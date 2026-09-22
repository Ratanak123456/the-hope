--!nonstrict
-- Aegis Zero's dialogue panel. The server decides what is said and when the
-- conversation counts as finished; this only renders and reports back.
--
-- Advance rules: the first advance completes the line that is still typing,
-- the next advance moves to the following line.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Theme)

local Responsive = require(script.Parent.Parent.Responsive)
local Settings = require(script.Parent.Parent.Settings)
local State = require(script.Parent.Parent.State)
local UIKit = require(script.Parent.Parent.UIKit)

local DialoguePanel = {}

local root: Frame
local panel: Frame
local speakerLabel: TextLabel
local bodyLabel: TextLabel
local hintLabel: TextLabel
local counterLabel: TextLabel
local portrait: Frame
local portraitRings: { Frame } = {}
local textNodes: { { label: TextLabel, style: string } } = {}
local choiceRow: Frame
local choiceButtons: { any } = {}

local lines: { any } = {}
local queued: { any } = {}
local lineIndex = 0
local activeToken: number? = nil
local typing = false
local typeConnection: RBXScriptConnection? = nil
local spinConnection: RBXScriptConnection? = nil
local onFinished: ((token: number) -> ())? = nil
local onChoice: ((token: number, choiceId: string) -> ())? = nil

-- Choices grow the otherwise fixed-height panel by exactly this much: the
-- hint row's normal 16px slot becomes a 62px 2x2 grid. Because `row`/`column`
-- fill the panel by Scale, this single number is the only thing that needs
-- to change - bodyLabel's Scale-minus-Offset height gains the same slack.
-- Forward-declared (assigned further down) so clearChoices/showChoices,
-- defined earlier in the file, can call it.
local choiceExtraHeight = 0
local applyLayout: () -> ()
local setChoicesVisible: (visible: boolean) -> ()

local function registerText(label: TextLabel, style: string)
	table.insert(textNodes, { label = label, style = style })
	label.TextSize = Theme.text(style, Responsive.compact)
end

-- Simple geometric AI portrait: nested squares and a core, no image assets.
local function buildPortrait(parent: Frame): Frame
	local holder = UIKit.create("Frame", {
		Parent = parent,
		BackgroundColor3 = Theme.Color.Void,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(64, 64),
		LayoutOrder = 1,
		Name = "Portrait",
		ClipsDescendants = true,
	})
	UIKit.corner(Theme.Metric.Radius).Parent = holder
	UIKit.stroke(Theme.Color.TealDeep, 1, 0.2).Parent = holder

	for index, spec in {
		{ size = 42, rotation = 0, transparency = 0.55, thickness = 1 },
		{ size = 30, rotation = 45, transparency = 0.3, thickness = 1 },
	} do
		local ring = UIKit.create("Frame", {
			Parent = holder,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(spec.size, spec.size),
			BackgroundTransparency = 1,
			Rotation = spec.rotation,
			Name = "Ring" .. index,
		})
		UIKit.stroke(Theme.Color.Teal, spec.thickness, spec.transparency).Parent = ring
		table.insert(portraitRings, ring)
	end

	local core = UIKit.create("Frame", {
		Parent = holder,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Theme.Color.TealGlow,
		BorderSizePixel = 0,
		Rotation = 45,
		Name = "Core",
	})
	UIKit.corner(2).Parent = core

	return holder
end

local function stopSpin()
	if spinConnection then
		spinConnection:Disconnect()
		spinConnection = nil
	end
end

local function startSpin()
	stopSpin()
	if Settings.reducedMotion() then
		return
	end
	spinConnection = RunService.RenderStepped:Connect(function(dt)
		for index, ring in portraitRings do
			if ring.Parent then
				ring.Rotation += dt * (if index % 2 == 0 then -14 else 9)
			end
		end
	end)
end

local function stopTyping()
	if typeConnection then
		typeConnection:Disconnect()
		typeConnection = nil
	end
	typing = false
end

local function clearChoices()
	for _, button in choiceButtons do
		button.instance:Destroy()
	end
	table.clear(choiceButtons)
	if choiceRow then
		choiceRow.Visible = false
	end
	setChoicesVisible(false)
end

local function closeActive()
	stopTyping()
	stopSpin()
	clearChoices()
	hintLabel.Visible = true
	activeToken = nil
	lines = {}
	lineIndex = 0
	root.Visible = false
	State.set("dialogueOpen", false)
end

-- Choices replace the "continue" affordance entirely: the line stays open
-- until the player picks one, so nothing here can be skipped past by accident.
local function showChoices(line)
	clearChoices()
	local options = line.choices
	if typeof(options) ~= "table" or #options == 0 then
		return
	end
	choiceRow.Visible = true
	hintLabel.Visible = false
	setChoicesVisible(true)

	for index, choice in options do
		local button = UIKit.button({
			Parent = choiceRow,
			Text = string.upper(tostring(choice.text or "")),
			variant = if index == 1 then "primary" else "ghost",
			compact = true,
			Size = UDim2.fromOffset(1, 1), -- overridden by the grid's CellSize
			LayoutOrder = index,
			Name = "Choice" .. index,
		})
		button.onActivated(function()
			local token = activeToken
			if not token then
				return
			end
			local id = tostring(choice.id or "")
			closeActive()
			if onChoice then
				onChoice(token, id)
			end
			local nextPayload = table.remove(queued, 1)
			if nextPayload then
				task.defer(DialoguePanel.play, nextPayload)
			end
		end)
		table.insert(choiceButtons, button)
	end

	GuiService.SelectedObject = choiceButtons[1].instance
end

local function finishLineInstantly()
	stopTyping()
	bodyLabel.MaxVisibleGraphemes = -1
	local line = lines[lineIndex]
	if lineIndex == #lines and typeof(line) == "table" and typeof(line.choices) == "table" then
		showChoices(line)
	else
		hintLabel.Visible = true
		hintLabel.Text = if Responsive.inputMode == "Touch" then "Tap to continue" elseif Responsive.inputMode == "Gamepad" then "[A] continue" else "[E] continue"
	end
end

local function showLine(index: number)
	local line = lines[index]
	if not line then
		return
	end
	stopTyping()
	clearChoices()

	speakerLabel.Text = string.upper(tostring(line.speaker or "KESTREL"))
	bodyLabel.Text = tostring(line.text or "")
	counterLabel.Text = string.format("%d / %d", index, #lines)

	local charsPerSecond = if Settings.get("instantDialogue") then 0 else Settings.charsPerSecond()
	if charsPerSecond <= 0 then
		finishLineInstantly()
		return
	end

	bodyLabel.MaxVisibleGraphemes = 0
	typing = true
	hintLabel.Visible = true
	hintLabel.Text = if Responsive.inputMode == "Touch" then "Tap to reveal" elseif Responsive.inputMode == "Gamepad" then "[A] reveal" else "[E] reveal"

	local revealed = 0
	local total = utf8.len(bodyLabel.Text) or #bodyLabel.Text
	typeConnection = RunService.Heartbeat:Connect(function(dt)
		revealed += dt * charsPerSecond
		local visible = math.floor(revealed)
		if visible >= total then
			finishLineInstantly()
		else
			bodyLabel.MaxVisibleGraphemes = visible
		end
	end)
end

function DialoguePanel.isOpen(): boolean
	return activeToken ~= nil
end

function DialoguePanel.advance()
	if not activeToken then
		return
	end
	if choiceRow.Visible then
		return -- a choice must be picked explicitly; the advance key does nothing here
	end
	if typing then
		finishLineInstantly()
		return
	end
	if lineIndex < #lines then
		lineIndex += 1
		showLine(lineIndex)
		return
	end

	local token = activeToken
	closeActive()
	if onFinished and token then
		onFinished(token)
	end
	local nextPayload = table.remove(queued, 1)
	if nextPayload then task.defer(DialoguePanel.play, nextPayload) end
end

function DialoguePanel.clear()
	closeActive()
	table.clear(queued)
end

function DialoguePanel.play(payload)
	if typeof(payload) ~= "table" or typeof(payload.lines) ~= "table" or #payload.lines == 0 then
		return
	end
	if activeToken then
		table.insert(queued, payload)
		return
	end
	stopTyping()
	clearChoices()

	lines = payload.lines
	lineIndex = 1
	activeToken = payload.token
	root.Visible = true
	State.set("dialogueOpen", true)
	startSpin()
	showLine(1)
end

function DialoguePanel.setFinishedCallback(callback: (token: number) -> ())
	onFinished = callback
end

-- Fired only when a line's choice button is picked, immediately after the
-- panel has already closed itself - the callback never has to do that part.
function DialoguePanel.setChoiceCallback(callback: (token: number, choiceId: string) -> ())
	onChoice = callback
end

applyLayout = function()
	local compact = Responsive.compact
	for _, node in textNodes do
		if node.label.Parent then
			node.label.TextSize = Theme.text(node.style, compact)
		end
	end
	panel.Size = UDim2.new(if compact then 0.94 else 0.72, 0, 0, (if compact then 138 else 156) + choiceExtraHeight)
	panel.Position = UDim2.new(0.5, 0, 1, if Responsive.touch then -118 else -Theme.Metric.EdgeInset)
	portrait.Size = UDim2.fromOffset(if compact then 48 else 64, if compact then 48 else 64)
	hintLabel.Text = if Responsive.inputMode == "Touch" then "Tap to continue" elseif Responsive.inputMode == "Gamepad" then "[A] continue" else "[E] continue"
end

setChoicesVisible = function(visible: boolean)
	choiceExtraHeight = if visible then 46 else 0
	applyLayout()
end

function DialoguePanel.build(parent: Frame)
	root = UIKit.container({ Parent = parent, Name = "Dialogue", Visible = false })

	panel = UIKit.panel({
		Parent = root,
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 0.05,
	})
	UIKit.create("UISizeConstraint", { Parent = panel, MaxSize = Vector2.new(880, 220) })
	UIKit.padding(14, 16, 12, 16).Parent = panel
	UIKit.bracket(panel, Vector2.new(0, 0), Theme.Color.Teal, 16)
	UIKit.bracket(panel, Vector2.new(1, 1), Theme.Color.Teal, 16)

	local row = UIKit.container({ Parent = panel, Size = UDim2.fromScale(1, 1), Name = "Row" })
	local rowLayout = UIKit.list(Enum.FillDirection.Horizontal, 14)
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	rowLayout.Parent = row

	portrait = buildPortrait(row)

	local column = UIKit.container({ Parent = row, Size = UDim2.new(1, -80, 1, 0), LayoutOrder = 2, Name = "Column" })
	UIKit.list(Enum.FillDirection.Vertical, 6).Parent = column

	local speakerRow = UIKit.container({ Parent = column, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1 })
	speakerLabel = UIKit.text({
		Parent = speakerRow,
		Size = UDim2.new(0.7, 0, 1, 0),
		Font = Theme.Font.Heading,
		Text = "KESTREL",
		TextColor3 = Theme.Color.Teal,
		Name = "Speaker",
	})
	registerText(speakerLabel, "Label")

	counterLabel = UIKit.text({
		Parent = speakerRow,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.3, 0, 1, 0),
		Font = Theme.Font.Mono,
		Text = "1 / 1",
		TextColor3 = Theme.Color.TextFaint,
		TextXAlignment = Enum.TextXAlignment.Right,
		Name = "Counter",
	})
	registerText(counterLabel, "Caption")

	UIKit.divider(column, 2)

	bodyLabel = UIKit.text({
		Parent = column,
		Size = UDim2.new(1, 0, 1, -56),
		Font = Theme.Font.Body,
		Text = "",
		TextColor3 = Theme.Color.Text,
		TextWrapped = true,
		LayoutOrder = 3,
		Name = "Body",
	})
	registerText(bodyLabel, "Body")

	hintLabel = UIKit.text({
		Parent = column,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Theme.Font.Label,
		Text = "[E] continue",
		TextColor3 = Theme.Color.TextFaint,
		LayoutOrder = 4,
		Name = "Hint",
	})
	registerText(hintLabel, "Caption")

	-- Repeat-interaction choices ("What should I do?" / "Explain the
	-- controls." / ...). Shares the hint row's LayoutOrder slot and is grown
	-- into via choiceExtraHeight/setChoicesVisible above.
	choiceRow = UIKit.container({
		Parent = column,
		Size = UDim2.new(1, 0, 0, 62),
		LayoutOrder = 4,
		Visible = false,
		Name = "Choices",
	})
	local choiceGrid = UIKit.create("UIGridLayout", {
		Parent = choiceRow,
		CellSize = UDim2.new(0.5, -4, 0, 26),
		CellPadding = UDim2.new(0, 8, 0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	choiceGrid.FillDirection = Enum.FillDirection.Horizontal

	-- Whole-panel tap target for touch and mouse. Sits BEHIND `row` (ZIndex 0
	-- vs. the default 1) so the choice buttons nested inside it - the only
	-- other interactive elements in this panel - take priority: Roblox's
	-- Sibling ZIndexBehavior resolves hit-testing at this level, so a higher
	-- ZIndex here would swallow clicks meant for anything nested in `row`.
	local tapTarget = UIKit.create("TextButton", {
		Parent = panel,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Name = "AdvanceTarget",
	})
	tapTarget.Activated:Connect(function()
		DialoguePanel.advance()
	end)

	applyLayout()
	Responsive.Changed:Connect(applyLayout)
	Settings.Changed:Connect(function(key)
		if key == "reducedMotion" and activeToken then
			startSpin()
		end
	end)
end

return DialoguePanel
