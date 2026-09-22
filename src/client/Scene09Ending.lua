--!nonstrict
-- Chapter One's ending cutscene: "A Much Larger War." Seven short shots
-- carry the whole closing sequence - Aegis Zero kneeling, Mira's banter,
-- Ren and Voss arriving, Commander Sera's transmission, the fleet reveal,
-- and Aegis Zero's final question - as subtitle-carried dialogue over a
-- moving camera, the same CutsceneRunner pattern every scene cutscene from
-- Scene 2 onward uses. Finishing this cutscene (watched or skipped) fires
-- Net.Action.Scene09Done, which is what actually opens the chapter-complete
-- screen (see ChapterOneDirector.lua's completeScene09).

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local CutsceneRunner = require(script.Parent.CutsceneRunner)

local Scene09Ending = {}

local player = Players.LocalPlayer

local function playerRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function orbitShot(name: string, duration: number, subtitle: { any }?, radius: number, height: number, speed: number)
	return {
		name = name,
		duration = duration,
		subtitle = subtitle,
		enter = function()
			return { angle = math.random() * math.pi * 2 }
		end,
		update = function(state, alpha)
			local root = playerRoot()
			local at = if root then root.Position else Vector3.new(0, 5, 0)
			state.angle += speed * (1 / 60)
			local offset = Vector3.new(math.cos(state.angle) * radius, height, math.sin(state.angle) * radius)
			CutsceneRunner.setCamera(at + offset, at + Vector3.new(0, 3, 0), math.sin(alpha * math.pi) * 0.2)
		end,
		leave = function() end,
	}
end

function Scene09Ending.run(parent: Frame)
	CutsceneRunner.play({
		parent = parent,
		shots = {
			orbitShot("Kneel", 3.4, { nil, "Aegis Zero kneels in the ruined district, its core light unstable." }, 10, 5, 0.2),
			orbitShot("MiraBanter", 3.2, { "MIRA", "You could have warned me you were secretly a giant robot pilot." }, 7, 4, 0.15),
			orbitShot("MiraBanter2", 2.6, { "KAI", "I found out ten minutes ago." }, 7, 4, 0.15),
			orbitShot("MiraBanter3", 2.4, { "MIRA", "Still rude." }, 7, 4, 0.15),
			orbitShot("RenArrives", 3, { "CAPTAIN REN", "This battle is over. But the invasion isn't." }, 9, 5, 0.18),
			orbitShot("VossDiscovery", 3.2, { "DR. ELIAN VOSS", "The Harrower's final transmission activated signals across the Earth. Other Aegis Frames are waking up." }, 9, 5, 0.18),
			orbitShot("SeraRadio1", 3.4, { "COMMANDER SERA", "My name is Commander Sera. I lead the resistance operating beyond Nova City. If you can hear this, bring the Aegis Frame to our outpost." }, 6, 6, 0.1),
			orbitShot("SeraRadio2", 3, { "COMMANDER SERA", "The enemy above your city was only a scouting vessel." }, 6, 6, 0.1),
			orbitShot("FleetReveal", 3.6, { nil, "Beyond the moon, hundreds of distant lights are approaching." }, 14, 9, 0.12),
			orbitShot("Objective1", 2.8, { "AEGIS ZERO", "Pilot, what is our objective?" }, 9, 5, 0.15),
			orbitShot("Objective2", 3, { "KAI", "We find the others. Then we take our world back." }, 9, 5, 0.15),
		},
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
			Net.get("Action"):FireServer(Net.Action.Scene09Done, nil)
		end,
	})
end

return Scene09Ending
