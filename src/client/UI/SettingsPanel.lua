--!nonstrict
-- Settings. Only options with real behaviour are listed, and the panel states
-- plainly that nothing here is saved yet.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Theme)

local Responsive = require(script.Parent.Parent.Responsive)
local Settings = require(script.Parent.Parent.Settings)
local State = require(script.Parent.Parent.State)
local UIKit = require(script.Parent.Parent.UIKit)

local SettingsPanel = {}

local root: Frame
local panel: Frame
local content: Frame
local closeButton: any
local closeCallback: (() -> ())? = nil
local guideCallbacks = {
	replayIntro = nil :: (() -> ())?,
	requestTraining = nil :: (() -> ())?,
}

local function sectionLabel(parent: Frame, text: string, order: number)
	local label = UIKit.text({
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Theme.Font.Label,
		Text = text,
		TextColor3 = Theme.Color.Teal,
		TextSize = Theme.text("Caption", Responsive.compact),
		LayoutOrder = order,
		Name = "Section",
	})
	return label
end

local function row(parent: Frame, title: string, description: string, order: number): (Frame, Frame)
	local holder = UIKit.create("Frame", {
		Parent = parent,
		BackgroundColor3 = Theme.Color.SurfaceRaised,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Name = "Row",
	})
	UIKit.corner(Theme.Metric.Radius).Parent = holder
	UIKit.padding(12, 14, 12, 14).Parent = holder

	local textColumn = UIKit.container({
		Parent = holder,
		Size = UDim2.new(1, -200, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Name = "Text",
	})
	UIKit.list(Enum.FillDirection.Vertical, 2).Parent = textColumn

	UIKit.text({
		Parent = textColumn,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Theme.Font.Heading,
		Text = title,
		TextColor3 = Theme.Color.Text,
		TextSize = Theme.text("Label", Responsive.compact),
		LayoutOrder = 1,
	})
	UIKit.text({
		Parent = textColumn,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Body,
		Text = description,
		TextColor3 = Theme.Color.TextMuted,
		TextWrapped = true,
		TextSize = Theme.text("Caption", Responsive.compact),
		LayoutOrder = 2,
	})

	local controlHolder = UIKit.container({
		Parent = holder,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(186, 34),
		Name = "Control",
	})

	return holder, controlHolder
end

local function toggle(parent: Frame, key: string)
	local button = UIKit.create("TextButton", {
		Parent = parent,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(64, 30),
		BackgroundColor3 = Theme.Color.Void,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Name = "Toggle",
	})
	UIKit.corner(15).Parent = button
	local stroke = UIKit.stroke(Theme.Color.Line, 1, 0.3)
	stroke.Parent = button

	local knob = UIKit.create("Frame", {
		Parent = button,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Theme.Color.TextFaint,
		BorderSizePixel = 0,
		Name = "Knob",
	})
	UIKit.corner(12).Parent = knob

	local function paint()
		local on = Settings.get(key) == true
		knob.Position = if on then UDim2.new(1, -27, 0.5, 0) else UDim2.new(0, 3, 0.5, 0)
		knob.BackgroundColor3 = if on then Theme.Color.Teal else Theme.Color.TextFaint
		stroke.Color = if on then Theme.Color.TealDeep else Theme.Color.Line
	end

	button.Activated:Connect(function()
		Settings.set(key, not (Settings.get(key) == true))
	end)
	Settings.Changed:Connect(function(changedKey)
		if changedKey == key then
			paint()
		end
	end)
	paint()
	return button
end

local function segmented(parent: Frame, key: string, options: { string })
	local holder = UIKit.create("Frame", {
		Parent = parent,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(186, 30),
		BackgroundColor3 = Theme.Color.Void,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Name = "Segmented",
	})
	UIKit.corner(Theme.Metric.Radius).Parent = holder
	UIKit.stroke(Theme.Color.Line, 1, 0.35).Parent = holder
	UIKit.padding(3, 3, 3, 3).Parent = holder
	local layout = UIKit.list(Enum.FillDirection.Horizontal, 3)
	layout.Parent = holder

	local buttons: { TextButton } = {}
	for index, option in options do
		local button = UIKit.create("TextButton", {
			Parent = holder,
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Color.TealDeep,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Theme.Font.Label,
			Size = UDim2.new(1 / #options, -2, 1, 0),
			Text = string.upper(option),
			TextColor3 = Theme.Color.TextMuted,
			TextSize = Theme.text("Caption", Responsive.compact),
			LayoutOrder = index,
			Name = option,
		})
		UIKit.corner(4).Parent = button
		button.Activated:Connect(function()
			Settings.set(key, option)
		end)
		buttons[index] = button
	end

	local function paint()
		local current = Settings.get(key)
		for index, option in options do
			local selected = option == current
			buttons[index].BackgroundTransparency = if selected then 0.15 else 1
			buttons[index].TextColor3 = if selected then Theme.Color.Text else Theme.Color.TextMuted
		end
	end
	Settings.Changed:Connect(function(changedKey)
		if changedKey == key then
			paint()
		end
	end)
	paint()
	return holder
end

function SettingsPanel.setVisible(visible: boolean)
	root.Visible = visible
	State.set("settingsOpen", visible)
	if visible and closeButton then
		game:GetService("GuiService").SelectedObject = closeButton.instance
	end
end

function SettingsPanel.isOpen(): boolean
	return root.Visible
end

function SettingsPanel.setCloseCallback(callback: () -> ())
	closeCallback = callback
end

--[[
	replayIntro: cinematic only, never touches tutorial completion.
	requestTraining: "Practice again" - available even to a player who
	skipped onboarding entirely, per the requirement that skipping must not
	block access to training later.
]]
function SettingsPanel.setGuideCallbacks(callbacks: { replayIntro: (() -> ())?, requestTraining: (() -> ())? })
	guideCallbacks.replayIntro = callbacks.replayIntro
	guideCallbacks.requestTraining = callbacks.requestTraining
end

local function applyLayout()
	local compact = Responsive.compact
	panel.Size = UDim2.new(if compact then 0.94 else 0.56, 0, if compact then 0.86 else 0.74, 0)
end

function SettingsPanel.build(parent: Frame)
	root = UIKit.container({ Parent = parent, Name = "Settings", Visible = false })

	UIKit.create("Frame", {
		Parent = root,
		BackgroundColor3 = Theme.Color.Void,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Name = "Scrim",
	})

	panel = UIKit.panel({
		Parent = root,
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0.02,
	})
	UIKit.create("UISizeConstraint", { Parent = panel, MaxSize = Vector2.new(640, 720) })
	UIKit.padding(20, 22, 18, 22).Parent = panel

	local header = UIKit.container({ Parent = panel, Size = UDim2.new(1, 0, 0, 42), Name = "Header" })
	UIKit.text({
		Parent = header,
		Size = UDim2.new(1, -60, 0, 30),
		Font = Theme.Font.Display,
		Text = "SETTINGS",
		TextColor3 = Theme.Color.Text,
		TextSize = Theme.text("H1", Responsive.compact),
	})
	closeButton = UIKit.button({
		Parent = header,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(36, 32),
		Text = "✕",
		variant = "ghost",
		compact = true,
		Name = "Close",
	})
	closeButton.onActivated(function()
		if closeCallback then
			closeCallback()
		else
			SettingsPanel.setVisible(false)
		end
	end)

	content = UIKit.create("ScrollingFrame", {
		Parent = panel,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Color.Line,
		Name = "Content",
	})
	UIKit.list(Enum.FillDirection.Vertical, 8).Parent = content
	UIKit.padding(0, 8, 8, 0).Parent = content

	sectionLabel(content, "ACCESSIBILITY", 1)
	local _, motionControl = row(content, "Reduced motion", "Stops camera shake, field-of-view pulses and animated UI.", 2)
	toggle(motionControl, "reducedMotion")

	local _, markerControl = row(content, "Hit confirmation marker", "Shows a marker at the centre of the screen when a strike connects.", 3)
	toggle(markerControl, "hitMarker")

	local _, shakeControl = row(content, "Camera shake", "Controls local impact motion. Other players never move your camera.", 4)
	segmented(shakeControl, "cameraShake", { "Off", "Low", "Full" })

	local _, vfxControl = row(content, "Effects quality", "Low keeps attack warnings but removes decorative particles.", 5)
	segmented(vfxControl, "vfxQuality", { "Low", "Medium", "High" })

	sectionLabel(content, "DIALOGUE", 6)
	local _, speedControl = row(content, "Text speed", "How fast Aegis Zero's lines type out.", 7)
	segmented(speedControl, "textSpeed", { "Slow", "Normal", "Fast" })
	local _, instantControl = row(content, "Instant dialogue", "Shows complete lines immediately without typewriter motion.", 8)
	toggle(instantControl, "instantDialogue")

	sectionLabel(content, "GUIDE", 9)
	local _, introControl = row(content, "Replay intro", "Watch the opening cinematic again. Does not touch training progress.", 10)
	local introButton = UIKit.button({ Parent = introControl, Text = "REPLAY", variant = "ghost", compact = true, Size = UDim2.fromOffset(120, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0) })
	introButton.onActivated(function()
		if guideCallbacks.replayIntro then guideCallbacks.replayIntro() end
	end)

	local _, practiceControl = row(content, "Practice again", "Return to the launch platform and redo the training steps.", 11)
	local practiceButton = UIKit.button({ Parent = practiceControl, Text = "PRACTICE", variant = "ghost", compact = true, Size = UDim2.fromOffset(120, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0) })
	practiceButton.onActivated(function()
		if guideCallbacks.requestTraining then guideCallbacks.requestTraining() end
	end)

	sectionLabel(content, "NOT AVAILABLE YET", 12)
	local audioRow = row(content, "Audio", "Volume sliders appear once the game actually has sound.", 13)
	audioRow.BackgroundTransparency = 0.65

	local note = UIKit.text({
		Parent = content,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Body,
		Text = "These settings apply to this session only. They reset when you leave — saving arrives with the checkpoint milestone.",
		TextColor3 = Theme.Color.TextFaint,
		TextWrapped = true,
		TextSize = Theme.text("Caption", Responsive.compact),
		LayoutOrder = 14,
		Name = "PersistenceNote",
	})

	applyLayout()
	Responsive.Changed:Connect(applyLayout)
	return note
end

return SettingsPanel
