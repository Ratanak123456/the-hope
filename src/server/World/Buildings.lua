--!nonstrict
-- Modular building kit.
--
-- A building is assembled from reusable pieces - foundation, core mass, facade
-- bands, pilasters, ledges, parapet, roof equipment, entrance - rather than
-- placing every window by hand. Only the faces that look toward a street get
-- detail, which is what keeps the part count sane.
--
-- Collision is deliberately crude: the core mass and foundation collide, every
-- decorative piece does not.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Shared").Palette)
local Kit = require(script.Parent.Kit)

local Buildings = {}

local FLOOR_HEIGHT = 11
local BASE_Y = 0.5 -- sidewalk level

export type Damage = "None" | "Scarred" | "Breached" | "Sheared"

export type Config = {
	x: number,
	z: number,
	width: number,
	depth: number,
	floors: number,
	style: number,
	damage: Damage?,
	name: string?,
}

-- The horizontal normals of the faces that look toward the avenues. A building
-- in the north-east block shows its west and south faces to the player.
local function streetNormals(cfg: Config): { Vector3 }
	local normals = {}
	table.insert(normals, Vector3.new(if cfg.x >= 0 then -1 else 1, 0, 0))
	table.insert(normals, Vector3.new(0, 0, if cfg.z >= 0 then -1 else 1))
	return normals
end

local function buildFacade(model: Model, cfg: Config, rng: Random, height: number)
	local facade = Kit.pick(rng, Palette.City.Facade)
	local halfWidth = cfg.width / 2
	local halfDepth = cfg.depth / 2

	for _, normal in streetNormals(cfg) do
		local along = if math.abs(normal.X) > 0.5 then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0)
		local faceHalf = if math.abs(normal.X) > 0.5 then halfWidth else halfDepth
		local spanHalf = if math.abs(normal.X) > 0.5 then halfDepth else halfWidth
		local faceOrigin = Vector3.new(cfg.x, 0, cfg.z) + normal * faceHalf

		-- Recessed glass band per floor: one part, reads as a window group.
		for floor = 1, cfg.floors do
			local y = BASE_Y + 3 + (floor - 0.5) * FLOOR_HEIGHT
			local bandSize = along * (spanHalf * 2 - 5) + Vector3.new(0, 4.2, 0) + normal:Abs() * 1.2
			Kit.part({
				name = "WindowBand",
				size = bandSize,
				position = faceOrigin + Vector3.new(0, y, 0) - normal * 0.35,
				color = Palette.City.Glass,
				material = Palette.Material.Glass,
				reflectance = 0.08,
				decor = true,
				parent = model,
			})

			-- A handful of lit rooms so the block does not read as abandoned.
			if rng:NextNumber() < Palette.Quality.LitWindowChance then
				local offset = (rng:NextNumber() - 0.5) * (spanHalf * 2 - 10)
				Kit.part({
					name = "LitWindow",
					size = along * 3.4 + Vector3.new(0, 2.6, 0) + normal:Abs() * 1.3,
					position = faceOrigin + Vector3.new(0, y, 0) - normal * 0.3 + along * offset,
					color = Palette.City.GlassLit,
					material = Palette.Material.Energy,
					transparency = 0.35,
					decor = true,
					parent = model,
				})
			end
		end

		-- Vertical pilasters break up the facade and read as structure.
		for index = -1, 1 do
			Kit.part({
				name = "Pilaster",
				size = along * 2.4 + Vector3.new(0, height - 2, 0) + normal:Abs() * 1.6,
				position = faceOrigin + Vector3.new(0, BASE_Y + 3 + (height - 2) / 2, 0) - normal * 0.1 + along * (index * spanHalf * 0.72),
				color = Palette.City.FacadeTrim,
				material = Palette.Material.Concrete,
				decor = true,
				parent = model,
			})
		end

		-- Ledges: one at the shoulder, one under the parapet.
		for _, fraction in { 0.42, 0.92 } do
			Kit.part({
				name = "Ledge",
				size = along * (spanHalf * 2 + 1) + Vector3.new(0, 0.9, 0) + normal:Abs() * 2.2,
				position = faceOrigin + Vector3.new(0, BASE_Y + 3 + height * fraction, 0) - normal * 0.2,
				color = facade,
				material = Palette.Material.Concrete,
				decor = true,
				parent = model,
			})
		end
	end
end

local function buildEntrance(model: Model, cfg: Config, rng: Random)
	-- Recessed doorway on the face pointing most directly at the plaza.
	local normal = if math.abs(cfg.x) > math.abs(cfg.z)
		then Vector3.new(if cfg.x >= 0 then -1 else 1, 0, 0)
		else Vector3.new(0, 0, if cfg.z >= 0 then -1 else 1)
	local along = if math.abs(normal.X) > 0.5 then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0)
	local faceHalf = if math.abs(normal.X) > 0.5 then cfg.width / 2 else cfg.depth / 2
	local origin = Vector3.new(cfg.x, BASE_Y, cfg.z) + normal * faceHalf

	Kit.part({
		name = "EntranceRecess",
		size = along * 12 + Vector3.new(0, 8, 0) + normal:Abs() * 2.4,
		position = origin + Vector3.new(0, 4.2, 0) - normal * 0.6,
		color = Palette.City.Foundation,
		material = Palette.Material.Concrete,
		decor = true,
		parent = model,
	})
	Kit.part({
		name = "EntranceVoid",
		size = along * 9 + Vector3.new(0, 6.4, 0) + normal:Abs() * 1.2,
		position = origin + Vector3.new(0, 3.4, 0) - normal * 0.1,
		color = Color3.fromRGB(14, 16, 20),
		material = Palette.Material.Concrete,
		decor = true,
		parent = model,
	})
	Kit.part({
		name = "Canopy",
		size = along * 15 + Vector3.new(0, 0.8, 0) + normal:Abs() * 5,
		position = origin + Vector3.new(0, 8.8, 0) + normal * 1.4,
		color = Palette.City.FacadeTrim,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	})
	for side = -1, 1, 2 do
		Kit.part({
			name = "EntranceColumn",
			size = Vector3.new(1.8, 8.6, 1.8),
			position = origin + Vector3.new(0, 4.3, 0) + normal * 1.6 + along * (side * 6.4),
			color = Palette.City.Sidewalk,
			material = Palette.Material.Concrete,
			decor = true,
			parent = model,
		})
	end

	-- Steps down to the sidewalk.
	Kit.part({
		name = "Step",
		size = along * 15 + Vector3.new(0, 0.5, 0) + normal:Abs() * 4,
		position = origin + Vector3.new(0, 0.25, 0) + normal * 1.6,
		color = Palette.City.Sidewalk,
		material = Palette.Material.Sidewalk,
		decor = true,
		parent = model,
	})
end

local function buildRoof(model: Model, cfg: Config, rng: Random, height: number)
	local topY = BASE_Y + 3 + height

	Kit.part({
		name = "RoofDeck",
		size = Vector3.new(cfg.width - 1, 0.8, cfg.depth - 1),
		position = Vector3.new(cfg.x, topY + 0.4, cfg.z),
		color = Palette.City.RoofDeck,
		material = Palette.Material.Concrete,
		decor = true,
		parent = model,
	})

	-- Parapet: four thin walls, so the roofline is not a bare cube edge.
	for _, spec in {
		{ size = Vector3.new(cfg.width + 1.4, 2.2, 1.2), offset = Vector3.new(0, 0, cfg.depth / 2) },
		{ size = Vector3.new(cfg.width + 1.4, 2.2, 1.2), offset = Vector3.new(0, 0, -cfg.depth / 2) },
		{ size = Vector3.new(1.2, 2.2, cfg.depth + 1.4), offset = Vector3.new(cfg.width / 2, 0, 0) },
		{ size = Vector3.new(1.2, 2.2, cfg.depth + 1.4), offset = Vector3.new(-cfg.width / 2, 0, 0) },
	} do
		Kit.part({
			name = "Parapet",
			size = spec.size,
			position = Vector3.new(cfg.x, topY + 1.1, cfg.z) + spec.offset,
			color = Palette.City.FacadeTrim,
			material = Palette.Material.Concrete,
			decor = true,
			parent = model,
		})
	end

	-- Rooftop equipment gives every silhouette a different top edge.
	local units = rng:NextInteger(2, 3)
	for index = 1, units do
		local offsetX = (rng:NextNumber() - 0.5) * (cfg.width - 12)
		local offsetZ = (rng:NextNumber() - 0.5) * (cfg.depth - 12)
		local boxHeight = rng:NextNumber() * 3 + 2.5
		Kit.part({
			name = "RoofUnit",
			size = Vector3.new(rng:NextNumber() * 4 + 4, boxHeight, rng:NextNumber() * 4 + 4),
			position = Vector3.new(cfg.x + offsetX, topY + 0.8 + boxHeight / 2, cfg.z + offsetZ),
			color = Palette.City.Equipment,
			material = Palette.Material.MetalWorn,
			decor = true,
			parent = model,
		})
	end

	Kit.cylinder({
		name = "Vent",
		size = Vector3.new(3.4, 3, 3),
		position = Vector3.new(cfg.x - cfg.width * 0.25, topY + 2.3, cfg.z + cfg.depth * 0.25),
		color = Palette.City.Equipment,
		material = Palette.Material.Metal,
		decor = true,
		parent = model,
	}, "y")

	if cfg.floors >= 5 then
		Kit.part({
			name = "Mast",
			size = Vector3.new(0.6, 14, 0.6),
			position = Vector3.new(cfg.x + cfg.width * 0.3, topY + 8, cfg.z - cfg.depth * 0.3),
			color = Palette.City.Equipment,
			material = Palette.Material.Metal,
			decor = true,
			parent = model,
		})
	end
end

-- Damage is concentrated near the invasion zone; these variants share the same
-- core mass so the silhouette stays readable.
local function buildDamage(model: Model, cfg: Config, rng: Random, height: number)
	local damage = cfg.damage or "None"
	if damage == "None" then
		return
	end

	local topY = BASE_Y + 3 + height
	local normal = Vector3.new(if cfg.x >= 0 then -1 else 1, 0, 0)
	local along = Vector3.new(0, 0, 1)
	local faceHalf = cfg.width / 2
	local origin = Vector3.new(cfg.x, 0, cfg.z) + normal * faceHalf

	if damage == "Scarred" or damage == "Breached" or damage == "Sheared" then
		-- Scorch and cracking across the street face.
		for index = 1, 4 do
			local y = BASE_Y + 6 + rng:NextNumber() * (height - 12)
			Kit.part({
				name = "Scorch",
				size = along * (rng:NextNumber() * 8 + 5) + Vector3.new(0, rng:NextNumber() * 3 + 1.4, 0) + normal:Abs() * 0.4,
				cframe = CFrame.new(origin + Vector3.new(0, y, 0) - normal * 0.2 + along * ((rng:NextNumber() - 0.5) * cfg.depth * 0.6))
					* CFrame.Angles(0, 0, math.rad((rng:NextNumber() - 0.5) * 24)),
				color = Color3.fromRGB(32, 30, 30),
				material = Palette.Material.Concrete,
				decor = true,
				parent = model,
			})
		end
	end

	if damage == "Breached" or damage == "Sheared" then
		-- A hole punched through the facade with exposed floor slabs behind it.
		local breachY = BASE_Y + 3 + height * 0.55
		Kit.part({
			name = "Breach",
			size = along * 16 + Vector3.new(0, 14, 0) + normal:Abs() * 3,
			position = origin + Vector3.new(0, breachY, 0) - normal * 1.2,
			color = Color3.fromRGB(18, 20, 24),
			material = Palette.Material.Concrete,
			decor = true,
			parent = model,
		})
		for slab = -1, 1 do
			Kit.part({
				name = "ExposedFloor",
				size = along * 14 + Vector3.new(0, 0.7, 0) + normal:Abs() * 5,
				position = origin + Vector3.new(0, breachY + slab * FLOOR_HEIGHT * 0.5, 0) - normal * 2,
				color = Palette.City.Foundation,
				material = Palette.Material.Concrete,
				decor = true,
				parent = model,
			})
		end
		-- Leaning panel torn off the facade and resting on the sidewalk.
		Kit.part({
			name = "LeaningPanel",
			size = Vector3.new(1.2, 16, 9),
			cframe = CFrame.new(origin + normal * 5 + Vector3.new(0, BASE_Y + 6.5, 0) + along * 6)
				* CFrame.Angles(0, 0, math.rad(if normal.X > 0 then -28 else 28)),
			color = Palette.City.Rubble,
			material = Palette.Material.Concrete,
			decor = true,
			parent = model,
		})
		for index = 1, 3 do
			Kit.cylinder({
				name = "Rebar",
				size = Vector3.new(0.35, 0.35, rng:NextNumber() * 5 + 3),
				cframe = CFrame.new(origin + Vector3.new(0, breachY - 6, 0) - normal * 1 + along * ((index - 2) * 4))
					* CFrame.Angles(math.rad(rng:NextNumber() * 50 - 25), 0, 0),
				color = Palette.City.RebarMetal,
				material = Palette.Material.MetalWorn,
				decor = true,
				parent = model,
			}, "z")
		end
	end

	if damage == "Sheared" then
		-- The top two floors are gone; wedges sell the broken edge.
		Kit.part({
			name = "ShearCap",
			size = Vector3.new(cfg.width + 0.4, FLOOR_HEIGHT * 1.6, cfg.depth + 0.4),
			position = Vector3.new(cfg.x, topY - FLOOR_HEIGHT * 0.8 + 0.4, cfg.z),
			color = Color3.fromRGB(30, 32, 36),
			material = Palette.Material.Concrete,
			decor = true,
			parent = model,
		})
		for index = 0, 3 do
			local angle = index * math.pi / 2
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle))
			Kit.wedge({
				name = "ShearEdge",
				size = Vector3.new(cfg.width * 0.5, 7, cfg.depth * 0.34),
				cframe = CFrame.new(Vector3.new(cfg.x, topY - FLOOR_HEIGHT * 0.8 + 4, cfg.z) + offset * (cfg.width * 0.28))
					* CFrame.Angles(0, angle + math.rad(90 * index), 0),
				color = Palette.City.Rubble,
				material = Palette.Material.Rubble,
				decor = true,
				parent = model,
			})
		end
	end
end

function Buildings.build(parent: Instance, cfg: Config, rng: Random): Model
	local height = cfg.floors * FLOOR_HEIGHT
	local model = Kit.model(cfg.name or "Building", parent)
	local facade = Palette.City.Facade[((cfg.style - 1) % #Palette.City.Facade) + 1]

	-- Foundation and core mass are the only pieces that collide.
	Kit.part({
		name = "Foundation",
		size = Vector3.new(cfg.width + 2.5, 3, cfg.depth + 2.5),
		position = Vector3.new(cfg.x, BASE_Y + 1.5, cfg.z),
		color = Palette.City.Foundation,
		material = Palette.Material.Concrete,
		parent = model,
	})

	local core = Kit.part({
		name = "Core",
		size = Vector3.new(cfg.width, height, cfg.depth),
		position = Vector3.new(cfg.x, BASE_Y + 3 + height / 2, cfg.z),
		color = facade,
		material = Palette.Material.Concrete,
		parent = model,
	})
	model.PrimaryPart = core

	-- A stepped setback on taller towers varies the silhouette.
	if cfg.floors >= 6 then
		Kit.part({
			name = "Setback",
			size = Vector3.new(cfg.width * 0.62, FLOOR_HEIGHT * 1.5, cfg.depth * 0.62),
			position = Vector3.new(cfg.x, BASE_Y + 3 + height + FLOOR_HEIGHT * 0.75, cfg.z),
			color = facade,
			material = Palette.Material.Concrete,
			parent = model,
		})
	end

	buildFacade(model, cfg, rng, height)
	buildEntrance(model, cfg, rng)
	buildRoof(model, cfg, rng, height)
	buildDamage(model, cfg, rng, height)

	return model
end

Buildings.FloorHeight = FLOOR_HEIGHT
Buildings.BaseY = BASE_Y

return Buildings
