--!nonstrict
-- Phase 0.A foundation, module 1 of 6: the skeleton.
--
-- Pure data and pure math. Nothing in this file touches Instance, workspace,
-- RunService or any other Roblox service, which is what lets the offline
-- harness (tools/phase0a/offline) execute the real rig maths headlessly
-- instead of a port of it.
--
-- PROPORTIONS. **Re-derived 2026-09-21 after the first visual review failed.**
--
-- The numbers previously carried over from NorthPole/Cast.lua were REALISTIC
-- HUMAN ratios (head 15% of standing height, shoulders 2.25 head widths).
-- Rendered, they read exactly as the brief's failure case: a low-poly
-- realistic human, not a Roblox character. A default R15 avatar has a head
-- close to a fifth of its height and roughly two thirds the width of its
-- torso, and its arms hang flush OUTSIDE the torso rather than overlapping
-- it. These numbers target that instead:
--
--   standing height         5.70 studs
--   head                    1.10  = 19.3% of height   (was 15.0%)
--   head width / torso      1.10 / 1.75 = 0.63        (was 0.44)
--   hip pivot -> sole       2.80  = 49.1% of height   (was 48.0%)
--   torso, LT+UT            1.80  = 31.6% of height
--   shoulder outer span     3.45  = 0.61 of height    (was 0.40)
--   arm inner face          x = 0.875 = exactly the torso's outer face, so
--                           the arms read as separate masses in silhouette
--   relaxed hand bottom     y = -0.72 vs thigh span +0.10..-1.25 -> lower thigh
--
-- A second visual pass shortened the torso and lengthened the legs and feet's
-- proportions again: the first R15-ratio attempt still rendered squat, with
-- stubby legs under a long torso and feet that read as skis (1.25 deep).
--
-- Segment sizes and offsets are the single source of truth: every derived
-- length below, the IK, the validator and the offline renderer all read them
-- from this table rather than restating a number.
--
-- BEND DIRECTION. This is the correctness issue that most likely explains the
-- "knees bend backward" and "arms pass through the torso" reports, so the
-- derivation is written out rather than asserted.
--   Roblox -Z is forward. Confirmed twice, independently, for THIS rig:
--     (a) the foot's ankle pivot offset is (0, 0.145, 0.28), putting the foot
--         body at z = -0.28 and the toes at z = -0.755 -> toes point -Z;
--     (b) placement uses CFrame.lookAt, whose LookVector is -Z.
--   CFrame.Angles(t,0,0) applied to a limb hanging along local -Y gives
--     (0, -cos t, -sin t)
--   so POSITIVE x rotation swings a hanging limb toward -Z, i.e. FORWARD.
--   Therefore:
--     knee  bends the shin BACKWARD  -> NEGATIVE x   (KneeBendSign = -1)
--     elbow bends the forearm FORWARD -> POSITIVE x  (ElbowBendSign =  1)
--     shoulder raises the arm forward -> POSITIVE x
--   NorthPole/Cast.lua currently uses the opposite sign for all three. The
--   joint limits below make the wrong direction unreachable rather than
--   merely unused, and Validate.lua re-checks the result geometrically at
--   runtime so this reasoning is never load-bearing on its own.
local Skeleton={}
local V,CF,A=Vector3.new,CFrame.new,CFrame.Angles

Skeleton.KneeBendSign=-1
Skeleton.ElbowBendSign=1

-- Segment table. c0 = offset on the parent part, c1 = pivot on the child part,
-- exactly the Motor6D convention: child.CFrame = parent.CFrame * c0 * T * c1:Inverse()
-- `owner` is the single system permitted to write this joint (see Pose.lua).
local function seg(motor,parent,part,size,c0,c1,owner)
 return {motor=motor,parent=parent,part=part,size=size,c0=c0,c1=c1,owner=owner}
end
Skeleton.Segments={
 seg("Root","HumanoidRootPart","LowerTorso",V(1.75,0.40,0.90),V(0,0.30,0),V(0,0,0),"pose"),
 seg("Waist","LowerTorso","UpperTorso",V(1.75,1.40,0.90),V(0,0.20,0),V(0,-0.70,0),"pose"),
 seg("Neck","UpperTorso","Head",V(1.10,1.10,1.10),V(0,0.70,0),V(0,-0.55,0),"pose"),
 seg("LeftShoulder","UpperTorso","LeftUpperArm",V(0.85,1.15,0.85),V(-1.30,0.60,0),V(0,0.575,0),"pose"),
 seg("LeftElbow","LeftUpperArm","LeftLowerArm",V(0.78,0.95,0.78),V(0,-0.575,0),V(0,0.475,0),"pose"),
 seg("LeftWrist","LeftLowerArm","LeftHand",V(0.80,0.42,0.72),V(0,-0.475,0),V(0,0.21,0),"pose"),
 seg("RightShoulder","UpperTorso","RightUpperArm",V(0.85,1.15,0.85),V(1.30,0.60,0),V(0,0.575,0),"pose"),
 seg("RightElbow","RightUpperArm","RightLowerArm",V(0.78,0.95,0.78),V(0,-0.575,0),V(0,0.475,0),"pose"),
 seg("RightWrist","RightLowerArm","RightHand",V(0.80,0.42,0.72),V(0,-0.475,0),V(0,0.21,0),"pose"),
 seg("LeftHip","LowerTorso","LeftUpperLeg",V(0.88,1.35,0.88),V(-0.45,-0.20,0),V(0,0.675,0),"ik"),
 seg("LeftKnee","LeftUpperLeg","LeftLowerLeg",V(0.84,1.15,0.84),V(0,-0.675,0),V(0,0.575,0),"ik"),
 seg("LeftAnkle","LeftLowerLeg","LeftFoot",V(0.88,0.30,1.05),V(0,-0.575,0),V(0,0.15,0.24),"ik"),
 seg("RightHip","LowerTorso","RightUpperLeg",V(0.88,1.35,0.88),V(0.45,-0.20,0),V(0,0.675,0),"ik"),
 seg("RightKnee","RightUpperLeg","RightLowerLeg",V(0.84,1.15,0.84),V(0,-0.675,0),V(0,0.575,0),"ik"),
 seg("RightAnkle","RightLowerLeg","RightFoot",V(0.88,0.30,1.05),V(0,-0.575,0),V(0,0.15,0.24),"ik"),
}
Skeleton.ByMotor={}
for _,s in Skeleton.Segments do Skeleton.ByMotor[s.motor]=s end

-- Derived lengths, computed from the table above rather than restated, so a
-- proportion change can never silently desync the IK.
Skeleton.ThighLength=math.abs(Skeleton.ByMotor.LeftHip.c1.Y)+math.abs(Skeleton.ByMotor.LeftKnee.c0.Y) -- 1.25
Skeleton.ShinLength=math.abs(Skeleton.ByMotor.LeftKnee.c1.Y)+math.abs(Skeleton.ByMotor.LeftAnkle.c0.Y) -- 1.05
Skeleton.LegReach=Skeleton.ThighLength+Skeleton.ShinLength -- 2.30
-- Ankle pivot height above the sole when the foot is flat: foot half-height
-- (0.175) plus the pivot's own y offset (0.145).
Skeleton.AnkleHeight=Skeleton.ByMotor.LeftAnkle.c1.Y+Skeleton.ByMotor.LeftAnkle.size.Y/2 -- 0.30
-- Hip pivot height relative to the root part.
Skeleton.HipHeight=Skeleton.ByMotor.Root.c0.Y+Skeleton.ByMotor.LeftHip.c0.Y -- +0.075
Skeleton.RootToSole=Skeleton.AnkleHeight-Skeleton.HipHeight+Skeleton.LegReach -- 2.525, straight-legged
Skeleton.HipHalfWidth=math.abs(Skeleton.ByMotor.LeftHip.c0.X) -- 0.47
Skeleton.StandHeight=5.70
-- Standing flex, specified as an ANGLE rather than a height drop.
--
-- Near full extension a two-bone chain is violently non-linear: the previous
-- 0.05-stud "crouch" produced a 23.6 degree knee bend, which rendered as a
-- permanent half-squat. Specifying the bend directly and deriving the leg
-- span from it makes the standing pose mean what it says, and keeps the
-- solver a few degrees clear of the singularity where a straight leg has no
-- defined knee plane.
Skeleton.StandKneeBend=math.rad(5)
Skeleton.StandLegSpan=math.sqrt(
 Skeleton.ThighLength^2+Skeleton.ShinLength^2
 +2*Skeleton.ThighLength*Skeleton.ShinLength*math.cos(Skeleton.StandKneeBend))

-- Per-axis joint limits, in radians, as {min,max}. Asymmetric where the
-- anatomy is asymmetric: a knee may only bend one way and an elbow only the
-- other, which is enforced here as a hard bound rather than a convention.
local function lim(xmin,xmax,ymin,ymax,zmin,zmax)
 return {x={xmin,xmax},y={ymin,ymax},z={zmin,zmax}}
end
local d=math.rad
Skeleton.Limits={
 Root=lim(d(-8),d(8),d(-10),d(10),d(-8),d(8)),
 Waist=lim(d(-25),d(30),d(-22),d(22),d(-12),d(12)),
 Neck=lim(d(-28),d(32),d(-58),d(58),d(-14),d(14)),
 LeftShoulder=lim(d(-60),d(120),d(-45),d(45),d(-95),d(25)),
 RightShoulder=lim(d(-60),d(120),d(-45),d(45),d(-25),d(95)),
 LeftElbow=lim(0,d(150),d(-15),d(15),d(-15),d(15)),
 RightElbow=lim(0,d(150),d(-15),d(15),d(-15),d(15)),
 LeftWrist=lim(d(-40),d(40),d(-40),d(40),d(-30),d(30)),
 RightWrist=lim(d(-40),d(40),d(-40),d(40),d(-30),d(30)),
 LeftHip=lim(d(-50),d(85),d(-30),d(30),d(-30),d(30)),
 RightHip=lim(d(-50),d(85),d(-30),d(30),d(-30),d(30)),
 LeftKnee=lim(d(-150),0,d(-8),d(8),d(-8),d(8)),
 RightKnee=lim(d(-150),0,d(-8),d(8),d(-8),d(8)),
 LeftAnkle=lim(d(-40),d(40),d(-25),d(25),d(-25),d(25)),
 RightAnkle=lim(d(-40),d(40),d(-25),d(25),d(-25),d(25)),
}

-- The rest pose: the stable base every additive layer is measured from.
-- Deliberately tiny. A rest pose that already leans cannot be returned to
-- exactly, and "returns to exactly neutral" is the property this whole
-- foundation is built to guarantee.
Skeleton.RestPose={
 LeftShoulder={0,0,-0.030},
 RightShoulder={0,0,0.030},
 LeftElbow={0.10,0,0},
 RightElbow={0.10,0,0},
}

function Skeleton.restOf(motor)
 local r=Skeleton.RestPose[motor]
 if not r then return 0,0,0 end
 return r[1],r[2],r[3]
end

-- Forward kinematics over the whole skeleton. `transforms` maps motor name ->
-- CFrame; anything missing is identity. Returns part name -> world CFrame.
-- Segments are stored parent-before-child, so one pass is enough.
function Skeleton.forward(rootCFrame,transforms)
 local world={HumanoidRootPart=rootCFrame}
 for _,s in Skeleton.Segments do
  local parent=world[s.parent]
  if parent then
   local t=transforms[s.motor] or CF()
   world[s.part]=parent*CF(s.c0)*t*CF(s.c1):Inverse()
  end
 end
 return world
end

-- Two-bone leg IK.
--
-- Solves for the hip and knee transforms that put the ankle pivot exactly on
-- `ankleWorld`, with the knee displaced toward `poleWorld` (the direction the
-- knee should point, normally the character's facing). Then solves the ankle
-- transform directly from the resulting shin frame so the foot lands at
-- `footWorld`'s orientation - no sign guesswork on the ankle at all.
--
-- Returns hipCF, kneeCF, ankleCF, reachError. reachError is 0 when the target
-- was reachable; when it is not, the leg extends as far as it can along the
-- target direction and reports the shortfall, which Locomotion uses to lower
-- the pelvis rather than letting a foot hover.
function Skeleton.solveLeg(side,lowerTorsoCFrame,ankleWorld,footYawCFrame,poleWorld)
 local hip=Skeleton.ByMotor[side.."Hip"]
 local base=lowerTorsoCFrame*CF(hip.c0) -- the hip pivot frame, in world space
 local q=base:PointToObjectSpace(ankleWorld)
 local dist=q.Magnitude
 local L1,L2=Skeleton.ThighLength,Skeleton.ShinLength
 local maxReach=L1+L2-0.004
 local minReach=math.abs(L1-L2)+0.02
 local reachError=0
 if dist>maxReach then reachError=dist-maxReach;dist=maxReach
 elseif dist<minReach then dist=minReach end
 if q.Magnitude<1e-6 then q=V(0,-dist,0) end
 local n=q.Unit*dist
 local nDir=n.Unit

 -- Knee bend from the law of cosines. beta is a magnitude; the sign that
 -- makes it anatomically correct is applied once, from the constant above.
 local cosKnee=(L1*L1+L2*L2-dist*dist)/(2*L1*L2)
 local beta=math.pi-math.acos(math.clamp(cosKnee,-1,1))
 -- Angle between the thigh and the straight hip->ankle line.
 local cosAlpha=(L1*L1+dist*dist-L2*L2)/(2*L1*dist)
 local alpha=math.acos(math.clamp(cosAlpha,-1,1))

 -- Pole direction, expressed in the hip frame and made perpendicular to the
 -- hip->ankle line so the thigh can be rotated toward it by exactly alpha.
 local pole=base:VectorToObjectSpace(poleWorld)
 pole=pole-nDir*pole:Dot(nDir)
 if pole.Magnitude<1e-4 then
  pole=V(0,0,-1)-nDir*V(0,0,-1):Dot(nDir)
  if pole.Magnitude<1e-4 then pole=V(1,0,0) end
 end
 pole=pole.Unit
 local thighDir=(nDir*math.cos(alpha)+pole*math.sin(alpha)).Unit

 -- Build the thigh basis. Local -Y runs down the bone; local -Z must face the
 -- pole side, because the knee bends the shin toward local +Z (see the bend
 -- derivation at the top of this file), which must be away from the pole.
 local yAxis=-thighDir
 local zRaw=-(pole-thighDir*pole:Dot(thighDir))
 if zRaw.Magnitude<1e-4 then zRaw=V(0,0,1)-yAxis*V(0,0,1):Dot(yAxis) end
 local zAxis=zRaw.Unit
 local xAxis=yAxis:Cross(zAxis).Unit
 zAxis=xAxis:Cross(yAxis).Unit
 local hipCF=CFrame.fromMatrix(V(0,0,0),xAxis,yAxis,zAxis)
 local kneeCF=A(Skeleton.KneeBendSign*beta,0,0)

 -- Ankle: solve directly from the achieved shin frame to the wanted foot
 -- orientation. thigh = base*hip*c1inv ; shin = thigh*c0*knee*c1inv.
 local knee=Skeleton.ByMotor[side.."Knee"]
 local ankle=Skeleton.ByMotor[side.."Ankle"]
 local thighCF=base*hipCF*CF(hip.c1):Inverse()
 local shinCF=thighCF*CF(knee.c0)*kneeCF*CF(knee.c1):Inverse()
 -- shin*CF(c0) IS the current ankle pivot frame, and `wanted` is where that
 -- pivot should be, so the transform is just one frame relative to the other.
 -- (An earlier version post-multiplied by c1 here, which put the foot's
 -- CENTRE on the target and left every sole 0.145 studs off the floor.)
 local wanted=CF(ankleWorld)*(footYawCFrame-footYawCFrame.Position)
 local ankleCF=(shinCF*CF(ankle.c0)):Inverse()*wanted
 return hipCF,kneeCF,ankleCF,reachError
end

-- Highest pelvis height at which `ankleWorld` is still reachable by this hip,
-- given where the hip sits horizontally. Locomotion uses this to guarantee a
-- planted foot is never stretched off the floor.
function Skeleton.maxPelvisY(hipWorldXZ,ankleWorld)
 local dx=hipWorldXZ.X-ankleWorld.X
 local dz=hipWorldXZ.Z-ankleWorld.Z
 local horizontal=math.sqrt(dx*dx+dz*dz)
 local r=Skeleton.LegReach-0.02
 if horizontal>=r then return ankleWorld.Y end
 return ankleWorld.Y+math.sqrt(r*r-horizontal*horizontal)
end

return Skeleton
