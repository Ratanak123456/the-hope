--!nonstrict
-- Chapter One's completion screen (Scene 9's ending). Distinct from
-- ResultPanel (that is the chamber encounter's victory/defeat popup, a
-- two-button shape that does not fit a multi-stat chapter milestone) -
-- shows the chapter title, a short stat summary and unlock line, and
-- Continue / Return to Menu.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Theme = require(Shared.Theme)

local Responsive = require(script.Parent.Parent.Responsive)
local State = require(script.Parent.Parent.State)
local UIKit = require(script.Parent.Parent.UIKit)

local ChapterCompletePanel = {}

local root: Frame
local panel: Frame
local statsLabel: TextLabel
local unlockLabel: TextLabel
local continueButton
local menuButton

local callbacks = {
	continue_ = nil :: (() -> ())?,
	returnToMenu = nil :: (() -> ())?,
}

function ChapterCompletePanel.setCallbacks(handlers)
	callbacks.continue_ = handlers.continue_
	callbacks.returnToMenu = handlers.returnToMenu
end

function ChapterCompletePanel.hide()
	root.Visible = false
	State.set("chapterCompleteOpen", false)
end

function ChapterCompletePanel.isOpen(): boolean
	return root.Visible
end

function ChapterCompletePanel.show(data)
	local rescued = (typeof(data) == "table" and tonumber(data.rescued)) or 0
	local unlocked = (typeof(data) == "table" and data.unlocked) or Config.Scene09.NewLocationUnlocked
	statsLabel.Text = `Civilians rescued: {rescued}\nThe Harrower: defeated`
	unlockLabel.Text = `New location unlocked — {unlocked}`
	root.Visible = true
	State.set("chapterCompleteOpen", true)
end

local function applyLayout()
	local compact = Responsive.compact
	panel.Size = UDim2.new(if compact then 0.94 else 0.52, 0, 0, 0)
end

function ChapterCompletePanel.build(parent: Frame)
	root = UIKit.container({ Parent = parent, Name = "ChapterComplete", Visible = false, ZIndex = 30 })

	UIKit.create("Frame", {
		Parent = root,
		BackgroundColor3 = Theme.Color.Void,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Name = "Scrim",
		ZIndex = 30,
	})

	panel = UIKit.panel({
		Parent = root,
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.02,
		ZIndex = 31,
	})
	UIKit.create("UISizeConstraint", { Parent = panel, MaxSize = Vector2.new(600, 1000) })
	UIKit.bracket(panel, Vector2.new(0, 0), Theme.Color.Amber, 18)
	UIKit.bracket(panel, Vector2.new(1, 0), Theme.Color.Amber, 18)

	local body = UIKit.container({ Parent = panel, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Name = "Body", ZIndex = 31 })
	UIKit.padding(26, 28, 24, 28).Parent = body
	UIKit.list(Enum.FillDirection.Vertical, 12).Parent = body

	UIKit.text({
		Parent = body,
		Size = UDim2.new(1, 0, 0, 14),
		Font = Theme.Font.Label,
		Text = "CHAPTER ONE COMPLETE",
		TextColor3 = Theme.Color.Amber,
		LayoutOrder = 1,
		ZIndex = 31,
	})

	UIKit.text({
		Parent = body,
		Size = UDim2.new(1, 0, 0, 38),
		Font = Theme.Font.Display,
		Text = Config.Scene09.ChapterSubtitle,
		TextColor3 = Theme.Color.Text,
		LayoutOrder = 2,
		ZIndex = 31,
	})

	UIKit.divider(body, 3)

	statsLabel = UIKit.text({
		Parent = body,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Body,
		Text = "",
		TextColor3 = Theme.Color.TextMuted,
		TextWrapped = true,
		LayoutOrder = 4,
		ZIndex = 31,
	})

	unlockLabel = UIKit.text({
		Parent = body,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Label,
		Text = "",
		TextColor3 = Theme.Color.Teal,
		TextWrapped = true,
		LayoutOrder = 5,
		ZIndex = 31,
	})

	UIKit.divider(body, 6)

	local buttonRow = UIKit.container({ Parent = body, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 7, Name = "Buttons", ZIndex = 31 })
	UIKit.list(Enum.FillDirection.Horizontal, 10).Parent = buttonRow

	continueButton = UIKit.button({ Parent = buttonRow, Text = "CONTINUE", variant = "primary", Size = UDim2.new(0.5, -5, 1, 0), LayoutOrder = 1, Name = "Continue", ZIndex = 31 })
	menuButton = UIKit.button({ Parent = buttonRow, Text = "RETURN TO MENU", variant = "ghost", Size = UDim2.new(0.5, -5, 1, 0), LayoutOrder = 2, Name = "Menu", ZIndex = 31 })

	continueButton.onActivated(function()
		if callbacks.continue_ then
			callbacks.continue_()
		end
		ChapterCompletePanel.hide()
	end)
	menuButton.onActivated(function()
		if callbacks.returnToMenu then
			callbacks.returnToMenu()
		end
		ChapterCompletePanel.hide()
	end)

	applyLayout()
	Responsive.Changed:Connect(applyLayout)
end

return ChapterCompletePanel
