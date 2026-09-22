# THE DAY THE SKY BROKE — 0.4.0 (Chapter One, all 9 scenes implemented)

Story-driven Roblox prototype. Everything in the world is generated from code —
no models, no Toolbox assets, no paid content.

`The_Hope_Storyline.md` is the narrative source of truth.

## Run it

1. `rojo serve` in this folder.
2. In Studio, connect the Rojo plugin and sync.
3. Press **Play** (not Run) so both the client and the server start.

Seeing an empty `Workspace` while editing is expected. The map and interface
are created by `Main.server.lua` and `Main.client.lua` only after **Play** starts;
the Rojo project contains source code, not a prebuilt map.

The Baseplate's own `SpawnLocation` must stay deleted — it covered the ruin
entrance. The spawn used by the game is created in code at `(0, 1, 48)`.

## Controls

| Action | Desktop | Gamepad | Touch |
|---|---|---|---|
| Descend into the ruin | hold **E** | prompt button | hold prompt |
| Awaken / dismiss Aegis Zero | **Q** | **Y** | Aegis button |
| Mechanical combo | **left mouse** | **RT** | fist button |
| Ground slam | **R** | **X** | impact-ring button |
| Resonance bolt | **F** | **RB** | bolt button |
| Thruster dash | **left Shift** | **B** | chevron button |
| Core burst | **X** when charged | **LB** | core button |
| Advance dialogue | **E**, **Space** or **Enter** | prompt glyph | tap panel |
| Settings | gear, top right | select button | gear, top right |

## Source layout

```
src/shared/      Config      gameplay numbers, timings, limits
                 Palette     world colours, materials, quality budget
                 Theme       UI colours, type scale, metrics
                 Net         remote registry + message kinds
                 Signal, Dialogues

src/server/      Main            wiring + the validated remote boundary
                 PlayerService   menu lock, unlock, transformation sequence
                 AegisRig        procedural Aegis Zero armour (R6 and R15)
                 MechaAnimator   server-replicated Motor6D stance and attacks
                 WardenRig       procedural Warden (alien troop)
                 CombatService   strikes, windup, damage
                 EncounterService spawning, AI, objectives, retry
                 DialogueService, RateLimiter, WorldBuilder
                 World/          Kit, Buildings, Streets, Props,
                                 City, Ruin, Sky

src/client/      Main + UIKit, Responsive, State, Settings, Effects,
                 InputController, and UI/ (Root, MainMenu, HUD,
                 DialoguePanel, ResultPanel, SettingsPanel)
```

World generation is deterministic: `Palette.Quality.Seed` fixes the layout, so
the district is identical between test runs. `Palette.Quality` also caps
dynamic lights, skyline rings and particles in one place.

The server owns health, cooldowns, the bloodline unlock, encounter state and
dialogue progression. The client renders what it is told and sends requests;
every remote is validated and rate limited.

Map containment and fall recovery are server controlled. To inspect the four
collision walls around each zone, temporarily set
`Config.World.ShowBoundaries = true`; leave it `false` for normal play.

## Art status

Everything visible is **procedural Roblox geometry**. There are no models, no
Toolbox assets, no uploaded textures and no asset IDs anywhere in the project.

The original static-body cause was structural: Aegis Zero plates followed the
avatar limbs, but no code ever posed the avatar Motor6Ds; Warden limbs were
WeldConstraints on one invisible root. `MechaAnimator` now composes poses at
Heartbeat over the existing Animator, while Warden fore/hind segments use
Motor6D joints. The server starts the same named action timeline that drives
damage and telegraphs, so the movement is not particle- or camera-dependent.

Explicitly procedural art (replaceable, not asset-backed):

- Aegis Zero's armour (segment-local plates on the player's own rig),
- the Wardens (articulated procedural shell),
- the dormant Aegis Zero statue in the vault,
- every building, prop and piece of rubble.

They are built so proportion, silhouette and articulation are right, and so a
real model can replace each builder without touching gameplay code.

## What exists today

- **Chapter One, Scene 1: "A Normal Morning" is playable start-to-finish.**
  Start Game spawns the player outside Uncle Daren's repair garage (Kai's
  home neighborhood), plays a 4-shot morning cinematic (`Opening.lua`) with a
  real Skip button, then: talk to Daren (a procedural named NPC with a
  proximity prompt) to receive the delivery objective and the package; Mira
  (a procedural companion NPC) follows at a comfortable distance, holds
  during dialogue, and self-recovers if she falls behind or gets stuck;
  ~14 ambient civilians walk fixed loops, wait at a crossing/bus stop, sit,
  browse a market stall, repair a vehicle, or talk in pairs; a mystery event
  partway along the route (power flicker, birds scattering, a broadcast
  notice, the wrist device pulsing) fires once; reaching Central Plaza saves
  the checkpoint, shows a location title card and ends the scene. See
  `ChapterOneDirector.lua`, `NPCService.lua`, `World/Neighborhood.lua`.
- Main menu with a camera framing of the city, Play / Settings / Credits.
  Continue is visible but **disabled** — there is no saving yet.
- HUD: chapter/objective tracker, integrity readout, Aegis Zero status, and an
  action bar with real server-driven cooldowns.
- Aegis Zero dialogue with typewriter text, speaker portrait, and a
  reveal-then-advance flow that works on keyboard and touch.
- Beacon, world-space label and proximity prompt on the ruin entrance.
- One encounter: the Chapter 1 awakening chamber. A four-scout wave, then
  the Harrower boss (Hunter → Signal phase — two adds and two shielding
  relay pylons → Desperation phase — faster, unlocks a wide Shockring →
  Defeated), with victory and death/retry panels that really reset the whole
  encounter, boss included. Reached today via the old tutorial/chamber flow
  once Scene 1 is complete (Scenes 2-5 do not exist yet - see AGENT.md).
- Progress is saved: onboarding-complete and a 10-stage Chapter One flag
  (`Scene01_NormalMorning` … `ChapterOneComplete`) persist to DataStore per
  player (see `SaveService.lua`), with an honest Loading/Ready/Failed status
  and a retry action if the fetch breaks.
- Settings with reduced motion, hit-marker toggle and dialogue speed.
  Session only — they reset when you leave.
- A composed city: Daren's neighborhood (garage, two residential buildings
  with balconies/AC units/fire escapes, market stalls, a bus stop) built
  peacefully with no invasion damage visible, connected to the existing
  plaza/ruin district by the same avenue; damage, wreckage and the alien
  shard already exist in the world but stay hidden
  (`World/Kit.lua`'s `markInvasionOnly`/`World/WorldState.lua`) until
  something calls `WorldState.revealInvasion()` - nothing does yet, since
  that is Scene 2's job.
- Two lighting moods, split so only one is ever built: warm morning (the
  default, `Sky.build()`) and dusk-invasion (`Sky.revealInvasion()`, not yet
  triggered by anything - the rift/hull/smoke/emergency-lights do not exist
  in the world until it runs).
- An Ancient vault 116 studs tall with a colonnade, monumental gateway,
  activation dais and a 92-stud dormant Aegis Zero.
- A transformation sequence: resonance glyph, armour assembling legs to helmet,
  core ignition, shockwave, and a camera/HUD shift into Aegis Zero mode.
- Telegraphed Warden attacks whose warning radius and timing are read from
  the same values the damage check uses.
- A three-layer outer backdrop (`HopeBackdrop/ NearBoundary`,
  `MiddleDistance`, `DistantHorizon`) with intentional ground continuity; the
  default Baseplate is neutralised instead of being left visible beyond walls.

## Studio verification still required

No Roblox Studio/Vinegar runtime is available in this container. After syncing
with Rojo, test with particles and camera shake disabled first: transform,
walk/run, each combo hit, Ground Slam, Resonance Bolt, Dash, enemy windup/
strike/recovery, hit reaction, death/respawn, and a second client observing.
Orbit the camera at human and Aegis Zero height around all four city and ruin
edges; confirm the near facades hide the ground edge and the legal ruin
descent is unaffected. Finally repeat at 1920×1080, 1366×768 and a narrow
landscape viewport. The code checks pass, but these are visual play-tests and
must not be inferred from static analysis alone.

## Manual Studio step

`Lighting.Technology` cannot be accessed from an experience script. Set it once:

**Explorer → Lighting → Properties → Technology → Future**
(use ShadowMap instead on a slower machine).

## Not built yet

All nine scenes of Chapter One are implemented (see `AGENT.md` for exactly
what each one covers and the scope simplifications each one made - several
scenes deliberately narrate a beat in dialogue rather than staging a full
separate camera cinematic, given the size of the whole chapter). **None of
it has been played in a real Roblox Studio session** - no Studio/Vinegar
runtime exists in this container, so every scene was verified by
`./tools/check.sh` (static analysis) and careful hand-tracing only. A full
playtest is the single most important next step before trusting any of this
in front of a player. Also not built: audio, and Chapter 2 onward.

## Optional: static analysis

`./tools/check.sh` type-checks and lints `src/` with luau-lsp. It downloads the
tool into `tools/.bin` on first run. Not required to build or play.
