--!nonstrict
-- Existing Start Game entry point. One controller, one hold state, one exit.
-- Normal completion, Skip, respawn and errors all return through finalize().
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local GuiService=game:GetService("GuiService")
local Config=require(game:GetService("ReplicatedStorage").Shared.Config)
local MenuScene=require(script.Parent.MenuScene)
local Settings=require(script.Parent.Settings)
local Env=require(script.Parent.NorthPole.Env)
local Sequences=require(script.Parent.NorthPole.Sequences)
local Light=require(script.Parent.NorthPole.Lighting)
local Audio=require(script.Parent.NorthPole.Audio)
local Opening={}
local active
local player=Players.LocalPlayer
local function make(class,parent,props)
 local item=Instance.new(class)
 for k,v in props do item[k]=v end
 item.Parent=parent
 return item
end
local function corner(parent,radius) make("UICorner",parent,{CornerRadius=UDim.new(0,radius)}) end
local function animate(run,item,props,duration)
 local tween=TweenService:Create(item,TweenInfo.new(Settings.reducedMotion() and 0.05 or duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props)
 table.insert(run.tweens,tween);tween:Play()
 return tween
end
local function connect(run,signal,fn)
 local connection=signal:Connect(fn);table.insert(run.connections,connection);return connection
end
local function createUI(run)
 local gui=make("ScreenGui",player:WaitForChild("PlayerGui"),{Name="OpeningCinematicGui",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=100,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets
 run.gui=gui
 local root=make("Frame",gui,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
 local black=make("Frame",root,{Name="Blackout",Size=UDim2.fromScale(1,1),BorderSizePixel=0,BackgroundColor3=Color3.new(0,0,0),ZIndex=2})
 local bars={}
 for _,bottom in {false,true} do
  local bar=make("Frame",root,{Name=bottom and "BottomLetterbox" or "TopLetterbox",AnchorPoint=Vector2.new(0,bottom and 1 or 0),Position=UDim2.fromScale(0,bottom and 1 or 0),Size=UDim2.fromScale(1,0),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ZIndex=3})
  animate(run,bar,{Size=UDim2.fromScale(1,0.055)},0.5);table.insert(bars,bar)
 end
 run.bars=bars
 local safe=make("Frame",root,{Name="SafeContent",BackgroundTransparency=1,Position=UDim2.fromOffset(24,60),Size=UDim2.new(1,-48,1,-84),ZIndex=4})
 local card=make("CanvasGroup",safe,{Name="Subtitles",AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-36),Size=UDim2.new(0.64,0,0,118),BackgroundColor3=Color3.fromRGB(9,13,18),BackgroundTransparency=0.25,BorderSizePixel=0,Visible=false,GroupTransparency=1,ZIndex=5})
 corner(card,12)
 local speaker=make("TextLabel",card,{Name="Speaker",BackgroundTransparency=1,Position=UDim2.fromOffset(22,14),Size=UDim2.new(1,-44,0,22),Text="",TextSize=17,Font=Enum.Font.GothamMedium,TextColor3=Color3.fromRGB(216,214,203),TextXAlignment=Enum.TextXAlignment.Center,ZIndex=6})
 local line=make("TextLabel",card,{Name="Dialogue",BackgroundTransparency=1,Position=UDim2.fromOffset(22,39),Size=UDim2.new(1,-44,1,-51),Text="",TextSize=27,Font=Enum.Font.Gotham,TextColor3=Color3.fromRGB(246,241,228),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,TextStrokeTransparency=0.88,ZIndex=6})
 make("UITextSizeConstraint",line,{MinTextSize=20,MaxTextSize=28})
 local title=make("TextLabel",safe,{Name="Title",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.43),Size=UDim2.fromScale(0.93,0.25),Text="",Font=Enum.Font.GothamMedium,TextSize=42,TextWrapped=true,TextColor3=Color3.fromRGB(244,237,222),BackgroundTransparency=1,TextTransparency=1,ZIndex=6})
 local subtitle=make("TextLabel",safe,{Name="Era",AnchorPoint=Vector2.new(0.5,0),Position=UDim2.fromScale(0.5,0.59),Size=UDim2.new(0.95,0,0,30),Text="",Font=Enum.Font.Gotham,TextSize=16,TextColor3=Color3.fromRGB(217,215,207),BackgroundTransparency=1,TextTransparency=1,ZIndex=6})
 local accent=make("Frame",safe,{Name="EnergyLine",AnchorPoint=Vector2.new(0.5,0),Position=UDim2.fromScale(0.5,0.57),Size=UDim2.fromOffset(90,2),BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(203,139,73),BackgroundTransparency=1,ZIndex=6})
 local skip=make("TextButton",safe,{Name="HoldToSkip",AnchorPoint=Vector2.new(1,0),Position=UDim2.fromScale(1,0),Size=UDim2.fromOffset(205,44),BackgroundColor3=Color3.fromRGB(12,17,23),BackgroundTransparency=0.25,BorderSizePixel=0,Text="",Selectable=true,AutoButtonColor=false,Visible=false,ClipsDescendants=true,ZIndex=7})
 corner(skip,22)
 make("UIStroke",skip,{Color=Color3.fromRGB(230,230,221),Transparency=0.8,Thickness=1})
 local skipText=make("TextLabel",skip,{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Text="E  ››  Hold to Skip",TextSize=15,Font=Enum.Font.GothamMedium,TextColor3=Color3.fromRGB(238,235,224),ZIndex=9})
 local fill=make("Frame",skip,{Name="HoldProgress",Size=UDim2.fromScale(0,1),BackgroundColor3=Color3.fromRGB(191,133,72),BackgroundTransparency=0.6,BorderSizePixel=0,ZIndex=8})
 local function layout()
  local camera=workspace.CurrentCamera
  local vp=camera and camera.ViewportSize or Vector2.new(1366,768)
  local mobile=vp.X<900
  local inset=GuiService:GetGuiInset()
  local top=math.max(24,inset.Y+10)
  safe.Position=UDim2.fromOffset(24,top);safe.Size=UDim2.new(1,-48,1,-top-20)
  card.Size=UDim2.new(mobile and 0.96 or 0.64,0,0,mobile and 116 or 132)
  card.Position=UDim2.new(0.5,0,1,-math.max(18,vp.Y*0.055))
  line.TextSize=mobile and 21 or 27;speaker.TextSize=mobile and 14 or 17
  title.TextSize=mobile and 28 or 44;subtitle.TextSize=mobile and 13 or 16
  skipText.Text=Input.GamepadEnabled and "A  ››  Hold to Skip" or Input.TouchEnabled and "››  Hold to Skip" or "E  ››  Hold to Skip"
 end
 layout()
 if workspace.CurrentCamera then connect(run,workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),layout) end
 connect(run,Input.LastInputTypeChanged,layout)
 connect(run,skip.MouseEnter,function() animate(run,skip,{BackgroundTransparency=0.08},0.15) end)
 connect(run,skip.MouseLeave,function() run.pointer=nil;animate(run,skip,{BackgroundTransparency=0.25},0.15) end)
 connect(run,skip.SelectionGained,function() animate(run,skip,{BackgroundTransparency=0.08},0.15) end)
 connect(run,skip.SelectionLost,function() run.holds[Enum.KeyCode.ButtonA]=nil;animate(run,skip,{BackgroundTransparency=0.25},0.15) end)
 connect(run,skip.InputBegan,function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then run.pointer=input end
 end)
 local currentLine,currentTitle="",""
 local ui={}
 function ui.setSubtitle(who,text)
  local key=(who or "")..text
  if key==currentLine then return end
  currentLine=key
  if text=="" then
   card.Visible=false;card.GroupTransparency=1;line.Text="";return
  end
  speaker.Text=who or ""
  speaker.TextColor3=who==Config.Cinematic.Names.Aegis and Color3.fromRGB(235,167,88) or who==Config.Cinematic.Names.Sovereign and Color3.fromRGB(193,149,240) or Color3.fromRGB(222,218,205)
  line.Text=text
  card.Visible=true;card.GroupTransparency=1
  animate(run,card,{GroupTransparency=0},0.18)
 end
 function ui.setBlackout(alpha) black.BackgroundTransparency=math.clamp(alpha,0,1) end
 function ui.setTitleCard(lines)
  local key=lines and table.concat(lines,"|") or ""
  if key==currentTitle then return end
  currentTitle=key;title.Text=lines and lines[1] or "";subtitle.Text=lines and lines[2] or ""
  animate(run,title,{TextTransparency=lines and 0 or 1},0.65)
  animate(run,subtitle,{TextTransparency=lines and 0 or 1},0.65)
  animate(run,accent,{BackgroundTransparency=lines and 0.15 or 1},0.65)
 end
 function ui.playCue(name) if not run.seeking then run.audio:play(name) end end
 run.ui=ui;run.skip=skip;run.fill=fill;run.black=black;run.card=card
end
local function hideAvatar(run,character)
 local function hide(p)
  if p:IsA("BasePart") or p:IsA("Decal") then
   if run.hidden[p]==nil then run.hidden[p]=p.LocalTransparencyModifier end
   p.LocalTransparencyModifier=1
  end
 end
 for _,p in character:GetDescendants() do hide(p) end
 connect(run,character.DescendantAdded,hide)
end
local function finalize(run)
 if run.finished then return end
 run.finished=true;run.cancelled=true
 for _,c in run.connections do c:Disconnect() end
 for _,t in run.tweens do t:Cancel() end
 run.audio:destroy()
 if run.env then Env.destroy(run.env);run.env=nil end
 for p,value in run.hidden do if p.Parent then p.LocalTransparencyModifier=value end end
 Light.restore()
 local camera=workspace.CurrentCamera
 if camera then
  camera.FieldOfView=run.fov or 70;camera.CameraType=Enum.CameraType.Custom
  local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if humanoid then camera.CameraSubject=humanoid end
 end
 if run.gui then run.gui:Destroy() end
 if run.controls then run.controls:Enable() end
 active=nil
 -- Existing MenuState=false path restores spawn/controls and starts Scene 1.
 local ok,err=pcall(run.finish)
 if not ok then warn("[Opening] gameplay handoff callback failed: "..tostring(err)) end
end
local function play(run)
 createUI(run)
 local ready=os.clock()
 while not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") do
  if run.cancelled or os.clock()-ready>8 then return end
  RunService.RenderStepped:Wait()
 end
 hideAvatar(run,player.Character)
 connect(run,player.CharacterAdded,function(character)
  hideAvatar(run,character)
  run.cancelled=true -- respawn exits via the same finalizer, without replaying.
 end)
 local camera=workspace.CurrentCamera
 run.fov=camera and camera.FieldOfView or 70
 if camera then camera.CameraType=Enum.CameraType.Scriptable end
 local pm=player.PlayerScripts:FindFirstChild("PlayerModule")
 if pm then
  local ok,controls=pcall(function() return (require :: any)(pm):GetControls() end)
  if ok then run.controls=controls;controls:Disable() end
 end
 connect(run,Input.InputBegan,function(input,processed)
  if Input:GetFocusedTextBox() then return end
  if processed and input.KeyCode~=Enum.KeyCode.ButtonA then return end
  if input.KeyCode==Enum.KeyCode.E or input.KeyCode==Enum.KeyCode.ButtonA then run.holds[input.KeyCode]=true end
 end)
 connect(run,Input.InputEnded,function(input)
  run.holds[input.KeyCode]=nil
  if run.pointer==input or input.UserInputType==Enum.UserInputType.MouseButton1 then run.pointer=nil end
 end)
 connect(run,Input.WindowFocusReleased,function() table.clear(run.holds);run.pointer=nil;run.progress=0 end)
 run.env=Env.build() -- build has no async asset requests and cleans partial errors.
 if run.cancelled then return end
 local cast=Sequences.buildCast(run.env)
 local shots=Sequences.build(run.env,cast,run.ui)
 run.shots=shots
 local debugMode=RunService:IsStudio() and Config.Cinematic.Debug.Enabled
 local debugLabel
 if debugMode then
  debugLabel=make("TextLabel",run.gui,{Name="StudioShotInspector",Position=UDim2.fromOffset(24,110),Size=UDim2.fromOffset(540,55),BackgroundColor3=Color3.fromRGB(12,18,25),BackgroundTransparency=0.2,TextColor3=Color3.new(1,1,1),TextSize=16,Font=Enum.Font.Code,TextWrapped=true,ZIndex=30})
  connect(run,Input.InputBegan,function(input,processed)
   if processed then return end
   if input.KeyCode==Enum.KeyCode.RightBracket then run.seek=math.min(#shots,(run.index or 1)+1)
   elseif input.KeyCode==Enum.KeyCode.LeftBracket then run.seek=math.max(1,(run.index or 1)-1)
   elseif input.KeyCode==Enum.KeyCode.P then run.paused=not run.paused end
  end)
  run.seek=math.clamp(Config.Cinematic.Debug.StartShot,1,#shots)
  run.paused=Config.Cinematic.Debug.Paused
 end
 local index=1
 while index<=#shots and not run.cancelled do
  if run.seek then
   -- Reconstruct state in chronological order for reproducible single-shot tests.
   local desired=run.seek;run.seek=nil;run.seeking=true
   run.audio:stopSequence()
   for i=1,desired-1 do local st=shots[i].enter();shots[i].update(st,1);shots[i].leave(st) end
   run.seeking=false;index=desired
  end
  local shot=shots[index];run.index=index
  if debugLabel then debugLabel.Text=`{index}/{#shots} {shot.name}\n[ / ] jump • P pause • Output: geometric camera report` end
  run.audio:stopSequence()
  local state=shot.enter()
  local elapsed=0
  while elapsed<shot.duration and not run.cancelled and not run.seek do
   local dt=RunService.RenderStepped:Wait()
   if run.finished then return end
   if not run.paused then elapsed+=dt end
   shot.update(state,math.clamp(elapsed/shot.duration,0,1))
   local eligible=os.clock()-run.started>3 and index<#shots
   run.skip.Visible=eligible
   if eligible then
    local held=run.pointer~=nil or next(run.holds)~=nil
    run.progress=held and math.clamp(run.progress+dt/Config.Cinematic.SkipHoldSeconds,0,1) or 0
    run.fill.Size=UDim2.fromScale(run.progress,1)
    if run.progress>=1 then run.cancelled=true end
   end
  end
  if run.finished then return end
  shot.leave(state)
  index+=1
 end
 if not run.finished then
  run.skip.Visible=false;run.ui.setSubtitle(nil,"")
  for _,bar in run.bars do animate(run,bar,{Size=UDim2.fromScale(1,0)},0.25) end
  -- Tiny bounded exit, including Skip; never waits for audio or tween completion.
  local start=os.clock()
  while os.clock()-start<0.25 and not run.finished do RunService.RenderStepped:Wait() end
 end
end
function Opening.start(_parent: Frame,finish: () -> ())
 if active then return end
 local run={finish=finish,finished=false,cancelled=false,started=os.clock(),connections={},tweens={},hidden={},holds={},progress=0,audio=Audio.new()}
 active=run
 local ok,err=xpcall(function()
  MenuScene.hide()
  task.delay(Config.Cinematic.TotalTargetSeconds+45,function()
   if active==run and not run.finished and not (RunService:IsStudio() and Config.Cinematic.Debug.Enabled) then
    warn("[Opening] watchdog exit");finalize(run)
   end
  end)
  play(run)
 end,debug.traceback)
 if not ok then warn("[Opening] "..tostring(err)) end
 finalize(run)
end
return Opening
