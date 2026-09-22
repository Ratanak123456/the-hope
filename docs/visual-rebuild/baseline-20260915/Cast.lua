--!nonstrict
-- Deterministic, asset-independent R15-compatible articulated cinematic cast.
-- Root is the only anchored part; standard Motor6Ds drive segment transforms.
-- Each pose also evaluates FK immediately so camera focus sees this frame's head.
local Kit=require(script.Parent.Kit)
local Config=require(game:GetService("ReplicatedStorage").Shared.Config)
local C=require(script.Parent.Env).Colors
local V,CF,A=Vector3.new,CFrame.new,CFrame.Angles
local Cast={}
-- Small named additive poses. Locomotion, gaze and reactions layer on top.
Cast.PoseLibrary={
 NeutralIdle={Waist=A(0,0,0),LeftShoulder=A(0.02,0,-0.03),RightShoulder=A(0.02,0,0.03)},
 AlertIdle={Waist=A(0.025,0,0),LeftShoulder=A(0.08,0,-0.06),RightShoulder=A(0.1,0,0.06)},
 ResearchIdle={Waist=A(0.015,0,0),LeftShoulder=A(-0.16,0,-0.08),RightShoulder=A(-0.12,0,0.08)},
 ListeningIdle={Waist=A(0.04,0,0),LeftShoulder=A(0.1,0,-0.03),RightShoulder=A(0.1,0,0.03)},
 Thinking={Waist=A(0.06,0.02,0),LeftShoulder=A(-0.3,0,-0.08),RightShoulder=A(0.18,0,0.08)},
 CheckingTablet={Waist=A(0.03,0,0),LeftShoulder=A(-0.48,0,-0.12),RightShoulder=A(-0.58,0,0.1)},
 Pointing={Waist=A(0,0,0),RightShoulder=A(-0.52,0,0.28),RightElbow=A(-0.48,0,0)},
 Warning={Waist=A(0.08,0,0),LeftShoulder=A(0.22,0,-0.12),RightShoulder=A(0.2,0,0.12)},
 Brace={Waist=A(0.22,0,0),LeftShoulder=A(-1.1,0,-0.13),RightShoulder=A(-1.1,0,0.13)},
}
function Cast.applyPose(r,name,weight)
 local pose=Cast.PoseLibrary[name]
 if not pose then return end
 local alpha=weight or 1
 for jointName,target in pose do r.poses[jointName]=(r.poses[jointName] or CF()):Lerp(target,alpha) end
end
export type Human=any
export type AegisHandle=any
export type Creature=any
local function shape(parent,name,size,cf,color,kind,material)
 local fn=kind=="ball" and Kit.ball or kind=="wedge" and Kit.wedge or Kit.part
 local p=fn({name=name,size=size,cframe=cf,color=color,material=material or Enum.Material.SmoothPlastic,shadow=true})
 p.Parent=parent
 return p
end
local function rig(parent,name,cf)
 local m=Kit.model(name,parent)
 local root=shape(m,"HumanoidRootPart",V(1,1,1),cf,C.dark)
 root.Transparency=1;root.CanQuery=false;m.PrimaryPart=root
 local controller=Instance.new("AnimationController");controller.Parent=m
 Instance.new("Animator").Parent=controller
 return {model=m,root=root,joints={},order={},rigid={},rest={},poses={},applied={},target={},eyes={},clock=0,scale=1,expression="Focused",blend=0.22}
end
local function attach(r,host,name,size,offset,color,kind,material)
 local p=shape(r.model,name,size,host.CFrame*offset,color,kind,material)
 Kit.weld(host,p)
 table.insert(r.rigid,{part=p,host=host,offset=offset})
 return p
end
local function joint(r,host,name,jointName,size,offset,pivot,color,kind,material)
 local p=shape(r.model,name,size,host.CFrame*offset*pivot:Inverse(),color,kind,material)
 local m=Kit.joint(jointName,host,p,offset,pivot)
 r.joints[jointName]=m;r.rest[jointName]=offset
 table.insert(r.order,m)
 return p
end
function Cast.evaluate(r)
 for _,m in r.order do
  -- Preserve authored C0/C1. Transform is the additive performance layer,
  -- blended so dialogue reactions never snap at a shot boundary.
  local target=r.poses[m.Name] or CF()
  local previous=r.applied[m.Name] or m.Transform or CF()
  local alpha=if r.applied[m.Name] then (r.blend or 0.22) else 1
  local value=previous:Lerp(target,alpha)
  r.applied[m.Name]=value
  m.Transform=value
 end
end
function Cast.pose(r,name,cf)
 r.poses[name]=cf
end
local function face(r,skin,hair,variant)
 local h=r.head;local s=r.scale
 local function detail(name,size,offset,color,kind)
  return attach(r,h,name,size*s,CF(offset*s),color,kind)
 end
 -- Separate white, iris, pupil and eyebrow geometry allows live expression.
 r.face={brows={},irises={},lids={}}
 for _,side in {-1,1} do
  detail("EyeSocket",V(0.34,0.2,0.1),V(side*0.25,0.08,-0.47),skin:Lerp(C.dark,0.35),"ball")
  detail("EyeWhite",V(0.27,0.12,0.08),V(side*0.25,0.09,-0.52),Color3.fromRGB(220,215,203),"ball")
  local iris=detail("Iris",V(0.105,0.115,0.065),V(side*0.25,0.085,-0.565),Color3.fromRGB(66,43,30),"ball")
  detail("Pupil",V(0.047,0.073,0.035),V(side*0.25,0.085,-0.597),C.dark,"ball")
  local brow=detail("Brow",V(0.32,0.065,0.08),V(side*0.25,0.27,-0.51),hair,"ball")
  table.insert(r.face.brows,{part=brow,side=side})
  table.insert(r.face.irises,iris)
 end
 detail("Nose",V(0.16,0.24,0.18),V(0,-0.03,-0.54),skin,"ball")
 r.face.mouth=detail("Mouth",V(0.32,0.045,0.035),V(0,-0.28,-0.5),skin:Lerp(Color3.fromRGB(70,35,35),0.6),"ball")
 detail("LowerLip",V(0.27,0.045,0.04),V(0,-0.33,-0.49),skin:Lerp(Color3.fromRGB(156,90,79),0.4),"ball")
 for _,side in {-1,1} do detail("Ear",V(0.2,0.36,0.2),V(side*0.55,0,0),skin,"ball") end
 if variant=="Lyra" then
  detail("PracticalBun",V(0.64,0.55,0.52),V(0,0.05,0.52),hair,"ball")
  detail("EyebrowMark",V(0.04,0.16,0.02),V(-0.37,0.3,-0.54),skin:Lerp(C.ivory,0.4))
 elseif variant=="Voss" then
  for i=-3,3 do detail("Stubble",V(0.085,0.11,0.03),V(i*0.1,-0.4,-0.42),hair,"ball") end
  for _,side in {-1,1} do detail("GrayTemple",V(0.13,0.32,0.5),V(side*0.5,0.25,0.1),Color3.fromRGB(131,135,136),"ball") end
 elseif variant=="Hale" then
  for _,side in {-1,1} do detail("WeatheredCheek",V(0.21,0.025,0.018),V(side*0.34,-0.08,-0.49),skin:Lerp(C.dark,0.3)) end
 end
end
function Cast.buildHuman(parent,spec): Human
 local r=rig(parent,spec.name,spec.cframe)
 r.scale=spec.scale or 1;r.kind=spec.kind or "Scientist";r.coat=spec.coat
 r.animState={moving=false,phase="Idle",seed=spec.seed or 0,activity="Research",activityAt=0,activityIndex=1,reactionUntil=0}
 local s=r.scale
 local function j(host,name,motor,size,offset,pivot,color,kind)
  return joint(r,host,name,motor,size*s,CF(offset*s),CF(pivot*s),color,kind,Enum.Material.Fabric)
 end
 local lower=j(r.root,"LowerTorso","Root",V(1.55,0.85,0.9),V(0,0,0),V(0,0,0),spec.coat)
 local torso=j(lower,"UpperTorso","Waist",V(1.9,1.65,1),V(0,0.3,0),V(0,-0.8,0),spec.coat)
 r.torso=torso
 local head=j(torso,"Head","Neck",V(1.1,1.25,1),V(0,0.9,0),V(0,-0.65,0),spec.skin)
 r.head=head
 -- A visible neck (there was none before - the head sat straight on the
 -- torso) plus a jaw taper and a slightly wider upper skull, so the head
 -- reads as a shaped head, not a ball with a face painted on it.
 attach(r,head,"Neck",V(0.5,0.4,0.48)*s,CF(0,-0.68*s,0),spec.skin)
 attach(r,head,"Jaw",V(0.68,0.34,0.56)*s,CF(0,-0.4*s,-0.06*s),spec.skin,"wedge")
 attach(r,head,"UpperSkull",V(1.04,0.3,0.86)*s,CF(0,0.5*s,0.04*s),spec.skin)
 local hair=spec.hair or Color3.fromRGB(42,35,30)
 attach(r,head,"HairCap",V(1.12,0.48,1.03)*s,CF(0,0.48*s,0.05*s),hair,"ball",Enum.Material.Fabric)
 for i=1,5 do
  attach(r,head,"HairStrand",V(0.13,0.35,0.14)*s,CF((-0.5+i*0.16)*s,0.36*s,-0.43*s)*A(0,0,-0.25+i*0.07),hair,"ball")
 end
 face(r,spec.skin,hair,r.kind)
 if spec.headwear=="Helmet" or spec.headwear=="Hood" then
  attach(r,head,"HeadProtection",V(1.28,0.6,1.2)*s,CF(0,0.58*s,0.06*s),spec.trim,"ball",Enum.Material.Fabric)
 end
 if r.kind=="Lyra" or r.kind=="Voss" then
  for _,side in {-1,1} do
   local y=r.kind=="Lyra" and 0.55 or 0.08
   attach(r,head,"OpticalFrame",V(0.43,0.25,0.12)*s,CF(side*0.25*s,y*s,-0.55*s),C.dark)
   local glass=attach(r,head,"OpticalLens",V(0.34,0.17,0.13)*s,CF(side*0.25*s,y*s,-0.57*s),C.cyan)
   glass.Material=Enum.Material.Glass;glass.Transparency=0.65;glass.CanQuery=false
  end
 end
 -- Layered long coat, seams, pockets, harness, padded collar and equipment.
 for _,side in {-1,1} do
  attach(r,lower,"CoatSkirt",V(0.94,1.3,1.02)*s,CF(side*0.48*s,-0.65*s,0)*A(0,0,-side*0.06),spec.coat,"wedge",Enum.Material.Fabric)
  attach(r,torso,"PaddedCollar",V(0.85,0.4,1.2)*s,CF(side*0.45*s,0.78*s,0),spec.trim,"wedge",Enum.Material.Fabric)
  attach(r,torso,"ChestPocket",V(0.55,0.45,0.18)*s,CF(side*0.5*s,-0.18*s,-0.5*s),spec.coat)
  attach(r,torso,"Harness",V(0.13,1.45,0.13)*s,CF(side*0.68*s,0,-0.52*s),C.dark)
 end
 attach(r,torso,"CenterZipper",V(0.035,1.6,0.08)*s,CF(0,0,-0.54*s),C.metal)
 attach(r,torso,"IDPatch",V(0.33,0.17,0.06)*s,CF(0.43*s,0.36*s,-0.59*s),spec.trim)
 attach(r,lower,"UtilityBelt",V(1.68,0.23,1.04)*s,CF(0,-0.1*s,0),C.dark)
 attach(r,lower,"Buckle",V(0.22,0.22,0.1)*s,CF(0,-0.1*s,-0.56*s),C.ivory)
 attach(r,torso,"ExpeditionPack",V(1.2,1.45,0.6)*s,CF(0,0,0.71*s),C.metal,"ball",Enum.Material.Fabric)
 if r.kind=="Voss" then attach(r,torso,"ScarfTail",V(0.5,1.1,0.17)*s,CF(-0.3*s,0.25*s,-0.59*s),C.ivory,"wedge",Enum.Material.Fabric) end
 r.hands={}
 for _,side in {-1,1} do
  local prefix=side<0 and "Left" or "Right"
  local arm=j(torso,prefix.."UpperArm",prefix.."Shoulder",V(0.67,1.05,0.7),V(side*1.05,0.65,0),V(0,0.43,0),spec.coat)
  attach(r,arm,"ShoulderPad",V(0.92,0.42,0.86)*s,CF(0,0.44*s,0),spec.trim,"wedge",Enum.Material.Fabric)
  local fore=j(arm,prefix.."LowerArm",prefix.."Elbow",V(0.61,0.9,0.63),V(0,-0.53,0),V(0,0.4,0),spec.coat)
  local hand=j(fore,prefix.."Hand",prefix.."Wrist",V(0.53,0.48,0.48),V(0,-0.48,0),V(0,0.2,0),C.dark)
  r.hands[prefix]=hand
  attach(r,fore,"InsulatedCuff",V(0.68,0.2,0.71)*s,CF(0,-0.33*s,0),spec.trim,"wedge",Enum.Material.Fabric)
  attach(r,hand,"Palm",V(0.5,0.16,0.44)*s,CF(0,-0.14*s,-0.14*s),C.dark)
  attach(r,hand,"FingerBlock",V(0.46,0.15,0.3)*s,CF(0,-0.14*s,-0.4*s),C.dark,"wedge")
  attach(r,hand,"Thumb",V(0.16,0.26,0.16)*s,CF(side*0.28*s,-0.05*s,-0.16*s)*A(0,0,-side*0.5),C.dark,"wedge")
  local thigh=j(lower,prefix.."UpperLeg",prefix.."Hip",V(0.75,1.05,0.8),V(side*0.46,-0.35,0),V(0,0.48,0),spec.pants)
  local shin=j(thigh,prefix.."LowerLeg",prefix.."Knee",V(0.68,1,0.7),V(0,-0.55,0),V(0,0.48,0),spec.pants)
  local foot=j(shin,prefix.."Foot",prefix.."Ankle",V(0.8,0.5,1.1),V(0,-0.5,0),V(0,0.2,0.2),C.dark)
  attach(r,foot,"BootSole",V(0.94,0.17,1.3)*s,CF(0,-0.24*s,0),C.metal)
  attach(r,foot,"ToeCap",V(0.8,0.34,0.44)*s,CF(0,-0.04*s,-0.52*s),C.metal,"wedge")
  attach(r,foot,"AnkleCuff",V(0.86,0.3,0.88)*s,CF(0,0.34*s,0.05*s),C.dark,"wedge",Enum.Material.Fabric)
  for n=1,3 do attach(r,foot,"BootLace",V(0.48,0.045,0.08)*s,CF(0,0.22*s,(-0.4+n*0.18)*s),C.ivory) end
 end
 r.scanner=attach(r,r.hands.Left,"TranslationScanner",V(0.55,0.13,0.8)*s,CF(0,-0.08*s,-0.28*s)*A(-0.3,0,0),C.metal)
 attach(r,r.scanner,"ScannerScreen",V(0.42,0.02,0.56)*s,CF(0,0.08*s,0),C.cyan,nil,Enum.Material.Neon)
 if r.kind=="Hale" or spec.weapon then
  local host=spec.weapon and r.hands.Right or lower
  r.weapon=attach(r,host,"ExpeditionRifle",V(0.2,0.3,1.35)*s,CF(0.2*s,-0.1*s,-0.5*s),C.metal)
  attach(r,r.weapon,"Barrel",V(0.11,0.11,0.7)*s,CF(0,0,-0.85*s),C.dark)
  attach(r,r.weapon,"Stock",V(0.25,0.4,0.45)*s,CF(0,-0.05*s,0.75*s),C.dark)
 end
 Cast.evaluate(r)
 return r
end
local N=Config.Cinematic.Names
function Cast.buildLyra(parent,cf)
 return Cast.buildHuman(parent,{name=N.Lyra,kind="Lyra",cframe=cf,scale=1,skin=Color3.fromRGB(176,132,100),hair=Color3.fromRGB(38,27,22),coat=C.ivory,trim=C.orange,pants=C.dark})
end
function Cast.buildVoss(parent,cf)
 return Cast.buildHuman(parent,{name=N.Voss,kind="Voss",cframe=cf,scale=1.06,skin=Color3.fromRGB(207,177,149),coat=Color3.fromRGB(37,48,65),trim=C.ivory,pants=C.dark})
end
function Cast.buildHale(parent,cf)
 return Cast.buildHuman(parent,{name=N.Hale,kind="Hale",cframe=cf,scale=1.12,skin=Color3.fromRGB(192,151,120),hair=Color3.fromRGB(141,143,142),coat=C.dark,trim=Color3.fromRGB(132,66,62),pants=C.metal})
end
local skins={Color3.fromRGB(225,186,158),Color3.fromRGB(157,112,83),Color3.fromRGB(105,73,55),Color3.fromRGB(187,140,111)}
function Cast.buildScientist(parent,cf,rng,index)
 return Cast.buildHuman(parent,{name=`Scientist{index}`,seed=index,kind="Scientist",cframe=cf,scale=0.92+index%4*0.04,skin=skins[index%4+1],hair=Color3.fromRGB(40+index*8,35+index*8,30+index*8),coat=C.ivory:Lerp(C.ice,index%3*0.18),trim=C.orange,pants=C.dark,headwear=index%2==0 and "Hood" or "Hair"})
end
function Cast.buildSoldier(parent,cf,rng,index)
 return Cast.buildHuman(parent,{name=`Soldier{index}`,seed=index+12,kind="Soldier",cframe=cf,scale=0.96+index%3*0.07,skin=skins[(index+1)%4+1],coat=C.metal:Lerp(C.ivory,index%3*0.12),trim=C.metal,pants=C.dark,headwear="Helmet",weapon=true})
end
function Cast.lookAt(r,target)
 r.lookTarget=target
end
function Cast.setWalking(r,moving) r.animState.moving=moving end
function Cast.act(r,action,expression,target)
 r.animState.phase=action or "Idle";r.expression=expression or "Focused";r.lookTarget=target
 r.animState.actionAt=os.clock()
 r.animState.reactionUntil=if action=="Stumble" or action=="Flinch" or action=="StepBack" then os.clock()+0.65 else 0
end
function Cast.setActivity(r,activity)
 r.animState.activity=activity;r.animState.phase="Operate";r.animState.activityIndex=1
 r.animState.activityAt=os.clock()+((r.animState.seed%17)/17)*1.8
end
function Cast.react(r,expression,target,intensity)
 local level=intensity or 1
 r.lookTarget=target;r.expression=expression or "Concerned"
 r.animState.phase=if level>=0.85 then "Stumble" elseif level>=0.45 then "Flinch" else "Listen"
 r.animState.actionAt=os.clock();r.animState.reactionUntil=os.clock()+0.35+0.3*level
end
function Cast.place(r,pos,target)
 r.root.CFrame=CFrame.lookAt(pos,V(target.X,pos.Y,target.Z))
 Cast.evaluate(r)
end
function Cast.walk(r,from,to,t,running)
 local p=from:Lerp(to,t)
 local d=to-from
 if d.Magnitude>0.01 then Cast.place(r,p,p+d) end
 r.animState.moving=t>0 and t<1
 r.animState.phase=running and "Run" or "Walk"
end
function Cast.stepAnimate(r,now)
 local phase=r.animState.phase
 if phase=="Operate" and now>=r.animState.activityAt then
  local activities={"TypingConsole","CheckingTablet","AdjustingCable","Monitoring","WritingNotes"}
  if r.kind=="Worker" then activities={"OperateDrill","CarryCase","CheckCable","ClearIce"}
  elseif r.kind=="Soldier" then activities={"Radio","SecurityWatch","CheckWrist","PatrolIdle"} end
  r.animState.activity=activities[r.animState.activityIndex] or activities[1]
  r.animState.activityIndex=(r.animState.activityIndex%#activities)+1
  r.animState.activityAt=now+3.5+(r.animState.seed%23)/8
 end
 if phase=="Operate" then phase=r.animState.activity end
 local speed=(phase=="Run") and 11 or 6
 local wave=math.sin(now*speed+r.animState.seed)
 local move=r.animState.moving
 local breath=math.sin(now*1.7+r.animState.seed)*0.012
 r.poses.Waist=A(breath,0,0);r.poses.Neck=CF()
 for _,side in {-1,1} do
  local p=side<0 and "Left" or "Right"
  r.poses[p.."Hip"]=A(move and wave*side*0.4 or 0,0,0)
  r.poses[p.."Knee"]=A(move and math.max(0,-wave*side)*0.65 or 0,0,0)
  r.poses[p.."Ankle"]=A(move and -math.max(0,-wave*side)*0.25 or 0,0,0)
  r.poses[p.."Shoulder"]=A(move and -wave*side*0.28 or 0,0,side*0.04)
  r.poses[p.."Elbow"]=A(-0.1,0,0)
 end
 if phase=="Idle" then Cast.applyPose(r,"NeutralIdle",0.7)
 elseif phase=="Listen" then Cast.applyPose(r,"ListeningIdle",0.8)
 elseif phase=="Monitoring" or phase=="SecurityWatch" then Cast.applyPose(r,"AlertIdle",0.65)
 elseif phase=="CheckingTablet" then Cast.applyPose(r,"CheckingTablet",0.75)
 elseif phase=="Brace" then Cast.applyPose(r,"Brace",0.8)
 end
 if phase=="Scan" or phase=="Operate" or phase=="ClearIce" or phase=="CheckingTablet" then
  r.poses.LeftShoulder=A(-0.5,0,-0.15);r.poses.LeftElbow=A(-1.1,0,0)
  r.poses.RightShoulder=A(-0.4,0,0.1);r.poses.RightElbow=A(-0.7+(phase=="ClearIce" and math.sin(now*2)*0.15 or 0),0,0)
 elseif phase=="TypingConsole" or phase=="WritingNotes" then
  local tap=math.sin(now*7+r.animState.seed)*0.08
  r.poses.LeftShoulder=A(-0.65+tap,0,-0.12);r.poses.LeftElbow=A(-1.05,0,0)
  r.poses.RightShoulder=A(-0.7-tap,0,0.12);r.poses.RightElbow=A(-1.0,0,0)
 elseif phase=="AdjustingCable" or phase=="CheckCable" or phase=="OperateDrill" then
  r.poses.LeftShoulder=A(-0.8,0,-0.22);r.poses.LeftElbow=A(-0.9+math.sin(now*2.8)*0.12,0,0)
  r.poses.RightShoulder=A(-0.45,0,0.2);r.poses.RightElbow=A(-0.7,0,0)
 elseif phase=="Monitoring" or phase=="SecurityWatch" or phase=="PatrolIdle" then
  r.poses.LeftShoulder=A(0.06,0,-0.05);r.poses.RightShoulder=A(0.12,0,0.05)
  r.poses.LeftElbow=A(-0.25,0,0);r.poses.RightElbow=A(-0.18,0,0)
 elseif phase=="Radio" or phase=="CheckWrist" then
  r.poses.LeftShoulder=A(-0.3,0,-0.15);r.poses.LeftElbow=A(-0.65,0,0)
  r.poses.RightShoulder=A(-0.78,0,0.18);r.poses.RightElbow=A(-0.95,0,0)
 elseif phase=="CarryCase" then
  r.poses.LeftShoulder=A(0.18,0,-0.16);r.poses.RightShoulder=A(0.18,0,0.16)
  r.poses.LeftElbow=A(-0.3,0,0);r.poses.RightElbow=A(-0.3,0,0)
 elseif phase=="Speak" then
  -- A single gesture anchored to line-start decays to nothing well before a
  -- longer line finishes, leaving the speaker static while still talking.
  -- Two different-frequency sines summed together keep the hand moving for
  -- the whole line without the fixed period reading as a repeating loop.
  local t=now-(r.lineStart or now)
  local emphasis=0.08+math.sin(t*2.3)*0.16+math.sin(t*3.7+1.1)*0.1
  r.poses.RightShoulder=A(-emphasis,0,0.09);r.poses.RightElbow=A(-0.25-emphasis,0,0)
 elseif phase=="Listen" then
  -- A listener is not "Idle" - a slow weight shift onto one foot and a
  -- slight forward lean toward the speaker, distinct from standing around.
  local shift=math.sin(now*0.55+r.animState.seed)*0.05
  r.poses.Waist=A(breath+0.035,shift,0)
  r.poses.LeftShoulder=A(0.1,0,shift*0.4);r.poses.RightShoulder=A(0.1,0,-shift*0.4)
  r.poses.LeftElbow=A(-0.32,0,0);r.poses.RightElbow=A(-0.32,0,0)
 elseif phase=="Authority" then
  r.poses.LeftShoulder=A(0.35,0,0.1);r.poses.RightShoulder=A(0.35,0,-0.1)
  r.poses.LeftElbow=A(-0.6,0,0);r.poses.RightElbow=A(-0.6,0,0)
 elseif phase=="Reach" or phase=="Pull" or phase=="TouchCore" or phase=="Brace" or phase=="Defend" then
  for _,p in {"Left","Right"} do
   r.poses[p.."Shoulder"]=A(-1.1,0,p=="Left" and -0.13 or 0.13)
   r.poses[p.."Elbow"]=A(phase=="Brace" and -0.9 or -0.3,0,0)
  end
  if phase=="Brace" then r.poses.Waist=A(0.22,0,0);r.poses.LeftHip=A(-0.2,0,-0.12);r.poses.RightHip=A(0.2,0,0.12) end
 elseif phase=="Stumble" or phase=="Help" then
  r.poses.Waist=A(0.22,0,math.sin(now*2)*0.1);r.poses.RightShoulder=A(-0.7,0,0.5)
 elseif phase=="Flinch" then
  local q=math.clamp(1-(now-(r.animState.actionAt or now))/0.38,0,1)
  r.poses.Waist=A(0.18*q,0,-0.08*q)
  r.poses.LeftShoulder=A(0.35*q,0,-0.18*q);r.poses.RightShoulder=A(0.28*q,0,0.18*q)
  r.poses.LeftElbow=A(-0.5*q,0,0);r.poses.RightElbow=A(-0.42*q,0,0)
 elseif phase=="StepBack" then
  r.poses.Waist=A(0.22,0,0);r.poses.LeftShoulder=A(0.3,0,-0.15);r.poses.RightShoulder=A(0.3,0,0.15)
 end
 if r.lookTarget then
  local localTarget=r.root.CFrame:PointToObjectSpace(r.lookTarget)
  local yaw=math.clamp(math.atan2(-localTarget.X,-localTarget.Z),-math.rad(58),math.rad(58))
  local pitch=math.clamp(math.atan2(localTarget.Y-2.6*r.scale,Vector2.new(localTarget.X,localTarget.Z).Magnitude),-math.rad(32),math.rad(32))
  local bodyTurn=math.clamp(yaw*0.28,-math.rad(18),math.rad(18))
  r.poses.Neck=A(pitch,yaw-bodyTurn,0)
  r.poses.Waist=r.poses.Waist*A(0,bodyTurn,0)
 end
 Cast.evaluate(r)
 -- Facial geometry is evaluated after the head, never left behind as it turns.
 local expr=r.expression
 local fear=expr=="Afraid" or expr=="Horrified" or expr=="Amazed"
 local angry=expr=="Angry" or expr=="Determined"
 for _,b in r.face.brows do
  b.part:SetAttribute("ExpressionTilt",b.side*(angry and -0.22 or expr=="Sad" and 0.22 or fear and 0.08 or 0))
 end
 r.face.mouth.Size=V(0.32,fear and 0.15 or phase=="Speak" and 0.045+math.abs(math.sin(now*9))*0.055 or 0.045,0.035)*r.scale
end
-- Mechanical guardian: 62 studs standing, 38 kneeling. Individual limbs,
-- fingers, neck pistons, core rotor, armor flakes and conduit plates.
function Cast.buildAegisZero(parent,cf,scale): AegisHandle
 local r=rig(parent,"AegisZeroSealed",cf);r.scale=scale or 10;r.dummy=r.model;r.chains={};r.chainData={};r.fingers={};r.ice={}
 local pelvis=joint(r,r.root,"Pelvis","Root",V(12,6,8),CF(),CF(),C.metal,"ball")
 r.torso=joint(r,pelvis,"UpperTorso","Waist",V(17,17,9),CF(0,3,0),CF(0,-7,0),C.metal,"ball")
 r.head=joint(r,r.torso,"Head","Neck",V(7,8,6),CF(0,9,0),CF(0,-3,0),C.metal,"wedge")
 r.core=attach(r,r.torso,"ChestCore",V(5,5,1.2),CF(0,1,-5),C.orange,"ball",Enum.Material.Neon)
 r.coreLight=Kit.light(r.core,C.warm,45,1)
 r.rotor=joint(r,r.torso,"CoreRotor","CoreRotor",V(5.6,0.5,1.3),CF(0,1,-5.2),CF(),C.gold)
 for _,side in {-1,1} do
  local prefix=side<0 and "Left" or "Right"
  local arm=joint(r,r.torso,prefix.."UpperArm",prefix.."Shoulder",V(7,11,7),CF(side*11,6,0),CF(0,4,0),C.metal,"ball")
  local fore=joint(r,arm,prefix.."LowerArm",prefix.."Elbow",V(6,10,6),CF(0,-6,0),CF(0,4,0),C.metal,"ball")
  local hand=joint(r,fore,prefix.."Hand",prefix.."Wrist",V(5,4,3.5),CF(0,-6,0),CF(0,1.5,0),C.metal)
  for f=1,4 do
   local finger=joint(r,hand,prefix.."Finger"..f,prefix.."Finger"..f,V(0.8,3,1),CF(-2.3+f, -1.5,-0.7),CF(0,1.2,0),C.ivory)
   attach(r,finger,"Knuckle",V(1,0.8,1.1),CF(0,0.8,0),C.gold,"ball")
   table.insert(r.fingers,prefix.."Finger"..f)
  end
  local thigh=joint(r,pelvis,prefix.."Thigh",prefix.."Hip",V(7,12,8),CF(side*5,-2,0),CF(0,5,0),C.metal,"ball")
  local shin=joint(r,thigh,prefix.."Shin",prefix.."Knee",V(6.5,12,7),CF(0,-7,0),CF(0,5,0),C.metal,"ball")
  local foot=joint(r,shin,prefix.."Foot",prefix.."Ankle",V(7,4,12),CF(0,-7,0),CF(0,1,3),C.metal,"wedge")
  for _,host in {arm,fore,thigh,shin,r.torso} do
   local sz=host.Size
   for layer=1,3 do
    local armor=attach(r,host,"IvoryArmorPlate",V(sz.X*1.07,sz.Y*0.3,sz.Z*0.28),CF(0,sz.Y*(0.4-layer*0.27),-sz.Z*0.45),C.ivory,"wedge")
    attach(r,armor,"WeatheredGoldEdge",V(armor.Size.X*0.9,0.15,0.15),CF(0,armor.Size.Y/2,-0.2),C.gold)
    attach(r,armor,"BattleScore",V(armor.Size.X*0.3,0.05,0.05),CF(-0.5,0,-armor.Size.Z/2-0.03)*A(0,0,0.22),C.metal)
   end
   attach(r,host,"Conduit",V(0.24,sz.Y*0.65,0.2),CF(sz.X*0.42,0,-sz.Z*0.54),C.orange,nil,Enum.Material.Neon)
   attach(r,host,"JointBearing",V(sz.X*0.7,1.4,sz.Z*0.7),CF(0,-sz.Y/2,0),C.gold,"ball")
  end
  attach(r,arm,"BroadPauldron",V(10,4,10),CF(side,5,0),C.ivory,"wedge")
  local frost=attach(r,arm,"FracturingIce",V(9,2,9),CF(side,7,0),C.ice,"wedge",Enum.Material.Ice)
  frost.Transparency=0.25;table.insert(r.ice,frost)
  attach(r,foot,"ToeCap",V(7.5,2,6),CF(0,1,-4),C.ivory,"wedge")
  local eye=attach(r,r.head,"Eye",V(1.7,0.5,0.3),CF(side*1.6,0.5,-3.2),C.orange,nil,Enum.Material.Neon)
  table.insert(r.eyes,eye)
  attach(r,r.head,"CheekArmor",V(2,3,1),CF(side*2,-1,-3),side<0 and C.ivory or C.metal,"wedge")
  attach(r,r.torso,"BackPylon",V(2,18,3),CF(side*5,4,6)*A(-0.3,0,side*0.1),C.ivory,"wedge")
  attach(r,r.torso,"EmbeddedBlade",V(1,13,2),CF(side*7,10,5)*A(0.4,0,side*0.3),C.gold,"wedge")
 end
 r.poses.Waist=A(math.rad(20),0,0);r.poses.Neck=A(math.rad(-25),0,0)
 for _,p in {"Left","Right"} do
  r.poses[p.."Hip"]=A(0,0,0)
  r.poses[p.."Knee"]=A(math.rad(-90),0,0)
  r.poses[p.."Ankle"]=A(math.rad(90),0,0)
  r.poses[p.."Shoulder"]=A(math.rad(-18),0,p=="Left" and -0.12 or 0.12)
  r.poses[p.."Elbow"]=A(math.rad(-24),0,0)
 end
 Cast.evaluate(r)
 for index,prefix in {"Left","Right"} do
  local hand=r.model:FindFirstChild(prefix.."Hand")
  local chain=Kit.model(prefix.."RestraintChain",r.model)
  local links={}
  for i=1,14 do
   local link=Kit.model("InterlockingLink",chain)
   for _,side in {-1,1} do
    shape(link,"LinkSide",V(0.35,1.8,0.35),CF(side*0.6,0,0),C.gold,"ball",Enum.Material.Metal)
    shape(link,"LinkEnd",V(1.45,0.35,0.35),CF(0,side*0.8,0),C.gold,"ball",Enum.Material.Metal)
   end
   table.insert(links,link)
  end
  table.insert(r.chains,chain)
  table.insert(r.chainData,{hand=hand,links=links,anchor=cf.Position+V(index==1 and -5 or 5,-cf.Position.Y+9500,6),broken=false})
 end
 return r
end
function Cast.updateChains(r,t)
 for _,chain in r.chainData do
  local from=chain.hand.Position
  for i,link in chain.links do
   local a=i/#chain.links
   local pos=from:Lerp(chain.anchor,a)
   if chain.broken then
    local dt=math.min(t-chain.breakTime,1.5)
    pos+=V(math.sin(i)*dt*6,-dt*dt*12,math.cos(i)*dt*4)
   end
   local direction=chain.anchor-from
   link:PivotTo(CFrame.lookAt(pos,pos+direction)*A(math.pi/2,(i%2)*math.pi/2,0))
  end
 end
end
-- Quintic "smootherstep" (Perlin): zero first AND second derivative at both
-- ends, unlike the cubic Kit.smooth curve - that extra flatness at rest is
-- what reads as inertia (a heavy mass reluctant to start, and reluctant to
-- stop) rather than a generic ease. Every Aegis Zero pose driver below
-- reshapes its incoming `amount` through this once, so every call site can
-- keep passing plain linear shot-progress without the mecha ever moving at
-- a robotic constant speed.
local function heavy(t)
 t=math.clamp(t,0,1)
 return t*t*t*(t*(t*6-15)+10)
end
function Cast.setAegisAwaken(r,rawAmount)
 local amount=heavy(rawAmount)
 r.poses.CoreRotor=A(0,0,amount*math.pi*3)
 r.poses.Neck=A(-0.44+amount*0.5,0,0)
 for i,name in r.fingers do r.poses[name]=A(-math.clamp(amount*2-i*0.06,0,1)*1.1,0,0) end
 for _,prefix in {"Left","Right"} do r.poses[prefix.."Wrist"]=A(0,amount*0.16,0) end
 r.core.Color=C.orange:Lerp(C.warm,amount)
 if r.coreLight then r.coreLight.Brightness=1+amount*3 end
 for _,eye in r.eyes do eye.Transparency=1-math.clamp((amount-0.65)/0.35,0,1) end
 for _,ice in r.ice do ice.Transparency=math.clamp(0.25+amount*0.75,0,1) end
 Cast.evaluate(r)
end
function Cast.setAegisRise(r,rawAmount)
 local amount=heavy(rawAmount)
 r.poses.Waist=A(0.35-amount*0.3,0,0)
 for _,p in {"Left","Right"} do
  r.poses[p.."Shoulder"]=A(-0.32+amount*0.3,0,p=="Left" and -0.12 or 0.12)
  r.poses[p.."Elbow"]=A(-0.42+amount*0.22,0,0)
 end
 Cast.evaluate(r)
end
function Cast.breakChain(r,index,time)
 local c=r.chainData[index]
 if c then c.broken=true;c.breakTime=time or 0 end
end
-- Anatomy per the visual-director brief: a narrow waist widening into an
-- armored chest, two reverse-jointed legs (hip and knee bend the SAME
-- rotational way, so the shin angles backward like a bird's - not a human
-- knee), two forelimbs reaching to roughly knee level with a three-digit
-- hand, a small forward-projecting wedge head with one horizontal sensor
-- slit (no face), and three large backward-facing spine fins. One coherent
-- creature read from a silhouette, not a stack of plates.
local function biomech(parent,cf0,scale,name)
 local r=rig(parent,name,cf0);r.scale=scale;r.ice={};r.eyes={}
 local s=scale
 -- CFrame has no CFrame*number operator - scale each component going in,
 -- not the constructed CFrame coming out.
 local function cf(x,y,z) return CF(x*s,y*s,z*s) end
 local pelvis=joint(r,r.root,"Pelvis","Root",V(1.3,1.2,1.2)*s,cf(0,0,0),cf(0,0,0),Color3.fromRGB(26,24,32))
 r.torso=joint(r,pelvis,"Thorax","Waist",V(2.6,3,2)*s,cf(0,1.5,0),cf(0,-1.4,0),Color3.fromRGB(30,28,36))
 -- Rib-like segmented armor around the chest - three plates, not eight.
 for i=1,3 do
  attach(r,r.torso,"RibPlate"..i,V(2.9-i*0.28,0.5,2.2-i*0.18)*s,cf(0,1.05-i*0.75,0),C.metal,"wedge")
 end
 attach(r,r.torso,"SternumRidge",V(0.4,2.6,0.3)*s,cf(0,0.1,-1),Color3.fromRGB(174,174,155))
 -- Small forward-projecting head, no face - one recessed horizontal sensor
 -- slit made of 5 segments (kept as r.eyes for the existing progressive
 -- reveal - Cast.setCreatureEyes lights them left-to-right).
 r.head=joint(r,r.torso,"NarrowHead","HeadJoint",V(1.3,1,1.9)*s,cf(0,1.65,-0.3),cf(0,-0.5,0.4),C.metal,"wedge")
 local slit=attach(r,r.head,"SensorSlit",V(1.0,0.16,0.15)*s,cf(0,0.05,-0.95),Color3.fromRGB(20,18,26))
 for i=1,5 do
  local t=(i-3)/2
  local eye=attach(r,slit,"SensorSegment"..i,V(0.14,0.1,0.06)*s,cf(t*0.42,0,-0.09),C.violet,nil,Enum.Material.Neon)
  eye.Transparency=1;table.insert(r.eyes,eye)
 end
 -- Three large, readable back spines instead of a dozen small wing spars.
 for i=1,3 do
  local t=(i-2)
  attach(r,r.torso,"SpineFin"..i,V(0.35,2.6-math.abs(t)*0.5,1.9-math.abs(t)*0.3)*s,cf(t*0.55,0.9-i*0.1,1.05)*A(0.55,0,0),Color3.fromRGB(24,22,30),"wedge")
 end
 -- Two forelimbs, reaching to roughly knee level: thin upper arm, a
 -- slightly larger forearm, a hand with three long digits.
 for _,side in {-1,1} do
  local prefix=side<0 and "Left" or "Right"
  local arm=joint(r,r.torso,prefix.."Arm",prefix.."Shoulder",V(0.55,2.8,0.6)*s,cf(side*1.35,1.1,0),cf(0,1.3,0),Color3.fromRGB(30,28,36),"wedge")
  local forearm=joint(r,arm,prefix.."Forearm",prefix.."Elbow",V(0.62,2.6,0.68)*s,cf(0,-1.3,0),cf(0,1.25,0),Color3.fromRGB(30,28,36))
  local hand=joint(r,forearm,prefix.."Hand",prefix.."Wrist",V(0.5,0.7,0.55)*s,cf(0,-1.25,0),cf(0,0.32,0),Color3.fromRGB(22,20,28))
  for d=1,3 do
   local dt=(d-2)*0.32
   local base=attach(r,hand,"Digit"..d.."Base",V(0.15,0.55,0.16)*s,cf(dt,-0.28,-0.15),Color3.fromRGB(170,165,151),"wedge")
   attach(r,base,"Digit"..d.."Tip",V(0.11,0.4,0.12)*s,cf(0,-0.42,-0.06)*A(0.3,0,0),Color3.fromRGB(170,165,151),"wedge")
  end
  r.poses[prefix.."Shoulder"]=A(0.3,0,side*-0.18)
  r.poses[prefix.."Elbow"]=A(0.55,0,0)
  -- Two reverse-jointed legs. Hip and knee bend the SAME rotational
  -- direction (both positive here) rather than opposite, which is what
  -- makes the shin read as angled backward like a bird's leg instead of a
  -- human knee.
  local thigh=joint(r,pelvis,prefix.."Thigh",prefix.."Hip",V(0.85,2.5,0.95)*s,cf(side*0.55,-0.5,0),cf(0,1.15,0),Color3.fromRGB(28,26,34),"wedge")
  local shin=joint(r,thigh,prefix.."Shin",prefix.."Knee",V(0.68,2.5,0.8)*s,cf(0,-1.15,0.15),cf(0,1.15,0),Color3.fromRGB(28,26,34))
  local foot=joint(r,shin,prefix.."Foot",prefix.."Ankle",V(0.55,0.5,1.9)*s,cf(0,-1.2,-0.3),cf(0,0.22,0.55),Color3.fromRGB(20,18,26),"wedge")
  for c=1,3 do
   attach(r,foot,"ToeClaw"..c,V(0.16,0.18,0.7)*s,cf((c-2)*0.16,-0.02,-1.05),Color3.fromRGB(170,165,151),"wedge")
  end
  r.poses[prefix.."Hip"]=A(0.55,0,0)
  r.poses[prefix.."Knee"]=A(0.85,0,0)
  r.poses[prefix.."Ankle"]=A(-0.5,0,0)
 end
 for i=1,4 do
  local frost=attach(r,r.torso,"IceFracture",V(1.6,1.2,0.4)*s,cf(i%2==0 and 1 or -1,1-i*0.5,-1)*A(0,0,i*0.4),C.ice,"wedge",Enum.Material.Ice)
  frost.Transparency=0.5;table.insert(r.ice,frost)
 end
 Cast.evaluate(r)
 return r
end
function Cast.buildSovereign(parent,cf,scale) return biomech(parent,cf,scale or 5,"SovereignBelow") end
function Cast.buildWarden(parent,cf,scale,frozen)
 local r=biomech(parent,cf,scale,"Warden")
 if not frozen then for _,p in r.ice do p.Transparency=1 end end
 return r
end
-- Alien stillness: the opposite movement language from Aegis Zero's `heavy`
-- curve above. Holds almost motionless (a small deliberate "tell," not a
-- full freeze - twitching constantly would undercut it) through `holdUntil`,
-- then moves in one controlled, unnervingly fast burst. A lower `holdUntil`
-- makes something commit to movement earlier than the rest of the body -
-- used below to make the head turn before the torso/limbs follow.
local function sudden(t,holdUntil)
 t=math.clamp(t,0,1);holdUntil=holdUntil or 0.7
 if t<=holdUntil then return (t/holdUntil)*0.06 end
 local burst=(t-holdUntil)/(1-holdUntil)
 return 0.06+0.94*(burst*burst*(3-2*burst))
end
function Cast.setCreatureEyes(r,amount)
 local a=sudden(amount,0.55)
 for i,eye in r.eyes do eye.Transparency=1-math.clamp(a*1.6-(i-1)*0.12,0,1) end
end
function Cast.setCreatureLimbUnfold(r,rawAmount)
 -- The head commits first (holdUntil 0.3), the limbs follow later (0.7) -
 -- "its head may turn before its torso." Arms swing out from a tucked rest
 -- pose into a threatening extended reach; legs partially straighten out of
 -- their frozen crouch toward a ready stance - the reverse-jointed knee
 -- angle (hip and knee bending the same rotational way) is preserved at
 -- every point along the unfold, not just at the rest pose.
 r.poses.HeadJoint=A(0,sudden(rawAmount,0.3)*0.6,0)
 local amount=sudden(rawAmount,0.7)
 for _,side in {-1,1} do
  local prefix=side<0 and "Left" or "Right"
  r.poses[prefix.."Shoulder"]=A(0.3-amount*0.9,0,side*(-0.18-amount*0.4))
  r.poses[prefix.."Elbow"]=A(0.55-amount*0.35,0,0)
  r.poses[prefix.."Hip"]=A(0.55-amount*0.15,0,0)
  r.poses[prefix.."Knee"]=A(0.85-amount*0.25,0,0)
  r.poses[prefix.."Ankle"]=A(-0.5+amount*0.15,0,0)
 end
 Cast.evaluate(r)
end
function Cast.removeIceShell(r,amount)
 for i,p in r.ice do
  p.Transparency=math.clamp(0.5+(amount or 1)*0.5,0,1)
 end
end
return Cast
