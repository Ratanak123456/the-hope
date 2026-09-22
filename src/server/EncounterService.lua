--!strict
-- Owns the only encounter that exists today: the Chapter 1 awakening chamber.
-- Spawning, enemy AI, objective text, victory, failure and retry all live here
-- so the HUD never has to guess at progress.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local CombatService = require(script.Parent.CombatService)
local BoundaryService = require(script.Parent.BoundaryService)
local WardenRig = require(script.Parent.WardenRig)
local DialogueService = require(script.Parent.DialogueService)
local PlayerService = require(script.Parent.PlayerService)
local SaveService = require(script.Parent.SaveService)

local EncounterService = {}

export type Phase = "City" | "Chamber" | "Combat" | "Boss" | "Cleared"

local feedback: RemoteEvent
local world: any
local container: Folder

local wardens: { Model } = {}
-- Per-Warden attack state. `windupEnd` is the single timestamp that drives
-- both the telegraph and the damage, so they can never disagree.
type AttackState = { phase: string, windupEnd: number, readyAt: number, targetId: number? }
local wardenAttack: { [Model]: AttackState } = {}
local aliveCount = 0
local totalCount = 0
local encounterState: string = "Idle" -- Idle | Active | Cleared
local participants: { [Player]: boolean } = {}
local retryTimers: { [Player]: thread } = {}

local OBJECTIVES: { [string]: { chapter: string, title: string, detail: string } } = {
	City = {
		chapter = "PROLOGUE",
		title = "The Sky Breaks",
		detail = "Reach the Ancient signal at the city centre.",
	},
	Chamber = {
		chapter = "CHAPTER 1",
		title = "The Awakening",
		detail = "Awaken Aegis Zero.",
	},
	Combat = {
		chapter = "CHAPTER 1",
		title = "The Awakening",
		detail = "Clear the chamber of Wardens.",
	},
	Boss = {
		chapter = "CHAPTER 1",
		title = "The Harrower",
		detail = "Bring down the Harrower.",
	},
	Cleared = {
		chapter = "CHAPTER 1",
		title = "The Harrower",
		detail = "Chamber secured.",
	},
}

local function pushObjective(player: Player, phase: string, withProgress: boolean?)
	local entry = OBJECTIVES[phase]
	if not entry then
		return
	end
	feedback:FireClient(player, Net.Feedback.Objective, {
		chapter = entry.chapter,
		title = entry.title,
		detail = entry.detail,
		progressCurrent = if withProgress then totalCount - aliveCount else nil,
		progressTotal = if withProgress then totalCount else nil,
	})
end

local function broadcastObjective(phase: string, withProgress: boolean?)
	for player in participants do
		if player.Parent then
			pushObjective(player, phase, withProgress)
		end
	end
end

local function pushEncounter(player: Player, state: string)
	feedback:FireClient(player, Net.Feedback.Encounter, {
		state = state,
		name = Config.Encounter.Opening.Name,
		remaining = aliveCount,
		total = totalCount,
	})
end

local function broadcastEncounter(state: string)
	for player in participants do
		if player.Parent then
			pushEncounter(player, state)
		end
	end
end

--[[
	Aggregate Warden health: the sum of every spawned Warden's current health
	over the sum of their starting health. This is the closest honest analog
	to a "boss health bar" the game actually has - there is no single boss,
	just the Wardens - and it is entirely real Humanoid.Health data, not an
	invented stat. Dead Wardens contribute 0, so the bar visibly drains
	both from damage and from kills.
]]
local function wardenTotals(): (number, number)
	local current = 0
	for _, model in wardens do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			current += math.max(humanoid.Health, 0)
		end
	end
	return current, totalCount * Config.Warden.MaxHealth
end

local function pushWardenStatusTo(player: Player)
	if totalCount <= 0 then
		feedback:FireClient(player, Net.Feedback.EnemyStatus, { active = false })
		return
	end
	local current, max = wardenTotals()
	feedback:FireClient(player, Net.Feedback.EnemyStatus, {
		active = encounterState == "Active",
		label = "WARDENS",
		current = current,
		max = max,
	})
end

local function broadcastWardenStatus()
	for player in participants do
		if player.Parent then
			pushWardenStatusTo(player)
		end
	end
end

--------------------------------------------------------------------------------
-- The Harrower: Chapter 1's boss.
--
-- Fought once the four-scout wave above is fully cleared. Hunter -> Signal
-- (65% health: summons two adds and two shielding pylons) -> Desperation (30%
-- health: faster, unlocks a wide Shockring) -> Defeated (a short cinematic-
-- lite hold before cleanup). See WardenRig.lua for the rig itself.
--------------------------------------------------------------------------------

type BossAttack = {
	phase: string, -- Idle | Windup | Recover
	kind: string?,
	windupEnd: number,
	readyAt: number,
	cooldowns: { [string]: number },
	targetPos: Vector3?,
	lineEnd: Vector3?,
}

type BossInfo = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	phase: string, -- Hunter | Signal | Desperation | Defeated
	shielded: boolean,
	attack: BossAttack,
}

local boss: BossInfo? = nil
local pylons: { Model } = {}
local bossAdds: { Model } = {}

local BOSS_ATTACK_SPEC: { [string]: { windup: number, recover: number, cooldown: number } } = {
	Claw = { windup = Config.Boss.ClawWindup, recover = Config.Boss.ClawRecover, cooldown = Config.Boss.ClawCooldown },
	Leap = { windup = Config.Boss.LeapWindup, recover = Config.Boss.LeapRecover, cooldown = Config.Boss.LeapCooldown },
	Line = { windup = Config.Boss.LineWindup, recover = Config.Boss.LineRecover, cooldown = Config.Boss.LineCooldown },
	Shockring = { windup = Config.Boss.ShockringWindup, recover = Config.Boss.ShockringRecover, cooldown = Config.Boss.ShockringCooldown },
}

-- Flattened point-to-segment distance: used by the Line attack so a hit check
-- reads as "near this stretch of ground" rather than "near one exact point."
local function distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local abLenSq = ab:Dot(ab)
	if abLenSq < 1e-4 then
		return (point - a).Magnitude
	end
	local t = math.clamp((point - a):Dot(ab) / abLenSq, 0, 1)
	return (point - (a + ab * t)).Magnitude
end

local function damagePlayersInRadius(center: Vector3, radius: number, damage: number)
	for player in participants do
		local state = PlayerService.get(player)
		local character = state and state.character
		local targetHumanoid = state and state.humanoid
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		if targetRoot and targetRoot:IsA("BasePart") and targetHumanoid and targetHumanoid.Health > 0 then
			if (targetRoot.Position - center).Magnitude <= radius then
				targetHumanoid:TakeDamage(damage)
				PlayerService.hitReaction(player, true)
			end
		end
	end
end

local function damagePlayersOnSegment(a: Vector3, b: Vector3, radius: number, damage: number)
	local flatA, flatB = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
	for player in participants do
		local state = PlayerService.get(player)
		local character = state and state.character
		local targetHumanoid = state and state.humanoid
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		if targetRoot and targetRoot:IsA("BasePart") and targetHumanoid and targetHumanoid.Health > 0 then
			local flatPoint = Vector3.new(targetRoot.Position.X, 0, targetRoot.Position.Z)
			if distanceToSegment(flatPoint, flatA, flatB) <= radius then
				targetHumanoid:TakeDamage(damage)
				PlayerService.hitReaction(player, true)
			end
		end
	end
end

local function fireBossTelegraph(position: Vector3, radius: number, duration: number)
	feedback:FireAllClients(Net.Feedback.WardenTelegraph, { position = position, radius = radius, duration = duration })
end

local function bossLabel(): string
	if not boss then
		return string.upper(Config.Boss.Name)
	end
	local base = string.upper(Config.Boss.Name)
	if boss.phase == "Signal" then
		return `{base} — {if boss.shielded then "SIGNAL" else "EXPOSED"}`
	elseif boss.phase == "Desperation" then
		return `{base} — DESPERATE`
	end
	return base
end

local function pushBossStatusTo(player: Player)
	if not boss then
		feedback:FireClient(player, Net.Feedback.EnemyStatus, { active = false })
		return
	end
	feedback:FireClient(player, Net.Feedback.EnemyStatus, {
		active = true,
		label = bossLabel(),
		current = math.max(boss.humanoid.Health, 0),
		max = boss.humanoid.MaxHealth,
	})
end

local function broadcastBossStatus()
	for player in participants do
		if player.Parent then
			pushBossStatusTo(player)
		end
	end
end

-- Generic "no enemy status bar right now" - used both to clear the Warden status bar
-- when the grunt wave ends and to clear the boss bar once it falls.
local function hideEnemyStatus()
	for player in participants do
		if player.Parent then
			feedback:FireClient(player, Net.Feedback.EnemyStatus, { active = false })
		end
	end
end

local function setShielded(active: boolean)
	if not boss then
		return
	end
	boss.shielded = active
	boss.model:SetAttribute("ShieldMultiplier", if active then Config.Boss.ShieldDamageMultiplier else 1)
end

local function createWarden(position: Vector3): Model
	local model = WardenRig.build(container, position, Config.Warden.MaxHealth, Config.Warden.WalkSpeed)
	model:SetAttribute("ArenaHome", position)
	CollectionService:AddTag(model, CombatService.WardenTag)
	wardenAttack[model] = { phase = "Idle", windupEnd = 0, readyAt = 0, targetId = nil }
	return model
end

local function createPylon(position: Vector3): Model
	local model = WardenRig.buildPylon(container, position, Config.Boss.PylonHealth)
	CollectionService:AddTag(model, CombatService.WardenTag)
	return model
end

local function clearWardens()
	for _, model in wardens do
		if model.Parent then
			CollectionService:RemoveTag(model, CombatService.WardenTag)
			model:Destroy()
		end
	end
	table.clear(wardens)
	table.clear(wardenAttack)
	aliveCount = 0
	totalCount = 0
end

local function clearPylons()
	for _, model in pylons do
		if model.Parent then
			CollectionService:RemoveTag(model, CombatService.WardenTag)
			model:Destroy()
		end
	end
	table.clear(pylons)
end

local function clearBossAdds()
	for _, model in bossAdds do
		wardenAttack[model] = nil -- adds share the grunt attack-state table
		if model.Parent then
			CollectionService:RemoveTag(model, CombatService.WardenTag)
			WardenRig.remove(model)
			model:Destroy()
		end
	end
	table.clear(bossAdds)
end

-- Full teardown: destroys the boss body (if any), every add and every pylon.
-- Called by EncounterService.start() (a fresh run) and resetIfEmpty() (the
-- last participant left), so no encounter state can outlive its own chamber.
local function clearBoss()
	if boss and boss.model.Parent then
		CollectionService:RemoveTag(boss.model, CombatService.WardenTag)
		WardenRig.remove(boss.model)
		boss.model:Destroy()
	end
	boss = nil
	clearBossAdds()
	clearPylons()
end

-- Runs once, however many participants are in the chamber: each player's own
-- Chapter1_Victory callback calls this, but `boss` already being set is what
-- keeps a second or third caller from spawning a second body.
local function beginBoss()
	if boss or not world then
		return
	end
	encounterState = "Boss"

	local center = world.ArenaCenter
	local spawnPosition = center + Vector3.new(0, 0, Config.Encounter.Opening.ForwardOffset - 10)
	local model = WardenRig.build(container, spawnPosition, Config.Boss.MaxHealth, Config.Boss.WalkSpeed, { scale = Config.Boss.Scale, isBoss = true })
	model.Name = "Harrower"
	model:SetAttribute("ArenaHome", spawnPosition)
	CollectionService:AddTag(model, CombatService.WardenTag)

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model.PrimaryPart :: BasePart

	boss = {
		model = model,
		humanoid = humanoid,
		root = root,
		phase = "Hunter",
		shielded = false,
		attack = { phase = "Idle", kind = nil, windupEnd = 0, readyAt = 0, cooldowns = {}, targetPos = nil, lineEnd = nil },
	}

	humanoid.Died:Connect(function()
		local defeated = boss
		if not defeated or defeated.model ~= model then
			return
		end
		defeated.phase = "Defeated"
		defeated.attack.phase = "Idle"
		defeated.attack.kind = nil

		WardenRig.setTelegraph(model, false)
		WardenRig.setAnimation(model, "Defeat")
		clearBossAdds()
		clearPylons()

		encounterState = "Cleared"
		hideEnemyStatus()
		broadcastObjective("Cleared", false)
		broadcastEncounter("Cleared")
		for player in participants do
			DialogueService.play(player, "Chapter1_BossVictory")
			SaveService.markStage(player, "Scene09_ChapterEnding")
		end

		task.delay(Config.Boss.DefeatLingerSeconds, function()
			WardenRig.remove(model)
			if model.Parent then
				CollectionService:RemoveTag(model, CombatService.WardenTag)
				model:Destroy()
			end
			if boss == defeated then
				boss = nil
			end
		end)
	end)

	broadcastObjective("Boss", false)
	broadcastEncounter("Active")
	broadcastBossStatus()
end

local function onWardenDied(model: Model)
	if aliveCount <= 0 then
		return
	end
	aliveCount -= 1
	WardenRig.setTelegraph(model, false)
	WardenRig.setAnimation(model, "Idle")
	WardenRig.remove(model)
	wardenAttack[model] = nil

	CollectionService:RemoveTag(model, CombatService.WardenTag)
	task.delay(2.5, function()
		if model.Parent then
			model:Destroy()
		end
	end)

	if aliveCount > 0 then
		broadcastObjective("Combat", true)
		broadcastEncounter("Active")
		broadcastWardenStatus()
		return
	end

	-- The scout wave is down. Aegis Zero's line plays for every participant, and
	-- whichever finishes first actually brings the Harrower in -
	-- beginBoss() is idempotent (it bails once `boss` is already set), so it is
	-- safe to hand it to every player's own callback rather than picking one.
	encounterState = "Boss"
	broadcastEncounter("Active")
	hideEnemyStatus() -- clears the Warden status bar; beginBoss() raises the boss bar once Aegis Zero's line finishes
	for player in participants do
		DialogueService.play(player, "Chapter1_Victory", beginBoss)
	end
end

function EncounterService.start()
	clearWardens()
	clearBoss()
	encounterState = "Active"

	local center = world.ArenaCenter
	local spread = Config.Encounter.Opening.SpawnSpread
	local count = Config.Warden.Count
	for index = 1, count do
		local offset = Vector3.new((index - (count + 1) / 2) * spread, 0, Config.Encounter.Opening.ForwardOffset)
		local model = createWarden(center + offset)
		table.insert(wardens, model)
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			onWardenDied(model)
		end)
	end
	aliveCount = count
	totalCount = count

	broadcastObjective("Combat", true)
	broadcastEncounter("Active")
	broadcastWardenStatus()
end

function EncounterService.isActive(): boolean
	return encounterState == "Active"
end

function EncounterService.addParticipant(player: Player)
	participants[player] = true
end

local function cancelRetryTimer(player: Player)
	local timer = retryTimers[player]
	if timer then
		task.cancel(timer)
		retryTimers[player] = nil
	end
end

--[[
	Retry resets the player, and resets the encounter itself when nobody else is
	still fighting it. With another pilot alive in the chamber the retrying
	player rejoins the fight in progress instead of wiping their run.
]]
function EncounterService.retry(player: Player)
	cancelRetryTimer(player)

	local state = PlayerService.get(player)
	if not state then
		return
	end

	local humanoid = state.humanoid
	if humanoid and humanoid.Health > 0 then
		return -- only a dead pilot may retry
	end

	local othersFighting = false
	for other in participants do
		if other ~= player then
			local otherState = PlayerService.get(other)
			local otherHumanoid = otherState and otherState.humanoid
			if otherHumanoid and otherHumanoid.Health > 0 then
				othersFighting = true
				break
			end
		end
	end

	if state.inRuin and not othersFighting and encounterState ~= "Idle" then
		EncounterService.start()
	end

	PlayerService.respawn(player)
end

-- Once the chamber is empty the encounter goes back to Idle so a later descent
-- starts a fresh fight instead of walking into a cleared, empty room.
local function resetIfEmpty()
	for participant in participants do
		local state = PlayerService.get(participant)
		if participant.Parent and state and state.inRuin then
			return
		end
	end
	clearWardens()
	clearBoss()
	encounterState = "Idle"
end

function EncounterService.returnToSurface(player: Player)
	cancelRetryTimer(player)
	local state = PlayerService.get(player)
	if not state then
		return
	end
	participants[player] = nil
	PlayerService.forceHuman(player)
	PlayerService.setCheckpoint(player, world.CitySpawn, false)
	if state.humanoid and state.humanoid.Health > 0 then
		PlayerService.teleport(player, world.CitySpawn)
	else
		PlayerService.respawn(player)
	end
	pushObjective(player, "City", false)
	feedback:FireClient(player, Net.Feedback.Encounter, { state = "Idle", remaining = 0, total = 0 })
	feedback:FireClient(player, Net.Feedback.EnemyStatus, { active = false })
	resetIfEmpty()
end

function EncounterService.onDescend(player: Player)
	local state = PlayerService.get(player)
	if not state then
		return
	end

	participants[player] = true
	PlayerService.setCheckpoint(player, world.RuinSpawn, true)
	PlayerService.teleport(player, world.RuinSpawn)
	pushObjective(player, "Chamber", false)
	SaveService.markStage(player, "Scene06_AegisChamber")

	DialogueService.play(player, "Chapter1_Awakening", function()
		if not player.Parent then
			return
		end
		player:SetAttribute("CanTransform", true)
		PlayerService.pushTransformState(player)
		pushObjective(player, "Chamber", false)
	end)
end

local function onPlayerDied(player: Player)
	if not participants[player] then
		-- Died in the city: still offer a retry, just without an encounter reset.
		feedback:FireClient(player, Net.Feedback.Encounter, { state = "Failed", remaining = 0, total = 0 })
	else
		DialogueService.cancel(player)
		pushEncounter(player, "Failed")
	end

	cancelRetryTimer(player)
	retryTimers[player] = task.delay(Config.Encounter.RetryFallbackSeconds, function()
		retryTimers[player] = nil
		if player.Parent then
			EncounterService.retry(player)
		end
	end)
end

local function onTransformChanged(player: Player, active: boolean)
	if not active then
		return
	end
	local state = PlayerService.get(player)
	if not (state and state.inRuin) then
		return
	end
	if encounterState == "Idle" then
		DialogueService.play(player, "Chapter1_FirstTransform")
		EncounterService.start()
	end
end

local thinkAccumulator = 0

local function nearestTarget(root: BasePart): (Model?, Humanoid?, number)
	local nearestCharacter: Model? = nil
	local nearestHumanoid: Humanoid? = nil
	local nearestDistance = Config.Warden.AggroRange

	for player in participants do
		local state = PlayerService.get(player)
		local character = state and state.character
		local targetHumanoid = state and state.humanoid
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if state and not state.inMenu and character and targetHumanoid and targetRoot and targetHumanoid.Health > 0 then
			local distance = (targetRoot.Position - root.Position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestCharacter = character
				nearestHumanoid = targetHumanoid
			end
		end
	end

	return nearestCharacter, nearestHumanoid, nearestDistance
end

--[[
	One Warden's turn.

	Attack timing, in order:
	  Chase   -> target within AttackRange and off cooldown
	  Windup  -> telegraph on, movement stopped, lasts WindupTime
	  Strike  -> damage applied IF the target is still inside the same
	             AttackRange the telegraph showed
	  Recover -> telegraph off, RecoverTime of vulnerability, then cooldown

	There is deliberately no separate "warning radius" value: the telegraph and
	the damage check both read Config.Warden.AttackRange.
]]
local function thinkOne(enemy: Model, now: number)
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	local root = enemy.PrimaryPart
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local home = enemy:GetAttribute("ArenaHome")
	BoundaryService.keepEnemyInRuin(enemy, if typeof(home) == "Vector3" then home else world.ArenaCenter)

	local attack = wardenAttack[enemy]
	if not attack then
		attack = { phase = "Idle", windupEnd = 0, readyAt = 0, targetId = nil }
		wardenAttack[enemy] = attack
	end

	if attack.phase == "Windup" then
		if now < attack.windupEnd then
			WardenRig.setAnimation(enemy, "Windup")
			humanoid:MoveTo(root.Position) -- committed: hold position
			return
		end

		-- Strike. Re-check against the very range the telegraph displayed.
		WardenRig.setAnimation(enemy, "Strike")
		local character, targetHumanoid, distance = nearestTarget(root)
		WardenRig.setTelegraph(enemy, false)
		if character and targetHumanoid and distance <= Config.Warden.AttackRange then
			local targetRoot = character:FindFirstChild("HumanoidRootPart")
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { enemy, character }
			params.RespectCanCollide = true
			if targetRoot and targetRoot:IsA("BasePart") and workspace:Raycast(root.Position, targetRoot.Position - root.Position, params) == nil then
				targetHumanoid:TakeDamage(Config.Warden.Damage)
				local targetPlayer = Players:GetPlayerFromCharacter(character)
				if targetPlayer then PlayerService.hitReaction(targetPlayer, false) end
			end
		end
		attack.phase = "Recover"
		attack.readyAt = now + Config.Warden.RecoverTime
		return
	end

	if attack.phase == "Recover" then
		WardenRig.setAnimation(enemy, "Recover")
		if now < attack.readyAt then
			return
		end
		attack.phase = "Idle"
		attack.readyAt = now + Config.Warden.AttackCooldown - Config.Warden.RecoverTime
		return
	end

	local character, _, distance = nearestTarget(root)
	if not character then
		return
	end
	local targetRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not targetRoot then
		return
	end

	if distance > Config.Warden.AttackRange then
		humanoid:MoveTo(targetRoot.Position)
		return
	end

	if now < attack.readyAt then
		humanoid:MoveTo(root.Position)
		return
	end

	attack.phase = "Windup"
	WardenRig.setAnimation(enemy, "Windup")
	attack.windupEnd = now + Config.Warden.WindupTime
	WardenRig.setTelegraph(enemy, true)
	feedback:FireAllClients(Net.Feedback.WardenTelegraph, {
		position = root.Position,
		radius = Config.Warden.AttackRange,
		duration = Config.Warden.WindupTime,
	})
end

--------------------------------------------------------------------------------
-- the Harrower AI. Mirrors thinkOne()'s Windup/Strike/Recover shape, but
-- with several attack kinds sharing one state machine instead of one.
--------------------------------------------------------------------------------

local function lineClearToTarget(target: Model, targetPosition: Vector3): boolean
	if not boss then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { boss.model, target }
	params.RespectCanCollide = true
	return workspace:Raycast(boss.root.Position, targetPosition - boss.root.Position, params) == nil
end

local function bossCooldownScale(): number
	return if boss and boss.phase == "Desperation" then Config.Boss.DesperationCooldownScale else 1
end

local function chooseBossAttack(now: number, distance: number): string?
	if not boss then
		return nil
	end
	local options: { string } = {}
	local cooldowns = boss.attack.cooldowns
	if distance <= Config.Boss.ClawRange + 5 and now >= (cooldowns.Claw or 0) then
		table.insert(options, "Claw")
	end
	if now >= (cooldowns.Leap or 0) then
		table.insert(options, "Leap")
	end
	if now >= (cooldowns.Line or 0) then
		table.insert(options, "Line")
	end
	if boss.phase == "Desperation" and now >= (cooldowns.Shockring or 0) then
		table.insert(options, "Shockring")
	end
	if #options == 0 then
		return nil
	end
	return options[math.random(1, #options)]
end

local function startBossAttack(kind: string, now: number, targetPosition: Vector3)
	if not boss then
		return
	end
	local spec = BOSS_ATTACK_SPEC[kind]
	local attack = boss.attack
	attack.phase = "Windup"
	attack.kind = kind
	attack.windupEnd = now + spec.windup
	WardenRig.setAnimation(boss.model, "Windup")

	if kind == "Claw" then
		WardenRig.setTelegraph(boss.model, true)
		fireBossTelegraph(boss.root.Position, Config.Boss.ClawRange, spec.windup)
	elseif kind == "Leap" then
		attack.targetPos = targetPosition
		fireBossTelegraph(targetPosition, Config.Boss.LeapRadius, spec.windup)
	elseif kind == "Line" then
		local origin = boss.root.Position
		local direction = Vector3.new(targetPosition.X - origin.X, 0, targetPosition.Z - origin.Z)
		direction = if direction.Magnitude > 0.1 then direction.Unit else Vector3.new(boss.root.CFrame.LookVector.X, 0, boss.root.CFrame.LookVector.Z)
		local lineEnd = origin + direction * Config.Boss.LineLength
		attack.lineEnd = lineEnd
		for step = 1, Config.Boss.LineSteps do
			fireBossTelegraph(origin:Lerp(lineEnd, step / Config.Boss.LineSteps), Config.Boss.LineRadius, spec.windup)
		end
	elseif kind == "Shockring" then
		fireBossTelegraph(boss.root.Position, Config.Boss.ShockringRadius, spec.windup)
	end
end

local function resolveBossAttack(now: number)
	if not boss then
		return
	end
	local attack = boss.attack
	local kind = attack.kind
	if not kind then
		attack.phase = "Idle"
		return
	end
	local spec = BOSS_ATTACK_SPEC[kind]
	local model = boss.model

	WardenRig.setAnimation(model, "Strike")
	WardenRig.setTelegraph(model, false)

	if kind == "Claw" then
		local character, targetHumanoid, distance = nearestTarget(boss.root)
		if character and targetHumanoid and distance <= Config.Boss.ClawRange then
			local targetRoot = character:FindFirstChild("HumanoidRootPart")
			if targetRoot and targetRoot:IsA("BasePart") and lineClearToTarget(character, targetRoot.Position) then
				targetHumanoid:TakeDamage(Config.Boss.ClawDamage)
				local targetPlayer = Players:GetPlayerFromCharacter(character)
				if targetPlayer then
					PlayerService.hitReaction(targetPlayer, true)
				end
			end
		end
	elseif kind == "Leap" and attack.targetPos then
		local destination = attack.targetPos
		local startPosition = boss.root.Position
		task.spawn(function()
			for step = 1, 5 do
				if not model.Parent then
					return
				end
				model:PivotTo(CFrame.lookAt(startPosition:Lerp(destination, step / 5), destination))
				task.wait(0.05)
			end
			if model.Parent then
				damagePlayersInRadius(destination, Config.Boss.LeapRadius, Config.Boss.LeapDamage)
				feedback:FireAllClients(Net.Feedback.WardenHit, { position = destination, died = false })
			end
		end)
	elseif kind == "Line" and attack.lineEnd then
		damagePlayersOnSegment(boss.root.Position, attack.lineEnd, Config.Boss.LineRadius, Config.Boss.LineDamage)
		feedback:FireAllClients(Net.Feedback.WardenHit, { position = attack.lineEnd, died = false })
	elseif kind == "Shockring" then
		damagePlayersInRadius(boss.root.Position, Config.Boss.ShockringRadius, Config.Boss.ShockringDamage)
		feedback:FireAllClients(Net.Feedback.WardenHit, { position = boss.root.Position, died = false })
	end

	attack.cooldowns[kind] = now + spec.cooldown * bossCooldownScale()
	attack.phase = "Recover"
	attack.readyAt = now + spec.recover
	attack.kind = nil
	attack.targetPos = nil
	attack.lineEnd = nil
end

-- Health-fraction phase transitions. Independent of each other on purpose:
-- a player who ignores the Signal-phase pylons only fights a slower fight
-- (see Config.Boss.ShieldDamageMultiplier), never a stuck one.
local function checkBossPhaseTransitions()
	if not boss or boss.phase == "Defeated" then
		return
	end
	local fraction = boss.humanoid.Health / math.max(boss.humanoid.MaxHealth, 1)

	if boss.phase == "Hunter" and fraction <= Config.Boss.SignalHealthFraction then
		boss.phase = "Signal"
		setShielded(true)
		local center = boss.root.Position

		for index = 1, Config.Boss.SignalAddCount do
			local offset = Vector3.new((index - (Config.Boss.SignalAddCount + 1) / 2) * 12, 0, -10)
			local add = createWarden(center + offset)
			table.insert(bossAdds, add)
			local addHumanoid = add:FindFirstChildOfClass("Humanoid") :: Humanoid
			addHumanoid.MaxHealth = Config.Boss.SignalAddHealth
			addHumanoid.Health = Config.Boss.SignalAddHealth
			addHumanoid.Died:Connect(function()
				local index2 = table.find(bossAdds, add)
				if index2 then
					table.remove(bossAdds, index2)
				end
				wardenAttack[add] = nil
				WardenRig.remove(add)
				CollectionService:RemoveTag(add, CombatService.WardenTag)
				task.delay(2.5, function()
					if add.Parent then
						add:Destroy()
					end
				end)
			end)
		end

		for index = 1, Config.Boss.PylonCount do
			local offset = Vector3.new((index - (Config.Boss.PylonCount + 1) / 2) * 20, 0, 6)
			table.insert(pylons, createPylon(center + offset))
		end
		for _, model in pylons do
			local pylonHumanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
			pylonHumanoid.Died:Connect(function()
				local index2 = table.find(pylons, model)
				if index2 then
					table.remove(pylons, index2)
				end
				WardenRig.powerDownPylon(model)
				CollectionService:RemoveTag(model, CombatService.WardenTag)
				task.delay(3, function()
					if model.Parent then
						model:Destroy()
					end
				end)
			end)
		end

		for player in participants do
			DialogueService.play(player, "Chapter1_BossSignal")
		end
		broadcastBossStatus()
	end

	-- Not gated to the Signal phase specifically: a player who pushes the boss
	-- into Desperation without clearing the pylons first should still be
	-- rewarded for destroying them afterward, rather than staying shielded
	-- for the rest of the fight.
	if boss.shielded and #pylons == 0 then
		setShielded(false)
		broadcastBossStatus()
	end

	if boss.phase ~= "Desperation" and fraction <= Config.Boss.DesperationHealthFraction then
		boss.phase = "Desperation"
		boss.humanoid.WalkSpeed = Config.Boss.DesperationWalkSpeed
		for player in participants do
			feedback:FireClient(player, Net.Feedback.Notice, { text = "The Harrower is desperate." })
		end
		broadcastBossStatus()
	end
end

local function thinkBoss(now: number)
	if not boss then
		return
	end
	local humanoid, root, model = boss.humanoid, boss.root, boss.model
	if humanoid.Health <= 0 or not root.Parent then
		return
	end
	local home = model:GetAttribute("ArenaHome")
	BoundaryService.keepEnemyInRuin(model, if typeof(home) == "Vector3" then home else world.ArenaCenter)

	local attack = boss.attack

	if attack.phase == "Windup" then
		if now < attack.windupEnd then
			WardenRig.setAnimation(model, "Windup")
			humanoid:MoveTo(root.Position) -- committed, like a grunt's windup: the telegraph is a promise
			return
		end
		resolveBossAttack(now)
		return
	end

	if attack.phase == "Recover" then
		WardenRig.setAnimation(model, "Recover")
		if now < attack.readyAt then
			return
		end
		attack.phase = "Idle"
		return
	end

	local character, _, distance = nearestTarget(root)
	if not character then
		return
	end
	local targetRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return
	end

	local kind = chooseBossAttack(now, distance)
	if kind then
		startBossAttack(kind, now, targetRoot.Position)
		return
	end

	if distance > Config.Boss.ClawRange then
		humanoid:MoveTo(targetRoot.Position)
	else
		humanoid:MoveTo(root.Position)
	end
end

local function think()
	if encounterState ~= "Active" and encounterState ~= "Boss" then
		return
	end
	local now = os.clock()
	for _, enemy in wardens do
		if enemy.Parent then
			thinkOne(enemy, now)
		end
	end
	for _, enemy in bossAdds do
		if enemy.Parent then
			thinkOne(enemy, now)
		end
	end
	if boss and boss.phase ~= "Defeated" then
		checkBossPhaseTransitions()
		thinkBoss(now)
	end
end

function EncounterService.clearPlayer(player: Player)
	participants[player] = nil
	cancelRetryTimer(player)
	resetIfEmpty()
end

function EncounterService.onPlayerReady(player: Player)
	local state = PlayerService.get(player)
	if state and state.inRuin then
		participants[player] = true
		if encounterState == "Cleared" then
			pushObjective(player, "Cleared", false)
			pushEncounter(player, "Cleared")
			feedback:FireClient(player, Net.Feedback.EnemyStatus, { active = false })
		elseif encounterState == "Boss" then
			pushObjective(player, "Boss", false)
			pushEncounter(player, "Active")
			pushBossStatusTo(player)
		else
			pushObjective(player, "Combat", true)
			pushEncounter(player, "Active")
			pushWardenStatusTo(player)
		end
	else
		pushObjective(player, "City", false)
		feedback:FireClient(player, Net.Feedback.Encounter, { state = "Idle", remaining = 0, total = 0 })
		feedback:FireClient(player, Net.Feedback.EnemyStatus, { active = false })
	end
end

function EncounterService.init(builtWorld: any)
	world = builtWorld
	feedback = Net.get("Feedback")

	local existing = workspace:FindFirstChild("ChapterEncounter")
	if existing then
		existing:Destroy()
	end
	container = Instance.new("Folder")
	container.Name = "ChapterEncounter"
	container.Parent = workspace

	PlayerService.Died:Connect(onPlayerDied)
	PlayerService.TransformChanged:Connect(onTransformChanged)
	Players.PlayerRemoving:Connect(EncounterService.clearPlayer)
	CombatService.WardenDamaged:Connect(function()
		if encounterState == "Active" then
			broadcastWardenStatus()
		elseif encounterState == "Boss" then
			broadcastBossStatus()
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		thinkAccumulator += dt
		if thinkAccumulator < 0.2 then
			return
		end
		thinkAccumulator = 0
		think()
	end)
end

return EncounterService
