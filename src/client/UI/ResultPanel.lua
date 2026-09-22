--!nonstrict
-- Encounter results: cleared and failed. Both states are pushed by the server;
-- the buttons here only send verbs back, they never change gameplay locally.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Theme = require(Shared.Theme)

local Responsive = require(script.Parent.Parent.Responsive)
local State = require(script.Parent.Parent.State)
local UIKit = require(script.Parent.Parent.UIKit)

local ResultPanel = {}

local root: Frame
local panel: Frame
local kicker: TextLabel
local titleLabel: TextLabel
local detailLabel: TextLabel
local footnote: TextLabel
local primaryButton
local secondaryButton
local accentRule: Frame

local countdownConnection: RBXScriptConnection? = nil
local countdownEnd = 0

local callbacks = {
	retry = nil :: (() -> ())?,
	returnToSurface = nil :: (() -> ())?,
	dismiss = nil :: (() -> ())?,
}

local function stopCountdown()
	if countdownConnection then
		countdownConnection:Disconnect()
		countdownConnection = nil
	end
end

local function startCountdown(seconds: number)
	stopCountdown()
	countdownEnd = os.clock() + seconds
	countdownConnection = RunService.Heartbeat:Connect(function()
		local remaining = countdownEnd - os.clock()
		if remaining <= 0 then
			footnote.Text = "Rebuilding the bond…"
			stopCountdown()
			return
		end
		footnote.Text = string.format("Automatic retry in %d s", math.ceil(remaining))
	end)
end

function ResultPanel.hide()
	stopCountdown()
	root.Visible = false
	State.set("resultOpen", false)
end

function ResultPanel.isOpen(): boolean
	return root.Visible
end

local function show(config)
	stopCountdown()
	kicker.Text = config.kicker
	kicker.TextColor3 = config.accent
	accentRule.BackgroundColor3 = config.accent
	titleLabel.Text = config.title
	detailLabel.Text = config.detail
	footnote.Text = config.footnote or ""

	primaryButton.setText(config.primaryText)
	secondaryButton.setText(config.secondaryText)
	primaryButton.setEnabled(true)
	secondaryButton.setEnabled(true)

	root.Visible = true
	State.set("resultOpen", true)
end

function ResultPanel.showVictory(data)
	local name = (typeof(data) == "table" and data.name) or "Encounter"
	show({
		kicker = "ENCOUNTER CLEARED",
		accent = Theme.Color.Teal,
		title = tostring(name),
		detail = "Every Warden in the chamber is down. Aegis Zero is still listening.",
		footnote = "Chapter progress saved.",
		primaryText = "RETURN TO SURFACE",
		secondaryText = "STAY IN THE CHAMBER",
	})
	ResultPanel.mode = "victory"
end

function ResultPanel.showDefeat(data)
	local inEncounter = typeof(data) == "table" and data.state == "Failed" and (data.total or 0) > 0
	show({
		kicker = "BOND BROKEN",
		accent = Theme.Color.Danger,
		title = if inEncounter then "The chamber holds" else "You went down",
		detail = if inEncounter
			then "Retrying resets the chamber and every Warden in it."
			else "Retrying returns you to your last checkpoint.",
		footnote = "",
		primaryText = "RETRY",
		secondaryText = "RETURN TO SURFACE",
	})
	ResultPanel.mode = "defeat"
	startCountdown(Config.Encounter.RetryFallbackSeconds)
end

function ResultPanel.setCallbacks(handlers)
	callbacks.retry = handlers.retry
	callbacks.returnToSurface = handlers.returnToSurface
	callbacks.dismiss = handlers.dismiss
end

local function applyLayout()
	local compact = Responsive.compact
	panel.Size = UDim2.new(if compact then 0.92 else 0.5, 0, 0, 0)
	titleLabel.TextSize = Theme.text("H1", compact)
	detailLabel.TextSize = Theme.text("Label", compact)
	kicker.TextSize = Theme.text("Caption", compact)
	footnote.TextSize = Theme.text("Caption", compact)
end

function ResultPanel.build(parent: Frame)
	root = UIKit.container({ Parent = parent, Name = "Result", Visible = false })

	UIKit.create("Frame", {
		Parent = root,
		BackgroundColor3 = Theme.Color.Void,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Name = "Scrim",
	})

	panel = UIKit.panel({
		Parent = root,
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.02,
	})
	UIKit.create("UISizeConstraint", { Parent = panel, MaxSize = Vector2.new(560, 1000) })
	accentRule = UIKit.create("Frame", {
		Parent = panel,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Theme.Color.Teal,
		BorderSizePixel = 0,
		ZIndex = 2,
		Name = "AccentRule",
	})

	UIKit.bracket(panel, Vector2.new(0, 1), Theme.Color.TealDeep, 16)
	UIKit.bracket(panel, Vector2.new(1, 1), Theme.Color.TealDeep, 16)

	local body = UIKit.container({
		Parent = panel,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Name = "Body",
	})
	UIKit.padding(22, 24, 20, 24).Parent = body
	UIKit.list(Enum.FillDirection.Vertical, 10).Parent = body

	kicker = UIKit.text({
		Parent = body,
		Size = UDim2.new(1, 0, 0, 14),
		Font = Theme.Font.Label,
		Text = "ENCOUNTER CLEARED",
		TextColor3 = Theme.Color.Teal,
		LayoutOrder = 1,
		Name = "Kicker",
	})

	titleLabel = UIKit.text({
		Parent = body,
		Size = UDim2.new(1, 0, 0, 34),
		Font = Theme.Font.Display,
		Text = "",
		TextColor3 = Theme.Color.Text,
		LayoutOrder = 2,
		Name = "Title",
	})

	detailLabel = UIKit.text({
		Parent = body,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Body,
		Text = "",
		TextColor3 = Theme.Color.TextMuted,
		TextWrapped = true,
		LayoutOrder = 3,
		Name = "Detail",
	})

	UIKit.divider(body, 4)

	local buttonRow = UIKit.container({ Parent = body, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 5, Name = "Buttons" })
	local buttonLayout = UIKit.list(Enum.FillDirection.Horizontal, 10)
	buttonLayout.Parent = buttonRow

	primaryButton = UIKit.button({
		Parent = buttonRow,
		Text = "RETRY",
		variant = "primary",
		Size = UDim2.new(0.5, -5, 1, 0),
		LayoutOrder = 1,
		Name = "Primary",
	})
	secondaryButton = UIKit.button({
		Parent = buttonRow,
		Text = "RETURN TO SURFACE",
		variant = "ghost",
		Size = UDim2.new(0.5, -5, 1, 0),
		LayoutOrder = 2,
		Name = "Secondary",
	})

	footnote = UIKit.text({
		Parent = body,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Theme.Font.Label,
		Text = "",
		TextColor3 = Theme.Color.TextFaint,
		LayoutOrder = 6,
		Name = "Footnote",
	})

	primaryButton.onActivated(function()
		if ResultPanel.mode == "defeat" then
			if callbacks.retry then
				callbacks.retry()
			end
		else
			if callbacks.returnToSurface then
				callbacks.returnToSurface()
			end
		end
		ResultPanel.hide()
	end)

	secondaryButton.onActivated(function()
		if ResultPanel.mode == "defeat" then
			if callbacks.returnToSurface then
				callbacks.returnToSurface()
			end
		else
			if callbacks.dismiss then
				callbacks.dismiss()
			end
		end
		ResultPanel.hide()
	end)

	applyLayout()
	Responsive.Changed:Connect(applyLayout)
end

ResultPanel.mode = "victory"

return ResultPanel
