--!nonstrict
-- One bench sequence shared by Studio and the offline regression harness.
local Timeline={}
function Timeline.full(actor)
 local labels={}
 local function segment(label,fn)
  local before=#actor.queue
  fn()
  for i=before+1,#actor.queue do labels[i]=label end
 end
 segment("1  STAND - hold the idle",function() actor:idle(5) end)
 segment("2  LOOK - small left",function() actor:look(0.35,0.04,2) end)
 segment("2  LOOK - small right",function() actor:look(-0.35,0,2) end)
 segment("2  LOOK - large left",function() actor:look(0.95,0.08,2.4):idle(1) end)
 for i=1,3 do
  segment("3  GESTURE - "..i,function() actor:gesture(2.4):idle(i==3 and 1.2 or 0.8) end)
 end
 segment("4  TURN - 90 degrees",function() actor:turn(math.pi/2,1.8):idle(1.5) end)
 segment("5  WALK - 20 studs",function() actor:walk(20,2.6):idle(1.5) end)
 segment("6  WALK - turn while moving",function() actor:walk(6,2.4,-math.rad(60)) end)
 segment("6  WALK - short leg, then stop",function() actor:walk(5,2.4):idle(1.5) end)
 segment("7  STEP BACK",function() actor:stepBack(1.5):idle(1.2) end)
 segment("8  FLINCH",function() actor:flinch(1.1):idle(1) end)
 segment("9  FINAL IDLE - drift check",function() actor:idle(8) end)
 return labels
end
function Timeline.stops(actor)
 for _,speed in {1.0,2.2,3.4} do actor:walk(12,speed):idle(1.5) end
end
function Timeline.turns(actor)
 for _,angle in {60,90,120} do
  -- Rotation is confined to cruise, before the stopping ramp begins.
  actor:enqueue({kind="Walk",distance=14,speed=2.4,turn=-math.rad(angle),turnStart=2,turnEnd=11}):idle(1.5)
 end
end
return Timeline
