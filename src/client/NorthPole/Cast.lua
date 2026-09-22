--!nonstrict
-- Deterministic, asset-independent R15-compatible articulated cinematic cast.
-- Root is the only anchored part; standard Motor6Ds drive segment transforms.
-- Each pose also evaluates FK immediately so camera focus sees this frame's head.
local Kit=require(script.Parent.Kit)
local Config=require(game:GetService("ReplicatedStorage").Shared.Config)
local RunService=game:GetService("RunService")
local C=require(script.Parent.Env).Colors
local Appearance=require(script.Parent.CharacterAppearance)
local V,CF,A=Vector3.new,CFrame.new,CFrame.Angles
local Cast={}
-- Every rig ever built, so ground raycasts can exclude the whole cast at
-- once: a character must stand on the floor, never on another character.
local builtRigs: {Instance}={}
local groundParams=RaycastParams.new()
groundParams.FilterType=Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater=true

local IS_STUDIO=RunService:IsStudio()
-- Phases where a human is intentionally not upright. Anything else that
-- shows up leaning past the check below is a real bug, not a choice.
local NON_UPRIGHT_PHASES={Brace=true,Stumble=true,Flinch=true,Help=true}
-- How much of the speaking gesture each lead actually uses. See the Speak
-- branch in stepAnimate; anyone not listed keeps the full amplitude.
local GESTURE_RESTRAINT={Hale=0.3,Voss=0.65,Soldier=0.4}
--[[
 How far from vertical an ORDINARY standing/talking torso may be before the
 Studio validator calls it a defect.

 The authored idle and listen poses lean the waist by at most about 12
 degrees, and a deliberate reaction (Brace, Stumble, Flinch, Help) is exempt
 above, so this is a genuine envelope rather than a threshold picked to keep
 the log quiet. It used to be an unnamed `up<0.9`, i.e. nearly 26 degrees -
 loose enough that a visibly hunched character passed.
]]
local MAX_UPRIGHT_DEGREES=16
local uprightWarned={}
-- Small named additive poses. Locomotion, gaze and reactions layer on top.
--[[
 JOINT DIRECTION, derived once and relied on everywhere below.

 This rig faces -Z (Cast.place builds its root with CFrame.lookAt, whose
 LookVector is the frame's -Z, and the face geometry is built at negative Z on
 the head). Every limb segment hangs BELOW its joint pivot, and
 CFrame.Angles(t,0,0) maps a hanging segment's local (0,-1,0) to
 (0,-cos t,-sin t) - i.e. positive t swings it toward -Z, forward.

 Therefore, for this rig:
   * shoulders and elbows raise/bend the arm forward on POSITIVE x;
   * knees bend the heel backward on NEGATIVE x (a positive knee is a
     backwards-bending knee, which is what the cast used to do on every
     single walking frame);
   * ankles lift the toe on POSITIVE x.

 Everything in this file now obeys that. The alien rigs (biomech, further
 down) intentionally do not - they are reverse-jointed and say so.
]]
Cast.PoseLibrary={
 NeutralIdle={Waist=A(0,0,0),LeftShoulder=A(0.02,0,-0.03),RightShoulder=A(0.02,0,0.03)},
 AlertIdle={Waist=A(0.025,0,0),LeftShoulder=A(0.08,0,-0.06),RightShoulder=A(0.1,0,0.06)},
 ResearchIdle={Waist=A(0.015,0,0),LeftShoulder=A(0.16,0,-0.08),RightShoulder=A(0.12,0,0.08)},
 ListeningIdle={Waist=A(0.04,0,0),LeftShoulder=A(0.1,0,-0.03),RightShoulder=A(0.1,0,0.03)},
 Thinking={Waist=A(0.06,0.02,0),LeftShoulder=A(0.3,0,-0.08),RightShoulder=A(0.18,0,0.08)},
 CheckingTablet={Waist=A(0.03,0,0),LeftShoulder=A(0.48,0,-0.12),RightShoulder=A(0.58,0,0.1)},
 Pointing={Waist=A(0,0,0),RightShoulder=A(0.85,0,0.28),RightElbow=A(0.2,0,0)},
 Warning={Waist=A(0.08,0,0),LeftShoulder=A(0.22,0,-0.12),RightShoulder=A(0.2,0,0.12)},
 Brace={Waist=A(0.22,0,0),LeftShoulder=A(1.1,0,-0.13),RightShoulder=A(1.1,0,0.13)},
}
function Cast.applyPose(r,name,weight)
 local pose=Cast.PoseLibrary[name]
 if not pose then return end
 local alpha=weight or 1
 for jointName,target in pose do r.poses[jointName]=(r.poses[jointName] or CF()):Lerp(target,alpha) end
end
export type Human=any
export type AegisHandle=any
export type Creature=any
local function shape(parent,name,size,cf,color,kind,material)
 local fn=kind=="ball" and Kit.ball or kind=="wedge" and Kit.wedge or Kit.part
 local p=fn({name=name,size=size,cframe=cf,color=color,material=material or Enum.Material.SmoothPlastic,shadow=true})
 p.Parent=parent
 return p
end
local function rig(parent,name,cf)
 local m=Kit.model(name,parent)
 table.insert(builtRigs,m)
 local root=shape(m,"HumanoidRootPart",V(1,1,1),cf,C.dark)
 root.Transparency=1;root.CanQuery=false;m.PrimaryPart=root
 local controller=Instance.new("AnimationController");controller.Parent=m
 Instance.new("Animator").Parent=controller
 return {model=m,root=root,joints={},order={},rigid={},rest={},poses={},applied={},target={},eyes={},clock=0,scale=1,expression="Focused",blend=0.22}
end
--[[
 A decoration rigidly fixed to `host` (hair, collar, belt, a rifle). The
 WeldConstraint is kept so the part reads as attached in the explorer and so
 anything that reparents a rig still moves as one piece, but the part is
 re-ANCHORED afterwards and its world CFrame is driven explicitly from
 `r.rigid` in Cast.evaluate. See the note there for why nothing in a
 cinematic rig may be left unanchored.
]]
local function attach(r,host,name,size,offset,color,kind,material)
 local p=shape(r.model,name,size,host.CFrame*offset,color,kind,material)
 Kit.weld(host,p)
 p.Anchored=true
 table.insert(r.rigid,{part=p,host=host,offset=offset})
 return p
end
local function joint(r,host,name,jointName,size,offset,pivot,color,kind,material)
 local p=shape(r.model,name,size,host.CFrame*offset*pivot:Inverse(),color,kind,material)
 local m=Kit.joint(jointName,host,p,offset,pivot)
 -- Kit.joint unanchors its Part1, because that is what a PHYSICALLY jointed
 -- rig needs. This rig is not one: Cast.evaluate solves the whole chain in
 -- script and writes world CFrames itself, so the part is re-anchored here.
 -- Leaving it unanchored made every rig share one physics assembly, and
 -- writing a member's CFrame moves the WHOLE assembly - so each joint write
 -- dragged the rig (root included) a little further every frame. Measured in
 -- Studio: the command-room leads climbed from y=3 to y=30 and tumbled past
 -- upside down over one conversation, with zero velocity and an anchored
 -- root, which is exactly the signature of assembly dragging rather than
 -- simulation.
 p.Anchored=true
 r.joints[jointName]=m;r.rest[jointName]=offset
 table.insert(r.order,m)
 return p
end
-- Hard safety envelope for human joints only (r.human), applied AFTER every
-- pose source (idle, look, gesture, reaction) has already been combined into
-- r.poses[name], so no combination of layered offsets - however they were
-- authored - can ever land a joint outside a believable human range. This is
-- a last-line-of-defense clamp, not the primary source of natural motion:
-- individual poses above already author well inside these numbers. Values
-- are outer bounds in radians, (yaw, pitch, roll) matching this file's own
-- CFrame.Angles(x,y,z) = (pitch, yaw, roll) convention. Never applied to the
-- alien/mecha rigs (they never set r.human), which intentionally move well
-- outside human ranges.
local JOINT_LIMITS={
 Neck={math.rad(30),math.rad(58),math.rad(12)},
 Waist={math.rad(28),math.rad(22),math.rad(10)},
 LeftShoulder={math.rad(100),math.rad(70),math.rad(100)},
 RightShoulder={math.rad(100),math.rad(70),math.rad(100)},
 LeftElbow={math.rad(155),math.rad(20),math.rad(20)},
 RightElbow={math.rad(155),math.rad(20),math.rad(20)},
 LeftWrist={math.rad(45),math.rad(45),math.rad(45)},
 RightWrist={math.rad(45),math.rad(45),math.rad(45)},
 LeftHip={math.rad(45),math.rad(35),math.rad(35)},
 RightHip={math.rad(45),math.rad(35),math.rad(35)},
 LeftKnee={math.rad(115),math.rad(10),math.rad(10)},
 RightKnee={math.rad(115),math.rad(10),math.rad(10)},
 LeftAnkle={math.rad(50),math.rad(20),math.rad(20)},
 RightAnkle={math.rad(50),math.rad(20),math.rad(20)},
 Root={math.rad(20),math.rad(20),math.rad(20)},
}
local function clampJoint(name,cf)
 local limit=JOINT_LIMITS[name]
 if not limit then return cf end
 local rx,ry,rz=cf:ToOrientation()
 return CFrame.new(cf.Position)*A(math.clamp(rx,-limit[1],limit[1]),math.clamp(ry,-limit[2],limit[2]),math.clamp(rz,-limit[3],limit[3]))
end
--------------------------------------------------------------------------------
-- GROUNDING
--
-- Every Y position in Sequences.lua/Env.lua was authored as a constant (2.8,
-- 2.95, 3.1 ...) against a rig whose root sits 2.81 studs above its own soles
-- at scale 1. Two things break that:
--
--   * scale. Voss is 1.06, Hale 1.12, the scientists 0.92-1.04, the soldiers
--     0.96-1.10. At 1.12 the soles are 3.15 below the root, so a character
--     authored at 3.1 sank; at 0.92 they are 2.59 below it, so that character
--     floated a third of a stud.
--   * the Arctic floor is not flat. It is a field of overlapping snow balls
--     whose surface varies by several studs, so NO single constant is right
--     across it.
--
-- So nothing assumes a height any more: the sole-to-root distance is measured
-- off the built rig, and the floor under each character is found by raycast.
-- Every cinematic rig is excluded from that raycast, so a person can never
-- end up standing on another person's shoulder or on Aegis Zero's foot.
--------------------------------------------------------------------------------

-- Distance the ground search looks up/down from the expected floor. Generous
-- enough for drifted snow, tight enough that a character over a stairwell
-- keeps their authored height instead of dropping to a floor far below.
local GROUND_UP,GROUND_DOWN=14,26
--[[
 How far ABOVE the author's own hint a surface may be and still count as the
 floor that hint meant.

 The ray has to start well above the mark (a ray that starts inside a snow
 drift reports no hit at all), which means indoors it starts above the
 ceiling - and a ceiling is a solid, query-able, downward-facing surface like
 any other. Without this, every character in the command room "stood" on the
 roof slab 12.4 studs over the room they were supposed to be talking in, and
 the camera, which is placed from their heads, went up there with them.

 4 studs is well over the ~1.3 the Arctic drifts actually vary by at any
 authored mark (measured across the built set, not guessed) and well under
 the height of any room in this cinematic, so the check separates "the ground
 is a bit higher here than the author assumed" from "that is the ceiling".
]]
local STANDABLE_RISE=4

function Cast.soleDrop(r): number
 return r.soleDropValue or 2.81*(r.scale or 1)
end

-- Distance the whole rig must move vertically for its LOWER sole to rest
-- exactly on r.floorY. Positive lifts, negative sinks.
function Cast.footCorrection(r): number
 local left=r.model:FindFirstChild("LeftFoot")
 local right=r.model:FindFirstChild("RightFoot")
 if not (left and right and r.floorY) then return 0 end
 local soleL=left.Position.Y-left.Size.Y/2
 local soleR=right.Position.Y-right.Size.Y/2
 return math.clamp(r.floorY-math.min(soleL,soleR),-0.6,0.6)
end
--[[
 The real floor under (x,z), for a character whose author expected it at
 `expected`.

 Casts down from above and walks PAST anything too high overhead to be stood
 on - ceiling slabs, roof trusses, cable trays, gantries - resuming the ray
 just under each one, so an interior returns its floor rather than its roof.
 Falls back to the author's own hint if the search runs out of surfaces,
 which is the only honest answer when nothing solid is there at all.
]]
function Cast.floorUnder(r,x: number,z: number,expected: number): number
 groundParams.FilterDescendantsInstances=builtRigs
 local ceiling=expected+STANDABLE_RISE
 local from=V(x,expected+GROUND_UP,z)
 local bottom=expected-GROUND_DOWN
 -- Bounded: each pass must start strictly lower than the last, so this
 -- terminates on the ray length even if a set is built from many thin
 -- stacked slabs.
 for _=1,8 do
  local length=from.Y-bottom
  if length<=0 then break end
  local hit=workspace:Raycast(from,V(0,-length,0),groundParams)
  if not hit then break end
  if hit.Position.Y<=ceiling then return hit.Position.Y end
  from=V(x,hit.Position.Y-0.05,z)
 end
 return expected
end

--[[
 Solve the whole rig, in one pass, from the root outwards.

 `r.order` is in creation order, which is parent-before-child, so every
 Part0 below has already been placed this call. Every part in the rig is
 ANCHORED (see `joint`/`attach`), which is what makes writing world CFrames
 here safe: on an unanchored, jointed rig Roblox treats each part as a member
 of one physics assembly and moving a member moves the assembly, so a
 per-joint CFrame write silently transports the entire character.

 `m.Transform` is still written so the joint's own state matches what was
 rendered - anything inspecting the rig in Studio, and Cast.evaluate's own
 blend on the next call, reads the same value the frame actually used.
]]
function Cast.evaluate(r)
 for _,m in r.order do
  -- Preserve authored C0/C1. Transform is the additive performance layer,
  -- blended so dialogue reactions never snap at a shot boundary.
  local target=r.poses[m.Name] or CF()
  if r.human then target=clampJoint(m.Name,target) end
  local previous=r.applied[m.Name] or m.Transform or CF()
  local alpha=if r.applied[m.Name] then (r.blend or 0.22) else 1
  local value=previous:Lerp(target,alpha)
  r.applied[m.Name]=value
  m.Transform=value
  m.Part1.CFrame=m.Part0.CFrame*m.C0*value*m.C1:Inverse()
 end
 -- Welded decoration follows its host explicitly, for the same reason: an
 -- anchored host cannot drag an anchored child, and a WeldConstraint between
 -- two anchored parts does nothing. Creation order is parent-first here too.
 for _,entry in r.rigid do
  entry.part.CFrame=entry.host.CFrame*entry.offset
 end
end
function Cast.pose(r,name,cf)
 r.poses[name]=cf
end
--[[
 THE FACE, parameterised.

 Still the same flat block language: two eyes, two pupils, two brows and a
 mouth, no spherical sockets, no nose, no lips, no ears. What changed is that
 the numbers come from a face preset rather than being the same seven
 literals on all twenty-four heads. The spread between presets is a few
 hundredths of a stud on purpose - far enough that the leads are not the same
 face, nowhere near far enough to become caricature.
]]
local function face(r,skin,hair,metrics)
 local h=r.head;local s=r.scale
 local function detail(name,size,offset,color)
  return attach(r,h,name,size*s,CF(offset*s),color)
 end
 r.face={brows={},mouthWidth=metrics.mouthWidth}
 for _,side in {-1,1} do
  detail("Eye",V(metrics.eyeWidth,metrics.eyeHeight,0.02),V(side*metrics.eyeSpacing,0.05,-0.395),Color3.fromRGB(245,245,240))
  detail("Pupil",V(metrics.eyeWidth*0.44,metrics.eyeHeight*0.5,0.015),V(side*metrics.eyeSpacing,0.04,-0.403),C.dark)
  local brow=detail("Brow",V(metrics.browWidth,metrics.browThickness,0.02),V(side*metrics.eyeSpacing,metrics.browHeight,-0.39),hair)
  --[[
   The brow's RIGID ENTRY, not just its part.

   stepAnimate has always computed a per-expression brow tilt and then written
   it to a `SetAttribute("ExpressionTilt",...)` that nothing anywhere read, so
   every angry, sad and frightened face in the cinematic has been rendering
   with perfectly level eyebrows. Holding the entry (and its rest offset)
   lets that existing calculation drive the actual geometry, which is a
   two-line fix to a dead feature rather than a new animation system.
  ]]
  local entry=r.rigid[#r.rigid]
  table.insert(r.face.brows,{part=brow,side=side,entry=entry,base=entry.offset,rest=metrics.browTilt})
 end
 r.face.mouth=detail("Mouth",V(metrics.mouthWidth,0.04,0.02),V(0,-0.2,-0.39),skin:Lerp(C.dark,0.55))
end
-- A hair/headwear piece's offset is authored at scale 1; only its POSITION
-- scales with the character, never its rotation.
local function scaledOffset(cf,s)
 local at=cf.Position
 return CF(at.X*s,at.Y*s,at.Z*s)*(cf-at)
end
local function buildPieces(r,host,pieces,colour)
 for _,piece in pieces do
  attach(r,host,piece.name,piece.size*r.scale,scaledOffset(piece.at,r.scale),colour,piece.kind)
 end
end
--[[
 EQUIPMENT, chosen by role instead of issued to everybody.

 Every human used to be built with the same TranslationScanner in the same
 hand and the same ExpeditionPack on the same back - the senior officer
 included - which is most of the clone effect on its own: twenty-four
 identical silhouettes carrying identical kit. Now a profile lists what its
 person carries, four of the eight scientists carry nothing at all, and the
 things people do carry break their outline in different places: Lyra's
 scanner is low and forward, Voss's tablet is held in close, Hale's rifle is
 a long horizontal across his hip.

 Each entry is a handful of parts. Order matters: anything attached to
 another accessory must be attached AFTER it, because Cast.evaluate walks
 r.rigid in insertion order and a child read before its parent would lag a
 frame behind.
]]
local EQUIPMENT={}
EQUIPMENT.Scanner=function(r,p)
 local s=r.scale
 r.scanner=attach(r,r.hands.Left,"TranslationScanner",V(0.5,0.12,0.7)*s,CF(0,-0.06*s,-0.24*s)*A(-0.3,0,0),C.metal)
 attach(r,r.scanner,"ScannerScreen",V(0.38,0.02,0.5)*s,CF(0,0.07*s,0),C.cyan,nil,Enum.Material.Neon)
end
EQUIPMENT.Tablet=function(r,p)
 local s=r.scale
 local slab=attach(r,r.hands.Left,"FieldTablet",V(0.44,0.06,0.6)*s,CF(0,-0.05*s,-0.2*s)*A(-0.4,0,0),C.metal)
 attach(r,slab,"TabletScreen",V(0.34,0.02,0.48)*s,CF(0,0.05*s,0),C.cyan,nil,Enum.Material.Neon)
end
EQUIPMENT.Radio=function(r,p)
 local s=r.scale
 local radio=attach(r,p.lower,"BeltRadio",V(0.2,0.32,0.15)*s,CF(-0.52*s,0.34*s,-0.16*s),C.dark)
 attach(r,radio,"RadioAntenna",V(0.04,0.32,0.04)*s,CF(0,0.3*s,0),C.metal)
end
EQUIPMENT.HipPouch=function(r,p)
 attach(r,p.lower,"HipPouch",V(0.3,0.3,0.22)*r.scale,CF(0.56*r.scale,0.3*r.scale,0.08*r.scale),p.profile.trim)
end
-- A strap, not a pack: it crosses the chest diagonally, so it reads on a
-- front-on silhouette without adding a slab to the back the way the old
-- universal ExpeditionPack did.
EQUIPMENT.ShoulderStrap=function(r,p)
 attach(r,p.torso,"ShoulderStrap",V(0.16,1.3,0.1)*r.scale,CF(-0.3*r.scale,0.05*r.scale,-0.47*r.scale)*A(0,0,0.26),p.profile.trim)
end
EQUIPMENT.SmallPack=function(r,p)
 local s=r.scale
 attach(r,p.torso,"FieldPack",V(0.78,0.8,0.36)*s,CF(0,-0.05*s,0.55*s),C.metal)
end
EQUIPMENT.ToolRoll=function(r,p)
 attach(r,p.lower,"ToolRoll",V(0.5,0.22,0.2)*r.scale,CF(0,0.36*r.scale,0.44*r.scale),C.dark)
end
EQUIPMENT.ToolCase=function(r,p)
 local s=r.scale
 local case=attach(r,r.hands.Right,"ToolCase",V(0.48,0.42,0.28)*s,CF(0,-0.34*s,0),C.metal)
 attach(r,case,"CaseLatch",V(0.5,0.06,0.06)*s,CF(0,0.08*s,-0.15*s),p.profile.trim)
end
EQUIPMENT.ToolBelt=function(r,p)
 local s=r.scale
 attach(r,p.lower,"ToolBelt",V(1.5*p.width,0.24,0.92*p.width)*s,CF(0,0.34*s,0),C.dark)
 for _,side in {-1,1} do
  attach(r,p.lower,"ToolLoop",V(0.16,0.3,0.14)*s,CF(side*0.5*s,0.2*s,-0.3*s),p.profile.trim)
 end
end
EQUIPMENT.CableCoil=function(r,p)
 attach(r,p.lower,"CableCoil",V(0.5,0.5,0.18)*r.scale,CF(0.5*r.scale,0.3*r.scale,0.3*r.scale),C.dark)
end
EQUIPMENT.HelmetLamp=function(r,p)
 local s=r.scale
 local lamp=attach(r,r.head,"HelmetLamp",V(0.18,0.14,0.14)*s,CF(0,0.34*s,-0.44*s),C.metal)
 attach(r,lamp,"LampLens",V(0.12,0.1,0.03)*s,CF(0,0,-0.08*s),C.warm,nil,Enum.Material.Neon)
end
EQUIPMENT.KneePads=function(r,p)
 for _,side in {"Left","Right"} do
  local shin=r.model:FindFirstChild(side.."LowerLeg")
  if shin then attach(r,shin,"KneePad",V(0.58,0.3,0.6)*r.scale,CF(0,0.4*r.scale,-0.04*r.scale),C.dark) end
 end
end
-- A hi-vis tabard. One flat panel front and back rather than a second shell
-- wrapped round the whole torso.
EQUIPMENT.Vest=function(r,p)
 local s=r.scale
 attach(r,p.torso,"WorkVestFront",V(1.12*p.width,0.94,0.1)*s,CF(0,0,-0.47*s),p.profile.trim)
 attach(r,p.torso,"WorkVestBack",V(1.12*p.width,0.94,0.1)*s,CF(0,0,0.47*s),p.profile.trim)
 -- Shoulder straps close the loop over the top of the torso, which is what
 -- separates a worn vest from a panel leaning against somebody's chest.
 for _,side in {-1,1} do
  attach(r,p.torso,"VestStrap",V(0.24,0.2,1.0)*s,CF(side*0.42*s,0.56*s,0),p.profile.trim)
 end
 attach(r,p.torso,"VestStripe",V(1.14*p.width,0.1,0.12)*s,CF(0,-0.3*s,-0.47*s),C.ivory)
end
EQUIPMENT.Webbing=function(r,p)
 local s=r.scale
 attach(r,p.torso,"Webbing",V(1.6*p.width,0.3,0.98*p.width)*s,CF(0,-0.15*s,0),C.dark)
 for _,side in {-1,1} do
  attach(r,p.torso,"AmmoPouch",V(0.26,0.28,0.16)*s,CF(side*0.4*s,-0.14*s,-0.5*s),C.metal)
 end
end
EQUIPMENT.NeckGuard=function(r,p)
 attach(r,p.torso,"NeckGuard",V(0.8,0.34,0.7)*r.scale,CF(0,0.66*r.scale,0.02*r.scale),C.dark)
end
EQUIPMENT.ChestPlate=function(r,p)
 local s=r.scale
 attach(r,p.torso,"ChestPlate",V(1.55*p.width,1.05,0.2)*s,CF(0,0.12*s,-0.46*s),C.metal)
 attach(r,p.torso,"PlateRidge",V(0.2,1.0,0.1)*s,CF(0,0.12*s,-0.56*s),C.dark)
end
-- The single strongest broad-shoulder cue in the set: a yoke across the top
-- of the torso plus a cap on each upper arm.
EQUIPMENT.ShoulderYoke=function(r,p)
 local s=r.scale
 attach(r,p.torso,"ShoulderYoke",V(2.05*p.width,0.26,1.0*p.width)*s,CF(0,0.48*s,0.02*s),p.profile.coat)
 -- The yoke's lower edge is defined by VALUE, not hue. In the accent colour
 -- it crossed the coat placket and the two together read as a heraldic red
 -- cross on the chest - obvious the moment it was seen under the command
 -- room's warm key, and invisible in a flat offline render.
 attach(r,p.torso,"YokeEdge",V(2.07*p.width,0.07,1.02*p.width)*s,CF(0,0.36*s,0.02*s),p.profile.coat:Lerp(C.dark,0.6))
 for _,side in {"Left","Right"} do
  local arm=r.model:FindFirstChild(side.."UpperArm")
  if arm then attach(r,arm,"ShoulderCap",V(0.72,0.3,0.7)*s,CF(0,0.42*s,0),p.profile.coat,"wedge") end
 end
end
EQUIPMENT.RankMarker=function(r,p)
 local s=r.scale
 attach(r,p.torso,"RankPlate",V(0.3,0.16,0.06)*s,CF(-0.46*s,0.3*s,-0.47*s),p.profile.accent or p.profile.trim)
 attach(r,p.torso,"RankBar",V(0.3,0.06,0.06)*s,CF(-0.46*s,0.12*s,-0.47*s),p.profile.accent or p.profile.trim)
end
EQUIPMENT.HeavyBelt=function(r,p)
 local s=r.scale
 attach(r,p.lower,"CommandBelt",V(1.52*p.width,0.3,0.94*p.width)*s,CF(0,0.34*s,0),C.dark)
 attach(r,p.lower,"BeltBuckle",V(0.26,0.26,0.1)*s,CF(0,0.34*s,-0.48*s),p.profile.accent or C.ivory)
 attach(r,p.lower,"SidearmHolster",V(0.26,0.42,0.22)*s,CF(0.5*s,0.1*s,0.06*s),C.dark)
end
local function rifle(r,host,offset)
 local s=r.scale
 r.weapon=attach(r,host,"ExpeditionRifle",V(0.18,0.26,1.2)*s,offset,C.metal)
 attach(r,r.weapon,"Barrel",V(0.1,0.1,0.6)*s,CF(0,0,-0.75*s),C.dark)
 attach(r,r.weapon,"Stock",V(0.22,0.36,0.4)*s,CF(0,-0.05*s,0.65*s),C.dark)
end
-- Slung across the hip: a long horizontal, which is a completely different
-- silhouette cue to a rifle held in the hands.
EQUIPMENT.SlungRifle=function(r,p)
 rifle(r,p.lower,CF(0.2*r.scale,-0.1*r.scale,-0.5*r.scale)*A(0,0,0.34))
end
EQUIPMENT.Rifle=function(r,p)
 rifle(r,r.hands.Right,CF(0.06*r.scale,-0.3*r.scale,-0.3*r.scale))
end
EQUIPMENT.Scarf=function(r,p)
 local s=r.scale
 attach(r,p.torso,"ScarfWrap",V(1.0,0.32,0.98)*s,CF(0,0.5*s,0),p.profile.trim)
 attach(r,p.torso,"ScarfTail",V(0.4,0.9,0.14)*s,CF(-0.25*s,0.1*s,-0.48*s),p.profile.trim,"wedge")
end
--[[
 OUTFITS - the small set of accent pieces that says what somebody does.

 The body blocks are ALREADY coloured as worn clothing (coat on torso and
 arms, trousers on legs, dark on hands and feet), so these are a few
 silhouette-defining pieces on top, never a second bulky shell over the
 whole R15 body.
]]
local function collar(r,p,size,colour)
 attach(r,p.torso,"Collar",V(size*p.width,0.16,0.92*p.width)*r.scale,CF(0,0.58*r.scale,0),colour,"wedge")
end
local function chestBadge(r,p,colour)
 attach(r,p.torso,"ChestBadge",V(0.22,0.22,0.05)*r.scale,CF(0.45*r.scale,0.15*r.scale,-0.46*r.scale),colour)
end
local function slimBelt(r,p)
 local s=r.scale
 attach(r,p.lower,"UtilityBelt",V(1.44*p.width,0.18,0.88*p.width)*s,CF(0,0.38*s,0),C.dark)
 attach(r,p.lower,"BeltBuckle",V(0.2,0.2,0.08)*s,CF(0,0.38*s,-0.44*s),C.ivory)
end
local OUTFITS={
 LeadResearcher=function(r,p)
  collar(r,p,1.56,p.profile.trim)
  -- A small scientific identifier, not the generic badge everyone wore.
  attach(r,p.torso,"FieldIdTag",V(0.3,0.14,0.05)*r.scale,CF(0.42*r.scale,0.26*r.scale,-0.46*r.scale),p.profile.trim)
  slimBelt(r,p)
 end,
 Researcher=function(r,p) collar(r,p,1.5,p.profile.trim);chestBadge(r,p,p.profile.trim);slimBelt(r,p) end,
 -- Cleanest front in the cinematic: no badge, no pouches. The scarf is the
 -- only thing interrupting it, which is what makes it read as deliberate.
 Analyst=function(r,p) collar(r,p,1.46,p.profile.trim);slimBelt(r,p) end,
 Commander=function(r,p)
  attach(r,p.torso,"StandingCollar",V(0.92,0.36,0.86)*r.scale,CF(0,0.62*r.scale,0.02*r.scale),p.profile.coat)
  attach(r,p.torso,"CoatPlacket",V(0.16,1.2,0.1)*r.scale,CF(0,0.05*r.scale,-0.47*r.scale),p.profile.accent or p.profile.trim)
 end,
 Technician=function(r,p) collar(r,p,1.5,p.profile.trim);chestBadge(r,p,p.profile.trim);slimBelt(r,p) end,
 FieldWorker=function(r,p) collar(r,p,1.5,C.dark) end,
 Security=function(r,p) attach(r,p.torso,"ArmourCollar",V(1.0,0.3,0.94)*r.scale,CF(0,0.6*r.scale,0),C.dark) end,
}
local EYEWEAR={
 -- Two lenses, thin and rectangular: Voss and the analysts.
 Glasses=function(r,p)
  local s=r.scale
  for _,side in {-1,1} do
   local glass=attach(r,r.head,"OpticalLens",V(0.28,0.13,0.05)*s,CF(side*0.17*s,0.05*s,-0.4*s),C.cyan)
   glass.Material=Enum.Material.Glass;glass.Transparency=0.62;glass.CanQuery=false
  end
  attach(r,r.head,"GlassesBridge",V(0.1,0.03,0.04)*s,CF(0,0.05*s,-0.4*s),C.metal)
 end,
 -- ONE temple lens on ONE side. Lyra and Voss used to wear identical cyan
 -- pairs, so the two scientists in the command room read as a matched set
 -- from any distance; this is asymmetric, so it also helps her three-quarter
 -- outline.
 ARLens=function(r,p)
  local s=r.scale
  local lens=attach(r,r.head,"ARLens",V(0.2,0.1,0.04)*s,CF(-0.17*s,0.07*s,-0.405*s),C.cyan)
  lens.Material=Enum.Material.Glass;lens.Transparency=0.5;lens.CanQuery=false
  attach(r,r.head,"ARTemple",V(0.06,0.05,0.34)*s,CF(-0.39*s,0.08*s,-0.22*s),C.metal)
 end,
 Goggles=function(r,p)
  local s=r.scale
  attach(r,r.head,"GoggleStrap",V(0.9,0.16,0.88)*s,CF(0,0.07*s,0.01*s),C.dark)
  local lens=attach(r,r.head,"GoggleLens",V(0.62,0.18,0.08)*s,CF(0,0.07*s,-0.41*s),C.cyan)
  lens.Material=Enum.Material.Glass;lens.Transparency=0.45;lens.CanQuery=false
 end,
 -- Pushed up onto the forehead: the face stays readable and the character
 -- still reads as someone who works outdoors.
 GogglesUp=function(r,p)
  local s=r.scale
  attach(r,r.head,"GoggleStrap",V(0.88,0.14,0.86)*s,CF(0,0.3*s,0.01*s),C.dark)
  attach(r,r.head,"GoggleLens",V(0.58,0.16,0.08)*s,CF(0,0.3*s,-0.4*s),C.metal)
 end,
}
-- R15-standard segmentation and proportions, built directly as the visible
-- body (no separate invisible "carrier" skeleton hidden under a second shell
-- layer - the block IS the character). At scale 1: head ~15% of standing
-- height, shoulder width ~2.25 head-widths, legs ~48% of standing height,
-- relaxed hands fall to roughly upper/mid-thigh. Segments meet directly at
-- each joint pivot; nothing decorative sits at a shoulder, elbow, hip, knee
-- or ankle.
--
-- BODY STYLE IS WIDTH ONLY. Every joint offset, pivot and limb LENGTH below
-- is identical for all four builds, because the animation system - sole drop,
-- knee and elbow bend direction, hand-clear-of-torso, the upright validator -
-- was stabilised against this exact geometry. A silhouette pass earns a few
-- percent of torso and arm thickness plus some overlay geometry, and nothing
-- else.
function Cast.buildHuman(parent,spec): Human
 local profile=spec.profile
 local r=rig(parent,spec.name,spec.cframe)
 r.scale=profile.scale;r.kind=spec.kind or "Scientist";r.coat=profile.coat;r.human=true
 r.profile=profile
 r.animState={moving=false,phase="Idle",seed=spec.seed or 0,activity="Research",activityAt=0,activityIndex=1,reactionUntil=0}
 local s=r.scale
 local body=Appearance.body(profile.bodyStyle)
 local tw,aw=body.torsoWidth,body.armWidth
 local function j(host,name,motor,size,offset,pivot,color,kind)
  return joint(r,host,name,motor,size*s,CF(offset*s),CF(pivot*s),color,kind,Enum.Material.SmoothPlastic)
 end
 -- The 0.31-stud offset here (not zero) is load-bearing: it makes this R15
 -- rig's root-to-sole distance match the pre-rebuild rig's (verified by
 -- hand: 2.81 studs at scale 1), which is what every hardcoded Y position
 -- throughout Sequences.lua/Env.lua was authored against.
 local lower=j(r.root,"LowerTorso","Root",V(1.4*tw,0.8,0.85),V(0,0.31,0),V(0,0,0),profile.coat)
 local torso=j(lower,"UpperTorso","Waist",V(1.8*tw,1.3,0.9),V(0,0.4,0),V(0,-0.65,0),profile.coat)
 r.torso=torso
 local head=j(torso,"Head","Neck",V(0.8,0.85,0.8),V(0,0.65,0),V(0,-0.425,0),profile.skin)
 r.head=head
 face(r,profile.skin,profile.hairColor,Appearance.face(profile.faceStyle))
 buildPieces(r,head,Appearance.hair(profile.hairStyle),profile.hairColor)
 if profile.headwear then
  buildPieces(r,head,Appearance.headwear(profile.headwear),profile.headwear=="Hood" and profile.coat or profile.trim)
 end
 -- Hale's jaw shadow: one small dark block low on the head, well under the
 -- albedo budget's "facial detail" size. Not a beard, not anatomy - the same
 -- trick a stylized avatar uses to age a face by a decade.
 if profile.faceStyle=="Mature" then
  attach(r,head,"JawShadow",V(0.62,0.16,0.12)*s,CF(0,-0.3*s,-0.36*s),profile.skin:Lerp(C.dark,0.42))
 end
 local eyewear=profile.eyewear and EYEWEAR[profile.eyewear]
 if eyewear then eyewear(r,{profile=profile}) end
 r.hands={}
 for _,side in {-1,1} do
  local prefix=side<0 and "Left" or "Right"
  local arm=j(torso,prefix.."UpperArm",prefix.."Shoulder",V(0.55*aw,1.05,0.55*aw),V(side*0.85,0.5,0),V(0,0.525,0),profile.coat)
  local fore=j(arm,prefix.."LowerArm",prefix.."Elbow",V(0.48*aw,0.85,0.48*aw),V(0,-0.525,0),V(0,0.425,0),profile.coat)
  local hand=j(fore,prefix.."Hand",prefix.."Wrist",V(0.45,0.42,0.25),V(0,-0.425,0),V(0,0.21,0),C.dark)
  r.hands[prefix]=hand
  local heavyGlove=profile.outfitStyle=="FieldWorker" or profile.outfitStyle=="Security"
  attach(r,fore,"GloveCuff",V(heavyGlove and 0.6 or 0.52,heavyGlove and 0.2 or 0.14,heavyGlove and 0.6 or 0.52)*s,CF(0,-0.34*s,0),profile.trim,"wedge")
  local thigh=j(lower,prefix.."UpperLeg",prefix.."Hip",V(0.65,1.25,0.65),V(side*0.55,-0.4,0),V(0,0.625,0),profile.pants)
  local shin=j(thigh,prefix.."LowerLeg",prefix.."Knee",V(0.55,1.15,0.55),V(0,-0.625,0),V(0,0.575,0),profile.pants)
  local foot=j(shin,prefix.."Foot",prefix.."Ankle",V(0.6,0.35,0.95),V(0,-0.575,0),V(0,0.145,0.28),C.dark)
  attach(r,foot,"BootCuff",V(0.62,0.14,0.6)*s,CF(0,0.16*s,0.05*s),profile.trim,"wedge")
 end
 local p={torso=torso,lower=lower,profile=profile,width=tw}
 local outfit=OUTFITS[profile.outfitStyle]
 if outfit then outfit(r,p) end
 for _,item in profile.equipment do
  local build=EQUIPMENT[item]
  if build then build(r,p) end
 end
 Cast.evaluate(r)
 -- Measured, never assumed: with the rest pose evaluated the feet are flat,
 -- so root-Y minus the sole's Y IS the number every placement needs.
 local soleFoot=r.model:FindFirstChild("LeftFoot")
 r.soleDropValue=if soleFoot then r.root.Position.Y-(soleFoot.Position.Y-soleFoot.Size.Y/2) else 2.81*s
 local origin=spec.cframe.Position
 Cast.place(r,origin,origin+spec.cframe.LookVector*4)
 return r
end
local N=Config.Cinematic.Names
--[[
 THE ALBEDO BUDGET, and why it is written down rather than eyeballed.

 A Roblox surface's final pixel is roughly its own colour times the light
 reaching it. In the command room that light is a warm ceiling spot plus a
 neutral ambient fill, and their sum is comfortably over 1.0 - which is
 correct, and is what makes the room feel lit. It also means the colour is
 what decides whether a surface clips to white.

 The lab walls were deliberately taken down to 126-150 for this reason. The
 coats were not, and at 178 they were BRIGHTER THAN THE WALLS: the people
 were the palest thing in their own room, which is most of "the characters'
 heads become glowing bright shapes" before a single light is blamed. So:

   * no garment above ~0.60 value (152). A field parka is worn canvas, not
     laboratory white.
   * no skin above ~0.80 (204). Roblox skin tones run light and the warmest
     of them was 225, which cannot survive a warm key.
   * the brightest thing in any frame should be a light source - a screen, a
     lamp lens, a beacon - never a person.

 CharacterAppearance.lua's palette is authored inside this budget, and
 tools/castcheck enforces it on every rig that is actually built.
]]
function Cast.buildLyra(parent,cf)
 return Cast.buildHuman(parent,{name=N.Lyra,kind="Lyra",cframe=cf,profile=Appearance.lead("Lyra")})
end
function Cast.buildVoss(parent,cf)
 return Cast.buildHuman(parent,{name=N.Voss,kind="Voss",cframe=cf,profile=Appearance.lead("Voss")})
end
function Cast.buildHale(parent,cf)
 return Cast.buildHuman(parent,{name=N.Hale,kind="Hale",cframe=cf,profile=Appearance.lead("Hale")})
end
-- Background identity is INDEXED, never randomised: scientist 3 has the same
-- curls, the same build and the same kit on every replay, so the audience can
-- learn a face instead of watching the room reshuffle itself. `rng` is still
-- accepted (callers pass one) and deliberately unused for appearance.
function Cast.buildScientist(parent,cf,rng,index)
 return Cast.buildHuman(parent,{name=`Scientist{index}`,seed=index,kind="Scientist",cframe=cf,profile=Appearance.scientist(index)})
end
function Cast.buildSoldier(parent,cf,rng,index)
 return Cast.buildHuman(parent,{name=`Soldier{index}`,seed=index+12,kind="Soldier",cframe=cf,profile=Appearance.soldier(index)})
end
function Cast.buildWorker(parent,cf,index)
 return Cast.buildHuman(parent,{name=`ExcavationWorker{index}`,seed=index+30,kind="Worker",cframe=cf,profile=Appearance.worker(index)})
end
-- Called once per cinematic build. Without it the raycast exclusion list
-- would keep growing across replays with models that no longer exist.
function Cast.reset()
 table.clear(builtRigs)
 table.clear(uprightWarned)
end
function Cast.lookAt(r,target)
 if r.lookTarget~=target then r.lookChangedAt=os.clock() end
 r.lookTarget=target
end
function Cast.setWalking(r,moving) r.animState.moving=moving end
function Cast.act(r,action,expression,target)
 r.animState.phase=action or "Idle";r.expression=expression or "Focused";r.lookTarget=target
 if r.lastAction~=action then r.animState.actionAt=os.clock();r.lookChangedAt=os.clock();r.lastAction=action end
 r.animState.reactionUntil=if action=="Stumble" or action=="Flinch" or action=="StepBack" then os.clock()+0.65 else 0
end
function Cast.setActivity(r,activity)
 r.animState.activity=activity;r.animState.phase="Operate";r.animState.activityIndex=1
 r.animState.activityAt=os.clock()+((r.animState.seed%17)/17)*1.8
end
function Cast.react(r,expression,target,intensity)
 local level=intensity or 1
 r.lookTarget=target;r.expression=expression or "Concerned"
 r.animState.phase=if level>=0.85 then "Stumble" elseif level>=0.45 then "Flinch" else "Listen"
 r.animState.actionAt=os.clock();r.animState.reactionUntil=os.clock()+0.35+0.3*level
end
--[[
 Stands `r` at `pos`, facing `target`.

 The Y of `pos` is treated as a HINT (roughly where the author expected the
 floor to be), not as the answer: the real floor is found by raycast and the
 root is then placed exactly one sole-drop above it, so both feet touch. The
 root is built with CFrame.lookAt on a horizontal target, so it carries yaw
 and nothing else - a character cannot end up pitched or rolled by placement.

 Walking re-places every frame, so the ground height is smoothed while the
 character is travelling (otherwise crossing the snow drifts bobs them), and
 snapped whenever they are moved somewhere genuinely different.
]]
function Cast.place(r,pos,target)
 local y=pos.Y
 if r.human then
  local drop=Cast.soleDrop(r)
  local expected=pos.Y-drop
  local floor=Cast.floorUnder(r,pos.X,pos.Z,expected)
  local previous=r.root.Position
  local jumped=(V(previous.X,0,previous.Z)-V(pos.X,0,pos.Z)).Magnitude>3 or r.floorY==nil
  if jumped then
   r.floorY=floor
  else
   r.floorY+=(floor-r.floorY)*0.3
  end
  y=r.floorY+drop
 end
 local at=V(pos.X,y,pos.Z)
 r.root.CFrame=CFrame.lookAt(at,V(target.X,y,target.Z))
 Cast.evaluate(r)
end
function Cast.walk(r,from,to,t,running)
 r.travel=(to-from).Magnitude*t
 local p=from:Lerp(to,t)
 local d=to-from
 if d.Magnitude>0.01 then Cast.place(r,p,p+d) end
 r.animState.moving=t>0 and t<1
 r.animState.phase=running and "Run" or "Walk"
end
-- Single owner of every human joint pose, one function, one call site
-- (PerformanceDirector calls this and nothing else touches r.poses for a
-- human). Every branch below computes its result FROM this frame's neutral
-- base, never by multiplying onto whatever was left in r.poses last frame -
-- there is no accumulator anywhere in this function. A phase that isn't
-- explicitly handled just keeps the relaxed baseline set at the top, so nothing
-- is ever left in a stale, half-applied pose from a phase that ran earlier.
function Cast.stepAnimate(r,now)
 -- A transient reaction (Stumble/Flinch/StepBack, from Cast.react or
 -- Cast.act) carries its own end time in reactionUntil but nothing ever
 -- consulted it - a character who reacted once stayed leaned/off-balance in
 -- every later shot until some unrelated call happened to re-pose them.
 -- Revert to a settled "Listen" the moment the reaction window closes.
 if r.animState.reactionUntil>0 and now>=r.animState.reactionUntil
  and (r.animState.phase=="Stumble" or r.animState.phase=="Flinch" or r.animState.phase=="StepBack") then
  r.animState.phase="Listen";r.animState.reactionUntil=0
 end
 local phase=r.animState.phase
 if phase=="Operate" and now>=r.animState.activityAt then
  local activities={"TypingConsole","CheckingTablet","AdjustingCable","Monitoring","WritingNotes"}
  if r.kind=="Worker" then activities={"OperateDrill","CarryCase","CheckCable","ClearIce"}
  elseif r.kind=="Soldier" then activities={"Radio","SecurityWatch","CheckWrist","PatrolIdle"} end
  r.animState.activity=activities[r.animState.activityIndex] or activities[1]
  r.animState.activityIndex=(r.animState.activityIndex%#activities)+1
  r.animState.activityAt=now+3.5+(r.animState.seed%23)/8
 end
 if phase=="Operate" then phase=r.animState.activity end
 local moving=r.animState.moving
 local seed=r.animState.seed or 0
 local breath=math.sin(now*math.pi*2/3+seed)
 --[[
  Relaxed baseline, rebuilt from neutral every frame. Three rules hold the
  whole cast upright, and every branch below is written to preserve them:

   1. The legs are the support structure, not a performance layer. Standing
      means hips near zero, a 3-degree knee bend (NEGATIVE - see the
      direction note at the top of this file) and an ankle that cancels it so
      the sole stays flat on the floor Cast.place found.
   2. The pelvis never leaves the space above the feet. The old idle slid the
      root sideways 0.06 studs with no foot compensation and read as a slow
      drift; the weight shift now lives in the waist, where a real one does.
   3. Nothing accumulates. Every pose is written from this baseline, so a
      phase that ends leaves nothing behind.
 ]]
 r.poses.Root=CF()
 r.poses.Waist=CF(0,breath*0.01*r.scale,0)*A(0.012+breath*0.008,0.015,0.012*math.sin(now*0.37+seed))
 r.poses.Neck=CF()
 for _,side in {-1,1} do
  local p=side<0 and "Left" or "Right"
  r.poses[p.."Hip"]=A(0,0,side*-0.02)
  r.poses[p.."Knee"]=A(-0.05,0,0)
  r.poses[p.."Ankle"]=A(0.05,0,0)
  r.poses[p.."Shoulder"]=A(0.03,0,side*0.04)
  r.poses[p.."Elbow"]=A(0.14,0,0)
  r.poses[p.."Wrist"]=CF()
 end
 if moving then
  -- Cycle driven by distance actually travelled (Cast.walk sets r.travel),
  -- not elapsed time, so feet never slide against the ground.
  local cycle=(r.travel or now*2.5)/(1.4*r.scale)*math.pi
  for _,side in {-1,1} do
   local p=side<0 and "Left" or "Right"
   local sidePhase=cycle+(side<0 and 0 or math.pi)
   local lift=math.max(0,math.sin(sidePhase))
   r.poses[p.."Hip"]=A(-math.cos(sidePhase)*0.4,0,side*0.02)
   -- Knee bends the heel BACK (negative) during the swing, and the ankle
   -- lifts the toe (positive) to clear the ground - the two together are
   -- what a step looks like; the old pair did the exact opposite of both.
   r.poses[p.."Knee"]=A(-(lift*0.8+0.05),0,0)
   r.poses[p.."Ankle"]=A(lift*0.35+0.05,0,0)
   r.poses[p.."Shoulder"]=A(math.cos(sidePhase)*0.26,0,side*0.05)
   r.poses[p.."Elbow"]=A(0.3,0,0)
  end
  r.poses.Waist=A(0.02,-math.sin(cycle)*0.05,0)
 elseif phase=="Idle" then Cast.applyPose(r,"NeutralIdle",0.7)
 elseif phase=="Listen" then
  -- A listener is not "Idle" - a slow weight shift onto one foot and a
  -- slight lean toward the speaker. Both are small on purpose: a listening
  -- scientist in a briefing does not sway.
  local shift=math.sin(now*0.5+seed)*0.04
  r.poses.Waist=A(breath*0.01+0.025,shift,0)
  r.poses.LeftShoulder=A(0.08,0,shift*0.4);r.poses.RightShoulder=A(0.08,0,-shift*0.4)
  r.poses.LeftElbow=A(0.34,0,0);r.poses.RightElbow=A(0.3,0,0)
 end
 if not moving and (phase=="Idle" or phase=="Listen") then
  -- One brief unscripted wrist flick in a per-person offset window, so a row
  -- of idle NPCs never all move in lockstep.
  local micro=(now+seed*0.71)%4.6
  local flick=math.sin(math.clamp(micro-3.6,0,1)*math.pi)
  r.poses.LeftWrist=A(0,flick*0.15,0)
 end
 -- Working and acting phases. Arms come FORWARD on positive shoulder/elbow
 -- values; every one of these used to be negative, which swung the hands
 -- behind the back and dragged the forearms through the torso.
 --[[
  Working at the island: less shoulder, MORE elbow. The old values raised the
  upper arm 29 degrees and bent the elbow only 60, which puts the hand a whole
  forearm out in front of the chest - rendered, that is not somebody reading a
  tablet, it is somebody holding out a tray, and at this rig's arm length it
  was the most conspicuous thing in the command room. Dropping the shoulder
  and closing the elbow brings the hands back over the console where the work
  is, and the silhouette reads as attention rather than presentation.
 ]]
 if phase=="Scan" or phase=="Operate" or phase=="ClearIce" or phase=="CheckingTablet" then
  r.poses.LeftShoulder=A(0.32,0,-0.14);r.poses.LeftElbow=A(1.34,0,0)
  r.poses.RightShoulder=A(0.24,0,0.1);r.poses.RightElbow=A(1.02+(phase=="ClearIce" and math.sin(now*2)*0.15 or 0),0,0)
 elseif phase=="TypingConsole" or phase=="WritingNotes" then
  local tap=math.sin(now*7+seed)*0.08
  r.poses.LeftShoulder=A(0.6+tap,0,-0.12);r.poses.LeftElbow=A(1,0,0)
  r.poses.RightShoulder=A(0.64-tap,0,0.12);r.poses.RightElbow=A(0.96,0,0)
 elseif phase=="AdjustingCable" or phase=="CheckCable" or phase=="OperateDrill" then
  r.poses.LeftShoulder=A(0.8,0,-0.22);r.poses.LeftElbow=A(0.9+math.sin(now*2.8)*0.12,0,0)
  r.poses.RightShoulder=A(0.45,0,0.2);r.poses.RightElbow=A(0.7,0,0)
 elseif phase=="Monitoring" or phase=="SecurityWatch" or phase=="PatrolIdle" then
  r.poses.LeftShoulder=A(0.06,0,-0.05);r.poses.RightShoulder=A(0.12,0,0.05)
  r.poses.LeftElbow=A(0.28,0,0);r.poses.RightElbow=A(0.22,0,0)
 elseif phase=="Radio" or phase=="CheckWrist" then
  r.poses.LeftShoulder=A(0.3,0,-0.15);r.poses.LeftElbow=A(0.65,0,0)
  r.poses.RightShoulder=A(0.62,0,0.18);r.poses.RightElbow=A(1.25,0,0)
 elseif phase=="CarryCase" then
  r.poses.LeftShoulder=A(0.18,0,-0.16);r.poses.RightShoulder=A(0.18,0,0.16)
  r.poses.LeftElbow=A(0.42,0,0);r.poses.RightElbow=A(0.42,0,0)
 elseif phase=="Speak" or phase=="Warning" then
  --[[
   Restrained delivery. Two different-frequency sines summed together keep
   the hand alive for the whole line, however long it runs, without the
   fixed period reading as a repeating loop.

   The amplitude is deliberately small (roughly +-9 degrees at the
   shoulder). These are scientists and an officer talking in a briefing, not
   stage actors: readability comes from where they look and who they turn
   toward, and an arm that keeps swinging through a long line reads as a
   broken rig, not as emphasis.
  ]]
  local t=now-(r.lineStart or now)
  --[[
   Scaled by WHO is talking, because "restrained" is not one number for
   everyone in the room. Hale is the ranking officer: his lines are orders
   and questions, and an officer who gestures through them reads as a third
   scientist rather than as the authority. At 0.3 his hand still lives, but
   the delivery is carried almost entirely by stillness and where he looks.
   Voss is analytical and controlled; Lyra, who is the one actually working
   the problem, keeps the full (already small) amplitude.
  ]]
  local restraint=GESTURE_RESTRAINT[r.kind] or 1
  local emphasis=(0.06+math.sin(t*2.1)*0.09+math.sin(t*3.3+1.1)*0.05)*restraint
  r.poses.RightShoulder=A(0.18+emphasis,0,0.09+(phase=="Warning" and 0.1 or 0));r.poses.RightElbow=A(0.7+emphasis,0,0)
  r.poses.LeftShoulder=A(0.1,0,-0.07);r.poses.LeftElbow=A(0.5,0,0)
 elseif phase=="Authority" then
  -- Hands clasped in front, weight even: stillness reads as rank.
  r.poses.LeftShoulder=A(0.3,0,0.12);r.poses.RightShoulder=A(0.3,0,-0.12)
  r.poses.LeftElbow=A(0.75,0,0);r.poses.RightElbow=A(0.75,0,0)
 elseif phase=="Reach" or phase=="Pull" or phase=="TouchCore" or phase=="Brace" or phase=="Defend" then
  for _,p in {"Left","Right"} do
   r.poses[p.."Shoulder"]=A(1.05,0,p=="Left" and -0.13 or 0.13)
   r.poses[p.."Elbow"]=A(phase=="Brace" and 0.9 or 0.3,0,0)
  end
  if phase=="Brace" then
   -- Braced stance: one foot forward, one back, knees bending the correct
   -- way so the pose still supports the body it belongs to.
   r.poses.Waist=A(0.2,0,0)
   r.poses.LeftHip=A(0.26,0,-0.12);r.poses.RightHip=A(-0.22,0,0.12)
   r.poses.LeftKnee=A(-0.3,0,0);r.poses.RightKnee=A(-0.18,0,0)
   r.poses.LeftAnkle=A(0.08,0,0);r.poses.RightAnkle=A(0.32,0,0)
  end
 elseif phase=="Stumble" or phase=="Help" then
  r.poses.Waist=A(0.2,0,math.sin(now*2)*0.08);r.poses.RightShoulder=A(0.7,0,0.5)
  r.poses.LeftHip=A(0.2,0,0);r.poses.LeftKnee=A(-0.25,0,0);r.poses.LeftAnkle=A(0.08,0,0)
 elseif phase=="Flinch" then
  local q=math.clamp(1-(now-(r.animState.actionAt or now))/0.38,0,1)
  -- A flinch is a recoil, not a fall: the pelvis drops and shifts back over
  -- the heels, the knees take it, and the feet stay where they are.
  r.poses.Root=CF(0,-0.06*q*r.scale,0.1*q*r.scale)
  r.poses.Waist=A(0.15*q,0,-0.06*q)
  r.poses.LeftKnee=A(-0.05-0.2*q,0,0);r.poses.RightKnee=A(-0.05-0.2*q,0,0)
  r.poses.LeftAnkle=A(0.05+0.14*q,0,0);r.poses.RightAnkle=A(0.05+0.14*q,0,0)
  r.poses.LeftShoulder=A(0.35*q,0,-0.18*q);r.poses.RightShoulder=A(0.28*q,0,0.18*q)
  r.poses.LeftElbow=A(0.5*q+0.14,0,0);r.poses.RightElbow=A(0.42*q+0.14,0,0)
 elseif phase=="StepBack" then
  r.poses.Waist=A(0.16,0,0);r.poses.LeftShoulder=A(0.3,0,-0.15);r.poses.RightShoulder=A(0.3,0,0.15)
  r.poses.RightHip=A(-0.3,0,0);r.poses.RightKnee=A(-0.15,0,0);r.poses.RightAnkle=A(0.2,0,0)
 end
 -- Gaze: neck leads immediately; the torso only follows after the look has
 -- held for a beat, and both ease in rather than snapping the instant the
 -- target changes.
 if r.lookTarget then
  local localTarget=r.root.CFrame:PointToObjectSpace(r.lookTarget)
  local yaw=math.clamp(math.atan2(-localTarget.X,-localTarget.Z),-math.rad(55),math.rad(55))
  local pitch=math.clamp(math.atan2(localTarget.Y-2.6*r.scale,Vector2.new(localTarget.X,localTarget.Z).Magnitude),-math.rad(25),math.rad(30))
  local age=math.clamp(now-(r.lookChangedAt or now),0,1)
  local ease=age*age*(3-2*age)
  local bodyTurn=math.clamp(yaw*0.25,-math.rad(18),math.rad(18))*ease
  r.poses.Neck=A(pitch*ease,(yaw-bodyTurn)*ease,0)
  r.poses.Waist=r.poses.Waist*A(0,bodyTurn,0)
 end
 Cast.evaluate(r)
 --[[
  FOOT CONTACT. The legs here are forward-kinematic, not IK, so any pose that
  rotates a hip or bends a knee moves the feet off the floor as a side effect.
  Rather than hand-compensating every pose (which is what nobody did, and is
  why people hovered and sank), the pelvis follows the lower foot: measure how
  far the lowest sole is from the floor this character is standing on, and
  translate the root by exactly that.

  Dropping the pelvis by d lowers both feet by d, so the lower sole lands on
  the floor and the higher one stays at or above it - which is precisely the
  requirement: both feet on the ground unless one is mid-step. The clamp stops
  a wild pose from burying the character.
 ]]
 if r.human and r.floorY then
  local lift=Cast.footCorrection(r)
  if math.abs(lift)>0.002 then
   r.poses.Root=CF(0,lift,0)*(r.poses.Root or CF())
   --[[
    Grounding is a CONSTRAINT, not a performance beat, so it is written
    straight into the applied state instead of being eased toward like a pose.

    Clearing r.applied.Root makes the next evaluate take this target exactly
    (see the alpha there). Easing it was a real, measurable bug: moving the
    pelvis by x moves both soles by x, so with a 22% blend the correction
    settles at a fixed point where the remaining error is exactly HALF the
    original gap and never closes. Studio reported it every frame, on every
    character, at a stubbornly constant value - "both feet off the floor by
    0.25 studs" - which is the arithmetic signature of that half, not of a
    bad pose.
   ]]
   r.applied.Root=nil
   Cast.evaluate(r)
  end
 end
 if IS_STUDIO and r.human and r.torso and not moving and not NON_UPRIGHT_PHASES[phase] then
  --[[
   The standing check, run every frame in Studio. "The character looks wrong"
   has to become a line in the output at the moment it happens, not a thing
   somebody notices in a screenshot three sessions later, so this asserts the
   four properties that together mean "standing":

     1. UPRIGHT   - the torso's up vector points at world +Y.
     2. STACKED   - pelvis above both feet, head above the pelvis. This is
                    the literal wording of the requirement and it is checked
                    literally, in world space, off the evaluated rig.
     3. GROUNDED  - both soles are within a quarter stud of the floor
                    Cast.place put this character on.
     4. LEVEL     - neither foot is far below the other, which is what a
                    collapsed or half-fallen stance actually looks like.
  ]]
  local problem=nil
  local up=r.torso.CFrame.UpVector:Dot(V(0,1,0))
  local lean=math.deg(math.acos(math.clamp(up,-1,1)))
  if lean>MAX_UPRIGHT_DEGREES then problem=`leaning {string.format("%.1f",lean)} degrees` end
  local left=r.model:FindFirstChild("LeftFoot")
  local right=r.model:FindFirstChild("RightFoot")
  local pelvis=r.model:FindFirstChild("LowerTorso")
  if not problem and left and right and pelvis and r.head then
   local soleL=left.Position.Y-left.Size.Y/2
   local soleR=right.Position.Y-right.Size.Y/2
   local floor=r.floorY or math.min(soleL,soleR)
   if pelvis.Position.Y<=math.max(soleL,soleR)+0.4 then
    problem=`pelvis below feet (pelvis {string.format("%.2f",pelvis.Position.Y)}, sole {string.format("%.2f",math.max(soleL,soleR))})`
   elseif r.head.Position.Y<=pelvis.Position.Y then
    problem=`head below pelvis`
   elseif math.abs(soleL-soleR)>0.5 then
    problem=`feet {string.format("%.2f",math.abs(soleL-soleR))} studs apart vertically`
   elseif math.abs(soleL-floor)>0.25 and math.abs(soleR-floor)>0.25 then
    problem=`both feet off the floor by {string.format("%.2f",math.min(math.abs(soleL-floor),math.abs(soleR-floor)))} studs`
   end
  end
  if problem then
   if not uprightWarned[r] then
    --[[
     Everything needed to FIND the fault, in one line: who, what phase they
     were in when it happened, how far from upright they actually are, how
     far their soles are from the floor this character was placed on, and
     where their root is in the world so it can be typed straight into the
     Studio command bar. A warning that only says "not standing correctly"
     costs a whole extra session to act on.
    ]]
    local sole=left and right and math.min(left.Position.Y-left.Size.Y/2,right.Position.Y-right.Size.Y/2) or nil
    local gap=(sole and r.floorY) and string.format("%.2f",sole-r.floorY) or "n/a"
    local at=r.root.Position
    warn(`[ActorValidation] {r.model.Name}: {problem} (phase={phase}, lean={string.format("%.1f",lean)}deg, feet {gap} above floor, root {string.format("%.1f, %.1f, %.1f",at.X,at.Y,at.Z)})`)
   end
   uprightWarned[r]=true
  else
   uprightWarned[r]=nil
  end
 end
 -- Facial geometry is evaluated after the head, never left behind as it turns.
 local expr=r.expression
 local fear=expr=="Afraid" or expr=="Horrified" or expr=="Amazed"
 local angry=expr=="Angry" or expr=="Determined"
 --[[
  This used to write the tilt to an attribute nothing read, so every angry,
  sad and frightened face in the cinematic rendered with level eyebrows. The
  brow is welded decoration, and Cast.evaluate drives welded decoration from
  `entry.offset` every frame - so rotating THAT is the whole fix. The rest
  angle is the face preset's own, which is what separates Hale's heavy set
  brow from Lyra's.
 ]]
 for _,b in r.face.brows do
  b.entry.offset=b.base*A(0,0,b.side*(b.rest+(angry and -0.22 or expr=="Sad" and 0.22 or fear and 0.08 or 0)))
 end
 r.face.mouth.Size=V(r.face.mouthWidth,fear and 0.1 or phase=="Speak" and 0.03+math.abs(math.sin(now*9))*0.045 or 0.03,0.03)*r.scale
end
-- Mechanical guardian: 62 studs standing, 38 kneeling. Individual limbs,
-- fingers, neck pistons, core rotor, armor flakes and conduit plates.
function Cast.buildAegisZero(parent,cf,scale): AegisHandle
 local r=rig(parent,"AegisZeroSealed",cf);r.scale=scale or 10;r.dummy=r.model;r.chains={};r.chainData={};r.fingers={};r.ice={}
 local pelvis=joint(r,r.root,"Pelvis","Root",V(12,6,8),CF(),CF(),C.metal,"wedge")
 r.torso=joint(r,pelvis,"UpperTorso","Waist",V(17,17,9),CF(0,3,0),CF(0,-7,0),C.metal,"wedge")
 r.head=joint(r,r.torso,"Head","Neck",V(7,8,6),CF(0,9,0),CF(0,-3,0),C.metal,"wedge")
 r.core=attach(r,r.torso,"ChestCore",V(5,5,1.2),CF(0,1,-5),C.orange,"ball",Enum.Material.Neon)
 r.coreLight=Kit.light(r.core,C.warm,45,1)
 r.rotor=joint(r,r.torso,"CoreRotor","CoreRotor",V(5.6,0.5,1.3),CF(0,1,-5.2),CF(),C.gold)
 for _,side in {-1,1} do
  local prefix=side<0 and "Left" or "Right"
  local arm=joint(r,r.torso,prefix.."UpperArm",prefix.."Shoulder",V(7,11,7),CF(side*11,6,0),CF(0,4,0),C.metal,"wedge")
  local fore=joint(r,arm,prefix.."LowerArm",prefix.."Elbow",V(6,10,6),CF(0,-6,0),CF(0,4,0),C.metal,"wedge")
  local hand=joint(r,fore,prefix.."Hand",prefix.."Wrist",V(5,4,3.5),CF(0,-6,0),CF(0,1.5,0),C.metal)
  for f=1,4 do
   local finger=joint(r,hand,prefix.."Finger"..f,prefix.."Finger"..f,V(0.8,3,1),CF(-2.3+f, -1.5,-0.7),CF(0,1.2,0),C.ivory)
   attach(r,finger,"Knuckle",V(1,0.8,1.1),CF(0,0.8,0),C.gold,"ball")
   table.insert(r.fingers,prefix.."Finger"..f)
  end
  local thigh=joint(r,pelvis,prefix.."Thigh",prefix.."Hip",V(7,12,8),CF(side*5,-2,0),CF(0,5,0),C.metal,"wedge")
  local shin=joint(r,thigh,prefix.."Shin",prefix.."Knee",V(6.5,12,7),CF(0,-7,0),CF(0,5,0),C.metal,"wedge")
  local foot=joint(r,shin,prefix.."Foot",prefix.."Ankle",V(7,4,12),CF(0,-7,0),CF(0,1,3),C.metal,"wedge")
  for _,host in {arm,fore,thigh,shin,r.torso} do
   local sz=host.Size
   for layer=1,3 do
    local armor=attach(r,host,"IvoryArmorPlate",V(sz.X*1.07,sz.Y*0.3,sz.Z*0.28),CF(0,sz.Y*(0.4-layer*0.27),-sz.Z*0.45),C.ivory,"wedge")
    attach(r,armor,"WeatheredGoldEdge",V(armor.Size.X*0.9,0.15,0.15),CF(0,armor.Size.Y/2,-0.2),C.gold)
    attach(r,armor,"BattleScore",V(armor.Size.X*0.3,0.05,0.05),CF(-0.5,0,-armor.Size.Z/2-0.03)*A(0,0,0.22),C.metal)
   end
   attach(r,host,"Conduit",V(0.24,sz.Y*0.65,0.2),CF(sz.X*0.42,0,-sz.Z*0.54),C.orange,nil,Enum.Material.Neon)
   attach(r,host,"JointBearing",V(sz.X*0.7,1.4,sz.Z*0.7),CF(0,-sz.Y/2,0),C.gold,"wedge")
  end
  attach(r,arm,"BroadPauldron",V(10,4,10),CF(side,5,0),C.ivory,"wedge")
  local frost=attach(r,arm,"FracturingIce",V(9,2,9),CF(side,7,0),C.ice,"wedge",Enum.Material.Ice)
  frost.Transparency=0.25;table.insert(r.ice,frost)
  attach(r,foot,"ToeCap",V(7.5,2,6),CF(0,1,-4),C.ivory,"wedge")
  local eye=attach(r,r.head,"Eye",V(1.7,0.5,0.3),CF(side*1.6,0.5,-3.2),C.orange,nil,Enum.Material.Neon)
  table.insert(r.eyes,eye)
  attach(r,r.head,"CheekArmor",V(2,3,1),CF(side*2,-1,-3),side<0 and C.ivory or C.metal,"wedge")
  attach(r,r.torso,"BackPylon",V(2,18,3),CF(side*5,4,6)*A(-0.3,0,side*0.1),C.ivory,"wedge")
  attach(r,r.torso,"EmbeddedBlade",V(1,13,2),CF(side*7,10,5)*A(0.4,0,side*0.3),C.gold,"wedge")
 end
 r.poses.Waist=A(math.rad(20),0,0);r.poses.Neck=A(math.rad(-25),0,0)
 for _,p in {"Left","Right"} do
  r.poses[p.."Hip"]=A(0,0,0)
  r.poses[p.."Knee"]=A(math.rad(-90),0,0)
  r.poses[p.."Ankle"]=A(math.rad(90),0,0)
  r.poses[p.."Shoulder"]=A(math.rad(-18),0,p=="Left" and -0.12 or 0.12)
  r.poses[p.."Elbow"]=A(math.rad(-24),0,0)
 end
 Cast.evaluate(r)
 for index,prefix in {"Left","Right"} do
  local hand=r.model:FindFirstChild(prefix.."Hand")
  local chain=Kit.model(prefix.."RestraintChain",r.model)
  local links={}
  for i=1,14 do
   local link=Kit.model("InterlockingLink",chain)
   for _,side in {-1,1} do
    shape(link,"LinkSide",V(0.35,1.8,0.35),CF(side*0.6,0,0),C.gold,"ball",Enum.Material.Metal)
    shape(link,"LinkEnd",V(1.45,0.35,0.35),CF(0,side*0.8,0),C.gold,"ball",Enum.Material.Metal)
   end
   table.insert(links,link)
  end
  table.insert(r.chains,chain)
  table.insert(r.chainData,{hand=hand,links=links,anchor=cf.Position+V(index==1 and -5 or 5,-cf.Position.Y+9500,6),broken=false})
 end
 return r
end
function Cast.updateChains(r,t)
 for _,chain in r.chainData do
  local from=chain.hand.Position
  for i,link in chain.links do
   local a=i/#chain.links
   local pos=from:Lerp(chain.anchor,a)
   if chain.broken then
    local dt=math.min(t-chain.breakTime,1.5)
    pos+=V(math.sin(i)*dt*6,-dt*dt*12,math.cos(i)*dt*4)
   end
   local direction=chain.anchor-from
   link:PivotTo(CFrame.lookAt(pos,pos+direction)*A(math.pi/2,(i%2)*math.pi/2,0))
  end
 end
end
-- Quintic "smootherstep" (Perlin): zero first AND second derivative at both
-- ends, unlike the cubic Kit.smooth curve - that extra flatness at rest is
-- what reads as inertia (a heavy mass reluctant to start, and reluctant to
-- stop) rather than a generic ease. Every Aegis Zero pose driver below
-- reshapes its incoming `amount` through this once, so every call site can
-- keep passing plain linear shot-progress without the mecha ever moving at
-- a robotic constant speed.
local function heavy(t)
 t=math.clamp(t,0,1)
 return t*t*t*(t*(t*6-15)+10)
end
function Cast.setAegisAwaken(r,rawAmount)
 local amount=heavy(rawAmount)
 r.poses.CoreRotor=A(0,0,amount*math.pi*3)
 r.poses.Neck=A(-0.44+amount*0.5,0,0)
 for i,name in r.fingers do r.poses[name]=A(-math.clamp(amount*2-i*0.06,0,1)*1.1,0,0) end
 for _,prefix in {"Left","Right"} do r.poses[prefix.."Wrist"]=A(0,amount*0.16,0) end
 r.core.Color=C.orange:Lerp(C.warm,amount)
 if r.coreLight then r.coreLight.Brightness=1+amount*3 end
 for _,eye in r.eyes do eye.Transparency=1-math.clamp((amount-0.65)/0.35,0,1) end
 for _,ice in r.ice do ice.Transparency=math.clamp(0.25+amount*0.75,0,1) end
 Cast.evaluate(r)
end
function Cast.setAegisRise(r,rawAmount)
 local amount=heavy(rawAmount)
 r.poses.Waist=A(0.35-amount*0.3,0,0)
 for _,p in {"Left","Right"} do
  r.poses[p.."Shoulder"]=A(-0.32+amount*0.3,0,p=="Left" and -0.12 or 0.12)
  r.poses[p.."Elbow"]=A(-0.42+amount*0.22,0,0)
 end
 Cast.evaluate(r)
end
function Cast.breakChain(r,index,time)
 local c=r.chainData[index]
 if c then c.broken=true;c.breakTime=time or 0 end
end
-- Anatomy per the visual-director brief: a narrow waist widening into an
-- armored chest, two reverse-jointed legs (hip and knee bend the SAME
-- rotational way, so the shin angles backward like a bird's - not a human
-- knee), two forelimbs reaching to roughly knee level with a three-digit
-- hand, a small forward-projecting wedge head with one horizontal sensor
-- slit (no face), and three large backward-facing spine fins. One coherent
-- creature read from a silhouette, not a stack of plates.
local function biomech(parent,cf0,scale,name)
 local r=rig(parent,name,cf0);r.scale=scale;r.ice={};r.eyes={}
 local s=scale
 -- CFrame has no CFrame*number operator - scale each component going in,
 -- not the constructed CFrame coming out.
 local function cf(x,y,z) return CF(x*s,y*s,z*s) end
 local pelvis=joint(r,r.root,"Pelvis","Root",V(1.3,1.2,1.2)*s,cf(0,0,0),cf(0,0,0),Color3.fromRGB(26,24,32))
 r.torso=joint(r,pelvis,"Thorax","Waist",V(2.6,3,2)*s,cf(0,1.5,0),cf(0,-1.4,0),Color3.fromRGB(30,28,36))
 -- Rib-like segmented armor around the chest - three plates, not eight.
 for i=1,3 do
  attach(r,r.torso,"RibPlate"..i,V(2.9-i*0.28,0.5,2.2-i*0.18)*s,cf(0,1.05-i*0.75,0),C.metal,"wedge")
 end
 attach(r,r.torso,"SternumRidge",V(0.4,2.6,0.3)*s,cf(0,0.1,-1),Color3.fromRGB(174,174,155))
 -- Small forward-projecting head, no face - one recessed horizontal sensor
 -- slit made of 5 segments (kept as r.eyes for the existing progressive
 -- reveal - Cast.setCreatureEyes lights them left-to-right).
 r.head=joint(r,r.torso,"NarrowHead","HeadJoint",V(1.3,1,1.9)*s,cf(0,1.65,-0.3),cf(0,-0.5,0.4),C.metal,"wedge")
 local slit=attach(r,r.head,"SensorSlit",V(1.0,0.16,0.15)*s,cf(0,0.05,-0.95),Color3.fromRGB(20,18,26))
 for i=1,5 do
  local t=(i-3)/2
  local eye=attach(r,slit,"SensorSegment"..i,V(0.14,0.1,0.06)*s,cf(t*0.42,0,-0.09),C.violet,nil,Enum.Material.Neon)
  eye.Transparency=1;table.insert(r.eyes,eye)
 end
 -- Three large, readable back spines instead of a dozen small wing spars.
 for i=1,3 do
  local t=(i-2)
  attach(r,r.torso,"SpineFin"..i,V(0.35,2.6-math.abs(t)*0.5,1.9-math.abs(t)*0.3)*s,cf(t*0.55,0.9-i*0.1,1.05)*A(0.55,0,0),Color3.fromRGB(24,22,30),"wedge")
 end
 -- Two forelimbs, reaching to roughly knee level: thin upper arm, a
 -- slightly larger forearm, a hand with three long digits.
 for _,side in {-1,1} do
  local prefix=side<0 and "Left" or "Right"
  local arm=joint(r,r.torso,prefix.."Arm",prefix.."Shoulder",V(0.55,2.8,0.6)*s,cf(side*1.35,1.1,0),cf(0,1.3,0),Color3.fromRGB(30,28,36),"wedge")
  local forearm=joint(r,arm,prefix.."Forearm",prefix.."Elbow",V(0.62,2.6,0.68)*s,cf(0,-1.3,0),cf(0,1.25,0),Color3.fromRGB(30,28,36))
  local hand=joint(r,forearm,prefix.."Hand",prefix.."Wrist",V(0.5,0.7,0.55)*s,cf(0,-1.25,0),cf(0,0.32,0),Color3.fromRGB(22,20,28))
  for d=1,3 do
   local dt=(d-2)*0.32
   local base=attach(r,hand,"Digit"..d.."Base",V(0.15,0.55,0.16)*s,cf(dt,-0.28,-0.15),Color3.fromRGB(170,165,151),"wedge")
   attach(r,base,"Digit"..d.."Tip",V(0.11,0.4,0.12)*s,cf(0,-0.42,-0.06)*A(0.3,0,0),Color3.fromRGB(170,165,151),"wedge")
  end
  r.poses[prefix.."Shoulder"]=A(0.3,0,side*-0.18)
  r.poses[prefix.."Elbow"]=A(0.55,0,0)
  -- Two reverse-jointed legs. Hip and knee bend the SAME rotational
  -- direction (both positive here) rather than opposite, which is what
  -- makes the shin read as angled backward like a bird's leg instead of a
  -- human knee.
  local thigh=joint(r,pelvis,prefix.."Thigh",prefix.."Hip",V(0.85,2.5,0.95)*s,cf(side*0.55,-0.5,0),cf(0,1.15,0),Color3.fromRGB(28,26,34),"wedge")
  local shin=joint(r,thigh,prefix.."Shin",prefix.."Knee",V(0.68,2.5,0.8)*s,cf(0,-1.15,0.15),cf(0,1.15,0),Color3.fromRGB(28,26,34))
  local foot=joint(r,shin,prefix.."Foot",prefix.."Ankle",V(0.55,0.5,1.9)*s,cf(0,-1.2,-0.3),cf(0,0.22,0.55),Color3.fromRGB(20,18,26),"wedge")
  for c=1,3 do
   attach(r,foot,"ToeClaw"..c,V(0.16,0.18,0.7)*s,cf((c-2)*0.16,-0.02,-1.05),Color3.fromRGB(170,165,151),"wedge")
  end
  r.poses[prefix.."Hip"]=A(0.55,0,0)
  r.poses[prefix.."Knee"]=A(0.85,0,0)
  r.poses[prefix.."Ankle"]=A(-0.5,0,0)
 end
 for i=1,4 do
  local frost=attach(r,r.torso,"IceFracture",V(1.6,1.2,0.4)*s,cf(i%2==0 and 1 or -1,1-i*0.5,-1)*A(0,0,i*0.4),C.ice,"wedge",Enum.Material.Ice)
  frost.Transparency=0.5;table.insert(r.ice,frost)
 end
 Cast.evaluate(r)
 return r
end
function Cast.buildSovereign(parent,cf,scale) return biomech(parent,cf,scale or 5,"SovereignBelow") end
function Cast.buildWarden(parent,cf,scale,frozen)
 local r=biomech(parent,cf,scale,"Warden")
 if not frozen then for _,p in r.ice do p.Transparency=1 end end
 return r
end
-- Alien stillness: the opposite movement language from Aegis Zero's `heavy`
-- curve above. Holds almost motionless (a small deliberate "tell," not a
-- full freeze - twitching constantly would undercut it) through `holdUntil`,
-- then moves in one controlled, unnervingly fast burst. A lower `holdUntil`
-- makes something commit to movement earlier than the rest of the body -
-- used below to make the head turn before the torso/limbs follow.
local function sudden(t,holdUntil)
 t=math.clamp(t,0,1);holdUntil=holdUntil or 0.7
 if t<=holdUntil then return (t/holdUntil)*0.06 end
 local burst=(t-holdUntil)/(1-holdUntil)
 return 0.06+0.94*(burst*burst*(3-2*burst))
end
function Cast.setCreatureEyes(r,amount)
 local a=sudden(amount,0.55)
 for i,eye in r.eyes do eye.Transparency=1-math.clamp(a*1.6-(i-1)*0.12,0,1) end
end
function Cast.setCreatureLimbUnfold(r,rawAmount)
 -- The head commits first (holdUntil 0.3), the limbs follow later (0.7) -
 -- "its head may turn before its torso." Arms swing out from a tucked rest
 -- pose into a threatening extended reach; legs partially straighten out of
 -- their frozen crouch toward a ready stance - the reverse-jointed knee
 -- angle (hip and knee bending the same rotational way) is preserved at
 -- every point along the unfold, not just at the rest pose.
 r.poses.HeadJoint=A(0,sudden(rawAmount,0.3)*0.6,0)
 local amount=sudden(rawAmount,0.7)
 for _,side in {-1,1} do
  local prefix=side<0 and "Left" or "Right"
  r.poses[prefix.."Shoulder"]=A(0.3-amount*0.9,0,side*(-0.18-amount*0.4))
  r.poses[prefix.."Elbow"]=A(0.55-amount*0.35,0,0)
  r.poses[prefix.."Hip"]=A(0.55-amount*0.15,0,0)
  r.poses[prefix.."Knee"]=A(0.85-amount*0.25,0,0)
  r.poses[prefix.."Ankle"]=A(-0.5+amount*0.15,0,0)
 end
 Cast.evaluate(r)
end
function Cast.removeIceShell(r,amount)
 for i,p in r.ice do
  p.Transparency=math.clamp(0.5+(amount or 1)*0.5,0,1)
 end
end
return Cast
