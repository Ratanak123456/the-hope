--!strict
--[[
	HUMAN EXPEDITION INSTRUMENTATION.

	This module owns the expedition's own screens and nothing else. It does not
	sequence shots, it does not build world geometry, and it never touches the
	fullscreen cinematic overlay - the bore telemetry is DIEGETIC, a physical
	panel on a physical console that the camera has to be pointed at. A
	fullscreen HUD would also quietly destroy the thing this whole sequence is
	about: the audience is meant to be standing on the ice with the expedition,
	reading what they read, not being handed the answer by the game.

	VISUAL LANGUAGE - deliberately, absolutely unlike anything ancient:

	    HUMAN (here)     rectangles, English labels, monospaced numbers, thin
	                     rules, a small trace graph; near-black background,
	                     off-white text, muted cyan data, amber for a caution,
	                     red reserved for one genuine failure.
	    ANCIENT          glyph strokes, no words, radial or banded, bronze
	                     when dead and amber when live (see GlyphLanguage).
	    THE PRISONER     violet, and violet appears nowhere else.

	Those three are never mixed, in this module or anywhere else in the
	opening. It is how the audience knows, at a glance, whose technology they
	are looking at.

	CALM UNTIL IT IS NOT. Everything below is built so that the normal state is
	boring: aligned rows, steady values, one quiet trace. The alarm state is
	then one or two strong regions appearing on an otherwise unchanged panel,
	never a screen full of flashing text - a calm instrument developing a
	single red band is far more alarming than a panel that was always shouting.

	PERFORMANCE. Every element is created once, in create(), and only ever has
	its Text/Size/Color written afterwards, and only when the value actually
	changed. Nothing here allocates per frame.
]]

local Kit = require(script.Parent.Kit)

local Instrumentation = {}

export type DrillTelemetry = {
	depth: number, -- metres of hole made
	hosePayout: number, -- metres of hose off the reel; always a little more than depth
	waterTemperature: number, -- degrees C at the nozzle
	linePressure: number, -- MPa
	flowRate: number, -- litres per minute
	signalStrength: number, -- multiple of the baseline return, 1.0 = nominal
	returnDensity: number, -- 1 normal, 0 nothing coming back
	state: string, -- "ACTIVE", "HOLD", "FAULT" ...
	sourceEstimate: number?, -- metres; nil leaves the footer as it was
	alert: string?, -- one caution line, or nil for none
}

export type DrillDisplay = {
	gui: SurfaceGui,
	setTelemetry: (DrillTelemetry) -> (),
	-- The second argument is the severity: "caution" (amber, the default) or
	-- "critical" (red). Red is for a containment failure and for nothing else.
	setAlert: (string?, string?) -> (),
	-- Writes one named row directly, for the readings that are not numbers -
	-- "SOURCE DEPTH / LOCKED", "RETURN DENSITY / LOST".
	setRow: (string, string, string?) -> (),
	setFooter: (string, string, string?) -> (),
	-- Feeds the trace graph. 0..1, where 1 fills the band.
	pushSignal: (number) -> (),
	destroy: () -> (),
}

export type RowSpec = { key: string, label: string }

export type DisplayConfig = {
	title: string,
	face: Enum.NormalId?,
	canvas: Vector2?,
	rows: { RowSpec }?,
	graph: boolean?,
	footerLabel: string?,
	footerValue: string?,
}

local INK = {
	background = Color3.fromRGB(13, 16, 19),
	panel = Color3.fromRGB(20, 25, 29),
	rule = Color3.fromRGB(48, 58, 65),
	label = Color3.fromRGB(139, 150, 156),
	text = Color3.fromRGB(216, 221, 218),
	data = Color3.fromRGB(122, 190, 202),
	amber = Color3.fromRGB(216, 154, 66),
	red = Color3.fromRGB(201, 72, 55),
	trace = Color3.fromRGB(96, 158, 172),
}
Instrumentation.Ink = INK

local GRAPH_SAMPLES = 44

local DEFAULT_ROWS: { RowSpec } = {
	{ key = "depth", label = "DEPTH" },
	{ key = "payout", label = "HOSE PAYOUT" },
	{ key = "temperature", label = "WATER TEMP" },
	{ key = "pressure", label = "LINE PRESSURE" },
	{ key = "flow", label = "FLOW" },
	{ key = "density", label = "RETURN DENSITY" },
}

local function frame(parent: Instance, name: string, position: UDim2, size: UDim2, color: Color3?, transparency: number?): Frame
	local element = Instance.new("Frame")
	element.Name = name
	element.Position = position
	element.Size = size
	element.BackgroundColor3 = color or INK.panel
	element.BackgroundTransparency = transparency or 0
	element.BorderSizePixel = 0
	element.Parent = parent
	return element
end

local function text(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	content: string,
	textSize: number,
	color: Color3,
	alignment: Enum.TextXAlignment,
	font: Enum.Font
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = content
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = alignment
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Font = font
	label.Parent = parent
	return label
end

-- Thousands separated, fixed decimals: "1,984" and "642.8" rather than
-- "1984.0" and "642.80000000001". A field instrument that prints raw floats
-- reads as a debug overlay, which is the one thing this must not look like.
local function number(value: number, decimals: number): string
	local rounded = string.format(`%.{decimals}f`, value)
	local whole, fraction = rounded:match("^(%-?%d+)(.*)$")
	if not whole then
		return rounded
	end
	local sign = ""
	if whole:sub(1, 1) == "-" then
		sign = "-"
		whole = whole:sub(2)
	end
	local grouped = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return sign .. grouped .. (fraction or "")
end
Instrumentation.formatNumber = number

--[[
	Builds a panel on `host`. `config.rows` names the rows it carries; the
	returned display writes them by key. Two ready-made arrangements are below
	(boreConsole / fieldMonitor); both go through this, so both look like the
	same manufacturer built them.
]]
function Instrumentation.create(host: BasePart, config: DisplayConfig): DrillDisplay
	local canvas = config.canvas or Vector2.new(880, 640)
	local gui = Kit.surfaceGui(host, config.face, nil, canvas)
	gui.Name = "Instrumentation"

	local root = frame(gui, "Bezel", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), INK.background)

	local width = canvas.X
	local height = canvas.Y
	local margin = math.floor(width * 0.055)
	local inner = width - margin * 2

	-- Header: the instrument names itself and states what it is doing. The
	-- state word on the right is the only thing up here that ever changes.
	text(
		root,
		"Title",
		UDim2.fromOffset(margin, math.floor(height * 0.045)),
		UDim2.fromOffset(math.floor(inner * 0.62), math.floor(height * 0.075)),
		config.title,
		math.floor(height * 0.058),
		INK.text,
		Enum.TextXAlignment.Left,
		Enum.Font.GothamMedium
	)
	local stateLabel = text(
		root,
		"State",
		UDim2.fromOffset(margin + math.floor(inner * 0.62), math.floor(height * 0.045)),
		UDim2.fromOffset(math.floor(inner * 0.38), math.floor(height * 0.075)),
		"STANDBY",
		math.floor(height * 0.05),
		INK.data,
		Enum.TextXAlignment.Right,
		Enum.Font.Code
	)
	frame(root, "HeaderRule", UDim2.fromOffset(margin, math.floor(height * 0.14)), UDim2.fromOffset(inner, 2), INK.rule)

	-- Data rows.
	local rowSpecs = config.rows or DEFAULT_ROWS
	local rowTop = math.floor(height * 0.185)
	local rowHeight = math.floor(height * 0.072)
	local rowGap = math.floor(height * 0.018)
	local values: { [string]: TextLabel } = {}
	for index, spec in rowSpecs do
		local y = rowTop + (index - 1) * (rowHeight + rowGap)
		text(
			root,
			spec.key .. "Label",
			UDim2.fromOffset(margin, y),
			UDim2.fromOffset(math.floor(inner * 0.55), rowHeight),
			spec.label,
			math.floor(height * 0.042),
			INK.label,
			Enum.TextXAlignment.Left,
			Enum.Font.Gotham
		)
		values[spec.key] = text(
			root,
			spec.key .. "Value",
			UDim2.fromOffset(margin + math.floor(inner * 0.45), y),
			UDim2.fromOffset(math.floor(inner * 0.55), rowHeight),
			"—",
			math.floor(height * 0.05),
			INK.data,
			Enum.TextXAlignment.Right,
			Enum.Font.Code
		)
	end

	local afterRows = rowTop + #rowSpecs * (rowHeight + rowGap) + math.floor(height * 0.015)

	-- Signal trace. Forty-four thin bars, written in place: a real instrument
	-- draws a line, and a line is the one element here that can carry "this
	-- has been quietly doing the same thing for hours" and then "this just
	-- changed" without a single word.
	local bars: { Frame } = {}
	local graphBottom = afterRows
	if config.graph ~= false then
		text(
			root,
			"TraceLabel",
			UDim2.fromOffset(margin, afterRows),
			UDim2.fromOffset(inner, math.floor(height * 0.055)),
			"SIGNAL RETURN",
			math.floor(height * 0.04),
			INK.label,
			Enum.TextXAlignment.Left,
			Enum.Font.Gotham
		)
		local graphTop = afterRows + math.floor(height * 0.06)
		local graphHeight = math.floor(height * 0.16)
		frame(root, "TraceWell", UDim2.fromOffset(margin, graphTop), UDim2.fromOffset(inner, graphHeight), INK.panel)
		local barWidth = math.max(2, math.floor(inner / GRAPH_SAMPLES) - 2)
		for index = 1, GRAPH_SAMPLES do
			local x = margin + math.floor((index - 1) * inner / GRAPH_SAMPLES) + 1
			local bar = frame(
				root,
				`Trace{index}`,
				UDim2.fromOffset(x, graphTop + graphHeight - 3),
				UDim2.fromOffset(barWidth, 3),
				INK.trace
			)
			bars[index] = bar
			bar:SetAttribute("BaseY", graphTop + graphHeight)
			bar:SetAttribute("Span", graphHeight - 4)
			bar:SetAttribute("Width", barWidth)
			bar:SetAttribute("X", x)
		end
		graphBottom = graphTop + graphHeight + math.floor(height * 0.02)
	end

	-- Footer: the one figure the whole expedition is here for.
	frame(root, "FooterRule", UDim2.fromOffset(margin, graphBottom), UDim2.fromOffset(inner, 2), INK.rule)
	local footerY = graphBottom + math.floor(height * 0.022)
	local footerHeight = math.floor(height * 0.072)
	text(
		root,
		"FooterLabel",
		UDim2.fromOffset(margin, footerY),
		UDim2.fromOffset(math.floor(inner * 0.6), footerHeight),
		config.footerLabel or "SOURCE ESTIMATE",
		math.floor(height * 0.042),
		INK.label,
		Enum.TextXAlignment.Left,
		Enum.Font.Gotham
	)
	local footerValue = text(
		root,
		"FooterValue",
		UDim2.fromOffset(margin + math.floor(inner * 0.4), footerY),
		UDim2.fromOffset(math.floor(inner * 0.6), footerHeight),
		config.footerValue or "—",
		math.floor(height * 0.05),
		INK.data,
		Enum.TextXAlignment.Right,
		Enum.Font.Code
	)

	-- The alert band, built hidden. It sits OVER the lower rows rather than
	-- beside them, so when it appears it visibly interrupts the panel.
	local alertBand = frame(
		root,
		"AlertBand",
		UDim2.fromOffset(margin, footerY + footerHeight + math.floor(height * 0.012)),
		UDim2.fromOffset(inner, math.floor(height * 0.082)),
		INK.amber
	)
	alertBand.Visible = false
	local alertText = text(
		alertBand,
		"AlertText",
		UDim2.fromOffset(math.floor(width * 0.02), 0),
		UDim2.fromScale(0.96, 1),
		"",
		math.floor(height * 0.046),
		INK.background,
		Enum.TextXAlignment.Left,
		Enum.Font.GothamMedium
	)

	-- Cached last-written strings. Writing a TextLabel's Text is not free, and
	-- these are driven from a per-frame shot update.
	local written: { [string]: string } = {}
	local trace: { number } = table.create(GRAPH_SAMPLES, 0.12)
	local traceCursor = 0

	local function write(label: TextLabel, key: string, value: string, tone: Color3?)
		if written[key] ~= value then
			written[key] = value
			label.Text = value
		end
		if tone and label.TextColor3 ~= tone then
			label.TextColor3 = tone
		end
	end

	local function toneFor(name: string?): Color3
		if name == "critical" then
			return INK.red
		elseif name == "caution" then
			return INK.amber
		elseif name == "label" then
			return INK.label
		end
		return INK.data
	end

	local display: DrillDisplay
	display = {
		gui = gui,
		setRow = function(key: string, value: string, tone: string?)
			local label = values[key]
			if label then
				write(label, key, value, toneFor(tone))
			end
		end,
		setFooter = function(label: string, value: string, tone: string?)
			local footerLabelElement = root:FindFirstChild("FooterLabel") :: TextLabel?
			if footerLabelElement then
				write(footerLabelElement, "footerLabel", label, INK.label)
			end
			write(footerValue, "footerValue", value, toneFor(tone))
		end,
		setAlert = function(message: string?, level: string?)
			if not message or message == "" then
				alertBand.Visible = false
				return
			end
			alertBand.Visible = true
			alertBand.BackgroundColor3 = if level == "critical" then INK.red else INK.amber
			write(alertText, "alert", message, INK.background)
		end,
		pushSignal = function(value: number)
			traceCursor += 1
			trace[(traceCursor % GRAPH_SAMPLES) + 1] = math.clamp(value, 0, 1)
			for index, bar in bars do
				-- Read oldest-first so the trace scrolls left, the way a
				-- strip chart does, instead of flickering in place.
				local sample = trace[((traceCursor + index) % GRAPH_SAMPLES) + 1] or 0
				local span = (bar:GetAttribute("Span") :: number?) or 1
				local baseY = (bar:GetAttribute("BaseY") :: number?) or 0
				local barWidth = (bar:GetAttribute("Width") :: number?) or 2
				local x = (bar:GetAttribute("X") :: number?) or 0
				local barHeight = math.max(2, math.floor(sample * span))
				bar.Size = UDim2.fromOffset(barWidth, barHeight)
				bar.Position = UDim2.fromOffset(x, baseY - barHeight - 2)
			end
		end,
		setTelemetry = function(telemetry: DrillTelemetry)
			write(stateLabel, "state", telemetry.state, if telemetry.state == "FAULT" then INK.red else INK.data)
			display.setRow("depth", `{number(telemetry.depth, 1)} m`)
			display.setRow("payout", `{number(telemetry.hosePayout, 1)} m`)
			display.setRow("temperature", `{number(telemetry.waterTemperature, 0)} °C`)
			display.setRow(
				"pressure",
				`{number(telemetry.linePressure, 1)} MPa`,
				if telemetry.linePressure < 4 then "caution" else nil
			)
			display.setRow("flow", `{number(telemetry.flowRate, 0)} L/min`)
			if telemetry.returnDensity <= 0.02 then
				display.setRow("density", "LOST", "critical")
			elseif telemetry.returnDensity < 0.6 then
				display.setRow("density", "FALLING", "caution")
			else
				display.setRow("density", "NORMAL")
			end
			if telemetry.sourceEstimate then
				display.setFooter("SOURCE ESTIMATE", `{number(telemetry.sourceEstimate, 0)} m`)
			end
			display.pushSignal(math.clamp(0.08 + telemetry.signalStrength * 0.1, 0, 1))
			display.setAlert(telemetry.alert, if telemetry.alert then "caution" else nil)
		end,
		destroy = function()
			gui:Destroy()
		end,
	}
	return display
end

-- The operator console at the bore head. Full telemetry, the trace, and the
-- source estimate the whole expedition is chasing.
function Instrumentation.boreConsole(host: BasePart, face: Enum.NormalId?): DrillDisplay
	return Instrumentation.create(host, {
		title = "DEEP BORE 07",
		face = face,
		canvas = Vector2.new(880, 660),
		rows = DEFAULT_ROWS,
		graph = true,
		footerLabel = "SOURCE ESTIMATE",
		footerValue = "1,984 m",
	})
end

-- The portable unit the team carries down with them. Same manufacturer, fewer
-- rows, because it is a survey monitor rather than a rig console - and it is
-- what reports the spike once the floor starts to fail.
function Instrumentation.fieldMonitor(host: BasePart, face: Enum.NormalId?): DrillDisplay
	return Instrumentation.create(host, {
		title = "FIELD SURVEY 02",
		face = face,
		canvas = Vector2.new(760, 520),
		rows = {
			{ key = "signal", label = "SIGNAL RETURN" },
			{ key = "depth", label = "SOURCE DEPTH" },
			{ key = "bearing", label = "SOURCE POSITION" },
		},
		graph = true,
		footerLabel = "STATUS",
		footerValue = "TRACKING",
	})
end

return Instrumentation
