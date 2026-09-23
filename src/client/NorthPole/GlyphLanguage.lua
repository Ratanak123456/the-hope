--!strict
--[[
	THE ANCIENT SCRIPT.

	One fictional writing system, defined once, rendered onto every ancient
	surface in the opening: the seal key, its pedestal, the inner gate, the
	Aegis Zero chest band, the containment floor, the warning band in the
	chamber and the lower seal machinery. The repetition is the whole point -
	a viewer who sees the same four marks on the key, on the door it opens and
	on the machine behind it learns, without a line of dialogue, that the three
	things belong to one system. Randomly generated decoration can never do
	that, so nothing here is random: a glyph is the same shape every time.

	DESIGN RULES (the thing that makes twenty strokes read as one hand):

	  1. Straight strokes only. Every mark is a line segment in a normalised
	     [-1, 1] box, so it can be drawn as a thin part on a wall, as a beam,
	     or on a screen, and still be the same glyph.
	  2. Every glyph has a SPINE - one stroke running most of the height.
	  3. The BINDING BAR, a horizontal stroke at y = -0.62 running the full
	     width, appears on every glyph in the containment family (Gate,
	     Guardian, Bind, Below, Warning) and on no other. That single shared
	     feature is what makes the warning band read as a sentence about one
	     subject rather than as five unrelated ornaments.
	  4. The OPEN CROWN - two strokes meeting at a high apex and never closed
	     by a third - appears in the transition family (Key, Life, Release,
	     Return). Containment closes; transition opens.
	  5. Nothing is mirror-symmetric about its own spine. The archaic
	     letterforms this borrows its feel from (digamma, koppa, sampi) are
	     all lopsided, and a symmetric mark reads as a decorative rosette
	     rather than as writing.

	These are letterforms, not sentences: no arrangement here transliterates
	any real language, and the names are what the glyph MEANS to the
	expedition's partial translation, not a pronunciation.
]]

local GlyphLanguage = {}

export type Stroke = {
	x1: number,
	y1: number,
	x2: number,
	y2: number,
}

export type GlyphDefinition = {
	strokes: { Stroke },
}

export type GlyphName =
	"Gate"
	| "Guardian"
	| "Bind"
	| "Key"
	| "Below"
	| "Warning"
	| "Life"
	| "Release"
	| "Power"
	| "Return"

-- Rendered glyph. `setLit(0..1)` takes it from a dead engraving to a fully
-- illuminated channel without creating or destroying anything, so a gate can
-- light one mark at a time across a shot without allocating mid-frame.
export type GlyphHandle = {
	model: Model,
	strokes: { BasePart },
	setLit: (number) -> (),
	destroy: () -> (),
}

local BAR = -0.62 -- the binding bar's height, shared by the containment family

GlyphLanguage.Glyphs = {
	--[[
		CONTAINMENT FAMILY - all five carry the binding bar at y = BAR.
	]]

	-- A closed threshold: two uprights and a lintel, with the bar drawn
	-- across the opening. The right upright is taller and kicks outward, so
	-- the mark leans.
	Gate = {
		strokes = {
			{ x1 = -0.62, y1 = BAR, x2 = -0.62, y2 = 0.78 },
			{ x1 = 0.58, y1 = BAR, x2 = 0.72, y2 = 0.96 },
			{ x1 = -0.62, y1 = 0.78, x2 = 0.72, y2 = 0.96 },
			{ x1 = -0.86, y1 = BAR, x2 = 0.82, y2 = BAR },
		},
	},

	-- A figure holding. Full spine, two braces out to two posts that stand on
	-- the bar. The right brace is shorter and higher than the left: this is
	-- the damaged shoulder, and it is the detail that lets the same mark read
	-- as a portrait of the machine in the chamber.
	Guardian = {
		strokes = {
			{ x1 = -0.06, y1 = 0.98, x2 = -0.06, y2 = BAR },
			{ x1 = -0.06, y1 = 0.52, x2 = -0.74, y2 = -0.10 },
			{ x1 = -0.06, y1 = 0.52, x2 = 0.66, y2 = 0.04 },
			{ x1 = -0.74, y1 = -0.10, x2 = -0.74, y2 = BAR },
			{ x1 = 0.66, y1 = 0.04, x2 = 0.66, y2 = BAR },
			{ x1 = -0.92, y1 = BAR, x2 = 0.86, y2 = BAR },
		},
	},

	-- Two bars held apart by a diagonal tie. The tie is the glyph: remove it
	-- and this becomes Release.
	Bind = {
		strokes = {
			{ x1 = 0.02, y1 = 0.92, x2 = 0.02, y2 = BAR },
			{ x1 = -0.68, y1 = 0.46, x2 = 0.66, y2 = 0.46 },
			{ x1 = -0.68, y1 = -0.10, x2 = 0.66, y2 = -0.10 },
			{ x1 = -0.68, y1 = 0.46, x2 = 0.66, y2 = -0.10 },
			{ x1 = -0.82, y1 = BAR, x2 = 0.78, y2 = BAR },
		},
	},

	-- Descending chevrons under a head bar, each narrower than the last and
	-- each apex pushed left of the one above, so the mark drills downward
	-- rather than sitting still.
	Below = {
		strokes = {
			{ x1 = -0.86, y1 = 0.74, x2 = 0.80, y2 = 0.74 },
			{ x1 = -0.66, y1 = 0.74, x2 = -0.04, y2 = 0.20 },
			{ x1 = -0.04, y1 = 0.20, x2 = 0.72, y2 = 0.74 },
			{ x1 = -0.46, y1 = 0.20, x2 = -0.14, y2 = -0.24 },
			{ x1 = -0.14, y1 = -0.24, x2 = 0.44, y2 = 0.22 },
			{ x1 = -0.88, y1 = BAR, x2 = 0.76, y2 = BAR },
		},
	},

	-- A broken spine. Two collinear segments with a gap between them, flanked
	-- by two struts from the apex - the right one longer, so the mark tips.
	-- The gap is the warning: this spine does not hold.
	Warning = {
		strokes = {
			{ x1 = 0.00, y1 = 0.98, x2 = 0.00, y2 = 0.34 },
			{ x1 = 0.00, y1 = 0.10, x2 = 0.00, y2 = -0.34 },
			{ x1 = -0.70, y1 = 0.62, x2 = 0.00, y2 = 0.98 },
			{ x1 = 0.00, y1 = 0.98, x2 = 0.78, y2 = 0.54 },
			{ x1 = -0.84, y1 = BAR, x2 = 0.80, y2 = BAR },
		},
	},

	--[[
		TRANSITION FAMILY - open crown, no binding bar. These are the marks
		that describe something changing state.
	]]

	-- An open ring on a spine, with the gap deliberately left on the right:
	-- the shape of a thing that fits INTO something else. This is the one
	-- glyph the audience sees as a physical object before they see it written
	-- (the seal key is built to this outline).
	Key = {
		strokes = {
			{ x1 = -0.10, y1 = 0.96, x2 = 0.52, y2 = 0.52 },
			{ x1 = -0.10, y1 = 0.96, x2 = -0.66, y2 = 0.44 },
			{ x1 = -0.66, y1 = 0.44, x2 = -0.62, y2 = -0.26 },
			{ x1 = -0.62, y1 = -0.26, x2 = -0.02, y2 = -0.70 },
			{ x1 = -0.02, y1 = -0.70, x2 = 0.56, y2 = -0.34 },
			{ x1 = -0.10, y1 = 0.96, x2 = -0.10, y2 = -0.16 },
		},
	},

	-- Open crown over a stem, with a tilted crossbar and a short foot that
	-- deliberately stops well short of full width, so it can never be mistaken
	-- for a binding bar.
	Life = {
		strokes = {
			{ x1 = -0.56, y1 = 0.36, x2 = 0.06, y2 = 0.96 },
			{ x1 = 0.06, y1 = 0.96, x2 = 0.72, y2 = 0.42 },
			{ x1 = 0.06, y1 = 0.96, x2 = 0.06, y2 = -0.52 },
			{ x1 = -0.48, y1 = 0.30, x2 = 0.64, y2 = 0.14 },
			{ x1 = -0.28, y1 = -0.52, x2 = 0.42, y2 = -0.52 },
		},
	},

	-- Bind with the tie snapped: the two bars have sprung apart and only two
	-- stubs of the tie remain, one on each bar, pointing at where the other
	-- half used to be.
	Release = {
		strokes = {
			{ x1 = 0.02, y1 = 0.92, x2 = 0.02, y2 = -0.52 },
			{ x1 = -0.70, y1 = 0.62, x2 = 0.64, y2 = 0.30 },
			{ x1 = -0.70, y1 = -0.34, x2 = 0.64, y2 = 0.02 },
			{ x1 = -0.70, y1 = 0.62, x2 = -0.50, y2 = 0.30 },
			{ x1 = 0.44, y1 = 0.02, x2 = 0.64, y2 = -0.24 },
		},
	},

	-- A current running inside a frame that is open on two sides. The zigzag
	-- crosses the frame's own axis twice, which is what stops it reading as a
	-- lightning bolt clipart.
	Power = {
		strokes = {
			{ x1 = -0.72, y1 = 0.92, x2 = -0.72, y2 = -0.56 },
			{ x1 = -0.72, y1 = 0.92, x2 = 0.46, y2 = 0.92 },
			{ x1 = -0.40, y1 = 0.62, x2 = 0.30, y2 = 0.24 },
			{ x1 = 0.30, y1 = 0.24, x2 = -0.26, y2 = -0.04 },
			{ x1 = -0.26, y1 = -0.04, x2 = 0.44, y2 = -0.44 },
		},
	},

	-- Out, down, back - and a return stub that stops short of the spine it
	-- came from. The circuit does not close, which is the difference between
	-- "return" and "repeat".
	Return = {
		strokes = {
			{ x1 = -0.06, y1 = 0.94, x2 = -0.06, y2 = -0.18 },
			{ x1 = -0.06, y1 = 0.94, x2 = 0.74, y2 = 0.94 },
			{ x1 = 0.74, y1 = 0.94, x2 = 0.74, y2 = -0.52 },
			{ x1 = 0.74, y1 = -0.52, x2 = -0.44, y2 = -0.52 },
			{ x1 = -0.44, y1 = -0.52, x2 = -0.44, y2 = -0.02 },
		},
	},
} :: { [string]: GlyphDefinition }

-- The two standing arrangements the set actually uses. Naming them here rather
-- than spelling the lists out at each call site is what keeps the gate, the
-- key, the pedestal and the Aegis chest carrying the SAME marks - which is the
-- entire mechanism by which the audience is told they are one system.
GlyphLanguage.Phrases = {
	-- Stamped on the key, its cradle, the gate's lock channel and Aegis
	-- Zero's chest band. Four marks, always in this order.
	SealAuthority = { "Key", "Gate", "Guardian", "Bind" } :: { GlyphName },
	-- The band around the chamber. Lyra reads three of these five.
	ChamberWarning = { "Guardian", "Bind", "Below", "Warning", "Release" } :: { GlyphName },
}

-- Bronze when dead, hot amber when lit. Ancient machinery only ever uses this
-- pair; violet belongs to the thing under the floor and cyan to the humans
-- (see Instrumentation.lua), and the three are never mixed.
GlyphLanguage.Dead = Color3.fromRGB(118, 92, 52)
GlyphLanguage.Lit = Color3.fromRGB(240, 172, 78)

local function strokePart(name: string, thickness: number, length: number, depth: number, cf: CFrame, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	-- Engraved line work is thin trim, not architecture: a glyph stroke must
	-- never be what an obstruction ray decides a shot is blocked by, the same
	-- rule Env's route markers and mud flaps already follow.
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.Slate
	part.Color = color
	part.Size = Vector3.new(thickness, length, depth)
	part.CFrame = cf
	return part
end

export type RenderOptions = {
	thickness: number?, -- stroke width as a fraction of `scale`; default 0.12
	depth: number?, -- how far the stroke stands off the surface, in studs
	dead: Color3?,
	lit: Color3?,
	name: string?,
	--[[
		Whether `setLit` is POWER or merely VISIBILITY. Default true: the mark
		goes Neon, which is what a live mechanism does.

		False keeps the material as Slate and only lerps the colour, for the
		bands that are being cleaned rather than energised - frost brushed out
		of an engraved channel so the bronze underneath catches a hand lamp.
		Those must never glow: a warning carved on a wall that lights up by
		itself tells the audience the building is awake, which is a completely
		different film from the one where a dead facility stays dead until
		somebody puts a key in it.
	]]
	emissive: boolean?,
}

--[[
	Draws one glyph on the XY plane of `center`, with `center`'s local +Z as
	the surface normal (so pass the face's own CFrame and the mark sits on it).
	`scale` is the half-height in studs: a glyph drawn at scale 1 occupies
	roughly two studs square.
]]
function GlyphLanguage.render(
	parent: Instance,
	glyph: GlyphName,
	center: CFrame,
	scale: number,
	color: Color3?,
	options: RenderOptions?
): GlyphHandle
	local definition = GlyphLanguage.Glyphs[glyph]
	if not definition then
		error(`GlyphLanguage: no glyph named "{glyph}"`)
	end
	local opts: RenderOptions = options or {}
	local dead = opts.dead or color or GlyphLanguage.Dead
	local lit = opts.lit or GlyphLanguage.Lit
	local emissive = opts.emissive ~= false
	local thickness = (opts.thickness or 0.12) * scale
	local depth = opts.depth or math.max(0.06, scale * 0.09)

	local model = Instance.new("Model")
	model.Name = opts.name or (`Glyph_{glyph}`)
	model.Parent = parent

	local strokes: { BasePart } = {}
	for index, stroke in definition.strokes do
		local dx = (stroke.x2 - stroke.x1) * scale
		local dy = (stroke.y2 - stroke.y1) * scale
		local length = math.sqrt(dx * dx + dy * dy)
		if length > 1e-4 then
			local mx = (stroke.x1 + stroke.x2) * 0.5 * scale
			local my = (stroke.y1 + stroke.y2) * 0.5 * scale
			-- A part's length runs along its own local Y. Rotating by theta
			-- about local Z sends that axis to (-sin, cos), so theta =
			-- atan2(-dx, dy) points it along the stroke.
			local theta = math.atan2(-dx, dy)
			-- Overrun by one stroke width so consecutive strokes meet at a
			-- solid corner instead of leaving a pinhole at every junction.
			local part = strokePart(
				`Stroke{index}`,
				thickness,
				length + thickness,
				depth,
				center * CFrame.new(mx, my, depth * 0.5) * CFrame.Angles(0, 0, theta),
				dead
			)
			part.Parent = model
			table.insert(strokes, part)
		end
	end

	local handle: GlyphHandle
	handle = {
		model = model,
		strokes = strokes,
		setLit = function(amount: number)
			local a = math.clamp(amount, 0, 1)
			-- One material switch and one colour lerp per stroke, and no
			-- lights at all: a gate carries dozens of these, and a PointLight
			-- per mark would blow the whole scene's light budget on
			-- decoration (see Kit.resetLightBudget).
			local material = if emissive and a > 0.02 then Enum.Material.Neon else Enum.Material.Slate
			local tint = dead:Lerp(lit, a)
			for _, part in strokes do
				part.Material = material
				part.Color = tint
			end
		end,
		destroy = function()
			model:Destroy()
		end,
	}
	handle.setLit(0)
	return handle
end

export type BandHandle = {
	model: Model,
	glyphs: { GlyphHandle },
	setLit: (number) -> (),
	-- Lights the band one mark at a time, left to right: pass 0..#glyphs.
	-- 1.4 means "the first is fully lit, the second is four-tenths of the way
	-- there". This is how energy is shown travelling THROUGH a mechanism
	-- rather than the whole thing switching on at once.
	setProgress: (number) -> (),
	destroy: () -> (),
}

--[[
	A row of glyphs along `start`'s local +X. Used for the wall bands, the
	gate's lock channel, the key's flank and Aegis Zero's chest.
]]
function GlyphLanguage.band(
	parent: Instance,
	glyphs: { GlyphName },
	start: CFrame,
	scale: number,
	spacing: number?,
	color: Color3?,
	options: RenderOptions?
): BandHandle
	local step = spacing or scale * 2.8
	local model = Instance.new("Model")
	model.Name = (options and options.name) or "GlyphBand"
	model.Parent = parent

	local rendered: { GlyphHandle } = {}
	local count = #glyphs
	for index, glyph in glyphs do
		local offset = (index - (count + 1) * 0.5) * step
		table.insert(rendered, GlyphLanguage.render(model, glyph :: GlyphName, start * CFrame.new(offset, 0, 0), scale, color, options))
	end

	local handle: BandHandle
	handle = {
		model = model,
		glyphs = rendered,
		setLit = function(amount: number)
			for _, glyph in rendered do
				glyph.setLit(amount)
			end
		end,
		setProgress = function(progress: number)
			for index, glyph in rendered do
				glyph.setLit(math.clamp(progress - (index - 1), 0, 1))
			end
		end,
		destroy = function()
			model:Destroy()
		end,
	}
	handle.setLit(0)
	return handle
end

--[[
	The same glyphs arranged around a circle on `center`'s XY plane, each
	rotated to stand upright on the ring. Used for the gate's lock face and
	the containment floor, where a row would read as signage and a ring reads
	as a mechanism.
]]
function GlyphLanguage.ring(
	parent: Instance,
	glyphs: { GlyphName },
	center: CFrame,
	radius: number,
	scale: number,
	color: Color3?,
	options: RenderOptions?
): BandHandle
	local model = Instance.new("Model")
	model.Name = (options and options.name) or "GlyphRing"
	model.Parent = parent

	local rendered: { GlyphHandle } = {}
	local count = #glyphs
	for index, glyph in glyphs do
		local angle = (index - 1) / count * math.pi * 2
		local placement = center
			* CFrame.new(math.sin(angle) * radius, math.cos(angle) * radius, 0)
			* CFrame.Angles(0, 0, -angle)
		table.insert(rendered, GlyphLanguage.render(model, glyph :: GlyphName, placement, scale, color, options))
	end

	local handle: BandHandle
	handle = {
		model = model,
		glyphs = rendered,
		setLit = function(amount: number)
			for _, glyph in rendered do
				glyph.setLit(amount)
			end
		end,
		setProgress = function(progress: number)
			for index, glyph in rendered do
				glyph.setLit(math.clamp(progress - (index - 1), 0, 1))
			end
		end,
		destroy = function()
			model:Destroy()
		end,
	}
	handle.setLit(0)
	return handle
end

return GlyphLanguage
