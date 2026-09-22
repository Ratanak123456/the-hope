--!nonstrict
-- World presence for onboarding: Aegis Zero's field projection at the launch
-- platform, the platform marker, and per-player training dummies.
--
-- TODO(scene-fork): this whole pre-descent "meet the guide near city spawn"
-- flow belongs to the OLD tutorial-before-the-chamber structure. Chapter One,
-- Scene 7 ("Learning to Stand") moves this teaching moment to AFTER the
-- awakening, inside the chamber, taught by Aegis Zero directly once the
-- pilot has bonded with it - not a hologram wandering near the city spawn
-- before the player has even met it. Keep this working and correctly named
-- for now; replace/relocate it when Scene 7 is implemented for real.
--
-- Everything here is procedural geometry built the same way the rest of
-- World/* is - no models, no Toolbox assets, no asset IDs. The guide appears
-- as a translucent field projection (ForceField-material "hologram" body
-- with Neon accents) rather than a human character, standing in for Aegis
-- Zero's presence, and it lets the guide be a simple Motor6D rig with zero
-- dependency on avatar or animation assets.
--
-- The training dummy reuses WardenRig.build() outright: same silhouette
-- the player will actually fight, same health-bar billboard, same flashHit,
-- and it becomes a valid target for every real ability for free because
-- CombatService.damageArea() targets anything tagged CombatService.WardenTag.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)

local Kit = require(script.Parent.World.Kit)
local CombatService = require(script.Parent.CombatService)
local WardenRig = require(script.Parent.WardenRig)

local TutorialArea = {}

local ACCENT = Palette.Energy.Cyan
local BODY_COLOR = Color3.fromRGB(150, 226, 224)
local HOLOGRAM = Enum.Material.ForceField

local guideModel: Model? = nil
local guideJoints: { [string]: Motor6D } = {}
local guidePosition = Vector3.zero
local guideLookTarget = Vector3.new(0, 0, -1)
local gesturePhase: string? = nil
local gestureStarted = 0
local headYaw, headPitch = 0, 0

local markerPart: Part? = nil
local markerActive = false

local function hologramPart(parent: Instance, root: BasePart, name: string, size: Vector3, offset: CFrame, articulated: boolean?): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = BODY_COLOR
	part.Material = HOLOGRAM
	part.Transparency = 0.4
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = root.CFrame * offset
	part.Parent = parent

	if articulated then
		local motor = Instance.new("Motor6D")
		motor.Name = name .. "Joint"
		motor.Part0 = root
		motor.Part1 = part
		motor.C0 = offset
		motor.Parent = root
	else
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	return part
end

local function accentPart(parent: Instance, root: BasePart, name: string, size: Vector3, offset: CFrame): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = ACCENT
	part.Material = Enum.Material.Neon
	part.Transparency = 0.1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.CFrame = root.CFrame * offset
	part.Parent = parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

--[[
	Builds Aegis Zero's field projection near the city spawn. `standAt` and
	`lookAt` are both world positions so callers never have to reason about
	rig-local offsets.
]]
function TutorialArea.buildGuide(parent: Instance, standAt: Vector3, lookAt: Vector3): (Model, ProximityPrompt)
	local model = Instance.new("Model")
	model.Name = "GuideAegis"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.lookAt(standAt + Vector3.new(0, 3, 0), Vector3.new(lookAt.X, standAt.Y + 3, lookAt.Z))
	root.Transparency = 1
	root.Anchored = true -- a static field projection: no physics, no falling, never pushes anyone
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Parent = model

	local body = Instance.new("Folder")
	body.Name = "Projection"
	body.Parent = model

	hologramPart(body, root, "Torso", Vector3.new(2.0, 2.4, 1.1), CFrame.new(0, 1.4, 0))
	hologramPart(body, root, "Hips", Vector3.new(1.8, 1.1, 1.1), CFrame.new(0, 0.1, 0))
	local head = hologramPart(body, root, "Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 3.1, 0), true)
	hologramPart(body, root, "RightArm", Vector3.new(0.7, 2.2, 0.7), CFrame.new(1.35, 1.3, 0), true)
	hologramPart(body, root, "LeftArm", Vector3.new(0.7, 2.2, 0.7), CFrame.new(-1.35, 1.3, 0), true)
	hologramPart(body, root, "RightLeg", Vector3.new(0.8, 2.3, 0.8), CFrame.new(0.55, -1.9, 0))
	hologramPart(body, root, "LeftLeg", Vector3.new(0.8, 2.3, 0.8), CFrame.new(-0.55, -1.9, 0))

	accentPart(body, root, "Visor", Vector3.new(1.1, 0.22, 0.3), CFrame.new(0, 3.15, -0.55))
	accentPart(body, root, "Core", Vector3.new(0.4, 0.4, 0.2), CFrame.new(0, 1.6, -0.5))
	Kit.light(root, ACCENT, 14, 1.6)

	local nameTag = Instance.new("BillboardGui")
	nameTag.Name = "GuideLabel"
	nameTag.Adornee = head
	nameTag.AlwaysOnTop = true
	nameTag.MaxDistance = 60
	nameTag.LightInfluence = 0
	nameTag.Size = UDim2.fromOffset(160, 34)
	nameTag.StudsOffset = Vector3.new(0, 1.4, 0)
	nameTag.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = "AEGIS ZERO"
	nameLabel.TextColor3 = ACCENT
	nameLabel.TextSize = 16
	nameLabel.Parent = nameTag

	local roleLabel = Instance.new("TextLabel")
	roleLabel.BackgroundTransparency = 1
	roleLabel.Position = UDim2.new(0, 0, 0.6, 0)
	roleLabel.Size = UDim2.new(1, 0, 0.4, 0)
	roleLabel.Font = Enum.Font.Gotham
	roleLabel.Text = "GUARDIAN AI — FIELD GUIDE"
	roleLabel.TextColor3 = Color3.fromRGB(210, 235, 234)
	roleLabel.TextSize = 11
	roleLabel.Parent = nameTag

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Hold to talk"
	prompt.ObjectText = "AEGIS ZERO"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = Config.Tutorial.GuideInteractRange
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.UIOffset = Vector2.new(0, -36)
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = root

	model.PrimaryPart = root
	model.Parent = parent

	guideModel = model
	guidePosition = standAt
	guideLookTarget = lookAt
	guideJoints = {}
	for _, item in root:GetChildren() do
		if item:IsA("Motor6D") then
			guideJoints[item.Name] = item
		end
	end

	return model, prompt
end

-- "Wave" plays once on first meeting; "Point" plays while sending the player
-- toward the platform marker. Either clears itself back to idle afterward.
function TutorialArea.gesture(kind: string?)
	gesturePhase = kind
	gestureStarted = os.clock()
end

RunService.Heartbeat:Connect(function()
	if not guideModel or not guideModel.Parent then
		return
	end
	local now = os.clock()
	local sway = math.sin(now * 1.35) * 0.05

	-- Limited head tracking: lerp toward the nearest player within range, and
	-- ease back to a forward rest pose when nobody is close. Explicitly
	-- clamped so it never reads as the guide snapping or staring unnaturally.
	local nearest: BasePart? = nil
	local nearestDistance = 26
	for _, player in game:GetService("Players"):GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local distance = (root.Position - guidePosition).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearest = root
			end
		end
	end

	local targetYaw, targetPitch = 0, 0
	if nearest then
		local flat = nearest.Position - guidePosition
		local forward = (guideLookTarget - guidePosition)
		forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.new(0, 0, -1)
		local toPlayer = Vector3.new(flat.X, 0, flat.Z)
		if toPlayer.Magnitude > 0.5 then
			toPlayer = toPlayer.Unit
			local signedAngle = math.atan2(forward.X * toPlayer.Z - forward.Z * toPlayer.X, forward.X * toPlayer.X + forward.Z * toPlayer.Z)
			targetYaw = math.clamp(signedAngle, math.rad(-45), math.rad(45))
		end
		local heightDelta = (nearest.Position.Y - (guidePosition.Y + 3.1))
		targetPitch = math.clamp(math.atan2(heightDelta, nearestDistance + 0.01), math.rad(-16), math.rad(16))
	end
	headYaw += (targetYaw - headYaw) * math.min(1, 0.08)
	headPitch += (targetPitch - headPitch) * math.min(1, 0.08)

	local neck = guideJoints["HeadJoint"]
	if neck then
		neck.Transform = CFrame.Angles(headPitch, headYaw, 0)
	end

	local rightArm = guideJoints["RightArmJoint"]
	local leftArm = guideJoints["LeftArmJoint"]
	local gestureT = if gesturePhase then math.clamp((now - gestureStarted) / 1.1, 0, 1) else 0
	if gesturePhase == "Wave" then
		local wave = math.sin(gestureT * math.pi * 5) * (1 - gestureT) * 0.5
		if rightArm then rightArm.Transform = CFrame.Angles(math.rad(-140) * gestureT, 0, wave) end
		if leftArm then leftArm.Transform = CFrame.Angles(sway * 3, 0, 0) end
	elseif gesturePhase == "Point" then
		local reach = math.sin(math.min(gestureT, 0.4) / 0.4 * math.pi * 0.5)
		if rightArm then rightArm.Transform = CFrame.Angles(math.rad(-80) * reach, math.rad(-20) * reach, 0) end
		if leftArm then leftArm.Transform = CFrame.Angles(sway * 3, 0, 0) end
	else
		if rightArm then rightArm.Transform = CFrame.Angles(sway * 3, 0, 0) end
		if leftArm then leftArm.Transform = CFrame.Angles(-sway * 3, 0, 0) end
	end
	if gesturePhase and gestureT >= 1 then
		gesturePhase = nil
	end

	if markerPart and markerActive then
		local base = markerPart:GetAttribute("BasePosition") :: Vector3?
		if base then
			markerPart.CFrame = CFrame.new(base + Vector3.new(0, math.sin(now * 2) * 0.15, 0)) * CFrame.Angles(0, now * 1.4, 0) * CFrame.Angles(0, 0, math.rad(90))
		end
	end
end)

function TutorialArea.buildMarker(parent: Instance, position: Vector3): Part
	-- A thin flat disc: X is the cylinder's axis, so a small X with equal Y/Z
	-- lays it flat once rotated onto world-Y by Kit.cylinder's "y" convention.
	local part = Kit.cylinder({
		name = "TutorialMarker",
		size = Vector3.new(0.35, 2.4, 2.4),
		position = position + Vector3.new(0, 4.5, 0),
		color = ACCENT,
		material = Enum.Material.Neon,
		transparency = 1,
		decor = true,
		parent = parent,
	}, "y")
	part:SetAttribute("BasePosition", part.Position)
	markerPart = part
	markerActive = false
	return part
end

function TutorialArea.setMarkerActive(active: boolean)
	markerActive = active
	if markerPart then
		markerPart.Transparency = if active then 0.35 else 1
	end
end

function TutorialArea.markerPart(): Part?
	return markerPart
end

--------------------------------------------------------------------------------
-- Training dummy: the exact rig the player will fight, held still and tagged
-- so the real CombatService already treats it as a valid, damageable target.
--------------------------------------------------------------------------------

function TutorialArea.spawnDummy(parent: Instance, position: Vector3): Model
	local model = WardenRig.build(parent, position, Config.Tutorial.DummyHealth, Config.Tutorial.DummyWalkSpeed)
	model.Name = "TrainingDummy"
	model:SetAttribute("TrainingDummy", true)
	CollectionService:AddTag(model, CombatService.WardenTag)

	local head = model:FindFirstChild("Shell") and model.Shell:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local tag = Instance.new("BillboardGui")
		tag.Name = "TrainingLabel"
		tag.Adornee = head
		tag.AlwaysOnTop = false
		tag.MaxDistance = 100
		tag.LightInfluence = 0
		tag.Size = UDim2.fromOffset(140, 18)
		tag.StudsOffset = Vector3.new(0, 5.2, 0)
		tag.Parent = head

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamMedium
		label.Text = "TRAINING TARGET"
		label.TextColor3 = ACCENT
		label.TextSize = 13
		label.Parent = tag
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.AutoRotate = false
	end

	return model
end

function TutorialArea.healDummy(model: Model?)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
	end
end

function TutorialArea.removeDummy(model: Model?)
	if model and model.Parent then
		CollectionService:RemoveTag(model, CombatService.WardenTag)
		WardenRig.remove(model)
		model:Destroy()
	end
end

return TutorialArea
