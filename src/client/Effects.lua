--!nonstrict
-- Local feedback: hit confirmation, damage response, camera impulse and
-- placeholder world VFX. Everything here is client-side and self-cleaning.
--
-- Two rules this module exists to enforce:
--   1. Field of view always returns to ONE stored base value, so repeated
--      impulses can never drift the camera.
--   2. Nothing another player does is allowed to move this player's camera.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Palette = require(Shared.Palette)
local Theme = require(Shared.Theme)

local Settings = require(script.Parent.Settings)
local UIKit = require(script.Parent.UIKit)

local Effects = {}

local overlay: Frame
local hitMarker: Frame
local flash: Frame
local baseFieldOfView = 70
local fovTween: Tween? = nil
local shakeAmount = 0
local shakeConnection: RBXScriptConnection? = nil
local boundHumanoid: Humanoid? = nil
local healthConnection: RBXScriptConnection? = nil
local lastHealth = 0
local temporaryParts: { Instance } = {}

local function camera(): Camera?
	return workspace.CurrentCamera
end

local function trackPart(instance: Instance, lifetime: number)
	table.insert(temporaryParts, instance)
	Debris:AddItem(instance, lifetime)
	task.delay(lifetime, function()
		local index = table.find(temporaryParts, instance)
		if index then
			table.remove(temporaryParts, index)
		end
	end)
end

function Effects.init(parent: Frame)
	overlay = UIKit.container({ Parent = parent, Name = "Effects", ZIndex = 30 })

	flash = UIKit.create("Frame", {
		Parent = overlay,
		BackgroundColor3 = Theme.Color.Danger,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 30,
		Name = "DamageFlash",
	})

	hitMarker = UIKit.container({
		Parent = overlay,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(44, 44),
		Visible = false,
		ZIndex = 31,
		Name = "HitMarker",
	})
	for index = 0, 3 do
		local angle = index * 90 + 45
		UIKit.create("Frame", {
			Parent = hitMarker,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(2, 14),
			Rotation = angle,
			BackgroundColor3 = Theme.Color.Teal,
			BorderSizePixel = 0,
			ZIndex = 31,
		})
	end

	local cam = camera()
	if cam then
		baseFieldOfView = cam.FieldOfView
	end

	Effects.startFootsteps()
end

function Effects.setBaseFieldOfView(value: number)
	baseFieldOfView = value
end

-- One tween, one base value. Repeated calls restart rather than stack.
function Effects.fieldOfViewPulse(delta: number, duration: number?)
	if Settings.reducedMotion() then
		return
	end
	local cam = camera()
	if not cam then
		return
	end
	if fovTween then
		fovTween:Cancel()
		fovTween = nil
	end
	cam.FieldOfView = baseFieldOfView + delta
	fovTween = TweenService:Create(cam, TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = baseFieldOfView,
	})
	;(fovTween :: Tween):Play()
end

local function ensureShakeLoop()
	if shakeConnection then
		return
	end
	shakeConnection = RunService.RenderStepped:Connect(function(dt)
		local humanoid = boundHumanoid
		if not humanoid or humanoid.Parent == nil then
			shakeAmount = 0
		end
		if shakeAmount <= 0.01 then
			shakeAmount = 0
			if humanoid and humanoid.Parent then
				humanoid.CameraOffset = Vector3.zero
			end
			if shakeConnection then
				shakeConnection:Disconnect()
				shakeConnection = nil
			end
			return
		end
		shakeAmount = math.max(0, shakeAmount - dt * shakeAmount * 6 - dt * 0.15)
		if humanoid and humanoid.Parent then
			humanoid.CameraOffset = Vector3.new(
				(math.random() - 0.5) * shakeAmount,
				(math.random() - 0.5) * shakeAmount,
				0
			)
		end
	end)
end

function Effects.shake(magnitude: number)
	local scale = Settings.shakeScale()
	if scale <= 0 then
		return
	end
	if not boundHumanoid then
		return
	end
	shakeAmount = math.min(1.6, shakeAmount + magnitude * scale)
	ensureShakeLoop()
end

function Effects.hitConfirm(count: number, killed: number)
	if count <= 0 or not Settings.get("hitMarker") then
		return
	end
	hitMarker.Visible = true
	local tint = if killed > 0 then Theme.Color.Amber else Theme.Color.Teal
	for _, child in hitMarker:GetChildren() do
		if child:IsA("Frame") then
			child.BackgroundColor3 = tint
		end
	end
	if Settings.reducedMotion() then
		hitMarker.Size = UDim2.fromOffset(44, 44)
		task.delay(0.16, function()
			hitMarker.Visible = false
		end)
	else
		hitMarker.Size = UDim2.fromOffset(30, 30)
		UIKit.fade(hitMarker, { Size = UDim2.fromOffset(54, 54) }, 0.16)
		task.delay(0.18, function()
			hitMarker.Visible = false
		end)
	end
	Effects.shake(0.25 + math.min(count, 3) * 0.05)
end

function Effects.damageResponse(amount: number, maxHealth: number)
	local intensity = math.clamp(amount / math.max(maxHealth, 1), 0.05, 0.5)
	flash.BackgroundTransparency = 1 - intensity * (if Settings.reducedMotion() then 0.3 else 0.9)
	UIKit.fade(flash, { BackgroundTransparency = 1 }, 0.35)
	Effects.shake(0.3)
end

--------------------------------------------------------------------------------
-- Combat presentation
--------------------------------------------------------------------------------

local function neonPart(name: string, cframe: CFrame, size: Vector3, color: Color3, transparency: number, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Size = size
	part.CFrame = cframe
	if shape then
		part.Shape = shape
	end
	part.Parent = workspace
	return part
end

-- Pulses Aegis Zero's chest core. Reads as the armour powering the swing.
local function pulseCore(character: Model?)
	if not character then
		return
	end
	local plating = character:FindFirstChild("AegisPlating")
	local core = plating and plating:FindFirstChild("Core")
	if not core or not core:IsA("BasePart") then
		return
	end
	local light = core:FindFirstChildOfClass("PointLight")
	core.Transparency = 0
	if light then
		light.Brightness = 5
		TweenService:Create(light, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Brightness = 2.2 }):Play()
	end
	TweenService:Create(core, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Transparency = 0.05 }):Play()
	local visor = plating and plating:FindFirstChild("Visor")
	if visor and visor:IsA("BasePart") then
		visor.Transparency = 0
		TweenService:Create(visor, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Transparency = 0.1 }):Play()
	end
end

--[[
	Aegis Zero's strike. A blade of light sweeps through the arc over exactly the
	server's windup, then an impact shell blooms where the damage is actually
	tested. The sweep is world-space so everyone sees it; only the attacker's
	camera responds.
]]
function Effects.strikeVFX(payload)
	if typeof(payload) ~= "table" or not payload.origin then
		return
	end
	local origin: Vector3 = payload.origin
	local direction: Vector3 = payload.direction or Vector3.new(0, 0, -1)
	local reach = tonumber(payload.reach) or 9
	local radius = tonumber(payload.radius) or 12
	local windup = tonumber(payload.windup) or 0.18
	local isLocal = payload.byUserId == Players.LocalPlayer.UserId

	local facing = CFrame.lookAt(origin, origin + direction)
	local reduced = Settings.reducedMotion()

	-- Sweeping blade.
	local blade = neonPart(
		"HopeStrikeArc",
		facing * CFrame.Angles(0, math.rad(70), 0) * CFrame.new(0, 0, -reach * 0.6),
		Vector3.new(0.5, 3.2, reach * 1.1),
		Palette.Energy.Cyan,
		0.25
	)
	trackPart(blade, windup + 0.5)
	TweenService:Create(blade, TweenInfo.new(windup, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		CFrame = facing * CFrame.Angles(0, math.rad(-70), 0) * CFrame.new(0, 0, -reach * 0.6),
	}):Play()
	task.delay(windup, function()
		if blade.Parent then
			TweenService:Create(blade, TweenInfo.new(0.22), { Transparency = 1 }):Play()
		end
	end)

	-- Contact bloom at the point the server actually tests.
	task.delay(windup, function()
		local centre = origin + direction * reach
		local shell = neonPart("HopeStrikeImpact", CFrame.new(centre), Vector3.one * radius * 0.5, Palette.Energy.Cyan, 0.5, Enum.PartType.Ball)
		trackPart(shell, 0.6)
		local goal = if reduced
			then { Transparency = 1 }
			else { Size = Vector3.one * radius * 2, Transparency = 1 }
		TweenService:Create(shell, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal):Play()

		local ring = neonPart("HopeStrikeRing", CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.4, radius, radius), Palette.Energy.Cyan, 0.45)
		ring.Shape = Enum.PartType.Cylinder
		trackPart(ring, 0.6)
		TweenService:Create(ring, TweenInfo.new(0.32, Enum.EasingStyle.Quint), {
			Size = Vector3.new(0.4, radius * 2.4, radius * 2.4),
			Transparency = 1,
		}):Play()
	end)

	local subject = Players:GetPlayerByUserId(payload.byUserId)
	pulseCore(subject and subject.Character)

	if isLocal then
		-- Anticipation pulls in, follow-through pushes out.
		Effects.fieldOfViewPulse(-3, windup)
		task.delay(windup, function()
			Effects.fieldOfViewPulse(5, 0.3)
		end)
	end
end

--[[
	Warden attack warning.

	The ring is drawn at exactly the radius the server will test and fills over
	exactly the windup the server will wait, so it is a truthful promise rather
	than decoration.
]]
function Effects.constructTelegraph(payload)
	if typeof(payload) ~= "table" or not payload.position then
		return
	end
	local position: Vector3 = payload.position
	local radius = tonumber(payload.radius) or 7
	local duration = tonumber(payload.duration) or 0.5

	local base = CFrame.new(position - Vector3.new(0, 2.4, 0))
	local outline = neonPart("HopeTelegraph", base * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.25, radius * 2, radius * 2), Palette.Alien.Energy, 0.7)
	outline.Shape = Enum.PartType.Cylinder
	trackPart(outline, duration + 0.4)

	local fill = neonPart("HopeTelegraphFill", base * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.3, 0.5, 0.5), Palette.Alien.Energy, 0.45)
	fill.Shape = Enum.PartType.Cylinder
	trackPart(fill, duration + 0.4)

	-- Filling to the full radius exactly as the strike resolves.
	TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.3, radius * 2, radius * 2),
	}):Play()
	task.delay(duration, function()
		if outline.Parent then
			TweenService:Create(outline, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		end
		if fill.Parent then
			TweenService:Create(fill, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		end
	end)
end

function Effects.constructHit(payload)
	if typeof(payload) ~= "table" or not payload.position then
		return
	end
	local died = payload.died == true
	local colour = if died then Palette.Energy.Amber else Palette.Alien.Energy
	local burst = neonPart("SkyWardenHit", CFrame.new(payload.position), Vector3.one * (if died then 3 else 1.6), colour, 0.3, Enum.PartType.Ball)
	trackPart(burst, 0.6)
	TweenService:Create(burst, TweenInfo.new(if died then 0.45 else 0.25, Enum.EasingStyle.Quint), {
		Size = Vector3.one * (if died then 14 else 5),
		Transparency = 1,
	}):Play()
end

local function impactSparks(position: Vector3, heavy: boolean)
	local quality = Settings.vfxQuality()
	local count = if quality == "Low" then 3 else (if quality == "High" then (if heavy then 11 else 7) else (if heavy then 8 else 5))
	for index = 1, count do
		local angle = index / count * math.pi * 2
		local spark = neonPart("HopeImpactSpark", CFrame.new(position), Vector3.new(0.25, 0.25, if heavy then 3.2 else 1.8), if index % 2 == 0 then Palette.Energy.Amber else Color3.fromRGB(242, 246, 238), 0.08)
		trackPart(spark, 0.4)
		local direction = Vector3.new(math.cos(angle), 0.3 + (index % 3) * 0.2, math.sin(angle))
		TweenService:Create(spark, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.lookAt(position + direction * (if heavy then 8 else 4), position + direction * 9), Transparency = 1 }):Play()
	end
end

local function impactRing(position: Vector3, radius: number, color: Color3, duration: number)
	local ring = neonPart("HopeAbilityRing", CFrame.new(position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.35, 2, 2), color, 0.28, Enum.PartType.Cylinder)
	trackPart(ring, duration + 0.2)
	TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.35, radius * 2, radius * 2), Transparency = 1 }):Play()
end

function Effects.abilityVFX(payload)
	if typeof(payload) ~= "table" then return end
	local ability = tostring(payload.ability)
	local stage = tostring(payload.stage)
	local position = payload.position or payload.origin
	if typeof(position) ~= "Vector3" then return end
	local userId = tonumber(payload.byUserId)
	local isLocal = userId == Players.LocalPlayer.UserId
	local subject = userId and Players:GetPlayerByUserId(userId)
	local character = subject and subject.Character

	if ability == "Strike" then
		if stage == "Begin" then
			Effects.strikeVFX(payload)
		else
			impactSparks(position, tonumber(payload.step) == 3)
		end
	elseif ability == "GroundSlam" then
		if stage == "Begin" then
			pulseCore(character)
			impactRing(position, tonumber(payload.radius) or 24, Palette.Energy.Amber, tonumber(payload.windup) or 0.68)
		else
			impactRing(position, tonumber(payload.radius) or 24, Palette.Energy.Cyan, 0.42)
			impactSparks(position, true)
			if Settings.vfxQuality() ~= "Low" then
				local dustCount = if Settings.vfxQuality() == "High" then 8 else 5
				for index = 1, dustCount do
					local angle = index / dustCount * math.pi * 2
					local dust = neonPart("HopeSlamDust", CFrame.new(position + Vector3.new(math.cos(angle) * 3, -2, math.sin(angle) * 3)), Vector3.one * 2.2, Color3.fromRGB(112, 105, 94), 0.45, Enum.PartType.Ball)
					dust.Material = Enum.Material.SmoothPlastic
					trackPart(dust, 0.55)
					TweenService:Create(dust, TweenInfo.new(0.42, Enum.EasingStyle.Quad), { CFrame = dust.CFrame + Vector3.new(math.cos(angle) * 8, 3, math.sin(angle) * 8), Size = Vector3.one * 4, Transparency = 1 }):Play()
				end
			end
			if isLocal then
				Effects.shake(0.7)
				Effects.fieldOfViewPulse(4, 0.3)
			end
		end
	elseif ability == "ResonanceBolt" then
		if stage == "Begin" and typeof(payload.direction) == "Vector3" then
			pulseCore(character)
			local direction = payload.direction.Unit
			local speed = tonumber(payload.speed) or 150
			local range = tonumber(payload.range) or 150
			local windup = tonumber(payload.windup) or 0.28
			task.delay(windup, function()
				local bolt = neonPart(`HopeBolt_{userId or 0}`, CFrame.lookAt(position, position + direction), Vector3.new(0.8, 0.8, 4.5), Palette.Energy.Cyan, 0.05)
				trackPart(bolt, range / speed + 0.2)
				TweenService:Create(bolt, TweenInfo.new(range / speed, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(position + direction * range, position + direction * (range + 1)), Transparency = 0.35 }):Play()
			end)
		else
			local bolt = workspace:FindFirstChild(`HopeBolt_{userId or 0}`)
			if bolt then bolt:Destroy() end
			local burst = neonPart("HopeBoltImpact", CFrame.new(position), Vector3.one * 1.5, Palette.Energy.Cyan, 0.1, Enum.PartType.Ball)
			trackPart(burst, 0.45)
			TweenService:Create(burst, TweenInfo.new(0.28, Enum.EasingStyle.Quint), { Size = Vector3.one * ((tonumber(payload.radius) or 3.5) * 2), Transparency = 1 }):Play()
			impactSparks(position, false)
		end
	elseif ability == "ThrusterDash" and stage == "Begin" then
		local direction = if typeof(payload.direction) == "Vector3" then payload.direction.Unit else Vector3.new(0, 0, -1)
		for side = -1, 1, 2 do
			local exhaust = neonPart("HopeThruster", CFrame.lookAt(position - direction * 3 + Vector3.new(side * 2, 0, 0), position - direction * 8), Vector3.new(0.7, 0.7, 7), Palette.Energy.Cyan, 0.22)
			trackPart(exhaust, 0.5)
			TweenService:Create(exhaust, TweenInfo.new(0.3), { Size = Vector3.new(0.2, 0.2, 13), Transparency = 1 }):Play()
		end
		if isLocal then Effects.fieldOfViewPulse(5, 0.28) end
	elseif ability == "CoreBurst" then
		if stage == "Begin" then
			pulseCore(character)
			impactRing(position, tonumber(payload.radius) or 34, Palette.Energy.Amber, tonumber(payload.windup) or 1)
		else
			impactRing(position, tonumber(payload.radius) or 34, Palette.Energy.Cyan, 0.55)
			impactSparks(position, true)
			local burst = neonPart("HopeCoreBurst", CFrame.new(position), Vector3.one * 5, Palette.Energy.Amber, 0.5, Enum.PartType.Ball)
			trackPart(burst, 0.7)
			TweenService:Create(burst, TweenInfo.new(0.42, Enum.EasingStyle.Quint), { Size = Vector3.one * (tonumber(payload.radius) or 34) * 1.8, Transparency = 1 }):Play()
			if isLocal then
				Effects.shake(0.9)
				Effects.fieldOfViewPulse(7, 0.4)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Aegis Zero footfalls
--
-- Sampled on a timer rather than every frame, and only for characters that are
-- actually in Aegis Zero form and near the camera, so the cost stays bounded.
--------------------------------------------------------------------------------

local footstepAccumulator = 0
local lastFootPosition: { [Model]: Vector3 } = {}
local footstepConnection: RBXScriptConnection? = nil

local function spawnDust(at: Vector3)
	local puff = neonPart("HopeFootDust", CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.3, 3, 3), Color3.fromRGB(120, 118, 112), 0.55)
	puff.Shape = Enum.PartType.Cylinder
	puff.Material = Enum.Material.SmoothPlastic
	trackPart(puff, 0.7)
	TweenService:Create(puff, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.3, 11, 11),
		Transparency = 1,
	}):Play()
end

local function sampleFootsteps()
	local cam = camera()
	if not cam then
		return
	end
	local origin = cam.CFrame.Position

	for _, other in Players:GetPlayers() do
		local character = other.Character
		if not character or character:GetAttribute("AegisActive") ~= true then
			if character then
				lastFootPosition[character] = nil
			end
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			continue
		end
		if (root.Position - origin).Magnitude > 180 then
			continue
		end

		local previous = lastFootPosition[character]
		if previous and (root.Position - previous).Magnitude >= 7 then
			local drop = humanoid.HipHeight + root.Size.Y / 2
			spawnDust(root.Position - Vector3.new(0, drop, 0))
			lastFootPosition[character] = root.Position
		elseif not previous then
			lastFootPosition[character] = root.Position
		end
	end
end

function Effects.startFootsteps()
	if footstepConnection then
		footstepConnection:Disconnect()
	end
	footstepConnection = RunService.Heartbeat:Connect(function(dt)
		footstepAccumulator += dt
		if footstepAccumulator < 0.12 then
			return
		end
		footstepAccumulator = 0
		if not Settings.reducedMotion() and Settings.vfxQuality() ~= "Low" then
			sampleFootsteps()
		end
	end)
end

--------------------------------------------------------------------------------
-- Transformation presentation
--
-- Driven entirely by phase messages from the server. Everything world-space is
-- played for every viewer; only the transforming player's own camera reacts.
--------------------------------------------------------------------------------

local activeMotes: { [number]: ParticleEmitter } = {}

local function tween(instance: Instance, duration: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local created = TweenService:Create(instance, info, goal)
	created:Play()
	return created
end

local function ringPart(name: string, cframe: CFrame, diameter: number, thickness: number, color: Color3, transparency: number): Part
	local ring = Instance.new("Part")
	ring.Name = name
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = transparency
	ring.Size = Vector3.new(thickness, diameter, diameter)
	ring.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	return ring
end

local function footCFrame(character: Model): CFrame?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local drop = if humanoid then humanoid.HipHeight + root.Size.Y / 2 else 3
	return CFrame.new(root.Position - Vector3.new(0, drop, 0))
end

-- The activation glyph: two rings and six ticks, rotating open on the ground.
local function playGlyph(character: Model, duration: number)
	local base = footCFrame(character)
    if not base then
		return
	end
	local reduced = Settings.reducedMotion()
	local pieces: { BasePart } = {}

	local outer = ringPart("HopeGlyphOuter", base, 6, 0.3, Palette.Energy.Cyan, 0.35)
	local inner = ringPart("HopeGlyphInner", base, 3, 0.3, Palette.Energy.Cyan, 0.5)
	table.insert(pieces, outer)
	table.insert(pieces, inner)

	for index = 1, 6 do
		local angle = (index / 6) * math.pi * 2
		local tick = Instance.new("Part")
		tick.Name = "HopeGlyphTick"
		tick.Anchored = true
		tick.CanCollide = false
		tick.CanQuery = false
		tick.CanTouch = false
		tick.CastShadow = false
		tick.Material = Enum.Material.Neon
		tick.Color = Palette.Energy.Cyan
		tick.Transparency = 0.45
		tick.Size = Vector3.new(0.6, 0.25, 3)
		tick.CFrame = base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -5)
		tick.Parent = workspace
		table.insert(pieces, tick)
	end

	for _, piece in pieces do
		trackPart(piece, duration + 0.5)
	end

	-- Expand and fade. Tween-driven, so there is no per-frame work and no flash.
	tween(outer, duration * 0.45, { Size = Vector3.new(0.3, 24, 24) }, Enum.EasingStyle.Quint)
	tween(inner, duration * 0.6, { Size = Vector3.new(0.3, 15, 15) }, Enum.EasingStyle.Quint)
	for index = 3, #pieces do
		local piece = pieces[index]
		local goal: { [string]: any } = { Size = Vector3.new(0.9, 0.25, 7) }
		if not reduced then
			goal.CFrame = base * CFrame.Angles(0, ((index - 2) / 6) * math.pi * 2 + math.rad(70), 0) * CFrame.new(0, 0, -10)
		end
		tween(piece, duration * 0.7, goal, Enum.EasingStyle.Quint)
	end

	task.delay(duration * 0.75, function()
		for _, piece in pieces do
			if piece.Parent then
				tween(piece, duration * 0.3, { Transparency = 1 })
			end
		end
	end)
end

local function startMotes(character: Model, userId: number, duration: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not Palette.Quality.ParticlesEnabled or Settings.vfxQuality() == "Low" then
		return
	end
	local existing = activeMotes[userId]
	if existing then
		existing:Destroy()
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "HopeResonance"
	emitter.Color = ColorSequence.new(Palette.Energy.Cyan)
	emitter.LightEmission = 0.75
	emitter.Rate = 60
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(-16, -9) -- negative: motes converge inward
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0.25)
	emitter.Parent = root
	activeMotes[userId] = emitter

	task.delay(duration, function()
		if activeMotes[userId] == emitter then
			emitter.Enabled = false
			activeMotes[userId] = nil
			Debris:AddItem(emitter, 1)
		end
	end)
end

local function stopMotes(userId: number)
	local emitter = activeMotes[userId]
	if emitter then
		emitter.Enabled = false
		activeMotes[userId] = nil
		Debris:AddItem(emitter, 1)
	end
end

local function playCoreFlash(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local flare = Instance.new("Part")
	flare.Name = "HopeCoreFlare"
	flare.Shape = Enum.PartType.Ball
	flare.Anchored = true
	flare.CanCollide = false
	flare.CanQuery = false
	flare.CanTouch = false
	flare.CastShadow = false
	flare.Material = Enum.Material.Neon
	flare.Color = Palette.Energy.Amber
	flare.Transparency = 0.2
	flare.Size = Vector3.one * 1.5
	flare.CFrame = root.CFrame * CFrame.new(0, 0.4, -1.4)
	flare.Parent = workspace
	trackPart(flare, 0.8)
	tween(flare, 0.5, { Size = Vector3.one * 6, Transparency = 1 }, Enum.EasingStyle.Quint)
end

local function playShockwave(character: Model)
	local base = footCFrame(character)
	if not base then
		return
	end
	local wave = ringPart("HopeShockwave", base, 8, 0.5, Palette.Energy.Cyan, 0.3)
	trackPart(wave, 1)
	tween(wave, 0.55, { Size = Vector3.new(0.5, 46, 46), Transparency = 1 }, Enum.EasingStyle.Quint)

	local dome = Instance.new("Part")
	dome.Name = "HopeShockDome"
	dome.Shape = Enum.PartType.Ball
	dome.Anchored = true
	dome.CanCollide = false
	dome.CanQuery = false
	dome.CanTouch = false
	dome.CastShadow = false
	dome.Material = Enum.Material.Neon
	dome.Color = Palette.Energy.Cyan
	dome.Transparency = 0.75
	dome.Size = Vector3.one * 4
	dome.CFrame = base * CFrame.new(0, 4, 0)
	dome.Parent = workspace
	trackPart(dome, 1)
	tween(dome, 0.5, { Size = Vector3.one * 26, Transparency = 1 }, Enum.EasingStyle.Quint)
end

--[[
	Entry point for the broadcast transform VFX.
	`payload` is { userId, phase, duration }.
]]
function Effects.transformVFX(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local userId = tonumber(payload.userId)
	local phase = tostring(payload.phase)
	local duration = tonumber(payload.duration) or 1
	if not userId then
		return
	end

	local subject = Players:GetPlayerByUserId(userId)
	local character = subject and subject.Character
	local isLocal = userId == Players.LocalPlayer.UserId

	if phase == "Begin" then
		if character then
			playGlyph(character, duration)
			startMotes(character, userId, duration * 0.9)
		end
		if isLocal then
			Effects.fieldOfViewPulse(-4, duration * 0.5)
		end
	elseif phase == "Core" then
		if character then
			playCoreFlash(character)
		end
		if isLocal then
			Effects.fieldOfViewPulse(6, 0.4)
		end
	elseif phase == "Complete" then
		stopMotes(userId)
		if character then
			playShockwave(character)
		end
		if isLocal then
			Effects.fieldOfViewPulse(10, 0.55)
			Effects.shake(0.55)
		end
	elseif phase == "Revert" then
		stopMotes(userId)
		if character then
			local base = footCFrame(character)
			if base then
				local ring = ringPart("HopeRevert", base, 18, 0.35, Palette.Energy.CyanDim, 0.5)
				trackPart(ring, 0.8)
				tween(ring, 0.45, { Size = Vector3.new(0.35, 4, 4), Transparency = 1 })
			end
		end
		if isLocal then
			Effects.fieldOfViewPulse(-5, 0.35)
		end
	elseif phase == "Human" or phase == "Abort" then
		stopMotes(userId)
	end
end

-- Rebinding on respawn drops the previous character's connections so nothing
-- stale keeps firing.
function Effects.bindCharacter(character: Model?, humanoid: Humanoid?)
	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end
	if boundHumanoid and boundHumanoid.Parent then
		boundHumanoid.CameraOffset = Vector3.zero
	end
	shakeAmount = 0
	boundHumanoid = humanoid

	if not humanoid then
		return
	end
	lastHealth = humanoid.Health
	healthConnection = humanoid.HealthChanged:Connect(function(health)
		local delta = lastHealth - health
		lastHealth = health
		if delta > 0 then
			Effects.damageResponse(delta, humanoid.MaxHealth)
		end
	end)
end

function Effects.clear()
	if fovTween then
		fovTween:Cancel()
		fovTween = nil
	end
	local cam = camera()
	if cam then
		cam.FieldOfView = baseFieldOfView
	end
	if shakeConnection then
		shakeConnection:Disconnect()
		shakeConnection = nil
	end
	shakeAmount = 0
	if boundHumanoid and boundHumanoid.Parent then
		boundHumanoid.CameraOffset = Vector3.zero
	end
	for _, instance in table.clone(temporaryParts) do
		if instance.Parent then
			instance:Destroy()
		end
	end
	table.clear(temporaryParts)
	for userId in table.clone(activeMotes) do
		stopMotes(userId)
	end
	table.clear(lastFootPosition)
	if flash then
		flash.BackgroundTransparency = 1
	end
	if hitMarker then
		hitMarker.Visible = false
	end
end

return Effects
