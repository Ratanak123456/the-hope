--!nonstrict
-- Phase 0.A: world-space foot plants, predictive release, and bounded gait height.
-- A plant is immutable until an explicit swing starts. Landing targets may
-- adapt during a swing; scripted turn/back-step targets retain their intent.
-- Nominal gait drop is 0.12 studs at scale 1; release budget is 0.14, and
-- the existing 0.22 failure ceiling is unchanged. Raw demand remains visible
-- to validation even when the applied pelvis correction is bounded.
local Skeleton=require(script.Parent.Skeleton)
local Pose=require(script.Parent.Pose)
local Loco={}
local V,CF,A=Vector3.new,CFrame.new,CFrame.Angles

local SIDES={"Left","Right"}
Loco.TRAIL=0.30
Loco.SWING=0.35
Loco.SWINGTIME=0.32

Loco.BOB=0.12
Loco.RELEASE=0.14
Loco.MAXDROP=0.22
-- Total body travel includes the gait bob and ambient pose, not just IK.
Loco.NORMALHEIGHT=0.18
Loco.PELVISRATE=0.60

-- Invert the leg reach circle to derive horizontal reach from a height budget.
function Loco.supportRadius(scale,budget)
 local r=Skeleton.LegReach-0.02
 local span=Skeleton.StandLegSpan-budget
 return math.sqrt(math.max(0.04,r*r-span*span))*scale
end

export type State=any

function Loco.new(scale:number,floorY:number): State
 return {
  scale=scale,floorY=floorY,
  stride=Loco.supportRadius(scale,Loco.BOB)*0.92/Loco.TRAIL,
  stepHeight=0.073*Skeleton.StandHeight*scale, -- 0.42 studs
  wasMoving=false,
  stance=Skeleton.HipHalfWidth*scale, -- feet track the hips exactly
  distance=0,                 -- total ground distance travelled, drives phase
  phase=0,
  speed=0,
  gaitWeight=0,
  feet={},
  pelvisDrop=0,
  dropSide=nil,
  reachError=0,
  rootVel=V(0,0,0),
  yawRate=0,
  prevRoot=nil,
  pelvisApplied=0,
  pelvisRate=0,
  speedRate=0,
  prevSpeed=0,
  lastDt=1/60,
  scripted=false,
 }
end

local function restFoot(state,rootCFrame,side)
 local lateral=(side=="Left" and -1 or 1)*state.stance
 local p=rootCFrame*CF(lateral,0,0)
 return CFrame.lookAt(V(p.X,state.floorY+Skeleton.AnkleHeight*state.scale,p.Z),
  V(p.X,state.floorY+Skeleton.AnkleHeight*state.scale,p.Z)+rootCFrame.LookVector)
end

function Loco.place(state,rootCFrame)
 state.feet={}
 for _,side in SIDES do
  state.feet[side]={mode="planted",target=restFoot(state,rootCFrame,side),progress=0,from=nil,to=nil,plantId=1}
 end
 state.distance=0;state.phase=0;state.speed=0;state.pelvisDrop=0;state.reachError=0;state.dropSide=nil
end

local function plantSpot(state,rootCFrame,side,ahead)
 local lateral=(side=="Left" and -1 or 1)*state.stance
 local p=rootCFrame*CF(lateral,0,-ahead)
 local y=state.floorY+Skeleton.AnkleHeight*state.scale
 return CFrame.lookAt(V(p.X,y,p.Z),V(p.X,y,p.Z)+rootCFrame.LookVector)
end

-- Deliberate release: only this transition permits a planted target to move.
function Loco.stepTo(state,side,target,swingDistance)
 local f=state.feet[side]
 if not f then return end
 f.mode="swing";f.from=f.target;f.to=target;f.progress=0
 f.adaptive=not state.scripted
 f.swingDistance=math.max(swingDistance or state.stride,0.05)
end

-- Double-support COM proxy: distance to the segment between the feet.
function Loco.supportOffset(state,rootCFrame)
 local L,R=state.feet.Left,state.feet.Right
 if L.mode~="planted" or R.mode~="planted" then return 0 end
 local a,b=L.target.Position,R.target.Position
 local p=rootCFrame.Position
 local abx,abz=b.X-a.X,b.Z-a.Z
 local len2=abx*abx+abz*abz
 local t=0
 if len2>1e-6 then t=math.clamp(((p.X-a.X)*abx+(p.Z-a.Z)*abz)/len2,0,1) end
 local dx,dz=p.X-(a.X+abx*t),p.Z-(a.Z+abz*t)
 return math.sqrt(dx*dx+dz*dz)
end

function Loco.isSwinging(state)
 for _,side in SIDES do if state.feet[side].mode=="swing" then return true,side end end
 return false
end

local function trail(state,rootCFrame,side)
 local f=state.feet[side]
 local local_=rootCFrame:PointToObjectSpace(f.target.Position)
 return local_.Z -- +Z is behind, because -Z is forward
end

local function hipOffset(state,rootCFrame,side,footPos)
 local l=rootCFrame:PointToObjectSpace(footPos)
 local lateral=(side=="Left" and -1 or 1)*state.stance
 local dx,dz=l.X-lateral,l.Z
 return math.sqrt(dx*dx+dz*dz)
end

local function trackRoot(state,rootCFrame,dt)
 local prev=state.prevRoot
 if prev and dt>1e-5 then
  state.rootVel=(rootCFrame.Position-prev.Position)/dt
  local a,b=prev.LookVector,rootCFrame.LookVector
  state.yawRate=math.atan2(a.Z*b.X-a.X*b.Z,a.X*b.X+a.Z*b.Z)/dt
 end
 state.prevRoot=rootCFrame
end

-- Predict translation and yaw through the remaining swing time.
local function projectRoot(state,rootCFrame,ahead)
 if ahead<=1e-4 then return rootCFrame end
 local travelTime=ahead
 if state.speed<=0.05 then travelTime=0
 elseif state.speedRate<0 then
  local stoppingTime=math.min(ahead,state.speed/-state.speedRate)
  travelTime=stoppingTime+0.5*state.speedRate/state.speed*stoppingTime*stoppingTime
 end
 local p=rootCFrame.Position+state.rootVel*travelTime
 local yaw=math.atan2(-rootCFrame.LookVector.X,-rootCFrame.LookVector.Z)
 return CF(p.X,p.Y,p.Z)*A(0,yaw+state.yawRate*ahead,0)
end

local function uncross(state,rootCFrame,side,spot)
 local l=rootCFrame:PointToObjectSpace(spot.Position)
 local want=(side=="Left" and -1 or 1)
 local minX=want*state.stance*0.6
 local x=l.X
 if (want>0 and x<minX) or (want<0 and x>minX) then x=minX else return spot end
 local q=rootCFrame*CF(x,0,l.Z)
 local y=state.floorY+Skeleton.AnkleHeight*state.scale
 return CFrame.lookAt(V(q.X,y,q.Z),V(q.X,y,q.Z)+spot.LookVector)
end

-- Turns use shorter steps so a support foot is not stranded sideways while
-- its partner travels around the arc. Straight walking retains its cadence.
local function stepStride(state)
 return state.stride*math.clamp(1-math.abs(state.yawRate)*0.65,0.60,1)
end

-- Shorten the landing stride using projected speed during deceleration.
local function aheadFor(state,speed,eta)
 if speed<=0.05 then return 0 end
 local proj=math.max(0,speed+state.speedRate*(eta or 0))
 return stepStride(state)*Loco.TRAIL*math.clamp(proj/speed,0,1)
end

function Loco.setScripted(state,on) state.scripted=on and true or false end

function Loco.update(state,rootCFrame,speed,dt)
 local travelled=speed*dt
 state.speed=speed
 local desiredWeight=math.clamp(speed/2.6,0,1)
 state.gaitWeight=math.clamp(desiredWeight,state.gaitWeight-3*dt,state.gaitWeight+3*dt)
 state.lastDt=dt
 state.distance+=travelled
 state.phase=(state.distance/(state.stride*2))%1
 trackRoot(state,rootCFrame,dt)
 if dt>1e-5 then
  state.speedRate=state.speedRate*0.7+((speed-state.prevSpeed)/dt)*0.3
 end
 state.prevSpeed=speed

 for _,side in SIDES do
  local f=state.feet[side]
  if f.mode=="swing" then
   local advance
   if speed>0.35 then advance=travelled/f.swingDistance
   else advance=dt/Loco.SWINGTIME end
   if f.adaptive and (state.speedRate< -0.1 or math.abs(state.yawRate)>0.05) then
    -- During braking/turning, finish the airborne step before the remaining
    -- support is exhausted. Never lift both feet or wait for a visible dip.
    local future=projectRoot(state,rootCFrame,0.12)
    for _,supportSide in SIDES do
     local support=state.feet[supportSide]
     if support.mode=="planted" and hipOffset(state,future,supportSide,support.target.Position)>Loco.supportRadius(state.scale,Loco.RELEASE) then
      advance=math.max(advance,dt/0.20)
     end
    end
   end
   f.progress=math.min(1,f.progress+advance)

   local rate=(speed>0.35) and (speed/f.swingDistance) or (1/Loco.SWINGTIME)
   local eta=(rate>1e-4) and math.min((1-f.progress)/rate,0.6) or 0
   -- Adapt in flight at a bounded target velocity; never rewrite a plant.
   if f.adaptive then
    local desired=uncross(state,rootCFrame,side,plantSpot(state,projectRoot(state,rootCFrame,eta),side,aheadFor(state,speed,eta)))
    local distance=(desired.Position-f.to.Position).Magnitude
    f.to=f.to:Lerp(desired,math.min(1,dt*4*state.scale/math.max(distance,0.001)))
   end
   local t=f.progress
   local flat=f.from.Position:Lerp(f.to.Position,Pose.ease(t))
   local lift=math.sin(math.pi*t)*state.stepHeight
   local rot=f.from:Lerp(f.to,Pose.ease(t))
   f.current=CF(flat.X,flat.Y+lift,flat.Z)*(rot-rot.Position)
   if t>=1 then
    -- Land on the approached target; never snap the foot into reach here.
    f.mode="planted";f.target=f.to;f.current=nil;f.from=nil;f.to=nil;f.plantId+=1
   end
  else
   f.current=nil
  end
 end

 local moving=speed>0.35
 if moving and not state.wasMoving and not Loco.isSwinging(state) then
  local side=trail(state,rootCFrame,"Right")>=trail(state,rootCFrame,"Left") and "Right" or "Left"
  Loco.stepTo(state,side,plantSpot(state,rootCFrame,side,state.stride*0.30),state.stride*0.22)
 end
 state.wasMoving=moving

 if speed>0.35 and not Loco.isSwinging(state) then
  local worstSide,worstTrail=nil,-math.huge
  for _,side in SIDES do
   local t=trail(state,rootCFrame,side)
   if t>worstTrail then worstTrail=t;worstSide=side end
  end
  if worstTrail>stepStride(state)*Loco.TRAIL then
   Loco.stepTo(state,worstSide,
    uncross(state,rootCFrame,worstSide,
     plantSpot(state,projectRoot(state,rootCFrame,Loco.SWINGTIME),worstSide,aheadFor(state,speed,Loco.SWINGTIME))),
    stepStride(state)*Loco.SWING)
  end
 end

 -- Reserve enough support reach for the next swing, including turning travel.
 if not state.scripted and not Loco.isSwinging(state) then
  local limit=Loco.supportRadius(state.scale,Loco.RELEASE)
  local horizon=stepStride(state)*Loco.SWING/math.max(speed,0.35)
  local turned=math.abs(state.yawRate)>0.05 and projectRoot(state,rootCFrame,math.min(horizon,0.4)) or rootCFrame
  local worstSide,worst=nil,limit
  for _,side in SIDES do
   local f=state.feet[side]
   if f.mode=="planted" then
    local d=hipOffset(state,turned,side,f.target.Position)
    local twist=math.acos(math.clamp(f.target.LookVector:Dot(turned.LookVector),-1,1))
    if twist>math.rad(40) then d=math.max(d,limit+(twist-math.rad(40))*state.scale) end
    if d>worst then worst=d;worstSide=side end
   end
  end
  if worstSide then
   Loco.stepTo(state,worstSide,
    uncross(state,rootCFrame,worstSide,
     plantSpot(state,projectRoot(state,rootCFrame,Loco.SWINGTIME),worstSide,aheadFor(state,speed,Loco.SWINGTIME))),
    stepStride(state)*Loco.SWING)
  end
 end
end

-- Recover neutral with alternating steps; never slide either support foot.
function Loco.squareUp(state,rootCFrame)
 if Loco.isSwinging(state) then return false end
 for _,side in SIDES do
  local f=state.feet[side]
  local rest=restFoot(state,rootCFrame,side)
  local offset=(f.target.Position-rest.Position).Magnitude
  local yawDelta=1-f.target.LookVector:Dot(rootCFrame.LookVector)
  if offset>0.18*state.scale or yawDelta>0.01 then
   Loco.stepTo(state,side,rest,math.max(offset,0.25))
   return true
  end
 end
 return false
end

function Loco.footTarget(state,side)
 local f=state.feet[side]
 return f.current or f.target
end

-- Small, rate-limited gait-height adjustment; never hide raw reach demand.
function Loco.pelvisCorrection(state,lowerTorsoCFrame)
 local drop,worstSide=0,nil
 local prepared=0
 for _,side in SIDES do
  local f=state.feet[side]
  if f.mode=="planted" or f.mode=="swing" then
   local hip=lowerTorsoCFrame*CF(Skeleton.ByMotor[side.."Hip"].c0)
   local ankle=Loco.footTarget(state,side).Position
   local ceiling=Skeleton.maxPelvisY(hip.Position,ankle)
   local excess=hip.Position.Y-ceiling
   -- Prepare a bounded weight transfer before touchdown rather than dipping
   -- suddenly when the descending foot becomes support.
   if f.mode=="swing" and f.to then
    local landing=hip.Position.Y-Skeleton.maxPelvisY(hip.Position,f.to.Position)
    prepared=math.max(prepared,math.min(landing,Loco.BOB*state.scale)*Pose.ease(f.progress))
   end
   if excess>drop then drop=excess;worstSide=side end
  end
 end
 state.pelvisDrop=drop
 state.dropSide=worstSide
 local want=math.min(math.max(drop,prepared),Loco.MAXDROP*state.scale)
 local dt=state.lastDt or (1/60)
 local step=Loco.PELVISRATE*state.scale*dt
 local applied=math.clamp(want,state.pelvisApplied-step,state.pelvisApplied+step)
 state.pelvisRate=(dt>1e-5) and math.abs(applied-state.pelvisApplied)/dt or 0
 state.pelvisApplied=applied
 return -applied
end

-- Solve the legs after the body pose and its bounded height adjustment.
function Loco.solveLegs(state,rootCFrame,lowerTorsoCFrame,out)
 local pole=rootCFrame.LookVector
 local worst=0
 for _,side in SIDES do
  local target=Loco.footTarget(state,side)
  local hipCF,kneeCF,ankleCF,err=Skeleton.solveLeg(side,lowerTorsoCFrame,target.Position,target,pole)
  out[side.."Hip"]=hipCF;out[side.."Knee"]=kneeCF;out[side.."Ankle"]=ankleCF
  if err>worst then worst=err end
 end
 state.reachError=worst
 return worst
end

function Loco.contribute(state,frame,weight)
 local w=(weight or 1)*state.gaitWeight
 if w<=0 then return end
 local swing=math.sin(state.phase*math.pi*2)
 local bob=math.cos(state.phase*math.pi*4)
 Pose.add(frame,"Locomotion","LeftShoulder",swing*0.42,0,0,0,0,0,w)
 Pose.add(frame,"Locomotion","RightShoulder",-swing*0.42,0,0,0,0,0,w)
 Pose.add(frame,"Locomotion","LeftElbow",0.18+math.max(0,-swing)*0.12,0,0,0,0,0,w)
 Pose.add(frame,"Locomotion","RightElbow",0.18+math.max(0,swing)*0.12,0,0,0,0,0,w)
 Pose.add(frame,"Locomotion","Waist",0.03,-swing*0.05,0,0,0,0,w)
 Pose.add(frame,"Locomotion","Neck",0,swing*0.02,0,0,0,0,w)
 Pose.add(frame,"Locomotion","Root",0,0,0,0,-0.035*state.scale*(1-bob)/2,0,w)
end

return Loco
