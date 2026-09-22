--!nonstrict
-- Gameplay HUD: objective tracker, integrity readout, Aegis Zero status and the
-- action bar. Every value shown here comes from the server or from the live
-- Humanoid - nothing is invented locally.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Theme)

local Responsive = require(script.Parent.Parent.Responsive)
local State = require(script.Parent.Parent.State)
local UIKit = require(script.Parent.Parent.UIKit)

local HUD = {}

local root: Frame
local objectiveCard: Frame
local chapterLabel: TextLabel
local titleLabel: TextLabel
local detailLabel: TextLabel
local progressRow: Frame
local progressLabel: TextLabel
local pipHolder: Frame
local skipTrainingButton: any
local skipTutorialCallback: (() -> ())? = nil

local healthCard: Frame
local healthHeader: TextLabel
local healthValue: TextLabel
local healthBar
local healthTrail: Frame
local healthTrailToken = 0
local statusChip: Frame
local statusLabel: TextLabel

local actionBar: Frame
local slots: { [string]: any } = {}
local noticeCard: Frame
local noticeLabel: TextLabel
local noticeToken = 0

local enemyCard: Frame
local enemyLabel: TextLabel
local enemyBar
local enemyVisible = false

local settingsButton: TextButton
local settingsCallback: (() -> ())? = nil
local textNodes: { { label: TextLabel, style: string } } = {}
local humanoidConnections: { RBXScriptConnection } = {}
local cooldownConnection: RBXScriptConnection? = nil
local pipCount = 0
local modeSweepPlayed = false
local highlightConnection: RBXScriptConnection? = nil
local highlightedSlot: string? = nil

local ACTIONS = {
	{ id = "Strike", name = "Mechanical combo", key = "LMB", touchKey = "1", gamepadKey = "RT", icon = "Fist", order = 1 },
	{ id = "GroundSlam", name = "Ground slam", key = "R", touchKey = "2", gamepadKey = "X", icon = "Slam", order = 2 },
	{ id = "ResonanceBolt", name = "Resonance bolt", key = "F", touchKey = "3", gamepadKey = "RB", icon = "Bolt", order = 3 },
	{ id = "ThrusterDash", name = "Thruster dash", key = "SHIFT", touchKey = "4", gamepadKey = "B", icon = "Dash", order = 4 },
	{ id = "CoreBurst", name = "Core burst", key = "X", touchKey = "5", gamepadKey = "LB", icon = "Core", order = 5, ultimate = true },
	{ id = "Aegis", name = "Transform", key = "Q", touchKey = "Q", gamepadKey = "Y", icon = "Aegis", order = 6 },
}

local function iconLine(parent: GuiObject, size: UDim2, position: UDim2, rotation: number?, color: Color3?): Frame
	return UIKit.create("Frame", {
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		Rotation = rotation or 0,
		BackgroundColor3 = color or Theme.Color.Teal,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
end

local function buildAbilityIcon(parent: GuiObject, kind: string): Frame
	local icon = UIKit.container({ Parent = parent, Size = UDim2.fromOffset(28, 28), Name = "Icon", ZIndex = 3 })
	if kind == "Fist" then
		iconLine(icon, UDim2.fromOffset(17, 13), UDim2.fromScale(0.48, 0.48), -8)
		iconLine(icon, UDim2.fromOffset(7, 12), UDim2.fromScale(0.65, 0.72), 30)
	elseif kind == "Slam" then
		iconLine(icon, UDim2.fromOffset(5, 14), UDim2.fromScale(0.5, 0.33))
		for index = 1, 3 do
			iconLine(icon, UDim2.fromOffset(4 + index * 6, 2), UDim2.fromScale(0.5, 0.55 + index * 0.1), 0, if index == 3 then Theme.Color.Amber else Theme.Color.Teal)
		end
	elseif kind == "Bolt" then
		iconLine(icon, UDim2.fromOffset(7, 23), UDim2.fromScale(0.5, 0.5), 38)
		iconLine(icon, UDim2.fromOffset(12, 4), UDim2.fromScale(0.42, 0.46), -8, Theme.Color.TealGlow)
	elseif kind == "Dash" then
		for index = 1, 3 do
			iconLine(icon, UDim2.fromOffset(13, 3), UDim2.fromScale(0.32 + index * 0.16, 0.5), -42)
		end
	elseif kind == "Core" then
		local core = iconLine(icon, UDim2.fromOffset(13, 13), UDim2.fromScale(0.5, 0.5), 45, Theme.Color.Amber)
		UIKit.stroke(Theme.Color.Amber, 2, 0.1).Parent = core
		for index = 0, 3 do
			iconLine(icon, UDim2.fromOffset(2, 5), UDim2.fromScale(0.5, 0.5), index * 90, Theme.Color.Amber)
		end
	else
		local diamond = iconLine(icon, UDim2.fromOffset(17, 17), UDim2.fromScale(0.5, 0.5), 45)
		diamond.BackgroundTransparency = 0.2
		UIKit.stroke(Theme.Color.TealGlow, 1, 0.1).Parent = diamond
	end
	return icon
end

local function registerText(label: TextLabel, style: string)
	table.insert(textNodes, { label = label, style = style })
	label.TextSize = Theme.text(style, Responsive.compact)
end

local function buildObjectiveCard(parent: Frame)
	objectiveCard = UIKit.panel({
		Parent = parent,
		Name = "Objective",
		AnchorPoint = Vector2.new(0, 0),
		Size = UDim2.fromOffset(312, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.12,
	})

	-- Thin amber rule marking this as the objective surface. It lives outside
	-- the content frame so the list layout never treats it as a row.
	UIKit.create("Frame", {
		Parent = objectiveCard,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = Theme.Color.Amber,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 2,
		Name = "Rule",
	})

	UIKit.bracket(objectiveCard, Vector2.new(1, 0), Theme.Color.TealDeep, 12)
	local objectiveDiamond = UIKit.create("Frame", { Parent = objectiveCard, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(8, 8), Rotation = 45, BackgroundColor3 = Theme.Color.Amber, BorderSizePixel = 0, ZIndex = 3, Name = "ObjectiveDiamond" })
	UIKit.stroke(Theme.Color.Text, 1, 0.45).Parent = objectiveDiamond

	local card = UIKit.container({
		Parent = objectiveCard,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Name = "Content",
	})
	UIKit.padding(12, 14, 12, 14).Parent = card
	UIKit.list(Enum.FillDirection.Vertical, 4).Parent = card

	chapterLabel = UIKit.text({
		Parent = card,
		Size = UDim2.new(1, 0, 0, 14),
		Font = Theme.Font.Label,
		Text = "PROLOGUE",
		TextColor3 = Theme.Color.Amber,
		LayoutOrder = 1,
		Name = "Chapter",
	})
	registerText(chapterLabel, "Caption")

	titleLabel = UIKit.text({
		Parent = card,
		Size = UDim2.new(1, 0, 0, 22),
		Font = Theme.Font.Heading,
		Text = "The Sky Breaks",
		TextColor3 = Theme.Color.Text,
		LayoutOrder = 2,
		Name = "Title",
	})
	registerText(titleLabel, "H2")

	detailLabel = UIKit.text({
		Parent = card,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Body,
		Text = "Reach the Ancient signal at the city centre.",
		TextColor3 = Theme.Color.TextMuted,
		TextWrapped = true,
		LayoutOrder = 3,
		Name = "Detail",
	})
	registerText(detailLabel, "Label")

	progressRow = UIKit.container({
		Parent = card,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 4,
		Visible = false,
		Name = "Progress",
	})
	UIKit.list(Enum.FillDirection.Horizontal, 8).Parent = progressRow

	progressLabel = UIKit.text({
		Parent = progressRow,
		Size = UDim2.fromOffset(90, 20),
		Font = Theme.Font.Label,
		Text = "CONSTRUCTS 0/0",
		TextColor3 = Theme.Color.TextMuted,
		TextYAlignment = Enum.TextYAlignment.Center,
		LayoutOrder = 1,
		Name = "ProgressLabel",
	})
	registerText(progressLabel, "Caption")

	pipHolder = UIKit.container({
		Parent = progressRow,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Name = "Pips",
	})
	local pipLayout = UIKit.list(Enum.FillDirection.Horizontal, 4)
	pipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pipLayout.Parent = pipHolder

	skipTrainingButton = UIKit.button({
		Parent = card,
		Text = "SKIP TRAINING",
		variant = "ghost",
		compact = true,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 5,
		Name = "SkipTraining",
	})
	skipTrainingButton.instance.Visible = false
	skipTrainingButton.onActivated(function()
		if skipTutorialCallback then
			skipTutorialCallback()
		end
	end)
end

local function buildHealthCard(parent: Frame)
	healthCard = UIKit.panel({
		Parent = parent,
		Name = "Integrity",
		Size = UDim2.fromOffset(268, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.12,
	})
	UIKit.padding(12, 14, 12, 14).Parent = healthCard
	UIKit.list(Enum.FillDirection.Vertical, 6).Parent = healthCard

	local header = UIKit.container({ Parent = healthCard, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1 })
	healthHeader = UIKit.text({
		Parent = header,
		Size = UDim2.new(0.62, 0, 1, 0),
		Font = Theme.Font.Label,
		Text = "VITALS",
		TextColor3 = Theme.Color.TextMuted,
		Name = "Header",
	})
	registerText(healthHeader, "Caption")

	healthValue = UIKit.text({
		Parent = header,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		Font = Theme.Font.Mono,
		Text = "100 / 100",
		TextColor3 = Theme.Color.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
		Name = "Value",
	})
	registerText(healthValue, "Caption")

	healthBar = UIKit.bar({
		Parent = healthCard,
		Size = UDim2.new(1, 0, 0, 10),
		LayoutOrder = 2,
		Color = Theme.Color.Teal,
	})
	healthTrail = UIKit.create("Frame", { Parent = healthBar.instance, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Color.Danger, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 1, Name = "DamageTrail" })
	healthBar.fill.ZIndex = 2

	statusChip = UIKit.create("Frame", {
		Parent = healthCard,
		BackgroundColor3 = Theme.Color.SurfaceRaised,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 3,
		Name = "AegisStatus",
	})
	UIKit.corner(11).Parent = statusChip
	local chipStroke = UIKit.stroke(Theme.Color.Line, 1, 0.4)
	chipStroke.Name = "ChipStroke"
	chipStroke.Parent = statusChip
	UIKit.padding(0, 10, 0, 10).Parent = statusChip

	statusLabel = UIKit.text({
		Parent = statusChip,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Theme.Font.Label,
		Text = "WARDEN — DORMANT",
		TextColor3 = Theme.Color.TextMuted,
		TextYAlignment = Enum.TextYAlignment.Center,
		Name = "StatusLabel",
	})
	registerText(statusLabel, "Caption")
end

--[[
	Top-centre swarm status, the closest honest read this game has on a "boss
	bar" - there is no single boss, so this aggregates every spawned
	Warden's real Humanoid.Health instead of inventing one. Shown only
	while an encounter is actually active; kept clear of the centre of the
	screen so it never sits over combat.
]]
local function buildEnemyCard(parent: Frame)
	enemyCard = UIKit.panel({
		Parent = parent,
		Name = "EnemyStatus",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.12,
		Visible = false,
	})
	UIKit.padding(10, 14, 10, 14).Parent = enemyCard
	UIKit.list(Enum.FillDirection.Vertical, 5).Parent = enemyCard

	enemyLabel = UIKit.text({
		Parent = enemyCard,
		Size = UDim2.new(1, 0, 0, 14),
		Font = Theme.Font.Label,
		Text = "SWARM",
		TextColor3 = Theme.Color.Danger,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		Name = "Label",
	})
	registerText(enemyLabel, "Caption")

	enemyBar = UIKit.bar({
		Parent = enemyCard,
		Size = UDim2.new(1, 0, 0, 8),
		LayoutOrder = 2,
		Color = Theme.Color.Danger,
	})
end

local function buildSlot(parent: Frame, spec)
	local compact = Responsive.compact
	local button = UIKit.create("TextButton", {
		Parent = parent,
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.Surface,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(if compact then 62 else (if spec.ultimate then 74 else 68), if compact then 58 else 68),
		Text = "",
		LayoutOrder = spec.order,
		Name = spec.id,
		ClipsDescendants = false,
		Selectable = true,
	})
	UIKit.corner(Theme.Metric.Radius).Parent = button
	local stroke = UIKit.stroke(Theme.Color.Line, 1, 0.35)
	stroke.Parent = button

	local content = UIKit.container({ Parent = button, Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	UIKit.padding(5, 5, 5, 5).Parent = content
	local layout = UIKit.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = content

	local icon = buildAbilityIcon(content, spec.icon)
	icon.LayoutOrder = 1
	local keyText = if Responsive.inputMode == "Touch" then spec.touchKey elseif Responsive.inputMode == "Gamepad" then spec.gamepadKey else spec.key
	local keycap = UIKit.keycap(content, keyText, true)
	keycap.LayoutOrder = 2
	keycap.ZIndex = 2

	local nameLabel = UIKit.text({ Parent = button, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -7), Size = UDim2.fromOffset(132, 24), Font = Theme.Font.Label, Text = spec.name, TextColor3 = Theme.Color.Text, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, BackgroundColor3 = Theme.Color.SurfaceRaised, BackgroundTransparency = 0.04, Visible = false, ZIndex = 8, Name = "Tooltip" })
	UIKit.corner(4).Parent = nameLabel
	UIKit.stroke(Theme.Color.Line, 1, 0.2).Parent = nameLabel
	registerText(nameLabel, "Caption")

	local scrim = UIKit.create("Frame", {
		Parent = button,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Theme.Color.Void,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 3,
		Name = "Cooldown",
	})

	local timerLabel = UIKit.text({
		Parent = button,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Font.Mono,
		Text = "",
		TextColor3 = Theme.Color.Teal,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 4,
		Visible = false,
		Name = "Timer",
	})
	registerText(timerLabel, "Label")

	local charge = UIKit.create("Frame", { Parent = button, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(0, 0.06), BackgroundColor3 = Theme.Color.Amber, BorderSizePixel = 0, ZIndex = 5, Name = "Charge" })
	button.MouseEnter:Connect(function() nameLabel.Visible = true end)
	button.MouseLeave:Connect(function() nameLabel.Visible = false end)
	button.SelectionGained:Connect(function() nameLabel.Visible = true end)
	button.SelectionLost:Connect(function() nameLabel.Visible = false end)

	return {
		spec = spec,
		button = button,
		stroke = stroke,
		keycapLabel = keycap:FindFirstChild("Label") :: TextLabel,
		nameLabel = nameLabel,
		icon = icon,
		charge = charge,
		scrim = scrim,
		timerLabel = timerLabel,
		available = false,
		cooldownEnd = 0,
		cooldownDuration = 0,
		state = "Unavailable",
	}
end

local function buildActionBar(parent: Frame)
	actionBar = UIKit.container({
		Parent = parent,
		Name = "ActionBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
	})
	local layout = UIKit.list(Enum.FillDirection.Horizontal, Theme.Metric.Gap, Enum.HorizontalAlignment.Center)
	layout.Parent = actionBar

	for _, spec in ACTIONS do
		slots[spec.id] = buildSlot(actionBar, spec)
	end
end

local function paintSlot(slot)
	local available = slot.available
	slot.button.BackgroundTransparency = if available then 0.1 else 0.4
	slot.stroke.Color = if available then Theme.Color.TealDeep else Theme.Color.LineSoft
	slot.stroke.Transparency = if available then 0.15 else 0.6
	slot.nameLabel.TextColor3 = if available then Theme.Color.Text else Theme.Color.TextMuted
	slot.keycapLabel.TextColor3 = if available then Theme.Color.Teal else Theme.Color.TextFaint
	for _, child in slot.icon:GetDescendants() do
		if child:IsA("Frame") then
			child.BackgroundTransparency = if available then 0 else 0.55
		end
	end
end

function HUD.setSlotAvailable(id: string, available: boolean)
	local slot = slots[id]
	if not slot then
		return
	end
	slot.available = available
	paintSlot(slot)
end

function HUD.setSkipTutorialCallback(callback: () -> ())
	skipTutorialCallback = callback
end

--[[
	Onboarding's "briefly highlight the relevant control." A pulsing amber
	stroke on one action-bar slot, cleared the same way it was set - by name,
	or by passing nil - so at most one control is ever highlighted at once.
]]
function HUD.setHighlight(id: string?)
	if highlightedSlot and slots[highlightedSlot] then
		slots[highlightedSlot].stroke.Thickness = 1
		paintSlot(slots[highlightedSlot])
	end
	highlightedSlot = id
	if highlightConnection then
		highlightConnection:Disconnect()
		highlightConnection = nil
	end
	local slot = id and slots[id]
	if not slot then
		return
	end
	highlightConnection = RunService.Heartbeat:Connect(function()
		if not slot.button.Parent then
			return
		end
		local pulse = 0.5 + math.sin(os.clock() * 6) * 0.5
		slot.stroke.Color = Theme.Color.Amber
		slot.stroke.Thickness = 1.5 + pulse * 1.5
		slot.stroke.Transparency = 0.1 - pulse * 0.1
	end)
end

local function tickCooldowns()
	local now = os.clock()
	local anyActive = false
	for _, slot in slots do
		if slot.cooldownEnd > now then
			anyActive = true
			local remaining = slot.cooldownEnd - now
			slot.scrim.Size = UDim2.fromScale(1, math.clamp(remaining / slot.cooldownDuration, 0, 1))
			slot.timerLabel.Visible = true
			slot.timerLabel.Text = string.format("%.1f", remaining)
		elseif slot.timerLabel.Visible then
			slot.scrim.Size = UDim2.fromScale(1, 0)
			slot.timerLabel.Visible = false
			slot.timerLabel.Text = ""
		end
	end
	if not anyActive and cooldownConnection then
		cooldownConnection:Disconnect()
		cooldownConnection = nil
	end
end

function HUD.startCooldown(id: string, duration: number)
	local slot = slots[id]
	if not slot or duration <= 0 then
		return
	end
	slot.cooldownDuration = duration
	slot.cooldownEnd = os.clock() + duration
	if not cooldownConnection then
		cooldownConnection = RunService.Heartbeat:Connect(tickCooldowns)
	end
end

function HUD.setRequested(id: string)
	local slot = slots[id]
	if not slot or not slot.available then
		return
	end
	slot.button.Size -= UDim2.fromOffset(3, 3)
	task.delay(0.1, function()
		if slot.button.Parent then
			local size = if Responsive.compact then 62 else (if slot.spec.ultimate then 74 else 68)
			slot.button.Size = UDim2.fromOffset(size, if Responsive.compact then 58 else 68)
		end
	end)
end

function HUD.setAbilityState(data)
	if typeof(data) ~= "table" then
		return
	end
	local id = tostring(data.ability or "")
	local slot = slots[id]
	if not slot then
		return
	end
	if data.accepted == false then
		slot.stroke.Color = Theme.Color.Danger
		slot.nameLabel.Text = tostring(data.reason or "Unavailable")
		HUD.notify(tostring(data.reason or "Ability unavailable"))
		task.delay(0.65, function()
			if slot.button.Parent then
				slot.nameLabel.Text = slot.spec.name
				paintSlot(slot)
			end
		end)
	elseif data.accepted == true then
		slot.stroke.Color = if id == "CoreBurst" then Theme.Color.Amber else Theme.Color.TealGlow
	end
	local charge = tonumber(data.charge)
	local required = tonumber(data.required)
	if id == "CoreBurst" and charge and required and required > 0 then
		slot.charge.Size = UDim2.fromScale(math.clamp(charge / required, 0, 1), 0.06)
		HUD.setSlotAvailable(id, State.wardenActive and charge >= required)
		if charge >= required then
			slot.stroke.Color = Theme.Color.Amber
			slot.nameLabel.Text = "Core burst ready"
		end
	end
end

function HUD.notify(text: string)
	noticeToken += 1
	local token = noticeToken
	noticeLabel.Text = text
	noticeCard.Visible = true
	noticeCard.BackgroundTransparency = 0.08
	task.delay(2.4, function()
		if token == noticeToken and noticeCard.Parent then
			UIKit.fade(noticeCard, { BackgroundTransparency = 1 }, 0.25)
			task.delay(0.26, function()
				if token == noticeToken then noticeCard.Visible = false end
			end)
		end
	end)
end

function HUD.clearCooldowns()
	for _, slot in slots do
		slot.cooldownEnd = 0
		slot.cooldownDuration = 0
		slot.scrim.Size = UDim2.fromScale(1, 0)
		slot.timerLabel.Visible = false
	end
	if cooldownConnection then
		cooldownConnection:Disconnect()
		cooldownConnection = nil
	end
	HUD.setHighlight(nil)
end

function HUD.onSlotActivated(id: string, callback: () -> ())
	local slot = slots[id]
	if not slot then
		return
	end
	slot.button.Activated:Connect(function()
		callback()
	end)
end

function HUD.setObjective(data)
	if typeof(data) ~= "table" then
		return
	end
	local nextTitle = tostring(data.title or "")
	local changed = titleLabel.Text ~= nextTitle
	chapterLabel.Text = tostring(data.chapter or "")
	titleLabel.Text = nextTitle
	detailLabel.Text = tostring(data.detail or "")
	if changed then
		titleLabel.TextTransparency = 0.55
		UIKit.fade(titleLabel, { TextTransparency = 0 }, 0.28)
	end

	skipTrainingButton.instance.Visible = data.tutorial == true

	local total = tonumber(data.progressTotal)
	local current = tonumber(data.progressCurrent)
	if total and total > 0 then
		progressRow.Visible = true
		progressLabel.Text = string.format("CONSTRUCTS %d/%d", current or 0, total)
		if pipCount ~= total then
			pipCount = total
			for _, child in pipHolder:GetChildren() do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end
			for index = 1, total do
				local pip = UIKit.create("Frame", {
					Parent = pipHolder,
					BackgroundColor3 = Theme.Color.Alien,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(10, 4),
					LayoutOrder = index,
					Name = "Pip" .. index,
				})
				UIKit.corner(2).Parent = pip
			end
		end
		local defeated = current or 0
		local index = 0
		for _, child in pipHolder:GetChildren() do
			if child:IsA("Frame") then
				index += 1
				child.BackgroundColor3 = if index <= defeated then Theme.Color.TealDeep else Theme.Color.Alien
			end
		end
	else
		progressRow.Visible = false
		pipCount = 0
	end
end

-- data: { active, label, current, max } - see EncounterService.pushWardenStatusTo.
-- current/max are real summed Humanoid.Health, not invented numbers.
function HUD.setEnemyStatus(data)
	if typeof(data) ~= "table" or data.active ~= true then
		if enemyVisible then
			enemyVisible = false
			UIKit.fade(enemyCard, { BackgroundTransparency = 1 }, 0.2)
			task.delay(0.22, function()
				if not enemyVisible and enemyCard.Parent then
					enemyCard.Visible = false
				end
			end)
		end
		return
	end

	local max = math.max(tonumber(data.max) or 1, 1)
	local current = math.clamp(tonumber(data.current) or 0, 0, max)
	local ratio = current / max

	enemyLabel.Text = tostring(data.label or "SWARM")
	enemyBar.setRatio(ratio, true)
	enemyBar.setColor(if ratio <= 0.3 then Theme.Color.Danger else Theme.Color.Alien)

	if not enemyVisible then
		enemyVisible = true
		enemyCard.Visible = true
		enemyCard.BackgroundTransparency = 1
		UIKit.fade(enemyCard, { BackgroundTransparency = 0.12 }, 0.25)
	end
end

function HUD.setAegisStatus(unlocked: boolean, active: boolean)
	local text, color, strokeColor
	if active then
		text, color, strokeColor = "WARDEN — ACTIVE", Theme.Color.Teal, Theme.Color.Teal
	elseif unlocked then
		text, color, strokeColor = "WARDEN — AVAILABLE", Theme.Color.Amber, Theme.Color.AmberDeep
	else
		text, color, strokeColor = "WARDEN — DORMANT", Theme.Color.TextMuted, Theme.Color.Line
	end
	statusLabel.Text = text
	statusLabel.TextColor3 = color
	local stroke = statusChip:FindFirstChild("ChipStroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = strokeColor
	end

	HUD.setSlotAvailable("Aegis", unlocked)
	for _, id in { "Strike", "GroundSlam", "ResonanceBolt", "ThrusterDash" } do
		HUD.setSlotAvailable(id, active)
	end
	HUD.setSlotAvailable("CoreBurst", false)
	healthBar.setColor(if active then Theme.Color.Teal else Theme.Color.Amber)
end

local function refreshHealth(humanoid: Humanoid)
	local maxHealth = math.max(humanoid.MaxHealth, 1)
	local ratio = math.clamp(humanoid.Health / maxHealth, 0, 1)
	healthValue.Text = string.format("%d / %d", math.floor(humanoid.Health + 0.5), math.floor(maxHealth + 0.5))
	local previousRatio = healthBar.fill.Size.X.Scale
	healthBar.setRatio(ratio, true)
	if ratio < previousRatio then
		healthTrailToken += 1
		local token = healthTrailToken
		healthTrail.Size = UDim2.fromScale(previousRatio, 1)
		task.delay(0.28, function()
			if token == healthTrailToken and healthTrail.Parent then
				game:GetService("TweenService"):Create(healthTrail, TweenInfo.new(0.38, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(ratio, 1) }):Play()
			end
		end)
	else
		healthTrail.Size = UDim2.fromScale(ratio, 1)
	end
	if ratio <= 0.3 then
		healthBar.setColor(Theme.Color.Danger)
		healthHeader.Text = "LOW INTEGRITY"
		healthHeader.TextColor3 = Theme.Color.Danger
	else
		healthBar.setColor(if State.wardenActive then Theme.Color.Teal else Theme.Color.Amber)
		healthHeader.Text = if State.wardenActive then "WARDEN INTEGRITY" else "VITALS"
		healthHeader.TextColor3 = if State.wardenActive then Theme.Color.Teal else Theme.Color.TextMuted
	end
end

function HUD.setStatus(text: string)
	statusLabel.Text = text
	statusLabel.TextColor3 = if text == "TRANSFORMING" then Theme.Color.Amber else Theme.Color.TextMuted
end

function HUD.bindHumanoid(humanoid: Humanoid?)
	for _, connection in humanoidConnections do
		connection:Disconnect()
	end
	table.clear(humanoidConnections)
	if not humanoid then
		return
	end
	refreshHealth(humanoid)
	table.insert(humanoidConnections, humanoid.HealthChanged:Connect(function()
		refreshHealth(humanoid)
	end))
	table.insert(humanoidConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		refreshHealth(humanoid)
	end))
end

-- Small, quiet entry point to settings during play. Top-right, clear of the
-- Roblox top bar thanks to the ScreenGui's CoreUI safe insets.
local function buildSettingsButton(parent: Frame)
	settingsButton = UIKit.create("TextButton", {
		Parent = parent,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Theme.Metric.EdgeInset, 0, Theme.Metric.EdgeInset),
		Size = UDim2.fromOffset(34, 34),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.Surface,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Font = Theme.Font.Heading,
		Text = "",
		TextColor3 = Theme.Color.TextMuted,
		TextSize = 18,
		Name = "SettingsButton",
	})
	UIKit.corner(Theme.Metric.Radius).Parent = settingsButton
	UIKit.stroke(Theme.Color.LineSoft, 1, 0.4).Parent = settingsButton
	for index = 1, 3 do
		local line = UIKit.create("Frame", { Parent = settingsButton, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 8 + index * 5), Size = UDim2.fromOffset(17, 2), BackgroundColor3 = Theme.Color.TextMuted, BorderSizePixel = 0, ZIndex = 2 })
		UIKit.create("Frame", { Parent = line, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, if index % 2 == 0 then 5 else 12, 0.5, 0), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = Theme.Color.Teal, BorderSizePixel = 0, ZIndex = 3 })
	end
	settingsButton.Activated:Connect(function()
		if settingsCallback then
			settingsCallback()
		end
	end)
end

function HUD.setSettingsCallback(callback: () -> ())
	settingsCallback = callback
end

--[[
	Human mode is deliberately minimal: no strike slot, a plain vitals readout.
	Aegis Zero mode reveals the combat information, with a short accent sweep so the
	change is felt rather than just appearing.

	mode is "Human", "Awakening" or "Aegis".
]]
local currentMode = "Human"
local humanCombatEnabled = false

-- Chapter One Scene 3's temporary emergency-staff combat (rule: "mobile/
-- controller inputs" for the human-form Strike/Shove/Dodge kit - see
-- CombatService.lua's castHuman* casts). Shows the same three slots Aegis
-- mode uses (Strike/GroundSlam/ThrusterDash - reused rather than adding a
-- parallel set of slots, since a player is never in both modes at once) so
-- keyboard/mouse/gamepad and touch all get a working control surface,
-- independent of whatever Human/Awakening/Aegis mode is currently set.
function HUD.setHumanCombatEnabled(enabled: boolean)
	humanCombatEnabled = enabled
	HUD.setMode(currentMode)
end

function HUD.setMode(mode: string)
	currentMode = mode
	local aegis = mode == "Aegis"
	local awakening = mode == "Awakening"

	for id, slot in slots do
		if id == "Aegis" then
			slot.button.Visible = true
		elseif humanCombatEnabled and (id == "Strike" or id == "GroundSlam" or id == "ThrusterDash") then
			slot.button.Visible = true
		else
			slot.button.Visible = aegis or awakening
		end
	end

	healthHeader.Text = if aegis then "AEGIS INTEGRITY" elseif awakening then "RESONANCE RISING" else "VITALS"
	healthHeader.TextColor3 = if aegis then Theme.Color.Teal elseif awakening then Theme.Color.Amber else Theme.Color.TextMuted

	local stroke = healthCard:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if aegis then Theme.Color.TealDeep else Theme.Color.LineSoft
	end

	if aegis and not modeSweepPlayed then
		modeSweepPlayed = true
		UIKit.fade(healthCard, { BackgroundTransparency = 0.12 }, 0.35)
		healthCard.BackgroundTransparency = 0.02
	elseif not aegis then
		modeSweepPlayed = false
	end
end

function HUD.setVisible(visible: boolean)
	root.Visible = visible
end

-- The dialogue panel and the action bar share the bottom-centre of the screen,
-- so only one of them is ever on screen at a time.
function HUD.setActionBarVisible(visible: boolean)
	actionBar.Visible = visible
end

-- Discrete layouts rather than a blanket UIScale: on narrow screens the
-- integrity card joins the top-left stack (clear of the mobile joystick) and
-- the action bar lifts above the jump button.
local function applyLayout()
	local compact = Responsive.compact
	local inset = Theme.Metric.EdgeInset
	local chatClearance = if compact then Theme.Metric.ChatClearanceCompact else Theme.Metric.ChatClearanceDesktop

	for _, node in textNodes do
		if node.label.Parent then
			node.label.TextSize = Theme.text(node.style, compact)
		end
	end

	objectiveCard.AnchorPoint = Vector2.new(0, 0)
	objectiveCard.Position = UDim2.new(0, inset, 0, chatClearance)
	objectiveCard.Size = UDim2.fromOffset(if compact then 232 else 312, 0)

	-- Top-centre, below the transient notice card so the two never overlap.
	enemyCard.AnchorPoint = Vector2.new(0.5, 0)
	enemyCard.Position = UDim2.new(0.5, 0, 0, 80)
	enemyCard.Size = UDim2.fromOffset(if compact then 240 else 300, 0)

	if compact then
		healthCard.AnchorPoint = Vector2.new(0, 0)
		healthCard.Position = UDim2.new(0, inset, 0, chatClearance + 118)
		healthCard.Size = UDim2.fromOffset(214, 0)
	else
		healthCard.AnchorPoint = Vector2.new(0, 1)
		healthCard.Position = UDim2.new(0, inset, 1, -inset)
		healthCard.Size = UDim2.fromOffset(268, 0)
	end

	actionBar.Position = UDim2.new(0.5, 0, 1, if Responsive.touch then -108 else -inset)

	for _, slot in slots do
		local width = if compact then 62 else (if slot.spec.ultimate then 74 else 68)
		slot.button.Size = UDim2.fromOffset(width, if compact then 58 else 68)
		slot.keycapLabel.Text = if Responsive.inputMode == "Touch" then slot.spec.touchKey elseif Responsive.inputMode == "Gamepad" then slot.spec.gamepadKey else slot.spec.key
	end
end

local function buildNotice(parent: Frame)
	noticeCard = UIKit.panel({ Parent = parent, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.fromOffset(310, 42), Visible = false, Name = "Notice", ZIndex = 12 })
	UIKit.bracket(noticeCard, Vector2.new(0, 0.5), Theme.Color.Teal, 12)
	noticeLabel = UIKit.text({ Parent = noticeCard, Size = UDim2.fromScale(1, 1), Font = Theme.Font.Label, Text = "", TextColor3 = Theme.Color.Text, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 13 })
	registerText(noticeLabel, "Label")
end

-- A short "Central Plaza — 11:47 AM" style title card: a cinematic location
-- announcement distinct from the small Notice toast, shown once per scene
-- transition (see ChapterOneDirector.lua's Net.Feedback.LocationTitle).
local locationTitleFrame: Frame
local locationTitleLabel: TextLabel
local locationTitleToken = 0

local function buildLocationTitle(parent: Frame)
	locationTitleFrame = UIKit.container({
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.new(0, 520, 0, 44),
		Visible = false,
		Name = "LocationTitle",
		ZIndex = 11,
	})
	locationTitleLabel = UIKit.text({
		Parent = locationTitleFrame,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Font.Display,
		Text = "",
		TextColor3 = Theme.Color.Text,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 11,
	})
	registerText(locationTitleLabel, "H1")
end

function HUD.showLocationTitle(text: string)
	if not locationTitleFrame or not locationTitleLabel then
		return
	end
	locationTitleToken += 1
	local token = locationTitleToken
	locationTitleLabel.Text = text
	locationTitleLabel.TextTransparency = 1
	locationTitleFrame.Visible = true
	UIKit.fade(locationTitleLabel, { TextTransparency = 0 }, 0.5)
	task.delay(3.4, function()
		if token ~= locationTitleToken or not locationTitleFrame.Parent then
			return
		end
		UIKit.fade(locationTitleLabel, { TextTransparency = 1 }, 0.6)
		task.delay(0.65, function()
			if token == locationTitleToken then
				locationTitleFrame.Visible = false
			end
		end)
	end)
end

function HUD.build(parent: Frame)
	root = UIKit.container({ Parent = parent, Name = "HUD" })
	buildObjectiveCard(root)
	buildEnemyCard(root)
	buildHealthCard(root)
	buildActionBar(root)
	buildNotice(root)
	buildLocationTitle(root)
	buildSettingsButton(root)
	HUD.setMode("Human")
	applyLayout()
	Responsive.Changed:Connect(applyLayout)
	HUD.setAegisStatus(false, false)
end

return HUD
