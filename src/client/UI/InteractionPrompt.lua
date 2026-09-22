--!nonstrict
-- One custom proximity surface for important world interactions. Roblox owns
-- focus and range; this module only presents the active prompt and its hold.

local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Theme)

local Responsive = require(script.Parent.Parent.Responsive)
local UIKit = require(script.Parent.Parent.UIKit)

local InteractionPrompt = {}

local root: Frame
local keyLabel: TextLabel
local actionLabel: TextLabel
local objectLabel: TextLabel
local progress: Frame
local activePrompt: ProximityPrompt? = nil
local holdStarted = 0
local holdConnection: RBXScriptConnection? = nil

local function stopHold()
	if holdConnection then
		holdConnection:Disconnect()
		holdConnection = nil
	end
	progress.Size = UDim2.fromScale(0, 1)
end

local function inputText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "HOLD"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return prompt.GamepadKeyCode.Name
	end
	local text = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	return if text ~= "" then text else prompt.KeyboardKeyCode.Name
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	activePrompt = prompt
	keyLabel.Text = inputText(prompt, inputType)
	actionLabel.Text = prompt.ActionText
	objectLabel.Text = prompt.ObjectText
	root.Visible = true
	root.Position = UDim2.new(0.5, 0, 1, if Responsive.touch then -184 else -116)
end

function InteractionPrompt.build(parent: Frame)
	root = UIKit.panel({
		Parent = parent,
		Name = "InteractionPrompt",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -116),
		Size = UDim2.fromOffset(330, 68),
		Visible = false,
		ClipsDescendants = true,
		ZIndex = 8,
	})
	UIKit.bracket(root, Vector2.new(0, 0), Theme.Color.Teal, 14)

	local key = UIKit.create("Frame", {
		Parent = root,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Theme.Color.SurfaceRaised,
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = 9,
	})
	UIKit.corner(5).Parent = key
	UIKit.stroke(Theme.Color.Teal, 1, 0.15).Parent = key
	keyLabel = UIKit.text({ Parent = key, Size = UDim2.fromScale(1, 1), Font = Theme.Font.Mono, Text = "E", TextColor3 = Theme.Color.TealGlow, TextSize = Theme.text("Caption"), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Rotation = -45, ZIndex = 10 })

	objectLabel = UIKit.text({ Parent = root, Position = UDim2.fromOffset(72, 11), Size = UDim2.new(1, -84, 0, 18), Font = Theme.Font.Label, Text = "ANCIENT SIGNAL", TextColor3 = Theme.Color.Teal, TextSize = Theme.text("Caption"), ZIndex = 9 })
	actionLabel = UIKit.text({ Parent = root, Position = UDim2.fromOffset(72, 30), Size = UDim2.new(1, -84, 0, 25), Font = Theme.Font.Heading, Text = "Hold to investigate", TextColor3 = Theme.Color.Text, TextSize = Theme.text("Body"), ZIndex = 9 })

	local track = UIKit.create("Frame", { Parent = root, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Theme.Color.LineSoft, BorderSizePixel = 0, ZIndex = 9 })
	progress = UIKit.create("Frame", { Parent = track, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Color.Teal, BorderSizePixel = 0, ZIndex = 10 })

	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then show(prompt, inputType) end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt == activePrompt then
			stopHold()
			activePrompt = nil
			root.Visible = false
		end
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		if prompt ~= activePrompt then return end
		stopHold()
		holdStarted = os.clock()
		local duration = math.max(prompt.HoldDuration, 0.01)
		holdConnection = RunService.Heartbeat:Connect(function()
			progress.Size = UDim2.fromScale(math.clamp((os.clock() - holdStarted) / duration, 0, 1), 1)
		end)
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		if prompt == activePrompt then stopHold() end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt == activePrompt then stopHold() end
	end)
end

return InteractionPrompt
