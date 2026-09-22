--!nonstrict
-- One disposable client-local set. Interiors are separate sound stages, never
-- solid shells superimposed on the exterior. No global Terrain edits to undo.
local Kit = require(script.Parent.Kit)
local Env = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local C = {
 snow = Color3.fromRGB(193,211,220), ice = Color3.fromRGB(91,151,179), deep = Color3.fromRGB(39,78,105),
 ivory = Color3.fromRGB(210,211,198), metal = Color3.fromRGB(53,65,71), dark = Color3.fromRGB(25,32,39),
 orange = Color3.fromRGB(177,106,61), gold = Color3.fromRGB(188,144,81), cyan = Color3.fromRGB(115,204,214),
 violet = Color3.fromRGB(164,118,224), warm = Color3.fromRGB(255,219,167),
 --[[
  Vehicle-specific, and the whole point of these five values is the SPACING
  between them. The original trucks were one glued white prop because every
  surface sat within a few percent of the same value; the first correction
  overshot and made them one glued BLACK prop instead, with the tyres, the
  hull and the shadowed panels all inside a 40-unit band.

  These are spread deliberately, roughly 2:1 at each step, so a single flat
  light still separates them: near-black tyre, dark panel, mid hull, then the
  hi-vis band and the glass reading as the two accents. The tyres stay the
  darkest thing on the vehicle by a wide margin - that is what makes a wheel
  read as rubber against bodywork.
 ]]
 rubber = Color3.fromRGB(23,24,27), rubberWorn = Color3.fromRGB(44,46,50),
 hull = Color3.fromRGB(96,107,117), hullDark = Color3.fromRGB(54,62,70),
 glass = Color3.fromRGB(26,40,55), hiVis = Color3.fromRGB(206,118,52),
 -- Lab surfaces: deliberately NOT ivory. A near-white wall under a warm
 -- practical is what turned the command room into a white box with glowing
 -- people in it; these sit low enough to hold detail under a real key light.
 labWall = Color3.fromRGB(126,134,142), labWallDark = Color3.fromRGB(84,92,100),
 labFloor = Color3.fromRGB(58,64,70), labTrim = Color3.fromRGB(150,158,164),
}
Env.Colors = C
Env.Zones = {
 BaseCenter = V(0,9500,0), Command = V(650,9500,0), Door = V(1000,9500,0),
 ChamberFloor = V(1400,9500,0), ChamberCenter = V(1400,9520,0),
 PrisonCenter = V(2000,9300,0), Space = V(3000,10300,0),
}
export type Handle = any
local function part(parent, name, size, cf, color, material, shape, transparency)
 local spec={name=name,size=size,cframe=cf,color=color,material=material or Enum.Material.Metal,transparency=transparency,shadow=true}
 local p = if shape == "wedge" then Kit.wedge(spec) elseif shape == "ball" then Kit.ball(spec) else Kit.part(spec)
 p.Parent = parent
 return p
end
local function cylinder(parent,name,size,cf,color,axis)
 local p=Kit.cylinder({name=name,size=size,cframe=cf,color=color,material=Enum.Material.Metal,shadow=true},axis)
 p.Parent=parent
 return p
end
local function lamp(parent,cf,color,range,brightness)
 local p=part(parent,"Practical",V(1.2,0.22,0.6),cf,color,Enum.Material.Neon)
 Kit.light(p,color,range,brightness)
 return p
end
local function cable(parent,a,b,sag,color)
 local previous=a
 for i=1,12 do
  local t=i/12
  local nextPoint=a:Lerp(b,t)-V(0,math.sin(t*math.pi)*sag,0)
  Kit.beam(parent,"Cable",previous,nextPoint,0.16,color or C.dark)
  previous=nextPoint
 end
end
local function crate(parent,cf,size)
 local m=Kit.model("ReinforcedEquipmentCase",parent)
 part(m,"Case",size,cf,C.metal)
 for _,x in {-1,1} do
  part(m,"ReinforcingBand",V(0.16,size.Y+0.12,size.Z+0.12),cf*CF(x*size.X*0.36,0,0),C.ivory)
  part(m,"Latch",V(0.3,0.4,0.15),cf*CF(x*size.X*0.34,0,-size.Z/2-0.08),C.orange)
 end
 part(m,"SnowDeposit",V(size.X*0.9,0.2,size.Z*0.92),cf*CF(0,size.Y/2,0),C.snow,Enum.Material.Snow,"ball")
 return m
end
local function module(parent,cf,name,width,length)
 local m=Kit.model(name,parent)
 part(m,"RaisedInsulatedFloor",V(width,0.8,length),cf*CF(0,0.6,0),C.metal,Enum.Material.DiamondPlate)
 -- Separate insulated ribs and sloped roof, an actual empty interior.
 for _,side in {-1,1} do
  part(m,"Wall",V(0.35,5.5,length),cf*CF(side*width/2,3.6,0),C.ivory)
  part(m,"PitchedRoof",V(width*0.58,0.3,length+0.6),cf*CF(side*width*0.25,7,0)*A(0,0,side*math.rad(-20)),C.ivory)
  for z=-length/2,length/2,3 do
   part(m,"ShellRib",V(0.3,5.8,0.25),cf*CF(side*(width/2+0.15),3.7,z),C.metal)
  end
  for z=-length/2+3,length/2-2,4 do
   part(m,"WindowFrame",V(0.5,2.2,2.9),cf*CF(side*width/2,4,z),C.dark)
   part(m,"FrostedWindow",V(0.55,1.8,2.5),cf*CF(side*width/2,4,z),C.warm,Enum.Material.Glass,nil,0.2)
  end
  cable(m,(cf*CF(side*(width/2+0.4),1.2,-length/2)).Position,(cf*CF(side*(width/2+0.4),1.2,length/2)).Position,0.5)
 end
 part(m,"RearBulkhead",V(width,6,0.35),cf*CF(0,3.7,length/2),C.ivory)
 for _,side in {-1,1} do
  part(m,"EntryJamb",V(width/2-1.6,6,0.35),cf*CF(side*(width/4+0.8),3.7,-length/2),C.ivory)
 end
 part(m,"EntryLintel",V(3.2,1.3,0.35),cf*CF(0,6,-length/2),C.ivory)
 for i=1,3 do
  part(m,"SnowDustedStep",V(3.4,0.22,1),cf*CF(0,0.85-i*0.22,-length/2-i*0.75),C.snow,Enum.Material.DiamondPlate)
 end
 local sign=part(m,"Identification",V(4,0.7,0.08),cf*CF(0,6.1,-length/2-0.22),C.metal)
 Kit.label(sign,name)
 lamp(m,cf*CF(0,5.7,-length/2+1),C.warm,16,1.7)
 part(m,"RoofDrift",V(width*0.65,0.6,length*0.9),cf*CF(0,7.8,0),C.snow,Enum.Material.Snow,"ball")
 return m
end
--------------------------------------------------------------------------------
-- VEHICLES
--
-- Rebuilt 2026-09-22. The previous truck was one rigid model containing its
-- own "wheels", welded solid and slid along a lerp - so nothing ever rotated,
-- nothing ever reacted to the surface, and the whole thing read as a single
-- prop skating across the map.
--
-- Three rules make this one read as a machine instead:
--
-- 1. GROUND ORIGIN. The CFrame handed to vehicle() is the patch of snow the
--    tyres stand on, NOT the middle of the hull. Every offset below is a real
--    height above the ground, so moveVehicle() can drop each wheel onto the
--    surface it actually finds without converting through a second frame.
-- 2. THE WHEELS ARE NOT PART OF THE BODY. They are separate models in
--    `handle.wheels`, positioned every frame in the vehicle's FLAT (yaw-only)
--    frame, so they stay level and stay on the snow while the body above them
--    pitches and rolls. Their spin comes from distance travelled / radius, so
--    it can never disagree with the speed the vehicle is actually moving at.
-- 3. A ROTATING CYLINDER SHOWS NO ROTATION. Each wheel carries six tread lugs
--    and three spokes for exactly that reason; without them "the wheels turn"
--    is unobservable at any distance the camera actually uses.
--------------------------------------------------------------------------------

local WHEEL_R, WHEEL_W = 1.45, 1.1
local SUSPENSION_TRAVEL = 0.42 -- studs of vertical give at each wheel
local MAX_PITCH, MAX_ROLL = math.rad(4.5), math.rad(3.5)

local function buildWheel(parent,name)
 local m=Kit.model(name,parent)
 local tyre=Kit.cylinder({name="Tyre",size=V(WHEEL_W,WHEEL_R*2,WHEEL_R*2),cframe=CF(),color=C.rubber,material=Enum.Material.SmoothPlastic,shadow=true},"x")
 tyre.Parent=m;m.PrimaryPart=tyre
 -- Tread lugs around the circumference: the ONLY thing that makes rotation
 -- visible. A box at wheel-angle `a` sits at (0, R cos a, R sin a) and is
 -- rolled about the axle by the same `a`, which lays its flat face tangent
 -- to the tyre.
 for i=1,6 do
  local a=i/6*math.pi*2
  local lug=Kit.part({name="TreadLug",size=V(WHEEL_W*1.08,0.26,0.66),cframe=CF(0,math.cos(a)*WHEEL_R,math.sin(a)*WHEEL_R)*A(a,0,0),color=C.rubberWorn,material=Enum.Material.SmoothPlastic})
  lug.Parent=m
 end
 --[[
  THE WHEEL FACE. Lugs around the circumference only prove rotation in
  silhouette; every shot that actually looks at a wheel looks at it from
  OUTBOARD, where the circumference is edge-on and all that is left is the
  flat side of a black disc.

  So the face carries the second, brighter read: a mid-value rim dish, five
  light spokes reaching most of the way out to the tyre, and a hi-vis centre
  cap. Five rather than three, because an odd, denser count never lands back
  on itself at a half-turn the way three does, and reaching further out means
  the pattern sweeps a longer arc for the same rotation.
 ]]
 local rim=Kit.cylinder({name="Rim",size=V(WHEEL_W*1.06,WHEEL_R*1.34,WHEEL_R*1.34),cframe=CF(),color=Color3.fromRGB(88,96,104),material=Enum.Material.Metal},"x")
 rim.Parent=m
 for i=1,5 do
  local spoke=Kit.part({name="Spoke",size=V(WHEEL_W*1.1,WHEEL_R*1.36,0.3),cframe=CF()*A(i*math.pi/5,0,0),color=Color3.fromRGB(176,183,190),material=Enum.Material.Metal})
  spoke.Parent=m
 end
 local cap=Kit.cylinder({name="HubCap",size=V(WHEEL_W*1.2,WHEEL_R*0.5,WHEEL_R*0.5),cframe=CF(),color=C.hiVis,material=Enum.Material.Metal},"x")
 cap.Parent=m
 -- Every part above is authored around the origin, so the identity frame is
 -- the wheel's own reference: place(target) then puts the whole wheel where
 -- the axle goes. See Kit.rigid for why this is not Model:PivotTo.
 return m,Kit.rigid(m,CF())
end

--[[
 Returns a handle:
   { model, body, wheels = {{model, offset}}, base, spray, lights, ... }

 `body` holds everything rigid to the hull; `wheels` are siblings of it, never
 children, which is what lets the two move independently.
]]
local function vehicle(parent,cf,kind,index)
 local m=Kit.model(kind,parent)
 local body=Kit.model("Body",m)
 local utility=kind=="SnowUtility"
 local w,l=utility and 3.4 or 6,utility and 7 or 11.5
 local axles=utility and {-1.9,1.9} or {-3.5,0.4,4.1}
 local track=w/2+0.28 -- wheel centreline, just outboard of the hull

 local chassisY=WHEEL_R+0.55
 local deckY=chassisY+0.85
 local function at(x,y,z) return cf*CF(x,y,z) end

 -- Frame rails and cross members: visible under the body, between the
 -- wheels, so the hull reads as sitting ON something rather than floating.
 for _,side in {-1,1} do
  part(body,"FrameRail",V(0.34,0.5,l*0.9),at(side*w*0.3,chassisY,0),C.hullDark)
 end
 for _,z in axles do
  part(body,"AxleBeam",V(w+0.5,0.34,0.5),at(0,WHEEL_R,z),C.hullDark)
 end

 -- Hull, deck and cab. Three distinct values (hull / dark / hi-vis band) so
 -- the silhouette breaks up instead of reading as one white slab.
 local hull=part(body,"Hull",V(w,1.5,l*0.92),at(0,deckY,0),C.hull)
 m.PrimaryPart=hull
 -- Named so `model.PrimaryPart` is the hull for every caller that frames the
 -- truck (the shots focus on it) and for camera obstruction tests.
 body.PrimaryPart=hull
 part(body,"HiVisBand",V(w+0.06,0.36,l*0.66),at(0,deckY-0.2,l*0.06),C.hiVis)
 part(body,"Skirt",V(w*0.94,0.7,l*0.86),at(0,chassisY+0.25,0),C.hullDark)

 local cabZ=-l*0.26
 part(body,"Cab",V(w*0.94,2.3,l*0.34),at(0,deckY+1.85,cabZ),C.hull)
 part(body,"CabRoof",V(w*0.98,0.22,l*0.36),at(0,deckY+3.05,cabZ),C.hullDark)
 part(body,"SlopedNose",V(w*0.96,1.5,2),at(0,deckY+0.3,-l*0.46),C.hull,nil,"wedge")
 part(body,"BullBar",V(w*0.9,0.3,0.3),at(0,deckY-0.15,-l*0.52),C.hullDark)
 for _,side in {-1,1} do
  part(body,"BullBarUpright",V(0.26,1.1,0.26),at(side*w*0.3,deckY+0.35,-l*0.52),C.hullDark)
 end

 -- Glass: one dark raked windscreen and two side lights, all clearly framed.
 -- Deep blue-black glass against a mid-grey hull is what makes a window read
 -- as a window rather than a lighter patch of paint.
 part(body,"WindscreenFrame",V(w*0.9,1.65,0.2),at(0,deckY+2.1,-l*0.42),C.hullDark)
 part(body,"Windscreen",V(w*0.82,1.35,0.12),at(0,deckY+2.1,-l*0.428),C.glass,Enum.Material.Glass,nil,0.08)
 part(body,"WindscreenPillar",V(0.16,1.5,0.22),at(0,deckY+2.1,-l*0.43),C.hullDark)
 for _,side in {-1,1} do
  part(body,"SideGlass",V(0.1,1,l*0.2),at(side*w*0.47,deckY+2.2,cabZ-0.2),C.glass,Enum.Material.Glass,nil,0.08)
  part(body,"DoorPanel",V(0.14,1.5,l*0.24),at(side*w*0.47,deckY+0.85,cabZ),C.hullDark)
  part(body,"DoorHandle",V(0.2,0.1,0.42),at(side*w*0.5,deckY+1.3,cabZ+0.7),C.labTrim)
  part(body,"MirrorArm",V(0.5,0.08,0.08),at(side*(w*0.5+0.25),deckY+2.5,-l*0.36),C.hullDark)
  part(body,"Mirror",V(0.12,0.5,0.3),at(side*(w*0.5+0.5),deckY+2.4,-l*0.36),C.dark)
  part(body,"Step",V(0.5,0.1,1.2),at(side*w*0.5,chassisY+0.1,cabZ),C.hullDark,Enum.Material.DiamondPlate)
 end

 --[[
  Wheel arches: a lip OVER each tyre and a shallow fin along that lip's outer
  edge, which is what makes the wheel sit IN the body rather than beside it.
  Clearance is WHEEL_R + 0.5, comfortably more than the suspension travel
  below, so a wheel riding up a drift never pushes through its own arch.

  The fin is exactly that - a fin, 0.42 studs deep, on TOP of the arch. It
  used to be a 1.6-stud plate standing at axle height directly outboard of
  the tyre, which is not a flare, it is a wheel cover: it hid the entire
  outer face of the wheel from anything to the side of the truck, including
  the one insert shot whose whole job is to show that face turning.

  It and the mud flap opt out of camera queries, the same rule the route
  markers use for thin trim, so a wheel insert is never pushed off its
  framing by a strip of bodywork. The arch lip does not opt out: it is solid
  structure over the tyre and a camera should not be inside it.
 ]]
 for _,side in {-1,1} do
  for _,z in axles do
   local archY=WHEEL_R+WHEEL_R*0.72
   part(body,"ArchLip",V(WHEEL_W*1.9,0.3,WHEEL_R*2.4),at(side*track,archY,z),C.hullDark)
   local flare=part(body,"ArchFlare",V(0.3,0.42,WHEEL_R*2.5),at(side*(track+WHEEL_W*0.9),archY-0.12,z),C.hullDark)
   flare.CanQuery=false
   local flap=part(body,"MudFlap",V(WHEEL_W*1.4,0.8,0.1),at(side*track,WHEEL_R*0.55,z+WHEEL_R*1.15),C.dark,Enum.Material.SmoothPlastic)
   flap.CanQuery=false
  end
 end

 -- Roof kit: light bar, aerials and settled snow. Snow on the roof and
 -- nowhere else is the cheapest possible "this has been outside for weeks".
 part(body,"RoofRack",V(w*0.9,0.14,l*0.3),at(0,deckY+3.2,cabZ),C.hullDark)
 local bar=part(body,"RoofLightBar",V(w*0.66,0.26,0.3),at(0,deckY+3.42,cabZ-l*0.12),C.hullDark)
 for i=-1,1 do
  part(body,"RoofLamp",V(0.5,0.22,0.16),bar.CFrame*CF(i*w*0.2,0,-0.16),C.warm,Enum.Material.Neon,nil,0.25)
 end
 part(body,"RoofSnow",V(w*0.8,0.2,l*0.3),at(0,deckY+3.35,cabZ),C.snow,Enum.Material.Snow,"ball")
 part(body,"Antenna",V(0.07,2.4,0.07),at(w*0.4,deckY+4.4,cabZ+l*0.1),C.dark)
 part(body,"AerialWhip",V(0.05,1.8,0.05),at(-w*0.36,deckY+4.1,cabZ+l*0.14)*A(0.14,0,0.1),C.dark)

 --[[
  HEADLIGHTS. The old pair sat flush in the nose with a 55-degree cone, so
  the first thing every beam lit was the truck's own bodywork - the "bright
  white prop" look. These sit AHEAD of the bull bar, are pitched down 9
  degrees, and run a narrow 32-degree cone: the cone's near edge clears the
  vehicle entirely and the pool lands on the snow in front of it.
 ]]
 local lights={}
 for _,side in {-1,1} do
  part(body,"HeadlampLens",V(0.52,0.42,0.16),at(side*w*0.3,deckY+0.25,-l*0.54),C.warm,Enum.Material.Neon,nil,0.15)
  part(body,"HeadlampHousing",V(0.66,0.56,0.2),at(side*w*0.3,deckY+0.25,-l*0.51),C.hullDark)
  local emitter=part(body,"HeadlampEmitter",V(0.1,0.1,0.1),at(side*w*0.3,deckY+0.25,-l*0.62)*A(math.rad(-9),0,0),C.warm,Enum.Material.Neon,nil,1)
  emitter.CastShadow=false
  local spot=Instance.new("SpotLight")
  spot.Face=Enum.NormalId.Front;spot.Angle=32;spot.Range=70;spot.Brightness=2.4;spot.Color=C.warm;spot.Parent=emitter
  table.insert(lights,spot)
  part(body,"TailLight",V(0.42,0.28,0.14),at(side*w*0.34,deckY+0.2,l*0.47),Color3.fromRGB(179,55,44),Enum.Material.Neon,nil,0.15)
 end
 -- The pool the beams land in. Snow under a headlight is the readable part of
 -- a headlight; the cone itself is invisible without volumetrics.
 local pool=part(body,"HeadlampPool",V(w*1.5,0.06,l*1.4),at(0,0.08,-l*1.15),C.warm,Enum.Material.Neon,nil,0.88)
 pool.CastShadow=false;pool.CanQuery=false

 if kind=="EquipmentCarrier" then
  crate(body,at(0,deckY+1.7,l*0.2),V(4,1.9,3))
  for _,side in {-1,1} do part(body,"DeckRail",V(0.12,0.7,l*0.4),at(side*w*0.46,deckY+1.1,l*0.18),C.hullDark) end
 elseif kind=="EvacuationTransport" or kind=="PersonnelTransport" then
  part(body,"PassengerPod",V(w*0.94,2.5,l*0.46),at(0,deckY+2,l*0.24),C.hull)
  part(body,"PodRoof",V(w*0.98,0.2,l*0.48),at(0,deckY+3.25,l*0.24),C.hullDark)
  for _,side in {-1,1} do
   for i=-1,1 do part(body,"PassengerWindow",V(0.1,0.7,0.9),at(side*w*0.48,deckY+2.4,l*0.24+i*1.4),C.glass,Enum.Material.Glass,nil,0.08) end
  end
 elseif kind=="HeavyDrill" then
  part(body,"DrillDeck",V(w*0.92,0.5,l*0.5),at(0,deckY+1,l*0.2),C.hullDark,Enum.Material.DiamondPlate)
  for _,side in {-1,1} do part(body,"Outrigger",V(0.4,1.4,0.4),at(side*(w*0.5+0.5),chassisY-0.2,l*0.3),C.hiVis) end
 end

 local exhaust=part(body,"ExhaustStack",V(0.24,1.6,0.24),at(w*0.36,deckY+2.2,cabZ+l*0.18),C.dark)
 Kit.dust(exhaust,3,C.snow,1)

 -- Wheels last, as siblings of `body`, so PivotTo on one never moves the other.
 local wheels={}
 for _,side in {-1,1} do
  for i,z in axles do
   local wm,place=buildWheel(m,`Wheel{side<0 and "L" or "R"}{i}`)
   table.insert(wheels,{model=wm,place=place,offset=V(side*track,WHEEL_R,z),side=side,z=z})
  end
 end

 local spray=part(m,"WheelSpray",V(w,0.2,0.2),at(0,0.3,l*0.5),C.snow,nil,nil,1)
 spray.CastShadow=false
 local emitter=Kit.dust(spray,0,C.snow,8)
 m:SetAttribute("VehicleNumber",index)

 --[[
  The body is re-placed every frame from its CHASSIS frame - the patch of snow
  the tyres stand on, which is exactly the frame `cf` every offset above was
  authored against. Freezing it here rather than pivoting the model each frame
  is what keeps the hull, cab, glass and frame rails rigid relative to one
  another for the whole cinematic (see Kit.rigid).
 ]]
 local placeBody=Kit.rigid(body,cf)
 local handle={model=m,body=body,placeBody=placeBody,wheels=wheels,base=cf,spray=emitter,sprayHost=spray,lights=lights,pool=pool,
  length=l,width=w,deckY=deckY,spin=0,pitch=0,roll=0,lift=0,speed=0}
 -- Place it once so a parked vehicle is already sitting on the snow, level,
 -- before any shot ever touches it.
 Env.settleVehicle(handle,cf.Position,cf.LookVector)
 return handle
end
local function exterior(env,rng)
 local root=Kit.folder("ArcticLandscape",env.folder)
 local o=Env.Zones.BaseCenter
 -- Continuous substrate, buried under overlapping wind-carved ridges.
 part(root,"BuriedIceShelf",V(1100,18,1100),CF(o-V(0,12,0)),C.deep,Enum.Material.Ice)
 for x=-480,480,60 do for z=-420,480,60 do
  local h=2+math.noise(x/150,z/150)*4
  part(root,"WindSculptedSnow",V(90,8+h,92),CF(o+V(x,-4,z))*A(0,rng:NextNumber(-0.5,0.5),0),C.snow,Enum.Material.Snow,"ball")
 end end
 -- Keep the base and convoy corridor clear; detail is placed deliberately.
 for i=1,95 do
  local x=rng:NextNumber(-95,95);local z=rng:NextNumber(-20,145)
  if math.abs(x)>12 then
   part(root,"Drift",V(rng:NextNumber(4,11),rng:NextNumber(1,3),rng:NextNumber(6,16)),CF(o+V(x,0.4,z))*A(0,-0.35,0),C.snow,Enum.Material.Snow,"ball")
  end
 end
 --[[
  THE ROUTE. The single most important piece of storytelling in the exterior:
  a viewer has to be able to see, in one frame, where the convoy came from and
  where it is going. Four layers do that, from the ground up:

    1. a graded roadbed - compacted, slightly darker, slightly sunken;
    2. ploughed berms either side, which is what actually reads as "a road
       somebody cut through a snowfield" rather than "a stripe painted on it";
    3. twin tyre ruts down the middle, at the truck's real track width;
    4. marker poles with orange flags, spaced to converge toward the base -
       a perspective line that the eye follows straight to the destination.

  The route runs +Z (far, where the convoy enters) to 0 (the base).
 ]]
 local ROUTE_HALF=7
 for z=6,186,6 do
  part(root,"GradedRoadbed",V(ROUTE_HALF*2,0.5,6.2),CF(o+V(0,0.18,z)),C.ice:Lerp(C.snow,0.45),Enum.Material.Snow)
  for _,side in {-1,1} do
   local h=rng:NextNumber(1.1,2.1)
   part(root,"PloughBerm",V(3.4,h,6.4),CF(o+V(side*(ROUTE_HALF+1.3),h*0.3,z))*A(0,side*0.06,side*0.1),C.snow,Enum.Material.Snow,"ball")
  end
 end
 for z=8,188,1.6 do for _,x in {-2.9,2.9} do
  part(root,"TyreRut",V(1.25,0.06,0.62),CF(o+V(x,0.4,z)),C.ice,Enum.Material.Snow)
 end end
 -- Marker poles. Every fourth carries a small warm beacon, so at a distance
 -- the route reads as a dotted line of lights even before the base is legible.
 local GATE_Z=52
 for i=1,18 do
  local z=GATE_Z+6+i*8
  for _,side in {-1,1} do
   local base=o+V(side*(ROUTE_HALF+2.4),0.2,z)
   -- Poles and flags opt OUT of camera queries (Kit's "tiny decoration can
   -- opt out" rule). The tracking shot deliberately runs the camera outside
   -- the route so markers flick through the foreground; if they counted as
   -- obstructions, Camera.applyShot would abandon that framing and hunt for
   -- an unobstructed one every time a pole crossed the lens.
   local pole=Kit.beam(root,"RouteMarkerPole",base,base+V(0,3.6,0),0.14,C.dark)
   pole.CanQuery=false
   local flag=part(root,"RouteMarkerFlag",V(0.1,0.7,1.1),CF(base+V(side*0.5,3.2,0)),C.hiVis,Enum.Material.SmoothPlastic)
   flag.CanQuery=false
  end
  if i%4==0 then
   lamp(root,CF(o+V(ROUTE_HALF+2.4,3.9,z)),C.warm,17,1.1)
  end
 end
 -- Boot traffic between the apron and the modules: a worn path, not a random
 -- scatter, so the base reads as somewhere people actually walk every day.
 for i=1,54 do
  local z=2+i*0.85
  part(root,"BootPrint",V(0.34,0.04,0.65),CF(o+V(-13+(i%2)*0.55,0.31,z)),C.ice,Enum.Material.Snow,"ball")
 end

 --[[
  THE GATE. The route needs an arrival point or the convoy is just driving
  across a field. Two masts, a lit sign, a boom and a guard box: the moment
  the trucks pass this, the audience knows they have arrived.
 ]]
 for _,side in {-1,1} do
  Kit.beam(root,"GateMast",o+V(side*(ROUTE_HALF+1),0,GATE_Z),o+V(side*(ROUTE_HALF+1),9,GATE_Z),0.5,C.metal)
  lamp(root,CF(o+V(side*(ROUTE_HALF+0.4),8.2,GATE_Z+0.6))*A(-0.5,0,0),C.warm,26,1.6)
 end
 Kit.beam(root,"GateSpan",o+V(-(ROUTE_HALF+1),8.6,GATE_Z),o+V(ROUTE_HALF+1,8.6,GATE_Z),0.4,C.metal)
 local gateSign=part(root,"GateSign",V(11,2.1,0.24),CF(o+V(0,7.2,GATE_Z+0.2)),C.hullDark)
 Kit.label(gateSign,"ARCTIC EXPEDITION SEVEN\n88° N  ·  RESTRICTED",C.hiVis)
 part(root,"BoomBarrier",V(9,0.3,0.3),CF(o+V(-1.5,2.2,GATE_Z-1.8))*A(0,0,math.rad(-62)),C.hiVis)
 part(root,"BoomCounterweight",V(0.8,0.8,0.8),CF(o+V(-5.6,1.2,GATE_Z-1.8)),C.hullDark)
 local shack=Kit.model("GateHut",root)
 part(shack,"Hut",V(3.4,3.4,3.2),CF(o+V(ROUTE_HALF+3.4,1.9,GATE_Z-3)),C.hull)
 part(shack,"HutRoof",V(3.9,0.3,3.7),CF(o+V(ROUTE_HALF+3.4,3.7,GATE_Z-3)),C.hullDark)
 part(shack,"HutWindow",V(0.12,1.2,2),CF(o+V(ROUTE_HALF+1.7,2.4,GATE_Z-3)),C.warm,Enum.Material.Neon,nil,0.35)
 part(shack,"HutSnow",V(3.4,0.3,3.2),CF(o+V(ROUTE_HALF+3.4,3.9,GATE_Z-3)),C.snow,Enum.Material.Snow,"ball")

 --[[
  THE APRON. A flat compacted pad inside the gate where vehicles actually
  stop, with painted bays. Without it the trucks park on open snow at
  arbitrary angles and the site has no "here is where you arrive" beat.
 ]]
 part(root,"ArrivalApron",V(46,0.4,30),CF(o+V(4,0.2,28)),C.ice:Lerp(C.snow,0.3),Enum.Material.Snow)
 for i=-1,1 do
  part(root,"ApronBayLine",V(0.3,0.06,16),CF(o+V(4+i*9,0.42,28)),C.hiVis,Enum.Material.SmoothPlastic)
 end
 part(root,"ApronKerb",V(46,0.5,0.6),CF(o+V(4,0.4,43)),C.hiVis)
 for ring=1,3 do for i=1,24 do
  local angle=i/24*math.pi*2
  local radius=260+ring*65
  local height=rng:NextNumber(65,150)+ring*24
  local pos=o+V(math.cos(angle)*radius,height*0.32-10,math.sin(angle)*radius)
  part(root,"GlacierMass",V(100,height,100),CF(pos)*A(0,angle,rng:NextNumber(-0.2,0.2)),C.ice:Lerp(C.snow,ring/4),Enum.Material.Ice,"wedge")
  part(root,"SummitSnow",V(94,height*0.7,90),CF(pos+V(-5,height*0.25,0))*A(0,angle,0.1),C.snow,Enum.Material.Snow,"wedge")
 end end
--[[
  NEAR-FIELD RELIEF. The establishing shots look down the approach from high
  and far; without anything between the lens and the convoy the frame is one
  flat white plane and the site has no readable scale.

  These ridges sit either side of the route at z = 120..210 - the band the
  high cameras fly over - and are deliberately capped at ~22 studs. The
  establishing camera sits around y = 50 and its sightline to the convoy has
  already descended to roughly y = 36 by the time it crosses this band, so
  these read as foreground relief in the lower third of frame and can never
  occlude the subject (which is what would otherwise send Camera.applyShot
  hunting for an alternative position mid-shot).
 ]]
 for i=1,14 do
  local side=i%2==0 and 1 or -1
  local x=side*rng:NextNumber(26,76)
  local z=118+i*6.5+rng:NextNumber(-6,6)
  local h=rng:NextNumber(9,21)
  part(root,"NearIceRidge",V(rng:NextNumber(18,34),h,rng:NextNumber(20,40)),CF(o+V(x,h*0.34-3,z))*A(0,rng:NextNumber(-0.6,0.6),side*0.09),C.ice:Lerp(C.snow,rng:NextNumber(0.3,0.8)),Enum.Material.Ice,"wedge")
  part(root,"NearRidgeCap",V(rng:NextNumber(14,26),h*0.5,rng:NextNumber(16,30)),CF(o+V(x-side*3,h*0.62-3,z))*A(0,rng:NextNumber(-0.4,0.4),0),C.snow,Enum.Material.Snow,"wedge")
 end
 -- Wind-blown surface snow streaming across the route toward the camera.
 do
  local host=part(root,"RouteSpindrift",V(120,3,90),CF(o+V(0,2,120)),C.snow,nil,nil,1)
  local drift=Kit.dust(host,55,C.snow,18)
  drift.Acceleration=V(14,-2,2);drift.EmissionDirection=Enum.NormalId.Right
  drift.Size=NumberSequence.new(0.2)
  table.insert(env.weather,drift)
 end
 -- Giant iceberg: central passage left physically open.
 for _,side in {-1,1} do for i=1,13 do
  local p=o+V(side*(30+i*5),30+rng:NextNumber(0,35),-55-rng:NextNumber(0,50))
  part(root,"IcebergButtress",V(23,rng:NextNumber(85,140),42),CF(p)*A(0,rng:NextNumber(-0.3,0.3),side*0.12),C.ice:Lerp(C.snow,rng:NextNumber(0,0.6)),Enum.Material.Ice,"wedge")
  part(root,"BlueFissure",V(0.3,50,0.4),CF(p+V(-side*8,0,22))*A(0,0,side*0.13),C.deep,Enum.Material.Ice)
 end end
 for i=1,9 do
  part(root,"Crown",V(45,45,55),CF(o+V((i-5)*20,106,-90))*A(0,i*0.4,0.15),C.snow,Enum.Material.Snow,"wedge")
 end
 for _,side in {-1,1} do
  for y=3,18,5 do
   Kit.beam(root,"Scaffold",o+V(side*12,y,-36),o+V(side*12,y,-56),0.3,C.metal)
   Kit.beam(root,"DiagonalBrace",o+V(side*12,y,-36),o+V(side*12,y+5,-46),0.22,C.orange)
  end
  Kit.beam(root,"ShoringUpright",o+V(side*10,0,-42),o+V(side*10,22,-42),1,C.metal)
 end
 Kit.beam(root,"ShoringLintel",o+V(-10,22,-42),o+V(10,22,-42),1,C.metal)
 lamp(root,CF(o+V(0,18,-43)),C.warm,40,2)
 for i=1,4 do
  Kit.beam(root,"ExposedAncientEdge",o+V(32+i*3,10,-32),o+V(32+i*3,52,-32),0.4,C.gold)
 end
 local sea=part(root,"OceanLead",V(120,1,210),CF(o+V(-200,-0.3,70)),C.deep,Enum.Material.Glass)
 for i=1,22 do part(root,"BrokenFloe",V(rng:NextNumber(5,22),1.5,rng:NextNumber(8,25)),sea.CFrame*CF(rng:NextNumber(-52,52),1,rng:NextNumber(-94,94))*A(0,i,0),C.snow,Enum.Material.Ice,"wedge") end
 for _,pos in {V(-65,6,10),V(45,8,80),V(-30,22,-40)} do
  local emitter=part(root,"StormVolume",V(100,4,80),CF(o+pos),C.snow,nil,nil,1)
  local snow=Kit.dust(emitter,80,C.snow,25)
  snow.Acceleration=V(12,-3,3);snow.EmissionDirection=Enum.NormalId.Right
  snow.Size=NumberSequence.new(0.14)
  table.insert(env.weather,snow)
 end
 module(root,CF(o+V(-35,0,20))*A(0,0.2,0),"COMMAND / 07",16,22)
 module(root,CF(o+V(-56,0,47))*A(0,0.2,0),"MEDICAL",12,16)
 module(root,CF(o+V(32,0,16))*A(0,-0.2,0),"POWER / STORAGE",12,20)
 for i=1,9 do crate(root,CF(o+V(25+(i%3)*4,1.5,44+math.floor(i/3)*4)),V(3,2.5,3)) end
 for i=1,3 do
  local g=crate(root,CF(o+V(32+i*5,2,-8)),V(4,3,6))
  for n=1,7 do part(g,"CoolingLouver",V(0.08,1.8,0.1),CF(o+V(32+i*5-1.5+n*0.35,2,-11.1)),C.dark) end
  cylinder(root,"FuelDrum",V(3,2,2),CF(o+V(34+i*3,1.5,0)),C.metal,"y")
 end
 cable(root,o+V(39,1,-8),o+V(0,1,-28),0.65)
 for i=1,7 do
  part(root,"Walkway",V(7,0.3,6),CF(o+V(-18,0.4,46-i*6)),C.metal,Enum.Material.DiamondPlate)
  for _,x in {-22,-14} do
   Kit.beam(root,"SafetyRail",o+V(x,2.8,46-i*6),o+V(x,2.8,40-i*6),0.12,C.orange)
  end
 end
 env.commTower=Kit.model("CommunicationsTower",root)
 for y=0,28,4 do for _,x in {-1,1} do
  Kit.beam(env.commTower,"TrussLeg",o+V(24+x,y,-20),o+V(24+x,y+4,-20),0.25,C.ivory)
  Kit.beam(env.commTower,"TrussCross",o+V(24+x,y,-20),o+V(24-x,y+4,-20),0.15,C.metal)
 end end
 -- An explicit pivot, on the tower's own base at ground level: 29e_TowerFalls
 -- rotates this model, and a runtime-built Model with no PrimaryPart has no
 -- defined pivot to rotate about until one is named.
 env.commTower.WorldPivot=CF(o+V(24,0,-20))
 env.towerBase=env.commTower:GetPivot()
 env.radarDish=part(env.commTower,"Dish",V(5,5,0.7),CF(o+V(24,22,-20))*A(-0.3,0,0),C.ivory,nil,"ball")
 -- Site floodlights, placed as a deliberate ring around the working area
 -- rather than a scattered line: two over the apron, two over the drill head,
 -- two between the modules. Each mast is a visible source with a pool under
 -- it, so "the base is lit" is something the frame shows, not something the
 -- global ambient has to claim.
 for _,spot in {V(-16,0,34),V(24,0,34),V(-14,0,-14),V(16,0,-14),V(-30,0,8),V(30,0,4)} do
  local pos=o+spot
  Kit.beam(root,"FloodlightMast",pos,pos+V(0,11,0),0.3,C.metal)
  Kit.beam(root,"FloodlightStay",pos+V(0,7,0),pos+V(1.6,3.5,0),0.12,C.metal)
  local head=part(root,"FloodlightHead",V(1.6,0.7,1),CF(pos+V(0,11.2,0))*A(math.rad(-38),0,0),C.hullDark)
  local flood=Instance.new("SpotLight")
  flood.Face=Enum.NormalId.Front;flood.Angle=64;flood.Range=42;flood.Brightness=1.5;flood.Color=C.warm;flood.Parent=head
  part(root,"FloodlightLens",V(1.3,0.5,0.1),head.CFrame*CF(0,0,-0.55),C.warm,Enum.Material.Neon,nil,0.2)
 end
 local kinds={"PersonnelTransport","EquipmentCarrier","HeavyDrill","SnowUtility","EvacuationTransport"}
 -- 1 and 2 are the arriving convoy (moved by the shots); 3 is the drill rig at
-- the excavation; 4 and 5 are parked on the apron in marked bays, angled off
-- the route so the approach corridor stays visually clear.
 local placements={
  {at=V(0,1.6,150),yaw=0},
  {at=V(0,1.6,178),yaw=0},
  {at=V(0,1.6,-23),yaw=0},
  {at=V(-5,1.6,26),yaw=math.rad(96)},
  {at=V(13,1.6,26),yaw=math.rad(96)},
 }
 for i,kind in kinds do
  local placement=placements[i]
  table.insert(env.vehicles,vehicle(root,CF(o+placement.at)*A(0,placement.yaw,0),kind,i))
 end
 local drill=env.vehicles[3].model
 for _,x in {-2.8,2.8} do
  Kit.beam(drill,"HydraulicMast",o+V(x,2,-22),o+V(x,15,-28),0.65,C.orange)
  Kit.beam(drill,"Piston",o+V(x,3,-18),o+V(x,12,-27),0.3,C.ivory)
 end
 env.drill=Kit.model("RotatingAuger",root)
 cylinder(env.drill,"DriveShaft",V(12,0.8,0.8),CF(o+V(0,8,-28)),C.metal,"y")
 for i=1,18 do
  local t=i*0.8
  part(env.drill,"HelicalCuttingTooth",V(1.4,0.28,0.8),CF(o+V(math.cos(t)*0.75,2+i*0.62,-28+math.sin(t)*0.75))*A(0,-t,0.25),C.ivory)
 end
 -- Same again, and it matters more here: 07a_DrillRotates spins this model
 -- every frame. Without a pivot on the auger's own axis the rotation is
 -- about whatever the engine picks - at worst the world origin, which swings
 -- the whole auger around a 28-stud circle instead of turning it in place.
 env.drill.WorldPivot=CF(o+V(0,8,-28))
 env.drillBase=env.drill:GetPivot()
 local chip=part(root,"DrillContact",V(1,1,1),CF(o+V(0,1,-28)),C.ice,nil,nil,1)
 env.drillDust=Kit.dust(chip,0,C.snow,8)
 for i=1,10 do
  Kit.beam(root,"FracturedIce",o+V(0,0.4,-28),o+V(math.sin(i)*7,0.4,-28+math.cos(i)*7),0.08,C.deep)
 end
end
--------------------------------------------------------------------------------
-- THE COMMAND ROOM
--
-- Rebuilt 2026-09-22. The old room was a 26x24 box with six identical desks
-- around the edge, three overlapping ceiling lamps and ivory walls - which is
-- why it read as a prototype and why anyone standing under the middle lamp
-- turned into a glowing shape.
--
-- It is now laid out like a room somebody works in, with one hierarchy:
--
--   FOCAL POINT   the signal display, on an angled mount at the head of the
--                 central island. Everything in the room points at it.
--   MAIN STATION  the central island itself, where Lyra and Voss stand.
--   SECONDARY     four wall consoles, two a side, each with a technician
--                 facing their own screen (see LAB_STATIONS in Sequences).
--   BACKGROUND    the rear display wall, the equipment racks, the entrance
--                 vestibule with the cold outside leaking through it.
--
-- LIGHTING, which is the actual bug being fixed:
--
--   * Surfaces are mid-grey (C.labWall / C.labFloor), never ivory. A
--     near-white wall plus a warm practical is what blows out.
--   * Ceiling fixtures are SPOT lights aimed straight down over the WORK
--     SURFACES, not point lights hanging over where people stand, and their
--     cones do not overlap. Nobody is ever inside two lights at once, which
--     is what the old three-lamps-in-a-24-stud-room arrangement guaranteed.
--   * Everything else is a practical with a visible source and a short range:
--     screen glow, under-lip strips, rack LEDs. People are lit BY THE ROOM.
--
-- The room is also deliberately deep (z -17 to +21). The dialogue master shot
-- stands about 17 studs back from the group; in the old 24-stud-deep room
-- that camera was outside the wall.
--------------------------------------------------------------------------------

local function commandRoom(env,rng)
 local o=Env.Zones.Command
 local room=Kit.folder("CommandInterior",env.folder)
 local function at(x,y,z) return CF(o+V(x,y,z)) end

 -- Shell -------------------------------------------------------------------
 part(room,"Floor",V(32,0.5,38),at(0,-0.25,2),C.labFloor,Enum.Material.DiamondPlate)
 part(room,"Ceiling",V(32,0.4,38),at(0,12.2,2),C.labWallDark)
 for _,side in {-1,1} do
  part(room,"SideWall",V(0.5,12,38),at(side*16,6,2),C.labWall)
  -- Vertical ribs: rhythm on a big flat surface, and something for the key
  -- light to fall across so the wall is not one dead value.
  for z=-14,18,4 do part(room,"WallRib",V(0.22,11,0.4),at(side*15.7,6,z),C.labWallDark) end
  -- Frosted windows, high on the wall: cold daylight from outside, which is
  -- the contrast the warm interior is playing against.
  for z=-8,14,7 do
   part(room,"WindowFrame",V(0.5,3.2,3.4),at(side*15.8,8,z),C.dark)
   part(room,"FrostedGlass",V(0.3,2.7,2.9),at(side*15.9,8,z),Color3.fromRGB(150,176,196),Enum.Material.Glass,nil,0.25)
  end
 end
 part(room,"RearWall",V(32,12,0.5),at(0,6,-17),C.labWall)
 part(room,"FrontWall",V(32,12,0.5),at(0,6,21),C.labWall)
 -- Ceiling structure and cable trays, so the top of frame is not empty.
 for z=-13,19,8 do
  part(room,"CeilingTruss",V(32,0.7,0.7),at(0,11.6,z),C.labWallDark)
 end
 for _,side in {-1,1} do
  part(room,"CableTray",V(0.6,0.3,36),at(side*13,11.2,2),C.dark)
 end

 -- Entrance vestibule ------------------------------------------------------
 -- The way in from the cold. A room with an obvious door is a place; a sealed
 -- box is a set.
 part(room,"DoorFrame",V(6,0.6,0.6),at(0,8.4,20.7),C.labTrim)
 for _,side in {-1,1} do
  part(room,"DoorJamb",V(0.6,8.4,0.6),at(side*3,4.2,20.7),C.labTrim)
 end
 part(room,"OuterDoorGlow",V(5.4,7.8,0.2),at(0,4,20.9),Color3.fromRGB(150,176,196),Enum.Material.Neon,nil,0.72)
 part(room,"BootMat",V(6,0.1,3),at(0,0.06,18.4),C.dark,Enum.Material.SmoothPlastic)
 for i=-1,1 do
  part(room,"CoatHook",V(0.2,0.2,0.6),at(5.4+i*0.9,6.6,20.4),C.labTrim)
  part(room,"HangingParka",V(1.3,2.6,0.7),at(5.4+i*0.9,5.2,20.2),i==0 and C.hiVis or C.metal,Enum.Material.Fabric)
 end
 part(room,"BootRack",V(3.4,0.7,1),at(-6,0.4,19.4),C.dark,Enum.Material.DiamondPlate)

 -- Main workstation: the island ---------------------------------------------
 local island=Kit.model("MainWorkstation",room)
 part(island,"IslandTop",V(9,0.3,4.8),at(0,2.85,-3.6),C.labTrim,Enum.Material.Metal)
 part(island,"IslandBody",V(8.4,2.6,4.2),at(0,1.55,-3.6),C.labWallDark)
 part(island,"IslandKick",V(8.6,0.3,4.4),at(0,0.2,-3.6),C.dark)
 -- Under-lip strip: a practical that lights the island and the hands at it
 -- from below, without reaching anybody's face.
 for _,side in {-1,1} do
  local strip=part(island,"IslandEdgeLight",V(8.6,0.1,0.14),at(0,2.66,-3.6+side*2.42),C.cyan,Enum.Material.Neon,nil,0.25)
  Kit.light(strip,C.cyan,7,0.35)
 end
 part(island,"Keyboard",V(2.4,0.1,0.9),at(-2.4,3.05,-2.4),C.dark)
 part(island,"Notepad",V(1,0.06,1.4),at(2.6,3.03,-2.6),C.ivory)
 part(island,"Flask",V(0.5,1.1,0.5),at(3.6,3.55,-3.4),C.hiVis)
 part(island,"SampleTray",V(2.2,0.24,1.4),at(0.4,3.1,-4.8),C.metal,Enum.Material.DiamondPlate)
 for i=1,4 do
  part(island,"IceCoreVial",V(0.26,0.5,0.26),at(-0.4+i*0.35,3.4,-4.8),Color3.fromRGB(150,190,208),Enum.Material.Glass,nil,0.2)
 end
 -- Hazard tape on the floor around the island: the room tells you where to
 -- stand, which is also exactly where the blocking puts people.
 for _,side in {-1,1} do
  part(room,"IslandFloorMark",V(0.22,0.06,8),at(side*5.4,0.04,-3.6),C.hiVis,Enum.Material.SmoothPlastic)
 end

 -- The focal point ----------------------------------------------------------
 part(room,"DisplayMount",V(1,2.2,1),at(0,1.6,-6.4),C.labWallDark)
 env.signalDisplay=part(room,"SignalDisplay",V(7,3,0.25),at(0,4.6,-6.4)*A(-0.16,0,0),C.deep,Enum.Material.Glass)
 part(room,"SignalDisplayBezel",V(7.5,3.5,0.18),at(0,4.6,-6.55)*A(-0.16,0,0),C.labWallDark)
 env.pulses={}
 for i=1,3 do
  local pulse=part(room,"RepeatingPulse",V(0.3,1.8,0.08),env.signalDisplay.CFrame*CF((i-2)*1.8,-0.2,-0.18),C.cyan,Enum.Material.Neon)
  table.insert(env.pulses,pulse)
 end
 Kit.label(env.signalDisplay,"07  /  SUBGLACIAL RETURN",C.cyan)
 -- The display's own spill, aimed into the room: this is the light that
 -- actually falls on Lyra's and Voss's faces while they read it.
 local spill=part(room,"DisplaySpill",V(0.3,0.3,0.3),at(0,4.8,-5.6),C.cyan,Enum.Material.Neon,nil,1)
 spill.CastShadow=false
 local spillLight=Instance.new("SpotLight")
 spillLight.Face=Enum.NormalId.Back;spillLight.Angle=90;spillLight.Range=16;spillLight.Brightness=0.7;spillLight.Color=Color3.fromRGB(150,200,214);spillLight.Parent=spill

 -- Rear display wall --------------------------------------------------------
 part(room,"DisplayWallFrame",V(17,6.4,0.4),at(0,6.6,-16.6),C.labWallDark)
 local wallScreen=part(room,"DisplayWall",V(16,5.6,0.2),at(0,6.6,-16.45),C.deep)
 Kit.label(wallScreen,"EXPEDITION VII      88° N / 2,000 M\nSUBGLACIAL RETURN  ·  SOURCE UNCONFIRMED",C.cyan)
 for i=1,8 do
  Kit.beam(room,"MapContour",o+V(-6.5,5+i*0.4,-16.3),o+V(6.5,5.3+i*0.42,-16.3),0.035,C.cyan)
 end
 for _,side in {-1,1} do
  local panel=part(room,"SidePanel",V(4,3,0.2),at(side*10.5,6.6,-16.45),C.deep)
  Kit.label(panel,side<0 and "SEISMIC\nARRAY" or "CORE\nSAMPLES",C.labTrim)
 end

 -- Secondary stations -------------------------------------------------------
 -- Two a side, each turned to face the wall it is against, so a technician
 -- working at one is visibly doing a job rather than facing the camera.
 for _,side in {-1,1} do
  for index,z in {-4,3} do
   local cf=at(side*12,0,z)*A(0,side*math.pi/2,0)
   part(room,"DeskTop",V(5,0.24,2.2),cf*CF(0,2.8,0),C.labTrim)
   part(room,"DeskBody",V(4.6,2.6,1.9),cf*CF(0,1.45,0.1),C.labWallDark)
   local screen=part(room,"InstrumentScreen",V(2.8,1.5,0.14),cf*CF(0,3.9,-0.6)*A(-0.12,0,0),C.deep)
   Kit.label(screen,side<0 and `SEISMIC / 0{index}` or `THERMAL / 0{index}`,C.cyan)
   part(room,"ScreenBezel",V(3.1,1.8,0.1),cf*CF(0,3.9,-0.68)*A(-0.12,0,0),C.labWallDark)
   part(room,"Keyboard",V(2,0.1,0.8),cf*CF(0,2.95,0.45),C.dark)
   part(room,"DeskLampArm",V(0.1,1.2,0.1),cf*CF(1.8,3.5,0),C.labWallDark)
   local deskLamp=part(room,"DeskLamp",V(0.7,0.16,0.5),cf*CF(1.8,4.1,-0.3),C.warm,Enum.Material.Neon,nil,0.25)
   Kit.light(deskLamp,C.warm,7,0.5)
   part(room,"ChairSeat",V(1.6,0.24,1.5),cf*CF(0,1.5,2.4),C.dark)
   part(room,"ChairBack",V(1.6,1.5,0.22),cf*CF(0,2.25,3.05)*A(0.12,0,0),C.dark)
   cylinder(room,"ChairPedestal",V(1.4,0.22,0.22),cf*CF(0,0.75,2.4),C.metal,"y")
   part(room,"ChairBase",V(1.3,0.14,1.3),cf*CF(0,0.12,2.4),C.dark)
  end
 end

 -- Equipment racks and site clutter -----------------------------------------
 for _,side in {-1,1} do
  local rack=Kit.model("EquipmentRack",room)
  part(rack,"RackFrame",V(3.4,6,1.6),at(side*13.4,3,-14),C.labWallDark)
  for n=1,6 do
   part(rack,"RackUnit",V(3,0.7,0.2),at(side*13.4,0.6+n*0.85,-13.2),C.dark)
   local led=part(rack,"RackStatus",V(0.14,0.14,0.08),at(side*12.2,0.6+n*0.85,-13.1),n%3==0 and C.hiVis or C.cyan,Enum.Material.Neon,nil,0.1)
   led.CastShadow=false
  end
 end
 for i=1,4 do
  crate(room,at(-13+((i-1)%2)*3,1.5,13+math.floor((i-1)/2)*3.4),V(2.6,2.4,2.6))
 end
 part(room,"Whiteboard",V(6,3.4,0.12),at(11,6,16.4)*A(0,math.pi,0),C.ivory)
 Kit.label(part(room,"WhiteboardFace",V(5.8,3.2,0.06),at(11,6,16.3)*A(0,math.pi,0),C.ivory),"DRILL PLAN\n1  CORE  2  RELAY  3  DESCEND",C.dark)
 cable(room,o+V(-13,11,-12),o+V(-13,11,16),1.4)
 cable(room,o+V(13,11,-12),o+V(13,11,16),1.4)

 --[[
  KEY LIGHTING. One downward spot per group of people, each sized so that
  every character stands inside EXACTLY ONE cone:

    island   (0,-1.6)    Lyra and Voss, at the main station
    command  (0, 5.6)    Hale, standing back from the work - narrower and
                         dimmer, which is why he reads as apart from it
    consoles (+-10.3,-0.5) the two technicians on each side wall
    entrance (0, 16)     the doorway, cooler, nobody standing in it

  That is the whole fix for "characters' heads become glowing bright shapes".
  The old room put three 22-stud point lights eight studs apart in a 24-stud
  box, so anyone near the middle sat inside two falloffs at once and clipped.
  Cone geometry is recorded on env.roomLights so the offline harness can
  assert the one-cone-per-person property directly rather than by eye.
 ]]
 env.roomLights={}
 local function ceilingSpot(x,z,brightness,range,angle,color)
  local fixture=part(room,"CeilingFixture",V(2.6,0.3,1.4),at(x,11.4,z),C.labWallDark)
  local lens=part(room,"CeilingLens",V(2.2,0.1,1),at(x,11.24,z),color,Enum.Material.Neon,nil,0.45)
  lens.CastShadow=false
  local spot=Instance.new("SpotLight")
  spot.Face=Enum.NormalId.Bottom
  spot.Angle=angle
  spot.Range=range
  spot.Brightness=brightness
  spot.Color=color
  spot.Parent=fixture
  table.insert(env.roomLights,{position=o+V(x,11.4,z),angle=angle,range=range,brightness=brightness})
  return spot
 end
 ceilingSpot(0,-1.6,1.05,18,80,C.warm)                    -- Lyra and Voss at the island
 ceilingSpot(0,5.6,0.7,14,62,C.warm)                      -- Hale, standing back
 ceilingSpot(-10.3,-0.5,0.8,15,78,C.warm)                 -- left consoles
 ceilingSpot(10.3,-0.5,0.8,15,78,C.warm)                  -- right consoles
 ceilingSpot(0,16,0.6,14,70,Color3.fromRGB(198,214,226))  -- entrance, cooler
 -- A single very soft fill from high at the back of the room, so the shadow
 -- side of a face is dark but still readable - never black, never a second
 -- key.
 local fillHost=part(room,"RoomFill",V(0.3,0.3,0.3),at(0,10,10),C.warm,Enum.Material.Neon,nil,1)
 fillHost.CastShadow=false
 Kit.light(fillHost,Color3.fromRGB(150,162,180),30,0.5)
end

local function interiors(env,rng)
 commandRoom(env,rng)
 local d=Env.Zones.Door
 local hall=Kit.folder("AncientEntry",env.folder)
 part(hall,"EntryFloor",V(30,1,70),CF(d+V(0,-0.5,10)),C.deep,Enum.Material.Slate)
 for _,side in {-1,1} do
  part(hall,"IceWall",V(3,24,70),CF(d+V(side*16,11,10)),C.ice,Enum.Material.Ice,"wedge")
  for z=-18,38,8 do
   part(hall,"FlutedPillar",V(2,20,2),CF(d+V(side*12,10,z)),C.ivory,Enum.Material.Marble)
   for x=-0.6,0.6,0.6 do part(hall,"PillarFlute",V(0.13,18,0.1),CF(d+V(side*12+x,10,z+1.05)),C.gold) end
   lamp(hall,CF(d+V(side*11,2,z)),C.warm,20,1)
  end
 end
 for _,side in {-1,1} do
  part(hall,"DoorJamb",V(3,20,2),CF(d+V(side*10,10,0)),C.ivory,Enum.Material.Marble)
 end
 part(hall,"DoorLintel",V(23,3,2),CF(d+V(0,20,0)),C.ivory,Enum.Material.Marble)
 env.door={}
 for _,side in {-1,1} do
  local leaf=Kit.model(side<0 and "DoorLeft" or "DoorRight",hall)
  local p=part(leaf,"AncientDoor",V(9.5,18,0.8),CF(d+V(side*4.8,9,0)),C.ivory,Enum.Material.Marble)
  leaf.PrimaryPart=p
  for i=1,7 do
   part(leaf,"InsetGoldRib",V(8.5,0.1,0.2),p.CFrame*CF(0,-7+i*2,0.5),C.gold)
  end
  env.door[side<0 and "left" or "right"]=leaf
  -- Slid open every frame of 08c_AncientDoorOpens, so it is placed from a
  -- frozen offset set rather than re-pivoted off its own last position - see
  -- Kit.rigid, and the truck body, which is the same problem.
  env.door[side<0 and "slideLeft" or "slideRight"]=Kit.rigid(leaf,CF(d))
  env.door[side<0 and "leftBase" or "rightBase"]=CF(d)
 end
 env.door.symbol=part(hall,"TranslationGlyph",V(1.6,1.6,0.14),CF(d+V(-1,5,0.55)),C.gold)
 for i=1,8 do
  local a=i*math.pi/4
  part(hall,"GlyphFacet",V(0.14,0.55,0.15),env.door.symbol.CFrame*CF(math.cos(a)*0.55,math.sin(a)*0.55,0.1)*A(0,0,a),C.warm,Enum.Material.Neon)
 end
 local ch=Env.Zones.ChamberFloor
 local chamber=Kit.folder("AegisVault",env.folder)
 -- Annular floor has a real hole; seal leaves open independently above it.
 for i=1,32 do
  local a=i/32*2*math.pi
  part(chamber,"RadialFloor",V(14,1,60),CF(ch+V(math.sin(a)*44,-0.5,math.cos(a)*44))*A(0,a,0),C.deep,Enum.Material.Slate)
  if i%2==0 then
   local pos=ch+V(math.sin(a)*72,0,math.cos(a)*72)
   part(chamber,"VaultButtress",V(5,80,7),CF(pos+V(0,40,0))*A(0,a,0),C.ice,Enum.Material.Ice,"wedge")
   part(chamber,"ArchitecturalConduit",V(0.18,60,0.18),CF(pos+V(-2,35,0)),C.gold,Enum.Material.Neon)
  end
 end
 env.sealLeaves={}
 for i=1,12 do
  local a=i/12*math.pi*2
  local p=part(chamber,"SealIris",V(7.5,0.65,15),CF(ch+V(math.sin(a)*7,0.5,math.cos(a)*7))*A(0,a,0),C.gold)
  table.insert(env.sealLeaves,{part=p,base=p.CFrame,direction=V(math.sin(a),0,math.cos(a))})
 end
 env.sealCrack=cylinder(chamber,"PrisonLight",V(0.2,28,28),CF(ch+V(0,-1,0)),C.violet,"y")
 env.sealCrack.Material=Enum.Material.Neon
 for _,x in {-34,34} do
  -- Reduced from brightness 3 - close enough to the human dialogue blocking
  -- on the chamber floor (see stage() in Sequences.lua) to overexpose them.
  lamp(chamber,CF(ch+V(x,28,8)),C.cyan,60,1.8)
  lamp(chamber,CF(ch+V(x,35,-32)),C.warm,60,1.8)
 end
 env.mythWall=part(chamber,"GuardianPictograph",V(20,9,0.5),CF(ch+V(-38,6,26)),C.ivory,Enum.Material.Slate)
 env.reliefs={}
 for i=1,4 do
  local cf=env.mythWall.CFrame*CF((i-2.5)*4.6,0,0.36)
  local panel=part(chamber,"ReliefPanel",V(4,6,0.1),cf,C.deep)
  -- Recognizable pictograms: guardian torso/head/arms linked to a seal.
  part(chamber,"CarvedHead",V(0.5,0.5,0.14),cf*CF(0,1.5,0.12),C.gold,nil,"ball")
  Kit.beam(chamber,"GuardianBody",(cf*CF(0,1.2,0.12)).Position,(cf*CF(0,-0.3,0.12)).Position,0.3,C.gold)
  for _,side in {-1,1} do
   Kit.beam(chamber,"HoldingArm",(cf*CF(0,0.8,0.12)).Position,(cf*CF(side*1.1,-0.6,0.12)).Position,0.18,C.gold)
   Kit.beam(chamber,"CarvedChain",(cf*CF(side*1.1,-0.6,0.12)).Position,(cf*CF(side*0.4,-1.6,0.12)).Position,0.08,C.gold)
   part(chamber,"CreatureClaw",V(0.2,0.7,0.14),cf*CF(side*0.7,-2,0.14)*A(0,0,side*0.5),C.violet,nil,"wedge")
  end
  table.insert(env.reliefs,panel)
 end
 env.activationConsole=part(chamber,"PowerConsole",V(4,2.7,2),CF(ch+V(9,1.4,24)),C.metal)
 local screen=part(chamber,"PowerReadout",V(3,1.2,0.12),env.activationConsole.CFrame*CF(0,0.5,1.1)*A(0,math.pi,0),C.deep)
 Kit.label(screen,"EXTERNAL POWER / CONNECTED",C.cyan)
 cable(chamber,ch+V(9,0.4,24),ch+V(3,0.4,7),0.2)
 env.elevator=Kit.model("EvacuationLift",chamber)
 part(env.elevator,"LiftFloor",V(12,0.5,10),CF(ch+V(25,0.25,35)),C.metal,Enum.Material.DiamondPlate)
 env.liftDoors={}
 for _,side in {-1,1} do
  part(env.elevator,"LiftFrame",V(0.4,9,0.4),CF(ch+V(25+side*6,4.5,30)),C.ivory)
  local p=part(env.elevator,"EmergencyDoor",V(5.5,8,0.3),CF(ch+V(25+side*8,4,30)),C.metal)
  table.insert(env.liftDoors,{part=p,base=p.CFrame,side=side})
 end
 lamp(env.elevator,CF(ch+V(25,8,34)),C.warm,20,2)
 env.redLights={}
 for i=1,5 do
  local p=lamp(chamber,CF(ch+V(-24+i*10,4,38)),Color3.fromRGB(235,70,55),20,0)
  local light=p:FindFirstChildOfClass("PointLight")
  if light then table.insert(env.redLights,light) end
 end
 local pr=Env.Zones.PrisonCenter
 local prison=Kit.folder("SovereignPrison",env.folder)
 part(prison,"LowerCavernFloor",V(300,4,260),CF(pr+V(0,-15,15)),C.deep,Enum.Material.Ice)
 --[[
  THE OBSERVATION LEDGE. Every "Prison" mark in Sequences.lua's STAGING - and
  the descent walk in 16_PrisonDescent, and the soldier's mark - stands the
  cast at PrisonCenter's own Y, but the only surface here was the cavern
  floor 13 studs below, so there was literally nothing under their feet: they
  either hovered over the drop (before placement raycast for real) or sank to
  the cavern floor in among the frozen Wardens (after). This is the shelf the
  whole prison sequence was written to be standing on.

  It reads as somewhere people arrived at and set up on, not a slab: a rock
  shelf continuous with the cavern wall behind it, a rail along the drop, a
  tunnel mouth they came in through, and two portable work lamps that are the
  only warm light down here - which is also what keeps faces readable against
  the violet cavern without lighting them from inside.
 ]]
 -- One solid shelf from the cavern floor up to Y=0: the top surface is the
 -- floor the marks assume, and the face below it is the drop they look over.
 part(prison,"ObservationLedge",V(70,26,30),CF(pr+V(-6,-13,-45)),C.ice,Enum.Material.Ice)
 part(prison,"LedgeDeck",V(70,0.4,30),CF(pr+V(-6,-0.2,-45)),C.deep,Enum.Material.Slate)
 -- The front lip overhangs slightly, so the wide shot reads a real edge
 -- rather than a seam between two same-coloured ice blocks.
 part(prison,"LedgeLip",V(70,1.2,1.6),CF(pr+V(-6,-0.6,-30.4)),C.metal,Enum.Material.DiamondPlate)
 for x=-38,24,6.2 do
  part(prison,"RailPost",V(0.3,3.4,0.3),CF(pr+V(x,1.7,-30.8)),C.metal)
 end
 part(prison,"RailTop",V(64,0.22,0.22),CF(pr+V(-7,3.3,-30.8)),C.metal)
 part(prison,"RailMid",V(64,0.18,0.18),CF(pr+V(-7,2,-30.8)),C.metal)
 -- The way in, at the back of the shelf.
 part(prison,"TunnelMouth",V(14,13,3),CF(pr+V(-9,6.5,-59)),C.dark,Enum.Material.Rock)
 for _,side in {-1,1} do
  part(prison,"TunnelJamb",V(1.6,13,3.4),CF(pr+V(-9+side*7.8,6.5,-59)),C.ivory,Enum.Material.Rock)
 end
 -- Portable work lamps on tripods: a visible source, short range, aimed down
 -- the shelf rather than at the drop, so they light the ground the cast is
 -- standing on and nothing beyond it.
 for _,spot in {V(-20,0,-47),V(9,0,-47)} do
  local mast=Kit.model("PortableWorkLamp",prison)
  for i=0,2 do
   part(mast,"TripodLeg",V(0.24,4.6,0.24),CF(pr+spot+V(math.sin(i*2.1)*0.9,2.3,math.cos(i*2.1)*0.9))*A(math.cos(i*2.1)*0.2,0,-math.sin(i*2.1)*0.2),C.metal)
  end
  part(mast,"LampBody",V(2,1.2,1),CF(pr+spot+V(0,5,0)),C.metal,Enum.Material.DiamondPlate)
  local lens=part(mast,"LampLens",V(1.7,0.95,0.14),CF(pr+spot+V(0,5,-0.6)),C.warm,Enum.Material.Neon,nil,0.3)
  lens.CastShadow=false
  local beam=Instance.new("SpotLight")
  beam.Face=Enum.NormalId.Front;beam.Angle=96;beam.Range=26;beam.Brightness=1.1;beam.Color=Color3.fromRGB(255,226,186)
  beam.Parent=lens
  cable(mast,pr+spot+V(0,0.4,0),pr+spot+V(-2,0.2,-9),0.4)
 end
 -- The kit they carried down: reads as an expedition, not three people
 -- standing on a rock.
 crate(prison,CF(pr+V(-26,1.4,-53)),V(2.6,2.4,2.6))
 crate(prison,CF(pr+V(-23,1.4,-56)),V(2.2,2,2.2))
 part(prison,"SurveyTripodHead",V(1.2,0.5,0.9),CF(pr+V(14,4.2,-40)),C.dark)
 for i=0,2 do
  part(prison,"SurveyTripodLeg",V(0.18,4,0.18),CF(pr+V(14,2,-40)+V(math.sin(i*2.1)*0.7,0,math.cos(i*2.1)*0.7))*A(math.cos(i*2.1)*0.17,0,-math.sin(i*2.1)*0.17),C.dark)
 end
 for i=1,36 do
  local a=i/36*math.pi*2
  local pos=pr+V(math.sin(a)*138,20,math.cos(a)*115)
  part(prison,"StratifiedIceWall",V(28,110,25),CF(pos)*A(0,a,0.15),C.ice,Enum.Material.Ice,"wedge")
  Kit.beam(prison,"BlackRoot",pos-V(0,45,0),pos+V(math.sin(i)*18,35,-10),1.6,C.dark)
 end
 -- Reduced range/brightness: at the old 90-stud range and brightness 3 these
 -- reached the human dialogue positions on the prison ledge (see stage()'s
 -- "Prison" positions in Sequences.lua) strongly enough to wash them out -
 -- exactly the "human glows white/pink in the cave" failure. The Sovereign's
 -- own closer shots (17a-19) still read it clearly at this range.
 for _,x in {-45,45} do lamp(prison,CF(pr+V(x,25,-22)),C.violet,60,1.6) end
 lamp(prison,CF(pr+V(0,45,-70)),C.cyan,70,1.6)
 env.prisonSpots={}
 for i=1,16 do table.insert(env.prisonSpots,CF(pr+V((i%4-1.5)*22,-7,35+math.floor(i/4)*18))*A(0,math.pi,0)) end
 -- Distant army uses distinct low-detail silhouettes, never 200 full rigs.
 env.armySensors={}
 for row=1,10 do for col=1,24 do
  local pos=pr+V((col-12.5)*8+rng:NextNumber(-2,2),-7+row*1.7,50+row*7)
  part(prison,"FrozenWardenCarapace",V(2.4,4.5,2),CF(pos)*A(0,col*0.2,0.1),C.metal,Enum.Material.Slate,"wedge")
  for _,side in {-1,1} do
   part(prison,"FoldedClaw",V(0.4,3.8,1.2),CF(pos+V(side*1.5,-1,0))*A(0,0,side*0.3),C.dark,nil,"wedge")
   local eye=part(prison,"DormantSensor",V(0.24,0.15,0.12),CF(pos+V(side*0.4,1.4,-1.1)),C.violet,Enum.Material.Neon,nil,1)
   table.insert(env.armySensors,eye)
  end
 end end
 local fog=part(prison,"GroundFog",V(130,0.3,120),CF(pr+V(0,-10,30)),C.snow,nil,nil,1)
 local mist=Kit.dust(fog,24,C.ice,0.5);mist.Size=NumberSequence.new(8)
 env.space=Kit.folder("SpaceAftermath",env.folder)
 local sp=Env.Zones.Space
 env.earth=part(env.space,"EarthLimb",V(220,220,220),CF(sp+V(-85,-110,0)),C.deep,Enum.Material.SmoothPlastic,"ball")
 part(env.space,"PolarCap",V(205,30,170),CF(sp+V(-85,-14,0)),C.snow,Enum.Material.Ice,"ball")
 env.carrier=Kit.model("AlienCarrier",env.space)
 local cp=sp+V(120,35,-320)
 for i=1,9 do
  part(env.carrier,"SweptHullRib",V(100-i*7,7,130),CF(cp+V(0,i*2,-i*8))*A(0,0,0.025*i),C.metal,nil,"wedge")
 end
 env.carrierLights={}
 -- Thousands of pixels on fixed SurfaceGuis cost far fewer draw calls than lights.
 for _,side in {-1,1} do
  local panel=part(env.carrier,"CarrierSensorBank",V(0.2,14,110),CF(cp+V(side*28,10,-25)),C.dark)
  local gui=Instance.new("SurfaceGui");gui.Face=side<0 and Enum.NormalId.Left or Enum.NormalId.Right;gui.CanvasSize=Vector2.new(1200,200);gui.LightInfluence=0;gui.Parent=panel
  for i=1,1000 do
   local dot=Instance.new("Frame");dot.Size=UDim2.fromOffset(3,3);dot.Position=UDim2.fromOffset((i%100)*12,math.floor(i/100)*18);dot.BackgroundColor3=C.violet;dot.BackgroundTransparency=1;dot.BorderSizePixel=0;dot.Parent=gui
   table.insert(env.carrierLights,dot)
  end
 end
 env.signal=part(env.space,"EscapingSignal",V(1,1,1),CF(sp),C.violet,Enum.Material.Neon,"ball")
end
function Env.build(): Handle
 local folder=Instance.new("Folder");folder.Name="NorthPoleCinematic";folder.Parent=workspace
 local env={folder=folder,markers=Kit.folder("CameraMarkers",folder),vehicles={},weather={}}
 Kit.resetLightBudget(64)
 local ok,err=pcall(function()
  local rng=Kit.rng(20260915)
  exterior(env,rng);interiors(env,rng)
 end)
 if not ok then folder:Destroy();error(err) end
 return env
end
function Env.destroy(handle)
 if handle then handle.folder:Destroy() end
end
function Env.openSeal(env,amount)
 for _,leaf in env.sealLeaves do leaf.part.CFrame=leaf.base+leaf.direction*amount*15 end
end
--------------------------------------------------------------------------------
-- Ground sampling and vehicle motion.
--
-- Every height in the Arctic set comes from a raycast against the set itself,
-- never from a constant: the exterior floor is a field of overlapping snow
-- balls whose surface varies by several studs, so any hardcoded Y is wrong
-- somewhere. This is the same mechanism Cast.lua grounds its people with.
--------------------------------------------------------------------------------

local groundParams=RaycastParams.new()
groundParams.FilterType=Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater=true

-- `ignore`: instances whose own geometry must not count as ground (the
-- vehicle doing the asking, the character being stood up). Passing nothing
-- means "anything solid counts".
function Env.surfaceY(x: number, z: number, near: number, ignore: {Instance}?): number
 groundParams.FilterDescendantsInstances=ignore or {}
 local hit=workspace:Raycast(V(x,near+30,z),V(0,-140,0),groundParams)
 return hit and hit.Position.Y or near
end

--[[
 Places a vehicle at a ground position with a given facing, solving the
 suspension for the surface actually under each wheel.

 `blend` (0..1) is how much of the way to move toward the newly solved body
 attitude this frame; 1 snaps (used when parking a vehicle at build time),
 and moveVehicle passes a small value so pitch and roll lag the terrain the
 way a heavy sprung mass does instead of tracking every bump exactly.
]]
function Env.settleVehicle(v,position: Vector3,facing: Vector3,blend: number?)
 local flat=V(facing.X,0,facing.Z)
 if flat.Magnitude<0.001 then flat=V(0,0,-1) end
 flat=flat.Unit
 local ignore={v.model}
 local baseY=Env.surfaceY(position.X,position.Z,position.Y,ignore)
 -- Yaw-only frame. Built from a horizontal look vector, so the vehicle's
 -- reference frame can never itself acquire a pitch or roll: attitude is only
 -- ever the small, clamped correction applied on top of this.
 local flatCF=CFrame.lookAt(V(position.X,baseY,position.Z),V(position.X,baseY,position.Z)+flat)

 local front,rear,left,right,frontN,rearN,leftN,rightN=0,0,0,0,0,0,0,0
 local total,count=0,0
 for _,wheel in v.wheels do
  local at=flatCF*CF(wheel.offset.X,0,wheel.offset.Z)
  local gy=Env.surfaceY(at.Position.X,at.Position.Z,baseY,ignore)
  local deflection=math.clamp(gy-baseY,-SUSPENSION_TRAVEL,SUSPENSION_TRAVEL)
  wheel.groundY=gy
  wheel.deflection=deflection
  total+=deflection;count+=1
  if wheel.z<0 then front+=deflection;frontN+=1 else rear+=deflection;rearN+=1 end
  if wheel.side<0 then left+=deflection;leftN+=1 else right+=deflection;rightN+=1 end
 end
 local mean=count>0 and total/count or 0
 local frontAvg=frontN>0 and front/frontN or 0
 local rearAvg=rearN>0 and rear/rearN or 0
 local leftAvg=leftN>0 and left/leftN or 0
 local rightAvg=rightN>0 and right/rightN or 0
 -- Nose-up when the front wheels ride higher than the rear. -Z is forward,
 -- so a positive pitch about X lifts the nose.
 local targetPitch=math.clamp(math.atan2(frontAvg-rearAvg,math.max(v.length*0.7,1)),-MAX_PITCH,MAX_PITCH)
 local targetRoll=math.clamp(math.atan2(rightAvg-leftAvg,math.max(v.width,1)),-MAX_ROLL,MAX_ROLL)
 local k=blend or 1
 v.pitch+=(targetPitch-v.pitch)*k
 v.roll+=(targetRoll-v.roll)*k
 v.lift+=(mean-v.lift)*k

 -- The chassis frame: the patch of snow under the truck, yawed to its
 -- heading, with the suspension's mean lift and the clamped attitude on top.
 -- Pitch and roll are applied HERE, about the ground contact, so the body
 -- rocks over its wheels rather than about its own roof.
 local yaw=math.atan2(-flat.X,-flat.Z)
 local chassis=CF(flatCF.Position+V(0,v.lift,0))*CFrame.Angles(0,yaw,0)*A(v.pitch,0,v.roll)
 v.placeBody(chassis)
 for _,wheel in v.wheels do
  local at=flatCF*CF(wheel.offset.X,0,wheel.offset.Z)
  -- Each wheel is placed in the FLAT frame, on the surface found under it,
  -- and spun about its own axle - so it stays level and stays on the snow
  -- while the body above it pitches and rolls.
  wheel.place(CF(at.Position.X,(wheel.groundY or baseY)+WHEEL_R,at.Position.Z)*CFrame.Angles(0,yaw,0)*A(v.spin,0,0))
 end
 if v.sprayHost then
  v.sprayHost.CFrame=flatCF*CF(0,0.3,v.length*0.5)
 end
 v.groundY=baseY
end

--[[
 Drives a vehicle from `from` to `to` over normalised shot progress `t`.

 The wheels' rotation is derived from distance actually covered since the
 previous frame - never from elapsed time - so "the wheels turn at the speed
 the truck is moving" is true by construction rather than by tuning. Y in the
 supplied endpoints is ignored: the snow decides the height.
]]
function Env.moveVehicle(v,from,to,t)
 local a=Kit.smooth(t)
 local pos=from:Lerp(to,a)
 local direction=to-from
 local facing=direction.Magnitude>0.01 and direction.Unit or v.base.LookVector

 local previous=v.lastPos
 local travelled=0
 if previous then
  local delta=pos-previous
  travelled=V(delta.X,0,delta.Z).Magnitude
  -- Signed: reversing (the evacuation shot runs the transport away from
  -- camera) must not spin the wheels forwards.
  if V(delta.X,0,delta.Z):Dot(V(facing.X,0,facing.Z))<0 then travelled=-travelled end
 end
 v.lastPos=pos
 v.spin+=travelled/WHEEL_R

 -- Speed drives the body's fore/aft weight transfer and the snow spray.
 local speed=math.abs(travelled)*60
 local accel=speed-(v.speed or 0)
 v.speed=speed
 Env.settleVehicle(v,pos,facing,0.18)
 -- Squat under acceleration, dive under braking: a small pitch on top of the
 -- terrain attitude, which is what gives the hull a sense of mass.
 v.pitch=math.clamp(v.pitch+math.clamp(accel*0.004,-0.02,0.02),-MAX_PITCH*1.4,MAX_PITCH*1.4)

 if v.spray then v.spray.Rate=(t>0 and t<1) and math.clamp(speed*0.9,0,45) or 0 end
 if v.pool then v.pool.Transparency=0.88 end
end
return Env
