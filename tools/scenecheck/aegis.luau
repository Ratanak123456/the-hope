--!nonstrict
--[[
 AEGIS ZERO, ON ITS OWN.

 The isolated review the redesign brief asks for before anything is judged in
 the cinematic: the machine standing and in its sealed kneel, clean (no
 damage, frost or chains) and finished, each from front, three-quarter, side
 and back, plus solid-black silhouettes - with one human beside it for scale.

 The clean pass is the real test. If the bare masses do not read as head,
 shoulders, chest, core, waist, pelvis, arms, hands, thighs, knees, shins and
 feet at thumbnail size, no amount of detail on top will fix it.

   ./tools/scenecheck/run.sh aegis
]]

local Cast=MOD.Cast
local Aegis=MOD.AegisCinematic
local V=Vector3.new
local A=CFrame.Angles

RBX.useSolids=false
RBX.floorY=0
RBX.studio=false
Cast.reset()

local root=Instance.new("Folder")
root.Name="AegisBench"
root.Parent=RBX.workspace

local SPACING=600
local stages={}
local function stage(label,x,build)
 local r=build(CFrame.new(V(x,40,0))*A(0,math.pi,0))
 table.insert(stages,{label=label,x=x,r=r})
 return r
end
-- Every stage faces +Z (rotated like the cinematic's), so a "front" camera
-- sits at +Z.
local standing=stage("clean-standing",0,function(cf)
 local r=Aegis.build(root,cf,10,{floorY=0,clean=true});Aegis.setStanding(r);return r end)
stage("clean-sealed",SPACING,function(cf)
 return Aegis.build(root,cf,10,{floorY=0,clean=true}) end)
local final=stage("final-sealed",SPACING*2,function(cf)
 return Aegis.build(root,cf,10,{floorY=0}) end)
local awake=stage("final-risen",SPACING*3,function(cf)
 local r=Aegis.build(root,cf,10,{floorY=0});Aegis.setAwaken(r,1);Aegis.setRise(r,1);Aegis.updateChains(r,0);return r end)
stage("final-standing",SPACING*4,function(cf)
 local r=Aegis.build(root,cf,10,{floorY=0});Aegis.setStanding(r);Aegis.updateChains(r,0);return r end)

-- One person beside each stage, at the chamber's own conversation distance.
for _,s in stages do
 local h=Cast.buildLyra(root,CFrame.lookAt(V(s.x+22,2.8,14),V(s.x,2.8,0)))
 h.animState.phase="Idle";Cast.stepAnimate(h,2.6)
end

-- Measurements, printed to stderr-ish (a leading '#') so run.sh's `tail -n 1`
-- still gets the JSON.
local function extent(r)
 local lo,hi=V(math.huge,math.huge,math.huge),V(-math.huge,-math.huge,-math.huge)
 for _,item in r.model:GetDescendants() do
  if item:IsA("BasePart") and item~=r.root and not r.chainParts[item] then
   local cf,half=rawget(item,"CFrame"),rawget(item,"Size")/2
   for _,c in {V(-1,-1,-1),V(1,-1,-1),V(-1,1,-1),V(1,1,-1),V(-1,-1,1),V(1,-1,1),V(-1,1,1),V(1,1,1)} do
    local p=cf*V(c.X*half.X,c.Y*half.Y,c.Z*half.Z)
    lo=V(math.min(lo.X,p.X),math.min(lo.Y,p.Y),math.min(lo.Z,p.Z))
    hi=V(math.max(hi.X,p.X),math.max(hi.Y,p.Y),math.max(hi.Z,p.Z))
   end
  end
 end
 return lo,hi
end
for _,s in stages do
 local lo,hi=extent(s.r)
 local low,where=Aegis.lowestPoint(s.r)
 local parts=0
 for _,d in s.r.model:GetDescendants() do if d:IsA("BasePart") then parts+=1 end end
 print(string.format("# %-15s height %.2f width %.2f depth %.2f lowest %.3f (%s) parts %d",
  s.label,hi.Y-lo.Y,hi.X-lo.X,hi.Z-lo.Z,low,where,parts))
end
-- Every contact, not just the lowest: the knee, the laid-back foot and the
-- planted sole should all be ON the floor, not just one of them.
for _,s in stages do
 if not string.find(s.label,"standing") then
  local line={}
  for _,name in {"LeftSole","RightKneeCap","RightShinShield","RightSole","RightHeel","LeftHand","RightHand"} do
   local p=s.r.model:FindFirstChild(name)
   local cf,half=rawget(p,"CFrame"),rawget(p,"Size")/2
   local low=math.huge
   for _,c in {V(-1,-1,-1),V(1,-1,-1),V(-1,1,-1),V(1,1,-1),V(-1,-1,1),V(1,-1,1),V(-1,1,1),V(1,1,1)} do
    low=math.min(low,(cf*V(c.X*half.X,c.Y*half.Y,c.Z*half.Z)).Y)
   end
   table.insert(line,string.format("%s %.2f",name,low))
  end
  print("# contacts "..s.label..": "..table.concat(line,", "))
 end
end
do
 local head=standing.head
 local lo=math.huge;local hi=-math.huge
 for _,e in standing.rigid do
  if e.host==head then
   local p=rawget(e.part,"CFrame").Position;local sz=rawget(e.part,"Size")
   lo=math.min(lo,p.Y-sz.Y/2);hi=math.max(hi,p.Y+sz.Y/2)
  end
 end
 local hp=rawget(head,"CFrame").Position;local hs=rawget(head,"Size")
 lo=math.min(lo,hp.Y-hs.Y/2);hi=math.max(hi,hp.Y+hs.Y/2)
 local blo,bhi=extent(standing)
 local ls=standing.model:FindFirstChild("LeftShoulderShell")
 local rs=standing.model:FindFirstChild("RightShoulderShell")
 -- In the rig's own frame: the stage is turned 180 degrees, so world X runs
 -- the other way round from the machine's left and right.
 local rootCF=rawget(standing.root,"CFrame")
 local lx=(rootCF:Inverse()*rawget(ls,"CFrame")).Position.X
 local rx=(rootCF:Inverse()*rawget(rs,"CFrame")).Position.X
 local span=(rx+rawget(rs,"Size").X/2)-(lx-rawget(ls,"Size").X/2)
 print(string.format("# head %.2f tall -> %.2f heads standing; shoulder span %.2f = %.2f heads",hi-lo,(bhi.Y-blo.Y)/(hi-lo),math.abs(span),math.abs(span)/(hi-lo)))
end

local out={}
local function emit(tag,eye,target,fov)
 local cf=CFrame.lookAt(eye,target)
 local look=cf.LookVector
 local parts={}
 for _,solid in RBX.solids do
  local transparency=rawget(solid,"Transparency") or 0
  if transparency<0.92 then
   local pcf=rawget(solid,"CFrame")
   local size=rawget(solid,"Size")
   local delta=pcf.Position-eye
   if delta:Dot(look)>0 or delta.Magnitude<math.max(size.X,size.Y,size.Z) then
    local colour=rawget(solid,"Color")
    local rgb=colour and colour.rgb or {200,200,200}
    local shape=rawget(solid,"ClassName")=="WedgePart" and "Wedge" or "Block"
    local shapeEnum=rawget(solid,"Shape")
    if shapeEnum and rawget(solid,"ClassName")~="WedgePart" then shape=shapeEnum.Name end
    table.insert(parts,string.format(
     '{"n":"%s","s":[%.3f,%.3f,%.3f],"p":[%.3f,%.3f,%.3f],"x":[%.4f,%.4f,%.4f],"y":[%.4f,%.4f,%.4f],"z":[%.4f,%.4f,%.4f],"c":[%d,%d,%d],"t":%.2f,"k":"%s"}',
     rawget(solid,"Name"),size.X,size.Y,size.Z,
     pcf.Position.X,pcf.Position.Y,pcf.Position.Z,
     pcf.XVector.X,pcf.XVector.Y,pcf.XVector.Z,
     pcf.YVector.X,pcf.YVector.Y,pcf.YVector.Z,
     pcf.ZVector.X,pcf.ZVector.Y,pcf.ZVector.Z,
     math.floor(rgb[1]),math.floor(rgb[2]),math.floor(rgb[3]),transparency,shape))
   end
  end
 end
 table.insert(out,string.format(
  '{"tag":"%s","fov":%.2f,"eye":[%.3f,%.3f,%.3f],"look":[%.5f,%.5f,%.5f],"up":[%.5f,%.5f,%.5f],"parts":[%s]}',
  tag,fov,eye.X,eye.Y,eye.Z,look.X,look.Y,look.Z,cf.YVector.X,cf.YVector.Y,cf.YVector.Z,
  table.concat(parts,",")))
end

-- Stages are 600 studs apart, so no camera here ever sees a neighbour.
for _,s in stages do
 local standingPose=string.find(s.label,"standing")~=nil
 local c=V(s.x,standingPose and 30 or 25,0)
 local d=standingPose and 105 or 95
 emit("aegis-"..s.label.."-front",c+V(0,4,d),c,40)
 emit("aegis-"..s.label.."-threequarter",c+V(d*0.68,8,d*0.72),c,40)
 emit("aegis-"..s.label.."-side",c+V(d,3,0),c,40)
 emit("aegis-"..s.label.."-back",c+V(-6,6,-d),c,40)
 emit("aegis-"..s.label.."-silhouette",c+V(0,4,d),c,40)
 emit("aegis-"..s.label.."-threequarter-silhouette",c+V(d*0.68,8,d*0.72),c,40)
 -- Close on the chest and head, where the core, visor and waist live.
 local chest=rawget(s.r.torso,"CFrame").Position
 emit("aegis-"..s.label.."-chest",chest+V(14,4,34),chest+V(0,1,0),40)
 local head=rawget(s.r.head,"CFrame").Position
 emit("aegis-"..s.label.."-head",head+V(7,1,15),head,40)
 local shoulder=rawget(s.r.model:FindFirstChild("RightUpperArm"),"CFrame").Position
 emit("aegis-"..s.label.."-rightshoulder",shoulder+V(-16,8,20),shoulder+V(0,2,0),40)
 local hand=rawget(s.r.hands.Right,"CFrame").Position
 emit("aegis-"..s.label.."-hand",hand+V(-10,6,18),hand+V(0,-3,0),40)
end
print("["..table.concat(out,",").."]")
