--!nonstrict
-- Chapter One, Scene 2's invasion cutscene: "The Sky Breaks." Built on
-- CutsceneRunner (shared shot-sequencing/Skip/handoff), the same pattern
-- Opening.lua established for Scene 1. Five shots compress the scene spec's
-- fifteen described beats while keeping every story beat readable: darkness
-- falling, the sky rupturing, distant impacts, the pod bearing down on the
-- plaza while the player takes cover, and the smoke clearing on the first
-- Warden. By the time this runs, the server has already called
-- WorldState.revealInvasion() and spawned the pod/Warden (see
-- ChapterOneDirector.lua's beginScene02) - this module only points a camera
-- at what already exists, it builds nothing itself.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local CutsceneRunner = require(script.Parent.CutsceneRunner)

local Scene02Invasion = {}

local player = Players.LocalPlayer

local function findCity(): Instance?
	local world = workspace:FindFirstChild("HopeGreybox")
	return world and world:FindFirstChild("City")
end

local function findFountain(): BasePart?
	local city = findCity()
	local fountain = city and city:FindFirstChild("PlazaFountain")
	local core = fountain and fountain:FindFirstChild("MonumentCore")
	return if core and core:IsA("BasePart") then core else nil
end

local function findPod(): BasePart?
	local scene = workspace:FindFirstChild("ChapterOneScene")
	local pod = scene and scene:FindFirstChild("DropPod")
	local shell = pod and pod:FindFirstChild("PodShell")
	return if shell and shell:IsA("BasePart") then shell else nil
end

local function findWarden(): Model?
	local scene = workspace:FindFirstChild("ChapterOneScene")
	for _, child in (scene and scene:GetChildren() or {}) do
		if child:IsA("Model") and child.Name == "Warden" then
			return child
		end
	end
	return nil
end

local function playerRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function shotDarkening()
	return {
		name = "Darkening",
		duration = 3,
		subtitle = { nil, "The light goes out of the sky." },
		enter = function()
			return {}
		end,
		update = function(_state, alpha)
			local root = playerRoot()
			local at = if root then root.Position else Vector3.new(0, 5, 20)
			CutsceneRunner.setCamera(at + Vector3.new(3.5, 2.4, 3.5), at + Vector3.new(0, 2, 0), math.sin(alpha * math.pi) * 0.4)
		end,
		leave = function() end,
	}
end

local function shotRupture()
	return {
		name = "Rupture",
		duration = 3.6,
		subtitle = { nil, "The clouds are turning around something that should not be there." },
		enter = function()
			return {}
		end,
		update = function(_state, alpha)
			local root = playerRoot()
			local base = if root then root.Position else Vector3.new(0, 5, 20)
			local eased = alpha * alpha * (3 - 2 * alpha)
			local low = base + Vector3.new(-6, 3, -2)
			local high = base + Vector3.new(-10, 40, -14)
			CutsceneRunner.setCamera(low:Lerp(high, eased * 0.3), Vector3.new(-70, 420, -560), 0)
		end,
		leave = function() end,
	}
end

local function shotDistantImpacts()
	return {
		name = "DistantImpacts",
		duration = 3.2,
		subtitle = { nil, "Something is already falling, kilometers away." },
		enter = function()
			return {}
		end,
		update = function(_state, alpha)
			local origin = Vector3.new(160, 90, -120)
			local target = Vector3.new(60, 10, -220)
			local eased = 1 - (1 - alpha) ^ 2
			CutsceneRunner.setCamera(origin, origin:Lerp(target, eased * 0.4), math.sin(alpha * math.pi) * 0.6)
		end,
		leave = function() end,
	}
end

local function shotPodApproach()
	return {
		name = "PodApproach",
		duration = 3.4,
		subtitle = { nil, "Kai pulls Mira down behind the fountain." },
		enter = function()
			return {}
		end,
		update = function(_state, alpha)
			local fountain = findFountain()
			local focus = if fountain then fountain.Position else Vector3.new(0, 6, 20)
			local podAbove = focus + Vector3.new(0, 40 * (1 - alpha), -20 * (1 - alpha) - 6)
			local eased = alpha * alpha
			CutsceneRunner.setCamera(focus + Vector3.new(9, 5 + eased * 2, 9), podAbove, 0)
		end,
		leave = function() end,
	}
end

local function shotReveal()
	return {
		name = "Reveal",
		duration = 3.2,
		subtitle = { nil, "The Wardens have arrived." },
		enter = function()
			return {}
		end,
		update = function(_state, alpha)
			local pod = findPod()
			local warden = findWarden()
			local wardenRoot = warden and warden.PrimaryPart
			local focus = if wardenRoot then wardenRoot.Position elseif pod then pod.Position else Vector3.new(0, 3, 14)
			local eased = alpha * alpha * (3 - 2 * alpha)
			local far = focus + Vector3.new(14, 10, 14)
			local near = focus + Vector3.new(6, 5, 8)
			CutsceneRunner.setCamera(far:Lerp(near, eased), focus + Vector3.new(0, 3, 0), 0)
		end,
		leave = function() end,
	}
end

function Scene02Invasion.run(parent: Frame)
	CutsceneRunner.play({
		parent = parent,
		shots = { shotDarkening(), shotRupture(), shotDistantImpacts(), shotPodApproach(), shotReveal() },
		skipActionVerb = nil, -- the end state is identical either way - see finish() below, which always fires Scene02Done
		skipHintText = "E / START",
		finish = function()
			local camera = workspace.CurrentCamera
			if camera then
				camera.CameraType = Enum.CameraType.Custom
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					camera.CameraSubject = humanoid
				end
			end
			Net.get("Action"):FireServer(Net.Action.Scene02Done, nil)
		end,
	})
end

return Scene02Invasion
