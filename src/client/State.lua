--!nonstrict
-- Client-side view state. The HUD reads from here; the server is still the
-- authority for anything that matters, this is only what we were last told.

local Signal = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Signal)

local State = {}

State.Changed = Signal.new() -- (key, value)

State.menuOpen = true
State.openingActive = false
State.dialogueOpen = false
State.resultOpen = false
State.settingsOpen = false
State.wardenActive = false
State.wardenUnlocked = false
State.wardenBusy = false
State.encounterState = "Idle"

function State.set(key: string, value: any)
	if State[key] == value then
		return
	end
	State[key] = value
	State.Changed:Fire(key, value)
end

-- True whenever a full-screen surface owns the input.
function State.overlayOpen(): boolean
	return State.menuOpen or State.openingActive or State.resultOpen or State.settingsOpen
end

-- Combat verbs are blocked by any overlay and by an open conversation.
function State.combatAllowed(): boolean
	return not State.overlayOpen() and not State.dialogueOpen and not State.wardenBusy
end

return State
