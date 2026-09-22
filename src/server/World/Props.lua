--!nonstrict
-- Street furniture and debris.
--
-- Everything here is decorative: nothing collides, so rubble can never trap the
-- player or wedge a Warden against a kerb. The only exceptions are the two
-- large wreck bodies, which are solid enough to read as cover.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Shared").Palette)
local Kit = require(script.Parent.Kit)

local Props = {}

local WALK_Y = 0.5

function Props.streetLamp(parent: Instance, position: Vector3, lit: boolean): Model
	local model = Kit.model("StreetLamp", parent)
	Kit.cylinder({
		name = "Base",
		size = Vector3.new(1.4, 1.6, 1.6),
		position = position + Vector3.new(0, 0.7, 0),
		color = Palette.City.Equipment,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	}, "y")
	Kit.part({
		name = "Pole",
		size = Vector3.new(0.55, 16, 0.55),
		position = position + Vector3.new(0, 8, 0),
		color = Palette.City.Equipment,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	})
	local armDirection = if position.X >= 0 then -1 else 1
	Kit.part({
		name = "Arm",
		size = Vector3.new(5, 0.45, 0.45),
		position = position + Vector3.new(armDirection * 2.4, 15.7, 0),
		color = Palette.City.Equipment,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	})
	local head = Kit.part({
		name = "Head",
		size = Vector3.new(2.6, 0.5, 1.2),
		position = position + Vector3.new(armDirection * 4.6, 15.3, 0),
		color = if lit then Palette.Sky.Emergency else Palette.City.Equipment,
		material = if lit then Palette.Material.Energy else Palette.Material.Metal,
		transparency = if lit then 0.15 else 0,
		decor = true,
		parent = model,
	})
	if lit then
		Kit.light(head, Palette.Sky.Emergency, 26, 1.2, false)
	end
	return model
end

function Props.barrier(parent: Instance, position: Vector3, rotation: number, lit: boolean): Model
	local model = Kit.model("Barrier", parent)
	local cframe = CFrame.new(position) * CFrame.Angles(0, rotation, 0)
	Kit.part({
		name = "Rail",
		size = Vector3.new(9, 1.1, 0.5),
		cframe = cframe * CFrame.new(0, 2.4, 0),
		color = Palette.Sky.Emergency,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	})
	Kit.part({
		name = "RailLower",
		size = Vector3.new(9, 0.9, 0.5),
		cframe = cframe * CFrame.new(0, 1.1, 0),
		color = Palette.City.Curb,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	})
	for _, side in { -1, 1 } do
		Kit.part({
			name = "Leg",
			size = Vector3.new(0.5, 3, 2.6),
			cframe = cframe * CFrame.new(side * 4.1, 1.5, 0),
			color = Palette.City.Equipment,
			material = Palette.Material.Metal,
			decor = true,
			parent = model,
		})
	end
	if lit then
		local beacon = Kit.part({
			name = "Beacon",
			size = Vector3.new(0.8, 0.8, 0.8),
			cframe = cframe * CFrame.new(0, 3.3, 0),
			color = Palette.Sky.Emergency,
			material = Palette.Material.Energy,
			decor = true,
			parent = model,
		})
		Kit.light(beacon, Palette.Sky.Emergency, 18, 1.6, false)
	end
	return model
end

function Props.trafficSignal(parent: Instance, position: Vector3, rotation: number): Model
	local model = Kit.model("TrafficSignal", parent)
	local cframe = CFrame.new(position) * CFrame.Angles(0, rotation, 0)
	Kit.part({
		name = "Post",
		size = Vector3.new(0.6, 13, 0.6),
		cframe = cframe * CFrame.new(0, 6.5, 0),
		color = Palette.City.Equipment,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	})
	Kit.part({
		name = "Arm",
		size = Vector3.new(7, 0.4, 0.4),
		cframe = cframe * CFrame.new(3.2, 12.6, 0),
		color = Palette.City.Equipment,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	})
	Kit.part({
		name = "Housing",
		size = Vector3.new(1.2, 3.2, 1.2),
		cframe = cframe * CFrame.new(6.2, 11.2, 0),
		color = Color3.fromRGB(40, 42, 44),
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	})
	return model
end

-- A civilian vehicle abandoned mid-evacuation. Blocks plus a wedge roofline.
function Props.vehicle(parent: Instance, position: Vector3, rotation: number, wrecked: boolean): Model
	local model = Kit.model("Vehicle", parent)
	local cframe = CFrame.new(position) * CFrame.Angles(0, rotation, if wrecked then math.rad(9) else 0)
	local body = if wrecked then Color3.fromRGB(74, 70, 68) else Color3.fromRGB(86, 96, 110)

	Kit.part({
		name = "Body",
		size = Vector3.new(6.4, 2.2, 14),
		cframe = cframe * CFrame.new(0, 2.2, 0),
		color = body,
		material = Palette.Material.Metal,
		collide = true,
		castShadow = true,
		parent = model,
	})
	Kit.part({
		name = "Cabin",
		size = Vector3.new(6, 2.4, 7),
		cframe = cframe * CFrame.new(0, 4.3, -0.6),
		color = if wrecked then Color3.fromRGB(60, 58, 56) else body,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	})
	Kit.part({
		name = "Glass",
		size = Vector3.new(5.4, 1.8, 6.4),
		cframe = cframe * CFrame.new(0, 4.5, -0.6),
		color = Palette.City.Glass,
		material = Palette.Material.Glass,
		transparency = if wrecked then 0.1 else 0.35,
		decor = true,
		parent = model,
	})
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.cylinder({
				name = "Wheel",
				size = Vector3.new(1.2, 2.6, 2.6),
				cframe = cframe * CFrame.new(sx * 3.1, 1.4, sz * 4.6),
				color = Color3.fromRGB(28, 28, 30),
				material = Palette.Material.Metal,
				decor = true,
				parent = model,
			}, "x")
		end
	end
	if wrecked then
		Kit.wedge({
			name = "CrumpledHood",
			size = Vector3.new(6, 1.8, 3.4),
			cframe = cframe * CFrame.new(0, 3.4, 5.6) * CFrame.Angles(math.rad(-22), 0, 0),
			color = body,
			material = Palette.Material.MetalWorn,
			decor = true,
			parent = model,
		})
	end
	return model
end

-- Loose debris. Deliberately non-colliding so it never becomes a trap.
function Props.rubble(parent: Instance, centre: Vector3, radius: number, count: number, rng: Random): Model
	local model = Kit.model("Rubble", parent)
	for index = 1, count do
		local angle = rng:NextNumber() * math.pi * 2
		local distance = rng:NextNumber() ^ 0.6 * radius
		local at = centre + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local size = Vector3.new(rng:NextNumber() * 3 + 1, rng:NextNumber() * 2 + 0.7, rng:NextNumber() * 3 + 1)
		Kit.part({
			name = "Chunk",
			size = size,
			cframe = CFrame.new(at + Vector3.new(0, size.Y * 0.35, 0))
				* CFrame.Angles(rng:NextNumber() * 0.7, rng:NextNumber() * math.pi * 2, rng:NextNumber() * 0.7),
			color = if index % 4 == 0 then Palette.City.Sidewalk else Palette.City.Rubble,
			material = Palette.Material.Rubble,
			decor = true,
			parent = model,
		})
	end
	-- A couple of bent rebar strands reading as structural failure.
	for index = 1, math.max(1, math.floor(count / 6)) do
		local angle = rng:NextNumber() * math.pi * 2
		Kit.cylinder({
			name = "Rebar",
			size = Vector3.new(0.3, 0.3, rng:NextNumber() * 4 + 2.5),
			cframe = CFrame.new(centre + Vector3.new(math.cos(angle) * radius * 0.5, 1, math.sin(angle) * radius * 0.5))
				* CFrame.Angles(math.rad(rng:NextNumber() * 60 - 30), rng:NextNumber() * math.pi, math.rad(rng:NextNumber() * 40 - 20)),
			color = Palette.City.RebarMetal,
			material = Palette.Material.MetalWorn,
			decor = true,
			parent = model,
		}, "z")
	end
	return model
end

function Props.planter(parent: Instance, position: Vector3): Model
	local model = Kit.model("Planter", parent)
	Kit.part({
		name = "Box",
		size = Vector3.new(5, 2, 5),
		position = position + Vector3.new(0, 1, 0),
		color = Palette.City.Sidewalk,
		material = Palette.Material.Concrete,
		decor = true,
		parent = model,
	})
	Kit.part({
		name = "Soil",
		size = Vector3.new(4.2, 0.4, 4.2),
		position = position + Vector3.new(0, 2.1, 0),
		color = Palette.City.Earth,
		material = Palette.Material.Earth,
		decor = true,
		parent = model,
	})
	return model
end

-- A sidewalk bench: two supports, a seat, a backrest.
function Props.bench(parent: Instance, position: Vector3, rotation: number): Model
	local model = Kit.model("Bench", parent)
	local cframe = CFrame.new(position) * CFrame.Angles(0, rotation, 0)
	Kit.part({
		name = "Seat",
		size = Vector3.new(5, 0.3, 1.6),
		cframe = cframe * CFrame.new(0, 1.4, 0),
		color = Palette.City.Equipment,
		material = Palette.Material.MetalWorn,
		decor = true,
		parent = model,
	})
	Kit.part({
		name = "Back",
		size = Vector3.new(5, 1.1, 0.2),
		cframe = cframe * CFrame.new(0, 2.0, -0.7),
		color = Palette.City.Equipment,
		material = Palette.Material.MetalWorn,
		decor = true,
		parent = model,
	})
	for _, side in { -1, 1 } do
		Kit.part({
			name = "Leg",
			size = Vector3.new(0.5, 1.4, 1.6),
			cframe = cframe * CFrame.new(side * 2.1, 0.7, 0),
			color = Palette.City.Foundation,
			material = Palette.Material.Metal,
			decor = true,
			parent = model,
		})
	end
	return model
end

-- A street bin: a cylindrical body with a rim.
function Props.bin(parent: Instance, position: Vector3): Model
	local model = Kit.model("Bin", parent)
	Kit.cylinder({
		name = "Body",
		size = Vector3.new(2.6, 1.2, 1.2),
		position = position + Vector3.new(0, 1.3, 0),
		color = Palette.City.Equipment,
		material = Palette.Material.MetalWorn,
		decor = true,
		parent = model,
	}, "y")
	Kit.cylinder({
		name = "Rim",
		size = Vector3.new(0.2, 1.35, 1.35),
		position = position + Vector3.new(0, 2.5, 0),
		color = Palette.City.FacadeTrim,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	}, "y")
	return model
end

-- A curbside utility/drainage box - the small unglamorous detail Scene 1
-- explicitly asks for alongside benches and bins.
function Props.utilityBox(parent: Instance, position: Vector3, rotation: number): Model
	local model = Kit.model("UtilityBox", parent)
	local cframe = CFrame.new(position) * CFrame.Angles(0, rotation, 0)
	Kit.part({
		name = "Box",
		size = Vector3.new(2.2, 2.6, 1.8),
		cframe = cframe * CFrame.new(0, 1.3, 0),
		color = Palette.City.Equipment,
		material = Palette.Material.MetalWorn,
		decor = true,
		parent = model,
	})
	Kit.part({
		name = "Vent",
		size = Vector3.new(1.6, 0.15, 1.2),
		cframe = cframe * CFrame.new(0, 2.15, 0.95),
		color = Palette.City.FacadeTrim,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	})
	Kit.part({
		name = "WarningStripe",
		size = Vector3.new(2.24, 0.3, 0.05),
		cframe = cframe * CFrame.new(0, 0.5, 0.93),
		color = Palette.Energy.Amber,
		material = Palette.Material.Concrete,
		decor = true,
		parent = model,
	})
	return model
end

-- A drainage grate set flush into the sidewalk/curb - purely decorative.
function Props.drain(parent: Instance, position: Vector3, rotation: number): Model
	local model = Kit.model("Drain", parent)
	Kit.part({
		name = "Grate",
		size = Vector3.new(2.4, 0.06, 1.4),
		cframe = CFrame.new(position + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, rotation, 0),
		color = Color3.fromRGB(24, 26, 28),
		material = Palette.Material.MetalWorn,
		decor = true,
		parent = model,
	})
	return model
end

-- A market/food stall: awning over a serving counter, with a couple of
-- hanging accent lights. `hue` picks from a small awning palette so a row of
-- stalls does not read as identical copies.
local AWNING_COLORS = {
	Color3.fromRGB(196, 90, 70),
	Color3.fromRGB(70, 140, 120),
	Color3.fromRGB(196, 160, 70),
	Color3.fromRGB(90, 110, 180),
}

function Props.marketStall(parent: Instance, position: Vector3, rotation: number, hue: number?): Model
	local model = Kit.model("MarketStall", parent)
	local cframe = CFrame.new(position) * CFrame.Angles(0, rotation, 0)
	local awning = AWNING_COLORS[((hue or 1) - 1) % #AWNING_COLORS + 1]

	Kit.part({
		name = "Counter",
		size = Vector3.new(6, 1.2, 2.4),
		cframe = cframe * CFrame.new(0, 1.4, 0),
		color = Palette.City.Foundation,
		material = Palette.Material.Concrete,
		decor = true,
		parent = model,
	})
	Kit.part({
		name = "Goods",
		size = Vector3.new(5.2, 0.6, 1.8),
		cframe = cframe * CFrame.new(0, 2.1, 0),
		color = Kit.pick(Kit.rng(), { Palette.Energy.Amber, Palette.Ancient.Bronze, Color3.fromRGB(150, 176, 96) }),
		material = Palette.Material.Concrete,
		decor = true,
		parent = model,
	})
	for _, side in { -1, 1 } do
		Kit.part({
			name = "Post",
			size = Vector3.new(0.35, 6.6, 0.35),
			cframe = cframe * CFrame.new(side * 2.7, 3.4, -0.9),
			color = Palette.City.Equipment,
			material = Palette.Material.Metal,
			decor = true,
			parent = model,
		})
	end
	Kit.wedge({
		name = "Awning",
		size = Vector3.new(6.8, 1.8, 3.2),
		cframe = cframe * CFrame.new(0, 6.2, 0.2) * CFrame.Angles(0, math.rad(180), 0),
		color = awning,
		parent = model,
	})
	Kit.part({
		name = "AwningTrim",
		size = Vector3.new(6.8, 0.2, 0.2),
		cframe = cframe * CFrame.new(0, 5.3, 1.75),
		color = Color3.fromRGB(238, 232, 220),
		material = Palette.Material.Concrete,
		decor = true,
		parent = model,
	})
	local bulb = Kit.part({
		name = "AccentLight",
		size = Vector3.new(0.4, 0.4, 0.4),
		cframe = cframe * CFrame.new(0, 5.0, 1.0),
		color = Palette.Energy.Amber,
		material = Palette.Material.Energy,
		transparency = 0.2,
		decor = true,
		parent = model,
	})
	Kit.light(bulb, Palette.Energy.Amber, 12, 1.3, false)
	return model
end

-- A bus stop: a shelter with a bench and a route sign, no rooftop.
function Props.busStop(parent: Instance, position: Vector3, rotation: number): Model
	local model = Kit.model("BusStop", parent)
	local cframe = CFrame.new(position) * CFrame.Angles(0, rotation, 0)
	Kit.part({
		name = "Roof",
		size = Vector3.new(3.4, 0.2, 9),
		cframe = cframe * CFrame.new(0, 7.4, 0),
		color = Palette.City.FacadeTrim,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	})
	Kit.part({
		name = "BackPanel",
		size = Vector3.new(0.15, 6.6, 9),
		cframe = cframe * CFrame.new(-1.6, 4.1, 0),
		color = Palette.City.Glass,
		material = Palette.Material.Glass,
		transparency = 0.4,
		decor = true,
		parent = model,
	})
	for _, z in { -3.6, 3.6 } do
		Kit.part({
			name = "Post",
			size = Vector3.new(0.3, 7.4, 0.3),
			cframe = cframe * CFrame.new(1.5, 3.7, z),
			color = Palette.City.Equipment,
			material = Palette.Material.Metal,
			decor = true,
			parent = model,
		})
	end
	Kit.part({
		name = "SignPost",
		size = Vector3.new(0.3, 8.5, 0.3),
		cframe = cframe * CFrame.new(2.4, 4.25, -4.2),
		color = Palette.City.Equipment,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	})
	local sign = Kit.part({
		name = "Sign",
		size = Vector3.new(0.15, 1.6, 2.4),
		cframe = cframe * CFrame.new(2.4, 8.1, -4.2) * CFrame.Angles(0, math.rad(90), 0),
		color = Palette.Energy.Amber,
		material = Palette.Material.Energy,
		transparency = 0.25,
		decor = true,
		parent = model,
	})
	Kit.light(sign, Palette.Energy.Amber, 10, 1, false)
	Props.bench(model, position + (cframe.RightVector * -0.8), rotation)
	return model
end

-- A parked scooter: a light two-wheeler, distinct from Props.vehicle's cars.
function Props.scooter(parent: Instance, position: Vector3, rotation: number): Model
	local model = Kit.model("Scooter", parent)
	local cframe = CFrame.new(position) * CFrame.Angles(0, rotation, 0)
	Kit.part({
		name = "Body",
		size = Vector3.new(0.9, 1.1, 3.2),
		cframe = cframe * CFrame.new(0, 1.05, 0),
		color = Color3.fromRGB(196, 90, 70),
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	})
	Kit.part({
		name = "Seat",
		size = Vector3.new(1.0, 0.3, 1.4),
		cframe = cframe * CFrame.new(0, 1.65, 0.2),
		color = Color3.fromRGB(30, 30, 32),
		material = Palette.Material.MetalWorn,
		decor = true,
		parent = model,
	})
	Kit.part({
		name = "Handlebar",
		size = Vector3.new(1.6, 0.15, 0.15),
		cframe = cframe * CFrame.new(0, 1.9, -1.4),
		color = Color3.fromRGB(40, 40, 44),
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	})
	for _, z in { -1.5, 1.4 } do
		Kit.cylinder({
			name = "Wheel",
			size = Vector3.new(0.35, 1.3, 1.3),
			cframe = cframe * CFrame.new(0, 0.65, z),
			color = Color3.fromRGB(20, 20, 22),
			material = Palette.Material.Metal,
			decor = true,
			parent = model,
		}, "x")
	end
	return model
end

Props.WalkY = WALK_Y

return Props
