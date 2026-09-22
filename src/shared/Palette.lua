--!strict
-- World palette, materials and quality budget.
--
-- Single source of truth for every colour and material used by the environment,
-- Aegis Zero, the Wardens (the alien troops) and the VFX, so the whole game can
-- be retuned from one file. UI colours live in Theme.lua and are deliberately
-- kept in step with the Ancient/alien families below.

local Palette = {}

Palette.City = {
	Asphalt = Color3.fromRGB(46, 50, 56),
	AsphaltWorn = Color3.fromRGB(56, 60, 66),
	LaneMark = Color3.fromRGB(186, 184, 168),
	Sidewalk = Color3.fromRGB(104, 108, 112),
	SidewalkWorn = Color3.fromRGB(92, 95, 99),
	Curb = Color3.fromRGB(132, 135, 138),
	Earth = Color3.fromRGB(74, 64, 52),

	-- Facade family: slate, concrete, muted blue, weathered metal.
	Facade = {
		Color3.fromRGB(84, 92, 102),
		Color3.fromRGB(110, 112, 114),
		Color3.fromRGB(74, 88, 106),
		Color3.fromRGB(94, 98, 102),
		Color3.fromRGB(98, 92, 88),
	},
	FacadeTrim = Color3.fromRGB(62, 68, 76),
	Foundation = Color3.fromRGB(66, 70, 74),
	Glass = Color3.fromRGB(26, 36, 48),
	GlassLit = Color3.fromRGB(226, 188, 130),
	RoofDeck = Color3.fromRGB(58, 62, 66),
	Equipment = Color3.fromRGB(70, 74, 78),
	Rubble = Color3.fromRGB(88, 88, 86),
	RebarMetal = Color3.fromRGB(104, 76, 58),
	Skyline = Color3.fromRGB(44, 52, 66),
}

Palette.Ancient = {
	StonePale = Color3.fromRGB(164, 158, 142),
	Stone = Color3.fromRGB(122, 118, 106),
	StoneDark = Color3.fromRGB(78, 78, 74),
	StoneShadow = Color3.fromRGB(52, 54, 54),
	Teal = Color3.fromRGB(30, 92, 98),
	TealDeep = Color3.fromRGB(20, 58, 64),
	Bronze = Color3.fromRGB(134, 100, 60),
	BronzeDark = Color3.fromRGB(86, 64, 40),
	Machinery = Color3.fromRGB(62, 68, 70),
}

Palette.Energy = {
	Cyan = Color3.fromRGB(84, 214, 218),
	CyanDim = Color3.fromRGB(38, 128, 136),
	Amber = Color3.fromRGB(240, 176, 78),
	AmberDim = Color3.fromRGB(146, 98, 34),
}

Palette.Aegis = {
	PlateOuter = Color3.fromRGB(34, 48, 62),
	PlateInner = Color3.fromRGB(55, 64, 70),
	PlateAccent = Color3.fromRGB(184, 187, 178),
	Joint = Color3.fromRGB(20, 25, 29),
	Trim = Color3.fromRGB(143, 105, 58),
	Visor = Color3.fromRGB(96, 224, 228),
	Core = Color3.fromRGB(244, 182, 88),
}

Palette.Alien = {
	Shell = Color3.fromRGB(44, 34, 54),
	ShellLight = Color3.fromRGB(62, 48, 76),
	Plate = Color3.fromRGB(34, 26, 42),
	Sinew = Color3.fromRGB(72, 50, 86),
	Energy = Color3.fromRGB(214, 62, 170),
	EnergyDim = Color3.fromRGB(126, 34, 100),

	-- The Harrower (boss) reads as an apex variant of the scout family at
	-- a glance: a deeper plum shell and a hot amber-red core in place of the
	-- pack's cool magenta, rather than a different creature entirely.
	BossShell = Color3.fromRGB(58, 26, 40),
	BossShellLight = Color3.fromRGB(84, 36, 54),
	BossEnergy = Color3.fromRGB(255, 96, 64),
	BossEnergyDim = Color3.fromRGB(150, 48, 30),
}

Palette.Sky = {
	Ambient = Color3.fromRGB(44, 50, 62),
	OutdoorAmbient = Color3.fromRGB(94, 104, 122),
	FogColor = Color3.fromRGB(56, 64, 80),
	AtmosphereColor = Color3.fromRGB(168, 178, 196),
	AtmosphereDecay = Color3.fromRGB(96, 106, 128),
	RiftCore = Color3.fromRGB(196, 74, 168),
	RiftShell = Color3.fromRGB(38, 28, 48),
	Smoke = Color3.fromRGB(52, 50, 54),
	Emergency = Color3.fromRGB(232, 120, 60),
}

Palette.Material = {
	Asphalt = Enum.Material.Asphalt,
	Concrete = Enum.Material.Concrete,
	Sidewalk = Enum.Material.Pavement,
	Metal = Enum.Material.Metal,
	MetalWorn = Enum.Material.DiamondPlate,
	Glass = Enum.Material.Glass,
	Stone = Enum.Material.Slate,
	StoneRough = Enum.Material.Rock,
	StoneCarved = Enum.Material.Sandstone,
	Rubble = Enum.Material.Cobblestone,
	Energy = Enum.Material.Neon,
	Earth = Enum.Material.Ground,
	Shell = Enum.Material.Granite,
}

-- Budget knobs. Everything expensive is counted here rather than sprinkled
-- through the builders, so one edit changes the whole scene's cost.
Palette.Quality = {
	Seed = 20260912, -- deterministic world; same layout every test run
	SkylineRings = 2,
	PropDensity = 1.0,
	MaxDynamicLights = 20,
	ParticlesEnabled = true,
	DecorCastsShadow = false,
	LitWindowChance = 0.16,
}

return Palette
