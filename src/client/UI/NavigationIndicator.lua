--!nonstrict
-- Compact objective direction marker. It exists only for the city signal and
-- never draws over nearby interaction UI.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Theme)
local UIKit = require(script.Parent.Parent.UIKit)

local NavigationIndicator = {}
local root: Frame
local diamond: Frame
local distanceLabel: TextLabel
local active = false
local connection: RBXScriptConnection? = nil
local explicitTarget: BasePart? = nil
local usingExplicit = false

-- Onboarding points this at the guide, the platform marker or a training
-- dummy in turn. Passing nil while `usingExplicit` is true hides the marker
-- outright rather than silently falling back to the ruin entrance below.
function NavigationIndicator.setTarget(part: BasePart?)
	usingExplicit = true
	explicitTarget = part
end

function NavigationIndicator.clearTarget()
	usingExplicit = false
	explicitTarget = nil
end

local function targetPart(): BasePart?
	if usingExplicit then
		return if explicitTarget and explicitTarget.Parent then explicitTarget else nil
	end
	local world = workspace:FindFirstChild("HopeGreybox")
	local target = world and world:FindFirstChild("RuinEntrance", true)
	return if target and target:IsA("BasePart") then target else nil
end

local function stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	root.Visible = false
end

local function start()
	if connection then return end
	connection = RunService.RenderStepped:Connect(function()
		if not active then
			stop()
			return
		end
		local camera = workspace.CurrentCamera
		local target = targetPart()
		local character = Players.LocalPlayer.Character
		local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
		if not camera or not target or not playerRoot or not playerRoot:IsA("BasePart") then
			root.Visible = false
			return
		end
		local distance = (playerRoot.Position - target.Position).Magnitude
		if distance < 24 then
			root.Visible = false
			return
		end
		local point, onScreen = camera:WorldToViewportPoint(target.Position + Vector3.new(0, 10, 0))
		local viewport = camera.ViewportSize
		local margin = 46
		local x = math.clamp(point.X, margin, viewport.X - margin)
		local y = math.clamp(point.Y, margin + 32, viewport.Y - margin - 100)
		if point.Z < 0 then
			x = viewport.X - x
			y = viewport.Y - y
		end
		root.Position = UDim2.fromOffset(x, y)
		root.Visible = true
		distanceLabel.Text = string.format("%d STUDS", math.floor(distance + 0.5))
		diamond.Rotation = if onScreen then 45 else math.deg(math.atan2(y - viewport.Y / 2, x - viewport.X / 2)) + 45
	end)
end

function NavigationIndicator.setActive(value: boolean)
	active = value
	if value then start() else stop() end
end

function NavigationIndicator.build(parent: Frame)
	root = UIKit.container({ Parent = parent, Name = "ObjectiveDirection", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(58, 54), Visible = false, ZIndex = 5 })
	diamond = UIKit.create("Frame", { Parent = root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 17), Size = UDim2.fromOffset(18, 18), Rotation = 45, BackgroundColor3 = Theme.Color.Amber, BorderSizePixel = 0, ZIndex = 6 })
	UIKit.stroke(Theme.Color.Text, 1, 0.25).Parent = diamond
	distanceLabel = UIKit.text({ Parent = root, Position = UDim2.fromOffset(0, 31), Size = UDim2.new(1, 0, 0, 18), Font = Theme.Font.Mono, Text = "", TextColor3 = Theme.Color.Text, TextSize = Theme.text("Caption"), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
end

return NavigationIndicator
