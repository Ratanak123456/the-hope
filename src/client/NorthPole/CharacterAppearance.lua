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
	-- Rises above the crown line; hidden under a hat or helmet so it cannot
	-- punch through the shell.
	tall: boolean?,
	-- Overrides the style colour (a band, a clip).
	color: Color3?,
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
	eyeY: number,
	mouthY: number,
}

-- Width multipliers ONLY. Nothing here touches a joint HEIGHT or a limb
-- LENGTH: sole drop and the walk cycle depend on those. Cast derives the
-- shoulder and hip spacing from the torso width, so a broad build's arms sit
-- flush against its wider torso rather than inside it.
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
	-- A lab coat has to read as a lab coat at a glance, so it is the palest
	-- garment in the film - and still inside the albedo budget castcheck
	-- enforces.
	labcoat = rgb(166, 170, 166),
}

Appearance.Hair = HAIR
Appearance.Skin = SKIN
Appearance.Cloth = CLOTH

--------------------------------------------------------------------------------
-- HAIR
--
-- ROBLOX HAIR: a few big masses sitting ON a block head, not strands. Every
-- style is two to six pieces and every piece is chunky - the smallest is a
-- tenth of a stud thick, most are a third of a stud or more - because thin
-- technical pieces on a head are what made the old cast read as a row of
-- small mannequins rather than avatars.
--
-- Head-local space for the 1.3 x 1.25 x 1.25 block head (Cast.HeadSize): the
-- head spans x +-0.65, y +-0.625, z +-0.625, the rig faces -Z so the face
-- plane is z = -0.625, and the brows sit at y ~0.23-0.33. Every fringe bottoms out at
-- y >= 0.36 so it never crosses its own eyebrows.
--
-- Hair is deliberately WIDER than the skull (side masses at |x| 0.66-0.72):
-- hair that stops at the skull line reads as a swim cap.
--------------------------------------------------------------------------------

local HAIR_STYLES: { [string]: { HairPiece } } = {
	-- Lyra. A short, chunky layered bob with wolf-cut edges: a full crown, a
	-- heavy asymmetric fringe, side masses down to the jaw (the left longer
	-- than the right), and a short choppy nape. Clearly short hair, and the
	-- widest head outline of the three leads from any angle.
	LayeredBob = {
		{ name = "HairCrown", size = V(1.42, 0.42, 1.40), at = CF(0, 0.62, 0.04) },
		-- The side masses FLARE: a second, wider block at jaw height gives the
		-- bob its bell outline, which is what separates her head from Voss's
		-- neat block in flat silhouette.
		{ name = "HairSideLeft", size = V(0.28, 0.9, 1.1), at = CF(-0.71, 0.18, 0.08) },
		{ name = "HairSideRight", size = V(0.26, 0.72, 1.06), at = CF(0.7, 0.27, 0.1) },
		{ name = "HairFlareLeft", size = V(0.46, 0.42, 1.04), at = CF(-0.86, -0.2, 0.12) * A(0, 0, math.rad(-10)) },
		{ name = "HairFlareRight", size = V(0.4, 0.36, 0.98), at = CF(0.84, -0.04, 0.14) * A(0, 0, math.rad(10)) },
		{ name = "HairBack", size = V(1.38, 0.84, 0.28), at = CF(0, 0.16, 0.68) },
		{ name = "HairFringe", size = V(0.9, 0.3, 0.26), at = CF(-0.2, 0.52, -0.66) * A(0, 0, math.rad(-11)) },
		{ name = "HairTuft", size = V(0.5, 0.26, 0.5), at = CF(0.22, 0.84, 0.12) * A(0, math.rad(20), math.rad(-14)), tall = true },
	},
	-- Choppier than the bob, with a longer nape and a spiky top. A modern
	-- short cut on anyone - assigned to male- and female-presenting people.
	ShortWolf = {
		{ name = "HairCrown", size = V(1.38, 0.4, 1.36), at = CF(0, 0.6, 0.04) },
		{ name = "HairSideLeft", size = V(0.22, 0.66, 0.92), at = CF(-0.68, 0.26, 0.1) },
		{ name = "HairSideRight", size = V(0.22, 0.6, 0.9), at = CF(0.68, 0.29, 0.1) },
		{ name = "HairNape", size = V(0.96, 0.6, 0.28), at = CF(0, -0.02, 0.68) },
		{ name = "HairFringe", size = V(0.84, 0.26, 0.24), at = CF(0.12, 0.5, -0.65) * A(0, 0, math.rad(7)) },
		{ name = "HairSpike", size = V(0.56, 0.3, 0.56), at = CF(-0.14, 0.86, 0.08) * A(0, math.rad(35), math.rad(12)), tall = true },
	},
	-- Voss. Controlled and combed: one heavy sweep over a low part, tight
	-- squared temples. Reads as "kept", not just "short".
	SidePart = {
		{ name = "HairCrown", size = V(1.36, 0.34, 1.34), at = CF(0, 0.64, 0.03) },
		{ name = "HairSweep", size = V(0.96, 0.36, 0.56), at = CF(-0.18, 0.74, -0.4) * A(0, 0, math.rad(-12)), tall = true },
		{ name = "HairPartSide", size = V(0.38, 0.26, 0.56), at = CF(0.46, 0.62, -0.3) },
		{ name = "HairBack", size = V(1.3, 0.46, 0.24), at = CF(0, 0.34, 0.66) },
		{ name = "HairTempleLeft", size = V(0.12, 0.42, 0.96), at = CF(-0.66, 0.36, 0.08) },
		{ name = "HairTempleRight", size = V(0.12, 0.42, 0.96), at = CF(0.66, 0.36, 0.08) },
	},
	-- Hale. A hard, square military cut: a flat top, a squared front edge and
	-- hair held tight and LOW on the sides. Compact, and the smallest head
	-- volume of the three leads by design.
	CrewCut = {
		{ name = "HairCrown", size = V(1.34, 0.26, 1.34), at = CF(0, 0.68, 0.02) },
		{ name = "HairFront", size = V(1.16, 0.24, 0.32), at = CF(0, 0.72, -0.5) },
		{ name = "HairSideLeft", size = V(0.1, 0.44, 1.04), at = CF(-0.66, 0.3, 0.06) },
		{ name = "HairSideRight", size = V(0.1, 0.44, 1.04), at = CF(0.66, 0.3, 0.06) },
		{ name = "HairNape", size = V(1.18, 0.32, 0.12), at = CF(0, 0.24, 0.66) },
	},
	-- Tall on top, shaved at the temples, with a forward quiff. The strongest
	-- vertical of the set - the one background silhouette unmistakable in a
	-- crowd.
	Undercut = {
		{ name = "HairTop", size = V(1.12, 0.52, 1.2), at = CF(0, 0.8, 0.06), tall = true },
		{ name = "HairQuiff", size = V(0.94, 0.36, 0.44), at = CF(0, 0.98, -0.38) * A(math.rad(18), 0, 0), tall = true },
		{ name = "HairShaveLeft", size = V(0.08, 0.38, 1.04), at = CF(-0.65, 0.34, 0.06) },
		{ name = "HairShaveRight", size = V(0.08, 0.38, 1.04), at = CF(0.65, 0.34, 0.06) },
		{ name = "HairBack", size = V(1.02, 0.3, 0.2), at = CF(0, 0.48, 0.66) },
	},
	-- Deliberately off-axis: two big tufts rotated against each other, so the
	-- outline is lopsided from every angle.
	MessyCrop = {
		{ name = "HairCrown", size = V(1.38, 0.38, 1.34), at = CF(0, 0.62, 0.03) },
		{ name = "HairTuftLeft", size = V(0.6, 0.32, 0.54), at = CF(-0.3, 0.86, -0.14) * A(0, 0, math.rad(11)), tall = true },
		{ name = "HairTuftRight", size = V(0.54, 0.3, 0.5), at = CF(0.32, 0.84, 0.2) * A(0, 0, math.rad(-15)), tall = true },
		{ name = "HairFringe", size = V(0.88, 0.26, 0.24), at = CF(0.06, 0.52, -0.65) * A(0, 0, math.rad(6)) },
		{ name = "HairBack", size = V(1.2, 0.5, 0.26), at = CF(0, 0.34, 0.66) },
	},
	-- Five big rounded puffs, not fifty little ones: a flat base carries the
	-- hairline and four controlled curls carry the volume.
	CurlyTop = {
		{ name = "HairBase", size = V(1.4, 0.42, 1.4), at = CF(0, 0.6, 0.04) },
		{ name = "HairCurlLeft", size = V(0.74, 0.66, 0.74), at = CF(-0.36, 0.84, -0.08), kind = "ball", tall = true },
		{ name = "HairCurlRight", size = V(0.7, 0.64, 0.7), at = CF(0.38, 0.86, 0.08), kind = "ball", tall = true },
		{ name = "HairCurlBack", size = V(0.68, 0.6, 0.68), at = CF(0, 0.86, 0.4), kind = "ball", tall = true },
		{ name = "HairCurlFront", size = V(0.62, 0.54, 0.62), at = CF(0, 0.8, -0.4), kind = "ball", tall = true },
	},
	-- Smooth over the crown, gathered at the nape into a short thick tail.
	-- Medium length worn UP: a different outline to the bob without being
	-- "the long-haired one".
	TiedBack = {
		{ name = "HairCrown", size = V(1.4, 0.4, 1.38), at = CF(0, 0.62, 0.04) },
		{ name = "HairSideLeft", size = V(0.18, 0.52, 1.02), at = CF(-0.68, 0.36, 0.1) },
		{ name = "HairSideRight", size = V(0.18, 0.52, 1.02), at = CF(0.68, 0.36, 0.1) },
		{ name = "HairBand", size = V(0.44, 0.3, 0.34), at = CF(0, 0.22, 0.72), color = Color3.fromRGB(132, 66, 62) },
		{ name = "HairTail", size = V(0.42, 0.84, 0.36), at = CF(0, -0.22, 0.8) * A(math.rad(-8), 0, 0) },
	},
	Bald = {},
}

--------------------------------------------------------------------------------
-- HEADWEAR, worn OVER hair rather than instead of it. Big, rounded-off shells
-- that change the head outline completely - on a worker or a guard the
-- headwear IS the silhouette, and the hair only shows at the sides and nape.
--------------------------------------------------------------------------------

local HEADWEAR: { [string]: { HairPiece } } = {
	Helmet = {
		{ name = "HelmetShell", size = V(1.54, 0.74, 1.52), at = CF(0, 0.56, 0.03) },
		{ name = "HelmetBrim", size = V(1.56, 0.14, 0.4), at = CF(0, 0.3, -0.58) },
		{ name = "HelmetNape", size = V(1.46, 0.4, 0.26), at = CF(0, 0.12, 0.68) },
		{ name = "HelmetRail", size = V(0.16, 0.3, 1.2), at = CF(0.78, 0.5, 0.04) },
		{ name = "HelmetMount", size = V(0.4, 0.26, 0.2), at = CF(0, 0.66, -0.78) },
	},
	HardHat = {
		{ name = "HardHatShell", size = V(1.5, 0.62, 1.48), at = CF(0, 0.6, 0.03) },
		{ name = "HardHatCrest", size = V(0.28, 0.24, 1.42), at = CF(0, 0.94, 0.03) },
		{ name = "HardHatBrim", size = V(1.6, 0.12, 0.52), at = CF(0, 0.38, -0.62) },
		{ name = "HardHatBrimBack", size = V(1.56, 0.1, 0.22), at = CF(0, 0.36, 0.78) },
	},
	Hood = {
		{ name = "HoodShell", size = V(1.6, 0.84, 1.52), at = CF(0, 0.52, 0.1) },
		{ name = "HoodRim", size = V(1.56, 0.3, 0.28), at = CF(0, 0.62, -0.62), color = Color3.fromRGB(150, 136, 116) },
		{ name = "HoodDrapeLeft", size = V(0.26, 0.78, 0.86), at = CF(-0.74, 0.1, 0.14) },
		{ name = "HoodDrapeRight", size = V(0.26, 0.78, 0.86), at = CF(0.74, 0.1, 0.14) },
	},
}

--------------------------------------------------------------------------------
-- FACES
--
-- The default-avatar language: solid dark eyes with one glint, a bar for each
-- brow, a bar for a mouth. Faces are told apart by eye SIZE and spacing, brow
-- weight and angle, and mouth width - never by sculpted anatomy.
--------------------------------------------------------------------------------

local FACES: { [string]: FaceMetrics } = {
	Neutral = {
		eyeWidth = 0.2, eyeHeight = 0.24, eyeSpacing = 0.24, eyeY = 0.04,
		browWidth = 0.28, browThickness = 0.07, browHeight = 0.29, browTilt = 0,
		mouthWidth = 0.3, mouthY = -0.26,
	},
	-- Lyra: the biggest, roundest eyes and a light brow.
	Soft = {
		eyeWidth = 0.22, eyeHeight = 0.28, eyeSpacing = 0.235, eyeY = 0.04,
		browWidth = 0.26, browThickness = 0.06, browHeight = 0.32, browTilt = 0.06,
		mouthWidth = 0.26, mouthY = -0.25,
	},
	-- Voss: narrow, wide-set, level eyes and a sharp angled brow.
	Sharp = {
		eyeWidth = 0.24, eyeHeight = 0.15, eyeSpacing = 0.26, eyeY = 0.05,
		browWidth = 0.32, browThickness = 0.065, browHeight = 0.26, browTilt = -0.08,
		mouthWidth = 0.24, mouthY = -0.26,
	},
	-- Hale: small eyes under a heavy, low, straight brow, and a wide mouth.
	Mature = {
		eyeWidth = 0.19, eyeHeight = 0.14, eyeSpacing = 0.27, eyeY = 0.03,
		browWidth = 0.36, browThickness = 0.1, browHeight = 0.23, browTilt = -0.03,
		mouthWidth = 0.36, mouthY = -0.27,
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
		equipment = { "ShoulderYoke", "RankMarker", "HeavyBelt", "Headset", "SlungRifle" },
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
		skin = SKIN.fair, coat = CLOTH.labcoat, pants = CLOTH.dark, trim = CLOTH.orange,
		scale = 0.96, eyewear = "GogglesUp", equipment = { "Clipboard" },
	},
	{
		hairStyle = "SidePart", hairColor = HAIR.black, faceStyle = "Sharp",
		bodyStyle = "Average", outfitStyle = "Analyst",
		skin = SKIN.brown, coat = CLOTH.ice, pants = CLOTH.dark, trim = CLOTH.ivory,
		scale = 1.02, eyewear = "Glasses", equipment = { "Tablet" },
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
		skin = SKIN.tan, coat = CLOTH.labcoat, pants = CLOTH.dark, trim = CLOTH.ivory,
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
		scale = 1.01, eyewear = "Goggles", equipment = { "Radio" },
	},
	{
		hairStyle = "CrewCut", hairColor = HAIR.lightBrown, faceStyle = "Neutral",
		bodyStyle = "Broad", outfitStyle = "Researcher",
		skin = SKIN.warm, coat = CLOTH.labcoat, pants = CLOTH.dark, trim = CLOTH.orange,
		scale = 1.05, eyewear = "GogglesUp", equipment = { "SmallPack" },
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
		equipment = { "Vest", "ToolBelt", "CableCoil", "WorkPack" },
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
		equipment = { "Vest", "ToolBelt", "WorkPack", "ToolCase" },
	},
}

function Appearance.worker(index: number): Profile
	return WORKERS[(index - 1) % #WORKERS + 1]
end

Appearance.ScientistCount = #SCIENTISTS
Appearance.SoldierCount = #SOLDIERS
Appearance.WorkerCount = #WORKERS

return Appearance
