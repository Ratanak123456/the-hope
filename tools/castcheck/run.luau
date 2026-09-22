--!nonstrict
-- Offline verification of the North Pole cinematic cast.
--
-- Runs the real Cast.lua against a shimmed Roblox so the questions the user
-- actually asked about ("do these people stand up properly?") get numeric
-- answers before anyone opens Studio. Checks are geometric, taken off the
-- solved rig, never off the pose tables that produced it.

local Cast=MOD.Cast
local FLOOR=9500
RBX.floorY=FLOOR
RBX.studio=false -- the in-rig Studio validator is re-implemented here, with numbers

local V=Vector3.new
local failures,checks=0,0
local function check(name,ok,detail)
 checks+=1
 if not ok then
  failures+=1
  print(string.format("FAIL  %-58s %s",name,detail or ""))
 end
end
local function near(a,b,tol) return math.abs(a-b)<=tol end

local root=RBX.newInstance("Folder")
rawset(root,"Name","CastCheck")
root.Parent=RBX.workspace

--------------------------------------------------------------------------------
-- The cast, built exactly the way Sequences.buildCast builds it.
--------------------------------------------------------------------------------
Cast.reset()
local people={}
local function add(label,human) table.insert(people,{label=label,r=human}) end
add("Lyra",Cast.buildLyra(root,CFrame.new(V(0,FLOOR+2.8,0))))
add("Voss",Cast.buildVoss(root,CFrame.new(V(4,FLOOR+2.95,0))))
add("Hale",Cast.buildHale(root,CFrame.new(V(8,FLOOR+3.1,0))))
local rng=MOD.Kit.rng(20260915)
for i=1,8 do
 add("Scientist"..i,Cast.buildScientist(root,CFrame.new(V(-6-i*2,FLOOR+2.8,6)),rng,i))
 add("Soldier"..i,Cast.buildSoldier(root,CFrame.new(V(6+i*2,FLOOR+3,6)),rng,i))
end
for i=1,5 do
 add("Worker"..i,Cast.buildHuman(root,{name="Worker"..i,kind="Worker",seed=i+30,cframe=CFrame.new(V(-4+i*3,FLOOR+2.8,-8)),
  scale=0.94+i%3*0.04,skin=Color3.fromRGB(150,110,80),coat=MOD.Env.Colors.metal,trim=MOD.Env.Colors.orange,pants=MOD.Env.Colors.dark,headwear="Helmet"}))
end

--------------------------------------------------------------------------------
-- Rig measurements
--------------------------------------------------------------------------------
local function part(r,name) return r.model:FindFirstChild(name) end
local function soleY(r,side)
 local foot=part(r,side.."Foot")
 return foot.Position.Y-foot.Size.Y/2
end
-- A joint's pivot in world space: Part1.CFrame*C1 is exactly the frame the
-- Motor6D rotates about (Part1.CFrame = Part0.CFrame*C0*Transform*C1^-1).
local function pivot(r,jointName)
 local motor=r.joints[jointName]
 return (motor.Part1.CFrame*motor.C1).Position
end
local function localTo(r,worldPoint) return r.root.CFrame:PointToObjectSpace(worldPoint) end

print("== sole drop (measured off the built rig, must scale with the character) ==")
for _,entry in people do
 local r=entry.r
 check(entry.label.." sole drop matches scale",near(Cast.soleDrop(r),2.81*r.scale,0.02),
  string.format("measured %.4f, expected %.4f (scale %.3f)",Cast.soleDrop(r),2.81*r.scale,r.scale))
end
print(string.format("   scales %.2f .. %.2f, sole drop %.3f .. %.3f",
 people[1].r.scale,people[3].r.scale,Cast.soleDrop(people[1].r),Cast.soleDrop(people[3].r)))

print("== grounded on build (the authored Y is a hint, the floor is the answer) ==")
for _,entry in people do
 local r=entry.r
 local low=math.min(soleY(r,"Left"),soleY(r,"Right"))
 check(entry.label.." stands on the floor",near(low,FLOOR,0.02),string.format("lowest sole %.4f, floor %.1f (%.3f off)",low,FLOOR,low-FLOOR))
end

--------------------------------------------------------------------------------
-- Standing invariants, every phase, over time.
--------------------------------------------------------------------------------
local STANDING={"Idle","Listen","Speak","Warning","Authority","Scan","ClearIce","CheckingTablet",
 "TypingConsole","WritingNotes","AdjustingCable","OperateDrill","Monitoring","SecurityWatch",
 "PatrolIdle","Radio","CheckWrist","CarryCase","Reach","Pull","TouchCore","Defend","Brace",
 "StepBack","Flinch","Stumble","Help"}

print("== standing invariants across "..#STANDING.." phases x "..#people.." people ==")
local worstFoot,worstFootWhere=0,""
local worstUp,worstUpWhere=1,""
for _,phaseName in STANDING do
 for _,entry in people do
  local r=entry.r
  Cast.act(r,phaseName,"Focused",r.head.Position+V(0,0,-6))
  r.lineStart=0
  for frame=1,14 do
   local now=frame*0.1
   -- reactionUntil would time these out; re-assert the phase under test.
   r.animState.phase=phaseName
   r.animState.reactionUntil=0
   Cast.stepAnimate(r,now)
   local where=string.format("%s/%s frame %d",entry.label,phaseName,frame)
   local up=r.torso.CFrame.UpVector:Dot(V(0,1,0))
   if up<worstUp then worstUp=up;worstUpWhere=where end
   check("upright "..where,up>0.9,string.format("torso UpVector.Y=%.3f",up))
   local pelvis=part(r,"LowerTorso")
   local sl,sr=soleY(r,"Left"),soleY(r,"Right")
   check("pelvis above feet "..where,pelvis.Position.Y>math.max(sl,sr)+0.4,
    string.format("pelvis %.3f, highest sole %.3f",pelvis.Position.Y-FLOOR,math.max(sl,sr)-FLOOR))
   check("head above pelvis "..where,r.head.Position.Y>pelvis.Position.Y+0.5,
    string.format("head %.3f, pelvis %.3f",r.head.Position.Y-FLOOR,pelvis.Position.Y-FLOOR))
   local low=math.min(sl,sr)
   local gap=math.abs(low-FLOOR)
   if gap>worstFoot then worstFoot=gap;worstFootWhere=where end
   check("supporting foot on floor "..where,gap<0.06,string.format("lowest sole %.4f above floor",low-FLOOR))
   check("no foot through floor "..where,math.max(sl,sr)>FLOOR-0.06,string.format("highest sole %.4f",math.max(sl,sr)-FLOOR))
  end
 end
end
print(string.format("   worst supporting-foot gap %.4f studs (%s)",worstFoot,worstFootWhere))
print(string.format("   worst torso uprightness %.4f (%s)",worstUp,worstUpWhere))

--------------------------------------------------------------------------------
-- Joint directions. These are the two defects the AGENT.md build log flagged
-- as the likely cause of "knees bend backward" and "arms pass through the
-- torso", so they are asserted geometrically rather than by reading signs.
--------------------------------------------------------------------------------
print("== joint bend directions (forward is -Z in rig space) ==")
local kneeWorst,elbowWorst=math.huge,math.huge
for _,phaseName in {"Idle","Listen","Speak","Scan","TypingConsole","Radio","Reach","Brace","Authority"} do
 for _,entry in people do
  local r=entry.r
  r.animState.phase=phaseName;r.animState.reactionUntil=0
  Cast.stepAnimate(r,1.7)
  for _,side in {"Left","Right"} do
   local hip,knee,ankle=localTo(r,pivot(r,side.."Knee")),nil,nil
   hip=localTo(r,pivot(r,side.."Hip"))
   knee=localTo(r,pivot(r,side.."Knee"))
   ankle=localTo(r,pivot(r,side.."Ankle"))
   -- Where the knee sits relative to the straight line from hip to ankle: a
   -- human knee is FORWARD of it (more negative Z), never behind.
   local t=(knee.Y-hip.Y)/((ankle.Y-hip.Y)~=0 and (ankle.Y-hip.Y) or 1)
   local chordZ=hip.Z+(ankle.Z-hip.Z)*t
   local bow=chordZ-knee.Z -- positive = knee forward of the chord
   if bow<kneeWorst then kneeWorst=bow end
   check(string.format("knee bends forward %s %s/%s",side,entry.label,phaseName),bow>=-0.002,
    string.format("knee is %.4f studs BEHIND the hip-ankle line",-bow))

   local shoulder=localTo(r,pivot(r,side.."Shoulder"))
   local elbow=localTo(r,pivot(r,side.."Elbow"))
   local wrist=localTo(r,pivot(r,side.."Wrist"))
   local tt=(elbow.Y-shoulder.Y)/((wrist.Y-shoulder.Y)~=0 and (wrist.Y-shoulder.Y) or 1)
   local chordZE=shoulder.Z+(wrist.Z-shoulder.Z)*tt
   local back=elbow.Z-chordZE -- positive = elbow behind the chord, which is correct
   if back<elbowWorst then elbowWorst=back end
   check(string.format("elbow bends forward %s %s/%s",side,entry.label,phaseName),back>=-0.002,
    string.format("elbow is %.4f studs IN FRONT of the shoulder-wrist line",-back))
  end
 end
end
print(string.format("   minimum knee bow %.4f, minimum elbow set-back %.4f (both must be >= 0)",kneeWorst,elbowWorst))

--------------------------------------------------------------------------------
-- Hands must stay outside the torso volume for every working/acting pose.
--------------------------------------------------------------------------------
print("== hands clear of the torso ==")
local worstPen,worstPenWhere=0,""
for _,phaseName in STANDING do
 for _,entry in people do
  local r=entry.r
  r.animState.phase=phaseName;r.animState.reactionUntil=0
  r.lineStart=0
  Cast.stepAnimate(r,2.3)
  local torso=r.torso
  for _,side in {"Left","Right"} do
   local hand=r.hands[side]
   local inTorso=torso.CFrame:PointToObjectSpace(hand.Position)
   local half=torso.Size/2
   local penX=half.X-math.abs(inTorso.X)
   local penY=half.Y-math.abs(inTorso.Y)
   local penZ=half.Z-math.abs(inTorso.Z)
   local penetration=math.min(penX,penY,penZ)
   if penetration>worstPen then worstPen=penetration;worstPenWhere=entry.label.."/"..phaseName.."/"..side end
   check(string.format("hand outside torso %s %s/%s",side,entry.label,phaseName),penetration<=0.06,
    string.format("hand is %.3f studs inside the torso box",penetration))
  end
 end
end
print(string.format("   deepest hand/torso overlap %.4f studs (%s)",worstPen,worstPenWhere))

--------------------------------------------------------------------------------
-- Walking: the gait must be driven by distance covered, not by wall time.
--------------------------------------------------------------------------------
print("== walk cycle is distance-driven ==")
--[[
 The property under test is not "how many steps happen" but "the pose at a
 given distance travelled is the same regardless of how fast the character
 covered it". Sampling both runs at identical distances tests that directly,
 with no crossing-counting boundary error in the way.
]]
local walker=people[1].r
local function hipAt(distance,total)
 Cast.walk(walker,V(0,FLOOR+2.8,0),V(0,FLOOR+2.8,-total),distance/total)
 Cast.stepAnimate(walker,os.clock())
 return (select(1,walker.poses.LeftHip:ToOrientation()))
end
local maxDelta=0
for i=1,20 do
 local distance=i*0.9
 local slow=hipAt(distance,20)
 local fast=hipAt(distance,40)
 maxDelta=math.max(maxDelta,math.abs(slow-fast))
 check(string.format("hip angle identical at %.1f studs regardless of speed",distance),near(slow,fast,1e-6),
  string.format("%.6f vs %.6f rad",slow,fast))
end
print(string.format("   worst hip-angle difference between a 20-stud and a 40-stud walk: %.2e rad",maxDelta))
-- And the cycle must actually advance: a "distance-driven" cycle that never
-- moves would pass the check above trivially.
local a=hipAt(0.2,20)
local b=hipAt(1.6,20)
check("walk cycle advances with distance",math.abs(a-b)>0.05,string.format("%.4f vs %.4f rad",a,b))

--------------------------------------------------------------------------------
-- CINEMATIC DRY RUN
--
-- Builds the real Arctic set, the real cast and the real shot list, then runs
-- every shot's enter/update/leave. Anything that would throw in Studio on the
-- first play - a missing subject, a nil handle, a renamed field - throws here
-- instead, which is the failure this project has hit repeatedly.
--------------------------------------------------------------------------------
print("")
print("== cinematic dry run ==")
root:Destroy()
RBX.useSolids=true
RBX.floorY=nil -- off the built set there is no floor; placements fall back to their hint
Cast.reset()

local Env=MOD.Env
local Sequences=MOD.Sequences
local env=Env.build()
print(string.format("   set built: %d parts",#RBX.solids))

local cast=Sequences.buildCast(env)

local subtitles,titleCards={},{}
local ui={
 setSubtitle=function(who,text) if text and text~="" then table.insert(subtitles,{who=who,text=text}) end end,
 setBlackout=function() end,
 setTitleCard=function(lines,style) if lines then table.insert(titleCards,{lines=lines,style=style or "Location"}) end end,
 playCue=function() end,
}
local shots=Sequences.build(env,cast,ui)
check("shot list built",#shots>40,string.format("%d shots",#shots))

local leads={cast.lyra,cast.voss,cast.hale}
local total=0
local framesRun=0
local tightestLens,tightestLensWhere=math.huge,""
for index,shot in shots do
 total+=shot.duration
 local framedAsAuthored=nil
 local closestPerson,closestWho=math.huge,""
 local ok,err=pcall(function()
  local state=shot.enter()
  for frame=0,4 do
   shot.update(state,frame/4)
   framesRun+=1
   if frame==0 and not shot.black then
    --[[
     AT ALPHA 0 THE CAMERA MUST BE EXACTLY WHERE THE SHOT PUT IT.

     Camera.applyShot has an unstick fallback for a lens that ends up inside
     geometry, and every one of its candidates moves the camera closer to or
     further from the focus - so if the distance still matches the shot's own
     offset, the fallback did not fire and the frame on screen is the frame
     in Sequences.lua. If it does not match, the authored framing is being
     silently thrown away, which is how every over-the-shoulder shot in the
     cinematic came to play as a 1.5-stud face close-up without anything
     anywhere reporting a problem.

     Eased at alpha 0 is exactly `from`, for every pace.
    ]]
    local distance=(RBX.camera.CFrame.Position-RBX.camera.Focus.Position).Magnitude
    framedAsAuthored=math.abs(distance-shot.from.Magnitude)
   end
   --[[
    AND THE LENS MUST NOT BE INSIDE ANYBODY.

    Shots are built from a character's own facing, so a framing that points
    along an eyeline pointed at other people puts the camera among them. That
    is how every "Over" shot ended up a stud and a half inside Lyra: the
    distance from the SUBJECT was exactly as authored, so the check above was
    perfectly happy, and the frame was a wall of face. A person is about a
    stud wide, so anything under 1.6 studs from a head or a torso is inside
    them as far as a lens is concerned.
   ]]
   if not shot.black then
    local eye=RBX.camera.CFrame.Position
    for _,person in cast.allHumans do
     for _,piece in {person.head,person.torso} do
      local gap=(eye-piece.Position).Magnitude
      if gap<closestPerson then closestPerson=gap;closestWho=person.model.Name end
     end
    end
   end
  end
  shot.leave(state)
 end)
 check(string.format("shot %d %s runs",index,shot.name),ok,tostring(err))
 if ok and framedAsAuthored then
  check(string.format("shot %d %s plays the framing it declares",index,shot.name),framedAsAuthored<0.01,
   string.format("camera is %.2f studs off its authored distance - the unstick fallback moved it",framedAsAuthored))
  check(string.format("shot %d %s keeps the lens out of the cast",index,shot.name),closestPerson>=1.6,
   string.format("lens is %.2f studs from %s",closestPerson,closestWho))
  if closestPerson<tightestLens then tightestLens=closestPerson;tightestLensWhere=shot.name.."/"..closestWho end
 end
 if ok and not shot.black then
  -- The camera must end up somewhere real, looking at something real.
  local cf=RBX.camera.CFrame
  local position=cf.Position
  check(string.format("shot %d %s camera is finite",index,shot.name),
   position.X==position.X and position.Y==position.Y and position.Z==position.Z,"NaN camera position")
  local focus=RBX.camera.Focus.Position
  check(string.format("shot %d %s camera is not on top of its subject",index,shot.name),
   (position-focus).Magnitude>1,string.format("%.3f studs from focus",(position-focus).Magnitude))
 end
end
print(string.format("   %d shots, %.1f s of runtime, %d frames executed",#shots,total,framesRun))
print(string.format("   closest the lens ever comes to a character: %.2f studs (%s)",tightestLens,tightestLensWhere))

-- Subtitle discipline: short enough to read in the time they are on screen.
local longest,longestText=0,""
for _,entry in subtitles do
 if #entry.text>longest then longest=#entry.text;longestText=entry.text end
 -- 90 characters is about two comfortable lines at the size Opening.lua sets,
 -- and the longest line in the cinematic is 76. A card that needs longer than
 -- that is a line that should be split across two beats, not shrunk.
 check("subtitle fits two comfortable lines",#entry.text<=90,string.format("%d chars: %s",#entry.text,entry.text))
 check("subtitle has a speaker",entry.who~=nil and entry.who~="","missing speaker name")
end
print(string.format("   %d subtitles, longest %d characters",#subtitles,longest))

-- Card discipline: exactly one main title, everything else a location card.
local titles=0
for _,card in titleCards do
 if card.style=="Title" then titles+=1 end
 check("card line is short enough to set at a fixed size",#card.lines[1]<=34,
  string.format("%q is %d characters",card.lines[1],#card.lines[1]))
end
check("exactly one main title card in the whole cinematic",titles==1,string.format("%d title cards",titles))
print(string.format("   %d cards (%d main title, %d location)",#titleCards,titles,#titleCards-titles))

--------------------------------------------------------------------------------
-- EVERY AUTHORED MARK HAS A FLOOR UNDER IT.
--
-- Read straight off Sequences' own STAGING/LAB_STATIONS tables and measured
-- against the real built set, so a mark whose Y hint no longer matches any
-- surface - or which sits under a ceiling the placement ray hits first - is a
-- failure here rather than a character on the roof in Studio. Both of those
-- happened: the whole command-room cast stood 12.4 studs up on the ceiling
-- slab, and the prison marks had nothing at all beneath them.
--------------------------------------------------------------------------------
print("== every staged mark has a floor under it ==")
local Z=MOD.Env.Zones
local worstMark,worstMarkWhere=0,""
local function markFloor(label,r,position)
 local expected=position.Y-Cast.soleDrop(r)
 r.floorY=nil
 local found=Cast.floorUnder(r,position.X,position.Z,expected)
 local delta=found-expected
 if math.abs(delta)>math.abs(worstMark) then worstMark=delta;worstMarkWhere=label end
 check(label.." mark stands on a real floor",math.abs(delta)<1.5,
  string.format("floor is %.2f studs from the authored mark",delta))
end
for stageName,plan in Sequences.Staging do
 local origin=MOD.Env.Zones[plan.origin]
 for index,mark in plan.marks do
  markFloor(string.format("%s/%d",stageName,index),leads[index],origin+mark.at)
 end
end
for index,station in Sequences.LabStations do
 markFloor("LabStation/"..index,cast.scientists[index],Z.Command+station)
end
print(string.format("   worst mark-to-floor error %.3f studs (%s)",worstMark,worstMarkWhere))

--------------------------------------------------------------------------------
-- The lab: every character stands inside exactly one ceiling cone.
--------------------------------------------------------------------------------
print("== command room lighting: one cone per person ==")
-- The leads end the cinematic in the chamber, so put them back on their
-- command-room marks (the same ones STAGING.Command uses) before measuring.
for index,lead in leads do
 Cast.place(lead,Z.Command+Sequences.Staging.Command.marks[index].at,Z.Command+Vector3.new(0,4.6,-6.4))
end
check("command room records its ceiling lights",#env.roomLights>0,string.format("%d recorded",#env.roomLights))
local function conesOver(head)
 local inside=0
 for _,light in env.roomLights do
  local drop=light.position.Y-head.Y
  if drop>0 and drop<light.range then
   local radius=math.tan(math.rad(light.angle)/2)*drop
   local flat=Vector3.new(head.X-light.position.X,0,head.Z-light.position.Z).Magnitude
   if flat<=radius then inside+=1 end
  end
 end
 return inside
end
local labCast={{"Lyra",cast.lyra},{"Voss",cast.voss},{"Hale",cast.hale}}
for i=1,4 do table.insert(labCast,{"Technician"..i,cast.scientists[i]}) end
for _,entry in labCast do
 local count=conesOver(entry[2].head.Position)
 check(entry[1].." is lit by exactly one ceiling light",count==1,string.format("inside %d cones",count))
end

--------------------------------------------------------------------------------
-- THE ALBEDO BUDGET.
--
-- "Characters' heads become glowing bright shapes" is a colour problem before
-- it is a lighting problem: a 0.88-value coat under a warm key clips to white
-- whatever the lights are doing, and the coats used to be paler than the walls
-- of the room they stood in. Cast.lua states the budget; this enforces it on
-- the rigs that are actually built.
--------------------------------------------------------------------------------
print("== nobody is brighter than the room they stand in ==")
local function value(colour) return (colour.rgb[1]+colour.rgb[2]+colour.rgb[3])/3 end
local brightest,brightestWhere=0,""
for _,entry in labCast do
 for _,descendant in entry[2].model:GetDescendants() do
  local colour=rawget(descendant,"Color")
  local size=rawget(descendant,"Size")
  -- Facial detail is exempt: an eye white is SUPPOSED to be the brightest
  -- thing on a Roblox face, and at a sixth of a stud across it cannot bloom
  -- into a glowing head. The budget is about garments and skin - the large
  -- surfaces that make up a silhouette.
  local detail=size and math.max(size.X,size.Y,size.Z)<0.35
  if colour and not detail and rawget(descendant,"Transparency")<0.5 then
   local level=value(colour)
   if level>brightest then brightest=level;brightestWhere=entry[1].."/"..rawget(descendant,"Name") end
   check(entry[1].." surface is inside the albedo budget",level<=206,
    string.format("%s is %.0f (cap 206)",rawget(descendant,"Name"),level))
  end
 end
end
print(string.format("   brightest surface on any lab character: %.0f (%s)",brightest,brightestWhere))

--------------------------------------------------------------------------------
-- The vehicle: wheels turn with distance, and the headlights point away from
-- the bodywork they used to wash out.
--------------------------------------------------------------------------------
print("== vehicle ==")
local truck=env.vehicles[1]
check("truck has six wheels",#truck.wheels==6,string.format("%d wheels",#truck.wheels))
local startSpin=truck.spin
local from=Z.BaseCenter+Vector3.new(0,0,120)
local to=Z.BaseCenter+Vector3.new(0,0,60)
Env.moveVehicle(truck,from,to,0)
local spinAtStart=truck.spin
for i=1,60 do Env.moveVehicle(truck,from,to,i/60) end
local turned=truck.spin-spinAtStart
local expected=60/1.45 -- distance / wheel radius
check("wheel rotation matches distance travelled",near(turned,expected,0.05),
 string.format("%.4f rad turned, %.4f expected",turned,expected))
print(string.format("   %.2f rad of wheel rotation over 60 studs (%.2f expected)",turned,expected))

-- A stationary vehicle's wheels must not creep.
local held=truck.spin
for i=1,10 do Env.moveVehicle(truck,to,to,i/10) end
check("parked wheels do not turn",near(truck.spin,held,1e-9),string.format("%.6f rad of creep",truck.spin-held))

-- Wheels sit on the snow, under their arches, and the body rides above them.
local hull=truck.model.PrimaryPart
for index,wheel in truck.wheels do
 local centre=wheel.model.PrimaryPart.Position
 local ground=Env.surfaceY(centre.X,centre.Z,centre.Y,{truck.model})
 check(string.format("wheel %d rests on the surface",index),near(centre.Y-ground,1.45,0.02),
  string.format("axle %.3f studs above ground, expected 1.45",centre.Y-ground))
 check(string.format("wheel %d sits below the hull",index),centre.Y<hull.Position.Y,
  string.format("wheel %.2f, hull %.2f",centre.Y,hull.Position.Y))
end

--[[
 THE BODY MUST STAY RIGID, however long the truck drives.

 Re-deriving each part's offset from the previous frame's world CFrame (which
 is what Model:PivotTo does) squares any basis scale error on every call, so
 the body folds into its own hull after roughly fifty frames in double
 precision - sooner in Roblox's float32. This measures a part far from the
 pivot across a long drive and demands it has not moved relative to the hull
 AT ALL, which the frozen-offset placement in Kit.rigid makes true exactly
 rather than approximately.
]]
local function emitterOffset()
 for _,descendant in truck.body:GetDescendants() do
  if descendant.Name=="HeadlampEmitter" then
   return hull.CFrame:PointToObjectSpace(descendant.Position)
  end
 end
 return nil
end
local rigidStart=emitterOffset()
check("the truck body has a part to measure rigidity against",rigidStart~=nil,"no HeadlampEmitter found")
for i=1,400 do Env.moveVehicle(truck,from,to,(i%60)/60) end
local rigidEnd=emitterOffset()
local drift=rigidStart and rigidEnd and (rigidEnd-rigidStart).Magnitude or math.huge
check("body stays rigid over 400 frames of driving",drift<1e-9,
 string.format("bodywork drifted %.6f studs relative to the hull",drift))
print(string.format("   bodywork drift over 400 frames: %.2e studs",drift))

-- Headlight emitters must be forward of the nose, or the first thing every
-- beam lights is the truck itself.
local forwardMost=-math.huge
local emitters=0
for _,descendant in truck.body:GetDescendants() do
 if descendant.Name=="HeadlampEmitter" then
  emitters+=1
  local localZ=hull.CFrame:PointToObjectSpace(descendant.Position).Z
  local noseZ=-hull.Size.Z/2
  check("headlamp emitter is ahead of the bodywork",localZ<noseZ,
   string.format("emitter at local Z %.2f, nose at %.2f",localZ,noseZ))
  forwardMost=math.max(forwardMost,noseZ-localZ)
 end
end
check("two headlamps",emitters==2,string.format("%d found",emitters))
print(string.format("   headlamp emitters sit %.2f studs ahead of the nose",forwardMost))

--------------------------------------------------------------------------------
-- Everyone is still standing, on the real set, after the whole run.
--------------------------------------------------------------------------------
print("== cast still standing on the built set ==")
for _,entry in {{"Lyra",cast.lyra},{"Voss",cast.voss},{"Hale",cast.hale},
 {"Technician1",cast.scientists[1]},{"Worker1",cast.workers[1]},{"Soldier1",cast.soldiers[1]}} do
 local r=entry[2]
 local left=r.model:FindFirstChild("LeftFoot")
 local right=r.model:FindFirstChild("RightFoot")
 local low=math.min(left.Position.Y-left.Size.Y/2,right.Position.Y-right.Size.Y/2)
 local ground=Cast.floorUnder(r,r.root.Position.X,r.root.Position.Z,low)
 check(entry[1].." is on the ground after the full run",math.abs(low-ground)<0.1,
  string.format("lowest sole %.3f, ground %.3f",low,ground))
 check(entry[1].." is upright after the full run",r.torso.CFrame.UpVector:Dot(V(0,1,0))>0.9,"toppled")
end

print("")
print(string.format("%d checks, %d failures, %d ground raycasts",checks,failures,RBX.rayCount))
if failures>0 then error(string.format("%d checks failed",failures),0) end
