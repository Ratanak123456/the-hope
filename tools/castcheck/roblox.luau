--!nonstrict
-- Minimal Roblox instance/enum/service shims, on top of the Phase 0.A
-- Vector3/CFrame shim, so src/client/NorthPole/Cast.lua can be executed by
-- the Luau CLI outside Roblox. The point is to verify the REAL rig source,
-- not a re-implementation of it: every joint offset, pivot, clamp and pose in
-- the checks below comes from the file the game actually runs.
local R={}

R.warnings={}
function R.warn(...)
 local parts={}
 for i=1,select("#",...) do table.insert(parts,tostring((select(i,...)))) end
 table.insert(R.warnings,table.concat(parts," "))
end

-- Enum: any Enum.<Category>.<Item> resolves to a unique stable token.
local enumCache={}
R.Enum=setmetatable({},{__index=function(_,category)
 if not enumCache[category] then
  enumCache[category]=setmetatable({},{__index=function(t,item)
   local value={Name=item,Value=item,Category=category}
   rawset(t,item,value)
   return value
  end})
 end
 return enumCache[category]
end})

-- Value types Kit/Cast touch but never inspect.
R.Vector2={new=function(x,y) return {X=x or 0,Y=y or 0,Magnitude=math.sqrt((x or 0)^2+(y or 0)^2)} end}
R.UDim2={new=function(...) return {...} end,fromScale=function(x,y) return {x,y} end,fromOffset=function(x,y) return {x,y} end}
R.NumberRange={new=function(a,b) return {Min=a,Max=b or a} end}
R.NumberSequenceKeypoint={new=function(t,v) return {Time=t,Value=v} end}
R.NumberSequence={new=function(v) return {Value=v} end}
R.ColorSequence={new=function(v) return {Value=v} end}
R.RaycastParams={new=function() return {FilterType=nil,FilterDescendantsInstances={},IgnoreWater=false} end}
R.OverlapParams={new=function() return {FilterType=nil,FilterDescendantsInstances={},MaxParts=0} end}
R.Random={new=function(seed)
 local state=seed or 0
 local function next()
  state=(1103515245*state+12345)%2147483648
  return state/2147483648
 end
 return {NextNumber=function(_,a,b) local v=next() if a==nil then return v end return a+(b-a)*v end,
  NextInteger=function(_,a,b) return a+math.floor(next()*(b-a+1)) end}
end}

--------------------------------------------------------------------------------
-- Instances
--------------------------------------------------------------------------------

local Methods={}
local InstanceMT={
 __index=function(t,k)
  -- Position is derived from CFrame exactly as the engine derives it, so a
  -- check that reads part.Position is reading the solved transform.
  if k=="Position" then
   local cf=rawget(t,"CFrame")
   return cf and cf.Position or Vector3.new(0,0,0)
  end
  local method=Methods[k]
  if method~=nil then return method end
  -- Roblox resolves an unknown index to a child of that name; Cast.lua
  -- relies on it for ReplicatedStorage.Shared.Config.
  for _,child in rawget(t,"_children") do
   if rawget(child,"Name")==k then return child end
  end
  return nil
 end,
 __newindex=function(t,k,v)
  if k=="Parent" then
   local old=rawget(t,"Parent")
   if old then
    local siblings=rawget(old,"_children")
    for i,child in siblings do
     if child==t then table.remove(siblings,i) break end
    end
   end
   rawset(t,"Parent",v)
   if v then table.insert(rawget(v,"_children"),t) end
   return
  end
  rawset(t,k,v)
 end,
}

local PART_CLASSES={Part=true,WedgePart=true,CornerWedgePart=true,MeshPart=true,TrussPart=true}

function Methods:IsA(class)
 local own=rawget(self,"ClassName")
 if own==class then return true end
 if class=="BasePart" then return PART_CLASSES[own]==true end
 if class=="Instance" then return true end
 return false
end
function Methods:GetChildren()
 local out={}
 for _,child in rawget(self,"_children") do table.insert(out,child) end
 return out
end
function Methods:GetDescendants()
 local out={}
 local function walk(node)
  for _,child in rawget(node,"_children") do
   table.insert(out,child)
   walk(child)
  end
 end
 walk(self)
 return out
end
function Methods:FindFirstChild(name)
 for _,child in rawget(self,"_children") do
  if rawget(child,"Name")==name then return child end
 end
 return nil
end
function Methods:FindFirstChildOfClass(class)
 for _,child in rawget(self,"_children") do
  if rawget(child,"ClassName")==class then return child end
 end
 return nil
end
function Methods:FindFirstAncestorOfClass(class)
 local node=rawget(self,"Parent")
 while node do
  if rawget(node,"ClassName")==class then return node end
  node=rawget(node,"Parent")
 end
 return nil
end
function Methods:SetAttribute(name,value) rawget(self,"_attributes")[name]=value end
function Methods:GetAttribute(name) return rawget(self,"_attributes")[name] end
function Methods:Destroy()
 rawset(self,"_destroyed",true)
 self.Parent=nil
end
function Methods:GetFullName() return rawget(self,"Name") end
-- ParticleEmitter:Emit and friends: the cinematic fires bursts from several
-- shots; nothing here inspects particles, they just have to not throw.
function Methods:Emit() end
function Methods:Clear() end
--[[
 Roblox's own pivot rules, in order: a PrimaryPart's CFrame, else an
 explicitly set WorldPivot, else the centre of the model's bounding box.

 The third case is the dangerous one and is why it is modelled here rather
 than collapsed to the identity: a Model built at runtime with neither a
 PrimaryPart nor a WorldPivot still pivots about SOMETHING, just not about
 anything the author chose - which is how the truck's whole body ended up
 positioned away from its own wheels while every wheel was placed correctly.
]]
function Methods:GetPivot()
 local primary=rawget(self,"PrimaryPart")
 if primary then return rawget(primary,"CFrame") end
 local pivot=rawget(self,"WorldPivot")
 if pivot then return pivot end
 local own=rawget(self,"CFrame")
 if own then return own end
 local lo,hi=nil,nil
 for _,descendant in self:GetDescendants() do
  local cf=rawget(descendant,"CFrame")
  local size=rawget(descendant,"Size")
  if cf and size then
   local p=cf.Position
   local half=Vector3.new(
    math.abs(cf.XVector.X)*size.X/2+math.abs(cf.YVector.X)*size.Y/2+math.abs(cf.ZVector.X)*size.Z/2,
    math.abs(cf.XVector.Y)*size.X/2+math.abs(cf.YVector.Y)*size.Y/2+math.abs(cf.ZVector.Y)*size.Z/2,
    math.abs(cf.XVector.Z)*size.X/2+math.abs(cf.YVector.Z)*size.Y/2+math.abs(cf.ZVector.Z)*size.Z/2)
   local a,b=p-half,p+half
   if lo then
    lo=Vector3.new(math.min(lo.X,a.X),math.min(lo.Y,a.Y),math.min(lo.Z,a.Z))
    hi=Vector3.new(math.max(hi.X,b.X),math.max(hi.Y,b.Y),math.max(hi.Z,b.Z))
   else
    lo,hi=a,b
   end
  end
 end
 if not lo then return CFrame.new() end
 return CFrame.new((lo+hi)/2)
end
function Methods:PivotTo(target)
 local pivot=self:GetPivot()
 local inverse=pivot:Inverse()
 if PART_CLASSES[rawget(self,"ClassName")] then
  rawset(self,"CFrame",target)
  return
 end
 for _,descendant in self:GetDescendants() do
  local cf=rawget(descendant,"CFrame")
  if cf then rawset(descendant,"CFrame",target*(inverse*cf)) end
 end
end

function R.newInstance(class)
 local instance=setmetatable({},InstanceMT)
 rawset(instance,"ClassName",class)
 rawset(instance,"Name",class)
 rawset(instance,"_children",{})
 rawset(instance,"_attributes",{})
 if PART_CLASSES[class] then
  rawset(instance,"CFrame",CFrame.new())
  rawset(instance,"Size",Vector3.new(1,1,1))
  rawset(instance,"Transparency",0)
  table.insert(R.solids,instance)
 elseif class=="Motor6D" or class=="Weld" then
  rawset(instance,"C0",CFrame.new())
  rawset(instance,"C1",CFrame.new())
  rawset(instance,"Transform",CFrame.new())
 end
 return instance
end
R.Instance={new=function(class,parent)
 local instance=R.newInstance(class)
 if parent then instance.Parent=parent end
 return instance
end}

--------------------------------------------------------------------------------
-- Services and workspace
--
-- The floor is a single analytic plane at R.floorY. Cast.floorUnder's raycast
-- therefore returns a known value, which is what lets the checks below assert
-- an exact sole height rather than a plausible-looking one.
--------------------------------------------------------------------------------

R.floorY=0
R.rayCount=0
R.useSolids=false

local workspaceInstance=R.newInstance("Workspace")
rawset(workspaceInstance,"Name","Workspace")
function workspaceInstance:Raycast(origin,direction,params)
 R.rayCount+=1
 if direction.Y>=0 then return nil end
 local hitY=nil
 if R.useSolids then hitY=self:RaycastSolids(origin,direction,params) end
 if hitY==nil and R.floorY~=nil then
  local t=(R.floorY-origin.Y)/direction.Y
  if t>=0 and t<=1 then hitY=R.floorY end
 end
 if hitY==nil then return nil end
 local t=(hitY-origin.Y)/direction.Y
 return {Position=Vector3.new(origin.X+direction.X*t,hitY,origin.Z+direction.Z*t),Instance=workspaceInstance,Normal=Vector3.new(0,1,0)}
end
function workspaceInstance:GetPartBoundsInBox() return {} end
-- Terrain and the scriptable camera: Lighting.lua reads workspace.Terrain at
-- module load, and Camera.applyShot drives workspace.CurrentCamera.
local terrain=R.newInstance("Terrain")
rawset(terrain,"Name","Terrain")
terrain.Parent=workspaceInstance
local clouds=R.newInstance("Clouds")
rawset(clouds,"Name","HopeClouds")
clouds.Parent=terrain
local camera=R.newInstance("Camera")
rawset(camera,"Name","Camera")
rawset(camera,"FieldOfView",70)
rawset(camera,"CFrame",CFrame.new())
rawset(camera,"Focus",CFrame.new())
rawset(camera,"ViewportSize",R.Vector2.new(1920,1080))
camera.Parent=workspaceInstance
rawset(workspaceInstance,"CurrentCamera",camera)
R.camera=camera
R.workspace=workspaceInstance

--[[
 The workspace ray also answers queries against real built geometry, not just
 the analytic floor, so a cinematic dry run exercises Cast.floorUnder and
 Env.surfaceY against the set that was actually constructed.

 Only axis-aligned boxes are considered, which is exact for the flat interior
 floors the cast stands on and conservative for the ball/wedge snow outside -
 more than enough to catch "this character is placed 40 studs above the
 ground" without reimplementing Roblox's collision geometry.
]]
R.solids={}
function workspaceInstance:RaycastSolids(origin,direction,params)
 local exclude={}
 if params and params.FilterDescendantsInstances then
  for _,item in params.FilterDescendantsInstances do exclude[item]=true end
 end
 local best=nil
 for _,solid in R.solids do
  if rawget(solid,"Transparency")<0.65 then
   local skip=false
   local node=solid
   while node do
    if exclude[node] then skip=true break end
    node=rawget(node,"Parent")
   end
   -- Anything detached from the workspace tree (Destroy sets Parent=nil) is
   -- not part of the world and must not act as ground.
   if not skip then
    local attached,walk=false,solid
    while walk do
     if walk==workspaceInstance then attached=true break end
     walk=rawget(walk,"Parent")
    end
    skip=not attached
   end
   if not skip then
    local cf=rawget(solid,"CFrame")
    local size=rawget(solid,"Size")
    -- Only boxes whose frame is (near) axis aligned are considered.
    if math.abs(cf.yv[2])>0.999 then
     local halfX,halfZ=math.abs(cf.xv[1])*size[1]/2+math.abs(cf.zv[1])*size[3]/2,math.abs(cf.xv[3])*size[1]/2+math.abs(cf.zv[3])*size[3]/2
     local p=cf.p
     if math.abs(origin[1]-p[1])<=halfX and math.abs(origin[3]-p[3])<=halfZ then
      local top=p[2]+size[2]/2
      if top<=origin[2] and origin[2]+direction[2]<=top then
       if not best or top>best then best=top end
      end
     end
    end
   end
  end
 end
 return best
end

local lighting=R.newInstance("Lighting")
rawset(lighting,"Name","Lighting")
for _,name in {"HopeBloom","HopeSunRays","HopeAtmosphere","HopeGrade"} do
 local effect=R.newInstance(name)
 rawset(effect,"Name",name)
 effect.Parent=lighting
end
local services={
 RunService={IsStudio=function() return R.studio end,IsClient=function() return true end,IsServer=function() return false end,
  -- PreRender/PreSimulation/PostSimulation are the current names; the three
  -- legacy aliases are kept because modules this harness does not own still
  -- use them. A shim that only knows the deprecated names silently fails the
  -- moment a module is modernised, which is how it should NOT find out.
  PreRender={Connect=function() return {Disconnect=function() end} end,Wait=function() return 1/60 end},
  PreSimulation={Connect=function() return {Disconnect=function() end} end,Wait=function() return 1/60 end},
  PostSimulation={Connect=function() return {Disconnect=function() end} end,Wait=function() return 1/60 end},
  RenderStepped={Connect=function() return {Disconnect=function() end} end,Wait=function() return 1/60 end},
  Heartbeat={Connect=function() return {Disconnect=function() end} end,Wait=function() return 1/60 end},
  Stepped={Connect=function() return {Disconnect=function() end} end,Wait=function() return 1/60 end}},
 ReplicatedStorage=nil,
 TweenService={Create=function() return {Play=function() end,Cancel=function() end,Completed={Connect=function() return {Disconnect=function() end} end}} end},
 Lighting=lighting,
 Players={},
}
R.studio=true

function R.install(modules)
 local shared=R.newInstance("Folder")
 rawset(shared,"Name","Shared")
 for name in modules do
  local proxy=R.newInstance("ModuleScript")
  rawset(proxy,"Name",name)
  rawset(proxy,"__mod",name)
  proxy.Parent=shared
 end
 local replicated=R.newInstance("Folder")
 rawset(replicated,"Name","ReplicatedStorage")
 rawset(replicated,"Shared",shared)
 function replicated:WaitForChild(name) return self:FindFirstChild(name) or shared end
 shared.Parent=replicated
 services.ReplicatedStorage=replicated
end

-- Callers may add services the cinematic itself never touches (the menu
-- scene reads UserInputService and GuiService, for instance) by assigning
-- R.extraServices before the first GetService call.
R.extraServices=nil
R.game={GetService=function(_,name) return services[name] or (R.extraServices and R.extraServices[name]) end}

return R
