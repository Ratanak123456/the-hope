--!nonstrict
-- Mood presets for "The Guardian Beneath the Ice", applied directly to the
-- (client-local) Lighting service exactly the way MenuScene.lua already
-- does for the menu hangar - each client mutates its own rendered copy of
-- Lighting, nothing here ever replicates or affects other players. No sky
-- asset is used (matches World/Sky.lua's approach): the engine's own
-- procedural sky responds to ClockTime + Atmosphere, and a close FogEnd is
-- what hides the map boundary instead of a skybox.
--
-- Plain Lighting properties (ClockTime, Brightness, Ambient, ColorShift,
-- Fog*) are restored to Config.World.MorningLighting/Palette.Sky's exact
-- values on cleanup - the same restore target MenuScene.hide() already uses,
-- for the identical reason it documents: a runtime snapshot could race the
-- server's own async Sky.build() and restore a stale value over the real
-- gameplay mood.
--
-- The post-effect instances (Atmosphere/Bloom/ColorCorrection/SunRays,
-- Terrain's Clouds) are a different story: World/Sky.lua already creates and
-- owns "Hope*"-named ones of these. Rather than parenting a second,
-- competing Atmosphere/Clouds under the same Lighting/Terrain (undefined,
-- possibly conflicting rendering), this mutates the EXISTING "Hope*"
-- instances in place while the cinematic runs and restores their exact
-- Sky.build() literals on cleanup - mirroring
-- `applyLighting(Config.World.MorningLighting, 0.55, 0.4, 400, 1400,
-- Color3.fromRGB(255, 248, 232))` and `applyClouds(0.32, 0.35,
-- Color3.fromRGB(255, 250, 240))` from World/Sky.lua's Sky.build(). If
-- those instances have not replicated yet (Start Game pressed before the
-- server's world-gen finishes, which in practice does not happen - see
-- Opening.lua's own READY_TIMEOUT comment for the same assumption elsewhere)
-- this simply skips the enhancement for that one mood rather than creating a
-- duplicate: the base Lighting properties alone still carry the mood.

local Lighting = game:GetService("Lighting")
local Terrain = workspace.Terrain

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)

local NPLighting = {}

local function withEffect(parent: Instance, name: string, apply: (Instance) -> ())
	local existing = parent:FindFirstChild(name)
	if existing then
		apply(existing)
	end
end

local function setProps(instance: Instance, props: { [string]: any })
	for key, value in props do
		(instance :: any)[key] = value
	end
end

--[[
	`bloom` is per-mood rather than one global setting, because bloom is the
	mechanism that turns a bright surface into a glowing blob. An interior lit
	by warm practicals needs a HIGH threshold and a low intensity; an exterior
	snowfield can carry more. Leaving it out keeps the previous default.
]]
local function applyMood(props: { [string]: any }, atmosphere: { [string]: any }?, cloud: { [string]: any }?, grade: { [string]: any }?, bloom: { [string]: any }?)
	setProps(Lighting, props)
 withEffect(Lighting, "HopeBloom", function(instance) setProps(instance, bloom or {Intensity=0.18, Size=18, Threshold=1.6}) end)
 withEffect(Lighting, "HopeSunRays", function(instance) setProps(instance, {Intensity=0}) end)
 if atmosphere and atmosphere.Density == nil then atmosphere.Density = 0.18 end
	if atmosphere then
		withEffect(Lighting, "HopeAtmosphere", function(instance) setProps(instance, atmosphere) end)
	end
	if cloud then
		withEffect(Terrain, "HopeClouds", function(instance) setProps(instance, cloud) end)
	end
	if grade then
		withEffect(Lighting, "HopeGrade", function(instance) setProps(instance, grade) end)
	end
end

-- Storm-lit Arctic exterior: pale, low sun through heavy cloud, blue-gray
-- shift, tight fog so the map boundary never shows.
function NPLighting.exterior()
	applyMood({
		-- A low polar sun late in the day rather than flat midday overcast.
		-- The site's floodlights, the route beacons and the trucks' headlamps
		-- are all meant to read as light sources; under a 1.6-brightness
		-- noon sky none of them registered at all, and the snowfield was one
		-- undifferentiated white plane with no sense of scale.
		ClockTime = 16.9,
		GeographicLatitude = 78,
		Brightness = 1.15,
		ExposureCompensation = -0.12,
		Ambient = Color3.fromRGB(52, 60, 74),
		OutdoorAmbient = Color3.fromRGB(96, 110, 130),
		ColorShift_Top = Color3.fromRGB(38, 40, 46),
		ColorShift_Bottom = Color3.fromRGB(10, 14, 22),
		FogColor = Color3.fromRGB(126, 140, 158),
		FogStart = 60,
		FogEnd = 320,
	}, {
		Haze = 3.2,
		Glare = 0.1,
		Color = Color3.fromRGB(180, 190, 200),
		Decay = Color3.fromRGB(120, 132, 148),
	}, {
		Cover = 0.85,
		Density = 0.6,
		Color = Color3.fromRGB(150, 156, 164),
	}, {
		Brightness = -0.02,
		Contrast = 0.1,
		Saturation = -0.35,
		TintColor = Color3.fromRGB(214, 222, 232),
	})
end

--[[
	The command room. Warm practicals against the cold outside, but tuned so
	that a lit face cannot clip:

	  * exposure is pulled DOWN, not up. The old preset ran +0.05 on top of
	    three overlapping point lights; that is the "characters become glowing
	    bright shapes" report, in one number.
	  * ambient is a neutral-cool fill, bright enough that the shadow side of
	    a face and the far walls both hold detail (the "too flat in some
	    places, too dark in others" complaint is a contrast problem, not a
	    brightness one), and comfortably above the 0.16 average the camera's
	    own readability heuristic checks for.
	  * bloom threshold is raised well above the brightest surface in the
	    room, so nothing in the room can bleed into a halo.
	  * fog is set far enough back that it never veils a face at conversation
	    distance, but close enough to give the deep room some air.
]]
function NPLighting.commandTent()
	applyMood({
		ClockTime = 9.2,
		Brightness = 0.95,
		ExposureCompensation = -0.08,
		Ambient = Color3.fromRGB(62, 62, 70),
		OutdoorAmbient = Color3.fromRGB(104, 118, 134),
		ColorShift_Top = Color3.fromRGB(34, 27, 16),
		ColorShift_Bottom = Color3.fromRGB(10, 12, 18),
		FogColor = Color3.fromRGB(34, 38, 46),
		FogStart = 24,
		FogEnd = 130,
	}, {
		Density = 0.1,
		Haze = 0.9,
		Glare = 0,
		Color = Color3.fromRGB(196, 186, 168),
		Decay = Color3.fromRGB(70, 74, 84),
	}, nil, {
		Brightness = -0.02,
		Contrast = 0.12,
		Saturation = -0.08,
		TintColor = Color3.fromRGB(255, 242, 224),
	}, {
		Intensity = 0.08,
		Size = 14,
		Threshold = 2.1,
	})
end

-- Ancient interior: cool, deep, teal-lit, room tone dark - but the room and
-- the characters in it must stay readable, not black. Used for the
-- excavation-tunnel/ancient-door/warning sequences.
function NPLighting.ancientInterior()
	applyMood({
		ClockTime = 0,
		Brightness = 0.62,
		ExposureCompensation = -0.05,
		Ambient = Color3.fromRGB(58, 74, 88),
		OutdoorAmbient = Color3.fromRGB(22, 34, 38),
		ColorShift_Top = Color3.fromRGB(4, 10, 12),
		ColorShift_Bottom = Color3.fromRGB(2, 6, 8),
		FogColor = Color3.fromRGB(14, 22, 26),
		FogStart = 40,
		FogEnd = 120,
	}, {
		Haze = 2.6,
		Glare = 0,
		Color = Color3.fromRGB(60, 90, 96),
		Decay = Color3.fromRGB(20, 40, 46),
	}, nil, {
		Brightness = -0.03,
		Contrast = 0.12,
		Saturation = -0.2,
		TintColor = Color3.fromRGB(200, 226, 228),
	})
end

-- The Aegis chamber: vast, dim, cool stone with a faint gold undertone
-- promising the core beneath - readable even before the core ignites, not
-- just once `awaken` (0..1) warms it up.
function NPLighting.chamber(awaken: number?)
	local a = awaken or 0
	applyMood({
		ClockTime = 0,
		Brightness = 0.46 + 0.4 * a,
		ExposureCompensation = -0.08 + 0.15 * a,
		Ambient = Color3.fromRGB(62, 76, 92):Lerp(Color3.fromRGB(108, 92, 76), a),
		OutdoorAmbient = Color3.fromRGB(24, 28, 34):Lerp(Color3.fromRGB(80, 56, 30), a),
		ColorShift_Top = Color3.fromRGB(6, 8, 10),
		ColorShift_Bottom = Color3.fromRGB(2, 4, 6),
		FogColor = Color3.fromRGB(12, 14, 18),
		FogStart = 55,
		FogEnd = 300,
	}, {
		Haze = 2.2,
		Glare = 0.05 * a,
		Color = Color3.fromRGB(200, 170, 120),
		Decay = Color3.fromRGB(30, 26, 20),
	}, nil, {
		Brightness = -0.03,
		Contrast = 0.14,
		Saturation = -0.1,
		TintColor = Color3.fromRGB(255, 224, 190):Lerp(Color3.fromRGB(255, 200, 150), a),
	})
end

-- Violet-tinted alien prison cavern. Dark and cool, but the Sovereign's
-- silhouette must always separate from the background - very dark blue-violet
-- ambient fill, not near-black: this is "a dark creature against a darker
-- room with a readable rim," never a black screen with two glowing dots.
function NPLighting.prison()
	applyMood({
		ClockTime = 0,
		Brightness = 0.44,
		ExposureCompensation = -0.08,
		Ambient = Color3.fromRGB(64, 64, 96),
		OutdoorAmbient = Color3.fromRGB(40, 30, 50),
		ColorShift_Top = Color3.fromRGB(4, 2, 8),
		ColorShift_Bottom = Color3.fromRGB(2, 1, 6),
		FogColor = Color3.fromRGB(16, 10, 20),
		FogStart = 60,
		FogEnd = 350,
	}, {
		Haze = 3,
		Glare = 0,
		Color = Color3.fromRGB(120, 80, 150),
		Decay = Color3.fromRGB(40, 20, 50),
	}, nil, {
		Brightness = -0.05,
		Contrast = 0.16,
		Saturation = -0.05,
		TintColor = Color3.fromRGB(220, 190, 235),
	})
end

-- Emergency: dark NEUTRAL shadows carry the scene, not a red wash - the red
-- comes entirely from env.redLights' placed practicals (see Sequences.lua),
-- plus a small cool fill so skin/model silhouettes stay readable underneath
-- the red accent rather than disappearing into it.
function NPLighting.emergency()
	applyMood({
		ClockTime = 0,
		Brightness = 0.5,
		ExposureCompensation = -0.08,
		Ambient = Color3.fromRGB(48, 50, 58),
		OutdoorAmbient = Color3.fromRGB(46, 40, 46),
		ColorShift_Top = Color3.fromRGB(14, 6, 6),
		ColorShift_Bottom = Color3.fromRGB(6, 4, 8),
		FogColor = Color3.fromRGB(24, 14, 16),
		FogStart = 14,
		FogEnd = 150,
	}, {
		Haze = 2.4,
		Glare = 0.06,
		Color = Color3.fromRGB(150, 90, 90),
		Decay = Color3.fromRGB(50, 40, 48),
	}, nil, {
		Brightness = -0.02,
		Contrast = 0.13,
		Saturation = -0.2,
		TintColor = Color3.fromRGB(238, 210, 208),
	})
end

-- Near-total darkness just before/at the explosion, and again for the
-- aftermath drift under the ice.
function NPLighting.blackout()
 applyMood({ClockTime=0,Brightness=0.05,ExposureCompensation=-0.3,Ambient=Color3.fromRGB(14,16,24),OutdoorAmbient=Color3.fromRGB(14,16,24),FogColor=Color3.fromRGB(4,6,12),FogStart=150,FogEnd=1200}, {Haze=0,Glare=0,Density=0}, nil, {Brightness=0,Contrast=0.08,Saturation=0,TintColor=Color3.new(1,1,1)})
end

function NPLighting.restore()
	local lightingConfig = Config.World.MorningLighting
	applyMood({
		GeographicLatitude = 14,
		ClockTime = lightingConfig.ClockTime,
		Brightness = lightingConfig.Brightness,
		ExposureCompensation = lightingConfig.ExposureCompensation,
		OutdoorAmbient = Palette.Sky.OutdoorAmbient,
		Ambient = Palette.Sky.Ambient,
		ColorShift_Top = lightingConfig.ColorShiftTop,
		ColorShift_Bottom = lightingConfig.ColorShiftBottom,
		FogColor = Palette.Sky.FogColor,
		FogStart = 400,
		FogEnd = 1400,
	}, {
		Density = 0.32,
		Haze = 0.55,
		Glare = 0.4,
		Color = Palette.Sky.AtmosphereColor,
		Decay = Palette.Sky.AtmosphereDecay,
	}, {
		Cover = 0.32,
		Density = 0.35,
		Color = Color3.fromRGB(255, 250, 240),
	})
	withEffect(Lighting, "HopeGrade", function(instance) setProps(instance, { Brightness = 0, Contrast = 0.08, Saturation = -0.06, TintColor = Color3.fromRGB(255, 248, 232) }) end)
	withEffect(Lighting, "HopeBloom", function(instance) setProps(instance, { Intensity = 0.55, Size = 20, Threshold = 1.35 }) end)
	withEffect(Lighting, "HopeSunRays", function(instance) setProps(instance, { Intensity = 0.06, Spread = 0.6 }) end)
end

return NPLighting
