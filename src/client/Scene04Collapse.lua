--!nonstrict
-- Chapter One, Scene 4's climax: "The Hunter's Pursuit." Three shots (the
-- Harrower's leap, Ren pushing the evacuation group to safety, the street
-- collapsing) built on the same CutsceneRunner every scene cutscene from
-- Scene 2 onward uses. The actual teleport-underground/injured-pose/
-- objective work happens server-side once this finishes (see
-- ChapterOneDirector.lua's applyScene04EndState) - this module is camera
-- and subtitle only.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local CutsceneRunner = require(script.Parent.CutsceneRunner)

local Scene04Collapse = {}

local player = Players.LocalPlayer

local function playerRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function shotLeap()
	return {
		name = "Leap",
		duration = 2.6,
		subtitle = { nil, "The Harrower clears the block in a single stride." },
		enter = function()
			return {}
		end,
		update = function(_state, alpha)
			local root = playerRoot()
			local at = if root then root.Position else Vector3.new(0, 5, 0)
			CutsceneRunner.setCamera(at + Vector3.new(-8, 10, 10), at + Vector3.new(14, 4, -14), math.sin(alpha * math.pi) * 0.5)
		end,
		leave = function() end,
	}
end

local function shotPush()
	return {
		name = "Push",
		duration = 2.4,
		subtitle = { "CAPTAIN REN", "It's found us. Inside, now, all of you!" },
		enter = function()
			return {}
		end,
		update = function(_state, alpha)
			local root = playerRoot()
			local at = if root then root.Position else Vector3.new(0, 5, 0)
			local eased = alpha * alpha
			CutsceneRunner.setCamera(at + Vector3.new(4, 3.4, 4):Lerp(Vector3.new(2, 2.6, 2), eased), at + Vector3.new(0, 3, 0), 0)
		end,
		leave = function() end,
	}
end

local function shotCollapse()
	return {
		name = "Collapse",
		duration = 3,
		subtitle = { nil, "The road opens beneath them." },
		enter = function()
			return {}
		end,
		update = function(_state, alpha)
			local root = playerRoot()
			local at = if root then root.Position else Vector3.new(0, 5, 0)
			local drop = alpha * alpha * 6
			CutsceneRunner.setCamera(at + Vector3.new(6, 6 - drop, 6), at + Vector3.new(0, -2 - drop, 0), 0)
		end,
		leave = function() end,
	}
end

function Scene04Collapse.run(parent: Frame)
	CutsceneRunner.play({
		parent = parent,
		shots = { shotLeap(), shotPush(), shotCollapse() },
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
			Net.get("Action"):FireServer(Net.Action.Scene04Done, nil)
		end,
	})
end

return Scene04Collapse
