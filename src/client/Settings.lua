--!nonstrict
-- Session-only player settings. Nothing here is saved yet - persistence lands
-- with the checkpoint/saving milestone, and the settings panel says so.

local Signal = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Signal)
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config)

local Settings = {}

Settings.Changed = Signal.new() -- (key, value)
Settings.persisted = false

Settings.values = {
	reducedMotion = false,
	textSpeed = "Normal", -- Slow | Normal | Fast
	hitMarker = true,
	cameraShake = "Low", -- Off | Low | Full
	vfxQuality = "Medium", -- Low | Medium | High
	instantDialogue = false,
}

function Settings.get(key: string): any
	return Settings.values[key]
end

function Settings.set(key: string, value: any)
	if Settings.values[key] == value then
		return
	end
	Settings.values[key] = value
	Settings.Changed:Fire(key, value)
end

function Settings.charsPerSecond(): number
	return Config.Dialogue.CharsPerSecond[Settings.values.textSpeed] or Config.Dialogue.CharsPerSecond.Normal
end

function Settings.reducedMotion(): boolean
	return Settings.values.reducedMotion == true
end

function Settings.shakeScale(): number
	if Settings.reducedMotion() or Settings.values.cameraShake == "Off" then
		return 0
	end
	return if Settings.values.cameraShake == "Full" then 1 else 0.55
end

function Settings.vfxQuality(): string
	return tostring(Settings.values.vfxQuality or "Medium")
end

return Settings
