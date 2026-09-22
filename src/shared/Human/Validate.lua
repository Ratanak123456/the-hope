--!nonstrict
-- Phase 0.A foundation, module 5 of 6: the validator.
--
-- Every failure mode named in the Phase 0.A brief, expressed as a number that
-- is measured every frame rather than judged by eye. This exists because the
-- visual verdict belongs to a human watching Studio, and a human watching
-- Studio cannot see a 0.004-stud foot slide or a pose offset that has drifted
-- by a thousandth of a radian per cycle. The eye and this file check
-- different things, and Phase 0.A needs both.
--
-- Nothing here is Roblox-specific except scanRig(), so the whole checklist
-- runs headlessly in tools/phase0a/offline as well as on screen in Studio.
local Skeleton=require(script.Parent.Skeleton)
local Loco=require(script.Parent.Locomotion)
local Validate={}
local V,CF=Vector3.new,CFrame.new
local SIDES={"Left","Right"}

local CHECKS={
 "rootUpright","torsoUpright","feetGrounded","noFootSlide","kneeDirection",
 "elbowDirection","armClearsTorso","headOnNeck","legReach","noResidualPose",
 "noAccumulation","pelvisSupported","pelvisRate","overSupport","bodyDrop","bodyVerticalRate","targetReach",
}

function Validate.newSession()
 local s={frames=0,worst={},fail={},plants={},baseline=nil,samples={}}
 for _,c in CHECKS do s.worst[c]=0;s.fail[c]=0 end
 return s
end

local function record(s,check,value,limit)
 if value>s.worst[check] then s.worst[check]=value end
 if value>limit then s.fail[check]+=1 end
end

-- Pitch/roll of a CFrame, in radians, independent of yaw.
local function tilt(cf)
 local up=cf.UpVector
 local pitch=math.asin(math.clamp(-cf.LookVector.Y,-1,1))
 local roll=math.asin(math.clamp(cf.RightVector.Y,-1,1))
 return math.abs(pitch),math.abs(roll),up
end

function Validate.step(session,actor)
 session.frames+=1
 local world=actor.world
 if not world then return end
 local scale=actor.scale
 local root=actor.rootCFrame

 -- 1. The world root must be exactly upright. Not approximately: this
 -- foundation builds it from a single yaw, so anything but zero is a bug in
 -- the construction itself, not a tolerance question.
 local pitch,roll=tilt(root)
 record(session,"rootUpright",math.max(pitch,roll),1e-6)

 -- 2. The torso must be standing. Same check the old cast made, kept because
 -- it is the one that catches "the character is lying down".
 local up=world.UpperTorso.UpVector:Dot(V(0,1,0))
 record(session,"torsoUpright",math.max(0,0.86-up),1e-6)

 -- 3/4. Feet: on the floor when planted, above it when swinging, and a
 -- planted foot must not move between frames while its plant id is unchanged.
 local half=Skeleton.ByMotor.LeftAnkle.size.Y/2*scale
 for _,side in SIDES do
  local f=actor.loco.feet[side]
  local footCF=world[side.."Foot"]
  local soleY=(footCF*CF(0,-half,0)).Position.Y
  if f.mode=="planted" then
   record(session,"feetGrounded",math.abs(soleY-actor.floorY),0.012*scale)
   local prev=session.plants[side]
   if prev and prev.id==f.plantId then
    record(session,"noFootSlide",(prev.pos-f.target.Position).Magnitude,1e-9)
   end
   session.plants[side]={id=f.plantId,pos=f.target.Position}
  else
   -- A swinging foot may be above the floor but never below it.
   record(session,"feetGrounded",math.max(0,actor.floorY-soleY),0.012*scale)
   session.plants[side]=nil
  end
 end

 -- 4b. CHECKS THAT REPRESENT THE BODY, not the solver.
 --
 -- The lesson from the collapse is that a solver can satisfy ankle position,
 -- leg reach, planted-foot state and neutral return while producing a pose no
 -- human could hold. legReach and feetGrounded are both satisfied BY the
 -- pelvis dropping, so neither can ever see it. These three are deliberately
 -- about the body itself, and between them they describe the general category
 -- of "technically reachable, visibly invalid" rather than the one frame that
 -- caught it: too deep, too sudden, or too splayed.

 -- Depth: the drop the stance DEMANDS, measured before Locomotion bounds it,
 -- so clamping can never hide an impossible stance behind a healthy number.
 record(session,"pelvisSupported",actor.loco.pelvisDrop,Loco.MAXDROP*scale)

 -- Rate: a dip can be shallow enough to pass on depth and still read as a
 -- stumble because it happened over three frames. Bounds how fast the hips
 -- may move vertically, which is what the eye actually objects to.
 record(session,"pelvisRate",actor.loco.pelvisRate,Loco.PELVISRATE*scale*1.02)

 -- Support base: is the body actually over its feet? Every other check here
 -- is satisfiable with the character standing beside the base it is standing
 -- on, because they all measure a foot against its own hip rather than the
 -- body against the ground it is carried by.
 record(session,"overSupport",Loco.supportOffset(actor.loco,root),Loco.supportRadius(scale,Loco.BOB))

 -- Measure the rendered body independently of the solver correction clamp.
 local bodyY=world.LowerTorso.Position.Y
 local neutralY=actor.standY+Skeleton.ByMotor.Root.c0.Y
 local normal=actor.reactionState.timer<0
 if normal then
  record(session,"bodyDrop",math.max(0,neutralY-bodyY),Loco.NORMALHEIGHT*scale)
  if session.bodyY and session.normal and actor.loco.lastDt>1e-5 then
   record(session,"bodyVerticalRate",math.abs(bodyY-session.bodyY)/actor.loco.lastDt,0.85*scale)
  end
 end
 session.bodyY=bodyY;session.normal=normal
 record(session,"targetReach",actor.loco.reachError,0.012*scale)

 -- 5. Knee direction. Geometric, not a sign convention: when a knee is bent,
 -- its pivot must sit FORWARD of the straight hip-to-ankle line. This is what
 -- makes the bend-sign derivation in Skeleton.lua self-checking - if that
 -- reasoning were inverted, this check fails immediately and loudly.
 local forward=root.LookVector
 for _,side in SIDES do
  local hipSeg=Skeleton.ByMotor[side.."Hip"]
  local kneeSeg=Skeleton.ByMotor[side.."Knee"]
  local ankleSeg=Skeleton.ByMotor[side.."Ankle"]
  local hipPivot=(world.LowerTorso*CF(hipSeg.c0)).Position
  local kneePivot=(world[side.."UpperLeg"]*CF(kneeSeg.c0)).Position
  local anklePivot=(world[side.."LowerLeg"]*CF(ankleSeg.c0)).Position
  local chord=anklePivot-hipPivot
  local bend=(kneePivot-(hipPivot+chord*0.5))
  local perpendicular=bend-chord.Unit*bend:Dot(chord.Unit)
  if perpendicular.Magnitude>0.02*scale then
   -- Only meaningful once the leg is actually bent.
   record(session,"kneeDirection",math.max(0,-perpendicular.Unit:Dot(forward)),0.15)
  end
  -- 9. A leg must never be asked for more than it has.
  record(session,"legReach",(anklePivot-hipPivot).Magnitude-Skeleton.LegReach*scale,1e-4)
 end

 -- 6/7. Elbow direction and arm clearance. A bent elbow's pivot must sit
 -- BEHIND the shoulder-to-wrist line, and the hand must stay outside the
 -- torso - the two halves of "arms pass through the chest".
 local torsoHalf=Skeleton.ByMotor.Waist.size*0.5*scale
 for _,side in SIDES do
  local shoulderSeg=Skeleton.ByMotor[side.."Shoulder"]
  local elbowSeg=Skeleton.ByMotor[side.."Elbow"]
  local shoulderPivot=(world.UpperTorso*CF(shoulderSeg.c0)).Position
  local elbowPivot=(world[side.."UpperArm"]*CF(elbowSeg.c0)).Position
  local wristSeg=Skeleton.ByMotor[side.."Wrist"]
  local wristPivot=(world[side.."LowerArm"]*CF(wristSeg.c0)).Position
  local chord=wristPivot-shoulderPivot
  if chord.Magnitude>0.05 then
   local bend=elbowPivot-(shoulderPivot+chord*0.5)
   local perpendicular=bend-chord.Unit*bend:Dot(chord.Unit)
   if perpendicular.Magnitude>0.02*scale then
    record(session,"elbowDirection",math.max(0,perpendicular.Unit:Dot(forward)),0.15)
   end
  end
  local handLocal=world.UpperTorso:PointToObjectSpace(world[side.."Hand"].Position)
  local inside=math.max(0,torsoHalf.X-math.abs(handLocal.X))
   *math.max(0,torsoHalf.Y-math.abs(handLocal.Y))
   *math.max(0,torsoHalf.Z-math.abs(handLocal.Z))
  record(session,"armClearsTorso",inside,1e-6)
 end

 -- 8. The head must stay on the neck: the gap between the top of the torso
 -- and the bottom of the head is fixed by the rig and must not open up.
 local neckSeg=Skeleton.ByMotor.Neck
 local neckPivot=(world.UpperTorso*CF(neckSeg.c0)).Position
 local headBase=(world.Head*CF(neckSeg.c1)).Position
 record(session,"headOnNeck",(neckPivot-headBase).Magnitude,1e-4)

 -- 10. No residual pose. When every action has finished, the only layers
 -- allowed to be contributing are the two that are supposed to run forever.
 if not actor:isBusy() and actor.speed==0 and actor.lastFrame then
  for motor,layers in actor.lastFrame.touched do
   for layer in layers do
    if layer~="Breath" and layer~="WeightShift" and layer~="Locomotion" and layer~="Pelvis" then
     record(session,"noResidualPose",1,0)
    end
   end
  end
 end
end

-- 11. Accumulation. Sampled at matched points in the breathing cycle so the
-- comparison is like-for-like: the same phase, the same expected pose. Any
-- difference between two such samples is drift, and with a scalar accumulator
-- reset every frame there should be exactly none.
function Validate.sample(session,actor,tag)
 local t={}
 for motor,cf in actor.transforms do
  local x,y,z=cf:ToOrientation()
  t[motor]={x,y,z,cf.Position.X,cf.Position.Y,cf.Position.Z}
 end
 session.samples[tag]=t
 return t
end

function Validate.compareSamples(session,tagA,tagB)
 local a,b=session.samples[tagA],session.samples[tagB]
 if not a or not b then return nil end
 local worst,where=0,"none"
 for motor,va in a do
  local vb=b[motor]
  if vb then
   for i=1,6 do
    local d=math.abs(va[i]-vb[i])
    if d>worst then worst=d;where=motor end
   end
  end
 end
 record(session,"noAccumulation",worst,1e-4)
 return worst,where
end

-- Roblox-only: the rig must not light itself.
function Validate.scanRig(model)
 local lights,neon={},{}
 for _,d in model:GetDescendants() do
  if d:IsA("Light") then table.insert(lights,d:GetFullName()) end
  if d:IsA("BasePart") and d.Material==Enum.Material.Neon then table.insert(neon,d.Name) end
 end
 return lights,neon
end

function Validate.report(session)
 local rows={}
 for _,c in CHECKS do
  table.insert(rows,{name=c,worst=session.worst[c],failures=session.fail[c],ok=session.fail[c]==0})
 end
 return rows
end

function Validate.passed(session)
 for _,c in CHECKS do if session.fail[c]>0 then return false end end
 return true
end

Validate.Checks=CHECKS
return Validate
