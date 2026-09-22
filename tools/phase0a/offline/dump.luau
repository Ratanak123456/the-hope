--!nonstrict
-- Emits the solved rig geometry as JSON at a set of named capture points, so
-- the offline renderer can draw exactly the boxes Studio would draw. Every
-- number here comes from the real modules; nothing about the rig's shape or
-- pose is restated in the renderer.
local Skeleton,Actor,Build=MOD.Skeleton,MOD.Actor,MOD.Build
local V=Vector3.new
local palette=Build.Palette

local out={}
local function esc(s) return s end
local function emitFrame(tag,actor)
 local parts={}
 local world=actor.world
 for _,s in Skeleton.Segments do
  local cf=world[s.part]
  local c=Build.colourFor(s.part,palette)
  table.insert(parts,string.format(
   '{"name":"%s","size":[%f,%f,%f],"p":[%f,%f,%f],"x":[%f,%f,%f],"y":[%f,%f,%f],"z":[%f,%f,%f],"c":[%d,%d,%d]}',
   s.part,s.size.X*actor.scale,s.size.Y*actor.scale,s.size.Z*actor.scale,
   cf.Position.X,cf.Position.Y,cf.Position.Z,
   cf.XVector.X,cf.XVector.Y,cf.XVector.Z,
   cf.YVector.X,cf.YVector.Y,cf.YVector.Z,
   cf.ZVector.X,cf.ZVector.Y,cf.ZVector.Z,
   c.rgb[1],c.rgb[2],c.rgb[3]))
 end
 for _,d in Build.Decoration do
  local host=world[d.host]
  if host then
   local cf=host*CFrame.new(d.offset*actor.scale)
   local c=palette[d.colour]
   table.insert(parts,string.format(
    '{"name":"%s","size":[%f,%f,%f],"p":[%f,%f,%f],"x":[%f,%f,%f],"y":[%f,%f,%f],"z":[%f,%f,%f],"c":[%d,%d,%d]}',
    d.name,d.size.X*actor.scale,d.size.Y*actor.scale,d.size.Z*actor.scale,
    cf.Position.X,cf.Position.Y,cf.Position.Z,
    cf.XVector.X,cf.XVector.Y,cf.XVector.Z,
    cf.YVector.X,cf.YVector.Y,cf.YVector.Z,
    cf.ZVector.X,cf.ZVector.Y,cf.ZVector.Z,
    c.rgb[1],c.rgb[2],c.rgb[3]))
  end
 end
 local fl,fr=actor.loco.feet.Left,actor.loco.feet.Right
 table.insert(out,string.format(
  '{"tag":"%s","yaw":%f,"root":[%f,%f,%f],"speed":%f,"command":"%s",'..
  '"feet":{"Left":{"mode":"%s","plant":%d,"target":[%f,%f,%f]},'..
  '"Right":{"mode":"%s","plant":%d,"target":[%f,%f,%f]}},"parts":[%s]}',
  tag,actor.yaw,actor.position.X,actor.position.Y,actor.position.Z,actor.speed,actor:label(),
  fl.mode,fl.plantId,fl.target.Position.X,fl.target.Position.Y,fl.target.Position.Z,
  fr.mode,fr.plantId,fr.target.Position.X,fr.target.Position.Y,fr.target.Position.Z,
  table.concat(parts,",")))
end

-- Same actor, same timeline, same order as the Studio bench.
local actor=Actor.new({scale=1,floorY=0,position=V(0,0,14),yaw=0,seed=2})
actor:idle(5)
actor:look(0.35,0.04,2.0)
actor:look(-0.35,0,2.0)
actor:look(0.95,0.08,2.4) actor:idle(1.0)
actor:gesture(2.4) actor:idle(0.8)
actor:gesture(2.4) actor:idle(0.8)
actor:gesture(2.4) actor:idle(1.2)
actor:turn(math.pi/2,1.8) actor:idle(1.5)
actor:walk(20,2.6) actor:idle(1.5)
actor:walk(6,2.4,-math.rad(60))
actor:walk(5,2.4) actor:idle(1.5)
actor:stepBack(1.5) actor:idle(1.2)
actor:flinch(1.1) actor:idle(1.0)
actor:idle(8)

-- Capture points, keyed to COMMAND INDEX and an offset inside that command.
-- Wall-clock times were wrong: a command finishes when its own state machine
-- says so (a walk waits for its last foot to plant and then settles), so
-- nominal durations drift and a "mid-walk" capture landed inside the turn.
local CAPTURES={
 {1,3.00,"neutral"},
 {2,1.00,"look_small_left"},
 {4,1.00,"look_large_left"},
 {6,1.10,"gesture_peak"},
 {6,2.00,"gesture_late"},
 {12,0.90,"turn_mid"},
 {13,1.00,"turn_end"},
 {14,3.00,"walk_stride_a"},
 {14,3.17,"walk_stride_b"},
 {14,3.34,"walk_stride_c"},
 {14,3.51,"walk_stride_d"},
 {15,1.20,"walk_stop"},
 {16,1.20,"walk_turn"},
 {19,0.75,"step_back"},
 {21,0.30,"flinch"},
 {23,6.00,"final_idle"},
}
local dt=1/120
local t=0
local index=0
local started=0
local previous=nil
local pending=1
local guard=0
while pending<=#CAPTURES and guard<60000 do
 actor:update(dt)
 t+=dt
 guard+=1
 if actor.current~=previous and actor.current~=nil then
  index+=1;started=t
 end
 previous=actor.current
 while pending<=#CAPTURES and index==CAPTURES[pending][1] and (t-started)>=CAPTURES[pending][2] do
  emitFrame(CAPTURES[pending][3],actor)
  pending+=1
 end
 -- If a command ends before its capture offset, skip that capture rather
 -- than silently emitting it from the wrong command.
 while pending<=#CAPTURES and index>CAPTURES[pending][1] do
  emitFrame(CAPTURES[pending][3],actor)
  pending+=1
 end
end
print("["..table.concat(out,",").."]")
