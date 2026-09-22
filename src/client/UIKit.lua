--!nonstrict
-- Small builder layer for the interface. Everything the UI draws goes through
-- here so spacing, corners, strokes and button behaviour stay consistent.

local TweenService = game:GetService("TweenService")

local Theme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Theme)

local UIKit = {}

local HOVER_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function UIKit.create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UIKit.corner(radius: number?): UICorner
	return UIKit.create("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Metric.Radius) })
end

function UIKit.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UIKit.create("UIStroke", {
		Color = color or Theme.Color.Line,
		Thickness = thickness or Theme.Metric.Stroke,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.padding(top: number, right: number?, bottom: number?, left: number?): UIPadding
	local r = right or top
	local b = bottom or top
	local l = left or r
	return UIKit.create("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, b),
		PaddingLeft = UDim.new(0, l),
	})
end

function UIKit.list(direction: Enum.FillDirection, padding: number, align: Enum.HorizontalAlignment?): UIListLayout
	return UIKit.create("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, padding),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})
end

function UIKit.container(props: { [string]: any }?): Frame
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}
	if props then
		for key, value in props do
			merged[key] = value
		end
	end
	return UIKit.create("Frame", merged)
end

-- A surface panel: the base card used by every screen.
function UIKit.panel(props: { [string]: any }?): Frame
	local merged: { [string]: any } = {
		BackgroundColor3 = Theme.Color.Surface,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
	}
	if props then
		for key, value in props do
			merged[key] = value
		end
	end
	local frame = UIKit.create("Frame", merged)
	UIKit.corner(Theme.Metric.RadiusLarge).Parent = frame
	UIKit.stroke(Theme.Color.LineSoft, 1, 0.2).Parent = frame
	return frame
end

function UIKit.text(props: { [string]: any }?): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.Font.Body,
		TextColor3 = Theme.Color.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = false,
	}
	if props then
		for key, value in props do
			merged[key] = value
		end
	end
	return UIKit.create("TextLabel", merged)
end

-- Thin L-shaped corner detail. Restrained geometric accent used on key panels.
function UIKit.bracket(parent: GuiObject, anchor: Vector2, color: Color3?, length: number?)
	local size = length or 14
	local tint = color or Theme.Color.TealDeep
	local xSign = if anchor.X < 0.5 then 1 else -1
	local ySign = if anchor.Y < 0.5 then 1 else -1

	UIKit.create("Frame", {
		Parent = parent,
		AnchorPoint = anchor,
		Position = UDim2.fromScale(anchor.X, anchor.Y),
		Size = UDim2.fromOffset(size, 2),
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	UIKit.create("Frame", {
		Parent = parent,
		AnchorPoint = anchor,
		Position = UDim2.fromScale(anchor.X, anchor.Y),
		Size = UDim2.fromOffset(2, size),
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	-- keep the unused signs referenced for clarity of intent
	return xSign, ySign
end

export type Button = {
	instance: TextButton,
	setEnabled: (enabled: boolean) -> (),
	setText: (text: string) -> (),
	onActivated: (callback: () -> ()) -> RBXScriptConnection,
}

local VARIANTS = {
	primary = {
		background = Theme.Color.TealDeep,
		hover = Color3.fromRGB(30, 122, 130),
		text = Theme.Color.Text,
		stroke = Theme.Color.Teal,
	},
	-- The welcome screen's primary action: a bright amber fill with dark
	-- text, per the redesign's "clearest interactive element on screen."
	accent = {
		background = Theme.Color.Amber,
		hover = Color3.fromRGB(255, 191, 105),
		text = Theme.Color.Void,
		stroke = Theme.Color.Amber,
	},
	ghost = {
		background = Theme.Color.SurfaceRaised,
		hover = Theme.Color.SurfaceHover,
		text = Theme.Color.Text,
		stroke = Theme.Color.Line,
	},
	danger = {
		background = Theme.Color.DangerDeep,
		hover = Color3.fromRGB(128, 44, 56),
		text = Theme.Color.Text,
		stroke = Theme.Color.Danger,
	},
}

function UIKit.button(props: { [string]: any }): Button
	local variant = VARIANTS[props.variant or "ghost"] or VARIANTS.ghost
	local compact = props.compact == true

	local button = UIKit.create("TextButton", {
		Parent = props.Parent,
		AutoButtonColor = false,
		BackgroundColor3 = variant.background,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Font = Theme.Font.Heading,
		LayoutOrder = props.LayoutOrder or 0,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Size = props.Size or UDim2.new(1, 0, 0, if compact then 38 else 46),
		Text = props.Text or "",
		TextColor3 = variant.text,
		TextSize = Theme.text("Body", compact),
		Name = props.Name or "Button",
		ZIndex = props.ZIndex or 1,
	})

	UIKit.corner(Theme.Metric.Radius).Parent = button
	local stroke = UIKit.stroke(variant.stroke, 1, 0.45)
	stroke.Parent = button

	local enabled = true
	local function paint(color: Color3, strokeTransparency: number)
		TweenService:Create(button, HOVER_TWEEN, { BackgroundColor3 = color }):Play()
		TweenService:Create(stroke, HOVER_TWEEN, { Transparency = strokeTransparency }):Play()
	end

	button.MouseEnter:Connect(function()
		if enabled then
			paint(variant.hover, 0.1)
		end
	end)
	button.MouseLeave:Connect(function()
		if enabled then
			paint(variant.background, 0.45)
		end
	end)
	button.SelectionGained:Connect(function()
		if enabled then paint(variant.hover, 0) end
	end)
	button.SelectionLost:Connect(function()
		if enabled then paint(variant.background, 0.45) end
	end)
	button.InputBegan:Connect(function(input)
		if enabled and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA) then
			button.BackgroundTransparency = 0.02
		end
	end)
	button.InputEnded:Connect(function(input)
		if enabled and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA) then
			button.BackgroundTransparency = 0.12
		end
	end)

	local api: Button
	api = {
		instance = button,
		setEnabled = function(value: boolean)
			enabled = value
			button.Active = value
			button.AutoButtonColor = false
			button.BackgroundTransparency = if value then 0.12 else 0.55
			button.TextColor3 = if value then variant.text else Theme.Color.TextFaint
			stroke.Transparency = if value then 0.45 else 0.8
		end,
		setText = function(text: string)
			button.Text = text
		end,
		onActivated = function(callback: () -> ())
			return button.Activated:Connect(function()
				if enabled then
					callback()
				end
			end)
		end,
	}
	return api
end

export type Bar = {
	instance: Frame,
	fill: Frame,
	setRatio: (ratio: number, animate: boolean?) -> (),
	setColor: (color: Color3) -> (),
}

function UIKit.bar(props: { [string]: any }): Bar
	local track = UIKit.create("Frame", {
		Parent = props.Parent,
		BackgroundColor3 = Theme.Color.Void,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		Size = props.Size or UDim2.new(1, 0, 0, 10),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Name = props.Name or "Bar",
	})
	UIKit.corner(3).Parent = track
	UIKit.stroke(Theme.Color.LineSoft, 1, 0.4).Parent = track

	local fill = UIKit.create("Frame", {
		Parent = track,
		BackgroundColor3 = props.Color or Theme.Color.Teal,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Name = "Fill",
	})
	UIKit.corner(3).Parent = fill

	local tween: Tween? = nil
	return {
		instance = track,
		fill = fill,
		setRatio = function(ratio: number, animate: boolean?)
			local clamped = math.clamp(ratio, 0, 1)
			if tween then
				tween:Cancel()
				tween = nil
			end
			if animate then
				tween = TweenService:Create(fill, TweenInfo.new(0.22, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(clamped, 1) })
				;(tween :: Tween):Play()
			else
				fill.Size = UDim2.fromScale(clamped, 1)
			end
		end,
		setColor = function(color: Color3)
			fill.BackgroundColor3 = color
		end,
	}
end

-- Key label used on the action bar. Shows a keycap on desktop and a dot on touch.
function UIKit.keycap(parent: GuiObject, text: string, compact: boolean): Frame
	local cap = UIKit.create("Frame", {
		Parent = parent,
		BackgroundColor3 = Theme.Color.Void,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(if compact then 30 else 34, if compact then 20 else 22),
		Name = "Keycap",
	})
	UIKit.corner(4).Parent = cap
	UIKit.stroke(Theme.Color.Line, 1, 0.35).Parent = cap
	UIKit.text({
		Parent = cap,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Font.Mono,
		Text = text,
		TextColor3 = Theme.Color.TextMuted,
		TextSize = Theme.text("Caption", compact),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Name = "Label",
	})
	return cap
end

function UIKit.divider(parent: GuiObject, layoutOrder: number?): Frame
	return UIKit.create("Frame", {
		Parent = parent,
		BackgroundColor3 = Theme.Color.LineSoft,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder or 0,
		Size = UDim2.new(1, 0, 0, 1),
		Name = "Divider",
	})
end

function UIKit.fade(instance: GuiObject, properties: { [string]: any }, duration: number): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	tween:Play()
	return tween
end

return UIKit
