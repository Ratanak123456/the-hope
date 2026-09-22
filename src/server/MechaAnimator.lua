--!nonstrict
-- Server-side procedural pose layer.  It composes a small pose over the
-- avatar's existing Animator output instead of anchoring or moving the root.
local RunService = game:GetService("RunService")

local MechaAnimator = {}
local bound: { [Model]: any } = {}

local function joint(model: Model, names: {string}, p0: string?, p1: string?): Motor6D?
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") then
			for _, name in names do
				if item.Name == name then return item end
			end
			if p0 and p1 and item.Part0 and item.Part1 and item.Part0.Name == p0 and item.Part1.Name == p1 then return item end
		end
	end
	return nil
end

local function collect(model: Model): { [string]: Motor6D }
	local out: { [string]: Motor6D } = {}
	local function add(key: string, names: {string}, p0: string?, p1: string?)
		local found = joint(model, names, p0, p1)
		if found then out[key] = found end
	end
	add("waist", {"Waist", "RootJoint", "Root"}, "LowerTorso", "UpperTorso")
	add("neck", {"Neck"}, "UpperTorso", "Head")
	add("rShoulder", {"RightShoulder", "Right Shoulder"}, "UpperTorso", "RightUpperArm")
	add("lShoulder", {"LeftShoulder", "Left Shoulder"}, "UpperTorso", "LeftUpperArm")
	add("rElbow", {"RightElbow"}, "RightUpperArm", "RightLowerArm")
	add("lElbow", {"LeftElbow"}, "LeftUpperArm", "LeftLowerArm")
	add("rHip", {"RightHip", "Right Hip"}, "LowerTorso", "RightUpperLeg")
	add("lHip", {"LeftHip", "Left Hip"}, "LowerTorso", "LeftUpperLeg")
	add("rKnee", {"RightKnee"}, "RightUpperLeg", "RightLowerLeg")
	add("lKnee", {"LeftKnee"}, "LeftUpperLeg", "LeftLowerLeg")
	return out
end

local function ease(x: number): number
	return x * x * (3 - 2 * x)
end

local function pose(state: any, now: number): { [string]: CFrame }
	local t = now - state.started
	local result: { [string]: CFrame } = {}
	local speed = state.humanoid and state.humanoid.MoveDirection.Magnitude or 0
	local moving = state.active and speed > 0.05
	local cycle = now * (if speed > 0.75 then 8 else 5)
	local sway = if moving then math.sin(cycle) else math.sin(now * 1.7) * 0.08
	result.waist = CFrame.Angles(0, sway * 0.035, if moving then -0.04 else 0)
	result.rHip = CFrame.Angles(sway * 0.16, 0, 0)
	result.lHip = CFrame.Angles(-sway * 0.16, 0, 0)
	result.rShoulder = CFrame.Angles(-sway * 0.12, 0, 0.08)
	result.lShoulder = CFrame.Angles(sway * 0.12, 0, -0.08)
	if state.action then
		local a = math.clamp(t / state.duration, 0, 1)
		local hit = state.action
		local pulse = if a < 0.28 then ease(a / 0.28) else if a < 0.55 then 1 - ease((a - 0.28) / 0.27) else 0
		if hit == "Combo1" then
			result.waist = CFrame.Angles(0, -0.28 * pulse, 0)
			result.rShoulder = CFrame.Angles(-0.7 * pulse, -0.2 * pulse, 0.1)
			result.rElbow = CFrame.Angles(-0.9 * pulse, 0, 0)
		elseif hit == "Combo2" then
			result.waist = CFrame.Angles(0, 0.32 * pulse, 0)
			result.lShoulder = CFrame.Angles(-0.65 * pulse, 0.25 * pulse, -0.18)
			result.lElbow = CFrame.Angles(-1.15 * pulse, 0, 0)
		elseif hit == "Combo3" or hit == "GroundSlam" then
			local drive = if hit == "GroundSlam" then pulse else math.sin(math.clamp(a * math.pi, 0, math.pi))
			result.waist = CFrame.Angles(0.38 * drive, 0, 0)
			result.rShoulder = CFrame.Angles(-1.25 * drive, 0, 0)
			result.lShoulder = CFrame.Angles(-1.1 * drive, 0, 0)
			result.rElbow = CFrame.Angles(-0.45 * drive, 0, 0)
			result.lElbow = CFrame.Angles(-0.45 * drive, 0, 0)
			result.rHip = CFrame.Angles(0.22 * drive, 0, 0)
			result.lHip = CFrame.Angles(0.22 * drive, 0, 0)
		elseif hit == "ResonanceBolt" then
			result.waist = CFrame.Angles(0, -0.15 * pulse, 0)
			result.rShoulder = CFrame.Angles(-0.6 * pulse, -0.2 * pulse, 0)
			result.rElbow = CFrame.Angles(-0.6 * pulse, 0, 0)
		elseif hit == "ThrusterDash" then
			result.waist = CFrame.Angles(0.3 * pulse, 0, 0)
			result.rShoulder = CFrame.Angles(0.3 * pulse, 0, 0.2)
			result.lShoulder = CFrame.Angles(0.3 * pulse, 0, -0.2)
		elseif hit == "Hit" then
			result.waist = CFrame.Angles(0, 0, 0.18 * pulse)
		end
	end
	return result
end

function MechaAnimator.bind(character: Model, humanoid: Humanoid)
	MechaAnimator.unbind(character)
	local state = { joints = collect(character), previous = {}, humanoid = humanoid, active = false, started = os.clock(), action = nil }
	bound[character] = state
	for key in state.joints do state.previous[key] = CFrame.identity end
end

function MechaAnimator.unbind(character: Model)
	local state = bound[character]
	if state then
		for key, motor in state.joints do motor.Transform = CFrame.identity end
		bound[character] = nil
	end
end

function MechaAnimator.setActive(character: Model, active: boolean)
	local state = bound[character]
	if state then state.active = active end
end

function MechaAnimator.action(character: Model, name: string, duration: number)
	local state = bound[character]
	if state then state.action = name; state.duration = duration; state.started = os.clock() end
end

function MechaAnimator.clearAction(character: Model)
	local state = bound[character]
	if state then state.action = nil end
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for character, state in bound do
		if not character.Parent or not state.humanoid.Parent or state.humanoid.Health <= 0 then
			MechaAnimator.unbind(character)
			continue
		end
		local nextPose = pose(state, now)
		for key, motor in state.joints do
			local previous = state.previous[key] or CFrame.identity
			local animatorPose = motor.Transform * previous:Inverse()
			local desired = nextPose[key] or CFrame.identity
			motor.Transform = animatorPose * desired
			state.previous[key] = desired
		end
		if state.action and now - state.started >= state.duration then state.action = nil end
	end
end)

return MechaAnimator
