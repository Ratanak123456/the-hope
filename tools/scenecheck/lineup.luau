--!nonstrict
--[[
 THE CAST LINEUP.

 Every human in the opening, stood in a neutral row and photographed from
 front, three-quarter, side and in silhouette. It exists for one question,
 which no other harness in this repo can answer: are these people tellable
 apart?

 castcheck proves the rig is CORRECT - feet on the floor, knees bending
 forward, hands outside the torso, nobody brighter than the room. It has
 never had an opinion about whether twenty-four correct rigs are twenty-four
 different-looking people, and for a long time they were not: one hair cap,
 one face, one collar, one belt, one scanner, one backpack, recoloured.

 The silhouette pass is the real test. Rendered as flat shapes with every
 colour thrown away, the three leads still have to be identifiable, because
 that is what survives a wide shot, a dark room and a player who is not
 looking closely.
]]

local Cast=MOD.Cast
local Env=MOD.Env
local V=Vector3.new

local MIN_ANGULAR_SIZE=0.0012
local MAX_DISTANCE=400

RBX.useSolids=false
-- A flat, infinite floor: this is a lineup on a neutral stage, not a scene.
-- Cast.place raycasts for the ground and every rig grounds itself against
-- this, which is also a cheap check that grounding still works after an
-- appearance change.
RBX.floorY=0
RBX.studio=false
Cast.reset()

local root=Instance.new("Folder")
root.Name="Lineup"
root.Parent=RBX.workspace

--[[
 SPACING. Wide enough that neighbours never overlap in the side view, which
 is the view most likely to hide a mistake behind the next person along.
]]
-- 4.8, not 3.4: the Roblox-proportioned bodies are about 3.9 studs across
-- the arms, so the old spacing put every neighbour inside the next one.
local GAP=4.8
local people={}
local function place(label,builder)
 local x=#people*GAP
 local rig=builder(CFrame.lookAt(V(x,2.8,0),V(x,2.8,-4)))
 table.insert(people,{label=label,rig=rig,x=x})
 return rig
end

place("Lyra",function(cf) return Cast.buildLyra(root,cf) end)
place("Voss",function(cf) return Cast.buildVoss(root,cf) end)
place("Hale",function(cf) return Cast.buildHale(root,cf) end)
for i=1,8 do
 place("Scientist"..i,function(cf) return Cast.buildScientist(root,cf,nil,i) end)
end
-- Three representative security silhouettes and three of the excavation crew,
-- per the review brief: the point is the variants, not all eight guards.
for _,i in {2,1,3} do
 place("Soldier"..i,function(cf) return Cast.buildSoldier(root,cf,nil,i) end)
end
for _,i in {1,2,3} do
 place("Worker"..i,function(cf) return Cast.buildWorker(root,cf,i) end)
end

-- One settled animation frame, so what is photographed is a character as the
-- cinematic actually poses them rather than a bind pose. This is also the
-- check that no accessory is left behind by a pose: everything visible below
-- was driven through Cast.evaluate's rigid pass.
for _,entry in people do
 entry.rig.animState.phase="Idle"
 Cast.stepAnimate(entry.rig,2.6)
end

--[[
 THE BENCHMARK: a plain classic-avatar dummy - six blocks, head 1.2, torso
 2.4 x 2.4 x 1.2, arms and legs 1.2 x 2.4 x 1.2 - stood one place to the left
 of Lyra at the cast's own height. It answers the question this lineup exists
 for ("does this read as a Roblox character?") by putting the reference in the
 same frame, rather than leaving it to memory.
]]
do
 local x=-GAP
 local grey=Color3.fromRGB(150,152,156)
 local function block(name,size,y,dx)
  local part=Instance.new("Part")
  part.Name=name;part.Size=size;part.Color=grey;part.Transparency=0
  part.CFrame=CFrame.new(x+(dx or 0),y,0)
  part.Parent=root
 end
 block("DummyLeftLeg",V(1.2,2.4,1.2),1.2,-0.6)
 block("DummyRightLeg",V(1.2,2.4,1.2),1.2,0.6)
 block("DummyTorso",V(2.4,2.4,1.2),3.6)
 block("DummyLeftArm",V(1.2,2.4,1.2),3.6,-1.8)
 block("DummyRightArm",V(1.2,2.4,1.2),3.6,1.8)
 block("DummyHead",V(1.44,1.2,1.2),5.4)
end

local span=(#people-1)*GAP
local centre=V(span/2,3.4,0)

local function emit(out,tag,eye,target,fov,skipPrefix)
 local cf=CFrame.lookAt(eye,target)
 local look=cf.LookVector
 local parts={}
 for _,solid in RBX.solids do
  local transparency=rawget(solid,"Transparency") or 0
  local skipped=skipPrefix and string.sub(rawget(solid,"Name") or "",1,#skipPrefix)==skipPrefix
  if transparency<0.92 and not skipped then
   local pcf=rawget(solid,"CFrame")
   local size=rawget(solid,"Size")
   local delta=pcf.Position-eye
   local distance=delta.Magnitude
   local extent=math.max(size.X,size.Y,size.Z)
   if distance<MAX_DISTANCE and (distance<extent or delta:Dot(look)>0)
    and extent/math.max(distance,1)>MIN_ANGULAR_SIZE then
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

--[[
 EVERY CAMERA IS AT NEGATIVE Z, because that is the side the cast faces.

 Cast.place builds a root with CFrame.lookAt, whose LookVector is the frame's
 -Z, and the face geometry is built at negative Z on the head - so a lineup
 shot from +Z is a row of the backs of people's heads. Worth stating: the
 first run of this harness photographed exactly that, and a back-of-head row
 is genuinely hard to tell from a front-of-head row at thumbnail size when
 the hair is the thing under review.
]]
local out={}
--[[
 FRAMED IN GROUPS, not as one row. Seventeen people across one frame put each
 of them about forty pixels wide, which is too small to judge a hairstyle -
 and judging hairstyles is the entire purpose of this harness. Six at a time
 is the most that stays legible.
]]
local function group(tag,first,last,height,fov)
 local mid=V((first+last)/2*GAP,height,0)
 local width=(last-first+1)*GAP
 -- The renderer is 960x540, and its horizontal half-angle is the VERTICAL
 -- one times the aspect. Sizing the shot off fov alone (as the first version
 -- did) framed nearly twice the group it was asked for.
 local distance=width/2/(math.tan(math.rad(fov/2))*960/540)*1.1
 emit(out,tag,mid+V(0,0.4,-distance),mid,fov)
 emit(out,tag.."-silhouette",mid+V(0,0.4,-distance),mid,fov)
end
group("group-benchmark",-1,2,3.2,34)
group("group-leads",0,5,3.2,34)
group("group-scientists",6,10,3.2,34)
group("group-crew",11,16,3.2,34)
-- The three leads on their own, at conversation distance, which is the scale
-- the command room actually plays them at.
local leads=V(GAP,3.2,0)
emit(out,"leads-front",leads+V(0,0.4,-14),leads,42)
emit(out,"leads-threequarter",leads+V(-10,1.4,-11),leads,42)
-- Side-on, the three stand behind one another; from far enough out the
-- nearest (Lyra) is the profile under review and the others add depth.
emit(out,"leads-side",leads+V(-20,0.6,0.5),leads,30,"Dummy")
-- THE ACCEPTANCE TEST: identity with every colour thrown away. render.py
-- draws any tag containing "silhouette" as flat shapes.
emit(out,"leads-silhouette",leads+V(0,0.4,-14),leads,42)
emit(out,"leads-threequarter-silhouette",leads+V(-10,1.4,-11),leads,42)
print("["..table.concat(out,",").."]")
