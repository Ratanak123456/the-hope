--!strict
--[[
	WHO EVERY HUMAN IN THE OPENING IS, AS DATA.

	This module owns NO instances, NO joints and NO animation. It is the
	answer to "what does this person look like", and nothing else; Cast.lua
	reads it and builds the geometry, exactly as it always did, on the same
	rig, with the same Motor6D hierarchy, joint directions, limits and
	grounding.

	It exists because the alternative was losing. Every human was being built
	from one `buildHuman` body with one flat rectangular hair cap, one face,
	one collar, one chest badge, one belt, one scanner and one backpack, and
	then told apart by recolouring four values. Twenty-four people built that
	way are one mannequin twenty-four times: freeze any medium shot and the
	only thing separating the lead scientist from a background technician is
	hue. Character-specific code was starting to pile up inside buildHuman as
	`if r.kind=="Lyra"` branches, which is the shape of a problem that only
	gets worse with the next character.

	So: identity is a PROFILE, profiles are data, and the data is indexed
	deterministically. A background scientist looks the same on every replay
	because their appearance comes from their index, never from `rng` - the
	audience should be able to learn a face, and an `rng` that reshuffles
	hair and build every time the cinematic runs makes that impossible.

	THE VISUAL LANGUAGE IS ROBLOX, deliberately. Simple blocks, strong
	silhouettes, clear hair shapes, small controlled detail counts. No
	realistic noses, lips, ears or sculpted faces - the face stays the flat
	block language a default avatar reads as, and the variation below is a
	few tenths of a stud, not anatomy. Nothing here uses an external asset
	id; every shape is procedural, the same rule the rest of the project
	works under.

	THE ACCEPTANCE TEST THIS DATA IS AIMED AT: rendered as flat grey, with
	subtitles off, Lyra, Voss and Hale must still be tellable apart by
	outline alone. That is why the three of them take different hair
	families, different head coverage, different shoulder treatments and
	different things in their hands, rather than three shades of the same
	coat.
]]

local Appearance = {}

export type HairStyle =
	"LayeredBob"
	| "ShortWolf"
	| "SidePart"
	| "CrewCut"
	| "Undercut"
	| "MessyCrop"
	| "CurlyTop"
	| "TiedBack"
	| "Bald"

export type Headwear = "Helmet" | "Hood" | "HardHat"

export type FaceStyle = "Soft" | "Sharp" | "Mature" | "Neutral"

export type BodyStyle = "Light" | "Average" | "Broad" | "Compact"

export type OutfitStyle =
	"LeadResearcher"
	| "Researcher"
	| "Analyst"
	| "Commander"
	| "Technician"
	| "FieldWorker"
	| "Security"

export type Eyewear = "Glasses" | "Goggles" | "ARLens" | "GogglesUp"

-- One block of hair. `at` is in HEAD-LOCAL space at scale 1; Cast multiplies
-- by the character's scale and welds it to the head, so it turns when the
-- head turns and can never be left behind.
export type HairPiece = {
	name: string,
	size: Vector3,
	at: CFrame,
	kind: string?,
}

export type FaceMetrics = {
	eyeWidth: number,
	eyeHeight: number,
	eyeSpacing: number,
	browWidth: number,
	browThickness: number,
	browHeight: number,
	browTilt: number,
	mouthWidth: number,
}

-- Width multipliers ONLY. Nothing here touches a joint offset, a pivot or a
-- limb LENGTH: the animation system was stabilised against the current rig's
-- geometry (sole drop, knee/elbow bend direction, hand-clear-of-torso) and a
-- silhouette pass is not the place to move any of that. Build reads as a
-- visual overlay plus a few percent of torso and arm thickness.
export type BodyMetrics = {
	torsoWidth: number,
	armWidth: number,
	shoulderPad: number,
}

export type Profile = {
	hairStyle: HairStyle,
	hairColor: Color3,
	faceStyle: FaceStyle,
	bodyStyle: BodyStyle,
	outfitStyle: OutfitStyle,

	skin: Color3,
	coat: Color3,
	pants: Color3,
	trim: Color3,
	accent: Color3?,

	scale: number,

	headwear: Headwear?,
	eyewear: Eyewear?,
	equipment: { string },
}

local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

--------------------------------------------------------------------------------
-- PALETTE
--
-- Everything here obeys Cast.lua's albedo budget (see its note): no garment
-- brighter than ~152, no skin brighter than ~204, and the brightest thing in
-- frame should be a light source rather than a person. Hair is naturally the
-- darkest large surface on a head and stays that way.
--------------------------------------------------------------------------------

local HAIR = {
	black = rgb(28, 24, 24),
	darkBrown = rgb(38, 27, 22),
	brown = rgb(64, 45, 33),
	lightBrown = rgb(96, 72, 50),
	auburn = rgb(86, 46, 34),
	sandy = rgb(124, 103, 70),
	ash = rgb(92, 92, 96),
	grey = rgb(141, 143, 142),
}

local SKIN = {
	fair = rgb(203, 168, 143),
	warm = rgb(176, 132, 100),
	light = rgb(194, 166, 141),
	tan = rgb(187, 140, 111),
	olive = rgb(168, 126, 96),
	brown = rgb(157, 112, 83),
	deep = rgb(105, 73, 55),
	rich = rgb(139, 99, 74),
}

local CLOTH = {
	field = rgb(150, 153, 144), -- the existing expedition parka grey
	parka = rgb(138, 121, 101), -- Lyra: warmer and a shade darker than the rest
	navy = rgb(37, 48, 65), -- Voss
	command = rgb(31, 36, 43), -- Hale, darker and flatter than any coat
	slate = rgb(74, 84, 92),
	canvas = rgb(112, 108, 95),
	ice = rgb(120, 141, 155),
	dark = rgb(25, 32, 39),
	metal = rgb(53, 65, 71),
	orange = rgb(177, 106, 61),
	rust = rgb(132, 66, 62),
	ivory = rgb(184, 184, 173),
	hiVis = rgb(151, 116, 52),
}

Appearance.Hair = HAIR
Appearance.Skin = SKIN
Appearance.Cloth = CLOTH

--------------------------------------------------------------------------------
-- HAIR
--
-- Two to six pieces per style, never more. The old single cap was one block
-- the width of the skull, which reads as a helmet at any distance and is
-- identical on everybody; these are built so the OUTLINE differs - where the
-- volume sits, how far down the sides come, whether there is a nape, whether
-- the fringe is centred.
--
-- The head is 0.8 x 0.85 x 0.8 and the rig faces -Z, so the face sits at
-- z = -0.39..-0.40 with the brows at y = 0.17..0.21. Every fringe below
-- therefore bottoms out at y >= 0.21: a fringe that hangs any lower crosses
-- its own eyebrows, which is the classic procedural-hair failure.
--------------------------------------------------------------------------------

local HAIR_STYLES: { [string]: { HairPiece } } = {
	-- Lyra. Short layered bob: full crown, side layers ending around the jaw,
	-- a short nape, and a deliberately ASYMMETRIC fringe - the left layer is
	-- longer than the right, so her three-quarter outline is not the mirror
	-- of itself and reads as a specific person rather than a hair preset.
	LayeredBob = {
		{ name = "HairCrown", size = V(0.90, 0.26, 0.88), at = CF(0, 0.35, 0.04) },
		-- The side layers sit PROUD of the skull (the head is 0.8 wide, these
		-- are centred at 0.41), because a bob that stops at the skull line
		-- reads as a swim cap. This is what makes her head wider than Voss's
		-- in outline and not only in colour.
		{ name = "HairSideLeft", size = V(0.24, 0.56, 0.64), at = CF(-0.41, 0.06, 0.05) },
		{ name = "HairSideRight", size = V(0.22, 0.42, 0.60), at = CF(0.41, 0.14, 0.06) },
		{ name = "HairBack", size = V(0.78, 0.44, 0.22), at = CF(0, 0.05, 0.39) },
		{ name = "HairFringe", size = V(0.50, 0.22, 0.14), at = CF(-0.12, 0.31, -0.40) * A(0, 0, math.rad(-11)) },
	},
	-- Shorter and choppier than the bob, with a longer nape. Reads as a
	-- modern short cut on anyone, which is the point: it is assigned to both
	-- male- and female-presenting characters below.
	ShortWolf = {
		{ name = "HairCrown", size = V(0.86, 0.26, 0.86), at = CF(0, 0.34, 0.03) },
		{ name = "HairSideLeft", size = V(0.16, 0.42, 0.56), at = CF(-0.38, 0.13, 0.06) },
		{ name = "HairSideRight", size = V(0.16, 0.38, 0.54), at = CF(0.38, 0.15, 0.07) },
		{ name = "HairNape", size = V(0.56, 0.32, 0.17), at = CF(0, -0.03, 0.40) },
		{ name = "HairFringe", size = V(0.50, 0.18, 0.13), at = CF(0.08, 0.32, -0.39) * A(0, 0, math.rad(7)) },
	},
	-- Voss. Controlled, combed, one heavy sweep over a low part; the tight
	-- temple strips are what make it read as "kept" rather than "short".
	SidePart = {
		{ name = "HairCrown", size = V(0.84, 0.22, 0.84), at = CF(0, 0.36, 0.03) },
		{ name = "HairSweep", size = V(0.52, 0.20, 0.28), at = CF(-0.13, 0.38, -0.27) * A(0, 0, math.rad(-12)) },
		{ name = "HairPartSide", size = V(0.22, 0.15, 0.30), at = CF(0.32, 0.33, -0.19) },
		{ name = "HairBack", size = V(0.74, 0.22, 0.15), at = CF(0, 0.22, 0.40) },
		{ name = "HairTempleLeft", size = V(0.07, 0.20, 0.56), at = CF(-0.395, 0.22, 0.06) },
		{ name = "HairTempleRight", size = V(0.07, 0.20, 0.56), at = CF(0.395, 0.22, 0.06) },
	},
	-- Hale. Almost no volume: a short crown, a slightly raised front, and hair
	-- that sits LOW on the sides. Two pieces would have read as a swim cap;
	-- the low side strips are what make it military.
	CrewCut = {
		{ name = "HairCrown", size = V(0.84, 0.18, 0.84), at = CF(0, 0.37, 0.02) },
		{ name = "HairFront", size = V(0.72, 0.13, 0.17), at = CF(0, 0.40, -0.33) },
		{ name = "HairSideLeft", size = V(0.07, 0.26, 0.66), at = CF(-0.395, 0.16, 0.05) },
		{ name = "HairSideRight", size = V(0.07, 0.26, 0.66), at = CF(0.395, 0.16, 0.05) },
		{ name = "HairNape", size = V(0.70, 0.20, 0.09), at = CF(0, 0.14, 0.40) },
	},
	-- Tall on top, shaved at the temples. The strongest vertical of the set,
	-- so it is the one background silhouette that is unmistakable in a crowd.
	Undercut = {
		{ name = "HairTop", size = V(0.72, 0.36, 0.78), at = CF(0, 0.41, 0.04) },
		{ name = "HairShaveLeft", size = V(0.06, 0.24, 0.62), at = CF(-0.40, 0.19, 0.05) },
		{ name = "HairShaveRight", size = V(0.06, 0.24, 0.62), at = CF(0.40, 0.19, 0.05) },
		{ name = "HairBack", size = V(0.62, 0.17, 0.13), at = CF(0, 0.28, 0.40) },
	},
	-- Deliberately off-axis: the two tufts are rotated against each other so
	-- the outline is lopsided from every angle.
	MessyCrop = {
		{ name = "HairCrown", size = V(0.84, 0.24, 0.82), at = CF(0, 0.35, 0.02) },
		{ name = "HairTuftLeft", size = V(0.34, 0.18, 0.30), at = CF(-0.18, 0.44, -0.09) * A(0, 0, math.rad(11)) },
		{ name = "HairTuftRight", size = V(0.30, 0.16, 0.28), at = CF(0.20, 0.43, 0.11) * A(0, 0, math.rad(-15)) },
		{ name = "HairFringe", size = V(0.52, 0.16, 0.13), at = CF(0.04, 0.33, -0.39) * A(0, 0, math.rad(6)) },
		{ name = "HairBack", size = V(0.70, 0.24, 0.15), at = CF(0, 0.20, 0.40) },
	},
	-- FIVE rounded pieces, not fifty. The environment pass had just finished
	-- deleting a snowfield made of overlapping spheres; a head is not the
	-- place to reintroduce that. A flat base carries the hairline and four
	-- controlled puffs carry the volume.
	CurlyTop = {
		{ name = "HairBase", size = V(0.86, 0.26, 0.86), at = CF(0, 0.34, 0.03) },
		{ name = "HairCurlLeft", size = V(0.44, 0.40, 0.44), at = CF(-0.23, 0.46, -0.05), kind = "ball" },
		{ name = "HairCurlRight", size = V(0.42, 0.38, 0.42), at = CF(0.24, 0.47, 0.05), kind = "ball" },
		{ name = "HairCurlBack", size = V(0.40, 0.36, 0.40), at = CF(0, 0.47, 0.25), kind = "ball" },
		{ name = "HairCurlFront", size = V(0.36, 0.32, 0.36), at = CF(0, 0.44, -0.25), kind = "ball" },
	},
	-- Smooth over the crown, gathered at the nape, with a short tail. Medium
	-- length worn UP, so it is a different outline to the bob without being
	-- "the long-haired one".
	TiedBack = {
		{ name = "HairCrown", size = V(0.86, 0.24, 0.84), at = CF(0, 0.35, 0.03) },
		{ name = "HairSideLeft", size = V(0.12, 0.30, 0.60), at = CF(-0.40, 0.21, 0.06) },
		{ name = "HairSideRight", size = V(0.12, 0.30, 0.60), at = CF(0.40, 0.21, 0.06) },
		{ name = "HairBand", size = V(0.26, 0.18, 0.20), at = CF(0, 0.12, 0.42) },
		{ name = "HairTail", size = V(0.24, 0.46, 0.22), at = CF(0, -0.10, 0.46) * A(math.rad(-8), 0, 0) },
	},
	Bald = {},
}

--------------------------------------------------------------------------------
-- HEADWEAR, worn OVER hair rather than instead of it.
--
-- Helmeted characters below are always given a tight hair style, so what
-- shows under the shell is a hairline at the temples rather than a block
-- fighting its way out through the crown.
--------------------------------------------------------------------------------

local HEADWEAR: { [string]: { HairPiece } } = {
	Helmet = {
		{ name = "HelmetShell", size = V(0.94, 0.46, 0.92), at = CF(0, 0.31, 0.02) },
		{ name = "HelmetBrim", size = V(0.96, 0.09, 0.26), at = CF(0, 0.15, -0.35) },
		{ name = "HelmetNape", size = V(0.88, 0.22, 0.15), at = CF(0, 0.05, 0.40) },
	},
	HardHat = {
		{ name = "HardHatShell", size = V(0.92, 0.40, 0.90), at = CF(0, 0.33, 0.02) },
		{ name = "HardHatCrest", size = V(0.16, 0.14, 0.86), at = CF(0, 0.52, 0.02) },
		{ name = "HardHatBrim", size = V(0.94, 0.08, 0.30), at = CF(0, 0.17, -0.38) },
	},
	Hood = {
		{ name = "HoodShell", size = V(0.98, 0.50, 0.94), at = CF(0, 0.28, 0.07) },
		{ name = "HoodRim", size = V(0.94, 0.16, 0.14), at = CF(0, 0.36, -0.38) },
		{ name = "HoodDrapeLeft", size = V(0.14, 0.42, 0.50), at = CF(-0.44, 0.08, 0.10) },
		{ name = "HoodDrapeRight", size = V(0.14, 0.42, 0.50), at = CF(0.44, 0.08, 0.10) },
	},
}

--------------------------------------------------------------------------------
-- FACES
--
-- Four presets, all within a few hundredths of a stud of each other. This is
-- deliberately conservative: the brief is a stylized Roblox face, and the
-- distance between "these two people are different" and "this person is a
-- caricature" is very small at this scale. Identity is carried by hair,
-- clothing and silhouette; the face only has to stop being literally
-- identical on twenty-four heads.
--------------------------------------------------------------------------------

local FACES: { [string]: FaceMetrics } = {
	Neutral = {
		eyeWidth = 0.16, eyeHeight = 0.14, eyeSpacing = 0.16,
		browWidth = 0.18, browThickness = 0.04, browHeight = 0.19, browTilt = 0,
		mouthWidth = 0.20,
	},
	Soft = {
		eyeWidth = 0.17, eyeHeight = 0.155, eyeSpacing = 0.155,
		browWidth = 0.17, browThickness = 0.035, browHeight = 0.205, browTilt = 0.05,
		mouthWidth = 0.19,
	},
	Sharp = {
		eyeWidth = 0.155, eyeHeight = 0.115, eyeSpacing = 0.168,
		browWidth = 0.195, browThickness = 0.038, browHeight = 0.178, browTilt = -0.06,
		mouthWidth = 0.19,
	},
	Mature = {
		eyeWidth = 0.145, eyeHeight = 0.105, eyeSpacing = 0.172,
		browWidth = 0.215, browThickness = 0.055, browHeight = 0.172, browTilt = -0.025,
		mouthWidth = 0.22,
	},
}

local BODIES: { [string]: BodyMetrics } = {
	Light = { torsoWidth = 0.94, armWidth = 0.95, shoulderPad = 0 },
	Average = { torsoWidth = 1, armWidth = 1, shoulderPad = 0 },
	Broad = { torsoWidth = 1.07, armWidth = 1.05, shoulderPad = 0.16 },
	Compact = { torsoWidth = 1.04, armWidth = 1.02, shoulderPad = 0.08 },
}

function Appearance.hair(style: HairStyle): { HairPiece }
	return HAIR_STYLES[style] or HAIR_STYLES.CrewCut
end

function Appearance.headwear(kind: Headwear): { HairPiece }
	return HEADWEAR[kind] or {}
end

function Appearance.face(style: FaceStyle): FaceMetrics
	return FACES[style] or FACES.Neutral
end

function Appearance.body(style: BodyStyle): BodyMetrics
	return BODIES[style] or BODIES.Average
end

function Appearance.hairStyles(): { string }
	local names = {}
	for name in HAIR_STYLES do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

--------------------------------------------------------------------------------
-- THE THREE LEADS
--
-- Read these as three OUTLINES rather than three costumes:
--
--   Lyra  - widest head shape (layered bob down to the jaw), narrowest
--           shoulders, one small thing in one hand, nothing on her back.
--   Voss  - tightest head shape, tallest, one strong vertical (the scarf)
--           down an otherwise clean front, a flat tablet held in close.
--   Hale  - smallest head shape (cropped, no volume), widest shoulders by a
--           clear margin, a long horizontal (the slung rifle) across his hip.
--
-- Hair volume, shoulder width and held silhouette all disagree between the
-- three, which is what survives being rendered as flat grey.
--------------------------------------------------------------------------------

local LEADS: { [string]: Profile } = {
	Lyra = {
		hairStyle = "LayeredBob",
		hairColor = HAIR.darkBrown,
		faceStyle = "Soft",
		-- Average, not Light: Voss is the narrow one, and two leads sharing a
		-- build meant their silhouettes differed only from the neck up.
		bodyStyle = "Average",
		outfitStyle = "LeadResearcher",
		skin = SKIN.warm,
		coat = CLOTH.parka,
		pants = CLOTH.dark,
		trim = CLOTH.orange,
		accent = CLOTH.orange,
		scale = 1,
		-- A single temple lens, never Voss's two. They used to wear the exact
		-- same pair of cyan rectangles, which made the two scientists in the
		-- room read as a matched set at any distance over about six studs.
		eyewear = "ARLens",
		equipment = { "Scanner", "HipPouch", "ShoulderStrap" },
	},
	Voss = {
		hairStyle = "SidePart",
		hairColor = HAIR.black,
		faceStyle = "Sharp",
		bodyStyle = "Light",
		outfitStyle = "Analyst",
		skin = SKIN.light,
		coat = CLOTH.navy,
		pants = CLOTH.dark,
		trim = CLOTH.ivory,
		accent = CLOTH.ice,
		scale = 1.06,
		eyewear = "Glasses",
		equipment = { "Scarf", "Tablet" },
	},
	Hale = {
		hairStyle = "CrewCut",
		hairColor = HAIR.grey,
		faceStyle = "Mature",
		bodyStyle = "Broad",
		outfitStyle = "Commander",
		skin = SKIN.tan,
		coat = CLOTH.command,
		pants = CLOTH.metal,
		trim = CLOTH.rust,
		accent = CLOTH.rust,
		scale = 1.12,
		-- No scanner, no expedition pack. He used to carry the identical
		-- scientist kit, which is most of why the senior officer read as a
		-- third researcher.
		equipment = { "ShoulderYoke", "RankMarker", "HeavyBelt", "SlungRifle" },
	},
}

function Appearance.lead(name: string): Profile
	local profile = LEADS[name]
	assert(profile, `no lead appearance profile named {name}`)
	return profile
end

--------------------------------------------------------------------------------
-- THE EIGHT LAB SCIENTISTS
--
-- Indexed, never randomised: scientist 3 is the same person with the same
-- curls on every replay. Six hair families across eight people, and hair
-- length is NOT assigned by gender presentation - short layered, cropped and
-- undercut styles sit on female-presenting characters here as ordinary
-- choices, and the longest style in the group (TiedBack) is not reserved for
-- them either.
--
-- Equipment is what actually breaks the clone effect: four of the eight carry
-- nothing at all, because a lab technician at a console has their hands on
-- the console.
--------------------------------------------------------------------------------

local SCIENTISTS: { Profile } = {
	{
		hairStyle = "LayeredBob", hairColor = HAIR.darkBrown, faceStyle = "Soft",
		bodyStyle = "Light", outfitStyle = "Researcher",
		skin = SKIN.fair, coat = CLOTH.field, pants = CLOTH.dark, trim = CLOTH.orange,
		scale = 0.96, equipment = { "Tablet" },
	},
	{
		hairStyle = "SidePart", hairColor = HAIR.black, faceStyle = "Sharp",
		bodyStyle = "Average", outfitStyle = "Analyst",
		skin = SKIN.brown, coat = CLOTH.ice, pants = CLOTH.dark, trim = CLOTH.ivory,
		scale = 1.02, eyewear = "Glasses", equipment = { "HipPouch" },
	},
	{
		hairStyle = "CurlyTop", hairColor = HAIR.black, faceStyle = "Neutral",
		bodyStyle = "Broad", outfitStyle = "Technician",
		skin = SKIN.deep, coat = CLOTH.slate, pants = CLOTH.dark, trim = CLOTH.orange,
		scale = 1.04, equipment = { "SmallPack", "Radio" },
	},
	{
		hairStyle = "TiedBack", hairColor = HAIR.brown, faceStyle = "Soft",
		bodyStyle = "Average", outfitStyle = "Researcher",
		skin = SKIN.tan, coat = CLOTH.field, pants = CLOTH.dark, trim = CLOTH.ivory,
		scale = 0.99, equipment = {},
	},
	{
		hairStyle = "MessyCrop", hairColor = HAIR.sandy, faceStyle = "Neutral",
		bodyStyle = "Compact", outfitStyle = "Technician",
		skin = SKIN.olive, coat = CLOTH.canvas, pants = CLOTH.dark, trim = CLOTH.hiVis,
		scale = 0.94, eyewear = "GogglesUp", equipment = { "ToolRoll" },
	},
	{
		hairStyle = "ShortWolf", hairColor = HAIR.auburn, faceStyle = "Sharp",
		bodyStyle = "Light", outfitStyle = "Analyst",
		skin = SKIN.light, coat = CLOTH.ice, pants = CLOTH.dark, trim = CLOTH.ivory,
		scale = 0.97, equipment = { "Scanner" },
	},
	{
		hairStyle = "Undercut", hairColor = HAIR.ash, faceStyle = "Mature",
		bodyStyle = "Average", outfitStyle = "Technician",
		skin = SKIN.rich, coat = CLOTH.slate, pants = CLOTH.dark, trim = CLOTH.orange,
		scale = 1.01, equipment = { "Radio" },
	},
	{
		hairStyle = "CrewCut", hairColor = HAIR.lightBrown, faceStyle = "Neutral",
		bodyStyle = "Broad", outfitStyle = "Researcher",
		skin = SKIN.warm, coat = CLOTH.field, pants = CLOTH.dark, trim = CLOTH.orange,
		scale = 1.05, equipment = {},
	},
}

function Appearance.scientist(index: number): Profile
	return SCIENTISTS[(index - 1) % #SCIENTISTS + 1]
end

--------------------------------------------------------------------------------
-- SECURITY
--
-- One faction language - same helmet family, same webbing, same dark palette -
-- in three silhouettes, so they read as a unit without reading as a stamped
-- copy. Variation is clothing and kit, never joint geometry.
--
--   LightScout       no chest plate, goggles down, rifle carried
--   Standard         neck guard, rifle slung
--   HeavyLead        chest plate and shoulder pads, the widest of the three
--
-- One of the eight (index 6) has his helmet off, which is the cheapest way to
-- tell the audience these are people rather than equipment.
--------------------------------------------------------------------------------

local SOLDIERS: { Profile } = {
	{
		hairStyle = "CrewCut", hairColor = HAIR.black, faceStyle = "Neutral",
		bodyStyle = "Average", outfitStyle = "Security",
		skin = SKIN.tan, coat = CLOTH.metal, pants = CLOTH.dark, trim = CLOTH.metal,
		scale = 1.02, headwear = "Helmet", equipment = { "Webbing", "NeckGuard", "SlungRifle" },
	},
	{
		hairStyle = "CrewCut", hairColor = HAIR.brown, faceStyle = "Sharp",
		bodyStyle = "Light", outfitStyle = "Security",
		skin = SKIN.fair, coat = CLOTH.slate, pants = CLOTH.dark, trim = CLOTH.metal,
		scale = 0.97, headwear = "Helmet", eyewear = "Goggles", equipment = { "Webbing", "Rifle" },
	},
	{
		hairStyle = "CrewCut", hairColor = HAIR.ash, faceStyle = "Mature",
		bodyStyle = "Broad", outfitStyle = "Security",
		skin = SKIN.brown, coat = CLOTH.metal, pants = CLOTH.dark, trim = CLOTH.rust,
		scale = 1.09, headwear = "Helmet", eyewear = "Goggles",
		equipment = { "ChestPlate", "ShoulderYoke", "Webbing", "SlungRifle" },
	},
	{
		hairStyle = "CrewCut", hairColor = HAIR.darkBrown, faceStyle = "Neutral",
		bodyStyle = "Average", outfitStyle = "Security",
		skin = SKIN.deep, coat = CLOTH.metal, pants = CLOTH.dark, trim = CLOTH.metal,
		scale = 1.01, headwear = "Helmet", equipment = { "Webbing", "NeckGuard", "SlungRifle" },
	},
	{
		hairStyle = "CrewCut", hairColor = HAIR.sandy, faceStyle = "Sharp",
		bodyStyle = "Light", outfitStyle = "Security",
		skin = SKIN.olive, coat = CLOTH.slate, pants = CLOTH.dark, trim = CLOTH.metal,
		scale = 0.98, headwear = "Helmet", equipment = { "Webbing", "Rifle" },
	},
	{
		-- Helmet off. Same uniform, visible face.
		hairStyle = "MessyCrop", hairColor = HAIR.lightBrown, faceStyle = "Neutral",
		bodyStyle = "Average", outfitStyle = "Security",
		skin = SKIN.light, coat = CLOTH.metal, pants = CLOTH.dark, trim = CLOTH.metal,
		scale = 1.03, eyewear = "GogglesUp", equipment = { "Webbing", "NeckGuard", "SlungRifle" },
	},
	{
		hairStyle = "CrewCut", hairColor = HAIR.black, faceStyle = "Mature",
		bodyStyle = "Broad", outfitStyle = "Security",
		skin = SKIN.rich, coat = CLOTH.metal, pants = CLOTH.dark, trim = CLOTH.rust,
		scale = 1.08, headwear = "Helmet", eyewear = "Goggles",
		equipment = { "ChestPlate", "ShoulderYoke", "Webbing", "SlungRifle" },
	},
	{
		hairStyle = "CrewCut", hairColor = HAIR.ash, faceStyle = "Neutral",
		bodyStyle = "Average", outfitStyle = "Security",
		skin = SKIN.warm, coat = CLOTH.slate, pants = CLOTH.dark, trim = CLOTH.metal,
		scale = 1, headwear = "Helmet", equipment = { "Webbing", "NeckGuard", "Rifle" },
	},
}

function Appearance.soldier(index: number): Profile
	return SOLDIERS[(index - 1) % #SOLDIERS + 1]
end

--------------------------------------------------------------------------------
-- EXCAVATION CREW
--
-- Not recoloured scientists: hard hats rather than parka hoods, a hi-vis
-- vest, a heavy tool belt, gloves and knee pads. Worker 1 keeps a scanner
-- because two shots (07c_SampleCollection, 07d_CompassAnomaly) frame it by
-- name and one of them recolours it every frame.
--------------------------------------------------------------------------------

local WORKERS: { Profile } = {
	{
		hairStyle = "CrewCut", hairColor = HAIR.brown, faceStyle = "Neutral",
		bodyStyle = "Average", outfitStyle = "FieldWorker",
		skin = SKIN.tan, coat = CLOTH.canvas, pants = CLOTH.dark, trim = CLOTH.hiVis,
		scale = 1, headwear = "HardHat", eyewear = "Goggles",
		equipment = { "Vest", "ToolBelt", "KneePads", "Scanner" },
	},
	{
		hairStyle = "MessyCrop", hairColor = HAIR.black, faceStyle = "Mature",
		bodyStyle = "Broad", outfitStyle = "FieldWorker",
		skin = SKIN.deep, coat = CLOTH.canvas, pants = CLOTH.dark, trim = CLOTH.hiVis,
		scale = 1.06, headwear = "HardHat",
		equipment = { "Vest", "ToolBelt", "KneePads", "ToolCase" },
	},
	{
		hairStyle = "Bald", hairColor = HAIR.black, faceStyle = "Neutral",
		bodyStyle = "Compact", outfitStyle = "FieldWorker",
		skin = SKIN.olive, coat = CLOTH.slate, pants = CLOTH.dark, trim = CLOTH.hiVis,
		scale = 0.95, headwear = "Hood",
		equipment = { "Vest", "ToolBelt", "CableCoil" },
	},
	{
		hairStyle = "CrewCut", hairColor = HAIR.sandy, faceStyle = "Sharp",
		bodyStyle = "Average", outfitStyle = "FieldWorker",
		skin = SKIN.fair, coat = CLOTH.canvas, pants = CLOTH.dark, trim = CLOTH.hiVis,
		scale = 0.99, headwear = "HardHat", eyewear = "GogglesUp",
		equipment = { "Vest", "ToolBelt", "HelmetLamp", "Radio" },
	},
	{
		hairStyle = "ShortWolf", hairColor = HAIR.auburn, faceStyle = "Neutral",
		bodyStyle = "Light", outfitStyle = "FieldWorker",
		skin = SKIN.brown, coat = CLOTH.slate, pants = CLOTH.dark, trim = CLOTH.hiVis,
		scale = 0.96, headwear = "HardHat",
		equipment = { "Vest", "ToolBelt", "ToolCase" },
	},
}

function Appearance.worker(index: number): Profile
	return WORKERS[(index - 1) % #WORKERS + 1]
end

Appearance.ScientistCount = #SCIENTISTS
Appearance.SoldierCount = #SOLDIERS
Appearance.WorkerCount = #WORKERS

return Appearance
