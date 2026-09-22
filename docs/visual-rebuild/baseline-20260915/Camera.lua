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
function Camera.configure(handle) env=handle;table.clear(reported) end
local function point(subject)
 if typeof(subject)=="Vector3" then return subject end
 if typeof(subject)=="Instance" and subject:IsA("BasePart") and subject.Parent then return subject.Position end
 return nil
end
local function params(subject)
 local p=RaycastParams.new();p.FilterType=Enum.RaycastFilterType.Include;p.FilterDescendantsInstances={env.folder};p.IgnoreWater=false
 local excluded={env.markers}
 if typeof(subject)=="Instance" then
  local m=subject:FindFirstAncestorOfClass("Model")
  table.insert(excluded,m or subject)
 end
 -- Exclude only the intended subject from obstruction tests.
 p.FilterType=Enum.RaycastFilterType.Exclude;p.FilterDescendantsInstances=excluded
 return p
end
local function inside(pos,subject)
 local p=OverlapParams.new();p.FilterType=Enum.RaycastFilterType.Include;p.FilterDescendantsInstances={env.folder};p.MaxParts=30
 local subjectModel = if typeof(subject)=="Instance" then subject:FindFirstAncestorOfClass("Model") else nil
 for _,hit in workspace:GetPartBoundsInBox(CFrame.new(pos),Vector3.new(0.5,0.5,0.5),p) do
  if hit.Transparency<0.65 and not hit:IsDescendantOf(env.markers) and (not subjectModel or not hit:IsDescendantOf(subjectModel)) then return hit end
 end
 return nil
end
local function obstruction(pos,target,subject)
 local delta=target-pos
 if delta.Magnitude<0.01 then return nil end
 return workspace:Raycast(pos,delta,params(subject))
end
function Camera.inspect(name,subject,pos,target)
 local exists=point(subject)~=nil
 local distance=(target-pos).Magnitude
 local block=obstruction(pos,target,subject)
 local embedded=inside(pos,subject)
 local terrain=workspace:Raycast(pos+Vector3.new(0,2,0),Vector3.new(0,-2,0),params(subject))
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
 local original=Camera.inspect(shot.name,subject,pos,focus)
 if not original.passed and (original.blocked or original.inside) then
  local direction=offset.Unit
  local right=Vector3.new(-direction.Z,0,direction.X)
  for _,candidate in {focus+offset*0.8,focus+offset*0.6,focus+offset*0.4,pos+right*4,pos-right*4,pos+Vector3.new(0,4,0)} do
   if not inside(candidate,subject) and not obstruction(candidate,focus,subject) and (candidate-focus).Magnitude>1 then pos=candidate;break end
  end
 end
 camera.CameraType=Enum.CameraType.Scriptable
 camera.FieldOfView=shot.fov or 48
 camera.CFrame=CFrame.lookAt(pos,focus)
 camera.Focus=CFrame.new(focus)
 if RunService:IsStudio() and (not reported[shot.name] or env.folder:GetAttribute("ValidateEveryFrame")) then
  reported[shot.name]=true
  local r=Camera.inspect(shot.name,subject,pos,focus)
  print("[OpeningCamera] "..game:GetService("HttpService"):JSONEncode(r))
  if not r.passed then warn("[OpeningCamera] FAILED: "..shot.name.." — inspect this frame in Studio") end
  env.folder:SetAttribute("LastCameraPassed",r.passed)
 end
end
return Camera
