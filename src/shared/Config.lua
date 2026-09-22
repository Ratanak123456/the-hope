--!strict

return {
	Game = {
		Title = "THE DAY THE SKY BROKE",
		Version = "0.2.0 — UI Milestone",
		LocationLabel = "NOVA CITY",
		Tagline = "An old signal. A new pilot.",
	},

	-- Real chapter identity, matching EncounterService.OBJECTIVES and
	-- Dialogues.lua exactly - the welcome screen must never invent a
	-- different chapter title than the one the game actually uses in play.
	Chapters = {
		{
			id = "Chapter1",
			number = "01",
			title = "The Day the Sky Broke",
			description = "An ordinary morning in Nova City ends when the sky tears open. Deliver a package, survive the invasion, and awaken Aegis Zero to stand against the Harrower.",
		},
	},
	Aegis = {
		Scale = 2.25,
		WalkSpeed = 24,
		MaxHealth = 300,
		Abilities = {
			Combo = {
				Damage = { 22, 26, 42 },
				Range = 14,
				Reach = 8,
				Windup = { 0.16, 0.2, 0.34 },
				Active = { 0.1, 0.1, 0.14 },
				Recovery = { 0.22, 0.26, 0.58 },
				ResetTime = 1.15,
				ChargeGain = { 12, 14, 24 },
			},
			GroundSlam = {
				Damage = 55,
				Radius = 24,
				Windup = 0.68,
				Active = 0.12,
				Recovery = 0.72,
				Cooldown = 6,
				ChargeGain = 30,
			},
			ResonanceBolt = {
				Damage = 32,
				Speed = 150,
				Range = 150,
				Radius = 3.5,
				Windup = 0.28,
				Active = 1,
				Recovery = 0.3,
				Cooldown = 2.8,
				ChargeGain = 18,
			},
			ThrusterDash = {
				Distance = 28,
				Windup = 0.1,
				Active = 0.2,
				Recovery = 0.24,
				Cooldown = 3.5,
			},
			CoreBurst = {
				Damage = 110,
				Radius = 34,
				Windup = 1.05,
				Active = 0.18,
				Recovery = 1.15,
				Cooldown = 14,
				ChargeRequired = 100,
			},
		},
		TransformCooldown = 1.2,

		-- Transformation sequence. The first awakening plays in full; later
		-- ones use the shortened timing so repeat use is never a chore.
		TransformDuration = 2.1,
		TransformDurationRepeat = 1.05,
		RevertDuration = 0.55,
		-- Movement is locked until this fraction of the sequence has elapsed.
		MovementLockFraction = 0.6,
		-- Camera is pushed out this far while piloting Aegis Zero.
		CameraMinZoom = 22,
	},
	-- The Wardens: the Veyra Dominion's alien troops (grunts). The Harrower
	-- (Config.Boss below) is a scaled, apex variant of the same rig family.
	Warden = {
		Count = 4,
		MaxHealth = 100,
		WalkSpeed = 10,
		Damage = 12,
		AttackRange = 7,
		AttackCooldown = 1.4,
		AggroRange = 140,
		-- The telegraph plays for exactly this long before damage is applied,
		-- and the damage check uses the same AttackRange the warning shows.
		WindupTime = 0.55,
		-- The Warden stops while winding up, so the swing reads as committed.
		RecoverTime = 0.45,
	},
	Encounter = {
		-- Chapter 1 arena fight, the only encounter that exists today.
		Opening = {
			Name = "Awakening Chamber",
			SpawnSpread = 14,
			ForwardOffset = -25,
		},
		RetryFallbackSeconds = 20, -- safety respawn if the client never asks
	},
	-- The Harrower: Chapter 1's boss, fought once the four-scout wave
	-- (Encounter/Warden above) is cleared. See EncounterService.lua for the
	-- Hunter -> Signal -> Desperation -> Defeated state machine.
	Boss = {
		Name = "The Harrower",
		MaxHealth = 900,
		WalkSpeed = 14,
		Scale = 1.85, -- rig scale relative to a scout Warden

		ClawDamage = 26,
		ClawRange = 12,
		ClawWindup = 0.6,
		ClawRecover = 0.5,
		ClawCooldown = 2.4,

		-- Telegraphs a circle at the target's position, then the boss moves
		-- there and detonates - the "leap" attack.
		LeapDamage = 30,
		LeapRadius = 13,
		LeapWindup = 0.75,
		LeapRecover = 0.55,
		LeapCooldown = 6,

		-- A line of telegraphed bursts from the boss toward its target,
		-- resolved as one capsule-shaped hit check at the end of the windup.
		LineDamage = 22,
		LineRadius = 9,
		LineLength = 55,
		LineSteps = 3,
		LineWindup = 0.65,
		LineRecover = 0.6,
		LineCooldown = 8,

		-- Desperation-phase only: a large telegraphed ring centred on the boss.
		ShockringDamage = 34,
		ShockringRadius = 38,
		ShockringWindup = 0.9,
		ShockringRecover = 0.7,
		ShockringCooldown = 7,

		-- Phase thresholds, read against Humanoid.Health / MaxHealth.
		SignalHealthFraction = 0.65,
		DesperationHealthFraction = 0.30,
		SignalAddCount = 2,
		SignalAddHealth = 70,
		PylonCount = 2,
		PylonHealth = 90,
		-- Incoming damage is multiplied by this while the Signal-phase pylons
		-- still stand, rather than blocked outright - destroying them is always
		-- a speed-up, never a hard requirement, so the fight can never soft-lock.
		ShieldDamageMultiplier = 0.35,
		DesperationWalkSpeed = 20,
		DesperationCooldownScale = 0.65, -- attacks recur faster once desperate
		DefeatLingerSeconds = 2.6, -- time the defeated body stays before cleanup
	},
	Dialogue = {
		MinSecondsPerLine = 0.35, -- floor before a client ack is believed
		MaxSecondsPerLine = 30, -- server-side auto-advance backstop
		CharsPerSecond = { Slow = 22, Normal = 42, Fast = 75 },
	},
	Limits = {
		-- requests allowed per window (seconds) per player, per remote
		Attack = { count = 12, window = 1 },
		Transform = { count = 5, window = 2 },
		Action = { count = 20, window = 2 },
		Prompt = { count = 4, window = 2 },
	},
	World = {
		ShowBoundaries = false,
		RecoveryPollSeconds = 0.2,
		SafeSampleSeconds = 0.6,
		RecoveryDebounceSeconds = 1.5,
		City = {
			Center = Vector3.new(0, 48, 0),
			HalfSize = Vector3.new(178, 72, 178),
			FallY = -32,
			SafeFallback = CFrame.lookAt(Vector3.new(0, 4, 48), Vector3.new(0, 4, 0)),
		},
		Ruin = {
			Center = Vector3.new(0, -92, 0),
			HalfSize = Vector3.new(67, 58, 67),
			FallY = -178,
			SafeFallback = CFrame.lookAt(Vector3.new(0, -146, 44), Vector3.new(0, -146, 0)),
		},
		-- The dusk-invasion mood (read by World/Sky.lua's revealInvasion()),
		-- active from Chapter One Scene 2 onward. MenuScene.lua's temporary
		-- "dawn hangar" Lighting swap restores to these exact values on exit
		-- rather than a runtime snapshot, which would race against Sky.lua's
		-- own async setup and could restore stale pre-Sky values over the
		-- real gameplay mood.
		Lighting = {
			ClockTime = 17.4,
			Brightness = 2.2,
			ExposureCompensation = 0.05,
			ColorShiftTop = Color3.fromRGB(24, 20, 10),
			ColorShiftBottom = Color3.fromRGB(8, 12, 20),
		},
		-- Chapter One Scene 1's peaceful morning mood: warm sun, light haze, a
		-- clean blue sky - active by default until Sky.revealInvasion() runs.
		MorningLighting = {
			ClockTime = 8.4,
			Brightness = 3,
			ExposureCompensation = 0.1,
			ColorShiftTop = Color3.fromRGB(20, 14, 4),
			ColorShiftBottom = Color3.fromRGB(6, 8, 4),
		},
	},
	-- Chapter One, Scene 1: "A Normal Morning" - names, positions, objective
	-- text and mystery-event timing/positions. All configurable per rule 15.
	-- Positions are resolved relative to World.Neighborhood at runtime
	-- (ChapterOneDirector reads the real built positions); the numbers here
	-- are the *offsets/relative* tuning knobs, not absolute world studs,
	-- except where noted.
	Scene01 = {
		Names = {
			Daren = "UNCLE DAREN",
			Mira = "MIRA",
			Player = "KAI",
		},
		Objective = {
			Title = "Morning Delivery",
			Detail = "Deliver the energy regulator to the research facility near Central Plaza.",
		},
		-- The abandoned station where the wrist device first activates -
		-- placed along the route between the neighborhood and the plaza.
		MysteryStation = {
			Offset = Vector3.new(20, 0, -15), -- relative to the neighborhood garage - roughly midway to the plaza
			TriggerRadius = 18,
		},
		LocationTitle = "Central Plaza — 11:47 AM",
		ControlTips = {
			Walk = "WASD / Left Stick to move",
			Sprint = "Hold Shift / Click Stick to sprint",
			Jump = "Space / A to jump",
			Interact = "E / X to interact",
		},
	},

	-- Chapter One, Scene 3's temporary human-form combat kit (rule: "a
	-- temporary emergency staff... the player is still human and should feel
	-- vulnerable"). Deliberately much weaker than Config.Aegis - low health,
	-- short range, no combo chain. See CombatService.lua's castHuman* casts,
	-- gated on the player's "HasEmergencyStaff" attribute rather than
	-- PlayerService.isTransformed (this all happens well before Scene 6's
	-- awakening).
	HumanCombat = {
		MaxHealth = 60,
		Strike = { Damage = 14, Range = 7, Reach = 4, Windup = 0.22, Active = 0.12, Recovery = 0.28, Cooldown = 0.5 },
		Shove = { Damage = 4, Radius = 7, Knockback = 26, Windup = 0.2, Active = 0.1, Recovery = 0.32, Cooldown = 2.2 },
		Dodge = { Distance = 14, Windup = 0.05, Active = 0.16, Recovery = 0.18, Cooldown = 1.6, IFrameSeconds = 0.4 },
	},

	-- Chapter One, Scene 3: "Survival Through Nova City."
	Scene03 = {
		Names = {
			Ren = "CAPTAIN REN",
			Voss = "DR. ELIAN VOSS",
		},
		-- All positions are relative to World.FountainPosition.
		RescueOffset = Vector3.new(-25, 0, -15),
		PowerBoxOffset = Vector3.new(30, 0, -20),
		GateOffset = Vector3.new(34, 0, -24),
		RenStandOffset = Vector3.new(30, 0, -14),
		VossStandOffset = Vector3.new(26, 0, -16),
		ScoutCount = 2,
		ScoutMaxHealth = 70,
		RescueHoldSeconds = 2.2,
		PowerConnectorColors = { Color3.fromRGB(214, 62, 170), Color3.fromRGB(84, 214, 218), Color3.fromRGB(240, 176, 78) },
		Objectives = {
			FindMira = { title = "Regroup with Mira", detail = "She's behind the damaged market stalls." },
			Rescue = { title = "Free the trapped survivors", detail = "Hold to clear the debris." },
			Power = { title = "Restore power to the evacuation gate", detail = "Reconnect the matching power line." },
			Combat = { title = "Hold the line", detail = "Wardens are closing in on the survivors." },
			Ending = { title = "Reach the Eastern Shelter", detail = "Stay with Captain Ren's group." },
		},
	},

	-- Chapter One, Scene 5: "Beneath the City."
	Scene05 = {
		-- The landing point (see ChapterOneDirector.applyScene04EndState) is
		-- this far back from World.RuinSpawn (the vault gateway) along its
		-- own -Z axis, opening up a short corridor to walk rather than
		-- landing directly at the reveal.
		TunnelLength = 18, -- kept well inside Config.World.Ruin.HalfSize (67 studs) from World.RuinSpawn's z=44
		TunnelWidth = 10,
		PuzzleFraction = 0.6, -- how far along the tunnel the conduit puzzle sits (0 = landing, 1 = gateway)
		-- Deliberately after the Reveal1 (0.3) and Reveal2 (0.55) dialogue
		-- thresholds in ChapterOneDirector.checkScene05Dialogue, so the
		-- pressure line can never fire the same tick as (and pre-empt) an
		-- exposition line still being read.
		PressureStartFraction = 0.7,
	},

	-- Chapter One, Scene 9: "A Much Larger War" - the chapter ending.
	Scene09 = {
		ChapterTitle = "CHAPTER ONE COMPLETE",
		ChapterSubtitle = "The Day the Sky Broke",
		NewLocationUnlocked = "Resistance Outpost",
		TeaserObjective = "Reach the Resistance Outpost",
	},

	-- Chapter One, Scene 4: "The Hunter's Pursuit."
	Scene04 = {
		-- Positions relative to World.FountainPosition, continuing the route
		-- east from Scene 3's gate.
		CollapseOffset = Vector3.new(70, 0, -40),
		MiraGapOffset = Vector3.new(52, 0, -32),
		SoldierOffsets = { Vector3.new(40, 0, -28), Vector3.new(46, 0, -36) },
		TelegraphWarnSeconds = 1.6,
		FallCFrameOffsets = {
			Player = Vector3.new(0, 0, 0),
			Mira = Vector3.new(4, 0, 2),
			Voss = Vector3.new(-4, 0, 2),
		},
	},

	-- Chapter One, Scene 2: "The Sky Breaks."
	Scene02 = {
		PreInvasionSeconds = 6, -- ordinary plaza time before the sky starts to turn
		Objective = {
			Title = "Find Mira and escape the plaza",
			Detail = "Get clear of the wreckage and regroup.",
		},
		Warden = {
			MaxHealth = 100, -- matches Config.Warden.MaxHealth; kept separate so Scene 2's reveal can be tuned without touching combat balance
			WalkSpeed = 10,
		},
		PodImpactOffset = Vector3.new(0, 0, -6), -- relative to FountainPosition
		CoverOffset = Vector3.new(0, 0, 6), -- relative to FountainPosition - where the player/Mira end up after diving for cover
	},

	-- Chapter One, Scene 1: Uncle Daren's neighborhood, ambient civilians and
	-- Mira's companion follow behaviour. All configurable per rule 15.
	Neighborhood = {
		AmbientCount = 16, -- total ambient civilians spawned for Scene 1 (rule 11: capped, not unlimited)
		AmbientWalkSpeed = 8,
		CompanionWalkSpeed = 15, -- slightly faster than the player's base 16 so Mira can catch up
		CompanionFollowDistance = 7, -- stops trying to close the gap once this close (never stands on the player)
		CompanionRecoveryDistance = 55, -- teleport-to-recovery threshold if she falls this far behind
		CompanionStuckSeconds = 4.5, -- if no progress is made toward the player for this long, recover in place
	},

	-- Onboarding: the guide NPC, the launch-platform marker and the training
	-- dummy used to teach transform / strike / dodge / skill before the real
	-- Chapter 1 encounter. Entirely separate from EncounterService's state.
	Tutorial = {
		DummyHealth = 600, -- generous: survives every practice hit across steps
		DummyWalkSpeed = 0, -- stationary, never fights back
		GuideInteractRange = 9,
		MarkerReachRange = 10,
		DefenseTelegraphRadius = 11,
		DefenseTelegraphDuration = 1.4, -- slower than a real Warden windup (0.55s) - readable on purpose
		DefenseRetryInterval = 5.5, -- re-shows the telegraph if the player has not dashed yet
		StepTimeoutSeconds = 45, -- gentle reminder nudge, never a hard block - Skip Training always works
	},

	-- Opening cinematic: "THE GUARDIAN BENEATH THE ICE" - a prequel cold open
	-- (15 years before the main story) that plays once, after Start Game and
	-- before Chapter One Scene 1 begins. Client-local only: no shared
	-- instances, so one player's playback or skip never touches anyone
	-- else's - see src/client/Opening.lua and src/client/NorthPole/.
	Cinematic = {
		TotalTargetSeconds = 210,
		Debug = { Enabled = false, StartShot = 1, Paused = true },
		SkipHoldSeconds = 0.85, -- "Hold to Skip": long enough to prevent an accidental tap
		Names = {
			Lyra = "DR. LYRA REN",
			Voss = "DR. ELIAN VOSS",
			Hale = "GENERAL CORVIN HALE",
			Soldier = "SOLDIER",
			Scientist = "SCIENTIST",
			Sovereign = "THE SOVEREIGN BELOW",
			Aegis = "AEGIS ZERO",
			Radio = "RADIO",
		},
		-- Shot durations: NorthPole/Sequences.lua; sounds: OpeningAudioConfig.

	},

	Input = {
		TransformKey = Enum.KeyCode.Q,
		SlamKey = Enum.KeyCode.R,
		BoltKey = Enum.KeyCode.F,
		DashKey = Enum.KeyCode.LeftShift,
		UltimateKey = Enum.KeyCode.X,
		TransformGamepadKey = Enum.KeyCode.ButtonY,
		PrimaryGamepadKey = Enum.KeyCode.ButtonR2,
		SlamGamepadKey = Enum.KeyCode.ButtonX,
		BoltGamepadKey = Enum.KeyCode.ButtonR1,
		DashGamepadKey = Enum.KeyCode.ButtonB,
		UltimateGamepadKey = Enum.KeyCode.ButtonL1,
		AdvanceKeys = { Enum.KeyCode.E, Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.ButtonA },
		InteractKey = Enum.KeyCode.E,
		MenuKey = Enum.KeyCode.Escape, -- reserved by Roblox; we use Backquote
		PauseKey = Enum.KeyCode.M,
	},
}
