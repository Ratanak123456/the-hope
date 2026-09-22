--!strict
-- Small, isolated persistence for onboarding + chapter-stage progress. THE
-- DAY THE SKY BROKE has no other save system (see README - "Not built yet:
-- Saving/checkpoints"), so this intentionally stays a couple of flags, not a
-- general-purpose profile store. Every DataStore call is pcall-guarded and
-- never blocks: a Studio session with API access off, or a live outage, must
-- never delay Play. The in-memory cache is the source of truth for the rest
-- of the server; the DataStore is best-effort persistence across sessions.
--
-- Progress has an explicit three-way status - Loading / Ready / Failed - so
-- callers can tell "still checking" and "the fetch broke" apart from "this is
-- a confirmed new player." Collapsing those to one boolean is exactly how you
-- end up silently treating a returning player as new.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local SaveService = {}

-- (player, stage) - fires whenever markStage() actually advances a player's
-- stage (never on a no-op repeat/regression attempt). ChapterOneDirector
-- uses this to start Scene 9 the instant the pre-existing boss-fight code
-- marks Scene09_ChapterEnding, without EncounterService.lua needing to know
-- Scene 9 exists.
SaveService.StageChanged = Signal.new()

-- Chapter One: "The Day the Sky Broke" - one Stage per scene, ranked in story
-- order. markStage() below only ever moves a player forward through this
-- list, which is what satisfies the "finished scenes cannot repeat
-- accidentally" requirement: a stray or replayed trigger for an earlier scene
-- can never regress a player who has already moved on.
export type Stage =
	"NotStarted"
	| "Scene01_NormalMorning" -- the morning delivery from Uncle Daren's repair shop
	| "Scene02_CentralPlaza" -- the plaza invasion cutscene / drop pod landing
	| "Scene03_CitySurvival" -- rescues, the power objective, first combat, meeting Ren and Voss
	| "Scene04_EvacuationRun" -- the escape run to the eastern shelter, ending in the street collapse
	| "Scene05_Underground" -- the tunnel journey from human wreckage to Architect ruin
	| "Scene06_AegisChamber" -- the Aegis Zero reveal, memory sequence and synchronization choice
	| "Scene07_AegisTraining" -- learning the Mecha combat kit inside the chamber
	| "Scene08_HarrowerBoss" -- the multi-phase Harrower boss fight
	| "Scene09_ChapterEnding" -- the ending cinematic and Commander Sera reveal
	| "ChapterOneComplete"
export type Progress = { onboardingComplete: boolean, stage: Stage }
export type Status = "Loading" | "Ready" | "Failed"

local STORE_NAME = "SkyBrokeProgressV3"
local FETCH_TIMEOUT = 3 -- never make a joining player wait longer than this for a synchronous read

-- Keyed as plain `string` rather than `{ [Stage]: number }`: luau-lsp does not
-- reliably narrow string-literal index expressions against a singleton-union
-- indexer, which made every lookup below a false type error.
local STAGE_RANK: { [string]: number } = {
	NotStarted = 0,
	Scene01_NormalMorning = 1,
	Scene02_CentralPlaza = 2,
	Scene03_CitySurvival = 3,
	Scene04_EvacuationRun = 4,
	Scene05_Underground = 5,
	Scene06_AegisChamber = 6,
	Scene07_AegisTraining = 7,
	Scene08_HarrowerBoss = 8,
	Scene09_ChapterEnding = 9,
	ChapterOneComplete = 10,
}

local DEFAULT_PROGRESS: Progress = { onboardingComplete = false, stage = "NotStarted" }

-- freshProgress() widens `stage` back to plain `string` under
-- luau-lsp's inference, so a small typed constructor is used everywhere
-- instead of cloning the constant.
local function freshProgress(): Progress
	return { onboardingComplete = false, stage = "NotStarted" }
end

local store: DataStore? = nil
local cache: { [Player]: Progress } = {}
local status: { [Player]: Status } = {}
local feedback: RemoteEvent? = nil

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		return store
	end
	warn(`[SKY BROKE] SaveService: DataStore unavailable ({result}) - progress will not persist across sessions`)
	return nil
end

-- Accepts the old boolean-only save shape from before progress tracking
-- existed, so nobody who already completed onboarding reads back as new.
local function normalize(raw: any): Progress
	if typeof(raw) == "boolean" then
		return { onboardingComplete = raw, stage = if raw then "Scene07_AegisTraining" else "NotStarted" }
	end
	if typeof(raw) == "table" then
		local stage = raw.stage
		if typeof(stage) ~= "string" or STAGE_RANK[stage :: Stage] == nil then
			stage = "NotStarted"
		end
		return { onboardingComplete = raw.onboardingComplete == true, stage = stage :: Stage }
	end
	return freshProgress()
end

local function pushProgress(player: Player)
	if not feedback then
		return
	end
	local current = cache[player] or DEFAULT_PROGRESS
	local resolvedStatus = status[player] or "Loading"
	if resolvedStatus ~= "Loading" then
		print(`[SKY BROKE] SaveService: progress resolved for {player.Name} - status={resolvedStatus} stage={current.stage}`)
	end
	feedback:FireClient(player, Net.Feedback.Progress, {
		status = resolvedStatus,
		onboardingComplete = current.onboardingComplete,
		stage = current.stage,
	})
end

-- Kicks off the async fetch and announces every step to the client, so the
-- menu can show "Checking progress..." immediately and then the real result
-- (or a retryable failure) the moment it resolves.
function SaveService.prefetch(player: Player)
	status[player] = "Loading"
	pushProgress(player)
	task.spawn(function()
		local dataStore = getStore()
		if not dataStore then
			if player.Parent then
				cache[player] = freshProgress()
				status[player] = "Ready" -- no DataStore access is a confirmed-empty read, not a retryable failure
				pushProgress(player)
			end
			return
		end
		local ok, result = pcall(function()
			return dataStore:GetAsync(tostring(player.UserId))
		end)
		if not player.Parent then
			return
		end
		if ok then
			cache[player] = normalize(result)
			status[player] = "Ready"
		else
			warn(`[SKY BROKE] SaveService: GetAsync failed for {player.Name}: {result}`)
			status[player] = "Failed"
		end
		pushProgress(player)
	end)
end

function SaveService.retry(player: Player)
	SaveService.prefetch(player)
end

--[[
	Best-effort synchronous read for server logic that needs an answer right
	now (e.g. deciding whether to run onboarding). Waits briefly for the
	prefetch, then falls back to "not completed" - by the time a player has
	sat through the menu and pressed Play this has essentially always
	resolved already, so the timeout is a safety net, not the common path.
]]
function SaveService.hasCompletedOnboarding(player: Player): boolean
	local waited = 0
	while status[player] == "Loading" and player.Parent and waited < FETCH_TIMEOUT do
		task.wait(0.1)
		waited += 0.1
	end
	local progress = cache[player]
	return progress ~= nil and progress.onboardingComplete
end

local function persist(player: Player, progress: Progress)
	cache[player] = progress
	status[player] = "Ready"
	pushProgress(player)
	task.spawn(function()
		local dataStore = getStore()
		if not dataStore then
			return
		end
		local ok, err = pcall(function()
			dataStore:SetAsync(tostring(player.UserId), progress)
		end)
		if not ok then
			warn(`[SKY BROKE] SaveService: SetAsync failed for {player.Name}: {err}`)
		end
	end)
end

function SaveService.markOnboardingComplete(player: Player)
	local current = cache[player] or freshProgress()
	persist(player, { onboardingComplete = true, stage = current.stage })
end

-- Stage only ever moves forward: a stray or replayed event can never regress
-- a player from, say, Scene08_HarrowerBoss back down to Scene06_AegisChamber.
function SaveService.markStage(player: Player, stage: Stage)
	local current = cache[player] or freshProgress()
	if STAGE_RANK[stage] <= STAGE_RANK[current.stage] then
		return
	end
	persist(player, { onboardingComplete = current.onboardingComplete, stage = stage })
	SaveService.StageChanged:Fire(player, stage)
end

-- Convenience read for scene triggers that must refuse to fire a second time
-- once the player has already moved past that point in the story (rule: "a
-- finished scene cannot repeat accidentally").
function SaveService.hasReached(player: Player, stage: Stage): boolean
	local current = cache[player] or freshProgress()
	return STAGE_RANK[current.stage] >= STAGE_RANK[stage]
end

-- Synchronous snapshot for anything that wants "whatever we know right now"
-- without waiting - the menu's progress push already covers the async path.
function SaveService.snapshot(player: Player): { status: Status, progress: Progress }
	return { status = status[player] or "Loading", progress = cache[player] or DEFAULT_PROGRESS }
end

function SaveService.clearPlayer(player: Player)
	cache[player] = nil
	status[player] = nil
end

function SaveService.init()
	feedback = Net.get("Feedback")
	Players.PlayerAdded:Connect(SaveService.prefetch)
	Players.PlayerRemoving:Connect(SaveService.clearPlayer)
	for _, player in Players:GetPlayers() do
		SaveService.prefetch(player)
	end
end

return SaveService
