--!nonstrict
-- Server authority for Aegis Zero actions. Clients may name an ability and supply
-- an aim direction; timing, movement, hits, damage and charge remain here.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local BoundaryService = require(script.Parent.BoundaryService)
local WardenRig = require(script.Parent.WardenRig)
local PlayerService = require(script.Parent.PlayerService)
local MechaAnimator = require(script.Parent.MechaAnimator)

local CombatService = {}
CombatService.WardenTag = "SkyWarden"
CombatService.WardenDamaged = Signal.new() -- (model, damage, player, ability)
CombatService.AbilityUsed = Signal.new() -- (player, ability) - fires once a cast is accepted

type CombatState = { token: number, busyUntil: number, cooldowns: { [string]: number }, comboStep: number, comboExpires: number, charge: number }
local states: { [Player]: CombatState } = {}
local feedback: RemoteEvent

local function stateFor(player: Player): CombatState
	local state = states[player]
	if state then return state end
	state = { token = 0, busyUntil = 0, cooldowns = {}, comboStep = 0, comboExpires = 0, charge = 0 }
	states[player] = state
	return state
end

local function finiteVector(value: any): boolean
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < 100000 and math.abs(value.Y) < 100000 and math.abs(value.Z) < 100000
end

local function reject(player: Player, ability: string, reason: string): boolean
	local state = stateFor(player)
	feedback:FireClient(player, Net.Feedback.AbilityState, { ability = ability, accepted = false, reason = reason, charge = state.charge, required = Config.Aegis.Abilities.CoreBurst.ChargeRequired })
	return false
end

local function rootFor(player: Player): (Model?, BasePart?)
	local playerState = PlayerService.get(player)
	local character = playerState and playerState.character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, if root and root:IsA("BasePart") then root else nil
end

local function accepted(player: Player, ability: string, cooldown: number)
	local state = stateFor(player)
	state.cooldowns[ability] = os.clock() + cooldown
	feedback:FireClient(player, Net.Feedback.Cooldown, { ability = ability, duration = cooldown })
	feedback:FireClient(player, Net.Feedback.AbilityState, { ability = ability, accepted = true })
	CombatService.AbilityUsed:Fire(player, ability)
end

local function begin(player: Player, ability: string, totalTime: number, cooldown: number, movementLocked: boolean, requireTransform: boolean?): number?
	if not PlayerService.isPlayable(player) then
		reject(player, ability, "Unavailable while incapacitated")
		return nil
	end
	if requireTransform ~= false and not PlayerService.isTransformed(player) then
		reject(player, ability, "Aegis Zero form required")
		return nil
	end
	local state = stateFor(player)
	local now = os.clock()
	if now < state.busyUntil then
		reject(player, ability, "Another action is active")
		return nil
	end
	if now < (state.cooldowns[ability] or 0) then
		reject(player, ability, "Cooling down")
		return nil
	end
	state.token += 1
	state.busyUntil = now + totalTime
	accepted(player, ability, cooldown)
	if movementLocked then PlayerService.setCombatLocked(player, true) end
	local token = state.token
	task.delay(totalTime, function()
		local live = states[player]
		if live and live.token == token then
			live.busyUntil = 0
			PlayerService.setCombatLocked(player, false)
		end
	end)
	return token
end

local function active(player: Player, token: number, requireTransform: boolean?): boolean
	local state = states[player]
	if state == nil or state.token ~= token or not PlayerService.isPlayable(player) then
		return false
	end
	return requireTransform == false or PlayerService.isTransformed(player)
end

local function lineClear(character: Model, enemy: Model, origin: Vector3, target: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, enemy }
	params.RespectCanCollide = true
	return workspace:Raycast(origin, target - origin, params) == nil
end

local function addCharge(player: Player, amount: number)
	local state = stateFor(player)
	local required = Config.Aegis.Abilities.CoreBurst.ChargeRequired
	state.charge = math.clamp(state.charge + amount, 0, required)
	feedback:FireClient(player, Net.Feedback.AbilityState, { ability = "CoreBurst", charge = state.charge, required = required })
end

local function damageArea(player: Player, origin: Vector3, radius: number, damage: number, chargeGain: number, forward: Vector3?, ability: string?): (number, number)
	local character = rootFor(player)
	if not character then return 0, 0 end
	local hits, kills = 0, 0
	local hitModels: { [Model]: boolean } = {}
	for _, tagged in CollectionService:GetTagged(CombatService.WardenTag) do
		if not tagged:IsA("Model") or hitModels[tagged] or not tagged.Parent then continue end
		local enemyRoot = tagged.PrimaryPart
		local enemyHumanoid = tagged:FindFirstChildOfClass("Humanoid")
		if not enemyRoot or not enemyHumanoid or enemyHumanoid.Health <= 0 then continue end
		local offset = enemyRoot.Position - origin
		if offset.Magnitude > radius then continue end
		if forward and offset.Magnitude > 0.1 and forward:Dot(offset.Unit) < -0.12 then continue end
		if not lineClear(character, tagged, origin, enemyRoot.Position) then continue end
		hitModels[tagged] = true
		-- A Signal-phase boss reduces incoming damage rather than blocking it
		-- outright (see EncounterService.lua) - ShieldMultiplier is read
		-- generically here so CombatService never needs to know a boss exists.
		local shieldMultiplier = tagged:GetAttribute("ShieldMultiplier")
		enemyHumanoid:TakeDamage(if typeof(shieldMultiplier) == "number" then damage * shieldMultiplier else damage)
		hits += 1
		local died = enemyHumanoid.Health <= 0
		if died then kills += 1 else WardenRig.flashHit(tagged) end
		feedback:FireAllClients(Net.Feedback.WardenHit, { position = enemyRoot.Position, died = died })
		CombatService.WardenDamaged:Fire(tagged, damage, player, ability)
	end
	if hits > 0 then addCharge(player, chargeGain * hits) end
	feedback:FireClient(player, Net.Feedback.Hit, { count = hits, killed = kills })
	return hits, kills
end

local function castCombo(player: Player): boolean
	local config = Config.Aegis.Abilities.Combo
	local combat = stateFor(player)
	local now = os.clock()
	local step = if now <= combat.comboExpires then combat.comboStep % 3 + 1 else 1
	local total = config.Windup[step] + config.Active[step] + config.Recovery[step]
	local token = begin(player, "Strike", total, total, false)
	if not token then return false end
	local playerState = PlayerService.get(player)
	if playerState and playerState.character then MechaAnimator.action(playerState.character, `Combo{step}`, total) end
	combat.comboStep = step
	combat.comboExpires = now + total + config.ResetTime
	local _, root = rootFor(player)
	if not root then return false end
	feedback:FireAllClients(Net.Feedback.AbilityVFX, { ability = "Strike", stage = "Begin", step = step, byUserId = player.UserId, origin = root.Position, direction = root.CFrame.LookVector, reach = config.Reach, radius = config.Range, windup = config.Windup[step], active = config.Active[step] })
	task.delay(config.Windup[step], function()
		if not active(player, token) then return end
		local _, liveRoot = rootFor(player)
		if not liveRoot then return end
		local center = liveRoot.Position + liveRoot.CFrame.LookVector * config.Reach
		damageArea(player, center, config.Range, config.Damage[step], config.ChargeGain[step], liveRoot.CFrame.LookVector, "Strike")
		feedback:FireAllClients(Net.Feedback.AbilityVFX, { ability = "Strike", stage = "Contact", step = step, position = center, radius = config.Range, byUserId = player.UserId })
	end)
	return true
end

local function castSlam(player: Player): boolean
	local config = Config.Aegis.Abilities.GroundSlam
	local playerState = PlayerService.get(player)
	if not playerState or not playerState.humanoid or playerState.humanoid.FloorMaterial == Enum.Material.Air then return reject(player, "GroundSlam", "Ground contact required") end
	local token = begin(player, "GroundSlam", config.Windup + config.Active + config.Recovery, config.Cooldown, true)
	if not token then return false end
	local slamState = PlayerService.get(player)
	if slamState and slamState.character then MechaAnimator.action(slamState.character, "GroundSlam", config.Windup + config.Active + config.Recovery) end
	local _, root = rootFor(player)
	if not root then return false end
	feedback:FireAllClients(Net.Feedback.AbilityVFX, { ability = "GroundSlam", stage = "Begin", position = root.Position, radius = config.Radius, windup = config.Windup, byUserId = player.UserId })
	task.delay(config.Windup, function()
		if not active(player, token) then return end
		local _, liveRoot = rootFor(player)
		if not liveRoot then return end
		damageArea(player, liveRoot.Position, config.Radius, config.Damage, config.ChargeGain, nil, "GroundSlam")
		feedback:FireAllClients(Net.Feedback.AbilityVFX, { ability = "GroundSlam", stage = "Contact", position = liveRoot.Position, radius = config.Radius, byUserId = player.UserId })
	end)
	return true
end

local function runBolt(player: Player, token: number, origin: Vector3, direction: Vector3)
	local config = Config.Aegis.Abilities.ResonanceBolt
	local position, travelled, previous = origin, 0, os.clock()
	local connection: RBXScriptConnection?
	connection = RunService.Heartbeat:Connect(function()
		if not active(player, token) then
			if connection then connection:Disconnect() end
			return
		end
		local now = os.clock()
		local distance = math.min(config.Speed * (now - previous), config.Range - travelled)
		previous = now
		if distance <= 0 then
			if connection then connection:Disconnect() end
			return
		end
		local segment = direction * distance
		local character = rootFor(player)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = if character then { character } else {}
		params.RespectCanCollide = false
		local hit = workspace:Raycast(position, segment, params)
		local nextPosition = if hit then hit.Position else position + segment
		travelled += (nextPosition - position).Magnitude
		position = nextPosition
		if hit or travelled >= config.Range or not BoundaryService.contains(BoundaryService.areaForPlayer(player), position, 3) then
			if connection then connection:Disconnect() end
			if hit then
				local model = hit.Instance:FindFirstAncestorOfClass("Model")
				if model and CollectionService:HasTag(model, CombatService.WardenTag) then damageArea(player, hit.Position, config.Radius, config.Damage, config.ChargeGain, nil, "ResonanceBolt") end
			end
			feedback:FireAllClients(Net.Feedback.AbilityVFX, { ability = "ResonanceBolt", stage = "Impact", position = position, radius = config.Radius, byUserId = player.UserId })
		end
	end)
end

local function castBolt(player: Player, payload: any): boolean
	local config = Config.Aegis.Abilities.ResonanceBolt
	if typeof(payload) ~= "table" or not finiteVector(payload.direction) or payload.direction.Magnitude < 0.5 then return reject(player, "ResonanceBolt", "Invalid aim") end
	local token = begin(player, "ResonanceBolt", config.Windup + config.Recovery, config.Cooldown, false)
	if not token then return false end
	local boltState = PlayerService.get(player)
	if boltState and boltState.character then MechaAnimator.action(boltState.character, "ResonanceBolt", config.Windup + config.Recovery) end
	local character, root = rootFor(player)
	if not character or not root then return false end
	local direction = payload.direction.Unit
	if root.CFrame.LookVector:Dot(direction) < -0.15 then direction = root.CFrame.LookVector end
	local origin = root.Position + Vector3.new(0, 3, 0) + direction * 4
	feedback:FireAllClients(Net.Feedback.AbilityVFX, { ability = "ResonanceBolt", stage = "Begin", position = origin, direction = direction, speed = config.Speed, range = config.Range, windup = config.Windup, byUserId = player.UserId })
	task.delay(config.Windup, function() if active(player, token) then runBolt(player, token, origin, direction) end end)
	return true
end

local function castDash(player: Player, payload: any): boolean
	local config = Config.Aegis.Abilities.ThrusterDash
	if typeof(payload) ~= "table" or not finiteVector(payload.direction) then return reject(player, "ThrusterDash", "Invalid direction") end
	local flat = Vector3.new(payload.direction.X, 0, payload.direction.Z)
	local _, root = rootFor(player)
	if not root then return reject(player, "ThrusterDash", "No movement root") end
	if flat.Magnitude < 0.2 then flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) end
	flat = flat.Unit
	local token = begin(player, "ThrusterDash", config.Windup + config.Active + config.Recovery, config.Cooldown, true)
	if not token then return false end
	local dashState = PlayerService.get(player)
	if dashState and dashState.character then MechaAnimator.action(dashState.character, "ThrusterDash", config.Windup + config.Active + config.Recovery) end
	feedback:FireAllClients(Net.Feedback.AbilityVFX, { ability = "ThrusterDash", stage = "Begin", position = root.Position, direction = flat, distance = config.Distance, windup = config.Windup, active = config.Active, byUserId = player.UserId })
	task.delay(config.Windup, function()
		if not active(player, token) then return end
		local character, liveRoot = rootFor(player)
		if not character or not liveRoot then return end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		params.RespectCanCollide = true
		local hit = workspace:Blockcast(liveRoot.CFrame, Vector3.new(5, 8, 5), flat * config.Distance, params)
		local distance = if hit then math.max(0, hit.Distance - 3) else config.Distance
		local destination = BoundaryService.clampDestination(BoundaryService.areaForPlayer(player), liveRoot.Position + flat * distance, 8)
		local delta = destination - liveRoot.Position
		for _ = 1, 5 do
			if not active(player, token) then return end
			character:PivotTo(character:GetPivot() + delta / 5)
			task.wait(config.Active / 5)
		end
	end)
	return true
end

local function castBurst(player: Player): boolean
	local config = Config.Aegis.Abilities.CoreBurst
	local combat = stateFor(player)
	if combat.charge < config.ChargeRequired then return reject(player, "CoreBurst", `Core charge {math.floor(combat.charge)} / {config.ChargeRequired}`) end
	local token = begin(player, "CoreBurst", config.Windup + config.Active + config.Recovery, config.Cooldown, true)
	if not token then return false end
	local burstState = PlayerService.get(player)
	if burstState and burstState.character then MechaAnimator.action(burstState.character, "CoreBurst", config.Windup + config.Active + config.Recovery) end
	combat.charge = 0
	local _, root = rootFor(player)
	if not root then return false end
	feedback:FireClient(player, Net.Feedback.AbilityState, { ability = "CoreBurst", charge = 0, required = config.ChargeRequired })
	feedback:FireAllClients(Net.Feedback.AbilityVFX, { ability = "CoreBurst", stage = "Begin", position = root.Position, radius = config.Radius, windup = config.Windup, byUserId = player.UserId })
	task.delay(config.Windup, function()
		if not active(player, token) then return end
		local _, liveRoot = rootFor(player)
		if not liveRoot then return end
		damageArea(player, liveRoot.Position, config.Radius, config.Damage, 0, nil, "CoreBurst")
		feedback:FireAllClients(Net.Feedback.AbilityVFX, { ability = "CoreBurst", stage = "Contact", position = liveRoot.Position, radius = config.Radius, byUserId = player.UserId })
	end)
	return true
end

--------------------------------------------------------------------------------
-- Chapter One, Scene 3's temporary human-form combat: a light strike, a
-- defensive shove (knockback, not much damage) and a dodge with brief
-- invulnerability. Reuses damageArea/MechaAnimator/the same busy/cooldown
-- state table the Aegis abilities use - only the transform gate differs
-- (begin/active's requireTransform=false) and the numbers come from
-- Config.HumanCombat instead of Config.Aegis. Gated on the player's
-- "HasEmergencyStaff" attribute (set by ChapterOneDirector.lua for the
-- duration of Scene 3's combat beat only).
--------------------------------------------------------------------------------

local function castHumanStrike(player: Player): boolean
	local config = Config.HumanCombat.Strike
	local total = config.Windup + config.Active + config.Recovery
	local token = begin(player, "Strike", total, config.Cooldown, false, false)
	if not token then return false end
	local playerState = PlayerService.get(player)
	if playerState and playerState.character then MechaAnimator.action(playerState.character, "Combo1", total) end
	local _, root = rootFor(player)
	if not root then return false end
	feedback:FireAllClients(Net.Feedback.AbilityVFX, { ability = "Strike", stage = "Begin", step = 1, byUserId = player.UserId, origin = root.Position, direction = root.CFrame.LookVector, reach = config.Reach, radius = config.Range, windup = config.Windup, active = config.Active })
	task.delay(config.Windup, function()
		if not active(player, token, false) then return end
		local _, liveRoot = rootFor(player)
		if not liveRoot then return end
		local center = liveRoot.Position + liveRoot.CFrame.LookVector * config.Reach
		damageArea(player, center, config.Range, config.Damage, 0, liveRoot.CFrame.LookVector, "Strike")
		feedback:FireAllClients(Net.Feedback.AbilityVFX, { ability = "Strike", stage = "Contact", step = 1, position = center, radius = config.Range, byUserId = player.UserId })
	end)
	return true
end

local function castHumanShove(player: Player): boolean
	local config = Config.HumanCombat.Shove
	local total = config.Windup + config.Active + config.Recovery
	local token = begin(player, "GroundSlam", total, config.Cooldown, true, false)
	if not token then return false end
	local playerState = PlayerService.get(player)
	if playerState and playerState.character then MechaAnimator.action(playerState.character, "Combo2", total) end
	local _, root = rootFor(player)
	if not root then return false end
	feedback:FireAllClients(Net.Feedback.AbilityVFX, { ability = "GroundSlam", stage = "Begin", position = root.Position, radius = config.Radius, windup = config.Windup, byUserId = player.UserId })
	task.delay(config.Windup, function()
		if not active(player, token, false) then return end
		local character, liveRoot = rootFor(player)
		if not character or not liveRoot then return end
		for _, tagged in CollectionService:GetTagged(CombatService.WardenTag) do
			if not tagged:IsA("Model") or not tagged.Parent then continue end
			local enemyRoot = tagged.PrimaryPart
			local enemyHumanoid = tagged:FindFirstChildOfClass("Humanoid")
			if not enemyRoot or not enemyHumanoid or enemyHumanoid.Health <= 0 then continue end
			local offset = enemyRoot.Position - liveRoot.Position
			if offset.Magnitude > config.Radius then continue end
			enemyHumanoid:TakeDamage(config.Damage)
			WardenRig.flashHit(tagged)
			enemyRoot.AssemblyLinearVelocity = Vector3.new(offset.Unit.X, 0.3, offset.Unit.Z) * config.Knockback
		end
		feedback:FireAllClients(Net.Feedback.AbilityVFX, { ability = "GroundSlam", stage = "Contact", position = liveRoot.Position, radius = config.Radius, byUserId = player.UserId })
	end)
	return true
end

local function castHumanDodge(player: Player, payload: any): boolean
	local config = Config.HumanCombat.Dodge
	if typeof(payload) ~= "table" or not finiteVector(payload.direction) then return reject(player, "ThrusterDash", "Invalid direction") end
	local flat = Vector3.new(payload.direction.X, 0, payload.direction.Z)
	local _, root = rootFor(player)
	if not root then return reject(player, "ThrusterDash", "No movement root") end
	if flat.Magnitude < 0.2 then flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) end
	flat = flat.Unit
	local total = config.Windup + config.Active + config.Recovery
	local token = begin(player, "ThrusterDash", total, config.Cooldown, true, false)
	if not token then return false end
	local dashState = PlayerService.get(player)
	if dashState and dashState.character then MechaAnimator.action(dashState.character, "ThrusterDash", total) end
	feedback:FireAllClients(Net.Feedback.AbilityVFX, { ability = "ThrusterDash", stage = "Begin", position = root.Position, direction = flat, distance = config.Distance, windup = config.Windup, active = config.Active, byUserId = player.UserId })
	player:SetAttribute("DodgeInvulnerable", true)
	task.delay(config.Windup, function()
		if not active(player, token, false) then player:SetAttribute("DodgeInvulnerable", false); return end
		local character, liveRoot = rootFor(player)
		if not character or not liveRoot then player:SetAttribute("DodgeInvulnerable", false); return end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		params.RespectCanCollide = true
		local hit = workspace:Blockcast(liveRoot.CFrame, Vector3.new(5, 8, 5), flat * config.Distance, params)
		local distance = if hit then math.max(0, hit.Distance - 3) else config.Distance
		local destination = BoundaryService.clampDestination(BoundaryService.areaForPlayer(player), liveRoot.Position + flat * distance, 8)
		local delta = destination - liveRoot.Position
		for _ = 1, 5 do
			if not active(player, token, false) then break end
			character:PivotTo(character:GetPivot() + delta / 5)
			task.wait(config.Active / 5)
		end
		task.delay(config.IFrameSeconds, function()
			player:SetAttribute("DodgeInvulnerable", false)
		end)
	end)
	return true
end

function CombatService.request(player: Player, ability: any, payload: any): boolean
	if typeof(ability) ~= "string" then return reject(player, "Strike", "Invalid request") end
	if not PlayerService.isTransformed(player) and player:GetAttribute("HasEmergencyStaff") == true then
		if ability == "Strike" then return castHumanStrike(player)
		elseif ability == "GroundSlam" then return castHumanShove(player)
		elseif ability == "ThrusterDash" then return castHumanDodge(player, payload) end
		return reject(player, ability, "Unavailable")
	end
	if ability == "Strike" then return castCombo(player)
	elseif ability == "GroundSlam" then return castSlam(player)
	elseif ability == "ResonanceBolt" then return castBolt(player, payload)
	elseif ability == "ThrusterDash" then return castDash(player, payload)
	elseif ability == "CoreBurst" then return castBurst(player) end
	return reject(player, ability, "Unknown ability")
end

function CombatService.attack(player: Player): boolean return CombatService.request(player, "Strike", nil) end

function CombatService.cancelPlayer(player: Player)
	local state = states[player]
	if state then
		state.token += 1
		state.busyUntil = 0
		state.comboStep = 0
	end
	PlayerService.setCombatLocked(player, false)
end

local function syncPlayer(player: Player, activeWarden: boolean)
	if not activeWarden then return end
	local state = stateFor(player)
	local now = os.clock()
	for ability, readyAt in state.cooldowns do
		local remaining = readyAt - now
		if remaining > 0 then feedback:FireClient(player, Net.Feedback.Cooldown, { ability = ability, duration = remaining }) end
	end
	feedback:FireClient(player, Net.Feedback.AbilityState, { ability = "CoreBurst", charge = state.charge, required = Config.Aegis.Abilities.CoreBurst.ChargeRequired })
end

function CombatService.clearPlayer(player: Player)
	CombatService.cancelPlayer(player)
	states[player] = nil
end

function CombatService.init()
	feedback = Net.get("Feedback")
	PlayerService.Interrupted:Connect(function(player: Player, reason: string)
		CombatService.cancelPlayer(player)
		if reason ~= "recovery" then
			local state = stateFor(player)
			state.charge = 0
			feedback:FireClient(player, Net.Feedback.AbilityState, { ability = "CoreBurst", charge = 0, required = Config.Aegis.Abilities.CoreBurst.ChargeRequired })
		end
	end)
	PlayerService.TransformChanged:Connect(syncPlayer)
end

return CombatService
