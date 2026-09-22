--!nonstrict
-- The Ancient Aegis Zero vault.
--
-- Scale contract: the floor sits at y = -150, the ceiling at y = -34, giving a
-- 116-stud hall. A human is 5 studs tall, the active Aegis Zero about 11, and the
-- dormant Aegis Zero statue at the far end is roughly 92 - so the chamber genuinely
-- dwarfs the player while still leaving Aegis Zero room to fight.
-- The vault is this deep specifically so the statue fits underground.
--
-- Most surfaces stay stone or metal. Light is concentrated in three places
-- only: the ceiling shafts, the floor channels, and the statue's core.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Shared").Palette)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Ruin = {}

local FLOOR_Y = -151 -- slab centre; its top is at -150
local FLOOR_TOP = -150
local HALF = 72 -- chamber half-extent
local WALL_HEIGHT = 116
local CEILING_Y = FLOOR_TOP + WALL_HEIGHT -- -34

local function buildShell(parent: Instance)
	local folder = Kit.folder("Shell", parent)

	Kit.part({
		name = "Floor",
		size = Vector3.new(HALF * 2, 2, HALF * 2),
		position = Vector3.new(0, FLOOR_Y, 0),
		color = Palette.Ancient.StoneDark,
		material = Palette.Material.Stone,
		parent = folder,
	})

	-- Floor inlay grid, thin and dark, so the ground is not one flat sheet.
	for index = -3, 3 do
		for _, alongZ in { true, false } do
			local size = if alongZ then Vector3.new(0.7, 0.3, HALF * 2) else Vector3.new(HALF * 2, 0.3, 0.7)
			local position = if alongZ then Vector3.new(index * 19, FLOOR_TOP - 0.05, 0) else Vector3.new(0, FLOOR_TOP - 0.05, index * 19)
			Kit.part({
				name = "FloorInlay",
				size = size,
				position = position,
				color = Palette.Ancient.StoneShadow,
				material = Palette.Material.StoneCarved,
				decor = true,
				parent = folder,
			})
		end
	end

	Kit.part({
		name = "Ceiling",
		size = Vector3.new(HALF * 2, 3, HALF * 2),
		position = Vector3.new(0, CEILING_Y + 1.5, 0),
		color = Palette.Ancient.StoneShadow,
		material = Palette.Material.Stone,
		parent = folder,
	})

	-- Four walls, each built in three recessed layers so the surface has depth.
	for index = 0, 3 do
		local angle = index * math.pi / 2
		local normal = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local along = Vector3.new(-math.sin(angle), 0, math.cos(angle))

		for layer, spec in {
			{ inset = 0, thickness = 10, height = WALL_HEIGHT, color = Palette.Ancient.StoneDark },
			{ inset = 5, thickness = 3, height = WALL_HEIGHT - 18, color = Palette.Ancient.Stone },
			{ inset = 8, thickness = 2, height = WALL_HEIGHT - 40, color = Palette.Ancient.StonePale },
		} do
			local size = normal:Abs() * spec.thickness + along:Abs() * (HALF * 2) + Vector3.new(0, spec.height, 0)
			Kit.part({
				name = `WallLayer{layer}`,
				size = size,
				position = normal * (HALF - spec.inset - spec.thickness / 2) + Vector3.new(0, FLOOR_TOP + spec.height / 2, 0),
				color = spec.color,
				material = if layer == 1 then Palette.Material.Stone else Palette.Material.StoneCarved,
				decor = layer > 1,
				parent = folder,
			})
		end

		-- Ribs: repeated vertical buttresses reading as structure.
		for step = -3, 3 do
			Kit.part({
				name = "Rib",
				size = normal:Abs() * 5.5 + along:Abs() * 6 + Vector3.new(0, WALL_HEIGHT - 6, 0),
				position = normal * (HALF - 8) + along * (step * 19) + Vector3.new(0, FLOOR_TOP + (WALL_HEIGHT - 6) / 2, 0),
				color = Palette.Ancient.Stone,
				material = Palette.Material.StoneRough,
				decor = true,
				parent = folder,
			})
			-- Carved geometric band near the top of each rib.
			Kit.part({
				name = "RibGlyph",
				size = normal:Abs() * 1.2 + along:Abs() * 4 + Vector3.new(0, 4, 0),
				position = normal * (HALF - 11.2) + along * (step * 19) + Vector3.new(0, FLOOR_TOP + WALL_HEIGHT - 22, 0),
				color = Palette.Ancient.Bronze,
				material = Palette.Material.Metal,
				decor = true,
				parent = folder,
			})
		end
	end

	return folder
end

-- Free-standing colonnade flanking the approach to the dais.
local function buildColonnade(parent: Instance)
	local folder = Kit.folder("Colonnade", parent)

	for _, side in { -1, 1 } do
		for index = 0, 4 do
			local at = Vector3.new(side * 44, FLOOR_TOP, 40 - index * 21)
			Kit.part({
				name = "PillarBase",
				size = Vector3.new(14, 4, 14),
				position = at + Vector3.new(0, 2, 0),
				color = Palette.Ancient.StoneDark,
				material = Palette.Material.StoneRough,
				parent = folder,
			})
			Kit.part({
				name = "PillarShaft",
				size = Vector3.new(9.5, 84, 9.5),
				position = at + Vector3.new(0, 46, 0),
				color = Palette.Ancient.Stone,
				material = Palette.Material.StoneCarved,
				parent = folder,
			})
			-- A narrow cyan channel set into the inward face of each pillar.
			Kit.part({
				name = "PillarChannel",
				size = Vector3.new(0.6, 64, 2),
				position = at + Vector3.new(-side * 4.9, 46, 0),
				color = Palette.Energy.CyanDim,
				material = Palette.Material.Energy,
				transparency = 0.4,
				decor = true,
				parent = folder,
			})
			Kit.part({
				name = "PillarCapital",
				size = Vector3.new(13, 5, 13),
				position = at + Vector3.new(0, 90.5, 0),
				color = Palette.Ancient.StonePale,
				material = Palette.Material.StoneCarved,
				decor = true,
				parent = folder,
			})
			Kit.part({
				name = "PillarBronze",
				size = Vector3.new(11, 1.6, 11),
				position = at + Vector3.new(0, 87, 0),
				color = Palette.Ancient.Bronze,
				material = Palette.Material.Metal,
				decor = true,
				parent = folder,
			})
		end
	end

	return folder
end

-- Monumental doorway on the +Z wall: this is where the player arrives.
local function buildGateway(parent: Instance)
	local folder = Kit.folder("Gateway", parent)
	local z = HALF - 8

	Kit.part({
		name = "GateVoid",
		size = Vector3.new(34, 52, 8),
		position = Vector3.new(0, FLOOR_TOP + 26, z),
		color = Color3.fromRGB(8, 10, 12),
		material = Palette.Material.Stone,
		decor = true,
		parent = folder,
	})
	for _, side in { -1, 1 } do
		Kit.part({
			name = "GateJamb",
			size = Vector3.new(10, 58, 10),
			position = Vector3.new(side * 22, FLOOR_TOP + 29, z - 1),
			color = Palette.Ancient.StonePale,
			material = Palette.Material.StoneCarved,
			parent = folder,
		})
		Kit.part({
			name = "GateJambTrim",
			size = Vector3.new(1.8, 44, 1.8),
			position = Vector3.new(side * 16.6, FLOOR_TOP + 25, z - 6.4),
			color = Palette.Ancient.Bronze,
			material = Palette.Material.Metal,
			decor = true,
			parent = folder,
		})
	end
	Kit.part({
		name = "GateLintel",
		size = Vector3.new(58, 9, 11),
		position = Vector3.new(0, FLOOR_TOP + 62, z - 1),
		color = Palette.Ancient.StonePale,
		material = Palette.Material.StoneCarved,
		parent = folder,
	})
	Kit.part({
		name = "GateSeal",
		size = Vector3.new(13, 13, 1.6),
		cframe = CFrame.new(0, FLOOR_TOP + 62, z - 7) * CFrame.Angles(0, 0, math.rad(45)),
		color = Palette.Ancient.Bronze,
		material = Palette.Material.Metal,
		decor = true,
		parent = folder,
	})

	return folder
end

-- Low, wide activation dais. Two shallow steps only, so it never blocks combat.
local function buildDais(parent: Instance)
	local folder = Kit.folder("Dais", parent)

	Kit.cylinder({
		name = "DaisLower",
		size = Vector3.new(1.2, 64, 64),
		cframe = CFrame.new(0, FLOOR_TOP + 0.6, 0),
		color = Palette.Ancient.Stone,
		material = Palette.Material.StoneCarved,
		parent = folder,
	}, "y")
	Kit.cylinder({
		name = "DaisUpper",
		size = Vector3.new(1.2, 48, 48),
		cframe = CFrame.new(0, FLOOR_TOP + 1.8, 0),
		color = Palette.Ancient.StonePale,
		material = Palette.Material.StoneCarved,
		parent = folder,
	}, "y")

	-- Concentric energy rings inset into the dais face.
	for _, radius in { 21, 13 } do
		local segments = 20
		for index = 1, segments do
			local angle = (index / segments) * math.pi * 2
			Kit.part({
				name = "DaisRing",
				size = Vector3.new(1.1, 0.3, radius * 6.283 / segments * 0.7),
				cframe = CFrame.new(math.cos(angle) * radius, FLOOR_TOP + 2.5, math.sin(angle) * radius) * CFrame.Angles(0, -angle, 0),
				color = Palette.Energy.CyanDim,
				material = Palette.Material.Energy,
				transparency = 0.45,
				decor = true,
				parent = folder,
			})
		end
	end

	-- Channels running from the dais toward the dormant giant.
	for _, offset in { -6, 6 } do
		Kit.part({
			name = "CoreChannel",
			size = Vector3.new(1.1, 0.3, 30),
			position = Vector3.new(offset, FLOOR_TOP + 0.05, -42),
			color = Palette.Energy.CyanDim,
			material = Palette.Material.Energy,
			transparency = 0.4,
			decor = true,
			parent = folder,
		})
	end

	return folder
end

--[[
	The dormant Aegis Zero. Built from the same vocabulary as the player's armour -
	broad pauldrons, layered chest around a core, narrow visor - at five times
	the scale, so the transformation later reads as "that, but you".

	This is placeholder procedural geometry, not a finished sculpt.
]]
local function buildDormantAegis(parent: Instance)
	local folder = Kit.folder("DormantAegis", parent)
	local origin = Vector3.new(0, FLOOR_TOP, -56)
	local plate = Palette.Aegis.PlateOuter
	local inner = Palette.Aegis.PlateInner
	local joint = Palette.Aegis.Joint

	local function piece(name, size, offset, color, material, transparency)
		return Kit.part({
			name = name,
			size = size,
			position = origin + offset,
			color = color,
			material = material or Palette.Material.Metal,
			transparency = transparency,
			decor = true,
			castShadow = false,
			parent = folder,
		})
	end

	-- Plinth is the only solid piece; everything above is decorative.
	Kit.part({
		name = "Plinth",
		size = Vector3.new(46, 5, 26),
		position = origin + Vector3.new(0, 2.5, 0),
		color = Palette.Ancient.StoneDark,
		material = Palette.Material.StoneRough,
		parent = folder,
	})

	-- Legs
	for _, side in { -1, 1 } do
		piece("Foot", Vector3.new(11, 4, 17), Vector3.new(side * 10, 7, 1), inner)
		piece("Shin", Vector3.new(9, 17, 10), Vector3.new(side * 10, 17, 0), plate)
		piece("Knee", Vector3.new(10.5, 5, 11), Vector3.new(side * 10, 26, -0.5), inner)
		piece("Thigh", Vector3.new(10, 16, 11), Vector3.new(side * 10, 35, -0.5), plate)
		piece("HipJoint", Vector3.new(8, 4, 9), Vector3.new(side * 10, 44, -0.5), joint, Palette.Material.MetalWorn)
	end

	-- Torso: layered plates around a dormant core.
	piece("Pelvis", Vector3.new(24, 8, 13), Vector3.new(0, 47, 0), inner)
	piece("TorsoLower", Vector3.new(26, 12, 14), Vector3.new(0, 56, 0), plate)
	piece("TorsoUpper", Vector3.new(31, 14, 16), Vector3.new(0, 68, -0.5), plate)
	piece("ChestPlateL", Vector3.new(12, 12, 4), Vector3.new(-8, 68, -8), Palette.Aegis.PlateAccent)
	piece("ChestPlateR", Vector3.new(12, 12, 4), Vector3.new(8, 68, -8), Palette.Aegis.PlateAccent)
	piece("TrimBand", Vector3.new(30, 1.8, 17), Vector3.new(0, 61, -0.5), Palette.Aegis.Trim)

	local core = Kit.part({
		name = "DormantCore",
		size = Vector3.new(7, 7, 4),
		cframe = CFrame.new(origin + Vector3.new(0, 68, -8.5)) * CFrame.Angles(0, 0, math.rad(45)),
		color = Palette.Energy.Amber,
		material = Palette.Material.Energy,
		transparency = 0.35, -- dormant: dim, not blazing
		decor = true,
		parent = folder,
	})
	Kit.light(core, Palette.Energy.Amber, 40, 1.4, false)

	-- Shoulders and arms
	for _, side in { -1, 1 } do
		piece("Pauldron", Vector3.new(15, 11, 18), Vector3.new(side * 22, 72, -0.5), plate)
		piece("PauldronEdge", Vector3.new(16, 3, 19), Vector3.new(side * 22, 77.5, -0.5), Palette.Aegis.PlateAccent)
		piece("ShoulderJoint", Vector3.new(7, 7, 7), Vector3.new(side * 22, 65, -0.5), joint, Palette.Material.MetalWorn)
		piece("UpperArm", Vector3.new(9, 16, 10), Vector3.new(side * 22, 56, -0.5), plate)
		piece("Forearm", Vector3.new(11, 16, 12), Vector3.new(side * 22, 41, -1), inner)
		piece("Fist", Vector3.new(11, 9, 12), Vector3.new(side * 22, 31, -1), plate)
	end

	-- Head: compact helmet, narrow visor.
	piece("Neck", Vector3.new(7, 4, 7), Vector3.new(0, 76, -0.5), joint, Palette.Material.MetalWorn)
	piece("Helmet", Vector3.new(14, 11, 14), Vector3.new(0, 82, -0.5), plate)
	piece("HelmetCrest", Vector3.new(3, 5, 15), Vector3.new(0, 89, -0.5), Palette.Aegis.Trim)
	piece("Visor", Vector3.new(11, 2.2, 2), Vector3.new(0, 82.5, -7), Palette.Aegis.Visor, Palette.Material.Energy, 0.45)

	-- Ancient restraints: the vault has been holding it in place for centuries.
	for _, side in { -1, 1 } do
		Kit.part({
			name = "Restraint",
			size = Vector3.new(4, 3, 26),
			position = origin + Vector3.new(side * 20, 58, 6),
			color = Palette.Ancient.BronzeDark,
			material = Palette.Material.Metal,
			decor = true,
			parent = folder,
		})
	end

	return folder
end

-- Broken stone with machinery showing through the fractures.
local function buildDebris(parent: Instance, rng: Random)
	local folder = Kit.folder("Debris", parent)

	for _, at in {
		Vector3.new(-56, FLOOR_TOP, 16),
		Vector3.new(54, FLOOR_TOP, -8),
		Vector3.new(-28, FLOOR_TOP, -48),
		Vector3.new(34, FLOOR_TOP, 48),
	} do
		Props.rubble(folder, at, 12, rng:NextInteger(9, 13), rng)
		Kit.part({
			name = "EmbeddedMachinery",
			size = Vector3.new(rng:NextNumber() * 5 + 5, rng:NextNumber() * 4 + 4, rng:NextNumber() * 5 + 5),
			cframe = CFrame.new(at + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi, math.rad(rng:NextNumber() * 20 - 10)),
			color = Palette.Ancient.Machinery,
			material = Palette.Material.MetalWorn,
			decor = true,
			parent = folder,
		})
		Kit.part({
			name = "MachineryVein",
			size = Vector3.new(0.8, 0.8, 6),
			cframe = CFrame.new(at + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0),
			color = Palette.Energy.CyanDim,
			material = Palette.Material.Energy,
			transparency = 0.4,
			decor = true,
			parent = folder,
		})
	end

	-- Collapsed slabs leaning against the side walls.
	for _, side in { -1, 1 } do
		Kit.part({
			name = "FallenSlab",
			size = Vector3.new(4, 44, 18),
			cframe = CFrame.new(side * 58, FLOOR_TOP + 20, 58) * CFrame.Angles(0, 0, math.rad(side * 24)),
			color = Palette.Ancient.Stone,
			material = Palette.Material.StoneRough,
			decor = true,
			parent = folder,
		})
	end

	return folder
end

-- Subtle shafts from cracks in the ceiling, plus sparse drifting motes.
local function buildAtmosphere(parent: Instance)
	local folder = Kit.folder("Atmosphere", parent)

	for _, at in { Vector3.new(0, 0, 24), Vector3.new(-32, 0, -16), Vector3.new(34, 0, -34), Vector3.new(20, 0, 48) } do
		Kit.cylinder({
			name = "LightShaft",
			size = Vector3.new(WALL_HEIGHT, 14, 14),
			cframe = CFrame.new(at.X, FLOOR_TOP + WALL_HEIGHT / 2, at.Z),
			color = Palette.Energy.Cyan,
			material = Palette.Material.Energy,
			transparency = 0.94,
			decor = true,
			parent = folder,
		}, "y")
		Kit.part({
			name = "CeilingCrack",
			size = Vector3.new(13, 1.6, 13),
			position = Vector3.new(at.X, CEILING_Y - 0.4, at.Z),
			color = Palette.Energy.CyanDim,
			material = Palette.Material.Energy,
			transparency = 0.6,
			decor = true,
			parent = folder,
		})
	end

	if Palette.Quality.ParticlesEnabled then
		for _, at in { Vector3.new(0, FLOOR_TOP + 20, 12), Vector3.new(-30, FLOOR_TOP + 16, -24) } do
			local emitterPart = Kit.part({
				name = "MoteSource",
				size = Vector3.new(30, 1, 30),
				position = at,
				color = Palette.Energy.Cyan,
				transparency = 1,
				decor = true,
				parent = folder,
			})
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "Motes"
			emitter.Color = ColorSequence.new(Palette.Energy.Cyan)
			emitter.LightEmission = 0.6
			emitter.Rate = 6
			emitter.Lifetime = NumberRange.new(5, 9)
			emitter.Speed = NumberRange.new(0.4, 1.2)
			emitter.SpreadAngle = Vector2.new(25, 25)
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 0.35),
				NumberSequenceKeypoint.new(1, 0),
			})
			emitter.Transparency = NumberSequence.new(0.45)
			emitter.Acceleration = Vector3.new(0, 0.6, 0)
			emitter.Parent = emitterPart
		end
	end

	return folder
end

function Ruin.build(parent: Instance): { [string]: any }
	local folder = Kit.folder("Ruin", parent)
	local rng = Kit.rng(11)

	buildShell(folder)
	buildColonnade(folder)
	buildGateway(folder)
	buildDais(folder)
	buildDormantAegis(folder)
	buildDebris(folder, rng)
	buildAtmosphere(folder)

	return {
		Folder = folder,
		-- Arrive at the gateway facing the dormant giant.
		SpawnCFrame = CFrame.lookAt(Vector3.new(0, FLOOR_TOP + 4, 44), Vector3.new(0, FLOOR_TOP + 4, 0)),
		ArenaCentre = Vector3.new(0, FLOOR_TOP + 4, 0),
		FloorTop = FLOOR_TOP,
	}
end

return Ruin
