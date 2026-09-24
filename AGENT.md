# AGENT.md — build log for Chapter One: "The Day the Sky Broke"

This file tracks what has actually been implemented against the Chapter One
scene-by-scene spec (originally `ROBLOX_CHAPTER_ONE_MASTER_BUILD_PROMPT.md`,
now superseded in authority by `story.txt` — see below), so a future session
can pick up without re-deriving project state or redoing finished work.
Update it at the end of every session that changes gameplay code.

## Identity, as of 2026-09-15: superseded — read this first

**As of 2026-09-15 this project's identity was fully renamed** from the old
abstract "THE HOPE" naming to the concrete "Day the Sky Broke" naming that
`story.txt` and the master build prompt actually use. The table below that
used to forbid Aegis/Harrower/Mira-Vale naming is obsolete and **inverted** —
those names are now correct and mandatory throughout this codebase.
`story.txt` is the narrative source of truth going forward; the old
`The_Hope_Storyline.md` is superseded (kept for reference, not deleted, but
do not follow it for new work).

Canonical naming, current as of this rename:

| Concept | Name used everywhere in this codebase |
|---|---|
| The player's Mecha | **Aegis Zero** (`Config.Aegis`, `src/shared/AegisRig.lua`, HUD "AEGIS INTEGRITY", action-bar slot id `"Aegis"`) |
| The alien Dominion's ground troops (grunts) | **Wardens** (`Config.Warden`, `src/server/WardenRig.lua`, `CollectionService` tag `"SkyWarden"` via `CombatService.WardenTag`) — note this is the OPPOSITE of the pre-2026-09-15 meaning of "Warden", which was the mecha |
| Chapter One's boss | **the Harrower** (`Config.Boss.Name`, a scaled/recoloured variant of the same Warden rig family — see `WardenRig.lua`'s `isBoss` option) |
| The alien empire | **the Veyra Dominion** (or "the Dominion") — replaces the old "the Swarm" |
| The chamber/tutorial guide voice | **Aegis Zero itself** — the old separate "Kestrel" persona was retired and folded into Aegis Zero's own dialogue (see `Dialogues.lua`); Aegis Zero speaks for both the pre-awakening chamber voice and the post-awakening combat tutorial |
| The protagonist | The player's own Roblox avatar, referred to as **Kai** in dialogue |
| Kai's best friend | **Mira Vale** — not yet implemented as an NPC (see gaps) |
| Kai's guardian | **Uncle Daren**, repair-shop owner — not yet implemented |
| City defense officer | **Captain Ren** — not yet implemented |
| The researcher who knew Kai's mother | **Dr. Elian Voss** — not yet implemented |
| Resistance leader (Scene 9) | **Commander Sera** — not yet implemented |
| The city | **Nova City** (`Config.Game.LocationLabel`) |
| Kai's missing mother | **Lyra (Lyra Ren)** — referenced in Scene 6's memory sequence (not a live NPC in Chapter One); now also the lead character of the North Pole prequel opening (see 2026-09-15 entry below) - her sacrifice there is what Scene 5/6's dialogue is about |

**The chapter-state system** (`SaveService.lua`'s `Stage` type) now has one
entry per scene, `Scene01_NormalMorning` through `Scene09_ChapterEnding`,
plus `ChapterOneComplete`, ranked in story order so `SaveService.markStage()`
can never regress or repeat a finished scene (rule 14 of the working rules).
Only the tail of this list has real gameplay behind it today — see "Current
status" below.

**Do not re-introduce** the old "Warden = mecha" / "Construct = enemy" /
"Kestrel" / "the Swarm" naming. If you are ever handed the original generic
master-prompt text again, it already matches this project's real naming
directly — no translation table is needed anymore.

## Current status vs. the 9-scene Chapter One spec

Chapter One is specified as nine scenes: 1 A Normal Morning, 2 The Sky
Breaks, 3 Survival Through Nova City, 4 The Hunter's Pursuit, 5 Beneath the
City, 6 The Awakening, 7 Learning to Stand, 8 The Harrower, 9 A Much Larger
War. Before the 2026-09-15 rename/rebuild pass, this project's actual
playable content only covered what roughly maps to the tail of that list —
an awakening chamber (Scene 6, compressed), a tutorial (Scene 7, but
sequenced *before* the chamber instead of after — see the TODO in
`TutorialArea.lua`), and the boss fight (Scene 8, functionally complete).
Scenes 1–5 and 9 did not exist as gameplay at all: no city life, no named
human NPCs, no invasion cutscene, no rescues, no underground journey, no
ending cinematic.

**What already exists and is being reused/extended, not rebuilt:**
- The full Mecha combat system — procedural body-driven poses (not just
  VFX), 5 abilities (Combo, GroundSlam, ResonanceBolt, ThrusterDash,
  CoreBurst), server-validated damage, telegraphed enemy attacks. This is
  Scene 7/8's combat foundation.
- The Harrower's full 4-phase boss fight (Hunter → Signal → Desperation →
  Defeated) already matches Scene 8's spec almost exactly — see "Boss fight
  implementation notes" below before touching it.
- The onboarding tutorial (`TutorialService.lua`/`TutorialArea.lua`) teaches
  the same 5 abilities Scene 7 asks for, via holographic targets, then real
  enemies — same shape as Scene 7's spec, just needs relocating to fire
  *after* the chamber awakening instead of before it.
- A real save/stage system (`SaveService.lua`) — extended 2026-09-15 to a
  10-stage enum (`Scene01_NormalMorning` … `ChapterOneComplete`) satisfying
  rule 14 ("finished scenes cannot repeat accidentally").
- A composed city district, an Ancient vault/chamber, dusk invasion lighting,
  a transformation sequence, a working save/settings/menu UI stack.

**What does not exist yet and is real scene-content work, not renaming:**
Scenes 1–5 and 9 in full (city life, named NPCs Mira/Daren/Ren/Voss/Sera,
ambient civilians and traffic, the invasion cutscene, rescues, the power
puzzle, first (human-scale) combat, the escape/collapse cinematic, the
underground traversal, the memory sequence, the sync choice, the ending
cinematic and chapter-completion screen). The existing Opening.lua cinematic
also needs a real Skip button (it does not have one) and its 4 shots rewritten
to match Scene 1's "peaceful morning" content instead of the old
pre-invasion-teaser framing.

## 2026-09-15 session: full identity rename

Executed the full identity rename described in the "Identity" section above
(Warden↔Aegis Zero swap, Construct→Warden, Kestrel retired into Aegis Zero's
voice, Swarm→Veyra Dominion, `THE HOPE`→`SKY BROKE` log prefix, new
`SaveService.Stage` enum). File renames: `src/shared/WardenRig.lua` →
`src/shared/AegisRig.lua` (the mecha rig); `src/server/ConstructRig.lua` →
`src/server/WardenRig.lua` (the alien rig — reuses the freed name for a
different purpose, intentional). Every `Config.Warden`/`Config.Construct`,
`CombatService.ConstructTag`/`ConstructDamaged`,
`Net.Feedback.ConstructTelegraph`/`ConstructHit`, and every player-facing
string (HUD labels, dialogue, tutorial cues, menu credits, tutorial guide
name tag) was updated to match. Two functional (not just cosmetic) fixes
were caught during this pass: `Effects.lua` was still looking for
`"WardenPlating"`/`"WardenActive"` (the OLD mecha folder/attribute names)
after `PlayerService.lua`/`AegisRig.lua` were renamed to
`"AegisPlating"`/`"AegisActive"` — VFX would have silently failed to find
the plating; and `TutorialService.lua`'s tutorial-cue highlight string still
said `"Warden"` after the HUD action-bar slot id was renamed to `"Aegis"` —
the tutorial's "highlight the transform button" step would have silently
highlighted nothing. Both fixed. Verification: `./tools/check.sh` — clean,
no diagnostics.

**Note on process:** a background fork was first launched to do this rename
and returned a bogus "done" result after a single tool call with no actual
file changes — caught by verifying file state directly (`grep`/`ls`) rather
than trusting the summary, per "trust but verify." The rename was then
redone directly. Also: `sed -i` was briefly combined with a `>` redirect in
one command, which — because `-i` suppresses sed's stdout — emptied
`EncounterService.lua` to 0 bytes; caught immediately via `wc -l` and
reconstructed verbatim from the file content already read earlier in the
same session, then the rename re-applied correctly. Lesson: never combine
`sed -i` with a stdout redirect.

## Boss fight implementation notes (still current, renamed)

The Harrower's fight lives in `EncounterService.lua` (search for "The
Harrower"). Phases:
1. **Hunter** — three attacks: `Claw` (melee), `Leap` (telegraphs the
   target's position, then the boss traverses there and detonates), `Line`
   (a row of telegraphed bursts toward the target, resolved as one capsule
   hit-check).
2. **Signal** (health ≤ 65%) — summons two scout-AI adds (reuses the exact
   grunt AI via `thinkOne`, for free) and two destructible relay pylons.
   Incoming damage to the boss is multiplied by
   `Config.Boss.ShieldDamageMultiplier` (0.35) while any pylon stands — a
   slow-down, never a hard gate, so the fight cannot soft-lock if a player
   ignores the pylons.
3. **Desperation** (health ≤ 30%) — faster, shorter cooldowns, unlocks
   `Shockring` (a large telegraphed AoE centred on the boss).
4. **Defeated** — the boss stops attacking, holds a collapsed pose
   (`WardenRig`'s "Defeat" animation phase) for
   `Config.Boss.DefeatLingerSeconds` before cleanup, while
   `Chapter1_BossVictory` plays. This is the "do not instantly delete it,
   trigger a short finishing beat" requirement, within what a
   procedural-parts rig can actually do (no bespoke defeat animation — this
   is a pose hold, not a keyframed sequence; flagged as a known limitation —
   Scene 8's spec wants a real finishing cinematic with Kai catching the
   blade, which is more than this pose-hold does today).

The boss reuses, unmodified: `CombatService.damageArea` (targets anything
tagged `CombatService.WardenTag` in radius — grunts, adds, pylons and the
boss all "just work"), the `WardenTelegraph`/`WardenHit`/`AbilityVFX` client
VFX, and the HUD's generic `EnemyStatus` bar (arbitrary `label`, shows
`THE HARROWER`, `— SIGNAL`/`— EXPOSED`, or `— DESPERATE` depending on
phase). Check whether an existing generic Feedback kind already covers a new
need before adding one.

## 2026-09-15 session: Scene 1 "A Normal Morning" implemented

New files: `src/server/ChapterOneDirector.lua` (the scene director - owns
Scene 1's begin/skip/objective/mystery-event/completion flow and will own
Scenes 2-9 the same way), `src/server/NPCService.lua` (procedural human NPC
framework: ambient civilians on fixed-point loops, a named static NPC
pattern used for Daren, a companion-follow pattern used for Mira - reusable
for Ren/Voss/Sera in later scenes), `src/server/World/Neighborhood.lua`
(Daren's garage + two residential buildings with balconies/AC/fire escapes,
built into one existing city-block footprint rather than expanding the map),
`src/server/World/WorldState.lua` (the invasion-reveal toggle - see below).

**World state split into peaceful/invaded, built once, toggled, not
duplicated.** The whole existing city was previously baked in its
post-invasion state from world-gen (ground damage, wrecked vehicles,
emergency barriers, the alien shard, dusk lighting, the sky rift/hull/smoke)
with no peaceful state at all - a direct conflict with Scene 1's "make the
city feel peaceful and alive." Fixed via `Kit.markInvasionOnly()` (tags +
hides an instance, remembering its pre-hidden Transparency/CanCollide) at
every invasion-only build site in `Streets.lua`/`City.lua`, plus splitting
`Sky.lua` into `Sky.build()` (default: warm morning lighting/clouds, no
rift/hull/smoke built at all yet) and `Sky.revealInvasion()` (dusk mood +
builds the rift/hull/smoke/emergency-lights on demand). `WorldState.lua`
calls both halves together. **Nothing currently calls
`WorldState.revealInvasion()`** - that is Scene 2's job once implemented;
right now the city simply stays peaceful forever, which is correct for what
exists today.

**Spawn moved.** `City.lua`'s SpawnLocation and returned `SpawnCFrame` now
point at `Neighborhood.SpawnCFrame` (outside Daren's garage) instead of the
old plaza-adjacent point, which is preserved separately as
`PlazaSpawnCFrame` (used by `ChapterOneDirector.completeScene01` as the
Scene-2 handoff position).

**Opening.lua rewritten.** The old 4 shots (Aftermath/Threat/Response/
Handoff) dramatized an already-invaded world with a Warden-silhouette
"threat" shot and a Kestrel transmission - both wrong for a Scene 1 that
must show nothing has happened yet. Replaced with
CityDawn/MorningLife/ToTheShop/Handoff, all referencing the real
Neighborhood geometry by name (no hardcoded coordinates). **Added a working
Skip button** (mouse/touch/gamepad via `UIKit.button`, plus a keyboard
shortcut on `Config.Input.AdvanceKeys`) that fires `Net.Action.SkipScene01`
before running the same `performHandoff()` every other exit path uses -
this did not exist before this session (see the git-less history: it was a
known, explicitly flagged gap). Skip applies the scene's end state (package
received, delivery objective active) via `ChapterOneDirector.skip()`, not
just a camera cut.

**Known simplifications, stated plainly:**
- Mira/the mystery-event/control-tips are written for one "story player"
  (the first to begin Scene 1). A second player in the same server sees the
  same world, NPCs and dialogue triggers work for them too, but Mira only
  follows the first player and the mystery event only fires once globally,
  not per-player. Documented in `ChapterOneDirector.lua`'s header comment.
- Control tips (rule: "optional") are plain timed Notice toasts phrased for
  keyboard, not input-device-aware and not dismiss-on-action. The action bar
  itself already shows the real per-device key/touch/gamepad icon.
- No audio (project-wide constraint, unchanged) - the mystery event's power
  flicker/broadcast/device pulse are all visual/text only.
- **Not verified in a real Studio session** - no Studio/Vinegar runtime
  exists in this container. Verified by `./tools/check.sh` (clean, no
  diagnostics) after every substantive edit, plus hand-tracing every new
  call site (world positions, remote payload shapes, the objective/
  navigation-indicator remote-ordering dependency in
  `ChapterOneDirector.pushObjective`). Treat as "should work" until someone
  plays it in Studio.

## 2026-09-15 session (continued): Scene 2 "The Sky Breaks" implemented

New files: `src/client/CutsceneRunner.lua` (generic shot-sequencer/Skip/
handoff, extracted from Opening.lua's pattern - used by Scene 2's cutscene
and intended for every remaining scene's cutscene; Opening.lua itself was
deliberately left alone rather than migrated, since it already works and a
rewrite would be pure regression risk for no behaviour change),
`src/client/Scene02Invasion.lua` (the 5-shot invasion cutscene), plus
additions to `ChapterOneDirector.lua` (`beginScene02`/`applyScene02EndState`/
`completeScene02`), `NPCService.lua` (`setGlobalPanic` - every ambient
civilian flees the panic source at a raised speed once called), and
`City.lua` (`buildFountain`/`buildPlazaLife` - a real, collidable fountain/
monument at the plaza centre used as Scene 2's cover point, plus trees,
benches, planters, food vendors, info displays and a plaza crowd).

Flow: Scene 2 begins the instant Scene 1 completes (entering the plaza).
`Config.Scene02.PreInvasionSeconds` (6s) of completely normal, player-
controlled time first (rule: movement must stay free here, not frozen -
this was a bug caught and fixed before it shipped: an earlier draft locked
movement the moment Scene 1 ended instead of when the cutscene itself
starts). Then: a power flicker + birds scatter (reusing Scene 1's exact
helpers, not duplicated), `WorldState.revealInvasion()` fires (the sky/
lighting swap plus every `Kit.markInvasionOnly()` instance across the whole
city, not just the plaza), civilian panic starts, the drop pod and first
Warden are spawned (`WardenRig.build()` - no new alien design needed, it
already matches the spec), then the client cutscene runs. Skip and natural
completion both funnel through one `Net.Action.Scene02Done` →
`applyScene02EndState`, so the end state can never diverge between the two
paths (simpler and safer than Scene 1's two-code-path Skip, worth carrying
forward for later scenes). Ends with objective "Find Mira and escape the
plaza," `SaveService` stage `Scene03_CitySurvival`, and stops cleanly since
Scene 3 does not exist yet - the Warden stands revealed but does not hunt
the player (no open-world combat AI exists outside the awakening-chamber
encounter for it to run on yet).

**`ChapterOneDirector.begin()` extended for resume-mid-scene-2:** a player
who finishes Scene 1, disconnects, and rejoins before finishing Scene 2 used
to fall through to the old tutorial flow (their stage already read as
"Scene1 done" and the old guard only checked that). Fixed: the guard now
checks `hasReached(player, "Scene03_CitySurvival")`, and a player who has
passed Scene 1 but not Scene 2 resumes directly into `beginScene02` instead.

**Known simplifications:** defense-aircraft-vs-carrier combat is not shown;
"scripted vehicles brake" is represented by wreckage simply being revealed
(already-stopped), not an active braking animation; civilian panic is one
uniform "flee the source" reaction for every NPC rather than simulating
panic/hide/help/evacuate as distinct individual behaviours. All noted in
code comments at the relevant call sites. Verification: `./tools/check.sh`
clean; no Studio session performed (same caveat as every prior entry).

## 2026-09-15 session (continued): Scenes 3-4 implemented

**Scene 3 "Survival Through Nova City."** New: a temporary human-form combat
kit (`CombatService.lua`'s `castHumanStrike`/`castHumanShove`/`castHumanDodge`
- gated on a `HasEmergencyStaff` player attribute instead of
`PlayerService.isTransformed`, reusing `begin()`/`active()` with a new
`requireTransform` parameter rather than forking the whole cast pipeline;
reuses `MechaAnimator.action()` directly on the player's own avatar joints
for real swing/shove/dash poses - that module turned out to already be
generic over any Motor6D-rigged humanoid, not Warden-specific, so zero new
animation code was needed). `HUD.setHumanCombatEnabled()` shows the existing
Strike/GroundSlam/ThrusterDash action-bar slots outside Aegis mode so touch/
gamepad players have real buttons. A rescue hold-prompt, a 3-connector
power-restore interaction (one correct, clearly lit; wrong ones fail softly),
2 Warden Scouts with a self-contained mini AI (deliberately not reusing
EncounterService's - that state machine is chamber-specific), Ren and Voss
as named NPCs. **Recognition-moment bug caught before shipping:** the first
draft triggered "Captain Ren destroys the closest Scout" only after the
player had already killed every scout themselves, which inverts the beat -
fixed to trigger the instant exactly one scout remains, so Ren genuinely
finishes the last one. Scope cuts (stated in code comments):
"guide civilians to the evacuation route" is Scene 2's existing panic-flee
behaviour, not a new escort mechanic; Toma/the emergency transport is a
line of dialogue, not a second interactive system.

**Scene 4 "The Hunter's Pursuit."** Mostly scripted environmental staging
per the spec's own instruction ("mostly remain a scripted environmental
threat... do not allow its AI to wander away or kill required NPCs") -
stationary soldiers and an idle-but-telegraphing Warden down a side street
for atmosphere, a real hold-prompt to help Mira across a gap, then a
telegraphed strike at the collapse point that doubles as both "avoid the
Harrower's telegraphed strike" and the collapse warning, a 3-shot
`CutsceneRunner` climax, and a landing that reuses `World.RuinSpawn` - the
exact point the pre-existing awakening-chamber flow already used - so Scene
5/6 have a real destination waiting rather than needing new geometry for
the hand-off point.

Both scenes verified via `./tools/check.sh` (clean) and hand-tracing; no
Studio session (same standing caveat).

## 2026-09-15 session (continued): Scene 5 implemented

**Scene 5 "Beneath the City."** A short new tunnel (`buildScene05Tunnel`,
built inside `ChapterOneDirector.lua` rather than a new `World/` module,
given how much of the chapter was still ahead) connects Scene 4's landing
point to `World.RuinSpawn` - the exact point the pre-existing
`EncounterService.onDescend`/`Chapter1_Awakening` flow already starts from.
Scene 5's ending calls that function directly rather than reimplementing the
awakening: Scenes 6-8 (awakening dialogue, transformation, the tutorial
teaching all 5 abilities, the full 4-phase Harrower fight) were already
substantially built before this session and did not need to be rebuilt, only
extended - see the next entry. Voss's exposition is delivered in four pieces
gated on fraction-of-tunnel-walked rather than one dump; a real bug was
caught and fixed before shipping (the pressure-cue threshold originally
matched one of the dialogue thresholds exactly, which meant that beat could
pre-empt/cancel an exposition line the player was still reading - reordered
so pressure only starts after every exposition beat has had room to play).
**Real timing bug also caught:** the tunnel was originally built at
`ChapterOneDirector.init()` time, reading `World.RuinSpawn` before
`WorldBuilder.finishDecor()` (which runs asynchronously and is what actually
computes the real gateway position) had run - the tunnel would have been
built at the placeholder Neighborhood-spawn position. Fixed by polling
`World.DecorReady` before building it.

## 2026-09-15 session (continued): Scenes 6-8 extended (not rebuilt)

Rather than rebuild the pre-existing awakening/tutorial/boss flow, added the
specific new-story content on top of it, in `Dialogues.lua` and
`ChapterOneDirector.lua`:
- **Scene 6:** `Chapter1_Awakening` now includes the memory-sequence beat and
  Lyra's exact recorded line before Aegis Zero speaks; `Chapter1_FirstTransform`
  now opens with the "why do you want my power" / "I can't let them hurt
  anyone else" / "a reason to stand" / "then stand with me" exchange, spoken
  the moment the player actually transforms. The Synchronize/Not-Yet choice
  is *not* a separate two-button prompt - pressing Transform (always
  available, never gated to a single use) is functionally "Synchronize," and
  simply not pressing it is "Not Yet" with no dead end, which was judged a
  reasonable scope simplification over building a parallel choice UI.
  Mira/Voss are now real NPCs by this point (Scenes 1-5), so "Mira and Voss
  become endangered" during the scout wave is naturally true rather than
  staged - `thinkScene05` repositions them to the gateway just before
  `EncounterService.onDescend` fires so they are not left behind in the
  tunnel.
- **Scene 7:** `beginScene07Coaching` (hooked to `PlayerService.TransformChanged`)
  fires Aegis Zero's three short coaching lines ("Balance before power." /
  "Observe the attack before you answer it." / "Now move with me.") as
  Notices timed across the opening of the real fight. A separate
  holographic-target-then-real-Wardens phase (the fullest reading of the
  spec) was not built - stated scope simplification.
- **Scene 8:** `Chapter1_BossVictory` now opens with the finishing-blow beat
  narrated in dialogue (the Harrower's last strike turning toward Mira, "Not
  them," the caught blade, the orange wings) before the existing "signal
  reached the Dominion" lines, which already set up Scene 9's "other Aegis
  Frames awakening" reveal. A separate staged finishing camera cinematic
  was not built, and the arena is still the underground vault, not a
  relocated surface city district - both stated scope simplifications.

## 2026-09-15 session (continued): Scene 9 implemented - Chapter One complete

**Scene 9 "A Much Larger War."** Triggered off a new `SaveService.StageChanged`
signal (fired from inside `markStage()`) rather than a direct call from
`EncounterService.lua` - this is what let Scene 9 get built without touching
that already-complex, working boss state machine at all: `EncounterService`
already marked `Scene09_ChapterEnding` the instant the Harrower died, so
Scene 9 just had to listen. `beginScene09` polls `DialogueService.isActive`
(not a fixed delay) before seizing the camera, so the ending cutscene can
never cut off the boss's own victory dialogue mid-read. An 11-shot
`CutsceneRunner` cutscene (`Scene09Ending.lua`) carries Aegis Zero kneeling,
Mira's banter, Ren and Voss's arrivals, Commander Sera's transmission and
the fleet reveal, ending on "we find the others, then we take our world
back." A new `ChapterCompletePanel.lua` (deliberately separate from
`ResultPanel.lua` - that one is a two-button encounter popup, this is a
multi-stat chapter milestone screen) shows rescued-civilians count, the
Harrower-defeated state, the Resistance Outpost unlock, and Continue/Return
to Menu. Chapter completion is saved via the existing monotonic
`markStage(..., "ChapterOneComplete")` - its own forward-only guard is what
prevents the reward from being granted twice on a repeat trigger, the same
mechanism every other scene transition in this file already relied on.
Continue pushes a teaser objective without pretending Chapter Two exists, in
the existing cleared chamber (no new hub area was built - stated scope
simplification).

**Chapter One's nine scenes are now all implemented**, verified throughout
by `./tools/check.sh` (clean at every step) and hand-tracing - never an
actual Studio playtest, since none is available in this container. See each
scene's own session entry above for exactly what was built, what was
deliberately simplified, and what real bugs were caught and fixed before
shipping (the recognition-moment sequencing bug, the pressure/dialogue
threshold collision, the tunnel-built-before-DecorReady timing bug, the
premature Scene-2 movement lock, several Lua forward-reference bugs from
inserting sections out of call order). **A human playtest in real Roblox
Studio is the essential next step** - this is a large amount of new
interlocking gameplay logic (positions, timings, trigger radii, NPC
placement) that has only ever been reasoned about, never watched running.

## 2026-09-15 session (continued): the pre-gameplay opening replaced with "THE GUARDIAN BENEATH THE ICE"

`Opening.lua` (the client-local cinematic that plays after Start Game and
before Chapter One Scene 1 - **not** the same thing as Scene 1's own
gameplay, which is unaffected) was rewritten from a 4-shot Nova City
flythrough into a full 14-sequence prequel cold open, set 15 years before the
main story: scientists discover Aegis Zero sealed over the Sovereign Below's
prison at the North Pole, Hale forces the activation, both wake up, and
Lyra sacrifices herself to re-bury them. Ends on the game's real title
(`Config.Game.Title`) and hands off directly into Scene 1 gameplay - never
back to the welcome screen, per explicit instruction this session.

**New client-only modules, all under `src/client/NorthPole/`** (none of this
replicates or touches the server - same "client-local temporary scene" trick
`MenuScene.lua` already uses for the menu hangar, just a second, much larger
instance of that pattern, built at `Vector3.new(0, 9500, 0)` so it can never
overlap MenuScene's own box at y=3000):
- `Kit.lua` - the same small part/wedge/cylinder/weld/rng builder helpers
  `World/Kit.lua` provides server-side, re-implemented client-side with
  cinematic-appropriate defaults (CanCollide false, massless, no shadow
  unless asked).
- `Env.lua` - the whole environment: exterior snowfield/iceberg/research
  base, the ice tunnel into an ancient hall, the Aegis chamber (seal ring,
  myth-wall relief, foreground machinery), a shaft down to the alien prison
  cavern, and one `CameraMarkers` folder of named, invisible marker parts
  (`S05_AegisFaceReveal`, `S12_LyraFinalClose`, etc.) that every camera move
  reads from by name.
- `Cast.lua` - the whole cast. Lyra/Voss/Hale/background scientists/soldiers
  are a small custom welded-part skeleton (Root→Waist→Torso→Neck→Head,
  Torso→Shoulders→Arms, Root→Hips→Legs), not a real Humanoid - camera-driven
  cinematic characters need no NavMesh walking and a real Humanoid would only
  add `CreateHumanoidModelFromDescription` async latency for nothing. Aegis
  Zero is the one deliberate exception: it's the **real shared `AegisRig`**
  on a real R15 dummy (`MenuScene.upgradeMecha`'s exact technique), posed
  kneeling from R15's actual hip/knee/ankle joints, with frost patches, a
  damaged faceplate/shoulder, embedded blades and four sagging procedural
  chains to the seal - so the mecha the player pilots 15 years later is
  unmistakably the same design, not a reskin. The Sovereign Below and the
  Wardens are simplified biomechanical primitives (tapered trunk segments,
  a multi-eye head, folded claw limbs, broken wing slabs) built with
  silhouette/partial-reveal in mind, per the brief's own "reveal through
  shapes and shadow, not a clean lit body" direction.
- `Camera.lua` - the reusable camera controller: eased position/target
  interpolation between two marker CFrames, with handheld sway and a shake
  amount that's scaled by `Settings.shakeScale()` (the existing camera-shake
  accessibility setting), so nothing here bypasses a setting the rest of the
  game already respects.
- `Lighting.lua` - one named mood per major location (exterior storm,
  command tent, ancient interior, chamber with an `awaken` 0..1 warm-up,
  prison, emergency red, blackout), all client-local `Lighting`
  property changes exactly like `MenuScene`'s "dawn hangar" trick. The
  post-effect instances (Atmosphere/Bloom/ColorCorrection/Clouds) are
  **mutated in place on the server's own existing `Hope*`-named instances**
  rather than a second competing instance being parented alongside them -
  `restore()` sets them back to `World/Sky.lua`'s exact `Sky.build()`
  literals (0.55/0.4/400/1400/etc.), which only exists as a mirror of that
  call site and will drift if that literal ever changes there.
- `Sequences.lua` - the 14 named shots themselves (Arrival → Signal →
  Excavation → the ancient door → the Aegis reveal → the warning → the
  prison → the activation order → Aegis awakens → the Sovereign awakens →
  the expedition falls → Lyra's sacrifice → the signal reaches space → the
  title), each an `{enter, update, leave}` triple in the same shape
  `CutsceneRunner.lua`'s shots already use, run one at a time by
  `Opening.lua`'s own loop (deliberately NOT routed through the shared
  `CutsceneRunner.lua` - see below).

**`Opening.lua` itself**: same external contract as before
(`Opening.start(parent, finish)`, called identically from
`Main.client.lua`), same skip-fires-`Net.Action.SkipScene01` mechanism
(unchanged - `ChapterOneDirector.begin()+skip()` already do exactly "start
Scene 1, then fast-forward to its end state" regardless of what the
cinematic's content is, so **zero server-side changes were needed for this
whole feature**), same guarded single-exit-path/watchdog/loading-screen
shape. New: Skip is now hold-to-skip (`Config.Cinematic.SkipHoldSeconds`,
0.85s), tracked locally in `Opening.lua` rather than by changing the shared
`CutsceneRunner.lua` other scenes' skip buttons use, precisely so this
change can never regress Scenes 2/4/9's skip behaviour. The player's own
avatar is hidden for the cinematic's duration via
`LocalTransparencyModifier = 1` on every `BasePart`/`Decal` in
`player.Character` (never touches the real `Transparency` property, never
replicates, restored to 0 before `finish()` runs) - the camera never points
at it anyway (it's locked to the North Pole stage the whole time), so this
is pure insurance per the brief's own "hide it locally" safe-approach list.

**Continuity fix, caught before shipping:** `Dialogues.lua`'s already-shipped
Scene 5/6 lines said Kai's mother's discovery happened "under this city"
and that Aegis Zero has "slept beneath this city since the Architects
fell" - both directly contradicted a North Pole origin. Reconciled with
three small text edits rather than reworking either side: `Scene05_Reveal1`
now says "at the edge of the world" (was "under this city") and "Fifteen
years ago" (was "Decades ago", matching this cinematic's exact timeframe);
`Scene05_Reveal2` now says the dormant machine was "guarding something far
worse beneath it" and that officials "tried to force it awake" (both now
literally true per this cinematic) while still saying Lyra "sealed it all
away again" rather than stating she died, preserving the very next line's
deliberate "I don't know if she died" ambiguity - this cinematic never
shows a body either, only the explosion and the aftermath from a distance,
so that ambiguity survives intact; `Chapter1_Awakening`'s Aegis line now
says "beneath the ice, and then beneath this city" instead of just
"beneath this city", acknowledging both sites without inventing or
depending on any new lore about how it moved between them.

**Why `CutsceneRunner.lua` was deliberately left untouched**: it's shared by
Scenes 2/4/9's already-shipped cutscenes, and changing its skip button to
hold-style (or teaching it Aegis/alien pose helpers) would be pure
regression risk to working scenes for a feature only this one cinematic
needs - the same reasoning the original `Opening.lua` header already gave
for staying its own thing rather than migrating onto `CutsceneRunner.lua`.

**Known simplifications, stated plainly:**
- No audio, same as everywhere else in this project by design -
  `Config.Cinematic.Sounds` gained ~18 new named cues (`Wind`, `AegisPulse`,
  `SovereignVoice`, `Explosion`, ...) all blank strings; paste in real
  `rbxassetid://` values to enable them without touching any cinematic logic.
- "Hundreds of frozen Wardens" is 14 background instances at varied
  scale/rotation/distance (`Env.prisonSpots`) plus one that actually breaks
  free - a capped, varied crowd rather than a literal army, the same
  "capped, not unlimited" call already made for ambient civilians
  (`Config.Neighborhood.AmbientCount`).
- "8-12 scientists"/"8-10 soldiers" are 7 of each, procedurally varied
  (colour/scale/headwear/accessory via a seeded `Random`), not 15-20
  individually hand-authored characters.
- No dynamic facial expressions or face textures (no asset support in this
  project) - emotional readability is carried entirely through the same
  movement toolkit `MenuScene`'s mecha already uses one instance of (head/
  neck tracking, torso lean, hand gesture, kneel), applied at every story
  beat the brief calls out (Lyra's suspicion/fear/determination etc. are
  posture and gesture, not a face).
- Some kneeling/pose placement (Aegis Zero's exact floor contact, the
  simplified human rig's crouch) is visually approximate rather than IK-
  solved - acceptable at this project's existing "placeholder geometry,
  proportions and silhouette right" bar (see `AegisRig.lua`'s own header),
  and not verifiable more precisely without a real Studio session anyway.
- The alien carrier reveal (Sequence 13) is built ad hoc inside that one
  shot rather than in `Env.lua`, since nothing else ever needs it - it's
  destroyed along with everything else when `Env.destroy()` runs.
- Total cinematic runtime is tuned to ~350s (`Config.Cinematic.
  TotalTargetSeconds`, ~5.8 minutes) via `Config.Cinematic.Shots`, at the
  low end of the requested 5-7 minutes on purpose - it is skippable end to
  end via hold-to-skip regardless.
- **Not verified in a real Studio session** - no Studio/Vinegar runtime
  exists in this container, same standing caveat as every other entry in
  this file. Verified via `./tools/check.sh` (clean) after every substantive
  edit and extensive hand-tracing (camera marker names resolve, CFrame
  composition order for the drill spin/door slide was worked through
  explicitly, joint names match real R15 Motor6D names, chain/eye/limb
  state is captured once in each shot's `enter()` rather than re-derived
  every frame). Treat as "should work" until someone plays it in Studio -
  this is the single most important next step for this feature specifically.

## 2026-09-15 session: North Pole cinematic visual rebuild

The North Pole opening was rebuilt in place while preserving the existing
`Main.client.lua` Start Game call, `ChapterOneDirector` handoff, and
`SkipScene01` remote. The old client-local visual recipes were copied to the
inactive `OpeningCinematic_Backup/` folder before replacement; no duplicate
controller or remote was added. The replacement uses a layered Arctic set,
separate command/ancient/prison stages, detailed expedition modules,
tracked vehicles, working drill parts, a 94-shot ~3:30 timeline, articulated
humans with facial geometry and expressions, a jointed kneeling Aegis Zero,
and an articulated Sovereign/warden reveal. `OpeningCinematicGui` now owns
responsive subtitles, location/title cards, letterbox bars, safe-area layout,
and hold-to-skip. Camera shots use live subject focus plus Studio-only
obstruction/inside/bounds/light reports and `[ / ]` shot stepping.

Audio is intentionally nonblocking and centralized in
`src/shared/OpeningAudioConfig.lua`; every field is empty until the project
has authorized recordings. `docs/OpeningAudioAssets.md` is the complete
recording/asset checklist. Static validation (`./tools/check.sh`) and a Rojo
place build pass. A full Play-mode watch remains required; Studio is not
available as an in-session runtime connector here.

## 2026-09-15 session: targeted quality pass on the North Pole opening

A "major quality pass" request came in describing the opening as feeling
like a prototype (static camera, frozen characters, over/under-exposed
scenes, VFX standing in for animation). Inspecting the actual current code
(built in the visual-rebuild session directly above this one) found it
already far more capable than that description on paper - real facial
geometry with live brow/eye/mouth posing, a walk/breathing cycle, gradual
foot→hands→full-body reveals for both Aegis Zero and the Sovereign, an
obstruction/embedding-avoiding camera, a working sound-mixer. Rather than
rebuild any of that, this session hunted for concrete, verifiable gaps
between that code and the specific complaints, and fixed five real ones -
Studio remains unavailable in this container, so "verifiable" here means
"wrong on inspection," not "confirmed by eye":

1. **Lighting was overexposed for exactly the scenes it needed to be moodiest.**
   `Lighting.lua`'s dark/interior presets (`ancientInterior`, `chamber`,
   `prison`, `emergency`, `blackout`) had `Brightness` values of 1.25-1.5 -
   inconsistent with their own doc comments ("room tone dark", "low-key",
   "near-total darkness") and with rule 16's "keep shadows dark but
   readable." Rebalanced all five to 0.05-0.5 base brightness with matching
   `ExposureCompensation`. `emergency()` specifically was rebuilt per rule
   17's exact ask - dark **neutral** shadows now carry the scene; the red
   comes only from `env.redLights`' placed practicals plus a small cool fill,
   not a flat red-tinted Ambient.
2. **The mecha and the alien moved with the identical easing curve** (or no
   easing at all - see next point), which is why they wouldn't have read as
   different creatures in motion. Added `heavy()` (Perlin quintic
   smootherstep - zero velocity *and* zero acceleration at both ends) inside
   `Cast.setAegisAwaken`/`setAegisRise`, and the opposite `sudden()` curve
   (holds near-still, then one fast controlled burst) inside
   `setCreatureEyes`/`setCreatureLimbUnfold`, with the Sovereign/Warden's
   head committing to a turn before its limbs do ("its head may turn before
   its torso," implemented literally via an earlier `holdUntil`).
3. **`Sequences.lua`'s per-shot `op.update(a)` callbacks were receiving raw
   linear alpha with no easing applied anywhere** - the character-animation
   equivalent of "robotic constant-speed movement." Point 2's fix lives
   inside `Cast.lua` specifically so every existing call site benefits
   without being touched individually (drill rotation and vehicle travel,
   which correctly want a spinning motor's/already-smoothed motion's literal
   linear or self-eased input, were left alone on purpose).
4. **Every dialogue shot used one identical camera relationship to the
   speaker** - `human()`'s `shot.from` formula never varied by who was
   speaking or which line it was, so ~35 dialogue shots across the whole
   cinematic were framed identically. Added a per-character `speakerSide`
   (a lightweight stand-in for the 180-degree rule, so cuts between speakers
   read as real shot/reverse-shot coverage) and a per-shot distance
   variation, plus an opt-in `reactOn` param used on three pivotal lines
   (Hale's "greatest weapon"/"we did not cross half the planet"/"we did it")
   to frame Lyra's reaction instead of the speaker - rule 28's "show
   reactions," used sparingly on purpose rather than on every line.
5. **A single gesture anchored to line-start decayed to nothing after 1.3s**,
   so any line longer than that (several run 3-6s) left the speaker's arm
   static while they kept talking - the literal "characters cannot remain
   frozen while speaking" bug, on the longer half of the dialogue. Replaced
   with two summed different-frequency sines so the hand keeps moving for
   the whole line without the fixed period reading as a repeating loop
   (rule 5's "avoid repetitive looping gestures").

Also: added a `pace` field to `Camera.applyShot` (`"Slow"`/`"Fast"`/default
smoothstep - three dolly feels instead of one constant curve for every shot),
applied `"Slow"` to the five reveal-scale shots (`04_WorkingBaseReveal`,
`10_AegisFoot`, `11_HandsHoldChains`, `12_FullKneelingGuardian`,
`18_PrisonAndFrozenArmy`) and made `handheld` shots default to `"Fast"`;
added a real `"Listen"` reaction pose (weight shift + forward lean) so
non-authority listeners stop defaulting to generic `"Idle"` while someone
else speaks; made the four Aegis-awakening shots (`21`-`22c`) call
`Light.chamber(a)` every frame instead of once at shot-start, so the room's
warmth escalates continuously with the core instead of jumping in four
discrete steps.

**Deliberately not touched:** the environment, VFX, sound, and UI systems,
per this request's own explicit "do not add more props/particles/neon/UI"
instruction - all four were already well short of that failure mode on
inspection. **Also out of scope, flagged rather than silently absorbed:**
sections of the request describing mecha-punch/energy-attack combat
cinematography and Warden combat AI describe the *real gameplay* combat
system (`CombatService.lua`, `MechaAnimator.lua`, `EncounterService.lua`,
`WardenRig.lua`) - separate from this opening cinematic, which never shows
Aegis Zero fighting (only awakening and struggling once against the
Sovereign in `32_FinalStruggle`). If that system should get the same
animation-over-VFX treatment, that is a distinct follow-up task against
different files. Verification: `./tools/check.sh` clean after every edit;
no Studio session (same standing limitation as every entry in this file).

## 2026-09-16 session: bug-fix / restoration pass on the North Pole opening

The user reported a full playthrough of the prior session's rebuild and
found it badly regressed: scientists deforming into impossible poses during
animation, the humans no longer reading as Roblox characters, lighting
swinging to near-black for large stretches, the cinematic ending roughly
halfway through (alien/mecha/explosion/aftermath never playing), and the
post-cinematic handoff dropping the player against exterior building
geometry instead of "inside his house." Framed explicitly as a bug-fix pass,
not new content - see the user's own numbered brief for the full spec this
session worked against.

**Root cause of "story ends halfway" (the most testable failure) - found and
fixed first, before anything else.** `Opening.start` wraps the entire 38-shot
cinematic in one `xpcall`; any uncaught error anywhere aborts every remaining
shot and silently hands off to gameplay via `finalize()`, only `warn()`-ing to
an output console the player never sees. `Sequences.lua` had three shots
(`17a_GiantClaw`, `17b_FoldedLimbs`, `19_FingerMovement`, right where the
player descends to view the Sovereign) calling
`c.sovereign.model:FindFirstChild("Claw1"/"Limb3"/"Talon1_1")` - names that do
not exist anywhere on the rig `Cast.lua`'s `biomech()` actually builds
(`Digit1Base`, `LeftForearm`, etc.) - a rename that was never propagated to
the call sites. The first of the three (`17a`, ~45% through the timeline)
threw `attempt to index nil with 'Position'` the instant its `subject()`
returned nil, killing shots 17b through 38 - the argument, activation, alien
breakout, disaster, sacrifice, explosion, aftermath, signal/carrier reveal and
title, i.e. everything the user described as missing. Repointed all three at
real parts (`RightHand`, `RightForearm`) and re-posed the finger-twitch beat
onto the real `RightWrist` joint instead of a phantom `Talon1_1`. This alone
very likely explains "cinematic ends around the Guardian reveal."

**Human rig and animation, fully rebuilt** (`src/client/NorthPole/Cast.lua`;
`HumanShell.lua` and `HumanMotion.lua` deleted outright, not deprecated in
place - see the superseding note atop `docs/visual-rebuild/REVIEW.md` for
why the prior pass's own construction is the deformation bug's real cause).
Per explicit instruction: keep the zero-uploaded-asset/no-asset-ID rule (still
procedural parts, never `CreateHumanoidModelFromDescription` or real R15
avatar meshes, which would pull in Roblox's own catalog assets), but rebuild
the STRUCTURE to read as R15, not just reshape the old one.
- `Cast.buildHuman` now builds body segments as plain rectangular blocks
  sized and jointed to R15 proportions and hand-verified against the brief's
  own ratios (computed from the actual joint-offset chain, not eyeballed):
  head ≈15.0% of standing height (target 14-16%), shoulder width ≈2.25 head
  widths (target 2.1-2.4), legs ≈48.5% of standing height (target ~50%),
  relaxed hand falls to upper-thigh height just below the hip line (target
  upper/mid-thigh). No ball/wedge geometry sits at any joint (no shoulder
  balls, elbow balls, knee spheres, floating connectors) - segments meet
  directly at the pivot. `HumanShell.lua`'s loft/triangle-mesh shell system
  (the actual source of the "custom pseudo-realistic humanoid" look, and,
  via its post-hoc shoulder `C0` mutation without repositioning the geometry
  built from it, a real contributor to the visible deformation) is gone
  outright, not layered under a toggle.
- The face is now 7 flat blocks (2 eyes, 2 pupils, 2 brows, 1 mouth) instead
  of 11+ ball-shaped parts (eye socket/white/iris/pupil/brow x2,
  nose/mouth/lower-lip, ears x2) plus per-character realism details (Voss's
  7-part stubble, Hale's weathered-cheek marks, Lyra's scarred eyebrow) - all
  dropped. Character distinction is now carried entirely by clothing colour,
  hair colour, scale and accessories, exactly as instructed, not sculpted
  anatomy.
- **Single animation owner, added rotation clamps.** The real "two systems
  fighting over one joint" bug was Lyra-specific: `Cast.stepAnimate`'s own
  phase branches wrote Waist/Neck/Hip/Shoulder every frame, then (only for
  `r.kind=="Lyra"`) `HumanMotion.apply` overwrote most of the same joints a
  second time with an independently-authored set of poses. Merged into one
  function, one call site (`PerformanceDirector:update` -> `Cast.stepAnimate`,
  unchanged), applied uniformly to every human, not just Lyra. Kept
  `HumanMotion`'s better behaviours (distance-driven walk cycle so feet never
  slide, per-person idle micro-action offset, two-sine speak gesture that
  never goes static on a long line, eased look-target ramp-in) and dropped the
  duplicate/dead ones (`Cast.applyPose` and a raw override both claiming the
  same phase for Monitoring/CheckingTablet/Brace - only the raw branch, which
  always won anyway, is kept now). Added `JOINT_LIMITS` in `Cast.evaluate`: a
  hard per-joint rotation clamp (decomposed via `CFrame:ToOrientation`,
  reclamped, recomposed) applied only when `r.human` is set, so it can never
  affect Aegis Zero or the Sovereign/Wardens, which intentionally move outside
  human ranges. This is a last-line safety net on top of already-modest
  authored pose values, not the primary source of natural motion, and is
  exactly the "clamp every procedural joint" ask.
- Every human (Lyra/Voss/Hale/scientists/soldiers/workers, ~24 characters)
  shares this one `buildHuman`/`stepAnimate` path already, so there was no
  separate "build one prototype, then propagate" step needed - fixing the
  shared function fixed all of them at once.
- **Cannot be visually confirmed in this container** (no Roblox Studio, same
  standing limitation as every prior session). Verified instead by: hand
  deriving the standing-height/shoulder/leg/arm ratios from the actual
  joint-offset math via a small script (not eyeballed), grepping for and
  confirming zero remaining ball-shaped parts in the face/body construction,
  and `./tools/check.sh` clean after every edit. A real Studio playtest
  specifically watching the scientist section for any remaining deformation
  is the load-bearing next step - more than for anything else in this file.

**Lighting readability** (`src/client/NorthPole/Lighting.lua`). The
centralised-controller/single-managed-instance structure this asked for
already existed and was already correct: one `NPLighting` module owns every
cinematic mood, every preset sets every relevant property in full (no stale
carry-over between scenes), and `World/Sky.lua`'s `add()`/`clearManaged()`
already prevents duplicate Bloom/ColorCorrection/Atmosphere instances from
ever stacking (confirmed by grep - only one creation site exists). What was
actually too dark: `ancientInterior` (Brightness 0.45->0.62, Exposure
-0.15->-0.05), `chamber`'s pre-awaken base (0.4->0.55, -0.12->-0.02) and
especially `prison` (0.32->0.58, -0.15->0, Ambient brightened and shifted
warmer) - the alien-reveal scene the brief specifically called out
("silhouette must separate from background, never a black screen with two
glowing dots"). `blackout` (used only for the deep-space shots 36-38, where
near-total darkness is the correct mood, not a bug) and `emergency` (already
corrected in the prior "targeted quality pass" session) were left alone.

**Player spawn: a real Kai's-bedroom addition, not the garage exterior**
(`src/server/World/Neighborhood.lua`, `src/server/ChapterOneDirector.lua`,
`src/client/Opening.lua`). Checked first, before building anything: this
codebase never had a house/bedroom - Scene 1 previously spawned the player
outdoors at `Neighborhood.SpawnCFrame`, right next to Daren's garage. Per
explicit instruction, added exactly one small addition rather than a new
environment: `buildHome()` builds a small living-area+bedroom volume in the
airspace directly above Daren's garage (inside its existing 20x13 footprint,
well clear of the sloped roof and both neighbouring apartment buildings -
checked numerically, not by eye, since the block's existing footprint is
tight: apartment/garage margins computed from `City.lua`'s actual call
`Neighborhood.build(folder,-52,52,36,...)` before committing to a wall
position), reached by a compact switchback exterior stair
(`buildHomeStair`, modelled on this same file's existing `buildFireEscape`
pattern) hugging the garage's west wall. One interior partition splits a
small living area (bench, side table) from Kai's bedroom (bed, desk, chair,
lamp, shelf with one framed photo - the personal object tying the room to
Daren). `KaiBedroomSpawn` is a dedicated CFrame, not the model's pivot,
checked by hand against every piece of furniture and every wall with a
1.1-stud safety margin (wider than an R15 character actually needs) via a
short verification script - clear on every axis.
`ChapterOneDirector.begin()` now does the actual `PlayerService.teleport`
that was missing before (the exterior `SpawnCFrame` was previously only ever
used as a checkpoint, never explicitly teleported to - the Roblox
`SpawnLocation` object placed there was doing the real positioning) - the
first-time path now teleports to `KaiBedroomSpawn` and updates the
respawn checkpoint to it; `beginDelivery()` (once Daren's conversation
resolves) moves the checkpoint forward to the exterior spot so a later death
mid-delivery does not send the player back upstairs. The objective text
changed from "Talk to Uncle Daren" (he was in proximity-prompt range at
spawn before) to "Go downstairs and find Uncle Daren" - the ProximityPrompt
trigger itself (`onDarenTriggered`) needed no change at all, since it was
already purely range-gated. **A real ordering bug caught and fixed before
this could ship**: the client (`Main.client.lua`'s `enterGameplay`) restores
the gameplay camera and sends the `MenuState=false` action that triggers the
server-side teleport in the same breath - since that action is a fire-and
-forget remote, the camera could have been revealed pointed at the player's
old position for a network round trip before the teleport visibly landed,
exactly the "camera restores before player is positioned correctly" failure
the brief explicitly listed. Fixed in `Opening.lua`'s `finalize()`: the
cinematic's own already-opaque blackout frame (the title shot already ends on
one) is kept up and controls kept disabled for a fixed 0.4s hold after
calling the finish callback, before the camera is switched to `Custom` and
the cinematic GUI is torn down - reusing existing infrastructure rather than
building a new establishing-shot camera sequence (a scripted pan was
considered and deliberately cut for scope: it would need the bedroom's
camera CFrame replicated to the client, which nothing today provides).
**Not verified in Studio** - the same standing limitation as everything
above; verified by hand-tracing the actual remote/teleport/camera ordering
and the furniture-clearance script above.

**Explicitly not touched this session, per instruction:** the alien/mecha
rigs and their `heavy`/`sudden` easing curves, `Sequences.lua`'s shot list
and camera work (beyond the three broken part references), VFX, audio,
`CutsceneRunner.lua`, and Chapter One's own Scene 2-9 gameplay.

## 2026-09-16 session (continued): foundation-repair pass, part 1 of N

A full playthrough of the previous session's fixes found new, more severe
failures: humans floating/leaning/lying sideways, walking with no ground
contact, heads/bodies occasionally reading as lit from within, wild
brightness swings, the lab interior exposing empty space through a missing
wall, camera clipping, and the Guardian/mecha still reading as primitive
blocks. Framed explicitly as foundation repair, in a strict order (root
orientation -> transform ownership -> standing pose -> ground contact ->
walk -> accidental glow -> architecture -> camera -> lighting -> THEN
Guardian/mecha, not before). **This session completed through lighting; the
Guardian and mecha rebuild (the user's own steps 10-13) has not been started
and is explicitly the next session's work - not attempted here, per the
user's own "do not jump ahead" instruction.**

Concrete, verified-by-reading (not guessed) bugs found and fixed:

- **A 0.31-stud floor-sink bug in every single shot**, introduced by the
  prior session's own rig rebuild. `Cast.buildHuman`'s R15 proportions have
  longer legs than the pre-rebuild rig; every hardcoded character Y-position
  throughout `Sequences.lua`/`Env.lua` (dozens of them) was authored against
  the OLD rig's root-to-sole distance. Recovered both distances by hand from
  the actual joint-offset chain (old: 2.81 studs at scale 1, matching the
  original author's own 2.8/2.95/3.1 literals almost exactly; new: 3.12) and
  fixed it with one added offset at the Root->LowerTorso joint
  (`Cast.buildHuman`, `V(0,0.31,0)`) rather than touching every call site -
  this alone is very likely most of "characters float/sink," since it
  affected literally every placement in the cinematic, not a specific shot.
- **`reactionUntil` was dead state - a real "character stuck leaning" bug.**
  `Cast.react`/`Cast.act` have always computed a `reactionUntil` timestamp
  meant to end a Stumble/Flinch/StepBack reaction, but nothing anywhere ever
  read it - once triggered, a character stayed in that off-balance pose
  through every subsequent shot until an unrelated call happened to re-pose
  them (concretely: Voss and Hale after `15_ChainImpact`'s intensity-0.9
  react() call stayed in "Stumble" through shots 16/17a/17b/17c, ~7 seconds,
  before `18b_SoldierUnderstands` incidentally reset them). Fixed by checking
  it at the top of `Cast.stepAnimate` and reverting to "Listen" once the
  window closes.
- **The Command/lab room was missing its entire front wall.** Floor,
  ceiling, both side walls and a rear wall were built; nothing closed the
  +Z side. Since this room sits alone in an isolated zone 650 studs from
  anything else (`Env.Zones.Command`), any shot looking back through that
  side saw straight into empty space - exactly "the interior exposes the
  void outside." Added the missing wall (`Env.lua`'s `interiors()`);
  checked the chamber and prison vaults too - both are built as full
  360-degree rings already, genuinely enclosed, not missing anything.
- **Added the explicit upright-validation check from the user's own brief**
  (`Cast.stepAnimate`, Studio-only): warns once per actor
  (`[ActorValidation] <name> invalid standing root orientation`) if a
  standing/talking human's actual torso UpVector drops below a believable
  threshold outside an intentional reaction phase. This is a genuine
  diagnostic tool for whatever, if anything, is still wrong at runtime -
  something this session cannot see for itself without Studio.
- **Lighting: the prior session's own darkness fix had likely overcorrected
  into overexposure**, especially combined with unrelated existing practical
  lights it didn't account for. Moderated `chamber`/`prison`'s base
  Brightness back down from last session's values (still brighter than the
  original "too dark" numbers, just not as bright as last session's
  "readability" fix), and separately reduced several practical lamps that
  sit close to where humans stand and talk: the Command room's three ceiling
  lamps (brightness 2, 26-stud range, only 8 studs apart - three overlapping
  falloffs in a 24-stud room), the chamber's four lamps, and the prison's two
  violet lamps (previously brightness 3 at 90-100 stud range, reaching the
  human dialogue positions on the ledge strongly enough to plausibly wash
  them toward white/pink - a real candidate for the "glowing body in the
  cave" complaint). Audited every human-rig part this session and last for
  Neon material/PointLight/SpotLight: there are none - the only Neon on any
  human is a hand-held prop's tiny screen.
- **Hardened the camera obstruction fallback** (`Camera.lua`): the existing
  6-candidate unstick logic had no floor - if every candidate still failed,
  it silently kept the original blocked/embedded position. Added a 7th
  close-in candidate and an explicit last-resort fallback (pull in tight
  along the shot's own direction) so a shot is now never left exactly where
  it was already known to be inside geometry.

**Explicitly not touched, not started:** `Cast.buildAegisZero` and
`biomech()` (the Sovereign/Warden creature builder) - the "still reads as
primitive blocks" complaint. True distance-locked foot IK (current walking
is distance-driven for the leg cycle, per the prior session, but the root
still glides via a plain Lerp rather than true per-foot world-locking - a
real, acknowledged gap, not silently claimed as fixed). Exact walk
start/stop easing choreography (Sections 10-12 of the brief) and the
Guardian/mecha reveal choreography and combat animation (Sections 28-41) -
all flagged as the deliberately-deferred next phase, not attempted this
session.

**Cannot be visually confirmed in this container** - no Roblox Studio, the
same standing limitation as every session before this one. Every fix above
was verified by hand-tracing the actual code path and math (the floor-sink
number in particular was derived from the real joint-offset chain, not
eyeballed) and `./tools/check.sh` clean after every edit, never by watching
it run.

## 2026-09-21 session: opening visual direction, then Phase 0.A (human rig)

Two deliverables, in order, both scoped by the user to stop short of touching
the cinematic itself.

**1. `docs/opening/VISUAL_DIRECTION.md`** - the complete visual direction for
the Chapter One opening as one continuous cinematic: nine overriding laws,
character design sheets (Lyra/Voss/Hale/ensemble/Kai/Aegis Zero/the Sovereign
Below, each with a motion signature, not just a costume), six environment
sheets with camera-legal volumes and named light sources, a 130-shot
prose storyboard from the first frame after Start Game to Kai receiving
control, a continuity ledger, a lighting bible with an emissive budget, and a
12-phase build order with per-phase gates. Runtime budgets at 8:19; a fixed
compression path down to ~7:00 is written into Part 7 rather than left to
improvisation. The brief's "Warden" is mapped to **the Sovereign Below**
throughout, deliberately, to avoid re-creating the naming collision the
2026-09-15 rename fixed. No code was touched for this deliverable.

**2. Phase 0.A - the isolated human rig test bench.** New, additive only:
`src/shared/Human/` (Skeleton, Pose, Locomotion, Actor, Build, Validate),
`tools/phase0a/` (the Studio bench + offline harness) and
`phase0a.project.json` (a second Rojo project, root-level, mapping ONLY
`src/shared/Human` and the one bench script - the game's city/menu/cinematic
cannot appear in that Studio window). **`src/client/NorthPole/Cast.lua` and
every scene module were not touched.** The cinematic still runs on its own
rig; migrating it is later work, gated on this bench passing a visual review.

Architecture, which is the actual deliverable rather than one good-looking
test animation:
- **Additive scalar accumulator.** A frame's pose is a sum of six numbers per
  joint (rx,ry,rz,tx,ty,tz), zeroed every frame and converted to a CFrame
  once, on top of a constant rest pose. Nothing is ever multiplied into the
  previous frame's value, so accumulation has no state to collect in, and a
  settled layer contributes literal zero, so neutral return is bit-exact.
  The old `Cast.evaluate` used `previous:Lerp(target,0.22)`, which can only
  approach neutral asymptotically and always leaves residual rotation.
- **One owner per joint, enforced.** Root/Waist/Neck/Shoulders/Elbows/Wrists
  are written only by additive layers; both Hips/Knees/Ankles are written only
  by the IK. `Pose.add` throws if a layer touches an IK-owned joint, so "two
  controllers fighting over one joint" is a load-time error, not an artefact.
- **Legs are always IK.** Planted feet are constant world CFrames, so foot
  slide is unrepresentable rather than tuned out, and the pelvis is lowered
  whenever a leg would otherwise overreach, so feet never hover or stretch.
- **The world root cannot pitch or roll.** It is built as
  `CFrame.new(pos)*CFrame.Angles(0,yaw,0)` from a single scalar. "Character
  became horizontal" is no longer a bug that was fixed; it is a state that
  cannot be expressed.
- **Bend directions derived, then geometrically self-checked.** -Z is forward
  for this rig (confirmed twice: the foot's own pivot offset, and
  CFrame.lookAt), and `CFrame.Angles(t,0,0)` swings a hanging limb toward -Z
  for positive t. Therefore knees bend with NEGATIVE x and elbows with
  POSITIVE x. **`NorthPole/Cast.lua` currently uses the opposite sign for
  knee, elbow and shoulder** - a strong candidate for the long-standing
  "knees bend backward" and "arms pass through the torso" reports. The new
  limits make the wrong direction unreachable, and `Validate` re-checks the
  result geometrically every frame (knee pivot must be forward of the
  hip-ankle chord; elbow pivot behind the shoulder-wrist chord) so the
  derivation is never load-bearing on its own.

**Offline verification is real this time.** The Luau CLI was fetched into
`tools/.bin/luau`, and `tools/phase0a/offline/` bundles the REAL module source
against a CFrame/Vector3 shim so the rig maths executes headlessly. Current
result, all passing: IK ankle placement error 0.000000 across a 250-target
grid; knee and elbow direction 0.000000; a 54.7s run of the full demo timeline
with every validator check at 0 failures; 40 repeated gestures bit-identical
to the first; exact neutral return on every pose-owned joint; and 0.750
steps-per-stud at both 1.3 and 2.6 speed, i.e. the cycle is distance-driven.
Three real bugs were found and fixed this way before anything reached Studio:
the ankle transform put the foot's CENTRE on the target instead of its pivot
(every sole 0.145 studs off the floor), the walk's deceleration curve
asymptoted so the command never completed, and the walk's settle restarted
itself every frame.

**Visual review, same session: Phase 0.A FAILED its first look, then was
fixed.** Two corrections to standing assumptions in this file, both load-bearing:

1. **Roblox Studio IS available in this container** - Vinegar is installed
   (`~/.local/share/vinegar`, `RobloxStudioBeta.exe`, a `studio` wine prefix)
   and `:1` is a live Hyprland session. The "no Studio/Vinegar runtime"
   caveat repeated throughout this file is STALE. It was still not used this
   session: driving it means taking over the user's live desktop, and there
   is no input-automation tool installed (`xdotool`/`ydotool`/`wtype` all
   absent; `python-xlib` and `/dev/uinput` are present, so it is possible but
   intrusive). Ask before launching it.
2. **The rig was reviewed visually anyway**, by rendering it offline.
   `tools/phase0a/offline/render.py` is a flat-shaded z-buffer rasteriser
   that draws the exact boxes `Build.lua` builds from the exact transforms
   the modules solve, with a one-stud ground grid, and writes front/side/
   three-quarter/silhouette views and paused action frames to
   `docs/visual-rebuild/phase0a/`. `Build.lua` was refactored so the rig's
   appearance is declarative data (`Build.Decoration`, `Build.colourFor`) and
   the renderer and Studio draw from one source of truth.

**Every numeric check passed and the character still looked wrong**, which is
the entire argument for not trusting validators alone. Four defects, fixed:

- **Proportions were realistic-human, not Roblox.** Head 15% of standing
  height and 0.44 of torso width - inherited from `Cast.lua`, and exactly the
  brief's "low-poly realistic human" failure. Now 19.3% and 0.63, after two
  passes (the first fixed the head but left a long torso on stubby legs with
  1.25-deep "ski" feet).
- **Arms sat inside the torso footprint** (centre 0.85 vs torso half-width
  0.9), so they never separated in silhouette. Now flush outside it.
- **The standing knee bent 23.6 degrees.** `StandCrouch=0.05` studs sits near
  the IK singularity where a tiny length change is a huge angle. Replaced
  with `StandKneeBend` (5 degrees) and the stand height derived from it.
- **The step model did not close.** Swing lasted a full stride of body
  travel, so every foot landed 0.3 strides BEHIND the hip; the walk rendered
  as a collapsed splay. Rebuilt on a consistent budget: lift at TRAIL=0.30
  stride behind, plant AHEAD=0.70 ahead, body travels SWING=0.40 during the
  swing, so it lands 0.30 ahead - symmetric with where it lifted. Stride
  itself is now 0.60 of standing height rather than a bare literal.

Also added: a short first step out of standstill (it was sliding most of a
stud before the first foot moved), and `Loco.squareUp`, which recovers the
neutral stance one foot at a time while idle - without it the final idle
never matched the first, since a walk, a back step and a flinch each leave a
foot wherever it landed. Start and end stance now differ by 0.163 studs on
one foot and nothing else.

After the fixes: all 11 validators still 0 failures, offline checks all pass,
and the rendered neutral/walk/gesture/flinch/final-idle frames read as a
Roblox character. **Studio acceptance is still the user's call** - the
renderer shows geometry and pose, not Roblox materials, lighting or shadows.

**Still not visually confirmed.** Same standing limitation as every entry in
this file - no Studio in this container. The maths is proven; whether the
block rig READS as a Roblox person is exactly the question the offline harness
cannot answer, and it is the actual Phase 0.A acceptance criterion. See
`tools/phase0a/README.md` for the by-eye checklist. Phase 0.B (Aegis Zero) and
0.C (the Sovereign) were deliberately not started.

## 2026-09-22 session: visual foundation repair, and a way to SEE it

A brief came in describing the opening as several unfinished systems placed
next to each other - weak welcome page, fake-feeling car arrival, unstable
talking scene, people who do not stand properly, unfinished environments - and
asked for the foundation to be repaired in a fixed order (welcome page, then
scene 1, then scene 2, then acting) rather than for more effects or story.

Most of the work the brief describes was already in the code from the session
that ended late on 2026-09-21 without logging here: the menu column, the
subtitle/location-card rebuild, the lab palette, the wheel/suspension model and
the restrained dialogue poses all pre-date this session. So this session did
not redo them. It went looking for what was actually still broken, and the
answer turned out to be: quite a lot, none of it visible in the source.

**The important change is `tools/scenecheck/`.** The project could already
prove the opening was geometrically correct (`tools/castcheck`) and could not
look at it at all, and this session needed both. `castcheck` is what caught the
cast standing on the ceiling - it was already asserting that every character
stands inside exactly one ceiling light cone, and reported `inside 0 cones` for
all seven of them, which is only possible if they are above the lights. But no
number anywhere says "this master shot opens on three backs", and that class of
problem turned out to be just as common.

So `scenecheck` bundles the REAL modules against castcheck's shim, runs the
real shots, and rasterises the frames plus a report of where every element
lands as a percentage of the half-frame at its own distance. Read
`tools/scenecheck/README.md` before trusting it for anything: it shows framing,
scale and what is in shot, and it cannot see a light.

Every fix below was found by one of those two tools, not by reading code.

**Three bugs that were silently wrecking the scenes.**

1. **The whole command-room cast stood on the ceiling.** `Cast.floorUnder`
   starts its placement ray 14 studs above the mark (it has to - a ray that
   starts inside a snow drift reports no hit), which indoors is above the
   roof, and a ceiling slab is a solid downward-facing surface like any other.
   Every lead and every technician was placed 12.4 studs up, on top of the
   room they were supposed to be talking in, and the coverage cameras - which
   are built from their heads - went up there with them. The ray now walks
   past anything more than `STANDABLE_RISE` (4 studs) above the author's own
   hint and resumes underneath it. Measured across the built set, the Arctic
   drifts only ever move a mark by 1.3 studs, so the two cases separate
   cleanly.
2. **The prison marks had no floor at all.** Every "Prison" position in
   `STAGING`, the descent walk and the soldier's mark stood the cast at
   PrisonCenter's own Y, where the nearest surface was the cavern floor 13
   studs below. Added the observation ledge the sequence was written to stand
   on (`Env.lua`): a rock shelf continuous with the cavern wall, a rail along
   the drop, the tunnel they came in through, two portable work lamps and
   their kit. It is now the strongest frame in the prison stretch.
3. **`Model:PivotTo` every frame is numerically unstable, and it folded the
   trucks into their own hulls.** PivotTo re-derives each part offset from the
   previous frame's world CFrame, and because a rotation's inverse is its
   transpose, `transpose(R) * R` is `scale^2 * I` - any scale error in the
   stored basis is SQUARED on every call. Measured: the body's basis was at
   0.65 after about a second of driving and the headlamps, cab and frame rails
   converged onto the hull. In double precision that takes ~55 frames; Roblox
   is float32, so it would take about 20. The same call pattern was used for
   the wheels and the ancient door. Replaced with `Kit.rigid`, which measures
   every offset ONCE and re-applies it from a freshly built target - exact for
   as long as a shot runs. `tools/castcheck` now drives the truck 400 frames
   and demands zero drift (result: 1e-12 studs).

   Two related pivot problems, found on the way: `body` was pivoted with no
   PrimaryPart and no WorldPivot, i.e. about a point nobody chose, and
   `env.drill` / `env.commTower` were the same. All three now name their pivot
   explicitly. The shim's `GetPivot` was also taught Roblox's real rules
   (PrimaryPart, else WorldPivot, else bounding-box centre) so it cannot hide
   this class of bug again.

**Every over-the-shoulder shot in the cinematic was playing as a giant face
close-up, and nothing reported it.** Three faults in a row, all in the camera
layer and none of them visible in the source:

  1. `human()` set `other` (the character the shot is taken OVER) to
     `byName[who]` - the speaker. On any shot without `reactOn` that is the
     same person as `subject`, so the guard `other~=subject` was false and the
     over-the-shoulder branch NEVER RAN. Every "Over" shot silently fell back
     to a plain medium taken along the speaker's own eyeline.
  2. Hale's eyeline points across the room at the main workstation, so his
     reverse put the lens about a stud and a half INSIDE Lyra, standing over
     the island.
  3. `Camera.applyShot`'s unstick fallback then did its job: it found the lens
     embedded, could not resolve it, and pulled in to 1.5 studs from the
     subject's face - the giant close-up the brief is about.

`other` is now the speaker's actual counterpart, the over-the-shoulder branch
runs, and shots can declare what legitimately belongs in front of the subject
(`shot.foreground` / `allowed` in `Camera.lua`) so a deliberate foreground
shoulder is never mistaken for an obstruction.

Those were invisible because nothing compared the camera's actual position
with the shot's own, and nothing noticed a lens standing inside a person.
`castcheck` now does both, for all 98 shots: at alpha 0 the distance from focus
must equal the shot's own offset (every fallback candidate changes it), and the
lens must stay at least 1.6 studs from every head and torso in the cast - a
person is about a stud wide, so anything closer is inside them. The first check
immediately found three more shots being silently relocated - `07b_IceFragments` had its lens inside the parked drill
rig's cab, `29d_EvacuationVehicles` sat level with the drift it was looking
across, and `10_AegisFoot` aimed at a focal point inside the chamber floor.
All three are fixed; all 98 shots now play what they declare, and the closest
the lens ever comes to a character is 1.80 studs.

**A real defect found and deliberately NOT fixed:** Aegis Zero's kneeling pose
puts its toe geometry about twelve studs below the chamber floor and its feet
centred exactly on it. That is the Guardian rig, which this file has listed as
deferred work since 2026-09-16 and which the brief also puts after the scene-1
and scene-2 foundation - re-posing a 62-stud mecha is its own job, not a
footnote to a camera pass. `10_AegisFoot` now frames just above the floor so
the shot works; the rig still needs doing.

**Composition and framing fixes, all measured rather than guessed.**

- **The welcome screen's entire foreground layer was outside the camera
  frustum.** The gantry column sat 8 studs past a 5-stud half-frame; the
  platform, rail and crate stack were off the bottom and right. Everything the
  file's own header describes as "the frame" was never in shot, so the
  welcome screen was the mecha alone in an empty bay. The desktop framing is
  now declared once as a constant and the foreground is authored IN CAMERA
  SPACE (`inFrame`/`standing`), with each prop's span quoted as a percentage
  of the half-frame at its own distance. Same bug, same fix, for the approach
  lane: the chevrons ran from 2.6 to 15 studs and the bay floor does not enter
  frame until ~18, so not one of them had ever been seen.
- **The lab master shot opened on three backs.** All three marks look at the
  signal display, and the master was a fixed +Z offset - i.e. behind all of
  them, and behind the workstation they were working at. `master()` now builds
  its camera from the direction the cast is FACING and swings 40 degrees off
  that axis, which is also what stops the display (head height, dead ahead)
  and the island (a four-stud slab) from being between the lens and the scene.
  Lyra and Voss swapped sides of the island so the lead of the scene is the
  face the audience reads first.
- **The over-the-shoulder shots were a wall, not a shoulder.** At 2.3 studs
  back the listener's head filled over half the frame. Now 3.4 back and 1.9
  across, which puts it in the outer lower corner, cropped by the frame edge.
- **The convoy tracking shot was shot through a route marker** parked 3.3
  studs from the lens, at exactly flag height, covering a quarter of the
  frame. Moved out to 19 studs and up above the flag line.
- **The wheel insert was a black rectangle.** Three separate causes: the
  camera sat inside a plough berm so the unstick fallback threw the framing
  away every time; from above the axle the frame was all bodywork at the same
  value as the tyre; and `ArchFlare` was not a flare but a 1.6-stud plate
  standing directly outboard of the tyre, hiding the entire wheel face from
  anything to the side. The flare is now a fin on top of the arch, the flare
  and mud flap opt out of camera queries (thin trim, same rule the route
  markers use), and the lens sits outboard above the berm.

**Colour, because "heads become glowing bright shapes" is an albedo problem
before it is a lighting one.** The lab walls had been dropped to 126-150 to
stop them clipping; the coats had not, and at 178 the people were paler than
the room they stood in. `Cast.lua` now states a budget - no garment above 152,
no skin above 204, the brightest thing in frame should be a light source - and
`castcheck` enforces it on every built surface (facial detail exempt: an eye
white is supposed to be the brightest thing on a Roblox face). Separately the
trucks, which had been corrected from "one glued white prop" into one glued
BLACK prop, were respread so tyre, panel and hull sit roughly 2:1 apart, and
the wheel face got a mid-value rim and five light spokes - the circumference
lugs only show rotation in silhouette, and every shot of a wheel looks at it
from outboard.

**Subtitles.** Voss's 128-character signal line was the longest card in the
cinematic by a wide margin and held for six seconds; split into two beats,
which also earns a cut. The harness cap is now 90 characters (longest is 76).

**Verification.** `./tools/check.sh` clean; `./tools/castcheck/run.sh` 48,418
checks, 0 failures (it began the session at 48,022 checks with 7 failures);
`./tools/phase0a/offline/run.sh` still all-pass; `rojo build` produces a place;
frames and framing reports in `docs/visual-rebuild/scenecheck/`.

One thing tried and reverted, so nobody repeats it: the shim's `workspace:Raycast`
is a vertical ground probe, not a general raycast, which is why
`Camera.inspect`'s obstruction test is only approximated offline. Replacing it
with a proper oriented-box slab test (with a broadphase) worked but took the
harness from 67 seconds to minutes, which is not a trade worth making for a
tool that has to be run after every edit. The approximation is conservative in
the right direction - it reports a camera sitting over geometry, which is the
case that matters - and the framing check above is what actually catches the
consequences. **Still not run in Studio** - the
same standing caveat as every entry above, and it matters more than usual
here, because scenecheck cannot see lighting at all. The lab lighting, the
Arctic exposure and whether the menu's three-point key/rim actually separates
the mecha are exactly the questions it cannot answer.

**Deliberately not done.** Character acting beyond what already existed: the
brief puts it last, explicitly after room, lighting and camera, and the room
and camera work above is what this session had evidence for. The Guardian and
Sovereign rigs (still the standing "reads as primitive blocks" gap). Audio.
Anything in Chapter One's own scenes 2-9.

## 2026-09-22 session: welcome page + Arctic arrival + command room, IN STUDIO

The first session in this file whose claims were checked by watching the game
run. **Roblox Studio was driven directly** (Vinegar on the live `:1` session,
Rojo live-sync, XTEST for input, `grim` for capture), so every "fixed" below
means a rendered frame was looked at, not only that a harness passed. Scope was
fixed in advance at: welcome page -> Start Game -> Arctic convoy arrival -> base
reveal -> the first Lyra/Voss/Hale command-room conversation, and nothing past it.

**The correction that matters most for future sessions: this file has been
saying "not verified in a real Studio session" for a year, and the things that
were wrong were wrong in ways no harness here could have caught.** `castcheck`
was passing 48,422 checks and `scenecheck` was rendering clean frames while the
command-room cast was physically flying out of the room.

### Six bugs found by watching it, with the measurement that identified each

1. **Every cinematic human drifted and tumbled out of the set.** Measured: the
   leads' roots went from y=3 to y=30 (Hale) and y=-9 (Lyra) over one
   conversation, with `up` passing through zero - upside down - while
   `Anchored=true` and `AssemblyLinearVelocity=0`. Not simulation, then. Cause:
   `Kit.joint`/`Kit.weld` unanchor their Part1, so a rig was one physics
   assembly, and `Cast.evaluate` writes member CFrames directly - which in
   Roblox moves the WHOLE assembly, compounding every joint, every frame. Fix:
   rig parts are anchored (`Cast.lua`'s `joint`/`attach`) and `evaluate` now
   also drives the welded decoration from `r.rigid`, which was already being
   recorded and never read. This is the single fix behind "General Hale
   delivering his first line while lying on his side in the snow".
2. **A constant 0.25-stud float on every character**, which the existing
   validator had been reporting 152 times a run into a log nobody read. The
   foot-grounding correction was being eased through `Cast.evaluate`'s 0.22
   pose blend; since moving the pelvis by x moves both soles by x, that settles
   at a fixed point of exactly HALF the gap and never closes. Grounding is a
   constraint, so it now bypasses the blend (`r.applied.Root=nil`).
3. **The menu mecha had never been at Aegis scale.** `heightScale` read 2.25
   while every part was default R15 size: the Humanoid only applies its four
   body-scale NumberValues once the model is in the DataModel, and
   `upgradeMecha` set them on a nil-parented model. It also placed the model
   with `PivotTo`, which positions an R15 rig by its HIP, burying six studs of
   leg under the bay floor - and only the chest was ever on screen, which is
   why a 5-stud avatar passed for a mecha. Fixed with `Model:ScaleTo` (the
   supported, synchronous API, which needs none of that) plus a measured
   stand-on-the-floor lift. `buildPlaceholder`'s model was also never destroyed
   - its return value was discarded, so two mechas overlapped and one leaked on
   every menu open.
4. **Four command-room shots were playing at 1.4-1.5 studs instead of their
   authored 6.8-8.2.** The signal display sat six studs from a cast that all
   face it, so every reverse angle was taken from behind the screen, and the
   unstick fallback - which only tried positions along the same blocked line -
   gave up at 1.5 studs from a face. The panel moved back to z=-9.2, and the
   fallback now ORBITS or RISES at the authored distance before it will give up
   any of it.
5. **The correction re-decided every frame**, so a shot could report a clean
   orbit on frame 1 and render a second later as a head filling half the
   screen, because a listener's breathing had moved the margin. Corrections are
   now held for the whole take, and a mid-shot correction or collapse WARNS -
   the per-shot report only ever printed a shot's first frame, which is how all
   of this stayed invisible. That new warning immediately caught two more:
   `04_GateArrival` collapsing as the truck crossed the lens, and
   `06_ThreePulses` swinging away from its own pulse bars. Both are now
   declared `foreground`, a concept `Camera.lua` already had and `add` did not
   expose.
6. **The signal display's readout was on its back.** The panel is built with no
   yaw, so its local -Z - which is what Roblox calls Front, and what
   `Kit.label` defaults to - faces away from the room. The three pulse bars and
   the printed marking were both on the far side, and the shot that exists to
   show the returning signal rendered as a blank blue sheet.

### Also done, all visually confirmed

- **Frame-rate independence** (`VehicleMotion.lua`, new, `--!strict`, with real
  `VehicleHandle`/`WheelHandle` types). `speed = distance * 60` and a fixed
  0.18-per-frame suspension blend are gone; both now take the real delta, which
  is threaded from `Opening.lua`'s loop through `shot.update` to
  `Env.moveVehicle`. Wheel spin stays distance-derived - it was already correct
  and already frame-rate independent, and was deliberately left alone.
- **`RunService.RenderStepped` -> `PreRender`** in `Opening.lua` and
  `MenuScene.lua` (still exactly one connection for the whole menu scene).
  `CutsceneRunner.lua` was left alone: it belongs to Scenes 2/4/9, which are out
  of scope.
- **The wheel face** rebuilt from ten bright arms to five radial spokes, a small
  hub and one hi-vis timing mark, so rotation is unambiguous in a still frame.
  The fake `HeadlampPool` Neon slab - a hard-edged glowing rectangle rigid to
  the hull - is gone; the real SpotLight already did the job.
- **02_ArcticEstablishing** lowered from 115 studs/24 degrees to 72/10, which is
  what stops it reading as a tabletop; **03_ConvoyTracking** given a nine-stud
  fall-back so the truck visibly pulls away from a lens that used to be welded
  to it; **01_BlackRadio** now lifts out of black onto the convoy's headlamps
  instead of holding five seconds of dead frame.
- **Acting**: gesture amplitude is now a character trait (`GESTURE_RESTRAINT`,
  Hale at 0.3), and the Scan/CheckingTablet pose brings the hands in over the
  console instead of presenting them on a tray.
- **The welcome page** reframed to 34.6 studs with the doorway shifted behind
  the machine, the key and rim raised to the subject's real height, and the
  foreground masses re-placed to crop the edges again.

### Verification

`./tools/check.sh` clean (and the one pre-existing lint warning fixed);
`./tools/castcheck/run.sh` 48,422 checks, 0 failures;
`./tools/phase0a/offline/run.sh` all pass; `rojo build` produces a place. In
Studio, at the end of the pass: **17/17 in-scope shots play exactly as authored
(distance == authoredDistance, no correction), 0 mid-shot corrections or
collapses, 0 `[ActorValidation]` warnings.** Before/after frames and the numbers
are in `docs/visual-rebuild/2026-09-22-opening-pass/`.

### Tooling corrected, because it had been lying

- `tools/scenecheck/render.py` drew a 93%-transparent part as an opaque wash of
  background colour, so the menu's ground haze was ERASING the mecha's legs in
  the offline render while being invisible in Studio. A tool that invents
  occlusion is worse than no tool; parts above 0.6 transparency are now skipped.
- The Roblox shim knew only `RenderStepped`, so it broke the moment a module was
  modernised. It now knows `PreRender`/`PreSimulation`/`PostSimulation` too, and
  `CFrame.fromAxisAngle`.
- `buildPlaceholder` was two-thirds the height of the rig it stands in for, so
  the offline framing report was measuring the wrong object. It is now
  proportioned to the real thing.

### `Model:PivotTo` was suspected, measured, and cleared

`tools/pivotcheck/` settles the assumption `Kit.rigid` was built on. Driving a
25-part truck-shaped model for 4000 frames of translation plus three-axis
rotation: `PivotTo` and `Kit.rigid` drift **identically**, 0.000009 studs, basis
scale 1.00000004. The residual is float32 quantisation, the same for both, not
accumulation. `Kit.rigid` was deliberately NOT removed - it is not wrong and
every vehicle shot is currently verified against it - but new code is free to
use the supported pivot APIs. See that folder's README.

### Deliberately not touched

Anything past "Begin drilling." Phase 0.B, and the migration of the cinematic
onto `src/shared/Human/` (Phase 0.A still awaits approval). The Aegis and
Sovereign rig DESIGNS - the long-standing "reads as primitive blocks" gap - are
untouched; this pass fixed how they are placed, scaled, lit and framed, not what
they look like. `07e_SkippingClock` has the same behind-the-display camera bug
`06_ThreePulses` had, and the excavation workers' `CarryCase`/`OperateDrill`
poses lean the torso far enough to trip the validator; both are outside this
scope and are left reported rather than fixed.

## 2026-09-22 session: Scene 1, the Arctic convoy arrival, IN STUDIO

Scoped to the first Arctic convoy scene only, against a brief listing four
visible faults: the two arriving trucks overlapping when parked, too many cuts
for one simple arrival, a snowfield of rounded balls, and a tiled road. Driven
in Studio (Vinegar on `:1`, Rojo live-sync, XTEST, `grim`) and accepted on
rendered frames, not on harness output. Nothing past `06_CommandMaster` was
touched.

**Parking.** `LEAD_PARK`/`SECOND_PARK` are `BaseCenter+(0,0,16)` and
`+(0,0,34)`: 18 studs apart on an 11.5-stud vehicle. The old 30/38 gave 8
studs, which is less than one truck, so the second truck ended the shot inside
the first. Measured across the whole move rather than assumed - the two bodies'
closest approach is **5.79 studs**, at t=12.1s. `castcheck` now asserts that
every run (`== the arriving convoy never overlaps itself ==`): it drives the
REAL shot at 140 steps and demands the two world AABBs stay apart, which is
sound in the fail direction, plus that the lead parks deeper and both are
stationary on the frame the shot cuts on.

**One camera instead of five.** `02_ArcticEstablishing`, `03_ConvoyTracking`,
`03b_WheelContact`, `04_GateArrival` and `05_WorkingBaseReveal` are replaced by
one 14s crane, `02_ArcticArrival`, focused on the midpoint between the two
trucks and driven by elapsed shot time through a `segmentAlpha` helper. Wheel
rotation is untouched and still distance-derived - the insert is gone, not the
wheel. 94 shots now, was 98.

**The defect that only Studio could find.** The crane reported clean on its
first frame and then COLLAPSED 9.4s into the 14s take: the `GateSign` crossed
the sightline for exactly 2 frames as the lead truck passed under the gate, and
Camera.applyShot abandoned the framing and held a 54-degree orbit for the
remaining 194 frames. One deliberate move became two shots, from two frames of
an object the shot exists to look past. Fixed by grouping the gate into one
model (`env.gate`) and declaring it in the shot's `foreground`, which is
exactly what that field is for. Found by setting `ValidateEveryFrame` on
`workspace.NorthPoleCinematic` so the camera report prints every frame instead
of only a shot's first - that attribute is a diagnostic and was removed again.

**`01_BlackRadio` was corrected for its whole length too**, and the cause was
environmental: `NearIceRidge` was placed at `|x| 26..76` with widths up to 34,
so a ridge reached x=9 - two studs off the roadbed edge, fifteen studs tall.
That is a canyon wall, not near-field relief. The x range is now 44..92, which
puts the nearest face 27 studs out. It is ONE draw in the same position in the
seeded sequence, so nothing downstream of that loop shifts.

**Snow and road.** The ball-based snowfield is gone: one continuous
`PackedSnowField` (1100x3x1100) over the existing ice shelf, with 34 low
two-wedge `snowRidge` crests for wind relief, placed outside the route and the
base footprint. The road is one `GradedRoadbed` instead of 31 tiled blocks, and
the ruts are five long overlapping segments per side that wander slightly in
width and across the roadbed, rather than either one perfect 184-stud stripe or
the old 115 repeated tread rectangles. The apron was rebuilt at 52x44 centred
at z=27 (runs z=5..49) and the two static service vehicles moved to x=-10.5 and
x=16 so the centre lane is clear. Its colour moved from `ice:Lerp(snow,0.22)`
to `0.5` - at 0.22 it was bluer than both the road feeding it and the snow
around it, and read as a rectangle of water dropped into the set.

**Studio result:** `01_BlackRadio` 188 frames, `02_ArcticArrival` 631 frames,
`06_CommandMaster` 170 frames, **0 corrections, 0 blocks, 0 failures, 0
`[OpeningCamera]` warnings, 0 `[ActorValidation]` warnings**. Frames and the
numbers are in `docs/visual-rebuild/2026-09-22-arctic-arrival/`.

### Three tooling bugs fixed on the way, because the tools were lying

The offline renderer could not draw this scene at all, and said nothing:

1. **`tri()` discarded any triangle with a vertex behind the near plane.** Safe
   while every part is small; the new ground is a single 1100-stud slab whose
   every face has corners behind any camera standing on it, so the entire
   snowfield vanished and the frame showed sky where the ground is.
   `draw_floor`'s own docstring had described this hazard for years. Now
   properly clipped (`_clip_near`), at `NEAR=0.0625` - strictly inside
   `Camera.project`'s own 0.05 cutoff, or every clipped vertex lands on the
   reject boundary and the triangle is dropped by the check the clipping exists
   to avoid.
2. **Depth was interpolated linearly in screen space, not perspective-correct.**
   Invisible on a small part; on the ground slab the error was large enough
   that its UNDERSIDE won the depth test against its own top face, so the snow
   rendered as flat ambient-only dark grey. Now interpolates 1/z.
3. **The Roblox shim answered every raycast with a vertical ground probe.**
   That is right for `Cast.floorUnder`/`Env.surfaceY`, which are thousands of
   queries, and wrong for the one caller that fires a long shallow ray -
   `Camera.inspect` - so every downward-looking exterior shot read as blocked.
   Oblique rays now get a real segment-vs-box sweep, honouring `CanQuery=false`
   the way the engine does; near-vertical rays keep the fast path, so the cost
   stays off the ground queries (harness is ~44s, was ~67s before the session's
   other changes). A prior session tried replacing the whole thing and reverted
   it for speed - this splits by ray direction instead. `Random:Clone()` was
   also missing from the shim.

Honest ray-casting made **10 pre-existing shots** report that they are being
moved off their authored framing: `06_ThreePulses`, `07b_IceFragments`,
`07e_SkippingClock`, `14d_GuardianNotBuried`, `18_PrisonAndFrozenArmy`,
`29e_TowerFalls`, `30c_TellThem`, `31b_CanYouStopIt`, `31e_ThousandsOfYears`,
`31f_ProtectTogether`, `37_AlienCarrier`. All are outside this pass (command
room, excavation, prison, closing space shots) and none is fixed here. They are
listed by name in `KNOWN_FRAMING_FLAGS` in `tools/castcheck/run.luau` and
printed every run, so they stay visible - and any shot NOT on that list that
starts failing is still a hard failure. They are flagged, not proven: the sweep
still approximates a wedge and a rotated box by its world AABB. Studio confirmed
one of them directly - `07b_IceFragments` is blocked by
`RotatingAuger.DriveShaft`.

**Not done, deliberately:** anything past `06_CommandMaster`; the Aegis and
Sovereign rigs; audio; lighting (the brief put exterior lighting out of scope,
and the arrival is noticeably hazy/low-contrast in Studio - worth a look, but
it is `Lighting.lua`'s call, not this pass's).

## 2026-09-22 session: the human cast, redesigned as appearance profiles

Scoped to the VISUAL DESIGN of every human in the opening and nothing else.
The rig was explicitly out of bounds and stayed out: Motor6D hierarchy, joint
directions, JOINT_LIMITS, grounding, `Cast.place`, `Cast.walk`,
`Cast.stepAnimate`, the pose library, look-at, the upright validator, foot
correction and PerformanceDirector ownership are untouched. Aegis Zero, the
Sovereign, the Wardens, vehicles, environments, lighting, cameras, story
timing and the Arctic arrival were not modified.

**The problem.** `Cast.buildHuman` built one body and then told twenty-four
people apart by recolouring four values. Everyone got the same flat
rectangular hair cap, the same face, the same collar, the same chest badge,
the same belt, the same `TranslationScanner` in the same hand and the same
`ExpeditionPack` on the same back - the senior officer included. Character
work had started accreting inside `buildHuman` as `if r.kind=="Lyra"`
branches, and Lyra and Voss wore the identical pair of cyan lenses, so the two
scientists in the command room read as a matched set at any distance.

**New file: `src/client/NorthPole/CharacterAppearance.lua`** (`--!strict`),
data only - no instances, no joints, no animation. Hair styles as piece lists,
four face-metric presets, four body-width presets, headwear, eyewear, and one
indexed PROFILE per character. `Cast.lua` consumes profiles; it no longer
contains per-character appearance branches.

**Determinism is the point of the indexing.** Background appearance comes from
`index`, never from `rng` - scientist 3 has the same curls, build and kit on
every replay, so the audience can learn a face instead of watching the room
reshuffle itself. `buildScientist`/`buildSoldier` still ACCEPT an `rng` (their
callers pass one) and deliberately ignore it for appearance.

**Nine hair styles plus three headwear shells**, 2-6 blocks each, never more:
LayeredBob, ShortWolf, SidePart, CrewCut, Undercut, MessyCrop, CurlyTop,
TiedBack, Bald; Helmet, HardHat, Hood worn OVER hair. CurlyTop is five
controlled rounded pieces, not fifty - the environment pass had just finished
deleting a snowfield made of overlapping spheres and a head is not the place
to reintroduce that. Every fringe bottoms out at y >= 0.21 in head-local
space, because the brows sit at 0.17-0.21 and a fringe any lower crosses its
own eyebrows.

**Hair length is not assigned by gender presentation.** Short layered, cropped
and undercut styles sit on female-presenting characters as ordinary choices,
and the longest style in the group (TiedBack, worn up) is not reserved for
them.

**The three leads, as three outlines rather than three costumes:** Lyra -
widest head (layered bob to the jaw, asymmetric fringe), average build, one
small thing in one hand, nothing on her back, single temple AR lens. Voss -
tightest head, tallest, narrowest, one strong vertical (the scarf) down a
deliberately clean front, two thin rectangular lenses. Hale - smallest head
volume (cropped, no volume), widest shoulders by a clear margin via a yoke and
shoulder caps, a long horizontal (the SLUNG rifle) across his hip, a stylized
jaw shadow, and NO scientist scanner or pack. They disagree on hair volume,
shoulder width, head coverage and held silhouette, which is what survives
being rendered as flat grey.

**Equipment now comes from the role.** Four of the eight scientists carry
nothing at all, because a technician at a console has their hands on the
console. Workers get hard hats, hi-vis vests, tool belts, knee pads and one
tool each; security shares a helmet/webbing faction language across three
silhouettes (light scout, standard, heavy lead) with one of the eight
deliberately helmet-off. Worker 1 keeps a `scanner` because
`07c_SampleCollection` and `07d_CompassAnomaly` frame it by name and one of
them recolours it every frame - checked before the universal scanner was
removed, not after.

**Body style is WIDTH ONLY** - a few percent on torso and arm thickness plus
overlay geometry. Not one joint offset, pivot or limb LENGTH moved, because
sole drop, knee/elbow bend direction and hand-clear-of-torso were all
stabilised against the current numbers. castcheck confirms: deepest
hand/torso overlap still 0.0000, minimum knee bow and elbow set-back still
positive, sole drop still scales.

**A dead feature found and fixed while parameterising the face.**
`stepAnimate` has always computed a per-expression brow tilt and written it to
`SetAttribute("ExpressionTilt", ...)` that NOTHING anywhere read - so every
angry, sad and frightened face in the cinematic has been rendering with
perfectly level eyebrows. The brow is welded decoration and `Cast.evaluate`
drives welded decoration from `entry.offset`, so holding that entry and
rotating it is the whole fix. The face preset's own rest angle rides on the
same value, which is what separates Hale's heavy set brow from Lyra's.
Separately, the mouth's animated `Size` was hardcoded to `0.2` wide and would
have overwritten every per-character mouth width on the first animated frame.

### Tooling

- **`tools/scenecheck/run.sh lineup`** (new `lineup.luau`) builds every human
  on a neutral stage and photographs the row from front, three-quarter, side
  and **in silhouette**. `render.py` gained a real silhouette mode: any tag
  containing "silhouette" is drawn as flat shapes on a light ground, colour
  thrown away. That is the acceptance test the brief asked for, and it is the
  one question castcheck cannot answer - it proves rigs are CORRECT and has
  never had an opinion about whether twenty-four correct rigs are twenty-four
  different-looking people.
- **castcheck gained a parent-first decoration check.** `Cast.evaluate` walks
  `r.rigid` in insertion order and places each part from `host.CFrame`, so a
  part whose host is ITSELF decoration must come later in the list or it
  trails by a frame - on a turning head that is hair lagging behind the skull.
  Profiles introduced several of these (screen on scanner, antenna on radio,
  lens on lamp, latch on case), so the ordering went from incidental to
  load-bearing. It also checks no accessory is hosted on another character's
  rig. 646 decoration parts across 24 people (26.9 each).
- Two harness call sites were building humans with hand-rolled specs
  (`tools/castcheck/run.luau`'s workers, `Sequences.buildCast`'s workers);
  both now go through `Cast.buildWorker`, so the harness checks the character
  that actually appears in the cinematic. The new module was added to both
  offline bundles.

**Verification:** `./tools/check.sh` clean; `./tools/castcheck/run.sh` 49,699
checks / 0 failures (up from 48,406, the new checks); `./tools/phase0a/offline/run.sh`
all pass; `rojo build` produces a place. Frames in
`docs/visual-rebuild/2026-09-22-cast-appearance/`.

### Studio

The cast WAS watched in the running command room (Play mode, real lighting),
and doing so immediately paid for itself: **Hale's rust yoke edge crossed his
rust coat placket, and the two together read as a heraldic red cross on his
chest.** That is invisible in a flat offline render and obvious the moment a
warm key hits it. The yoke edge is now defined by VALUE - a darker shade of
his own coat - rather than by hue, and the fix was re-confirmed in a second
Play run. Frames before and after are in the docs folder.

What was NOT done is a systematic front/three-quarter/side/silhouette photo
set taken inside Studio. The edit-mode camera cannot be driven from a script -
Studio's own controller overwrites `CurrentCamera.CFrame` every frame, so the
lineup has to be placed relative to wherever the camera already is and then
orbited by synthetic right-drags, which is slow and imprecise. The silhouette
evidence is the offline renderer's; the lighting evidence is the cinematic's
own camera. A lineup at eye level was captured and is in the docs folder.

### Driving Studio here: a capture rule worth keeping

`grim` captures an OUTPUT, not a window, so "Studio has focus" is NOT enough
to make a screenshot safe: anything tiled beside it lands in the frame too.
That happened once this session - Studio was tiled next to the browser the
user was reading, and the frame caught it. It was deleted immediately.

The capture helper now refuses unless Studio is focused AND is the only window
on the active workspace, and it parks Studio alone on its own workspace before
every attempt (it drifted back onto the user's workspace twice). It refuses
rather than captures when that cannot be arranged, which is the right default:
a missing frame costs a retry, a leaked one cannot be taken back.

## 2026-09-23 session: the discovery sequence rebuilt (bore -> facility -> key -> Aegis -> seal failure)

Scope: everything after Hale's "Begin drilling." up to the Warden army's first
light, rebuilt around one rule - **nobody, expedition or audience, knows there
is anything below Aegis Zero until they disturb its seal.** Started from HEAD
`2d47c5f`. The code for this pass was written in a session that ended around
01:14 on 2026-09-23 without committing or logging; this session audited that
work against the brief, added a check, and wrote this entry. Nothing below is
committed yet.

**New modules.** `Instrumentation.lua` (`--!strict`): the expedition's own
diegetic screens - a `SurfaceGui` on a physical console built once, with
typed `DrillTelemetry`/`DrillDisplay`, rows/graph/alert band updated only when
a value changes; `boreConsole` and `fieldMonitor` are two layouts of the same
instrument family (dark field, off-white labels, muted cyan data, amber
alerts, red only for failure). `GlyphLanguage.lua` (`--!strict`): the ancient
script - ten stroke-defined glyphs (Gate, Guardian, Bind, Key, Below, Warning,
Life, Release, Power, Return), `render`/`band`/`ring` helpers that build them
as thin physical strokes with progressive lighting, and two fixed phrases
(`SealAuthority` on key, pedestal, gate socket and Aegis's chest band;
`ChamberWarning` around the chamber). Colour law lives there too: bronze dead /
amber lit for ancient, cyan for human, violet only for what is below.
`Kit.surfaceGui` is the one small helper added to `Kit.lua`.

**Set (`Env.lua`).** The `RotatingAuger` is gone; the bore is a hot-water
plant of five masses (`BoreTower`, `BoreCollar`, `HoseReel`, `HeaterPumpSkid`,
`BoreControlConsole`) with hose over the crown, steam and weathering driven by
`setReelRotation`/`setBoreSteam`/`setBoreWeathering`. An excavation pit with
cut walls, scaffold, shaft-head station and an `AccessHatch` in an exposed
roof. The marble/ivory/gold `AncientEntry` temple is replaced by an abandoned
facility (`EntryShaft`, corridor, dead workstations, `GateHall`) in dark metal,
slate and composite with ivory reduced to small armour plates. The inner gate
is a segmented bulkhead with drive drums and lock channels, unlocked in stages
by `setGateUnlock` (key core -> first glyph -> channels -> segments -> drums ->
leaves). `SealKey` in a recessed `KeyPedestal` with matching glyphs, charged by
`setKeyCharge` and moved by `placeKey` into `gateSocket`. The chamber's violet
disc is gone: the lower seal is a closed iris over a dark `ContainmentShaft`,
and `Env.setLowerSealReveal` is the ONLY path that lights anything violet (rim
arcs, prison practicals, the army's sensors, the floor glyphs' state change).

**Sequence (`Sequences.lua`, 106 shots, 317s).** New order: 06i Begin
drilling -> 07a-07g bore/telemetry/progress/pressure drop/void/non-ice/structure
exposed -> 08a-08b hatch, descent -> 09a-09g lab, dead workstation, inner gate,
key, insertion, lock responds, gate unlocks -> 10a-10d Aegis foot/chains/torso/
full -> 11a-11k reactions, glyphs, partial translation ("Below what?" / "I
don't know.") -> 12a-12s external power, core, chest glyphs match the door,
containment strain, signal spike on the human monitor (DIRECTLY BELOW), "It
was never the source", "We were opening a lock" -> 13a-13l seal cracks, chain
breaks, violet below, first partial, eye, Sovereign, Warden lights, first
breakout -> the existing 29a+ disaster/sacrifice/ending, unchanged. Removed:
07a-07f auger shots and every early prison beat (14d, 14e, 16, 17a-c, 18,
18b-d, 19, 19b). `Lighting.lua` gained `abandonedLab()`. `story.txt`,
`OpeningAudioConfig.lua`, `docs/OpeningAudioAssets.md` and
`docs/opening/VISUAL_DIRECTION.md` were updated to the new canon and cue names.

**Harness.** castcheck now fails any shot before `13a_SealCracks` that leaves a
lower-seal light above zero or a rim/emissive part below full transparency, and
checks the reveal actually happens afterwards (mutation-tested: a half-visible
rim fails from shot 1). Its framing waiver list also now fails on waivers for
shots that no longer exist. `./tools/check.sh` clean; castcheck 49,885 checks,
0 failures; six known framing waivers remain (06_ThreePulses, 29e, 31b, 31e,
31f, 37 - all outside this pass).

**NOT verified in Studio.** A Play run was started from shot 14 via
`Config.Cinematic.Debug` but was stopped from the desktop by the user almost
immediately (the user was at the machine); the debug flag was reverted. The
brief's Studio acceptance pass - bore silhouette, console legibility, lab
mood, key/gate readability, Aegis scale, no early violet, the reveal as a
twist - is still owed, along with the screenshots it asks for. Offline frames
are in `docs/visual-rebuild/scenecheck/` (07a-13i). Seen offline and worth a
look in Studio: Aegis in `10d_AegisFullReveal` reads as standing rather than
kneeling (the long-standing Guardian rig pose gap, not touched here).

## 2026-09-23 session (continued): the excavation gantry, IN STUDIO

Scope: only the transition from "the bore detects a void" to "the access
structure is exposed". Started from HEAD `750f993`. The bore FOUND the
structure; a second, much larger machine now EXPOSES it.

**New: `src/client/NorthPole/ExcavationRig.lua`** (`--!strict`) - the gantry
only. Two crawler bases (x=+-16, 20 long, on timber crane mats), two braced
towers, a twin box-girder bridge (deck at y=32.6), machinery houses to 36.6 and
light masts to ~39, a carriage that travels +-8 along the bridge, a telescoping
mast, and a ~10 x 8.6 x 10 cutter head (thermal body, two support rings, six
raked cutting sectors, hose manifold, extraction stub, hi-vis rotation mark).
Service walkway with rails along the bridge, an operator station and ladder on
the left tower, festoon and mast hoses that are re-placed from their end points
every frame, a slush return line down the right tower to a separator and a
discharge to the spoil heap, six SpotLight work lights, two steam emitters.
Overall ~36 wide x 20 deep x ~39 tall - about seven people high. Painted
muted ochre on purpose, so it never merges with the grey bore plant. Motion is
three numbers (carriage, depth, spin) applied through `Kit.rigid` from stored
rest transforms - never accumulated.

**`Env.lua`:** the three-bench pit is replaced by an opening 26 wide x 36 long
(`Env.Cut`), snow over ice down to a trench floor at -16, roof top at -12:
kerfed cut faces, cutter-pass ledges, soldier piles and walers, drainage
trenches with pumps, a scaffold stair down the -Z end, barriers, survey stakes,
a spoil heap, rim lamps, a ground ring out to 160 studs. The roof now has a
straight full-width seam, ribs, the dead glyph band, side walls and buttresses
visible in the trenches, and a raised armoured coaming round the hatch
(`env.accessBulkhead`, hatch at z=11.5). Six ice-cover strips are lowered by
`Env.setExcavationProgress` (centre first, ends last); the hoist, power station,
lamps and crates on the roof are hidden until progress is 1.
`Env.cutterDepthFor` puts the head's teeth on the ice surface. A second copy of
the bore plant (`env.surveyPlant`, built into a throwaway table) stands beside
the gantry for the scale comparison.

**A pre-existing bug fixed on the way:** the bore tower's diagonal braces scaled
WORLD positions instead of corner offsets and then added the bore origin again,
so the real plant has had sixteen hair-thin beams ~8,000 studs tall since the
bore rebuild. Invisible at x=0; the copy at x~786 threw them sideways into the
lab and chamber stages, which is how castcheck found it.

**Shots:** `07g_StructureExposed` is replaced by `07g_ExcavationGantryEstablished`,
`07h_ExcavationBegins`, `07i_CutterDescends`, `07j_StructureRoofExposed` (new
line, Voss: "Straight edges. Seams. Somebody built this."), and
`07k_AccessTunnelRevealed`; `08a`/`08b` re-aimed at the new hatch. New stage
`ExcavationRim` (the leads behind the rim barrier); `Excavation` marks moved to
the new roof. Crew are placed on the machine for scale (walkway, operator
station, beside a crawler, far rim, a scientist at the barrier). New audio
names: `Machinery.GantryIdle/GantryStart/CutterLoad`, `Dialogue.VossBuilt`.
110 shots, 339.8s.

**Verified in Studio** (Play, debug start at shot 23): 07g-08b all play
exactly as authored (`corrected:false`), no mid-shot corrections, no
`[ActorValidation]` warnings. Frames in
`docs/visual-rebuild/2026-09-23-excavation/`. The excavation plays at night
under the gantry's work lights (the `Cut` preset is `Light.exterior(1)`), which
reads well for scale but leaves the far set dark. castcheck 49,914 / 0
failures; check.sh clean.

**Not re-watched after the last edit:** the 07j fix moving the far-rim worker out
of frame (from straight above he read as lying down) is verified offline only.

## 2026-09-23 session (continued): the cast as Roblox avatars, IN STUDIO

Scope: the VISUAL look of every human in the opening, nothing else. Started
from HEAD `4c31411`, with a previous session's uncommitted edits for this same
pass already in the tree (Cast.lua body/accessories, CharacterAppearance.lua
hair/faces/profiles, the lineup benchmark dummy). This session audited that
work, finished it, and checked it in Studio.

**Unchanged by design:** Motor6D names and hierarchy, joint HEIGHTS and limb
LENGTHS (sole drop still 2.81 at scale 1, the 0.31 Root offset intact),
JOINT_LIMITS, `Cast.place`/`walk`/`stepAnimate`, grounding, look-at, the
upright validator, PerformanceDirector.

**Body (`Cast.lua`, `HEAD_SIZE` and the constants beside it):** block head
1.3 x 1.25 x 1.25, up from 0.8, which puts it at the classic-avatar ratio to
the torso. Torso 2.2 wide (x torso style). The lower torso hangs 0.2 below its
joint and covers the top of the thighs like a belt line, with the waist and hip
offsets moved by the same 0.2 so no pivot moves in world space. Arms and legs
are ONE width top to bottom, hands and feet included. Shoulder and hip spacing
now come from the torso width, so arms sit flush outside it. Every accessory
offset is written against the named torso/head dimensions (`p.uh/ud/lh/ld/lt/fz`,
`HEAD_FRONT`) rather than literals. The face is flat and graphic: solid dark
eyes with one glint, bar brows, and a bar mouth that the existing expression
code animates.

**Appearance (`CharacterAppearance.lua`):** every hairstyle rebuilt as two to
seven chunky masses wider than the skull. `tall` pieces are hidden under
headwear so they can't punch through a helmet. Lyra's bob gained jaw-height
flare blocks, the one change that separated her head from Voss's in flat
silhouette. Headwear shells are bigger. Eyewear is sized to read at medium
distance: Voss wears heavy dark frames, Lyra a single temple lens with an ear
pod, and goggles come down or pushed up. The outfit families are each an
OUTLINE: field parka (Lyra), lab coat with lapels and skirt, analyst long coat,
commander greatcoat, technician jacket, worker coveralls, security armour.
Coat skirts hang from the upper legs so they swing with the walk. Equipment is
larger and more varied: Lyra's scanner is now an orange pistol-grip
instrument with an antenna, deliberately unlike Voss's flat tablet. Other
items are a clipboard, a work pack, a headset for Hale, and rifles with
magazines.

**Studio found one regression the offline tools did not.** The over-the-
shoulder reverse (`human()`, `shot="Over"`) was tuned for the 0.8 head. With
the new head and bob, Lyra's hair covered half of 06a/06c/06f/07f2. Moving the
lens further back does NOT fix this: the listener sits at `lateral*D/(back+D)`
off the lens axis, so a longer throw pulls them toward frame centre (tried; it
also backed the lens into a technician). The fix scales the LATERAL offset by
`Cast.HeadSize` and raises the lens (`OTS_BACK/ACROSS/LIFT`). Confirmed in a
second Studio run. Separately, the two command-room masters picked up a 16-degree
mid-shot orbit, most likely the bigger heads grazing the sightline to the leads'
centroid. `master()` now declares the three leads as `foreground`. That fix is
verified OFFLINE ONLY: the user had limited screen time and it was not re-watched.

**Tooling:** `tools/scenecheck/dump.luau` now captures every over-the-shoulder
shot (06a, 06f, 07f2, 09c2, 11j, 12a). The lineup has a six-block classic
dummy for comparison and a wider `GAP`.

**Verification:** `./tools/check.sh` clean; castcheck 50,298 / 0 failures
(closest lens-to-person now 2.79 studs, was 1.80); phase0a all pass. Studio:
two Play runs through 06-07g, 0 `[ActorValidation]` warnings, and 06a/06c/06f/
07f2 play `corrected:false`. Frames and lineup are in
`docs/visual-rebuild/2026-09-23-roblox-cast/`.

**Found and NOT fixed (outside this pass):** 11j_HaleBelowWhat and 12a_HaleWake
frame Hale tiny behind a chamber pillar with either old or new OTS numbers, so
it's chamber staging, not head size. Voss's face blows out near white under the
exterior key in 07e2 (lighting). Pre-existing mid-shot orbits in 07a, 09a2 and
11k-12n (also present in a log from before this pass).

**Driving Studio, learned this session:** `vinegar --help` opens Vinegar's GUI
and hangs rather than printing help. Launch with
`GDK_BACKEND=x11 DISPLAY=:1 vinegar <place>.rbxlx`. Build the review place from
a SCRATCH copy of `src` with `Config.Cinematic.Debug` edited there, so the repo
config is never touched. Never `pkill -f` a pattern that also appears in the
same shell command: it kills that shell (exit 144). The user moves between
workspaces while Studio runs; the capture guard refused correctly twice, so ask
again rather than pulling focus back.

## 2026-09-23 session (continued): Aegis Zero redesigned for readability

Scope: ONLY the historical giant Aegis in the North Pole opening. Started from
HEAD `7f5eef5`. The human cast, excavation, lab, key, glyphs, Sovereign,
Wardens, story, command room and convoy were not touched.

**New: `src/client/NorthPole/AegisCinematic.lua`** (`--!strict`) owns the build,
the sealed kneel, the standing pose (review only), the damage, frost, chains,
awakening and rise. `Cast.lua` keeps one-line wrappers (`buildAegisZero`,
`setAegisAwaken`, `setAegisRise`, `updateChains`, `breakChain`) and registers the
model in `builtRigs`. The handle keeps the old shape (`model/torso/head/core/
fingers/chains/chainData/ice/rigid`) so `Cast.fix` still hangs the glyph band.
It evaluates EXACTLY (no 22% blend like `Cast.evaluate`), because the drivers
already ease through `heavy` and the floor contact has to be checkable.

**Design.** The old builder hung the same recipe (3 ivory plates, 3 gold edges,
3 scores, a Neon conduit, a bearing) on every limb and the torso, so no region
had its own shape. Now every region is a shape first, with at most one primary
shell, one light accent and one trim, all from `Palette.Aegis` (was `C.ivory/
gold/orange/metal`). Standing: 60.2 studs, head 8.15 (7.4 heads), shoulders
28.2 across (3.46 heads). Broad upper chest (18.6) tapering by two wedges to a
10.4 lower chest, an UNARMOURED dark waist (5 wide spine + two actuators), a
separate pelvis with a bronze belt and flared hip guards, thin dark gaps at
every joint. Head: one recessed horizontal visor under a light brow, light
cheeks, bronze crest; the two `Eye` parts are gone. Core: dark socket, bronze
ring, rotor, small centre lens - dormant is dark metal, the centre lights first,
then the rotor and the two short channels under it. Neon budget when awake:
visor segments, core, 3 channels (castcheck enforces it). Hands: palm, light
knuckle guard, four two-piece fingers, thumb; the chain's first link sits in
the curl. Identity matches `AegisRig.lua` piece for piece (left-only bronze
crest, bronze gauntlet band, light knee/toe caps, etc.); **`AegisRig.lua` did
not need changes.**

**Damage:** right shoulder shell missing (remnant, torn wedge, hanging rim
fragment, exposed joint and a light actuator); right cheek sheared, brow
chipped, visor cracked into a main band and a fragment that lights last;
three blades in the back at different places, angles and depths; five broad
frost patches on up-facing surfaces only.

**Sealed pose** is authored as absolute segment angles (joint values derived).
Left leg forward, flat foot, knee up; right knee on the floor, shin flat, foot
laid back sole-up. Toes-tucked was tried and is impossible at these
proportions (the foot is nearly as long as the shin; it held the knee 5 studs
up and floated the planted foot 2.7 studs). The root height is never typed:
`ground()` measures the lowest corner and puts it on `floorY`. **The
long-standing "toes 12 studs inside the floor" defect is gone.**

**Placement (`Sequences.lua`):** root at `ChamberFloor+(0,0,-36)`, facing the
room, i.e. kneeling at the seal's RIM. Chosen from the set, not by eye: the
forward foot must clear the iris (leaves slide 15 studs in 13a) and the raised
race ring at r=17.5; nearest floor contact is now r=23.1. Chains are made fast
to two iris leaves (`anchorHosts`), so opening the seal drags them taut before
they break; links sit at a fixed pitch with pre-built hidden spares, so a
stretched chain gets longer instead of gapping. The chest glyph band now uses
`c.aegis.chestBand` (a plate above the core). Shots re-framed: `10a` (old
offset put the lens inside the left chain - brown frame), `10d` (fixed focal
point, lens behind the three leads so they are the scale reference, Aegis
declared foreground since the focus is inside it), `32` (camera had moved
outside the buttress ring). Chamber-mark eyelines now point at the chest.

**Harness.** castcheck: Aegis on the floor within 0.05 in EVERY shot; no
contact inside r=18.4 of the seal; lens never inside any Aegis/chain part
(mutation-tested with the old 10a offset: fails); unbroken chains reach their
anchor with no gaps (mutation-tested with no slack: fails); sealed knee AND
planted sole on the floor; standing both soles on the floor; nothing below the
floor in either pose; energy budget; no `Eye`; one visor band; core recessed
behind its housing lip. 30c/31b/31e/31f were removed from
`KNOWN_FRAMING_FLAGS`: they were being blocked by the old machine and now play
as authored (so they are hard checks again). New isolated bench:
`./tools/scenecheck/run.sh aegis` (clean/finished, standing/sealed/risen, front/
3-4/side/back/silhouette, close-ups, a human for scale, printed dimensions and
contact heights). `dump.luau` also captures 10b, 10c, 12e, 12k, 12l, 12m, 13c,
31a, 31e, 32. `./tools/check.sh` clean; castcheck 51,217 / 0 failures;
phase0a all pass. Captures in `docs/visual-rebuild/2026-09-23-aegis/`.

**NOT verified in Studio.** Everything above is offline geometry. Owed: 10a-10d,
12e-12m (awakening), 13a-13d (rise, chain failure), 31e, 32 in Play mode.
Specific things the renderer cannot answer: whether `PlateOuter` (34,48,62)
separates from the dark chamber at all under the real lights (the light accents
may be carrying the whole read); how bright the core's PointLight (40 range,
3.5) is; whether the ice patches read as frost or as blue plates. Known
weaknesses: the laid-back right foot reads a little spiky from the side; the
forward thigh's frost patch reads as a flat blue square in 10c; in the sealed
front view the arms cover the chest-to-waist taper (it reads from 3/4 and when
risen). The pre-existing `Chamber/3` mark-to-floor error (0.872) is unrelated.

## Known gaps / good next increments (roughly priority order)

0. **A real Studio playtest of everything AFTER the command room.** The 2026-09-22
   session drove Studio directly and cleared welcome page -> Arctic arrival ->
   base reveal -> the first command-room conversation; that stretch is verified
   by rendered frames, not by harness alone. Everything from "Begin drilling."
   onward has still only ever been reasoned about, and the six bugs that pass
   found (see its entry) were all invisible to `castcheck` and `scenecheck` -
   so assume the later scenes carry the same class of defect until somebody
   watches them. The 2026-09-23 discovery-sequence rebuild (07a-13l) is the
   first thing to watch - see its entry for the checklist. Also unwatched: the
   full Start Game -> bedroom spawn -> Daren flow.

   As of the Arctic-arrival pass later the same day there is now a NAMED LIST
   to work from rather than a guess: `KNOWN_FRAMING_FLAGS` in
   `tools/castcheck/run.luau` holds the 10 shots whose framing the (now honest)
   obstruction ray says is being thrown away, every one of them past the
   command room. Studio confirmed one directly - `07b_IceFragments` is blocked
   by `RotatingAuger.DriveShaft`. That is the natural starting point for the
   next Studio pass, and each one needs the same treatment the arrival got:
   decide whether the thing in the way is legitimate foreground (declare it) or
   a real obstruction (move the lens).

1. **An actual Studio playtest of the full chapter, start to finish.** See
   above - nothing in this session was verified any other way.
2. **Audio.** Nothing in the project has sound at all — `Config.Cinematic.Sounds`
   ids are all blank strings by design ("no uploaded audio assets"). The
   wiring points already exist (`Config.Cinematic.Sounds`, and every VFX
   function in `Effects.lua` is a natural place to add a
   `SoundService:PlayLocalSound`-style call). This requires the *user* to
   supply or approve asset IDs; do not invent them.
3. **The Sovereign rig**, still "reads as primitive blocks" (2026-09-16).
   Aegis Zero was redesigned 2026-09-23 (see that entry) and its floor defect
   is fixed; it still needs a Studio look.

4. **A dedicated boss defeat cinematic** (real camera work via a cutscene
   controller) rather than the current pose-hold — Scene 8 asks for a real
   finishing sequence (Kai catches the blade, breaks it, delivers the
   finishing strike). `Opening.lua`'s own camera/pose techniques (now the
   North Pole prequel, see the 2026-09-15 entry below) could reasonably be
   adapted for this later.
5. **Chapter 2 onward** — explicitly out of scope for this chapter's mandate.
6. **A Studio playtest of the new North Pole opening specifically** (see its
   own session entry below) — camera marker framing, character scale/
   placement and pacing have only ever been reasoned about, never watched.

## Working agreements for this repo (carried over from README.md — don't relitigate)

- Everything visible is procedural Roblox geometry. No models, no Toolbox
  assets, no uploaded textures, no asset IDs anywhere (audio ids are the one
  sanctioned exception, and only when the user supplies them).
- The server owns health, cooldowns, unlocks, encounter state and dialogue
  progression. The client renders and requests; every remote is validated
  and rate-limited (`RateLimiter.lua`, `Config.Limits`).
- `Palette.Quality.Seed` fixes world generation — it must stay deterministic.
- **Roblox Studio CAN be driven from here, and as of 2026-09-22 has been.**
  Vinegar launches it on the user's live `:1` session; `rojo serve` plus the
  Rojo Studio plugin live-syncs the working tree into an open place; XTEST via
  `python-xlib` sends input; `grim` captures. **Ask first** - it takes over the
  user's only display - and never capture a frame without confirming Roblox
  Studio is the focused window, or you will screenshot whatever they are
  actually doing. Studio writes every `print`/`warn` to
  `~/.local/share/vinegar/appdata/Roblox/logs/`, which is far better than
  reading the Output panel off a screenshot: `[OpeningCamera]` and
  `[ActorValidation]` are already instrumented for exactly this.
  The offline harnesses are still the fast loop, and should be run rather than
  reasoned around - but they are not the acceptance test:
    * `./tools/check.sh` - type-check and lint.
    * `./tools/castcheck/run.sh` - the North Pole cinematic's geometry, rig,
      placement, framing-as-authored, subtitle and albedo checks, against the
      real modules (~70s).
    * `./tools/phase0a/offline/run.sh` - the `src/shared/Human` rig maths.
    * `./tools/scenecheck/run.sh` - renders the welcome screen and the
      opening's own shots, plus a report of where everything lands in frame.
  Nothing in that list can see a light, and none of it caught any of the six
  bugs the 2026-09-22 Studio pass found. Qualify a claim as "checks out and was
  looked at offline" unless you actually watched it run.
