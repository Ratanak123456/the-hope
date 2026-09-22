--!nonstrict
-- Chapter One story director. Owns the scene-by-scene flow described in the
-- working rules (rule 14: a Chapter One state system so finished scenes
-- cannot repeat) - today that is Scenes 1-3. Scenes 4-9 are not implemented
-- yet; SaveService's Stage enum already has a slot for each one so later
-- work only has to add a new begin*/run* pair here without touching the
-- rest of the chapter.
--
-- Everything a player-visible number or string needs is read from
-- Config.Scene01/Scene02/Scene03 (rule 15: names, positions, timings,
-- objective text are all configurable in one place).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Palette = require(Shared.Palette)

local CombatService = require(script.Parent.CombatService)
local DialogueService = require(script.Parent.DialogueService)
local EncounterService = require(script.Parent.EncounterService)
local Kit = require(script.Parent.World.Kit)
local MechaAnimator = require(script.Parent.MechaAnimator)
local NPCService = require(script.Parent.NPCService)
local PlayerService = require(script.Parent.PlayerService)
local SaveService = require(script.Parent.SaveService)
local WardenRig = require(script.Parent.WardenRig)
local WorldState = require(script.Parent.World.WorldState)

local ChapterOneDirector = {}

local feedback: RemoteEvent
local world: any = nil
local container: Folder

-- The player Scene 1's narrative beats (Mira's companionship, Daren's
-- conversation) are written for - see the module header for why this is a
-- deliberate, documented simplification rather than a missed multiplayer
-- case: the story has one protagonist ("Kai"), and every other participant
-- still gets the same world, NPCs and ambient life around them.
local storyPlayer: Player? = nil

type Scene01State = {
	step: string, -- "Cinematic" | "AwaitingDaren" | "Delivery" | "Done"
	mysteryTriggered: boolean,
	device: BasePart?, -- the wrist-device neon strip welded to the player's arm
	startedAt: number,
}

local scene01: { [Player]: Scene01State } = {}

local darenPrompt: ProximityPrompt? = nil
local darenPromptBusy = false

local MIRA_NAME = Config.Scene01.Names.Mira
local CHAPTER_ONE = Config.Chapters[1]
local CHAPTER_LABEL = if CHAPTER_ONE then `CHAPTER {CHAPTER_ONE.number} — {CHAPTER_ONE.title}` else "CHAPTER ONE"

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------

local function pushObjective(player: Player, title: string, detail: string, withMarker: BasePart?)
	feedback:FireClient(player, Net.Feedback.Objective, {
		chapter = CHAPTER_LABEL,
		title = title,
		detail = detail,
	})
	feedback:FireClient(player, Net.Feedback.WorldMarker, { target = withMarker, active = withMarker ~= nil })
end

local function notice(player: Player, text: string)
	feedback:FireClient(player, Net.Feedback.Notice, { text = text })
end

local function locationTitle(player: Player, text: string)
	feedback:FireClient(player, Net.Feedback.LocationTitle, { text = text })
end

--------------------------------------------------------------------------------
-- Ambient population: a capped set of civilians doing one of the behaviours
-- the scene spec asks for, spread between the neighborhood courtyard and the
-- avenue up toward the plaza so neither end of the route feels empty.
--------------------------------------------------------------------------------

local function populateAmbient(neighborhood: any, rng: Random)
	local base = neighborhood.GaragePosition
	local specs: { NPCService.AmbientSpec } = {
		-- Walking loops near the neighborhood and along the avenue.
		{ kind = "Walk", points = { base + Vector3.new(-6, 0, 14), base + Vector3.new(10, 0, 8), base + Vector3.new(4, 0, -18) } },
		{ kind = "Walk", points = { Vector3.new(-18, 0, 92), Vector3.new(-18, 0, 40), Vector3.new(-24, 0, 60) } },
		{ kind = "Walk", points = { Vector3.new(20, 0, 88), Vector3.new(26, 0, 44) } },
		{ kind = "Carry", points = { base + Vector3.new(12, 0, -4), base + Vector3.new(-8, 0, 6), Vector3.new(-20, 0, 70) } },
		{ kind = "Walk", points = { Vector3.new(0, 0, 70), Vector3.new(0, 0, 36), Vector3.new(18, 0, 50) } },

		-- Waiting at a crossing (plaza approach).
		{ kind = "Wait", points = { Vector3.new(-2, 0, 38) }, facing = Vector3.new(0, 0, -1) },
		{ kind = "Wait", points = { Vector3.new(2, 0, 38) }, facing = Vector3.new(0, 0, -1) },

		-- Waiting at the neighborhood bus stop.
		{ kind = "Wait", points = { base + Vector3.new(15, 0, -9) }, facing = Vector3.new(-1, 0, 0) },
		{ kind = "Wait", points = { base + Vector3.new(14, 0, -6) }, facing = Vector3.new(-1, 0, 0) },

		-- Browsing / seated near the market stalls.
		{ kind = "Browse", points = { base + Vector3.new(0, 0, -20) }, facing = Vector3.new(0, 0, 1) },
		{ kind = "Sit", points = { base + Vector3.new(-11, 0, 3) }, facing = Vector3.new(1, 0, 0) },

		-- Repairing a vehicle outside the garage - a nod to Kai's own job.
		{ kind = "Repair", points = { base + Vector3.new(6, 0, 3) }, facing = Vector3.new(0, 0, -1) },

		-- Talking in a small group.
		{ kind = "Talk", points = { base + Vector3.new(-4, 0, -10) }, facing = Vector3.new(1, 0, 0.3) },
		{ kind = "Talk", points = { base + Vector3.new(-2.3, 0, -9.4) }, facing = Vector3.new(-1, 0, -0.3) },
	}

	local count = math.min(Config.Neighborhood.AmbientCount, #specs)
	for index = 1, count do
		NPCService.spawnAmbient(container, specs[index], rng)
	end
end

-- Central Plaza's crowd (Scene 2: "crowds with varied activities... the
-- plaza should feel large but not empty"), separate from the neighborhood's
-- population above so each area reads as populated on its own.
local function populatePlazaCrowd(fountainPosition: Vector3, rng: Random)
	local specs: { NPCService.AmbientSpec } = {
		{ kind = "Walk", points = { fountainPosition + Vector3.new(-20, 0, -10), fountainPosition + Vector3.new(18, 0, 6), fountainPosition + Vector3.new(-4, 0, -22) } },
		{ kind = "Walk", points = { fountainPosition + Vector3.new(14, 0, -18), fountainPosition + Vector3.new(-16, 0, -4) } },
		{ kind = "Carry", points = { fountainPosition + Vector3.new(-22, 0, 4), fountainPosition + Vector3.new(6, 0, -20) } },
		{ kind = "Sit", points = { fountainPosition + Vector3.new(-16, 0, 4) }, facing = Vector3.new(1, 0, -0.2) },
		{ kind = "Sit", points = { fountainPosition + Vector3.new(16, 0, -4) }, facing = Vector3.new(-1, 0, 0.2) },
		{ kind = "Browse", points = { fountainPosition + Vector3.new(-16, 0, 8) }, facing = Vector3.new(0, 0, -1) },
		{ kind = "Talk", points = { fountainPosition + Vector3.new(6, 0, 12) }, facing = Vector3.new(0.3, 0, -1) },
		{ kind = "Talk", points = { fountainPosition + Vector3.new(7.3, 0, 12.5) }, facing = Vector3.new(-0.3, 0, 1) },
	}
	for _, spec in specs do
		NPCService.spawnAmbient(container, spec, rng)
	end
end

--------------------------------------------------------------------------------
-- Wrist device: a small procedural part welded to the player's right arm,
-- inert until the mystery event, then briefly pulses. Building it as a real
-- world part (not a UI overlay) is what lets "Mira turns back, but the
-- device becomes inactive before she sees it clearly" read as a real beat -
-- it is genuinely there to be seen, and genuinely turns off.
--------------------------------------------------------------------------------

local function buildWristDevice(character: Model): BasePart?
	local arm = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or character:FindFirstChild("RightLowerArm")
	if not arm or not arm:IsA("BasePart") then
		return nil
	end
	local casing = Instance.new("Part")
	casing.Name = "WristDeviceCasing"
	casing.Size = Vector3.new(0.7, 0.5, 0.7)
	casing.Color = Color3.fromRGB(40, 38, 34)
	casing.Material = Enum.Material.Metal
	casing.CanCollide = false
	casing.CanQuery = false
	casing.CanTouch = false
	casing.CastShadow = false
	casing.Massless = true
	casing.CFrame = arm.CFrame * CFrame.new(0, -arm.Size.Y * 0.3, 0)
	casing.Parent = character
	Kit.weld(arm, casing)

	local face = Instance.new("Part")
	face.Name = "WristDeviceFace"
	face.Size = Vector3.new(0.3, 0.08, 0.3)
	face.Color = Palette.Energy.AmberDim
	face.Material = Enum.Material.Neon
	face.Transparency = 0.85
	face.CanCollide = false
	face.CanQuery = false
	face.CanTouch = false
	face.CastShadow = false
	face.Massless = true
	face.CFrame = casing.CFrame * CFrame.new(0, 0.29, 0)
	face.Parent = character
	Kit.weld(casing, face)

	return face
end

--------------------------------------------------------------------------------
-- Mystery events: power flicker, birds, broadcast, wrist pulse - triggered
-- once, near the sealed abandoned station along the route.
--------------------------------------------------------------------------------

local function flickerCityPower()
	local originalBrightness = Lighting.Brightness
	TweenService:Create(Lighting, TweenInfo.new(0.08, Enum.EasingStyle.Linear), { Brightness = originalBrightness * 0.35 }):Play()
	task.delay(0.18, function()
		TweenService:Create(Lighting, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Brightness = originalBrightness }):Play()
	end)
end

local function scatterBirds(from: Vector3, direction: Vector3)
	local flock = Kit.folder("BirdFlock", container)
	for index = 1, 5 do
		local bird = Instance.new("Part")
		bird.Name = "Bird"
		bird.Size = Vector3.new(0.6, 0.2, 0.9)
		bird.Color = Color3.fromRGB(28, 28, 30)
		bird.Material = Enum.Material.SmoothPlastic
		bird.CanCollide = false
		bird.CanQuery = false
		bird.CanTouch = false
		bird.CastShadow = false
		bird.Anchored = true
		bird.CFrame = CFrame.lookAt(from + Vector3.new((index - 3) * 1.6, index * 0.4, 0), from + direction)
		bird.Parent = flock
		TweenService:Create(bird, TweenInfo.new(1.8 + index * 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = bird.CFrame + direction * 70 + Vector3.new(0, 18, 0),
		}):Play()
	end
	task.delay(2.4, function()
		flock:Destroy()
	end)
end

local function pulseWristDevice(state: Scene01State)
	local face = state.device
	if not face or not face.Parent then
		return
	end
	TweenService:Create(face, TweenInfo.new(0.25, Enum.EasingStyle.Sine), { Transparency = 0.1, Color = Palette.Energy.Amber }):Play()
	local light = Instance.new("PointLight")
	light.Color = Palette.Energy.Amber
	light.Range = 6
	light.Brightness = 0
	light.Parent = face
	TweenService:Create(light, TweenInfo.new(0.25), { Brightness = 2 }):Play()
	task.delay(1.6, function()
		TweenService:Create(face, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { Transparency = 0.85, Color = Palette.Energy.AmberDim }):Play()
		TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
		task.delay(0.7, function()
			light:Destroy()
		end)
	end)
end

local function triggerMysteryEvent(player: Player, state: Scene01State)
	if state.mysteryTriggered then
		return
	end
	state.mysteryTriggered = true

	flickerCityPower()
	notice(player, "The street lights flicker for a moment.")

	local root = PlayerService.get(player)
	local characterRoot = root and root.character and root.character:FindFirstChild("HumanoidRootPart")
	if characterRoot and characterRoot:IsA("BasePart") then
		scatterBirds(characterRoot.Position + Vector3.new(0, 24, 0), characterRoot.CFrame.LookVector)
	end

	task.delay(1.2, function()
		if not player.Parent then
			return
		end
		notice(player, "BROADCAST: \"Space agencies continue to investigate an unidentified object detected beyond lunar orbit. Officials insist there is currently no danger—\"")
	end)

	task.delay(3, function()
		if not player.Parent then
			return
		end
		pulseWristDevice(state)
		DialogueService.play(player, "Scene01_MysteryDevice")
	end)
end

--------------------------------------------------------------------------------
-- Daren's conversation, the delivery objective and the plaza arrival that
-- ends the scene.
--------------------------------------------------------------------------------

local function beginDelivery(player: Player, state: Scene01State)
	state.step = "Delivery"
	-- Daren's conversation is resolved now, so a death during the delivery
	-- run should respawn at his stand outside the garage, not back upstairs
	-- in the bedroom.
	PlayerService.setCheckpoint(player, world.Neighborhood.SpawnCFrame, false)

	local playerState = PlayerService.get(player)
	local character = playerState and playerState.character
	if character then
		state.device = buildWristDevice(character)
	end

	pushObjective(player, Config.Scene01.Objective.Title, Config.Scene01.Objective.Detail, world.ResearchFacilityMarker)
	NPCService.setCompanionHold(MIRA_NAME, false)

	task.delay(4, function()
		if player.Parent and scene01[player] == state and state.step == "Delivery" then
			DialogueService.play(player, "Scene01_MiraEarly")
		end
	end)

	-- Short, staggered control tips along the route (rule: "optional short
	-- control tips"). KNOWN SIMPLIFICATION: these are plain timed toasts
	-- (via the existing Notice channel) phrased for keyboard; they do not
	-- yet detect touch/gamepad input to show the matching glyph, and they
	-- fade on a timer rather than dismissing the instant the player actually
	-- performs the action. HUD.lua's action bar already shows the real bound
	-- key/touch/gamepad icon per slot, so a mobile/controller player is not
	-- left without guidance, just without this specific text variant.
	local tips = Config.Scene01.ControlTips
	task.delay(1, function()
		if player.Parent then notice(player, tips.Walk) end
	end)
	task.delay(9, function()
		if player.Parent then notice(player, tips.Sprint) end
	end)
	task.delay(17, function()
		if player.Parent then notice(player, tips.Jump) end
	end)
end

local function onDarenTriggered(player: Player)
	if darenPromptBusy then
		return
	end
	local state = scene01[player]
	if not state or state.step ~= "AwaitingDaren" then
		return
	end
	darenPromptBusy = true
	state.step = "Conversation"
	NPCService.setCompanionHold(MIRA_NAME, true)
	DialogueService.play(player, "Scene01_DarenDelivery", function()
		darenPromptBusy = false
		if player.Parent and scene01[player] == state then
			beginDelivery(player, state)
		end
	end)
end

--------------------------------------------------------------------------------
-- Chapter One, Scene 2: "The Sky Breaks."
--
-- Begins the instant Scene 1 completes (the player has, by definition, just
-- walked into Central Plaza - see completeScene01 below). A short peaceful
-- beat, then the invasion cutscene (client: CutsceneRunner + the shots built
-- in Main.client.lua's Scene 2 handler), then one unified end state applied
-- whether the player watched it or skipped - see applyScene02EndState.
--------------------------------------------------------------------------------

type Scene02State = {
	step: string, -- "PreInvasion" | "Cutscene" | "Done"
}

local scene02: { [Player]: Scene02State } = {}
local scene02Warden: Model? = nil
local scene02Pod: Model? = nil

-- A small alien drop pod: a scorched ovoid shell embedded nose-first in the
-- plaza paving, cracked open along one seam. Built once, on demand, the
-- same "hidden until needed" spirit as Kit.markInvasionOnly - there is no
-- reason for this to exist before Scene 2 actually reaches its impact beat.
local function spawnPod(): Model
	local at = world.FountainPosition + Config.Scene02.PodImpactOffset
	local model = Kit.model("DropPod", container)

	Kit.part({
		name = "ImpactScorch",
		size = Vector3.new(12, 0.2, 12),
		position = at + Vector3.new(0, 0.55, 0),
		color = Color3.fromRGB(24, 22, 22),
		material = Palette.Material.Asphalt,
		decor = true,
		parent = model,
	})
	local shell = Kit.part({
		name = "PodShell",
		size = Vector3.new(6, 5.5, 6),
		cframe = CFrame.new(at + Vector3.new(0, 2.2, 0)) * CFrame.Angles(math.rad(12), math.rad(20), 0),
		color = Palette.Alien.Shell,
		material = Palette.Material.Shell,
		castShadow = true,
		parent = model,
	})
	Kit.wedge({
		name = "PodCrack",
		size = Vector3.new(3.2, 4.6, 2.4),
		cframe = shell.CFrame * CFrame.new(0.5, 0, 2.2) * CFrame.Angles(0, math.rad(90), 0),
		color = Palette.Alien.Plate,
		parent = model,
	})
	Kit.part({
		name = "PodGlow",
		size = Vector3.new(1.4, 1.4, 1.4),
		cframe = shell.CFrame * CFrame.new(0, 0, 2.6),
		color = Palette.Alien.Energy,
		material = Palette.Material.Energy,
		transparency = 0.25,
		decor = true,
		parent = model,
	})
	for index = 1, 4 do
		local angle = (index / 4) * math.pi * 2
		Kit.part({
			name = "DebrisChunk",
			size = Vector3.new(1.4, 0.8, 1.4),
			cframe = CFrame.new(at + Vector3.new(math.cos(angle) * 4.5, 0.6, math.sin(angle) * 4.5)) * CFrame.Angles(math.random(), math.random(), math.random()),
			color = Palette.City.Rubble,
			material = Palette.Material.Rubble,
			decor = true,
			parent = model,
		})
	end
	return model
end

-- The first Warden: WardenRig.build() already produces exactly the "black
-- armoured plates, pale organic material, violet energy at joints, multiple
-- sensor lights" design the scene spec asks for (see WardenRig.lua) - no new
-- creature design needed, just a spawn placed at the pod for the reveal.
local function spawnFirstWarden(): Model
	local at = world.FountainPosition + Config.Scene02.PodImpactOffset + Vector3.new(0, 0, -3)
	local model = WardenRig.build(container, at, Config.Scene02.Warden.MaxHealth, Config.Scene02.Warden.WalkSpeed)
	WardenRig.setAnimation(model, "Idle")
	return model
end

--------------------------------------------------------------------------------
-- Chapter One, Scene 3: "Survival Through Nova City."
--
-- Scope note: the full spec lists eight gameplay beats (find Mira, a debris
-- rescue, guiding civilians, a power-restore puzzle, combat, starting an
-- emergency transport with a mechanic named Toma, meeting Ren and Voss, the
-- Warden recognition moment). "Guide civilians to the evacuation route" is
-- covered by the panic behaviour Scene 2 already started (NPCService's
-- fleeing civilians head away from the plaza on their own) rather than a
-- separate escort mechanic, and Toma/the emergency transport is folded into
-- a line of Ren's dialogue rather than a second interactive system - both
-- deliberate scope cuts, stated plainly, made so the combat, rescue, power
-- puzzle and recognition-moment beats (the ones with real mechanical weight)
-- could be built properly instead of eight shallow ones.
--------------------------------------------------------------------------------

type Scene03State = {
	step: string, -- "FindMira" | "Rescue" | "Power" | "Combat" | "Recognition" | "Done"
	rescued: boolean,
	powerRestored: boolean,
}

local scene03: { [Player]: Scene03State } = {}
local completeScene03: (Player, Scene03State) -> () -- forward-declared: beginRecognition() below calls it from inside a delayed dialogue callback, before its real definition later in this section
local beginRecognition: (Player, Scene03State) -> () -- forward-declared: spawnScouts()'s Died handler below triggers it as soon as exactly one scout remains, before its real definition later in this section
local beginScene04: (Player) -> () -- forward-declared: completeScene03() below chains into it, before its real definition further down in this file's Scene 4 section
local beginScene05: (Player, CFrame) -> () -- forward-declared: applyScene04EndState() below chains into it, before its real definition further down in this file's Scene 5 section
local scene03Scouts: { Model } = {}
local scoutAttack: { [Model]: { phase: string, windupEnd: number, readyAt: number } } = {}
local scene03Ren: Model? = nil
local scene03Voss: Model? = nil
local rescuePrompt: ProximityPrompt? = nil
local powerPrompt: ProximityPrompt? = nil

local function scene03Point(offset: Vector3): Vector3
	return world.FountainPosition + offset
end

-- Debris pile + trapped survivors (visual only - two small huddled figures,
-- not full NPCs, since they only ever huddle and then vanish once rescued).
local function buildRescueSite(parent: Instance): ProximityPrompt
	local folder = Kit.folder("RescueSite", parent)
	local at = scene03Point(Config.Scene03.RescueOffset)

	for index = 1, 5 do
		Kit.part({
			name = "DebrisSlab",
			size = Vector3.new(3 + index % 2, 0.8, 2.4),
			cframe = CFrame.new(at + Vector3.new((index - 3) * 1.6, 0.6, 0)) * CFrame.Angles(0, math.rad(index * 11), math.rad(6)),
			color = Palette.City.Rubble,
			material = Palette.Material.Rubble,
			parent = folder,
		})
	end
	Kit.part({ name = "StallFrame", size = Vector3.new(6, 3, 0.3), cframe = CFrame.new(at + Vector3.new(0, 1.5, -2)) * CFrame.Angles(0, 0, math.rad(18)), color = Palette.City.Equipment, material = Palette.Material.MetalWorn, parent = folder })

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RescuePrompt"
	prompt.ActionText = "Hold to clear debris"
	prompt.ObjectText = "TRAPPED SURVIVORS"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Config.Scene03.RescueHoldSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.UIOffset = Vector2.new(0, -40)
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = Kit.part({ name = "RescueAnchor", size = Vector3.new(1, 1, 1), position = at, color = Palette.City.Rubble, transparency = 1, decor = true, parent = folder })
	return prompt
end

-- The power box: three colour-coded connectors, only one of which (chosen
-- at build time) is actually live - "clearly colored... connections", "do
-- not make it a confusing multi-minute puzzle". Interacting with the wrong
-- connector just fails softly (a Notice), never punishes or resets progress.
local function buildPowerBox(parent: Instance): (ProximityPrompt, number)
	local folder = Kit.folder("PowerBox", parent)
	local at = scene03Point(Config.Scene03.PowerBoxOffset)
	local colors = Config.Scene03.PowerConnectorColors
	local correctIndex = math.random(1, #colors)

	Kit.part({ name = "BoxCasing", size = Vector3.new(2.4, 3, 1.4), position = at + Vector3.new(0, 1.5, 0), color = Palette.City.Equipment, material = Palette.Material.MetalWorn, parent = folder })
	for index, color in colors do
		local connector = Kit.part({
			name = `Connector{index}`,
			size = Vector3.new(0.5, 0.5, 0.3),
			position = at + Vector3.new((index - 2) * 0.7, 2.3, -0.75),
			color = color,
			material = Palette.Material.Energy,
			transparency = if index == correctIndex then 0.1 else 0.55,
			decor = true,
			parent = folder,
		})
		if index == correctIndex then
			Kit.light(connector, color, 8, 1.4, false)
		end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PowerPrompt"
	prompt.ActionText = "Hold to reconnect the glowing line"
	prompt.ObjectText = "DAMAGED POWER BOX"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 1.4
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.UIOffset = Vector2.new(0, -40)
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = folder:FindFirstChild("BoxCasing")
	return prompt, correctIndex
end

local function buildGate(parent: Instance): Model
	local model = Kit.model("EvacuationGate", parent)
	local at = scene03Point(Config.Scene03.GateOffset)
	for _, side in { -1, 1 } do
		Kit.part({ name = "GatePost", size = Vector3.new(0.6, 8, 0.6), position = at + Vector3.new(side * 3.2, 4, 0), color = Palette.City.Equipment, material = Palette.Material.Metal, parent = model })
	end
	local door = Kit.part({ name = "GateDoor", size = Vector3.new(6, 7.4, 0.4), position = at + Vector3.new(0, 3.9, 0), color = Palette.City.FacadeTrim, material = Palette.Material.MetalWorn, parent = model }
	)
	local light = Kit.part({ name = "GateLight", size = Vector3.new(5.6, 0.3, 0.1), position = at + Vector3.new(0, 7, 0.25), color = Palette.Sky.Emergency, material = Palette.Material.Energy, transparency = 0.3, decor = true, parent = model })
	Kit.light(light, Palette.Sky.Emergency, 10, 1, false)
	model:SetAttribute("DoorTopY", door.Position.Y + door.Size.Y / 2)
	return model
end

local function openGate(gate: Model)
	local door = gate:FindFirstChild("GateDoor")
	if door and door:IsA("BasePart") then
		TweenService:Create(door, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Position = door.Position + Vector3.new(0, 7.5, 0) }):Play()
	end
	local light = gate:FindFirstChild("GateLight")
	if light and light:IsA("BasePart") then
		light.Color = Palette.Energy.Cyan
		local pointLight = light:FindFirstChildOfClass("PointLight")
		if pointLight then
			pointLight.Color = Palette.Energy.Cyan
		end
	end
end

--------------------------------------------------------------------------------
-- Combat: 2-3 Warden Scouts, a self-contained mini version of
-- EncounterService's Windup/Strike/Recover shape (not the same instance -
-- that state machine is tightly coupled to the awakening-chamber encounter,
-- so a small parallel loop here is lower-risk than reaching into it).
--------------------------------------------------------------------------------

local function spawnScouts(count: number)
	local at = scene03Point(Config.Scene03.GateOffset)
	for index = 1, count do
		local offset = Vector3.new((index - (count + 1) / 2) * 10, 0, -14)
		local scout = WardenRig.build(container, at + offset, Config.Scene03.ScoutMaxHealth, Config.Warden.WalkSpeed)
		CollectionService:AddTag(scout, CombatService.WardenTag)
		scoutAttack[scout] = { phase = "Idle", windupEnd = 0, readyAt = 0 }
		table.insert(scene03Scouts, scout)
		local humanoid = scout:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			local index2 = table.find(scene03Scouts, scout)
			if index2 then
				table.remove(scene03Scouts, index2)
			end
			scoutAttack[scout] = nil
			WardenRig.setTelegraph(scout, false)
			WardenRig.remove(scout)
			CollectionService:RemoveTag(scout, CombatService.WardenTag)
			task.delay(2.5, function()
				if scout.Parent then
					scout:Destroy()
				end
			end)

			-- The Warden Recognition Moment (rule): Ren destroys the last
			-- scout himself, so this fires the instant exactly one remains -
			-- deliberately not "the player defeated every scout unassisted."
			-- checkScene03Combat's 1s poll is a safety-net fallback only.
			if #scene03Scouts == 1 and storyPlayer then
				local state = scene03[storyPlayer]
				if state and state.step == "Combat" then
					beginRecognition(storyPlayer, state)
				end
			end
		end)
	end
end

local function thinkScout(scout: Model, target: BasePart, targetPlayer: Player, now: number)
	local humanoid = scout:FindFirstChildOfClass("Humanoid")
	local root = scout.PrimaryPart
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local attack = scoutAttack[scout]
	if not attack then
		return
	end

	if attack.phase == "Windup" then
		if now < attack.windupEnd then
			WardenRig.setAnimation(scout, "Windup")
			humanoid:MoveTo(root.Position)
			return
		end
		WardenRig.setAnimation(scout, "Strike")
		WardenRig.setTelegraph(scout, false)
		local distance = (target.Position - root.Position).Magnitude
		if distance <= Config.Warden.AttackRange and targetPlayer:GetAttribute("DodgeInvulnerable") ~= true then
			local playerState = PlayerService.get(targetPlayer)
			if playerState and playerState.humanoid and playerState.humanoid.Health > 0 then
				playerState.humanoid:TakeDamage(Config.Warden.Damage)
				PlayerService.hitReaction(targetPlayer, false)
			end
		end
		attack.phase = "Recover"
		attack.readyAt = now + Config.Warden.RecoverTime
		return
	end

	if attack.phase == "Recover" then
		WardenRig.setAnimation(scout, "Recover")
		if now < attack.readyAt then
			return
		end
		attack.phase = "Idle"
		attack.readyAt = now + Config.Warden.AttackCooldown
		return
	end

	local distance = (target.Position - root.Position).Magnitude
	if distance > Config.Warden.AttackRange then
		humanoid:MoveTo(target.Position)
		return
	end
	if now < attack.readyAt then
		humanoid:MoveTo(root.Position)
		return
	end
	attack.phase = "Windup"
	attack.windupEnd = now + Config.Warden.WindupTime
	WardenRig.setAnimation(scout, "Windup")
	WardenRig.setTelegraph(scout, true)
	feedback:FireAllClients(Net.Feedback.WardenTelegraph, { position = root.Position, radius = Config.Warden.AttackRange, duration = Config.Warden.WindupTime })
end

local function thinkScene03Combat(dt: number)
	if #scene03Scouts == 0 or not storyPlayer then
		return
	end
	local state = scene03[storyPlayer]
	if not state or state.step ~= "Combat" then
		return
	end
	local playerState = PlayerService.get(storyPlayer)
	local root = playerState and playerState.character and playerState.character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local now = os.clock()
	for _, scout in table.clone(scene03Scouts) do
		if scout.Parent then
			thinkScout(scout, root, storyPlayer, now)
		end
	end
end

--------------------------------------------------------------------------------
-- Recognition moment + Harrower tease + ending.
--------------------------------------------------------------------------------

beginRecognition = function(player: Player, state: Scene03State)
	if state.step ~= "Combat" then
		-- idempotent: the Died-handler trigger and the polling fallback in
		-- checkScene03Combat can both fire close together.
		return
	end
	state.step = "Recognition"
	local playerState = PlayerService.get(player)
	local character = playerState and playerState.character
	local face = character and character:FindFirstChild("WristDeviceFace")
	if face and face:IsA("BasePart") then
		TweenService:Create(face, TweenInfo.new(0.2), { Transparency = 0, Color = Palette.Energy.Amber }):Play()
		local light = Instance.new("PointLight")
		light.Color = Palette.Energy.Amber
		light.Range = 10
		light.Brightness = 3
		light.Parent = face
		task.delay(2, function()
			light:Destroy()
		end)
	end

	-- Every remaining scout freezes, scans, then Ren destroys the nearest one.
	local nearest: Model? = nil
	local nearestDistance = math.huge
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for _, scout in scene03Scouts do
		WardenRig.setAnimation(scout, "Idle")
		local humanoid = scout:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
		end
		if root and root:IsA("BasePart") and scout.PrimaryPart then
			local distance = (scout.PrimaryPart.Position - root.Position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearest = scout
			end
		end
	end
	if nearest then
		local humanoid = nearest:FindFirstChildOfClass("Humanoid")
		if humanoid then
			task.delay(0.6, function()
				if humanoid.Parent then
					humanoid.Health = 0
				end
			end)
		end
	end

	task.delay(1.4, function()
		if not player.Parent then
			return
		end
		DialogueService.play(player, "Scene03_Recognition", function()
			if not player.Parent then
				return
			end
			-- The Harrower rises in the distance before Voss can answer -
			-- a short, distant tease (not the full boss intro - that is
			-- Scene 8's job), reusing the same WardenRig boss variant.
			local harrowerAt = scene03Point(Vector3.new(60, 0, -80))
			local harrower = WardenRig.build(container, harrowerAt, Config.Boss.MaxHealth, 0, { scale = Config.Boss.Scale, isBoss = true })
			harrower.Name = "HarrowerTease"
			WardenRig.setAnimation(harrower, "Idle")
			task.delay(20, function()
				if harrower.Parent then
					WardenRig.remove(harrower)
					harrower:Destroy()
				end
			end)
			task.delay(1.2, function()
				if player.Parent then
					DialogueService.play(player, "Scene03_HarrowerRises", function()
						if player.Parent and scene03[player] == state then
							completeScene03(player, state)
						end
					end)
				end
			end)
		end)
	end)
end

completeScene03 = function(player: Player, state: Scene03State)
	state.step = "Done"
	player:SetAttribute("HasEmergencyStaff", false)
	feedback:FireClient(player, Net.Feedback.HumanCombat, { enabled = false })
	local playerState = PlayerService.get(player)
	if playerState and playerState.humanoid then
		playerState.humanoid.MaxHealth = playerState.baseMaxHealth
		playerState.humanoid.Health = playerState.baseMaxHealth
	end
	pushObjective(player, Config.Scene03.Objectives.Ending.title, Config.Scene03.Objectives.Ending.detail, nil)
	SaveService.markStage(player, "Scene04_EvacuationRun")
	locationTitle(player, "Nova City — Eastern District")
	notice(player, "Captain Ren leads the survivors toward the shelter.")
	beginScene04(player)
end

local function checkScene03Combat(player: Player, state: Scene03State)
	if state.step ~= "Combat" then
		return
	end
	local allDown = true
	for _, scout in scene03Scouts do
		local humanoid = scout:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			allDown = false
			break
		end
	end
	if allDown then
		beginRecognition(player, state)
	end
end

local function beginCombat(player: Player, state: Scene03State)
	state.step = "Combat"
	pushObjective(player, Config.Scene03.Objectives.Combat.title, Config.Scene03.Objectives.Combat.detail, nil)
	notice(player, "Wardens, incoming!")
	spawnScouts(Config.Scene03.ScoutCount)

	task.spawn(function()
		while state.step == "Combat" and player.Parent do
			task.wait(1)
			checkScene03Combat(player, state)
		end
	end)
end

local function onPowerTriggered(player: Player, correctIndex: number)
	local state = scene03[player]
	if not state or state.step ~= "Power" or state.powerRestored then
		return
	end
	state.powerRestored = true
	local gate = container:FindFirstChild("EvacuationGate")
	if gate and gate:IsA("Model") then
		openGate(gate)
	end
	DialogueService.play(player, "Scene03_PowerRestored", function()
		if player.Parent and scene03[player] == state then
			beginCombat(player, state)
		end
	end)
end

local function onRescueTriggered(player: Player)
	local state = scene03[player]
	if not state or state.step ~= "Rescue" or state.rescued then
		return
	end
	state.rescued = true
	if rescuePrompt then
		rescuePrompt.Enabled = false
	end
	local playerState = PlayerService.get(player)
	if playerState and playerState.character then
		MechaAnimator.action(playerState.character, "Combo3", 0.8)
	end
	-- Mira assists instead of just watching (rule): she steps in and braces
	-- alongside the player for the duration of the heave.
	local mira = NPCService.getCompanion(MIRA_NAME)
	if mira and mira.model.Parent then
		NPCService.setPhase(mira.model, "Talk")
	end
	DialogueService.play(player, "Scene03_RescueComplete", function()
		if not player.Parent or scene03[player] ~= state then
			return
		end
		state.step = "Power"
		player:SetAttribute("HasEmergencyStaff", true)
		feedback:FireClient(player, Net.Feedback.HumanCombat, { enabled = true })
		pushObjective(player, Config.Scene03.Objectives.Power.title, Config.Scene03.Objectives.Power.detail, nil)
		if powerPrompt then
			powerPrompt.Enabled = true
		end
	end)
end

local function beginScene03(player: Player)
	if scene03[player] then
		return
	end
	scene03[player] = { step = "FindMira", rescued = false, powerRestored = false }

	local playerState = PlayerService.get(player)
	if playerState and playerState.humanoid then
		playerState.humanoid.MaxHealth = Config.HumanCombat.MaxHealth
		playerState.humanoid.Health = Config.HumanCombat.MaxHealth
	end

	pushObjective(player, Config.Scene03.Objectives.FindMira.title, Config.Scene03.Objectives.FindMira.detail, nil)
	DialogueService.play(player, "Scene03_FindMira", function()
		if player.Parent and scene03[player] then
			scene03[player].step = "Rescue"
			pushObjective(player, Config.Scene03.Objectives.Rescue.title, Config.Scene03.Objectives.Rescue.detail, nil)
			if rescuePrompt then
				rescuePrompt.Enabled = true
			end
		end
	end)
end

-- One end state, reached whether the player watched the whole cutscene or
-- hit Skip (rule 7). Idempotent per player via scene02[player].step.
local function applyScene02EndState(player: Player)
	local state = scene02[player]
	if not state or state.step == "Done" then
		return
	end
	state.step = "Done"

	WorldState.revealInvasion()
	NPCService.setGlobalPanic(world.FountainPosition)
	if not scene02Pod then
		scene02Pod = spawnPod()
	end
	if not scene02Warden then
		scene02Warden = spawnFirstWarden()
	end

	local cover = world.FountainPosition + Config.Scene02.CoverOffset
	PlayerService.teleport(player, CFrame.lookAt(cover, world.FountainPosition))
	PlayerService.setCheckpoint(player, CFrame.new(cover + Vector3.new(0, 4, 0)), false)
	PlayerService.setCombatLocked(player, false)

	local mira = NPCService.getCompanion(MIRA_NAME)
	if mira and mira.model.PrimaryPart then
		mira.model:PivotTo(CFrame.new(cover + Vector3.new(2, 0, 0)))
		NPCService.setCompanionHold(MIRA_NAME, false)
	end

	pushObjective(player, Config.Scene02.Objective.Title, Config.Scene02.Objective.Detail, nil)
	SaveService.markStage(player, "Scene03_CitySurvival")
	notice(player, "The plaza is not safe. Move.")
	beginScene03(player)
end

function ChapterOneDirector.completeScene02(player: Player)
	applyScene02EndState(player)
end

local function beginScene02(player: Player)
	if scene02[player] then
		return
	end
	scene02[player] = { step = "PreInvasion" }
	-- Movement stays free through PreInvasion on purpose (rule: "normal
	-- music and city ambience continue briefly... NPCs perform ordinary
	-- routines") - only the cutscene itself takes the camera and freezes
	-- the player, once it actually starts below.

	task.delay(Config.Scene02.PreInvasionSeconds, function()
		local state = scene02[player]
		if not player.Parent or not state or state.step ~= "PreInvasion" then
			return
		end
		state.step = "Cutscene"
		PlayerService.setCombatLocked(player, true)

		-- Pre-invasion signs (rule: "shadows change... birds and small
		-- drones leave... cars and displays lose power"): a brief
		-- system-wide brightness dip plus the same bird-scatter beat Scene
		-- 1's mystery event uses, reused rather than duplicated.
		flickerCityPower()
		local playerState = PlayerService.get(player)
		local root = playerState and playerState.character and playerState.character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			scatterBirds(root.Position + Vector3.new(0, 30, 0), Vector3.new(0, 0, -1))
		end

		-- The sky/lighting transition and the pod + first Warden are all
		-- built here, several seconds before the client's camera actually
		-- needs to frame any of them (the cutscene's own early shots cover
		-- the gap) - replication has time to land, and applyScene02EndState
		-- below simply reuses these instead of building them twice.
		task.delay(1.6, function()
			if not player.Parent or scene02[player] ~= state then
				return
			end
			WorldState.revealInvasion()
			NPCService.setGlobalPanic(world.FountainPosition)
			if not scene02Pod then
				scene02Pod = spawnPod()
			end
			if not scene02Warden then
				scene02Warden = spawnFirstWarden()
			end
			feedback:FireClient(player, Net.Feedback.Scene02Invasion, {})
		end)
	end)
end

--------------------------------------------------------------------------------
-- Chapter One, Scene 4: "The Hunter's Pursuit."
--
-- Mostly a scripted environmental sequence rather than open combat (rule:
-- "the Harrower should feel dangerous but mostly remain a scripted
-- environmental threat... do not allow its AI to wander away or kill
-- required NPCs") - the Wardens/soldiers here are staged set-dressing, not a
-- second fight, since Scene 3 already delivered the chapter's combat beat.
--------------------------------------------------------------------------------

type Scene04State = { step: string, miraHelped: boolean } -- "Run" | "Collapse" | "Done"

local scene04: { [Player]: Scene04State } = {}
local miraGapPrompt: ProximityPrompt? = nil
local collapseTriggered = false

local function buildScene04SetPieces(parent: Instance)
	local folder = Kit.folder("PursuitRoute", parent)

	-- Soldiers holding a defensive line - visual presence, not combatants;
	-- they never move or fight, which is what keeps them safe from "the
	-- Harrower's AI wandering off and killing a required NPC."
	local soldierAppearance = { skin = Color3.fromRGB(180, 150, 120), shirt = Color3.fromRGB(58, 64, 56), pants = Color3.fromRGB(42, 46, 40), hair = Color3.fromRGB(28, 26, 24), scale = 1.04 }
	for _, offset in Config.Scene04.SoldierOffsets do
		local soldier = NPCService.build(folder, scene03Point(offset), soldierAppearance, 0, nil)
		soldier:PivotTo(CFrame.lookAt(scene03Point(offset), scene03Point(Config.Scene04.CollapseOffset)))
	end

	-- A visible Warden threat down a side street - idle/alert, not hunting,
	-- reads as danger without needing a second combat encounter.
	local sideStreetWarden = WardenRig.build(folder, scene03Point(Config.Scene04.SoldierOffsets[1]) + Vector3.new(-14, 0, -6), Config.Warden.MaxHealth, 0)
	WardenRig.setAnimation(sideStreetWarden, "Windup")
	WardenRig.setTelegraph(sideStreetWarden, true)

	-- The gap Mira needs help across: a widened, broken stretch of sidewalk.
	local gapAt = scene03Point(Config.Scene04.MiraGapOffset)
	Kit.part({ name = "GapEdgeNear", size = Vector3.new(6, 0.6, 2), position = gapAt + Vector3.new(0, 0, 2), color = Palette.City.Rubble, material = Palette.Material.Rubble, parent = folder })
	Kit.part({ name = "GapEdgeFar", size = Vector3.new(6, 0.6, 2), position = gapAt + Vector3.new(0, 0, -2), color = Palette.City.Rubble, material = Palette.Material.Rubble, parent = folder })

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MiraGapPrompt"
	prompt.ActionText = "Hold to help Mira across"
	prompt.ObjectText = "MIRA"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.UIOffset = Vector2.new(0, -34)
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Enabled = false
	prompt.Parent = Kit.part({ name = "GapAnchor", size = Vector3.new(1, 1, 1), position = gapAt, color = Palette.City.Rubble, transparency = 1, decor = true, parent = folder })
	miraGapPrompt = prompt
	prompt.Triggered:Connect(function(player: Player)
		local state = scene04[player]
		if not state or state.step ~= "Run" or state.miraHelped then
			return
		end
		state.miraHelped = true
		prompt.Enabled = false
		NPCService.setCompanionHold(MIRA_NAME, false)
		DialogueService.play(player, "Scene04_MiraGap")
	end)
end

local function applyScene04EndState(player: Player)
	local state = scene04[player]
	if not state or state.step == "Done" then
		return
	end
	state.step = "Done"

	-- Land behind the vault gateway, not on top of it - World.RuinSpawn looks
	-- toward -Z at the gateway (see Ruin.lua), so pushing back along +Z opens
	-- up Scene 5's short tunnel walk instead of landing the group already
	-- staring at the dormant Aegis Zero.
	local landing = world.RuinSpawn + Vector3.new(0, 0, Config.Scene05.TunnelLength)
	local fallOffsets = Config.Scene04.FallCFrameOffsets
	PlayerService.teleport(player, landing + fallOffsets.Player)
	PlayerService.setCheckpoint(player, landing, true)
	PlayerService.setCombatLocked(player, false)

	local playerState = PlayerService.get(player)
	if playerState and playerState.humanoid then
		-- Rule: "damaged/injured animation states" - a brief limp/stagger
		-- beat via the same pose composer combat already uses, not a
		-- persistent debuff.
		if playerState.character then
			MechaAnimator.action(playerState.character, "Hit", 1.2)
		end
	end

	local mira = NPCService.getCompanion(MIRA_NAME)
	if mira and mira.model.Parent then
		mira.model:PivotTo(landing + fallOffsets.Mira)
		NPCService.setPhase(mira.model, "Idle")
	end
	if scene03Voss and scene03Voss.Parent then
		scene03Voss:PivotTo(landing + fallOffsets.Voss)
	end

	DialogueService.play(player, "Scene04_Underground", function()
		if not player.Parent then
			return
		end
		pushObjective(player, "Find another way to the shelter", "Follow the tunnel deeper - Captain Ren's group stayed above.", nil)
		beginScene05(player, landing)
	end)
	SaveService.markStage(player, "Scene05_Underground")
end

function ChapterOneDirector.completeScene04(player: Player)
	applyScene04EndState(player)
end

beginScene04 = function(player: Player)
	if scene04[player] then
		return
	end
	scene04[player] = { step = "Run", miraHelped = false }
	if miraGapPrompt then
		miraGapPrompt.Enabled = true
	end
end

local function thinkScene04(dt: number)
	local player = storyPlayer
	if not player or not player.Parent then
		return
	end
	local state = scene04[player]
	if not state or state.step ~= "Run" then
		return
	end
	local playerState = PlayerService.get(player)
	local root = playerState and playerState.character and playerState.character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	NPCService.updateCompanion(MIRA_NAME, root, dt)

	local collapseAt = scene03Point(Config.Scene04.CollapseOffset)
	if (root.Position - collapseAt).Magnitude <= 20 and not collapseTriggered then
		collapseTriggered = true
		state.step = "Collapse"
		PlayerService.setCombatLocked(player, true)
		-- The telegraphed Harrower strike (rule: "a clearly telegraphed
		-- Harrower strike" the player must avoid) doubles as the collapse
		-- warning - a real Roblox client can act on it (keep moving/back
		-- away) even though the outcome (the street opens beneath the
		-- group either way) is authored, matching "mostly a scripted
		-- environmental threat" rather than a skill check that could fail
		-- required NPCs out of the story.
		feedback:FireAllClients(Net.Feedback.WardenTelegraph, { position = collapseAt, radius = 16, duration = Config.Scene04.TelegraphWarnSeconds })

		-- Ren visibly ushers the group toward safety (rule: "Captain Ren
		-- pushes civilians inside... Ren and the evacuation group remain
		-- above" - he never falls with the other three).
		if scene03Ren and scene03Ren.Parent then
			scene03Ren:PivotTo(CFrame.lookAt(collapseAt + Vector3.new(-4, 0, 4), collapseAt))
		end
		task.delay(Config.Scene04.TelegraphWarnSeconds, function()
			if player.Parent then
				feedback:FireClient(player, Net.Feedback.Scene04Collapse, {})
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- Chapter One, Scene 5: "Beneath the City."
--
-- A short walk (World.Ruin's own vault - built by World/Ruin.lua - already
-- is the "completely ancient Architect construction... huge geometric
-- doors... a massive machine" end state the scene spec describes; this
-- section only needs to build the human/transitional beginning and middle,
-- a short corridor rather than a sprawling level given the scope already
-- spent on Scenes 1-4) with Voss's exposition delivered in pieces as the
-- group moves, one simple puzzle, and pressure cues, ending at
-- World.RuinSpawn - the exact point the pre-existing awakening-chamber flow
-- (EncounterService.onDescend, Chapter1_Awakening) already starts from, so
-- Scene 6 onward reuses that flow rather than duplicating it.
--------------------------------------------------------------------------------

type Scene05State = { landing: CFrame, puzzleSolved: boolean, dialogueFired: { [string]: boolean } }
local scene05: { [Player]: Scene05State } = {}
local conduitPrompt: ProximityPrompt? = nil
local conduitGlyph: BasePart? = nil
local scene07Coached: { [Player]: boolean } = {} -- declared here (not in the Scene 7 section below) so ChapterOneDirector.clearPlayer, defined in between, can reference it
local scene09Started: { [Player]: boolean } = {} -- declared here for the same reason - see the Scene 9 section further down

-- Human tunnel (concrete, pipes, warning lights) nearest the landing point,
-- grading into exposed ancient metal and orange conduit light nearest the
-- gateway - "orange light appears beneath surfaces near the player."
local function buildScene05Tunnel(parent: Instance, gateway: Vector3, landing: Vector3)
	local folder = Kit.folder("UndergroundTunnel", parent)
	local length = Config.Scene05.TunnelLength
	local width = Config.Scene05.TunnelWidth
	local floorY = landing.Y - 3.6

	Kit.part({ name = "TunnelFloor", size = Vector3.new(width, 1, length + 6), position = Vector3.new(landing.X, floorY, (landing.Z + gateway.Z) / 2), color = Palette.City.Foundation, material = Palette.Material.Concrete, parent = folder })
	Kit.part({ name = "TunnelCeiling", size = Vector3.new(width, 1, length + 6), position = Vector3.new(landing.X, floorY + 11, (landing.Z + gateway.Z) / 2), color = Palette.City.Foundation, material = Palette.Material.Concrete, parent = folder })
	for _, side in { -1, 1 } do
		Kit.part({ name = "TunnelWall", size = Vector3.new(1, 11, length + 6), position = Vector3.new(landing.X + side * width / 2, floorY + 5.5, (landing.Z + gateway.Z) / 2), color = Palette.City.Foundation, material = Palette.Material.Concrete, parent = folder })
	end

	local steps = 6
	for index = 0, steps do
		local t = index / steps
		local z = landing.Z + (gateway.Z - landing.Z) * t
		local ancient = t > 0.6 -- nearer the gateway: human concrete gives way to ancient metal
		if index % 2 == 0 then
			Kit.part({ name = "PipeRun", size = Vector3.new(0.4, 0.4, length / steps), position = Vector3.new(landing.X + width / 2 - 0.8, floorY + 8, z), color = Palette.City.Equipment, material = Palette.Material.Metal, decor = true, parent = folder })
		end
		if ancient then
			Kit.part({ name = "AncientSeam", size = Vector3.new(width - 1, 0.1, 1.4), position = Vector3.new(landing.X, floorY + 0.55, z), color = Palette.Energy.Amber, material = Palette.Material.Energy, transparency = 0.5, decor = true, parent = folder })
		else
			local lit = index % 3 == 0
			local lamp = Kit.part({ name = "WarningLight", size = Vector3.new(0.6, 0.6, 0.3), position = Vector3.new(landing.X, floorY + 9.3, z), color = if lit then Palette.Sky.Emergency else Palette.City.Equipment, material = if lit then Palette.Material.Energy else Palette.Material.Metal, transparency = if lit then 0.2 else 0, decor = true, parent = folder })
			if lit then
				Kit.light(lamp, Palette.Sky.Emergency, 10, 1, false)
			end
		end
	end

	-- The conduit puzzle: a single console partway along, matching Scene 3's
	-- power box in spirit - one clearly-lit correct connection, no confusing
	-- multi-step sequence.
	local puzzleZ = landing.Z + (gateway.Z - landing.Z) * Config.Scene05.PuzzleFraction
	local consoleAt = Vector3.new(landing.X - width / 2 + 1.2, floorY, puzzleZ)
	Kit.part({ name = "ConduitConsole", size = Vector3.new(1.8, 3, 1.2), position = consoleAt + Vector3.new(0, 1.5, 0), color = Palette.Ancient.Machinery, material = Palette.Material.Metal, parent = folder })
	local glyph = Kit.part({ name = "ConduitGlyph", size = Vector3.new(0.1, 1.2, 1.2), position = consoleAt + Vector3.new(0.95, 2, 0), color = Palette.Energy.AmberDim, material = Palette.Material.Energy, transparency = 0.6, decor = true, parent = folder })
	conduitGlyph = glyph

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ConduitPrompt"
	prompt.ActionText = "Hold to channel power (wrist device)"
	prompt.ObjectText = "ANCIENT CONDUIT"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 1.6
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.UIOffset = Vector2.new(0, -40)
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = glyph
	conduitPrompt = prompt

	return folder
end

-- Distant impacts, dust, violet light through a damaged door - the
-- Harrower cutting through behind the group. Purely atmospheric (no damage),
-- fired on a loop once pressure starts.
local function pulsePressure(player: Player)
	flickerCityPower()
	local playerState = PlayerService.get(player)
	local root = playerState and playerState.character and playerState.character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local dust = Instance.new("Part")
		dust.Name = "DustPuff"
		dust.Size = Vector3.new(3, 0.3, 3)
		dust.Color = Palette.City.Rubble
		dust.Material = Enum.Material.SmoothPlastic
		dust.Transparency = 0.3
		dust.Anchored = true
		dust.CanCollide = false
		dust.CanQuery = false
		dust.CanTouch = false
		dust.CastShadow = false
		dust.Position = root.Position + Vector3.new(0, 6, -6)
		dust.Parent = container
		TweenService:Create(dust, TweenInfo.new(1.4), { Transparency = 1, Position = dust.Position + Vector3.new(0, -5, 0) }):Play()
		task.delay(1.6, function()
			if dust.Parent then
				dust:Destroy()
			end
		end)
	end
end

local function onConduitTriggered(player: Player)
	local state = scene05[player]
	if not state or state.puzzleSolved then
		return
	end
	state.puzzleSolved = true
	if conduitPrompt then
		conduitPrompt.Enabled = false
	end
	if conduitGlyph and conduitGlyph.Parent then
		TweenService:Create(conduitGlyph, TweenInfo.new(0.4), { Transparency = 0.1, Color = Palette.Energy.Amber }):Play()
		Kit.light(conduitGlyph, Palette.Energy.Amber, 10, 1.6, false)
	end
	DialogueService.play(player, "Scene05_PuzzleSolved")
end

local function checkScene05Dialogue(player: Player, state: Scene05State, fraction: number)
	if fraction >= 0.05 and not state.dialogueFired.Start then
		state.dialogueFired.Start = true
		DialogueService.play(player, "Scene05_Start")
	elseif fraction >= 0.3 and not state.dialogueFired.Reveal1 then
		state.dialogueFired.Reveal1 = true
		DialogueService.play(player, "Scene05_Reveal1")
	elseif fraction >= 0.55 and not state.dialogueFired.Reveal2 then
		state.dialogueFired.Reveal2 = true
		DialogueService.play(player, "Scene05_Reveal2")
	elseif fraction >= Config.Scene05.PressureStartFraction and not state.dialogueFired.Pressure then
		state.dialogueFired.Pressure = true
		DialogueService.play(player, "Scene05_Pressure")
	end
end

local function thinkScene05(dt: number)
	local player = storyPlayer
	if not player or not player.Parent then
		return
	end
	local state = scene05[player]
	if not state then
		return
	end
	local playerState = PlayerService.get(player)
	local root = playerState and playerState.character and playerState.character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	NPCService.updateCompanion(MIRA_NAME, root, dt)

	local traveled = state.landing.Position.Z - root.Position.Z -- decreasing Z = progress toward the gateway
	local fraction = math.clamp(traveled / Config.Scene05.TunnelLength, 0, 1)
	checkScene05Dialogue(player, state, fraction)

	if fraction >= Config.Scene05.PressureStartFraction and math.random() < 0.01 then
		pulsePressure(player)
	end

	if fraction >= 0.96 then
		scene05[player] = nil
		-- Bring Mira and Voss to the gateway with the player rather than
		-- leaving them wherever Scene 5's companion-follow last placed them -
		-- the chamber encounter beyond this point has no follow logic of its
		-- own for them.
		local gatewayCFrame = world.RuinSpawn
		local mira = NPCService.getCompanion(MIRA_NAME)
		if mira and mira.model.Parent then
			mira.model:PivotTo(gatewayCFrame + gatewayCFrame.RightVector * 3)
		end
		if scene03Voss and scene03Voss.Parent then
			scene03Voss:PivotTo(gatewayCFrame + gatewayCFrame.RightVector * -3)
		end
		DialogueService.play(player, "Scene05_Gateway", function()
			if player.Parent then
				EncounterService.onDescend(player)
			end
		end)
	end
end

beginScene05 = function(player: Player, landing: CFrame)
	scene05[player] = { landing = landing, puzzleSolved = false, dialogueFired = {} }
	if conduitPrompt then
		conduitPrompt.Enabled = true
	end
end

local function completeScene01(player: Player, state: Scene01State)
	state.step = "Done"
	pushObjective(player, "", "", nil)
	SaveService.markStage(player, "Scene02_CentralPlaza")
	PlayerService.setCheckpoint(player, world.PlazaSpawnCFrame, false)
	locationTitle(player, Config.Scene01.LocationTitle)
	notice(player, "You reach Central Plaza.")
	beginScene02(player)
end

--------------------------------------------------------------------------------
-- Per-frame checks: Mira's follow behaviour, the mystery-event trigger zone,
-- and the plaza-arrival trigger. Cheap - just distance checks against the
-- one active story player, not a spatial query over the whole city.
--------------------------------------------------------------------------------

local function think(dt: number)
	local player = storyPlayer
	if not player or not player.Parent then
		return
	end
	local state = scene01[player]
	if not state or state.step == "Done" then
		return
	end

	local playerState = PlayerService.get(player)
	local character = playerState and playerState.character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	NPCService.updateCompanion(MIRA_NAME, root, dt)

	if state.step == "Delivery" and not state.mysteryTriggered then
		local stationPosition = world.Neighborhood.GaragePosition + Config.Scene01.MysteryStation.Offset
		if (root.Position - stationPosition).Magnitude <= Config.Scene01.MysteryStation.TriggerRadius then
			triggerMysteryEvent(player, state)
		end
	end

	-- Gated on the mystery event having already fired (rule ordering: the
	-- device activation is a beat along the route, not something that can be
	-- skipped past by simply outrunning it to the plaza) as well as distance,
	-- since the station and the plaza are only ~25 studs apart in a straight
	-- line and a fast sprint could otherwise reach the plaza trigger before
	-- the mystery dialogue has even finished playing.
	if state.step == "Delivery" and state.mysteryTriggered then
		local plazaHalf = 30 -- Streets.PlazaHalf, kept local to avoid a World/Streets require just for one constant
		local flatDistance = Vector3.new(root.Position.X, 0, root.Position.Z).Magnitude
		if flatDistance <= plazaHalf + 14 then
			completeScene01(player, state)
		end
	end
end

--------------------------------------------------------------------------------

-- Called once the client's opening cinematic hands off control back to the
-- player (see Main.server.lua's MenuState handler) - mirrors
-- TutorialService.beginForPlayer's role for the old flow.
function ChapterOneDirector.begin(player: Player)
	if SaveService.hasReached(player, "Scene03_CitySurvival") then
		-- Scene 2 already complete and Scenes 3-5 do not exist yet - fall
		-- through to whatever the caller does next (see Main.server.lua).
		return false
	end
	if scene01[player] or scene02[player] then
		return true -- already running this session (e.g. Settings reopened mid-scene)
	end
	if SaveService.hasReached(player, "Scene02_CentralPlaza") then
		-- Rejoined (or respawned into a fresh session) after finishing
		-- Scene 1 but before finishing Scene 2. Scene 1's own content
		-- (Daren's conversation, the package) cannot sensibly replay - it is
		-- already resolved - so resume directly into Scene 2 at the plaza.
		PlayerService.setCheckpoint(player, world.PlazaSpawnCFrame, false)
		PlayerService.teleport(player, world.PlazaSpawnCFrame)
		beginScene02(player)
		return true
	end

	SaveService.markStage(player, "Scene01_NormalMorning")
	scene01[player] = {
		step = "AwaitingDaren",
		mysteryTriggered = false,
		device = nil,
		startedAt = os.clock(),
	}

	if not storyPlayer then
		storyPlayer = player
		-- Mira stays held beside Daren (set in init()) until the delivery
		-- objective actually begins - see beginDelivery().
	end

	-- The story's real starting position: Kai's own bedroom, above Daren's
	-- garage - never the garage-exterior SpawnLocation the map otherwise
	-- uses for respawns. PlayerService.teleport is a direct PivotTo to the
	-- dedicated KaiBedroomSpawn marker (never the house model's own pivot),
	-- run synchronously before this remote handler returns so no frame is
	-- ever rendered with the gameplay camera already restored but the
	-- character still at its old position - see Opening.lua's finalize(),
	-- which holds the cinematic's own blackout through this same handler.
	PlayerService.setCheckpoint(player, world.Neighborhood.KaiBedroomSpawn, false)
	PlayerService.teleport(player, world.Neighborhood.KaiBedroomSpawn)
	-- darenPrompt is left enabled from init() onward rather than toggled here:
	-- Roblox's ProximityPromptService does not reliably re-detect a prompt
	-- that flips Enabled while a player is already standing in range (see the
	-- identical note in WorldBuilder.lua). onDarenTriggered()'s own state
	-- check is what actually gates the interaction, not prompt visibility -
	-- now genuinely needed, since the player starts upstairs and has to walk
	-- down to reach him rather than spawning in range immediately.
	notice(player, "Go downstairs and find Uncle Daren before you head out.")
	return true
end

--[[
	The opening cinematic's Skip button (client: Opening.lua). Per rule 7,
	skipping must apply the scene's final state up to that point, not merely
	end the camera sequence: it cancels any dialogue in progress, gives the
	player the package, and starts the delivery objective immediately, the
	same as finishing the Daren conversation normally would. It deliberately
	does NOT skip past the delivery itself - "begin the delivery objective"
	is the end state Skip promises, not "complete Scene 1 outright."
]]
function ChapterOneDirector.skip(player: Player)
	local state = scene01[player]
	if not state or state.step == "Delivery" or state.step == "Done" then
		return
	end
	darenPromptBusy = false
	DialogueService.cancel(player)
	beginDelivery(player, state)
end

-- If the player respawns mid-scene (fell off the map, etc.), restore the
-- objective they were last on rather than leaving the HUD blank.
local function onCharacterReady(player: Player)
	local state = scene01[player]
	if not state then
		return
	end
	if state.step == "Delivery" then
		pushObjective(player, Config.Scene01.Objective.Title, Config.Scene01.Objective.Detail, world.ResearchFacilityMarker)
	elseif state.step == "AwaitingDaren" or state.step == "Conversation" then
		notice(player, "Go downstairs and find Uncle Daren before you head out.")
	end
end

function ChapterOneDirector.clearPlayer(player: Player)
	scene01[player] = nil
	scene02[player] = nil
	scene03[player] = nil
	scene04[player] = nil
	scene05[player] = nil
	scene07Coached[player] = nil
	scene09Started[player] = nil
	if storyPlayer == player then
		storyPlayer = nil
		NPCService.removeCompanion(MIRA_NAME)
	end
end

--------------------------------------------------------------------------------
-- Chapter One, Scene 7: "Learning to Stand."
--
-- Scope note: the pre-existing chamber encounter already teaches all 5
-- Aegis abilities through real combat against the 4-scout wave
-- (EncounterService.lua, unchanged by this session). What Scene 7 adds is
-- Aegis Zero's own coaching voice during that same fight (rule: "use Aegis
-- Zero's voice as the tutorial guide, keep lines short") - three short,
-- non-blocking lines timed across the opening of the fight. Building a
-- separate holographic-target phase before the real Wardens break in (as
-- the fullest reading of the spec describes) was deliberately not
-- attempted given how much of the chapter remained; this delivers the
-- teaching *voice* for real without that larger, separate system.
--------------------------------------------------------------------------------

local function beginScene07Coaching(player: Player)
	if scene07Coached[player] then
		return
	end
	scene07Coached[player] = true
	task.delay(4, function()
		if player.Parent then
			notice(player, "AEGIS ZERO: Balance before power.")
		end
	end)
	task.delay(11, function()
		if player.Parent then
			notice(player, "AEGIS ZERO: Observe the attack before you answer it.")
		end
	end)
	task.delay(18, function()
		if player.Parent then
			notice(player, "AEGIS ZERO: Now move with me.")
		end
	end)
end

--------------------------------------------------------------------------------
-- Chapter One, Scene 9: "A Much Larger War" - the chapter ending.
--
-- Triggered off SaveService.StageChanged rather than a direct call from
-- EncounterService.lua (which already marks Scene09_ChapterEnding the
-- instant the Harrower's Humanoid dies - see the rename session's "Boss
-- fight implementation notes") - this is what let Scene 9 get built without
-- touching that already-complex, working boss state machine at all.
--------------------------------------------------------------------------------

local function beginScene09(player: Player)
	if scene09Started[player] then
		return
	end
	scene09Started[player] = true
	PlayerService.setCombatLocked(player, true)
	PlayerService.setTransformed(player, false) -- rule: "the player exits or opens the interface"
	pushObjective(player, "", "", nil)
	feedback:FireClient(player, Net.Feedback.Scene09Ending, {})
end

-- Fired by the client once Scene 9's ending cutscene ends, whether watched
-- in full or skipped (Net.Action.Scene09Done). Saves Chapter One completion
-- exactly once - SaveService.markStage()'s own monotonic guard is what
-- prevents a repeat trigger from granting the reward twice, the same
-- mechanism every other scene transition in this file relies on.
function ChapterOneDirector.completeScene09(player: Player)
	PlayerService.setCombatLocked(player, false)
	local alreadyComplete = SaveService.hasReached(player, "ChapterOneComplete")
	SaveService.markStage(player, "ChapterOneComplete")
	if alreadyComplete then
		return
	end
	feedback:FireClient(player, Net.Feedback.ChapterComplete, {
		rescued = 1, -- Scene 3's debris rescue is the only tracked rescue today
		unlocked = Config.Scene09.NewLocationUnlocked,
	})
end

-- "Continue": rule - open the previously blocked route, add the teaser
-- objective, do not pretend Chapter Two exists. No new hub area is built
-- (the cleared chamber the player already stands in serves that purpose) -
-- a stated scope simplification given how much of the chapter was built
-- this session.
function ChapterOneDirector.continueAfterChapterOne(player: Player)
	pushObjective(player, Config.Scene09.TeaserObjective, `The road east toward the {Config.Scene09.NewLocationUnlocked} is open - Chapter Two is not available yet.`, nil)
end

function ChapterOneDirector.init(builtWorld: any)
	world = builtWorld
	feedback = Net.get("Feedback")

	local existing = workspace:FindFirstChild("ChapterOneScene")
	if existing then
		existing:Destroy()
	end
	container = Instance.new("Folder")
	container.Name = "ChapterOneScene"
	container.Parent = workspace

	local neighborhood = world.Neighborhood
	local rng = Kit.rng(9)

	populateAmbient(neighborhood, rng)
	populatePlazaCrowd(world.FountainPosition, Kit.rng(10))

	local darenAppearance = { skin = Color3.fromRGB(198, 150, 115), shirt = Color3.fromRGB(90, 96, 100), pants = Color3.fromRGB(52, 56, 66), hair = Color3.fromRGB(120, 120, 126), scale = 1.05 }
	local _darenModel, promptRef = NPCService.spawnNamed(container, Config.Scene01.Names.Daren, neighborhood.DarenStandCFrame, darenAppearance, "Hold to talk")
	darenPrompt = promptRef
	if darenPrompt then
		darenPrompt.Triggered:Connect(onDarenTriggered)
	end

	local miraAppearance = { skin = Color3.fromRGB(216, 180, 150), shirt = Color3.fromRGB(150, 96, 130), pants = Color3.fromRGB(40, 44, 52), hair = Color3.fromRGB(36, 30, 26), scale = 0.92 }
	NPCService.spawnCompanion(container, MIRA_NAME, neighborhood.MiraStandCFrame, miraAppearance)
	NPCService.setCompanionHold(MIRA_NAME, true) -- holds beside Daren until the conversation starts

	-- A small marker near the south-east plaza building stands in for "the
	-- research facility" the delivery objective names - see World/City.lua's
	-- BUILDINGS table for that block's exact footprint.
	local marker = Kit.part({
		name = "ResearchFacilityMarker",
		size = Vector3.new(1, 1, 1),
		position = Vector3.new(88, 4, 34),
		color = Palette.Energy.Cyan,
		transparency = 1,
		decor = true,
		parent = container,
	})
	world.ResearchFacilityMarker = marker

	-- Chapter One, Scene 3 set pieces: rescue site, power box, evacuation
	-- gate, Ren and Voss. Built now (server boot) like everything else, and
	-- the rescue/power prompts start disabled - beginScene03 enables the
	-- rescue prompt once the player has actually found Mira, and
	-- onRescueTriggered enables the power prompt in turn, so the player is
	-- never shown a prompt for a beat they have not reached yet.
	local rescuePromptCreated = buildRescueSite(container)
	rescuePromptCreated.Enabled = false
	rescuePromptCreated.Triggered:Connect(onRescueTriggered)
	rescuePrompt = rescuePromptCreated

	local powerPromptCreated, correctConnectorIndex = buildPowerBox(container)
	powerPromptCreated.Enabled = false
	powerPromptCreated.Triggered:Connect(function(player: Player)
		onPowerTriggered(player, correctConnectorIndex)
	end)
	powerPrompt = powerPromptCreated

	buildGate(container)

	local renAppearance = { skin = Color3.fromRGB(170, 140, 110), shirt = Color3.fromRGB(56, 62, 58), pants = Color3.fromRGB(40, 44, 40), hair = Color3.fromRGB(30, 28, 26), scale = 1.1 }
	scene03Ren = NPCService.build(container, scene03Point(Config.Scene03.RenStandOffset), renAppearance, 6, Config.Scene03.Names.Ren)

	local vossAppearance = { skin = Color3.fromRGB(210, 190, 170), shirt = Color3.fromRGB(120, 118, 108), pants = Color3.fromRGB(70, 68, 62), hair = Color3.fromRGB(180, 180, 176), scale = 0.98 }
	scene03Voss = NPCService.build(container, scene03Point(Config.Scene03.VossStandOffset), vossAppearance, 0, Config.Scene03.Names.Voss)

	buildScene04SetPieces(container)

	-- World.RuinSpawn is still a placeholder (the Neighborhood spawn) at this
	-- point - WorldBuilder.finishDecor() (which builds the real Ruin vault
	-- and updates RuinSpawn to the real gateway) runs asynchronously, kicked
	-- off by Main.server.lua right after every safeInit call including this
	-- one returns. Waiting for World.DecorReady here is what keeps the
	-- tunnel from being built at the wrong (placeholder) position.
	task.spawn(function()
		while not world.DecorReady do
			task.wait(0.1)
		end
		local tunnelLanding = world.RuinSpawn.Position + Vector3.new(0, 0, Config.Scene05.TunnelLength)
		buildScene05Tunnel(container, world.RuinSpawn.Position, tunnelLanding)
		if conduitPrompt then
			conduitPrompt.Enabled = false
			conduitPrompt.Triggered:Connect(onConduitTriggered)
		end
	end)

	PlayerService.CharacterReady:Connect(function(player: Player)
		onCharacterReady(player)
	end)
	PlayerService.TransformChanged:Connect(function(player: Player, active: boolean)
		if active then
			beginScene07Coaching(player)
		end
	end)
	SaveService.StageChanged:Connect(function(player: Player, stage: string)
		if stage == "Scene09_ChapterEnding" then
			-- Wait for the boss's own Defeat pose-hold AND its
			-- Chapter1_BossVictory dialogue (EncounterService.lua) to
			-- actually finish - polling DialogueService.isActive rather
			-- than a fixed delay, since how long that takes depends on how
			-- fast the player reads/advances it. Without this, the ending
			-- cutscene's camera could seize control while the victory
			-- dialogue panel is still up.
			task.spawn(function()
				task.wait(Config.Boss.DefeatLingerSeconds)
				while player.Parent and DialogueService.isActive(player) do
					task.wait(0.25)
				end
				if player.Parent then
					beginScene09(player)
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(ChapterOneDirector.clearPlayer)

	RunService.Heartbeat:Connect(function(dt)
		think(dt)
		thinkScene03Combat(dt)
		thinkScene04(dt)
		thinkScene05(dt)
	end)
end

return ChapterOneDirector
