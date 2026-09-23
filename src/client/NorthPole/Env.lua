--!nonstrict
-- One disposable client-local set. Interiors are separate sound stages, never
-- solid shells superimposed on the exterior. No global Terrain edits to undo.
local Kit = require(script.Parent.Kit)
local VehicleMotion = require(script.Parent.VehicleMotion)
local Glyph = require(script.Parent.GlyphLanguage)
local Instrumentation = require(script.Parent.Instrumentation)
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
 -- labTrim is the island top, the door frame and the console lips. At 164 it
 -- was the brightest surface in the command room - brighter than the coats
 -- (152) and brighter than any face - which put the eye on an empty counter
 -- in every wide. Brought under the coat ceiling so the people are the
 -- lightest thing in frame that is not a screen.
 labWall = Color3.fromRGB(126,134,142), labWallDark = Color3.fromRGB(84,92,100),
 labFloor = Color3.fromRGB(58,64,70), labTrim = Color3.fromRGB(130,137,144),
 --[[
  THE ABANDONED FACILITY. The old ancient interior was marble, ivory and gold
  with fluted pillars, which reads as a temple - and a temple tells the
  audience "this is a shrine somebody built to be looked at", when the whole
  point of the new sequence is that the expedition has broken into a
  WORKING INSTALLATION that stopped working.

  So: dark worn metal and black composite carry the volume, slate carries the
  floor, and oxidised bronze is an ACCENT on the mechanisms only - never a
  surface. Ivory survives on small armour-like plates, the same material
  language Aegis Zero itself is built from, which is what quietly ties the
  building to the thing inside it before anybody says so.

  Everything here sits well below the command room's own values: this is a
  place lit by five surviving fixtures and whatever the expedition carried in,
  and a mid-grey wall under a hand lamp is already the brightest thing in
  frame.
 ]]
 facMetal = Color3.fromRGB(52,57,62), facSlate = Color3.fromRGB(40,45,49),
 facComposite = Color3.fromRGB(26,29,33), facPanel = Color3.fromRGB(66,72,78),
 bronze = Color3.fromRGB(122,96,54), bronzeDark = Color3.fromRGB(74,60,38),
 frost = Color3.fromRGB(150,174,188), facIvory = Color3.fromRGB(162,164,152),
 -- Ancient emergency lighting is cold and weak; the expedition's own lamps
 -- are warm. Keeping those two apart is how the audience reads which light
 -- belongs to the building and which the humans brought with them.
 ancientEmergency = Color3.fromRGB(96,168,196),
}
Env.Colors = C
Env.Zones = {
 BaseCenter = V(0,9500,0), Command = V(650,9500,0),
 -- The open cut. A separate sound stage, for the same reason every interior
 -- in this file is one: the exterior's ground is a single 1100-stud slab, and
 -- a pit dug into it would be a hole in a solid box that every camera looking
 -- in has to shoot through. Built as its own volume, the excavation can be
 -- lit, framed and walked into without touching the Arctic set at all.
 Excavation = V(820,9500,0),
 Door = V(1000,9500,0),
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
 local rim=Kit.cylinder({name="Rim",size=V(WHEEL_W*1.06,WHEEL_R*1.34,WHEEL_R*1.34),cframe=CF(),color=Color3.fromRGB(74,81,89),material=Enum.Material.Metal},"x")
 rim.Parent=m
 --[[
  Five RADIAL spokes, not five diameter bars.

  The previous face used full-length bars through the hub, which is ten arms
  at 36-degree spacing plus a hi-vis cap covering most of the dish. Rendered,
  that is a white daisy: the brightest object in the whole Arctic sequence,
  and - because a ten-fold pattern repeats every 36 degrees - one that tells
  you almost nothing about which way the wheel has turned.

  Radial spokes give five-fold symmetry, and the timing mark below breaks
  even that, so any rotation at all is unambiguous. The value comes down to
  sit BETWEEN the hull (96) and the rim dish (74): still the brightest thing
  on the wheel, so orientation reads, but no longer brighter than the sky.
 ]]
 for i=1,5 do
  local a=i/5*math.pi*2
  local spoke=Kit.part({name="Spoke",size=V(WHEEL_W*1.08,WHEEL_R*0.62,0.26),
   cframe=CF(0,math.cos(a)*WHEEL_R*0.38,math.sin(a)*WHEEL_R*0.38)*A(a,0,0),
   color=Color3.fromRGB(142,150,158),material=Enum.Material.Metal})
  spoke.Parent=m
 end
 -- A small hub, and one hi-vis timing mark out near the rim. The mark is what
 -- makes a slow roll legible: with it, a quarter turn is obvious in a still
 -- frame, and remains legible during the convoy arrival.
 local cap=Kit.cylinder({name="HubCap",size=V(WHEEL_W*1.2,WHEEL_R*0.34,WHEEL_R*0.34),cframe=CF(),color=Color3.fromRGB(108,116,124),material=Enum.Material.Metal},"x")
 cap.Parent=m
 local mark=Kit.part({name="TimingMark",size=V(WHEEL_W*1.16,WHEEL_R*0.3,0.2),cframe=CF(0,WHEEL_R*0.74,0),color=C.hiVis,material=Enum.Material.SmoothPlastic})
 mark.Parent=m
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
 --[[
  There is deliberately no fake light "pool" geometry here any more.

  A Neon slab parented to `body` is rigid to the hull, so it pitched and
  rolled with the suspension and slid over the snow as one hard-edged glowing
  rectangle a stud in front of the bumper - visibly a prop, and the most
  eye-catching thing in the convoy shots. The SpotLight above already lands a
  real, terrain-following pool on the snow, which is the whole reason it is
  aimed ahead of the bull bar and pitched down; that is what the shot shows.
 ]]

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
 local handle={model=m,body=body,placeBody=placeBody,wheels=wheels,base=cf,spray=emitter,sprayHost=spray,lights=lights,
  length=l,width=w,deckY=deckY,spin=0,pitch=0,roll=0,lift=0,speed=0}
 -- Place it once so a parked vehicle is already sitting on the snow, level,
 -- before any shot ever touches it.
 Env.settleVehicle(handle,cf.Position,cf.LookVector)
 return handle
end
--------------------------------------------------------------------------------
-- THE DEEP BORE
--
-- Replaces a 12-stud rotating auger with a hot-water bore plant, because the
-- auger was telling the audience the wrong story. A screw that chews a metre
-- of ice at a time is a post-hole digger; this expedition believes its signal
-- is two kilometres down, and the only thing that looks capable of that is a
-- plant that sends HEAT down a hose. The whole design exists to make one
-- sentence readable without dialogue: this machine puts something very deep
-- into the ice.
--
-- Five functional masses, and deliberately no more. A single enormous vehicle
-- covered in greebles reads as a toy; five separated objects joined by visible
-- hose and cable read as a system, because the eye can follow what feeds what:
--
--     POWER/FUEL BANK ──cable──▶ HEATER/PUMP SKID ──hose──▶ HOSE REEL
--                                                              │
--                                            over the crown sheave
--                                                              ▼
--                            CONSOLE ◀──cable──         BORE TOWER ──▶ HOLE
--
-- Two things are load-bearing for the camera rather than for the fiction. The
-- reel carries spokes and one hi-vis timing mark for the same reason the truck
-- wheels do - a rotating cylinder shows no rotation, so "the reel is running"
-- would otherwise be unobservable. And the console screen is a real
-- Instrumentation panel (see that module) rather than a printed marking,
-- because six values have to change independently across the sequence.
--------------------------------------------------------------------------------

local BORE = V(0,0,-28) -- the hole itself, relative to BaseCenter
local BORE_TOWER_TOP = 21

local function boreSystem(env,root,o)
 local bore=o+BORE
 local sys=Kit.folder("DeepBorePlant",root)

 -- 1. THE TOWER --------------------------------------------------------------
 -- A tapered lattice over the hole, tall enough to read from the arrival
 -- crane's distance and open enough that the hose inside it stays visible.
 local tower=Kit.model("BoreTower",sys)
 env.boreTower=tower
 local legs={{-1,-1},{-1,1},{1,-1},{1,1}}
 for index,leg in legs do
  local baseX,baseZ=leg[1]*2.7,leg[2]*2.7
  local topX,topZ=leg[1]*1.15,leg[2]*1.15
  Kit.beam(tower,`TowerLeg{index}`,bore+V(baseX,0,baseZ),bore+V(topX,BORE_TOWER_TOP,topZ),0.42,C.hullDark)
 end
 for level=0,4 do
  local y=2.2+level*4.4
  local t=y/BORE_TOWER_TOP
  local r=2.7+(1.15-2.7)*t
  local corners={V(-r,y,-r),V(-r,y,r),V(r,y,r),V(r,y,-r)}
  for i=1,4 do
   local a=bore+corners[i]
   local b=bore+corners[i%4+1]
   Kit.beam(tower,"TowerGirt",a,b,0.24,C.metal)
   -- One diagonal per bay per level, alternating direction, so the lattice
   -- reads as braced structure instead of a stack of square hoops.
   local upper=2.7+(1.15-2.7)*((y+4.4)/BORE_TOWER_TOP)
   if level<4 then
    local lift=V(0,4.4,0)
    local target=if (i+level)%2==0 then b*(upper/r)+lift else a*(upper/r)+lift
    Kit.beam(tower,"TowerBrace",a,bore+target,0.16,C.metal)
   end
  end
 end
 -- Crown block: the sheaves the hose runs over, and the reason the tower has
 -- a top rather than simply stopping.
 part(tower,"CrownDeck",V(4.4,0.35,4.4),CF(bore+V(0,BORE_TOWER_TOP,0)),C.hullDark,Enum.Material.DiamondPlate)
 for _,side in {-0.75,0.75} do
  cylinder(tower,"CrownSheave",V(0.45,2.3,2.3),CF(bore+V(side,BORE_TOWER_TOP+1.3,0)),C.hull)
  cylinder(tower,"SheaveHub",V(0.55,0.7,0.7),CF(bore+V(side,BORE_TOWER_TOP+1.3,0)),C.bronze)
 end
 part(tower,"CrownGuard",V(4.6,1.4,0.3),CF(bore+V(0,BORE_TOWER_TOP+1.4,1.9)),C.hiVis)
 -- A working platform partway up, with a ladder to it: scale reference, and
 -- somewhere a person could plausibly be.
 part(tower,"TowerPlatform",V(6.4,0.28,3),CF(bore+V(0,8.4,2.6)),C.metal,Enum.Material.DiamondPlate)
 Kit.beam(tower,"PlatformRail",bore+V(-3.2,9.6,4),bore+V(3.2,9.6,4),0.12,C.hiVis)
 for rung=1,15 do
  Kit.beam(tower,"TowerLadderRung",bore+V(-0.7,rung*0.55,3.4),bore+V(0.7,rung*0.55,3.4),0.1,C.metal)
 end
 for _,x in {-0.75,0.75} do
  Kit.beam(tower,"TowerLadderStile",bore+V(x,0,3.4),bore+V(x,8.6,3.4),0.12,C.metal)
 end
 -- Guys out to four ground anchors. Thin trim, so they opt out of camera
 -- queries the way the route markers do.
 for _,anchor in {V(-11,0,-39),V(11,0,-39),V(-11,0,-17),V(11,0,-17)} do
  local guy=Kit.beam(sys,"TowerGuy",bore+V(0,BORE_TOWER_TOP-2.5,0),o+anchor,0.09,C.dark)
  guy.CanQuery=false
  part(sys,"GuyAnchor",V(1.2,0.5,1.2),CF(o+anchor+V(0,0.25,0)),C.hullDark)
 end

 -- 2. THE HOLE ---------------------------------------------------------------
 -- A raised steel collar, a black throat, a melt channel and a sump. Without
 -- the collar the bore is a dark smudge on white ground; with it, it is
 -- obviously an engineered opening.
 local collar=Kit.model("BoreCollar",sys)
 env.boreCollar=collar
 for i=1,12 do
  local a=i/12*math.pi*2
  part(collar,"CollarSegment",V(1.4,0.9,0.7),CF(bore+V(math.sin(a)*2.1,0.45,math.cos(a)*2.1))*A(0,a,0),C.hullDark,Enum.Material.DiamondPlate)
 end
 env.boreThroat=part(collar,"BoreThroat",V(3.4,0.3,3.4),CF(bore+V(0,0.18,0)),Color3.fromRGB(8,10,14),Enum.Material.SmoothPlastic,"ball")
 part(collar,"CollarDeck",V(9,0.2,9),CF(bore+V(0,0.1,0)),C.ice:Lerp(C.deep,0.35),Enum.Material.Ice)
 part(collar,"MeltChannel",V(1.1,0.16,7),CF(bore+V(3.4,0.14,3.5)),C.ice:Lerp(C.deep,0.55),Enum.Material.Ice)
 part(collar,"MeltSump",V(3,0.5,3),CF(bore+V(3.4,0.05,7.4)),C.deep,Enum.Material.Glass,nil,0.35)
 for i=1,10 do
  Kit.beam(sys,"FracturedIce",bore+V(0,0.4,0),bore+V(math.sin(i)*7,0.4,math.cos(i)*7),0.08,C.deep)
 end
 -- Steam off the hole is the single clearest "this is hot water, in the
 -- Arctic" signal in the frame, so it gets a real host part and its rate is
 -- driven per shot rather than left running.
 local vent=part(sys,"BoreVent",V(3,2,3),CF(bore+V(0,1.4,0)),C.snow,nil,nil,1)
 env.boreSteam=Kit.dust(vent,0,Color3.fromRGB(226,234,240),6)
 env.boreSteam.Acceleration=V(1.2,5,0.4)
 env.boreSteam.Lifetime=NumberRange.new(1.2,2.8)
 env.boreSteam.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.6),NumberSequenceKeypoint.new(1,5.5)})

 -- 3. THE HOSE REEL ----------------------------------------------------------
 local reelAxle=o+V(-12.5,4.6,-23.5)
 env.reelAxle=CF(reelAxle)
 local reel=Kit.model("HoseReel",sys)
 -- Exposed so 07d can declare it: that shot frames the reel, so the near
 -- flange is in front of the axle it is focused on BY CONSTRUCTION, and
 -- without `foreground` the camera spends the beat correcting away from the
 -- only thing it is there to look at.
 env.hoseReel=reel
 local drum=Kit.model("ReelDrum",reel)
 cylinder(drum,"ReelBarrel",V(7,6.4,6.4),CF(reelAxle),C.hullDark)
 -- Wrapped hose, as four bands of decreasing tidiness. One solid cylinder
 -- reads as a pipe; bands read as something wound.
 for i=0,3 do
  cylinder(drum,"WoundHose",V(1.5,8.4-i*0.28,8.4-i*0.28),CF(reelAxle+V(-2.6+i*1.75,0,0)),C.dark)
 end
 for _,side in {-1,1} do
  cylinder(drum,"ReelFlange",V(0.45,9.6,9.6),CF(reelAxle+V(side*3.8,0,0)),C.hull)
  -- Spokes, and one hi-vis mark. Same lesson the truck wheels taught: a
  -- turning cylinder is indistinguishable from a still one, and this reel
  -- turning is what the first bore shot is about.
  for i=1,6 do
   local a=i/6*math.pi*2
   part(drum,"FlangeSpoke",V(0.5,8.8,0.42),CF(reelAxle+V(side*4.05,0,0))*A(a,0,0),C.hullDark)
  end
  part(drum,"ReelTimingMark",V(0.55,1.6,0.5),CF(reelAxle+V(side*4.1,3.9,0)),C.hiVis)
 end
 env.reelSpin=Kit.rigid(drum,CF(reelAxle))
 -- Skid, bearings and the drive motor the reel is obviously driven BY.
 part(reel,"ReelSkid",V(11.5,1.2,10.5),CF(reelAxle+V(0,-4,0)),C.hullDark,Enum.Material.DiamondPlate)
 for _,side in {-1,1} do
  part(reel,"ReelPedestal",V(1.6,4.4,3),CF(reelAxle+V(side*4.6,-2.2,0)),C.hull)
  part(reel,"ReelBearing",V(1.9,1.9,1.9),CF(reelAxle+V(side*4.6,0,0)),C.bronze,nil,"ball")
 end
 part(reel,"ReelDriveMotor",V(2.4,2.6,3.4),CF(reelAxle+V(-6.4,-1.6,0)),C.metal)
 cylinder(reel,"ReelDriveShaft",V(2,0.8,0.8),CF(reelAxle+V(-5.3,-1.6,0)),C.bronze)
 part(reel,"ReelLevelWind",V(9,0.5,0.6),CF(reelAxle+V(0,0.2,5.6)),C.metal)
 Kit.label(part(reel,"ReelPlate",V(3.2,0.7,0.1),CF(reelAxle+V(0,-3.2,-5.4))*A(0,math.pi,0),C.hullDark),"HOSE  2400 m",C.hiVis)

 -- 4. THE HEATER / PUMP SKID -------------------------------------------------
 local plant=o+V(-24.5,0,-31)
 local skid=Kit.model("HeaterPumpSkid",sys)
 env.pumpSkid=skid
 part(skid,"SkidBase",V(11,1,7.5),CF(plant+V(0,0.5,0)),C.hullDark,Enum.Material.DiamondPlate)
 part(skid,"PlantHousing",V(10,5,6.6),CF(plant+V(0,3.5,0)),C.hull)
 part(skid,"PlantRoof",V(10.4,0.4,7),CF(plant+V(0,6.2,0)),C.hullDark)
 part(skid,"PlantRoofSnow",V(9,0.4,6),CF(plant+V(0,6.5,0)),C.snow,Enum.Material.Snow,"ball")
 part(skid,"HiVisStripe",V(10.1,0.5,6.7),CF(plant+V(0,1.6,0)),C.hiVis)
 -- Louvres and a burner flue: the two details that say "this thing is
 -- combusting something", which is what makes the steam legible.
 for i=1,9 do
  part(skid,"BurnerLouver",V(0.1,3,0.5),CF(plant+V(-4+i*0.8,3.6,-3.35)),C.dark)
 end
 cylinder(skid,"BurnerFlue",V(4.6,1.1,1.1),CF(plant+V(3.4,8.4,-1.2)),C.metal,"y")
 part(skid,"FlueCap",V(1.6,0.3,1.6),CF(plant+V(3.4,10.8,-1.2)),C.hullDark)
 local plume=part(skid,"FluePlume",V(1.6,1.6,1.6),CF(plant+V(3.4,11.6,-1.2)),C.snow,nil,nil,1)
 env.plantSteam=Kit.dust(plume,10,Color3.fromRGB(214,222,228),5)
 env.plantSteam.Acceleration=V(3,6,1)
 env.plantSteam.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.5),NumberSequenceKeypoint.new(1,4.5)})
 -- Manifold: four pipes and three valve wheels on the face the camera sees.
 for i=1,4 do
  cylinder(skid,"ManifoldPipe",V(9.4,0.55,0.55),CF(plant+V(0,1.9+i*0.8,3.6)),C.bronzeDark,"z")
 end
 for i=1,3 do
  local wheelAt=plant+V(-3+i*3,4.3,3.9)
  cylinder(skid,"ValveWheel",V(0.3,1.5,1.5),CF(wheelAt),C.hiVis,"z")
  for s=1,4 do
   part(skid,"ValveSpoke",V(0.16,1.4,0.16),CF(wheelAt)*A(0,0,s*math.pi/4),C.hullDark)
  end
 end
 part(skid,"PlantAccessDeck",V(11.5,0.25,2.2),CF(plant+V(0,1.1,4.8)),C.metal,Enum.Material.DiamondPlate)
 Kit.label(part(skid,"PlantPlate",V(5,0.9,0.12),CF(plant+V(-2,5.4,3.35))*A(0,math.pi,0),C.hullDark),"HOT WATER PLANT / 2",C.hiVis)

 -- 5. POWER AND FUEL ---------------------------------------------------------
 local bank=o+V(-24.5,0,-18)
 local power=Kit.model("PowerAndFuelBank",sys)
 env.powerBank=power
 part(power,"GeneratorSkid",V(9,1,6.6),CF(bank+V(0,0.5,0)),C.hullDark,Enum.Material.DiamondPlate)
 part(power,"GeneratorHousing",V(8.2,4.4,5.8),CF(bank+V(0,3.2,0)),C.hull)
 part(power,"GeneratorRoof",V(8.6,0.35,6.2),CF(bank+V(0,5.6,0)),C.hullDark)
 for i=1,11 do
  part(power,"RadiatorFin",V(0.09,2.8,0.45),CF(bank+V(-3.6+i*0.62,3.3,3)),C.dark)
 end
 cylinder(power,"GeneratorExhaust",V(3,0.7,0.7),CF(bank+V(-3,7.2,-1.6)),C.dark,"y")
 for i=1,3 do
  cylinder(power,"FuelDrum",V(3.2,2.2,2.2),CF(bank+V(5.4,1.6,-2.6+i*2.4)),C.hiVis,"y")
 end
 part(power,"FuelBund",V(4.4,0.35,8),CF(bank+V(5.4,0.2,0)),C.hullDark,Enum.Material.DiamondPlate)
 Kit.label(part(power,"PowerPlate",V(4.2,0.8,0.12),CF(bank+V(0,4.6,3.05))*A(0,math.pi,0),C.hullDark),"SITE POWER / 1",C.hiVis)

 -- 6. THE OPERATOR CONSOLE ---------------------------------------------------
 -- Placed so the operator stands with their back to camera-left and the bore
 -- beyond the screen: one camera position can hold the panel AND the tower,
 -- which is what stops the telemetry insert reading as a floating UI card.
 local consoleAt=o+V(8.6,0,-21)
 local consoleCF=CFrame.lookAt(V(consoleAt.X,consoleAt.Y,consoleAt.Z),V(bore.X,consoleAt.Y,bore.Z))
 env.boreConsoleCF=consoleCF
 local console=Kit.model("BoreControlConsole",sys)
 env.boreConsoleModel=console
 part(console,"ConsolePlinth",V(5,2.4,2.4),consoleCF*CF(0,1.2,0),C.hullDark)
 part(console,"ConsoleDesk",V(5.2,0.3,2.8),consoleCF*CF(0,2.5,0.1),C.metal,Enum.Material.DiamondPlate)
 part(console,"ConsoleKick",V(5.2,0.3,2.6),consoleCF*CF(0,0.15,0),C.dark)
 -- The screen faces the operator's side of the desk (the console's own +Z),
 -- pitched up 22 degrees toward a standing reader.
 local screenCF=consoleCF*CF(0,3.5,0.72)*A(0,math.pi,0)*A(math.rad(22),0,0)
 env.boreScreen=part(console,"BoreTelemetryPanel",V(3.7,2.8,0.14),screenCF,Color3.fromRGB(11,13,16),Enum.Material.SmoothPlastic)
 part(console,"ScreenBezel",V(4.1,3.2,0.12),screenCF*CF(0,0,0.1),C.hullDark)
 part(console,"ScreenHood",V(4.1,0.3,1),screenCF*CF(0,1.7,-0.4)*A(math.rad(-30),0,0),C.hullDark)
 for _,side in {-1,1} do
  part(console,"ScreenHoodCheek",V(0.24,1.5,1),screenCF*CF(side*1.95,0.8,-0.35),C.hullDark)
  part(console,"ScreenStanchion",V(0.28,1.3,0.28),consoleCF*CF(side*1.7,2.9,0.55),C.metal)
 end
 part(console,"ConsoleKeyboard",V(2.6,0.1,1),consoleCF*CF(-0.8,2.68,0.9),C.dark)
 for i=1,6 do
  part(console,"ToggleGuard",V(0.34,0.24,0.34),consoleCF*CF(1.1+((i-1)%3)*0.5,2.72,0.6+math.floor((i-1)/3)*0.5),C.hiVis)
 end
 cylinder(console,"EmergencyStop",V(0.3,0.9,0.9),consoleCF*CF(2.1,2.78,1),Color3.fromRGB(176,48,38),"y")
 part(console,"ConsoleCanopy",V(6,0.2,3.6),consoleCF*CF(0,5.6,0.2),C.hiVis)
 for _,side in {-1,1} do
  Kit.beam(console,"CanopyPost",(consoleCF*CF(side*2.7,0,-1.2)).Position,(consoleCF*CF(side*2.7,5.5,-1.2)).Position,0.16,C.metal)
 end
 -- The one warm practical over the desk, aimed down at it. Everything else out
 -- here is site floodlighting; this is the light the operator works by.
 local task=part(console,"ConsoleTaskLamp",V(1.4,0.22,0.5),consoleCF*CF(0,5.3,0.3),C.warm,Enum.Material.Neon,nil,0.25)
 task.CastShadow=false
 local taskBeam=Instance.new("SpotLight")
 taskBeam.Face=Enum.NormalId.Bottom;taskBeam.Angle=72;taskBeam.Range=11;taskBeam.Brightness=1.1;taskBeam.Color=C.warm
 taskBeam.Parent=task
 env.boreDisplay=Instrumentation.boreConsole(env.boreScreen,Enum.NormalId.Front)

 -- 7. HOSE AND CABLE RUNS ----------------------------------------------------
 -- What actually makes five boxes read as one machine. The supply hose is
 -- drawn as a real catenary from the reel, over the crown, down the tower.
 local function hose(name,a,b,sag,width,color)
  local previous=a
  for i=1,10 do
   local t=i/10
   local nextPoint=a:Lerp(b,t)-V(0,math.sin(t*math.pi)*sag,0)
   Kit.beam(sys,name,previous,nextPoint,width,color or C.dark)
   previous=nextPoint
  end
 end
 hose("SupplyHose",reelAxle+V(0,4.2,-2.6),bore+V(-0.75,BORE_TOWER_TOP+2.4,0),1.6,0.44)
 hose("BoreFeedHose",bore+V(0.75,BORE_TOWER_TOP+2.4,0),bore+V(0,1.2,0),0.4,0.44)
 hose("PlantToReelHose",plant+V(4.6,2.6,2),reelAxle+V(-4.2,-3.4,2.4),1,0.42,C.bronzeDark)
 cable(sys,bank+V(4,1.4,-3.2),plant+V(-4,1.6,-2),0.8)
 cable(sys,bank+V(4,1.2,2.6),(consoleCF*CF(-2.4,0.4,-0.6)).Position,1.4)
 cable(sys,(consoleCF*CF(0,0.3,-1.3)).Position,bore+V(2.4,0.4,2.4),0.7)
 cable(sys,plant+V(4.2,1.2,3),bore+V(-2.6,0.5,1.8),1.1)
 -- Cable protectors where a run crosses the working area, so the runs read as
 -- laid rather than dropped.
 for i=1,4 do
  part(sys,"CableRamp",V(2.6,0.28,1),CF(o+V(-16+i*4.4,0.24,-25)),C.hiVis,Enum.Material.SmoothPlastic,"wedge")
 end

 -- 8. WORK LIGHTING ----------------------------------------------------------
 -- Deliberately SpotLights built directly rather than through Kit.light: they
 -- are directional (which is what a work light is), and they do not spend the
 -- scene's shared PointLight budget, which the abandoned facility still needs.
 for _,spec in {{at=V(0,14,3.2),look=BORE,host=tower},{at=V(-12.5,9.4,-28.6),look=V(-12.5,0,-23.5),host=reel}} do
  part(spec.host,"WorkLampHead",V(1.5,0.7,0.9),CFrame.lookAt(o+spec.at,o+spec.look),C.hullDark)
  local lens=part(spec.host,"WorkLampLens",V(1.2,0.5,0.1),CFrame.lookAt(o+spec.at,o+spec.look)*CF(0,0,-0.5),C.warm,Enum.Material.Neon,nil,0.2)
  lens.CastShadow=false
  local beam=Instance.new("SpotLight")
  beam.Face=Enum.NormalId.Front;beam.Angle=68;beam.Range=34;beam.Brightness=1.5;beam.Color=C.warm
  beam.Parent=lens
  part(spec.host,"WorkLampArm",V(0.2,1.2,0.2),CF(o+spec.at+V(0,0.8,0)),C.metal)
 end

 -- 9. SNOW THAT ARRIVES DURING THE MONTAGE ------------------------------------
 -- Built invisible and grown by Env.setBoreWeathering. Depth numbers climbing
 -- on a screen is a caption; snow visibly banked up against equipment that was
 -- clear an hour ago is the passage of time happening in the frame.
 env.boreSnowCaps={}
 for _,spec in {
  {at=V(0,0.35,-24.4),size=V(8,0.7,3.4)},
  {at=V(-12.5,9.3,-23.5),size=V(8,0.8,7)},
  {at=V(-24.5,6.6,-31),size=V(9,0.7,6)},
  {at=V(-24.5,6,-18),size=V(8,0.7,5.4)},
  {at=V(8.6,5.8,-21),size=V(5.6,0.6,3.4)},
  {at=V(-8,0.5,-30),size=V(6,1,4)},
 } do
  local cap=part(sys,"AccumulatedSnow",spec.size,CF(o+spec.at),C.snow,Enum.Material.Snow,"ball",1)
  cap.CanQuery=false
  table.insert(env.boreSnowCaps,{part=cap,size=spec.size})
 end

 -- 10. SITE CLUTTER ----------------------------------------------------------
 -- Enough that the plant reads as somewhere people have been working for days.
 crate(sys,CF(o+V(-6,1.4,-19)),V(2.8,2.4,2.8))
 crate(sys,CF(o+V(-3.4,1.4,-17.4)),V(2.2,2,2.2))
 part(sys,"HoseSpoolSpare",V(3.4,1.6,3.4),CF(o+V(-18,0.8,-25)),C.dark,Enum.Material.SmoothPlastic)
 for i=1,3 do
  part(sys,"CoreSampleTube",V(0.5,0.5,5),CF(o+V(4.5+i*0.8,0.3,-17))*A(0,0.1*i,0),C.hullDark)
 end
 part(sys,"SampleRack",V(4,0.6,5.4),CF(o+V(5.6,0.2,-17)),C.metal,Enum.Material.DiamondPlate)
 for _,at in {V(-8,0,-31),V(6,0,-32)} do
  part(sys,"SafetyBarrier",V(5,1.4,0.24),CF(o+at),C.hiVis)
  for _,side in {-1,1} do
   part(sys,"BarrierFoot",V(0.5,0.3,1.4),CF(o+at+V(side*2.2,-0.55,0)),C.dark)
  end
 end
end

-- Two slopes meet at a shared crest, with their lower faces buried in the
-- substrate. Unlike superimposed wedges this has no vertical end at the crest.
local function snowRidge(parent,cf,width,height,length)
 for _,side in {-1,1} do
  part(parent,"WindSnowRidge",V(width,height,length/2),
   cf*CF(0,0,side*length/4)*A(0,side==1 and math.pi or 0,0),C.snow,Enum.Material.Snow,"wedge")
 end
end
local function exterior(env,rng)
 local root=Kit.folder("ArcticLandscape",env.folder)
 local o=Env.Zones.BaseCenter
 -- Preserve the downstream set's seeded layout, including the interiors.
 -- Consume the former surface's random draws without building its geometry.
 local surfaceRng=rng:Clone()
 for _=1,272 do rng:NextNumber(-0.5,0.5) end
 for _=1,95 do
  local x=rng:NextNumber(-95,95);rng:NextNumber(-20,145)
  if math.abs(x)>12 then
   rng:NextNumber(4,11);rng:NextNumber(1,3);rng:NextNumber(6,16)
  end
 end
 for _=1,62 do rng:NextNumber(1.1,2.1) end
 part(root,"BuriedIceShelf",V(1100,18,1100),CF(o-V(0,12,0)),C.deep,Enum.Material.Ice)
 part(root,"PackedSnowField",V(1100,3,1100),CF(o-V(0,1.5,0)),C.snow,Enum.Material.Snow)
 -- Broad, low wind relief outside the route and occupied base footprint.
 for i=1,34 do
  local side=i%2==0 and 1 or -1
  local x=side*surfaceRng:NextNumber(55,240)
  local z=surfaceRng:NextNumber(75,300)
  local h=surfaceRng:NextNumber(0.3,1.4)
  snowRidge(root,CF(o+V(x,h*0.25,z))*A(0,-0.35+surfaceRng:NextNumber(-0.12,0.12),0),
   surfaceRng:NextNumber(8,24),h,surfaceRng:NextNumber(12,34))
 end
 local ROUTE_HALF=7
 part(root,"GradedRoadbed",V(14,0.24,190),CF(o+V(0,0.13,97)),C.ice:Lerp(C.snow,0.45),Enum.Material.Snow)
 for _,x in {-2.9,2.9} do
  --[[
   A rut, not a painted line. One 184-stud bar is a perfectly straight,
   perfectly even stripe - the graphic-decal read this pass exists to remove -
   and a row of short tread marks is the tiled read it replaced. So: FIVE long
   overlapping segments, each wandering a little in width and a little across
   the roadbed, which is what a vehicle repeatedly following roughly the same
   line actually leaves. They overlap by design, so the rut never breaks.
  ]]
  local z=6
  while z<190 do
   local length=surfaceRng:NextNumber(34,46)
   part(root,"TyreTrack",V(surfaceRng:NextNumber(0.95,1.2),0.04,length+3),
    CF(o+V(x+surfaceRng:NextNumber(-0.22,0.22),0.28,z+length/2))*A(0,surfaceRng:NextNumber(-0.01,0.01),0),
    C.ice:Lerp(C.deep,0.2):Lerp(C.snow,0.35),Enum.Material.Snow)
   z+=length
  end
  -- Sparse feathered shoulders, irregular in length and spacing, soften the
  -- rut's edge without a repeated tread/decal pattern.
  for i=1,9 do
   local at=10+i*18+surfaceRng:NextNumber(-5,5)
   part(root,"TrackWear",V(surfaceRng:NextNumber(1.2,1.6),0.025,surfaceRng:NextNumber(3,10)),
    CF(o+V(x+surfaceRng:NextNumber(-0.12,0.12),0.265,at))*A(0,surfaceRng:NextNumber(-0.018,0.018),0),C.ice:Lerp(C.snow,0.38),Enum.Material.Snow,"wedge")
  end
 end
 -- Plough piles begin outside the gate; the apron remains open to both sides.
 for _,side in {-1,1} do
  for i=1,5 do
   local h=surfaceRng:NextNumber(0.35,0.75)
   snowRidge(root,CF(o+V(side*8.4,h*0.25,66+(i-1)*29))*A(0,math.pi/2,0),
    surfaceRng:NextNumber(29,35),h,surfaceRng:NextNumber(2.4,3.2))
  end
 end
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
 --[[
  Grouped, because the arrival crane has to be able to say "the gate belongs in
  front of the convoy". It does: the whole point of the shot is watching the
  trucks drive THROUGH this. Measured in Studio, the sign crossed the sightline
  for two frames as the lead truck passed under it, Camera.applyShot found the
  framing blocked, collapsed it, and then held a 54-degree orbit for the
  remaining third of the take - one deliberate crane turning into two shots,
  from two frames of an object the shot is deliberately shooting past. That is
  exactly what `shot.foreground` exists for.
 ]]
 local gate=Kit.model("Gate",root)
 for _,side in {-1,1} do
  Kit.beam(gate,"GateMast",o+V(side*(ROUTE_HALF+1),0,GATE_Z),o+V(side*(ROUTE_HALF+1),9,GATE_Z),0.5,C.metal)
  lamp(gate,CF(o+V(side*(ROUTE_HALF+0.4),8.2,GATE_Z+0.6))*A(-0.5,0,0),C.warm,26,1.6)
 end
 Kit.beam(gate,"GateSpan",o+V(-(ROUTE_HALF+1),8.6,GATE_Z),o+V(ROUTE_HALF+1,8.6,GATE_Z),0.4,C.metal)
 local gateSign=part(gate,"GateSign",V(11,2.1,0.24),CF(o+V(0,7.2,GATE_Z+0.2)),C.hullDark)
 Kit.label(gateSign,"ARCTIC EXPEDITION SEVEN\n88° N  ·  RESTRICTED",C.hiVis)
 part(gate,"BoomBarrier",V(9,0.3,0.3),CF(o+V(-7.2,5.6,GATE_Z-1.8))*A(0,0,math.rad(-90)),C.hiVis)
 part(gate,"BoomCounterweight",V(0.8,0.8,0.8),CF(o+V(-7.2,1.2,GATE_Z-1.8)),C.hullDark)
 env.gate=gate
 local shack=Kit.model("GateHut",gate)
 part(shack,"Hut",V(3.4,3.4,3.2),CF(o+V(ROUTE_HALF+3.4,1.9,GATE_Z-3)),C.hull)
 part(shack,"HutRoof",V(3.9,0.3,3.7),CF(o+V(ROUTE_HALF+3.4,3.7,GATE_Z-3)),C.hullDark)
 part(shack,"HutWindow",V(0.12,1.2,2),CF(o+V(ROUTE_HALF+1.7,2.4,GATE_Z-3)),C.warm,Enum.Material.Neon,nil,0.35)
 part(shack,"HutSnow",V(3.4,0.3,3.2),CF(o+V(ROUTE_HALF+3.4,3.9,GATE_Z-3)),C.snow,Enum.Material.Snow,"ball")

 --[[
  THE APRON. A flat compacted pad inside the gate where vehicles actually
  stop, with painted bays. Without it the trucks park on open snow at
  arbitrary angles and the site has no "here is where you arrive" beat.
 ]]
 --[[
  Graded snow, not a blue mat. At a 0.22 lerp off C.ice this pad was far bluer
  than both the roadbed feeding it (0.45) and the snowfield around it, so from
  the arrival crane it read as a rectangle of water dropped into the set - the
  single most "procedural toy map" thing in frame. It is the same compacted
  surface as the road, swept a little cleaner, so it sits just to the SNOW side
  of the roadbed and the two now read as one continuous graded area.
 ]]
 part(root,"ArrivalApron",V(52,0.35,44),CF(o+V(4,0.18,27)),C.ice:Lerp(C.snow,0.5),Enum.Material.Snow)
 -- Edge markers leave the full central lane clear, including at the gate.
 for _,x in {-6,7} do
  part(root,"ApronBayLine",V(0.18,0.04,32),CF(o+V(x,0.375,27)),C.hiVis,Enum.Material.SmoothPlastic)
 end
 for _,x in {-14.5,18.5} do
  part(root,"ApronKerb",V(15,0.5,0.6),CF(o+V(x,0.4,49)),C.hiVis)
 end
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
  -- Inner edge clears the corridor. At 26 studs out with a width of up to 34,
  -- a ridge reached x=9 - two studs off the roadbed's own edge and fifteen
  -- studs tall, which is a canyon wall, not relief, and it is what put
  -- 01_BlackRadio's low lens behind a wall of ice for its whole length. From
  -- 44 the nearest face is 27 studs out. ONE draw, same position in the
  -- sequence, so nothing downstream of this loop shifts.
  local x=side*rng:NextNumber(44,92)
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
 -- The four gold "ExposedAncientEdge" columns that used to stand here are
 -- gone. They put ancient structure in plain sight on the surface, in the
 -- establishing shots, before anybody had drilled anything - which is exactly
 -- the reveal this whole sequence now exists to earn. Nothing artificial is
 -- visible anywhere on the Arctic set until the bore finds it.
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
 -- 1 and 2 are the arriving convoy (moved by the shots); 3 is the rig truck,
-- moved off the bore centreline to x=15 so the bore plant itself occupies the
-- working area and the tower stands alone over the hole; 4 and 5 are parked on
-- the apron in marked bays, angled off the route so the approach corridor
-- stays visually clear.
 local placements={
  {at=V(0,1.6,150),yaw=0},
  {at=V(0,1.6,178),yaw=0},
  {at=V(15,1.6,-25),yaw=math.rad(-8)},
  {at=V(-10.5,1.6,22),yaw=0},
  {at=V(16,1.6,22),yaw=math.rad(96)},
 }
 for i,kind in kinds do
  local placement=placements[i]
  table.insert(env.vehicles,vehicle(root,CF(o+placement.at)*A(0,placement.yaw,0),kind,i))
 end
 -- The rig truck is now a support vehicle parked beside the bore rather than
 -- the drill itself: its deck carries spare hose and its outriggers are down,
 -- which is what a vehicle that has been stationary for days looks like.
 local rigTruck=env.vehicles[3].model
 for i=1,3 do
  cylinder(rigTruck,"SpareHoseCoil",V(1.4,4.6,4.6),CF(o+V(15,4.2,-27+i*1.6)),C.dark)
 end
 boreSystem(env,root,o)
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

 --[[
  The focal point.

  Stood back from z=-6.4 to -9.2. At the old depth the panel was only about
  six studs beyond the people working at the island, and all three of them
  face it - so every reverse angle in the scene was taken from BEHIND it.
  Measured in Studio, the dialogue mediums for Lyra and Voss put the lens at
  z=-6.5, a fifth of a stud past the screen, and the camera's obstruction
  correction had to swing every one of those shots around it.

  Three studs further back and the same framing clears the panel by over a
  stud and a half, the room gets a deeper background behind the cast, and the
  screen is still the thing they are all looking at.
 ]]
 part(room,"DisplayMount",V(1,2.2,1),at(0,1.6,-9.2),C.labWallDark)
 env.signalDisplay=part(room,"SignalDisplay",V(7,3,0.25),at(0,4.6,-9.2)*A(-0.16,0,0),C.deep,Enum.Material.Glass)
 part(room,"SignalDisplayBezel",V(7.5,3.5,0.18),at(0,4.6,-9.35)*A(-0.16,0,0),C.labWallDark)
 --[[
  ON THE ROOM SIDE of the panel.

  The display is built with no yaw, so its local -Z (which is what Roblox
  calls a part's Front, and what Kit.label defaults to) points AWAY from the
  people standing at the island. The three pulse bars were mounted at local
  z=-0.18 and the printed marking on Front, so both of them were on the back
  of the screen: the shot that exists to show the returning signal rendered as
  a blank blue sheet, which is exactly what it looked like in Studio.
 ]]
 env.pulses={}
 for i=1,3 do
  local pulse=part(room,"RepeatingPulse",V(0.3,1.8,0.08),env.signalDisplay.CFrame*CF((i-2)*1.8,-0.2,0.18),C.cyan,Enum.Material.Neon)
  table.insert(env.pulses,pulse)
 end
 Kit.label(env.signalDisplay,"07  /  SUBGLACIAL RETURN",C.cyan,Enum.NormalId.Back)
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

--------------------------------------------------------------------------------
-- THE OPEN CUT
--
-- What the expedition does AFTER the bore drops into a void: widen the
-- shallow section until the thing under the ice is standing in daylight.
--
-- This is a stepped excavation, not a hole. Three benches per side, each one
-- set in from the last, because that is how you dig a deep pit in a material
-- that will otherwise shear - and because a straight-sided shaft gives the
-- camera no scale at all, whereas benches give it a staircase of known steps
-- to read the depth against.
--
-- The point of the shot it exists for is the CONTRAST: cut ice above, and a
-- flat black composite roof at the bottom of it with bronze conduit running
-- out of the walls. Nothing about that roof is geological, and the audience
-- should be able to see that from the rim without being told.
--
-- It is its own stage (Zones.Excavation) rather than a pit dug into the
-- Arctic set: see the note on that zone.
--------------------------------------------------------------------------------

local function excavation(env,rng)
 local x=Env.Zones.Excavation
 local pit=Kit.folder("OpenCut",env.folder)
 env.excavation=pit
 local BENCHES={{inner=23,top=0,bottom=-8},{inner=18,top=-8,bottom=-16},{inner=13,top=-16,bottom=-24}}
 local ROOF_Y=-25

 -- Surrounding ice mass, built as four walls rather than one block with a
 -- hole in it: the walls ARE the cut faces, so there is no solid slab for a
 -- camera looking in to have to shoot through.
 for _,bench in BENCHES do
  local height=bench.top-bench.bottom
  local midY=(bench.top+bench.bottom)/2
  for _,side in {-1,1} do
   part(pit,"CutIceFace",V(6,height,bench.inner*2+12),CF(x+V(side*(bench.inner+3),midY,0)),C.ice,Enum.Material.Ice)
   part(pit,"CutIceFace",V(bench.inner*2+12,height,6),CF(x+V(0,midY,side*(bench.inner+3))),C.ice,Enum.Material.Ice)
  end
  -- The bench floor itself: a walkable ledge of cut ice, scored by the saw.
  for _,side in {-1,1} do
   part(pit,"BenchFloor",V(5,0.6,bench.inner*2+10),CF(x+V(side*(bench.inner+2.5),bench.top-0.3,0)),C.ice:Lerp(C.snow,0.4),Enum.Material.Ice)
   part(pit,"BenchFloor",V(bench.inner*2+10,0.6,5),CF(x+V(0,bench.top-0.3,side*(bench.inner+2.5))),C.ice:Lerp(C.snow,0.4),Enum.Material.Ice)
  end
 end
 -- Saw scoring on the upper faces. Vertical kerfs at an irregular pitch read
 -- as machine-cut ice; an unbroken blue wall reads as a swimming pool.
 -- Occasional saw marks, not hatching. At twenty-six a side these read as
 -- corduroy from the establishing distance the shot is actually taken at;
 -- nine, unevenly spaced and half the depth, read as a cut face.
 for i=1,9 do
  local along=-20+i*4.6+rng:NextNumber(-1.6,1.6)
  for _,side in {-1,1} do
   part(pit,"SawKerf",V(0.16,6.6,0.22),CF(x+V(side*22.94,-4.2,along)),C.deep,Enum.Material.Ice)
   part(pit,"SawKerf",V(0.22,6.6,0.16),CF(x+V(along,-4.2,side*22.94)),C.deep,Enum.Material.Ice)
  end
 end
 -- Rim: a snow lip, spoil piles from the cut, and stacked blocks that were
 -- lifted out. Evidence, not decoration - this is where the ice went.
 for _,side in {-1,1} do
  part(pit,"RimLip",V(7,2.4,60),CF(x+V(side*29,0.4,0)),C.snow,Enum.Material.Snow)
  part(pit,"RimLip",V(60,2.4,7),CF(x+V(0,0.4,side*29)),C.snow,Enum.Material.Snow)
  snowRidge(pit,CF(x+V(side*40,0.6,10))*A(0,math.pi/2,0),13,2.6,26)
 end
 for i=1,9 do
  part(pit,"CutIceBlock",V(4.4,2.6,4.4),CF(x+V(-36+((i-1)%3)*5,2+math.floor((i-1)/3)*2.7,20+((i-1)%3)*1.2))*A(0,rng:NextNumber(-0.2,0.2),0),C.ice,Enum.Material.Ice)
 end

 -- THE EXPOSED STRUCTURE. Flat, dark, ribbed and unmistakably manufactured,
 -- with ice still frozen onto its edges where the cut stopped.
 local roof=Kit.model("BuriedAccessStructure",pit)
 env.accessStructure=roof
 --[[
  FOUR SLABS AROUND A REAL HOLE, never one slab with a hatch drawn on it.

  As a solid 26-stud plate the roof contained the hatch throat, so the shot
  that looks down the shaft had its focal point inside the floor - and every
  frame of that descent was quietly relocated by the camera's own unstick
  fallback. A hatch has to be an absence.
 ]]
 local HATCH_HALF=5.6
 for _,side in {-1,1} do
  part(roof,"CompositeRoof",V(13-HATCH_HALF,2,26),CF(x+V(side*(13+HATCH_HALF)/2,ROOF_Y,0)),C.facComposite,Enum.Material.Slate)
  part(roof,"CompositeRoof",V(HATCH_HALF*2,2,13-HATCH_HALF),CF(x+V(0,ROOF_Y,side*(13+HATCH_HALF)/2)),C.facComposite,Enum.Material.Slate)
 end
 -- Two pieces per rib, one either side of the hatch. A single 25-stud rib
 -- runs straight across the opening, which is both wrong (a hatch has a
 -- frame, not a beam through it) and opaque to the shot that looks down into
 -- the shaft.
 for i=1,7 do
  for _,side in {-1,1} do
   part(roof,"RoofRib",V(6.8,0.5,0.9),CF(x+V(side*9.4,ROOF_Y+1.2,-11+(i-1)*3.6)),C.facMetal)
  end
 end
 for _,side in {-1,1} do
  part(roof,"RoofEdgeArmour",V(1.6,1.3,26),CF(x+V(side*12.6,ROOF_Y+1,0)),C.facIvory)
  part(roof,"RoofEdgeArmour",V(26,1.3,1.6),CF(x+V(0,ROOF_Y+1,side*12.6)),C.facIvory)
  -- Ice still gripping the edges: the cut reached the roof and stopped.
  part(roof,"ClingingIce",V(5,3.4,26),CF(x+V(side*14.4,ROOF_Y+1.6,0))*A(0,0,side*0.2),C.ice,Enum.Material.Ice,"wedge",0.1)
 end
 -- Conduit running out of the structure and INTO the ice, which is the detail
 -- that says this continues past what has been dug out.
 for _,offset in {-7.5,7.5} do
  -- Default axis: the run is along world X, crossing the roof and vanishing
  -- into the ice wall at each end. Passing "z" ran it along Z instead, which
  -- put a conduit straight through the access hatch.
  cylinder(roof,"EmbeddedConduit",V(30,1.1,1.1),CF(x+V(0,ROOF_Y+1.5,offset)),C.bronzeDark)
  for i=1,5 do
   part(roof,"ConduitClamp",V(1.6,1.5,0.7),CF(x+V(-10+(i-1)*5,ROOF_Y+1.5,offset)),C.facMetal)
  end
 end
 -- One faint glyph band, still dead. The first ancient writing in the film,
 -- and it is almost buried in frost - a mark the audience will see again on
 -- the key, on the gate and on Aegis Zero's chest.
 env.roofGlyphs=Glyph.band(roof,Glyph.Phrases.SealAuthority,
  CF(x+V(0,ROOF_Y+1.1,9.5))*A(-math.pi/2,0,0),0.95,3,C.bronzeDark,{emissive=false})
 for i=1,14 do
  -- Pushed outside the hatch collar: frost drawn over the opening is frost
  -- floating in mid-air over a shaft.
  local side=i%2==0 and 1 or -1
  part(roof,"SurfaceFrost",V(rng:NextNumber(1.6,4.2),0.12,rng:NextNumber(1.6,4.2)),
   CF(x+V(side*rng:NextNumber(6.5,11.5),ROOF_Y+1.1,rng:NextNumber(-11,11))),C.frost,Enum.Material.Ice,nil,0.35)
 end

 -- THE ACCESS HATCH. A recessed collar, the cover lifted out and standing on
 -- edge beside it, and a black throat: the way in.
 local hatch=Kit.model("AccessHatch",roof)
 env.accessHatch=hatch
 for i=1,10 do
  local a=i/10*math.pi*2
  part(hatch,"HatchCollar",V(2.6,1.1,1.5),CF(x+V(math.sin(a)*4.4,ROOF_Y+1.5,math.cos(a)*4.4))*A(0,a,0),C.facMetal)
 end
 env.hatchThroat=part(hatch,"HatchThroat",V(7,0.4,7),CF(x+V(0,ROOF_Y+0.9,0)),Color3.fromRGB(6,7,9),Enum.Material.SmoothPlastic)
 part(hatch,"ShaftLining",V(8.4,10,0.5),CF(x+V(0,ROOF_Y-5,-4.2)),C.facMetal)
 part(hatch,"ShaftLining",V(8.4,10,0.5),CF(x+V(0,ROOF_Y-5,4.2)),C.facMetal)
 part(hatch,"LiftedHatchCover",V(7.4,0.8,7.4),CF(x+V(9.5,ROOF_Y+4.2,0))*A(0,0,math.rad(76)),C.facMetal,Enum.Material.DiamondPlate)
 env.hatchGlyph=Glyph.render(hatch,"Gate",CF(x+V(9.1,ROOF_Y+4.2,0))*A(0,-math.pi/2,0)*A(0,0,math.rad(-14)),0.9,C.bronzeDark,{emissive=false})
 -- The expedition's own way down it: a bolted ladder and a tripod hoist.
 for rung=1,11 do
  Kit.beam(hatch,"DescentLadderRung",x+V(-0.8,ROOF_Y-rung*0.9,3.6),x+V(0.8,ROOF_Y-rung*0.9,3.6),0.1,C.hiVis)
 end
 for _,side in {-1,1} do
  Kit.beam(hatch,"DescentLadderStile",x+V(side*0.9,ROOF_Y+2,3.6),x+V(side*0.9,ROOF_Y-10,3.6),0.12,C.hiVis)
 end
 local hoist=Kit.model("TripodHoist",roof)
 for i=0,2 do
  local a=i*2.1
  Kit.beam(hoist,"HoistLeg",x+V(math.sin(a)*5,ROOF_Y+1.2,math.cos(a)*5),x+V(0,ROOF_Y+9,0),0.28,C.hiVis)
 end
 part(hoist,"HoistHead",V(1.6,0.9,1.6),CF(x+V(0,ROOF_Y+9.3,0)),C.hullDark)
 Kit.beam(hoist,"HoistLine",x+V(0,ROOF_Y+9,0),x+V(0,ROOF_Y+3.6,0),0.09,C.dark)
 part(hoist,"HoistHook",V(0.5,0.9,0.5),CF(x+V(0,ROOF_Y+3.2,0)),C.metal)

 -- SCAFFOLD. Down the -X side, four landings and three stair flights, which
 -- is the object that makes the depth of the cut legible in a wide shot.
 local scaffold=Kit.model("ExcavationScaffold",pit)
 env.scaffold=scaffold
 local LANDINGS={-3.5,-10.5,-17.5,ROOF_Y+1.6}
 for index,y in LANDINGS do
  local inset=if index<=3 then BENCHES[index].inner-1.5 else 11
  part(scaffold,"ScaffoldLanding",V(7,0.3,9),CF(x+V(-inset+3,y,0)),C.metal,Enum.Material.DiamondPlate)
  for _,side in {-1,1} do
   Kit.beam(scaffold,"LandingRail",x+V(-inset+0.2,y+1.2,side*4.4),x+V(-inset+6.2,y+1.2,side*4.4),0.11,C.hiVis)
  end
  if index<#LANDINGS then
   local nextY=LANDINGS[index+1]
   local nextInset=if index+1<=3 then BENCHES[index+1].inner-1.5 else 11
   local flight=(index%2==0) and 1 or -1
   local a=x+V(-inset+3,y,flight*4.2)
   local b=x+V(-nextInset+3,nextY,flight*4.2)
   Kit.beam(scaffold,"StairStringer",a,b,0.5,C.metal)
   local steps=math.max(4,math.floor((y-nextY)/1.1))
   for s=1,steps do
    local t=s/(steps+1)
    part(scaffold,"StairTread",V(3.4,0.18,1),CF(a:Lerp(b,t)),C.metal,Enum.Material.DiamondPlate)
   end
   Kit.beam(scaffold,"StairRail",a+V(0,1.3,0),b+V(0,1.3,0),0.1,C.hiVis)
  end
  Kit.beam(scaffold,"ScaffoldUpright",x+V(-inset+0.4,y,4.6),x+V(-inset+0.4,y+2.6,4.6),0.2,C.metal)
 end

 -- Work lighting: three masts on the rim aimed down into the cut, two
 -- portables on the structure itself. All warm, all obviously brought here -
 -- the contrast with the facility's own cold fixtures starts on this shot.
 for _,spec in {{at=V(-26,9,-16),look=V(-6,-22,-4)},{at=V(26,9,-16),look=V(6,-22,-4)},{at=V(0,9,27),look=V(0,-22,4)}} do
  local base=x+V(spec.at.X,0.8,spec.at.Z)
  Kit.beam(pit,"RimLampMast",base,base+V(0,spec.at.Y,0),0.3,C.metal)
  part(pit,"RimLampHead",V(1.8,0.8,1.1),CFrame.lookAt(x+spec.at,x+spec.look),C.hullDark)
  local lens=part(pit,"RimLampLens",V(1.5,0.6,0.12),CFrame.lookAt(x+spec.at,x+spec.look)*CF(0,0,-0.6),C.warm,Enum.Material.Neon,nil,0.2)
  lens.CastShadow=false
  local beam=Instance.new("SpotLight")
  beam.Face=Enum.NormalId.Front;beam.Angle=58;beam.Range=52;beam.Brightness=1.8;beam.Color=C.warm
  beam.Parent=lens
  cable(pit,base+V(0,0.6,0),x+V(spec.at.X*0.6,1,spec.at.Z*1.2),1.2)
 end
 for _,at in {V(-8,0,8),V(8,0,-9)} do
  local mast=Kit.model("PortableWorkLamp",pit)
  for i=0,2 do
   part(mast,"TripodLeg",V(0.22,4.2,0.22),CF(x+at+V(math.sin(i*2.1)*0.85,ROOF_Y+3.1,math.cos(i*2.1)*0.85))*A(math.cos(i*2.1)*0.2,0,-math.sin(i*2.1)*0.2),C.metal)
  end
  local lens=part(mast,"LampLens",V(1.5,0.85,0.12),CF(x+at+V(0,ROOF_Y+5.4,-0.55)),C.warm,Enum.Material.Neon,nil,0.28)
  lens.CastShadow=false
  local beam=Instance.new("SpotLight")
  beam.Face=Enum.NormalId.Front;beam.Angle=92;beam.Range=24;beam.Brightness=1.1;beam.Color=Color3.fromRGB(255,226,186)
  beam.Parent=lens
  part(mast,"LampBody",V(1.9,1.1,0.9),CF(x+at+V(0,ROOF_Y+5.4,0)),C.metal,Enum.Material.DiamondPlate)
 end

 -- The expedition's power and survey kit on the structure: the cable that
 -- later reaches Aegis Zero's chest physically starts here.
 local station=Kit.model("ShaftHeadStation",pit)
 part(station,"GeneratorSkid",V(6,3.2,4),CF(x+V(-9,ROOF_Y+3.6,-8)),C.hull)
 part(station,"GeneratorRoof",V(6.4,0.3,4.4),CF(x+V(-9,ROOF_Y+5.3,-8)),C.hullDark)
 Kit.label(part(station,"StationPlate",V(3.4,0.7,0.1),CF(x+V(-9,ROOF_Y+4.4,-5.95))*A(0,math.pi,0),C.hullDark),"SHAFT HEAD / POWER",C.hiVis)
 cylinder(station,"CableDrum",V(2.2,3,3),CF(x+V(-9,ROOF_Y+3.5,-3.4)),C.dark)
 cable(station,x+V(-9,ROOF_Y+3.4,-2),x+V(0,ROOF_Y+1.4,2.6),0.6)
 crate(station,CF(x+V(6,ROOF_Y+3.2,7)),V(2.8,2.4,2.8))
 crate(station,CF(x+V(9,ROOF_Y+3,9)),V(2.2,2,2.2))
 part(station,"FieldTable",V(4,0.2,2.2),CF(x+V(6.5,ROOF_Y+4.2,4)),C.metal,Enum.Material.DiamondPlate)
 for _,side in {-1,1} do
  part(station,"TableLeg",V(0.2,2.8,0.2),CF(x+V(6.5+side*1.7,ROOF_Y+2.7,4)),C.metal)
 end
 -- A tarp shelter over the rim station, so the top of the cut is not empty.
 part(pit,"RimShelterRoof",V(9,0.2,7),CF(x+V(-24,4.6,12))*A(0.1,0,0),C.hiVis,Enum.Material.Fabric)
 for _,corner in {V(-28,0,9),V(-20,0,9),V(-28,0,15),V(-20,0,15)} do
  Kit.beam(pit,"ShelterPost",x+corner+V(0,1,0),x+corner+V(0,4.6,0),0.14,C.metal)
 end
 -- Falling spindrift down the cut: the Arctic is still happening above them.
 local drift=part(pit,"CutSpindrift",V(40,2,40),CF(x+V(0,-2,0)),C.snow,nil,nil,1)
 local mist=Kit.dust(drift,22,C.snow,3)
 mist.Acceleration=V(1,-7,0)
 mist.Size=NumberSequence.new(0.3)
 table.insert(env.weather,mist)
end

local function interiors(env,rng)
 commandRoom(env,rng)
 -- Its own seeded stream, deliberately: sharing `rng` would shift every draw
 -- downstream of it (the chamber reliefs, the prison army's jitter) simply by
 -- existing, and this file's layout determinism is worth more than one
 -- shared Random.
 excavation(env,Kit.rng(20260921))
 local d=Env.Zones.Door
 --------------------------------------------------------------------------------
 -- THE ABANDONED FACILITY
 --
 -- What used to stand here was a colonnade: fluted marble pillars, ivory
 -- jambs, gold ribs and sixteen warm lamps. That is a temple, and a temple
 -- tells the audience the wrong thing twice over - that somebody built this
 -- to be admired, and that whatever is at the end of it is holy rather than
 -- contained.
 --
 -- This is a WORKING INSTALLATION that stopped working. It is read in that
 -- order on purpose: first the infrastructure (bulkheads, trenches, racks,
 -- conduit), then, underneath it, the fact that the infrastructure is not
 -- human. Dark worn metal and black composite carry the volume; oxidised
 -- bronze is reserved for mechanisms; the ivory that Aegis Zero is armoured
 -- in survives only as small plates on the structural edges.
 --
 -- ABANDONMENT IS TOLD WITH EVIDENCE, NOT DAMAGE. Breaking everything reads
 -- as a ruin. One chair pushed back from a dead console, one tool left on a
 -- work surface, one cabinet standing open, one maintenance panel taken off
 -- and leaned against its rack, one door jammed halfway, and one emergency
 -- fixture still alight after all this time - that reads as a place people
 -- left in a hurry and never came back to.
 --
 -- The camera walks it in five rooms, so the inner gate is genuinely DEEP
 -- inside rather than visible from the way in:
 --
 --   z  46..28   entry shaft, where the expedition broke through the ceiling
 --   z  28..16   airlock, its inner door stopped halfway
 --   z  16..0    maintenance corridor, conduit trench down the middle
 --   z   0..-16  operations bay, the dead workstations
 --   z -16..-36  gate hall, and the containment gate itself
 --------------------------------------------------------------------------------
 local fac=Kit.folder("AbandonedFacility",env.folder)
 env.facility=fac
 local function fpart(name,size,cf,color,material,shape,transparency)
  return part(fac,name,size,cf,color,material,shape,transparency)
 end
 -- Ancient fixtures are COLD and weak; anything warm in here was carried in
 -- by the expedition. Keeping the two apart is how the audience reads, shot
 -- by shot, how much of this room is theirs.
 local function ancientFixture(at,brightness,range)
  fpart("EmergencyFixture",V(1.4,0.5,0.5),CF(at),C.facMetal)
  local lens=fpart("FixtureLens",V(1.1,0.28,0.12),CF(at)*CF(0,-0.2,0),C.ancientEmergency,Enum.Material.Neon,nil,0.25)
  lens.CastShadow=false
  Kit.light(lens,C.ancientEmergency,range or 16,brightness or 0.55)
  return lens
 end
 local function expeditionLamp(at,look)
  local mast=Kit.model("PortableWorkLamp",fac)
  for i=0,2 do
   fpart("TripodLeg",V(0.2,4,0.2),CF(at+V(math.sin(i*2.1)*0.8,2,math.cos(i*2.1)*0.8))*A(math.cos(i*2.1)*0.2,0,-math.sin(i*2.1)*0.2),C.metal).Parent=mast
  end
  local head=CFrame.lookAt(at+V(0,4.6,0),look)
  local lens=fpart("LampLens",V(1.5,0.85,0.12),head*CF(0,0,-0.5),C.warm,Enum.Material.Neon,nil,0.28)
  lens.CastShadow=false;lens.Parent=mast
  local beam=Instance.new("SpotLight")
  beam.Face=Enum.NormalId.Front;beam.Angle=88;beam.Range=30;beam.Brightness=1.25;beam.Color=Color3.fromRGB(255,228,192)
  beam.Parent=lens
  fpart("LampBody",V(1.9,1.1,0.9),head,C.metal,Enum.Material.DiamondPlate).Parent=mast
  return mast
 end

 -- SHELL ---------------------------------------------------------------------
 -- Floor, ceiling and walls in three widths, so the space narrows and widens
 -- as it goes and never reads as one endless tube.
 local SEGMENTS={
  {from=28,to=46,halfWidth=12,ceiling=13},
  {from=16,to=28,halfWidth=10,ceiling=11},
  {from=0,to=16,halfWidth=11,ceiling=12},
  -- Tall on purpose: the gate stands 25 studs to the top of its drive drums,
  -- and the only place a lens can be far enough back to hold all of it is in
  -- this room. Against a 14-stud ceiling that camera was above the roof.
  {from=-16,to=0,halfWidth=17,ceiling=19},
  {from=-40,to=-16,halfWidth=17,ceiling=26},
 }
 for index,seg in SEGMENTS do
  local depth=seg.to-seg.from
  local midZ=(seg.from+seg.to)/2
  fpart("DeckPlate",V(seg.halfWidth*2,1,depth),CF(d+V(0,-0.5,midZ)),C.facSlate,Enum.Material.Slate)
  fpart("CeilingPlate",V(seg.halfWidth*2,0.8,depth),CF(d+V(0,seg.ceiling+0.4,midZ)),C.facComposite)
  for _,side in {-1,1} do
   fpart("BulkheadWall",V(1,seg.ceiling,depth),CF(d+V(side*(seg.halfWidth+0.5),seg.ceiling/2,midZ)),C.facMetal)
   -- Structural ribs at a regular pitch: rhythm, and something for a hand
   -- lamp to break across so the wall is never one dead value.
   for z=seg.from+2,seg.to-1,4 do
    fpart("WallRib",V(0.55,seg.ceiling-1,0.6),CF(d+V(side*(seg.halfWidth-0.2),seg.ceiling/2,z)),C.facPanel)
    fpart("RibArmourPlate",V(0.3,1.1,0.7),CF(d+V(side*(seg.halfWidth-0.35),seg.ceiling-2.2,z)),C.facIvory)
   end
   -- A low service channel along the base of both walls, capped with bronze.
   fpart("BaseChannel",V(0.7,1.2,depth),CF(d+V(side*(seg.halfWidth-0.4),0.6,midZ)),C.facComposite)
   cylinder(fac,"BaseConduit",V(depth-0.5,0.5,0.5),CF(d+V(side*(seg.halfWidth-0.4),1.4,midZ)),C.bronzeDark,"z")
  end
  -- Ceiling coffers, with two panels deliberately missing in the corridor.
  for z=seg.from+2,seg.to-2,3.5 do
   local dropped=index==3 and (z>7 and z<11)
   if not dropped then
    fpart("CeilingCoffer",V(seg.halfWidth*1.7,0.4,2.4),CF(d+V(0,seg.ceiling-0.2,z)),C.facPanel)
   end
  end
 end
 -- End caps. Without them the corridor is open at both ends, and a camera
 -- looking along its axis sees straight out of the set into nothing.
 fpart("EndBulkhead",V(26,14,1.2),CF(d+V(0,7,46.4)),C.facMetal)
 fpart("EndBulkheadArmour",V(20,1,1.5),CF(d+V(0,13.4,46.2)),C.facIvory)
 fpart("GateHallRear",V(38,27,1.2),CF(d+V(0,13.5,-40.4)),C.facComposite)
 --[[
  Doorway frames between sections: the reason the five rooms read as rooms
  rather than as one tube.

  Built as a JAMB-JAMB-LINTEL ring, never as one slab with a hole drawn on
  it. A solid slab across the opening is opaque to the obstruction ray, so
  every shot that looks down the corridor through a doorway - which is most
  of the facility's coverage - reports blocked and gets relocated by
  Camera.applyShot. The aperture has to be genuinely empty.
 ]]
 for _,gap in {{z=28,half=10,height=11},{z=16,half=9,height=10},{z=0,half=10,height=11},{z=-16,half=13,height=17}} do
  local outer=math.max(gap.half+5,12)
  for _,side in {-1,1} do
   fpart("SectionJamb",V(outer-gap.half,gap.height+3,1.6),CF(d+V(side*(gap.half+(outer-gap.half)/2),(gap.height+3)/2,gap.z)),C.facMetal)
   fpart("FrameArmour",V(0.8,gap.height,1.9),CF(d+V(side*gap.half,gap.height/2,gap.z)),C.facIvory)
  end
  fpart("SectionLintel",V(outer*2,3.4,1.6),CF(d+V(0,gap.height+1.7,gap.z)),C.facMetal)
  fpart("FrameLintelArmour",V(gap.half*2,0.9,1.9),CF(d+V(0,gap.height,gap.z)),C.facIvory)
  fpart("FrameSill",V(gap.half*2,0.3,1.9),CF(d+V(0,0.15,gap.z)),C.bronzeDark)
 end

 -- 1. ENTRY SHAFT -------------------------------------------------------------
 -- Where the expedition came through. The ceiling is broken open, there is a
 -- cone of ice and shattered panel on the floor beneath it, and the light
 -- from above is the only daylight in the whole facility.
 local entry=Kit.model("EntryShaft",fac)
 fpart("ShaftBreach",V(9,1.6,9),CF(d+V(0,13.2,38)),Color3.fromRGB(150,176,196),Enum.Material.Ice,nil,0.45).Parent=entry
 for i=1,10 do
  local a=i/10*math.pi*2
  fpart("BreachEdge",V(2.6,1.4,1.2),CF(d+V(math.sin(a)*5,13.1,38+math.cos(a)*5))*A(0,a,0.2),C.facMetal).Parent=entry
 end
 local shaftLight=Instance.new("SpotLight")
 shaftLight.Face=Enum.NormalId.Bottom;shaftLight.Angle=52;shaftLight.Range=30;shaftLight.Brightness=1.5
 shaftLight.Color=Color3.fromRGB(206,224,236)
 shaftLight.Parent=fpart("ShaftDaylight",V(6,0.2,6),CF(d+V(0,12.6,38)),Color3.fromRGB(206,224,236),Enum.Material.Neon,nil,0.6)
 for i=1,16 do
  fpart("FallenIce",V(rng:NextNumber(1,3.4),rng:NextNumber(0.6,2),rng:NextNumber(1,3.4)),
   CF(d+V(rng:NextNumber(-5.5,5.5),rng:NextNumber(0.3,2),38+rng:NextNumber(-5.5,5.5)))*A(rng:NextNumber(-0.4,0.4),rng:NextNumber(0,3),0),
   C.ice,Enum.Material.Ice).Parent=entry
 end
 for i=1,4 do
  fpart("ShatteredPanel",V(3,0.3,2.4),CF(d+V(-4+i*2.4,0.4,34+i*0.7))*A(0,rng:NextNumber(0,3),rng:NextNumber(-0.3,0.3)),C.facComposite).Parent=entry
 end
 -- The expedition's descent ladder and its first two lamps.
 for rung=1,14 do
  Kit.beam(entry,"DescentLadderRung",d+V(-0.8,rung*0.92,41.5),d+V(0.8,rung*0.92,41.5),0.1,C.hiVis)
 end
 for _,side in {-1,1} do
  Kit.beam(entry,"DescentLadderStile",d+V(side*0.9,0,41.5),d+V(side*0.9,13.4,41.5),0.13,C.hiVis)
 end
 expeditionLamp(d+V(-6.5,0,33),d+V(0,4,26))
 expeditionLamp(d+V(6.5,0,40),d+V(0,4,36))
 cable(fac,d+V(0,12.8,41),d+V(-8,0.6,30),1.4)
 crate(fac,CF(d+V(8,1.4,34)),V(2.8,2.4,2.8))

 -- 2. AIRLOCK / DECONTAMINATION ----------------------------------------------
 -- The jammed door is the single most useful object in the facility: it says
 -- the building tried to close itself and could not finish.
 local lock=Kit.model("Airlock",fac)
 env.jammedDoor=fpart("JammedBulkheadDoor",V(11,9.4,0.7),CF(d+V(-4.4,5,27.4)),C.facMetal,Enum.Material.DiamondPlate)
 env.jammedDoor.Parent=lock
 for i=1,4 do
  fpart("DoorRib",V(10.4,0.5,0.9),CF(d+V(-4.4,2+i*2,27.2)),C.facPanel).Parent=lock
 end
 fpart("DoorRunner",V(20,0.7,1.2),CF(d+V(0,10.2,27.4)),C.bronzeDark).Parent=lock
 fpart("DoorSeizedActuator",V(1.4,1.4,1.6),CF(d+V(1.6,10.2,27.4)),C.bronze).Parent=lock
 for i=1,3 do
  -- Decontamination emitter rings, dark. They still look like they would work.
  for n=1,12 do
   local a=n/12*math.pi*2
   fpart("EmitterSegment",V(1.1,0.5,0.55),CF(d+V(math.sin(a)*8.6,5.5+math.cos(a)*5.5,18+i*3))*A(0,math.pi/2,a),C.bronzeDark).Parent=lock
  end
 end
 fpart("FloorGrate",V(16,0.2,9),CF(d+V(0,0.12,22)),C.facMetal,Enum.Material.DiamondPlate).Parent=lock
 for i=1,9 do
  fpart("GrateSlot",V(15,0.1,0.35),CF(d+V(0,0.24,18.5+i*0.8)),Color3.fromRGB(8,10,12)).Parent=lock
 end
 -- A dead control niche beside the inner door, and the band of glyphs that
 -- labels it. This is the audience's second look at the script.
 fpart("ControlNiche",V(3.4,4,1.2),CF(d+V(8.4,4.4,24)),C.facComposite).Parent=lock
 fpart("NichePanel",V(2.8,2.2,0.2),CF(d+V(8,4.8,23.4))*A(0,math.rad(-90),0),Color3.fromRGB(10,12,14),Enum.Material.Glass).Parent=lock
 env.airlockGlyphs=Glyph.band(lock,{"Gate","Bind","Life"},CF(d+V(8.1,2.6,24))*A(0,math.rad(-90),0),0.42,1.3,C.bronzeDark,{emissive=false})
 ancientFixture(d+V(-8.6,9.4,21),0.5,14)
 -- Frost creeping in from the breached end.
 for i=1,10 do
  fpart("CreepingFrost",V(rng:NextNumber(1.6,4),rng:NextNumber(1,3),0.16),
   CF(d+V(rng:NextNumber(-9,9),rng:NextNumber(1,7),27.9))*A(0,0,rng:NextNumber(-0.5,0.5)),C.frost,Enum.Material.Ice,nil,0.45).Parent=lock
 end

 -- 3. MAINTENANCE CORRIDOR ----------------------------------------------------
 local corridor=Kit.model("MaintenanceCorridor",fac)
 -- The conduit trench: the corridor's spine, and the reason the floor is
 -- interesting to look along. One grating panel has been taken up and set
 -- against the wall - evidence, not damage.
 fpart("ConduitTrench",V(4.4,1.2,16),CF(d+V(0,0.1,8)),Color3.fromRGB(8,9,11)).Parent=corridor
 for _,offset in {-1.1,1.1} do
  cylinder(corridor,"TrenchConduit",V(15.6,0.8,0.8),CF(d+V(offset,0.5,8)),C.bronzeDark,"z")
 end
 for i=1,7 do
  local z=1.2+(i-1)*2.2
  if i~=4 then
   fpart("TrenchGrating",V(4.4,0.16,2),CF(d+V(0,0.72,z)),C.facMetal,Enum.Material.DiamondPlate).Parent=corridor
  end
 end
 fpart("LiftedGratingPanel",V(4.4,0.16,2),CF(d+V(-8.4,1.1,7.6))*A(0,0,math.rad(74)),C.facMetal,Enum.Material.DiamondPlate).Parent=corridor
 -- Cable bundles overhead, one of them collapsed onto the deck.
 for _,side in {-1,1} do
  cable(corridor,d+V(side*7,11.4,0.5),d+V(side*7,11.4,15.5),0.9)
 end
 cable(corridor,d+V(-4,11.2,4),d+V(-6.5,1,10),3.2)
 fpart("CollapsedBundle",V(2.6,0.9,4.4),CF(d+V(-7,0.6,11))*A(0,0.3,0),C.dark).Parent=corridor
 fpart("PulledCeilingPanel",V(4,0.3,2.6),CF(d+V(6.4,0.55,9.4))*A(0,0.4,math.rad(12)),C.facPanel).Parent=corridor
 -- The exposed structure above the two missing coffers.
 for z=7.5,10.5,1.5 do
  fpart("ExposedCeilingTruss",V(18,0.5,0.5),CF(d+V(0,11.4,z)),C.facMetal).Parent=corridor
 end
 -- A scorch, around a junction box that clearly failed.
 fpart("JunctionBox",V(2,2.4,0.9),CF(d+V(10.2,5,13)),C.facComposite).Parent=corridor
 fpart("ScorchMark",V(0.14,5,4.4),CF(d+V(10.4,6,13)),Color3.fromRGB(16,14,13),Enum.Material.Slate).Parent=corridor
 fpart("BurstPanelDoor",V(0.2,2,1.6),CF(d+V(10.3,4.4,11.6))*A(0,0,math.rad(20)),C.facMetal).Parent=corridor
 -- The wall band: the SAME four marks that are on the structure's roof, on
 -- the key, and on the gate. Third sighting, still unexplained.
 env.corridorGlyphs=Glyph.band(corridor,Glyph.Phrases.SealAuthority,CF(d+V(-10.6,5.4,8))*A(0,math.rad(90),0),0.55,2.2,C.bronzeDark,{emissive=false})
 ancientFixture(d+V(9.4,10,4),0.5,15)
 -- THE one fixture in the building that still works, and it is the wrong
 -- colour to be anything the expedition brought.
 env.survivingFixture=ancientFixture(d+V(-9.4,9.6,12),1.1,22)
 for i=1,12 do
  fpart("WallFrost",V(0.16,rng:NextNumber(1.4,3.6),rng:NextNumber(1.6,4)),
   CF(d+V((i%2==0 and 1 or -1)*10.4,rng:NextNumber(1.5,8),rng:NextNumber(1,15))),C.frost,Enum.Material.Ice,nil,0.5).Parent=corridor
 end
 expeditionLamp(d+V(7.5,0,3),d+V(0,4,-4))

 -- 4. OPERATIONS BAY ----------------------------------------------------------
 local ops=Kit.model("OperationsBay",fac)
 env.opsBay=ops
 for _,side in {-1,1} do
  for _,z in {-4,-11} do
   local cf=CF(d+V(side*14,0,z))*A(0,side*math.pi/2,0)
   fpart("StationDesk",V(6,0.3,2.6),cf*CF(0,3,0),C.facMetal,Enum.Material.DiamondPlate).Parent=ops
   fpart("StationBody",V(5.6,2.9,2.2),cf*CF(0,1.5,0.15),C.facComposite).Parent=ops
   local screen=fpart("DeadScreen",V(3.4,2,0.16),cf*CF(0,4.6,-0.7)*A(math.rad(-10),0,0),Color3.fromRGB(12,14,16),Enum.Material.Glass)
   screen.Parent=ops
   -- The one the dead-workstation insert is framed on. Naming a real part as
   -- that shot's subject (rather than a point in the air in front of it) is
   -- what lets the camera's obstruction test exclude the bay it is standing
   -- in, instead of reporting the console's own surround as an obstruction.
   if side<0 and z==-4 then env.deadScreen=screen end
   fpart("ScreenSurround",V(3.9,2.5,0.12),cf*CF(0,4.6,-0.82)*A(math.rad(-10),0,0),C.bronzeDark).Parent=ops
   -- A frost bloom growing over the panel: the room has been this cold for a
   -- very long time.
   fpart("PanelFrost",V(2.4,1.4,0.06),cf*CF(-0.5,4.3,-0.62)*A(math.rad(-10),0,0),C.frost,Enum.Material.Ice,nil,0.55).Parent=ops
   fpart("StationConsoleLip",V(4.6,0.3,0.9),cf*CF(0,3.2,1),C.bronzeDark).Parent=ops
  end
 end
 -- A chair, pushed back and turned away from the console it belongs to.
 local chairAt=CF(d+V(-9.6,0,-6.6))*A(0,math.rad(38),0)
 fpart("ChairSeat",V(1.9,0.26,1.8),chairAt*CF(0,1.6,0),C.facComposite).Parent=ops
 fpart("ChairBack",V(1.9,1.8,0.24),chairAt*CF(0,2.5,0.78)*A(math.rad(10),0,0),C.facComposite).Parent=ops
 cylinder(ops,"ChairColumn",V(1.5,0.24,0.24),chairAt*CF(0,0.8,0),C.facMetal,"y")
 fpart("ChairBase",V(1.5,0.16,1.5),chairAt*CF(0,0.1,0),C.facMetal).Parent=ops
 -- A tool left on a work surface, exactly where somebody put it down.
 fpart("AbandonedTool",V(0.4,0.3,2.2),CF(d+V(13.4,3.25,-4.6))*A(0,math.rad(14),0),C.bronze).Parent=ops
 fpart("ToolHead",V(0.75,0.5,0.75),CF(d+V(13.4,3.3,-5.6)),C.bronzeDark).Parent=ops
 -- A sealed cabinet, standing open.
 fpart("EquipmentCabinet",V(3,6,2),CF(d+V(-15.4,3,4.4)),C.facComposite).Parent=ops
 fpart("CabinetDoor",V(0.2,5.6,1.9),CF(d+V(-13.8,3,3.3))*A(0,math.rad(-58),0),C.facMetal).Parent=ops
 for i=1,4 do
  fpart("CabinetShelf",V(2.7,0.14,1.7),CF(d+V(-15.4,0.9+i*1.2,4.4)),C.facMetal).Parent=ops
 end
 fpart("CabinetContents",V(1.4,0.9,1.2),CF(d+V(-15.4,3.6,4.4)),C.bronzeDark).Parent=ops
 -- Equipment racks, one with its maintenance panel off and leaning on it.
 for _,side in {-1,1} do
  local rack=Kit.model("EquipmentRack",ops)
  fpart("RackFrame",V(4,7,2),CF(d+V(side*15,3.5,-14)),C.facComposite).Parent=rack
  for n=1,7 do
   fpart("RackUnit",V(3.5,0.66,0.3),CF(d+V(side*15,0.9+n*0.85,-13.1)),C.facMetal).Parent=rack
  end
 end
 fpart("RemovedMaintenancePanel",V(0.2,6.2,3.4),CF(d+V(-12.8,3.1,-13))*A(0,0,math.rad(9)),C.facMetal).Parent=ops
 -- An observation window into darkness. What is behind it is never explained,
 -- which is exactly why it works.
 fpart("ObservationFrame",V(13,6.4,0.9),CF(d+V(0,6.4,-15.6)),C.facMetal).Parent=ops
 fpart("ObservationGlass",V(11.6,5,0.3),CF(d+V(0,6.4,-15.7)),Color3.fromRGB(24,34,40),Enum.Material.Glass,nil,0.2).Parent=ops
 fpart("ObservationVoid",V(11.6,5,1.4),CF(d+V(0,6.4,-16.4)),Color3.fromRGB(3,4,5),Enum.Material.SmoothPlastic).Parent=ops
 for i=1,3 do
  fpart("WindowMullion",V(0.34,5,0.4),CF(d+V(-4+(i-1)*4,6.4,-15.6)),C.bronzeDark).Parent=ops
 end
 -- A collapsed ceiling section in the far corner, with what came down.
 fpart("CollapsedCeiling",V(7,0.6,6),CF(d+V(12.4,1.2,-12.6))*A(math.rad(18),0,math.rad(-24)),C.facComposite).Parent=ops
 for i=1,6 do
  fpart("CeilingDebris",V(rng:NextNumber(0.8,2.4),rng:NextNumber(0.4,1.2),rng:NextNumber(0.8,2.4)),
   CF(d+V(9+rng:NextNumber(-2,4),rng:NextNumber(0.3,1.4),-10+rng:NextNumber(-3,3)))*A(0,rng:NextNumber(0,3),0),C.facPanel).Parent=ops
 end
 for z=-13.5,-9.5,2 do
  fpart("HangingConduit",V(0.5,4.2,0.5),CF(d+V(12,10,z))*A(math.rad(20),0,math.rad(-14)),C.bronzeDark).Parent=ops
 end
 ancientFixture(d+V(0,18,-8),0.45,20)
 expeditionLamp(d+V(-10,0,-9),d+V(0,4,-14))
 expeditionLamp(d+V(9.5,0,1.5),d+V(0,4,-6))

 -- 5. THE GATE HALL AND THE INNER GATE ----------------------------------------
 --[[
  Not a pair of fantasy doors. A containment bulkhead: two sliding leaves,
  two deep piers they retract INTO, eight lock dogs along the leaf/pier
  interface, two drive drums over the head, and one lock housing set into the
  right-hand pier at chest height.
 
  The pier geometry is load-bearing rather than decorative. A sliding leaf
  that ends the shot standing proud of its own frame reads as a prop that has
  been slid sideways; a leaf that disappears behind a pier reads as a door
  that has retracted. So each pier is WIDER than the leaf it swallows (9.4
  against 8.2) and sits 1.6 studs in front of it, and the travel is exactly
  the leaf's own width.
 
  It is DEAD at build - no Neon anywhere, no light, every glyph at setLit(0) -
  which is what lets the unlock read as something being switched on rather
  than something merely being noticed.
 ]]
 local hall=Kit.model("GateHall",fac)
 local LEAF_W,LEAF_H=8.2,21
 local LEAF_Z,PIER_Z,FACE_Z=-37,-35.4,-34
 fpart("ApproachApron",V(34,0.4,20),CF(d+V(0,0.2,-26)),C.facComposite,Enum.Material.Slate).Parent=hall
 fpart("HallThresholdStep",V(30,0.45,2.4),CF(d+V(0,0.22,-17.4)),C.facSlate,Enum.Material.Slate).Parent=hall
 for _,side in {-1,1} do
  -- At z=-24 the left buttress stood directly between the hall and the key
  -- alcove, so the discovery shot was looking into the recess THROUGH it.
  fpart("HallButtress",V(2.6,24,3.4),CF(d+V(side*14.5,12,-21)),C.facMetal).Parent=hall
  fpart("ButtressArmour",V(1.2,22,1.2),CF(d+V(side*13.3,11,-21)),C.facIvory).Parent=hall
  ancientFixture(d+V(side*13,15,-19),0.4,18)
 end
 -- The void behind the leaves. Whatever light the hall has must not reach
 -- into it, or the chamber beyond is visible through the seam before the gate
 -- has opened.
 fpart("GateVoid",V(18,LEAF_H,4),CF(d+V(0,LEAF_H/2,LEAF_Z-3)),Color3.fromRGB(3,4,5),Enum.Material.SmoothPlastic).Parent=hall
 -- Leaves.
 env.gateLeaves={}
 for _,side in {-1,1} do
  local leaf=Kit.model(side<0 and "GateLeafLeft" or "GateLeafRight",hall)
  local body=fpart("LeafBody",V(LEAF_W,LEAF_H,1.8),CF(d+V(side*LEAF_W/2,LEAF_H/2,LEAF_Z)),C.facPanel)
  body.Parent=leaf
  leaf.PrimaryPart=body
  for i=1,5 do
   fpart("LeafSegment",V(LEAF_W-0.5,3.3,0.5),CF(d+V(side*LEAF_W/2,2.2+(i-1)*4.3,LEAF_Z+1.1)),C.facMetal).Parent=leaf
   fpart("LeafSeam",V(LEAF_W-0.3,0.26,0.7),CF(d+V(side*LEAF_W/2,4.2+(i-1)*4.3,LEAF_Z+1.15)),C.facComposite).Parent=leaf
  end
  fpart("LeafEdgeArmour",V(0.8,LEAF_H,1.9),CF(d+V(side*0.4,LEAF_H/2,LEAF_Z)),C.facIvory).Parent=leaf
  -- Three marks per leaf, standing in a column. A band's own axis is +X, so
  -- it is rotated a quarter turn about its normal to run vertically.
  local column=Glyph.band(leaf,side<0 and {"Guardian","Bind","Below"} or {"Warning","Bind","Gate"},
   CF(d+V(side*LEAF_W/2,LEAF_H/2,LEAF_Z+1.4))*A(0,0,math.pi/2),0.85,6,C.bronzeDark)
  table.insert(env.gateLeaves,{model=leaf,place=Kit.rigid(leaf,CF(d)),base=CF(d),side=side,glyphs=column})
 end
 -- Piers and head beam. The leaf travels LEAF_W and the pier is wider, so a
 -- fully open leaf is completely behind structure.
 for _,side in {-1,1} do
  fpart("GatePier",V(9.4,25,2.6),CF(d+V(side*12.7,12.5,PIER_Z)),C.facMetal).Parent=hall
  fpart("PierArmour",V(1.3,23,1.3),CF(d+V(side*8.6,11.5,FACE_Z+0.1)),C.facIvory).Parent=hall
  fpart("PierBase",V(10,2.2,3.4),CF(d+V(side*12.7,1.1,PIER_Z)),C.facComposite).Parent=hall
 end
 fpart("GateHeadBeam",V(35,3.4,2.6),CF(d+V(0,22.5,PIER_Z)),C.facMetal).Parent=hall
 fpart("HeadArmour",V(18,0.9,1.4),CF(d+V(0,20.9,FACE_Z+0.1)),C.facIvory).Parent=hall
 fpart("GateThreshold",V(35,0.8,3.4),CF(d+V(0,0.5,PIER_Z)),C.bronzeDark,Enum.Material.Slate).Parent=hall
 -- Lock dogs at the leaf/pier interface, four a side, plus two over the head.
 -- They withdraw INBOARD, into the leaf they belong to, which is the only
 -- direction a sliding door's dogs can go.
 env.gateLocks={}
 for _,side in {-1,1} do
  for i=1,4 do
   local y=3+(i-1)*5.4
   local dog=fpart("LockDog",V(3.6,1.7,2.4),CF(d+V(side*(LEAF_W-0.4),y,LEAF_Z+1.5)),C.bronze)
   dog.Parent=hall
   table.insert(env.gateLocks,{part=dog,base=dog.CFrame,direction=V(-side,0,0)})
   fpart("LockRecess",V(4,2.3,0.6),CF(d+V(side*(LEAF_W+0.9),y,PIER_Z+1.2)),Color3.fromRGB(6,7,9)).Parent=hall
  end
  local head=fpart("HeadLockDog",V(2.4,3.4,2.4),CF(d+V(side*4,LEAF_H+0.3,LEAF_Z+1.5)),C.bronze)
  head.Parent=hall
  table.insert(env.gateLocks,{part=head,base=head.CFrame,direction=V(0,-1,0)})
 end
 -- Drive drums over the head: something visibly turns before the leaves move,
 -- so the opening has a cause on screen rather than simply happening.
 env.gateDrums={}
 for _,side in {-1,1} do
  local drum=Kit.model("GateDriveDrum",hall)
  local axle=d+V(side*6,24.2,LEAF_Z+0.6)
  cylinder(drum,"DrumBarrel",V(4,5,5),CF(axle),C.bronzeDark)
  for i=1,6 do
   local a=i/6*math.pi*2
   part(drum,"DrumRib",V(4.1,5.2,0.5),CF(axle)*A(a,0,0),C.bronze)
  end
  cylinder(drum,"DrumHub",V(4.4,1.7,1.7),CF(axle),C.facMetal)
  Kit.beam(drum,"DrumChain",axle+V(side*2.3,-0.4,0),d+V(side*(LEAF_W/2),LEAF_H-0.4,LEAF_Z+1.2),0.22,C.bronzeDark)
  table.insert(env.gateDrums,{model=drum,place=Kit.rigid(drum,CF(axle)),base=CF(axle)})
 end
 -- THE LOCK HOUSING, set into the right-hand pier at chest height. Keeping
 -- the socket OFF the seam is what lets the circuit stay whole while the
 -- leaves part, and it puts the key where a person can actually reach it.
 local housingCF=CF(d+V(10.6,5.6,FACE_Z+1.2))
 env.gateSocketCF=housingCF
 fpart("LockHousing",V(5,6.4,1.6),housingCF,C.facComposite).Parent=hall
 fpart("HousingBezel",V(4.2,5.6,0.3),housingCF*CF(0,0,0.85),C.bronzeDark).Parent=hall
 for i=1,10 do
  local a=i/10*math.pi*2
  fpart("SocketJaw",V(0.55,1.1,0.5),housingCF*CF(math.sin(a)*1.75,math.cos(a)*1.75,0.92)*A(0,0,-a),C.bronze).Parent=hall
 end
 env.gateSocket=fpart("GateSocket",V(3.1,3.1,0.5),housingCF*CF(0,0,0.76),Color3.fromRGB(7,8,10),Enum.Material.SmoothPlastic,"ball")
 env.gateSocket.Parent=hall
 env.gateSocketCore=fpart("SocketCore",V(0.9,0.9,0.3),housingCF*CF(0,0,0.96),C.bronzeDark)
 env.gateSocketCore.Parent=hall
 env.gateSocketRing=Glyph.ring(hall,Glyph.Phrases.SealAuthority,housingCF*CF(0,0,1),2.35,0.42,C.bronzeDark)
 --[[
  THE CIRCUIT. Recessed channel segments running from the housing, up the
  right pier, across the head and down the left pier, built IN PATH ORDER -
  which is the only reason Env.setGateUnlock can light them one after another
  and have the charge visibly travel rather than simply appear.
 ]]
 env.gateChannel={}
 local function channelRun(from,to,count)
  for i=1,count do
   local a=from:Lerp(to,(i-1)/count)
   local b=from:Lerp(to,i/count)
   local seg=fpart("LockChannelSegment",V(0.75,(b-a).Magnitude+0.1,0.5),CFrame.lookAt((a+b)/2,b)*A(math.rad(90),0,0),C.bronzeDark)
   seg.Parent=hall
   table.insert(env.gateChannel,seg)
  end
 end
 channelRun(d+V(10.6,8.2,FACE_Z+1.1),d+V(10.6,21.4,FACE_Z+1.1),6)
 channelRun(d+V(10.6,21.4,FACE_Z+1.1),d+V(-10.6,21.4,FACE_Z+1.1),10)
 channelRun(d+V(-10.6,21.4,FACE_Z+1.1),d+V(-10.6,8.2,FACE_Z+1.1),6)
 for _,seg in env.gateChannel do
  fpart("ChannelRecess",V(1.15,seg.Size.Y,0.3),seg.CFrame*CF(0,0,-0.35),Color3.fromRGB(6,7,9)).Parent=hall
 end
 -- THE SEAL KEY AND ITS PEDESTAL ----------------------------------------------
 -- Not a medieval key. An open resonance ring on an asymmetric spine, with a
 -- small core inside it and the same four marks engraved along its flank -
 -- so the object itself is a copy of the glyph called "Key", which is how the
 -- audience is told what it is without anybody saying so.
 --
 -- It is found IN ITS CRADLE, in a recess beside the mechanism it belongs to,
 -- never lying loose on the floor: the pedestal is what makes it obvious that
 -- the thing and the door are one design.
 local pedestalAt=d+V(-15.4,0,-27)
 env.keyPedestalAt=pedestalAt
 local ped=Kit.model("KeyPedestal",hall)
 env.keyPedestal=ped
 -- The alcove. Its armour is a SURROUND - lintel, sill and two reveals around
 -- the mouth - not a plate across it: the discovery shot looks into this
 -- recess from the hall, and a closed face would simply block it.
 -- The recess is a VOID: a back panel and four liners, not a filled block.
 -- Built as one box it contained the plinth and the key, so the discovery
 -- shot was looking at an object inside a solid.
 fpart("RecessBack",V(0.6,9,8),CF(pedestalAt+V(-3.1,4.5,0)),Color3.fromRGB(5,6,7)).Parent=ped
 fpart("RecessCeiling",V(3.2,0.6,8),CF(pedestalAt+V(-1.6,8.8,0)),Color3.fromRGB(5,6,7)).Parent=ped
 fpart("RecessFloor",V(3.2,0.6,8),CF(pedestalAt+V(-1.6,0.3,0)),Color3.fromRGB(5,6,7)).Parent=ped
 for _,side in {-1,1} do
  fpart("RecessSide",V(3.2,9,0.6),CF(pedestalAt+V(-1.6,4.5,side*3.7)),Color3.fromRGB(5,6,7)).Parent=ped
 end
 fpart("RecessLintel",V(0.8,0.9,8.6),CF(pedestalAt+V(-0.1,9.1,0)),C.facIvory).Parent=ped
 fpart("RecessSill",V(0.8,0.6,8.6),CF(pedestalAt+V(-0.1,0.3,0)),C.facIvory).Parent=ped
 for _,side in {-1,1} do
  fpart("RecessReveal",V(0.8,9,0.9),CF(pedestalAt+V(-0.1,4.5,side*4)),C.facIvory).Parent=ped
 end
 fpart("PedestalPlinth",V(2.6,3.9,3.4),CF(pedestalAt+V(-1.1,1.95,0)),C.facComposite).Parent=ped
 fpart("PlinthCap",V(3.1,0.5,3.9),CF(pedestalAt+V(-1.1,4.05,0)),C.facMetal).Parent=ped
 -- The cradle: a ring-shaped depression with a raised rim and a slot for the
 -- spine. The key's own outline, cut into the stone.
 local cradleTop=pedestalAt+V(-1.1,4.3,0)
 for i=1,16 do
  local a=i/16*math.pi*2
  fpart("CradleRim",V(0.42,0.2,0.28),CF(cradleTop+V(math.sin(a)*1.22,0,math.cos(a)*1.22))*A(0,a,0),C.bronze).Parent=ped
 end
 fpart("CradleWell",V(2.5,0.22,2.5),CF(cradleTop+V(0,-0.12,0)),Color3.fromRGB(6,7,9),Enum.Material.SmoothPlastic,"ball").Parent=ped
 fpart("CradleSpineSlot",V(0.55,0.2,3.1),CF(cradleTop+V(0,-0.08,0))*A(0,math.rad(18),0),Color3.fromRGB(6,7,9)).Parent=ped
 env.keyPedestalGlyphs=Glyph.band(ped,Glyph.Phrases.SealAuthority,CF(pedestalAt+V(0.35,2.3,0))*A(0,math.rad(90),0),0.34,1.1,C.bronzeDark,{emissive=false})
 -- Frost over the cradle, cleared in the discovery shot.
 env.keyFrost=fpart("CradleFrost",V(3.2,0.34,3.6),CF(cradleTop+V(0,0.18,0)),C.frost,Enum.Material.Ice,nil,0.25)
 env.keyFrost.Parent=ped

 local key=Kit.model("SealKey",hall)
 env.sealKey=key
 -- Built about the origin, in a frame where the ring lies in XY and +Z is the
 -- face normal, so it can be placed flat in the cradle and upright in the
 -- socket from the same geometry.
 --[[
  THREE MASSES AND NOTHING ELSE: a slender open ring, one spine through it,
  one core inside it.

  The first version was twenty chunky blocks at two materials, and rendered
  at the distance the discovery shot actually uses it read as a pile of
  rubble - no ring, no spine, no object. The fixes are all subtraction: the
  ring segments are a third as thick and there are more of them, the whole
  ring is ONE material so the silhouette closes, the ivory is cut back to two
  small accents that mark the gap, and the core cage is gone.
 ]]
 local KEY_R=1.05
 for i=1,15 do
  -- 300 degrees of ring, and a deliberate 60-degree gap: an OPEN ring, which
  -- is the shape of a thing that fits INTO something else.
  local a=math.rad(-150)+(i-1)/14*math.rad(300)
  part(key,"RingSegment",V(0.15,0.26,0.19),CF(math.sin(a)*KEY_R,math.cos(a)*KEY_R,0)*A(0,0,-a),C.bronze)
 end
 for _,a in {math.rad(-150),math.rad(150)} do
  part(key,"RingGapTerminal",V(0.26,0.26,0.3),CF(math.sin(a)*KEY_R,math.cos(a)*KEY_R,0),C.facIvory)
 end
 -- Offset from centre and longer at one end, so the key reads "this way up,
 -- this end first" from any angle.
 part(key,"KeySpine",V(0.22,3,0.17),CF(0.16,-0.28,0)*A(0,0,math.rad(-9)),C.bronzeDark)
 part(key,"SpineTip",V(0.17,0.62,0.14),CF(0.34,-1.78,0)*A(0,0,math.rad(-9)),C.facIvory)
 part(key,"SpineCollar",V(0.44,0.2,0.28),CF(0.22,-0.92,0),C.bronze)
 env.keyCore=part(key,"KeyCore",V(0.38,0.38,0.38),CF(0.12,0.1,0),C.bronzeDark,Enum.Material.SmoothPlastic,"ball")
 -- Three marks along the spine flank, not four around the body: at forearm
 -- scale a fourth is smaller than a stroke is wide.
 env.keyGlyphs=Glyph.band(key,{"Key","Gate","Bind"},CF(0.16,-0.1,0.14)*A(0,0,math.rad(-9)),0.21,0.62,C.bronzeDark,{thickness=0.16})
 for _,p in key:GetDescendants() do
  if p:IsA("BasePart") then p.CanQuery=false end
 end
 -- Three placements, one rigid transform. Flat in its cradle; raised and
 -- turned in Lyra's hands as she lines it up; seated in the socket.
 env.keyPlace=Kit.rigid(key,CFrame.new())
 env.keyCradleCF=CF(cradleTop+V(0,0.35,0))*A(-math.pi/2,0,math.rad(18))
 env.keyAlignCF=housingCF*CF(-0.4,-0.6,3.6)*A(0,math.rad(28),math.rad(-14))
 env.keySeatedCF=housingCF*CF(0,0,1.05)
 env.keyPlace(env.keyCradleCF)
 expeditionLamp(d+V(-9,0,-23),d+V(-15,4,-27))
 expeditionLamp(d+V(7,0,-28),d+V(0,9,-35))
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
 -- Grouped into one model so 13a can declare it: that shot looks straight
 -- down at the iris opening, so the iris is in front of its own focal point
 -- by construction and would otherwise read as an obstruction.
 env.sealIris=Kit.model("SealIris",chamber)
 env.sealLeaves={}
 for i=1,12 do
  local a=i/12*math.pi*2
  local p=part(env.sealIris,"SealLeaf",V(7.5,0.65,15),CF(ch+V(math.sin(a)*7,0.5,math.cos(a)*7))*A(0,a,0),C.bronze)
  table.insert(env.sealLeaves,{part=p,base=p.CFrame,direction=V(math.sin(a),0,math.cos(a))})
 end
 --[[
  THE LOWER SEAL, CONCEALED.

  This was a 28-stud violet Neon disc sitting in the middle of the chamber
  floor from the moment the set was built - which meant the first frame of
  the first chamber shot showed the audience that there is another level,
  that it is lit in the colour the film reserves for the enemy, and that the
  machine is standing on it. That is the entire twist, given away before
  anybody has walked into the room.

  It is now built INVISIBLE and unlit, and only Env.setLowerSealReveal opens
  it. Everything violet in the film is behind that one function: this disc,
  the prison cavern's own practicals and the frozen army's sensors.
 ]]
 --[[
  LIGHT LEAKING UP AROUND THE RIM, not a disc across the opening.

  This used to be a single 28-stud violet plate sitting a stud below the
  floor. Rendered from above - which is exactly how both reveal shots are
  framed - it was an opaque purple lid filling the frame, so "the shaft
  continues impossibly far" read as "there is a flat violet surface just
  under the floor". The depth the whole twist depends on was invisible.

  Now: sixteen thin arcs at the opening's own edge, so what the audience sees
  first is light coming up THROUGH the gap, and the middle of the opening
  stays empty for the shaft below it to be seen down.
 ]]
 env.sealRim={}
 for i=1,16 do
  local a=i/16*math.pi*2
  local arc=part(chamber,"SealRimGlow",V(5.4,0.4,0.7),CF(ch+V(math.sin(a)*13.6,-0.5,math.cos(a)*13.6))*A(0,a,0),C.violet,Enum.Material.Neon,nil,1)
  arc.CanQuery=false
  table.insert(env.sealRim,arc)
 end
 env.lowerSealLights={}
 env.lowerSealEmissive={}
 --[[
  THE SHAFT UNDER THE IRIS.

  Seven rings of containment structure descending under the seal, each one
  smaller and further apart than the last, so when the iris finally opens the
  shot looking down has something to measure depth against and the drop reads
  as impossibly far rather than as a hole in a floor.

  This is ordinary dark structure - bronze and composite, no violet, no
  emission - and it is invisible for the whole film anyway, because the iris
  is closed over it. Only the glow at the bottom is gated by
  setLowerSealReveal.
 ]]
 env.sealShaft=Kit.model("ContainmentShaft",chamber)
 for level=1,7 do
  local y=-7-level*level*3.1
  local radius=12.5-level*1.05
  for i=1,8 do
   local a=i/8*math.pi*2
   part(env.sealShaft,"ShaftRingSegment",V(radius*0.85,1.6,2.2),CF(ch+V(math.sin(a)*radius,y,math.cos(a)*radius))*A(0,a,0),level%2==0 and C.bronzeDark or C.facComposite)
  end
  for i=1,4 do
   local a=i/4*math.pi*2+0.4
   part(env.sealShaft,"ShaftStrut",V(0.7,3.1*(2*level+1),0.7),CF(ch+V(math.sin(a)*radius,y+1.55*(2*level+1)/2,math.cos(a)*radius)),C.facMetal)
  end
 end
 --[[
  Light at three depths, so the drop can be MEASURED by eye: a faint band
  behind the fourth ring, a stronger one behind the sixth, and the floor of
  it a long way under both. One glow at the bottom alone reads as a dot;
  three, at receding scales, read as distance.
 ]]
 for _,spec in {{y=-56,size=12},{y=-106,size=16},{y=-166,size=26}} do
  local glow=cylinder(chamber,"ShaftDepthGlow",V(0.4,spec.size,spec.size),CF(ch+V(0,spec.y,0)),C.violet,"y")
  glow.Material=Enum.Material.Neon
  glow.Transparency=1
  glow.CanQuery=false
  table.insert(env.lowerSealEmissive,glow)
 end
 -- The containment floor itself: a ring of the SAME marks, set into the deck
 -- around the iris, dead. When the strain begins they are what changes state
 -- first, which is how the floor tells Lyra what she is standing on.
 env.sealFloorGlyphs=Glyph.ring(chamber,Glyph.Phrases.ChamberWarning,CF(ch+V(0,1.05,0))*A(-math.pi/2,0,0),13,1.6,C.bronzeDark)
 for i=1,16 do
  local a=i/16*math.pi*2
  part(chamber,"SealRaceSegment",V(4.4,0.5,1.6),CF(ch+V(math.sin(a)*17.5,0.85,math.cos(a)*17.5))*A(0,a,0),C.bronzeDark)
 end
 for _,x in {-34,34} do
  -- Reduced from brightness 3 - close enough to the human dialogue blocking
  -- on the chamber floor (see stage() in Sequences.lua) to overexpose them.
  lamp(chamber,CF(ch+V(x,28,8)),C.cyan,60,1.8)
  lamp(chamber,CF(ch+V(x,35,-32)),C.warm,60,1.8)
 end
 --[[
  THE WARNING BAND.

  The old panels carved the answer in gold: a guardian, chains, and a VIOLET
  clawed creature underneath it, four times over. A viewer who looks at that
  wall for two seconds already knows there is a monster below and that the
  machine is holding it - so Lyra's translation had nothing left to reveal,
  and the seal failure had nothing left to be a twist about.

  What survives is writing and two damaged figures: the five marks of the
  chamber phrase, standing in a band, with two badly-eroded relief panels
  beside them. Lyra can read three of the five, which is exactly the amount
  of understanding the story needs her to have - enough to be frightened,
  not enough to explain.
 ]]
 env.mythWall=part(chamber,"GuardianInscription",V(24,11,0.6),CF(ch+V(-38,6.5,26)),C.facMetal,Enum.Material.Slate)
 -- A SURROUND, never a slab across the face. Both translation shots look at
 -- this wall from the room, and a full-size panel a third of a stud in front
 -- of it is opaque to the obstruction ray: the camera reported blocked and
 -- was relocated on every take.
 for _,side in {-1,1} do
  part(chamber,"InscriptionFrame",V(1,13,0.5),CF(ch+V(-38+side*12.5,6.5,26.25)),C.facComposite)
  part(chamber,"InscriptionArmour",V(0.7,12,0.6),CF(ch+V(-38+side*11.8,6.5,26.35)),C.facIvory)
 end
 part(chamber,"InscriptionFrame",V(26,1.2,0.5),CF(ch+V(-38,12.6,26.25)),C.facComposite)
 part(chamber,"InscriptionFrame",V(26,1.2,0.5),CF(ch+V(-38,0.4,26.25)),C.facComposite)
 env.warningBand=Glyph.band(chamber,Glyph.Phrases.ChamberWarning,env.mythWall.CFrame*CF(0,1.4,0.36),1.5,4.5,C.bronzeDark,
  -- Cleaned, never energised: see GlyphLanguage's `emissive` note. Lyra
  -- brushing frost out of a channel is what makes a mark readable here.
  {emissive=false,lit=Color3.fromRGB(196,162,104)})
 -- Two eroded figures, kept deliberately unreadable: a standing shape and,
 -- beneath it, a shape that is only a mass. Nothing here is violet, nothing
 -- has a claw, and both panels are half lost under frost.
 env.reliefs={}
 for i=1,2 do
  local cf=env.mythWall.CFrame*CF((i-1.5)*9.4,-3.1,0.36)
  local panel=part(chamber,"ErodedRelief",V(7,4,0.12),cf,C.facSlate)
  Kit.beam(chamber,"CarvedStandingFigure",(cf*CF(0,1.2,0.1)).Position,(cf*CF(0,-0.6,0.1)).Position,0.28,C.bronzeDark)
  for _,side in {-1,1} do
   Kit.beam(chamber,"CarvedHoldingArm",(cf*CF(0,0.8,0.1)).Position,(cf*CF(side*1.2,-0.5,0.1)).Position,0.16,C.bronzeDark)
  end
  part(chamber,"CarvedMassBelow",V(3.4,0.7,0.12),cf*CF(0,-1.5,0.1),C.facComposite)
  part(chamber,"ReliefFrost",V(4.4,2.6,0.1),cf*CF(i==1 and 1.4 or -1.2,-0.4,0.14),C.frost,Enum.Material.Ice,nil,0.4)
  table.insert(env.reliefs,panel)
 end
 --[[
  THE EXPEDITION'S OWN KIT IN THE CHAMBER. A power console cabled to the
  machine, and a portable survey monitor on a tripod - the same instrument
  family as the bore console (see Instrumentation.lua), because the signal
  spike has to be reported on a HUMAN screen, in human units, for "Aegis was
  never the source" to be a measurement rather than an assertion.
 ]]
 env.activationConsole=part(chamber,"PowerConsole",V(4.4,2.9,2.2),CF(ch+V(9,1.45,24)),C.hullDark)
 part(chamber,"PowerConsoleDeck",V(4.6,0.26,2.4),CF(ch+V(9,2.95,24)),C.metal,Enum.Material.DiamondPlate)
 env.powerReadout=part(chamber,"PowerReadout",V(3,1.6,0.12),env.activationConsole.CFrame*CF(0,1.1,1.2)*A(0,math.pi,0)*A(math.rad(18),0,0),Color3.fromRGB(11,13,16))
 Kit.label(env.powerReadout,"EXTERNAL POWER\nSTANDBY",C.cyan)
 for i=1,4 do
  part(chamber,"PowerBreaker",V(0.5,0.3,0.5),CF(ch+V(7.6+(i-1)*0.9,3.1,24.6)),C.hiVis)
 end
 cable(chamber,ch+V(9,0.4,24),ch+V(3,0.4,7),0.2)
 local tripod=Kit.model("FieldSurveyTripod",chamber)
 local monitorAt=ch+V(14.5,0,21)
 for i=0,2 do
  part(tripod,"TripodLeg",V(0.2,4.4,0.2),CF(monitorAt+V(math.sin(i*2.1)*0.85,2.2,math.cos(i*2.1)*0.85))*A(math.cos(i*2.1)*0.2,0,-math.sin(i*2.1)*0.2),C.metal)
 end
 part(tripod,"MonitorBody",V(3.2,2.4,0.7),CF(monitorAt+V(0,5.4,0))*A(0,math.rad(-140),0),C.hullDark)
 env.fieldScreen=part(tripod,"FieldScreen",V(2.8,2,0.12),CF(monitorAt+V(0,5.4,0))*A(0,math.rad(-140),0)*CF(0,0,-0.42),Color3.fromRGB(11,13,16))
 env.fieldDisplay=Instrumentation.fieldMonitor(env.fieldScreen,Enum.NormalId.Front)
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
  THE CONTAINMENT LEDGE.

  Built as an expedition observation platform, back when Lyra, Voss and a
  soldier walked down here and looked at the Sovereign BEFORE anybody touched
  Aegis Zero. Nobody comes down here any more: under the new order the lower
  prison is never entered, only exposed, and the camera reaches it by looking
  DOWN through a floor that has just failed.

  So the shelf stays - it is the cavern's own structure, and the wide shot
  needs a foreground edge to read depth against - but the expedition's kit is
  gone: two portable work lamps, two cases and a survey tripod that would
  otherwise be standing in a chamber no human has ever set foot in, lit warm,
  three shots before the audience is told the place exists. The rail and lip
  are re-materialled to the facility's own bronze and composite, so they read
  as part of the building rather than as somewhere people set up.
 ]]
 -- One solid shelf from the cavern floor up to Y=0: the top surface is the
 -- gallery, and the face below it is the drop.
 part(prison,"ContainmentLedge",V(70,26,30),CF(pr+V(-6,-13,-45)),C.ice,Enum.Material.Ice)
 part(prison,"LedgeDeck",V(70,0.4,30),CF(pr+V(-6,-0.2,-45)),C.facComposite,Enum.Material.Slate)
 part(prison,"LedgeLip",V(70,1.2,1.6),CF(pr+V(-6,-0.6,-30.4)),C.bronzeDark,Enum.Material.Slate)
 for x=-38,24,6.2 do
  part(prison,"BalustradePost",V(0.3,3.4,0.3),CF(pr+V(x,1.7,-30.8)),C.bronzeDark)
 end
 part(prison,"BalustradeTop",V(64,0.22,0.22),CF(pr+V(-7,3.3,-30.8)),C.bronzeDark)
 part(prison,"BalustradeMid",V(64,0.18,0.18),CF(pr+V(-7,2,-30.8)),C.bronzeDark)
 part(prison,"GalleryMouth",V(14,13,3),CF(pr+V(-9,6.5,-59)),C.dark,Enum.Material.Rock)
 for _,side in {-1,1} do
  part(prison,"GalleryJamb",V(1.6,13,3.4),CF(pr+V(-9+side*7.8,6.5,-59)),C.facIvory,Enum.Material.Rock)
 end
 for i=1,36 do
  local a=i/36*math.pi*2
  local pos=pr+V(math.sin(a)*138,20,math.cos(a)*115)
  part(prison,"StratifiedIceWall",V(28,110,25),CF(pos)*A(0,a,0.15),C.ice,Enum.Material.Ice,"wedge")
  Kit.beam(prison,"BlackRoot",pos-V(0,45,0),pos+V(math.sin(i)*18,35,-10),1.6,C.dark)
 end
 --[[
  EVERY VIOLET SOURCE IN THE FILM STARTS AT ZERO.

  These used to burn at brightness 1.6 from the moment the set was built. It
  did not matter while the expedition walked down here in the middle of the
  film; it matters completely now, because the prison must not exist for the
  audience until the containment floor fails. Each light keeps its intended
  value on a TargetBrightness attribute and is handed to
  Env.setLowerSealReveal, which is the only thing that can turn it up.

  The single cold cyan fill stays lit: it is the light the cavern's own
  structure is read by in the wide shot, it is not the enemy's colour, and
  without it the reveal is a black screen with two glowing dots.
 ]]
 for _,x in {-45,45} do
  local practical=lamp(prison,CF(pr+V(x,25,-22)),C.violet,60,0)
  local light=practical:FindFirstChildOfClass("PointLight")
  if light then
   light:SetAttribute("TargetBrightness",1.6)
   table.insert(env.lowerSealLights,light)
  end
  practical.Transparency=1
  table.insert(env.lowerSealEmissive,practical)
 end
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
   -- Built fully transparent, and stays that way until 13i lights the army.
   local eye=part(prison,"DormantSensor",V(0.24,0.15,0.12),CF(pos+V(side*0.4,1.4,-1.1)),C.violet,Enum.Material.Neon,nil,1)
   eye.CanQuery=false
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
-- THE BORE, IN MOTION
--------------------------------------------------------------------------------

-- `revolutions` is cumulative, so the reel's rotation is driven by how much
-- hose has actually gone out rather than by a shot's 0..1 parameter - the same
-- rule the truck wheels follow, and for the same reason: a reel whose speed
-- disagrees with the depth readout beside it reads as decoration.
function Env.setReelRotation(env,revolutions: number)
 if env.reelSpin then env.reelSpin(env.reelAxle*A(revolutions*math.pi*2,0,0)) end
end

-- How much of the drilling montage has elapsed, 0..1. Drives the snow that
-- banks up on the plant, which is the passage of time the audience can see
-- without reading a number off a screen.
function Env.setBoreWeathering(env,amount: number)
 local a=math.clamp(amount or 0,0,1)
 for _,cap in env.boreSnowCaps do
  cap.part.Size=V(cap.size.X,math.max(0.05,cap.size.Y*a),cap.size.Z)
  cap.part.Transparency=1-a
 end
end

function Env.setBoreSteam(env,rate: number)
 if env.boreSteam then env.boreSteam.Rate=math.max(0,rate) end
 if env.plantSteam then env.plantSteam.Rate=math.max(0,rate*0.35+4) end
end

--------------------------------------------------------------------------------
-- THE INNER GATE
--
-- A staged mechanical unlock, not a door that lights up. Every window below
-- overlaps the next slightly, so no stage ever completes before the one it
-- causes has begun, and the whole thing reads as one machine doing one job:
--
--   0.06 - 0.24  the socket accepts the key: its ring lights, mark by mark
--   0.18 - 0.52  charge travels the channel, jamb -> head -> jamb, in order
--   0.46 - 0.62  the marks on the leaves answer the circuit
--   0.52 - 0.72  eight lock dogs withdraw into the structure
--   0.62 - 0.84  the drive drums turn
--   0.72 - 1.00  and only then do the leaves part
--
-- The light is never allowed to arrive somewhere before it has travelled
-- there: `setProgress` on a band lights one glyph at a time, and the channel
-- segments were built in path order for exactly this.
--------------------------------------------------------------------------------
local function window(a: number,from: number,to: number): number
 return math.clamp((a-from)/(to-from),0,1)
end

function Env.setGateUnlock(env,amount: number)
 local a=math.clamp(amount or 0,0,1)
 local lit=Glyph.Lit
 local dead=Glyph.Dead

 local socket=window(a,0.06,0.24)
 env.gateSocketRing.setProgress(socket*#env.gateSocketRing.glyphs)
 env.gateSocketCore.Color=dead:Lerp(lit,socket)
 env.gateSocketCore.Material=if socket>0.02 then Enum.Material.Neon else Enum.Material.Slate

 local travel=window(a,0.18,0.52)*#env.gateChannel
 for index,segment in env.gateChannel do
  local charge=math.clamp(travel-(index-1),0,1)
  segment.Color=dead:Lerp(lit,charge)
  segment.Material=if charge>0.02 then Enum.Material.Neon else Enum.Material.Slate
 end

 local answered=window(a,0.46,0.62)
 for _,leaf in env.gateLeaves do
  leaf.glyphs.setProgress(answered*#leaf.glyphs.glyphs)
 end

 -- Dogs withdraw along their own axis, into the structure they belong to.
 local withdraw=window(a,0.52,0.72)
 for _,dog in env.gateLocks do
  dog.part.CFrame=dog.base+dog.direction*withdraw*2.6
 end

 local turn=window(a,0.62,0.84)
 for index,drum in env.gateDrums do
  drum.place(drum.base*A((index==1 and 1 or -1)*turn*math.pi*1.6,0,0))
 end

 -- Named `separation`, not `part`: this file has a module-level part() builder
 -- and shadowing it inside a control function is asking for a confusing bug.
 local separation=window(a,0.72,1)
 for _,leaf in env.gateLeaves do
  leaf.place(leaf.base+V(leaf.side*separation*11.4,0,0))
 end
end

-- The key's own core, which answers BEFORE the gate does - that ordering is
-- the whole reason the unlock reads as the key causing it rather than the
-- door deciding to open.
function Env.setKeyCharge(env,amount: number)
 local a=math.clamp(amount or 0,0,1)
 env.keyCore.Color=Glyph.Dead:Lerp(Glyph.Lit,a)
 env.keyCore.Material=if a>0.02 then Enum.Material.Neon else Enum.Material.SmoothPlastic
 env.keyGlyphs.setProgress(a*#env.keyGlyphs.glyphs)
end

function Env.placeKey(env,cf: CFrame)
 env.keyPlace(cf)
end

--------------------------------------------------------------------------------
-- THE LOWER SEAL
--
-- The one gate on every violet pixel in the opening. Nothing else in the film
-- may turn any of this on, which is what guarantees the prison cannot leak
-- into a frame before the containment fails.
--------------------------------------------------------------------------------
function Env.setLowerSealReveal(env,amount: number)
 local a=math.clamp(amount or 0,0,1)
 for _,light in env.lowerSealLights do
  light.Brightness=((light:GetAttribute("TargetBrightness") :: number?) or 1)*a
 end
 for _,emissive in env.lowerSealEmissive do
  emissive.Transparency=1-a
 end
 -- The rim comes up first and hardest: it is the light escaping between the
 -- iris leaves, which is the only violet in the film until the camera is
 -- actually pointed down the shaft.
 for _,arc in env.sealRim do
  arc.Transparency=1-math.min(a*1.6,1)
 end
 -- The containment marks on the chamber floor change state with it: they are
 -- the last thing that was still holding, and they are read in the shot where
 -- Lyra looks down.
 if env.sealFloorGlyphs then
  env.sealFloorGlyphs.setLit(a)
 end
end
--------------------------------------------------------------------------------
-- Ground sampling and vehicle motion.
--
-- Every height in the Arctic set comes from a raycast against the set itself,
-- never from a constant: packed snow, apron and wind ridges have different
-- surface heights. This is the same mechanism Cast.lua grounds its people with.
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
--[[
 How fast the suspension settles, in "fraction of the way per second" terms
 (see VehicleMotion.expAlpha). 12 reproduces the feel the old fixed 0.18
 per-frame blend had at 60 fps - 1-(1-0.18)^60 is essentially the same
 curve - but now it is that same curve at any frame rate, instead of settling
 twice as fast on a 120 Hz display and half as fast on a 30 Hz one.
]]
local SUSPENSION_RESPONSE = 12

function Env.moveVehicle(v,from,to,t,deltaTime: number?)
 local dt=deltaTime or 0
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
 -- Rotation from distance covered, never from elapsed time. Unchanged, and
 -- deliberately so: this is the one relationship that makes the wheels agree
 -- with the ground under them, and it is already frame-rate independent
 -- because `travelled` is a distance, not a rate.
 v.spin+=travelled/WHEEL_R

 -- Speed drives the body's fore/aft weight transfer and the snow spray. Both
 -- are now per-SECOND quantities derived from the real step, so a 30 fps
 -- machine and a 144 fps machine show the same truck.
 local speed=VehicleMotion.speed(travelled,dt)
 local accel=VehicleMotion.acceleration(speed,v.speed or 0,dt)
 v.speed=speed
 Env.settleVehicle(v,pos,facing,VehicleMotion.expAlpha(SUSPENSION_RESPONSE,dt))
 -- Squat under acceleration, dive under braking: a small pitch on top of the
 -- terrain attitude, which is what gives the hull a sense of mass. The
 -- coefficient is now against studs/s^2 rather than a per-frame speed delta,
 -- hence the much smaller constant; the clamp keeps it restrained either way.
 v.pitch=math.clamp(v.pitch+math.clamp(accel*0.00007,-0.02,0.02),-MAX_PITCH*1.4,MAX_PITCH*1.4)

 if v.spray then v.spray.Rate=(t>0 and t<1) and math.clamp(speed*0.9,0,45) or 0 end
end
return Env
