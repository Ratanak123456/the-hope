--!strict
-- Server-driven dialogue. The client only renders and acknowledges; anything
-- gated behind a conversation is unlocked here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Dialogues = require(Shared.Dialogues)
local Net = require(Shared.Net)

type Active = {
	token: number,
	sequenceId: string,
	startedAt: number,
	lineCount: number,
	onComplete: (() -> ())?,
	completed: boolean,
}

local DialogueService = {}

local feedback: RemoteEvent
local active: { [Player]: Active } = {}
local nextToken = 0

local function finish(player: Player, entry: Active)
	if entry.completed then
		return
	end
	entry.completed = true
	if active[player] == entry then
		active[player] = nil
	end
	local callback = entry.onComplete
	if callback then
		task.spawn(callback)
	end
end

--[[
	Plays a sequence for one player.
	onComplete runs exactly once: on a believable client acknowledgement, on the
	server-side backstop timer, or if the conversation is cancelled - so story
	progression can never stall behind a UI that never answered.
]]
function DialogueService.play(player: Player, key: string, onComplete: (() -> ())?)
	local sequence = Dialogues[key]
	if not sequence then
		warn(`[Sky Broke] unknown dialogue sequence "{key}"`)
		if onComplete then
			task.spawn(onComplete)
		end
		return
	end

	local existing = active[player]
	if existing then
		-- Never let two conversations overlap; the older one resolves first.
		finish(player, existing)
	end

	nextToken += 1
	local entry: Active = {
		token = nextToken,
		sequenceId = sequence.id,
		startedAt = os.clock(),
		lineCount = #sequence.lines,
		onComplete = onComplete,
		completed = false,
	}
	active[player] = entry

	feedback:FireClient(player, Net.Feedback.Dialogue, {
		token = entry.token,
		sequenceId = sequence.id,
		lines = sequence.lines,
	})

	local backstop = entry.lineCount * Config.Dialogue.MaxSecondsPerLine
	task.delay(backstop, function()
		if active[player] == entry then
			feedback:FireClient(player, Net.Feedback.DialogueClear, { token = entry.token })
			finish(player, entry)
		end
	end)
end

-- Client says it finished reading. Validated against the live token and a
-- minimum believable duration so the ack cannot be spammed instantly.
function DialogueService.acknowledge(player: Player, token: unknown)
	if typeof(token) ~= "number" then
		return
	end
	local entry = active[player]
	if not entry or entry.token ~= token then
		return
	end
	local minimum = entry.lineCount * Config.Dialogue.MinSecondsPerLine
	if os.clock() - entry.startedAt < minimum then
		return
	end
	finish(player, entry)
end

-- Death, respawn or teardown. The completion still runs so unlocks survive.
function DialogueService.cancel(player: Player)
	local entry = active[player]
	if not entry then
		return
	end
	feedback:FireClient(player, Net.Feedback.DialogueClear, { token = entry.token })
	finish(player, entry)
end

function DialogueService.isActive(player: Player): boolean
	return active[player] ~= nil
end

function DialogueService.clearPlayer(player: Player)
	active[player] = nil
end

function DialogueService.init()
	feedback = Net.get("Feedback")
end

return DialogueService
