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
function Sequences.buildCast(env): CastState
 local o=Z.Command
 local c={scientists={},soldiers={},workers={},frozenWardens={},allHumans={}}
 c.lyra=Cast.buildLyra(env.folder,CF(o+V(-3,2.8,1)))
 c.voss=Cast.buildVoss(env.folder,CF(o+V(3,2.95,1)))
 c.hale=Cast.buildHale(env.folder,CF(o+V(0,3.1,7)))
 local rng=Kit.rng(20260915)
 for i=1,8 do
  local p=i<=4 and Z.Command+V(i%2==0 and -7 or 7,2.8,-6+math.floor(i/2)*5) or Z.BaseCenter+V(-25+i*6,2.8,22+i*3)
  table.insert(c.scientists,Cast.buildScientist(env.folder,CF(p),rng,i))
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
  h.home=h.root.CFrame;Cast.setActivity(h,(i%3==0 and "TypingConsole" or i%3==1 and "CheckingTablet" or "Monitoring"));Cast.lookAt(h,Z.Command+V(0,4,-3))
 end
 for i,h in c.workers do
  h.home=h.root.CFrame;Cast.setActivity(h,(i%2==0 and "OperateDrill" or "CarryCase"));Cast.lookAt(h,Z.BaseCenter+V(0,2,-28))
 end
 for i,h in c.soldiers do
  h.home=h.root.CFrame;Cast.setActivity(h,(i%3==0 and "Radio" or i%3==1 and "SecurityWatch" or "PatrolIdle"));Cast.lookAt(h,Z.BaseCenter+V(0,3,-28))
 end
 for _,h in {c.lyra,c.voss,c.hale} do h.home=h.root.CFrame;Cast.act(h,"Idle","Focused",Z.Command+V(0,4,-3)) end
 c.performance=Performance.new(c.allHumans)
 return c
end
function Sequences.build(env,c,ui): {Shot}
 local shots={}
 Camera.configure(env)
 local scene=""
 local function stage(name)
  if name==scene then return end
  scene=name
  local o=name=="Command" and Z.Command or name=="Door" and Z.Door or name=="Prison" and Z.PrisonCenter or Z.ChamberFloor
  local positions=name=="Command" and {V(-3,2.8,1),V(3,2.95,1),V(0,3.1,7)} or name=="Door" and {V(-1,2.8,4),V(3,2.95,9),V(-4,3.1,10)} or name=="Prison" and {V(-9,2.8,-42),V(-5,2.95,-40),V(0,3.1,-43)} or {V(-5,2.8,24),V(-1,2.95,27),V(5,3.1,25)}
  for i,h in {c.lyra,c.voss,c.hale} do Cast.place(h,o+positions[i],o+V(0,4,0));Cast.act(h,"Idle","Focused",o+V(0,8,0)) end
 end
 local byName={[N.Lyra]=c.lyra,[N.Voss]=c.voss,[N.Hale]=c.hale,[N.Soldier]=c.soldiers[1]}
 local function add(name,duration,subject,from,options)
  local op=options or {}
  local shot={name=name,duration=duration,subject=subject,from=from,to=op.to or from+V(0,0,-0.4),fov=op.fov or 46,focusOffset=op.focusOffset,handheld=op.handheld,pace=op.pace or (op.handheld and "Fast") or nil,primarySubject=op.primary or name,secondarySubject=op.secondary or "Expedition",purpose=op.purpose or name,transition=op.transition or "Cut",lighting=op.light or "Chamber",expression=op.expression or "Focused",black=op.black}
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
  shot.update=function(state,alpha)
   if op.update then op.update(alpha,alpha*duration) end
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
 local function human(name,dur,who,text,stageName,emotion,voice,extra)
  local op=extra or {}
  local reactOn=op.reactOn;op.reactOn=nil
  op.speaker=who;op.text=text;op.stage=stageName;op.expression=emotion;op.voice=voice
  op.light=op.light or (stageName=="Command" and "Command" or stageName=="Prison" and "Prison" or "Chamber")
  -- reactOn: frame a LISTENER's face instead of the speaker's, for the rare
  -- pivotal line where the reaction matters more than the delivery (e.g. the
  -- moment before Lyra's "No.") - never every line, or it stops reading as
  -- deliberate.
  local h=reactOn and byName[reactOn] or byName[who]
  local seed=0
  for i=1,#name do seed=(seed*31+string.byte(name,i))%997 end
  local side=speakerSide[who] or 1
  local distance=6+ (seed%5)*0.5
  local shot=add(name,dur,function() return h.head end,V(2,0.2,-7),op)
  local enter=shot.enter
  shot.enter=function()
   local state=enter()
   local facing=h.root.CFrame.LookVector
   shot.from=facing*distance+h.root.CFrame.RightVector*side*2.1+V(0,0.15,0)
   shot.to=shot.from*0.93
   return state
  end
  return shot
 end
 -- 01–04. Radio bridges to the convoy rather than holding an empty exterior.
 add("01_BlackRadio",5,function() return Z.BaseCenter end,V(0,10,30),{black=true,light="Exterior",cue="Radio.ExpeditionTransmission",update=function(_,t)
  if t>=0.6 then ui.setSubtitle(N.Radio,"Arctic Expedition Seven to Command. We have reached the signal’s origin.") end
 end})
 add("02_ArcticEstablishing",4,function() return env.vehicles[1].model.PrimaryPart end,V(65,48,80),{light="Exterior",fov=62,to=V(52,42,70),speaker=N.Radio,text="There is something beneath the ice.",cue="Music.ArcticMystery",update=function(a)
  Env.moveVehicle(env.vehicles[1],Z.BaseCenter+V(0,1.6,105),Z.BaseCenter+V(0,1.6,82),a)
  Env.moveVehicle(env.vehicles[2],Z.BaseCenter+V(0,1.6,128),Z.BaseCenter+V(0,1.6,105),a)
 end})
 add("03_ConvoyTracking",3,function() return env.vehicles[1].model.PrimaryPart end,V(12,2,-9),{light="Exterior",cue="Machinery.VehicleTracks",update=function(a)
  Env.moveVehicle(env.vehicles[1],Z.BaseCenter+V(0,1.6,82),Z.BaseCenter+V(0,1.6,67),a)
 end})
 add("04_WorkingBaseReveal",3.5,function() return Z.BaseCenter+V(0,18,-20) end,V(85,20,100),{light="Exterior",fov=63,to=V(78,32,95),pace="Slow",enter=function() ui.setTitleCard({"THE NORTH POLE","FIFTEEN YEARS BEFORE THE INVASION"}) end})
 -- 05–06. Cut on every speaker. Practical screen glow and readable faces.
 add("05_ThreePulses",2,function() return env.signalDisplay end,V(1,0,-6),{stage="Command",light="Command",cue="Radio.SignalPulse",update=function(_,t)
  for i,p in env.pulses do p.Size=V(0.25,0.3+math.max(0,math.sin(t*5-i*1.7))*1.5,0.08) end
 end})
 human("06a_HaleReport",1.2,N.Hale,"Report.","Command","Focused","HaleReport")
 human("06b_VossSignal",6,N.Voss,"The signal is approximately two kilometers beneath us. Whatever is producing it is larger than anything humanity has ever built.","Command","Focused","VossSignal",{action="Scan"})
 human("06c_HaleSpacecraft",1.3,N.Hale,"A spacecraft?","Command","Curious","HaleSpacecraft")
 human("06d_VossPossibly",1,N.Voss,"Possibly.","Command","Curious","VossPossibly")
 human("06e_LyraCalling",2,N.Lyra,"It isn’t calling us.","Command","Concerned","LyraCalling")
 human("06f_HaleQuestion",1.5,N.Hale,"Then what is it doing?","Command","Focused","HaleQuestion")
 human("06g_LyraUnknown",1.5,N.Lyra,"I don’t know yet.","Command","Concerned","LyraUnknown")
 add("06h_DeepPulseReaction",1.5,function() return c.lyra.head end,V(4,2,-11),{light="Command",cue="Environment.DeepIceImpact",enter=function()
  for i,h in c.scientists do Cast.react(h,"Concerned",env.signalDisplay.Position,0.25+(i%3)*0.12) end
  for _,h in {c.lyra,c.voss,c.hale} do Cast.react(h,"Concerned",env.signalDisplay.Position,0.75) end
 end})
 human("06i_BeginDrilling",1.5,N.Hale,"Begin drilling.","Command","Determined","HaleDrill")
 -- 07. Insert montage; each insert has a specific prop or action.
 add("07a_DrillRotates",2,function() return env.drill:GetChildren()[1] end,V(5,1,7),{light="Exterior",cue="Machinery.DrillLoop",update=function(_,t) env.drill:PivotTo(env.drillBase*A(0,t*6,0));env.drillDust.Rate=35 end,leave=function() env.drillDust.Rate=0 end})
 add("07b_IceFragments",1.3,function() return Z.BaseCenter+V(0,1,-28) end,V(4,1,5),{light="Exterior",cue="Impacts.IceCracking",enter=function() env.drillDust:Emit(35) end})
 add("07c_SampleCollection",1.8,function() return c.workers[1].head end,V(2,1,-6),{light="Exterior",enter=function() Cast.act(c.workers[1],"Scan","Focused",c.workers[1].scanner.Position) end})
 add("07d_CompassAnomaly",1.5,function() return c.workers[1].scanner end,V(0,1.4,-1.4),{light="Exterior",fov=38,update=function(_,t) c.workers[1].scanner.Color=Env.Colors.cyan:Lerp(Env.Colors.orange,math.abs(math.sin(t*9))) end})
 add("07e_SkippingClock",1.2,function() return env.signalDisplay end,V(0,0,-5),{light="Command",update=function(_,t) env.pulses[1].Size=V(0.25,0.5+(math.floor(t*12)%3)*0.5,0.08) end})
 add("07f_MetalUnderIce",1.8,function() return Z.BaseCenter+V(45,30,-32) end,V(5,1,17),{light="Exterior",cue="Machinery.DrillHitsMetal"})
 -- 08–09. Symbol, face, enormous doorway, then architectural scale.
 add("08a_LyraClearsSymbol",2,function() return env.door.symbol end,V(3,0.8,7),{stage="Door",light="Door",enter=function() Cast.act(c.lyra,"ClearIce","Curious",env.door.symbol.Position) end})
 human("08b_OrangeRecognition",1.5,N.Lyra,"","Door","Amazed",nil,{light="Door",action="ClearIce",enter=function() env.door.symbol.Material=Enum.Material.Neon end})
 add("08c_AncientDoorOpens",3,function() return Z.Door+V(0,10,0) end,V(2,1,34),{light="Door",fov=55,cue="Machinery.AncientDoorOpening",update=function(a)
  env.door.left:PivotTo(env.door.leftBase+V(-a*10,0,0));env.door.right:PivotTo(env.door.rightBase+V(a*10,0,0))
 end})
 add("09_EnteringStructure",3,function() return c.lyra.head end,V(4,2,12),{light="Door",fov=62,update=function(a)
  Cast.walk(c.lyra,Z.Door+V(-1,2.8,4),Z.Door+V(-1,2.8,-8),a)
  Cast.walk(c.voss,Z.Door+V(3,2.95,9),Z.Door+V(3,2.95,-3),a)
 end})
 -- 10–13. Foot -> hands AND chains -> complete kneeling silhouette.
 add("10_AegisFoot",2,function() return c.aegis.model:FindFirstChild("LeftFoot") end,V(10,3,14),{stage="Chamber",cue="Music.ScientificDiscovery",pace="Slow"})
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
 add("17a_GiantClaw",1.5,function() return c.sovereign.model:FindFirstChild("Claw1") end,V(-12,2,-16),{light="Prison"})
 add("17b_FoldedLimbs",1.5,function() return c.sovereign.model:FindFirstChild("Limb3") end,V(12,3,-22),{light="Prison"})
 add("17c_ClosedEyes",1.5,function() return c.sovereign.head end,V(4,1,-17),{light="Prison"})
 add("18_PrisonAndFrozenArmy",3,function() return c.sovereign.torso end,V(75,38,-110),{light="Prison",fov=63,focusOffset=V(0,0,25),pace="Slow"})
 human("18b_SoldierUnderstands",3,N.Soldier,"The machine wasn’t protecting itself from them.","Prison","Afraid","SoldierPrison")
 human("18c_ProtectingUs",1.7,N.Lyra,"It was protecting us.","Prison","Afraid","LyraUs")
 human("18d_ScannerQuiet",2.6,N.Voss,"My scanner shows no biological activity.","Prison","Concerned","VossBiology",{action="Scan"})
 add("19_FingerMovement",1.5,function() return c.sovereign.model:FindFirstChild("Talon1_1") end,V(3,1,-6),{light="Prison",cue="Alien.IceMovement",update=function(a) c.sovereign.poses.Talon1_1=A(-0.2*a,0,0);Cast.evaluate(c.sovereign) end})
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
 add("29d_EvacuationVehicles",2,function() return env.vehicles[5].model.PrimaryPart end,V(14,3,-18),{light="Exterior",cue="Radio.CommunicationFailure",update=function(a) Env.moveVehicle(env.vehicles[5],Z.BaseCenter+V(14,1.6,70),Z.BaseCenter+V(14,1.6,104),a) end})
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
 add("38_Title",3.5,function() return Z.Space end,V(0,0,20),{black=true,light="Space",cue="Music.TitleTheme",enter=function() ui.setTitleCard({"THE DAY THE SKY BROKE"}) end,leave=function() ui.setTitleCard(nil) end})
 local total=0
 for _,shot in shots do total+=shot.duration end
 env.folder:SetAttribute("TimelineSeconds",total)
 print(`[Opening] {#shots} shots; {total} seconds`)
 return shots
end
return Sequences
