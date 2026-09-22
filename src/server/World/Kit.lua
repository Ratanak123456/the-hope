--!nonstrict
-- Procedural building blocks shared by every environment module.
--
-- Two rules enforced here so the scene stays cheap:
--   * decorative geometry never collides, queries, touches or casts shadows;
--   * everything static is anchored.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Shared").Palette)

local Kit = {}

-- CollectionService tag for any instance that should not exist yet during
-- Chapter One's peaceful scenes (1) and only appear once the invasion begins
-- (Scene 2 onward): wreckage, scorch marks, emergency barriers, the alien
-- shard. Tagging at build time means the invasion reveal never has to know
-- the generators' internals - it just flips every tagged instance at once.
-- See World/WorldState.lua.
Kit.InvasionOnlyTag = "InvasionOnly"

-- Marks an already-built instance (and everything under it, if it is a
-- Model/Folder) as invasion-only, then immediately hides it: invisible,
-- non-colliding, but NOT destroyed, so WorldState.revealInvasion() can bring
-- it back exactly as built rather than having to rebuild anything.
function Kit.markInvasionOnly(instance: Instance)
	CollectionService:AddTag(instance, Kit.InvasionOnlyTag)
	local parts: { Instance } = { instance }
	for _, descendant in instance:GetDescendants() do
		table.insert(parts, descendant)
	end
	for _, part in parts do
		if part:IsA("BasePart") then
			part:SetAttribute("PreInvasionTransparency", part.Transparency)
			part:SetAttribute("PreInvasionCanCollide", part.CanCollide)
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
		elseif part:IsA("PointLight") or part:IsA("SpotLight") then
			part:SetAttribute("PreInvasionLightEnabled", part.Enabled)
			part.Enabled = false
		end
	end
end

local lightBudget = Palette.Quality.MaxDynamicLights

function Kit.resetLightBudget()
	lightBudget = Palette.Quality.MaxDynamicLights
end

function Kit.folder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Kit.model(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

export type PartSpec = {
	name: string?,
	size: Vector3,
	cframe: CFrame?,
	position: Vector3?,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	shape: Enum.PartType?,
	collide: boolean?, -- default: true
	decor: boolean?, -- shorthand for "no collision, no query, no shadow"
	castShadow: boolean?,
	parent: Instance,
}

--[[
	The single part constructor. `decor = true` marks purely visual geometry,
	which is the default for anything a player could otherwise snag on.
]]
function Kit.part(spec: PartSpec): Part
	local part = Instance.new("Part")
	part.Name = spec.name or "Part"
	part.Anchored = true
	part.Size = spec.size
	part.Color = spec.color
	part.Material = spec.material or Palette.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Transparency = spec.transparency or 0
	part.Reflectance = spec.reflectance or 0

	if spec.shape then
		part.Shape = spec.shape
	end
	if spec.cframe then
		part.CFrame = spec.cframe
	elseif spec.position then
		part.Position = spec.position
	end

	local decor = spec.decor == true
	if decor then
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = if spec.castShadow ~= nil then spec.castShadow else Palette.Quality.DecorCastsShadow
	else
		part.CanCollide = if spec.collide ~= nil then spec.collide else true
		part.CanTouch = false
		part.CastShadow = if spec.castShadow ~= nil then spec.castShadow else true
	end

	part.Parent = spec.parent
	return part
end

function Kit.wedge(spec: PartSpec): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = spec.name or "Wedge"
	wedge.Anchored = true
	wedge.Size = spec.size
	wedge.Color = spec.color
	wedge.Material = spec.material or Palette.Material.Concrete
	wedge.Transparency = spec.transparency or 0
	if spec.cframe then
		wedge.CFrame = spec.cframe
	elseif spec.position then
		wedge.Position = spec.position
	end
	local decor = spec.decor == true
	wedge.CanCollide = if decor then false else (if spec.collide ~= nil then spec.collide else true)
	wedge.CanQuery = not decor
	wedge.CanTouch = false
	wedge.CastShadow = if spec.castShadow ~= nil then spec.castShadow else not decor
	wedge.Parent = spec.parent
	return wedge
end

-- A cylinder laid along an axis: "y" upright, "x"/"z" lying down.
function Kit.cylinder(spec: PartSpec, axis: string?): Part
	local part = Kit.part(spec)
	part.Shape = Enum.PartType.Cylinder
	local base = spec.cframe or CFrame.new(spec.position or Vector3.zero)
	if axis == "y" or axis == nil then
		part.CFrame = base * CFrame.Angles(0, 0, math.rad(90))
	elseif axis == "z" then
		part.CFrame = base * CFrame.Angles(0, math.rad(90), 0)
	else
		part.CFrame = base
	end
	return part
end

-- Lights are budgeted: once the scene has spent its allowance, further calls
-- silently do nothing rather than quietly tanking the frame rate.
function Kit.light(parent: BasePart, color: Color3, range: number, brightness: number, shadows: boolean?): PointLight?
	if lightBudget <= 0 then
		return nil
	end
	lightBudget -= 1
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows == true
	light.Parent = parent
	return light
end

function Kit.weld(base: BasePart, attached: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = attached
	weld.Parent = attached
end

-- Deterministic RNG so the district is identical between test runs.
function Kit.rng(offset: number?): Random
	return Random.new(Palette.Quality.Seed + (offset or 0))
end

function Kit.pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

return Kit
