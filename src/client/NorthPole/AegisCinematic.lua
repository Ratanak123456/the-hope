--!strict
--[[
 AEGIS ZERO, AS THE EXPEDITION FINDS IT.

 The giant, fifteen-years-ago Aegis that kneels over the seal in the North
 Pole opening. Owns the build, the sealed kneel, the battle damage, the
 chains, the awakening and the rise. `Cast.lua` keeps thin wrappers
 (`Cast.buildAegisZero`, `Cast.setAegisAwaken`, ...) so `Sequences.lua` did
 not have to change its calls.

 WHY IT WAS REBUILT (2026-09-23). The old builder hung the same recipe - three
 stacked ivory plates, three gold edges, three battle scores, a glowing
 conduit and a bearing - on the arm, forearm, thigh, shin and torso alike. So
 every region looked like every other region, and nothing said "shoulder" or
 "shin". This one is built the other way round: every region is a SHAPE first
 (broad chest tapering to a narrow dark waist, a separate pelvis, a heavy
 forearm, a long shin shield, a big flat foot), and each gets at most one
 primary shell, one light accent and one trim.

 THE SAME MACHINE AS THE PLAYER'S. `src/shared/AegisRig.lua` is the armour Kai
 wears fifteen years later, and this is that design at sixty studs: compact
 helmet with ONE horizontal visor, a light brow and cheeks, broad shoulders
 with a bronze crest on the LEFT only, layered chest with light breastplates,
 a recessed amber core, a trimmed belt over a distinct pelvis, a heavy
 gauntlet with a bronze wrist band, a light knee cap, a light toe cap. Every
 colour comes from `Palette.Aegis`, which is what AegisRig uses too.

 PROPORTIONS, standing, measured off the solved rig (tools/scenecheck aegis):
 about 60 studs tall, a head of about 8 (so ~7.5 heads), shoulders about 28
 across (~3.5 heads). Chest 18.6 wide at the top, 10.4 at the bottom, the
 dark waist 5 wide, the pelvis 10 plus hip guards.

 AXES. Like every rig in this cinematic the machine faces its own -Z. For a
 segment hanging BELOW its joint (thigh, shin, arm, hand, finger) a positive
 x rotation swings it forward; for a segment ABOVE its joint (torso, head) a
 positive x rotation tips it BACK. So a forward lean is a negative Waist and
 a bowed head is a negative Neck.

 ENERGY BUDGET. The visor, the core, two short channels under the core and one
 down the spine. Nothing else on the machine is Neon, ever.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Palette = require(ReplicatedStorage:WaitForChild("Shared").Palette)
local Kit = require(script.Parent.Kit)
local Env = require(script.Parent.Env)

local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles

local OUTER = Palette.Aegis.PlateOuter
local INNER = Palette.Aegis.PlateInner
local ACCENT = Palette.Aegis.PlateAccent
local JOINT = Palette.Aegis.Joint
local TRIM = Palette.Aegis.Trim
local VISOR = Palette.Aegis.Visor
local CORE = Palette.Aegis.Core
-- Dormant: the core is a dark amber lens and the visor a dark slit. Neither
-- is Neon until the machine is actually receiving power.
local CORE_DEAD = Color3.fromRGB(58, 40, 22)
local VISOR_DEAD = Color3.fromRGB(26, 40, 44)
local CHANNEL_LIT = Palette.Energy.AmberDim
local BLADE = Color3.fromRGB(112, 110, 104)
local CHAIN = Palette.Ancient.BronzeDark
local ICE = Env.Colors.ice

local METAL = Enum.Material.Metal
local WORN = Enum.Material.DiamondPlate
local NEON = Enum.Material.Neon

local AegisCinematic = {}

export type Handle = { [string]: any }

--------------------------------------------------------------------------------
-- Construction helpers. Same contract as Cast.lua's own `joint`/`attach`:
-- every part is anchored, joints are Motor6Ds solved in script, and welded
-- decoration is driven from `r.rigid` in insertion order (host first). That
-- shared shape is what lets `Cast.fix` hang the glyph band on this rig.
--------------------------------------------------------------------------------

local function make(class: string, parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	local spec = { name = name, size = size, cframe = cf, color = color, material = material or METAL, shadow = true }
	local p: BasePart
	if class == "Wedge" then
		p = Kit.wedge(spec)
	elseif class == "Cylinder" then
		local c = Kit.part(spec)
		c.Shape = Enum.PartType.Cylinder
		p = c
	else
		p = Kit.part(spec)
	end
	p.Parent = parent
	return p
end

local function attach(r: Handle, host: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, class: string?): BasePart
	local p = make(class or "Block", r.model, name, size, host.CFrame * offset, color, material)
	Kit.weld(host, p)
	p.Anchored = true
	table.insert(r.rigid, { part = p, host = host, offset = offset })
	return p
end

local function joint(r: Handle, host: BasePart, name: string, jointName: string, size: Vector3, offset: CFrame, pivot: CFrame, color: Color3, material: Enum.Material?): BasePart
	local p = make("Block", r.model, name, size, host.CFrame * offset * pivot:Inverse(), color, material)
	local m = Kit.joint(jointName, host, p, offset, pivot)
	p.Anchored = true
	r.joints[jointName] = m
	table.insert(r.order, m)
	return p
end

-- A frame whose local +Y points along `dir`, for blades and pistons.
local function alongY(pos: Vector3, dir: Vector3, roll: number?): CFrame
	local y = dir.Unit
	local ref = if math.abs(y.Y) > 0.9 then V(1, 0, 0) else V(0, 1, 0)
	local x = ref:Cross(y).Unit
	local z = x:Cross(y)
	return CFrame.fromMatrix(pos, x, y, z) * A(0, roll or 0, 0)
end

-- A side taper for the chest: a wedge standing in the XY plane, full along
-- its top edge and its INNER edge, so the broad upper chest runs down and in
-- to the narrow lower chest. `side` is -1 (left) or +1 (right).
local function taperFrame(pos: Vector3, side: number): CFrame
	-- Wedge-local bottom (full) -> world top; wedge-local back (full) -> inner.
	local x = V(0, 0, -side)
	local y = V(0, -1, 0)
	local z = V(-side, 0, 0)
	return CFrame.fromMatrix(pos, x, y, z)
end

--------------------------------------------------------------------------------
-- Poses
--------------------------------------------------------------------------------

--[[
 THE SEALED KNEEL, as absolute segment angles (pitch, relative to the pelvis
 frame) so the joint values below are derived rather than guessed:
 hip = thigh, knee = shin - thigh, ankle = foot - shin.

 Left leg forward, foot planted flat, knee up: the leg the audience reads as
 "a leg" in every frame. Right knee down on the floor, shin flat along it and
 the foot laid out behind, sole up. Toes tucked under was tried first and is
 impossible at these proportions: the foot is nearly as long as the shin, so
 standing it on its toes held the knee five studs off the floor and lifted
 the planted foot clear of it too. Pelvis low and a little back, torso leaning over the seal,
 arms down and out to the chains. Restraint and effort, not a collapse: the
 chest stays open and the head stays clear of the shoulders.
]]
local LEGS_SEALED = {
	Left = { thigh = 1.4, shin = -0.66, foot = 0 },
	Right = { thigh = -0.4, shin = -1.57, foot = -3.0 },
}
local SEALED = {
	Waist = -0.3,
	Neck = -0.32,
	ShoulderPitch = 0.62,
	ShoulderRoll = 0.34,
	Elbow = 0.32,
	Wrist = 0.18,
}
-- Fully risen (setRise(1)): torso upright, head up, arms hauling back and out.
local RISEN = {
	Waist = 0.04,
	Neck = 0.02,
	ShoulderPitch = 0.28,
	ShoulderRoll = 0.46,
	Elbow = 0.62,
}
local GRIP_CURL = 1.05 -- dormant fingers already closed on the chain
local GRIP_TIGHT = 1.4 -- fully awake

local function sideName(side: number): string
	return if side < 0 then "Left" else "Right"
end

local function setLegs(r: Handle, legs: { [string]: { thigh: number, shin: number, foot: number } })
	for prefix, leg in legs do
		r.poses[prefix .. "Hip"] = A(leg.thigh, 0, 0)
		r.poses[prefix .. "Knee"] = A(leg.shin - leg.thigh, 0, 0)
		r.poses[prefix .. "Ankle"] = A(leg.foot - leg.shin, 0, 0)
	end
end

local function setUpper(r: Handle, waist: number, neck: number, pitch: number, roll: number, elbow: number, wrist: number)
	r.poses.Waist = A(waist, 0, 0)
	r.poses.Neck = A(neck, 0, 0)
	for _, side in { -1, 1 } do
		local prefix = sideName(side)
		r.poses[prefix .. "Shoulder"] = A(pitch, 0, side * roll)
		r.poses[prefix .. "Elbow"] = A(elbow, 0, 0)
		r.poses[prefix .. "Wrist"] = A(wrist, 0, 0)
	end
end

local function setGrip(r: Handle, curl: number)
	for i, name in r.fingers do
		-- The little finger closes a touch further than the index: a real grip.
		r.poses[name] = A(-(curl + (i % 4) * 0.04), 0, 0)
	end
	for _, side in { -1, 1 } do
		r.poses[sideName(side) .. "Thumb"] = A(-curl * 0.5, 0, -side * curl * 0.5)
	end
end

--------------------------------------------------------------------------------
-- Evaluation and grounding
--------------------------------------------------------------------------------

--[[
 Exact, not blended. Cast.evaluate eases every joint 22% of the way to its
 target per call, which is right for a human reacting between cues and wrong
 here: every Aegis driver already shapes its input through `heavy`, and a
 second, frame-rate-dependent ease on top meant the machine was never
 actually in the pose the shot asked for - which also made the floor contact
 impossible to validate.
]]
function AegisCinematic.evaluate(r: Handle)
	for _, m in r.order do
		local target = r.poses[m.Name] or CF()
		m.Transform = target
		m.Part1.CFrame = m.Part0.CFrame * m.C0 * target * m.C1:Inverse()
	end
	for _, entry in r.rigid do
		entry.part.CFrame = entry.host.CFrame * entry.offset
	end
end

local CORNERS = {
	V(-1, -1, -1), V(1, -1, -1), V(-1, 1, -1), V(1, 1, -1),
	V(-1, -1, 1), V(1, -1, 1), V(-1, 1, 1), V(1, 1, 1),
}
-- Lowest point of the machine's own geometry. Chains, anchors and the
-- invisible root are not the machine.
function AegisCinematic.lowestPoint(r: Handle): (number, string)
	local lowest, where = math.huge, ""
	for _, item in r.model:GetDescendants() do
		if item:IsA("BasePart") and item ~= r.root and not r.chainParts[item] then
			local cf, half = item.CFrame, item.Size / 2
			for _, corner in CORNERS do
				local y = (cf * (corner * half)).Y
				if y < lowest then
					lowest, where = y, item.Name
				end
			end
		end
	end
	return lowest, where
end

--[[
 Puts the lowest contact exactly on `r.floorY`. This is the fix for the old
 rig's feet: its toe geometry sat about twelve studs INSIDE the chamber floor,
 because the root was placed by a hand-typed height that the proportions
 later stopped agreeing with. Now nothing is typed: the pose is solved, the
 lowest corner is measured, and the root moves by exactly that much.
]]
function AegisCinematic.ground(r: Handle)
	if not r.floorY then
		return
	end
	AegisCinematic.evaluate(r)
	local lowest = AegisCinematic.lowestPoint(r)
	r.root.CFrame += V(0, r.floorY - lowest, 0)
	AegisCinematic.evaluate(r)
end

local validationWarned = false
local function validate(r: Handle, label: string)
	if not r.floorY or not RunService:IsStudio() then
		return
	end
	local lowest, where = AegisCinematic.lowestPoint(r)
	if lowest < r.floorY - 0.05 and not validationWarned then
		validationWarned = true
		warn(`[AegisValidation] {label}: {where} is {string.format("%.2f", r.floorY - lowest)} studs below the chamber floor`)
	end
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

export type BuildOptions = {
	floorY: number?,
	-- Where each chain is made fast, left chain first. With `anchorHosts`,
	-- the anchor rides that part (the seal's leaves), so opening the seal
	-- drags the chains taut before they break.
	anchors: { Vector3 }?,
	anchorHosts: { BasePart }?,
	-- Skip battle damage, frost and chains: the clean-silhouette review.
	clean: boolean?,
}

local function buildHead(r: Handle, torso: BasePart, clean: boolean)
	attach(r, torso, "NeckGap", V(3.4, 2.6, 3.6), CF(0, 7.2, 0.4), JOINT, WORN)
	local head = joint(r, torso, "Helmet", "Neck", V(6, 6.2, 6.6), CF(0, 6.3, 0.4), CF(0, -4.3, 0.3), OUTER)
	r.head = head
	-- A strong light brow overhanging one recessed visor slit: no face.
	attach(r, head, "Brow", V(6.4, 1.3, 2.2), CF(0, 1.2, -2.7), ACCENT)
	attach(r, head, "VisorRecess", V(5.1, 1.25, 0.5), CF(0, -0.15, -3.3), JOINT, WORN)
	attach(r, head, "Faceplate", V(4.4, 2.1, 1.0), CF(0, -2.1, -3.2), INNER)
	attach(r, head, "Crown", V(4.6, 1.2, 5.2), CF(0, 3.6, 0.5), INNER)
	attach(r, head, "Crest", V(0.9, 1.8, 6.2), CF(0, 4.1, 0.3), TRIM)
	attach(r, head, "LeftCheek", V(1.1, 3.4, 4.6), CF(-3.25, -1.2, -0.9), ACCENT)
	r.visors = {}
	local function visor(name: string, width: number, x: number)
		local v = attach(r, head, name, V(width, 0.42, 0.3), CF(x, -0.15, -3.56), VISOR_DEAD)
		table.insert(r.visors, v)
	end
	if clean then
		attach(r, head, "RightCheek", V(1.1, 3.4, 4.6), CF(3.25, -1.2, -0.9), ACCENT)
		visor("Visor", 4.4, 0)
	else
		-- The right side of the face took a blow: the cheek is sheared off
		-- short, a wedge of it is gone, the brow corner is chipped and the
		-- visor is cracked through - the right end is a separate fragment
		-- set behind a dark fracture, and it lights last.
		attach(r, head, "RightCheekBroken", V(1.1, 2.0, 3.0), CF(3.25, -0.5, -1.7), ACCENT)
		attach(r, head, "RightCheekShear", V(1.1, 1.4, 1.8), CF(3.25, -2.0, -0.3) * A(0.7, 0, 0), INNER, nil, "Wedge")
		attach(r, head, "BrowChip", V(1.5, 0.8, 1.0), CF(2.7, 1.55, -3.55) * A(0, 0, 0.55), JOINT, WORN)
		visor("Visor", 3.0, -0.7)
		visor("VisorFragment", 0.9, 1.75)
		attach(r, head, "VisorCrack", V(0.18, 1.6, 0.34), CF(1.05, -0.1, -3.58) * A(0, 0, -0.35), JOINT, WORN)
	end
end

local function buildTorso(r: Handle, pelvis: BasePart, clean: boolean)
	local torso = joint(r, pelvis, "ChestFrame", "Waist", V(10, 11.4, 7.6), CF(0, 4.8, 0), CF(0, -7.1, 0.2), INNER)
	r.torso = torso
	-- Broad upper chest, two taper wedges, narrow lower chest: the V.
	attach(r, torso, "UpperChest", V(18.6, 5.4, 9), CF(0, 3.2, 0.3), OUTER)
	for _, side in { -1, 1 } do
		local wedge = make("Wedge", r.model, sideName(side) .. "ChestTaper", V(8.4, 4.8, 4.2), CFrame.new(), OUTER)
		local offset = taperFrame(V(side * 7.2, -1.9, 0.3), side)
		wedge.CFrame = torso.CFrame * offset
		Kit.weld(torso, wedge)
		wedge.Anchored = true
		table.insert(r.rigid, { part = wedge, host = torso, offset = offset })
		attach(r, torso, sideName(side) .. "Breastplate", V(5.6, 4.4, 1.3), CF(side * 5.6, 1.9, -4.6) * A(0, -side * 0.2, 0), ACCENT)
	end
	attach(r, torso, "LowerChest", V(10.4, 5.2, 8.2), CF(0, -3.2, 0.2), OUTER)
	attach(r, torso, "Collar", V(8, 1.2, 6), CF(0, 6.4, 0.4), INNER)
	-- The plate the Sequences glyph band is laid on (see r.chestBand).
	attach(r, torso, "ChestBandPlate", V(12.4, 2.3, 0.8), CF(0, 5.0, -4.4), INNER)
	r.chestBand = { offset = CF(0, 5.0, -4.85), scale = 0.85, spacing = 3.0 }

	--[[
	 THE CORE, RECESSED. Not a ball on the chest: a dark socket, a bronze
	 ring, a rotor, and a small energy source at the centre. Dormant it is a
	 dark lens you have to look for; awake, the centre lights first, then the
	 rotor turns, then the two short channels under it take the light.
	]]
	local coreY = -1.4
	attach(r, torso, "CoreSocket", V(4.8, 4.8, 0.8), CF(0, coreY, -4.0), JOINT, WORN)
	attach(r, torso, "CoreRing", V(0.5, 4.2, 4.2), CF(0, coreY, -4.45) * A(0, math.pi / 2, 0), TRIM, METAL, "Cylinder")
	attach(r, torso, "HousingTop", V(6.4, 1.1, 1.6), CF(0, coreY + 2.65, -4.7), OUTER)
	attach(r, torso, "HousingBottom", V(6.4, 1.1, 1.6), CF(0, coreY - 2.65, -4.7), OUTER)
	for _, side in { -1, 1 } do
		attach(r, torso, sideName(side) .. "HousingSide", V(1.1, 4.2, 1.6), CF(side * 2.65, coreY, -4.7), OUTER)
	end
	local rotor = joint(r, torso, "CoreRotorBar", "CoreRotor", V(3.5, 0.55, 0.4), CF(0, coreY, -4.75), CF(), INNER)
	attach(r, rotor, "CoreRotorCross", V(0.55, 3.5, 0.4), CF(), INNER)
	r.core = attach(r, torso, "ResonanceCore", V(0.5, 1.8, 1.8), CF(0, coreY, -4.98) * A(0, math.pi / 2, 0), CORE_DEAD, METAL, "Cylinder")
	r.coreLight = Kit.light(r.core, CORE, 40, 0)
	r.channels = {}
	for _, side in { -1, 1 } do
		local ch = attach(r, torso, sideName(side) .. "CoreChannel", V(0.3, 2.4, 0.3), CF(side * 1.9, coreY - 4.0, -4.35) * A(0, 0, side * 0.45), JOINT, WORN)
		table.insert(r.channels, ch)
	end

	-- Back: one plate, the ancient spine crest, one thin spine channel.
	attach(r, torso, "BackPlate", V(13, 8, 1.4), CF(0, 1.4, 5.2), INNER)
	attach(r, torso, "SpineCrest", V(1, 7, 1.2), CF(0, 1.6, 6.3), TRIM)
	local spine = attach(r, torso, "SpineChannel", V(0.3, 5.6, 0.3), CF(0, 1.4, 6.95), JOINT, WORN)
	table.insert(r.channels, spine)

	buildHead(r, torso, clean)
	return torso
end

local function buildArm(r: Handle, torso: BasePart, side: number, clean: boolean)
	local prefix = sideName(side)
	local damaged = side > 0 and not clean
	local arm = joint(r, torso, prefix .. "UpperArm", prefix .. "Shoulder", V(4, 10, 4.2), CF(side * 10.2, 3.4, 0.3), CF(0, 4.6, 0), INNER)
	attach(r, arm, prefix .. "ShoulderJoint", V(4.8, 4.4, 4.8), CF(0, 4.4, 0), JOINT, WORN)
	attach(r, arm, prefix .. "BicepPlate", V(1.1, 6, 4.4), CF(side * 2.35, -1.3, 0), OUTER)
	if not damaged then
		attach(r, arm, prefix .. "ShoulderShell", V(6.2, 4, 7.2), CF(side * 0.8, 4.6, 0), OUTER)
		attach(r, arm, prefix .. "ShoulderRim", V(6.6, 0.9, 7.6), CF(side * 0.9, 2.4, 0), ACCENT)
		if side < 0 then
			-- The crest is on the LEFT shoulder, exactly as on AegisRig.
			attach(r, arm, "ShoulderCrest", V(0.8, 2, 4.6), CF(side * 3.7, 6.6, 0.2), TRIM)
		end
	else
		--[[
		 THE TORN SHOULDER. The shell is gone: what is left is its back third,
		 bent up, a snapped piece of the rim hanging off the front, and in
		 between the dark joint and one exposed piston. It is the single most
		 legible "this machine was in a war" detail on the body, so it is built
		 as missing geometry rather than a darker colour.
		]]
		attach(r, arm, "ShellRemnant", V(6.2, 3.2, 2.6), CF(side * 0.9, 4.9, 2.6) * A(-0.35, 0, side * 0.2), OUTER)
		attach(r, arm, "ShellTear", V(3.4, 2.4, 1.6), CF(side * 2.4, 5.4, 1.0) * A(0.3, 0.2, side * 0.5), OUTER, nil, "Wedge")
		attach(r, arm, "RimFragment", V(3.2, 0.9, 3.6), CF(side * 2.6, 2.5, -1.8) * A(0.25, 0, side * -0.35), ACCENT)
		attach(r, arm, "ExposedActuator", V(1.5, 6, 1.5), CF(side * 0.2, 5.4, -1.6) * A(0.25, 0, side * -0.6), ACCENT:Lerp(INNER, 0.45))
		attach(r, arm, "ActuatorSleeve", V(2.2, 2.4, 2.2), CF(side * 1.3, 3.7, -1.6) * A(0.25, 0, side * -0.6), TRIM)
	end
	attach(r, arm, prefix .. "ElbowJoint", V(3.8, 2.8, 4), CF(0, -5.6, 0), JOINT, WORN)

	-- Heavy gauntlet: the forearm outweighs the upper arm, as on AegisRig.
	local fore = joint(r, arm, prefix .. "LowerArm", prefix .. "Elbow", V(5.4, 9.4, 5.6), CF(0, -5.6, 0), CF(0, 5.0, 0), OUTER)
	attach(r, fore, prefix .. "ForearmFace", V(3.8, 6, 1.3), CF(0, 0.2, -3.2), ACCENT, METAL, "Wedge")
	attach(r, fore, prefix .. "GauntletTrim", V(5.8, 0.9, 6), CF(0, -3.6, 0), TRIM)
	attach(r, fore, prefix .. "WristJoint", V(3.2, 1.6, 3.4), CF(0, -5.2, 0), JOINT, WORN)

	--[[
	 THE HAND: palm, heavy knuckle guard, four fingers and a thumb, each big
	 enough to read at reveal distance. The palm faces the machine's BACK and
	 the fingers curl back toward it, closing round the chain's first link at
	 `r.grip` - so "a hand holding a chain" is readable from the front as a
	 fist with a chain coming out of the bottom of it.
	]]
	local hand = joint(r, fore, prefix .. "Hand", prefix .. "Wrist", V(4.8, 3.8, 3.4), CF(0, -5.4, 0), CF(0, 2.2, 0), INNER)
	attach(r, hand, prefix .. "KnuckleGuard", V(5.1, 2.0, 1.2), CF(0, -0.9, -2.1), ACCENT)
	for f = 1, 4 do
		local name = prefix .. "Finger" .. f
		local finger = joint(r, hand, name, name, V(1.05, 2.6, 1.4), CF(-1.8 + (f - 1) * 1.2, -1.9, -0.6), CF(0, 1.2, 0), INNER)
		attach(r, finger, name .. "Tip", V(0.98, 2.0, 1.3), CF(0, -1.2, 0) * A(-0.9, 0, 0) * CF(0, -0.9, 0), OUTER)
		table.insert(r.fingers, name)
	end
	local thumb = joint(r, hand, prefix .. "Thumb", prefix .. "Thumb", V(1.2, 2.6, 1.3), CF(-side * 2.5, -0.9, -0.3), CF(0, 1.1, 0), INNER)
	attach(r, thumb, prefix .. "ThumbTip", V(1.1, 1.6, 1.2), CF(0, -1.2, 0) * A(-0.6, 0, 0) * CF(0, -0.7, 0), OUTER)
	r.hands[prefix] = hand
	return arm
end

local function buildLeg(r: Handle, pelvis: BasePart, side: number)
	local prefix = sideName(side)
	attach(r, pelvis, prefix .. "HipJoint", V(4.4, 4.2, 4.6), CF(side * 4.8, -2.4, 0), JOINT, WORN)
	local thigh = joint(r, pelvis, prefix .. "Thigh", prefix .. "Hip", V(5, 12.8, 5.2), CF(side * 4.8, -2.4, 0), CF(0, 6.4, 0), INNER)
	-- One big dark armour mass per thigh, and its light accent on the OUTER
	-- face, so from the front the only light mark on the leg is the knee.
	attach(r, thigh, prefix .. "ThighArmour", V(6.8, 9.4, 7), CF(side * 0.3, 0.6, -0.3), OUTER)
	attach(r, thigh, prefix .. "ThighSide", V(0.9, 6.4, 4.4), CF(side * 3.95, 1.2, -0.5), ACCENT)
	attach(r, thigh, prefix .. "KneeBearing", V(5.6, 4.6, 4.6), CF(0, -6.9, 0) * A(0, 0, math.pi / 2), JOINT, WORN, "Cylinder")
	-- The shin is a different shape from the thigh: narrower, with a long
	-- shield plate down the front and a calf mass high at the back, so it
	-- tapers toward the ankle.
	local shin = joint(r, thigh, prefix .. "Shin", prefix .. "Knee", V(4.4, 12.6, 4.6), CF(0, -6.9, 0), CF(0, 6.3, 0), INNER)
	attach(r, shin, prefix .. "KneeCap", V(4.8, 3.6, 2.2), CF(0, 5.4, -2.8) * A(0.2, 0, 0), ACCENT)
	attach(r, shin, prefix .. "ShinShield", V(5.2, 9.8, 2.2), CF(0, -0.6, -2.6), OUTER)
	attach(r, shin, prefix .. "Calf", V(5.2, 6.4, 3.4), CF(0, 2.2, 1.4), OUTER)
	-- Big grounded foot: sole, main foot, light toe cap, heel.
	local foot = joint(r, shin, prefix .. "Foot", prefix .. "Ankle", V(6, 2.6, 11.4), CF(0, -6.8, 0), CF(0, 2.0, 1.8), INNER)
	attach(r, foot, prefix .. "AnkleJoint", V(3.8, 2.6, 4), CF(0, 1.9, 1.8), JOINT, WORN)
	attach(r, foot, prefix .. "Sole", V(6.4, 0.7, 12), CF(0, -1.55, -0.1), JOINT, WORN)
	attach(r, foot, prefix .. "Instep", V(5.2, 1.4, 5), CF(0, 1.6, -0.6), OUTER)
	attach(r, foot, prefix .. "ToeCap", V(6.2, 2.2, 3.6), CF(0, -0.2, -3.9), ACCENT, METAL, "Wedge")
	attach(r, foot, prefix .. "Heel", V(5.6, 3.2, 2.8), CF(0, 0.3, 4.6), OUTER)
end

--[[
 Three blades from an old war, each at its own place, angle and depth. They
 enter the back plate and stand out behind the machine, so they break its
 silhouette asymmetrically from every angle but the front.
]]
local function blade(r: Handle, host: BasePart, entry: Vector3, dir: Vector3, length: number, depth: number, roll: number, index: number)
	local base = alongY(entry, dir, roll)
	local exposed = length - depth
	attach(r, host, "EmbeddedBlade" .. index, V(0.5, length, 2.6), base * CF(0, length / 2 - depth, 0), BLADE)
	attach(r, host, "BladeGuard" .. index, V(3.8, 0.7, 1.1), base * CF(0, exposed + 0.35, 0), JOINT, WORN)
	attach(r, host, "BladeGrip" .. index, V(0.9, 3.2, 0.9), base * CF(0, exposed + 2.3, 0), JOINT, WORN)
end

local function frost(r: Handle, host: BasePart, name: string, size: Vector3, offset: CFrame)
	local p = attach(r, host, name, size, offset, ICE, Enum.Material.Ice)
	p.Transparency = 0.35
	p.CastShadow = false
	table.insert(r.ice, p)
end

local function buildDamage(r: Handle)
	local torso, head = r.torso, r.head
	blade(r, torso, V(-4.4, 3.4, 5.8), V(-0.35, 0.55, 0.76), 14, 3.2, 0.3, 1)
	blade(r, torso, V(4.6, -0.6, 5.6), V(0.62, 0.05, 0.78), 10.5, 1.6, -0.5, 2)
	blade(r, torso, V(1.4, -4.4, 4.4), V(0.12, -0.48, 0.87), 12, 3.6, 1.2, 3)

	-- Frost on the surfaces that face up: shoulder, crown, chest top and
	-- back, the forward thigh. Broad and few, so the machine reads through it.
	local leftArm = r.model:FindFirstChild("LeftUpperArm") :: BasePart
	frost(r, leftArm, "ShoulderFrost", V(5.6, 0.5, 6.4), CF(-0.8, 6.75, 0))
	frost(r, head, "CrownFrost", V(2.4, 0.5, 4.4), CF(-1.6, 4.35, 0.6))
	frost(r, torso, "ChestFrost", V(15.5, 0.5, 5.6), CF(-0.6, 6.05, 2.2))
	frost(r, torso, "BackFrost", V(9, 3.2, 0.5), CF(1.2, 3.6, 6.05))
	local leftThigh = r.model:FindFirstChild("LeftThigh") :: BasePart
	frost(r, leftThigh, "ThighFrost", V(5.8, 6.4, 0.5), CF(0.2, -0.8, -3.95))
end

--[[
 CHAINS. Each link is an open oval of four blocks, links alternate 90
 degrees, and the first link sits inside the closed fist at `grip`, so the
 chain visibly comes OUT of the hand rather than off its surface. Dark
 bronze: subordinate to the machine until a shot is about them.
]]
local LINK_LENGTH, LINK_WIDTH, LINK_BAR = 3.2, 2.0, 0.62
local LINK_PITCH = LINK_LENGTH - LINK_BAR * 1.6
local GRIP = CF(0, -3.3, 1.0) -- hand-local: inside the curled fingers
-- How much further than its sealed length a chain can be dragged (the seal's
-- leaves travel fifteen studs) before it runs out of pre-built links.
local CHAIN_SLACK = 24

local function buildChains(r: Handle, opts: BuildOptions)
	for index, prefix in { "Left", "Right" } do
		local hand = r.hands[prefix]
		local chainModel = Kit.model(prefix .. "RestraintChain", r.model)
		local grip = (hand.CFrame * GRIP).Position
		local anchor: Vector3
		if opts.anchors and opts.anchors[index] then
			anchor = opts.anchors[index]
		else
			anchor = V(grip.X, (r.floorY or grip.Y - 16) + 0.9, grip.Z) + r.root.CFrame.LookVector * 5
		end
		local host = opts.anchorHosts and opts.anchorHosts[index]
		local length = (anchor - grip).Magnitude
		-- Links sit at a fixed pitch and spares are pre-built and hidden, so
		-- when the opening seal drags the anchor outward the chain gets
		-- LONGER rather than pulling gaps open between its links.
		local links = {}
		for _ = 1, math.ceil((length + CHAIN_SLACK) / LINK_PITCH) + 1 do
			local pieces = {}
			for _, s in { -1, 1 } do
				table.insert(pieces, { part = make("Block", chainModel, "LinkSide", V(LINK_BAR, LINK_LENGTH, LINK_BAR), CF(), CHAIN), offset = CF(s * (LINK_WIDTH - LINK_BAR) / 2, 0, 0) })
				table.insert(pieces, { part = make("Block", chainModel, "LinkEnd", V(LINK_WIDTH, LINK_BAR, LINK_BAR), CF(), CHAIN), offset = CF(0, s * (LINK_LENGTH - LINK_BAR) / 2, 0) })
			end
			for _, piece in pieces do
				piece.part.CastShadow = true
				r.chainParts[piece.part] = true
			end
			table.insert(links, pieces)
		end
		-- The fixing on the seal: a bronze shackle plate the last link hooks.
		local shackle = make("Block", chainModel, "ChainShackle", V(3.2, 0.8, 3.2), CF(anchor - V(0, 0.2, 0)), TRIM)
		r.chainParts[shackle] = true
		table.insert(r.chains, chainModel)
		table.insert(r.chainData, {
			hand = hand,
			links = links,
			anchor = anchor,
			host = host,
			hostOffset = if host then host.CFrame:Inverse() * CF(anchor) else nil,
			shackle = shackle,
			broken = false,
			breakTime = 0,
			visible = 0,
		})
	end
end

function AegisCinematic.updateChains(r: Handle, t: number)
	for _, chain in r.chainData do
		local from = (chain.hand.CFrame * GRIP).Position
		local anchor = chain.anchor
		if chain.host then
			anchor = (chain.host.CFrame * chain.hostOffset).Position
		end
		chain.shackle.CFrame = CF(anchor - V(0, 0.2, 0))
		local span = anchor - from
		local direction = span.Unit
		if not chain.broken then
			chain.visible = math.min(#chain.links, math.ceil(span.Magnitude / LINK_PITCH) + 1)
		end
		for i, pieces in chain.links do
			local shown = i <= chain.visible
			local pos = from + direction * math.min((i - 1) * LINK_PITCH, span.Magnitude)
			if chain.broken then
				local dt = math.min(t - chain.breakTime, 1.5)
				pos += V(math.sin(i) * dt * 6, -dt * dt * 12, math.cos(i) * dt * 4)
			end
			local frame = alongY(pos, span, (i % 2) * math.pi / 2)
			for _, piece in pieces do
				piece.part.CFrame = frame * piece.offset
				piece.part.Transparency = if shown then 0 else 1
			end
		end
	end
end

function AegisCinematic.breakChain(r: Handle, index: number, time: number?)
	local c = r.chainData[index]
	if c then
		c.broken = true
		c.breakTime = time or 0
	end
end

function AegisCinematic.build(parent: Instance, cf: CFrame, scale: number?, options: BuildOptions?): Handle
	local opts: BuildOptions = options or {}
	local clean = opts.clean == true
	local model = Kit.model("AegisZeroSealed", parent)
	local root = make("Block", model, "HumanoidRootPart", V(1, 1, 1), cf, JOINT)
	root.Transparency = 1
	root.CanQuery = false
	model.PrimaryPart = root
	local r: Handle = {
		model = model,
		dummy = model,
		root = root,
		scale = scale or 10,
		floorY = opts.floorY,
		joints = {},
		order = {},
		rigid = {},
		poses = {},
		applied = {},
		fingers = {},
		hands = {},
		chains = {},
		chainData = {},
		chainParts = {},
		ice = {},
		eyes = {},
		awaken = 0,
		rise = 0,
	}

	-- PELVIS: its own mass, clearly below and apart from the chest.
	local pelvis = joint(r, root, "Pelvis", "Root", V(10, 5, 7.5), CF(), CF(), INNER)
	r.pelvis = pelvis
	attach(r, pelvis, "PelvisFront", V(5.6, 4.6, 1.6), CF(0, -0.8, -4.3), OUTER)
	attach(r, pelvis, "BeltTrim", V(10.4, 0.6, 1.0), CF(0, 2.2, -3.55), TRIM)
	for _, side in { -1, 1 } do
		attach(r, pelvis, sideName(side) .. "HipGuard", V(2.4, 6, 7.2), CF(side * 6.3, -1.4, 0) * A(0, 0, side * 0.18), OUTER)
	end
	-- THE WAIST: a dark spine block and two actuators, half the chest's width,
	-- deliberately left unarmoured so the eye always finds where the torso
	-- turns.
	attach(r, pelvis, "WaistSpine", V(5, 5.4, 5), CF(0, 4.9, 0.3), JOINT, WORN)
	for _, side in { -1, 1 } do
		attach(r, pelvis, sideName(side) .. "WaistActuator", V(1.3, 5.2, 1.3), CF(side * 2.9, 4.9, 0.9), INNER)
	end

	local torso = buildTorso(r, pelvis, clean)
	for _, side in { -1, 1 } do
		buildArm(r, torso, side, clean)
		buildLeg(r, pelvis, side)
	end
	-- The visor is the machine's only "eye": r.eyes kept for callers that
	-- fade eyes, but there is one slit, not two lights.
	r.eyes = r.visors
	if not clean then
		buildDamage(r)
	end

	AegisCinematic.setSealed(r)
	if not clean then
		buildChains(r, opts)
		AegisCinematic.updateChains(r, 0)
	end
	return r
end

--------------------------------------------------------------------------------
-- Pose drivers
--------------------------------------------------------------------------------

-- Quintic smootherstep: zero velocity AND acceleration at both ends, which is
-- what reads as a heavy mass reluctant to start and to stop. Every driver
-- reshapes its incoming amount through this once.
local function heavy(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function applyUpper(r: Handle)
	local a = heavy(r.rise)
	local w = heavy(r.awaken)
	local function mix(x: number, y: number): number
		return x + (y - x) * a
	end
	-- Awakening lifts the head a little before the body ever moves.
	setUpper(r, mix(SEALED.Waist, RISEN.Waist), mix(SEALED.Neck + w * 0.2, RISEN.Neck), mix(SEALED.ShoulderPitch, RISEN.ShoulderPitch), mix(SEALED.ShoulderRoll, RISEN.ShoulderRoll), mix(SEALED.Elbow, RISEN.Elbow), SEALED.Wrist + w * 0.12)
	setGrip(r, GRIP_CURL + (GRIP_TIGHT - GRIP_CURL) * math.clamp(w * 2 - 0.1, 0, 1))
	r.poses.CoreRotor = A(0, 0, math.clamp((w - 0.15) / 0.85, 0, 1) * math.pi * 3)
end

function AegisCinematic.setSealed(r: Handle)
	r.awaken, r.rise = 0, 0
	setLegs(r, LEGS_SEALED)
	applyUpper(r)
	AegisCinematic.ground(r)
	validate(r, "sealed")
end

-- The full standing pose. Not used by the cinematic, which never sees the
-- machine stand; it exists so the design can be reviewed upright and so the
-- floor contact can be checked in both poses.
function AegisCinematic.setStanding(r: Handle)
	for name in r.poses do
		r.poses[name] = CF()
	end
	-- Arms a hand's width off the hips, so the chest-to-waist taper shows.
	for _, side in { -1, 1 } do
		r.poses[sideName(side) .. "Shoulder"] = A(0.04, 0, side * 0.1)
		r.poses[sideName(side) .. "Elbow"] = A(0.1, 0, 0)
	end
	setGrip(r, GRIP_CURL)
	AegisCinematic.ground(r)
	validate(r, "standing")
end

function AegisCinematic.setAwaken(r: Handle, rawAmount: number)
	r.awaken = math.clamp(rawAmount, 0, 1)
	local amount = heavy(rawAmount)
	applyUpper(r)
	-- Order of light: core centre, then the channels, then the visor.
	local core = math.clamp(amount / 0.4, 0, 1)
	r.core.Material = if core > 0.02 then NEON else METAL
	r.core.Color = CORE_DEAD:Lerp(CORE, core)
	if r.coreLight then
		r.coreLight.Brightness = core * 3.5
	end
	local channel = math.clamp((amount - 0.3) / 0.4, 0, 1)
	for _, ch in r.channels do
		ch.Material = if channel > 0.02 then NEON else WORN
		ch.Color = JOINT:Lerp(CHANNEL_LIT, channel)
	end
	for i, v in r.visors do
		-- The cracked fragment catches up last.
		local lit = math.clamp((amount - 0.6 - (i - 1) * 0.12) / 0.3, 0, 1)
		v.Material = if lit > 0.02 then NEON else METAL
		v.Color = VISOR_DEAD:Lerp(VISOR, lit)
	end
	for _, ice in r.ice do
		ice.Transparency = math.clamp(0.35 + amount * 0.65, 0, 1)
	end
	AegisCinematic.evaluate(r)
end

function AegisCinematic.setRise(r: Handle, rawAmount: number)
	r.rise = math.clamp(rawAmount, 0, 1)
	applyUpper(r)
	AegisCinematic.evaluate(r)
	validate(r, "rise")
end

return AegisCinematic
