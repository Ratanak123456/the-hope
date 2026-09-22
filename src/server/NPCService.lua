--!nonstrict
-- Human NPCs: ambient civilians, and named story characters (Uncle Daren,
-- Mira). Everything here is procedural geometry in the same spirit as
-- WardenRig/AegisRig - no avatar assets, no Toolbox accessories, no
-- Animation instances. Walking is a real Humanoid:MoveTo() (so pathing stays
-- on the NavMesh and looks like walking, not sliding); the arm/leg swing is a
-- simple Heartbeat-driven Motor6D pose, the same trick ConstructRig/WardenRig
-- already use for the Wardens.
--
-- Ambient civilians are capped (Config.Neighborhood.AmbientCount) and only
-- ever walk between two or three fixed points each - never continuous
-- PathfindingService - which is what keeps a whole street of them cheap.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)

local Kit = require(script.Parent.World.Kit)

local NPCService = {}

NPCService.HumanTag = "SkyHuman"

--------------------------------------------------------------------------------
-- Appearance
--------------------------------------------------------------------------------

local SKIN_TONES = {
	Color3.fromRGB(232, 191, 160),
	Color3.fromRGB(198, 150, 115),
	Color3.fromRGB(151, 105, 79),
	Color3.fromRGB(100, 70, 52),
	Color3.fromRGB(240, 205, 180),
}

local SHIRT_COLORS = {
	Color3.fromRGB(96, 122, 140), Color3.fromRGB(178, 92, 78), Color3.fromRGB(120, 140, 96),
	Color3.fromRGB(206, 178, 110), Color3.fromRGB(90, 90, 110), Color3.fromRGB(150, 96, 130),
}

local PANTS_COLORS = {
	Color3.fromRGB(52, 56, 66), Color3.fromRGB(70, 62, 54), Color3.fromRGB(40, 44, 52), Color3.fromRGB(84, 78, 70),
}

local HAIR_COLORS = {
	Color3.fromRGB(36, 30, 26), Color3.fromRGB(70, 52, 36), Color3.fromRGB(20, 20, 22), Color3.fromRGB(120, 96, 70), Color3.fromRGB(150, 150, 156),
}

export type Appearance = {
	skin: Color3,
	shirt: Color3,
	pants: Color3,
	hair: Color3,
	scale: number,
}

function NPCService.randomAppearance(rng: Random): Appearance
	return {
		skin = Kit.pick(rng, SKIN_TONES),
		shirt = Kit.pick(rng, SHIRT_COLORS),
		pants = Kit.pick(rng, PANTS_COLORS),
		hair = Kit.pick(rng, HAIR_COLORS),
		scale = 0.94 + rng:NextNumber() * 0.14,
	}
end

--------------------------------------------------------------------------------
-- Rig: a simple, clearly-human silhouette built from welded/articulated
-- parts on one invisible collision root, exactly the WardenRig.lua approach.
--------------------------------------------------------------------------------

local function weldedPart(parent: Instance, root: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, articulated: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.Plastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = root.CFrame * offset
	part.Parent = parent

	if articulated then
		local motor = Instance.new("Motor6D")
		motor.Name = name .. "Joint"
		motor.Part0 = root
		motor.Part1 = part
		motor.C0 = offset
		motor.Parent = root
	else
		Kit.weld(root, part)
	end
	return part
end

local animated: { [Model]: { joints: { [string]: Motor6D }, phase: string, seed: number } } = {}

--[[
	Builds one human NPC. `appearance` controls colour/scale variety;
	`walkSpeed` 0 means stationary (used for NPCs that only ever sit/stand).
	Returns the Model - callers add behaviour (ambient loop, companion follow,
	proximity prompt) on top.
]]
function NPCService.build(parent: Instance, position: Vector3, appearance: Appearance, walkSpeed: number, displayName: string?): Model
	local scale = appearance.scale
	local model = Instance.new("Model")
	model.Name = displayName or "Civilian"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * scale
	root.Position = position
	root.Transparency = 1
	root.CastShadow = false
	root.CanCollide = true
	root.CanQuery = true
	root.CanTouch = false
	root.Parent = model

	local body = Instance.new("Folder")
	body.Name = "Body"
	body.Parent = model

	weldedPart(body, root, "Torso", Vector3.new(2, 2.2, 1) * scale, CFrame.new(0, 0.1, 0), appearance.shirt, Enum.Material.Fabric, false)
	local head = weldedPart(body, root, "Head", Vector3.new(1.3, 1.3, 1.3) * scale, CFrame.new(0, 2.05, 0), appearance.skin, Enum.Material.SmoothPlastic, true)
	-- Hair welds to the head (not the root) so it turns with the idle Talk pose.
	weldedPart(body, head, "Hair", Vector3.new(1.4, 0.5, 1.4) * scale, CFrame.new(0, 0.5, 0.05), appearance.hair, Enum.Material.Fabric, false)

	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		weldedPart(body, root, prefix .. "Arm", Vector3.new(0.7, 2, 0.7) * scale, CFrame.new(side * 1.35 * scale, 0.1, 0), appearance.skin, Enum.Material.SmoothPlastic, true)
		weldedPart(body, root, prefix .. "Leg", Vector3.new(0.85, 2, 0.85) * scale, CFrame.new(side * 0.55 * scale, -2.1, 0), appearance.pants, Enum.Material.Fabric, true)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 20
	humanoid.Health = 20
	humanoid.WalkSpeed = walkSpeed
	humanoid.HipHeight = 2 * scale
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	model.PrimaryPart = root
	model.Parent = parent
	root:SetNetworkOwner(nil)

	if displayName then
		local tag = Instance.new("BillboardGui")
		tag.Name = "NameTag"
		tag.Adornee = head
		tag.AlwaysOnTop = false
		tag.Size = UDim2.fromOffset(140, 28)
		tag.StudsOffset = Vector3.new(0, 1.1, 0)
		tag.MaxDistance = 60
		tag.LightInfluence = 0
		tag.Parent = head
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamMedium
		label.Text = string.upper(displayName)
		label.TextColor3 = Color3.fromRGB(226, 236, 243)
		label.TextSize = 14
		label.Parent = tag
	end

	CollectionService:AddTag(model, NPCService.HumanTag)
	animated[model] = { joints = {}, phase = "Idle", seed = math.random() * 100 }
	for _, item in root:GetChildren() do
		if item:IsA("Motor6D") then
			animated[model].joints[item.Name] = item
		end
	end

	return model
end

function NPCService.setPhase(model: Model, phase: string)
	local state = animated[model]
	if state then
		state.phase = phase
	end
end

function NPCService.remove(model: Model)
	animated[model] = nil
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for model, state in animated do
		if not model.Parent then
			animated[model] = nil
			continue
		end
		local root = model.PrimaryPart
		local moving = state.phase == "Walk" and root and root.AssemblyLinearVelocity.Magnitude > 0.6
		local swing = if moving then math.sin((now + state.seed) * 6.4) else math.sin((now + state.seed) * 1.1) * 0.05
		for name, motor in state.joints do
			if name:find("Arm") then
				motor.Transform = CFrame.Angles((if name:find("Left") then -swing else swing) * 0.5, 0, 0)
			elseif name:find("Leg") then
				motor.Transform = CFrame.Angles((if name:find("Left") then swing else -swing) * 0.45, 0, 0)
			elseif name == "HeadJoint" and state.phase == "Talk" then
				motor.Transform = CFrame.Angles(math.sin((now + state.seed) * 3.2) * 0.08, math.sin((now + state.seed) * 1.7) * 0.12, 0)
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Ambient civilians: simple looping behaviours between fixed points, capped
-- in number, never continuous pathfinding.
--------------------------------------------------------------------------------

export type AmbientSpec = {
	kind: "Walk" | "Wait" | "Sit" | "Talk" | "Browse" | "Repair" | "Carry",
	points: { Vector3 }, -- for Walk/Carry: the loop; for the rest, points[1] is where the NPC stays
	facing: Vector3?, -- for stationary kinds, which way to face
}

local ambientThreads: { thread } = {}

-- Set once, globally, when the invasion begins (see
-- ChapterOneDirector.applyScene02EndState) - not per-NPC state, because
-- every ambient civilian in the city reacts to the same event at once.
-- Rule: "civilians panic, hide, help one another or evacuate." This
-- implements the "evacuate" case uniformly (every civilian flees away from
-- the panic source at a raised speed) rather than simulating three
-- different reactions per individual, which is a deliberate scope
-- simplification for a background-life system, not the main gameplay.
local panicSource: Vector3? = nil

function NPCService.setGlobalPanic(source: Vector3?)
	panicSource = source
end

local function ambientLoop(model: Model, humanoid: Humanoid, spec: AmbientSpec)
	if not (spec.kind == "Walk" or spec.kind == "Carry") and spec.facing and model.PrimaryPart then
		model:PivotTo(CFrame.lookAt(model.PrimaryPart.Position, model.PrimaryPart.Position + spec.facing))
	end

	local index = 1
	while model.Parent do
		if panicSource then
			local root = model.PrimaryPart
			if not root then
				task.wait(0.5)
				continue
			end
			local away = root.Position - panicSource
			local direction = if away.Magnitude > 1 then away.Unit else Vector3.new(1, 0, 0)
			humanoid.WalkSpeed = Config.Neighborhood.AmbientWalkSpeed * 1.7 -- a panicked run, not the normal stroll
			NPCService.setPhase(model, "Walk")
			humanoid:MoveTo(root.Position + direction * 45)
			humanoid.MoveToFinished:Wait()
			task.wait(0.2)
			continue
		end

		humanoid.WalkSpeed = if spec.kind == "Walk" or spec.kind == "Carry" then Config.Neighborhood.AmbientWalkSpeed else 0
		if spec.kind == "Walk" or spec.kind == "Carry" then
			local target = spec.points[index]
			NPCService.setPhase(model, "Walk")
			humanoid:MoveTo(target)
			local reached = humanoid.MoveToFinished:Wait()
			if not reached then
				task.wait(1)
			end
			NPCService.setPhase(model, "Idle")
			task.wait(1.2 + math.random() * 1.8)
			index = index % #spec.points + 1
		else
			-- Stationary behaviours just idle in place with an occasional pose swap.
			NPCService.setPhase(model, if spec.kind == "Talk" then "Talk" else "Idle")
			task.wait(2 + math.random() * 3)
		end
	end
end

-- Builds and starts one ambient civilian. Returns the model so a caller could
-- clean it up, though ambient civilians normally live for the server's life.
function NPCService.spawnAmbient(parent: Instance, spec: AmbientSpec, rng: Random): Model
	local appearance = NPCService.randomAppearance(rng)
	local walkSpeed = if spec.kind == "Walk" or spec.kind == "Carry" then Config.Neighborhood.AmbientWalkSpeed else 0
	local model = NPCService.build(parent, spec.points[1], appearance, walkSpeed)

	if spec.kind == "Carry" then
		-- A small package clutched at chest height - reads as "carrying
		-- packages" from a distance without needing a held-tool asset.
		local root = model.PrimaryPart :: BasePart
		local box = Instance.new("Part")
		box.Name = "Package"
		box.Size = Vector3.new(1.1, 0.9, 1.1)
		box.Color = Palette.Energy.AmberDim
		box.Material = Enum.Material.Cardboard
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.CastShadow = false
		box.Massless = true
		box.CFrame = root.CFrame * CFrame.new(0.9, 0, -0.7)
		box.Parent = model
		Kit.weld(root, box)
	end

	table.insert(ambientThreads, task.spawn(ambientLoop, model, model:FindFirstChildOfClass("Humanoid"), spec))
	return model
end

--------------------------------------------------------------------------------
-- Named static NPC (Uncle Daren): stands at a fixed point with a
-- ProximityPrompt. The caller (ChapterOneDirector) owns what happens when
-- the prompt fires.
--------------------------------------------------------------------------------

function NPCService.spawnNamed(parent: Instance, name: string, cframe: CFrame, appearance: Appearance, promptText: string?): (Model, ProximityPrompt?)
	local model = NPCService.build(parent, cframe.Position, appearance, 0, name)
	model:PivotTo(cframe)

	local prompt: ProximityPrompt? = nil
	if promptText then
		local created = Instance.new("ProximityPrompt")
		created.Name = "TalkPrompt"
		created.ActionText = promptText
		created.ObjectText = string.upper(name)
		created.KeyboardKeyCode = Enum.KeyCode.E
		created.HoldDuration = 0.3
		created.MaxActivationDistance = 10
		created.RequiresLineOfSight = false
		created.ClickablePrompt = true
		created.UIOffset = Vector2.new(0, -34)
		created.Style = Enum.ProximityPromptStyle.Custom
		created.Parent = model.PrimaryPart
		prompt = created
	end

	return model, prompt
end

--------------------------------------------------------------------------------
-- Companion (Mira): follows a moving target root part without standing on
-- it, pauses for dialogue, and recovers to a hidden safe point if she falls
-- too far behind or gets stuck.
--------------------------------------------------------------------------------

export type Companion = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	holdForDialogue: boolean,
	lastProgressAt: number,
	lastDistance: number,
}

local companions: { [string]: Companion } = {}

-- `cframe` is only the companion's starting position - recovery (see
-- updateCompanion below) always teleports to a point near wherever the
-- player currently is, not back to this spawn point, since the player could
-- be anywhere along the route by the time she gets stuck.
function NPCService.spawnCompanion(parent: Instance, name: string, cframe: CFrame, appearance: Appearance): Companion
	local model = NPCService.build(parent, cframe.Position, appearance, Config.Neighborhood.CompanionWalkSpeed, name)
	model:PivotTo(cframe)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model.PrimaryPart :: BasePart

	local companion: Companion = {
		model = model,
		humanoid = humanoid,
		root = root,
		holdForDialogue = false,
		lastProgressAt = os.clock(),
		lastDistance = 0,
	}
	companions[name] = companion
	return companion
end

function NPCService.getCompanion(name: string): Companion?
	return companions[name]
end

function NPCService.setCompanionHold(name: string, holding: boolean)
	local companion = companions[name]
	if not companion then
		return
	end
	companion.holdForDialogue = holding
	if holding and companion.humanoid then
		companion.humanoid:MoveTo(companion.root.Position)
		NPCService.setPhase(companion.model, "Idle")
	end
end

function NPCService.removeCompanion(name: string)
	companions[name] = nil
end

-- Follows `targetRoot` at a comfortable offset (never directly on top of the
-- player), and teleports to a point near the player if progress toward the
-- target stalls for too long (stuck on geometry) or the gap grows too wide (fell
-- behind badly). Call once per Heartbeat tick from ChapterOneDirector.
function NPCService.updateCompanion(name: string, targetRoot: BasePart, dt: number)
	local companion = companions[name]
	if not companion or not companion.model.Parent or companion.holdForDialogue then
		return
	end
	local humanoid, root = companion.humanoid, companion.root
	if not root.Parent or humanoid.Health <= 0 then
		return
	end

	local toTarget = targetRoot.Position - root.Position
	local flatDistance = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude
	local followDistance = Config.Neighborhood.CompanionFollowDistance

	if flatDistance > Config.Neighborhood.CompanionRecoveryDistance then
		-- Too far behind: recover to a hidden point near the player rather
		-- than fighting through geometry to catch up in view.
		companion.model:PivotTo(CFrame.lookAt(targetRoot.Position + Vector3.new(-4, 0, -4), targetRoot.Position))
		NPCService.setPhase(companion.model, "Idle")
		companion.lastProgressAt = os.clock()
		companion.lastDistance = 0
		return
	end

	if flatDistance > followDistance then
		-- Stand slightly beside/behind the player, not directly on their heels.
		local offsetDirection = if toTarget.Magnitude > 0.1 then toTarget.Unit else Vector3.new(0, 0, 1)
		local sideways = Vector3.new(-offsetDirection.Z, 0, offsetDirection.X)
		local destination = targetRoot.Position - offsetDirection * (followDistance * 0.7) + sideways * 3
		humanoid:MoveTo(destination)
		NPCService.setPhase(companion.model, "Walk")

		-- Stuck detection: if the distance to target has not meaningfully
		-- shrunk in RecoveryDebounceSeconds despite trying, teleport clear.
		if flatDistance < companion.lastDistance - 0.5 then
			companion.lastProgressAt = os.clock()
		end
		companion.lastDistance = flatDistance
		if os.clock() - companion.lastProgressAt > Config.Neighborhood.CompanionStuckSeconds then
			companion.model:PivotTo(CFrame.lookAt(targetRoot.Position + Vector3.new(3, 0, -3), targetRoot.Position))
			companion.lastProgressAt = os.clock()
		end
	else
		humanoid:MoveTo(root.Position)
		NPCService.setPhase(companion.model, "Idle")
		companion.lastProgressAt = os.clock()
		companion.lastDistance = flatDistance
	end
end

return NPCService
