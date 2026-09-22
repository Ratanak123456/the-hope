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
	},
	Machinery = {
		-- Seamless tracked transport engine idle.
		VehicleEngineLoop = "",
		-- Tracks compressing snow and suspension movement.
		VehicleTracks = "",
		-- Heavy drill motor startup.
		DrillStart = "",
		-- Seamless rotary drilling through ice.
		DrillLoop = "",
		-- Drill tooth striking ancient metal.
		DrillHitsMetal = "",
		-- Heavy ancient door mechanisms grinding open.
		AncientDoorOpening = "",
		-- Motorized evacuation lift doors closing.
		EmergencyDoor = "",
		-- Massive metal links groaning under load.
		ChainTension = "",
		-- One huge chain snapping with ringing fragments.
		ChainBreak = "",
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
		-- Original Hale voice: Report.
		HaleReport = "",
		-- Original Voss voice: The signal is approximately two kilometers beneath us. Whatever is producing it is larger than anything humanity has ever built.
		VossSignal = "",
		-- Original Hale voice: A spacecraft?
		HaleSpacecraft = "",
		-- Original Voss voice: Possibly.
		VossPossibly = "",
		-- Original Lyra voice: It isn’t calling us.
		LyraCalling = "",
		-- Original Hale voice: Then what is it doing?
		HaleQuestion = "",
		-- Original Lyra voice: I don’t know yet.
		LyraUnknown = "",
		-- Original Hale voice: Begin drilling.
		HaleDrill = "",
		-- Original Voss voice: My God.
		VossAwe = "",
		-- Original Hale voice: How old is it?
		HaleAge = "",
		-- Original Voss voice: The surrounding ice is thousands of years old.
		VossIce = "",
		-- Original Hale voice: Then we have discovered the greatest weapon in human history.
		HaleWeapon = "",
		-- Original Lyra voice: No. It wasn’t buried here.
		LyraBuried = "",
		-- Original Lyra voice: It chose to remain.
		LyraRemain = "",
		-- Original Voss voice: Can you read it?
		VossRead = "",
		-- Original Lyra voice: Some of it.
		LyraSome = "",
		-- Original Lyra voice: The Guardian is the seal.
		LyraSeal = "",
		-- Original Soldier voice: The machine wasn’t protecting itself from them.
		SoldierPrison = "",
		-- Original Lyra voice: It was protecting us.
		LyraUs = "",
		-- Original Voss voice: My scanner shows no biological activity.
		VossBiology = "",
		-- Original Lyra voice: The ice is moving because it is waking up.
		LyraWaking = "",
		-- Original Lyra voice: Disconnect everything. We need to leave.
		LyraDisconnect = "",
		-- Original Hale voice: We did not cross half the planet to abandon humanity’s greatest discovery.
		HaleDiscovery = "",
		-- Original Lyra voice: It is holding the creature below us.
		LyraCreature = "",
		-- Original Hale voice: This machine may be the only defense humanity will ever need.
		HaleDefense = "",
		-- Original Lyra voice: It is already defending us.
		LyraDefending = "",
		-- Original Lyra voice: It isn’t an activation code.
		LyraCode = "",
		-- Original Hale voice: Then what is it?
		HaleCode = "",
		-- Original Lyra voice: It is asking for a new guardian.
		LyraGuardian = "",
		-- Original Hale voice: We did it.
		HaleSuccess = "",
		-- Original Lyra voice: No.
		LyraNo = "",
		-- Original Lyra voice: Turn off the power! It is fighting the activation!
		LyraPower = "",
		-- Original Hale voice: Seal the chamber!
		HaleSeal = "",
		-- Original Lyra voice: There is no seal anymore.
		LyraNoSeal = "",
		-- Original Voss voice: Lyra! We have to leave!
		VossLeave = "",
		-- Original Lyra voice: Can you stop it?
		LyraStop = "",
		-- Original Lyra voice: Then help me bury it again.
		LyraBury = "",
		-- Original Voss voice: I’m not leaving you!
		VossStay = "",
		-- Original Lyra voice: Someone has to tell them what happened here.
		LyraTell = "",
		-- Original Lyra voice: You protected our world for thousands of years.
		LyraYears = "",
		-- Original Lyra voice: Let us protect it together.
		LyraTogether = "",
		-- Original Lyra voice: The Guardian is not buried.
		LyraNotBuried = "",
	},
	Mix = {
		Radio = {Volume=0.65, PlaybackSpeed=1, Looped=false, SoundGroup="Dialogue"},
		Environment = {Volume=0.22, PlaybackSpeed=1, Looped=false, SoundGroup="Environment"},
		Machinery = {Volume=0.4, PlaybackSpeed=1, Looped=false, SoundGroup="Effects"},
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
		["Machinery.DrillLoop"] = {Looped=true},
	},
}
