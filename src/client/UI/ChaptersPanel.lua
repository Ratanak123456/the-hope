--!nonstrict
-- Chapter selection. Only Chapter One exists (Config.Chapters), so this is a
-- single polished chapter card with a real status, not a grid of placeholder
-- cards for content that doesn't exist yet.

local GuiService = game:GetService("GuiService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Theme = require(Shared.Theme)

local Responsive = require(script.Parent.Parent.Responsive)
local UIKit = require(script.Parent.Parent.UIKit)

local ChaptersPanel = {}

local root: Frame
local panel: Frame
local content: Frame
local closeButton: any
local statusChip: Frame
local statusLabel: TextLabel
local noteLabel: TextLabel
local primaryButton: any
local closeCallback: (() -> ())? = nil
local playCallback: ((returning: boolean) -> ())? = nil

local CHAPTER = Config.Chapters[1]

local progress = {
	status = "Loading" :: string,
	onboardingComplete = false,
	stage = "NotStarted" :: string,
}

-- { badge text, badge colour, action text, note under the action }
local IN_PROGRESS = { badge = "IN PROGRESS", color = "Amber", action = "CONTINUE CHAPTER" }

local STAGE_PRESENTATION: { [string]: { badge: string, color: string, action: string, note: string? } } = {
	NotStarted = { badge = "AVAILABLE", color = "Teal", action = "START CHAPTER" },
	Scene01_NormalMorning = IN_PROGRESS,
	Scene02_CentralPlaza = IN_PROGRESS,
	Scene03_CitySurvival = IN_PROGRESS,
	Scene04_EvacuationRun = IN_PROGRESS,
	Scene05_Underground = IN_PROGRESS,
	Scene06_AegisChamber = IN_PROGRESS,
	Scene07_AegisTraining = IN_PROGRESS,
	Scene08_HarrowerBoss = IN_PROGRESS,
	Scene09_ChapterEnding = IN_PROGRESS,
	ChapterOneComplete = { badge = "COMPLETED", color = "Good", action = "REPLAY CHAPTER", note = "Replaying fights the chamber again - it will not erase your completed status." },
}

function ChaptersPanel.setProgress(payload)
	if typeof(payload) ~= "table" then
		return
	end
	progress.status = tostring(payload.status or "Ready")
	progress.onboardingComplete = payload.onboardingComplete == true
	progress.stage = tostring(payload.stage or "NotStarted")

	if not statusLabel then
		return
	end
	if progress.status ~= "Ready" then
		statusLabel.Text = if progress.status == "Loading" then "CHECKING…" else "STATUS UNKNOWN"
		statusChip.BackgroundColor3 = Theme.Color.SurfaceRaised
		primaryButton.setEnabled(false)
		noteLabel.Visible = false
		return
	end

	local info = STAGE_PRESENTATION[progress.stage] or STAGE_PRESENTATION.NotStarted
	statusLabel.Text = info.badge
	statusChip.BackgroundColor3 = (Theme.Color :: any)[info.color] or Theme.Color.Teal
	primaryButton.setText(info.action)
	primaryButton.setEnabled(true)
	if info.note then
		noteLabel.Visible = true
		noteLabel.Text = info.note
	else
		noteLabel.Visible = false
	end
end

function ChaptersPanel.setVisible(visible: boolean)
	root.Visible = visible
	if visible then
		GuiService.SelectedObject = closeButton.instance
	end
end

function ChaptersPanel.isOpen(): boolean
	return root.Visible
end

function ChaptersPanel.setCallbacks(handlers)
	closeCallback = handlers.close
	playCallback = handlers.play
end

local function applyLayout()
	local compact = Responsive.compact
	panel.Size = UDim2.new(if compact then 0.94 else 0.6, 0, if compact then 0.86 else 0.62, 0)
end

function ChaptersPanel.build(parent: Frame)
	root = UIKit.container({ Parent = parent, Name = "Chapters", Visible = false })

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
	UIKit.create("UISizeConstraint", { Parent = panel, MinSize = Vector2.new(420, 360), MaxSize = Vector2.new(760, 620) })
	UIKit.padding(20, 22, 18, 22).Parent = panel

	local header = UIKit.container({ Parent = panel, Size = UDim2.new(1, 0, 0, 42), Name = "Header" })
	UIKit.text({
		Parent = header,
		Size = UDim2.new(1, -60, 0, 30),
		Font = Theme.Font.Display,
		Text = "CHAPTERS",
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
		if closeCallback then closeCallback() else ChaptersPanel.setVisible(false) end
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
	UIKit.padding(0, 8, 8, 0).Parent = content

	local card = UIKit.panel({
		Parent = content,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.1,
		Name = "ChapterCard",
	})
	UIKit.padding(18, 20, 18, 20).Parent = card
	UIKit.list(Enum.FillDirection.Vertical, 10).Parent = card
	UIKit.bracket(card, Vector2.new(0, 0), Theme.Color.TealDeep, 14)

	local topRow = UIKit.container({ Parent = card, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Name = "TopRow" })
	UIKit.text({
		Parent = topRow,
		Size = UDim2.new(0.7, 0, 1, 0),
		Font = Theme.Font.Label,
		Text = if CHAPTER then `CHAPTER {CHAPTER.number}` else "NO CHAPTER DATA",
		TextColor3 = Theme.Color.Amber,
		TextSize = Theme.text("Caption"),
	})
	statusChip = UIKit.create("Frame", {
		Parent = topRow,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Color.SurfaceRaised,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Name = "StatusChip",
	})
	UIKit.corner(11).Parent = statusChip
	UIKit.padding(0, 10, 0, 10).Parent = statusChip
	statusLabel = UIKit.text({
		Parent = statusChip,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Theme.Font.Label,
		Text = "CHECKING…",
		TextColor3 = Theme.Color.Void,
		TextYAlignment = Enum.TextYAlignment.Center,
		Name = "StatusLabel",
	})

	UIKit.text({
		Parent = card,
		Size = UDim2.new(1, 0, 0, 26),
		Font = Theme.Font.Heading,
		Text = if CHAPTER then CHAPTER.title else "—",
		TextColor3 = Theme.Color.Text,
		TextSize = Theme.text("H2", Responsive.compact),
		LayoutOrder = 2,
		Name = "ChapterTitle",
	})

	UIKit.text({
		Parent = card,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Body,
		Text = if CHAPTER then CHAPTER.description else "",
		TextColor3 = Theme.Color.TextMuted,
		TextWrapped = true,
		TextSize = Theme.text("Label", Responsive.compact),
		LayoutOrder = 3,
		Name = "ChapterDescription",
	})

	primaryButton = UIKit.button({
		Parent = card,
		Text = "START CHAPTER",
		variant = "accent",
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 4,
		Name = "Primary",
	})
	primaryButton.setEnabled(false)
	primaryButton.onActivated(function()
		if playCallback then
			playCallback(progress.onboardingComplete or progress.stage ~= "NotStarted")
		end
	end)

	noteLabel = UIKit.text({
		Parent = card,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Body,
		Text = "",
		TextColor3 = Theme.Color.TextFaint,
		TextWrapped = true,
		TextSize = Theme.text("Caption", Responsive.compact),
		Visible = false,
		LayoutOrder = 5,
		Name = "Note",
	})

	if not CHAPTER then
		local emptyNote = UIKit.text({
			Parent = content,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = Theme.Font.Body,
			Text = "No chapters are defined yet.",
			TextColor3 = Theme.Color.TextFaint,
			TextWrapped = true,
			TextSize = Theme.text("Label", Responsive.compact),
			LayoutOrder = 2,
			Name = "EmptyNote",
		})
		emptyNote.Visible = true
		card.Visible = false
	end

	applyLayout()
	Responsive.Changed:Connect(applyLayout)
end

return ChaptersPanel
