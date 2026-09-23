--!strict
-- Only paste Roblox asset IDs authorized for this experience. Empty is safe.
-- Durations and subtitle text live in Sequences; audio never controls timing.
return {
	Radio = {
		-- Two opening expedition radio lines, with radio filtering.
		ExpeditionTransmission = "",
		-- Short radio squelch and static.
		RadioStatic = "",
		-- Three repeating subglacial signal pulses.
		SignalPulse = "",
		-- Radio link distortion and cutoff.
		CommunicationFailure = "",
	},
	Environment = {
		-- Seamless polar storm wind loop.
		ArcticWindLoop = "",
		-- Muffled wind inside an insulated research module.
		InteriorWind = "",
		-- Snow and ice grains striking metal cladding.
		SnowAgainstMetal = "",
		-- Seamless distant diesel generator hum.
		GeneratorLoop = "",
		-- Slow deep glacier creaks.
		IceCreaking = "",
		-- Deep impact beneath the command room.
		DeepIceImpact = "",
		-- The abandoned facility's room tone: a large, cold, sealed volume.
		-- Almost silence, with pressure. No wind - nothing moves in here.
		FacilityTone = "",
		-- Distant metal settling somewhere in the structure, once.
		SettlingMetal = "",
	},
	Machinery = {
		-- Seamless tracked transport engine idle.
		VehicleEngineLoop = "",
		-- Tracks compressing snow and suspension movement.
		VehicleTracks = "",
		-- Hot-water bore plant starting: pump spin-up, burner light-off, reel
		-- drive engaging. Three distinct events in one cue.
		BoreStart = "",
		-- Seamless bore plant running: pump note, burner roar, reel creep.
		BoreLoop = "",
		-- Line pressure collapsing: pump note rising as the load disappears,
		-- hose slapping the reel, one mechanical alarm. No musical sting.
		LinePressureLoss = "",
		-- Return flow stopping. Mostly the ABSENCE of the circulation the mix
		-- has carried for the whole montage, plus a console alert tone.
		ReturnLost = "",
		-- The bore head touching something hard and flat: a bright metallic
		-- contact quite unlike ice, reported through hose and steel.
		HardReturn = "",
		-- Expedition power connected to ancient hardware: cable slap,
		-- breakers closing, an inverter note.
		PowerConnection = "",
		-- The containment gate unlocking: dogs withdrawing, drums turning
		-- under load, two heavy leaves parting. Mechanical, never magical.
		GateUnlock = "",
		-- The chamber's iris separating under strain.
		SealSeparates = "",
		-- Motorized evacuation lift doors closing.
		EmergencyDoor = "",
		-- Massive metal links groaning under load.
		ChainTension = "",
		-- One huge chain snapping with ringing fragments.
		ChainBreak = "",
	},
	--[[
		ANCIENT MECHANISM. Deliberately its own category rather than more
		Machinery cues: the opening's whole visual grammar keeps human
		equipment, ancient equipment and the prisoner apart (see
		Instrumentation.lua's note), and the mix has to do the same. These
		should have no motor note and no electrical hum - resonance, stone,
		and very old metal moving for the first time in a long time.
	]]
	Ancient = {
		-- The seal key found in its cradle: frost breaking off worked metal.
		KeyFound = "",
		-- The key seating into the gate socket: a single deep mechanical
		-- acceptance, then a low tone rising inside the object itself.
		KeySeats = "",
		-- The lock housing waking: the glyph ring taking charge, mark by
		-- mark, then the circuit running away up the pier.
		LockEngages = "",
		-- Aegis Zero's chest band taking the same charge. The audience should
		-- recognise this as the SAME sound as LockEngages, one octave lower -
		-- it is the cue that says the door and the machine are one system.
		ChestBandLights = "",
	},
	Aegis = {
		-- Slow muted dormant core heartbeat.
		CorePulse = "",
		-- Power entering and accelerating the chest core.
		CoreActivation = "",
		-- Layered armor unlocking and shifting.
		ArmorMovement = "",
		-- Hand and wrist servos under strain.
		ServoMovement = "",
		-- Neck pistons lifting a damaged mechanical head.
		HeadMovement = "",
		-- Brief orange eye ignition.
		EyeActivation = "",
		-- Damaged mechanical cry under extreme load.
		MechanicalCry = "",
		-- Original Aegis voice: Seal failure.
		VoiceLineSealFailure = "",
		-- Original Aegis voice: Core insufficient.
		VoiceLineCoreInsufficient = "",
	},
	Alien = {
		-- Subsonic-feeling alien presence, mixed without excessive bass.
		LowRumble = "",
		-- Organic movement and pressure beneath ice.
		IceMovement = "",
		-- Quiet violet eye awakening.
		EyeActivation = "",
		-- Warden limbs breaking through frozen armor.
		WardenBreakout = "",
		-- Alien Warden emergence call.
		WardenScream = "",
		-- Original Sovereign voice: The Guardian rises.
		SovereignVoiceGuardianRises = "",
		-- Original Sovereign voice: The gate is open.
		SovereignVoiceGateOpen = "",
		-- Original Sovereign voice: The harvest may continue.
		SovereignVoiceHarvestContinue = "",
		-- The true signal surging as the containment fails - heard on the
		-- expedition's own instruments before it is heard in the room.
		SignalSurge = "",
		-- Alien signal escaping toward space.
		SignalTransmission = "",
	},
	Impacts = {
		-- Chamber-wide subterranean shock.
		UndergroundImpact = "",
		-- Close ice fractures and fragments.
		IceCracking = "",
		-- Contained machinery blast.
		ExplosionSmall = "",
		-- Distant massive reactor detonation.
		ReactorExplosion = "",
		-- Tower and expedition structure collapsing.
		FacilityCollapse = "",
		-- Muffled underwater falling debris.
		DebrisImpact = "",
	},
	Music = {
		-- Sparse Arctic arrival mystery score.
		ArcticMystery = "",
		-- Restrained wonder for the ancient guardian reveal.
		ScientificDiscovery = "",
		-- Escalating tension under Lyra’s translation.
		WarningTension = "",
		-- Mechanical activation score.
		AegisAwakening = "",
		-- Alien prison breach score.
		AlienAwakening = "",
		-- Urgent evacuation score.
		ExpeditionDisaster = "",
		-- Emotional sacrifice score with room for dialogue.
		LyraSacrifice = "",
		-- Quiet cosmic signal and carrier reveal.
		SpaceReveal = "",
		-- Final title theme with one strong initial hit.
		TitleTheme = "",
	},
	Dialogue = {
		-- One entry per spoken line, in the order the cinematic plays them, so
		-- this doubles as the recording script. Every id is empty until the
		-- project has authorized recordings; the opening plays correctly silent.
		-- Hale: Report.
		HaleReport = "",
		-- Voss: The signal is approximately two kilometres beneath us.
		VossSignal = "",
		-- Voss: Whatever is producing it is larger than anything humanity has ever built.
		VossScale = "",
		-- Hale: A spacecraft?
		HaleSpacecraft = "",
		-- Voss: Possibly.
		VossPossibly = "",
		-- Lyra: It isn’t calling us.
		LyraCalling = "",
		-- Hale: Then what is it doing?
		HaleQuestion = "",
		-- Lyra: I don’t know yet.
		LyraUnknown = "",
		-- Hale: Begin drilling.
		HaleDrill = "",
		-- Voss: Eleven hundred metres of ice, and the return is still clean.
		VossBorePlan = "",
		-- Voss: We have no return at all. The bore is in open space.
		VossVoid = "",
		-- Lyra: There is no cavity in this ice. There never has been.
		LyraNoCavity = "",
		-- Voss: Something down there is returning a flat signal. A machined surface.
		VossNonIce = "",
		-- Hale: Then stop boring and start digging. I want to stand on it.
		HaleWiden = "",
		-- Voss: It was sealed from the inside.
		VossSealedInside = "",
		-- Voss: There is no power anywhere in this structure. Not a volt.
		VossNoPower = "",
		-- Lyra: Nobody shut this down. They walked out of it.
		LyraWalkedOut = "",
		-- Hale: Can you open it?
		HaleOpenIt = "",
		-- Voss: There is no mechanism to force. It is waiting for something.
		VossNoMechanism = "",
		-- Lyra: These are the same marks. On the roof, in the corridor, on the door.
		LyraSameMarks = "",
		-- Voss: My God.
		VossAwe = "",
		-- Hale: How old is it?
		HaleAge = "",
		-- Voss: The surrounding ice is thousands of years old.
		VossIce = "",
		-- Hale: Then we have discovered the greatest weapon in human history.
		HaleWeapon = "",
		-- Lyra: No. It wasn’t buried here.
		LyraBuried = "",
		-- Lyra: It chose to remain.
		LyraRemain = "",
		-- Voss: Can you read it?
		VossRead = "",
		-- Hale: Below what?
		HaleBelowWhat = "",
		-- Lyra: I don’t know.
		LyraDontKnow = "",
		-- Hale: Then we wake it and we ask it.
		HaleWake = "",
		-- Lyra: Give me a week with that wall before you put a current through it.
		LyraWait = "",
		-- Hale: We did not cross half the planet to abandon humanity’s greatest discovery.
		HaleDiscovery = "",
		-- Lyra: Those are the marks from the door. The door and this machine are one thing.
		LyraSameSystem = "",
		-- Lyra: It isn’t an activation code.
		LyraCode = "",
		-- Hale: Then what is it?
		HaleCode = "",
		-- Lyra: It is asking for a new guardian.
		LyraGuardian = "",
		-- Hale: We did it.
		HaleSuccess = "",
		-- Voss: It was never the source. It has been sitting on top of the source.
		VossNotSource = "",
		-- Lyra: We weren’t waking a machine. We were opening a lock.
		LyraLock = "",
		-- Lyra: Turn off the power! It is fighting the activation!
		LyraPower = "",
		-- Lyra: No.
		LyraNo = "",
		-- Lyra: It is holding something down there. It has always been holding it down there.
		LyraCreature = "",
		-- Hale: Seal the chamber!
		HaleSeal = "",
		-- Lyra: There is no seal anymore.
		LyraNoSeal = "",
		-- Voss: Lyra! We have to leave!
		VossLeave = "",
		-- Lyra: Can you stop it?
		LyraStop = "",
		-- Lyra: Then help me bury it again.
		LyraBury = "",
		-- Voss: I’m not leaving you!
		VossStay = "",
		-- Lyra: Someone has to tell them what happened here.
		LyraTell = "",
		-- Lyra: You protected our world for thousands of years.
		LyraYears = "",
		-- Lyra: Let us protect it together.
		LyraTogether = "",
	},
	Mix = {
		Radio = {Volume=0.65, PlaybackSpeed=1, Looped=false, SoundGroup="Dialogue"},
		Environment = {Volume=0.22, PlaybackSpeed=1, Looped=false, SoundGroup="Environment"},
		Machinery = {Volume=0.4, PlaybackSpeed=1, Looped=false, SoundGroup="Effects"},
		Ancient = {Volume=0.5, PlaybackSpeed=1, Looped=false, SoundGroup="Effects"},
		Aegis = {Volume=0.55, PlaybackSpeed=1, Looped=false, SoundGroup="Effects"},
		Alien = {Volume=0.5, PlaybackSpeed=1, Looped=false, SoundGroup="Effects"},
		Impacts = {Volume=0.5, PlaybackSpeed=1, Looped=false, SoundGroup="Effects"},
		Music = {Volume=0.3, PlaybackSpeed=1, Looped=false, SoundGroup="Music"},
		Dialogue = {Volume=0.8, PlaybackSpeed=1, Looped=false, SoundGroup="Dialogue"},
	},
	-- Optional per-cue mix overrides; IDs above remain simple paste-in fields.
	Overrides = {
		["Environment.ArcticWindLoop"] = {Looped=true},
		["Environment.GeneratorLoop"] = {Looped=true},
		["Machinery.VehicleEngineLoop"] = {Looped=true},
		["Machinery.BoreLoop"] = {Looped=true},
		["Environment.FacilityTone"] = {Looped=true},
	},
}
