--!nonstrict
--[[
 Emits the North Pole set, as the real modules build it, from the real camera
 of a named shot - so the opening's COMPOSITION can be looked at without
 Roblox Studio, the same way tools/phase0a/offline does for the human rig.

 Everything here comes from the shipping modules: Env builds the set,
 Sequences builds the cast and the shot list, and Camera.applyShot puts the
 lens where the shot puts it. Nothing about the framing is restated.

 Output is one JSON array of captures on stdout; tools/scenecheck/render.py
 rasterises it.
]]
local Cast,Env,Sequences=MOD.Cast,MOD.Env,MOD.Sequences
local V=Vector3.new

-- (shot name, alpha to capture at). Chosen to cover the beats the visual
-- brief is about: the Arctic arrival's composition and its vehicle, then the
-- lab's master, coverage and reverse.
local CAPTURES={
 -- The arrival is now ONE continuous shot, so it is sampled along its length
 -- rather than once per old cut: the convoy entering far up the route, passing
 -- the gate, and the held final composition with both trucks parked.
 {"02_ArcticArrival",0.0},
 {"02_ArcticArrival",0.25},
 {"02_ArcticArrival",0.5},
 {"02_ArcticArrival",0.75},
 {"02_ArcticArrival",1.0},
 {"06_CommandMaster",0.5},
 {"06b_VossSignal",0.5},
 {"06c_HaleSpacecraft",0.5},
 {"06e_LyraCalling",0.5},
 -- Every over-the-shoulder reverse. Their foreground is a listener's head,
 -- so they are the shots most sensitive to the cast's head size.
 {"06a_HaleReport",0.5},
 {"06f_HaleQuestion",0.5},
 {"07f2_HaleWiden",0.5},
 {"09c2_HaleOpenIt",0.5},
 {"11j_HaleBelowWhat",0.5},
 {"12a_HaleWake",0.5},
 -- The bore, the discovery and the facility: one frame per beat this pass
 -- exists to build, so a composition change anywhere in it shows up in the
 -- offline render without having to drive Studio.
 {"07a_BoreSystemStarts",0.0},
 {"07a_BoreSystemStarts",1.0},
 {"07b_BoreTelemetry",0.5},
 {"07c_BoreProgress",1.0},
 {"07d_PressureDrop",0.5},
 {"07e_UnexpectedVoid",0.5},
 -- The excavation: gantry established (scale), started, cutting, the roof
 -- coming through, and the finished cut.
 {"07g_ExcavationGantryEstablished",0.5},
 {"07h_ExcavationBegins",1.0},
 {"07i_CutterDescends",0.6},
 {"07j_StructureRoofExposed",0.0},
 {"07j_StructureRoofExposed",1.0},
 {"07k_AccessTunnelRevealed",0.5},
 {"08a_AccessHatch",0.5},
 {"09a_AbandonedLabEntry",0.5},
 {"09b_DeadWorkstation",0.5},
 {"09c_InnerGate",1.0},
 {"09d_KeyDiscovered",1.0},
 {"09f_LockResponds",0.5},
 {"09g_GateUnlocks",0.35},
 {"09g_GateUnlocks",1.0},
 {"10a_AegisFoot",0.0},
 {"10d_AegisFullReveal",0.5},
 {"11i_PartialTranslation",0.5},
 {"12f_ChestGlyphs",1.0},
 {"13a_SealCracks",1.0},
 {"13e_VioletBelow",0.5},
 {"13i_SovereignReveal",0.5},
 {"29d_EvacuationVehicles",0.0},
}
-- A part smaller than this fraction of its own distance cannot register at
-- the output resolution; emitting it only makes the JSON bigger and the
-- rasteriser slower.
local MIN_ANGULAR_SIZE=0.0016
local MAX_DISTANCE=1400

RBX.useSolids=true
RBX.floorY=nil
-- The in-camera Studio report JSON-encodes through a service the shim does
-- not provide, and is a diagnostic, not part of the framing under review.
RBX.studio=false
Cast.reset()

local env=Env.build()
local cast=Sequences.buildCast(env)
local ui={setSubtitle=function() end,setBlackout=function() end,setTitleCard=function() end,playCue=function() end}
local shots=Sequences.build(env,cast,ui)
local byName={}
for _,shot in shots do byName[shot.name]=shot end

local function detached(instance)
 local node=instance
 while node do
  if node==RBX.workspace then return false end
  if node==env.markers then return true end
  node=rawget(node,"Parent")
 end
 return true
end

local function emit(out,tag,shot)
 local camera=RBX.camera
 local cf=rawget(camera,"CFrame")
 local eye=cf.Position
 local look=cf.LookVector
 local parts={}
 for _,solid in RBX.solids do
  local transparency=rawget(solid,"Transparency") or 0
  if transparency<0.92 and not detached(solid) then
   local pcf=rawget(solid,"CFrame")
   local size=rawget(solid,"Size")
   local delta=pcf.Position-eye
   local distance=delta.Magnitude
   local extent=math.max(size.X,size.Y,size.Z)
   -- In front of the lens, close enough to matter, big enough to see.
   if distance<MAX_DISTANCE and (distance<extent or delta:Dot(look)>0)
    and extent/math.max(distance,1)>MIN_ANGULAR_SIZE then
    local colour=rawget(solid,"Color")
    local rgb=colour and colour.rgb or {200,200,200}
    local shapeEnum=rawget(solid,"Shape")
    local shape=shapeEnum and shapeEnum.Name or (rawget(solid,"ClassName")=="WedgePart" and "Wedge" or "Block")
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
 end
 table.insert(out,string.format(
  '{"tag":"%s","fov":%.2f,"eye":[%.3f,%.3f,%.3f],"look":[%.5f,%.5f,%.5f],"up":[%.5f,%.5f,%.5f],"parts":[%s]}',
  tag,rawget(camera,"FieldOfView") or 48,
  eye.X,eye.Y,eye.Z,look.X,look.Y,look.Z,cf.YVector.X,cf.YVector.Y,cf.YVector.Z,
  table.concat(parts,",")))
end

local out={}
local wanted={}
for _,capture in CAPTURES do wanted[capture[1]]=wanted[capture[1]] or {} end
for _,capture in CAPTURES do table.insert(wanted[capture[1]],capture[2]) end

-- Shots are run in order, never in isolation: a shot's enter() often depends
-- on where the previous one left the cast and the set.
local seen={}
for _,shot in shots do
 local state=shot.enter()
 local alphas=wanted[shot.name]
 for frame=0,8 do
  local alpha=frame/8
  shot.update(state,alpha)
  if alphas then
   for index,at in alphas do
    if not seen[shot.name..index] and alpha>=at then
     seen[shot.name..index]=true
     emit(out,#alphas>1 and string.format("%s@%.0f",shot.name,at*100) or shot.name,shot)
    end
   end
  end
 end
 shot.leave(state)
end
print("["..table.concat(out,",").."]")
