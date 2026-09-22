--!nonstrict
-- Sky, lighting and the things hanging in it.
--
-- Two moods, never both built at once:
--   Sky.build() (Chapter One Scene 1 onward, the default): a warm morning
--   sky, light haze, clean blue - "make the city feel peaceful and alive so
--   its destruction later has emotional impact."
--   Sky.revealInvasion() (Scene 2 onward): swaps to a cool dusk sky, layered
--   clouds, haze, one readable sky-rift, a distant hull, and smoke over the
--   invasion zone - built on demand rather than up front, both because nothing
--   before Scene 2 should be able to see them and because there is no reason
--   to spend the part count until they are actually needed.
-- No Skybox asset IDs are used - the engine's own procedural sky responds to
-- ClockTime and Atmosphere, which is what this tunes.
--
-- Streets stay readable on purpose: fog is long-range, ambient never drops to
-- black, and post-processing is deliberately restrained.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local Kit = require(script.Parent.Kit)

local Sky = {}

local MANAGED = "HopeManaged"

local function clearManaged(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:GetAttribute(MANAGED) then
			child:Destroy()
		end
	end
end

local function add(parent: Instance, className: string, props: { [string]: any })
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance:SetAttribute(MANAGED, true)
	instance.Parent = parent
	return instance
end

local function applyLighting(lightingConfig, atmosphereHaze: number, atmosphereGlare: number, fogStart: number, fogEnd: number, tint: Color3)
	clearManaged(Lighting)

	Lighting.ClockTime = lightingConfig.ClockTime
	Lighting.GeographicLatitude = 14
	Lighting.Brightness = lightingConfig.Brightness
	Lighting.ExposureCompensation = lightingConfig.ExposureCompensation
	Lighting.Ambient = Palette.Sky.Ambient
	Lighting.OutdoorAmbient = Palette.Sky.OutdoorAmbient
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.ShadowSoftness = 0.4
	Lighting.ColorShift_Top = lightingConfig.ColorShiftTop
	Lighting.ColorShift_Bottom = lightingConfig.ColorShiftBottom
	Lighting.FogColor = Palette.Sky.FogColor
	Lighting.FogStart = fogStart
	Lighting.FogEnd = fogEnd

	add(Lighting, "Atmosphere", {
		Name = "HopeAtmosphere",
		Density = 0.33,
		Offset = 0.1,
		Haze = atmosphereHaze,
		Glare = atmosphereGlare,
		Color = Palette.Sky.AtmosphereColor,
		Decay = Palette.Sky.AtmosphereDecay,
	})

	-- Restrained post. Bloom threshold is high so only genuine emissives glow.
	add(Lighting, "BloomEffect", {
		Name = "HopeBloom",
		Intensity = 0.55,
		Size = 20,
		Threshold = 1.35,
	})
	add(Lighting, "ColorCorrectionEffect", {
		Name = "HopeGrade",
		Brightness = 0,
		Contrast = 0.08,
		Saturation = -0.06,
		TintColor = tint,
	})
	add(Lighting, "SunRaysEffect", {
		Name = "HopeSunRays",
		Intensity = 0.06,
		Spread = 0.6,
	})
end

local function applyClouds(cover: number, density: number, color: Color3)
	local terrain = workspace.Terrain
	clearManaged(terrain)
	add(terrain, "Clouds", {
		Name = "HopeClouds",
		Cover = cover,
		Density = density,
		Color = color,
	})
end

-- A tear in the sky: a tall lens of dark shell plates around a magenta core.
local function buildRift(parent: Instance)
	local folder = Kit.folder("SkyRift", parent)
	local origin = Vector3.new(-70, 470, -620)
	local tilt = CFrame.Angles(0, math.rad(18), math.rad(-14))
	local steps = 9

	for index = 1, steps do
		local t = (index - 1) / (steps - 1)
		local taper = math.sin(t * math.pi)
		local height = 46
		local width = 10 + taper * 60
		local y = (index - (steps + 1) / 2) * height * 0.92

		Kit.part({
			name = "RiftShell",
			size = Vector3.new(width, height, 8),
			cframe = CFrame.new(origin) * tilt * CFrame.new(0, y, 0),
			color = Palette.Sky.RiftShell,
			material = Palette.Material.Shell,
			decor = true,
			castShadow = false,
			parent = folder,
		})
		Kit.part({
			name = "RiftCore",
			size = Vector3.new(math.max(2, width * 0.26), height * 0.94, 3),
			cframe = CFrame.new(origin) * tilt * CFrame.new(0, y, -3),
			color = Palette.Sky.RiftCore,
			material = Palette.Material.Energy,
			transparency = 0.25,
			decor = true,
			castShadow = false,
			parent = folder,
		})
	end

	-- Ragged edges so the silhouette is not a clean ellipse.
	for index = 1, 8 do
		local t = index / 8
		local side = if index % 2 == 0 then 1 else -1
		Kit.wedge({
			name = "RiftShard",
			size = Vector3.new(10, 60, 22),
			cframe = CFrame.new(origin) * tilt
				* CFrame.new(side * (34 + math.sin(t * 6) * 12), (t - 0.5) * 300, 0)
				* CFrame.Angles(0, 0, math.rad(side * 40)),
			color = Palette.Sky.RiftShell,
			material = Palette.Material.Shell,
			decor = true,
			castShadow = false,
			parent = folder,
		})
	end

	return folder
end

-- A single distant hull, read as silhouette only.
local function buildHull(parent: Instance)
	local folder = Kit.folder("AlienHull", parent)
	local origin = Vector3.new(330, 395, -470)
	local orient = CFrame.Angles(math.rad(-6), math.rad(-34), math.rad(4))

	Kit.part({
		name = "HullSpine",
		size = Vector3.new(58, 26, 250),
		cframe = CFrame.new(origin) * orient,
		color = Palette.Alien.Plate,
		material = Palette.Material.Shell,
		decor = true,
		castShadow = false,
		parent = folder,
	})
	Kit.part({
		name = "HullDeck",
		size = Vector3.new(110, 14, 150),
		cframe = CFrame.new(origin) * orient * CFrame.new(0, 14, 20),
		color = Palette.Alien.Shell,
		material = Palette.Material.Shell,
		decor = true,
		castShadow = false,
		parent = folder,
	})
	for _, side in { -1, 1 } do
		Kit.wedge({
			name = "HullWing",
			size = Vector3.new(20, 34, 120),
			cframe = CFrame.new(origin) * orient * CFrame.new(side * 72, 2, -20) * CFrame.Angles(0, 0, math.rad(side * 70)),
			color = Palette.Alien.Plate,
			material = Palette.Material.Shell,
			decor = true,
			castShadow = false,
			parent = folder,
		})
	end
	for index = -2, 2 do
		Kit.part({
			name = "HullLight",
			size = Vector3.new(7, 3, 7),
			cframe = CFrame.new(origin) * orient * CFrame.new(0, -13, index * 46),
			color = Palette.Alien.Energy,
			material = Palette.Material.Energy,
			transparency = 0.3,
			decor = true,
			castShadow = false,
			parent = folder,
		})
	end

	return folder
end

-- Smoke over the invasion zone. Tapered translucent columns, not particles, so
-- the cost stays flat regardless of how many are on screen.
local function buildSmoke(parent: Instance)
	local folder = Kit.folder("Smoke", parent)

	for _, spec in {
		{ at = Vector3.new(0, 0, -86), height = 260, drift = 26 },
		{ at = Vector3.new(-52, 70, -52), height = 190, drift = -20 },
		{ at = Vector3.new(52, 78, -52), height = 170, drift = 16 },
	} do
		local segments = 4
		for index = 1, segments do
			local t = (index - 0.5) / segments
			local y = spec.at.Y + t * spec.height
			Kit.cylinder({
				name = "SmokeColumn",
				size = Vector3.new(spec.height / segments * 1.1, 20 + t * 54, 20 + t * 54),
				cframe = CFrame.new(spec.at.X + spec.drift * t * t, y, spec.at.Z + spec.drift * 0.5 * t * t),
				color = Palette.Sky.Smoke,
				material = Palette.Material.Shell,
				transparency = 0.72 + t * 0.16,
				decor = true,
				castShadow = false,
				parent = folder,
			}, "y")
		end
	end

	return folder
end

-- Two slow emergency beacons. Driven by looping tweens, not a per-frame loop.
local function buildEmergencyLights(parent: Instance)
	local folder = Kit.folder("EmergencyLights", parent)

	for _, at in { Vector3.new(-30, 8, 44), Vector3.new(30, 8, -44) } do
		local lamp = Kit.part({
			name = "EmergencyLamp",
			size = Vector3.new(1.6, 1.6, 1.6),
			position = at,
			color = Palette.Sky.Emergency,
			material = Palette.Material.Energy,
			decor = true,
			parent = folder,
		})
		Kit.part({
			name = "EmergencyPost",
			size = Vector3.new(0.5, 8, 0.5),
			position = at - Vector3.new(0, 4.5, 0),
			color = Palette.City.Equipment,
			material = Palette.Material.Metal,
			decor = true,
			parent = folder,
		})
		local light = Kit.light(lamp, Palette.Sky.Emergency, 30, 2, false)
		if light then
			TweenService:Create(
				light,
				TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Brightness = 0.35 }
			):Play()
		end
	end

	return folder
end

local skyFolder: Folder? = nil
local invasionRevealed = false

-- Lighting.Technology cannot be read or written by experience scripts, so its
-- Studio-only setup is documented in the README instead of checked here.
--
-- Chapter One Scene 1's default mood: warm morning sun, light haze, a clean
-- blue sky. None of the invasion set-dressing (rift, hull, smoke, emergency
-- lights) exists yet - see revealInvasion().
function Sky.build(parent: Instance): { string }
	local folder = Kit.folder("Sky", parent)
	skyFolder = folder

	applyLighting(Config.World.MorningLighting, 0.55, 0.4, 400, 1400, Color3.fromRGB(255, 248, 232))
	applyClouds(0.32, 0.35, Color3.fromRGB(255, 250, 240))

	return {}
end

-- Chapter One Scene 2 ("The Sky Breaks") onward: swaps the sky to the
-- dusk-invasion mood and builds the rift/hull/smoke/emergency lights that
-- have no reason to exist before then. Idempotent - safe to call more than
-- once, only the first call does anything.
function Sky.revealInvasion()
	if invasionRevealed or not skyFolder then
		return
	end
	invasionRevealed = true

	applyLighting(Config.World.Lighting, 1.6, 0.25, 180, 900, Color3.fromRGB(238, 242, 255))
	applyClouds(0.72, 0.62, Color3.fromRGB(150, 158, 176))

	buildRift(skyFolder)
	buildHull(skyFolder)
	buildSmoke(skyFolder)
	buildEmergencyLights(skyFolder)
end

function Sky.isInvasionRevealed(): boolean
	return invasionRevealed
end

return Sky
