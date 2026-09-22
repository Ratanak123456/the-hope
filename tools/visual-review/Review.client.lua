--!nonstrict
-- Isolated Studio evidence scene; excluded from the production Rojo project.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local folder=game:GetService("ReplicatedStorage"):WaitForChild("ReviewModules")
local before=require(folder.BaselineCast)
local after=require(folder.Cast)
local light=game:GetService("Lighting")
light.Brightness=1.4;light.ExposureCompensation=-0.3
light.Ambient=Color3.fromRGB(100,105,115)
light.OutdoorAmbient=Color3.fromRGB(120,125,130);light.ClockTime=10
if Players.LocalPlayer.Character then Players.LocalPlayer.Character:Destroy() end
Players.LocalPlayer.CharacterAdded:Connect(function(c) c:Destroy() end)
local camera=workspace.CurrentCamera
camera.CameraType=Enum.CameraType.Scriptable;camera.FieldOfView=38
local rigFolder=Instance.new("Folder",workspace);rigFolder.Name="HumanComparison"
local models={}
for i,lib in {before,after,before,after} do
 local x=({7.5,2.5,-2.5,-7.5})[i]
 local r=lib.buildLyra(rigFolder,CFrame.new(x,2.8,0))
 lib.evaluate(r)
 if i>=3 then
  for _,p in r.model:GetDescendants() do
   if p:IsA("BasePart") then p.Color=Color3.new();p.Material=Enum.Material.SmoothPlastic;p.Reflectance=0 end
  end
 end
 table.insert(models,{rig=r,lib=lib})
end
local floor=Instance.new("Part",workspace)
floor.Name="ReviewFloor";floor.Size=Vector3.new(45,0.2,20)
floor.Position=Vector3.new(0,-0.2,0);floor.Anchored=true
floor.Color=Color3.fromRGB(135,142,152)
floor.TopSurface=Enum.SurfaceType.Smooth
local fill=Instance.new("Part",workspace)
fill.Anchored=true;fill.Transparency=1;fill.CanCollide=false;fill.Position=Vector3.new(0,8,-10)
local lamp=Instance.new("PointLight",fill)
lamp.Brightness=2;lamp.Range=45;lamp.Color=Color3.fromRGB(225,234,245)
local gui=Instance.new("ScreenGui",Players.LocalPlayer:WaitForChild("PlayerGui"))
local label=Instance.new("TextLabel",gui)
label.Size=UDim2.fromScale(1,0.1);label.BackgroundTransparency=1
label.Text="ORIGINAL              LYRA REBUILD              ORIGINAL SILHOUETTE              REBUILD SILHOUETTE\n1 Front  ·  2 Profile  ·  3 Three-quarter  ·  P Pause motion"
label.TextSize=18;label.TextColor3=Color3.fromRGB(235,238,240)
label.Font=Enum.Font.GothamMedium
local reviewOrigin=Vector3.new(0,20000,0)
floor.Position+=reviewOrigin;fill.Position+=reviewOrigin
local view=1
local paused=false
local start=os.clock()
Input.InputBegan:Connect(function(input,processed)

 if input.KeyCode==Enum.KeyCode.One then view=1
 elseif input.KeyCode==Enum.KeyCode.Two then view=2
 elseif input.KeyCode==Enum.KeyCode.Three then view=3
 elseif input.KeyCode==Enum.KeyCode.P then paused=not paused end
end)
RunService:BindToRenderStep("IsolatedVisualReview",Enum.RenderPriority.Last.Value+1,function()
 for _,g in Players.LocalPlayer.PlayerGui:GetChildren() do if g:IsA("ScreenGui") and g~=gui then g.Enabled=false end end
 camera.CameraType=Enum.CameraType.Scriptable
 camera.CFrame=CFrame.lookAt(reviewOrigin+Vector3.new(0,4,-31),reviewOrigin+Vector3.new(0,2.8,0))
 for i,item in models do
  local r=item.rig
  r.root.CFrame=CFrame.new(reviewOrigin+Vector3.new(({7.5,2.5,-2.5,-7.5})[i],2.8,0))*CFrame.Angles(0,view==2 and math.pi/2 or view==3 and math.pi/4 or 0,0)
  if not paused then
   local t=(os.clock()-start)%18
   local action=t<4 and "Idle" or t<9 and "Speak" or t<12 and "Brace" or "Walk"
   if r.reviewAction~=action then
    item.lib.act(r,action,"Focused",r.root.Position+Vector3.new(-3,3,-4))
    r.lineStart=os.clock();r.reviewAction=action
   end
   if action=="Walk" then
    r.travel=(t-12)*2;r.animState.moving=true
   else r.animState.moving=false end
   item.lib.stepAnimate(r,os.clock())
  end
 end
end)
print("[VisualReview] Pass 1 ready. Original and replacement, color and silhouette. No visual approval implied.")
