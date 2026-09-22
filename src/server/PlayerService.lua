--!strict
-- Authoritative per-player state: menu lock, bloodline unlock, Aegis form,
-- checkpoints and respawns. Nothing here trusts the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Signal = require(Shared.Signal)
local AegisRig = require(Shared.AegisRig) -- shared so the menu can also display it (MenuScene.lua)
local MechaAnimator = require(script.Parent.MechaAnimator)

export type State = {
	inMenu: boolean,
	transformed: boolean,
	-- "Human" | "Transforming" | "Aegis" | "Reverting"
	aegisState: string,
	sequenceToken: number,
	hasTransformed: boolean,
	lastTransform: number,
	checkpoint: CFrame,
	inRuin: boolean,
	baseWalkSpeed: number,
	baseJumpPower: number,
	baseJumpHeight: number,
	baseMaxHealth: number,
	character: Model?,
	humanoid: Humanoid?,
	connections: { RBXScriptConnection },
	safeCFrame: CFrame,
	lastSafeAt: number,
	recovering: boolean,
	combatLocked: boolean,
}

local PlayerService = {}

PlayerService.CharacterReady = Signal.new() -- (player, character, humanoid)
PlayerService.Died = Signal.new() -- (player)
PlayerService.TransformChanged = Signal.new() -- (player, active)
PlayerService.MenuChanged = Signal.new() -- (player, inMenu)
PlayerService.Interrupted = Signal.new() -- (player, reason)

local states: { [Player]: State } = {}
local feedback: RemoteEvent
local world: any = nil
local worldReady = false

local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50
local DEFAULT_JUMP_HEIGHT = 7.2

function PlayerService.get(player: Player): State?
	return states[player]
end

function PlayerService.isPlayable(player: Player): boolean
	local state = states[player]
	if not state or state.inMenu then
		return false
	end
	local humanoid = state.humanoid
	return humanoid ~= nil and humanoid.Health > 0
end

-- True only when Aegis Zero is fully online. Mid-sequence the player cannot
-- attack, which is what stops the transformation being used as an i-frame.
function PlayerService.isTransformed(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.aegisState == "Aegis"
end

function PlayerService.aegisState(player: Player): string
	local state = states[player]
	return if state then state.aegisState else "Human"
end

function PlayerService.hitReaction(player: Player, severe: boolean?)
	local state = states[player]
	if state and state.character and state.humanoid and state.humanoid.Health > 0 and state.aegisState == "Aegis" then
		MechaAnimator.action(state.character, "Hit", if severe then 0.34 else 0.18)
	end
end

local function send(player: Player, kind: string, payload: any)
	feedback:FireClient(player, kind, payload)
end

PlayerService.send = send

-- Aegis presentation lives in AegisRig; this module only decides *when*.

local function setScale(character: Model, humanoid: Humanoid, scale: number)
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		for _, name in { "BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "HeadScale" } do
			local value = humanoid:FindFirstChild(name)
			if value and value:IsA("NumberValue") then
				value.Value = scale
			end
		end
	else
		-- R6 has no scale values. Model:ScaleTo works but is guarded, because a
		-- failure here must not abort the transformation.
		local ok, err = pcall(function()
			character:ScaleTo(scale)
		end)
		if not ok then
			warn(`[Sky Broke] R6 scaling unavailable: {err}`)
		end
	end
end

-- Health is carried across the transform as a FRACTION, so toggling the Aegis
-- form can never be used as a free heal.
local function applyMaxHealth(humanoid: Humanoid, newMax: number)
	local previousMax = humanoid.MaxHealth
	local ratio = if previousMax > 0 then math.clamp(humanoid.Health / previousMax, 0, 1) else 1
	humanoid.MaxHealth = newMax
	humanoid.Health = math.clamp(newMax * ratio, 1, newMax)
end

local function lockMovement(state: State, humanoid: Humanoid, locked: boolean)
	if locked or state.combatLocked then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	else
		humanoid.WalkSpeed = if state.aegisState == "Aegis" then Config.Aegis.WalkSpeed else state.baseWalkSpeed
		humanoid.JumpPower = state.baseJumpPower
		humanoid.JumpHeight = state.baseJumpHeight
	end
end

function PlayerService.setCombatLocked(player: Player, locked: boolean)
	local state = states[player]
	if not state then return end
	state.combatLocked = locked
	local humanoid = state.humanoid
	if humanoid and humanoid.Health > 0 then
		lockMovement(state, humanoid, state.inMenu)
	end
end

function PlayerService.pushTransformState(player: Player, phase: string?, duration: number?)
	local state = states[player]
	if not state then
		return
	end
	send(player, Net.Feedback.Transform, {
		active = state.aegisState == "Aegis",
		busy = state.aegisState == "Transforming" or state.aegisState == "Reverting",
		unlocked = player:GetAttribute("CanTransform") == true,
		phase = phase,
		duration = duration,
	})
end

-- VFX goes to everyone so other players see the awakening; the client decides
-- what to do with it, and only the transforming player's own camera reacts.
local function broadcastVFX(player: Player, phase: string, duration: number?)
	feedback:FireAllClients(Net.Feedback.TransformVFX, {
		userId = player.UserId,
		phase = phase,
		duration = duration,
	})
end

--[[
	The transformation sequence. Runs on the server so the authoritative state
	can never drift from what the client is showing.

	Steps are expressed as fractions of the total duration, so the shortened
	repeat sequence keeps exactly the same rhythm.
]]
local SEQUENCE: { { at: number, action: string } } = {
	{ at = 0.22, action = "scale" },
	{ at = 0.30, action = "Legs" },
	{ at = 0.45, action = "Torso" },
	{ at = 0.60, action = "Arms" },
	{ at = 0.74, action = "Head" },
	{ at = 0.86, action = "ignite" },
	{ at = 1.00, action = "complete" },
}

local function abortSequence(player: Player, state: State, character: Model?, humanoid: Humanoid?)
	state.aegisState = "Human"
	state.transformed = false
	if character then
		MechaAnimator.setActive(character, false)
		MechaAnimator.clearAction(character)
		AegisRig.clear(character)
		if humanoid then
			setScale(character, humanoid, 1)
		end
		character:SetAttribute("AegisActive", false)
	end
	if humanoid and humanoid.Health > 0 then
		applyMaxHealth(humanoid, state.baseMaxHealth)
		lockMovement(state, humanoid, state.inMenu)
	end
	PlayerService.pushTransformState(player, "Abort")
	broadcastVFX(player, "Abort")
end

local function runTransform(player: Player, state: State, character: Model, humanoid: Humanoid, token: number)
	local duration = if state.hasTransformed then Config.Aegis.TransformDurationRepeat else Config.Aegis.TransformDuration
	local lockUntil = duration * Config.Aegis.MovementLockFraction

	PlayerService.pushTransformState(player, "Begin", duration)
	broadcastVFX(player, "Begin", duration)
	lockMovement(state, humanoid, true)

	local elapsed = 0
	local movementReleased = false

	local function stillValid(): boolean
		return state.sequenceToken == token
			and state.character == character
			and character.Parent ~= nil
			and humanoid.Health > 0
			and not state.inMenu
	end

	for _, step in SEQUENCE do
		local target = duration * step.at
		local wait = target - elapsed
		if wait > 0 then
			task.wait(wait)
			elapsed = target
		end

		if not stillValid() then
			abortSequence(player, state, character, humanoid)
			return
		end

		if not movementReleased and elapsed >= lockUntil then
			movementReleased = true
			-- Released mid-sequence, still at human speed until the core lights.
			humanoid.WalkSpeed = state.baseWalkSpeed
			humanoid.JumpPower = state.baseJumpPower
			humanoid.JumpHeight = state.baseJumpHeight
		end

		if step.action == "scale" then
			MechaAnimator.action(character, "Transform", duration)
			setScale(character, humanoid, Config.Aegis.Scale)
			AegisRig.applyUnderlayer(character)
			-- One frame for the rig to resize before plates are measured off it.
			task.wait()
		elseif step.action == "ignite" then
			AegisRig.ignite(character)
			applyMaxHealth(humanoid, Config.Aegis.MaxHealth)
			PlayerService.pushTransformState(player, "Core", duration)
			broadcastVFX(player, "Core", duration)
		elseif step.action == "complete" then
			state.aegisState = "Aegis"
			state.transformed = true
			state.hasTransformed = true
			character:SetAttribute("AegisActive", true)
			MechaAnimator.setActive(character, true)
			lockMovement(state, humanoid, state.inMenu)
			PlayerService.pushTransformState(player, "Complete", duration)
			broadcastVFX(player, "Complete", duration)
			PlayerService.TransformChanged:Fire(player, true)
		else
			AegisRig.buildGroup(character, humanoid, step.action)
			PlayerService.pushTransformState(player, step.action, duration)
		end
	end
end

local function runRevert(player: Player, state: State, character: Model, humanoid: Humanoid, token: number)
	local duration = Config.Aegis.RevertDuration
	PlayerService.pushTransformState(player, "Revert", duration)
	broadcastVFX(player, "Revert", duration)

	task.wait(duration * 0.6)
	if state.sequenceToken ~= token or state.character ~= character or character.Parent == nil then
		return
	end

	AegisRig.clear(character)
	MechaAnimator.setActive(character, false)
	MechaAnimator.clearAction(character)
	setScale(character, humanoid, 1)

	if humanoid.Health > 0 then
		applyMaxHealth(humanoid, state.baseMaxHealth)
	end

	state.aegisState = "Human"
	state.transformed = false
	character:SetAttribute("AegisActive", false)
	lockMovement(state, humanoid, state.inMenu)
	PlayerService.pushTransformState(player, "Human")
	broadcastVFX(player, "Human")
	PlayerService.TransformChanged:Fire(player, false)
end

--[[
	Entry point for a transform request. Returns (accepted, reason).

	Requests during a sequence are rejected outright rather than queued, which
	is what keeps repeated key presses from stacking sequences on top of each
	other or leaving the player half-armoured.
]]
function PlayerService.setTransformed(player: Player, enabled: boolean): (boolean, string?)
	local state = states[player]
	if not state then
		return false, "nostate"
	end
	if state.inMenu then
		return false, "menu"
	end
	if state.aegisState == "Transforming" or state.aegisState == "Reverting" then
		return false, "busy"
	end
	if enabled and player:GetAttribute("CanTransform") ~= true then
		return false, "locked"
	end

	local now = os.clock()
	if now - state.lastTransform < Config.Aegis.TransformCooldown then
		return false, "cooldown"
	end

	local character = state.character
	local humanoid = state.humanoid
	if not character or not humanoid or humanoid.Health <= 0 then
		return false, "nocharacter"
	end

	local isAegis = state.aegisState == "Aegis"
	if isAegis == enabled then
		return false, "nochange"
	end

	state.lastTransform = now
	PlayerService.Interrupted:Fire(player, "transform")
	state.sequenceToken += 1
	local token = state.sequenceToken

	if enabled then
		state.aegisState = "Transforming"
		task.spawn(runTransform, player, state, character, humanoid, token)
	else
		state.aegisState = "Reverting"
		task.spawn(runRevert, player, state, character, humanoid, token)
	end

	return true
end

--[[
	Immediate, unconditional return to human form. Used when the game moves the
	player itself (returning to the surface), where waiting on a cooldown or a
	running sequence would be wrong.
]]
function PlayerService.forceHuman(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state.sequenceToken += 1
	PlayerService.Interrupted:Fire(player, "forceHuman")
	state.aegisState = "Human"
	state.transformed = false

	local character = state.character
	local humanoid = state.humanoid
	if character then
		MechaAnimator.setActive(character, false)
		MechaAnimator.clearAction(character)
		AegisRig.clear(character)
		if humanoid then
			setScale(character, humanoid, 1)
		end
		character:SetAttribute("AegisActive", false)
	end
	if humanoid and humanoid.Health > 0 then
		applyMaxHealth(humanoid, state.baseMaxHealth)
		lockMovement(state, humanoid, state.inMenu)
	end

	PlayerService.pushTransformState(player, "Human")
	broadcastVFX(player, "Human")
	PlayerService.TransformChanged:Fire(player, false)
end

function PlayerService.setMenu(player: Player, inMenu: boolean)
	local state = states[player]
	if not state or state.inMenu == inMenu then
		return
	end
	state.inMenu = inMenu

	local humanoid = state.humanoid
	if humanoid and humanoid.Health > 0 then
		lockMovement(state, humanoid, inMenu)
	end

	PlayerService.MenuChanged:Fire(player, inMenu)
end

function PlayerService.setCheckpoint(player: Player, cframe: CFrame, inRuin: boolean)
	local state = states[player]
	if not state then
		return
	end
	state.checkpoint = cframe
	state.safeCFrame = cframe
	state.inRuin = inRuin
end

function PlayerService.cancelTransient(player: Player, reason: string)
	local state = states[player]
	if not state then return end
	state.sequenceToken += 1
	if state.aegisState == "Transforming" or state.aegisState == "Reverting" then
		abortSequence(player, state, state.character, state.humanoid)
	end
	state.combatLocked = false
	if state.humanoid and state.humanoid.Health > 0 then
		lockMovement(state, state.humanoid, state.inMenu)
	end
	PlayerService.Interrupted:Fire(player, reason)
end

function PlayerService.teleport(player: Player, cframe: CFrame)
	local character = states[player] and states[player].character
	if character and character.PrimaryPart then
		character:PivotTo(cframe)
	end
end

function PlayerService.respawn(player: Player)
	local state = states[player]
	if not state then
		return
	end
	-- Server-side reload is authoritative; CharacterAdded re-arms everything.
	task.spawn(function()
		player:LoadCharacterAsync()
	end)
end

local function disconnectAll(state: State)
	for _, connection in state.connections do
		connection:Disconnect()
	end
	table.clear(state.connections)
end

local function onCharacterAdded(player: Player, character: Model)
	local state = states[player]
	if not state then
		return
	end
	disconnectAll(state)

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	character:WaitForChild("HumanoidRootPart", 10)

	state.character = character
	state.humanoid = humanoid
	-- Bumping the token invalidates any sequence still running on the old body.
	state.sequenceToken += 1
	state.aegisState = "Human"
	state.transformed = false
	state.lastTransform = 0
	state.combatLocked = false
	state.recovering = false
	state.baseWalkSpeed = if humanoid.WalkSpeed > 0 then humanoid.WalkSpeed else DEFAULT_WALK_SPEED
	state.baseJumpPower = if humanoid.JumpPower > 0 then humanoid.JumpPower else DEFAULT_JUMP_POWER
	state.baseJumpHeight = if humanoid.JumpHeight > 0 then humanoid.JumpHeight else DEFAULT_JUMP_HEIGHT
	state.baseMaxHealth = humanoid.MaxHealth
	character:SetAttribute("AegisActive", false)
	MechaAnimator.bind(character, humanoid)

	if state.checkpoint then
		task.defer(function()
			if character.Parent and character.PrimaryPart then
				character:PivotTo(state.checkpoint)
			end
		end)
	end

	if state.inMenu then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end

	table.insert(
		state.connections,
			humanoid.Died:Connect(function()
			MechaAnimator.unbind(character)
			state.sequenceToken += 1 -- cancels a transformation in progress
			state.aegisState = "Human"
			state.transformed = false
			state.combatLocked = false
			PlayerService.Interrupted:Fire(player, "death")
			PlayerService.pushTransformState(player, "Human")
			PlayerService.Died:Fire(player)
		end)
	)

	PlayerService.pushTransformState(player)
	PlayerService.CharacterReady:Fire(player, character, humanoid)
end

local function onPlayerAdded(player: Player)
	states[player] = {
		inMenu = true,
		transformed = false,
		aegisState = "Human",
		sequenceToken = 0,
		hasTransformed = false,
		lastTransform = 0,
		checkpoint = world and world.CitySpawn or CFrame.new(0, 5, 48),
		inRuin = false,
		baseWalkSpeed = DEFAULT_WALK_SPEED,
		baseJumpPower = DEFAULT_JUMP_POWER,
		baseJumpHeight = DEFAULT_JUMP_HEIGHT,
		baseMaxHealth = 100,
		character = nil,
		humanoid = nil,
		connections = {},
		safeCFrame = world and world.CitySpawn or CFrame.new(0, 5, 48),
		lastSafeAt = 0,
		recovering = false,
		combatLocked = false,
	}
	player:SetAttribute("CanTransform", false)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	-- A character can already exist here: in Studio's Play Solo the player joins
	-- while the world is still generating, and auto-load may have spawned them
	-- before this handler was installed. Adopt it rather than ignoring it -
	-- without this, state.humanoid stays nil and every isPlayable() check
	-- silently fails while the player walks around perfectly normally.
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	elseif worldReady then
		task.spawn(function()
			player:LoadCharacterAsync()
		end)
	end
end

local function onPlayerRemoving(player: Player)
	local state = states[player]
	if state then
		disconnectAll(state)
	end
	states[player] = nil
end

--[[
	Installed BEFORE the world is generated.

	Generating the district takes long enough that a player can join during it.
	If CharacterAutoLoads is still true at that moment Roblox spawns them with
	no handlers attached, and every later check that needs state.humanoid fails
	quietly. Turning auto-load off first closes that window.
]]
function PlayerService.installHandlers()
	Players.CharacterAutoLoads = false
	feedback = Net.get("Feedback")

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		if not states[player] then
			task.spawn(onPlayerAdded, player)
		end
	end
end

-- Called once the world exists, so nobody is ever spawned into an empty place.
function PlayerService.setWorld(builtWorld: any)
	world = builtWorld
	worldReady = true

	for player, state in states do
		state.checkpoint = world.CitySpawn
		state.safeCFrame = world.CitySpawn
		if not state.character and player.Parent then
			task.spawn(function()
				player:LoadCharacterAsync()
			end)
		elseif state.character then
			-- Adopted from the auto-load race: move them onto the real spawn.
			PlayerService.teleport(player, world.CitySpawn)
		end
	end
end

-- Kept for compatibility with the previous call shape.
function PlayerService.init(builtWorld: any)
	PlayerService.installHandlers()
	PlayerService.setWorld(builtWorld)
end

--[[
	Why a request was refused, for the interaction log. Returns nil when the
	player is good to go.
]]
function PlayerService.blockReason(player: Player): string?
	local state = states[player]
	if not state then
		return "no player state (joined before the services started)"
	end
	if state.inMenu then
		return "still in the main menu (client never sent MenuState=false)"
	end
	if not state.character then
		return "no character tracked"
	end
	if not state.humanoid then
		return "no humanoid tracked"
	end
	if state.humanoid.Health <= 0 then
		return "character is dead"
	end
	return nil
end

return PlayerService
