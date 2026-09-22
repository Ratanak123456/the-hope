--!nonstrict
-- Phase 0.A foundation, module 6 of 6: the visible rig.
--
-- The only file in this foundation that touches Roblox Instances. Everything
-- about how the character MOVES lives in the five pure modules beside it, so
-- the motion can be verified headlessly; this file only decides what the
-- moving skeleton looks like and pushes the solved frame onto real parts.
--
-- DELIBERATE CHOICES
--  * Every visible segment is a plain rectangular block, sized and jointed to
--    the R15 proportions in Skeleton.lua. No balls, wedges or connector
--    geometry at any shoulder, elbow, hip, knee or ankle - segments meet
--    directly at the pivot, so the read is upper arm -> lower arm -> hand,
--    not block -> ball -> block.
--  * Real R15 part and Motor6D names throughout, so this rig can later be
--    driven by, or swapped for, an actual R15 character without renaming
--    anything.
--  * Every part is Anchored and positioned directly from our own forward
--    kinematics. The Motor6Ds are built and their Transform is kept in sync
--    so the rig is structurally a real R15 skeleton and is inspectable in the
--    explorer, but the engine's joint solver is never in a position to fight
--    the pose. One writer, always.
--  * No Light of any kind, and no Neon. A human is lit by the room. The
--    validator re-checks this at runtime rather than trusting the comment.
local Skeleton=require(script.Parent.Skeleton)
local Build={}
local V,CF=Vector3.new,CFrame.new

Build.Palette={
 skin=Color3.fromRGB(219,178,142),
 shirt=Color3.fromRGB(72,98,132),
 pants=Color3.fromRGB(54,60,70),
 shoe=Color3.fromRGB(36,40,47),
 hair=Color3.fromRGB(48,38,31),
 eye=Color3.fromRGB(245,245,240),
 pupil=Color3.fromRGB(28,30,34),
 mouth=Color3.fromRGB(150,105,90),
}

local function block(parent,name,size,color)
 local p=Instance.new("Part")
 p.Name=name;p.Size=size;p.Color=color
 p.Material=Enum.Material.SmoothPlastic
 p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 p.Massless=true;p.CastShadow=true
 p.Parent=parent
 return p
end

-- colour per body part, so the block skeleton reads as clothed without any
-- second shell layer sitting on top of it. Exported because the offline
-- renderer draws the rig from this same mapping - one source of truth for
-- what the character looks like.
function Build.colourFor(partName,palette)
 if partName=="Head" then return palette.skin end
 if partName=="LeftHand" or partName=="RightHand" then return palette.skin end
 if partName=="LeftFoot" or partName=="RightFoot" then return palette.shoe end
 if partName:find("Leg") then return palette.pants end
 return palette.shirt
end

-- Non-articulated detail: hair and a flat seven-block face, the same stylised
-- read a default Roblox avatar has. Nothing sculpted, nothing spherical, and
-- nothing that needs its own joint. Declared as data, not built inline, so
-- the offline renderer draws exactly what Studio will draw.
Build.Decoration={
 {host="Head",name="Hair",size=V(1.14,0.36,1.14),offset=V(0,0.41,0.03),colour="hair"},
 {host="Head",name="EyeL",size=V(0.20,0.18,0.02),offset=V(-0.22,0.07,-0.552),colour="eye"},
 {host="Head",name="EyeR",size=V(0.20,0.18,0.02),offset=V(0.22,0.07,-0.552),colour="eye"},
 {host="Head",name="PupilL",size=V(0.09,0.09,0.015),offset=V(-0.22,0.055,-0.564),colour="pupil"},
 {host="Head",name="PupilR",size=V(0.09,0.09,0.015),offset=V(0.22,0.055,-0.564),colour="pupil"},
 {host="Head",name="BrowL",size=V(0.24,0.05,0.02),offset=V(-0.22,0.27,-0.549),colour="hair"},
 {host="Head",name="BrowR",size=V(0.24,0.05,0.02),offset=V(0.22,0.27,-0.549),colour="hair"},
 {host="Head",name="Mouth",size=V(0.26,0.05,0.02),offset=V(0,-0.26,-0.549),colour="mouth"},
}

function Build.rig(parent,spec)
 spec=spec or {}
 local scale=spec.scale or 1
 local palette=spec.palette or Build.Palette
 local model=Instance.new("Model")
 model.Name=spec.name or "HumanPrototype"
 model.Parent=parent

 local handle={model=model,parts={},motors={},attachments={},scale=scale}

 local root=block(model,"HumanoidRootPart",V(1.4,0.8,0.85)*scale,palette.shirt)
 root.Transparency=1
 model.PrimaryPart=root
 handle.parts.HumanoidRootPart=root

 for _,s in Skeleton.Segments do
  local p=block(model,s.part,s.size*scale,Build.colourFor(s.part,palette))
  handle.parts[s.part]=p
 end

 -- Motor6Ds, with the exact C0/C1 the maths uses. Built after the parts so
 -- every Part0/Part1 already exists.
 for _,s in Skeleton.Segments do
  local m=Instance.new("Motor6D")
  m.Name=s.motor
  m.Part0=handle.parts[s.parent]
  m.Part1=handle.parts[s.part]
  m.C0=CF(s.c0*scale)
  m.C1=CF(s.c1*scale)
  m.Parent=handle.parts[s.parent]
  handle.motors[s.motor]=m
 end

 for _,d in Build.Decoration do
  local p=block(model,d.name,d.size*scale,palette[d.colour])
  table.insert(handle.attachments,{part=p,host=d.host,offset=CF(d.offset*scale)})
 end

 return handle
end

-- Push one solved frame onto the instances. Parent-before-child order is
-- guaranteed by Skeleton.Segments, and Skeleton.forward has already done the
-- chain, so this is a straight write with no maths of its own.
function Build.apply(handle,actor)
 local world=actor.world
 if not world then return end
 handle.parts.HumanoidRootPart.CFrame=actor.rootCFrame
 for _,s in Skeleton.Segments do
  local cf=world[s.part]
  if cf then
   handle.parts[s.part].CFrame=cf
   local m=handle.motors[s.motor]
   if m then m.Transform=actor.transforms[s.motor] or CF() end
  end
 end
 for _,a in handle.attachments do
  local host=world[a.host]
  if host then a.part.CFrame=host*a.offset end
 end
end

function Build.setSilhouette(handle,on)
 for _,p in handle.model:GetDescendants() do
  if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then
   if on then
    p:SetAttribute("BaseColor",p:GetAttribute("BaseColor") or p.Color)
    p.Color=Color3.new(0,0,0)
    p.Material=Enum.Material.SmoothPlastic
   else
    local c=p:GetAttribute("BaseColor")
    if c then p.Color=c end
   end
  end
 end
end

return Build
