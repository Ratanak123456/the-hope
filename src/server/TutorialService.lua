--!nonstrict
-- Onboarding flow for a brand-new pilot: meet Aegis Zero, reach the launch
-- platform, transform, land a strike, dodge a telegraphed pulse, and use a
-- skill - each step gated on a real, confirmed gameplay event, never on a
-- timer or a button press alone.
--
-- This module owns ONLY the onboarding state machine. It reuses the existing
-- transform, combat and dialogue systems outright (see TutorialArea.lua for
-- why the training dummy is a real, damageable Warden) and hands off to
-- EncounterService.onPlayerReady() - the exact function that used to run for
-- every player before onboarding existed - the moment onboarding ends, so
-- nothing downstream needs to know onboarding happened at all.
--
-- Every step transition is guarded by a per-player token, the same pattern
-- PlayerService uses for its transform sequence: a stale dialogue callback or
-- timer from a step the player has since left (via skip, death-and-retry, or
-- disconnecting) can never resurrect it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Streets = require(script.Parent.World.Streets)
local CombatService = require(script.Parent.CombatService)
local DialogueService = require(script.Parent.DialogueService)
local EncounterService = require(script.Parent.EncounterService)
local PlayerService = require(script.Parent.PlayerService)
local SaveService = require(script.Parent.SaveService)
local TutorialArea = require(script.Parent.TutorialArea)

local TutorialService = {}

type StepId = "Greeting" | "ReachMarker" | "Transform" | "BasicAttack" | "Defense" | "Skill" | "Handoff" | "Done"

type Session = {
	step: StepId,
	token: number,
	slot: number,
	dummy: Model?,
	highlight: string?,
	markerTarget: Instance?,
	deadline: number,
	nudged: boolean,
	defenseTelegraphToken: number,
}

local feedback: RemoteEvent
local world: any
local container: Folder
local guideModel: Model? = nil
local guidePrompt: ProximityPrompt? = nil
local markerPosition = Vector3.zero
local worldReady = false

local sessions: { [Player]: Session } = {}
local usedSlots: { [number]: boolean } = {}

local STEP_INFO: { [StepId]: { title: string, detail: string } } = {
	Greeting = { title = "Meet Aegis Zero", detail = "Speak to Aegis Zero near the launch platform." },
	ReachMarker = { title = "Reach the platform", detail = "Follow the marker to the launch platform." },
	Transform = { title = "Activate Aegis Zero", detail = "Use the highlighted control to transform." },
	BasicAttack = { title = "Strike the target", detail = "Land a hit on the training target." },
	Defense = { title = "Dodge the pulse", detail = "Dash clear of the telegraphed pulse." },
	Skill = { title = "Use a skill", detail = "Hit the training target with Resonance Bolt." },
}

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------

local function claimSlot(): number
	local index = 1
	while usedSlots[index] do
		index += 1
	end
	usedSlots[index] = true
	return index
end

local function releaseSlot(slot: number?)
	if slot then
		usedSlots[slot] = nil
	end
end

local function disconnectAll(session: Session, connections: { RBXScriptConnection }?)
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end

local function pushCue(player: Player, session: Session, highlight: string?, markerTarget: Instance?)
	session.highlight = highlight
	session.markerTarget = markerTarget
	feedback:FireClient(player, Net.Feedback.TutorialCue, { highlight = highlight, markerTarget = markerTarget })
end

local function pushStepObjective(player: Player, step: StepId)
	local info = STEP_INFO[step]
	if not info then
		return
	end
	feedback:FireClient(player, Net.Feedback.Objective, {
		chapter = "SYSTEMS CHECK",
		title = info.title,
		detail = info.detail,
		tutorial = true,
	})
end

local function notify(player: Player, text: string)
	feedback:FireClient(player, Net.Feedback.Notice, { text = text })
end

local function dummyRoot(session: Session): BasePart?
	local dummy = session.dummy
	local part = dummy and dummy.PrimaryPart
	return if part and part:IsA("BasePart") then part else nil
end

--[[
	The platform marker is one shared world fixture, not one per player, so
	its visibility can't just be set true/false at each session's own step
	transitions - that would hide it out from under a second player still on
	"ReachMarker". Recomputed from every live session instead.
]]
local function refreshMarkerVisibility()
	for _, session in sessions do
		if session.step == "ReachMarker" then
			TutorialArea.setMarkerActive(true)
			return
		end
	end
	TutorialArea.setMarkerActive(false)
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

local function teardownSession(player: Player, session: Session, connections: { [Player]: { RBXScriptConnection } })
	disconnectAll(session, connections[player])
	connections[player] = nil
	if session.dummy then
		TutorialArea.removeDummy(session.dummy)
		session.dummy = nil
	end
	releaseSlot(session.slot)
	pushCue(player, session, nil, nil)
end

local stepConnections: { [Player]: { RBXScriptConnection } } = {}

local function clearStepConnections(player: Player)
	local existing = stepConnections[player]
	if existing then
		for _, connection in existing do
			connection:Disconnect()
		end
	end
	stepConnections[player] = {}
end

local function trackConnection(player: Player, connection: RBXScriptConnection)
	local list = stepConnections[player]
	if not list then
		list = {}
		stepConnections[player] = list
	end
	table.insert(list, connection)
end

--------------------------------------------------------------------------------
-- Step machine
--------------------------------------------------------------------------------

local enterStep: (player: Player, session: Session, step: StepId) -> ()

local function isCurrent(player: Player, session: Session, token: number): boolean
	return sessions[player] == session and session.token == token and player.Parent ~= nil
end

local function advance(player: Player, session: Session, next: StepId)
	if sessions[player] ~= session then
		return
	end
	enterStep(player, session, next)
end

local function playGuideLine(player: Player, session: Session, token: number, key: string, onDone: () -> ())
	DialogueService.play(player, key, function()
		if isCurrent(player, session, token) then
			onDone()
		end
	end)
end

local function fireDefenseTelegraph(player: Player, session: Session)
	local state = PlayerService.get(player)
	local root = state and state.character and state.character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	feedback:FireClient(player, Net.Feedback.WardenTelegraph, {
		position = root.Position,
		radius = Config.Tutorial.DefenseTelegraphRadius,
		duration = Config.Tutorial.DefenseTelegraphDuration,
	})
end

enterStep = function(player: Player, session: Session, step: StepId)
	clearStepConnections(player)
	session.step = step
	session.token += 1
	local token = session.token
	session.deadline = os.clock() + Config.Tutorial.StepTimeoutSeconds
	session.nudged = false
	refreshMarkerVisibility()

	if step == "Greeting" then
		-- Waits for the player to actually walk up and trigger the prompt
		-- (onGuideInteract plays the line and advances) rather than talking
		-- at them the instant they leave the menu.
		pushStepObjective(player, step)
		pushCue(player, session, nil, guideModel and guideModel.PrimaryPart)
		return
	end

	if step == "ReachMarker" then
		pushStepObjective(player, step)
		pushCue(player, session, nil, TutorialArea.markerPart())
		TutorialArea.gesture("Point")
		return -- confirmed by the shared proximity poll below
	end

	if step == "Transform" then
		player:SetAttribute("CanTransform", true)
		PlayerService.pushTransformState(player)
		pushStepObjective(player, step)
		playGuideLine(player, session, token, "Guide_Transform", function()
			pushCue(player, session, "Aegis", nil)
			local connection
			connection = PlayerService.TransformChanged:Connect(function(p: Player, active: boolean)
				if p == player and active and isCurrent(player, session, token) then
					connection:Disconnect()
					notify(player, "Aegis Zero online.")
					advance(player, session, "BasicAttack")
				end
			end)
			trackConnection(player, connection)
		end)
		return
	end

	if step == "BasicAttack" then
		local slot = session.slot
		-- +4 matches EncounterService's ArenaCentre convention: WardenRig's
		-- root sits above the floor by that much (its collision box + HipHeight).
		local origin = markerPosition + Vector3.new(10 + slot * 6, 4, -6)
		local dummy = TutorialArea.spawnDummy(container, origin)
		session.dummy = dummy
		pushStepObjective(player, step)
		playGuideLine(player, session, token, "Guide_BasicAttack", function()
			pushCue(player, session, "Strike", dummy.PrimaryPart)
			local connection
			connection = CombatService.WardenDamaged:Connect(function(model: Model, _damage: number, attacker: Player, ability: string?)
				if model == session.dummy and attacker == player and ability == "Strike" and isCurrent(player, session, token) then
					connection:Disconnect()
					notify(player, "Direct hit.")
					advance(player, session, "Defense")
				end
			end)
			trackConnection(player, connection)
		end)
		return
	end

	if step == "Defense" then
		pushStepObjective(player, step)
		playGuideLine(player, session, token, "Guide_Defense", function()
			pushCue(player, session, "ThrusterDash", nil)
			local connection
			connection = CombatService.AbilityUsed:Connect(function(p: Player, ability: string)
				if p == player and ability == "ThrusterDash" and isCurrent(player, session, token) then
					connection:Disconnect()
					notify(player, "Clean dodge.")
					advance(player, session, "Skill")
				end
			end)
			trackConnection(player, connection)

			session.defenseTelegraphToken += 1
			local telegraphToken = session.defenseTelegraphToken
			local function loop()
				if not isCurrent(player, session, token) or session.defenseTelegraphToken ~= telegraphToken then
					return
				end
				fireDefenseTelegraph(player, session)
				task.delay(Config.Tutorial.DefenseRetryInterval, loop)
			end
			loop()
		end)
		return
	end

	if step == "Skill" then
		TutorialArea.healDummy(session.dummy)
		pushStepObjective(player, step)
		playGuideLine(player, session, token, "Guide_Skill", function()
			pushCue(player, session, "ResonanceBolt", dummyRoot(session))
			local connection
			connection = CombatService.WardenDamaged:Connect(function(model: Model, _damage: number, attacker: Player, ability: string?)
				if model == session.dummy and attacker == player and ability == "ResonanceBolt" and isCurrent(player, session, token) then
					connection:Disconnect()
					notify(player, "Skill confirmed.")
					advance(player, session, "Handoff")
				end
			end)
			trackConnection(player, connection)
		end)
		return
	end

	if step == "Handoff" then
		pushCue(player, session, nil, nil)
		if session.dummy then
			TutorialArea.removeDummy(session.dummy)
			session.dummy = nil
		end
		releaseSlot(session.slot)
		session.slot = 0
		playGuideLine(player, session, token, "Guide_EnterFight", function()
			TutorialService.complete(player)
		end)
		return
	end
end

--------------------------------------------------------------------------------
-- Public entry points
--------------------------------------------------------------------------------

function TutorialService.complete(player: Player)
	local session = sessions[player]
	if session then
		session.step = "Done"
		clearStepConnections(player)
	end
	SaveService.markOnboardingComplete(player)
	EncounterService.onPlayerReady(player)
end

--[[
	Called from Main.server.lua once a player leaves the menu. Returning
	players (or a missing guide/marker - see the pcall in Main.server.lua)
	skip straight to the existing city flow; everyone else meets Aegis Zero.
]]
function TutorialService.beginForPlayer(player: Player)
	if not (guideModel and guideModel.Parent and worldReady) then
		warn(`[SKY BROKE] Tutorial world pieces missing for {player.Name} - skipping onboarding`)
		EncounterService.onPlayerReady(player)
		return
	end
	if SaveService.hasCompletedOnboarding(player) then
		EncounterService.onPlayerReady(player)
		return
	end
	if sessions[player] then
		return -- already running; Play cannot start a second one
	end
	sessions[player] = {
		step = "Greeting",
		token = 0,
		slot = claimSlot(),
		dummy = nil,
		highlight = nil,
		markerTarget = nil,
		deadline = 0,
		nudged = false,
		defenseTelegraphToken = 0,
	}
	enterStep(player, sessions[player], "Greeting")
end

function TutorialService.skip(player: Player)
	local session = sessions[player]
	if not session or session.step == "Done" then
		if not SaveService.hasCompletedOnboarding(player) then
			player:SetAttribute("CanTransform", true)
			PlayerService.pushTransformState(player)
			SaveService.markOnboardingComplete(player)
			EncounterService.onPlayerReady(player)
		end
		return
	end
	teardownSession(player, session, stepConnections)
	stepConnections[player] = nil
	session.step = "Done"
	refreshMarkerVisibility()
	player:SetAttribute("CanTransform", true)
	PlayerService.pushTransformState(player)
	SaveService.markOnboardingComplete(player)
	EncounterService.onPlayerReady(player)
end

--[[
	"Practice again" - from the settings panel or the post-tutorial guide
	menu. Only valid once already playable and not mid-encounter, so it can
	never disturb a live fight.
]]
function TutorialService.requestTraining(player: Player)
	local state = PlayerService.get(player)
	if not state or state.inMenu or state.inRuin then
		notify(player, "Return to the surface to practice.")
		return
	end
	local existing = sessions[player]
	if existing and existing.step ~= "Done" then
		return
	end
	PlayerService.forceHuman(player)
	PlayerService.teleport(player, CFrame.lookAt(markerPosition + Vector3.new(0, 3, 14), markerPosition + Vector3.new(0, 3, 0)))
	sessions[player] = {
		step = "ReachMarker",
		token = 0,
		slot = claimSlot(),
		dummy = nil,
		highlight = nil,
		markerTarget = nil,
		deadline = 0,
		nudged = false,
		defenseTelegraphToken = 0,
	}
	enterStep(player, sessions[player], "ReachMarker")
end

function TutorialService.handleDialogueChoice(player: Player, token: unknown, choiceId: unknown)
	if typeof(token) ~= "number" or typeof(choiceId) ~= "string" then
		return
	end
	DialogueService.acknowledge(player, token)
	if choiceId == "explain" then
		DialogueService.play(player, "Guide_ExplainControls")
	elseif choiceId == "practice" then
		DialogueService.play(player, "Guide_PracticeAcknowledge", function()
			TutorialService.requestTraining(player)
		end)
	elseif choiceId == "status" then
		EncounterService.onPlayerReady(player)
	elseif choiceId == "bye" then
		DialogueService.play(player, "Guide_Farewell")
	end
end

local function onGuideInteract(player: Player)
	if DialogueService.isActive(player) then
		return -- already mid-line; a repeated hold must not restart or skip it
	end
	local session = sessions[player]
	if session and session.step == "Greeting" then
		TutorialArea.gesture("Wave")
		local token = session.token
		playGuideLine(player, session, token, "Guide_Greeting", function()
			advance(player, session, "ReachMarker")
		end)
		return
	end
	if session and session.step ~= "Done" then
		return -- mid-step: the guide is already talking the player through it
	end
	if SaveService.hasCompletedOnboarding(player) then
		DialogueService.play(player, "Guide_Menu")
	end
end

--------------------------------------------------------------------------------
-- Shared low-frequency poll: marker proximity + gentle step-timeout nudges.
-- One connection for every onboarding player, matching EncounterService's
-- think() pattern, rather than a per-player loop.
--------------------------------------------------------------------------------

local pollAccumulator = 0

local function pollSessions()
	local now = os.clock()
	for player, session in sessions do
		if not player.Parent then
			continue
		end
		if session.step ~= "Done" then
			local state = PlayerService.get(player)
			if state and state.inRuin then
				-- The player reached the vault on their own, bypassing the
				-- guide entirely. Fold onboarding away rather than leaving
				-- stale cues pointed at a training area they have left.
				TutorialService.skip(player)
				continue
			end
		end
		if session.step == "ReachMarker" then
			local state = PlayerService.get(player)
			local root = state and state.character and state.character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				if (root.Position - markerPosition).Magnitude <= Config.Tutorial.MarkerReachRange then
					TutorialArea.gesture(nil)
					advance(player, session, "Transform")
					continue
				end
			end
		end
		if session.step ~= "Done" and now > session.deadline then
			session.deadline = now + Config.Tutorial.StepTimeoutSeconds
			if not session.nudged then
				session.nudged = true
				notify(player, "Need a hand? Use Skip Training if you'd rather jump in.")
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function TutorialService.clearPlayer(player: Player)
	local session = sessions[player]
	if session then
		teardownSession(player, session, stepConnections)
	end
	sessions[player] = nil
	stepConnections[player] = nil
	refreshMarkerVisibility()
end

function TutorialService.init(builtWorld: any)
	world = builtWorld
	feedback = Net.get("Feedback")

	local existing = workspace:FindFirstChild("HopeTutorial")
	if existing then
		existing:Destroy()
	end
	container = Instance.new("Folder")
	container.Name = "HopeTutorial"
	container.Parent = workspace

	-- Ground level, not the elevated spawn CFrame's Y: the guide's feet and the
	-- marker disc both need to sit on the actual walkable surface.
	local groundY = Streets.WalkY
	local spawnPosition = world.CitySpawn.Position
	local standAt = Vector3.new(spawnPosition.X + 16, groundY, spawnPosition.Z - 14)
	markerPosition = Vector3.new(spawnPosition.X, groundY, spawnPosition.Z - 22)

	-- Faces back toward the spawn, since that is the direction every arriving
	-- player approaches from - the marker sits further past the guide.
	local ok, guide, prompt = pcall(function()
		return TutorialArea.buildGuide(container, standAt, Vector3.new(spawnPosition.X, groundY, spawnPosition.Z))
	end)
	if ok then
		guideModel = guide
		guidePrompt = prompt
		if guidePrompt then
			guidePrompt.Triggered:Connect(onGuideInteract)
		end
		-- Its own pcall, separate from the guide above: a marker failure here
		-- must not also cost the guide (or worldReady, or the connections
		-- below - PlayerRemoving cleanup, the poll loop) that already
		-- succeeded moments earlier.
		local markerOk, markerErr = pcall(TutorialArea.buildMarker, container, markerPosition)
		if not markerOk then
			warn(`[SKY BROKE] TutorialArea.buildMarker failed: {markerErr}`)
		end
	else
		warn(`[SKY BROKE] TutorialArea.buildGuide failed: {guide}`)
	end
	worldReady = true
	print(`[SKY BROKE] TutorialService: guide {if guideModel then "ready" else "unavailable"}, worldReady=true`)

	Players.PlayerRemoving:Connect(TutorialService.clearPlayer)
	PlayerService.CharacterReady:Connect(function(player: Player)
		local session = sessions[player]
		if session and session.step ~= "Done" then
			task.defer(function()
				if sessions[player] == session then
					pushCue(player, session, session.highlight, session.markerTarget)
				end
			end)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		pollAccumulator += dt
		if pollAccumulator < 0.25 then
			return
		end
		pollAccumulator = 0
		pollSessions()
	end)
end

return TutorialService
