--!nonstrict
-- Phase 0.A offline verification. Runs the real src/shared/Human modules
-- under the Luau CLI against a CFrame/Vector3 shim, drives the exact demo
-- timeline the Studio test plays, and reports the numbers a human watching
-- the screen cannot measure.
--
-- This does NOT replace the visual pass. It proves the maths; the eye still
-- has to confirm the result looks like a person.
local Skeleton,Pose,Loco,Actor,Validate=MOD.Skeleton,MOD.Pose,MOD.Locomotion,MOD.Actor,MOD.Validate
local V,CF=Vector3.new,CFrame.new
local ok=true
local function line(s) print(s) end
local function head(s) line("");line(s);line(string.rep("-",#s)) end
local function fmt(x) return string.format("%.6f",x) end

head("1. GEOMETRY, derived from the joint table (not restated)")
line(("  thigh length          %s"):format(fmt(Skeleton.ThighLength)))
line(("  shin length           %s"):format(fmt(Skeleton.ShinLength)))
line(("  leg reach             %s"):format(fmt(Skeleton.LegReach)))
line(("  ankle pivot height    %s"):format(fmt(Skeleton.AnkleHeight)))
line(("  root -> sole (straight) %s"):format(fmt(Skeleton.RootToSole)))
line(("  standing leg span     %s   (knee bend %.1f deg)"):format(fmt(Skeleton.StandLegSpan),math.deg(Skeleton.StandKneeBend)))
local headH=Skeleton.ByMotor.Neck.size.Y
local standing=Skeleton.RootToSole+Skeleton.ByMotor.Root.c0.Y+Skeleton.ByMotor.Waist.c0.Y
 -Skeleton.ByMotor.Waist.c1.Y+Skeleton.ByMotor.Neck.c0.Y-Skeleton.ByMotor.Neck.c1.Y+headH/2
line(("  standing height       %s"):format(fmt(standing)))
line(("  head / height         %s   (target ~0.19, R15-like)"):format(fmt(headH/standing)))
line(("  hip pivot -> sole / h %s   (target ~0.49)"):format(fmt((Skeleton.RootToSole+Skeleton.HipHeight)/standing)))
line(("  head / torso width    %s   (target ~0.6 for R15)"):format(fmt(Skeleton.ByMotor.Neck.size.X/Skeleton.ByMotor.Waist.size.X)))
if Skeleton.StandLegSpan>=Skeleton.LegReach then ok=false;line("  FAIL standing pose is at or past full leg extension") end

head("2. IK ACCURACY (does the solved chain actually reach the target?)")
do
 local worst,worstCase=0,""
 local lower=CF(0,3,0)
 for _,dx in {-0.9,-0.4,0,0.4,0.9} do
  for _,dz in {-1.1,-0.5,0,0.5,1.1} do
   for _,dy in {0.32,0.6,1.0,1.6,2.2} do
    for _,side in {"Left","Right"} do
     local target=V(dx,dy,dz)
     local footCF=CFrame.lookAt(target,target+V(0,0,-1))
     local hipCF,kneeCF,ankleCF,err=Skeleton.solveLeg(side,lower,target,footCF,V(0,0,-1))
     local t={}
     t[side.."Hip"]=hipCF;t[side.."Knee"]=kneeCF;t[side.."Ankle"]=ankleCF
     local world=Skeleton.forward(CF(0,3,0)*CF(0,-Skeleton.ByMotor.Root.c0.Y,0),t)
     -- rebuild the ankle pivot from the solved chain
     local hip=Skeleton.ByMotor[side.."Hip"]
     local knee=Skeleton.ByMotor[side.."Knee"]
     local base=lower*CF(hip.c0)
     local thigh=base*hipCF*CF(hip.c1):Inverse()
     local shin=thigh*CF(knee.c0)*kneeCF*CF(knee.c1):Inverse()
     local reached=(shin*CF(0,-knee.c1.Y,0)).Position
     if err==0 then
      local e=(reached-target).Magnitude
      if e>worst then worst=e;worstCase=("%s target (%.2f,%.2f,%.2f)"):format(side,dx,dy,dz) end
     end
    end
   end
  end
 end
 line(("  worst ankle placement error   %s studs   %s"):format(fmt(worst),worstCase))
 if worst>1e-5 then ok=false;line("  FAIL the IK does not land the ankle on its target") end
end

head("3. KNEE AND ELBOW BEND DIRECTION (geometric, not by convention)")
do
 local a=Actor.new({scale=1,floorY=0,quiet=true})
 a:walk(6,2.4)
 local session=Validate.newSession()
 local guard=0
 while a:isBusy() and guard<3000 do a:update(1/60);Validate.step(session,a);guard+=1 end
 local kneeWorst=session.worst.kneeDirection
 local elbowWorst=session.worst.elbowDirection
 line(("  knee pivot behind the hip-ankle chord (0 = always forward, correct)   %s"):format(fmt(kneeWorst)))
 line(("  elbow pivot ahead of the shoulder-wrist chord (0 = always behind)     %s"):format(fmt(elbowWorst)))
 if kneeWorst>0.15 then ok=false;line("  FAIL knees bend backward - flip Skeleton.KneeBendSign") end
 if elbowWorst>0.15 then ok=false;line("  FAIL elbows bend backward - flip Skeleton.ElbowBendSign") end
end

head("4. FULL DEMO TIMELINE (the same sequence the Studio test plays)")
do
 local a=Actor.new({scale=1,floorY=0,seed=3})
 MOD.Timeline.full(a)
 local session=Validate.newSession()
 local frames,guard=0,0
 while a:isBusy() and guard<20000 do a:update(1/60);Validate.step(session,a);frames+=1;guard+=1 end
 if guard>=20000 then ok=false;line(("  FAIL timeline stalled in command '%s' (%d still queued)"):format(a:label(),#a.queue)) end
 for i=1,180 do a:update(1/60);Validate.step(session,a);frames+=1 end
 line(("  simulated %d frames (%.1f s)"):format(frames,frames/60))
 line("")
 line(string.format("  %-18s %-14s %-10s %s","check","worst value","failures","verdict"))
 for _,row in Validate.report(session) do
  line(string.format("  %-18s %-14s %-10d %s",row.name,fmt(row.worst),row.failures,row.ok and "pass" or "FAIL"))
  if not row.ok then ok=false end
 end
end

head("5. REPEATED ACTION - does the rig distort as an action repeats?")
do
 local a=Actor.new({scale=1,floorY=0,quiet=true})
 local first,last
 for i=1,40 do
  a:gesture(2.0)
  local g=0;while a:isBusy() and g<9000 do a:update(1/60);g+=1 end;if g>=9000 then ok=false;line("  FAIL command timeline never completed") end
  for _=1,30 do a:update(1/60) end
  local snap={}
  for motor,cf in a.transforms do
   local x,y,z=cf:ToOrientation()
   snap[motor]={x,y,z,cf.Position.X,cf.Position.Y,cf.Position.Z}
  end
  if i==1 then first=snap end
  last=snap
 end
 local worst,where=0,"none"
 for motor,v in first do
  for i=1,6 do
   local d=math.abs(v[i]-last[motor][i])
   if d>worst then worst=d;where=motor end
  end
 end
 line(("  pose difference between gesture 1 and gesture 40   %s  (%s)"):format(fmt(worst),where))
 if worst~=0 then ok=false;line("  FAIL the rig is not returning to an identical pose") end
end

head("6. EXACT NEUTRAL RETURN (pose-owned joints, after the whole timeline)")
do
 local a=Actor.new({scale=1,floorY=0,quiet=true})
 a:look(0.9,0.1,2) a:gesture(2.2) a:turn(math.pi/2,1.8) a:walk(8,2.6)
 a:stepBack(1.4) a:flinch(1.0)
 local g=0;while a:isBusy() and g<9000 do a:update(1/60);g+=1 end;if g>=9000 then ok=false;line("  FAIL command timeline never completed") end
 for _=1,120 do a:update(1/60) end
 local worst,where=0,"none"
 for _,seg in Skeleton.Segments do
  if seg.owner=="pose" then
   local cf=a.transforms[seg.motor]
   local bx,by,bz=Skeleton.restOf(seg.motor)
   local x,y,z=cf:ToOrientation()
   local rest=CFrame.Angles(bx,by,bz)
   local rx,ry,rz=rest:ToOrientation()
   -- Root's ty legitimately carries the IK's pelvis drop, which depends on
   -- where the feet ended up standing. Everything else must be exactly rest.
   local expectedY=seg.motor=="Root" and -a.loco.pelvisDrop or 0
   for _,d in {math.abs(x-rx),math.abs(y-ry),math.abs(z-rz),
    math.abs(cf.Position.X),math.abs(cf.Position.Y-expectedY),math.abs(cf.Position.Z)} do
    if d>worst then worst=d;where=seg.motor end
   end
  end
 end
 line(("  worst deviation from rest pose   %s  (%s)"):format(fmt(worst),where))
 if worst>1e-9 then ok=false;line("  FAIL residual pose left behind after actions completed") end
 line(("  pelvis drop held by the IK       %s studs"):format(fmt(a.loco.pelvisDrop)))
 local leaked=false
 for motor,layers in a.lastFrame.touched do
  for layer in layers do
   if layer~="Breath" and layer~="WeightShift" and layer~="Locomotion" and layer~="Pelvis" then
    leaked=true;line(("  FAIL layer '%s' still contributing to %s"):format(layer,motor))
   end
  end
 end
 line(("  action layers still active       %s"):format(leaked and "yes" or "none"))
 if leaked then ok=false end
end

head("7. SPEED RESPONSE (is the step cycle driven by distance, not time?)")
do
 -- Measured over the CRUISE portion only. The ramps are deliberately not
 -- distance-driven any more: a decelerating body shortens its step, which is
 -- the whole point of the landing target following projected velocity. What
 -- must still hold - and what this actually tests - is that at a steady pace
 -- the cycle is driven by ground covered rather than by the clock.
 local function stepsPerStud(speed)
  local a=Actor.new({scale=1,floorY=0,quiet=true})
  a:walk(40,speed)
  local last={}
  for side,f in a.loco.feet do last[side]=f.plantId end
  local plants,dist,g=0,0,0
  while a:isBusy() and g<20000 do
   local before=a.position
   a:update(1/60);g+=1
   local cruising=a.loco.speed>=speed*0.95
   for side,f in a.loco.feet do
    if cruising then plants+=f.plantId-last[side] end
    last[side]=f.plantId
   end
   if cruising then dist+=(a.position-before).Magnitude end
  end
  if g>=20000 then ok=false;line("  FAIL command timeline never completed") end
  return dist>0.5 and plants/dist or 0
 end
 local slow,fast=stepsPerStud(1.3),stepsPerStud(2.6)
 line(("  steps per stud at speed 1.3   %s"):format(fmt(slow)))
 line(("  steps per stud at speed 2.6   %s"):format(fmt(fast)))
 if math.abs(slow-fast)>0.06 then ok=false;line("  FAIL the cycle is not distance-driven") end
end

head("8. ISOLATED LOCOMOTION CASES (decelerate, turn, then both together)")
do
 -- Deceleration and turning are tested APART before they are tested together,
 -- so a failure names which of the two owns it rather than only that their
 -- combination is broken. The pelvis numbers are the point of all three.
 local function run(label,build)
  local a=Actor.new({scale=1,floorY=0,quiet=true})
  build(a)
  local worstDrop,worstRate,worstBase,g=0,0,0,0
  local session=Validate.newSession()
  while a:isBusy() and g<20000 do
   a:update(1/60);Validate.step(session,a);g+=1
   if a.loco.pelvisDrop>worstDrop then worstDrop=a.loco.pelvisDrop end
   if a.loco.pelvisRate>worstRate then worstRate=a.loco.pelvisRate end
   local b=Loco.supportOffset(a.loco,a.rootCFrame)
   if b>worstBase then worstBase=b end
  end
  for _=1,120 do a:update(1/60) end
  local bad=worstDrop>Loco.MAXDROP or worstRate>Loco.PELVISRATE*1.02
   or worstBase>Loco.supportRadius(1,Loco.BOB) or g>=20000 or not Validate.passed(session)
  if bad then
   ok=false
   for _,row in Validate.report(session) do if not row.ok then print(label,row.name,row.worst,row.failures) end end
  end
  line(("  %-34s drop %s  rate %s  base %s  %s"):format(
   label,fmt(worstDrop),fmt(worstRate),fmt(worstBase),bad and "FAIL" or "pass"))
 end
 line(("  budget: drop <= %s   rate <= %s   base <= %s"):format(
  fmt(Loco.MAXDROP),fmt(Loco.PELVISRATE),fmt(Loco.supportRadius(1,Loco.BOB))))
 line("")
 for _,sp in {1.0,1.6,2.2,2.8,3.4} do
  run(("decelerate to a stop from %.1f"):format(sp),function(a) a:walk(12,sp) a:idle(1.5) end)
 end
 line("")
 for _,deg in {30,60,90,120} do
  run(("turn %d deg at constant speed"):format(deg),function(a)
   a:enqueue({kind="Walk",distance=14,speed=2.4,turn=-math.rad(deg),turnStart=2,turnEnd=11}) a:idle(1.0) end)
 end
 line("")
 for _,deg in {60,90} do
  run(("turn %d deg then decelerate"):format(deg),function(a)
   a:walk(10,2.6,-math.rad(deg)) a:walk(3,2.6) a:idle(1.5) end)
 end
end

head("9. SHARED STUDIO TAKE AT MULTIPLE FRAME RATES")
for _,dt in {1/30,1/60,1/120} do
 local a=Actor.new({seed=2})
 MOD.Timeline.full(a)
 local session=Validate.newSession()
 local count=0
 while a:isBusy() and count<18000 do
  a:update(dt);Validate.step(session,a);count+=1
 end
 local pass=Validate.passed(session) and not a:isBusy()
 if not pass then ok=false end
 line(("  %3d fps: body drop %.6f, vertical rate %.6f, %s"):format(
  1/dt,session.worst.bodyDrop,session.worst.bodyVerticalRate,pass and "pass" or "FAIL"))
 for _,row in Validate.report(session) do
  if not row.ok then line(("    %s: %.6f (%d frames)"):format(row.name,row.worst,row.failures)) end
 end
end

head("10. TURN PREDICTION DIRECTION")
for _,heading in {0,math.rad(120),-math.rad(120)} do
 for _,direction in {-1,1} do
  local a=Actor.new({quiet=true,yaw=heading})
  a:walk(10,2.4,direction*math.pi/2)
  local session=Validate.newSession()
  local count=0
  while a:isBusy() and count<1800 do
   a:update(1/60);Validate.step(session,a);count+=1
   if math.abs(a.loco.yawRate)>0.01 and a.loco.yawRate*direction<0 then
    ok=false;line("  FAIL predicted yaw opposes the commanded turn");break
   end
  end
  if a:isBusy() or not Validate.passed(session) then
   ok=false;line(("  FAIL turn from %.0f degrees, direction %d"):format(math.deg(heading),direction))
  end
 end
end

head("11. BODY VALIDATOR REGRESSIONS")
do
 local function fixture()
  local a=Actor.new({quiet=true})
  a:update(1/60)
  local session=Validate.newSession()
  Validate.step(session,a)
  return a,session
 end
 local a,session=fixture()
 a.world.LowerTorso=a.world.LowerTorso*CF(0,-0.4,0)
 Validate.step(session,a)
 if session.fail.bodyDrop==0 then ok=false;line("  FAIL hidden body collapse was accepted") end
 a,session=fixture()
 a.world.LowerTorso=a.world.LowerTorso*CF(0,-0.05,0)
 Validate.step(session,a)
 if session.fail.bodyVerticalRate==0 then ok=false;line("  FAIL shallow, sudden dip was accepted") end
 a,session=fixture()
 a.rootCFrame=a.rootCFrame*CF(1.2,0,0)
 Validate.step(session,a)
 if session.fail.overSupport==0 then ok=false;line("  FAIL body outside support base was accepted") end
 a,session=fixture()
 a.loco.reachError=0.08
 Validate.step(session,a)
 if session.fail.targetReach==0 then ok=false;line("  FAIL unreachable ankle target was accepted") end
 line("  exercised collapse, shallow jerk, unsupported stance, and unreachable target")
end

head(ok and "PHASE 0.A OFFLINE CHECKS: ALL PASS" or "PHASE 0.A OFFLINE CHECKS: FAILURES ABOVE")
if not ok then error("offline verification failed",0) end
