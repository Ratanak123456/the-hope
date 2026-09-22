--!nonstrict
-- Client entry point. Builds the interface once, wires it to the server's
-- feedback stream and keeps everything in step with respawns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Effects = require(script.Parent.Effects)
local InputController = require(script.Parent.InputController)
local MenuScene = require(script.Parent.MenuScene)
local Responsive = require(script.Parent.Responsive)
local Settings = require(script.Parent.Settings)
local State = require(script.Parent.State)

local UI = script.Parent.UI
local ChapterCompletePanel = require(UI.ChapterCompletePanel)
local ChaptersPanel = require(UI.ChaptersPanel)
local DialoguePanel = require(UI.DialoguePanel)
local HUD = require(UI.HUD)
local InteractionPrompt = require(UI.InteractionPrompt)
local MainMenu = require(UI.MainMenu)
local Opening = require(script.Parent.Opening)
local Scene02Invasion = require(script.Parent.Scene02Invasion)
local Scene04Collapse = require(script.Parent.Scene04Collapse)
local Scene09Ending = require(script.Parent.Scene09Ending)
local NavigationIndicator = require(UI.NavigationIndicator)
local ResultPanel = require(UI.ResultPanel)
local Root = require(UI.Root)
local SettingsPanel = require(UI.SettingsPanel)

local player = Players.LocalPlayer

local bootClock = os.clock()
local function elapsed(): string
	return string.format("%.2fs", os.clock() - bootClock)
end

-- UI first: this is pure local Instance construction, so it costs nothing to
-- put ahead of the remote waits below. It is what makes the menu the very
-- first thing a joining player sees, instead of a blank screen while remotes
-- replicate.
Responsive.init()
Root.build()

Effects.init(Root.layer("Overlay"))
HUD.build(Root.layer("HUD"))
InteractionPrompt.build(Root.layer("HUD"))
NavigationIndicator.build(Root.layer("HUD"))
DialoguePanel.build(Root.layer("Dialogue"))
ResultPanel.build(Root.layer("Result"))
ChapterCompletePanel.build(Root.layer("Result"))
SettingsPanel.build(Root.layer("Overlay"))
ChaptersPanel.build(Root.layer("Overlay"))
MainMenu.build(Root.layer("Menu"))

HUD.setVisible(false)
print(`[SKY BROKE] client UI ready at {elapsed()}`)

-- Remotes replicate almost immediately (the server creates them before it
-- starts building the world), but this still waits, so it is measured too.
local transformRemote = Net.get("Transform")
local attackRemote = Net.get("Attack")
local actionRemote = Net.get("Action")
local feedbackRemote = Net.get("Feedback")
print(`[SKY BROKE] remotes ready at {elapsed()}`)

local pendingVictory: any = nil
local originalMinZoom = player.CameraMinZoomDistance
local originalMaxZoom = player.CameraMaxZoomDistance
local settingsOpenedFromMenu = false
local openingActive = false

local function sendAction(verb: string, payload: any?)
	actionRemote:FireServer(verb, payload)
end

--------------------------------------------------------------------------------
-- Menu / settings
--------------------------------------------------------------------------------

local function openSettings(fromMenu: boolean)
	settingsOpenedFromMenu = fromMenu
	SettingsPanel.setVisible(true)
	if not fromMenu then
		sendAction(Net.Action.MenuState, true)
	end
end

local function closeSettings()
	SettingsPanel.setVisible(false)
	if not settingsOpenedFromMenu then
		sendAction(Net.Action.MenuState, false)
	else
		MainMenu.focusSecondary("settings")
	end
end

SettingsPanel.setCloseCallback(closeSettings)

HUD.setSettingsCallback(function()
	openSettings(false)
end)

local function openChapters()
	ChaptersPanel.setVisible(true)
end

local function closeChapters()
	ChaptersPanel.setVisible(false)
	MainMenu.focusSecondary("chapters")
end

--[[
	Shared by the first Play press and a mid-game Replay Intro: play the
	cinematic, then hand control back through the same MenuState toggle
	either way, so the server-side branch (fresh pilot vs. returning) is
	always decided the same way, in the same place.
]]
local function enterGameplay()
	openingActive = false
	State.set("openingActive", false)
	HUD.setVisible(true)
	local camera = workspace.CurrentCamera
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then camera.CameraSubject = humanoid end
	end
	sendAction(Net.Action.MenuState, false)
	-- The welcome screen never comes back in this game, so its hangar, the
	-- display mecha and its lights are freed outright here rather than just
	-- paused - "clean up menu-only resources" once gameplay truly begins.
	MenuScene.destroy()
	print(`[SKY BROKE] player in control at {elapsed()}`)
end

local function playOpening(onStart: (() -> ())?)
	if openingActive then return end
	openingActive = true
	State.set("openingActive", true)
	if onStart then onStart() end
	HUD.setVisible(false)
	Opening.start(Root.layer("Overlay"), enterGameplay)
end

--[[
	Shared by the main menu's primary action and the Chapters panel's own
	action - both ultimately do the same thing. A returning player (real
	server-reported progress, never a guess) skips the cinematic entirely:
	that is what Replay Intro is for, so Continue does not repeat it.
]]
local function handlePlay(returning: boolean)
	if openingActive then return end
	print(`[SKY BROKE] {if returning then "CONTINUE" else "PLAY"} pressed at {elapsed()}`)
	MainMenu.setBusy(if returning then "ENTERING…" else "PREPARING…")
	if returning then
		MainMenu.setVisible(false)
		enterGameplay()
	else
		playOpening(function()
			MainMenu.setVisible(false)
		end)
	end
end

MainMenu.setCallbacks({
	play = handlePlay,
	settings = function()
		openSettings(true)
	end,
	chapters = openChapters,
	retryProgress = function()
		sendAction(Net.Action.RetryProgress)
	end,
})

ChaptersPanel.setCallbacks({
	close = closeChapters,
	play = function(returning: boolean)
		closeChapters()
		handlePlay(returning)
	end,
})

-- Replay Intro is cinematic-only: it never touches tutorial completion, so a
-- player who has already finished (or skipped) training keeps that state.
local function replayIntro()
	if openingActive or MainMenu.isOpen() then return end
	SettingsPanel.setVisible(false)
	sendAction(Net.Action.MenuState, true)
	playOpening()
end

SettingsPanel.setGuideCallbacks({
	replayIntro = replayIntro,
	requestTraining = function()
		SettingsPanel.setVisible(false)
		sendAction(Net.Action.RequestTraining)
	end,
})

ResultPanel.setCallbacks({
	retry = function()
		sendAction(Net.Action.Retry)
	end,
	returnToSurface = function()
		sendAction(Net.Action.ReturnToSurface)
	end,
	dismiss = function() end,
})

ChapterCompletePanel.setCallbacks({
	continue_ = function()
		sendAction(Net.Action.ChapterOneContinue)
	end,
	returnToMenu = function()
		sendAction(Net.Action.ChapterOneReturnToMenu)
		HUD.setVisible(false)
		MainMenu.setVisible(true)
	end,
})

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

local function requestTransform()
	transformRemote:FireServer()
end

local function aimDirection(): Vector3
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
end

local function requestAbility(id: string)
	HUD.setRequested(id)
	local payload = nil
	if id == "ResonanceBolt" then
		payload = { direction = aimDirection() }
	elseif id == "ThrusterDash" then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		payload = { direction = if humanoid and humanoid.MoveDirection.Magnitude > 0 then humanoid.MoveDirection else aimDirection() }
	end
	attackRemote:FireServer(id, payload)
end

InputController.bind({
	transform = requestTransform,
	attack = function() requestAbility("Strike") end,
	slam = function() requestAbility("GroundSlam") end,
	bolt = function() requestAbility("ResonanceBolt") end,
	dash = function() requestAbility("ThrusterDash") end,
	ultimate = function() requestAbility("CoreBurst") end,
	advance = function()
		DialoguePanel.advance()
	end,
})

HUD.onSlotActivated("Aegis", function()
	if State.combatAllowed() then
		requestTransform()
	end
end)
HUD.onSlotActivated("Strike", function()
	if State.combatAllowed() then
		requestAbility("Strike")
	end
end)
for _, id in { "GroundSlam", "ResonanceBolt", "ThrusterDash", "CoreBurst" } do
	HUD.onSlotActivated(id, function()
		if State.combatAllowed() then requestAbility(id) end
	end)
end

DialoguePanel.setFinishedCallback(function(token)
	sendAction(Net.Action.DialogueDone, token)
end)
DialoguePanel.setChoiceCallback(function(token, choiceId)
	sendAction(Net.Action.DialogueChoice, { token = token, choiceId = choiceId })
end)

HUD.setSkipTutorialCallback(function()
	sendAction(Net.Action.SkipTutorial)
end)

--------------------------------------------------------------------------------
-- Aegis Zero camera framing
--------------------------------------------------------------------------------

--[[
	Piloting Aegis Zero pushes the camera out so the whole mecha stays in frame.
	The player's original zoom limits are captured once and always restored, so
	this can never leave their camera stuck.
]]
local function applyAegisCamera(active: boolean)
	if active then
		player.CameraMaxZoomDistance = math.max(originalMaxZoom, Config.Aegis.CameraMinZoom + 8)
		player.CameraMinZoomDistance = Config.Aegis.CameraMinZoom
	else
		player.CameraMinZoomDistance = originalMinZoom
		player.CameraMaxZoomDistance = originalMaxZoom
	end
end

--------------------------------------------------------------------------------
-- Character lifecycle
--------------------------------------------------------------------------------

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end

	-- Respawn is a hard reset for everything transient.
	DialoguePanel.clear()
	ResultPanel.hide()
	HUD.clearCooldowns()
	HUD.setMode("Human")
	HUD.setEnemyStatus(nil)
	Effects.clear()
	applyAegisCamera(false)
	pendingVictory = nil

	HUD.bindHumanoid(humanoid)
	Effects.bindCharacter(character, humanoid)

	if not MainMenu.isOpen() then
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
	end

	print(`[SKY BROKE] character ready at {elapsed()}`)
end

if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

--------------------------------------------------------------------------------
-- Server feedback
--------------------------------------------------------------------------------

local function tryShowVictory()
	if pendingVictory and not DialoguePanel.isOpen() and not ResultPanel.isOpen() then
		local data = pendingVictory
		pendingVictory = nil
		ResultPanel.showVictory(data)
	end
end

State.Changed:Connect(function(key, value)
	if key == "dialogueOpen" then
		HUD.setActionBarVisible(not value)
		if value == false then
			task.defer(tryShowVictory)
		end
	end
end)

Settings.Changed:Connect(function(key)
	if key == "reducedMotion" and Settings.reducedMotion() then
		Effects.clear()
	end
end)

local FEEDBACK = Net.Feedback

feedbackRemote.OnClientEvent:Connect(function(kind, payload)
	if kind == FEEDBACK.Progress then
		MainMenu.setProgress(payload)
		ChaptersPanel.setProgress(payload)
	elseif kind == FEEDBACK.Objective then
		HUD.setObjective(payload)
		-- While onboarding is active, TutorialCue owns the marker exclusively
		-- (it points at the guide, the platform or the dummy in turn); this
		-- only drives the original "head for the ruin" city pointer.
		if not (payload and payload.tutorial) then
			NavigationIndicator.setActive(payload and payload.chapter == "PROLOGUE")
		end
	elseif kind == FEEDBACK.TutorialCue then
		if typeof(payload) == "table" then
			HUD.setHighlight(payload.highlight)
			if payload.markerTarget then
				NavigationIndicator.setTarget(payload.markerTarget)
				NavigationIndicator.setActive(true)
			else
				NavigationIndicator.clearTarget()
				NavigationIndicator.setActive(false)
			end
		end
	elseif kind == FEEDBACK.EnemyStatus then
		HUD.setEnemyStatus(payload)
	elseif kind == FEEDBACK.Dialogue then
		DialoguePanel.play(payload)
	elseif kind == FEEDBACK.DialogueClear then
		DialoguePanel.clear()
	elseif kind == FEEDBACK.Transform then
		if typeof(payload) ~= "table" then
			return
		end
		local active = payload.active == true
		local busy = payload.busy == true
		local unlocked = payload.unlocked == true
		local phase = tostring(payload.phase)
		local duration = tonumber(payload.duration) or 0

		State.set("wardenActive", active)
		State.set("wardenUnlocked", unlocked)
		State.set("wardenBusy", busy)
		HUD.setAegisStatus(unlocked, active)

		if phase == "Begin" then
			HUD.setMode("Awakening")
			HUD.setStatus("TRANSFORMING")
			-- The slot is genuinely unavailable for exactly this long.
			HUD.startCooldown("Aegis", duration)
		elseif phase == "Complete" then
			HUD.setMode("Aegis")
			applyAegisCamera(true)
		elseif phase == "Revert" then
			HUD.startCooldown("Aegis", duration)
		elseif phase == "Human" or phase == "Abort" then
			HUD.setMode("Human")
			HUD.clearCooldowns()
			applyAegisCamera(false)
		end
	elseif kind == FEEDBACK.TransformVFX then
		Effects.transformVFX(payload)
	elseif kind == FEEDBACK.Cooldown then
		if payload and payload.ability then
			HUD.startCooldown(payload.ability, tonumber(payload.duration) or 0)
		end
	elseif kind == FEEDBACK.AbilityState then
		HUD.setAbilityState(payload)
	elseif kind == FEEDBACK.Notice then
		if payload and payload.text then HUD.notify(tostring(payload.text)) end
	elseif kind == FEEDBACK.WorldMarker then
		if typeof(payload) == "table" and payload.active and payload.target then
			NavigationIndicator.setTarget(payload.target)
			NavigationIndicator.setActive(true)
		else
			NavigationIndicator.clearTarget()
			NavigationIndicator.setActive(false)
		end
	elseif kind == FEEDBACK.LocationTitle then
		if payload and payload.text then HUD.showLocationTitle(tostring(payload.text)) end
	elseif kind == FEEDBACK.Scene02Invasion then
		Scene02Invasion.run(Root.layer("Overlay"))
	elseif kind == FEEDBACK.HumanCombat then
		HUD.setHumanCombatEnabled(payload and payload.enabled == true)
	elseif kind == FEEDBACK.Scene04Collapse then
		Scene04Collapse.run(Root.layer("Overlay"))
	elseif kind == FEEDBACK.Scene09Ending then
		Scene09Ending.run(Root.layer("Overlay"))
	elseif kind == FEEDBACK.ChapterComplete then
		ChapterCompletePanel.show(payload)
	elseif kind == FEEDBACK.Hit then
		if payload then
			Effects.hitConfirm(tonumber(payload.count) or 0, tonumber(payload.killed) or 0)
		end
	elseif kind == FEEDBACK.AttackVFX then
		-- Everyone sees the swing; only the attacker's camera reacts, which is
		-- decided inside Effects from the payload's userId.
		Effects.strikeVFX(payload)
	elseif kind == FEEDBACK.AbilityVFX then
		Effects.abilityVFX(payload)
	elseif kind == FEEDBACK.WardenTelegraph then
		Effects.constructTelegraph(payload)
	elseif kind == FEEDBACK.WardenHit then
		Effects.constructHit(payload)
	elseif kind == FEEDBACK.Encounter then
		local state = payload and payload.state
		State.set("encounterState", tostring(state))
		if state == "Cleared" then
			pendingVictory = payload
			task.defer(tryShowVictory)
		elseif state == "Failed" then
			DialoguePanel.clear()
			HUD.clearCooldowns()
			ResultPanel.showDefeat(payload)
		elseif state == "Active" then
			pendingVictory = nil
			if ResultPanel.isOpen() then
				ResultPanel.hide()
			end
		end
	end
end)

-- Startup banner. If this line is missing from the Output, the client script
-- stopped before finishing and no menu button will do anything.
print(`[SKY BROKE] client ready - {Config.Game.Version} - script init took {elapsed()}`)
