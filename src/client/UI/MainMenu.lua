--!nonstrict
-- Welcome screen. Owns menu visibility and the left-side composition; the
-- hangar scene and its camera belong to MenuScene.lua so the two can never
-- fight over CurrentCamera. While open, State.overlayOpen() is true, which is
-- what blocks combat input - Roblox's own menu and chat are untouched.
--
-- LAYOUT INTENT (rebuilt 2026-09-21). The screen is a poster, not a list of
-- buttons over a render:
--
--   * A directional scrim anchors the left third so type always has contrast,
--     plus a bottom scrim and four soft edge gradients acting as a vignette.
--     MenuScene's near-black foreground layer sits under exactly this area.
--   * One vertical rhythm in the column: EYEBROW -> TITLE -> RULE -> TAGLINE
--     -> (gap) -> PRIMARY -> (hairline) -> QUIET NAV -> HINT. Each step down
--     that list is visually quieter than the one above it, so "Start Game" is
--     the only thing on screen with a filled background.
--   * Secondary navigation is deliberately NOT a stack of boxed buttons. They
--     are quiet text rows with a leading accent tick that lights on hover or
--     controller focus, which is what keeps the primary action unambiguous.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Theme = require(Shared.Theme)

local TweenService = game:GetService("TweenService")

local Responsive = require(script.Parent.Parent.Responsive)
local State = require(script.Parent.Parent.State)
local UIKit = require(script.Parent.Parent.UIKit)
local MenuScene = require(script.Parent.Parent.MenuScene)
local Settings = require(script.Parent.Parent.Settings)

local MainMenu = {}

local root: Frame
local column: Frame
local creditsPanel: Frame
local eyebrowLabel: TextLabel
local titleLabel: TextLabel
local taglineLabel: TextLabel
local titleRule: Frame
local progressLine: TextLabel
local primaryButton: any
local primaryArrow: Frame
local primaryGlow: Frame
local hintLabel: TextLabel
local secondaryButtons: { [string]: any } = {}
local entranceScrim: Frame

local CHAPTER = Config.Chapters[1] -- only Chapter One exists; see ChaptersPanel for the same source of truth

local callbacks = {
	play = nil :: ((returning: boolean) -> ())?,
	settings = nil :: (() -> ())?,
	chapters = nil :: (() -> ())?,
	retryProgress = nil :: (() -> ())?,
}

-- Mirrors SaveService.Progress exactly (see Net.Feedback.Progress).
local progress = {
	status = "Loading" :: string,
	onboardingComplete = false,
	stage = "NotStarted" :: string,
}
local progressWatchdog: thread? = nil

--------------------------------------------------------------------------------
-- Primary action: text, sub-line and enabled state all come from real
-- server-reported progress - never an invented number, never a guess.
--------------------------------------------------------------------------------

local CHAPTER_LABEL = if CHAPTER then `CHAPTER {CHAPTER.number} · {CHAPTER.title}` else "CHAPTER PROGRESS"

local STAGE_TEXT: { [string]: { title: string, detail: string } } = {
	NotStarted = { title = "", detail = "" },
	Scene01_NormalMorning = { title = CHAPTER_LABEL, detail = "Nova City · Morning Delivery" },
	Scene02_CentralPlaza = { title = CHAPTER_LABEL, detail = "Central Plaza · The Sky Breaks" },
	Scene03_CitySurvival = { title = CHAPTER_LABEL, detail = "Nova City · Survival" },
	Scene04_EvacuationRun = { title = CHAPTER_LABEL, detail = "Nova City · The Hunter's Pursuit" },
	Scene05_Underground = { title = CHAPTER_LABEL, detail = "Beneath the City" },
	Scene06_AegisChamber = { title = CHAPTER_LABEL, detail = "The Awakening Chamber" },
	Scene07_AegisTraining = { title = CHAPTER_LABEL, detail = "The Awakening Chamber · Training" },
	Scene08_HarrowerBoss = { title = CHAPTER_LABEL, detail = `{Config.Encounter.Opening.Name} · In Progress` },
	Scene09_ChapterEnding = { title = CHAPTER_LABEL, detail = `{Config.Encounter.Opening.Name} · Cleared` },
	ChapterOneComplete = { title = CHAPTER_LABEL, detail = "Chapter Complete" },
}

local function isReturningPlayer(): boolean
	return progress.onboardingComplete or progress.stage ~= "NotStarted"
end

-- The primary button's glow is the one piece of emphasis on the screen; it is
-- hidden whenever the button is not actually actionable, so "looks important"
-- and "can be pressed" never disagree.
local function setPrimaryEmphasis(active: boolean)
	if not primaryGlow then
		return
	end
	primaryGlow.Visible = active
end

local function refreshPrimaryButton()
	if not primaryButton then
		return
	end
	if progress.status == "Loading" then
		primaryButton.setText("CHECKING PROGRESS…")
		primaryButton.setEnabled(false)
		primaryArrow.Visible = false
		progressLine.Visible = false
		setPrimaryEmphasis(false)
		return
	end

	if progress.status == "Failed" then
		primaryButton.setText("RETRY")
		primaryButton.setEnabled(true)
		primaryArrow.Visible = false
		progressLine.Visible = true
		progressLine.Text = "Progress could not be checked. Settings are still available."
		progressLine.TextColor3 = Theme.Color.Danger
		setPrimaryEmphasis(false)
		return
	end

	primaryArrow.Visible = true
	setPrimaryEmphasis(true)
	if isReturningPlayer() then
		primaryButton.setText("CONTINUE")
		local info = STAGE_TEXT[progress.stage] or STAGE_TEXT.Scene01_NormalMorning
		progressLine.Visible = true
		progressLine.TextColor3 = Theme.Color.TextMuted
		progressLine.Text = `{info.title}\n{info.detail}`
	else
		primaryButton.setText("START GAME")
		progressLine.Visible = false
	end
	primaryButton.setEnabled(true)
end

-- Applied the instant the button is pressed, before any network round trip:
-- "respond to activation immediately" + "lock repeated activation."
function MainMenu.setBusy(label: string?)
	if not primaryButton then
		return
	end
	primaryButton.setText(label or "PREPARING…")
	primaryButton.setEnabled(false)
	primaryArrow.Visible = false
	setPrimaryEmphasis(false)
end

--[[
	Server progress is pushed once as soon as the player joins ("Loading"),
	then again once it actually resolves. If that second message never
	arrives - a dropped remote, a very slow DataStore - this stops showing
	"Checking progress…" forever and treats it as a failure with a retry,
	which is the honest answer: "still loading" and "we don't know" must
	never look identical to the player.
]]
function MainMenu.setProgress(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if progressWatchdog then
		task.cancel(progressWatchdog)
		progressWatchdog = nil
	end
	progress.status = tostring(payload.status or "Ready")
	progress.onboardingComplete = payload.onboardingComplete == true
	progress.stage = tostring(payload.stage or "NotStarted")
	refreshPrimaryButton()

	if progress.status == "Loading" then
		progressWatchdog = task.delay(5, function()
			progressWatchdog = nil
			if progress.status == "Loading" then
				MainMenu.setProgress({ status = "Failed", onboardingComplete = false, stage = "NotStarted" })
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- Chrome
--------------------------------------------------------------------------------

-- Faux letter-spacing for the location label - Roblox TextLabels have no
-- native tracking control, so a space is inserted between characters.
local function spacedOut(text: string): string
	local chars = {}
	for char in text:gmatch(".") do
		table.insert(chars, char)
	end
	return table.concat(chars, " ")
end

--[[
	The scrim stack. Four separate gradients, each doing one job:

	 1. LEFT    a soft directional wash under the title column. Never a panel
	            with an edge - it has to melt into the render or it reads as a
	            rectangle pasted over half the shot.
	 2. BOTTOM  holds the version/hint line and weights the frame.
	 3. TOP     a short darkening so the ceiling of the hangar doesn't compete.
	 4. RIGHT   a thin darkening at the far edge; with 2 and 3 this is a
	            four-sided vignette, which Roblox cannot do radially.
]]
local function buildScrims(parent: Frame)
	local function wash(name: string, rotation: number, size: UDim2, anchor: Vector2, position: UDim2, stops: { { number } })
		local frame = UIKit.create("Frame", {
			Parent = parent,
			BackgroundColor3 = Theme.Color.Void,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = anchor,
			Position = position,
			Size = size,
			Name = name,
			ZIndex = 0,
		})
		local keypoints = {}
		for _, stop in stops do
			table.insert(keypoints, NumberSequenceKeypoint.new(stop[1], stop[2]))
		end
		UIKit.create("UIGradient", {
			Parent = frame,
			Rotation = rotation,
			Color = ColorSequence.new(Theme.Color.Void, Theme.Color.Void),
			Transparency = NumberSequence.new(keypoints),
		})
		return frame
	end

	wash("ScrimLeft", 0, UDim2.fromScale(1, 1), Vector2.new(0, 0), UDim2.fromScale(0, 0), {
		{ 0, 0.02 }, { 0.3, 0.16 }, { 0.52, 0.62 }, { 1, 1 },
	})
	wash("ScrimBottom", 90, UDim2.new(1, 0, 0.42, 0), Vector2.new(0, 1), UDim2.fromScale(0, 1), {
		{ 0, 1 }, { 0.55, 0.72 }, { 1, 0.18 },
	})
	wash("ScrimTop", 270, UDim2.new(1, 0, 0.22, 0), Vector2.new(0, 0), UDim2.fromScale(0, 0), {
		{ 0, 1 }, { 1, 0.4 },
	})
	wash("ScrimRight", 180, UDim2.new(0.22, 0, 1, 0), Vector2.new(1, 0), UDim2.fromScale(1, 0), {
		{ 0, 1 }, { 1, 0.45 },
	})
end

-- A small ">" chevron: two short bars meeting at a point on the right.
local function buildArrowIcon(parent: GuiObject): Frame
	local holder = UIKit.container({ Parent = parent, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(16, 16), Name = "Arrow", ZIndex = 3 })
	for _, spec in { { rotation = 42, y = 0.3 }, { rotation = -42, y = 0.7 } } do
		UIKit.create("Frame", {
			Parent = holder,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.3, 0, spec.y, 0),
			Size = UDim2.fromOffset(9, 2),
			Rotation = spec.rotation,
			BackgroundColor3 = Theme.Color.Void,
			BorderSizePixel = 0,
			ZIndex = 3,
		})
	end
	return holder
end

--[[
	A quiet navigation row: no fill, no border, one accent tick on the left
	that lights up on hover or controller focus and one text colour change.
	Deliberately lighter-weight than UIKit.button's "ghost" variant, which
	still draws a filled surface and a stroke - three of those stacked under
	the primary action is exactly the "everything looks equally important"
	problem this screen had.

	Returns the same { instance, onActivated, setEnabled, setText } shape
	UIKit.button does, so callers (and MainMenu.focusSecondary) do not care
	which of the two built a given row.
]]
local TICK_TWEEN = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function navRow(props): any
	local button = UIKit.create("TextButton", {
		Parent = props.Parent,
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.Surface,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.Font.Label,
		LayoutOrder = props.LayoutOrder or 0,
		Size = props.Size or UDim2.new(1, 0, 0, 44),
		Text = props.Text or "",
		TextColor3 = Theme.Color.TextMuted,
		TextSize = Theme.text("Body", Responsive.compact),
		TextXAlignment = Enum.TextXAlignment.Left,
		Name = props.Name or "NavRow",
		Selectable = true,
	})
	UIKit.create("UIPadding", { Parent = button, PaddingLeft = UDim.new(0, 18) })
	UIKit.corner(Theme.Metric.Radius).Parent = button

	local tick = UIKit.create("Frame", {
		Parent = button,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -18, 0.5, 0),
		Size = UDim2.fromOffset(2, 16),
		BackgroundColor3 = Theme.Color.Amber,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Name = "Tick",
	})

	local enabled = true
	local function highlight(on: boolean)
		if not enabled then
			return
		end
		TweenService:Create(tick, TICK_TWEEN, { BackgroundTransparency = if on then 0 else 1, Size = UDim2.fromOffset(2, if on then 20 else 16) }):Play()
		TweenService:Create(button, TICK_TWEEN, {
			TextColor3 = if on then Theme.Color.Text else Theme.Color.TextMuted,
			BackgroundTransparency = if on then 0.86 else 1,
		}):Play()
	end

	button.MouseEnter:Connect(function() highlight(true) end)
	button.MouseLeave:Connect(function() highlight(false) end)
	button.SelectionGained:Connect(function() highlight(true) end)
	button.SelectionLost:Connect(function() highlight(false) end)

	return {
		instance = button,
		setText = function(text: string) button.Text = text end,
		setEnabled = function(value: boolean)
			enabled = value
			button.Active = value
			button.TextColor3 = if value then Theme.Color.TextMuted else Theme.Color.TextFaint
		end,
		onActivated = function(callback: () -> ())
			return button.Activated:Connect(function()
				if enabled then
					callback()
				end
			end)
		end,
	}
end

local function buildCredits(parent: Frame): Frame
	local panel = UIKit.panel({
		Parent = parent,
		Name = "Credits",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		BackgroundTransparency = 0.05,
	})
	UIKit.padding(18, 20, 16, 20).Parent = panel
	UIKit.list(Enum.FillDirection.Vertical, 8).Parent = panel

	UIKit.text({
		Parent = panel,
		Size = UDim2.new(1, 0, 0, 22),
		Font = Theme.Font.Display,
		Text = "CREDITS",
		TextColor3 = Theme.Color.Text,
		TextSize = Theme.text("H2", Responsive.compact),
		LayoutOrder = 1,
	})
	UIKit.divider(panel, 2)
	UIKit.text({
		Parent = panel,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Body,
		Text = `{Config.Game.Title}\nStory, design and direction — project owner.\n\nGreybox world, Aegis Zero plating and Wardens are placeholder\nprocedural geometry, not final character art.\n\nBuilt in Roblox Studio with Rojo.`,
		TextColor3 = Theme.Color.TextMuted,
		TextWrapped = true,
		TextSize = Theme.text("Label", Responsive.compact),
		LayoutOrder = 3,
	})

	local back = UIKit.button({
		Parent = panel,
		Text = "BACK",
		variant = "ghost",
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 4,
		Name = "Back",
	})
	back.onActivated(function()
		panel.Visible = false
		column.Visible = true
	end)

	return panel
end

function MainMenu.setCallbacks(handlers)
	callbacks.play = handlers.play
	callbacks.settings = handlers.settings
	callbacks.chapters = handlers.chapters
	callbacks.retryProgress = handlers.retryProgress
end

function MainMenu.setVisible(visible: boolean)
	root.Visible = visible
	State.set("menuOpen", visible)
	if visible then
		column.Visible = true
		creditsPanel.Visible = false
		MenuScene.show()
	else
		MenuScene.hide()
	end
end

function MainMenu.isOpen(): boolean
	return root.Visible
end

-- Controller/keyboard focus restore: called after Chapters or Settings
-- closes, so focus lands back on the nav row it came from rather than
-- vanishing.
function MainMenu.focusSecondary(id: string)
	local button = secondaryButtons[id]
	if button then
		game:GetService("GuiService").SelectedObject = button.instance
	end
end

--[[
	Left column: 7% margin, ~34% width with sensible min/max, vertically
	centred slightly above the exact midpoint. On compact/mobile viewports the
	column takes the full width instead, since there is no room to also frame
	the mecha beside it - the hangar scene still shows behind, reframed toward
	the top by MenuScene's own camera choice under Responsive.compact.
]]
local function applyLayout()
	local compact = Responsive.compact
	eyebrowLabel.TextSize = Theme.text("Caption", compact)
	titleLabel.TextSize = Theme.text("Title", compact)
	taglineLabel.TextSize = Theme.text("Body", compact)
	hintLabel.TextSize = Theme.text("Caption", compact)
	primaryButton.instance.Size = UDim2.new(1, 0, 0, if compact then 56 else 64)
	primaryButton.instance.TextSize = Theme.text("Body", compact)
	column.Size = UDim2.new(if compact then 0.88 else 0.34, 0, 0, 0)
	column.Position = UDim2.new(if compact then 0.06 else 0.07, 0, if compact then 0.5 else 0.47, 0)
	column.AnchorPoint = Vector2.new(0, 0.5)
end

function MainMenu.build(parent: Frame)
	root = UIKit.container({ Parent = parent, Name = "MainMenu", Visible = true })
	buildScrims(root)

	column = UIKit.container({
		Parent = root,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Name = "Column",
		ZIndex = 2,
	})
	UIKit.create("UISizeConstraint", { Parent = column, MinSize = Vector2.new(320, 0), MaxSize = Vector2.new(540, 4000) })
	local columnLayout = UIKit.list(Enum.FillDirection.Vertical, Theme.Metric.Space12, Enum.HorizontalAlignment.Left)
	columnLayout.Parent = column

	-- A. Eyebrow: a short accent tick and the setting, letter-spaced. Sets
	-- the tone before the title without competing with it.
	local eyebrowRow = UIKit.container({ Parent = column, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Name = "Eyebrow", ZIndex = 2 })
	UIKit.create("Frame", {
		Parent = eyebrowRow,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(22, 2),
		BackgroundColor3 = Theme.Color.Teal,
		BorderSizePixel = 0,
		Name = "Tick",
		ZIndex = 2,
	})
	eyebrowLabel = UIKit.text({
		Parent = eyebrowRow,
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -32, 1, 0),
		Font = Theme.Font.Label,
		Text = spacedOut(Config.Game.LocationLabel),
		TextColor3 = Theme.Color.TextMuted,
		TextSize = Theme.text("Caption"),
		TextYAlignment = Enum.TextYAlignment.Center,
		Name = "Location",
		ZIndex = 2,
	})

	-- B. Title. LineHeight is tightened because a three-line display setting
	-- at default leading reads as three separate labels, not one title.
	titleLabel = UIKit.text({
		Parent = column,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Display,
		Text = Config.Game.Title,
		TextColor3 = Theme.Color.Text,
		TextWrapped = true,
		LineHeight = 0.92,
		LayoutOrder = 2,
		Name = "Title",
		ZIndex = 2,
	})

	-- C. Rule: the one graphic element between title and supporting line.
	titleRule = UIKit.create("Frame", {
		Parent = column,
		Size = UDim2.fromOffset(72, 2),
		BackgroundColor3 = Theme.Color.Amber,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Name = "Rule",
		ZIndex = 2,
	})

	-- D. Supporting line.
	taglineLabel = UIKit.text({
		Parent = column,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Body,
		Text = Config.Game.Tagline,
		TextColor3 = Theme.Color.TextMuted,
		TextWrapped = true,
		LayoutOrder = 4,
		Name = "Tagline",
		ZIndex = 2,
	})

	-- Spacer before the primary action, per the "separate title from
	-- navigation" spacing rule.
	UIKit.create("Frame", { Parent = column, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Theme.Metric.Space24), LayoutOrder = 5, Name = "Spacer1" })

	-- E. Primary action. The glow frame sits behind it (negative inset, lower
	-- ZIndex) so the button reads as lit rather than outlined.
	local primaryHolder = UIKit.container({ Parent = column, Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 6, Name = "PrimaryHolder", ZIndex = 2 })
	primaryGlow = UIKit.create("Frame", {
		Parent = primaryHolder,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 14, 1, 14),
		BackgroundColor3 = Theme.Color.Amber,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Visible = false,
		Name = "Glow",
		ZIndex = 1,
	})
	UIKit.corner(Theme.Metric.RadiusLarge).Parent = primaryGlow

	primaryButton = UIKit.button({
		Parent = primaryHolder,
		Text = "CHECKING PROGRESS…",
		variant = "accent",
		Size = UDim2.new(1, 0, 0, 64),
		Name = "Primary",
		ZIndex = 2,
	})
	primaryButton.instance.TextSize = Theme.text("Body")
	primaryButton.instance.Font = Theme.Font.Heading
	primaryArrow = buildArrowIcon(primaryButton.instance)
	primaryButton.setEnabled(false)

	progressLine = UIKit.text({
		Parent = column,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Label,
		Text = "",
		TextColor3 = Theme.Color.TextMuted,
		TextWrapped = true,
		TextSize = Theme.text("Caption"),
		Visible = false,
		LayoutOrder = 7,
		Name = "ProgressLine",
		ZIndex = 2,
	})

	UIKit.create("Frame", { Parent = column, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Theme.Metric.Space16), LayoutOrder = 8, Name = "Spacer2" })

	-- A hairline between the primary action and the quiet rows: the boundary
	-- between "the thing to do" and "everything else".
	UIKit.create("Frame", {
		Parent = column,
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Color.LineSoft,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		LayoutOrder = 9,
		Name = "Hairline",
		ZIndex = 2,
	})

	UIKit.create("Frame", { Parent = column, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Theme.Metric.Space8), LayoutOrder = 10, Name = "Spacer3" })

	-- F. Secondary navigation - quiet rows, not competing with the primary.
	local navOrder = 11
	local function navButton(id: string, text: string): any
		local button = navRow({
			Parent = column,
			Text = text,
			LayoutOrder = navOrder,
			Name = id,
		})
		navOrder += 1
		secondaryButtons[id] = button
		return button
	end

	navButton("chapters", "CHAPTERS")
	navButton("settings", "SETTINGS")
	-- Credits content is real (see buildCredits) - shown unconditionally
	-- because there is something true to say, not to fill space.
	navButton("credits", "CREDITS")

	UIKit.create("Frame", { Parent = column, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Theme.Metric.Space16), LayoutOrder = navOrder, Name = "Spacer4" })
	navOrder += 1

	-- G. Contextual help.
	hintLabel = UIKit.text({
		Parent = column,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Theme.Font.Label,
		Text = if Responsive.touch then "Tap Start to begin" elseif Responsive.inputMode == "Gamepad" then "[A] Start" else "[Enter] Start",
		TextColor3 = Theme.Color.TextFaint,
		TextSize = Theme.text("Caption"),
		LayoutOrder = navOrder,
		Name = "Hint",
		ZIndex = 2,
	})

	UIKit.text({
		Parent = root,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -Theme.Metric.EdgeInset, 1, -Theme.Metric.EdgeInset),
		Size = UDim2.fromOffset(280, 16),
		Font = Theme.Font.Mono,
		Text = Config.Game.Version,
		TextColor3 = Theme.Color.TextFaint,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 12,
		Name = "Version",
		ZIndex = 2,
	})

	creditsPanel = buildCredits(root)
	creditsPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	creditsPanel.Position = UDim2.fromScale(0.5, 0.6)
	creditsPanel.Size = UDim2.new(0, 360, 0, 0)
	creditsPanel.ZIndex = 3
	UIKit.create("UISizeConstraint", { Parent = creditsPanel, MaxSize = Vector2.new(420, 600) })

	-- A quick, honest entrance: the shell is already fully built above, so
	-- this is a pure cosmetic fade-in, never a wait (~0.35s, well inside the
	-- "roughly half a second" target). The title block also rises a few
	-- pixels into place, which is skipped entirely under reduced motion.
	entranceScrim = UIKit.create("Frame", { Parent = root, BackgroundColor3 = Theme.Color.Void, BackgroundTransparency = 0, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 50, Name = "Entrance" })
	UIKit.fade(entranceScrim, { BackgroundTransparency = 1 }, 0.35)
	if not Settings.reducedMotion() then
		titleRule.Size = UDim2.fromOffset(0, 2)
		TweenService:Create(titleRule, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0.18), { Size = UDim2.fromOffset(72, 2) }):Play()
	end
	task.delay(0.4, function()
		if entranceScrim then
			entranceScrim:Destroy()
			entranceScrim = nil :: any
		end
	end)

	primaryButton.onActivated(function()
		if progress.status == "Failed" then
			if callbacks.retryProgress then callbacks.retryProgress() end
		elseif progress.status == "Ready" then
			if callbacks.play then callbacks.play(isReturningPlayer()) end
		end
	end)
	secondaryButtons.chapters.onActivated(function()
		if callbacks.chapters then callbacks.chapters() end
	end)
	secondaryButtons.settings.onActivated(function()
		if callbacks.settings then callbacks.settings() end
	end)
	if secondaryButtons.credits then
		secondaryButtons.credits.onActivated(function()
			column.Visible = false
			creditsPanel.Visible = true
		end)
	end

	applyLayout()
	Responsive.Changed:Connect(applyLayout)
	State.set("menuOpen", true)
	MenuScene.show()
end

return MainMenu
