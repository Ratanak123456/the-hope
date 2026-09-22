--!nonstrict
-- Toggles the city between its peaceful (Chapter One, Scene 1) and invaded
-- (Scene 2 onward) states. Every instance that should not exist yet during
-- the peaceful scenes is tagged Kit.InvasionOnlyTag and hidden at build time
-- (see Kit.markInvasionOnly); this module just brings them back, once, when
-- the invasion actually begins. Building the world only once and toggling
-- visibility is far cheaper than generating two separate districts, and it
-- guarantees the "after" state is pixel-identical to what was always there.

local CollectionService = game:GetService("CollectionService")

local Kit = require(script.Parent.Kit)
local Sky = require(script.Parent.Sky)

local WorldState = {}

local revealed = false

-- Idempotent: safe to call once per player or once globally, whichever the
-- caller finds simpler - a second call is a silent no-op. Brings back every
-- ground-level Kit.markInvasionOnly() instance AND swaps the sky/lighting
-- mood (Sky.revealInvasion()) in the same call, so nothing can show one half
-- of the invasion without the other.
function WorldState.revealInvasion()
	if revealed then
		return
	end
	revealed = true
	Sky.revealInvasion()
	for _, instance in CollectionService:GetTagged(Kit.InvasionOnlyTag) do
		if instance:IsA("BasePart") then
			local transparency = instance:GetAttribute("PreInvasionTransparency")
			local canCollide = instance:GetAttribute("PreInvasionCanCollide")
			instance.Transparency = if typeof(transparency) == "number" then transparency else 0
			instance.CanCollide = canCollide == true
			instance.CanQuery = true
		end
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("BasePart") then
				local transparency = descendant:GetAttribute("PreInvasionTransparency")
				local canCollide = descendant:GetAttribute("PreInvasionCanCollide")
				descendant.Transparency = if typeof(transparency) == "number" then transparency else 0
				descendant.CanCollide = canCollide == true
				descendant.CanQuery = true
			elseif descendant:IsA("PointLight") or descendant:IsA("SpotLight") then
				local enabled = descendant:GetAttribute("PreInvasionLightEnabled")
				descendant.Enabled = enabled ~= false
			end
		end
	end
end

function WorldState.isInvasionRevealed(): boolean
	return revealed
end

return WorldState
