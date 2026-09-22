--!nonstrict
--[[
	Is Model:PivotTo() actually unstable for this project's procedural vehicles,
	or was that a guess?

	src/client/NorthPole/Kit.lua's `rigid` exists because an earlier session
	concluded that calling PivotTo every frame accumulates error - the stated
	reasoning being that PivotTo re-derives each part's offset from the
	previous frame's world CFrame, so any scale error in the stored basis is
	squared on every call. That is a plausible mechanism and it is also exactly
	the kind of claim that should not survive on plausibility alone, because
	Kit.rigid is load-bearing for every vehicle, the drill and the ancient door.

	HOW TO RUN. Paste this whole file into the Roblox Studio command bar (Edit
	mode is fine - nothing here needs a running game) and press Enter. It
	builds a model with the same shape as the real truck body, drives it for
	several thousand frames by both methods, and prints what each one's parts
	have drifted to. It creates nothing permanent: the test models are
	destroyed before it returns.

	WHAT IT MEASURES, per method, after N moves:
	  * offset drift - how far each part has moved from its ORIGINAL position
	    in the model's own frame. This is the number that matters: it is
	    "has the truck folded into itself".
	  * basis scale - how far the model's rotation basis has drifted from
	    orthonormal. 1.0 is exact; the squaring mechanism above would show up
	    here first, and long before the offsets visibly move.
]]

local FRAMES = 4000
local PARTS = 24

local function buildBody(name: string): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	-- A hull that is NOT axis aligned, so the test exercises rotation
	-- composition rather than pure translation.
	local hull = Instance.new("Part")
	hull.Name = "Hull"
	hull.Anchored = true
	hull.CanCollide = false
	hull.Size = Vector3.new(6, 2.4, 14)
	hull.CFrame = CFrame.new(0, 3, 0) * CFrame.Angles(0.07, 0.4, -0.03)
	hull.Parent = model
	model.PrimaryPart = hull
	-- Cab, frame rails, arches, lamps: assorted sizes and rotations at
	-- assorted offsets, the same mix the real body carries.
	for i = 1, PARTS do
		local p = Instance.new("Part")
		p.Name = "Piece" .. i
		p.Anchored = true
		p.CanCollide = false
		p.Size = Vector3.new(0.4 + i % 3, 0.5 + i % 4 * 0.3, 1 + i % 5 * 0.6)
		p.CFrame = hull.CFrame
			* CFrame.new(-2.5 + (i % 5) * 1.25, -0.8 + (i % 4) * 0.9, -6 + (i % 9) * 1.4)
			* CFrame.Angles(i * 0.11, i * 0.23, i * 0.07)
		p.Parent = model
	end
	model.Parent = workspace
	return model, hull
end

-- The path the model is driven along: a long translation with continuous yaw,
-- pitch and roll, which is what the convoy shots actually do to a truck.
local function targetAt(step: number): CFrame
	local t = step * 0.01
	return CFrame.new(math.sin(t) * 60, 3 + math.sin(t * 0.7) * 0.4, -t * 3)
		* CFrame.Angles(math.sin(t * 1.3) * 0.08, t * 0.5, math.sin(t * 0.9) * 0.05)
end

-- How far the basis has drifted from orthonormal. Exactly 1 for a clean
-- rotation; this is where a squared scale error shows up first.
local function basisScale(cf: CFrame): number
	local x, y, z = cf.XVector, cf.YVector, cf.ZVector
	return (x.Magnitude + y.Magnitude + z.Magnitude) / 3
end

local function measure(model: Model, primary: BasePart, original: { [BasePart]: CFrame }): (number, number)
	local worst = 0
	local inverse = primary.CFrame:Inverse()
	for part, offset in original do
		local now = inverse * part.CFrame
		worst = math.max(worst, (now.Position - offset.Position).Magnitude)
	end
	return worst, basisScale(primary.CFrame)
end

local function snapshot(model: Model, primary: BasePart): { [BasePart]: CFrame }
	local original = {}
	local inverse = primary.CFrame:Inverse()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			original[d] = inverse * d.CFrame
		end
	end
	return original
end

-- METHOD A: the supported pivot API, called once per frame.
local pivotModel, pivotPrimary = buildBody("PivotToSubject")
local pivotOriginal = snapshot(pivotModel, pivotPrimary)
for step = 1, FRAMES do
	pivotModel:PivotTo(targetAt(step))
end
local pivotDrift, pivotBasis = measure(pivotModel, pivotPrimary, pivotOriginal)

-- METHOD B: Kit.rigid - freeze every offset once, re-apply from a freshly
-- built target. Reproduced here rather than required, so the test does not
-- depend on the client module tree being loadable from the command bar.
local rigidModel, rigidPrimary = buildBody("RigidSubject")
local rigidOriginal = snapshot(rigidModel, rigidPrimary)
local frozen = {}
do
	local reference = rigidPrimary.CFrame
	local inverse = reference:Inverse()
	for _, d in rigidModel:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(frozen, { part = d, offset = inverse * d.CFrame })
		end
	end
end
for step = 1, FRAMES do
	local target = targetAt(step)
	for _, entry in frozen do
		entry.part.CFrame = target * entry.offset
	end
end
local rigidDrift, rigidBasis = measure(rigidModel, rigidPrimary, rigidOriginal)

print(string.format(
	"[PivotDrift] %d frames, %d parts\n  PivotTo   : max offset drift %.9f studs, basis scale %.12f\n  Kit.rigid : max offset drift %.9f studs, basis scale %.12f",
	FRAMES, PARTS + 1, pivotDrift, pivotBasis, rigidDrift, rigidBasis))

pivotModel:Destroy()
rigidModel:Destroy()
