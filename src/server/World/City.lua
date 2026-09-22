--!nonstrict
-- District composition.
--
-- The layout is built around one sightline. Standing on the spawn at z = +48
-- and looking north the player sees, in order: the avenue, the lit plaza and
-- its cyan beacon over the ruin entrance, and behind it the alien shard driven
-- into the street. Objective, landmark and route are all in one frame.
--
-- Damage is concentrated north of the plaza, where the shard came down.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Shared").Palette)
local Buildings = require(script.Parent.Buildings)
local Kit = require(script.Parent.Kit)
local Neighborhood = require(script.Parent.Neighborhood)
local Props = require(script.Parent.Props)
local Streets = require(script.Parent.Streets)

local City = {}

local WALK_Y = Streets.WalkY
local PLAZA_HALF = Streets.PlazaHalf

-- Hand-placed so the composition is deliberate rather than random. Quadrant
-- blocks start at |30|, so a 36-wide footprint at 52 leaves a clean setback.
-- The (-52, 52) slot is intentionally absent from this table: it is Uncle
-- Daren's neighborhood (Chapter One, Scene 1), built by World/Neighborhood.lua
-- into that exact footprint instead of a generic tower - see buildDistrict()
-- below and City.build()'s NeighborhoodResult return value.
local BUILDINGS: { Buildings.Config } = {
	-- South blocks: intact, they frame the view down the avenue.
	{ x = 52, z = 52, width = 36, depth = 36, floors = 4, style = 1 },
	{ x = 52, z = 104, width = 34, depth = 34, floors = 6, style = 2 },
	{ x = 104, z = 52, width = 34, depth = 34, floors = 3, style = 3 },
	{ x = 104, z = 104, width = 36, depth = 36, floors = 5, style = 4 },
	{ x = -52, z = 104, width = 34, depth = 34, floors = 3, style = 5 },
	{ x = -104, z = 52, width = 34, depth = 34, floors = 6, style = 1 },
	{ x = -104, z = 104, width = 36, depth = 36, floors = 4, style = 3 },

	-- North blocks: the invasion zone.
	{ x = 52, z = -52, width = 36, depth = 36, floors = 7, style = 3, damage = "Breached" },
	{ x = 52, z = -104, width = 34, depth = 34, floors = 4, style = 1, damage = "Scarred" },
	{ x = 104, z = -52, width = 34, depth = 34, floors = 5, style = 5, damage = "Scarred" },
	{ x = 104, z = -104, width = 36, depth = 36, floors = 3, style = 2 },
	{ x = -52, z = -52, width = 36, depth = 36, floors = 6, style = 4, damage = "Sheared" },
	{ x = -52, z = -104, width = 34, depth = 34, floors = 5, style = 2, damage = "Breached" },
	{ x = -104, z = -52, width = 34, depth = 34, floors = 4, style = 1, damage = "Scarred" },
	{ x = -104, z = -104, width = 36, depth = 36, floors = 6, style = 5 },
}

local function buildDistrict(parent: Instance, rng: Random)
	local folder = Kit.folder("Blocks", parent)
	for index, cfg in BUILDINGS do
		local config = table.clone(cfg)
		config.name = `Building_{index}`
		Buildings.build(folder, config, rng)
	end
	return folder
end

--------------------------------------------------------------------------------
-- Plaza over the ruin
--------------------------------------------------------------------------------

local function buildPlaza(parent: Instance, rng: Random)
	local folder = Kit.folder("Plaza", parent)

	Kit.part({
		name = "PlazaPad",
		size = Vector3.new(PLAZA_HALF * 2, 0.5, PLAZA_HALF * 2),
		position = Vector3.new(0, WALK_Y - 0.25, 0),
		color = Palette.City.Sidewalk,
		material = Palette.Material.Sidewalk,
		parent = folder,
	})

	-- Paving joints: thin dark lines rather than one slab per flagstone.
	for index = -2, 2 do
		for _, alongZ in { true, false } do
			local size = if alongZ then Vector3.new(0.45, 0.2, PLAZA_HALF * 2) else Vector3.new(PLAZA_HALF * 2, 0.2, 0.45)
			local position = if alongZ then Vector3.new(index * 12, WALK_Y - 0.05, 0) else Vector3.new(0, WALK_Y - 0.05, index * 12)
			Kit.part({
				name = "PavingJoint",
				size = size,
				position = position,
				color = Palette.City.SidewalkWorn,
				material = Palette.Material.Concrete,
				decor = true,
				parent = folder,
			})
		end
	end

	-- Ancient geometry surfacing through the human paving as it nears the ruin.
	for _, ring in { { radius = 22, segments = 24, width = 3.4 }, { radius = 14.5, segments = 18, width = 2.6 } } do
		for index = 1, ring.segments do
			local angle = (index / ring.segments) * math.pi * 2
			local at = Vector3.new(math.cos(angle) * ring.radius, WALK_Y + 0.03, math.sin(angle) * ring.radius)
			Kit.part({
				name = "AncientRing",
				size = Vector3.new(ring.width, 0.28, ring.radius * 6.283 / ring.segments * 0.82),
				cframe = CFrame.new(at) * CFrame.Angles(0, -angle, 0),
				color = if index % 4 == 0 then Palette.Ancient.StonePale else Palette.Ancient.Stone,
				material = Palette.Material.StoneCarved,
				decor = true,
				parent = folder,
			})
		end
	end

	-- Eight spokes; four carry a dim cyan channel pointing at the entrance.
	for index = 0, 7 do
		local angle = index * math.pi / 4
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		Kit.part({
			name = "Spoke",
			size = Vector3.new(2.2, 0.28, 15),
			cframe = CFrame.new(direction * 17 + Vector3.new(0, WALK_Y + 0.03, 0)) * CFrame.Angles(0, -angle + math.pi / 2, 0),
			color = Palette.Ancient.Stone,
			material = Palette.Material.StoneCarved,
			decor = true,
			parent = folder,
		})
		if index % 2 == 0 then
			Kit.part({
				name = "Channel",
				size = Vector3.new(0.5, 0.3, 13),
				cframe = CFrame.new(direction * 17 + Vector3.new(0, WALK_Y + 0.05, 0)) * CFrame.Angles(0, -angle + math.pi / 2, 0),
				color = Palette.Energy.CyanDim,
				material = Palette.Material.Energy,
				transparency = 0.25,
				decor = true,
				parent = folder,
			})
		end
	end

	return folder
end

--------------------------------------------------------------------------------
-- Central Plaza's fountain / energy monument (Chapter One, Scene 2 - "The
-- Sky Breaks"). Physically solid (unlike the mostly-decorative beacon
-- pylons) so it works as real cover: Scene 2's invasion cutscene has the
-- player pull Mira behind it when the drop pod hits.
--------------------------------------------------------------------------------

local FOUNTAIN_POSITION = Vector3.new(0, 0, 20)

local function buildFountain(parent: Instance): Model
	local model = Kit.model("PlazaFountain", parent)
	local base = FOUNTAIN_POSITION

	Kit.cylinder({
		name = "BasinRim",
		size = Vector3.new(2.2, 9, 9),
		position = base + Vector3.new(0, WALK_Y + 1.1, 0),
		color = Palette.Ancient.Stone,
		material = Palette.Material.StoneCarved,
		castShadow = true,
		parent = model,
	}, "y")
	Kit.cylinder({
		name = "BasinInner",
		size = Vector3.new(1.6, 7.6, 7.6),
		position = base + Vector3.new(0, WALK_Y + 1.3, 0),
		color = Palette.City.Sidewalk,
		material = Palette.Material.Sidewalk,
		decor = true,
		parent = model,
	}, "y")
	Kit.cylinder({
		name = "Water",
		size = Vector3.new(0.4, 6.8, 6.8),
		position = base + Vector3.new(0, WALK_Y + 1.9, 0),
		color = Palette.Energy.Cyan,
		material = Palette.Material.Energy,
		transparency = 0.55,
		decor = true,
		parent = model,
	}, "y")

	-- Central energy column - the "monument" half of "fountain or energy
	-- monument": a slender lit pillar rising from the basin centre.
	Kit.cylinder({
		name = "MonumentColumn",
		size = Vector3.new(11, 1.6, 1.6),
		position = base + Vector3.new(0, WALK_Y + 6, 0),
		color = Palette.Ancient.Bronze,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	}, "y")
	local core = Kit.part({
		name = "MonumentCore",
		size = Vector3.new(0.7, 0.7, 0.7),
		position = base + Vector3.new(0, WALK_Y + 11.6, 0),
		color = Palette.Energy.Cyan,
		material = Palette.Material.Energy,
		transparency = 0.15,
		decor = true,
		parent = model,
	})
	Kit.light(core, Palette.Energy.Cyan, 20, 1.8, false)

	-- Low seating ring: incidentally, exactly what a player needs to duck
	-- behind for the invasion cutscene's "dive behind the fountain" beat.
	for index = 1, 10 do
		local angle = (index / 10) * math.pi * 2
		Kit.part({
			name = "SeatEdge",
			size = Vector3.new(1.6, 1.1, 2.6),
			cframe = CFrame.new(base + Vector3.new(math.cos(angle) * 5.6, WALK_Y + 0.55, math.sin(angle) * 5.6)) * CFrame.Angles(0, -angle, 0),
			color = Palette.Ancient.StoneDark,
			material = Palette.Material.StoneRough,
			parent = model,
		})
	end

	return model
end

-- Trees, planters, benches, info displays, a couple of food vendors and cafe
-- seating around the fountain - Scene 2's "the plaza should feel large but
-- not empty."
local function buildPlazaLife(parent: Instance, rng: Random)
	local folder = Kit.folder("PlazaLife", parent)
	local base = FOUNTAIN_POSITION

	for _, offset in { Vector3.new(-10, 0, 8), Vector3.new(10, 0, 8), Vector3.new(-12, 0, -6), Vector3.new(13, 0, -4) } do
		Props.planter(folder, base + offset)
	end
	for index = 1, 4 do
		local angle = (index / 4) * math.pi * 2 + 0.4
		Props.bench(folder, base + Vector3.new(math.cos(angle) * 12, 0, math.sin(angle) * 12), -angle)
	end

	-- Food vendors with a few cafe-style seats nearby.
	Props.marketStall(folder, base + Vector3.new(-16, 0, 2), math.rad(90), 2)
	Props.marketStall(folder, base + Vector3.new(16, 0, -2), math.rad(-90), 4)
	for _, offset in { Vector3.new(-16, 0, 6), Vector3.new(-16, 0, -2), Vector3.new(16, 0, 2), Vector3.new(16, 0, -6) } do
		Props.bench(folder, base + offset, 0)
	end

	-- An information display: a thin standing kiosk, distinct from the
	-- neighborhood's bus-stop sign.
	for _, offset in { Vector3.new(-20, 0, -14), Vector3.new(20, 0, 14) } do
		local kiosk = Kit.part({
			name = "InfoDisplay",
			size = Vector3.new(2.6, 3.6, 0.3),
			cframe = CFrame.new(base + offset + Vector3.new(0, WALK_Y + 1.9, 0)) * CFrame.Angles(0, offset.X > 0 and math.rad(180) or 0, 0),
			color = Palette.City.GlassLit,
			material = Palette.Material.Energy,
			transparency = 0.3,
			decor = true,
			parent = folder,
		})
		Kit.part({
			name = "InfoDisplayPost",
			size = Vector3.new(0.4, 1.9, 0.4),
			position = base + offset + Vector3.new(0, WALK_Y + 0.5, 0),
			color = Palette.City.Equipment,
			material = Palette.Material.Metal,
			decor = true,
			parent = folder,
		})
		Kit.light(kiosk, Palette.City.GlassLit, 8, 1, false)
	end

	-- A handful of small trees dotted along the plaza edge.
	for index = 1, 6 do
		local angle = (index / 6) * math.pi * 2 + 0.9
		local at = Vector3.new(math.cos(angle) * 25, WALK_Y, math.sin(angle) * 25)
		Kit.cylinder({ name = "TreeTrunk", size = Vector3.new(0.6, 3, 0.6), position = at + Vector3.new(0, 1.5, 0), color = Color3.fromRGB(74, 58, 46), material = Palette.Material.Concrete, parent = folder }, "y")
		Kit.part({ name = "TreeCanopy", size = Vector3.new(4.4, 4, 4.4), position = at + Vector3.new(0, 5, 0), color = Color3.fromRGB(64, 96, 58), material = Palette.Material.Concrete, decor = true, parent = folder })
	end

	return folder
end

--------------------------------------------------------------------------------
-- Ruin entrance: collar, prompt surface and beacon
--------------------------------------------------------------------------------

local function buildEntrance(parent: Instance): (Part, ProximityPrompt)
	local folder = Kit.folder("RuinEntranceAssembly", parent)

	-- Collar of tilted stone blocks: the ground broke open around the shaft.
	for index = 1, 12 do
		local angle = (index / 12) * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		Kit.part({
			name = "Collar",
			size = Vector3.new(4.6, 2.6, 3.4),
			cframe = CFrame.new(direction * 9.4 + Vector3.new(0, WALK_Y + 0.6, 0))
				* CFrame.Angles(0, -angle, 0)
				* CFrame.Angles(0, 0, math.rad(if index % 2 == 0 then 11 else -7)),
			color = if index % 3 == 0 then Palette.Ancient.StonePale else Palette.Ancient.Stone,
			material = Palette.Material.StoneRough,
			decor = true,
			parent = folder,
		})
	end

	-- The interaction surface. Kept named RuinEntrance for continuity.
	local crater = Kit.part({
		name = "RuinEntrance",
		size = Vector3.new(15, 1, 15),
		position = Vector3.new(0, WALK_Y - 0.1, 0),
		color = Color3.fromRGB(10, 14, 18),
		material = Palette.Material.Stone,
		parent = folder,
	})

	-- Shaft void below, so looking down reads as depth rather than a black tile.
	-- Top at y = 0 so it tucks under the crater slab (which spans -0.1 .. 0.9)
	-- rather than ending flush with the subgrade, which would z-fight.
	Kit.part({
		name = "ShaftVoid",
		size = Vector3.new(13, 26, 13),
		position = Vector3.new(0, -13, 0),
		color = Color3.fromRGB(6, 9, 12),
		material = Palette.Material.Stone,
		decor = true,
		parent = folder,
	})
	for index = 1, 4 do
		local angle = index * math.pi / 2 + math.pi / 4
		Kit.part({
			name = "ShaftRib",
			size = Vector3.new(1.6, 24, 1.6),
			position = Vector3.new(math.cos(angle) * 5.6, -12.5, math.sin(angle) * 5.6),
			color = Palette.Ancient.TealDeep,
			material = Palette.Material.Energy,
			transparency = 0.55,
			decor = true,
			parent = folder,
		})
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DescendPrompt"
	prompt.ActionText = "Hold to investigate"
	prompt.ObjectText = "ANCIENT SIGNAL"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false -- the player stands on the crater itself
	prompt.ClickablePrompt = true -- gives touch and mouse users an affordance
	prompt.UIOffset = Vector2.new(0, -40)
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = crater

	return crater, prompt
end

local function buildBeacon(parent: Instance)
	local folder = Kit.folder("EntranceBeacon", parent)

	Kit.cylinder({
		name = "LightColumn",
		size = Vector3.new(190, 6.5, 6.5),
		cframe = CFrame.new(0, 95, 0),
		color = Palette.Energy.Cyan,
		material = Palette.Material.Energy,
		transparency = 0.86,
		decor = true,
		parent = folder,
	}, "y")

	Kit.cylinder({
		name = "ColumnCore",
		size = Vector3.new(190, 1.8, 1.8),
		cframe = CFrame.new(0, 95, 0),
		color = Palette.Energy.Cyan,
		material = Palette.Material.Energy,
		transparency = 0.55,
		decor = true,
		parent = folder,
	}, "y")

	-- Four Ancient pylons: stone shafts, bronze collars, cyan crowns.
	for index = 1, 4 do
		local angle = index * math.pi / 2 + math.pi / 4
		local at = Vector3.new(math.cos(angle) * 15, WALK_Y, math.sin(angle) * 15)
		Kit.part({
			name = "PylonBase",
			size = Vector3.new(4.4, 1.6, 4.4),
			position = at + Vector3.new(0, 0.8, 0),
			color = Palette.Ancient.StoneDark,
			material = Palette.Material.StoneRough,
			parent = folder,
		})
		Kit.part({
			name = "PylonShaft",
			size = Vector3.new(2.8, 15, 2.8),
			cframe = CFrame.new(at + Vector3.new(0, 9, 0)) * CFrame.Angles(0, -angle, 0),
			color = Palette.Ancient.Stone,
			material = Palette.Material.StoneCarved,
			parent = folder,
		})
		Kit.part({
			name = "PylonCollar",
			size = Vector3.new(3.4, 1, 3.4),
			position = at + Vector3.new(0, 14.4, 0),
			color = Palette.Ancient.Bronze,
			material = Palette.Material.Metal,
			decor = true,
			parent = folder,
		})
		local crown = Kit.part({
			name = "PylonCrown",
			size = Vector3.new(1.5, 3.2, 1.5),
			cframe = CFrame.new(at + Vector3.new(0, 17, 0)) * CFrame.Angles(0, math.rad(45), 0),
			color = Palette.Energy.Cyan,
			material = Palette.Material.Energy,
			decor = true,
			parent = folder,
		})
		Kit.light(crown, Palette.Energy.Cyan, 30, 2, false)
	end

	-- World-space label. Deliberately NOT AlwaysOnTop: it should be occluded by
	-- buildings so it reads as a thing in the world, not an x-ray marker.
	local anchor = Kit.part({
		name = "LabelAnchor",
		size = Vector3.new(1, 1, 1),
		position = Vector3.new(0, 23, 0),
		color = Palette.Energy.Cyan,
		transparency = 1,
		decor = true,
		parent = folder,
	})
	Kit.part({
		name = "SignalDiamond",
		size = Vector3.new(3.6, 3.6, 0.7),
		cframe = CFrame.new(0, 29, 0) * CFrame.Angles(0, 0, math.rad(45)),
		color = Palette.Energy.Cyan,
		material = Palette.Material.Energy,
		transparency = 0.12,
		decor = true,
		parent = folder,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EntranceLabel"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = false
	billboard.Size = UDim2.fromOffset(260, 62)
	billboard.MaxDistance = 340
	billboard.LightInfluence = 0
	billboard.Parent = anchor

	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(13, 19, 28)
	card.BackgroundTransparency = 0.18
	card.Size = UDim2.fromScale(1, 1)
	card.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Palette.Ancient.Teal
	stroke.Thickness = 1
	stroke.Transparency = 0.2
	stroke.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.Parent = card

	local kicker = Instance.new("TextLabel")
	kicker.BackgroundTransparency = 1
	kicker.Size = UDim2.new(1, 0, 0, 16)
	kicker.Font = Enum.Font.GothamMedium
	kicker.Text = "ANCIENT SIGNAL"
	kicker.TextColor3 = Palette.Energy.Cyan
	kicker.TextSize = 13
	kicker.Parent = card

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 24)
	title.Font = Enum.Font.GothamBold
	title.Text = "RUIN ENTRANCE"
	title.TextColor3 = Color3.fromRGB(226, 236, 243)
	title.TextSize = 20
	title.Parent = card

	return folder
end

--------------------------------------------------------------------------------
-- Invasion landmark: the shard
--------------------------------------------------------------------------------

local function buildShard(parent: Instance, rng: Random)
	local folder = Kit.folder("AlienShard", parent)
	local base = Vector3.new(0, WALK_Y, -86)

	-- Impact crater it punched into the avenue.
	Kit.cylinder({
		name = "ImpactCrater",
		size = Vector3.new(1.4, 44, 44),
		cframe = CFrame.new(base + Vector3.new(0, -0.4, 0)),
		color = Color3.fromRGB(28, 24, 26),
		material = Palette.Material.Rubble,
		decor = true,
		parent = folder,
	}, "y")

	-- Tapering stack of rotated slabs leaning back toward the plaza.
	local lean = CFrame.Angles(math.rad(16), math.rad(24), math.rad(-7))
	local segments = 6
	for index = 1, segments do
		local fraction = (index - 1) / segments
		local height = 22 - fraction * 9
		local width = 17 - fraction * 12
		local y = 6 + (index - 1) * 17
		Kit.part({
			name = "ShardSegment",
			size = Vector3.new(width, height, width * 0.72),
			cframe = CFrame.new(base + Vector3.new(0, y, 0)) * lean * CFrame.Angles(0, fraction * 0.5, 0),
			color = if index % 2 == 0 then Palette.Alien.Shell else Palette.Alien.Plate,
			material = Palette.Material.Shell,
			collide = index <= 2,
			castShadow = index <= 3,
			parent = folder,
		})
		-- Magenta fracture running up the spine.
		Kit.part({
			name = "ShardFracture",
			size = Vector3.new(0.9, height * 0.7, width * 0.78),
			cframe = CFrame.new(base + Vector3.new(0, y, 0)) * lean * CFrame.Angles(0, fraction * 0.5, 0) * CFrame.new(width * 0.28, 0, 0),
			color = Palette.Alien.Energy,
			material = Palette.Material.Energy,
			transparency = 0.25,
			decor = true,
			parent = folder,
		})
	end

	-- Barbed fins near the base give the silhouette an alien read.
	for index = 1, 5 do
		local angle = (index / 5) * math.pi * 2
		Kit.wedge({
			name = "ShardFin",
			size = Vector3.new(2.2, 13, 9),
			cframe = CFrame.new(base + Vector3.new(math.cos(angle) * 8, 8, math.sin(angle) * 8))
				* CFrame.Angles(0, -angle, math.rad(22)),
			color = Palette.Alien.Shell,
			material = Palette.Material.Shell,
			decor = true,
			parent = folder,
		})
	end

	local glow = Kit.part({
		name = "ShardCore",
		size = Vector3.new(5, 5, 5),
		position = base + Vector3.new(0, 9, 0),
		color = Palette.Alien.Energy,
		material = Palette.Material.Energy,
		transparency = 0.3,
		decor = true,
		parent = folder,
	})
	Kit.light(glow, Palette.Alien.Energy, 44, 2.2, false)

	Props.rubble(folder, base + Vector3.new(0, 0, 16), 18, 16, rng)
	Props.rubble(folder, base + Vector3.new(-14, 0, -6), 14, 12, rng)

	return folder
end

--------------------------------------------------------------------------------
-- Distant skyline
--------------------------------------------------------------------------------

local function buildSkyline(parent: Instance, rng: Random)
	local folder = Kit.folder("Skyline", parent)
	local rings = {
		{ radius = 300, count = 18, minHeight = 70, maxHeight = 150, width = 42 },
		{ radius = 440, count = 14, minHeight = 110, maxHeight = 230, width = 64 },
	}

	for ringIndex = 1, math.min(#rings, Palette.Quality.SkylineRings) do
		local ring = rings[ringIndex]
		for index = 1, ring.count do
			local angle = (index / ring.count) * math.pi * 2 + ringIndex * 0.21
			local distance = ring.radius + (rng:NextNumber() - 0.5) * 60
			local height = rng:NextNumber() * (ring.maxHeight - ring.minHeight) + ring.minHeight
			local width = ring.width * (0.6 + rng:NextNumber() * 0.7)
			Kit.part({
				name = "SkylineMass",
				size = Vector3.new(width, height, width * 0.8),
				cframe = CFrame.new(math.cos(angle) * distance, height / 2 - 4, math.sin(angle) * distance)
					* CFrame.Angles(0, -angle + rng:NextNumber(), 0),
				color = Palette.City.Skyline,
				material = Palette.Material.Concrete,
				decor = true,
				castShadow = false,
				parent = folder,
			})
		end
	end

	return folder
end

--------------------------------------------------------------------------------
-- Street dressing
--------------------------------------------------------------------------------

local function buildDressing(parent: Instance, rng: Random)
	local folder = Kit.folder("Dressing", parent)

	-- Lamps march down both avenues; only the four nearest the plaza are lit,
	-- which pulls the eye toward the objective.
	for _, distance in { 46, 72, 98, 126 } do
		for _, sign in { -1, 1 } do
			for _, alongZ in { true, false } do
				for _, side in { -1, 1 } do
					local lateral = side * 25
					local at = if alongZ
						then Vector3.new(lateral, WALK_Y, sign * distance)
						else Vector3.new(sign * distance, WALK_Y, lateral)
					Props.streetLamp(folder, at, distance == 46 and alongZ)
				end
			end
		end
	end

	-- Emergency barriers closing the plaza approaches.
	-- Emergency barriers: an invasion-era street closure, not part of a normal
	-- morning - built now but hidden until Scene 2 (see Kit.markInvasionOnly).
	for _, spec in {
		{ at = Vector3.new(-12, WALK_Y, 34), rotation = 0 },
		{ at = Vector3.new(12, WALK_Y, 34), rotation = 0 },
		{ at = Vector3.new(-12, WALK_Y, -34), rotation = 0 },
		{ at = Vector3.new(12, WALK_Y, -34), rotation = 0 },
		{ at = Vector3.new(34, WALK_Y, 0), rotation = math.rad(90) },
		{ at = Vector3.new(-34, WALK_Y, 0), rotation = math.rad(90) },
	} do
		Kit.markInvasionOnly(Props.barrier(folder, spec.at, spec.rotation, math.abs(spec.at.Z) > 20))
	end

	for _, corner in { Vector3.new(26, WALK_Y, 34), Vector3.new(-26, WALK_Y, 34), Vector3.new(26, WALK_Y, -34), Vector3.new(-26, WALK_Y, -34) } do
		Props.trafficSignal(folder, corner, if corner.X > 0 then math.rad(180) else 0)
	end

	for _, planter in { Vector3.new(26, WALK_Y, 26), Vector3.new(-26, WALK_Y, 26), Vector3.new(26, WALK_Y, -26), Vector3.new(-26, WALK_Y, -26) } do
		Props.planter(folder, planter)
	end

	-- Ordinary parked traffic near spawn (Scene 1 wants "parked cars, scooters
	-- and delivery vehicles" on a normal morning); wrecked ones thicken toward
	-- the invasion zone and are hidden until Scene 2 like everything else here.
	for _, spec in {
		{ at = Vector3.new(-10, 0, 62), rotation = 0, wrecked = false },
		{ at = Vector3.new(11, 0, 86), rotation = math.rad(6), wrecked = false },
		{ at = Vector3.new(-11, 0, 112), rotation = math.rad(-4), wrecked = false },
		{ at = Vector3.new(9, 0, -58), rotation = math.rad(28), wrecked = true },
		{ at = Vector3.new(-12, 0, -68), rotation = math.rad(-46), wrecked = true },
		{ at = Vector3.new(58, 0, 8), rotation = math.rad(90), wrecked = false },
		{ at = Vector3.new(-64, 0, -9), rotation = math.rad(96), wrecked = true },
	} do
		local car = Props.vehicle(folder, spec.at, spec.rotation, spec.wrecked)
		if spec.wrecked then
			Kit.markInvasionOnly(car)
		end
	end

	-- Debris fields at the foot of the damaged blocks - hidden until Scene 2.
	for _, at in {
		Vector3.new(34, WALK_Y, -40),
		Vector3.new(-34, WALK_Y, -42),
		Vector3.new(-36, WALK_Y, -92),
		Vector3.new(36, WALK_Y, -96),
		Vector3.new(-30, WALK_Y, 40),
	} do
		Kit.markInvasionOnly(Props.rubble(folder, at, 13, rng:NextInteger(10, 15), rng))
	end

	return folder
end

--------------------------------------------------------------------------------

function City.build(parent: Instance): { [string]: any }
	local folder = Kit.folder("City", parent)
	local rng = Kit.rng(1)

	Streets.build(folder, Kit.rng(2))
	buildDistrict(folder, Kit.rng(3))
	local neighborhood = Neighborhood.build(folder, -52, 52, 36, Kit.rng(7))
	buildPlaza(folder, rng)
	local fountain = buildFountain(folder)
	buildPlazaLife(folder, Kit.rng(8))
	local crater, prompt = buildEntrance(folder)
	buildBeacon(folder)
	-- The impact shard: built now, hidden until Scene 2's invasion - see
	-- Kit.markInvasionOnly. Chapter One Scene 1 happens before any of this.
	Kit.markInvasionOnly(buildShard(folder, Kit.rng(4)))
	buildSkyline(folder, Kit.rng(5))
	buildDressing(folder, Kit.rng(6))

	-- Chapter One, Scene 1 ("A Normal Morning") begins outside Uncle Daren's
	-- repair garage, so that is where a freshly-spawned player actually lands
	-- - see Neighborhood.build()'s SpawnCFrame. The plaza-adjacent point the
	-- spawn used to sit at is now just where the avenue happens to be; nothing
	-- reads that literal position anymore.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CitySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = neighborhood.SpawnCFrame.Position - Vector3.new(0, 3.2, 0)
	spawn.Transparency = 0.45
	spawn.Color = Palette.Energy.Amber
	spawn.Material = Palette.Material.Energy
	spawn.CanCollide = false
	spawn.Parent = folder

	return {
		Folder = folder,
		Crater = crater,
		Prompt = prompt,
		SpawnCFrame = neighborhood.SpawnCFrame,
		PlazaSpawnCFrame = CFrame.new(0, 4, 48), -- kept for anything that specifically wants the old plaza-adjacent point
		Neighborhood = neighborhood,
		Fountain = fountain,
		FountainPosition = FOUNTAIN_POSITION,
	}
end

return City
