--!nonstrict
-- Phase 0.A foundation, module 2 of 6: the additive pose solver.
--
-- THE ONE IDEA IN THIS FILE. A frame's pose is a SUM OF SIX NUMBERS PER JOINT
-- (rx, ry, rz, tx, ty, tz), accumulated as plain scalars and converted into a
-- CFrame exactly once, at the end, on top of a constant rest pose.
--
-- That is what makes the two properties the brief demands provable rather
-- than tuned:
--   * No accumulation. Nothing is ever multiplied into last frame's value.
--     Every frame starts from zeros and re-derives the whole pose from the
--     current layer states, so there is no state for error to collect in.
--   * Exact neutral return. Scalar addition of zeros is exactly zero, so when
--     every layer's weight reaches 0 the joint offset is bit-for-bit 0 and the
--     joint is bit-for-bit its rest pose. A CFrame:Lerp-toward-target filter
--     (what NorthPole/Cast.lua's evaluate() uses) can only ever approach
--     neutral asymptotically and always leaves residual rotation behind.
--
-- Easing therefore lives INSIDE each layer, as a weight that genuinely
-- reaches 0 and 1, never as a smoothing filter on the output.
--
-- JOINT OWNERSHIP. Every joint has exactly one owning system, declared in
-- Skeleton.Segments:
--   owner = "pose" -> Root, Waist, Neck, both Shoulders, Elbows, Wrists.
--                     Written only by additive layers through this file.
--   owner = "ik"   -> both Hips, Knees, Ankles.
--                     Written only by Locomotion's IK. Layers are forbidden
--                     to touch them, and add() throws if one tries, so the
--                     "two controllers fighting over one joint" failure is a
--                     load-time error instead of a visual artefact.
-- Layers may overlap freely on pose-owned joints; that is the point of an
-- additive stack, and the sum is order-independent.
local Skeleton=require(script.Parent.Skeleton)
local Pose={}
local CF,A=CFrame.new,CFrame.Angles

-- Declared layer order. Present for reporting and for the ownership audit;
-- the maths does not depend on it, because addition commutes.
Pose.Layers={"Breath","WeightShift","Locomotion","Pelvis","Action","Gesture","Look","Reaction"}

export type Frame={acc:{[string]:{number}},touched:{[string]:{[string]:boolean}}}

function Pose.newFrame(): Frame
 local acc={}
 for _,s in Skeleton.Segments do
  if s.owner=="pose" then acc[s.motor]={0,0,0,0,0,0} end
 end
 return {acc=acc,touched={}}
end

-- Add a weighted contribution. rx/ry/rz are radians, tx/ty/tz studs.
function Pose.add(frame:Frame,layer:string,motor:string,rx,ry,rz,tx,ty,tz,weight)
 local w=weight or 1
 if w==0 then return end
 local slot=frame.acc[motor]
 if not slot then
  local seg=Skeleton.ByMotor[motor]
  if seg and seg.owner=="ik" then
   error(`[Pose] layer '{layer}' tried to write '{motor}', which is owned by the IK solver`)
  end
  error(`[Pose] layer '{layer}' tried to write unknown joint '{motor}'`)
 end
 slot[1]=slot[1]+(rx or 0)*w
 slot[2]=slot[2]+(ry or 0)*w
 slot[3]=slot[3]+(rz or 0)*w
 slot[4]=slot[4]+(tx or 0)*w
 slot[5]=slot[5]+(ty or 0)*w
 slot[6]=slot[6]+(tz or 0)*w
 local t=frame.touched[motor]
 if not t then t={};frame.touched[motor]=t end
 t[layer]=true
end

local function clampAxis(range,value)
 if not range then return value end
 return math.clamp(value,range[1],range[2])
end

-- Collapse the frame into motor -> CFrame, rest pose included, limits applied.
-- Clamping happens on the summed scalars, so it is exact and cannot flip an
-- axis the way a ToOrientation/re-compose round trip can.
function Pose.resolve(frame:Frame)
 local out={}
 for motor,slot in frame.acc do
  local bx,by,bz=Skeleton.restOf(motor)
  local limits=Skeleton.Limits[motor]
  local rx=clampAxis(limits and limits.x,bx+slot[1])
  local ry=clampAxis(limits and limits.y,by+slot[2])
  local rz=clampAxis(limits and limits.z,bz+slot[3])
  if slot[4]==0 and slot[5]==0 and slot[6]==0 then
   out[motor]=A(rx,ry,rz)
  else
   out[motor]=CF(slot[4],slot[5],slot[6])*A(rx,ry,rz)
  end
 end
 return out
end

-- Is this frame exactly neutral? Used by the validator after every action
-- completes. Exact equality is the correct test here, not a tolerance: the
-- accumulator is scalar and a settled layer contributes literal zero.
function Pose.isNeutral(frame:Frame)
 for motor,slot in frame.acc do
  for i=1,6 do
   if slot[i]~=0 then return false,motor,i,slot[i] end
  end
 end
 return true
end

-- Largest absolute offset in the frame, for the on-screen drift readout.
function Pose.magnitude(frame:Frame)
 local worst,where=0,"none"
 for motor,slot in frame.acc do
  for i=1,6 do
   if math.abs(slot[i])>worst then worst=math.abs(slot[i]);where=motor end
  end
 end
 return worst,where
end

-- Smoothstep with genuine 0 and 1 endpoints - zero velocity at both ends and,
-- unlike an exponential filter, it actually arrives.
function Pose.ease(t)
 t=math.clamp(t,0,1)
 return t*t*(3-2*t)
end

-- Rise, hold, fall. Returns exactly 0 outside the window, which is what lets
-- a completed gesture leave nothing behind.
function Pose.envelope(elapsed,riseTime,holdTime,fallTime)
 if elapsed<=0 then return 0 end
 if elapsed<riseTime then return Pose.ease(elapsed/riseTime) end
 if elapsed<riseTime+holdTime then return 1 end
 local f=elapsed-riseTime-holdTime
 if f<fallTime then return 1-Pose.ease(f/fallTime) end
 return 0
end

return Pose
