--!nonstrict
-- Warden (alien troop) presentation.
--
-- Silhouette brief: low, hunched and angular, where Aegis Zero is upright and
-- broad. Charcoal-purple shell, magenta energy concentrated at a few weak
-- points, a forward-jutting sensor head. At gameplay distance the two should
-- never be confused for each other.
--
-- LIMITATION: placeholder procedural geometry welded to the collision root.
-- The limbs are posed, not animated - a real rig can replace this builder
-- without touching the AI or the damage code.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Palette = require(ReplicatedStorage:WaitForChild("Shared").Palette)
local Kit = require(script.Parent.World.Kit)

local WardenRig = {}
local animated: { [Model]: any } = {}

export type BuildOptions = {
	scale: number?, -- rig scale relative to a base scout Warden (default 1)
	isBoss: boolean?, -- swaps the shell/energy palette and adds a crest
}

local SHELL = Palette.Alien.Shell
local SHELL_LIGHT = Palette.Alien.ShellLight
local PLATE = Palette.Alien.Plate
local ENERGY = Palette.Alien.Energy
local ENERGY_DIM = Palette.Alien.EnergyDim

local SHELL_MATERIAL = Enum.Material.Granite
local NEON = Enum.Material.Neon

-- `scale` rescales both the part's size and its offset from the root, keeping
-- rotation untouched, so the same silhouette code produces a bigger rig
-- rather than requiring every literal in WardenRig.build to be rewritten.
local function scaleOffset(offset: CFrame, scale: number): CFrame
	if scale == 1 then
		return offset
	end
	return CFrame.new(offset.Position * scale) * offset.Rotation
end

local function plate(parent: Instance, root: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, transparency: number?, shadow: boolean?, articulated: boolean?, scale: number?): Part
	local factor = scale or 1
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size * factor
	part.Color = color
	part.Material = material or SHELL_MATERIAL
	part.Transparency = transparency or 0
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = shadow == true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local scaledOffset = scaleOffset(offset, factor)
	part.CFrame = root.CFrame * scaledOffset
	part.Parent = parent

	if articulated then
		local motor = Instance.new("Motor6D")
		motor.Name = name .. "Joint"
		motor.Part0 = root
		motor.Part1 = part
		motor.C0 = scaledOffset
		motor.Parent = root
	else
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	return part
end

local function wedge(parent: Instance, root: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, scale: number?): WedgePart
	local factor = scale or 1
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = size * factor
	part.Color = color
	part.Material = SHELL_MATERIAL
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = root.CFrame * scaleOffset(offset, factor)
	part.Parent = parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function buildHealthBar(head: BasePart, humanoid: Humanoid, energyColor: Color3, scale: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WardenHealth"
	billboard.Adornee = head
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 160
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(112, 8)
	billboard.StudsOffset = Vector3.new(0, 3.6 * scale, 0)
	billboard.Parent = head

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.fromScale(1, 1)
	track.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
	track.BackgroundTransparency = 0.2
	track.BorderSizePixel = 0
	track.Parent = billboard

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = energyColor
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	humanoid.HealthChanged:Connect(function(health)
		fill.Size = UDim2.fromScale(math.clamp(health / humanoid.MaxHealth, 0, 1), 1)
	end)
end

--[[
	Builds one Warden. The collision root keeps the same dimensions the AI and
	the strike volume already assume; everything else is welded decoration.

	`options.scale` rescales the whole silhouette (see scaleOffset() above) and
	`options.isBoss` swaps in the the Harrower's deeper-plum, hot-amber
	palette and adds a crest, so the boss reads as an apex variant of the same
	family rather than a different creature - see EncounterService.lua for the
	the Harrower fight itself.
]]
function WardenRig.build(parent: Instance, position: Vector3, maxHealth: number, walkSpeed: number, options: BuildOptions?): Model
	local scale = (options and options.scale) or 1
	local isBoss = options ~= nil and options.isBoss == true
	local shellColor = if isBoss then Palette.Alien.BossShell else SHELL
	local shellLightColor = if isBoss then Palette.Alien.BossShellLight else SHELL_LIGHT
	local energyColor = if isBoss then Palette.Alien.BossEnergy else ENERGY
	local energyDimColor = if isBoss then Palette.Alien.BossEnergyDim else ENERGY_DIM

	local model = Instance.new("Model")
	model.Name = "Warden"
	model:SetAttribute("IsWarden", true)
	-- setTelegraph() and flashHit() read these back instead of the module-level
	-- SHELL/ENERGY constants, so a variant's own colours survive a telegraph
	-- flash or a hit flash without snapping back to the scout palette.
	model:SetAttribute("ShellColor", shellColor)
	model:SetAttribute("SensorColor", energyColor)
	model:SetAttribute("RigScale", scale)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(4, 5, 3) * scale
	root.Position = position
	root.Transparency = 1 -- the shell is the visible body
	root.CastShadow = false
	root.CanCollide = true
	root.CanQuery = true
	root.CanTouch = false
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model

	local body = Instance.new("Folder")
	body.Name = "Shell"
	body.Parent = model

	-- Hunched carapace, pitched forward.
	-- The collision root is invisible and therefore casts nothing, so the main
	-- body masses carry the shadow that grounds the Warden.
	plate(body, root, "Carapace", Vector3.new(6.2, 2.8, 7.2), CFrame.new(0, 1.1, 0.4) * CFrame.Angles(math.rad(-12), 0, 0), shellColor, nil, nil, true, nil, scale)
	plate(body, root, "CarapaceUnder", Vector3.new(5, 1.8, 6.4), CFrame.new(0, -0.5, 0.3), PLATE, nil, nil, nil, nil, scale)

	-- Spine ridge: three wedges stepping down the back.
	for index = 1, 3 do
		local t = (index - 2) * 2.1
		wedge(body, root, "Ridge" .. index, Vector3.new(1.1, 2.2 - math.abs(index - 2) * 0.5, 2.4), CFrame.new(0, 2.4, t) * CFrame.Angles(0, math.rad(180), 0), shellLightColor, scale)
	end

	-- Shoulder plates flare outward.
	for _, side in { -1, 1 } do
		plate(body, root, "Shoulder", Vector3.new(2.2, 1.6, 3.4), CFrame.new(side * 3.1, 1.3, -1.4) * CFrame.Angles(0, 0, math.rad(side * 26)), shellLightColor, nil, nil, true, nil, scale)
		wedge(body, root, "ShoulderSpike", Vector3.new(0.9, 2.6, 2.2), CFrame.new(side * 4.0, 2.1, -1.2) * CFrame.Angles(0, math.rad(if side > 0 then 90 else -90), math.rad(side * 40)), PLATE, scale)
	end

	-- Forward sensor head.
	local head = plate(body, root, "Head", Vector3.new(3.2, 2.1, 3.2), CFrame.new(0, 0.7, -4.1) * CFrame.Angles(math.rad(10), 0, 0), PLATE, nil, nil, nil, nil, scale)
	plate(body, root, "Brow", Vector3.new(3.4, 0.7, 1.6), CFrame.new(0, 1.7, -4.6), shellColor, nil, nil, nil, nil, scale)
	for _, side in { -1, 1 } do
		wedge(body, root, "Mandible", Vector3.new(0.7, 1.8, 2.4), CFrame.new(side * 1.2, -0.5, -5.1) * CFrame.Angles(math.rad(-20), math.rad(if side > 0 then 0 else 180), 0), shellColor, scale)
	end

	-- The apex variant carries a taller crest above the brow - the single
	-- silhouette change that reads as "leader" at a glance and at range.
	if isBoss then
		for _, side in { -1, 1 } do
			wedge(body, root, "Crest", Vector3.new(0.8, 3.6, 2.6), CFrame.new(side * 0.9, 2.6, -3.4) * CFrame.Angles(math.rad(-30), math.rad(if side > 0 then 12 else -12), 0), shellLightColor, scale)
		end
	end

	-- The sensor slit is the read for both identity and attack telegraph.
	plate(body, root, "Sensor", Vector3.new(2.3, 0.42, 0.5), CFrame.new(0, 0.9, -5.7), energyColor, NEON, 0.15, nil, nil, scale)

	-- Weak points: three vents along the back.
	for index = -1, 1 do
		plate(body, root, "Vent", Vector3.new(0.9, 0.3, 1.6), CFrame.new(index * 2.0, 2.35, 1.6), energyDimColor, NEON, 0.3, nil, nil, scale)
	end

	-- Limbs: forelimbs braced forward, hind limbs coiled back.
	for _, side in { -1, 1 } do
		plate(body, root, "ForeUpper", Vector3.new(1.5, 3.4, 1.5), CFrame.new(side * 2.9, -0.4, -2.2) * CFrame.Angles(math.rad(26), 0, math.rad(side * 12)), shellColor, nil, nil, true, true, scale)
		plate(body, root, "ForeLower", Vector3.new(1.2, 3.2, 1.2), CFrame.new(side * 3.3, -2.4, -3.3) * CFrame.Angles(math.rad(-22), 0, math.rad(side * 6)), PLATE, nil, nil, nil, true, scale)
		wedge(body, root, "ForeClaw", Vector3.new(0.8, 1.4, 2.0), CFrame.new(side * 3.4, -3.9, -4.1) * CFrame.Angles(math.rad(-14), math.rad(180), 0), shellLightColor, scale)

		plate(body, root, "HindUpper", Vector3.new(1.8, 3.6, 2.2), CFrame.new(side * 2.8, -0.2, 2.4) * CFrame.Angles(math.rad(-30), 0, math.rad(side * 10)), shellColor, nil, nil, true, true, scale)
		plate(body, root, "HindLower", Vector3.new(1.3, 3.4, 1.3), CFrame.new(side * 3.2, -2.3, 3.2) * CFrame.Angles(math.rad(24), 0, 0), PLATE, nil, nil, nil, true, scale)
		wedge(body, root, "HindClaw", Vector3.new(0.8, 1.2, 1.8), CFrame.new(side * 3.2, -3.8, 2.5) * CFrame.Angles(0, math.rad(180), 0), shellLightColor, scale)
	end

	-- Tail fin closes the silhouette.
	wedge(body, root, "TailFin", Vector3.new(0.9, 2.8, 4.2), CFrame.new(0, 1.6, 4.4) * CFrame.Angles(math.rad(22), 0, 0), shellLightColor, scale)

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.WalkSpeed = walkSpeed
	humanoid.HipHeight = 2.5 * scale
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	buildHealthBar(head, humanoid, energyColor, scale)

	model.PrimaryPart = root
	model.Parent = parent
	root:SetNetworkOwner(nil)
	animated[model] = { joints = {}, phase = "Idle", started = os.clock() }
	for _, item in root:GetChildren() do
		if item:IsA("Motor6D") then animated[model].joints[item.Name] = item end
	end
	return model
end

function WardenRig.setAnimation(model: Model, phase: string)
	local state = animated[model]
	if state then state.phase = phase; state.started = os.clock() end
end

function WardenRig.remove(model: Model)
	animated[model] = nil
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for model, state in animated do
		if not model.Parent then animated[model] = nil; continue end
		local t = now - state.started

		-- Defeat holds a single buckled pose and never reverts to Idle: the
		-- model is destroyed a few seconds later (see EncounterService.lua),
		-- so there is no "after" state worth animating back to.
		if state.phase == "Defeat" then
			local collapse = math.min(1, t / 0.6)
			for name, motor in state.joints do
				if name:find("ForeUpper") or name:find("HindUpper") then
					motor.Transform = CFrame.Angles(0.85 * collapse, 0, 0.25 * collapse)
				elseif name:find("ForeLower") or name:find("HindLower") then
					motor.Transform = CFrame.Angles(-0.6 * collapse, 0, 0)
				else
					motor.Transform = CFrame.Angles(0.3 * collapse, 0, 0)
				end
			end
			continue
		end

		local moving = model.PrimaryPart and model.PrimaryPart.AssemblyLinearVelocity.Magnitude > 1
		local swing = if moving then math.sin(now * 7) else math.sin(now * 1.4) * 0.08
		for name, motor in state.joints do
			local transform = CFrame.identity
			if name:find("ForeUpper") then transform = CFrame.Angles(swing * 0.22, 0, 0) end
			if name:find("ForeLower") then transform = CFrame.Angles(-swing * 0.3, 0, 0) end
			if name:find("HindUpper") then transform = CFrame.Angles(-swing * 0.25, 0, 0) end
			if name:find("HindLower") then transform = CFrame.Angles(swing * 0.3, 0, 0) end
			if state.phase == "Windup" then transform *= CFrame.Angles(-0.35, 0, 0) end
			if state.phase == "Strike" then transform *= CFrame.Angles(0.7, 0, 0) end
			if state.phase == "Recover" then transform *= CFrame.Angles(0.18, 0, 0) end
			motor.Transform = transform
		end
		if state.phase ~= "Idle" and t > 0.9 then state.phase = "Idle" end
	end
end)

--[[
	Attack telegraph. Brightening the sensor is the *only* visual promise made
	here, and it is switched on and off by the same code that decides whether
	damage lands, so the warning can never disagree with the hitbox.

	The idle colour and the sensor's rest size both come back from the model
	itself (SensorColor / RigScale attributes set in WardenRig.build)
	instead of the module-level scout constants, so a the Harrower's flash
	returns to its own palette and its own scale rather than snapping back to
	a scout's.
]]
function WardenRig.setTelegraph(model: Model, active: boolean)
	local shell = model:FindFirstChild("Shell")
	local sensor = shell and shell:FindFirstChild("Sensor")
	local baseColor = model:GetAttribute("SensorColor")
	if typeof(baseColor) ~= "Color3" then baseColor = ENERGY end
	local scale = model:GetAttribute("RigScale")
	if typeof(scale) ~= "number" then scale = 1 end
	if sensor and sensor:IsA("BasePart") then
		sensor.Color = if active then Color3.fromRGB(255, 150, 230) else baseColor
		sensor.Transparency = if active then 0 else 0.15
		sensor.Size = if active then Vector3.new(2.9, 0.6, 0.5) * scale else Vector3.new(2.3, 0.42, 0.5) * scale
	end
	if shell then
		for _, vent in shell:GetChildren() do
			if vent.Name == "Vent" and vent:IsA("BasePart") then
				vent.Transparency = if active then 0.05 else 0.3
			end
		end
	end
end

-- Brief shell flash so a landed hit is unmistakable.
function WardenRig.flashHit(model: Model)
	local shell = model:FindFirstChild("Shell")
	if not shell then
		return
	end
	local carapace = shell:FindFirstChild("Carapace")
	if carapace and carapace:IsA("BasePart") then
		local baseColor = model:GetAttribute("ShellColor")
		if typeof(baseColor) ~= "Color3" then baseColor = SHELL end
		carapace.Color = Color3.fromRGB(198, 170, 220)
		task.delay(0.12, function()
			if carapace.Parent then
				carapace.Color = baseColor
			end
		end)
	end
end

--[[
	A Signal-phase relay pylon: a stationary, destructible totem, not an actor.
	It shares the Warden tag contract (PrimaryPart + Humanoid) so the
	existing CombatService.damageArea() targets it for free - no combat code
	needed to know pylons exist at all. BreakJointsOnDeath is off so the welded
	shell stays put and just powers down, rather than the parts flying apart.
]]
function WardenRig.buildPylon(parent: Instance, position: Vector3, maxHealth: number): Model
	local model = Instance.new("Model")
	model.Name = "RelayPylon"
	model:SetAttribute("IsPylon", true)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(3, 9, 3)
	root.CFrame = CFrame.new(position)
	root.Anchored = true
	root.CanCollide = true
	root.CanQuery = true
	root.CanTouch = false
	root.CastShadow = true
	root.Color = Palette.Alien.Plate
	root.Material = SHELL_MATERIAL
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model

	for index = 0, 2 do
		local ring = Instance.new("Part")
		ring.Name = "Ring"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.6, 3.4 - index * 0.5, 3.4 - index * 0.5)
		ring.Color = Palette.Alien.Plate
		ring.Material = SHELL_MATERIAL
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Massless = true
		ring.CastShadow = false
		ring.CFrame = root.CFrame * CFrame.new(0, -3 + index * 2.2, 0) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = model
		local ringWeld = Instance.new("WeldConstraint")
		ringWeld.Part0 = root
		ringWeld.Part1 = ring
		ringWeld.Parent = ring
	end

	local crystal = Instance.new("Part")
	crystal.Name = "Emitter"
	crystal.Shape = Enum.PartType.Ball
	crystal.Size = Vector3.one * 2.6
	crystal.Color = Palette.Alien.BossEnergy
	crystal.Material = NEON
	crystal.Transparency = 0.1
	crystal.CanCollide = false
	crystal.CanQuery = false
	crystal.CanTouch = false
	crystal.Massless = true
	crystal.CastShadow = false
	crystal.CFrame = root.CFrame * CFrame.new(0, 5.6, 0)
	crystal.Parent = model
	local crystalWeld = Instance.new("WeldConstraint")
	crystalWeld.Part0 = root
	crystalWeld.Part1 = crystal
	crystalWeld.Parent = crystal
	Kit.light(crystal, Palette.Alien.BossEnergy, 24, 2)

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.WalkSpeed = 0
	humanoid.HipHeight = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	buildHealthBar(crystal, humanoid, Palette.Alien.BossEnergy, 1)

	model.PrimaryPart = root
	model.Parent = parent
	return model
end

-- Called once a pylon's Humanoid dies: dims the emitter rather than deleting
-- it immediately, so its shutdown reads as a beat rather than a pop.
function WardenRig.powerDownPylon(model: Model)
	local crystal = model:FindFirstChild("Emitter")
	if crystal and crystal:IsA("BasePart") then
		crystal.Transparency = 0.85
		local light = crystal:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = false
		end
	end
end

return WardenRig
