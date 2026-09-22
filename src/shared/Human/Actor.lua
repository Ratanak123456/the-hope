--!nonstrict
-- Phase 0.A foundation, module 4 of 6: the actor - layers, command timeline
-- and the per-frame solve order.
--
-- THE WORLD ROOT CANNOT PITCH OR ROLL. It is built every frame as
--   CFrame.new(position) * CFrame.Angles(0, yaw, 0)
-- from a position and a single yaw scalar. There is no code path anywhere in
-- this foundation that can introduce root pitch or roll, so "the character
-- became horizontal" and "the root gained pitch during locomotion" are not
-- bugs that were fixed, they are states that can no longer be expressed. All
-- body lean is Waist and Root-motor work, inside clamped limits.
--
-- SOLVE ORDER, once per frame, always the same:
--   1. advance the command timeline -> speed, yaw, layer states
--   2. advance the gait -> foot targets (planted feet are world constants)
--   3. build the additive frame from the layers  (pose-owned joints)
--   4. resolve to CFrames, rest pose + clamp
--   5. drop the pelvis if a leg would otherwise overreach
--   6. IK both legs to the foot targets            (ik-owned joints)
--   7. forward kinematics -> world CFrames
-- Steps 3 and 6 write disjoint joint sets, checked by Pose.add, so no two
-- systems ever write the same joint.
local Skeleton=require(script.Parent.Skeleton)
local Pose=require(script.Parent.Pose)
local Loco=require(script.Parent.Locomotion)
local Actor={}
Actor.__index=Actor
local V,CF,A=Vector3.new,CFrame.new,CFrame.Angles

export type Actor=any

function Actor.new(opts): Actor
 local scale=opts and opts.scale or 1
 local floorY=opts and opts.floorY or 0
 local self=setmetatable({},Actor)
 self.scale=scale
 self.floorY=floorY
 -- Hip pivot sits exactly one StandLegSpan above the ankle target, which is
 -- what makes the standing knee bend equal Skeleton.StandKneeBend and not
 -- whatever a height guess happens to produce.
 self.standY=floorY+(Skeleton.StandLegSpan-Skeleton.HipHeight+Skeleton.AnkleHeight)*scale
 self.position=V((opts and opts.position or V(0,0,0)).X,self.standY,(opts and opts.position or V(0,0,0)).Z)
 self.yaw=opts and opts.yaw or 0
 self.seed=opts and opts.seed or 0
 -- Test affordance only: suppresses the two always-on ambient layers so an
 -- offline harness can compare two poses bit-for-bit. Never set in a scene.
 self.quiet=opts and opts.quiet or false
 self.time=0
 self.loco=Loco.new(scale,floorY)
 self.queue={}
 self.current=nil
 self.commandTime=0
 self.speed=0
 self.state="idle"
 -- Layer states. Each is a plain envelope in [0,1] that genuinely reaches
 -- both endpoints, never a filter that approaches one.
 self.lookState={yaw=0,pitch=0,weight=0,targetYaw=0,targetPitch=0,timer=0,duration=0}
 self.gestureState={timer=-1,duration=0,side="Right"}
 self.reactionState={timer=-1,duration=0,strength=0}
 self.settleState={timer=-1,duration=0}
 self.lastFrame=nil
 self.transforms={}
 self.rootCFrame=CF(self.position)*A(0,self.yaw,0)
 Loco.place(self.loco,self.rootCFrame)
 return self
end

function Actor:enqueue(cmd)
 table.insert(self.queue,cmd)
 return self
end

function Actor:idle(duration) return self:enqueue({kind="Idle",duration=duration}) end
function Actor:look(yaw,pitch,duration) return self:enqueue({kind="Look",yaw=yaw,pitch=pitch or 0,duration=duration}) end
function Actor:gesture(duration,side) return self:enqueue({kind="Gesture",duration=duration,side=side or "Right"}) end
function Actor:turn(delta,duration) return self:enqueue({kind="Turn",delta=delta,duration=duration or 1.7}) end
function Actor:walk(distance,speed,turnDelta) return self:enqueue({kind="Walk",distance=distance,speed=speed or 2.6,turn=turnDelta or 0}) end
function Actor:stepBack(duration) return self:enqueue({kind="StepBack",duration=duration or 1.5}) end
function Actor:flinch(duration) return self:enqueue({kind="Flinch",duration=duration or 1.1}) end

-- ---------------------------------------------------------------- commands

local function beginCommand(self,cmd)
 self.current=cmd
 self.commandTime=0
 Loco.setScripted(self.loco,cmd.kind=="Turn" or cmd.kind=="StepBack" or cmd.kind=="Flinch")
 if cmd.kind=="Look" then
  self.lookState.targetYaw=cmd.yaw;self.lookState.targetPitch=cmd.pitch
  self.lookState.timer=0;self.lookState.duration=cmd.duration
 elseif cmd.kind=="Gesture" then
  self.gestureState.timer=0;self.gestureState.duration=cmd.duration;self.gestureState.side=cmd.side
  self.lookState.targetYaw=0.35;self.lookState.targetPitch=0.02
  self.lookState.timer=0;self.lookState.duration=cmd.duration
 elseif cmd.kind=="Turn" then
  cmd.fromYaw=self.yaw;cmd.toYaw=self.yaw+cmd.delta
  cmd.firstFoot=false;cmd.secondFoot=false
  self.lookState.targetYaw=math.clamp(cmd.delta,-0.9,0.9)
  self.lookState.timer=0;self.lookState.duration=cmd.duration
 elseif cmd.kind=="Walk" then
  cmd.travelled=0;cmd.settling=false;cmd.fromYaw=self.yaw;cmd.toYaw=self.yaw+(cmd.turn or 0)
 elseif cmd.kind=="StepBack" then
  cmd.stepped=false;cmd.moved=0
 elseif cmd.kind=="Flinch" then
  self.reactionState.timer=0;self.reactionState.duration=cmd.duration;self.reactionState.strength=1
  cmd.stepped=false
 end
end

-- Returns true when the command is finished.
local function advanceCommand(self,cmd,dt)
 local t=self.commandTime
 if cmd.kind=="Idle" then
  self.speed=0
  return t>=cmd.duration
 elseif cmd.kind=="Look" then
  self.speed=0
  if t>=cmd.duration*0.55 then self.lookState.targetYaw=0;self.lookState.targetPitch=0 end
  return t>=cmd.duration
 elseif cmd.kind=="Gesture" then
  self.speed=0
  if t>=cmd.duration*0.7 then self.lookState.targetYaw=0;self.lookState.targetPitch=0 end
  return t>=cmd.duration and self.gestureState.timer<0
 elseif cmd.kind=="Turn" then
  -- Head leads, torso follows, the near foot re-plants, the root yaw
  -- completes, then the far foot settles. The root never rotates before a
  -- foot has moved, which is what stops it reading as a chess piece.
  local p=math.clamp(t/cmd.duration,0,1)
  local inner=cmd.delta>0 and "Right" or "Left"
  local outer=cmd.delta>0 and "Left" or "Right"
  if p>=0.30 and not cmd.firstFoot then
   cmd.firstFoot=true
   local futureRoot=CF(self.position)*A(0,cmd.toYaw,0)
   local lateral=(inner=="Left" and -1 or 1)*self.loco.stance
   local spot=futureRoot*CF(lateral,0,0)
   local y=self.floorY+Skeleton.AnkleHeight*self.scale
   Loco.stepTo(self.loco,inner,CFrame.lookAt(V(spot.X,y,spot.Z),V(spot.X,y,spot.Z)+futureRoot.LookVector),0.7*self.scale)
  end
  if p>=0.62 and not cmd.secondFoot then
   cmd.secondFoot=true
   local futureRoot=CF(self.position)*A(0,cmd.toYaw,0)
   local lateral=(outer=="Left" and -1 or 1)*self.loco.stance
   local spot=futureRoot*CF(lateral,0,0)
   local y=self.floorY+Skeleton.AnkleHeight*self.scale
   Loco.stepTo(self.loco,outer,CFrame.lookAt(V(spot.X,y,spot.Z),V(spot.X,y,spot.Z)+futureRoot.LookVector),0.7*self.scale)
  end
  -- Root yaw only moves across the middle of the turn, after the head.
  local yawP=Pose.ease(math.clamp((p-0.34)/0.5,0,1))
  self.yaw=cmd.fromYaw+(cmd.toYaw-cmd.fromYaw)*yawP
  self.speed=0
  if t>=cmd.duration*0.5 then self.lookState.targetYaw=0 end
  return p>=1 and not Loco.isSwinging(self.loco)
 elseif cmd.kind=="Walk" then
  local cruise=cmd.speed
  local remaining=cmd.distance-cmd.travelled
  -- Accelerate in, decelerate over the last stride so the stop is planned
  -- rather than an abrupt halt with a leg still in the air.
  local rampIn=Pose.ease(math.clamp(t/0.45,0,1))
  local rampOut=Pose.ease(math.clamp(remaining/(self.loco.stride*1.15),0,1))
  self.speed=cruise*math.min(rampIn,rampOut)
  local step
  if remaining<=0.5*dt then
   -- The decel curve approaches the target asymptotically, so the last
   -- frame of travel is closed outright. Below this threshold the snap is
   -- far smaller than one frame of travel and cannot be seen; without it the
   -- command never reports complete.
   step=remaining;self.speed=0
  else
   -- Floor the crawl so arrival is guaranteed in finite time. 0.5 is above
   -- Locomotion's 0.35 swing threshold on purpose: the walk is allowed to
   -- start one last step here, and the stop then waits for that foot to
   -- plant rather than halting with a leg in the air.
   self.speed=math.max(self.speed,0.5)
   step=math.min(self.speed*dt,remaining)
  end
  cmd.travelled+=step
  local turnStart=cmd.turnStart or 0
  local turnEnd=cmd.turnEnd or cmd.distance
  local yawP=Pose.ease(math.clamp((cmd.travelled-turnStart)/math.max(turnEnd-turnStart,0.001),0,1))
  self.yaw=cmd.fromYaw+(cmd.toYaw-cmd.fromYaw)*yawP
  local root=CF(self.position)*A(0,self.yaw,0)
  self.position=self.position+root.LookVector*step
  if cmd.travelled>=cmd.distance-1e-4 then
   self.speed=0
   if not Loco.isSwinging(self.loco) then
    -- One settle per walk. Keying this off settleState.timer alone restarted
    -- the settle the instant it finished, so the command could never report
    -- complete - the walk looked fine and simply never ended.
    if not cmd.settling then
     cmd.settling=true;self.settleState.timer=0;self.settleState.duration=0.55
     return false
    end
    if Loco.isSwinging(self.loco) then return false end
    return self.settleState.timer<0
   end
  end
  return false
 elseif cmd.kind=="StepBack" then
  -- Weight shifts first, then the foot moves, then the body follows it.
  local p=math.clamp(t/cmd.duration,0,1)
  self.speed=0
  if p>=0.28 and not cmd.stepped then
   cmd.stepped=true
   local root=CF(self.position)*A(0,self.yaw,0)
   local lateral=-self.loco.stance
   local spot=root*CF(lateral,0,0.55*self.scale)
   local y=self.floorY+Skeleton.AnkleHeight*self.scale
   Loco.stepTo(self.loco,"Left",CFrame.lookAt(V(spot.X,y,spot.Z),V(spot.X,y,spot.Z)+root.LookVector),0.55*self.scale)
  end
  if p>=0.45 and p<=0.85 then
   local root=CF(self.position)*A(0,self.yaw,0)
   local move=0.30*self.scale*(dt/(cmd.duration*0.4))
   self.position=self.position-root.LookVector*move
   cmd.moved+=move
  end
  if p>=0.7 and not cmd.settled then
   cmd.settled=true
   local root=CF(self.position)*A(0,self.yaw,0)
   local lateral=self.loco.stance
   local spot=root*CF(lateral,0,0)
   local y=self.floorY+Skeleton.AnkleHeight*self.scale
   Loco.stepTo(self.loco,"Right",CFrame.lookAt(V(spot.X,y,spot.Z),V(spot.X,y,spot.Z)+root.LookVector),0.6*self.scale)
  end
  return p>=1 and not Loco.isSwinging(self.loco)
 elseif cmd.kind=="Flinch" then
  -- Shoulders and torso only, plus one small defensive foot move. Nothing
  -- here can touch the world root's orientation.
  local p=math.clamp(t/cmd.duration,0,1)
  self.speed=0
  if p>=0.16 and not cmd.stepped then
   cmd.stepped=true
   local root=CF(self.position)*A(0,self.yaw,0)
   local spot=root*CF(-self.loco.stance,0,0.42*self.scale)
   local y=self.floorY+Skeleton.AnkleHeight*self.scale
   Loco.stepTo(self.loco,"Left",CFrame.lookAt(V(spot.X,y,spot.Z),V(spot.X,y,spot.Z)+root.LookVector),0.45*self.scale)
  end
  return p>=1 and self.reactionState.timer<0 and not Loco.isSwinging(self.loco)
 end
 return true
end

-- ------------------------------------------------------------------ layers

local function layerBreath(self,frame)
 -- Waist and shoulders only. Never the legs: breathing must not move a
 -- planted foot, and with the legs on IK it structurally cannot.
 local b=math.sin(self.time*math.pi*2/3.6+self.seed)
 Pose.add(frame,"Breath","Waist",0.010+b*0.009,0,0,0,0,0,1)
 Pose.add(frame,"Breath","LeftShoulder",b*0.016,0,-b*0.010,0,0,0,1)
 Pose.add(frame,"Breath","RightShoulder",b*0.016,0,b*0.010,0,0,0,1)
 Pose.add(frame,"Breath","Neck",-b*0.006,0,0,0,0,0,1)
end

local function layerWeightShift(self,frame)
 -- Suppressed entirely while moving, so the gait owns the pelvis alone.
 local w=1-math.clamp(self.speed/1.2,0,1)
 if w<=0 then return end
 local s=math.sin(self.time*0.42+self.seed*1.7)
 local s2=math.sin(self.time*0.23+self.seed*0.4)
 local sway=(s*0.6+s2*0.4)
 Pose.add(frame,"WeightShift","Root",0,0,sway*0.012,sway*0.055*self.scale,0,0,w)
 Pose.add(frame,"WeightShift","Waist",0,sway*0.020,-sway*0.022,0,0,0,w)
 Pose.add(frame,"WeightShift","Neck",0,-sway*0.010,0,0,0,0,w)
end

local function layerLook(self,frame,dt)
 local L=self.lookState
 if L.duration>0 then
  L.timer=math.min(L.timer+dt,L.duration)
 end
 -- Ease the live angle toward the requested one over a fixed ramp that
 -- genuinely arrives, then hold. No exponential filter, so a look that has
 -- been asked to return to 0 reaches exactly 0.
 local rate=dt/0.38
 local function approach(current,target)
  local delta=target-current
  local maxStep=math.abs(delta)
  local step=math.min(maxStep,rate*math.max(math.abs(target-current),0.6))
  if math.abs(delta)<=step then return target end
  return current+(delta>0 and step or -step)
 end
 L.yaw=approach(L.yaw,L.targetYaw)
 L.pitch=approach(L.pitch,L.targetPitch)
 if L.yaw==0 and L.pitch==0 then return end
 -- The neck leads. The waist assists only past a threshold, and only with
 -- the surplus, so a small look is pure neck.
 local assist=0
 local threshold=0.42
 if math.abs(L.yaw)>threshold then
  assist=(math.abs(L.yaw)-threshold)*0.45*(L.yaw>0 and 1 or -1)
 end
 Pose.add(frame,"Look","Neck",L.pitch,L.yaw-assist,0,0,0,0,1)
 if assist~=0 then Pose.add(frame,"Look","Waist",0,assist,0,0,0,0,1) end
end

local function layerGesture(self,frame,dt)
 local G=self.gestureState
 if G.timer<0 then return end
 G.timer+=dt
 local t=G.timer
 if t>=G.duration then G.timer=-1;return end
 local sign=G.side=="Left" and -1 or 1
 -- Shoulder prepares first; forearm follows, holds, then returns more slowly.
 local preparation=Pose.envelope(t,0.24,math.max(0.1,G.duration-1.0),0.76)
 local forearm=Pose.envelope(math.max(0,t-0.14),0.52,math.max(0.1,G.duration-1.46),0.80)
 Pose.add(frame,"Gesture",G.side.."Shoulder",0.12,0,sign*0.07,0,0,0,preparation)
 Pose.add(frame,"Gesture",G.side.."Elbow",1.05,0,0,0,0,0,forearm)
 Pose.add(frame,"Gesture",G.side.."Wrist",0.03,sign*0.10,0,0,0,0,forearm)

end

local function layerReaction(self,frame,dt)
 local R=self.reactionState
 if R.timer<0 then return end
 R.timer+=dt
 local w=Pose.envelope(R.timer,0.09,0.12,math.max(R.duration-0.21,0.3))*R.strength
 if w<=0 then R.timer=-1;return end
 -- Shoulders and torso. The Root motor gets a small vertical dip only; no
 -- pitch, no roll, and the world root is untouched by construction.
 Pose.add(frame,"Reaction","Waist",0.20,0,-0.05,0,0,0,w)
 Pose.add(frame,"Reaction","Root",0,0,0,0,-0.10*self.scale,0,w)
 Pose.add(frame,"Reaction","LeftShoulder",0.30,0,-0.22,0,0,0,w)
 Pose.add(frame,"Reaction","RightShoulder",0.26,0,0.22,0,0,0,w)
 Pose.add(frame,"Reaction","LeftElbow",0.62,0,0,0,0,0,w)
 Pose.add(frame,"Reaction","RightElbow",0.55,0,0,0,0,0,w)
 Pose.add(frame,"Reaction","Neck",-0.10,0,0,0,0,0,w)
end

local function layerSettle(self,frame,dt)
 local S=self.settleState
 if S.timer<0 then return end
 S.timer+=dt
 local w=Pose.envelope(S.timer,0.10,0.05,S.duration-0.15)
 if w<=0 then S.timer=-1;return end
 Pose.add(frame,"Action","Root",0,0,0,0,-0.045*self.scale,0,w)
 Pose.add(frame,"Action","Waist",0.03,0,0,0,0,0,w)
end

-- ------------------------------------------------------------------ update

function Actor:update(dt)
 self.time+=dt
 -- 1. timeline
 if not self.current then
  local nextCmd=table.remove(self.queue,1)
  if nextCmd then beginCommand(self,nextCmd) end
 end
 if self.current then
  self.commandTime+=dt
  if advanceCommand(self,self.current,dt) then self.current=nil end
 else
  self.speed=0
 end
 self.rootCFrame=CF(self.position.X,self.standY,self.position.Z)*A(0,self.yaw,0)

 -- 2. gait
 Loco.setScripted(self.loco,self.current and (self.current.kind=="Turn" or self.current.kind=="StepBack" or self.current.kind=="Flinch"))
 Loco.update(self.loco,self.rootCFrame,self.speed,dt)
 -- Standing still, drift the stance back to neutral one step at a time. Only
 -- while genuinely idle, so it can never interrupt an action mid-move.
 if self.speed==0 and (self.current==nil or self.current.kind=="Idle") then
  Loco.squareUp(self.loco,self.rootCFrame)
 end

 -- 3. additive layers
 local frame=Pose.newFrame()
 if not self.quiet then
  layerBreath(self,frame)
  layerWeightShift(self,frame)
 end
 Loco.contribute(self.loco,frame,1)
 layerSettle(self,frame,dt)
 layerGesture(self,frame,dt)
 layerReaction(self,frame,dt)
 layerLook(self,frame,dt)
 self.lastFrame=frame

 -- 4. resolve
 local transforms=Pose.resolve(frame)

 -- 5. pelvis correction, then re-resolve the Root motor only
 local rootSeg=Skeleton.ByMotor.Root
 local lower=self.rootCFrame*CF(rootSeg.c0)*transforms.Root*CF(rootSeg.c1):Inverse()
 local correction=Loco.pelvisCorrection(self.loco,lower)
 if correction~=0 then
  -- Its own layer name, not "Action": this is part of the IK, it is driven
  -- by where the feet actually are, and it is legitimately non-zero forever
  -- if a stop leaves the feet wider apart than the neutral stance. Treating
  -- it as an action leftover would be wrong.
  Pose.add(frame,"Pelvis","Root",0,0,0,0,correction,0,1)
  transforms=Pose.resolve(frame)
  lower=self.rootCFrame*CF(rootSeg.c0)*transforms.Root*CF(rootSeg.c1):Inverse()
 end

 -- 6. IK
 Loco.solveLegs(self.loco,self.rootCFrame,lower,transforms)
 self.transforms=transforms

 -- 7. FK
 self.world=Skeleton.forward(self.rootCFrame,transforms)
 return self.transforms,self.rootCFrame,self.world
end

function Actor:isBusy()
 return self.current~=nil or #self.queue>0
end

function Actor:label()
 if self.current then return self.current.kind end
 return "Idle"
end

return Actor
