# Opening audio asset checklist

Every ID is currently empty. Obtain original or licensed recordings and grant this experience permission to use the uploaded Roblox assets. Paste IDs into `src/shared/OpeningAudioConfig.lua`. No timing changes are necessary.

This file mirrors that config field for field; if the two ever disagree, the config is the source of truth.

Three sound identities are kept strictly apart, the same way the picture keeps them apart: the expedition's own machinery (`Machinery`, `Environment`, `Radio`), the ancient installation (`Ancient`, `Aegis`), and the prisoner beneath it (`Alien`). Nothing should be reusable across those three groups.

## Radio

| Config field | Required recording |
| --- | --- |
| `Radio.ExpeditionTransmission` | Two opening expedition radio lines, with radio filtering. |
| `Radio.RadioStatic` | Short radio squelch and static. |
| `Radio.SignalPulse` | Three repeating subglacial signal pulses. |
| `Radio.CommunicationFailure` | Radio link distortion and cutoff. |

## Environment

| Config field | Required recording |
| --- | --- |
| `Environment.ArcticWindLoop` | Seamless polar storm wind loop. |
| `Environment.InteriorWind` | Muffled wind inside an insulated research module. |
| `Environment.SnowAgainstMetal` | Snow and ice grains striking metal cladding. |
| `Environment.GeneratorLoop` | Seamless distant diesel generator hum. |
| `Environment.IceCreaking` | Slow deep glacier creaks. |
| `Environment.DeepIceImpact` | Deep impact beneath the command room. |
| `Environment.FacilityTone` | The abandoned facility's room tone: a large, cold, sealed volume. Almost silence, with pressure. No wind - nothing moves in here. |
| `Environment.SettlingMetal` | Distant metal settling somewhere in the structure, once. |

## Machinery

| Config field | Required recording |
| --- | --- |
| `Machinery.VehicleEngineLoop` | Seamless tracked transport engine idle. |
| `Machinery.VehicleTracks` | Tracks compressing snow and suspension movement. |
| `Machinery.BoreStart` | Hot-water bore plant starting: pump spin-up, burner light-off, reel drive engaging. Three distinct events in one cue. |
| `Machinery.BoreLoop` | Seamless bore plant running: pump note, burner roar, reel creep. |
| `Machinery.LinePressureLoss` | Line pressure collapsing: pump note rising as the load disappears, hose slapping the reel, one mechanical alarm. No musical sting. |
| `Machinery.ReturnLost` | Return flow stopping. Mostly the ABSENCE of the circulation the mix has carried for the whole montage, plus a console alert tone. |
| `Machinery.HardReturn` | The bore head touching something hard and flat: a bright metallic contact quite unlike ice, reported through hose and steel. |
| `Machinery.GantryIdle` | The excavation gantry at idle: a big diesel power pack ticking over and the hot-water plant's circulation, heard from the rim. |
| `Machinery.GantryStart` | The gantry starting work: carriage drive engaging, hoist brakes releasing, the cutter head spinning up and steam starting. |
| `Machinery.CutterLoad` | The cutter under load in the ice: a heavy grinding hiss, slush pumping away through the return line. |
| `Machinery.PowerConnection` | Expedition power connected to ancient hardware: cable slap, breakers closing, an inverter note. |
| `Machinery.GateUnlock` | The containment gate unlocking: dogs withdrawing, drums turning under load, two heavy leaves parting. Mechanical, never magical. |
| `Machinery.SealSeparates` | The chamber's iris separating under strain. |
| `Machinery.EmergencyDoor` | Motorized evacuation lift doors closing. |
| `Machinery.ChainTension` | Massive metal links groaning under load. |
| `Machinery.ChainBreak` | One huge chain snapping with ringing fragments. |

## Ancient

| Config field | Required recording |
| --- | --- |
| `Ancient.KeyFound` | The seal key found in its cradle: frost breaking off worked metal. |
| `Ancient.KeySeats` | The key seating into the gate socket: a single deep mechanical acceptance, then a low tone rising inside the object itself. |
| `Ancient.LockEngages` | The lock housing waking: the glyph ring taking charge, mark by mark, then the circuit running away up the pier. |
| `Ancient.ChestBandLights` | Aegis Zero's chest band taking the same charge. The audience should recognise this as the SAME sound as LockEngages, one octave lower - it is the cue that says the door and the machine are one system. |

## Aegis

| Config field | Required recording |
| --- | --- |
| `Aegis.CorePulse` | Slow muted dormant core heartbeat. |
| `Aegis.CoreActivation` | Power entering and accelerating the chest core. |
| `Aegis.ArmorMovement` | Layered armor unlocking and shifting. |
| `Aegis.ServoMovement` | Hand and wrist servos under strain. |
| `Aegis.HeadMovement` | Neck pistons lifting a damaged mechanical head. |
| `Aegis.EyeActivation` | Brief orange eye ignition. |
| `Aegis.MechanicalCry` | Damaged mechanical cry under extreme load. |
| `Aegis.VoiceLineSealFailure` | Original Aegis voice: Seal failure. |
| `Aegis.VoiceLineCoreInsufficient` | Original Aegis voice: Core insufficient. |

## Alien

| Config field | Required recording |
| --- | --- |
| `Alien.LowRumble` | Subsonic-feeling alien presence, mixed without excessive bass. |
| `Alien.IceMovement` | Organic movement and pressure beneath ice. |
| `Alien.EyeActivation` | Quiet violet eye awakening. |
| `Alien.WardenBreakout` | Warden limbs breaking through frozen armor. |
| `Alien.WardenScream` | Alien Warden emergence call. |
| `Alien.SovereignVoiceGuardianRises` | Original Sovereign voice: The Guardian rises. |
| `Alien.SovereignVoiceGateOpen` | Original Sovereign voice: The gate is open. |
| `Alien.SovereignVoiceHarvestContinue` | Original Sovereign voice: The harvest may continue. |
| `Alien.SignalSurge` | The true signal surging as the containment fails - heard on the expedition's own instruments before it is heard in the room. |
| `Alien.SignalTransmission` | Alien signal escaping toward space. |

## Impacts

| Config field | Required recording |
| --- | --- |
| `Impacts.UndergroundImpact` | Chamber-wide subterranean shock. |
| `Impacts.IceCracking` | Close ice fractures and fragments. |
| `Impacts.ExplosionSmall` | Contained machinery blast. |
| `Impacts.ReactorExplosion` | Distant massive reactor detonation. |
| `Impacts.FacilityCollapse` | Tower and expedition structure collapsing. |
| `Impacts.DebrisImpact` | Muffled underwater falling debris. |

## Music

| Config field | Required recording |
| --- | --- |
| `Music.ArcticMystery` | Sparse Arctic arrival mystery score. |
| `Music.ScientificDiscovery` | Restrained wonder for the ancient guardian reveal. |
| `Music.WarningTension` | Escalating tension under Lyra’s translation. |
| `Music.AegisAwakening` | Mechanical activation score. |
| `Music.AlienAwakening` | Alien prison breach score. |
| `Music.ExpeditionDisaster` | Urgent evacuation score. |
| `Music.LyraSacrifice` | Emotional sacrifice score with room for dialogue. |
| `Music.SpaceReveal` | Quiet cosmic signal and carrier reveal. |
| `Music.TitleTheme` | Final title theme with one strong initial hit. |

## Dialogue

| Config field | Required recording |
| --- | --- |
| `Dialogue.HaleReport` | One entry per spoken line, in the order the cinematic plays them, so this doubles as the recording script. Every id is empty until the project has authorized recordings; the opening plays correctly silent. Hale: Report. |
| `Dialogue.VossSignal` | Voss: The signal is approximately two kilometres beneath us. |
| `Dialogue.VossScale` | Voss: Whatever is producing it is larger than anything humanity has ever built. |
| `Dialogue.HaleSpacecraft` | Hale: A spacecraft? |
| `Dialogue.VossPossibly` | Voss: Possibly. |
| `Dialogue.LyraCalling` | Lyra: It isn’t calling us. |
| `Dialogue.HaleQuestion` | Hale: Then what is it doing? |
| `Dialogue.LyraUnknown` | Lyra: I don’t know yet. |
| `Dialogue.HaleDrill` | Hale: Begin drilling. |
| `Dialogue.VossBorePlan` | Voss: Eleven hundred metres of ice, and the return is still clean. |
| `Dialogue.VossVoid` | Voss: We have no return at all. The bore is in open space. |
| `Dialogue.LyraNoCavity` | Lyra: There is no cavity in this ice. There never has been. |
| `Dialogue.VossNonIce` | Voss: Something down there is returning a flat signal. A machined surface. |
| `Dialogue.HaleWiden` | Hale: Then stop boring and start digging. I want to stand on it. |
| `Dialogue.VossBuilt` | Voss: Straight edges. Seams. Somebody built this. |
| `Dialogue.VossSealedInside` | Voss: It was sealed from the inside. |
| `Dialogue.VossNoPower` | Voss: There is no power anywhere in this structure. Not a volt. |
| `Dialogue.LyraWalkedOut` | Lyra: Nobody shut this down. They walked out of it. |
| `Dialogue.HaleOpenIt` | Hale: Can you open it? |
| `Dialogue.VossNoMechanism` | Voss: There is no mechanism to force. It is waiting for something. |
| `Dialogue.LyraSameMarks` | Lyra: These are the same marks. On the roof, in the corridor, on the door. |
| `Dialogue.VossAwe` | Voss: My God. |
| `Dialogue.HaleAge` | Hale: How old is it? |
| `Dialogue.VossIce` | Voss: The surrounding ice is thousands of years old. |
| `Dialogue.HaleWeapon` | Hale: Then we have discovered the greatest weapon in human history. |
| `Dialogue.LyraBuried` | Lyra: No. It wasn’t buried here. |
| `Dialogue.LyraRemain` | Lyra: It chose to remain. |
| `Dialogue.VossRead` | Voss: Can you read it? |
| `Dialogue.HaleBelowWhat` | Hale: Below what? |
| `Dialogue.LyraDontKnow` | Lyra: I don’t know. |
| `Dialogue.HaleWake` | Hale: Then we wake it and we ask it. |
| `Dialogue.LyraWait` | Lyra: Give me a week with that wall before you put a current through it. |
| `Dialogue.HaleDiscovery` | Hale: We did not cross half the planet to abandon humanity’s greatest discovery. |
| `Dialogue.LyraSameSystem` | Lyra: Those are the marks from the door. The door and this machine are one thing. |
| `Dialogue.LyraCode` | Lyra: It isn’t an activation code. |
| `Dialogue.HaleCode` | Hale: Then what is it? |
| `Dialogue.LyraGuardian` | Lyra: It is asking for a new guardian. |
| `Dialogue.HaleSuccess` | Hale: We did it. |
| `Dialogue.VossNotSource` | Voss: It was never the source. It has been sitting on top of the source. |
| `Dialogue.LyraLock` | Lyra: We weren’t waking a machine. We were opening a lock. |
| `Dialogue.LyraPower` | Lyra: Turn off the power! It is fighting the activation! |
| `Dialogue.LyraNo` | Lyra: No. |
| `Dialogue.LyraCreature` | Lyra: It is holding something down there. It has always been holding it down there. |
| `Dialogue.HaleSeal` | Hale: Seal the chamber! |
| `Dialogue.LyraNoSeal` | Lyra: There is no seal anymore. |
| `Dialogue.VossLeave` | Voss: Lyra! We have to leave! |
| `Dialogue.LyraStop` | Lyra: Can you stop it? |
| `Dialogue.LyraBury` | Lyra: Then help me bury it again. |
| `Dialogue.VossStay` | Voss: I’m not leaving you! |
| `Dialogue.LyraTell` | Lyra: Someone has to tell them what happened here. |
| `Dialogue.LyraYears` | Lyra: You protected our world for thousands of years. |
| `Dialogue.LyraTogether` | Lyra: Let us protect it together. |
