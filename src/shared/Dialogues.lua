-- strict
-- Dialogue content. Sequences are played by the server (DialogueService) so
-- that anything gated behind a conversation stays server-authoritative.

export type Choice = {
	id: string,
	text: string,
}

export type Line = {
	speaker: string,
	text: string,
	choices: { Choice }?, -- only meaningful on the final line of a sequence
}

export type Sequence = {
	id: string,
	lines: { Line },
}

local AEGIS = "AEGIS ZERO"
local DAREN = "UNCLE DAREN"
local MIRA = "MIRA"
local KAI = "KAI"
local REN = "CAPTAIN REN"
local VOSS = "DR. ELIAN VOSS"

local Dialogues: { [string]: Sequence } = {
	--------------------------------------------------------------------------
	-- Chapter One, Scene 1: "A Normal Morning"
	--------------------------------------------------------------------------

	Scene01_DarenDelivery = {
		id = "Scene01_DarenDelivery",
		lines = {
			{ speaker = DAREN, text = "Kai, the research center needs this regulator before noon." },
			{ speaker = KAI, text = "What does it control?" },
			{ speaker = DAREN, text = "Something they refuse to explain—and something they're paying us not to ask about." },
			{ speaker = MIRA, text = "That sounds completely safe." },
			{ speaker = DAREN, text = "Take the main avenue. And try to reach school before tomorrow." },
		},
	},

	-- A short ambient exchange, played once shortly after the delivery
	-- objective begins - not gating anything, just a beat of city-life colour.
	Scene01_MiraEarly = {
		id = "Scene01_MiraEarly",
		lines = {
			{ speaker = MIRA, text = "You're actually early today. Should I be worried?" },
			{ speaker = KAI, text = "Give it five minutes." },
		},
	},

	-- Played once, near the abandoned station, when the wrist device first
	-- activates (see ChapterOneDirector.lua's mystery-event trigger).
	Scene01_MysteryDevice = {
		id = "Scene01_MysteryDevice",
		lines = {
			{ speaker = KAI, text = "Did you see that?" },
			{ speaker = MIRA, text = "See what?" },
			{ speaker = KAI, text = "Nothing. I thought this thing moved." },
			{ speaker = MIRA, text = "The broken watch?" },
			{ speaker = KAI, text = "It belonged to my mother." },
		},
	},

	--------------------------------------------------------------------------
	-- Chapter One, Scene 3: "Survival Through Nova City"
	--------------------------------------------------------------------------

	Scene03_FindMira = {
		id = "Scene03_FindMira",
		lines = {
			{ speaker = MIRA, text = "Kai! Over here—I'm okay, I'm okay." },
			{ speaker = KAI, text = "Stay close. We move together." },
		},
	},

	Scene03_RescueComplete = {
		id = "Scene03_RescueComplete",
		lines = {
			{ speaker = MIRA, text = "Got them. Go, go!" },
		},
	},

	Scene03_PowerRestored = {
		id = "Scene03_PowerRestored",
		lines = {
			{ speaker = KAI, text = "That should hold the gate open." },
		},
	},

	-- The Warden Recognition Moment.
	Scene03_Recognition = {
		id = "Scene03_Recognition",
		lines = {
			{ speaker = VOSS, text = "Lyra's key. It finally awakened." },
			{ speaker = KAI, text = "You knew my mother?" },
		},
	},

	Scene03_HarrowerRises = {
		id = "Scene03_HarrowerRises",
		lines = {
			{ speaker = REN, text = "Everyone move! Eastern station, now!" },
		},
	},

	--------------------------------------------------------------------------
	-- Chapter One, Scene 4: "The Hunter's Pursuit"
	--------------------------------------------------------------------------

	Scene04_MiraGap = {
		id = "Scene04_MiraGap",
		lines = {
			{ speaker = MIRA, text = "Kai, I can't get across—help me!" },
		},
	},

	Scene04_Collapse = {
		id = "Scene04_Collapse",
		lines = {
			{ speaker = REN, text = "It's found us. Inside, now, all of you!" },
			{ speaker = KAI, text = "Mira, Voss, move!" },
		},
	},

	Scene04_Underground = {
		id = "Scene04_Underground",
		lines = {
			{ speaker = VOSS, text = "Is everyone... we're alive. We're alive." },
			{ speaker = MIRA, text = "Kai? My leg—I think I twisted it." },
			{ speaker = KAI, text = "Lean on me. We'll find another way to the shelter." },
		},
	},

	--------------------------------------------------------------------------
	-- Chapter One, Scene 5: "Beneath the City" - exploration dialogue,
	-- delivered in small pieces as the group walks rather than one long
	-- exposition dump.
	--------------------------------------------------------------------------

	Scene05_Start = {
		id = "Scene05_Start",
		lines = {
			{ speaker = VOSS, text = "This tunnel predates the transit system. I know it - there should be another way through." },
			{ speaker = MIRA, text = "This place isn't human." },
			{ speaker = VOSS, text = "No. It was here before humanity." },
		},
	},

	Scene05_Reveal1 = {
		id = "Scene05_Reveal1",
		lines = {
			{ speaker = VOSS, text = "Fifteen years ago, a research team found something impossible at the edge of the world. I was part of it." },
			{ speaker = KAI, text = "My mother was on that team." },
			{ speaker = VOSS, text = "She led it." },
		},
	},

	Scene05_Reveal2 = {
		id = "Scene05_Reveal2",
		lines = {
			{ speaker = VOSS, text = "We found a dormant machine, guarding something far worse beneath it. When the officials tried to force it awake, Lyra sealed it all away again." },
			{ speaker = KAI, text = "My mother died protecting this thing?" },
			{ speaker = VOSS, text = "I don't know if she died." },
		},
	},

	Scene05_Pressure = {
		id = "Scene05_Pressure",
		lines = {
			{ speaker = MIRA, text = "Kai, it's getting closer." },
		},
	},

	Scene05_PuzzleSolved = {
		id = "Scene05_PuzzleSolved",
		lines = {
			{ speaker = VOSS, text = "The old conduits are answering it. Whatever your mother left you, it still works." },
		},
	},

	Scene05_Gateway = {
		id = "Scene05_Gateway",
		lines = {
			{ speaker = VOSS, text = "The Aegis cannot be forced to obey. You must choose each other." },
		},
	},

	-- Scene 6, "The Awakening": the wrist device floats free and the memory
	-- sequence plays (fragmented visions of the Architect/Veyra war and
	-- Lyra herself, standing in this same chamber) before Aegis Zero
	-- addresses the player directly. The visions are narrated in dialogue
	-- text rather than a separate visual flashback cinematic - a stated
	-- scope simplification - but Lyra's recorded line is her exact quoted
	-- words from story.txt, not a paraphrase.
	Chapter1_Awakening = {
		id = "Chapter1_Awakening",
		lines = {
			{ speaker = AEGIS, text = "Resonance detected. That is... not possible." },
			{ speaker = AEGIS, text = "I have slept since the Architects fell - beneath the ice, and then beneath this city - and I have not felt a bloodline in a very long time." },
			{ speaker = KAI, text = "(Fragmented images - burning planets, ancient battles, the Architects standing against the Veyra Dominion.)" },
			{ speaker = KAI, text = "(A woman stands in this same chamber. Mother.)" },
			{ speaker = "LYRA — RECORDING", text = "If you are seeing this, Kai, then I failed to stop them from finding Earth." },
			{ speaker = AEGIS, text = "The sky above you is tearing open again. The Veyra Dominion has come back to finish what it started." },
			{ speaker = AEGIS, text = "I will not hand my strength to someone who cannot hold it. But this chamber is already breached — so you will have to prove it the hard way." },
			{ speaker = AEGIS, text = "Bond accepted, provisionally. Awaken with me." },
		},
	},

	-- The Synchronization exchange, spoken the moment the player commits by
	-- transforming for the first time - functionally, pressing the Transform
	-- control IS "Synchronize" (rule: "Not Yet" must not be a dead end, and
	-- the player is always free to keep exploring and simply not press it,
	-- with the prompt effectively always available rather than a one-shot
	-- choice that could be missed).
	Chapter1_FirstTransform = {
		id = "Chapter1_FirstTransform",
		lines = {
			{ speaker = AEGIS, text = "Why do you want my power?" },
			{ speaker = KAI, text = "I can't let them hurt anyone else." },
			{ speaker = AEGIS, text = "A perfect warrior was never required. Only a reason to stand." },
			{ speaker = KAI, text = "Then stand with me." },
			{ speaker = AEGIS, text = "The armour holds. Wardens are coming through the breach — clear the chamber." },
		},
	},

	-- Played the instant the four-scout wave is cleared, before the Harrower
	-- itself appears - see EncounterService.lua.
	Chapter1_Victory = {
		id = "Chapter1_Victory",
		lines = {
			{ speaker = AEGIS, text = "The chamber is clear. That was a scout pack — the Dominion knows where you are now." },
			{ speaker = AEGIS, text = "Rest while you can, pilot. It will send something larger next." },
		},
	},

	Chapter1_BossSignal = {
		id = "Chapter1_BossSignal",
		lines = {
			{ speaker = AEGIS, text = "It is calling for support — more Wardens, and it just armed a pair of relay pylons." },
			{ speaker = AEGIS, text = "Break the pylons. They are feeding its shield." },
		},
	},

	-- The finishing sequence (rule: "do not immediately destroy the boss...
	-- trigger a short finishing cinematic... Kai moves between them and
	-- catches its blade... 'Not them'... breaks the blade and delivers the
	-- finishing strike"). EncounterService.lua already holds the defeated
	-- body in a "Defeat" pose for Config.Boss.DefeatLingerSeconds before
	-- cleanup rather than destroying it instantly, and plays this sequence
	-- the instant the kill lands - narrated here rather than staged as a
	-- separate camera cinematic, a stated scope simplification given how
	-- much of the chapter remained when this was built.
	Chapter1_BossVictory = {
		id = "Chapter1_BossVictory",
		lines = {
			{ speaker = KAI, text = "(It turns its last strike toward Mira and the transport.)" },
			{ speaker = KAI, text = "Not them." },
			{ speaker = KAI, text = "(The blade catches in Aegis Zero's hands. Orange wings of energy open behind the armour.)" },
			{ speaker = AEGIS, text = "The Harrower is down. But that signal reached the Dominion before it fell — they know exactly where you are now." },
			{ speaker = AEGIS, text = "Rest while you can, pilot. It will send something larger next." },
		},
	},

	Chapter1_Defeat = {
		id = "Chapter1_Defeat",
		lines = {
			{ speaker = AEGIS, text = "The bond broke. I can rebuild it — but the chamber will reset with you." },
		},
	},

	Locked_NotReady = {
		id = "Locked_NotReady",
		lines = {
			{ speaker = AEGIS, text = "You are not bonded to anything yet. Find the signal beneath the city." },
		},
	},

	--------------------------------------------------------------------------
	-- Guide onboarding. Aegis Zero projects a field presence at the launch
	-- platform so a brand-new pilot has someone to meet before the vault.
	--------------------------------------------------------------------------

	Guide_Greeting = {
		id = "Guide_Greeting",
		lines = {
			{ speaker = AEGIS, text = "Good, you're here. Let's check your systems before you face what's waiting." },
			{ speaker = AEGIS, text = "Head for the platform marker up ahead — I'll walk you through the rest." },
		},
	},

	Guide_Transform = {
		id = "Guide_Transform",
		lines = {
			{ speaker = AEGIS, text = "Bring me online. Press Q — or your bound control — to transform." },
		},
	},

	Guide_BasicAttack = {
		id = "Guide_BasicAttack",
		lines = {
			{ speaker = AEGIS, text = "Try a basic strike on the target. Watch your reach." },
		},
	},

	Guide_Defense = {
		id = "Guide_Defense",
		lines = {
			{ speaker = AEGIS, text = "Now the important part. When you see a pulse telegraphed like this, dash clear of it with your thrusters." },
		},
	},

	Guide_Skill = {
		id = "Guide_Skill",
		lines = {
			{ speaker = AEGIS, text = "Try your Resonance Bolt on the target. It fires an energy blast on a short cooldown — no charge needed." },
		},
	},

	Guide_EnterFight = {
		id = "Guide_EnterFight",
		lines = {
			{ speaker = AEGIS, text = "You're ready. The signal is below — head for the entrance." },
			{ speaker = AEGIS, text = "Watch the Wardens' movements and strike when they leave an opening." },
		},
	},

	Guide_Menu = {
		id = "Guide_Menu",
		lines = {
			{
				speaker = AEGIS,
				text = "Systems are green. What do you need?",
				choices = {
					{ id = "status", text = "What should I do?" },
					{ id = "explain", text = "Explain the controls." },
					{ id = "practice", text = "Practice again." },
					{ id = "bye", text = "Goodbye." },
				},
			},
		},
	},

	Guide_ExplainControls = {
		id = "Guide_ExplainControls",
		lines = {
			{ speaker = AEGIS, text = "Q transforms. Left click strikes. R slams. F fires a bolt. Shift dashes clear of danger." },
			{ speaker = AEGIS, text = "Once your core is charged, your ultimate lights up on the action bar." },
		},
	},

	Guide_PracticeAcknowledge = {
		id = "Guide_PracticeAcknowledge",
		lines = {
			{ speaker = AEGIS, text = "Understood. Setting up the marker again — take your time." },
		},
	},

	Guide_Farewell = {
		id = "Guide_Farewell",
		lines = {
			{ speaker = AEGIS, text = "Go carefully, pilot." },
		},
	},
}

return Dialogues
