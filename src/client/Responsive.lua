--!nonstrict
-- Viewport awareness. Layouts pick a discrete breakpoint instead of scaling
-- every element down, so text stays readable on phones.

local UserInputService = game:GetService("UserInputService")

local Signal = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Signal)

local Responsive = {}

Responsive.Changed = Signal.new() -- (compact: boolean, viewport: Vector2)
Responsive.compact = false
Responsive.mode = "Desktop" -- Desktop | Tablet | Mobile
Responsive.viewport = Vector2.new(1280, 720)
Responsive.touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
Responsive.inputMode = if Responsive.touch then "Touch" else "KeyboardMouse"

local COMPACT_WIDTH = 720

local function modeFor(viewport: Vector2): string
	if viewport.X < 720 or viewport.Y < 420 then
		return "Mobile"
	elseif viewport.X < 1180 or viewport.Y < 700 then
		return "Tablet"
	end
	return "Desktop"
end

local function evaluate(viewport: Vector2)
	local compact = viewport.X < COMPACT_WIDTH or viewport.Y < 420
	local mode = modeFor(viewport)
	local changed = compact ~= Responsive.compact or mode ~= Responsive.mode
	Responsive.compact = compact
	Responsive.mode = mode
	Responsive.viewport = viewport
	if changed then
		Responsive.Changed:Fire(compact, viewport)
	end
end

function Responsive.init()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	Responsive.viewport = camera.ViewportSize
	Responsive.compact = camera.ViewportSize.X < COMPACT_WIDTH or camera.ViewportSize.Y < 420
	Responsive.mode = modeFor(camera.ViewportSize)

	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		evaluate(camera.ViewportSize)
	end)

	-- Swapping between touch and keyboard changes key labels and safe zones, so
	-- it broadcasts the same way a breakpoint change does.
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		local touch = Responsive.touch
		local inputMode = Responsive.inputMode
		if inputType == Enum.UserInputType.Touch then
			touch = true
			inputMode = "Touch"
		elseif inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Keyboard then
			touch = false
			inputMode = "KeyboardMouse"
		elseif string.find(inputType.Name, "Gamepad") then
			touch = false
			inputMode = "Gamepad"
		end
		if touch ~= Responsive.touch or inputMode ~= Responsive.inputMode then
			Responsive.touch = touch
			Responsive.inputMode = inputMode
			Responsive.Changed:Fire(Responsive.compact, Responsive.viewport)
		end
	end)
end

return Responsive
