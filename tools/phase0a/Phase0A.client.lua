--!nonstrict
-- PHASE 0.A - isolated human rig test bench.
--
-- Deliberately bare. A flat floor, four neutral backdrop panels, one neutral
-- key light and nothing else: no props, no fog, no Bloom, no ColorCorrection,
-- no particles, no dialogue UI and no cinematic camera moves. Anything that
-- could flatter or hide a bad pose is absent on purpose.
--
-- This place is NOT part of the game's Rojo project. Serve it separately:
--   rojo serve tools/phase0a/phase0a.project.json --port 34873
-- so the city, the menu and the cinematic can never appear in this window.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInput=game:GetService("UserInputService")
local Lighting=game:GetService("Lighting")

local Human=game:GetService("ReplicatedStorage"):WaitForChild("Human")
local Timeline=require(game:GetService("ReplicatedStorage"):WaitForChild("Phase0ATimeline"))
local Pose=require(Human.Pose)
local Actor=require(Human.Actor)
local Build=require(Human.Build)
local Validate=require(Human.Validate)

local player=Players.LocalPlayer
local V,CF=Vector3.new,CFrame.new

-- ------------------------------------------------------------ bare stage
if player.Character then player.Character:Destroy() end
player.CharacterAdded:Connect(function(c) c:Destroy() end)

for _,child in Lighting:GetChildren() do
 if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then child:Destroy() end
end
for _,child in workspace.Terrain:GetChildren() do
 if child:IsA("Clouds") then child:Destroy() end
end
Lighting.Ambient=Color3.fromRGB(96,100,108)
Lighting.OutdoorAmbient=Color3.fromRGB(118,123,132)
Lighting.Brightness=2
Lighting.ExposureCompensation=0
Lighting.ClockTime=14
Lighting.GeographicLatitude=18
Lighting.EnvironmentDiffuseScale=0.45
Lighting.EnvironmentSpecularScale=0.2
Lighting.GlobalShadows=true
Lighting.FogEnd=100000
Lighting.FogStart=100000
Lighting.FogColor=Color3.fromRGB(150,155,163)
Lighting.ColorShift_Top=Color3.new(0,0,0)
Lighting.ColorShift_Bottom=Color3.new(0,0,0)
Lighting.ShadowSoftness=0.2

local stage=Instance.new("Folder");stage.Name="Phase0AStage";stage.Parent=workspace
local function panel(name,size,cframe,colour)
 local p=Instance.new("Part")
 p.Name=name;p.Size=size;p.CFrame=cframe;p.Color=colour
 p.Anchored=true;p.Material=Enum.Material.SmoothPlastic
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 p.Parent=stage
 return p
end
-- Floor top sits exactly at y = 0, which is the floor plane every foot target
-- and every validator check is measured against.
panel("Floor",V(160,1,160),CF(0,-0.5,0),Color3.fromRGB(129,134,142))
panel("BackdropNorth",V(160,60,1),CF(0,30,-60),Color3.fromRGB(150,155,163))
panel("BackdropSouth",V(160,60,1),CF(0,30,60),Color3.fromRGB(150,155,163))
panel("BackdropEast",V(1,60,160),CF(60,30,0),Color3.fromRGB(150,155,163))
panel("BackdropWest",V(1,60,160),CF(-60,30,0),Color3.fromRGB(150,155,163))

-- One neutral key, placed in the world, well away from the actor. Nothing is
-- ever attached to the character to make it visible.
local keyHost=Instance.new("Part")
keyHost.Name="KeyLight";keyHost.Size=V(1,1,1);keyHost.Transparency=1
keyHost.Anchored=true;keyHost.CanCollide=false;keyHost.CFrame=CF(14,18,16)
keyHost.Parent=stage
local key=Instance.new("PointLight")
key.Brightness=1.1;key.Range=70;key.Color=Color3.fromRGB(236,242,250);key.Shadows=true
key.Parent=keyHost

-- ------------------------------------------------------------------ actor
local actor=Actor.new({scale=1,floorY=0,position=V(0,0,14),yaw=0,seed=2})
local rig=Build.rig(workspace,{name="HumanPrototype",scale=1})
actor:update(0)
Build.apply(rig,actor)

local lights,neon=Validate.scanRig(rig.model)

-- --------------------------------------------------------------- timeline
-- One continuous performance, in the order Phase 0.A asks for it: hold an
-- idle, look, gesture (three times, to expose any per-repeat distortion),
-- turn, walk, stop, walk again with a turn under way, stop again, step back,
-- flinch, then hold a long final idle so any drift has somewhere to show.
local labels={}
local function loadTimeline()
 actor.queue={}
 labels=Timeline.full(actor)
end
loadTimeline()
local totalCommands=#actor.queue
local currentLabel="1  STAND - hold the idle"

-- ---------------------------------------------------------------- cameras
local camera=workspace.CurrentCamera
camera.CameraType=Enum.CameraType.Scriptable
camera.FieldOfView=40
local VIEWS={
 -- The actor starts at yaw 0, which faces -Z, so a "front" camera has to sit
 -- on the -Z side. The first pass put all three on +Z and framed its back.
 {name="three-quarter",offset=V(7.6,4.3,-9.2)},
 {name="front",offset=V(0,3.4,-11.4)},
 {name="side",offset=V(11.4,3.4,0)},
}
local viewIndex=1
local followCamera=true
local lockedFocus=actor.position
local silhouette=false
local paused=false
local stepFrame=false

local function updateCamera()
 local focusPos=followCamera and actor.position or lockedFocus
 local focus=V(focusPos.X,2.6,focusPos.Z)
 camera.CFrame=CFrame.lookAt(focus+VIEWS[viewIndex].offset,focus)
end
updateCamera()

-- -------------------------------------------------------------------- HUD
local gui=Instance.new("ScreenGui")
gui.Name="Phase0AGui";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true
gui.Parent=player:WaitForChild("PlayerGui")
local panelFrame=Instance.new("Frame")
panelFrame.Size=UDim2.new(0,430,0,510);panelFrame.Position=UDim2.new(0,14,0,14)
panelFrame.BackgroundColor3=Color3.fromRGB(16,18,22);panelFrame.BackgroundTransparency=0.18
panelFrame.BorderSizePixel=0;panelFrame.Parent=gui
local text=Instance.new("TextLabel")
text.Size=UDim2.new(1,-18,1,-18);text.Position=UDim2.new(0,9,0,9)
text.BackgroundTransparency=1;text.Font=Enum.Font.Code;text.TextSize=13
text.TextColor3=Color3.fromRGB(226,232,240)
text.TextXAlignment=Enum.TextXAlignment.Left;text.TextYAlignment=Enum.TextYAlignment.Top
text.Text="";text.Parent=panelFrame
local help=Instance.new("TextLabel")
help.Size=UDim2.new(0,430,0,22);help.Position=UDim2.new(0,14,0,532)
help.BackgroundTransparency=1;help.Font=Enum.Font.Code;help.TextSize=13
help.TextColor3=Color3.fromRGB(150,158,170);help.TextXAlignment=Enum.TextXAlignment.Left
help.Text="1/2/3 view   4 silhouette   L lock camera   Space pause   R restart / N frame / G gesture / D stops / T turns"
help.Parent=gui

-- ------------------------------------------------------------------- loop
local session=Validate.newSession()
local elapsed=0

UserInput.InputBegan:Connect(function(input,processed)
 if processed then return end
 local k=input.KeyCode
 if k==Enum.KeyCode.One then viewIndex=1
 elseif k==Enum.KeyCode.Two then viewIndex=2
 elseif k==Enum.KeyCode.Three then viewIndex=3
 elseif k==Enum.KeyCode.Four then silhouette=not silhouette;Build.setSilhouette(rig,silhouette)
 elseif k==Enum.KeyCode.L then followCamera=not followCamera;lockedFocus=actor.position
 elseif k==Enum.KeyCode.Space then paused=not paused
 elseif k==Enum.KeyCode.N then paused=true;stepFrame=true
 elseif k==Enum.KeyCode.G or k==Enum.KeyCode.D or k==Enum.KeyCode.T then
  actor=Actor.new({scale=1,floorY=0,position=V(0,0,14),yaw=0,seed=2})
  if k==Enum.KeyCode.G then actor:idle(1):gesture(2.4):idle(2);currentLabel="ISOLATED GESTURE"
  elseif k==Enum.KeyCode.D then
   Timeline.stops(actor)
   currentLabel="ISOLATED STRAIGHT DECELERATION"
  else
   Timeline.turns(actor)
   currentLabel="ISOLATED TURN AT CRUISE SPEED"
  end
  labels={};totalCommands=#actor.queue;session=Validate.newSession();elapsed=0;paused=false
 elseif k==Enum.KeyCode.R then
  actor=Actor.new({scale=1,floorY=0,position=V(0,0,14),yaw=0,seed=2})
  loadTimeline();totalCommands=#actor.queue
  session=Validate.newSession();elapsed=0;paused=false;stepFrame=false
 end
end)

local function statusBlock()
 local rows={}
 table.insert(rows,("PHASE 0.A  HUMAN RIG TEST        t = %6.2f s"):format(elapsed))
 table.insert(rows,("segment  %s"):format(currentLabel))
 table.insert(rows,("command  %-10s   speed %5.2f   view %s%s"):format(
  actor:label(),actor.speed,VIEWS[viewIndex].name,paused and "  [PAUSED]" or ""))
 local fl,fr=actor.loco.feet.Left,actor.loco.feet.Right
 table.insert(rows,("feet     L %-8s plant %-3d    R %-8s plant %d"):format(
  fl.mode,fl.plantId,fr.mode,fr.plantId))
 table.insert(rows,("pelvis   drop %.4f   reach err %.5f"):format(actor.loco.pelvisDrop,actor.loco.reachError))
 local drift,where=Pose.magnitude(actor.lastFrame)
 table.insert(rows,("pose     largest live offset %.4f  (%s)"):format(drift,where))
 table.insert(rows,"")
 table.insert(rows,("%-18s %-11s %s"):format("check","worst","verdict"))
 for _,row in Validate.report(session) do
  table.insert(rows,("%-18s %-11.6f %s"):format(row.name,row.worst,row.ok and "pass" or ("FAIL x"..row.failures)))
 end
 table.insert(rows,"")
 table.insert(rows,("self-illumination  lights %d   neon parts %d  %s"):format(
  #lights,#neon,(#lights==0 and #neon==0) and "pass" or "FAIL"))
 table.insert(rows,Validate.passed(session) and "ALL NUMERIC CHECKS PASS" or "SEE FAILURES ABOVE")
 return table.concat(rows,"\n")
end

RunService.RenderStepped:Connect(function(dt)
 if not paused or stepFrame then
  dt=stepFrame and 1/60 or math.min(dt,1/30)
  stepFrame=false
  elapsed+=dt
  local index=totalCommands-#actor.queue
  if labels[index] then currentLabel=labels[index] end
  actor:update(dt)
  Validate.step(session,actor)
  Build.apply(rig,actor)
 end
 updateCamera()
 text.Text=statusBlock()
end)
