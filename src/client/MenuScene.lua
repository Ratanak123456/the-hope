--!nonstrict
-- The welcome screen's hangar: a compact, client-local scene built far from
-- the real map (nothing here ever replicates - see Opening.lua for the same
-- pattern), so it is never duplicate map/mecha loading and never waits on the
-- server's world generation at all. It reuses the real Aegis armour
-- (AegisRig, now shared) on a local display dummy, so the mecha the player
-- sees at the menu is the same design they will actually pilot.
--
-- Owns: the hangar geometry, the display mecha, ambient animation, the menu
-- camera framing, and the temporary Lighting adjustments - all restored the
-- moment the menu is left, so gameplay lighting is never accidentally
-- recoloured.
--
-- COMPOSITION (rebuilt 2026-09-21). The shot is staged as three explicit
-- depth layers rather than "a room with a mecha in it", because the old
-- version read flat and prototype-ish behind the menu column:
--
--   FOREGROUND  (z ~ +6..+12, unlit, near-black)  a gantry column, a rail and
--               a crate stack that frame the left and bottom edges. These are
--               deliberately dark: they are a frame, not content, and they
--               give the UI column something solid to sit on.
--   MIDGROUND   (z ~ -3)  the mecha, its bay markings, the work platform and
--               one lit workstation. This is the only layer that is fully lit.
--   BACKGROUND  (z ~ -21 and beyond)  the open hangar door onto a cold polar
--               dawn: haze plane, three ridge layers, a tower. Pale, low
--               contrast, doing atmospheric perspective.
--
-- LIGHTING is three-point and intentional: a warm KEY spot from the upper
-- right front, a cold RIM spot through the doorway behind the mecha (which is
-- what separates its silhouette from the background instead of relying on
-- colour alone), and a very low ambient FILL. Every other light in the scene
-- is a practical with a visible source (screen, core, status lamps).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local AegisRig = require(Shared.AegisRig)

local Responsive = require(script.Parent.Responsive)
local Settings = require(script.Parent.Settings)

local MenuScene = {}

-- Tucked far above the real map: a scriptable camera never leaves this box,
-- so it can never be seen clipping through real city geometry, and nothing
-- here can physically collide with a real player.
local ORIGIN = Vector3.new(0, 3000, 0)
local MECHA_AT = ORIGIN + Vector3.new(5, 0, -3)
local MECHA_FACING = Vector3.new(-0.3, 0, -1) -- angled slightly toward the doorway, not square-on
-- Four studs right of the mecha's own X, so the OPENING (not just the wall it
-- is cut into) sits behind the machine from the desktop lens. Measured off the
-- built set: the gap now spans -1% to +15 studs where the mecha stands at
-- -1..+11, so the whole silhouette is against sky rather than half of it
-- against the dark right-hand wall panel.
local DOORWAY_AT = ORIGIN + Vector3.new(9, 0, -21)

--[[
	THE SHOT, as one constant, because the foreground layer only exists
	relative to it.

	The desktop framing lived inside driveCamera while the foreground props
	were authored in world coordinates elsewhere in the file, and the two had
	drifted apart: measured against the camera this actually builds, the
	gantry column sat 8 studs outside the left edge of a 5-stud half-frame and
	the platform, rail and crate stack were all off the bottom or off the
	right. Nothing described as "the frame" was in the frame. The welcome
	screen was the mecha alone in an empty bay.

	So the framing is declared once, here, and the foreground is placed IN
	CAMERA SPACE through `inFrame` below - a prop meant to crop the left edge
	is authored as "4.4 studs left of the axis, 9 ahead", which cannot quietly
	stop being true.
]]
local FOV_DESKTOP = 34
local FOV_COMPACT = 44
--[[
	Framed for a mecha that STANDS ON THE FLOOR and is about thirteen studs
	tall (R15 at Config.Aegis.Scale). The previous eye/target pair was set
	against the eight-stud placeholder, so once the real rig arrived its head
	was cropped by the top edge: at 22.8 studs and a 34-degree lens the visible
	band was roughly -1.6 to +12.4 studs, and the rig runs 0 to 13.

	At 34.6 studs the visible band is about 21 studs tall, so the machine uses
	roughly three fifths of the frame height with air above and below it - a
	poster, not a close-up. The look point is six studs to its left, which puts
	the whole machine in the right half of the frame and leaves the left to the
	title column and the dark foreground.

	Both numbers are checked by tools/scenecheck's framing report rather than
	by eye, and the placeholder in buildPlaceholder is sized to the real rig so
	that report is measuring something honest.
]]
--[[
	The lens sits nearly square behind the machine on purpose.

	The composition asks for the mecha to be SILHOUETTED against the open
	hangar door (that is what the rim light through the doorway is for), and
	the doorway stands eighteen studs directly behind it. From twelve studs off
	to the side that opening projected well to the mecha's left, so the bright
	background landed beside the subject and the machine's head was dark blue
	against a dark ceiling - unreadable, which is exactly the separation
	problem this shot is supposed to solve.

	The mecha still sits right of centre; that is done with the look TARGET
	below, not by swinging the eye, so the doorway stays behind it.
]]
local DESKTOP_EYE = MECHA_AT + Vector3.new(-3.5, 9.2, 34)
local DESKTOP_TARGET = MECHA_AT + Vector3.new(-6, 6.6, 0)
local DESKTOP_FRAME = CFrame.lookAt(DESKTOP_EYE, DESKTOP_TARGET)
-- Half-frame at a given distance, in studs, for the desktop lens. 16:9 is the
-- reference aspect; a wider viewport only reveals more to the sides, so an
-- element that crops the edge here crops it or sits just outside everywhere.
local function halfHeight(distance: number): number
	return distance * math.tan(math.rad(FOV_DESKTOP) / 2)
end
local function _halfWidth(distance: number): number
	return halfHeight(distance) * (16 / 9)
end
-- A point `distance` studs ahead of the lens, `lateral` studs right of the
-- axis and `vertical` studs above it. CFrame's forward is -Z.
local function inFrame(distance: number, lateral: number, vertical: number): Vector3
	return (DESKTOP_FRAME * CFrame.new(lateral, vertical, -distance)).Position
end
-- Foreground props stand ON the floor; only their horizontal placement comes
-- from the frame. Returns the CFrame for a part of the given height whose
-- base rests on the bay floor at the framed x/z.
local function standing(distance: number, lateral: number, height: number): CFrame
	local at = inFrame(distance, lateral, 0)
	return CFrame.new(at.X, ORIGIN.Y + height / 2, at.Z)
end

local HANGAR_METAL = Color3.fromRGB(58, 64, 73)
local HANGAR_METAL_DARK = Color3.fromRGB(31, 35, 41)
local HANGAR_FLOOR = Color3.fromRGB(37, 41, 47)
local FOREGROUND_BLACK = Color3.fromRGB(13, 16, 20) -- frame layer: reads as silhouette
local WARN_STRIPE = Color3.fromRGB(198, 160, 58)
local DAWN_SKY_TOP = Color3.fromRGB(178, 198, 216)
local DAWN_HAZE = Color3.fromRGB(196, 210, 222)
local RIM_COLD = Color3.fromRGB(176, 208, 236)
local KEY_WARM = Color3.fromRGB(255, 208, 158)

local folder: Folder? = nil
local mechaDummy: Model? = nil
local mechaJoints: { [string]: Motor6D } = {}
local coreLight: PointLight? = nil
local workLightFixture: SpotLight? = nil
local connections: { RBXScriptConnection } = {}
local tweens: { Tween } = {}
local visible = false
local gestureAt = 0
local nextGlanceAt = 0

local function trackTween(tween: Tween)
	table.insert(tweens, tween)
	return tween
end

local function part(name: string, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Material = material or Enum.Material.Metal
	p.Color = color
	p.Transparency = transparency or 0
	p.Size = size
	p.CFrame = cframe
	p.Parent = folder
	return p
end

-- Frame-layer geometry: never casts or receives interesting light, never
-- competes for attention. Split out so "is this foreground?" is one call and
-- not a colour that has to be remembered at every site.
local function silhouette(name: string, cframe: CFrame, size: Vector3, material: Enum.Material?): Part
	local p = part(name, cframe, size, FOREGROUND_BLACK, material or Enum.Material.Metal)
	p.CastShadow = false
	return p
end

--------------------------------------------------------------------------------
-- BACKGROUND: the doorway and what is beyond it.
--------------------------------------------------------------------------------

local function buildBackground()
	local wallY = ORIGIN.Y + 8

	-- Back wall with a doorway cut from two side panels (never a solid slab
	-- with an unexplained hole - the opening reads as a real gap).
	part("WallLeft", CFrame.new(ORIGIN.X - 8, wallY, ORIGIN.Z - 21), Vector3.new(14, 16, 1), HANGAR_METAL)
	part("WallRight", CFrame.new(ORIGIN.X + 20, wallY, ORIGIN.Z - 21), Vector3.new(10, 16, 1), HANGAR_METAL)
	part("WallLintel", CFrame.new(ORIGIN.X + 9, wallY + 6.5, ORIGIN.Z - 21), Vector3.new(18, 3, 1), HANGAR_METAL_DARK)
	-- Door leaves parked open against the jambs: the opening is explained.
	for _, side in { -1, 1 } do
		part("DoorLeaf", CFrame.new(ORIGIN.X + 9 + side * 8.6, wallY - 1, ORIGIN.Z - 20.2), Vector3.new(1.4, 13, 1.6), HANGAR_METAL_DARK, Enum.Material.DiamondPlate)
	end

	-- Exterior, in three pale layers. Each is further, larger, paler and more
	-- transparent than the last - atmospheric perspective doing the depth work
	-- so the doorway never reads as a flat lit rectangle.
	local ridgeColors = { Color3.fromRGB(138, 152, 168), Color3.fromRGB(166, 180, 192), Color3.fromRGB(192, 204, 214) }
	for index, dz in { -40, -80, -150 } do
		local ridge = part(`Ridge{index}`, CFrame.new(DOORWAY_AT + Vector3.new(index * 6 - 10, 4 + index * 4, dz)), Vector3.new(110, 16 + index * 8, 6), ridgeColors[index], Enum.Material.SmoothPlastic, 0.08 + index * 0.2)
		ridge.CastShadow = false
	end
	local tower = part("DistantTower", CFrame.new(DOORWAY_AT + Vector3.new(-13, 15, -96)), Vector3.new(2, 26, 2), Color3.fromRGB(70, 78, 90), Enum.Material.SmoothPlastic, 0.4)
	tower.CastShadow = false

	-- Sky card: a single pale plane well past the ridges, so the gap between
	-- them is never the engine's raw skybox seen edge-on through a door.
	local sky = part("SkyCard", CFrame.new(DOORWAY_AT + Vector3.new(0, 30, -200)), Vector3.new(400, 120, 1), DAWN_SKY_TOP, Enum.Material.SmoothPlastic, 0.12)
	sky.CastShadow = false

	-- Two haze planes just past the doorway soften the join between the
	-- hangar interior and the exterior ridge line.
	for index, dz in { -4, -16 } do
		local haze = part("DoorwayHaze", CFrame.new(DOORWAY_AT + Vector3.new(0, 7, dz)), Vector3.new(28, 18, 0.2), DAWN_HAZE, Enum.Material.ForceField, 0.72 + index * 0.06)
		haze.CastShadow = false
	end

	-- Light shaft: a soft cold cone of haze in the doorway, with sparse dust
	-- motes - the only particles in the whole scene.
	-- Cylinder's length runs along local X, so a Z-axis rotation is what
	-- stands it upright (X -> world Y): X carries the height, Y/Z the width.
	local beam = part("LightShaft", CFrame.new(DOORWAY_AT + Vector3.new(0, 7, 5)) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(21, 12, 12), RIM_COLD, Enum.Material.ForceField, 0.88)
	beam.Shape = Enum.PartType.Cylinder
	beam.CastShadow = false
	-- Default texture (no asset reference at all) - Roblox's built-in soft
	-- dot reads fine at this size and this keeps the scene asset-free.
	local motes = Instance.new("ParticleEmitter")
	motes.Color = ColorSequence.new(Color3.fromRGB(226, 232, 240))
	motes.Rate = 4
	motes.Lifetime = NumberRange.new(3, 5)
	motes.Speed = NumberRange.new(0.2, 0.6)
	motes.SpreadAngle = Vector2.new(25, 25)
	motes.Size = NumberSequence.new(0.14)
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.62), NumberSequenceKeypoint.new(1, 1) })
	motes.LightEmission = 0.5
	motes.Parent = beam

	-- The RIM light: a cold spot standing just outside the doorway, aimed
	-- back into the bay. This is what draws a bright edge down the mecha's
	-- silhouette and stops it merging into the dark rear wall.
	-- Raised to the new mecha's shoulder line for the same reason as the key:
	-- a rim aimed at the waist of a thirteen-stud machine draws an edge on its
	-- legs and nothing on the part of it the audience is looking at.
	local rimHost = part("DoorwayRimSource", CFrame.new(DOORWAY_AT + Vector3.new(-1, 13, -3)), Vector3.new(0.4, 0.4, 0.4), RIM_COLD, Enum.Material.Neon, 1)
	rimHost.CastShadow = false
	local rim = Instance.new("SpotLight")
	rim.Color = RIM_COLD
	rim.Brightness = 3.1
	rim.Range = 56
	rim.Angle = 62
	rim.Face = Enum.NormalId.Back -- +Z, i.e. back toward the mecha
	rim.Parent = rimHost
end

--------------------------------------------------------------------------------
-- MIDGROUND: floor, bay, the lit structure the mecha stands in.
--------------------------------------------------------------------------------

local function buildMidground()
	local wallY = ORIGIN.Y + 8

	-- Deep enough to reach the foreground layer, which now stands where the
	-- shot actually needs it rather than past the old floor edge.
	part("Floor", CFrame.new(ORIGIN + Vector3.new(4, -0.25, -2)), Vector3.new(40, 0.5, 44), HANGAR_FLOOR, Enum.Material.Concrete)

	-- Bay markings: a painted box around the mecha's feet plus a lane that
	-- runs from the bottom of frame toward it. Leading lines, and they tell
	-- the player this is a berth somebody parks a machine in.
	for _, spec in {
		{ offset = Vector3.new(0, 0, 4.2), size = Vector3.new(9.4, 0.06, 0.32) },
		{ offset = Vector3.new(0, 0, -4.2), size = Vector3.new(9.4, 0.06, 0.32) },
		{ offset = Vector3.new(-4.7, 0, 0), size = Vector3.new(0.32, 0.06, 8.7) },
		{ offset = Vector3.new(4.7, 0, 0), size = Vector3.new(0.32, 0.06, 8.7) },
	} do
		local mark = part("BayOutline", CFrame.new(MECHA_AT + spec.offset + Vector3.new(0, 0.03, 0)), spec.size, WARN_STRIPE, Enum.Material.SmoothPlastic, 0.25)
		mark.CastShadow = false
	end
	--[[
		The approach lane, placed by DISTANCE FROM THE LENS rather than by
		offset from the mecha, because the bay floor does not enter frame
		until about eighteen studs out: the camera stands 6.6 studs above it
		on a 34-degree lens, so everything nearer than that is below the
		bottom edge. The old chevrons ran from 2.6 to 15 studs - the entire
		set was authored underneath the frame and none of it was ever seen.
		These run from where the floor appears to the mecha's own feet, which
		is the only stretch where a leading line can lead anywhere.
	]]
	for i = 1, 5 do
		local chevron = part("LaneChevron", standing(18.4 + i * 1.15, 1.6, 0.06) * CFrame.Angles(0, math.rad(-10), 0), Vector3.new(2.6, 0.06, 0.34), WARN_STRIPE, Enum.Material.SmoothPlastic, 0.3 + i * 0.1)
		chevron.CastShadow = false
	end

	-- Side structure (partial - depth cues, not a sealed box) and a ceiling
	-- with trusses, plus hanging cable runs that break up the flat plane.
	part("SideWallLeft", CFrame.new(ORIGIN.X - 15, wallY, ORIGIN.Z - 6), Vector3.new(1, 16, 34), HANGAR_METAL_DARK)
	part("SideWallRight", CFrame.new(ORIGIN.X + 23, wallY, ORIGIN.Z - 6), Vector3.new(1, 16, 34), HANGAR_METAL_DARK)
	part("Ceiling", CFrame.new(ORIGIN.X + 4, ORIGIN.Y + 15.6, ORIGIN.Z - 6), Vector3.new(40, 0.4, 34), HANGAR_METAL_DARK)
	for _, z in { -14, -4, 6 } do
		part("Truss", CFrame.new(ORIGIN.X + 4, ORIGIN.Y + 14.4, ORIGIN.Z + z), Vector3.new(40, 1.1, 1.1), HANGAR_METAL)
		for _, x in { -8, 12 } do
			part("TrussDrop", CFrame.new(ORIGIN.X + x, ORIGIN.Y + 13.3, ORIGIN.Z + z), Vector3.new(0.35, 1.6, 0.35), HANGAR_METAL_DARK).CastShadow = false
		end
	end
	for _, z in { -10, 2 } do
		local run = part("CableRun", CFrame.new(ORIGIN.X + 4, ORIGIN.Y + 13.2, ORIGIN.Z + z), Vector3.new(30, 0.18, 0.18), Color3.fromRGB(22, 24, 28), Enum.Material.SmoothPlastic)
		run.CastShadow = false
	end

	-- Wall panelling on the lit right side: vertical ribs so the big flat
	-- surface behind the mecha has some rhythm instead of one dead plane.
	for i = 1, 7 do
		local rib = part("WallRib", CFrame.new(ORIGIN.X + 22.4, ORIGIN.Y + 7, ORIGIN.Z - 18 + i * 4), Vector3.new(0.25, 13, 0.5), HANGAR_METAL)
		rib.CastShadow = false
	end

	-- Workstation + cart, right of the mecha, out of the UI column's way.
	local console = part("Workstation", CFrame.new(ORIGIN.X + 15, ORIGIN.Y + 1.6, ORIGIN.Z - 9), Vector3.new(2.6, 3.2, 1.5), HANGAR_METAL_DARK)
	local screen = part("WorkstationScreen", console.CFrame * CFrame.new(0, 0.7, -0.78), Vector3.new(1.7, 1.1, 0.05), Palette.Energy.CyanDim, Enum.Material.Neon, 0.2)
	screen.CastShadow = false
	local screenGlow = Instance.new("PointLight")
	screenGlow.Color = Palette.Energy.CyanDim
	screenGlow.Brightness = 0.6
	screenGlow.Range = 9
	screenGlow.Parent = screen
	part("Cart", CFrame.new(ORIGIN.X + 11.5, ORIGIN.Y + 1, ORIGIN.Z - 4.5), Vector3.new(2.6, 2, 1.6), HANGAR_METAL)
	part("CrateOnCart", CFrame.new(ORIGIN.X + 11.5, ORIGIN.Y + 2.3, ORIGIN.Z - 4.5), Vector3.new(1.4, 1.1, 1.2), Color3.fromRGB(88, 78, 58), Enum.Material.WoodPlanks)

	-- Status lamps down the right wall: small, dim, and they read as a place
	-- that is powered and monitored rather than an empty box.
	for i = 1, 3 do
		local lamp = part("StatusLamp", CFrame.new(ORIGIN.X + 22, ORIGIN.Y + 5.5, ORIGIN.Z - 14 + i * 6), Vector3.new(0.18, 0.5, 0.5), Palette.Energy.CyanDim, Enum.Material.Neon, 0.1)
		lamp.CastShadow = false
	end

	-- The KEY light: one warm spot high on the right, aimed down and inward
	-- at the mecha's chest. Everything readable about the midground comes
	-- from this; it is the only bright light in the room.
	-- Raised, because the subject grew. This rig was hung for a mecha that was
	-- (wrongly) about five studs tall; the real one is thirteen, and at the old
	-- height the cone washed its chest and left the head in the dark.
	local fixture = part("WorkLightFixture", CFrame.new(ORIGIN.X + 13, ORIGIN.Y + 17.5, ORIGIN.Z - 1) * CFrame.Angles(math.rad(-30), math.rad(22), 0), Vector3.new(1, 0.7, 1), HANGAR_METAL_DARK)
	local spot = Instance.new("SpotLight")
	spot.Color = KEY_WARM
	spot.Brightness = 3.4
	spot.Range = 40
	spot.Angle = 58
	spot.Face = Enum.NormalId.Bottom
	spot.Parent = fixture
	workLightFixture = spot

	-- A dim, wide fill so the shadow side of the mecha is dark but not black.
	local fillHost = part("FillSource", CFrame.new(ORIGIN + Vector3.new(-4, 7, 6)), Vector3.new(0.4, 0.4, 0.4), KEY_WARM, Enum.Material.Neon, 1)
	fillHost.CastShadow = false
	local fill = Instance.new("PointLight")
	fill.Color = Color3.fromRGB(150, 168, 196)
	fill.Brightness = 0.55
	fill.Range = 30
	fill.Parent = fillHost

	-- One maintenance arm: a base, two segments and a restrained sweep.
	local armBase = part("MaintenanceArmBase", CFrame.new(ORIGIN.X - 1, ORIGIN.Y + 0.4, ORIGIN.Z - 9), Vector3.new(1.4, 0.8, 1.4), HANGAR_METAL_DARK)
	local lower = part("MaintenanceArmLower", armBase.CFrame * CFrame.new(0, 2, 0), Vector3.new(0.5, 3.6, 0.5), HANGAR_METAL)
	local upperPivot = lower.CFrame * CFrame.new(0, 1.9, 0)
	local upper = part("MaintenanceArmUpper", upperPivot * CFrame.new(1.4, 0, 0), Vector3.new(2.8, 0.4, 0.4), HANGAR_METAL)
	local motor = Instance.new("Motor6D")
	motor.Name = "ArmJoint"
	motor.Part0 = lower
	motor.Part1 = upper
	motor.C0 = CFrame.new(0, 1.9, 0)
	motor.C1 = CFrame.new(-1.4, 0, 0)
	motor.Parent = lower
	mechaJoints["MaintenanceArm"] = motor

	-- Low ground haze across the bay floor: separates the mecha's feet from
	-- the floor plane and keeps the deep background from reading as "more
	-- floor" at the same value.
	for index, z in { -14, -2 } do
		local haze = part("GroundHaze", CFrame.new(ORIGIN + Vector3.new(4, 0.9 + index * 0.4, z)), Vector3.new(36, 2.4, 14), DAWN_HAZE, Enum.Material.ForceField, 0.93)
		haze.CastShadow = false
	end
end

--------------------------------------------------------------------------------
-- FOREGROUND: the near-black frame. Nothing here is meant to be looked at.
--------------------------------------------------------------------------------

--[[
	Every position here is stated in the shot's own frame (see `inFrame` /
	`standing` above), with the half-frame at that distance quoted beside it,
	so "this crops the left edge" is arithmetic rather than hope.

	Nothing in this layer is meant to be looked at. It is near-black, it is
	cropped, and its only jobs are to give the title column something solid to
	sit against, to close the right side so the mecha is contained rather than
	drifting out of frame, and to put one dark mass across the bottom so the
	floor does not run to the edge as an empty plane.
]]
local function buildForeground()
	--[[
		The percentages quoted below are of the half-frame at each prop's own
		distance, measured off the built scene rather than estimated: -100% is
		the left edge, +100% the right, and the mecha occupies +9% to +43%
		laterally and -76% to +53% vertically. Every prop here is checked
		against those numbers so it crops an edge without ever reaching the
		subject.
	]]
	-- LEFT EDGE: -125% to -70%. A full-height vertical, half of it cropped
	-- away, sitting behind where the title column falls.
	local column = standing(9, -4.9, 18)
	silhouette("GantryColumn", column, Vector3.new(2.2, 18, 2.2))
	silhouette("GantryCollar", column * CFrame.new(0, -4.4, 0), Vector3.new(2.8, 0.7, 2.8))
	-- Short, and kept out at the edge: a 7-stud brace reached to within a
	-- fifth of the centre line and read as a bar across the shot.
	silhouette("GantryBrace", column * CFrame.new(1.0, -0.6, -0.4) * CFrame.Angles(0, 0, math.rad(-34)), Vector3.new(0.55, 4.2, 0.55))

	-- BOTTOM LEFT: -141% to -43% laterally, top edge a little over halfway
	-- down the lower half. One dark mass so the floor does not run to the
	-- corner as an empty plane - deliberately short of the centre line.
	local stack = standing(7.2, -3.6, 8.2)
	silhouette("EquipmentCase", stack, Vector3.new(3, 8.2, 2.8), Enum.Material.DiamondPlate)
	silhouette("EquipmentCaseLid", stack * CFrame.new(0, 4.3, 0) * CFrame.Angles(0, math.rad(6), 0), Vector3.new(3.3, 0.45, 3.1))

	-- RIGHT EDGE: +72% to +165%. Closes the composition on the side the mecha
	-- stands on so it is contained rather than drifting out, and stops clear
	-- of the mecha's own +43%.
	local crates = standing(8.2, 5.4, 7)
	silhouette("CrateStackLower", crates, Vector3.new(3.6, 7, 3.4))
	silhouette("CrateStackUpper", crates * CFrame.new(-0.3, 4.2, 0.3) * CFrame.Angles(0, math.rad(9), 0), Vector3.new(3, 1.6, 2.9))

end

local function buildHangar()
	buildBackground()
	buildMidground()
	buildForeground()
end

--------------------------------------------------------------------------------
-- Mecha display: an instant, cheap silhouette shown immediately, upgraded in
-- the background to the real AegisRig armour on a local dummy. Neither step
-- ever blocks the menu from being usable - see MenuScene.show().
--------------------------------------------------------------------------------

local function buildPlaceholder(): Model
	local model = Instance.new("Model")
	model.Name = "MechaPlaceholder"
	local look = CFrame.lookAt(MECHA_AT, MECHA_AT + MECHA_FACING)
	local dark = Palette.Aegis.PlateOuter
	local function box(name: string, offset: CFrame, size: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Metal
		p.Color = dark
		p.Size = size
		p.CFrame = look * offset
		p.Parent = model
	end
	-- Proportioned to the REAL rig (R15 at Config.Aegis.Scale, about thirteen
	-- studs standing), not to a convenient small box. The placeholder is on
	-- screen for the first moments of every menu open and it is what the
	-- offline framing harness measures, so a stand-in two-thirds the height of
	-- the thing it stands in for makes both of those lie about the shot.
	box("Torso", CFrame.new(0, 7.9, 0), Vector3.new(5, 4.8, 3.4))
	box("Head", CFrame.new(0, 11.6, -0.14), Vector3.new(2.2, 2.2, 2.2))
	box("LegL", CFrame.new(-1.25, 2.8, 0), Vector3.new(1.8, 5.6, 2.1))
	box("LegR", CFrame.new(1.25, 2.8, 0), Vector3.new(1.8, 5.6, 2.1))
	box("ArmL", CFrame.new(-3.2, 7.3, 0), Vector3.new(1.5, 5, 1.7))
	box("ArmR", CFrame.new(3.2, 7.3, 0), Vector3.new(1.5, 5, 1.7))
	model.PrimaryPart = model.Torso
	model.Parent = folder
	return model
end

local function poseAegisIdle(dummy: Model)
	local joints = {}
	for _, item in dummy:GetDescendants() do
		if item:IsA("Motor6D") then
			joints[item.Name] = item
		end
	end
	-- Torso turned slightly toward camera, one shoulder lowered as if resting
	-- near a console, head angled toward the open doorway - a maintenance
	-- pose, not a combat stance.
	if joints.Waist then joints.Waist.Transform = CFrame.Angles(0, math.rad(10), 0) end
	if joints.Neck then joints.Neck.Transform = CFrame.Angles(math.rad(4), math.rad(-14), 0) end
	if joints.RightShoulder then joints.RightShoulder.Transform = CFrame.Angles(math.rad(-8), 0, math.rad(6)) end
	if joints.LeftShoulder then joints.LeftShoulder.Transform = CFrame.Angles(math.rad(6), 0, math.rad(-4)) end
	if joints.RightElbow then joints.RightElbow.Transform = CFrame.Angles(math.rad(-18), 0, 0) end
	if joints.LeftElbow then joints.LeftElbow.Transform = CFrame.Angles(math.rad(-10), 0, 0) end
	mechaJoints["Neck"] = joints.Neck
end

--[[
	Builds the real display dummy in the background. Wrapped end-to-end in a
	pcall: if avatar creation or the rig build fails for any reason, the cheap
	placeholder silhouette (already on screen) simply stays up rather than the
	menu showing a broken or half-built mecha.
]]
local function upgradeMecha()
	local ok, err = pcall(function()
		local blankDescription = Instance.new("HumanoidDescription")
		local dummy = Players:CreateHumanoidModelFromDescription(blankDescription, Enum.HumanoidRigType.R15)
		local humanoid = dummy:FindFirstChildOfClass("Humanoid")
		local root = dummy:FindFirstChild("HumanoidRootPart")
		if not (humanoid and root and root:IsA("BasePart")) then
			dummy:Destroy()
			return
		end
		if not visible then
			dummy:Destroy() -- menu was hidden again before this finished
			return
		end

		dummy.Name = "MenuAegis"
		root.Anchored = true
		humanoid.PlatformStand = true
		humanoid.WalkSpeed = 0
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

		--[[
			BUILD IT OFF SCREEN, THEN BRING IT IN.

			The Humanoid only applies the four body-scale NumberValues once the
			model is actually in the DataModel, so setting them on a model still
			parented to nil - which is what this did - did nothing at all.
			Measured in Studio: heightScale read 2.25 while every part was still
			default R15 size, a 5.5-stud avatar wearing Aegis armour rather than
			the 12-stud machine the shot is framed for. It went unnoticed because
			the rig was ALSO being buried to the hips (see the standing fix
			below), so only its chest was ever on screen.

			So it is parented first, and parked four hundred studs under the bay
			while it is assembled, because an unarmoured R15 dummy must never be
			visible in the frame. The cheap placeholder stays up throughout and
			is destroyed by the swap at the end of this function.
		]]
		dummy:PivotTo(CFrame.new(ORIGIN - Vector3.new(0, 400, 0)))
		dummy.Parent = folder

		--[[
			Model:ScaleTo, not the Humanoid's four body-scale NumberValues.

			The NumberValue route is what PlayerService.runTransform uses, and it
			is right there: it runs on a real player character that is already in
			Workspace, unanchored, and owned by the Humanoid's own scaling pass.
			None of that is true of a display dummy, and measured in Studio the
			values read back as 2.25 while every part stayed default R15 size -
			parenting it first and giving it a frame did not change that.

			ScaleTo is the supported, synchronous model-scaling API: it resizes
			parts, joint offsets and attachments in one call, with no dependency
			on parenting, anchoring or a later engine pass, which is exactly what
			a rig that is about to have armour measured off it needs. Automatic
			scaling is turned off first so the Humanoid cannot undo it.
		]]
		humanoid.AutomaticScalingEnabled = false
		dummy:ScaleTo(Config.Aegis.Scale)
		AegisRig.applyUnderlayer(dummy)
		-- One frame for the rig to resize before the plates are measured off it.
		-- PlayerService.runTransform takes exactly this wait, for exactly this
		-- reason; without it the armour is sized against the pre-scale limbs.
		task.wait()
		if not visible or not folder or dummy.Parent ~= folder then
			dummy:Destroy() -- menu was hidden while the rig was being built
			return
		end
		for _, group in AegisRig.Groups do
			AegisRig.buildGroup(dummy, humanoid, group)
		end
		AegisRig.ignite(dummy)

		-- Low, steady intensity at rest - "core visibly powered at a low
		-- intensity," not full combat brightness.
		local core = AegisRig.findPiece(dummy, "Core")
		local light = core and core:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = 0.9
			coreLight = light
		end

		poseAegisIdle(dummy)

		-- Onto its mark, now that it is the size it is supposed to be.
		dummy:PivotTo(CFrame.lookAt(MECHA_AT, MECHA_AT + MECHA_FACING))

		--[[
			STAND IT ON THE FLOOR.

			Model:PivotTo places an R15 model by its HumanoidRootPart, and that
			part sits at the HIP, not at the feet - so pivoting it to MECHA_AT
			(which is at bay-floor height) buried everything below the waist.
			At Config.Aegis.Scale that is about six and a half studs of leg
			under the floor, which is exactly why the welcome screen read as a
			torso and a head with no machine under them.

			Measured off the built rig rather than assumed, after the armour
			groups are on, so changing the scale or the armour can never
			silently start sinking it again.
		]]
		local box, extent = dummy:GetBoundingBox()
		local lowest = box.Position.Y - extent.Y / 2
		dummy:PivotTo(dummy:GetPivot() + Vector3.new(0, ORIGIN.Y - lowest, 0))

		-- Already parented (it had to be, to be scaled); the placeholder goes
		-- now that the real rig is standing where the shot expects it.
		local old = mechaDummy
		mechaDummy = dummy
		if old and old.Parent then
			old:Destroy()
		end
	end)
	if not ok then
		warn(`[SKY BROKE] MenuScene: display mecha upgrade failed, keeping placeholder: {err}`)
	end
end

--------------------------------------------------------------------------------
-- Ambient animation: core pulse, occasional head glance, one work-light sweep,
-- one arm sweep. All paused while the menu is hidden and skipped outright
-- under reduced motion, per the brief.
--------------------------------------------------------------------------------

local function stopTweens()
	for _, tween in tweens do
		tween:Cancel()
	end
	table.clear(tweens)
end

-- coreLight only exists once the async mecha upgrade finishes (it lives on
-- the AegisRig core piece), which usually hasn't happened yet by the time
-- MenuScene.show() calls this - so it polls briefly rather than bailing out
-- and never starting the pulse at all.
local function startCorePulse()
	local base: number? = nil
	local function loop()
		if not visible then
			return
		end
		if not coreLight then
			task.delay(0.5, loop)
			return
		end
		base = base or coreLight.Brightness
		local tween = trackTween(TweenService:Create(coreLight, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Brightness = (base :: number) * 1.4 }))
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and visible and coreLight then
				local back = trackTween(TweenService:Create(coreLight, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Brightness = base :: number }))
				back.Completed:Connect(function(s2)
					if s2 == Enum.PlaybackState.Completed then loop() end
				end)
				back:Play()
			end
		end)
		tween:Play()
	end
	loop()
end

local function startWorkLightSweep()
	if not workLightFixture then
		return
	end
	local fixture = workLightFixture.Parent :: BasePart
	local baseCFrame = fixture.CFrame
	local function loop()
		if not visible or not fixture.Parent then
			return
		end
		local tween = trackTween(TweenService:Create(fixture, TweenInfo.new(6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = baseCFrame * CFrame.Angles(0, math.rad(9), 0) }))
		tween.Completed:Connect(function(state)
			if state ~= Enum.PlaybackState.Completed or not visible then return end
			local back = trackTween(TweenService:Create(fixture, TweenInfo.new(6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = baseCFrame * CFrame.Angles(0, math.rad(-9), 0) }))
			back.Completed:Connect(function(s2) if s2 == Enum.PlaybackState.Completed then loop() end end)
			back:Play()
		end)
		tween:Play()
	end
	loop()
end

local function heartbeat()
	if not visible then
		return
	end
	local now = os.clock()

	-- One restrained arm sweep, on an unhurried, irregular interval.
	local arm = mechaJoints["MaintenanceArm"]
	if arm then
		if now >= gestureAt then
			gestureAt = now + 7 + math.random() * 5
		end
		local phase = math.clamp((gestureAt - now) / 6, 0, 1)
		arm.Transform = CFrame.Angles(0, 0, math.sin(phase * math.pi) * math.rad(-16))
	end

	-- Occasional head glance toward the doorway and back - not continuous.
	local neck = mechaJoints["Neck"]
	if neck then
		if now >= nextGlanceAt then
			nextGlanceAt = now + 8 + math.random() * 6
		end
		local remaining = nextGlanceAt - now
		local glance = if remaining < 1.2 then math.sin((1.2 - remaining) / 1.2 * math.pi) else 0
		neck.Transform = CFrame.Angles(math.rad(4), math.rad(-14) - math.rad(10) * glance, 0)
	end
end

--------------------------------------------------------------------------------
-- Lighting: apply a cold hangar mood, restore the game's real values on hide.
--
-- Deliberately NOT a runtime snapshot-and-restore: the server builds the real
-- morning lighting (World/Sky.lua) asynchronously, well after this menu can
-- already be showing. A snapshot taken before that finishes would be stale,
-- and restoring it later would silently undo the real gameplay mood.
-- Restoring to Config.World.MorningLighting's known values instead is
-- correct regardless of exactly when Sky.lua's replication lands - and
-- MenuScene is destroyed the instant Scene 1 starts (see Main.client.lua's
-- enterGameplay()), so this never needs to restore the later dusk-invasion
-- mood; that transition happens well after this module stops existing.
--
-- The ambient values here are deliberately LOW: the room is meant to be a
-- dark bay with three placed lights doing the work. A high global ambient
-- would flatten exactly the depth separation the three layers above exist to
-- create.
--------------------------------------------------------------------------------

local function applyDawnLighting()
	local ok = pcall(function()
		Lighting.ClockTime = 6.1
		Lighting.Brightness = 1.35
		Lighting.OutdoorAmbient = Color3.fromRGB(52, 60, 72)
		Lighting.Ambient = Color3.fromRGB(23, 27, 34)
		Lighting.ColorShift_Top = Color3.fromRGB(196, 214, 236)
		Lighting.ColorShift_Bottom = Color3.fromRGB(34, 42, 58)
		Lighting.ExposureCompensation = -0.12
	end)
	if not ok then
		warn("[SKY BROKE] MenuScene: could not apply dawn lighting preset")
	end
end

local function restoreLighting()
	local lightingConfig = Config.World.MorningLighting
	pcall(function()
		Lighting.ClockTime = lightingConfig.ClockTime
		Lighting.Brightness = lightingConfig.Brightness
		Lighting.OutdoorAmbient = Palette.Sky.OutdoorAmbient
		Lighting.Ambient = Palette.Sky.Ambient
		Lighting.ColorShift_Top = lightingConfig.ColorShiftTop
		Lighting.ColorShift_Bottom = lightingConfig.ColorShiftBottom
		Lighting.ExposureCompensation = lightingConfig.ExposureCompensation
	end)
end

--------------------------------------------------------------------------------
-- Camera
--------------------------------------------------------------------------------

local orbitPhase = 0

--[[
	Three-quarter, near eye level, on a long-ish lens. A nearly-still camera on
	purpose - only a couple of studs of drift, and none at all under reduced
	motion, per the brief's "a nearly still camera is preferable if movement
	distracts."

	FOV is 34 rather than the default 70: a long lens compresses the three
	depth layers toward each other, which is what makes the doorway read as a
	distant destination instead of a hole in a nearby wall, and it keeps the
	mecha's proportions from distorting at this range.
]]
function MenuScene.driveCamera(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local drift = 0
	if not Settings.reducedMotion() then
		orbitPhase += dt * 0.05
		drift = math.sin(orbitPhase) * 0.8
	end
	local position: Vector3, target: Vector3
	if Responsive.compact then
		-- Mobile portrait: the menu column takes the full width below, so the
		-- mecha reframes centred and higher rather than sharing the width
		-- with a side column that no longer exists at this breakpoint.
		camera.FieldOfView = FOV_COMPACT
		position = MECHA_AT + Vector3.new(drift, 9, 21)
		target = MECHA_AT + Vector3.new(0, 6.2, 0)
	else
		-- The look target is offset to the mecha's LEFT on purpose: looking
		-- straight at it would centre it on screen, but the left ~34% of the
		-- viewport is the menu column, so the focal point needs to sit right
		-- of centre to land in the "mecha focal region" the composition
		-- calls for. Camera height sits just under the mecha's chest so the
		-- machine reads as tall without the shot becoming a heroic up-angle.
		camera.FieldOfView = FOV_DESKTOP
		position = DESKTOP_EYE + Vector3.new(drift, 0, 0)
		target = DESKTOP_TARGET
	end
	camera.CFrame = CFrame.lookAt(position, target)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function MenuScene.show()
	if visible then
		return
	end
	visible = true

	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "HopeMenuScene"
		newFolder.Parent = workspace
		folder = newFolder
		buildHangar()
		-- Kept in `mechaDummy` rather than discarded: upgradeMecha swaps that
		-- reference and destroys whatever was there, so throwing the return
		-- value away left the cheap placeholder parented inside the real rig
		-- for the whole session - two overlapping mechas, and a permanently
		-- leaked model on every menu open.
		mechaDummy = buildPlaceholder()
		task.spawn(upgradeMecha)
	end

	applyDawnLighting()
	startCorePulse()
	startWorkLightSweep()

	-- One connection for the whole menu scene, on PreRender (the current name
	-- for the pre-render step; RenderStepped is deprecated). Both callbacks are
	-- deliberately tiny - a camera CFrame and a handful of joint transforms -
	-- because the renderer blocks on this step. Nothing here allocates,
	-- searches the DataModel or creates instances; the scene is fully built
	-- before the connection is made, and MenuScene.hide disconnects it.
	table.insert(connections, RunService.PreRender:Connect(function(deltaTime: number)
		MenuScene.driveCamera(deltaTime)
		heartbeat()
	end))
end

function MenuScene.hide()
	if not visible then
		return
	end
	visible = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	stopTweens()
	restoreLighting()
end

-- Full teardown: called once gameplay actually starts, so nothing from the
-- menu (parts, lights, particles, the display dummy) lingers in memory.
function MenuScene.destroy()
	MenuScene.hide()
	if folder then
		folder:Destroy()
		folder = nil
	end
	mechaDummy = nil
	coreLight = nil
	workLightFixture = nil
	table.clear(mechaJoints)
end

return MenuScene
