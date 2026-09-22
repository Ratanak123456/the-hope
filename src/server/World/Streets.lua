--!nonstrict
-- Roads, sidewalks, curbs, markings and ground damage.
--
-- Height layering, chosen once so nothing z-fights:
--   subgrade top  -0.50   dark earth under everything
--   road top       0.00   asphalt
--   marking top    0.03   paint sits proud of the asphalt
--   sidewalk top   0.50   concrete, block pads and the plaza
--   curb top       0.62   lip along the kerb line
--
-- Plan, in studs from the crater at the origin:
--   |x| or |z| <  20        avenue carriageway
--   20 .. 30                sidewalk
--   30 .. 168               quadrant block (buildings stand here)
--   the central 60 x 60 square is the plaza and is built by City.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Shared").Palette)
local Kit = require(script.Parent.Kit)

local Streets = {}

Streets.Extent = 168 -- half-size of the built district
Streets.RoadHalf = 20 -- half-width of an avenue carriageway
Streets.WalkWidth = 10 -- sidewalk, from RoadHalf out to PlazaHalf
Streets.PlazaHalf = 30 -- the civic square over the ruin
Streets.RoadY = 0
Streets.WalkY = 0.5

local EXTENT = Streets.Extent
local ROAD_HALF = Streets.RoadHalf
local INNER = Streets.PlazaHalf
local WALK_MID = (ROAD_HALF + INNER) / 2
local WALK_WIDTH = Streets.WalkWidth

local function slab(parent, name, size, position, color, material, decor)
	return Kit.part({
		name = name,
		size = size,
		position = position,
		color = color,
		material = material,
		decor = decor,
		parent = parent,
	})
end

local function buildSubgrade(parent: Instance)
	slab(parent, "Subgrade", Vector3.new(EXTENT * 2 + 60, 6, EXTENT * 2 + 60), Vector3.new(0, -3.5, 0), Palette.City.Earth, Palette.Material.Earth, false)
end

-- Four quadrant pads at sidewalk height. Buildings stand on these.
local function buildBlocks(parent: Instance)
	local blockSize = EXTENT - INNER
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local centre = Vector3.new(sx * (INNER + blockSize / 2), Streets.WalkY - 0.25, sz * (INNER + blockSize / 2))
			slab(parent, "BlockPad", Vector3.new(blockSize, 0.5, blockSize), centre, Palette.City.SidewalkWorn, Palette.Material.Sidewalk, false)
		end
	end
end

-- Each avenue is built as two arms so the plaza is never overlapped.
local function buildAvenue(parent: Instance, alongZ: boolean)
	local armLength = EXTENT - INNER
	local armCentre = INNER + armLength / 2

	for _, direction in { -1, 1 } do
		local at = direction * armCentre

		local roadSize = if alongZ then Vector3.new(ROAD_HALF * 2, 0.6, armLength) else Vector3.new(armLength, 0.6, ROAD_HALF * 2)
		local roadPos = if alongZ then Vector3.new(0, Streets.RoadY - 0.3, at) else Vector3.new(at, Streets.RoadY - 0.3, 0)
		slab(parent, "Road", roadSize, roadPos, Palette.City.Asphalt, Palette.Material.Asphalt, false)

		for _, side in { -1, 1 } do
			local lateral = side * WALK_MID
			local walkSize = if alongZ then Vector3.new(WALK_WIDTH, 0.5, armLength) else Vector3.new(armLength, 0.5, WALK_WIDTH)
			local walkPos = if alongZ then Vector3.new(lateral, Streets.WalkY - 0.25, at) else Vector3.new(at, Streets.WalkY - 0.25, lateral)
			slab(parent, "Sidewalk", walkSize, walkPos, Palette.City.Sidewalk, Palette.Material.Sidewalk, false)

			local curbAt = side * (ROAD_HALF + 0.4)
			local curbSize = if alongZ then Vector3.new(0.8, 1.24, armLength) else Vector3.new(armLength, 1.24, 0.8)
			local curbPos = if alongZ then Vector3.new(curbAt, 0, at) else Vector3.new(at, 0, curbAt)
			slab(parent, "Curb", curbSize, curbPos, Palette.City.Curb, Palette.Material.Concrete, false)
		end
	end
end

-- Centre line down each avenue arm, plus crossings on the plaza approaches.
local function buildMarkings(parent: Instance)
	local dash, gap = 7, 9

	for _, alongZ in { true, false } do
		for _, direction in { -1, 1 } do
			local distance = INNER + 16
			while distance < EXTENT - 8 do
				local at = direction * distance
				local size = if alongZ then Vector3.new(0.7, 0.25, dash) else Vector3.new(dash, 0.25, 0.7)
				local position = if alongZ then Vector3.new(0, Streets.RoadY - 0.09, at) else Vector3.new(at, Streets.RoadY - 0.09, 0)
				slab(parent, "LaneMark", size, position, Palette.City.LaneMark, Palette.Material.Concrete, true)
				distance += dash + gap
			end

			-- Crossing bars just outside the plaza.
			local crossingAt = direction * (INNER + 6)
			for stripe = -3, 3 do
				local across = stripe * 5.2
				local size = if alongZ then Vector3.new(2.4, 0.25, 9) else Vector3.new(9, 0.25, 2.4)
				local position = if alongZ then Vector3.new(across, Streets.RoadY - 0.09, crossingAt) else Vector3.new(crossingAt, Streets.RoadY - 0.09, across)
				slab(parent, "Crossing", size, position, Palette.City.LaneMark, Palette.Material.Concrete, true)
			end
		end
	end
end

-- The invasion zone: cracked paving, exposed earth and buckled asphalt.
-- Approximated with a few overlapping rotated slabs rather than real meshes.
-- Built once at world-gen time but hidden (Kit.markInvasionOnly) until
-- Scene 2 actually begins - Chapter One Scene 1 is a peaceful morning and
-- this ground should look untouched.
local function buildGroundDamage(parent: Instance, rng: Random)
	local folder = Kit.folder("InvasionGroundDamage", parent)
	local hotspots = {
		Vector3.new(0, 0, -46),
		Vector3.new(-26, 0, -38),
		Vector3.new(30, 0, -44),
		Vector3.new(-34, 0, 38),
		Vector3.new(38, 0, 34),
		Vector3.new(-16, 0, -72),
	}

	for index, hotspot in hotspots do
		for patch = 1, rng:NextInteger(3, 5) do
			local at = hotspot + Vector3.new((rng:NextNumber() - 0.5) * 22, 0, (rng:NextNumber() - 0.5) * 22)
			local onWalk = math.abs(at.X) > ROAD_HALF or math.abs(at.Z) > ROAD_HALF
			local top = if onWalk then 0.56 else Streets.RoadY + 0.04
			local earthy = patch % 3 == 0
			Kit.part({
				name = "CrackedPaving",
				size = Vector3.new(rng:NextNumber() * 9 + 5, 0.3, rng:NextNumber() * 9 + 5),
				cframe = CFrame.new(at.X, top - 0.15, at.Z) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0),
				color = if earthy then Palette.City.Earth else Palette.City.AsphaltWorn,
				material = if earthy then Palette.Material.Earth else Palette.Material.Rubble,
				decor = true,
				parent = folder,
			})
		end

		-- A short buckled ridge so the damage is not all flat patches.
		Kit.wedge({
			name = "BuckledSlab",
			size = Vector3.new(rng:NextNumber() * 5 + 4, rng:NextNumber() * 1.6 + 0.9, rng:NextNumber() * 6 + 5),
			cframe = CFrame.new(hotspot + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0),
			color = Palette.City.Rubble,
			material = Palette.Material.Rubble,
			decor = true,
			parent = folder,
		})

		if index % 2 == 0 then
			Kit.part({
				name = "Scorch",
				size = Vector3.new(rng:NextNumber() * 14 + 10, 0.24, rng:NextNumber() * 14 + 10),
				cframe = CFrame.new(hotspot + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0),
				color = Color3.fromRGB(30, 28, 28),
				material = Palette.Material.Asphalt,
				decor = true,
				parent = folder,
			})
		end
	end

	Kit.markInvasionOnly(folder)
end

function Streets.build(parent: Instance, rng: Random): Folder
	local folder = Kit.folder("Streets", parent)
	buildSubgrade(folder)
	buildBlocks(folder)
	buildAvenue(folder, true)
	buildAvenue(folder, false)
	buildMarkings(folder)
	buildGroundDamage(folder, rng)
	return folder
end

return Streets
