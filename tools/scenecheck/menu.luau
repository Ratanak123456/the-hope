--!nonstrict
--[[
 The same treatment as dump.luau, for the welcome screen's hangar.

 MenuScene builds a real three-layer set and frames it with a real camera;
 this runs both and emits the frame, so "the welcome page feels weak" can be
 answered by looking at the composition rather than by reading the code that
 describes it.

 The UI column is drawn as an overlay rectangle at the end, at the same
 fraction of the viewport MainMenu.applyLayout gives it, so the question the
 review is actually asking - does the render still read with a third of the
 screen covered by type? - can be answered too.
]]
local MenuScene=MOD.MenuScene
RBX.useSolids=true
RBX.floorY=nil
RBX.studio=false

MenuScene.show()
MenuScene.driveCamera(0)

local camera=RBX.camera
local cf=rawget(camera,"CFrame")
local eye=cf.Position
local parts={}
for _,solid in RBX.solids do
 local transparency=rawget(solid,"Transparency") or 0
 local node,attached=solid,false
 while node do
  if node==RBX.workspace then attached=true break end
  node=rawget(node,"Parent")
 end
 if attached and transparency<0.95 then
  local pcf=rawget(solid,"CFrame")
  local size=rawget(solid,"Size")
  local colour=rawget(solid,"Color")
  local rgb=colour and colour.rgb or {200,200,200}
  local shapeEnum=rawget(solid,"Shape")
  local shape=shapeEnum and shapeEnum.Name or "Block"
  if rawget(solid,"ClassName")=="WedgePart" then shape="Wedge" end
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
print(string.format('[{"tag":"menu","fov":%.2f,"eye":[%.3f,%.3f,%.3f],"look":[%.5f,%.5f,%.5f],"up":[%.5f,%.5f,%.5f],"column":0.41,"parts":[%s]}]',
 rawget(camera,"FieldOfView") or 34,
 eye.X,eye.Y,eye.Z,cf.LookVector.X,cf.LookVector.Y,cf.LookVector.Z,cf.YVector.X,cf.YVector.Y,cf.YVector.Z,
 table.concat(parts,",")))
