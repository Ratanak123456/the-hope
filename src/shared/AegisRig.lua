--!nonstrict
-- Procedural Aegis Zero armour.
--
-- LIMITATION, stated plainly: this is placeholder geometry built from Roblox
-- primitives welded onto the pilot's existing rig. It is not a sculpted mecha
-- model. It exists so the silhouette, proportions and articulation are right,
-- and so a real model can replace it later without touching gameplay.
--
-- How it works:
--   * every plate is welded to the body part it belongs to, so the rig's own
--     animations articulate the armour for free;
--   * the underlying body is recoloured to a dark metal rather than hidden, so
--     the gaps between plates read as exposed joints and there are never holes;
--   * plates are massless, non-colliding, non-query and non-touch, so they add
--     no physics whatsoever.
--
-- Both R6 and R15 are supported; the rig type is read from the Humanoid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Shared").Palette)

local AegisRig = {}

local RIG_FOLDER = "AegisPlating"

local PLATE = Palette.Aegis.PlateOuter
local INNER = Palette.Aegis.PlateInner
local ACCENT = Palette.Aegis.PlateAccent
local JOINT = Palette.Aegis.Joint
local TRIM = Palette.Aegis.Trim

local METAL = Enum.Material.Metal
local WORN = Enum.Material.DiamondPlate
local NEON = Enum.Material.Neon

export type Piece = {
	group: string,
	limb: string,
	name: string,
	size: Vector3, -- multiple of the limb's own size
	offset: Vector3, -- multiple of the limb's own size
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	shadow: boolean?,
	shape: string?,
}

local function mirrored(side: number): string
	return if side < 0 then "Left" else "Right"
end

--------------------------------------------------------------------------------
-- R15
--------------------------------------------------------------------------------

local function r15Pieces(): { Piece }
	local pieces: { Piece } = {}
	local function add(piece: Piece)
		table.insert(pieces, piece)
	end

	for _, side in { -1, 1 } do
		local prefix = mirrored(side)

		-- Legs: big grounded feet, shin plate, knee cap, thigh plate.
		add({ group = "Legs", limb = prefix .. "Foot", name = prefix .. "Boot", size = Vector3.new(1.75, 1.5, 1.7), offset = Vector3.new(0, -0.1, -0.12), color = INNER, material = WORN, shadow = true })
		add({ group = "Legs", limb = prefix .. "Foot", name = prefix .. "BootToe", size = Vector3.new(1.6, 0.7, 0.55), offset = Vector3.new(0, -0.32, -0.72), color = ACCENT, material = METAL })
		add({ group = "Legs", limb = prefix .. "Foot", name = prefix .. "Heel", size = Vector3.new(1.35, 0.82, 0.48), offset = Vector3.new(0, -0.22, 0.72), color = PLATE, material = METAL, shape = "Wedge" })
		add({ group = "Legs", limb = prefix .. "LowerLeg", name = prefix .. "Shin", size = Vector3.new(1.55, 0.86, 1.6), offset = Vector3.new(0, 0.02, -0.1), color = PLATE, material = METAL, shadow = true })
		add({ group = "Legs", limb = prefix .. "LowerLeg", name = prefix .. "ShinFace", size = Vector3.new(0.9, 0.6, 0.22), offset = Vector3.new(0, -0.04, -0.86), color = ACCENT, material = METAL, shape = "Wedge" })
		add({ group = "Legs", limb = prefix .. "LowerLeg", name = prefix .. "ShinChannel", size = Vector3.new(0.16, 0.52, 0.12), offset = Vector3.new(0, -0.02, -0.99), color = Palette.Energy.CyanDim, material = NEON, transparency = 0.18 })
		add({ group = "Legs", limb = prefix .. "LowerLeg", name = prefix .. "Knee", size = Vector3.new(1.48, 0.4, 1.72), offset = Vector3.new(0, 0.44, -0.28), color = ACCENT, material = METAL, shape = "Wedge" })
		add({ group = "Legs", limb = prefix .. "UpperLeg", name = prefix .. "Thigh", size = Vector3.new(1.5, 0.8, 1.5), offset = Vector3.new(0, -0.02, -0.05), color = PLATE, material = METAL, shadow = true })
		add({ group = "Legs", limb = prefix .. "UpperLeg", name = prefix .. "HipGap", size = Vector3.new(1.18, 0.22, 1.18), offset = Vector3.new(0, 0.45, 0), color = JOINT, material = WORN })
	end

	-- Torso: pelvis, layered chest, back, ancient trim band, resonance core.
	add({ group = "Torso", limb = "LowerTorso", name = "Pelvis", size = Vector3.new(1.32, 1.1, 1.45), offset = Vector3.new(0, -0.05, 0), color = INNER, material = METAL, shadow = true })
	add({ group = "Torso", limb = "LowerTorso", name = "BeltTrim", size = Vector3.new(1.36, 0.2, 1.5), offset = Vector3.new(0, 0.3, 0), color = TRIM, material = METAL })
	add({ group = "Torso", limb = "LowerTorso", name = "WaistLeft", size = Vector3.new(0.34, 0.75, 1.15), offset = Vector3.new(-0.66, -0.16, 0.02), color = PLATE, material = METAL, shape = "Wedge" })
	add({ group = "Torso", limb = "LowerTorso", name = "WaistRight", size = Vector3.new(0.34, 0.75, 1.15), offset = Vector3.new(0.66, -0.16, 0.02), color = PLATE, material = METAL, shape = "Wedge" })
	add({ group = "Torso", limb = "UpperTorso", name = "TorsoShell", size = Vector3.new(1.3, 1.05, 1.5), offset = Vector3.new(0, -0.02, 0), color = PLATE, material = METAL, shadow = true })
	add({ group = "Torso", limb = "UpperTorso", name = "ChestPlateLeft", size = Vector3.new(0.62, 0.72, 0.42), offset = Vector3.new(-0.34, 0.16, -0.62), color = ACCENT, material = METAL })
	add({ group = "Torso", limb = "UpperTorso", name = "ChestPlateRight", size = Vector3.new(0.62, 0.72, 0.42), offset = Vector3.new(0.34, 0.16, -0.62), color = ACCENT, material = METAL })
	add({ group = "Torso", limb = "UpperTorso", name = "ChestCollarLeft", size = Vector3.new(0.56, 0.22, 0.56), offset = Vector3.new(-0.38, 0.5, -0.34), color = PLATE, material = METAL, shape = "Wedge" })
	add({ group = "Torso", limb = "UpperTorso", name = "ChestCollarRight", size = Vector3.new(0.56, 0.22, 0.56), offset = Vector3.new(0.38, 0.5, -0.34), color = PLATE, material = METAL, shape = "Wedge" })
	add({ group = "Torso", limb = "UpperTorso", name = "AncientGlyph", size = Vector3.new(0.08, 0.34, 0.12), offset = Vector3.new(-0.31, 0.12, -0.86), color = TRIM, material = METAL })
	add({ group = "Torso", limb = "UpperTorso", name = "BackPlate", size = Vector3.new(1.15, 0.9, 0.4), offset = Vector3.new(0, 0.05, 0.62), color = INNER, material = WORN })
	add({ group = "Torso", limb = "UpperTorso", name = "SpineFin", size = Vector3.new(0.22, 1.0, 0.5), offset = Vector3.new(0, 0.2, 0.76), color = TRIM, material = METAL })
	add({ group = "Torso", limb = "UpperTorso", name = "CollarGap", size = Vector3.new(0.7, 0.22, 0.7), offset = Vector3.new(0, 0.52, 0), color = JOINT, material = WORN })
	add({ group = "Torso", limb = "UpperTorso", name = "CoreHousing", size = Vector3.new(0.66, 0.66, 0.3), offset = Vector3.new(0, 0.1, -0.68), color = INNER, material = METAL })
	add({ group = "Torso", limb = "UpperTorso", name = "Core", size = Vector3.new(0.4, 0.4, 0.24), offset = Vector3.new(0, 0.1, -0.78), color = Palette.Aegis.Core, material = NEON, transparency = 1 })

	for _, side in { -1, 1 } do
		local prefix = mirrored(side)
		-- Arms: broad pauldron, upper arm, heavy forearm, blocky fist.
		add({ group = "Arms", limb = prefix .. "UpperArm", name = prefix .. "Pauldron", size = Vector3.new(1.9, 0.62, 1.95), offset = Vector3.new(side * 0.22, 0.42, 0), color = PLATE, material = METAL, shadow = true })
		add({ group = "Arms", limb = prefix .. "UpperArm", name = prefix .. "PauldronEdge", size = Vector3.new(2.0, 0.2, 2.05), offset = Vector3.new(side * 0.24, 0.66, 0), color = ACCENT, material = METAL })
		add({ group = "Arms", limb = prefix .. "UpperArm", name = prefix .. "ShoulderGap", size = Vector3.new(1.0, 0.24, 1.0), offset = Vector3.new(0, 0.18, 0), color = JOINT, material = WORN })
		add({ group = "Arms", limb = prefix .. "UpperArm", name = prefix .. "Bicep", size = Vector3.new(1.35, 0.7, 1.35), offset = Vector3.new(0, -0.14, 0), color = INNER, material = METAL })
		add({ group = "Arms", limb = prefix .. "LowerArm", name = prefix .. "ElbowGap", size = Vector3.new(1.05, 0.22, 1.05), offset = Vector3.new(0, 0.45, 0), color = JOINT, material = WORN })
		add({ group = "Arms", limb = prefix .. "LowerArm", name = prefix .. "Gauntlet", size = Vector3.new(1.7, 0.92, 1.7), offset = Vector3.new(0, -0.06, 0), color = PLATE, material = METAL, shadow = true })
		add({ group = "Arms", limb = prefix .. "LowerArm", name = prefix .. "GauntletTrim", size = Vector3.new(1.78, 0.16, 1.78), offset = Vector3.new(0, -0.36, 0), color = TRIM, material = METAL })
		add({ group = "Arms", limb = prefix .. "LowerArm", name = prefix .. "ForearmFace", size = Vector3.new(1.18, 0.62, 0.26), offset = Vector3.new(0, -0.08, -0.82), color = ACCENT, material = METAL, shape = "Wedge" })
		if side > 0 then
			add({ group = "Arms", limb = prefix .. "LowerArm", name = "BoltEmitter", size = Vector3.new(0.52, 0.72, 0.54), offset = Vector3.new(0.72, -0.08, -0.18), color = INNER, material = WORN })
			add({ group = "Arms", limb = prefix .. "LowerArm", name = "BoltChannel", size = Vector3.new(0.16, 0.52, 0.18), offset = Vector3.new(1.0, -0.08, -0.18), color = Palette.Energy.CyanDim, material = NEON, transparency = 0.15 })
		else
			add({ group = "Arms", limb = prefix .. "UpperArm", name = "ShoulderCrest", size = Vector3.new(0.42, 0.68, 1.2), offset = Vector3.new(-0.86, 0.5, 0.05), color = TRIM, material = METAL, shape = "Wedge" })
		end
		add({ group = "Arms", limb = prefix .. "Hand", name = prefix .. "Fist", size = Vector3.new(1.7, 1.5, 1.75), offset = Vector3.new(0, -0.12, -0.05), color = INNER, material = WORN, shadow = true })
		add({ group = "Arms", limb = prefix .. "Hand", name = prefix .. "Knuckle", size = Vector3.new(1.75, 0.42, 0.5), offset = Vector3.new(0, 0.1, -0.7), color = ACCENT, material = METAL })
	end

	-- Head: compact helmet with a narrow visor slit.
	add({ group = "Head", limb = "Head", name = "NeckGap", size = Vector3.new(0.66, 0.3, 0.66), offset = Vector3.new(0, -0.52, 0), color = JOINT, material = WORN })
	add({ group = "Head", limb = "Head", name = "Helmet", size = Vector3.new(1.16, 1.06, 1.2), offset = Vector3.new(0, 0.06, 0.02), color = PLATE, material = METAL, shadow = true })
	add({ group = "Head", limb = "Head", name = "HelmetBrow", size = Vector3.new(1.08, 0.22, 0.34), offset = Vector3.new(0, 0.2, -0.52), color = ACCENT, material = METAL, shape = "Wedge" })
	add({ group = "Head", limb = "Head", name = "HelmetCrown", size = Vector3.new(0.9, 0.3, 1.0), offset = Vector3.new(0, 0.56, 0.04), color = INNER, material = METAL })
	add({ group = "Head", limb = "Head", name = "HelmetCrest", size = Vector3.new(0.22, 0.42, 1.22), offset = Vector3.new(0, 0.5, 0), color = TRIM, material = METAL })
	add({ group = "Head", limb = "Head", name = "CheekLeft", size = Vector3.new(0.24, 0.62, 0.9), offset = Vector3.new(-0.56, -0.06, 0.05), color = ACCENT, material = METAL })
	add({ group = "Head", limb = "Head", name = "CheekRight", size = Vector3.new(0.24, 0.62, 0.9), offset = Vector3.new(0.56, -0.06, 0.05), color = ACCENT, material = METAL })
	add({ group = "Head", limb = "Head", name = "Visor", size = Vector3.new(0.86, 0.16, 0.2), offset = Vector3.new(0, 0.08, -0.56), color = Palette.Aegis.Visor, material = NEON, transparency = 1 })

	return pieces
end

--------------------------------------------------------------------------------
-- R6 - fewer limbs, so plates are grouped differently but read the same.
--------------------------------------------------------------------------------

local function r6Pieces(): { Piece }
	local pieces: { Piece } = {}
	local function add(piece: Piece)
		table.insert(pieces, piece)
	end

	for _, side in { -1, 1 } do
		local limb = mirrored(side) .. " Leg"
		local prefix = mirrored(side)
		add({ group = "Legs", limb = limb, name = prefix .. "Boot", size = Vector3.new(1.7, 0.3, 1.8), offset = Vector3.new(0, -0.38, -0.08), color = INNER, material = WORN, shadow = true })
		add({ group = "Legs", limb = limb, name = prefix .. "BootToe", size = Vector3.new(1.55, 0.16, 0.5), offset = Vector3.new(0, -0.46, -0.62), color = ACCENT, material = METAL })
		add({ group = "Legs", limb = limb, name = prefix .. "Shin", size = Vector3.new(1.5, 0.4, 1.55), offset = Vector3.new(0, -0.14, -0.08), color = PLATE, material = METAL, shadow = true })
		add({ group = "Legs", limb = limb, name = prefix .. "ShinFace", size = Vector3.new(0.9, 0.28, 0.22), offset = Vector3.new(0, -0.14, -0.86), color = ACCENT, material = METAL, shape = "Wedge" })
		add({ group = "Legs", limb = limb, name = prefix .. "Knee", size = Vector3.new(1.45, 0.18, 1.7), offset = Vector3.new(0, 0.06, -0.27), color = ACCENT, material = METAL, shape = "Wedge" })
		add({ group = "Legs", limb = limb, name = prefix .. "Thigh", size = Vector3.new(1.45, 0.4, 1.45), offset = Vector3.new(0, 0.24, -0.03), color = PLATE, material = METAL, shadow = true })
		add({ group = "Legs", limb = limb, name = prefix .. "HipGap", size = Vector3.new(1.12, 0.1, 1.12), offset = Vector3.new(0, 0.46, 0), color = JOINT, material = WORN })
	end

	add({ group = "Torso", limb = "Torso", name = "Pelvis", size = Vector3.new(1.24, 0.42, 1.4), offset = Vector3.new(0, -0.32, 0), color = INNER, material = METAL, shadow = true })
	add({ group = "Torso", limb = "Torso", name = "BeltTrim", size = Vector3.new(1.28, 0.09, 1.44), offset = Vector3.new(0, -0.1, 0), color = TRIM, material = METAL })
	add({ group = "Torso", limb = "Torso", name = "WaistLeft", size = Vector3.new(0.3, 0.34, 1.1), offset = Vector3.new(-0.65, -0.32, 0), color = PLATE, material = METAL, shape = "Wedge" })
	add({ group = "Torso", limb = "Torso", name = "WaistRight", size = Vector3.new(0.3, 0.34, 1.1), offset = Vector3.new(0.65, -0.32, 0), color = PLATE, material = METAL, shape = "Wedge" })
	add({ group = "Torso", limb = "Torso", name = "TorsoShell", size = Vector3.new(1.24, 0.62, 1.46), offset = Vector3.new(0, 0.12, 0), color = PLATE, material = METAL, shadow = true })
	add({ group = "Torso", limb = "Torso", name = "ChestPlateLeft", size = Vector3.new(0.56, 0.42, 0.4), offset = Vector3.new(-0.3, 0.2, -0.6), color = ACCENT, material = METAL })
	add({ group = "Torso", limb = "Torso", name = "ChestPlateRight", size = Vector3.new(0.56, 0.42, 0.4), offset = Vector3.new(0.3, 0.2, -0.6), color = ACCENT, material = METAL })
	add({ group = "Torso", limb = "Torso", name = "BackPlate", size = Vector3.new(1.1, 0.55, 0.38), offset = Vector3.new(0, 0.14, 0.6), color = INNER, material = WORN })
	add({ group = "Torso", limb = "Torso", name = "SpineFin", size = Vector3.new(0.2, 0.6, 0.46), offset = Vector3.new(0, 0.2, 0.74), color = TRIM, material = METAL })
	add({ group = "Torso", limb = "Torso", name = "CollarGap", size = Vector3.new(0.66, 0.11, 0.68), offset = Vector3.new(0, 0.46, 0), color = JOINT, material = WORN })
	add({ group = "Torso", limb = "Torso", name = "CoreHousing", size = Vector3.new(0.6, 0.4, 0.28), offset = Vector3.new(0, 0.16, -0.66), color = INNER, material = METAL })
	add({ group = "Torso", limb = "Torso", name = "Core", size = Vector3.new(0.36, 0.24, 0.22), offset = Vector3.new(0, 0.16, -0.76), color = Palette.Aegis.Core, material = NEON, transparency = 1 })

	for _, side in { -1, 1 } do
		local limb = mirrored(side) .. " Arm"
		local prefix = mirrored(side)
		add({ group = "Arms", limb = limb, name = prefix .. "Pauldron", size = Vector3.new(1.85, 0.28, 1.9), offset = Vector3.new(side * 0.2, 0.34, 0), color = PLATE, material = METAL, shadow = true })
		add({ group = "Arms", limb = limb, name = prefix .. "PauldronEdge", size = Vector3.new(1.95, 0.09, 2.0), offset = Vector3.new(side * 0.22, 0.46, 0), color = ACCENT, material = METAL })
		add({ group = "Arms", limb = limb, name = prefix .. "ShoulderGap", size = Vector3.new(1.0, 0.1, 1.0), offset = Vector3.new(0, 0.22, 0), color = JOINT, material = WORN })
		add({ group = "Arms", limb = limb, name = prefix .. "Bicep", size = Vector3.new(1.3, 0.3, 1.3), offset = Vector3.new(0, 0.06, 0), color = INNER, material = METAL })
		add({ group = "Arms", limb = limb, name = prefix .. "ElbowGap", size = Vector3.new(1.05, 0.09, 1.05), offset = Vector3.new(0, -0.1, 0), color = JOINT, material = WORN })
		add({ group = "Arms", limb = limb, name = prefix .. "Gauntlet", size = Vector3.new(1.65, 0.44, 1.68), offset = Vector3.new(0, -0.27, 0), color = PLATE, material = METAL, shadow = true })
		add({ group = "Arms", limb = limb, name = prefix .. "ForearmFace", size = Vector3.new(1.15, 0.24, 0.24), offset = Vector3.new(0, -0.28, -0.83), color = ACCENT, material = METAL, shape = "Wedge" })
		if side > 0 then
			add({ group = "Arms", limb = limb, name = "BoltEmitter", size = Vector3.new(0.5, 0.3, 0.5), offset = Vector3.new(0.74, -0.27, -0.12), color = INNER, material = WORN })
			add({ group = "Arms", limb = limb, name = "BoltChannel", size = Vector3.new(0.14, 0.2, 0.16), offset = Vector3.new(1, -0.27, -0.12), color = Palette.Energy.CyanDim, material = NEON, transparency = 0.15 })
		else
			add({ group = "Arms", limb = limb, name = "ShoulderCrest", size = Vector3.new(0.35, 0.32, 1.15), offset = Vector3.new(-0.88, 0.35, 0), color = TRIM, material = METAL, shape = "Wedge" })
		end
		add({ group = "Arms", limb = limb, name = prefix .. "Fist", size = Vector3.new(1.7, 0.2, 1.75), offset = Vector3.new(0, -0.46, -0.04), color = INNER, material = WORN, shadow = true })
	end

	add({ group = "Head", limb = "Head", name = "NeckGap", size = Vector3.new(0.7, 0.22, 0.7), offset = Vector3.new(0, -0.48, 0), color = JOINT, material = WORN })
	add({ group = "Head", limb = "Head", name = "Helmet", size = Vector3.new(1.12, 1.0, 1.16), offset = Vector3.new(0, 0.04, 0.02), color = PLATE, material = METAL, shadow = true })
	add({ group = "Head", limb = "Head", name = "HelmetBrow", size = Vector3.new(1.04, 0.18, 0.3), offset = Vector3.new(0, 0.17, -0.54), color = ACCENT, material = METAL, shape = "Wedge" })
	add({ group = "Head", limb = "Head", name = "HelmetCrown", size = Vector3.new(0.88, 0.28, 0.98), offset = Vector3.new(0, 0.52, 0.04), color = INNER, material = METAL })
	add({ group = "Head", limb = "Head", name = "HelmetCrest", size = Vector3.new(0.2, 0.4, 1.2), offset = Vector3.new(0, 0.46, 0), color = TRIM, material = METAL })
	add({ group = "Head", limb = "Head", name = "CheekLeft", size = Vector3.new(0.22, 0.6, 0.88), offset = Vector3.new(-0.54, -0.06, 0.05), color = ACCENT, material = METAL })
	add({ group = "Head", limb = "Head", name = "CheekRight", size = Vector3.new(0.22, 0.6, 0.88), offset = Vector3.new(0.54, -0.06, 0.05), color = ACCENT, material = METAL })
	add({ group = "Head", limb = "Head", name = "Visor", size = Vector3.new(0.84, 0.15, 0.2), offset = Vector3.new(0, 0.06, -0.56), color = Palette.Aegis.Visor, material = NEON, transparency = 1 })

	return pieces
end

--------------------------------------------------------------------------------

function AegisRig.piecesFor(humanoid: Humanoid): { Piece }
	return if humanoid.RigType == Enum.HumanoidRigType.R6 then r6Pieces() else r15Pieces()
end

function AegisRig.container(character: Model): Folder
	local existing = character:FindFirstChild(RIG_FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = RIG_FOLDER
	folder.Parent = character
	return folder
end

--[[
	Builds one named group of plates. Called several times during the
	transformation so the armour assembles in a deliberate order.
	Returns the parts created, newest first.
]]
function AegisRig.buildGroup(character: Model, humanoid: Humanoid, group: string): { BasePart }
	local folder = AegisRig.container(character)
	local created: { BasePart } = {}

	for _, piece in AegisRig.piecesFor(humanoid) do
		if piece.group ~= group then
			continue
		end
		local limb = character:FindFirstChild(piece.limb)
		if not limb or not limb:IsA("BasePart") then
			continue -- rig is missing this part; skip rather than error
		end
		if folder:FindFirstChild(piece.name) then
			continue -- already built
		end

		local plate = Instance.new(if piece.shape == "Wedge" then "WedgePart" else "Part")
		plate.Name = piece.name
		plate.Size = limb.Size * piece.size
		plate.Color = piece.color
		plate.Material = piece.material or METAL
		plate.Transparency = piece.transparency or 0
		plate.CanCollide = false
		plate.CanQuery = false
		plate.CanTouch = false
		plate.Massless = true
		plate.CastShadow = piece.shadow == true
		plate.TopSurface = Enum.SurfaceType.Smooth
		plate.BottomSurface = Enum.SurfaceType.Smooth
		plate.CFrame = limb.CFrame * CFrame.new(limb.Size * piece.offset)
		plate.Parent = folder

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = limb
		weld.Part1 = plate
		weld.Parent = plate

		table.insert(created, plate)
	end

	return created
end

function AegisRig.findPiece(character: Model, name: string): BasePart?
	local folder = character:FindFirstChild(RIG_FOLDER)
	local piece = folder and folder:FindFirstChild(name)
	return if piece and piece:IsA("BasePart") then piece else nil
end

--[[
	Ignites the resonance core and the visor. Both start fully transparent and
	are faded in, so there is no sudden flash.
]]
function AegisRig.ignite(character: Model)
	local core = AegisRig.findPiece(character, "Core")
	if core then
		core.Transparency = 0.05
		local light = Instance.new("PointLight")
		light.Name = "CoreLight"
		light.Color = Palette.Aegis.Core
		light.Brightness = 2.2
		light.Range = 24
		light.Shadows = false
		light.Parent = core
	end
	local visor = AegisRig.findPiece(character, "Visor")
	if visor then
		visor.Transparency = 0.1
	end
end

--------------------------------------------------------------------------------
-- Body treatment: the avatar becomes the dark under-structure between plates.
--------------------------------------------------------------------------------

--[[
	Original appearance is kept in a weak-keyed table rather than in instance
	attributes. Attributes would round-trip through the datamodel's own type
	system, and a single type mismatch there would silently skip the restore and
	leave the player permanently dark. A plain table cannot fail that way, and
	the weak key means a destroyed character is collected normally.
]]
type Saved = { target: Instance, color: Color3?, material: Enum.Material?, transparency: number }

local savedAppearance: { [Model]: { Saved } } = setmetatable({}, { __mode = "k" }) :: any

function AegisRig.applyUnderlayer(character: Model)
	if savedAppearance[character] then
		return -- already applied; never record the dark colours as "original"
	end

	local rigFolder = character:FindFirstChild(RIG_FOLDER)
	local saved: { Saved } = {}

	for _, descendant in character:GetDescendants() do
		if descendant.Parent == rigFolder then
			continue -- our own plates
		end
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			table.insert(saved, {
				target = descendant,
				color = descendant.Color,
				material = descendant.Material,
				transparency = descendant.Transparency,
			})
			descendant.Color = JOINT
			descendant.Material = WORN
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			table.insert(saved, {
				target = descendant,
				transparency = descendant.Transparency,
			})
			descendant.Transparency = 1
		end
	end

	savedAppearance[character] = saved
end

function AegisRig.restoreAppearance(character: Model)
	local saved = savedAppearance[character]
	if not saved then
		return
	end
	savedAppearance[character] = nil

	for _, entry in saved do
		local target = entry.target
		if not target.Parent then
			continue
		end
		if target:IsA("BasePart") then
			if entry.color then
				target.Color = entry.color
			end
			if entry.material then
				target.Material = entry.material
			end
			target.Transparency = entry.transparency
		elseif target:IsA("Decal") or target:IsA("Texture") then
			target.Transparency = entry.transparency
		end
	end
end

function AegisRig.clear(character: Model)
	local folder = character:FindFirstChild(RIG_FOLDER)
	if folder then
		folder:Destroy()
	end
	AegisRig.restoreAppearance(character)
end

AegisRig.Groups = { "Legs", "Torso", "Arms", "Head" }
AegisRig.FolderName = RIG_FOLDER

return AegisRig
