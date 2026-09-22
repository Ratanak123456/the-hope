--!nonstrict
-- The existing opening's single explicit edit. Durations drive everything,
-- including subtitles: no asset loading or Sound.TimeLength dependencies.
local Config=require(game:GetService("ReplicatedStorage").Shared.Config)
local Env=require(script.Parent.Env)
local Cast=require(script.Parent.Cast)
local Kit=require(script.Parent.Kit)
local Camera=require(script.Parent.Camera)
local Light=require(script.Parent.Lighting)
local Performance=require(script.Parent.PerformanceDirector)
local Sequences={}
local N=Config.Cinematic.Names
local Z=Env.Zones
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
 Door={origin="Door",marks={
  {at=V(-1,2.8,4),look=V(0,6,0),job="Idle"},
  {at=V(3,2.95,9),look=V(0,6,0),job="Idle"},
  {at=V(-4,3.1,10),look=V(0,6,0),job="Authority"},
 }},
 Prison={origin="PrisonCenter",marks={
  {at=V(-9,2.8,-42),look=V(0,10,0),job="Idle"},
  {at=V(-5,2.95,-40),look=V(0,10,0),job="Scan"},
  {at=V(0,3.1,-43),look=V(0,10,0),job="Authority"},
 }},
 Chamber={origin="ChamberFloor",marks={
  {at=V(-5,2.8,24),look=V(0,14,0),job="Idle"},
  {at=V(-1,2.95,27),look=V(0,14,0),job="Idle"},
  {at=V(5,3.1,25),look=V(0,14,0),job="Authority"},
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
  table.insert(c.soldiers,Cast.buildSoldier(env.folder,CF(Z.BaseCenter+V(-16+i*4,3,-13-i%2*5)),rng,i))
 end
 for i=1,5 do
  local w=Cast.buildHuman(env.folder,{name=`ExcavationWorker{i}`,kind="Worker",seed=i+30,cframe=CF(Z.BaseCenter+V(-13+i*5,2.8,-14)),scale=0.94+i%3*0.04,skin=Color3.fromRGB(114+i*19,84+i*14,66+i*12),coat=Env.Colors.metal,trim=Env.Colors.orange,pants=Env.Colors.dark,headwear="Helmet"})
  table.insert(c.workers,w)
 end
 c.aegis=Cast.buildAegisZero(env.folder,CF(Z.ChamberFloor+V(0,15,-8))*A(0,math.pi,0),10)
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
  h.home=h.root.CFrame;Cast.setActivity(h,(i%2==0 and "OperateDrill" or "CarryCase"));Cast.lookAt(h,Z.BaseCenter+V(0,2,-28))
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
   if op.light=="Exterior" then Light.exterior() elseif op.light=="Command" then Light.commandTent() elseif op.light=="Door" then Light.ancientInterior() elseif op.light=="Prison" then Light.prison() elseif op.light=="Emergency" then Light.emergency() elseif op.light=="Space" then Light.blackout() else Light.chamber(op.energy or 0) end
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
  op.light=op.light or (stageName=="Command" and "Command" or stageName=="Prison" and "Prison" or "Chamber")
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
    ]]
    local focus=subject.head.Position-V(0,spec.focusDrop,0)
    local toward=(focus-other.head.Position)
    local flat=V(toward.X,0,toward.Z)
    if flat.Magnitude<0.5 then flat=V(facing.X,0,facing.Z) end
    flat=flat.Unit
    local lateral=V(-flat.Z,0,flat.X)*side*1.9
    shot.from=(other.head.Position-flat*3.4+lateral+V(0,0.5,0))-focus
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
 -- 07. Insert montage; each insert has a specific prop or action.
 add("07a_DrillRotates",2,function() return env.drill:GetChildren()[1] end,V(5,1,7),{light="Exterior",cue="Machinery.DrillLoop",update=function(_,t) env.drill:PivotTo(env.drillBase*A(0,t*6,0));env.drillDust.Rate=35 end,leave=function() env.drillDust.Rate=0 end})
 -- Ahead of the drill head, not behind it: the HeavyDrill rig is parked at
 -- z=-23 and a camera five studs on that side of the contact point was inside
 -- its cab, which the unstick fallback then "corrected" to somewhere else
 -- entirely. From -34 the shot has the excavation between it and the rig.
 add("07b_IceFragments",1.3,function() return Z.BaseCenter+V(0,3.2,-28) end,V(5,1.6,-6),{light="Exterior",cue="Impacts.IceCracking",enter=function() env.drillDust:Emit(35) end})
 add("07c_SampleCollection",1.8,function() return c.workers[1].head end,V(2,1,-6),{light="Exterior",enter=function() Cast.act(c.workers[1],"Scan","Focused",c.workers[1].scanner.Position) end})
 add("07d_CompassAnomaly",1.5,function() return c.workers[1].scanner end,V(0,1.4,-1.4),{light="Exterior",fov=38,update=function(_,t) c.workers[1].scanner.Color=Env.Colors.cyan:Lerp(Env.Colors.orange,math.abs(math.sin(t*9))) end})
 add("07e_SkippingClock",1.2,function() return env.signalDisplay end,V(0,0,-5),{light="Command",update=function(_,t) env.pulses[1].Size=V(0.25,0.5+(math.floor(t*12)%3)*0.5,0.08) end})
 add("07f_MetalUnderIce",1.8,function() return Z.BaseCenter+V(45,30,-32) end,V(5,1,17),{light="Exterior",cue="Machinery.DrillHitsMetal"})
 -- 08–09. Symbol, face, enormous doorway, then architectural scale.
 add("08a_LyraClearsSymbol",2,function() return env.door.symbol end,V(3,0.8,7),{stage="Door",light="Door",enter=function() Cast.act(c.lyra,"ClearIce","Curious",env.door.symbol.Position) end})
 human("08b_OrangeRecognition",1.5,N.Lyra,"","Door","Amazed",nil,{light="Door",action="ClearIce",enter=function() env.door.symbol.Material=Enum.Material.Neon end})
 add("08c_AncientDoorOpens",3,function() return Z.Door+V(0,10,0) end,V(2,1,34),{light="Door",fov=55,cue="Machinery.AncientDoorOpening",update=function(a)
  env.door.slideLeft(env.door.leftBase+V(-a*10,0,0));env.door.slideRight(env.door.rightBase+V(a*10,0,0))
 end})
 add("09_EnteringStructure",3,function() return c.lyra.head end,V(4,2,12),{light="Door",fov=62,update=function(a)
  Cast.walk(c.lyra,Z.Door+V(-1,2.8,4),Z.Door+V(-1,2.8,-8),a)
  Cast.walk(c.voss,Z.Door+V(3,2.95,9),Z.Door+V(3,2.95,-3),a)
 end})
 -- 10–13. Foot -> hands AND chains -> complete kneeling silhouette.
 -- The focus is lifted clear of the floor. Aegis Zero's foot sits with its
 -- centre exactly at chamber-floor level (and some of its toe geometry below
 -- it - see AGENT.md's note on the Guardian rig, which is a separate job), so
 -- aiming at the part's own centre put the focal point in the floor and the
 -- camera check kept relocating the shot. Framing just above it shows the
 -- foot AND the floor it rests on, which is the reveal this shot is for.
 add("10_AegisFoot",2,function() return c.aegis.model:FindFirstChild("LeftFoot") end,V(10,3,14),{stage="Chamber",cue="Music.ScientificDiscovery",pace="Slow",focusOffset=V(0,2.5,0)})
 add("11_HandsHoldChains",3,function() return c.aegis.model:FindFirstChild("RightHand") end,V(12,3,17),{fov=58,focusOffset=V(0,-3,0),cue="Machinery.ChainTension",pace="Slow"})
 add("12_FullKneelingGuardian",3.5,function() return c.aegis.torso end,V(50,10,84),{fov=57,to=V(57,14,94),focusOffset=V(0,-4,0),pace="Slow"})
 human("13a_VossAwe",1.5,N.Voss,"My God.","Chamber","Amazed","VossAwe")
 human("13b_HaleAge",1.5,N.Hale,"How old is it?","Chamber","Amazed","HaleAge")
 human("13c_VossIce",2.5,N.Voss,"The surrounding ice is thousands of years old.","Chamber","Amazed","VossIce")
 human("13d_HaleWeapon",3.5,N.Hale,"Then we have discovered the greatest weapon in human history.","Chamber","Focused","HaleWeapon",{reactOn=N.Lyra})
 human("13e_LyraBuried",2.3,N.Lyra,"No. It wasn’t buried here.","Chamber","Concerned","LyraBuried")
 human("13f_LyraRemain",2,N.Lyra,"It chose to remain.","Chamber","Concerned","LyraRemain")
 -- 14–15. Pictograms carry story before the prison reveal.
 add("14a_ClearWarning",2,function() return env.mythWall end,V(3,0,16),{cue="Music.WarningTension",enter=function()
  Cast.place(c.lyra,Z.ChamberFloor+V(-38,2.8,30),env.mythWall.Position);Cast.act(c.lyra,"ClearIce","Concerned",env.mythWall.Position)
 end})
 human("14b_VossRead",1.3,N.Voss,"Can you read it?","Chamber","Concerned","VossRead")
 human("14c_LyraSome",1,N.Lyra,"Some of it.","Chamber","Afraid","LyraSome")
 add("14d_GuardianNotBuried",2.3,function() return env.reliefs[1] end,V(0,0,6),{speaker=N.Lyra,text="The Guardian is not buried.",voice="LyraNotBuried"})
 human("14e_GuardianIsSeal",2.5,N.Lyra,"The Guardian is the seal.","Chamber","Afraid","LyraSeal")
 add("15_ChainImpact",2,function() return c.aegis.model:FindFirstChild("LeftHand") end,V(-9,0,12),{cue="Impacts.UndergroundImpact",handheld=true,enter=function()
  for i,h in c.scientists do Cast.react(h,"Afraid",c.aegis.head.Position,0.3+(i%2)*0.2) end
  for _,h in {c.lyra,c.voss,c.hale} do Cast.react(h,"Afraid",c.aegis.head.Position,0.9) end
 end})
 -- 16–19. Arrival on the lower viewing ledge; anatomical partials then wide.
 add("16_PrisonDescent",2.5,function() return c.lyra.head end,V(-5,3,-12),{stage="Prison",light="Prison",enter=function()
  Cast.place(c.soldiers[1],Z.PrisonCenter+V(-12,3,-38),c.sovereign.head.Position)
 end,update=function(a) Cast.walk(c.lyra,Z.PrisonCenter+V(-9,5,-48),Z.PrisonCenter+V(-9,2.8,-42),a) end})
 add("17a_GiantClaw",1.5,function() return c.sovereign.model:FindFirstChild("RightHand") end,V(-12,2,-16),{light="Prison"})
 add("17b_FoldedLimbs",1.5,function() return c.sovereign.model:FindFirstChild("RightForearm") end,V(12,3,-22),{light="Prison"})
 add("17c_ClosedEyes",1.5,function() return c.sovereign.head end,V(4,1,-17),{light="Prison"})
 add("18_PrisonAndFrozenArmy",3,function() return c.sovereign.torso end,V(75,38,-110),{light="Prison",fov=63,focusOffset=V(0,0,25),pace="Slow"})
 human("18b_SoldierUnderstands",3,N.Soldier,"The machine wasn’t protecting itself from them.","Prison","Afraid","SoldierPrison")
 human("18c_ProtectingUs",1.7,N.Lyra,"It was protecting us.","Prison","Afraid","LyraUs")
 human("18d_ScannerQuiet",2.6,N.Voss,"My scanner shows no biological activity.","Prison","Concerned","VossBiology",{action="Scan"})
 add("19_FingerMovement",1.5,function() return c.sovereign.model:FindFirstChild("RightHand") end,V(3,1,-6),{light="Prison",cue="Alien.IceMovement",update=function(a) c.sovereign.poses.RightWrist=A(-0.2*a,0,0);Cast.evaluate(c.sovereign) end})
 human("19b_ItIsWaking",3,N.Lyra,"The ice is moving because it is waking up.","Prison","Afraid","LyraWaking")
 -- 20. Shot/reverse-shot escalation; preserve every essential argument line.
 human("20a_Disconnect",2.7,N.Lyra,"Disconnect everything. We need to leave.","Activation","Angry","LyraDisconnect")
 human("20b_HaleDiscovery",4.5,N.Hale,"We did not cross half the planet to abandon humanity’s greatest discovery.","Activation","Angry","HaleDiscovery",{reactOn=N.Lyra})
 human("20c_HoldingCreature",2.7,N.Lyra,"It is holding the creature below us.","Activation","Angry","LyraCreature")
 human("20d_OnlyDefense",3.8,N.Hale,"This machine may be the only defense humanity will ever need.","Activation","Determined","HaleDefense")
 human("20e_AlreadyDefending",2.2,N.Lyra,"It is already defending us.","Activation","Angry","LyraDefending")
 human("20f_NotACode",2,N.Lyra,"It isn’t an activation code.","Activation","Afraid","LyraCode")
 human("20g_WhatIsIt",1.4,N.Hale,"Then what is it?","Activation","Concerned","HaleCode")
 human("20h_NewGuardian",2.7,N.Lyra,"It is asking for a new guardian.","Activation","Horrified","LyraGuardian")
 -- 21–28. Physical machine activation, opposition, breach, alien response.
 add("21_CoreReceivesPower",2,function() return c.aegis.core end,V(8,1,18),{energy=0.3,cue="Aegis.CoreActivation",enter=function()
  for i,h in c.scientists do Cast.react(h,"Surprised",c.aegis.core.Position,0.35+(i%3)*0.16) end
  for _,h in {c.lyra,c.voss,c.hale} do Cast.react(h,"Amazed",c.aegis.core.Position,0.55) end
 end,update=function(a) Cast.setAegisAwaken(c.aegis,a*0.3);Light.chamber(a*0.3) end})
 add("22a_FingersTighten",1.5,function() return c.aegis.model:FindFirstChild("LeftHand") end,V(-8,1,10),{energy=0.4,cue="Aegis.ServoMovement",update=function(a) Cast.setAegisAwaken(c.aegis,0.3+a*0.15);Light.chamber(0.3+a*0.15) end})
 add("22b_ShoulderUnlocks",1.5,function() return c.aegis.model:FindFirstChild("RightUpperArm") end,V(12,2,18),{energy=0.5,cue="Aegis.ArmorMovement",update=function(a) Cast.setAegisAwaken(c.aegis,0.45+a*0.15);Light.chamber(0.45+a*0.15) end})
 add("22c_HeadAndEyes",2.5,function() return c.aegis.head end,V(9,0,22),{energy=0.7,cue="Aegis.HeadMovement",update=function(a) Cast.setAegisAwaken(c.aegis,0.6+a*0.4);Light.chamber(0.6+a*0.4) end})
 human("22d_WeDidIt",1.4,N.Hale,"We did it.","Activation","Amazed","HaleSuccess",{energy=1,reactOn=N.Lyra})
 human("23_LyraNo",1.2,N.Lyra,"No.","Activation","Horrified","LyraNo",{energy=1})
 human("23b_FightingActivation",3,N.Lyra,"Turn off the power! It is fighting the activation!","Activation","Horrified","LyraPower",{energy=1})
 add("24_SealSeparates",2,function() return Z.ChamberFloor+V(0,0.5,4) end,V(0,38,17),{energy=1,fov=57,cue="Machinery.ChainTension",update=function(a) Env.openSeal(env,a);Cast.setAegisRise(c.aegis,a) end})
 add("25_FirstChainBreak",1.5,function() return c.aegis.model:FindFirstChild("RightHand") end,V(16,3,14),{light="Emergency",cue="Machinery.ChainBreak",enter=function() Cast.breakChain(c.aegis,2,os.clock());Cast.act(c.hale,"Stumble","Horrified",c.aegis.head.Position) end})
 add("25b_SecondChainBreak",1.2,function() return c.aegis.model:FindFirstChild("LeftHand") end,V(-14,2,15),{light="Emergency",cue="Aegis.MechanicalCry",enter=function() Cast.breakChain(c.aegis,1,os.clock()) end})
 add("26_SovereignEyeOpens",2,function() return c.sovereign.eyes[1] end,V(1,0,-5),{light="Prison",cue="Alien.EyeActivation",update=function(a) Cast.setCreatureEyes(c.sovereign,a*0.5);Cast.removeIceShell(c.sovereign,a) end})
 add("26b_GuardianRises",2,function() return c.sovereign.head end,V(3,0,-18),{light="Prison",speaker=N.Sovereign,text="The Guardian rises.",cue="Alien.SovereignVoiceGuardianRises",update=function(a) Cast.setCreatureEyes(c.sovereign,0.5+a*0.5) end})
 add("27_WardenArmyActivates",2,function() return c.sovereign.torso end,V(70,30,-100),{light="Prison",fov=64,focusOffset=V(0,0,36),speaker=N.Sovereign,text="The gate is open.",cue="Alien.SovereignVoiceGateOpen",update=function(a)
  for i,p in env.armySensors do p.Transparency=1-math.clamp(a*2-i/#env.armySensors,0,1) end
  for i,w in c.frozenWardens do Cast.setCreatureEyes(w,math.clamp(a*2-i/#c.frozenWardens,0,1)) end
 end})
 add("28_FirstWardenBreakout",2.5,function() return c.breakingWarden.head end,V(-4,1,-12),{light="Prison",speaker=N.Sovereign,text="The harvest may continue.",cue="Alien.SovereignVoiceHarvestContinue",update=function(a)
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
  Cast.walk(c.scientists[5],Z.ChamberFloor+V(14,2.8,28),Z.ChamberFloor+V(22,2.8,34),a);Cast.act(c.scientists[5],"Help","Afraid",c.soldiers[2].head.Position)
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
 add("30d_ClosingLiftHands",2,function() return c.voss.hands.Left end,V(-3,1,-7),{light="Emergency",cue="Machinery.EmergencyDoor",update=function(a)
  Cast.act(c.voss,"Reach","Sad",c.lyra.head.Position)
  for _,door in env.liftDoors do door.part.CFrame=door.base+V(-door.side*a*5.2,0,0) end
 end})
 human("31e_ThousandsOfYears",3,N.Lyra,"You protected our world for thousands of years.","Core","Sad","LyraYears",{light="Emergency",cue="Music.LyraSacrifice",action="TouchCore",enter=function()
  local core=c.aegis.core.Position
  local platform=Kit.part({name="CoreMaintenanceGantry",size=V(10,0.3,7),color=Env.Colors.metal,material=Enum.Material.DiamondPlate,cframe=CF(core+V(0,-5,5))});platform.Parent=env.folder
  Cast.place(c.lyra,core+V(0,-2.2,3),core)
 end})
 human("31f_ProtectTogether",2.8,N.Lyra,"Let us protect it together.","Core","Determined","LyraTogether",{light="Emergency",action="Brace"})
 add("32_FinalStruggle",3,function() return c.aegis.torso end,V(58,16,88),{light="Emergency",fov=65,handheld=true,cue="Aegis.MechanicalCry",enter=function()
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
