--!nonstrict
-- Minimal Vector3/CFrame implementation so src/shared/Human/*.lua can be
-- executed by the Luau CLI outside Roblox. This exists so the rig maths is
-- verified by running the REAL module source, not a re-implementation of it.
local Shim={}

local Vector3={}
Vector3.__index=function(self,k)
 if k=="X" then return self[1] elseif k=="Y" then return self[2] elseif k=="Z" then return self[3]
 elseif k=="Magnitude" then return math.sqrt(self[1]^2+self[2]^2+self[3]^2)
 elseif k=="Unit" then
  local m=math.sqrt(self[1]^2+self[2]^2+self[3]^2)
  if m<1e-12 then return Shim.V3(0,0,0) end
  return Shim.V3(self[1]/m,self[2]/m,self[3]/m)
 end
 return rawget(Vector3,k)
end
Vector3.__add=function(a,b) return Shim.V3(a[1]+b[1],a[2]+b[2],a[3]+b[3]) end
Vector3.__sub=function(a,b) return Shim.V3(a[1]-b[1],a[2]-b[2],a[3]-b[3]) end
Vector3.__unm=function(a) return Shim.V3(-a[1],-a[2],-a[3]) end
Vector3.__mul=function(a,b)
 if type(b)=="number" then return Shim.V3(a[1]*b,a[2]*b,a[3]*b) end
 if type(a)=="number" then return Shim.V3(b[1]*a,b[2]*a,b[3]*a) end
 return Shim.V3(a[1]*b[1],a[2]*b[2],a[3]*b[3])
end
Vector3.__div=function(a,b) return Shim.V3(a[1]/b,a[2]/b,a[3]/b) end
Vector3.__eq=function(a,b) return a[1]==b[1] and a[2]==b[2] and a[3]==b[3] end
Vector3.__tostring=function(a) return string.format("(%.4f, %.4f, %.4f)",a[1],a[2],a[3]) end
function Vector3:Dot(o) return self[1]*o[1]+self[2]*o[2]+self[3]*o[3] end
function Vector3:Cross(o)
 return Shim.V3(self[2]*o[3]-self[3]*o[2],self[3]*o[1]-self[1]*o[3],self[1]*o[2]-self[2]*o[1])
end
function Vector3:Lerp(o,t) return Shim.V3(self[1]+(o[1]-self[1])*t,self[2]+(o[2]-self[2])*t,self[3]+(o[3]-self[3])*t) end
function Shim.V3(x,y,z) return setmetatable({x or 0,y or 0,z or 0},Vector3) end

local CFrame={}
-- Stored as three column vectors (right, up, back) plus a position.
local function newCF(p,xv,yv,zv)
 return setmetatable({p=p,xv=xv,yv=yv,zv=zv},CFrame)
end
local function rotMul(a,v) -- a's columns applied to v
 return a.xv*v[1]+a.yv*v[2]+a.zv*v[3]
end
local function rotTMul(a,v) -- transpose applied to v
 return Shim.V3(a.xv:Dot(v),a.yv:Dot(v),a.zv:Dot(v))
end
CFrame.__index=function(self,k)
 if k=="Position" then return self.p
 elseif k=="X" then return self.p[1] elseif k=="Y" then return self.p[2] elseif k=="Z" then return self.p[3]
 elseif k=="LookVector" then return -self.zv
 elseif k=="UpVector" then return self.yv
 elseif k=="RightVector" then return self.xv
 elseif k=="XVector" then return self.xv elseif k=="YVector" then return self.yv elseif k=="ZVector" then return self.zv
 end
 return rawget(CFrame,k)
end
CFrame.__mul=function(a,b)
 if getmetatable(b)==Vector3 then return a.p+rotMul(a,b) end
 return newCF(a.p+rotMul(a,b.p),rotMul(a,b.xv),rotMul(a,b.yv),rotMul(a,b.zv))
end
CFrame.__sub=function(a,v) return newCF(a.p-v,a.xv,a.yv,a.zv) end
CFrame.__add=function(a,v) return newCF(a.p+v,a.xv,a.yv,a.zv) end
CFrame.__tostring=function(a) return "CF"..tostring(a.p) end
function CFrame:Inverse()
 local xv=Shim.V3(self.xv[1],self.yv[1],self.zv[1])
 local yv=Shim.V3(self.xv[2],self.yv[2],self.zv[2])
 local zv=Shim.V3(self.xv[3],self.yv[3],self.zv[3])
 local r=newCF(Shim.V3(0,0,0),xv,yv,zv)
 return newCF(-rotMul(r,self.p),xv,yv,zv)
end
function CFrame:PointToObjectSpace(v) return rotTMul(self,v-self.p) end
function CFrame:VectorToObjectSpace(v) return rotTMul(self,v) end
function CFrame:ToObjectSpace(o) return self:Inverse()*o end
function CFrame:ToOrientation()
 -- R = Rx*Ry*Rz ; M[row][col], column-major storage
 local m02,m12,m22=self.zv[1],self.zv[2],self.zv[3]
 local m01,m00=self.yv[1],self.xv[1]
 local ry=math.asin(math.clamp(m02,-1,1))
 local rx=math.atan2(-m12,m22)
 local rz=math.atan2(-m01,m00)
 return rx,ry,rz
end
local function toQuat(c)
 local m00,m10,m20=c.xv[1],c.xv[2],c.xv[3]
 local m01,m11,m21=c.yv[1],c.yv[2],c.yv[3]
 local m02,m12,m22=c.zv[1],c.zv[2],c.zv[3]
 local tr=m00+m11+m22
 if tr>0 then
  local s=math.sqrt(tr+1)*2
  return (m21-m12)/s,(m02-m20)/s,(m10-m01)/s,0.25*s
 elseif m00>m11 and m00>m22 then
  local s=math.sqrt(1+m00-m11-m22)*2
  return 0.25*s,(m01+m10)/s,(m02+m20)/s,(m21-m12)/s
 elseif m11>m22 then
  local s=math.sqrt(1+m11-m00-m22)*2
  return (m01+m10)/s,0.25*s,(m12+m21)/s,(m02-m20)/s
 else
  local s=math.sqrt(1+m22-m00-m11)*2
  return (m02+m20)/s,(m12+m21)/s,0.25*s,(m10-m01)/s
 end
end
local function fromQuat(x,y,z,w)
 local n=math.sqrt(x*x+y*y+z*z+w*w)
 x,y,z,w=x/n,y/n,z/n,w/n
 return newCF(Shim.V3(0,0,0),
  Shim.V3(1-2*(y*y+z*z),2*(x*y+z*w),2*(x*z-y*w)),
  Shim.V3(2*(x*y-z*w),1-2*(x*x+z*z),2*(y*z+x*w)),
  Shim.V3(2*(x*z+y*w),2*(y*z-x*w),1-2*(x*x+y*y)))
end
function CFrame:Lerp(o,t)
 local x1,y1,z1,w1=toQuat(self)
 local x2,y2,z2,w2=toQuat(o)
 local d=x1*x2+y1*y2+z1*z2+w1*w2
 if d<0 then x2,y2,z2,w2,d=-x2,-y2,-z2,-w2,-d end
 local k1,k2
 if d>0.9995 then k1,k2=1-t,t
 else
  local theta=math.acos(math.clamp(d,-1,1))
  local s=math.sin(theta)
  k1=math.sin((1-t)*theta)/s;k2=math.sin(t*theta)/s
 end
 local r=fromQuat(x1*k1+x2*k2,y1*k1+y2*k2,z1*k1+z2*k2,w1*k1+w2*k2)
 return newCF(self.p:Lerp(o.p,t),r.xv,r.yv,r.zv)
end
Shim.CFrame={}
function Shim.CFrame.new(a,b,c)
 if a==nil then return newCF(Shim.V3(0,0,0),Shim.V3(1,0,0),Shim.V3(0,1,0),Shim.V3(0,0,1)) end
 if type(a)=="number" then return newCF(Shim.V3(a,b or 0,c or 0),Shim.V3(1,0,0),Shim.V3(0,1,0),Shim.V3(0,0,1)) end
 return newCF(a,Shim.V3(1,0,0),Shim.V3(0,1,0),Shim.V3(0,0,1))
end
function Shim.CFrame.Angles(rx,ry,rz)
 local cx,sx=math.cos(rx),math.sin(rx)
 local cy,sy=math.cos(ry),math.sin(ry)
 local cz,sz=math.cos(rz),math.sin(rz)
 -- R = Rx*Ry*Rz, stored as columns
 local col0=Shim.V3(cy*cz, sx*sy*cz+cx*sz, -cx*sy*cz+sx*sz)
 local col1=Shim.V3(-cy*sz, -sx*sy*sz+cx*cz, cx*sy*sz+sx*cz)
 local col2=Shim.V3(sy, -sx*cy, cx*cy)
 return newCF(Shim.V3(0,0,0),col0,col1,col2)
end
function Shim.CFrame.fromMatrix(p,xv,yv,zv) return newCF(p,xv,yv,zv) end
function Shim.CFrame.lookAt(at,target,up)
 up=up or Shim.V3(0,1,0)
 local forward=(target-at).Unit
 local zv=-forward
 local xv=up:Cross(zv)
 if xv.Magnitude<1e-6 then xv=Shim.V3(1,0,0):Cross(zv) end
 xv=xv.Unit
 local yv=zv:Cross(xv)
 return newCF(at,xv,yv,zv)
end
Shim.Color3={}
-- Color3 carries a Lerp because Cast.lua tints faces with it; the value is
-- never inspected by any check, it just has to exist and stay a Color3.
local ColorMT={}
ColorMT.__index=ColorMT
-- A lerped colour keeps its .rgb triple, because it IS inspected now: the
-- cast's field coats are built by lerping toward the ice colour and the
-- albedo-budget check reads every built surface's value.
function ColorMT:Lerp(other,t)
 local r=self.R+(other.R-self.R)*t
 local g=self.G+(other.G-self.G)*t
 local b=self.B+(other.B-self.B)*t
 return setmetatable({R=r,G=g,B=b,rgb={r*255,g*255,b*255}},ColorMT)
end
function Shim.Color3.fromRGB(r,g,b) return setmetatable({R=r/255,G=g/255,B=b/255,rgb={r,g,b}},ColorMT) end
function Shim.Color3.new(r,g,b) return setmetatable({R=r,G=g,B=b,rgb={r*255,g*255,b*255}},ColorMT) end

Shim.CFrameMeta=CFrame
Shim.Vector3Meta=Vector3
return Shim
