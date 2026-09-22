--!nonstrict
-- Chapter One, Scene 1 ("A Normal Morning"): Uncle Daren's repair garage and
-- the residential/commercial block around it.
--
-- This occupies exactly one quadrant footprint of the existing city grid
-- (see City.lua's BUILDINGS table - the entry this replaces is commented
-- "Neighborhood block - see World/Neighborhood.lua" rather than deleted, so
-- the footprint budget stays visible in one place) instead of extending the
-- map, so it inherits the same containment/boundary and does not require
-- touching BoundaryService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Shared").Palette)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Neighborhood = {}

local BASE_Y = 0.5

-- Kai's home: a small room built in the airspace directly above Daren's
-- garage (inside its existing 20x13 footprint, well clear of the sloped
-- roof below and of both neighbouring apartment buildings, which occupy
-- ground-level footprint of their own - see the placement note above
-- buildHomeStair). This is a vertical-only addition: it claims zero new
-- ground footprint from the neighbourhood block.
local HOME_W, HOME_D, HOME_H = 9, 8, 7.2

export type Result = {
	Folder: Folder,
	GarageDoor: BasePart,
	GaragePosition: Vector3,
	SpawnCFrame: CFrame,
	DarenStandCFrame: CFrame,
	MiraStandCFrame: CFrame,
	KaiBedroomSpawn: CFrame,
}

-- One floor of a residential facade: recessed windows, a balcony with a
-- railing, and (roughly half the time) an air-conditioner unit or hanging
-- laundry line - the "apartments with balconies, air conditioners... and
-- fire stairs" the scene spec asks for, layered onto the same modular
-- vocabulary Buildings.lua already uses elsewhere.
local function residentialFloor(model: Model, origin: Vector3, along: Vector3, normal: Vector3, y: number, spanHalf: number, rng: Random)
	Kit.part({
		name = "WindowBand",
		size = along * (spanHalf * 2 - 4) + Vector3.new(0, 3.2, 0) + normal:Abs() * 1.1,
		position = origin + Vector3.new(0, y, 0) - normal * 0.3,
		color = Palette.City.Glass,
		material = Palette.Material.Glass,
		reflectance = 0.06,
		decor = true,
		parent = model,
	})
	if rng:NextNumber() < Palette.Quality.LitWindowChance * 1.6 then
		Kit.part({
			name = "LitWindow",
			size = along * 2.6 + Vector3.new(0, 2.0, 0) + normal:Abs() * 1.2,
			position = origin + Vector3.new(0, y, 0) - normal * 0.25 + along * ((rng:NextNumber() - 0.5) * (spanHalf * 2 - 8)),
			color = Palette.City.GlassLit,
			material = Palette.Material.Energy,
			transparency = 0.3,
			decor = true,
			parent = model,
		})
	end

	local balcony = origin + Vector3.new(0, y - 2.4, 0) + normal * 1.6
	Kit.part({
		name = "BalconySlab",
		size = along * 4.6 + Vector3.new(0, 0.35, 0) + normal:Abs() * 3,
		position = balcony,
		color = Palette.City.RoofDeck,
		material = Palette.Material.Concrete,
		decor = true,
		parent = model,
	})
	for _, offset in { -1, 1 } do
		Kit.part({
			name = "BalconyRail",
			size = along * 0.15 + Vector3.new(0, 1.5, 0) + normal:Abs() * 3,
			position = balcony + along * (offset * 2.25) + Vector3.new(0, 0.9, 0),
			color = Palette.City.FacadeTrim,
			material = Palette.Material.Metal,
			decor = true,
			parent = model,
		})
	end
	Kit.part({
		name = "BalconyRailFront",
		size = along * 4.6 + Vector3.new(0, 1.5, 0) + normal:Abs() * 0.12,
		position = balcony + normal * 1.45 + Vector3.new(0, 0.9, 0),
		color = Palette.City.FacadeTrim,
		material = Palette.Material.Metal,
		transparency = 0.35,
		decor = true,
		parent = model,
	})

	if rng:NextNumber() < 0.55 then
		Kit.part({
			name = "AirConditioner",
			size = Vector3.new(1.3, 0.8, 0.9),
			position = origin + Vector3.new(0, y + 1.4, 0) + normal * 1.0 + along * (spanHalf * 0.55),
			color = Palette.City.Equipment,
			material = Palette.Material.MetalWorn,
			decor = true,
			parent = model,
		})
	else
		-- A sagging laundry line between the rail and the wall.
		Kit.part({
			name = "LaundryLine",
			size = along * 3.2 + Vector3.new(0.04, 0.04, 0),
			position = origin + Vector3.new(0, y - 1.0, 0) + normal * 0.9,
			color = Color3.fromRGB(210, 206, 196),
			material = Palette.Material.Concrete,
			decor = true,
			parent = model,
		})
	end
end

-- A zigzag fire escape climbing one side of the building - iron platforms
-- and diagonal stair runs, welded rather than collidable (decorative).
local function buildFireEscape(model: Model, cornerX: number, cornerZ: number, floors: number, rng: Random)
	local outward = Vector3.new(if cornerX >= 0 then 1 else -1, 0, 0)
	local along = Vector3.new(0, 0, if cornerZ >= 0 then 1 else -1)
	local base = Vector3.new(cornerX, 0, cornerZ) + outward * 1.6

	for floor = 1, floors - 1 do
		local y = BASE_Y + 2 + floor * 9.5
		Kit.part({
			name = "FireEscapePlatform",
			size = Vector3.new(4.4, 0.2, 3.4),
			position = base + Vector3.new(0, y, 0),
			color = Palette.City.Equipment,
			material = Palette.Material.MetalWorn,
			decor = true,
			parent = model,
		})
		for _, side in { -1, 1 } do
			Kit.part({
				name = "FireEscapeRail",
				size = Vector3.new(0.12, 1.1, 3.4),
				position = base + Vector3.new(side * 2.1, y + 0.6, 0),
				color = Palette.City.Equipment,
				material = Palette.Material.Metal,
				decor = true,
				parent = model,
			})
		end
		Kit.wedge({
			name = "FireEscapeStair",
			size = Vector3.new(4.2, 4.2, 2.6),
			cframe = CFrame.new(base + Vector3.new(0, y - 2.1, 0) + along * 2.6) * CFrame.Angles(0, if cornerZ >= 0 then math.rad(180) else 0, 0),
			color = Palette.City.Equipment,
			material = Palette.Material.MetalWorn,
			parent = model,
		})
	end

	-- Roof access ladder for the top run.
	Kit.part({
		name = "FireEscapeLadder",
		size = Vector3.new(1.6, floors * 9.5, 0.15),
		position = base + Vector3.new(0, floors * 9.5 / 2, 1.4),
		color = Palette.City.Equipment,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	})
end

-- A small apartment block: same core-mass approach as Buildings.lua, but
-- dressed with residentialFloor()/buildFireEscape() instead of the office
-- window-band treatment, so the neighborhood reads as lived-in rather than
-- corporate.
local function buildApartment(parent: Instance, x: number, z: number, width: number, depth: number, floors: number, facadeIndex: number, rng: Random): Model
	local floorHeight = 9.5
	local height = floors * floorHeight
	local model = Kit.model("Apartment", parent)
	local facade = Palette.City.Facade[((facadeIndex - 1) % #Palette.City.Facade) + 1]

	Kit.part({ name = "Foundation", size = Vector3.new(width + 2, 3, depth + 2), position = Vector3.new(x, BASE_Y + 1.5, z), color = Palette.City.Foundation, material = Palette.Material.Concrete, parent = model })
	Kit.part({ name = "Core", size = Vector3.new(width, height, depth), position = Vector3.new(x, BASE_Y + 3 + height / 2, z), color = facade, material = Palette.Material.Concrete, parent = model })

	-- Detail only the face pointing toward the courtyard (south, -z local),
	-- matching Buildings.lua's "only detail the street-facing side" rule.
	local normal = Vector3.new(0, 0, -1)
	local along = Vector3.new(1, 0, 0)
	local origin = Vector3.new(x, 0, z) + normal * (depth / 2)
	local spanHalf = width / 2

	for floor = 1, floors do
		residentialFloor(model, origin, along, normal, BASE_Y + 3 + (floor - 0.35) * floorHeight, spanHalf, rng)
	end

	-- Rooftop: parapet, tank, vents, pipe run down the blind side.
	local topY = BASE_Y + 3 + height
	Kit.part({ name = "RoofDeck", size = Vector3.new(width - 1, 0.6, depth - 1), position = Vector3.new(x, topY + 0.3, z), color = Palette.City.RoofDeck, material = Palette.Material.Concrete, decor = true, parent = model })
	Kit.cylinder({ name = "WaterTank", size = Vector3.new(3.6, 3.2, 3.2), position = Vector3.new(x - width * 0.22, topY + 2.4, z + depth * 0.2), color = Palette.City.Equipment, material = Palette.Material.MetalWorn, decor = true, parent = model }, "y")
	Kit.part({ name = "TankLegs", size = Vector3.new(3.8, 0.9, 3.8), position = Vector3.new(x - width * 0.22, topY + 0.75, z + depth * 0.2), color = Palette.City.Equipment, material = Palette.Material.Metal, decor = true, parent = model })
	for index = 1, 2 do
		Kit.part({ name = "RoofUnit", size = Vector3.new(2.6, 1.8, 2.6), position = Vector3.new(x + (index - 1.5) * 5, topY + 1.1, z - depth * 0.22), color = Palette.City.Equipment, material = Palette.Material.MetalWorn, decor = true, parent = model })
	end
	Kit.part({ name = "PipeRun", size = Vector3.new(0.35, height, 0.35), position = Vector3.new(x + width / 2 + 0.3, BASE_Y + 3 + height / 2, z + depth * 0.3), color = Palette.City.Equipment, material = Palette.Material.Metal, decor = true, parent = model })

	buildFireEscape(model, x - width / 2, z + depth / 2, floors, rng)

	return model
end

-- Uncle Daren's repair garage: a low workshop with a roll-up door, a
-- projecting sign, and scattered vehicle parts out front - distinct from
-- both the office towers and the apartments so it reads as a landmark.
local function buildGarage(parent: Instance, x: number, z: number, rng: Random): (Model, BasePart)
	local model = Kit.model("DarenGarage", parent)
	local width, depth, height = 20, 13, 7.5

	Kit.part({ name = "Foundation", size = Vector3.new(width + 1.5, 2, depth + 1.5), position = Vector3.new(x, BASE_Y + 1, z), color = Palette.City.Foundation, material = Palette.Material.Concrete, parent = model })
	Kit.part({ name = "Core", size = Vector3.new(width, height, depth), position = Vector3.new(x, BASE_Y + 2 + height / 2, z), color = Color3.fromRGB(96, 90, 82), material = Palette.Material.Concrete, parent = model })
	Kit.wedge({ name = "RoofSlope", size = Vector3.new(width + 1, 2.6, depth + 1), cframe = CFrame.new(x, BASE_Y + 2 + height + 1.3, z) * CFrame.Angles(0, math.rad(90), 0), color = Palette.City.RoofDeck, parent = model })

	-- Garage door facing south (-z, toward the little courtyard/sidewalk).
	local doorFace = Vector3.new(x, 0, z - depth / 2)
	local door = Kit.part({
		name = "GarageDoor",
		size = Vector3.new(width * 0.55, height * 0.72, 0.3),
		position = doorFace + Vector3.new(0, BASE_Y + 2 + height * 0.36, 0) - Vector3.new(0, 0, 0.2),
		color = Palette.City.Equipment,
		material = Palette.Material.MetalWorn,
		decor = true,
		parent = model,
	})
	for band = 1, 4 do
		Kit.part({
			name = "DoorBand",
			size = Vector3.new(width * 0.55 - 0.4, 0.15, 0.05),
			position = doorFace + Vector3.new(0, BASE_Y + 1.2 + band * (height * 0.72 / 5), 0) - Vector3.new(0, 0, 0.36),
			color = Palette.City.FacadeTrim,
			material = Palette.Material.Metal,
			decor = true,
			parent = model,
		})
	end

	-- A small side window and the office door.
	Kit.part({ name = "OfficeWindow", size = Vector3.new(3, 2.2, 0.2), position = doorFace + Vector3.new(width * 0.3, BASE_Y + 2 + height * 0.55, 0) - Vector3.new(0, 0, 0.2), color = Palette.City.Glass, material = Palette.Material.Glass, decor = true, parent = model })
	Kit.part({ name = "OfficeDoor", size = Vector3.new(2.2, 4.2, 0.2), position = doorFace + Vector3.new(width * 0.32, BASE_Y + 2 + 2.1, 0) - Vector3.new(0, 0, 0.2), color = Color3.fromRGB(60, 66, 72), material = Palette.Material.Metal, decor = true, parent = model })

	-- Projecting sign with a warm bulb - the beat marker for Daren's shop.
	Kit.part({ name = "SignArm", size = Vector3.new(0.3, 0.3, 3.4), position = doorFace + Vector3.new(-width * 0.42, BASE_Y + 2 + height + 0.6, 0) - Vector3.new(0, 0, 1.6), color = Palette.City.Equipment, material = Palette.Material.Metal, decor = true, parent = model })
	local sign = Kit.part({
		name = "ShopSign",
		size = Vector3.new(3.6, 1.6, 0.25),
		cframe = CFrame.new(doorFace + Vector3.new(-width * 0.42, BASE_Y + 2 + height + 0.6, 0) - Vector3.new(0, 0, 3.2)) * CFrame.Angles(0, math.rad(90), 0),
		color = Palette.Energy.Amber,
		material = Palette.Material.Energy,
		transparency = 0.2,
		decor = true,
		parent = model,
	})
	Kit.light(sign, Palette.Energy.Amber, 14, 1.4, false)

	-- Front apron: a couple of drone/vehicle parts and a workbench, so the
	-- shop looks lived-in rather than a closed storefront.
	local apron = doorFace + Vector3.new(0, 0, -3.2)
	Kit.part({ name = "Workbench", size = Vector3.new(4.4, 1.1, 1.6), position = apron + Vector3.new(-4.5, BASE_Y + 0.55, -1.2), color = Palette.City.Equipment, material = Palette.Material.MetalWorn, decor = true, parent = model })
	Kit.part({ name = "PartsCrate", size = Vector3.new(1.6, 1.2, 1.6), position = apron + Vector3.new(3.6, BASE_Y + 0.6, -1.6), color = Palette.Ancient.Bronze, material = Palette.Material.MetalWorn, decor = true, parent = model })
	Props.scooter(model, apron + Vector3.new(5.6, 0, 0.6), math.rad(20))
	Props.scooter(model, apron + Vector3.new(-6.4, 0, 1.8), math.rad(-35))

	return model, door
end

-- A compact switchback stair hugging the garage's west wall, climbing from
-- ground level to Kai's home floor above. Kept deliberately narrow
-- (projects only ~2.6 studs out from the wall, matching buildFireEscape's
-- own proportions) and positioned against the BACK half of the garage's west
-- wall specifically: the west apartment building's footprint reaches only to
-- roughly z + half*0.42 - 10 in world Z (see buildApartment's own call site
-- in Neighborhood.build), well short of the garage's own back edge, so this
-- stays clear of it. Landing at the top opens directly into the living area.
local function buildHomeStair(parent: Instance, garageX: number, garageZ: number, floorY: number, rng: Random): Model
	local model = Kit.model("HomeStair", parent)
	local wallX = garageX - HOME_W / 2
	local baseZ = garageZ + HOME_D / 2 - 1.4 -- deep against the back half of the wall
	local rise = floorY - BASE_Y
	local landings = 3
	local step = rise / landings

	for level = 0, landings do
		local y = BASE_Y + step * level
		Kit.part({
			name = "StairLanding",
			size = Vector3.new(2.6, 0.25, 2.6),
			position = Vector3.new(wallX - 1.6, y, baseZ),
			color = Palette.City.Equipment,
			material = Palette.Material.MetalWorn,
			parent = model,
		})
		if level < landings then
			Kit.wedge({
				name = "StairFlight",
				size = Vector3.new(2.4, step, 3.4),
				cframe = CFrame.new(wallX - 1.6, y + step / 2, baseZ - 2.9) * CFrame.Angles(0, math.rad(90), 0),
				color = Palette.City.Equipment,
				material = Palette.Material.MetalWorn,
				parent = model,
			})
		end
		if level > 0 then
			for _, side in { -1, 1 } do
				Kit.part({
					name = "StairRail",
					size = Vector3.new(0.1, 3, 2.6),
					position = Vector3.new(wallX - 1.6 + side * 1.3, y + 1.4, baseZ),
					color = Palette.City.Equipment,
					material = Palette.Material.Metal,
					decor = true,
					parent = model,
				})
			end
		end
	end

	return model
end

-- Kai's home: floor, walls, a flat roof, one interior partition splitting a
-- small living area (south, at the stair landing) from Kai's bedroom
-- (north), and the minimum furniture needed to read as lived-in. Doors and
-- the window are open gaps or inset glass rather than functional hardware,
-- matching how the rest of this file already treats openings (see
-- buildGarage's OfficeDoor). Returns the dedicated spawn marker CFrame -
-- never the model's own pivot.
local function buildHome(parent: Instance, garageX: number, garageZ: number, rng: Random): CFrame
	local model = Kit.model("KaiHome", parent)
	local cx, cz = garageX, garageZ
	local floorY = BASE_Y + 13.4
	local wallY = floorY + HOME_H / 2
	local wallT = 0.35
	local partitionZ = cz -- south (living area) / north (bedroom) split

	Kit.part({ name = "HomeFloor", size = Vector3.new(HOME_W, 0.4, HOME_D), position = Vector3.new(cx, floorY - 0.2, cz), color = Color3.fromRGB(120, 98, 74), material = Enum.Material.WoodPlanks, parent = model })
	Kit.part({ name = "HomeRoof", size = Vector3.new(HOME_W + 0.6, 0.4, HOME_D + 0.6), position = Vector3.new(cx, floorY + HOME_H + 0.2, cz), color = Palette.City.RoofDeck, material = Palette.Material.Concrete, decor = true, parent = model })

	-- South wall (living area, faces the stair landing).
	Kit.part({ name = "HomeWallSouth", size = Vector3.new(HOME_W, HOME_H, wallT), position = Vector3.new(cx, wallY, cz - HOME_D / 2), color = Color3.fromRGB(150, 138, 118), material = Palette.Material.Concrete, parent = model })
	-- North wall (bedroom) with an inset window - a glass panel laid over the
	-- solid wall, not a hole through it, the same technique residentialFloor
	-- already uses for apartment windows elsewhere in this file.
	Kit.part({ name = "HomeWallNorth", size = Vector3.new(HOME_W, HOME_H, wallT), position = Vector3.new(cx, wallY, cz + HOME_D / 2), color = Color3.fromRGB(150, 138, 118), material = Palette.Material.Concrete, parent = model })
	Kit.part({ name = "HomeWindow", size = Vector3.new(2.4, 2, 0.1), position = Vector3.new(cx + 1.4, floorY + HOME_H * 0.55, cz + HOME_D / 2 - 0.18), color = Palette.City.Glass, material = Palette.Material.Glass, decor = true, parent = model })
	-- East wall: solid.
	Kit.part({ name = "HomeWallEast", size = Vector3.new(wallT, HOME_H, HOME_D), position = Vector3.new(cx + HOME_W / 2, wallY, cz), color = Color3.fromRGB(150, 138, 118), material = Palette.Material.Concrete, parent = model })
	-- West wall: open for the last 2.4 studs at the south end (the entry,
	-- reached from the stair landing); solid the rest of the way.
	Kit.part({ name = "HomeWallWest", size = Vector3.new(wallT, HOME_H, HOME_D - 2.4), position = Vector3.new(cx - HOME_W / 2, wallY, cz + 1.2), color = Color3.fromRGB(150, 138, 118), material = Palette.Material.Concrete, parent = model })
	Kit.part({ name = "HomeDoorFrame", size = Vector3.new(wallT, 0.3, 2.4), position = Vector3.new(cx - HOME_W / 2, floorY + HOME_H - 0.15, cz - HOME_D / 2 + 1.2), color = Palette.City.FacadeTrim, material = Palette.Material.Metal, decor = true, parent = model })

	-- Interior partition: living area (south) / bedroom (north), with a
	-- 2-stud doorway gap centred on the room.
	Kit.part({ name = "HomePartitionWest", size = Vector3.new(HOME_W / 2 - 1, HOME_H, wallT), position = Vector3.new(cx - HOME_W / 4 - 0.5, wallY, partitionZ), color = Color3.fromRGB(158, 148, 130), material = Palette.Material.Concrete, parent = model })
	Kit.part({ name = "HomePartitionEast", size = Vector3.new(HOME_W / 2 - 1, HOME_H, wallT), position = Vector3.new(cx + HOME_W / 4 + 0.5, wallY, partitionZ), color = Color3.fromRGB(158, 148, 130), material = Palette.Material.Concrete, parent = model })

	-- Living area furniture: a small bench and side table only.
	Kit.part({ name = "LivingBench", size = Vector3.new(2.6, 0.9, 0.9), position = Vector3.new(cx + 2.6, floorY + 0.65, cz - HOME_D / 2 + 1), color = Color3.fromRGB(96, 70, 54), material = Enum.Material.Fabric, decor = true, parent = model })
	Kit.part({ name = "SideTable", size = Vector3.new(0.8, 0.7, 0.8), position = Vector3.new(cx + 3.6, floorY + 0.55, cz - 0.6), color = Color3.fromRGB(90, 68, 50), material = Enum.Material.Wood, decor = true, parent = model })
	Kit.light(Kit.part({ name = "LivingLightFixture", size = Vector3.new(0.6, 0.15, 0.6), position = Vector3.new(cx, floorY + HOME_H - 0.2, cz - HOME_D / 4), color = Palette.City.Equipment, material = Palette.Material.Metal, decor = true, parent = model }), Color3.fromRGB(255, 224, 176), 16, 1.1)

	-- Bedroom furniture: bed against the north wall, desk+chair on the east
	-- wall, a shelf on the west wall with one small object tying back to
	-- Daren, a ceiling light.
	Kit.part({ name = "BedFrame", size = Vector3.new(3, 0.9, 2.4), position = Vector3.new(cx - 2.3, floorY + 0.5, cz + 2.4), color = Color3.fromRGB(92, 68, 50), material = Enum.Material.Wood, decor = true, parent = model })
	Kit.part({ name = "BedMattress", size = Vector3.new(2.8, 0.4, 2.2), position = Vector3.new(cx - 2.3, floorY + 1.15, cz + 2.4), color = Color3.fromRGB(210, 200, 182), material = Enum.Material.Fabric, decor = true, parent = model })
	Kit.part({ name = "BedPillow", size = Vector3.new(0.9, 0.25, 0.6), position = Vector3.new(cx - 2.3, floorY + 1.45, cz + 3.3), color = Color3.fromRGB(232, 226, 214), material = Enum.Material.Fabric, decor = true, parent = model })
	Kit.part({ name = "Desk", size = Vector3.new(1.6, 0.75, 1.2), position = Vector3.new(cx + 3.5, floorY + 0.55, cz + 1.4), color = Color3.fromRGB(90, 68, 50), material = Enum.Material.Wood, decor = true, parent = model })
	Kit.part({ name = "DeskChair", size = Vector3.new(0.8, 0.85, 0.8), position = Vector3.new(cx + 2.9, floorY + 0.55, cz + 0.4), color = Color3.fromRGB(60, 66, 72), material = Enum.Material.Fabric, decor = true, parent = model })
	Kit.light(Kit.part({ name = "DeskLamp", size = Vector3.new(0.3, 0.5, 0.3), position = Vector3.new(cx + 3.9, floorY + 1.1, cz + 1.1), color = Palette.City.Equipment, material = Palette.Material.Metal, decor = true, parent = model }), Color3.fromRGB(255, 214, 150), 10, 1)
	Kit.part({ name = "Shelf", size = Vector3.new(1.8, 0.15, 0.4), position = Vector3.new(cx - 3.9, floorY + 1.6, cz + 1.2), color = Color3.fromRGB(90, 68, 50), material = Enum.Material.Wood, decor = true, parent = model })
	-- A framed photo on the shelf - the one personal object tying this room
	-- back to Daren, kept as a single small accent rather than set dressing.
	Kit.part({ name = "DarenPhotoFrame", size = Vector3.new(0.5, 0.4, 0.05), position = Vector3.new(cx - 3.9, floorY + 1.95, cz + 1.05), color = Palette.City.FacadeTrim, material = Palette.Material.Metal, decor = true, parent = model })
	Kit.light(Kit.part({ name = "BedroomLightFixture", size = Vector3.new(0.6, 0.15, 0.6), position = Vector3.new(cx, floorY + HOME_H - 0.2, cz + HOME_D / 4), color = Palette.City.Equipment, material = Palette.Material.Metal, decor = true, parent = model }), Color3.fromRGB(255, 224, 176), 16, 1.1)

	-- Dedicated spawn marker: clear of the bed (x <= cx-0.8), the desk/chair
	-- (x >= cx+2.6), the partition (>1.5 studs south of the north wall side),
	-- and every wall - never the model's own pivot.
	local spawnCFrame = CFrame.lookAt(Vector3.new(cx + 0.5, floorY + 3.5, cz + 2), Vector3.new(cx + 0.5, floorY + 3.5, cz + 4))

	buildHomeStair(parent, garageX, garageZ, floorY, rng)

	return spawnCFrame
end

--[[
	Builds the whole neighborhood block into the given quadrant footprint
	(matching one of City.lua's BUILDINGS entries) and returns the handles
	ChapterOneDirector needs: where to spawn the player, where Daren and Mira
	should stand for the opening conversation, and the garage door itself
	(used as the world-space beat marker before the player has met anyone).
]]
function Neighborhood.build(parent: Instance, x: number, z: number, footprint: number, rng: Random): Result
	local folder = Kit.folder("Neighborhood", parent)

	-- Layout inside the footprint (footprint is square, centred on x,z):
	--   south third (toward +z, away from the avenue): Daren's garage + apron
	--   north two-thirds (toward -z/-x, toward the avenue corner): two small
	--   apartment buildings framing a shared courtyard with market stalls.
	local half = footprint / 2
	local garageX, garageZ = x - half * 0.15, z + half * 0.42
	local _garageModel, garageDoor = buildGarage(folder, garageX, garageZ, rng)

	buildApartment(folder, x - half * 0.55, z - half * 0.35, 16, 20, 5, 2, rng)
	buildApartment(folder, x + half * 0.5, z - half * 0.15, 15, 18, 4, 4, rng)

	-- Small courtyard paving between the buildings and the sidewalk.
	Kit.part({
		name = "CourtyardPad",
		size = Vector3.new(footprint - 4, 0.3, footprint - 4),
		position = Vector3.new(x, BASE_Y - 0.15, z),
		color = Palette.City.SidewalkWorn,
		material = Palette.Material.Sidewalk,
		decor = true,
		parent = folder,
	})

	-- Two food/market stalls near the courtyard's avenue-facing corner.
	Props.marketStall(folder, Vector3.new(x - half * 0.05, BASE_Y, z - half * 0.62), math.rad(160), 1)
	Props.marketStall(folder, Vector3.new(x + half * 0.28, BASE_Y, z - half * 0.6), math.rad(200), 3)

	-- Street furniture along the courtyard edge.
	Props.bench(folder, Vector3.new(x - half * 0.7, BASE_Y, z + half * 0.05), math.rad(90))
	Props.bin(folder, Vector3.new(x - half * 0.68, BASE_Y, z + half * 0.2))
	Props.utilityBox(folder, Vector3.new(x + half * 0.75, BASE_Y, z + half * 0.55), 0)
	Props.drain(folder, Vector3.new(x, BASE_Y, z + half * 0.85), 0)
	Props.busStop(folder, Vector3.new(x + half * 0.78, BASE_Y, z - half * 0.2), math.rad(90))

	-- A couple of parked delivery/personal vehicles along the block's own
	-- frontage (separate from City.lua's Dressing pass on the main avenue).
	Props.vehicle(folder, Vector3.new(x + half * 0.15, 0, z + half * 0.75), math.rad(4), false)
	Props.scooter(folder, Vector3.new(x - half * 0.35, 0, z + half * 0.8), math.rad(-12))

	local spawnCFrame = CFrame.lookAt(Vector3.new(garageX + 2, BASE_Y + 3.2, garageZ - 6), Vector3.new(garageX, BASE_Y + 3.2, garageZ))
	local darenStand = CFrame.lookAt(Vector3.new(garageX - 1.5, BASE_Y + 3.2, garageZ - 4.5), Vector3.new(garageX, BASE_Y + 3.2, garageZ - 8))
	local miraStand = CFrame.lookAt(Vector3.new(garageX + 2.5, BASE_Y + 3.2, garageZ - 5), Vector3.new(garageX, BASE_Y + 3.2, garageZ - 8))
	local bedroomSpawn = buildHome(folder, garageX, garageZ, rng)

	return {
		Folder = folder,
		GarageDoor = garageDoor,
		GaragePosition = Vector3.new(garageX, BASE_Y, garageZ),
		SpawnCFrame = spawnCFrame,
		DarenStandCFrame = darenStand,
		MiraStandCFrame = miraStand,
		KaiBedroomSpawn = bedroomSpawn,
	}
end

return Neighborhood
