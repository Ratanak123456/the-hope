--!strict
-- Server entry point. Builds the world, starts the services and owns the only
-- places where client input crosses into gameplay.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local CombatService = require(script.Parent.CombatService)
local BoundaryService = require(script.Parent.BoundaryService)
local ChapterOneDirector = require(script.Parent.ChapterOneDirector)
local DialogueService = require(script.Parent.DialogueService)
local EncounterService = require(script.Parent.EncounterService)
local PlayerService = require(script.Parent.PlayerService)
local RateLimiter = require(script.Parent.RateLimiter)
local SaveService = require(script.Parent.SaveService)
local TutorialService = require(script.Parent.TutorialService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local bootClock = os.clock()
local function elapsed(): string
	return string.format("%.2fs", os.clock() - bootClock)
end

--[[
	Every subsystem init below is optional relative to the one thing that must
	never fail to wire up: the Action remote handler further down, which is
	what unlocks a player's controls after the opening cinematic (MenuState).
	Before this existed, an uncaught error in ANY one of these calls - all
	plain top-level statements - would silently abort the rest of this script,
	so nothing after the failure point (the remote handlers included) ever ran.
	That reproduces exactly "camera stuck, Skip does nothing, can't proceed":
	the client-side cinematic finishes or is skipped just fine and sends
	MenuState=false, but no server-side listener was ever connected to receive
	it, so the player's Humanoid never leaves its in-menu WalkSpeed-0 state.
]]
local function safeInit(label: string, fn: () -> ())
	-- pcall(fn) directly, with `fn` typed as a stored `() -> ()` parameter
	-- rather than an inline literal, only type-checks as returning `boolean`
	-- (Luau's pcall overload resolution needs to see the function literal
	-- itself to know an error string might follow) - wrapping it in one
	-- keeps the real error message intact for the warn() below.
	local ok, err = pcall(function()
		fn()
	end)
	if not ok then
		warn(`[SKY BROKE] {label} failed to initialize - continuing without it: {err}`)
	else
		print(`[SKY BROKE] {label} ready at {elapsed()}`)
	end
end

Net.init()
print(`[SKY BROKE] remotes ready at {elapsed()}`)

-- Player handlers go in BEFORE the world is generated. Building the district
-- takes long enough that a player can join mid-build, and anyone who spawns
-- before these are installed ends up with no tracked character.
PlayerService.installHandlers()

-- Two-phase build: the essential phase produces a walkable city and unblocks
-- character spawning immediately below; the ruin vault, outer backdrop and
-- sky dressing finish afterward without making anyone wait for them. See
-- WorldBuilder.lua for why this split is safe.
local world = WorldBuilder.buildEssential()
print(`[SKY BROKE] essential world (city + spawn) ready at {elapsed()}`)

BoundaryService.build(world.Folder)

PlayerService.setWorld(world) -- characters can spawn from this point on
print(`[SKY BROKE] spawning unblocked at {elapsed()}`)

safeInit("BoundaryService", BoundaryService.init)
safeInit("DialogueService", DialogueService.init)
safeInit("CombatService", CombatService.init)
safeInit("SaveService", SaveService.init)
safeInit("EncounterService", function() EncounterService.init(world) end) -- safe before finishDecor(): world is mutated in place

-- Onboarding only needs the essential-phase city (CitySpawn) - it never waits
-- on the ruin/backdrop/sky finishing in the background below.
safeInit("TutorialService", function() TutorialService.init(world) end)

-- Chapter One, Scene 1 ("A Normal Morning") also only needs the essential
-- city - Daren's neighborhood, the plaza marker and ambient civilians are
-- all part of that phase.
safeInit("ChapterOneDirector", function() ChapterOneDirector.init(world) end)

task.spawn(function()
	local ok, err = pcall(WorldBuilder.finishDecor, world)
	if ok then
		print(`[SKY BROKE] full world (ruin + backdrop + sky) ready at {elapsed()}`)
	else
		warn(`[SKY BROKE] WorldBuilder.finishDecor failed - ruin/backdrop/sky may be incomplete: {err}`)
	end
end)

local transformRemote = Net.get("Transform")
local attackRemote = Net.get("Attack")
local actionRemote = Net.get("Action")
local feedbackRemote = Net.get("Feedback")

local attackLimit = RateLimiter.new(Config.Limits.Attack.count, Config.Limits.Attack.window)
local transformLimit = RateLimiter.new(Config.Limits.Transform.count, Config.Limits.Transform.window)
local actionLimit = RateLimiter.new(Config.Limits.Action.count, Config.Limits.Action.window)
local promptLimit = RateLimiter.new(Config.Limits.Prompt.count, Config.Limits.Prompt.window)

-- Guards the descent so a player holding the prompt cannot re-enter the ruin
-- while the opening conversation is still running.
local descending: { [Player]: boolean } = {}

assert(world.Prompt and world.Prompt:IsA("ProximityPrompt"), "[SKY BROKE] ruin entrance prompt was not created")
print(`[SKY BROKE] entrance prompt ready on {world.Prompt.Parent and world.Prompt.Parent:GetFullName() or "?"} at {world.EntrancePosition}`)

world.Prompt.Triggered:Connect(function(player: Player)
	if not promptLimit:allow(player) then
		return
	end
	if descending[player] then
		return
	end

	local state = PlayerService.get(player)
	if state and state.inRuin then
		return -- already below; nothing to report
	end

	-- The prompt itself stays enabled the whole time (see WorldBuilder.lua for
	-- why); this is the actual gate on the vault existing to send anyone to.
	-- In practice finishDecor() completes well before any player can walk from
	-- spawn to the entrance, so this almost never triggers.
	if not world.DecorReady then
		warn(`[SKY BROKE] {player.Name} triggered the entrance before the vault finished generating`)
		feedbackRemote:FireClient(player, Net.Feedback.Notice, { text = "Still preparing the vault — try again in a moment" })
		return
	end

	-- Every other refusal is logged. A prompt that completes its hold and then
	-- does nothing is the single most confusing failure this game can produce,
	-- so it is never allowed to be silent.
	local reason = PlayerService.blockReason(player)
	if reason then
		warn(`[SKY BROKE] {player.Name} triggered the entrance but was refused: {reason}`)
		return
	end
	local character = state and state.character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or (root.Position - world.EntrancePosition).Magnitude > world.Prompt.MaxActivationDistance + 4 then
		warn(`[SKY BROKE] {player.Name} triggered the entrance outside validated range`)
		return
	end

	descending[player] = true
	EncounterService.onDescend(player)
	-- state.inRuin now guards re-entry; release the one-shot latch.
	descending[player] = nil
	print(`[SKY BROKE] {player.Name} descended into the ruin`)
end)

transformRemote.OnServerEvent:Connect(function(player)
	if not transformLimit:allow(player) then
		return
	end
	local wantsOn = not PlayerService.isTransformed(player)
	local ok, reason = PlayerService.setTransformed(player, wantsOn)
	if not ok and reason == "locked" then
		DialogueService.play(player, "Locked_NotReady")
	end
end)

attackRemote.OnServerEvent:Connect(function(player, ability, payload)
	if not attackLimit:allow(player) then
		return
	end
	CombatService.request(player, ability, payload)
end)

actionRemote.OnServerEvent:Connect(function(player, verb, payload)
	if not actionLimit:allow(player) then
		return
	end
	if typeof(verb) ~= "string" then
		return
	end

	if verb == Net.Action.MenuState then
		if typeof(payload) ~= "boolean" then
			return
		end
		PlayerService.setMenu(player, payload)
		if not payload then
			print(`[SKY BROKE] {player.Name} left the menu - unlocking controls, resolving intro entry`)
			-- Fresh pilots (or anyone who has not finished Scene 1 yet) begin
			-- Chapter One, Scene 1 first. ChapterOneDirector.begin() returns
			-- false only once Scene 1 is already complete, at which point
			-- control falls through to the existing tutorial/chamber/boss
			-- flow - see TutorialService.beginForPlayer. Scenes 2-5 are not
			-- implemented yet, so that fallback is deliberate, not a bug.
			local ok, handled = pcall(ChapterOneDirector.begin, player)
			if not ok then
				warn(`[SKY BROKE] ChapterOneDirector.begin failed for {player.Name}: {handled}`)
			elseif not handled then
				local tutorialOk, err = pcall(TutorialService.beginForPlayer, player)
				if not tutorialOk then
					warn(`[SKY BROKE] TutorialService.beginForPlayer failed for {player.Name}: {err}`)
				end
			end
		end
	elseif verb == Net.Action.DialogueDone then
		DialogueService.acknowledge(player, payload)
	elseif verb == Net.Action.DialogueChoice then
		if typeof(payload) == "table" then
			TutorialService.handleDialogueChoice(player, payload.token, payload.choiceId)
		end
	elseif verb == Net.Action.Retry then
		EncounterService.retry(player)
	elseif verb == Net.Action.ReturnToSurface then
		EncounterService.returnToSurface(player)
	elseif verb == Net.Action.SkipTutorial then
		TutorialService.skip(player)
	elseif verb == Net.Action.RequestTraining then
		TutorialService.requestTraining(player)
	elseif verb == Net.Action.RetryProgress then
		SaveService.retry(player)
	elseif verb == Net.Action.SkipScene01 then
		-- The client can fire this while its own cinematic is still playing,
		-- before MenuState=false has ever reached the server - begin() is
		-- idempotent (it no-ops if Scene 1 is already running or finished),
		-- so calling it here just guarantees scene01[player] exists before
		-- skip() applies the end state to it.
		ChapterOneDirector.begin(player)
		ChapterOneDirector.skip(player)
	elseif verb == Net.Action.Scene02Done then
		-- Fired by the client once Scene 2's invasion cutscene ends, whether
		-- watched in full or skipped - see CutsceneRunner's unified `finish`.
		ChapterOneDirector.completeScene02(player)
	elseif verb == Net.Action.Scene04Done then
		ChapterOneDirector.completeScene04(player)
	elseif verb == Net.Action.Scene09Done then
		ChapterOneDirector.completeScene09(player)
	elseif verb == Net.Action.ChapterOneContinue then
		ChapterOneDirector.continueAfterChapterOne(player)
	elseif verb == Net.Action.ChapterOneReturnToMenu then
		PlayerService.setMenu(player, true)
	end
end)

PlayerService.Died:Connect(function(player)
	DialogueService.cancel(player)
end)

Players.PlayerRemoving:Connect(function(player)
	descending[player] = nil
	attackLimit:clear(player)
	transformLimit:clear(player)
	actionLimit:clear(player)
	promptLimit:clear(player)
	CombatService.clearPlayer(player)
	DialogueService.clearPlayer(player)
end)

print(`[SKY BROKE] server ready - {Config.Game.Version}`)
