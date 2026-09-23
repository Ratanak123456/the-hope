--!strict
--[[
 THE EXCAVATION GANTRY.

 The deep-bore plant FOUND the structure: a hose a few centimetres wide that
 fell into a void at eleven hundred metres. Nothing that size can dig a hole a
 person can walk into, and the old sequence skipped straight from one to the
 other. This is the second machine - the one the expedition had flown in once
 they knew what they had hit - and it exists to make that step legible: the
 bore is a survey instrument, this is heavy plant.

 So the whole point of it is SCALE against the people standing next to it.
 Roughly, with a Roblox human at ~5.6 studs:

     overall height   ~39 studs  (bridge deck 32.6, machinery houses to 36.6,
                                  light masts to ~39)   ~7 people
     overall width     36 studs  (crawler outer faces x = +-18.2)
     depth (Z)         20 studs  (crawler length)
     cutter head       ~10 x 8.6 x 10                   ~1.5 people tall

 Five readable masses, not a thousand bolts - the camera is never close
 enough to see a bolt:

     BRIDGE / GANTRY  ===============================   (two box girders)
         [carriage] <- travels along the bridge (X)
             |  telescoping mast
         [cutter head] <- descends, rotates
   [L tower]                                 [R tower]
   [L crawler]        EXCAVATION             [R crawler]

 Everything that moves is placed from a transform stored at build time
 (Kit.rigid), never from its own previous frame: carriage position, cut depth
 and cutter rotation are three numbers, and the geometry is a pure function of
 them. Setting the same numbers twice gives the same picture, which is what a
 shot that can be scrubbed and re-entered needs.

 Deliberately painted ochre rather than the bore plant's greys: the two
 machines share a frame in the establishing shot, and they must read as two
 machines - a small grey survey plant and a large yellow excavator - rather
 than one pile of equipment.
]]
local Kit = require(script.Parent.Kit)

local ExcavationRig = {}

local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles

export type Handle = {
	model: Model,
	leftBase: Model,
	rightBase: Model,
	gantry: Model,
	carriage: Model,
	cutter: Model,
	-- Camera subjects.
	cutterBody: BasePart,
	carriageBody: BasePart,
	-- Where people stand, in world space (floor level, not root height).
	walkwayFloor: Vector3,
	operatorFloor: Vector3,

	setCutterSpin: (revolutions: number) -> (),
	setCarriagePosition: (t: number) -> (),
	setCutDepth: (amount: number) -> (),
	setSteam: (amount: number) -> (),
	setWorkLights: (amount: number) -> (),
}

-- Dimensions, relative to `origin` (the centre of the pit at ground level).
ExcavationRig.Dimensions = {
	baseX = 16, -- crawler centreline, either side
	baseWidth = 4.4,
	baseLength = 20,
	deckY = 32.6, -- top of the bridge girders
	houseTopY = 36.6,
	carriageTravel = 8, -- +- along the bridge
	cutTravel = 12, -- how far the head descends at depth 1
	headRestY = 5.4, -- head centre at depth 0 (bottom clear of the ice)
	headSize = V(10, 8.6, 10),
}

local D = ExcavationRig.Dimensions

type Hose = { segments: { BasePart }, width: number }

local function box(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Kit.part({ name = name, size = size, cframe = cf, color = color, material = material or Enum.Material.Metal, shadow = true })
	p.Parent = parent
	return p
end

local function drum(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, axis: string?): Part
	local p = Kit.cylinder({ name = name, size = size, cframe = cf, color = color, material = Enum.Material.Metal, shadow = true }, axis)
	p.Parent = parent
	return p
end

local function beam(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, color: Color3): BasePart
	local p = Kit.beam(parent, name, a, b, width, color)
	p.CastShadow = true
	return p
end

local function sagPoint(a: Vector3, b: Vector3, t: number, sag: number): Vector3
	return a:Lerp(b, t) - V(0, math.sin(t * math.pi) * sag, 0)
end

-- A static hanging cable or pipe run.
local function hang(parent: Instance, name: string, a: Vector3, b: Vector3, sag: number, width: number, color: Color3, pieces: number)
	local previous = a
	for i = 1, pieces do
		local nextPoint = sagPoint(a, b, i / pieces, sag)
		local p = Kit.beam(parent, name, previous, nextPoint, width, color, Enum.Material.SmoothPlastic)
		p.CanQuery = false
		previous = nextPoint
	end
end

-- A hose whose ends move. Segments are created once and re-placed from the two
-- end points every time, never from where they were last frame.
local function newHose(parent: Instance, name: string, width: number, color: Color3, pieces: number): Hose
	local hose: Hose = { segments = {}, width = width }
	for _ = 1, pieces do
		local p = Kit.part({ name = name, size = V(width, width, 1), color = color, material = Enum.Material.SmoothPlastic })
		p.CanQuery = false
		p.Parent = parent
		table.insert(hose.segments, p)
	end
	return hose
end

local function placeHose(hose: Hose, a: Vector3, b: Vector3, sag: number)
	local n = #hose.segments
	for i, segment in hose.segments do
		local p0 = sagPoint(a, b, (i - 1) / n, sag)
		local p1 = sagPoint(a, b, i / n, sag)
		local length = math.max((p1 - p0).Magnitude, 0.05)
		segment.Size = V(hose.width, hose.width, length + hose.width * 0.5)
		segment.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
	end
end

function ExcavationRig.build(parent: Instance, origin: Vector3, palette: any): Handle
	local C = palette
	-- Heavy-plant ochre, deliberately a long way from the bore plant's greys and
	-- kept muted: a saturated yellow the size of a building would be the
	-- brightest thing in every frame it is in.
	local PAINT = Color3.fromRGB(150, 112, 54)
	local PAINT_DARK = Color3.fromRGB(96, 74, 42)
	local STEEL = C.metal :: Color3
	local DARK = C.dark :: Color3
	local RUBBER = C.rubber :: Color3
	local HULL = C.hullDark :: Color3
	local HIVIS = C.hiVis :: Color3
	local WARM = C.warm :: Color3

	local o = origin
	local model = Kit.model("ExcavationGantry", parent)

	------------------------------------------------------------------------------
	-- 1-2. CRAWLER BASES. A track either side of each, a deck, and a machinery
	-- pack: the left carries the power unit, the right the slush separator.
	------------------------------------------------------------------------------
	local function crawler(side: number): Model
		local base = Kit.model(side < 0 and "LeftCrawlerBase" or "RightCrawlerBase", model)
		local x = side * D.baseX
		for _, offset in { -1.45, 1.45 } do
			box(base, "TrackFrame", V(1.5, 2.2, D.baseLength), CF(o + V(x + offset, 1.1, 0)), RUBBER)
			for _, z in { -D.baseLength / 2 + 1.1, D.baseLength / 2 - 1.1 } do
				drum(base, "TrackSprocket", V(1.6, 2.6, 2.6), CF(o + V(x + offset, 1.3, z)), DARK)
			end
			-- Track pads, sparse: enough that the band reads as a crawler track
			-- from a wide shot, not so many that it is a comb.
			for i = 1, 7 do
				box(base, "TrackGrouser", V(1.6, 0.22, 0.5), CF(o + V(x + offset, 2.25, -D.baseLength / 2 + i * D.baseLength / 8)), DARK)
			end
		end
		box(base, "CrawlerDeck", V(D.baseWidth + 0.8, 1.1, D.baseLength - 3), CF(o + V(x, 2.75, 0)), PAINT_DARK)
		-- Timber crane mats under the tracks: the ground at the lip of a cut is
		-- not trusted with this much weight, and they say so.
		for i = -2, 2 do
			box(base, "CraneMat", V(D.baseWidth + 1.6, 0.4, 3.6), CF(o + V(x, 0.15, i * 4)), Color3.fromRGB(78, 62, 44), Enum.Material.Wood)
		end
		if side < 0 then
			box(base, "PowerUnit", V(3.6, 3.4, 6.2), CF(o + V(x, 5, 5.2)), HULL)
			box(base, "PowerUnitRoof", V(3.9, 0.3, 6.5), CF(o + V(x, 6.85, 5.2)), DARK)
			drum(base, "ExhaustStack", V(3, 0.5, 0.5), CF(o + V(x - 1.1, 8.2, 7)), DARK, "y")
			local grille = box(base, "PowerUnitGrille", V(0.1, 2.2, 4.6), CF(o + V(x + side * 1.85, 5, 5.2)), DARK)
			grille.CanQuery = false
		else
			drum(base, "SlushSeparator", V(6.4, 3.4, 3.4), CF(o + V(x, 5.1, 5.4)), HULL, "z")
			drum(base, "SeparatorHopper", V(2.6, 2.6, 2.6), CF(o + V(x, 7.6, 3.4)), STEEL, "y")
		end
		return base
	end
	local leftBase = crawler(-1)
	local rightBase = crawler(1)

	------------------------------------------------------------------------------
	-- 3. THE GANTRY: two towers and the bridge between them.
	------------------------------------------------------------------------------
	local gantry = Kit.model("Gantry", model)
	local LEG_BOTTOM, LEG_TOP = 3.3, 30
	for _, side in { -1, 1 } do
		local x = side * D.baseX
		for _, z in { -1, 1 } do
			beam(gantry, "TowerLeg", o + V(x, LEG_BOTTOM, z * 7.2), o + V(x, LEG_TOP + 1, z * 3.4), 1.7, PAINT)
		end
		-- Girts and one diagonal per bay: a braced frame, not a ladder.
		local levels = { 9.5, 16.5, 23.5 }
		for index, y in levels do
			local t = (y - LEG_BOTTOM) / (LEG_TOP + 1 - LEG_BOTTOM)
			local half = 7.2 + (3.4 - 7.2) * t
			beam(gantry, "TowerGirt", o + V(x, y, -half), o + V(x, y, half), 0.8, PAINT_DARK)
			local previousY = index == 1 and LEG_BOTTOM + 0.6 or levels[index - 1]
			local pt = (previousY - LEG_BOTTOM) / (LEG_TOP + 1 - LEG_BOTTOM)
			local previousHalf = 7.2 + (3.4 - 7.2) * pt
			local flip = index % 2 == 0 and 1 or -1
			beam(gantry, "TowerBrace", o + V(x, previousY, flip * previousHalf), o + V(x, y, -flip * half), 0.55, PAINT_DARK)
		end
		-- The tower head the girders sit on.
		box(gantry, "TowerHead", V(3.6, 2.8, 8.4), CF(o + V(x, 31.2, 0)), PAINT_DARK)
		-- Machinery house over each tower: hoist motors on one side, the hot
		-- water plant's return pumps on the other.
		box(gantry, "MachineryHouse", V(5.4, 4, 7.2), CF(o + V(x + side * 0.6, 34.6, 0)), HULL)
		box(gantry, "MachineryHouseRoof", V(5.8, 0.35, 7.6), CF(o + V(x + side * 0.6, 36.75, 0)), DARK)
	end
	-- The bridge itself: two box girders with the carriage rails on top and a
	-- gap between them for the mast to run through.
	for _, z in { -2.6, 2.6 } do
		box(gantry, "BridgeGirder", V(37, 2.6, 1.2), CF(o + V(0, 31.3, z)), PAINT)
		box(gantry, "CarriageRail", V(33, 0.3, 0.5), CF(o + V(0, 32.75, z)), STEEL)
		-- Stiffeners on the outer web every few studs: they are what makes a
		-- girder read as a girder rather than as a painted plank.
		for i = -4, 4 do
			local stiff = box(gantry, "GirderStiffener", V(0.25, 2.4, 0.25), CF(o + V(i * 4, 31.3, z + (z > 0 and 0.72 or -0.72))), PAINT_DARK)
			stiff.CanQuery = false
		end
	end
	local sign = box(gantry, "GirderPlate", V(9, 1.2, 0.1), CF(o + V(-6, 31.3, 3.26)), PAINT_DARK)
	sign.CanQuery = false
	Kit.label(sign, "EXCAVATION GANTRY 01", Color3.fromRGB(28, 26, 22), Enum.NormalId.Back)

	------------------------------------------------------------------------------
	-- SERVICE WALKWAY along the +Z side of the bridge, and the OPERATOR STATION
	-- on the outside of the left tower. These are where people stand, and people
	-- are the scale reference for the whole machine.
	------------------------------------------------------------------------------
	local WALK_Z, WALK_Y = 4.7, 31.55
	box(gantry, "ServiceWalkway", V(30, 0.3, 2.4), CF(o + V(0, WALK_Y, WALK_Z)), STEEL, Enum.Material.DiamondPlate)
	for i = 0, 6 do
		local x = -15 + i * 5
		local post = beam(gantry, "WalkwayPost", o + V(x, WALK_Y, WALK_Z + 1.1), o + V(x, WALK_Y + 1.2, WALK_Z + 1.1), 0.14, HIVIS)
		post.CanQuery = false
		local bracket = beam(gantry, "WalkwayBracket", o + V(x, WALK_Y - 0.1, 3.2), o + V(x, WALK_Y - 0.1, WALK_Z + 1.1), 0.22, PAINT_DARK)
		bracket.CanQuery = false
	end
	for _, y in { 0.6, 1.2 } do
		local rail = beam(gantry, "WalkwayRail", o + V(-15, WALK_Y + y, WALK_Z + 1.1), o + V(15, WALK_Y + y, WALK_Z + 1.1), 0.1, HIVIS)
		rail.CanQuery = false
	end

	local OP_X, OP_Y = -D.baseX - 3.4, 20
	box(gantry, "OperatorPlatform", V(4, 0.3, 7), CF(o + V(OP_X, OP_Y, 0)), STEEL, Enum.Material.DiamondPlate)
	box(gantry, "OperatorCab", V(3, 3.2, 3.6), CF(o + V(OP_X - 0.3, OP_Y + 1.75, -1.6)), HULL)
	local glass = box(gantry, "OperatorCabGlass", V(0.12, 1.4, 3), CF(o + V(OP_X + 1.22, OP_Y + 2.4, -1.6)), C.glass :: Color3, Enum.Material.Glass)
	glass.Transparency = 0.3
	glass.CanQuery = false
	for _, z in { -3.4, 3.4 } do
		beam(gantry, "PlatformBracket", o + V(OP_X - 1.6, OP_Y - 0.1, z), o + V(-D.baseX - 0.8, OP_Y - 4, z * 0.8), 0.35, PAINT_DARK)
	end
	local opRail = beam(gantry, "PlatformRail", o + V(OP_X - 1.9, OP_Y + 1.1, 3.4), o + V(OP_X - 1.9, OP_Y + 1.1, -3.4), 0.1, HIVIS)
	opRail.CanQuery = false
	-- The ladder the operator came up: from the crawler deck to the platform.
	for _, z in { 2.6, 3.4 } do
		local stile = beam(gantry, "LadderStile", o + V(OP_X + 0.9, 3.3, z), o + V(OP_X + 0.9, OP_Y, z), 0.12, HIVIS)
		stile.CanQuery = false
	end
	for rung = 1, 16 do
		local y = 3.3 + rung * (OP_Y - 3.3) / 17
		local r = beam(gantry, "LadderRung", o + V(OP_X + 0.9, y, 2.6), o + V(OP_X + 0.9, y, 3.4), 0.08, HIVIS)
		r.CanQuery = false
	end

	------------------------------------------------------------------------------
	-- STATIC SERVICES: festoon cable under the bridge, the slush return line
	-- down the right tower to the separator, and power from the left crawler.
	------------------------------------------------------------------------------
	for i = 0, 3 do
		local x = -13 + i * 5.2
		hang(gantry, "FestoonCable", o + V(x, 29.8, -3.4), o + V(x + 5.2, 29.8, -3.4), 1.3, 0.3, DARK, 4)
	end
	local RETURN_END = o + V(D.baseX - 1.2, 29.2, -3.8)
	beam(gantry, "SlushReturnLine", RETURN_END, o + V(D.baseX - 1.2, 8.4, -3.8), 1.1, HULL)
	beam(gantry, "SlushReturnLine", o + V(D.baseX - 1.2, 8.4, -3.8), o + V(D.baseX, 6.8, 2.4), 1.1, HULL)
	-- And out of the separator, to the spoil heap: this is where the ice went.
	beam(gantry, "SlushDischarge", o + V(D.baseX + 2, 4.2, 3.6), o + V(D.baseX + 10, 1.4, -6), 0.9, HULL)
	for _, z in { 6.2, 7, 7.8 } do
		hang(gantry, "PowerCableBundle", o + V(-D.baseX - 2, 4, z), o + V(-D.baseX - 16, 0.4, z + 8), 0.8, 0.34, DARK, 6)
	end

	------------------------------------------------------------------------------
	-- WORK LIGHTS: four under the bridge looking down into the cut, two on masts
	-- over the machinery houses. Warm, like everything the expedition brought.
	------------------------------------------------------------------------------
	local lights: { SpotLight } = {}
	local lenses: { BasePart } = {}
	local function workLight(at: Vector3, look: Vector3, brightness: number, range: number)
		local cf = CFrame.lookAt(at, look)
		box(gantry, "WorkLightHousing", V(2.2, 1.3, 1.2), cf, DARK)
		local lens = box(gantry, "WorkLightLens", V(1.9, 1, 0.12), cf * CF(0, 0, -0.65), WARM, Enum.Material.Neon)
		lens.CastShadow = false
		lens.CanQuery = false
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = 70
		spot.Range = range
		spot.Color = WARM
		spot.Brightness = brightness
		spot:SetAttribute("TargetBrightness", brightness)
		spot.Parent = lens
		table.insert(lights, spot)
		table.insert(lenses, lens)
	end
	for _, x in { -10, 10 } do
		workLight(o + V(x, 29.4, -3.6), o + V(x * 0.4, -12, -2), 1.4, 46)
		workLight(o + V(x, 29.4, 3.6), o + V(x * 0.4, -12, 4), 1.4, 46)
	end
	for _, side in { -1, 1 } do
		local foot = o + V(side * (D.baseX + 0.6), 36.9, 2.8)
		beam(gantry, "LightMast", foot, foot + V(0, 2.4, 0), 0.3, STEEL)
		workLight(foot + V(0, 2.6, 0), o + V(-side * 4, -10, 0), 1.1, 60)
	end

	------------------------------------------------------------------------------
	-- 4. THE CARRIAGE. Built at its rest position (x = 0) and placed from there.
	------------------------------------------------------------------------------
	local carriage = Kit.model("Carriage", model)
	local CARRIAGE_REST = CF(o + V(0, 34.2, 0))
	local carriageBody = box(carriage, "CarriageBody", V(6.6, 2.9, 7.4), CARRIAGE_REST, PAINT)
	box(carriage, "CarriageRoof", V(6.9, 0.3, 7.7), CARRIAGE_REST * CF(0, 1.6, 0), DARK)
	drum(carriage, "HoistWinch", V(5, 2, 2), CARRIAGE_REST * CF(0, 2.6, -1.9), DARK, "x")
	drum(carriage, "HoseSaddle", V(1.2, 3.2, 3.2), CARRIAGE_REST * CF(2.6, 2.4, 2.2), STEEL)
	for _, x in { -2.6, 2.6 } do
		for _, z in { -2.6, 2.6 } do
			drum(carriage, "CarriageWheel", V(0.7, 1.4, 1.4), CARRIAGE_REST * CF(x, -1.25, z), DARK, "z")
		end
	end
	-- The outer mast sleeve, fixed to the carriage, down through the bridge gap.
	box(carriage, "MastSleeve", V(2.5, 10.5, 2.5), CARRIAGE_REST * CF(0, -3.6, 0), PAINT_DARK)
	box(carriage, "MastCollar", V(3.4, 0.8, 3.4), CARRIAGE_REST * CF(0, -8.6, 0), STEEL)

	------------------------------------------------------------------------------
	-- 5. THE CUTTER HEAD, and the inner mast that carries it.
	------------------------------------------------------------------------------
	local HEAD_REST = CF(o + V(0, D.headRestY, 0))
	local mast = Kit.model("InnerMast", model)
	box(mast, "InnerMast", V(1.7, 30, 1.7), HEAD_REST * CF(0, 4.2 + 15, 0), STEEL)
	for i = 1, 5 do
		local band = box(mast, "MastScale", V(1.78, 0.18, 1.78), HEAD_REST * CF(0, 4.2 + i * 5, 0), HIVIS)
		band.CanQuery = false
	end

	local cutter = Kit.model("CutterHead", model)
	-- Central thermal body.
	local cutterBody = drum(cutter, "ThermalBody", V(5, 6.2, 6.2), HEAD_REST, HULL, "y")
	-- Hose manifold on top, where supply and return lines meet the head.
	box(cutter, "HoseManifold", V(3.8, 1.6, 3.8), HEAD_REST * CF(0, 3.3, 0), DARK)
	drum(cutter, "SupplyStub", V(1.4, 1, 1), HEAD_REST * CF(1.6, 4.1, 1.2), STEEL, "y")
	drum(cutter, "ExtractionStub", V(1.6, 1.4, 1.4), HEAD_REST * CF(-1.4, 4.2, -1.2), STEEL, "y")
	-- Outer support ring, upper and lower, and the struts that hold it.
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local r = A(0, a, 0)
		box(cutter, "SupportRing", V(3.5, 1.1, 1.1), HEAD_REST * r * CF(0, 1.3, 4.3), PAINT)
		box(cutter, "SupportRing", V(3.7, 1, 1), HEAD_REST * r * CF(0, -1.7, 4.5), PAINT_DARK)
		if i % 2 == 0 then
			box(cutter, "RingStrut", V(0.6, 3.6, 0.6), HEAD_REST * r * CF(0, -0.2, 3.6), STEEL)
			box(cutter, "RingSpoke", V(0.5, 0.5, 1.6), HEAD_REST * r * CF(0, 1.3, 3.3), STEEL)
		end
	end
	-- Six melting/cutting sectors raked outward under the ring. These are what
	-- make it a tool that removes ice rather than a ball on a stick.
	for i = 1, 6 do
		local a = (i + 0.5) / 6 * math.pi * 2
		local sector = HEAD_REST * A(0, a, 0) * CF(0, -3.2, 3.2) * A(math.rad(-22), 0, 0)
		box(cutter, "CuttingSector", V(2.5, 2.4, 2.8), sector, STEEL)
		box(cutter, "SectorTeeth", V(2.3, 0.5, 0.6), sector * CF(0, -1.2, 1.1), DARK)
	end
	box(cutter, "HeadNose", V(2.6, 1.2, 2.6), HEAD_REST * CF(0, -3.7, 0), DARK)
	-- Hi-vis timing stripe on the body: a spinning drum shows no rotation
	-- without one, the same trick the truck wheels and the hose reel use.
	box(cutter, "RotationMark", V(0.5, 4.6, 0.3), HEAD_REST * CF(0, 0, -3.13), HIVIS)

	------------------------------------------------------------------------------
	-- MOVING SERVICES: supply festoon along the bridge to the carriage, and the
	-- supply and slush lines down the mast to the head.
	------------------------------------------------------------------------------
	local supplyFestoon = newHose(model, "SupplyHose", 0.7, DARK, 8)
	local returnFestoon = newHose(model, "SlushReturnHose", 1, HULL, 8)
	local mastSupply = newHose(model, "HeadSupplyHose", 0.6, DARK, 6)
	local mastReturn = newHose(model, "HeadReturnHose", 0.9, HULL, 6)

	------------------------------------------------------------------------------
	-- STEAM. One emitter on the head (it rides with it) and one at the separator
	-- vent. Few particles, large and soft: the job is to hide the contact line
	-- between cutter and ice, not to be an effect in its own right.
	------------------------------------------------------------------------------
	local headSteam = Kit.dust(cutterBody, 0, Color3.fromRGB(226, 232, 236), 4)
	headSteam.Lifetime = NumberRange.new(1.6, 3.2)
	headSteam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 6) })
	headSteam.Acceleration = V(0.8, 2.2, 0)
	headSteam.SpreadAngle = Vector2.new(70, 70)
	local ventHost = box(model, "SeparatorVent", V(0.8, 0.8, 0.8), CF(o + V(D.baseX, 9.2, 3.4)), DARK)
	ventHost.CanQuery = false
	local ventSteam = Kit.dust(ventHost, 0, Color3.fromRGB(226, 232, 236), 3)
	ventSteam.Lifetime = NumberRange.new(1.2, 2.6)
	ventSteam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 4) })
	ventSteam.Acceleration = V(0.6, 2.6, 0)

	------------------------------------------------------------------------------
	-- STATE. Three numbers; everything that moves is a function of them.
	------------------------------------------------------------------------------
	local placeCarriage = Kit.rigid(carriage, CARRIAGE_REST)
	local placeMast = Kit.rigid(mast, HEAD_REST)
	local placeCutter = Kit.rigid(cutter, HEAD_REST)
	local state = { carriage = 0, depth = 0, spin = 0 }

	local function apply()
		local x = state.carriage * D.carriageTravel
		local drop = state.depth * D.cutTravel
		local carriageCF = CARRIAGE_REST * CF(x, 0, 0)
		local headCF = HEAD_REST * CF(x, -drop, 0)
		placeCarriage(carriageCF)
		placeMast(headCF)
		placeCutter(headCF * A(0, state.spin * math.pi * 2, 0))
		-- Festoons: from the fixed ends of the bridge to the carriage. Slack
		-- grows with distance, which is what a real festoon does.
		local supplyFrom = o + V(-D.baseX + 1.5, 32.4, 3.2)
		local supplyTo = carriageCF.Position + V(-3.3, -0.6, 3.2)
		placeHose(supplyFestoon, supplyFrom, supplyTo, 0.8 + (supplyTo - supplyFrom).Magnitude * 0.06)
		local returnTo = carriageCF.Position + V(3.3, -1, -3.2)
		placeHose(returnFestoon, RETURN_END, returnTo, 0.8 + (returnTo - RETURN_END).Magnitude * 0.06)
		-- Down the mast: from the carriage saddle to the head manifold. Their
		-- slack is taken up by the saddle, so they stay nearly taut.
		local headTop = headCF.Position + V(0, 4.3, 0)
		placeHose(mastSupply, carriageCF.Position + V(2.6, 0.8, 3.6), headTop + V(1.6, 0.3, 1.2), 0.4)
		placeHose(mastReturn, carriageCF.Position + V(-2.4, -1.5, -3.8), headTop + V(-1.4, 0.4, -1.2), 0.4)
	end
	apply()

	local handle: Handle = {
		model = model,
		leftBase = leftBase,
		rightBase = rightBase,
		gantry = gantry,
		carriage = carriage,
		cutter = cutter,
		cutterBody = cutterBody,
		carriageBody = carriageBody,
		walkwayFloor = o + V(0, WALK_Y + 0.15, WALK_Z),
		operatorFloor = o + V(OP_X, OP_Y + 0.15, 1.6),

		-- -1 .. 1 along the bridge.
		setCarriagePosition = function(t: number)
			state.carriage = math.clamp(t, -1, 1)
			apply()
		end,
		-- 0 = parked clear of the ice, 1 = head just above the buried roof.
		setCutDepth = function(amount: number)
			state.depth = math.clamp(amount, 0, 1)
			apply()
		end,
		-- Absolute revolutions, like the hose reel: the caller owns the clock.
		setCutterSpin = function(revolutions: number)
			state.spin = revolutions
			apply()
		end,
		setSteam = function(amount: number)
			local a = math.clamp(amount, 0, 1)
			headSteam.Rate = a * 26
			ventSteam.Rate = a * 10
		end,
		setWorkLights = function(amount: number)
			local a = math.clamp(amount, 0, 1)
			for _, spot in lights do
				spot.Brightness = ((spot:GetAttribute("TargetBrightness") :: number?) or 1) * a
			end
			for _, lens in lenses do
				lens.Transparency = 0.15 + (1 - a) * 0.75
			end
		end,
	}
	return handle
end

return ExcavationRig
