--!nonstrict
-- Live subject framing with bounded correction; never interpolates rotations
-- between unrelated markers. Studio reports are geometric/light heuristics,
-- not a substitute for inspecting the rendered frame.
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local Settings=require(script.Parent.Parent.Settings)
local Camera={}
local env
local reported={}
--[[
 A shot that had to be corrected remembers HOW, for as long as it is on screen.

 The correction is re-tested every frame (the subject moves, so it has to be),
 but without a memory it also re-DECIDES every frame, and the margins in a
 crowded room are small enough that a listener's breathing is sometimes enough
 to flip the answer. Studio caught exactly that on 06a_HaleReport: the shot
 reported a clean orbit on its first frame and rendered, a second later, as a
 head filling half the screen, because by then every candidate had failed and
 the last resort had pulled the lens in to three studs.

 Keyed by shot name and cleared per cinematic run. The stored value is a
 STRATEGY, never a position, so a held correction still tracks a moving subject
 instead of freezing the camera in place.
]]
local corrections={}
-- A collapsed shot has no cached strategy to suppress its own warning, so the
-- warning would otherwise repeat every frame for the length of the shot.
local collapsedWarned={}
function Camera.configure(handle) env=handle;table.clear(reported);table.clear(corrections);table.clear(collapsedWarned) end
local function point(subject)
 if typeof(subject)=="Vector3" then return subject end
 if typeof(subject)=="Instance" and subject:IsA("BasePart") and subject.Parent then return subject.Position end
 return nil
end
--[[
 `allowed` is the shot's own list of things that are ALLOWED to be between the
 lens and the subject.

 Without it an over-the-shoulder shot can never pass: its whole construction
 puts the listener's head and shoulder in front of the speaker on purpose, the
 obstruction ray dutifully reports that as blocked, and the unstick fallback
 below throws the framing away and pulls in to 1.5 studs from the subject's
 face. Every "Over" shot in the cinematic was being played as an enormous
 face close-up for exactly that reason - the framing in Sequences.lua was
 correct and was never used.
]]
local function params(subject,allowed)
 local p=RaycastParams.new();p.FilterType=Enum.RaycastFilterType.Include;p.FilterDescendantsInstances={env.folder};p.IgnoreWater=false
 local excluded={env.markers}
 if typeof(subject)=="Instance" then
  local m=subject:FindFirstAncestorOfClass("Model")
  table.insert(excluded,m or subject)
 end
 if allowed then for _,item in allowed do table.insert(excluded,item) end end
 -- Exclude the intended subject, and whatever the shot says belongs in front
 -- of it, from obstruction tests.
 p.FilterType=Enum.RaycastFilterType.Exclude;p.FilterDescendantsInstances=excluded
 return p
end
local function inside(pos,subject,allowed)
 local p=OverlapParams.new();p.FilterType=Enum.RaycastFilterType.Include;p.FilterDescendantsInstances={env.folder};p.MaxParts=30
 local subjectModel = if typeof(subject)=="Instance" then subject:FindFirstAncestorOfClass("Model") else nil
 for _,hit in workspace:GetPartBoundsInBox(CFrame.new(pos),Vector3.new(0.5,0.5,0.5),p) do
  local permitted=false
  if allowed then
   for _,item in allowed do
    if hit==item or hit:IsDescendantOf(item) then permitted=true; break end
   end
  end
  if hit.Transparency<0.65 and not permitted and not hit:IsDescendantOf(env.markers) and (not subjectModel or not hit:IsDescendantOf(subjectModel)) then return hit end
 end
 return nil
end
local function obstruction(pos,target,subject,allowed)
 local delta=target-pos
 if delta.Magnitude<0.01 then return nil end
 return workspace:Raycast(pos,delta,params(subject,allowed))
end
function Camera.inspect(name,subject,pos,target,allowed)
 local exists=point(subject)~=nil
 local distance=(target-pos).Magnitude
 local block=obstruction(pos,target,subject,allowed)
 local embedded=inside(pos,subject,allowed)
 local terrain=workspace:Raycast(pos+Vector3.new(0,2,0),Vector3.new(0,-2,0),params(subject,allowed))
 local light=(Lighting.Ambient.R+Lighting.Ambient.G+Lighting.Ambient.B)/3>0.16 and Lighting.ExposureCompensation>=-0.2
 local cf=CFrame.lookAt(pos,target)
 local facing=distance>0.1 and cf.LookVector:Dot((target-pos).Unit)>0.99
 local report={shot=name,subject=typeof(subject)=="Instance" and subject.Name or "Location",exists=exists,distance=math.floor(distance*10)/10,blocked=block and block.Instance:GetFullName() or false,inside=embedded and embedded.Name or false,beneathTerrain=terrain~=nil and terrain.Instance==workspace.Terrain,facing=facing,lightHeuristic=light}
 report.passed=exists and distance>0.8 and not block and not embedded and not report.beneathTerrain and facing and light
 return report
end
-- Three dolly feels instead of one constant-speed curve for every shot:
-- "Slow" eases out gently and lingers near the held frame (mystery/scale -
-- a reveal should not arrive at the same rate it left), "Fast" arrives
-- quickly then only barely settles (danger/evacuation), and the default
-- smoothstep covers ordinary coverage. Never linear - that reads as the
-- robotic, security-camera movement this is meant to avoid.
local function ease(pace,t)
 if pace=="Slow" then return 1-(1-t)^3
 elseif pace=="Fast" then return 1-(1-t)^1.5
 end
 return t*t*(3-2*t)
end
--[[
 UNSTICKING, in order of how much of the shot it costs.

 An earlier list tried three progressively closer positions along the same
 blocked sightline, two sideways nudges, one upward nudge, and then gave up at
 1.5 studs from the subject's face. Every entry but the sideways pair kept the
 SAME direction, so anything blocking the line - a display bezel, a ceiling
 truss, a listener standing in the way - blocked most of the list too, and the
 shot ended as an enormous close-up. Measured in Studio, four of the command
 room's shots were being played at 1.4-1.5 studs instead of their authored
 6.8-8.2.

 So: try to keep the shot first. An ORBIT preserves the subject's size in frame
 exactly - it is still a medium, just from a few degrees round - and a RISE
 looks over whatever is in the way rather than around it, which is usually the
 right answer when the obstruction is a person. Only when neither works at any
 angle does this start giving up distance.

 The orbit is capped at 54 degrees, not further: past about sixty the lens has
 crossed to the other side of the speaker, which breaks the shot/reverse-shot
 side Sequences.speakerSide maintains and makes a conversation read as two
 people who have swapped places between cuts.
]]
local STRATEGIES={
 {kind="orbit",value=16},{kind="orbit",value=-16},
 {kind="rise",value=1.6},{kind="rise",value=-1.6},
 {kind="orbit",value=32},{kind="orbit",value=-32},
 {kind="rise",value=2.9},{kind="rise",value=-2.9},
 {kind="orbit",value=54},{kind="orbit",value=-54},
 {kind="pull",value=0.78},{kind="pull",value=0.6},{kind="pull",value=0.44},
}
local function strategyPoint(strategy,focus,offset)
 if strategy.kind=="orbit" then
  return focus+(CFrame.fromAxisAngle(Vector3.yAxis,math.rad(strategy.value))*offset.Unit)*offset.Magnitude
 elseif strategy.kind=="rise" then
  return focus+offset+Vector3.new(0,strategy.value,0)
 end
 return focus+offset*strategy.value
end
function Camera.applyShot(shot,alpha,elapsed)
 local camera=workspace.CurrentCamera
 local subject=shot.subject()
 local target=point(subject)
 if not camera or not target then error("Opening shot subject missing: "..shot.name) end
 local eased=ease(shot.pace,alpha)
 local from=shot.from
 local to=shot.to or from
 local offset=from:Lerp(to,Settings.reducedMotion() and 0.5 or eased)
 local focus=target+(shot.focusOffset or Vector3.zero)
 local pos=focus+offset
 if shot.handheld and not Settings.reducedMotion() then
  pos+=Vector3.new(math.noise(elapsed*5)*0.12,math.noise(0,elapsed*5)*0.09,0)*Settings.shakeScale()
 end
 local allowed=shot.foreground
 local original=Camera.inspect(shot.name,subject,pos,focus,allowed)
 local corrected=nil
 local function usable(candidate)
  return not inside(candidate,subject,allowed)
   and not obstruction(candidate,focus,subject,allowed)
   and (candidate-focus).Magnitude>1
 end
 --[[
  Once a shot has been corrected it STAYS corrected for the rest of the take,
  even on a frame where the original angle happens to clear again. A lens that
  snaps back to the authored angle mid-line is a cut, and a cut in the middle
  of a shot reads worse than holding a slightly compromised one.
 ]]
 local held=corrections[shot.name]
 if held then
  local candidate=strategyPoint(held,focus,offset)
  if usable(candidate) then pos=candidate;corrected=held.kind.."(held)" end
 end
 if not corrected and not original.passed and (original.blocked or original.inside) then
  local resolved=nil
  for _,strategy in STRATEGIES do
   local candidate=strategyPoint(strategy,focus,offset)
   if usable(candidate) then
    corrections[shot.name]=strategy;resolved=candidate;corrected=strategy.kind
    -- Said out loud the moment it happens. The report below prints once, on a
    -- shot's FIRST frame, so a shot that starts clean and is obstructed a
    -- second later - which is what a listener breathing into the sightline
    -- does - used to degrade completely silently.
    if RunService:IsStudio() then
     warn(`[OpeningCamera] {shot.name} corrected mid-shot: {strategy.kind} {strategy.value}`)
    end
    break
   end
  end
  if resolved then
   pos=resolved
  else
   -- Every strategy still blocked or embedded. Never render from inside
   -- geometry: pull in along the shot's own direction as a last resort, but
   -- no closer than three studs - closer than that is a nostril shot, which
   -- is worse than the obstruction it is avoiding.
   pos=focus+offset.Unit*math.max(3,offset.Magnitude*0.3)
   corrected="collapsed"
   if RunService:IsStudio() and not collapsedWarned[shot.name] then
    collapsedWarned[shot.name]=true
    warn(`[OpeningCamera] {shot.name} COLLAPSED: no angle clear, framing abandoned`)
   end
  end
 end
 camera.CameraType=Enum.CameraType.Scriptable
 camera.FieldOfView=shot.fov or 48
 camera.CFrame=CFrame.lookAt(pos,focus)
 camera.Focus=CFrame.new(focus)
 if RunService:IsStudio() and (not reported[shot.name] or env.folder:GetAttribute("ValidateEveryFrame")) then
  reported[shot.name]=true
  local r=Camera.inspect(shot.name,subject,pos,focus,allowed)
  -- A shot that had to be moved is a defect in the AUTHORED framing even when
  -- the corrected position passes, so say so rather than reporting only the
  -- position that was finally rendered.
  r.corrected=corrected or false
  r.authoredDistance=math.floor(offset.Magnitude*10)/10
  print("[OpeningCamera] "..game:GetService("HttpService"):JSONEncode(r))
  if not r.passed then warn("[OpeningCamera] FAILED: "..shot.name.." — inspect this frame in Studio") end
  env.folder:SetAttribute("LastCameraPassed",r.passed)
 end
end
return Camera
