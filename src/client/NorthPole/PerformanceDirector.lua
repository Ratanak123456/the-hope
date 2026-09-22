--!nonstrict
-- One centralized actor update for the whole opening. It owns no camera or
-- timeline decisions; Sequences supplies the authored cues and this director
-- keeps base activity, gaze, reactions and joint evaluation alive between
-- cues. This avoids one RunService connection per NPC or per joint.
local RunService=game:GetService("RunService")
local Cast=require(script.Parent.Cast)
local Director={}
function Director.new(actors)
 local self={actors=actors,enabled=true,last=0}
 function self:setEnabled(value) self.enabled=value end
 function self:react(actors,expression,target,intensity)
  for _,actor in actors do Cast.react(actor,expression,target,intensity) end
 end
 function self:update(now)
  if not self.enabled then return end
  self.last=now
  for _,actor in self.actors do
   Cast.stepAnimate(actor,now)
   if RunService:IsStudio() and actor.model then
    actor.model:SetAttribute("CurrentActivity",actor.animState.activity or "Idle")
    actor.model:SetAttribute("CurrentPose",actor.animState.phase or "Idle")
    actor.model:SetAttribute("Expression",actor.expression or "Focused")
    actor.model:SetAttribute("LookTarget",actor.lookTarget and tostring(actor.lookTarget) or "")
   end
  end
 end
 return self
end
return Director
