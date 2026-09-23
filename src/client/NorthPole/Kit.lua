--!nonstrict
-- Small builder helpers shared by every North Pole cinematic module
-- (Env/Cast/Sequences), mirroring src/server/World/Kit.lua's shape so the
-- cinematic's procedural geometry reads the same way the rest of the game's
-- procedural geometry does. Client-local only (see Env.lua's header) so this
-- cannot live in src/server/World - it is its own small copy on purpose,
-- not a duplicate of a shared concern (server Kit.lua builds physical,
-- replicated world geometry; this builds decorative, non-replicated,
-- temporary cinematic geometry with different defaults: CanCollide false,
-- CastShadow false by default, everything massless).

local Kit = {}

export type PartSpec = {
	name: string?,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	cframe: CFrame?,
	position: Vector3?,
	transparency: number?,
	shadow: boolean?,
	anchored: boolean?,
}

local lightBudget = 26

function Kit.resetLightBudget(n: number?)
	lightBudget = n or 26
end

function Kit.folder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Kit.model(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function applyCommon(part: BasePart, spec: PartSpec)
	part.Name = spec.name or part.ClassName
	part.Anchored = if spec.anchored == nil then true else spec.anchored
	part.Size = spec.size
	part.Color = spec.color
	part.Material = spec.material or Enum.Material.Concrete
	part.Transparency = spec.transparency or 0
	part.CanCollide = false
	part.CanQuery = (spec.transparency or 0) < 0.65
	part.CanTouch = false
	part.CastShadow = spec.shadow == true
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = spec.cframe or CFrame.new(spec.position or Vector3.zero)
end

function Kit.part(spec: PartSpec): Part
	local part = Instance.new("Part")
	applyCommon(part, spec)
	return part
end

function Kit.wedge(spec: PartSpec): WedgePart
	local wedge = Instance.new("WedgePart")
	applyCommon(wedge, spec)
	return wedge
end

function Kit.corner(spec: PartSpec): CornerWedgePart
	local corner = Instance.new("CornerWedgePart")
	applyCommon(corner, spec)
	return corner
end

-- Cylinder length runs along local X; "y" stands it upright, "z" lays it
-- along the horizontal Z axis, nil/"x" leaves it as authored.
function Kit.cylinder(spec: PartSpec, axis: string?): Part
	local part = Kit.part(spec)
	part.Shape = Enum.PartType.Cylinder
	local base = spec.cframe or CFrame.new(spec.position or Vector3.zero)
	if axis == "y" then
		part.CFrame = base * CFrame.Angles(0, 0, math.rad(90))
	elseif axis == "z" then
		part.CFrame = base * CFrame.Angles(0, math.rad(90), 0)
	else
		part.CFrame = base
	end
	return part
end

function Kit.ball(spec: PartSpec): Part
	local part = Kit.part(spec)
	part.Shape = Enum.PartType.Ball
	return part
end

function Kit.weld(base: BasePart, attached: BasePart)
	attached.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = attached
	weld.Parent = attached
end

-- A posable joint (as opposed to a rigid weld): `attached` is positioned at
-- `worldCFrame` at build time, then can be re-angled at runtime through the
-- returned Motor6D's Transform, exactly like AegisRig's use of the pilot's
-- own Motor6Ds.
function Kit.joint(name: string, base: BasePart, attached: BasePart, baseOffset: CFrame, attachedOffset: CFrame?): Motor6D
	attached.Anchored = false
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = base
	motor.Part1 = attached
	motor.C0 = baseOffset
	motor.C1 = attachedOffset or CFrame.new()
	motor.Parent = base
	return motor
end

function Kit.light(parent: BasePart, color: Color3, range: number, brightness: number, shadows: boolean?): PointLight?
	if lightBudget <= 0 then
		return nil
	end
	lightBudget -= 1
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows == true
	light.Parent = parent
	return light
end

--[[
	Freezes a model's shape once so it can be re-placed every frame WITHOUT
	re-deriving each part's offset from the previous frame's world CFrame.

	`Model:PivotTo` does exactly that re-derivation:

		part.CFrame = target * pivot:Inverse() * part.CFrame

	which feeds every frame's rounding back in as the next frame's input. That
	is not merely lossy, it is UNSTABLE: a rotation's inverse is its
	transpose, so transpose(R) * R is (scale^2) * I, and any scale error in
	the stored basis is SQUARED on every call - eps, 2*eps, 4*eps, 8*eps. The
	truck's body reached a basis scaled by 0.65 after about a second of
	driving and collapsed onto its own hull; the same maths applies to the
	wheels and the ancient door, which are re-pivoted every frame too.

	Offsets measured ONCE against a reference frame and re-applied from a
	freshly built target are exact for as long as the shot runs, however many
	frames that is, and they also remove the question of what a model's pivot
	is when it has no PrimaryPart.

	Returns `place(target)`: puts every part where it sat relative to
	`reference` at build time, rigidly, relative to `target` instead.
]]
function Kit.rigid(model: Instance, reference: CFrame): (CFrame) -> ()
	local inverse = reference:Inverse()
	local frozen: { { part: BasePart, offset: CFrame } } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(frozen, { part = descendant :: BasePart, offset = inverse * (descendant :: BasePart).CFrame })
		end
	end
	return function(target: CFrame)
		for _, entry in frozen do
			entry.part.CFrame = target * entry.offset
		end
	end
end

function Kit.rng(seed: number): Random
	return Random.new(seed)
end

function Kit.pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

function Kit.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Smoothstep - the same "eased(t)" curve Opening.lua/CutsceneRunner already
-- use throughout for camera/shot easing.
function Kit.smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Opaque architecture participates in camera checks. Tiny decoration can opt out.
function Kit.beam(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, color: Color3, material: Enum.Material?): BasePart
 local p = Kit.part({name = name, size = Vector3.new(width, width, (b-a).Magnitude), color = color, material = material or Enum.Material.Metal, cframe = CFrame.lookAt((a+b)/2, b)})
 p.Parent = parent
 return p
end

--[[
 A blank world-space screen on one face of `host`, for callers that need to
 drive individual elements rather than print one fixed marking.

 Kit.label below is the right tool for a stencilled sign or a painted panel
 number - one string, set once, never touched again. It is the wrong tool for
 the bore console, where six values change independently and an alert band has
 to appear over the top of them; that needs real child elements, which is what
 this returns a canvas for (see Instrumentation.lua).

 Passing `pixelsPerStud` sizes the canvas from the part, which suits a screen
 whose physical size might change. Leaving it out gives a FIXED canvas the
 caller states itself, which is what a laid-out instrument panel wants: every
 element then sits at a known pixel position regardless of how big the part is.
]]
function Kit.surfaceGui(host: BasePart, face: Enum.NormalId?, pixelsPerStud: number?, canvas: Vector2?): SurfaceGui
 local gui = Instance.new("SurfaceGui")
 gui.Name = "WorldDisplay"
 gui.Face = face or Enum.NormalId.Front
 gui.LightInfluence = 0
 gui.ZOffset = 0.02
 if pixelsPerStud then
  gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
  gui.PixelsPerStud = pixelsPerStud
 else
  gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
  gui.CanvasSize = canvas or Vector2.new(800, 600)
 end
 gui.Parent = host
 return gui
end

function Kit.label(host: BasePart, text: string, color: Color3?, face: Enum.NormalId?)
 local gui = Instance.new("SurfaceGui")
 gui.Name = "PrintedMarking"
 gui.Face = face or Enum.NormalId.Front
 gui.CanvasSize = Vector2.new(600, 240)
 gui.LightInfluence = 0.4
 gui.Parent = host
 local label = Instance.new("TextLabel")
 label.Size = UDim2.fromScale(1, 1)
 label.BackgroundTransparency = 1
 label.Text = text
 label.Font = Enum.Font.GothamMedium
 label.TextSize = 52
 label.TextColor3 = color or Color3.fromRGB(226, 224, 211)
 label.Parent = gui
 return label
end

function Kit.dust(host: BasePart, rate: number, color: Color3, speed: number): ParticleEmitter
 local p = Instance.new("ParticleEmitter")
 p.Name = "AtmosphericParticles"
 p.Texture = "rbxasset://textures/particles/smoke_main.dds"
 p.Color = ColorSequence.new(color)
 p.Rate = rate
 p.Lifetime = NumberRange.new(0.6, 1.8)
 p.Speed = NumberRange.new(speed * 0.5, speed)
 p.SpreadAngle = Vector2.new(25, 20)
 p.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1.8)})
 p.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.65), NumberSequenceKeypoint.new(1, 1)})
 p.Parent = host
 return p
end

return Kit
