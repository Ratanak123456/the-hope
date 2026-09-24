--!nonstrict
-- The existing opening's single explicit edit. Durations drive everything,
-- including subtitles: no asset loading or Sound.TimeLength dependencies.
local Config=require(game:GetService("ReplicatedStorage").Shared.Config)
local Env=require(script.Parent.Env)
local Cast=require(script.Parent.Cast)
local Kit=require(script.Parent.Kit)
local Camera=require(script.Parent.Camera)
local Light=require(script.Parent.Lighting)
local Glyph=require(script.Parent.GlyphLanguage)
local Instrumentation=require(script.Parent.Instrumentation)
local Performance=require(script.Parent.PerformanceDirector)
local Sequences={}
local N=Config.Cinematic.Names
local Z=Env.Zones
local CUT=Env.Cut
local V,CF,A=Vector3.new,CFrame.new,CFrame.Angles
export type UI=any
export type CastState=any
export type Shot=any
--[[
 BLOCKING. Every stage gives each speaking character a MARK (where they
 stand), a FACING (what they look at) and a JOB (what they are doing there),
 instead of three positions in a row with no reason behind them.

 In the command room specifically: Lyra is AT the signal table reading the
 return, Voss is across the corner of it with his tablet, and Hale stands back
 from the work facing both of them - which is what makes him read as the
 officer in the room rather than a third scientist. The camera positions below
 are built around those marks, so the audience can always answer "who is
 where" from any shot in the scene.

 Y values are hints only: Cast.place raycasts for the real floor (see
 Cast.floorUnder), so a character is never left hovering over, or sunk into,
 whatever surface is actually beneath their mark.
]]
local STAGING={
 -- Lyra takes the side of the island the master shot is on, so the lead of
 -- the scene is the face the audience reads first; Voss works the far corner
 -- and Hale stands back from both of them.
 Command={origin="Command",marks={
  {at=V(2.5,2.8,-0.3),look=V(0,4.2,-4.2),job="Scan"},
  {at=V(-2.8,2.95,0.7),look=V(0,4.2,-4.2),job="CheckingTablet"},
  {at=V(-0.4,3.1,5.4),look=V(-1,4,-1),job="Authority"},
 }},
 --[[
  The bore head. All three are on the operator's side of the console, which
  puts the screen between them and the tower - so any shot that holds a face
  also holds the machine they are arguing about.

  Their marks clear the console plinth (2.5 studs of local half-width), the
  canopy posts and the rig truck parked at x=15, all checked against the real
  build rather than eyeballed.
 ]]
 Bore={origin="BaseCenter",marks={
  {at=V(12.6,2.8,-12.6),look=V(-14,3,-22),job="Monitoring"},
  {at=V(9.2,2.95,-10.6),look=V(-14,3,-22),job="CheckingTablet"},
  {at=V(14.6,3.1,-8.4),look=V(6,3,-14),job="Authority"},
 }},
 -- At the rim of the cut, behind the barrier, while the gantry works: the
 -- three people who asked for this, watching it happen.
 ExcavationRim={origin="Excavation",marks={
  {at=V(2.5,2.8,23.6),look=V(0,-6,0),job="Monitoring"},
  {at=V(-1,2.95,24.6),look=V(0,-6,0),job="CheckingTablet"},
  {at=V(6.5,3.1,26),look=V(0,4,0),job="Authority"},
 }},
 -- On the exposed roof at the bottom of the finished cut (top at y=-12),
 -- clear of the hatch coaming, the hoist legs, the generator skid, the crates
 -- and the foot of the scaffold.
 Excavation={origin="Excavation",marks={
  {at=V(3,-9.2,-10.4),look=V(0,-10,11.5),job="Scan"},
  {at=V(0.2,-9.05,-10.2),look=V(0,-10,11.5),job="CheckingTablet"},
  {at=V(-2.8,-8.9,-10.8),look=V(-1,-10,0),job="Authority"},
 }},
 -- Inside the facility: first at the foot of the entry shaft, then in the
 -- operations bay, then before the gate. Three rooms, three blockings, which
 -- is what makes the walk in feel like distance travelled.
 LabEntry={origin="Door",marks={
  {at=V(-7,2.8,31),look=V(0,5,20),job="Scan"},
  {at=V(6,2.95,33),look=V(0,5,22),job="CheckingTablet"},
  {at=V(-8,3.1,36),look=V(-2,4,30),job="Authority"},
 }},
 Lab={origin="Door",marks={
  {at=V(-4,2.8,-6),look=V(-13,4.6,-4),job="Scan"},
  {at=V(-1,2.95,-2.5),look=V(-13,4.6,-4),job="CheckingTablet"},
  {at=V(4,3.1,-8),look=V(-5,4,-6),job="Authority"},
 }},
 GateHall={origin="Door",marks={
  {at=V(-4.5,3.2,-25),look=V(0,10,-36),job="Scan"},
  {at=V(-0.5,3.35,-22),look=V(0,10,-36),job="CheckingTablet"},
  {at=V(5,3.5,-21),look=V(0,10,-36),job="Authority"},
 }},
 -- Eyelines on the machine's chest: Aegis Zero kneels at the seal's rim,
 -- 36 studs back, not over the middle of it.
 Chamber={origin="ChamberFloor",marks={
  {at=V(-5,2.8,24),look=V(0,26,-30),job="Idle"},
  {at=V(-1,2.95,27),look=V(0,26,-30),job="Idle"},
  {at=V(5,3.1,25),look=V(0,26,-30),job="Authority"},
 }},
}

--[[
 The lab's supporting crew have fixed STATIONS, not scattered positions: four
 at the command room's own side consoles (two per wall, each facing their
 screen), the rest out on the site. A technician who is visibly at a console
 doing a job is what stops the room reading as "NPCs standing around waiting
 for subtitles".
]]
local LAB_STATIONS={V(-8.6,2.8,-4),V(-8.6,2.8,3),V(8.6,2.8,-4),V(8.6,2.8,3)}
-- Exported so tools/castcheck can assert, against the real built set, that
-- every authored mark actually has a floor under it - the check that would
-- have caught the whole command-room cast standing on the ceiling.
Sequences.Staging=STAGING
Sequences.LabStations=LAB_STATIONS
function Sequences.buildCast(env): CastState
 local o=Z.Command
 -- A fresh cinematic must not inherit the previous run's rig registry.
 Cast.reset()
 local c={scientists={},soldiers={},workers={},frozenWardens={},allHumans={}}
 -- Built on their command-room marks (see STAGING.Command) so the first time
 -- the audience sees them is already the blocking the scene uses.
 c.lyra=Cast.buildLyra(env.folder,CFrame.lookAt(o+V(2.5,2.8,-0.3),o+V(0,2.8,-4.2)))
 c.voss=Cast.buildVoss(env.folder,CFrame.lookAt(o+V(-2.8,2.95,0.7),o+V(0,2.95,-4.2)))
 c.hale=Cast.buildHale(env.folder,CFrame.lookAt(o+V(-0.4,3.1,5.4),o+V(-1,3.1,-1)))
 local rng=Kit.rng(20260915)
 for i=1,8 do
  local station=LAB_STATIONS[i]
  local p=station and Z.Command+station or Z.BaseCenter+V(-25+i*6,2.8,22+i*3)
  local facing=station and Z.Command+V(station.X*1.6,2.8,station.Z) or Z.BaseCenter+V(0,2.8,-28)
  table.insert(c.scientists,Cast.buildScientist(env.folder,CFrame.lookAt(p,facing),rng,i))
  --[[
   A cordon ACROSS the approach to the working area, facing it, rather than
   the old line at z = -13/-18 - which ran straight through where the bore
   plant now stands. Three of the console inserts put the lens within a stud
   of a soldier's torso, because the camera and the security detail were
   occupying the same patch of snow.
  ]]
  local post=Z.BaseCenter+V(-20+i*6,3,2-(i%2)*4)
  table.insert(c.soldiers,Cast.buildSoldier(env.folder,CFrame.lookAt(post,Z.BaseCenter+V(0,3,-28)),rng,i))
 end
 --[[
  The bore crew, one to each functional mass of the plant, so the machine
  reads as something being OPERATED rather than as scenery with people near
  it: the console, the reel, the heater skid, the collar and the power bank.
  Five positions, five different jobs, all checked clear of the equipment
  they stand at.
 ]]
 --[[
  One to each functional mass, and every mark checked against the real build
  rather than eyeballed: clear of the console canopy (which a placement ray
  reads as a ceiling), clear of the pump skid's raised deck, and clear of the
  fuel drums - all three of which the first draft put a worker inside.
 ]]
 local BORE_CREW={
  {at=V(6.2,2.8,-24.2),look=V(8.6,3.4,-21)},
  {at=V(-7.6,2.8,-20.6),look=V(-12.5,4.6,-23.5)},
  {at=V(-17.6,2.8,-29.4),look=V(-24.5,3.5,-31)},
  {at=V(3.2,2.8,-21.6),look=V(0,1,-28)},
  {at=V(-16.6,2.8,-14.2),look=V(-24.5,3.2,-18)},
 }
 for i=1,5 do
  local spot=BORE_CREW[i]
  table.insert(c.workers,Cast.buildWorker(env.folder,CFrame.lookAt(Z.BaseCenter+spot.at,Z.BaseCenter+V(spot.look.X,spot.at.Y,spot.look.Z)),i))
 end
 --[[
  AEGIS ZERO, kneeling at the rim of the seal and facing the room. The
  height is not authored: AegisCinematic solves the kneel and grounds the
  lowest contact on the chamber floor. The distance back IS authored, from
  the set: the planted forward foot has to clear both the iris (whose leaves
  slide fifteen studs outward in 13a) and the raised seal race ring at 17.5,
  and at 36 back its nearest corner is at radius 19. The chains run forward
  from the fists and are made fast to two of the iris leaves themselves, so
  when the seal opens it drags them taut before they break.
 ]]
 local function leafNearest(point)
  local best,bestDistance=nil,math.huge
  for _,leaf in env.sealLeaves do
   local d=(leaf.part.Position-point).Magnitude
   if d<bestDistance then best,bestDistance=leaf.part,d end
  end
  return best
 end
 local chainAnchors={Z.ChamberFloor+V(9.5,0.85,-6.5),Z.ChamberFloor+V(-9.5,0.85,-6.5)}
 c.aegis=Cast.buildAegisZero(env.folder,CF(Z.ChamberFloor+V(0,0,-36))*A(0,math.pi,0),10,{
  floorY=Z.ChamberFloor.Y,
  anchors=chainAnchors,
  anchorHosts={leafNearest(chainAnchors[1]),leafNearest(chainAnchors[2])},
 })
 --[[
  THE CHEST BAND.

  The same four marks that are engraved on the buried structure's roof, on
  the facility corridor, on the seal key, on its cradle and around the gate's
  lock housing - now on the machine itself. That repetition is the entire
  mechanism by which the audience works out, at the same moment Lyra does,
  that the door and the thing behind it are one system. Nobody has to say it.

  Fixed to the torso through Cast.fix rather than left standing in world
  space: setAegisRise pitches the waist about twenty degrees, which would
  leave the band hanging in the air where the chest used to be. It sits on
  the machine's own band plate across the top of the chest, above the core.
 ]]
 local band=c.aegis.chestBand
 c.aegisGlyphs=Glyph.band(c.aegis.model,Glyph.Phrases.SealAuthority,
  c.aegis.torso.CFrame*band.offset*A(0,math.pi,0),band.scale,band.spacing,Env.Colors.bronzeDark)
 for _,item in c.aegisGlyphs.model:GetDescendants() do
  if item:IsA("BasePart") then Cast.fix(c.aegis,c.aegis.torso,item) end
 end
 c.sovereign=Cast.buildSovereign(env.folder,CF(Z.PrisonCenter+V(0,21,5)),5.5)
 c.breakingWarden=Cast.buildWarden(env.folder,CF(Z.PrisonCenter+V(-24,0,-7)),0.85,true)
 for _,cf in env.prisonSpots do table.insert(c.frozenWardens,Cast.buildWarden(env.folder,cf,0.55,true)) end
 for _,h in {c.lyra,c.voss,c.hale} do table.insert(c.allHumans,h) end
 for _,group in {c.scientists,c.soldiers,c.workers} do for _,h in group do table.insert(c.allHumans,h) end end
 for i,h in c.scientists do
  h.home=h.root.CFrame
  Cast.setActivity(h,(i%3==0 and "TypingConsole" or i%3==1 and "CheckingTablet" or "Monitoring"))
  -- Lab technicians watch their own screen, not the middle of the room: a row
  -- of heads all turned the same way is the "chorus of NPCs" look.
  local station=LAB_STATIONS[i]
  Cast.lookAt(h,station and Z.Command+V(station.X*1.7,4,station.Z) or Z.BaseCenter+V(0,3,-28))
 end
 for i,h in c.workers do
  h.home=h.root.CFrame
  -- Each looks at the thing they are standing at, not all at one point: a row
  -- of heads turned the same way is the "chorus of NPCs" look. CarryCase and
  -- OperateDrill are deliberately left out of the rotation here - both lean
  -- the torso far enough to trip Cast's own upright validator (a known,
  -- separately-reported defect in those two poses), and the bore crew are the
  -- most-photographed background figures in the sequence.
  Cast.setActivity(h,(i%3==0 and "CheckCable" or i%3==1 and "Monitoring" or "TypingConsole"))
  Cast.lookAt(h,Z.BaseCenter+V(BORE_CREW[i].look.X,BORE_CREW[i].look.Y,BORE_CREW[i].look.Z))
 end
 for i,h in c.soldiers do
  h.home=h.root.CFrame;Cast.setActivity(h,(i%3==0 and "Radio" or i%3==1 and "SecurityWatch" or "PatrolIdle"));Cast.lookAt(h,Z.BaseCenter+V(0,3,-28))
 end
 for i,h in {c.lyra,c.voss,c.hale} do
  h.home=h.root.CFrame
  Cast.act(h,STAGING.Command.marks[i].job,"Focused",Z.Command+STAGING.Command.marks[i].look)
 end
 c.performance=Performance.new(c.allHumans)
 return c
end
--[[
 SHOT VOCABULARY. Four framings and nothing else, so a conversation reads as
 coverage rather than as a series of one-off camera positions.

 Every one of them puts the lens at or just above the subject's eye line
 (`height` is measured from the focus point, which itself sits below the head
 so the head lands in the upper third of frame). None of them looks up from
 below, none of them is closer than six studs, and none of them is rolled or
 skewed - the three things that made the old dialogue coverage read as
 unstable and extreme.
]]
-- Over-the-shoulder lens, relative to the listener's head (see human()).
local OTS_BACK,OTS_ACROSS,OTS_LIFT=3.6,1.7,1.1
local FRAMING={
 -- Height raised from 2.6: at eye level the workstation island ran across the
 -- bottom-right third of the master as one pale, empty plane and was the
 -- brightest surface in the room. A metre higher the lens looks OVER it, so
 -- it reads as the angled midground object the blocking is built around
 -- instead of as a counter the audience is standing behind.
 Master  ={distance=11.5,lateral=0,height=3.7,swing=32,fov=46,focusDrop=1.1},
 Medium  ={distance=8.2,lateral=2.2,height=0.42,fov=40,focusDrop=0.66},
 Over    ={distance=6.8,lateral=2.4,height=0.55,fov=38,focusDrop=0.5},
 Reaction={distance=7.4,lateral=1.8,height=0.35,fov=40,focusDrop=0.58},
}

function Sequences.build(env,c,ui): {Shot}
 local shots={}
 Camera.configure(env)
 local scene=""
 local function stage(name)
  if name==scene then return end
  scene=name
  local plan=STAGING[name] or STAGING.Chamber
  local o=Z[plan.origin]
  for i,h in {c.lyra,c.voss,c.hale} do
   local mark=plan.marks[i]
   Cast.place(h,o+mark.at,o+mark.look)
   Cast.act(h,mark.job,"Focused",o+mark.look)
  end
 end
 local byName={[N.Lyra]=c.lyra,[N.Voss]=c.voss,[N.Hale]=c.hale,[N.Soldier]=c.soldiers[1]}
 local function add(name,duration,subject,from,options)
  local op=options or {}
  -- `foreground` is the shot's own list of things that are ALLOWED to pass
  -- between the lens and the subject (see Camera.lua's `allowed`). Without it
  -- an object the shot is deliberately shooting past reads as an obstruction
  -- and the camera corrects away from the framing that was the point.
  local shot={name=name,duration=duration,subject=subject,from=from,to=op.to or from,fov=op.fov or 46,focusOffset=op.focusOffset,handheld=op.handheld,foreground=op.foreground,pace=op.pace or (op.handheld and "Fast") or nil,primarySubject=op.primary or name,secondarySubject=op.secondary or "Expedition",purpose=op.purpose or name,transition=op.transition or "Cut",lighting=op.light or "Chamber",expression=op.expression or "Focused",black=op.black}
  shot.enter=function()
   if op.stage then stage(op.stage) end
   ui.setSubtitle(nil,"");ui.setTitleCard(nil);ui.setBlackout(op.black and 0 or 1)
   --[[
    `advance` (0..1) is only meaningful for the two exterior moods: it walks
    the polar afternoon toward evening, which is how the drilling montage
    shows that hours have passed without a caption or a clock. "Cut" is the
    open excavation - the same sky, but always late, because it is a later
    day.
   ]]
   if op.light=="Exterior" then Light.exterior(op.advance)
   elseif op.light=="Cut" then Light.exterior(op.advance or 1)
   elseif op.light=="Command" then Light.commandTent()
   elseif op.light=="Lab" then Light.abandonedLab()
   elseif op.light=="Door" then Light.ancientInterior()
   elseif op.light=="Prison" then Light.prison()
   elseif op.light=="Emergency" then Light.emergency()
   elseif op.light=="Space" then Light.blackout()
   else Light.chamber(op.energy or 0) end
   if op.enter then op.enter() end
   if op.speaker then
    ui.setSubtitle(op.speaker,op.text)
    local actor=byName[op.speaker]
    if actor then
     local listener=actor==c.lyra and c.hale or c.lyra
     Cast.act(actor,op.action or "Speak",shot.expression,listener.head.Position)
     actor.lineStart=os.clock()
     for _,h in {c.lyra,c.voss,c.hale} do
      if h~=actor then Cast.act(h,h==c.hale and "Authority" or "Listen",op.reaction or "Concerned",actor.head.Position) end
     end
     -- Only nearby staff break from work; the rest keep their assigned task.
     -- This makes the room responsive without turning every NPC into a chorus.
     for i,h in c.scientists do
      if i%2==1 then Cast.act(h,"Listen","Concerned",actor.head.Position) end
     end
    end
   end
   if op.cue then ui.playCue(op.cue) end
   if op.voice then ui.playCue("Dialogue."..op.voice) end
   local s=subject()
   local target=typeof(s)=="Vector3" and s or s.Position
   local marker=env.markers:FindFirstChild(name)
   if not marker then marker=Kit.part({name=name,size=V(0.15,0.15,0.15),color=Color3.new(1,0.4,0),transparency=1});marker.Parent=env.markers end
   marker.CFrame=CFrame.lookAt(target+from,target)
   marker:SetAttribute("Subject",shot.primarySubject);marker:SetAttribute("Duration",duration);marker:SetAttribute("Purpose",shot.purpose);marker:SetAttribute("FOV",shot.fov);marker:SetAttribute("Lighting",shot.lighting);marker:SetAttribute("Expression",shot.expression);marker:SetAttribute("Transition",shot.transition)
   return {start=os.clock()}
  end
  --[[
   `dt` is the real render step, threaded through from Opening.lua's loop.
   Anything with a physical rate - the vehicles' speed, spray and suspension -
   needs it; anything driven by the authored 0..1 shot parameter does not and
   deliberately ignores it.
  ]]
  shot.update=function(state,alpha,dt)
   if op.update then op.update(alpha,alpha*duration,dt or 0) end
   c.performance:update(os.clock())
   Cast.updateChains(c.aegis,os.clock())
   if not op.black then Camera.applyShot(shot,alpha,alpha*duration) end
  end
  shot.leave=function()
   ui.setSubtitle(nil,"")
   if op.leave then op.leave() end
  end
  table.insert(shots,shot)
  return shot
 end
 -- Every character keeps a consistent camera side across the whole
 -- cinematic (a lightweight stand-in for the 180-degree rule) so cuts
 -- between speakers read as real shot/reverse-shot coverage instead of the
 -- exact same relative angle repeated on every line.
 local speakerSide={[N.Lyra]=1,[N.Voss]=-1,[N.Hale]=-1,[N.Soldier]=1}
 --[[
  A master of the room. Establishes where everybody is before the coverage
  starts cutting between faces; without one, a viewer never learns the
  geography and every later close shot floats.

  The camera is built from the direction the cast is FACING, not from a fixed
  +Z offset. Every mark in STAGING carries a look point, and in the command
  room all three of them look at the signal display - so a master at +Z put
  the lens behind all three and opened the scene on three backs and the back
  of the workstation they were meant to be working at. Taking the same shot
  from the side they face shows faces, the island and the display in one
  frame, which is the entire job of a master.

  It stays an oblique three-quarter rather than a flat front-on (the lateral
  offset is wide, and the height clears whatever they are looking at), so it
  reads as coverage rather than as a group photograph.
 ]]
 local function master(name,dur,stageName,options)
  local plan=STAGING[stageName] or STAGING.Chamber
  local o=Z[plan.origin]
  local centre=o+(plan.marks[1].at+plan.marks[2].at+plan.marks[3].at)/3
  local look=o+(plan.marks[1].look+plan.marks[2].look+plan.marks[3].look)/3
  local toward=V(look.X-centre.X,0,look.Z-centre.Z)
  local facing=toward.Magnitude>0.1 and toward.Unit or V(0,0,-1)
  local right=V(-facing.Z,0,facing.X)
  local spec=FRAMING.Master
  --[[
   SWING. Straight down the axis they are all facing is the worst possible
   place to stand, because whatever they are facing is between the lens and
   them: in the command room that is the signal display at head height, and
   before that the main workstation, so the shot was either looking through a
   screen or looking over a four-stud slab of desk that ate the bottom half
   of the frame.

   Swinging 40 degrees off that axis puts the camera in the room's corner.
   The sightline then passes OUTSIDE the display rather than through it, the
   island turns into an angled midground object instead of a wall, and the
   cast is seen three-quarter front - which is the angle that reads as
   cinematography rather than as a group photograph.
  ]]
  local swing=math.rad(spec.swing or 0)
  local direction=(facing*math.cos(swing)+right*math.sin(swing)).Unit
  local op=options or {}
  op.stage=stageName
  op.fov=op.fov or spec.fov
  op.pace=op.pace or "Slow"
  -- The leads ARE the master's subject, and the focus is the centroid of
  -- their marks, so the sightline always passes close by the nearest of them.
  -- With the Roblox-proportioned heads that grazed one mid-take and the
  -- camera orbited away (Studio, 06_CommandMaster / 06i_BeginDrilling).
  op.foreground=op.foreground or {c.lyra.model,c.voss.model,c.hale.model}
  return add(name,dur,function() return centre+V(0,spec.focusDrop,0) end,
   direction*spec.distance+right*spec.lateral+V(0,spec.height,0),op)
 end
 --[[
  A dialogue shot. `extra.shot` picks the framing:

    "Medium"   (default) the speaker, three-quarter, at eye level.
    "Over"     over the listener's shoulder onto the speaker - the shot that
               tells the audience the two of them are in the same room.
    "Reaction" the listener instead of the speaker, for the handful of lines
               where the reaction carries the beat (`reactOn`).

  The camera is placed in shot.enter, from the character's OWN facing, so it
  stays correct however the blocking above moves them. `side` is that
  character's fixed screen side, which is what keeps cuts from crossing the
  line.
 ]]
 local function human(name,dur,who,text,stageName,emotion,voice,extra)
  local op=extra or {}
  local reactOn=op.reactOn;op.reactOn=nil
  local kind=op.shot or (reactOn and "Reaction" or "Medium");op.shot=nil
  local spec=FRAMING[kind] or FRAMING.Medium
  op.speaker=who;op.text=text;op.stage=stageName;op.expression=emotion;op.voice=voice
  -- Each staging area's own mood, so a dialogue shot never has to restate it.
  local STAGE_LIGHT={Command="Command",Bore="Exterior",ExcavationRim="Cut",Excavation="Cut",LabEntry="Lab",Lab="Lab",GateHall="Lab"}
  op.light=op.light or STAGE_LIGHT[stageName] or "Chamber"
  if stageName=="Bore" then op.advance=op.advance or 1 end
  op.fov=op.fov or spec.fov
  local subject=reactOn and byName[reactOn] or byName[who]
  --[[
   Who the shot is taken OVER. This used to be `byName[who]` - the speaker
   themselves - which is the same person as `subject` on every shot that does
   not set `reactOn`, so the over-the-shoulder branch below was skipped and
   every "Over" shot silently fell back to a plain medium taken along the
   speaker's own eyeline. For Hale that eyeline points across the room at the
   main workstation, so his reverse put the lens a stud and a half inside
   Lyra, over the island. That is the giant-face-close-up the brief is about,
   and it was two lines of framing logic, not a lighting or an acting fault.

   The pairing is the same one `add` already uses to decide who a speaker is
   addressing: Lyra's counterpart is Hale, and everyone else's is Lyra.
  ]]
  local shoulder=byName[who]==c.lyra and c.hale or c.lyra
  local other=reactOn and byName[who] or shoulder
  local side=speakerSide[who] or 1
  local shot=add(name,dur,function() return subject.head end,V(spec.lateral,spec.height,spec.distance),op)
  shot.focusOffset=V(0,-spec.focusDrop,0)
  local enter=shot.enter
  shot.enter=function()
   local state=enter()
   local facing=subject.root.CFrame.LookVector
   local right=subject.root.CFrame.RightVector
   if kind=="Over" and other and other~=subject then
    --[[
     Behind the listener's near SHOULDER, looking through them at the
     speaker. Built from the two characters' real positions so the near
     shoulder is always genuinely between the lens and the subject.

     The two numbers below are what make it a shoulder rather than a wall.
     At 2.3 studs back and 1.15 across, the listener's head sat almost on the
     lens: a head is about a stud wide, and at that range it filled over half
     the frame, so every reverse cut opened on an enormous featureless mass
     with the speaker's head small behind it. Pulled back to 3.4 and out to
     1.9, the same head lands in the outer lower corner and is cropped by the
     frame edge, which is what an over-the-shoulder is supposed to look like.

     Both numbers were tuned for the old 0.8-stud head. The Roblox-proportioned
     head is 1.3 wide and a bob adds half a stud either side, so at 3.4/1.9 the
     listener's hair covered half of every reverse (seen in Studio on
     06a_HaleReport). Backing further off does NOT help: the listener sits
     at lateral*D/(back+D) off the lens axis (D = listener to speaker), so a
     longer throw pulls their head toward frame centre. What pushes it out is
     the lateral offset, which now scales with Cast.HeadSize, plus a higher
     lens that looks OVER the bigger head rather than into it.
    ]]
    local k=Cast.HeadSize.X/0.8
    local focus=subject.head.Position-V(0,spec.focusDrop,0)
    local toward=(focus-other.head.Position)
    local flat=V(toward.X,0,toward.Z)
    if flat.Magnitude<0.5 then flat=V(facing.X,0,facing.Z) end
    flat=flat.Unit
    local lateral=V(-flat.Z,0,flat.X)*side*OTS_ACROSS*k
    shot.from=(other.head.Position-flat*OTS_BACK+lateral+V(0,OTS_LIFT,0))-focus
    -- The listener IS the foreground of this shot. Say so, or the camera's
    -- obstruction check reads them as a wall and collapses the framing into a
    -- close-up (see Camera.lua's `allowed`).
    shot.foreground={other.model}
   else
    shot.from=facing*spec.distance+right*side*spec.lateral+V(0,spec.height,0)
   end
   -- A locked-off frame by default. A slow, 3% push is available per shot
   -- (op.push) for a line that earns one; the old code pushed 7% on EVERY
   -- line, which is what made the coverage feel like it was never settling.
   shot.to=op.push and shot.from*0.97 or shot.from
   return state
  end
  return shot
 end
 -- Arrival stays on one camera from the approach through the final park.
 local function segmentAlpha(time: number,startTime: number,duration: number): number
  return math.clamp((time-startTime)/duration,0,1)
 end
 local LEAD_APPROACH=Z.BaseCenter+V(0,0,150)
 local LEAD_GATE=Z.BaseCenter+V(0,0,62)
 local LEAD_PARK=Z.BaseCenter+V(0,0,16)
 local SECOND_APPROACH=Z.BaseCenter+V(0,0,178)
 local SECOND_GATE=Z.BaseCenter+V(0,0,96)
 local SECOND_PARK=Z.BaseCenter+V(0,0,34)
 local function convoyCenter()
  local first=env.vehicles[1].model.PrimaryPart
  local second=env.vehicles[2].model.PrimaryPart
  if not first or not second then return Z.BaseCenter+V(0,4,60) end
  return (first.Position+second.Position)*0.5+V(0,4,0)
 end
 --[[
  The radio over black - but not FIVE SECONDS of a dead frame.

  Measured in Studio, the old shot held pure black for its whole duration with
  a subtitle appearing three seconds in, and a player has no way to tell that
  from a game that has hung. The mystery is worth keeping; the ambiguity about
  whether anything is running is not.

  So the blackout now lifts on a curve rather than cutting: it holds fully
  opaque while the transmission is still the whole scene, then opens to a
  little under a third over the back half, where the lead truck's headlamps
  and the haze over the route are the first things to resolve out of it. The
  camera is live for the whole shot (it is no longer `black`), looking down
  the route at the convoy from far off, so what comes up out of the dark is
  the thing the next shot is about.
 ]]
 add("01_BlackRadio",5,function() return env.vehicles[1].model.PrimaryPart end,V(26,7,54),{light="Exterior",fov=42,to=V(22,6,46),pace="Slow",cue="Radio.ExpeditionTransmission",enter=function()
  -- The shot opens genuinely black; `black=true` is not used because that
  -- also stops the camera being driven at all, and this shot needs the lens
  -- already travelling by the time the frame opens.
  ui.setBlackout(0)
 end,update=function(a,t,dt)
  if t>=0.6 then ui.setSubtitle(N.Radio,"Arctic Expedition Seven to Command. We have reached the signal’s origin.") end
  -- 1 is fully clear, 0 is fully black (see ui.setBlackout). Ends just short
  -- of three-quarters clear, so the cut to the establishing shot is a lift in
  -- exposure rather than a jump from nothing to a lit landscape.
  ui.setBlackout(math.clamp((a-0.35)/0.65,0,1)*0.72)
  Env.moveVehicle(env.vehicles[1],Z.BaseCenter+V(0,0,166),Z.BaseCenter+V(0,0,150),a,dt)
  Env.moveVehicle(env.vehicles[2],Z.BaseCenter+V(0,0,194),Z.BaseCenter+V(0,0,178),a,dt)
 end})
 -- A high three-quarter crane follows BOTH vehicles. Its final two seconds
 -- hold the completed parking composition; the next cut is straight inside.
 add("02_ArcticArrival",14,convoyCenter,V(38,19,58),{light="Exterior",fov=54,to=V(48,26,70),pace="Slow",speaker=N.Radio,text="There is something beneath the ice.",cue="Music.ArcticMystery",foreground={env.vehicles[1].model,env.vehicles[2].model,env.gate},enter=function()
  ui.setTitleCard({"THE NORTH POLE","Fifteen years before the invasion"},"Location")
  ui.playCue("Machinery.VehicleTracks")
 end,update=function(_,elapsed,dt)
  if elapsed<7 then
   Env.moveVehicle(env.vehicles[1],LEAD_APPROACH,LEAD_GATE,segmentAlpha(elapsed,0,7),dt)
  else
   Env.moveVehicle(env.vehicles[1],LEAD_GATE,LEAD_PARK,segmentAlpha(elapsed,7,3.5),dt)
  end
  if elapsed<8 then
   Env.moveVehicle(env.vehicles[2],SECOND_APPROACH,SECOND_GATE,segmentAlpha(elapsed,0,8),dt)
  else
   Env.moveVehicle(env.vehicles[2],SECOND_GATE,SECOND_PARK,segmentAlpha(elapsed,8,4),dt)
  end
  if elapsed>=4 then ui.setTitleCard(nil);ui.setSubtitle(nil,"") end
 end,leave=function() ui.setTitleCard(nil) end})
 -- 06. Inside. A master first - who is in this room and where they stand -
 -- then cut on every speaker.
 master("06_CommandMaster",3,"Command",{light="Command",cue="Radio.SignalPulse",enter=function()
  for i,h in c.scientists do if i<=4 then Cast.setActivity(h,i%2==0 and "TypingConsole" or "Monitoring") end end
 end,update=function(_,t)
  for i,p in env.pulses do p.Size=V(0.25,0.3+math.max(0,math.sin(t*5-i*1.7))*1.5,0.08) end
 end})
 --[[
  In FRONT of the display and off to one side.

  The panel is built facing the room (+Z) with its bezel at z=-6.55, a fifth
  of a stud further back, so a lens authored at -6.5 was looking at the BACK
  of the screen through its own bezel: Studio reported it blocked on every
  run and the unstick pulled in to 1.5 studs, which rendered as a flat grey
  card with a subtitle on it.

  Straight out in front is not the answer either - that is exactly where Lyra
  is standing, and castcheck measured the lens at 1.73 studs from her, i.e.
  inside her.

  So: four and a half studs to Voss's side and seven and a half out. That
  clears every mark in the room, passes over the island (its top is at y=3,
  this looks across at y=5), and at eight and a half studs back the panel
  fills about half the frame rather than all of it - which is what lets the
  three pulse bars on it actually be the subject of the shot.
 ]]
 -- The pulse bars are the SUBJECT of this shot, and they stand a fifth of a
 -- stud proud of the screen they are drawn on, so the obstruction ray hits
 -- them on the way to the panel behind. Declared as foreground, or the camera
 -- spends the shot swinging away from the only thing it is there to show.
 add("06_ThreePulses",1.8,function() return env.signalDisplay end,V(-4.5,0.8,7.5),{stage="Command",light="Command",fov=40,foreground=env.pulses,update=function(_,t)
  for i,p in env.pulses do p.Size=V(0.25,0.3+math.max(0,math.sin(t*5-i*1.7))*1.5,0.08) end
 end})
 --[[
  Over Lyra's shoulder, not a plain medium.

  Hale stands back from the island with Voss between him and his own camera
  side, so his medium was the one shot in the scene the obstruction logic had
  to correct on every take - and when a listener's breathing moved the margin,
  it collapsed to a head filling half the frame. It is also simply the better
  coverage: his first line is an order addressed at the two of them, and
  shooting it over one of them says so. The same framing already plays clean
  on his other two lines.
 ]]
 human("06a_HaleReport",1.2,N.Hale,"Report.","Command","Focused","HaleReport",{shot="Over"})
 -- Split in two. As one 128-character card held for six seconds it was the
 -- longest subtitle in the cinematic by a wide margin, and a viewer reading
 -- it is not watching the scene; as two beats it also earns a cut, which is
 -- what lets the second half land on the room's reaction to the first.
 human("06b_VossSignal",2.8,N.Voss,"The signal is approximately two kilometres beneath us.","Command","Focused","VossSignal",{action="Scan"})
 human("06b2_VossScale",3.4,N.Voss,"Whatever is producing it is larger than anything humanity has ever built.","Command","Focused","VossScale",{action="Scan",push=true})
 human("06c_HaleSpacecraft",1.3,N.Hale,"A spacecraft?","Command","Curious","HaleSpacecraft",{shot="Over"})
 human("06d_VossPossibly",1,N.Voss,"Possibly.","Command","Curious","VossPossibly")
 human("06e_LyraCalling",2,N.Lyra,"It isn’t calling us.","Command","Concerned","LyraCalling")
 human("06f_HaleQuestion",1.5,N.Hale,"Then what is it doing?","Command","Focused","HaleQuestion",{shot="Over"})
 human("06g_LyraUnknown",1.5,N.Lyra,"I don’t know yet.","Command","Concerned","LyraUnknown")
 add("06h_DeepPulseReaction",1.5,function() return c.lyra.head end,V(2.6,0.5,-7.6),{light="Command",fov=40,focusOffset=V(0,-0.6,0),cue="Environment.DeepIceImpact",enter=function()
  for i,h in c.scientists do Cast.react(h,"Concerned",env.signalDisplay.Position,0.25+(i%3)*0.12) end
  for _,h in {c.lyra,c.voss,c.hale} do Cast.react(h,"Concerned",env.signalDisplay.Position,0.75) end
 end})
 --[[
  The scene ends on the ROOM, not on a face.

  "Begin drilling" is the decision the whole conversation has been building to,
  and a master puts the three of them and the display in one frame as it lands
  - which is both better coverage and a fix: Hale's medium has Voss standing in
  its sightline, so it played clean on its first frame and was then corrected,
  and eventually collapsed, part-way through the line.
 ]]
 master("06i_BeginDrilling",1.8,"Command",{light="Command",speaker=N.Hale,text="Begin drilling.",expression="Determined",voice="HaleDrill"})
 --[[
  ============================================================================
  07 - THE DEEP BORE, AND WHAT IT FINDS
  ============================================================================

  The sequence this replaces was six inserts of an auger turning, ice chips,
  a sample, a spinning compass, a skipping clock and then, with no
  preparation at all, metal under the ice. It told the audience nothing about
  what the expedition was doing and nothing about why the discovery mattered;
  the spooky-instrument beats were atmosphere standing in for a story.

  This is the discovery told as SCIENCE, in the order it would actually
  happen, with every beat carrying one new piece of information:

      a plant sending heat two kilometres down
        -> steady telemetry, nothing wrong
        -> hours pass
        -> the line loses pressure, suddenly
        -> the return says the bore is in a VOID, far too shallow
        -> the return says the void has a floor that is not ice, and that the
           floor is REGULAR
        -> the cut is widened and the thing is standing in the open

  The estimate on the console never changes: SOURCE ESTIMATE 1,984 m, all the
  way through. That single unmoving number is what makes the discovery legible
  as the wrong discovery - whatever they have hit at eleven hundred metres,
  it is not what they came for. Nobody has to explain that, because the
  instrument says it in every shot.
 ]]
 -- One baseline, overridden per beat, so a reading that is NOT the point of a
 -- shot cannot drift by accident between shots.
 local BORE_BASELINE={depth=0,hosePayout=0,waterTemperature=81,linePressure=7.2,flowRate=734,signalStrength=1,returnDensity=1,state="ACTIVE",sourceEstimate=1984}
 local function telemetry(overrides)
  local reading={}
  for key,value in BORE_BASELINE do reading[key]=value end
  if overrides then for key,value in overrides do reading[key]=value end end
  reading.hosePayout=reading.hosePayout>0 and reading.hosePayout or reading.depth*1.008
  env.boreDisplay.setTelemetry(reading)
  -- The reel is driven by DEPTH, never by the shot's own 0..1 parameter: a
  -- reel whose speed disagrees with the number on the screen beside it reads
  -- as decoration. Same rule the truck wheels follow.
  Env.setReelRotation(env,reading.depth*0.05)
  return reading
 end
 add("07a_BoreSystemStarts",5,function() return Z.BaseCenter+V(-4,8,-25) end,V(38,19,33),{light="Exterior",fov=54,stage="Bore",to=V(30,15,26),pace="Slow",cue="Machinery.BoreStart",enter=function()
  Env.setBoreSteam(env,26)
  Env.setBoreWeathering(env,0)
 end,update=function(a)
  telemetry({depth=206+a*58,state="ACTIVE"})
 end})
 -- The panel, on the operator's side of the desk. Six values, none of them
 -- alarming: this shot exists so the audience learns what normal looks like,
 -- which is the only way the next four can mean anything.
 add("07b_BoreTelemetry",3.6,function() return env.boreScreen end,V(5.5,1.6,4.5),{light="Exterior",fov=36,speaker=N.Voss,text="Eleven hundred metres of ice, and the return is still clean.",voice="VossBorePlan",update=function(a)
  telemetry({depth=264+a*46})
 end})
 --[[
  TIME PASSES, told four ways at once and with no clock anywhere: the depth
  jumps eight hundred metres, the light walks from polar afternoon into
  evening (Light.exterior's `advance`), snow banks up on equipment that was
  clear in the last shot, and the crew have changed over.
 ]]
 add("07c_BoreProgress",4.6,function() return Z.BaseCenter+V(-5,7,-25) end,V(-30,24,24),{light="Exterior",fov=56,to=V(-24,18,19),pace="Slow",cue="Machinery.BoreLoop",enter=function()
  -- The shift changes. Two of the crew step away from their stations and two
  -- take them over, which is a thing only time can explain.
  Cast.place(c.workers[2],Z.BaseCenter+V(-15.4,2.8,-13.4),Z.BaseCenter+V(-24.5,3,-18))
  Cast.place(c.workers[4],Z.BaseCenter+V(0.6,2.8,-19.4),Z.BaseCenter+V(8.6,3,-21))
  Cast.setActivity(c.workers[2],"CheckCable");Cast.setActivity(c.workers[4],"Monitoring")
 end,update=function(a)
  Light.exterior(a)
  Env.setBoreWeathering(env,a)
  Env.setBoreSteam(env,26+a*14)
  telemetry({depth=310+a*790,waterTemperature=79,flowRate=728})
 end})
 --[[
  THE FIRST THING THAT GOES WRONG, and deliberately not explained yet. The
  reel gives one small uncommanded movement - the hose is no longer being
  held back by anything - the crew look up, and the panel goes amber. The
  reason arrives two shots later.
 ]]
 add("07d_PressureDrop",3,function() return Z.BaseCenter+V(-12.5,4.8,-23.5) end,V(2.5,5.5,13.5),{light="Exterior",advance=1,fov=46,handheld=true,cue="Machinery.LinePressureLoss",foreground={env.hoseReel},enter=function()
  for index,worker in c.workers do Cast.react(worker,"Surprised",Z.BaseCenter+V(-12.5,5,-23.5),0.4+(index%3)*0.15) end
  for _,lead in {c.lyra,c.voss,c.hale} do Cast.react(lead,"Concerned",Z.BaseCenter+V(-12.5,5,-23.5),0.5) end
 end,update=function(a)
  telemetry({depth=1104,linePressure=7.2-a*4.6,flowRate=734+a*280,returnDensity=1-a*0.5,state="ALARM",alert="PRESSURE DROP"})
  -- One uncommanded lurch, then it catches: the reel runs AHEAD of the depth
  -- it should be at, which is what losing the load feels like. Applied after
  -- telemetry(), which sets the reel from depth and would otherwise undo it.
  local slip=math.min(a*3,1)
  Env.setReelRotation(env,(1104+slip*26)*0.05)
 end})
 -- The first real discovery. The bore is in empty space, a kilometre short of
 -- where the signal is supposed to be.
 add("07e_UnexpectedVoid",3.4,function() return env.boreScreen end,V(5,1,4.1),{light="Exterior",advance=1,fov=38,cue="Machinery.ReturnLost",speaker=N.Voss,text="We have no return at all. The bore is in open space.",voice="VossVoid",update=function(a)
  telemetry({depth=1112,linePressure=1.9,flowRate=1040,returnDensity=0,signalStrength=1+a*3.4,state="FAULT",alert="UNEXPECTED VOID DETECTED"})
 end})
 human("07e2_LyraNotACavity",2.8,N.Lyra,"There is no cavity in this ice. There never has been.","Bore","Concerned","LyraNoCavity")
 --[[
  NOT GEOLOGY. Said in the instrument's own language rather than with a
  camera feed that this project cannot make convincing: the return trace,
  which has wandered all sequence, goes FLAT - a hard horizontal line, which
  is what a regular surface returns and what nothing natural returns.
 ]]
 add("07f_NonIceMaterial",3.6,function() return env.boreScreen end,V(5.2,1.3,4.3),{light="Exterior",advance=1,fov=37,cue="Machinery.HardReturn",speaker=N.Voss,text="Something down there is returning a flat signal. A machined surface.",voice="VossNonIce",update=function(a)
  telemetry({depth=1118,linePressure=2.1,flowRate=1012,returnDensity=0.08,signalStrength=1+a*5.4,state="FAULT"})
  -- A regular surface returns a regular trace. Overwriting the graph with a
  -- constant after setTelemetry has pushed its own sample is what turns the
  -- wander of the last four shots into a straight line.
  env.boreDisplay.pushSignal(0.72)
  env.boreDisplay.setRow("density","NON-ICE","caution")
  env.boreDisplay.setFooter("GEOMETRY","REGULAR","caution")
  env.boreDisplay.setAlert("NON-ICE SURFACE  ·  RETURN × 6.4","caution")
 end})
 human("07f2_HaleWiden",2.4,N.Hale,"Then stop boring and start digging. I want to stand on it.","Bore","Determined","HaleWiden",{shot="Over"})
 --[[
  AND THEN THE CUT - shown, not skipped.

  The bore FOUND the structure; it cannot expose it. A hose a few
  centimetres wide does not become a hole people can climb down, and the
  old cut straight to a finished pit left the audience to fill that gap in.
  So the next five shots are the second machine: an excavation gantry the
  expedition brought in once they knew what was down there.

      07g  the gantry, established - with people in frame, and the bore
           plant beside it looking like the small instrument it is
      07h  it starts: carriage travels, cutter turns, steam
      07i  the head goes into the ice - several times the size of a person
      07j  enough is gone that a flat, seamed, ribbed surface shows through
           the middle of the cut: the "NON-ICE / REGULAR" from the console,
           in the flesh
      07k  finished: the roof, the bulkhead and the scaffold down to it,
           workers on the rim, the machine parked over it all

  Every shot drives the same four numbers (Env.setExcavationProgress plus
  the rig's carriage/depth/spin), each from its own absolute range, so any
  shot can be entered cold and look right.
 ]]
 local X=Z.Excavation
 local rig=env.excavationRig
 local function excavate(progress,carriage,spin,steam)
  local surface=Env.setExcavationProgress(env,progress)
  rig.setCarriagePosition(carriage)
  rig.setCutterSpin(spin)
  rig.setSteam(steam)
  env.cutMist.Rate=steam*14
  return surface
 end
 -- People are the scale reference, so the crew are put ON the machine: one on
 -- the service walkway, one at the operator station, one down by a crawler,
 -- and a scientist watching from behind the rim barrier.
 local function crewTheCut()
  local cut=X+V(0,-4,0)
  Cast.place(c.workers[1],rig.walkwayFloor+V(-7,2.8,0),cut)
  Cast.place(c.workers[3],rig.operatorFloor+V(0.2,2.8,1),cut)
  Cast.place(c.workers[2],X+V(-21.4,2.8,7.5),X+V(-16,3,2))
  Cast.place(c.workers[4],X+V(-24.5,2.8,-1),X+V(-27,3,-6))
  Cast.place(c.workers[5],X+V(-10,2.8,-21.6),cut)
  Cast.place(c.scientists[6],X+V(-8.5,2.8,23),cut)
  Cast.setActivity(c.workers[1],"Monitoring");Cast.setActivity(c.workers[3],"TypingConsole")
  Cast.setActivity(c.workers[2],"CheckCable");Cast.setActivity(c.workers[4],"Monitoring")
  Cast.setActivity(c.workers[5],"Monitoring");Cast.setActivity(c.scientists[6],"CheckingTablet")
  for _,h in {c.workers[1],c.workers[3],c.workers[5],c.scientists[6]} do Cast.lookAt(h,cut) end
 end
 add("07g_ExcavationGantryEstablished",6.4,function() return X+V(-12,10,8) end,V(46,12,62),{light="Cut",fov=56,stage="ExcavationRim",to=V(40,10,56),pace="Slow",cue="Machinery.GantryIdle",foreground={rig.model},enter=function()
  ui.setTitleCard({"THE OPEN CUT","Six days later"},"Location")
  crewTheCut()
  excavate(0,-0.7,0,0.05)
  rig.setCutDepth(0)
 end,update=function(a)
  if a>0.55 then ui.setTitleCard(nil) end
 end,leave=function() ui.setTitleCard(nil) end})
 -- Enough of the machine in frame that the audience can see WHAT is moving:
 -- the carriage running out along the bridge, the head beginning to turn,
 -- steam starting under it, a man on the walkway above it all.
 add("07h_ExcavationBegins",4.8,function() return X+V(-2,15,0) end,V(30,0,28),{light="Cut",fov=52,pace="Slow",cue="Machinery.GantryStart",foreground={rig.model},update=function(a)
  local eased=Kit.smooth(a)
  local surface=excavate(a*0.06,-0.7+eased*0.6,a*a*0.9,0.1+a*0.6)
  rig.setCutDepth(math.min(Env.cutterDepthFor(surface),a*0.35))
 end})
 -- Low, from the rim, looking up: the head in the ice at the bottom of frame,
 -- the bridge and the man on its walkway at the top. The contact line itself
 -- is left to the steam.
 add("07i_CutterDescends",5.2,function() return X+V(-2,4,0) end,V(5,-1,15),{light="Cut",fov=62,pace="Slow",cue="Machinery.CutterLoad",foreground={rig.model},update=function(a)
  local surface=excavate(0.06+a*0.36,-0.1+math.sin(a*math.pi)*0.25,0.9+a*2.6,0.75)
  rig.setCutDepth(Env.cutterDepthFor(surface))
 end})
 -- The payoff to "NON-ICE / REGULAR". Looking down into the middle of the
 -- cut, which is where the gantry has gone deepest: a flat dark surface with
 -- a straight seam across it and ribs at an even pitch, and grey ice still
 -- standing at both ends of the working.
 add("07j_StructureRoofExposed",5.2,function() return X+V(-3,-10.8,-6) end,V(8,30,-22),{light="Cut",fov=54,pace="Slow",cue="Music.ScientificDiscovery",foreground={rig.model},speaker=N.Voss,text="Straight edges. Seams. Somebody built this.",voice="VossBuilt",enter=function()
  -- Seen from almost directly above, the rim worker by the scaffold reads as
  -- somebody lying on the ice. He steps back to the ice-block stack for this
  -- one shot.
  Cast.place(c.workers[5],X+V(-24,2.8,-19),X+V(-28,3,-14))
 end,update=function(a)
  local surface=excavate(0.5+a*0.22,0.9-a*0.2,3.6+a*2.4,0.55)
  rig.setCutDepth(Env.cutterDepthFor(surface))
 end})
 -- Finished. Held long enough to read the geography: the machine parked up
 -- over the cut, the roof and its bulkhead at the bottom, the scaffold that
 -- leads down to them, people round the rim.
 add("07k_AccessTunnelRevealed",6.8,function() return X+V(0,-9,4) end,V(24,34,30),{light="Cut",fov=56,stage="ExcavationRim",to=V(21,31,27),pace="Slow",cue="Music.ArcticMystery",foreground={rig.model},enter=function()
  crewTheCut()
  Cast.place(c.workers[5],X+V(-3.4,-9.2,-12),X+V(0,-10,CUT.hatchZ))
 end,update=function()
  excavate(1,0.85,6,0.12)
  rig.setCutDepth(0.08)
 end})

 --[[
  ============================================================================
  08 - THE WAY IN
  ============================================================================
 ]]
 add("08a_AccessHatch",3.6,function() return X+V(0,CUT.roofTop+0.6,CUT.hatchZ) end,V(8,7,-7),{light="Cut",fov=48,stage="Excavation",pace="Slow",foreground={env.hatchHoist},speaker=N.Voss,text="It was sealed from the inside.",voice="VossSealedInside"})
 add("08b_Descent",4.2,function() return c.lyra.head end,V(6,3,-9),{light="Cut",fov=52,focusOffset=V(0,-0.7,0),cue="Music.ArcticMystery",update=function(a)
  Cast.walk(c.lyra,X+V(2.5,CUT.roofTop+1,-7),X+V(2,CUT.roofTop+1,2.5),a)
  Cast.walk(c.voss,X+V(-1,CUT.roofTop+1.1,-8),X+V(-1.8,CUT.roofTop+1.1,1.5),a)
 end})

 --[[
  ============================================================================
  09 - THE ABANDONED FACILITY
  ============================================================================
 ]]
 -- Looking BACK at the shaft they came down, so the only daylight in the
 -- building is behind the three of them and the corridor runs away into the
 -- dark behind camera. The room is established by what the expedition's own
 -- lamps reach, which is the whole idea of the abandonedLab preset.
 add("09a_AbandonedLabEntry",5.4,function() return Z.Door+V(0,4,36) end,V(7,4,8),{light="Lab",fov=60,stage="LabEntry",to=V(6,3.4,6.6),pace="Slow",cue="Environment.FacilityTone",enter=function()
  ui.setTitleCard({"BENEATH THE ICE"},"Location")
 end,update=function(a)
  if a>0.5 then ui.setTitleCard(nil) end
 end,leave=function() ui.setTitleCard(nil) end})
 human("09a2_VossPower",3.2,N.Voss,"There is no power anywhere in this structure. Not a volt.","LabEntry","Amazed","VossNoPower")
 -- One insert, not a montage of damage: a chair pushed back and turned away
 -- from a console somebody stopped working at, frost growing across the
 -- panel, and a tool left exactly where it was put down.
 add("09b_DeadWorkstation",4,function() return env.deadScreen end,V(7.4,1.4,3.8),{light="Lab",fov=42,stage="Lab",pace="Slow",cue="Environment.SettlingMetal"})
 human("09b2_LyraLeftQuickly",3,N.Lyra,"Nobody shut this down. They walked out of it.","Lab","Concerned","LyraWalkedOut")
 --[[
  THE GATE. Dead, and the shot is built to say so: no light on it anywhere,
  the only illumination in frame is the two portable lamps the expedition
  carried in, and the camera pushes in slowly rather than craning around it.
 ]]
 add("09c_InnerGate",5,function() return Z.Door+V(0,11,-33) end,V(5,3.5,27),{light="Lab",fov=56,stage="GateHall",to=V(4,2.8,22),pace="Slow",cue="Music.WarningTension"})
 human("09c2_HaleOpenIt",2.2,N.Hale,"Can you open it?","GateHall","Focused","HaleOpenIt",{shot="Over"})
 human("09c3_VossNoMechanism",3.2,N.Voss,"There is no mechanism to force. It is waiting for something.","GateHall","Concerned","VossNoMechanism")
 --[[
  THE KEY, found in its cradle. The pedestal is what does the work here: an
  object lying on a floor is set dressing, and an object sitting in a shaped
  recess cut to its own outline, beside the mechanism it belongs to, is an
  instruction. Lyra clears the frost off it rather than picking it up, so
  the beat is recognition rather than acquisition.
 ]]
 add("09d_KeyDiscovered",4.6,function() return env.keyCore end,V(4.1,2.6,4.6),{light="Lab",fov=30,pace="Slow",cue="Ancient.KeyFound",foreground={env.keyFrost},enter=function()
  Cast.place(c.lyra,Z.Door+V(-12.4,2.8,-26.6),Z.Door+V(-16,4,-27))
  Cast.act(c.lyra,"ClearIce","Amazed",Z.Door+V(-16.5,4.3,-27))
 end,update=function(a)
  -- The frost comes off the cradle as she works, and the marks on the plinth
  -- come up out of it. They do not LIGHT: they are being cleaned.
  env.keyFrost.Transparency=0.25+a*0.75
  env.keyPedestalGlyphs.setProgress(a*#env.keyPedestalGlyphs.glyphs)
  env.keyGlyphs.setProgress(a*#env.keyGlyphs.glyphs*0.4)
 end})
 human("09d2_LyraSameMarks",3.4,N.Lyra,"These are the same marks. On the roof, in the corridor, on the door.","GateHall","Amazed","LyraSameMarks",{enter=function()
  Cast.place(c.lyra,Z.Door+V(-6,2.9,-25),Z.Door+V(0,8,-36))
 end})
 --[[
  INSERTED, and the facility answers - faintly, and in the key first. That
  ordering is the whole reason the unlock reads as the key causing it rather
  than the door deciding to open.
 ]]
 add("09e_KeyInserted",4,function() return env.gateSocketCore end,V(3.2,1.4,3.6),{light="Lab",fov=36,cue="Ancient.KeySeats",enter=function()
  Cast.place(c.lyra,Z.Door+V(7.4,2.9,-31),Z.Door+V(10.6,5.6,-33))
  Cast.act(c.lyra,"Reach","Determined",Z.Door+V(10.6,5.6,-33))
 end,update=function(a)
  -- Lined up, then seated. The key travels into the socket on screen.
  Env.placeKey(env,env.keyAlignCF:Lerp(env.keySeatedCF,Kit.smooth(math.min(a*1.6,1))))
  Env.setKeyCharge(env,math.clamp((a-0.62)/0.38,0,1))
 end})
 --[[
  THE CIRCUIT. One tight shot on the lock housing while the charge leaves the
  key and starts up the pier - light travelling through a mechanism, not a
  door switching on.
 ]]
 add("09f_LockResponds",3.6,function() return env.gateSocketCore end,V(4.6,2.2,5.2),{light="Lab",fov=40,pace="Slow",cue="Ancient.LockEngages",update=function(a)
  Env.setKeyCharge(env,1)
  Env.setGateUnlock(env,a*0.3)
 end})
 --[[
  AND THE GATE. Wide enough to hold the whole mechanism, because every stage
  of the unlock is somewhere different on it: the charge crossing the head,
  eight dogs withdrawing, two drums turning, and only then the leaves parting.
  Nothing here is an explosion of light - it is a machine doing a job in the
  order a machine would do it.
 ]]
 add("09g_GateUnlocks",7.4,function() return Z.Door+V(0,12,-36) end,V(6,1,22),{light="Lab",fov=58,to=V(4.5,0.6,26),pace="Slow",cue="Machinery.GateUnlock",enter=function()
  for index,lead in {c.lyra,c.voss,c.hale} do Cast.react(lead,"Amazed",Z.Door+V(0,10,-36),0.3+index*0.1) end
 end,update=function(a)
  Env.setGateUnlock(env,0.3+a*0.7)
 end})

 --[[
  ============================================================================
  10 - AEGIS ZERO
  ============================================================================

  Four shots, bottom to top, each one further back than the last, so the
  reveal is about SCALE rather than about detail. The team walk into this
  believing it may be the source of the signal; nothing in these four shots
  tells them otherwise, and nothing tells the audience either.
 ]]
 -- The planted forward foot: a sole on the floor, a light toe cap, a heel,
 -- and the shin rising out of it. The focus is lifted to the top of the foot
 -- so the shot looks along it rather than down at the floor. Taken from
 -- outside the chain: the old front-on offset put the lens on the left
 -- chain's run from fist to seal.
 add("10a_AegisFoot",3.4,function() return c.aegis.model:FindFirstChild("LeftFoot") end,V(17,2,4),{stage="Chamber",cue="Music.ScientificDiscovery",pace="Slow",focusOffset=V(0,2.5,0)})
 add("10b_AegisChains",3.8,function() return c.aegis.model:FindFirstChild("RightHand") end,V(12,3,17),{fov=58,focusOffset=V(0,-3,0),cue="Machinery.ChainTension",pace="Slow"})
 -- The chest, and the band of marks across it - which the audience has now
 -- seen four times and cannot yet read.
 add("10c_AegisTorso",3.4,function() return c.aegis.core end,V(15,6,26),{fov=52,focusOffset=V(0,-2,0),pace="Slow",cue="Aegis.CorePulse"})
 -- From just behind the expedition, on the line from the machine through
 -- them, a few degrees off its left front: the three leads stand in the lower
 -- left of frame for scale with the kneeling machine filling the middle. The
 -- focus is a fixed point at chest height over the machine's knee rather than
 -- a part, so the framing does not wander with the pose. The planted foot and raised
 -- knee read as a kneel from here, and the chest does not flatten onto the
 -- waist the way it does head-on.
 add("10d_AegisFullReveal",4.8,function() return Z.ChamberFloor+V(0,18,-36) end,V(8,-10,84),{fov=57,to=V(10,-9,90),pace="Slow",foreground={c.aegis.model}})

 --[[
  ============================================================================
  11 - WHAT THEY THINK THEY HAVE FOUND
  ============================================================================
 ]]
 human("11a_VossAwe",1.6,N.Voss,"My God.","Chamber","Amazed","VossAwe")
 human("11b_HaleAge",1.6,N.Hale,"How old is it?","Chamber","Amazed","HaleAge")
 human("11c_VossIce",2.6,N.Voss,"The surrounding ice is thousands of years old.","Chamber","Amazed","VossIce")
 human("11d_HaleWeapon",3.6,N.Hale,"Then we have discovered the greatest weapon in human history.","Chamber","Focused","HaleWeapon",{reactOn=N.Lyra})
 human("11e_LyraBuried",2.4,N.Lyra,"No. It wasn’t buried here.","Chamber","Concerned","LyraBuried")
 human("11f_LyraRemain",2,N.Lyra,"It chose to remain.","Chamber","Concerned","LyraRemain")
 add("11g_LyraFindsGlyphs",3.4,function() return env.mythWall end,V(4.5,1.2,15),{cue="Music.WarningTension",pace="Slow",foreground={c.lyra.model},enter=function()
  Cast.place(c.lyra,Z.ChamberFloor+V(-38,2.8,30),env.mythWall.Position)
  Cast.act(c.lyra,"ClearIce","Concerned",env.mythWall.Position)
 end,update=function(a)
  env.warningBand.setProgress(a*1.2)
 end})
 human("11h_VossCanYouRead",1.6,N.Voss,"Can you read it?","Chamber","Concerned","VossRead")
 --[[
  THE PARTIAL TRANSLATION, and the most important restraint in the whole
  sequence.

  The version this replaces had Lyra say "The Guardian is the seal" out loud,
  in the chamber, before anybody touched anything - which hands the audience
  the ending and leaves the seal failure with nothing to reveal.

  She gets three words instead, and the third one is a question. The shot is
  held on the wall for the whole beat rather than cut between faces, so each
  mark is physically in frame as she names it and the audience can see her
  running out of wall before she runs out of sentence.
 ]]
 add("11i_PartialTranslation",8,function() return env.mythWall end,V(3.4,1,12),{fov=44,pace="Slow",to=V(3,0.8,10.5),foreground={c.lyra.model},enter=function()
  Cast.act(c.lyra,"Scan","Afraid",env.mythWall.Position)
 end,update=function(_,elapsed)
  if elapsed<1.5 then
   ui.setSubtitle(N.Lyra,"Parts of it.")
   env.warningBand.setProgress(1.2)
  elseif elapsed<3.2 then
   ui.setSubtitle(N.Lyra,"Guardian.")
   env.warningBand.setProgress(2)
  elseif elapsed<4.9 then
   ui.setSubtitle(N.Lyra,"Bind.")
   env.warningBand.setProgress(3)
  else
   ui.setSubtitle(N.Lyra,"And something below.")
   env.warningBand.setProgress(4)
  end
 end})
 human("11j_HaleBelowWhat",1.6,N.Hale,"Below what?","Chamber","Focused","HaleBelowWhat",{shot="Over"})
 human("11k_LyraDontKnow",2,N.Lyra,"I don’t know.","Chamber","Afraid","LyraDontKnow")

 --[[
  ============================================================================
  12 - THEY WAKE IT
  ============================================================================
 ]]
 human("12a_HaleWake",2,N.Hale,"Then we wake it and we ask it.","Chamber","Determined","HaleWake",{shot="Over"})
 human("12b_LyraWait",3.4,N.Lyra,"Give me a week with that wall before you put a current through it.","Chamber","Concerned","LyraWait")
 human("12c_HaleDiscovery",4.4,N.Hale,"We did not cross half the planet to abandon humanity’s greatest discovery.","Chamber","Angry","HaleDiscovery",{reactOn=N.Lyra})
 add("12d_ExternalPower",3.8,function() return env.activationConsole end,V(7,2.4,9),{light="Chamber",fov=44,cue="Machinery.PowerConnection",foreground={env.powerReadout},enter=function()
  -- Scientists 5 and 7, not 1-4: the first four are the command room's own
  -- technicians, each standing in exactly one ceiling light cone back at the
  -- base, and walking one of them into the chamber leaves that assertion -
  -- and the room's lighting design - quietly broken.
  Cast.place(c.scientists[5],Z.ChamberFloor+V(11.5,2.8,22.5),Z.ChamberFloor+V(9,3,24))
  Cast.place(c.scientists[7],Z.ChamberFloor+V(6.5,2.8,22),Z.ChamberFloor+V(9,3,24))
  Cast.setActivity(c.scientists[5],"AdjustingCable");Cast.setActivity(c.scientists[7],"TypingConsole")
 end})
 add("12e_CoreReceivesPower",2.6,function() return c.aegis.core end,V(8,1,18),{energy=0.3,cue="Aegis.CoreActivation",enter=function()
  for index,scientist in c.scientists do Cast.react(scientist,"Surprised",c.aegis.core.Position,0.35+(index%3)*0.16) end
  for _,lead in {c.lyra,c.voss,c.hale} do Cast.react(lead,"Amazed",c.aegis.core.Position,0.55) end
 end,update=function(a) Cast.setAegisAwaken(c.aegis,a*0.3);Light.chamber(a*0.3) end})
 --[[
  THE MATCH. The chest band lights, and it is the same four marks that were
  on the roof of the buried structure, in the corridor, on the key, on its
  cradle and around the gate's lock housing. This is the scene's real
  turning point and it is carried entirely by repetition of a shape.
 ]]
 add("12f_ChestGlyphs",3.4,function() return c.aegis.core end,V(11,2,20),{energy=0.35,fov=46,pace="Slow",cue="Ancient.ChestBandLights",update=function(a)
  Cast.setAegisAwaken(c.aegis,0.3+a*0.06)
  Light.chamber(0.3+a*0.06)
  c.aegisGlyphs.setProgress(a*#c.aegisGlyphs.glyphs)
 end})
 human("12g_LyraSameSystem",3.4,N.Lyra,"Those are the marks from the door. The door and this machine are one thing.","Chamber","Horrified","LyraSameSystem",{energy=0.36})
 human("12h_NotACode",2.2,N.Lyra,"It isn’t an activation code.","Chamber","Afraid","LyraCode",{energy=0.36})
 human("12i_WhatIsIt",1.5,N.Hale,"Then what is it?","Chamber","Concerned","HaleCode",{energy=0.36,shot="Over"})
 human("12j_NewGuardian",2.8,N.Lyra,"It is asking for a new guardian.","Chamber","Horrified","LyraGuardian",{energy=0.36})
 add("12k_FingersTighten",1.7,function() return c.aegis.model:FindFirstChild("LeftHand") end,V(-8,1,10),{energy=0.45,cue="Aegis.ServoMovement",update=function(a) Cast.setAegisAwaken(c.aegis,0.36+a*0.14);Light.chamber(0.36+a*0.14) end})
 add("12l_ShoulderUnlocks",1.7,function() return c.aegis.model:FindFirstChild("RightUpperArm") end,V(12,2,18),{energy=0.55,cue="Aegis.ArmorMovement",update=function(a) Cast.setAegisAwaken(c.aegis,0.5+a*0.15);Light.chamber(0.5+a*0.15) end})
 add("12m_HeadAndEyes",2.7,function() return c.aegis.head end,V(9,0,22),{energy=0.75,cue="Aegis.HeadMovement",update=function(a) Cast.setAegisAwaken(c.aegis,0.65+a*0.35);Light.chamber(0.65+a*0.35) end})
 human("12n_WeDidIt",1.5,N.Hale,"We did it.","Chamber","Amazed","HaleSuccess",{energy=1,reactOn=N.Lyra})
 --[[
  AND THE BUILDING DISAGREES. Three things happen at once, all of them
  BELOW the celebration: the chains come under tension, the marks set into
  the floor around the iris change state, and something a long way down
  answers. Nobody has said the word "seal" yet.
 ]]
 add("12o_ContainmentStrain",3.4,function() return Z.ChamberFloor+V(0,2,6) end,V(14,16,26),{energy=1,fov=52,handheld=true,cue="Impacts.UndergroundImpact",enter=function()
  for index,lead in {c.lyra,c.voss,c.hale} do Cast.react(lead,"Afraid",Z.ChamberFloor+V(0,0,0),0.55+index*0.1) end
 end,update=function(a)
  env.sealFloorGlyphs.setProgress(a*#env.sealFloorGlyphs.glyphs)
  Env.openSeal(env,a*0.05)
 end})
 --[[
  THE PAYOFF FOR THE BORE CONSOLE. Same instrument family, same layout, same
  units - so when the number moves by a factor of forty-seven the audience
  knows exactly how far from normal that is, because they spent four shots
  learning what normal looked like on the ice.
 ]]
 add("12p_SignalSpike",3.6,function() return env.fieldScreen end,V(2.9,0.8,2.4),{energy=1,fov=34,cue="Alien.SignalSurge",update=function(a)
  env.fieldDisplay.setRow("signal",`× {Instrumentation.formatNumber(1+a*46.2,1)}`,if a>0.3 then "critical" else "caution")
  env.fieldDisplay.setRow("depth",if a>0.45 then "LOCKED" else "RESOLVING","caution")
  env.fieldDisplay.setRow("bearing",if a>0.6 then "DIRECTLY BELOW" else "—",if a>0.6 then "critical" else nil)
  env.fieldDisplay.pushSignal(math.min(0.15+a*1.2,1))
  if a>0.6 then env.fieldDisplay.setAlert("SOURCE IS NOT THIS OBJECT","critical") end
 end})
 human("12q_VossNotTheSource",3.6,N.Voss,"It was never the source. It has been sitting on top of the source.","Chamber","Horrified","VossNotSource",{energy=1})
 human("12r_LyraRealizes",3.4,N.Lyra,"We weren’t waking a machine. We were opening a lock.","Chamber","Horrified","LyraLock",{energy=1})
 human("12s_LyraPower",3,N.Lyra,"Turn off the power! It is fighting the activation!","Chamber","Horrified","LyraPower",{energy=1})

 --[[
  ============================================================================
  13 - WHAT WAS UNDER IT
  ============================================================================

  The first violet frame in the film. Everything below is gated on
  Env.setLowerSealReveal, which is the only thing anywhere that can turn the
  lower prison's lights, the shaft glow or the frozen army's sensors up from
  zero - so the twist cannot leak into an earlier shot by accident.
 ]]
 add("13a_SealCracks",3.2,function() return Z.ChamberFloor+V(0,0.5,4) end,V(0,38,17),{energy=1,fov=57,cue="Machinery.SealSeparates",foreground={env.sealIris},update=function(a)
  Env.openSeal(env,0.05+a*0.95)
  Cast.setAegisRise(c.aegis,a)
  Env.setLowerSealReveal(env,a*0.45)
 end})
 human("13b_LyraNo",1.3,N.Lyra,"No.","Chamber","Horrified","LyraNo",{energy=1})
 add("13c_FirstChainBreak",1.6,function() return c.aegis.model:FindFirstChild("RightHand") end,V(16,3,14),{light="Emergency",cue="Machinery.ChainBreak",enter=function()
  Cast.breakChain(c.aegis,2,os.clock());Cast.act(c.hale,"Stumble","Horrified",c.aegis.head.Position)
 end})
 add("13d_SecondChainBreak",1.3,function() return c.aegis.model:FindFirstChild("LeftHand") end,V(-14,2,15),{light="Emergency",cue="Aegis.MechanicalCry",enter=function() Cast.breakChain(c.aegis,1,os.clock()) end})
 --[[
  LOOKING DOWN IT. The containment shaft under the iris is ordinary dark
  structure that has been sitting there, unseen, behind a closed floor for
  the entire film; opening the iris is the first and only time it is in
  frame. Seven rings falling away, each smaller than the last, and a long way
  under them, violet.
 ]]
 add("13e_VioletBelow",3.6,function() return Z.ChamberFloor+V(0,-6,0) end,V(0,34,14),{light="Emergency",fov=62,pace="Slow",to=V(0,26,10),cue="Alien.LowRumble",foreground={c.aegis.model},update=function(a)
  Env.setLowerSealReveal(env,0.45+a*0.55)
 end})
 human("13f_HoldingCreature",2.8,N.Lyra,"It is holding something down there. It has always been holding it down there.","Chamber","Horrified","LyraCreature",{light="Emergency"})
 -- Down in it. The expedition never goes here - the camera does.
 add("13g_FirstAlienPartial",2.6,function() return c.sovereign.model:FindFirstChild("RightHand") end,V(-12,2,-16),{light="Prison",pace="Slow",cue="Alien.IceMovement"})
 add("13h_SovereignEyeOpens",2.4,function() return c.sovereign.eyes[1] end,V(1,0,-5),{light="Prison",cue="Alien.EyeActivation",update=function(a) Cast.setCreatureEyes(c.sovereign,a*0.5);Cast.removeIceShell(c.sovereign,a) end})
 add("13i_SovereignReveal",3.8,function() return c.sovereign.torso end,V(56,28,-82),{light="Prison",fov=63,focusOffset=V(0,0,25),to=V(62,32,-92),pace="Slow",cue="Music.AlienAwakening"})
 add("13j_GuardianRises",2.2,function() return c.sovereign.head end,V(3,0,-18),{light="Prison",speaker=N.Sovereign,text="The Guardian rises.",cue="Alien.SovereignVoiceGuardianRises",update=function(a) Cast.setCreatureEyes(c.sovereign,0.5+a*0.5) end})
 --[[
  AND ONLY THEN THE ARMY. Held back a full shot from the Sovereign on
  purpose: two reveals landing on the same frame cancel each other out. What
  comes up first reads as more lights in the cavern, and then the lights turn
  out to be in pairs.
 ]]
 add("13k_WardenLights",3.2,function() return c.sovereign.torso end,V(70,30,-100),{light="Prison",fov=64,focusOffset=V(0,0,36),pace="Slow",speaker=N.Sovereign,text="The gate is open.",cue="Alien.SovereignVoiceGateOpen",update=function(a)
  for index,sensor in env.armySensors do sensor.Transparency=1-math.clamp(a*2-index/#env.armySensors,0,1) end
  for index,warden in c.frozenWardens do Cast.setCreatureEyes(warden,math.clamp(a*2-index/#c.frozenWardens,0,1)) end
 end})
 add("13l_FirstWardenBreakout",2.6,function() return c.breakingWarden.head end,V(-4,1,-12),{light="Prison",speaker=N.Sovereign,text="The harvest may continue.",cue="Alien.SovereignVoiceHarvestContinue",update=function(a)
  Cast.removeIceShell(c.breakingWarden,a);Cast.setCreatureEyes(c.breakingWarden,a);Cast.setCreatureLimbUnfold(c.breakingWarden,a);Cast.setCreatureLimbUnfold(c.sovereign,a)
 end})
 -- 29. Clear short disaster beats with distinct actions.
 add("29a_DefendScientists",2,function() return c.soldiers[2].head end,V(5,1,-12),{light="Emergency",cue="Music.ExpeditionDisaster",enter=function()
  Cast.place(c.soldiers[2],Z.ChamberFloor+V(12,3,25),Z.ChamberFloor);Cast.act(c.soldiers[2],"Defend","Afraid",c.aegis.head.Position)
  Cast.place(c.scientists[5],Z.ChamberFloor+V(14,2.8,28),Z.ChamberFloor+V(25,3,35));Cast.act(c.scientists[5],"Help","Afraid",c.soldiers[2].head.Position)
 end})
 human("29b_SealChamber",1.5,N.Hale,"Seal the chamber!","Activation","Horrified","HaleSeal",{light="Emergency",action="Defend"})
 human("29c_NoSeal",2,N.Lyra,"There is no seal anymore.","Activation","Horrified","LyraNoSeal",{light="Emergency"})
 -- Higher: at 3.5 studs above the hull the lens sat level with the drifted
 -- snow it was looking across, close enough that the camera check read the
 -- drift as being in the way and pulled the shot in. Six studs up looks over
 -- it, which is also the better angle on a vehicle leaving.
 add("29d_EvacuationVehicles",2,function() return env.vehicles[5].model.PrimaryPart end,V(16,10,-22),{light="Exterior",fov=48,cue="Radio.CommunicationFailure",update=function(a,_,dt) Env.moveVehicle(env.vehicles[5],Z.BaseCenter+V(13,0,26),Z.BaseCenter+V(9,0,92),a,dt) end})
 add("29e_TowerFalls",1.7,function() return Z.BaseCenter+V(24,14,-20) end,V(30,6,48),{light="Exterior",cue="Impacts.FacilityCollapse",update=function(a) env.commTower:PivotTo(CF(Z.BaseCenter+V(24,0,-20))*A(0,0,-a*1.25)*CF(-Z.BaseCenter-V(24,0,-20))*env.towerBase) end})
 add("29f_InjuredEvacuation",1.8,function() return c.scientists[5].head end,V(3,1,-8),{light="Emergency",update=function(a)
  Cast.walk(c.scientists[5],Z.ChamberFloor+V(14,2.8,28),Z.ChamberFloor+V(24,2.8,37),a);Cast.act(c.scientists[5],"Help","Afraid",c.soldiers[2].head.Position)
 end})
 -- 30–32. Both faces and reaching hands at the lift, then core access gantry.
 human("30a_VossLeave",2,N.Voss,"Lyra! We have to leave!","Sacrifice","Afraid","VossLeave",{light="Emergency",enter=function()
  Cast.place(c.lyra,Z.ChamberFloor+V(24,2.8,27),Z.ChamberFloor+V(25,3,33))
  Cast.place(c.voss,Z.ChamberFloor+V(25,2.95,33),c.lyra.head.Position)
 end,action="Pull"})
 add("31a_SealFailure",1.6,function() return c.aegis.head end,V(12,1,25),{light="Emergency",speaker=N.Aegis,text="Seal failure.",cue="Aegis.VoiceLineSealFailure"})
 human("31b_CanYouStopIt",1.6,N.Lyra,"Can you stop it?","Sacrifice","Afraid","LyraStop",{light="Emergency"})
 add("31c_CoreInsufficient",1.7,function() return c.aegis.core end,V(9,0,19),{light="Emergency",speaker=N.Aegis,text="Core insufficient.",cue="Aegis.VoiceLineCoreInsufficient"})
 human("31d_BuryItAgain",2.5,N.Lyra,"Then help me bury it again.","Sacrifice","Determined","LyraBury",{light="Emergency"})
 human("30b_NotLeavingYou",2,N.Voss,"I’m not leaving you!","Sacrifice","Sad","VossStay",{light="Emergency",action="Reach"})
 human("30c_TellThem",3.2,N.Lyra,"Someone has to tell them what happened here.","Sacrifice","Sad","LyraTell",{light="Emergency",action="Reach"})
 add("30d_ClosingLiftHands",2,function() return c.voss.hands.Left end,V(-3,1,-7),{light="Emergency",cue="Machinery.EmergencyDoor",foreground={c.voss.hands.Right},update=function(a)
  Cast.act(c.voss,"Reach","Sad",c.lyra.head.Position)
  for _,door in env.liftDoors do door.part.CFrame=door.base+V(-door.side*a*5.2,0,0) end
 end})
 human("31e_ThousandsOfYears",3,N.Lyra,"You protected our world for thousands of years.","Core","Sad","LyraYears",{light="Emergency",cue="Music.LyraSacrifice",action="TouchCore",enter=function()
  local core=c.aegis.core.Position
  local platform=Kit.part({name="CoreMaintenanceGantry",size=V(10,0.3,7),color=Env.Colors.metal,material=Enum.Material.DiamondPlate,cframe=CF(core+V(0,-5,5))});platform.Parent=env.folder
  Cast.place(c.lyra,core+V(0,-2.2,3),core)
 end})
 human("31f_ProtectTogether",2.8,N.Lyra,"Let us protect it together.","Core","Determined","LyraTogether",{light="Emergency",action="Brace"})
 add("32_FinalStruggle",3,function() return c.aegis.torso end,V(40,10,62),{light="Emergency",fov=65,handheld=true,cue="Aegis.MechanicalCry",enter=function()
  c.sovereign.root.CFrame=CF(Z.ChamberFloor+V(0,-15,18));Cast.evaluate(c.sovereign)
 end,update=function(a)
  Cast.setAegisRise(c.aegis,1-a);Cast.setCreatureLimbUnfold(c.sovereign,1-a*0.7);Cast.act(c.lyra,"Brace","Determined",c.aegis.core.Position)
  c.sovereign.root.CFrame=CF(Z.ChamberFloor+V(0,-15-a*20,18));Cast.evaluate(c.sovereign)
  for _,l in env.redLights do l.Brightness=1+math.sin(a*20)^2 end
 end})
 add("33_DistantReactorExplosion",4,function() return Z.BaseCenter+V(0,45,-70) end,V(150,60,200),{light="Exterior",fov=60,pace="Fast",handheld=true,cue="Impacts.ReactorExplosion",enter=function()
  -- A layered blast instead of one flat Neon sphere: a small hot core, a
  -- larger orange fire volume, a separate thin shockwave shell that outruns
  -- it, and a falloff-based PointLight so nearby geometry lights up while
  -- the far reaches of frame stay dark - never one full-screen colour.
  local origin=Z.BaseCenter+V(0,25,-65)
  local core=Kit.ball({name="BlastCore",size=V(2,2,2),color=Color3.fromRGB(255,247,214),material=Enum.Material.Neon,position=origin})
  core.Parent=env.folder
  local inner=Kit.ball({name="BlastInnerFire",size=V(3,3,3),color=Color3.fromRGB(255,150,50),material=Enum.Material.Neon,transparency=0.1,position=origin})
  inner.Parent=env.folder
  local outer=Kit.ball({name="BlastOuterEdge",size=V(4,4,4),color=Color3.fromRGB(140,40,20),material=Enum.Material.Neon,transparency=0.5,position=origin})
  outer.Parent=env.folder
  local shock=Kit.ball({name="BlastShockwave",size=V(6,6,6),color=Color3.fromRGB(255,240,220),material=Enum.Material.Neon,transparency=0.6,position=origin})
  shock.Parent=env.folder
  local smoke=Kit.ball({name="BlastSmoke",size=V(1,1,1),color=Color3.fromRGB(58,56,54),material=Enum.Material.SmoothPlastic,transparency=1,position=origin})
  smoke.Parent=env.folder
  local flashLight=Kit.light(core,Color3.fromRGB(255,235,200),0,0)
  local sparks=Kit.dust(core,0,Color3.fromRGB(255,200,120),18)
  sparks.Lifetime=NumberRange.new(0.35,0.85)
  sparks:Emit(70)
  env.explosion={origin=origin,core=core,inner=inner,outer=outer,shock=shock,smoke=smoke,light=flashLight}
 end,update=function(a)
  local e=env.explosion
  if a<0.03 then
   -- T=0.00-0.07s: a very brief, LOCALIZED flash - the light has a real
   -- range and falls off with distance, never a full-screen white Frame.
   local t=a/0.03
   if e.light then e.light.Brightness=24*t;e.light.Range=220*t end
   e.core.Size=V(1,1,1)*Kit.lerp(2,9,t)
  elseif a<0.16 then
   -- T=0.07-0.30s: the hot core stays readable while the orange fire volume
   -- expands around it - a fireball with a structure, not a flat disc.
   local t=(a-0.03)/0.13
   e.light.Brightness=24-16*t
   e.core.Size=V(1,1,1)*Kit.lerp(9,20,t)
   e.inner.Size=V(1,1,1)*Kit.lerp(3,32,t)
   e.outer.Size=V(1,1,1)*Kit.lerp(4,44,t)
  else
   local t=math.clamp((a-0.16)/0.2,0,1)
   if e.light then e.light.Brightness=8*(1-t) end
   e.core.Size=V(1,1,1)*Kit.lerp(20,16,t)
   e.inner.Size=V(1,1,1)*Kit.lerp(32,40,t)
   e.outer.Size=V(1,1,1)*Kit.lerp(44,58,t)
  end
  if a>0.12 then
   -- T=0.10-0.50s: a separate shockwave shell visibly outruns the fireball.
   local t=math.clamp((a-0.12)/0.3,0,1)
   e.shock.Size=V(1,1,1)*Kit.lerp(6,150,t)
   e.shock.Transparency=Kit.lerp(0.55,1,t)
  end
  if a>0.1 then
   -- T=0.30-2.50s: the fireball itself fades out well before the shot ends -
   -- it never simply holds full-bright for the remaining seconds.
   local t=math.clamp((a-0.1)/0.55,0,1)
   e.core.Transparency=t
   e.inner.Transparency=Kit.lerp(0.1,1,math.min(1,t*1.15))
   e.outer.Transparency=Kit.lerp(0.5,1,math.min(1,t*0.95))
  end
  if a>0.08 then
   -- T=0.30-2.50s+: smoke rises and expands as the fireball dies - the
   -- aftermath the old flat sphere never had.
   local t=(a-0.08)/0.92
   e.smoke.Size=V(1,1,1)*Kit.lerp(5,55,math.min(1,t))
   e.smoke.Position=e.origin+V(0,math.min(1,t)*26,0)
   e.smoke.Transparency=Kit.lerp(1,0.45,math.clamp(t*2.2,0,1))
  end
 end,leave=function()
  -- Smoke and embers keep drifting after the cut instead of vanishing -
  -- Debris on the emitter/light host cleans them up once env.folder is torn
  -- down at the end of the cinematic regardless.
  if env.explosion and env.explosion.light then env.explosion.light.Range=0 end
 end})
 add("34_UnderwaterAftermath",2.5,function() return c.sovereign.head end,V(16,3,-30),{light="Prison",to=V(15,-3,-28),cue="Impacts.DebrisImpact",enter=function()
  c.sovereign.root.CFrame=CF(Z.PrisonCenter+V(0,14,5));Cast.evaluate(c.sovereign);Cast.setCreatureEyes(c.sovereign,0)
 end})
 add("35_AlienEyeStillOpen",2,function() return c.sovereign.eyes[1] end,V(0,0,-4),{light="Prison",update=function(a) Cast.setCreatureEyes(c.sovereign,a*0.2) end})
 add("36_SignalLeavesEarth",2.5,function() return env.earth end,V(100,100,280),{light="Space",fov=60,cue="Alien.SignalTransmission",update=function(a) env.signal.Position=Z.Space+V(-40+a*160,10+a*35,-a*240) end})
 add("37_AlienCarrier",3,function() return Z.Space+V(120,45,-350) end,V(170,25,145),{light="Space",fov=56,cue="Music.SpaceReveal",update=function(a)
  for i,p in env.carrierLights do p.BackgroundTransparency=1-math.clamp(a*2-i/#env.carrierLights,0,1) end
 end})
 add("38_Title",3.5,function() return Z.Space end,V(0,0,20),{black=true,light="Space",cue="Music.TitleTheme",enter=function() ui.setTitleCard({"THE DAY THE SKY BROKE"},"Title") end,leave=function() ui.setTitleCard(nil) end})
 local total=0
 for _,shot in shots do total+=shot.duration end
 env.folder:SetAttribute("TimelineSeconds",total)
 print(`[Opening] {#shots} shots; {total} seconds`)
 return shots
end
return Sequences
