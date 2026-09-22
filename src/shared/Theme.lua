--!strict
-- Visual language for THE DAY THE SKY BROKE.
-- Dark navy surfaces, teal for Ancient/Architect tech, amber for objectives,
-- muted purple/red for the Veyra Dominion. Every colour and metric used by
-- the UI lives here so the whole interface can be retuned from one file.

local Theme = {}

Theme.Color = {
	-- Surfaces (dark navy / charcoal). Hex values are the menu redesign's
	-- reference palette - they landed extremely close to what was already
	-- here, so this is a small refinement, not a repaint.
	Void = Color3.fromRGB(0x0B, 0x12, 0x20), -- #0B1220
	Surface = Color3.fromRGB(0x13, 0x1E, 0x2D), -- #131E2D
	SurfaceRaised = Color3.fromRGB(28, 48, 64),
	SurfaceHover = Color3.fromRGB(35, 59, 76),
	Line = Color3.fromRGB(53, 80, 98),
	LineSoft = Color3.fromRGB(38, 57, 72),

	-- Typography
	Text = Color3.fromRGB(0xF2, 0xF5, 0xF7), -- #F2F5F7
	TextMuted = Color3.fromRGB(0xA7, 0xB6, 0xC6), -- #A7B6C6
	TextFaint = Color3.fromRGB(90, 108, 126),

	-- Ancient technology / resonance
	Teal = Color3.fromRGB(0x46, 0xCE, 0xD3), -- #46CED3
	TealDeep = Color3.fromRGB(22, 96, 104),
	TealGlow = Color3.fromRGB(120, 235, 232),

	-- Objectives and important actions (used sparingly)
	Amber = Color3.fromRGB(0xF5, 0xAD, 0x46), -- #F5AD46
	AmberDeep = Color3.fromRGB(116, 78, 26),

	-- Alien danger
	Alien = Color3.fromRGB(188, 121, 232),
	Danger = Color3.fromRGB(239, 113, 128),
	DangerDeep = Color3.fromRGB(96, 30, 40),

	-- Status
	Good = Color3.fromRGB(96, 194, 148),
}

Theme.Font = {
	Display = Enum.Font.GothamBold,
	Heading = Enum.Font.GothamBold,
	Body = Enum.Font.Gotham,
	Label = Enum.Font.GothamMedium,
	Mono = Enum.Font.Code,
}

-- Discrete type scale. Compact screens step down a named size rather than
-- multiplying every label by a blanket factor, so small text stays legible.
local TEXT: {[string]: {number}} = {
	-- name      = { desktop, compact }
	Title = { 64, 40 },
	H1 = { 28, 24 },
	H2 = { 22, 19 },
	Body = { 18, 16 },
	Label = { 15, 14 },
	Caption = { 13, 12 },
	Key = { 16, 15 },
}

function Theme.text(name: string, compact: boolean?): number
	local pair = TEXT[name] or TEXT.Body
	return (compact and pair[2]) or pair[1]
end

Theme.Metric = {
	Space4 = 4,
	Space8 = 8,
	Space12 = 12,
	Space16 = 16,
	Space24 = 24,
	Space32 = 32,
	Pad = 14,
	PadTight = 8,
	Gap = 10,
	Radius = 6,
	RadiusLarge = 10,
	Stroke = 1,
	StrokeStrong = 2,
	-- Vertical space reserved under the top bar for Roblox's default chat
	-- window, so the objective tracker never lands on top of it.
	ChatClearanceDesktop = 184,
	ChatClearanceCompact = 52,
	EdgeInset = 24,
}

Theme.Layer = {
	HUD = 1,
	Dialogue = 5,
	Result = 8,
	Menu = 10,
	Overlay = 12,
}

return Theme
