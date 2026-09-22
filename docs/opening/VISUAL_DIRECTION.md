# THE DAY THE SKY BROKE — Chapter One Opening
## Complete Visual Direction: character design, environment design, and shot-by-shot storyboard

**Status: DESIGN ONLY. Nothing in this document has been implemented.**
No script was modified, no rig was rebuilt, no scene was touched to produce it.
It is the locked plan that implementation is measured against, built one scene
at a time in the order given in Part 6.

Covers the continuous cinematic from the first frame after **Start Game** to the
frame where **Kai receives control in his bedroom**. Target runtime **8:19**
(499s), hold-to-skip available throughout (`Config.Cinematic.SkipHoldSeconds`).

---

## PART 0 — HOW TO READ THIS, AND THE RULES THAT OVERRIDE EVERYTHING

### 0.1 Naming reconciliation (read this before anything else)

The direction brief calls the creature "the Warden." **In this codebase that word
already means something else**, and the rename is load-bearing across
`Config.Warden`, `WardenRig.lua`, `CombatService.WardenTag` and Chapter One's
gameplay enemies. To avoid re-introducing the exact naming collision AGENT.md
warns against, this document uses the codebase's canonical names:

| The brief says | This document and the code say | What it is |
|---|---|---|
| "the alien / the Warden" | **the Sovereign Below** | The single huge creature under the ice. The brief's creature. |
| — | **Wardens** | The grunt army frozen around it. Background silhouettes here; real enemies in Chapter One gameplay. |
| "the mecha" | **Aegis Zero** | The machine. Same design the player pilots 15 years later — not a reskin. |
| "Lyra" | **Dr. Lyra Ren** | Kai's mother. Lead of this sequence. |
| "Voss" | **Dr. Elian Voss** | Research lead. |
| "Hale" | **General Corvin Hale** | Expedition commander. |

Everything the brief asks for the "Warden" — anatomy-first reveal, dark body with
violet seams, predatory stillness-then-burst movement — is specified below for
the **Sovereign Below**. Nothing about the brief's intent changes; only the word.

### 0.2 The nine laws

These override any individual shot description below. If a shot and a law
disagree, the law wins and the shot gets rewritten.

1. **Reaction precedes revelation.** A person notices, then the camera looks.
   Never cut to a glowing screen, a moving claw or an energy surge before a
   character in frame has physically reacted to it.
2. **Reveal in parts.** No subject larger than a human is ever first seen whole.
   Foot, then scale, then torso, then silhouette, then the full body — and only
   after it has *moved*.
3. **Rooms are rooms.** Every interior has floor, ceiling, four enclosing
   surfaces, an entrance and a reason for its light. The camera lives inside the
   room. A wall is never deleted to let the camera see. If the camera cannot fit,
   the *camera* moves, or the room is designed larger.
4. **Light has a source.** Every lit thing is lit by a named, placed practical or
   by the sky. No PointLights inside heads or torsos, no Neon on skin or cloth,
   no glowing characters. Aegis Zero's core and the Sovereign's seams are the
   only self-illuminating things in the film, and both are small.
5. **Readability floor.** In every frame, at every brightness: the floor plane is
   visible, every present character's silhouette separates from the background,
   and light clothing still shows fold and shadow. Darkness is achieved by
   lowering key, never by removing fill below this floor. No white-out longer
   than 3 frames.
6. **Motion carries weight.** Mass reads through sequence and settle: the heavy
   thing leads with its center, arrives, then its extremities catch up. Effects
   appear at the contact frame, never before it, and never in place of the
   motion.
7. **Everyone has a job.** No figure stands in frame waiting for dialogue. A
   background character is doing a task with an object, or moving between two
   places for a reason. Nobody freezes because someone else has a subtitle.
8. **The world is continuous.** Damage persists. Smoke persists. Emergency
   lighting persists until an event changes it. A character who ends a shot at
   the left of a console begins the next shot there, unless we saw them move.
   Part 4 is the ledger that enforces this.
9. **No cut hides a defect.** Fast cutting is used for chaos we can read, never
   to conceal a pose that does not work. If a motion cannot be shown, the shot
   is cut from the film — not sped up.

### 0.3 Shot notation

Every shot is written as prose for an animator, with a header line:

`N.NN — NAME · duration · lens · camera move`

Lens is Roblox `FieldOfView`. **70** = wide/environmental, **55–62** = standard
coverage, **40–46** = normal/portrait, **28–35** = long lens, compression and
isolation. Moves: **static**, **dolly** (position travel), **push/pull**
(toward/away on axis), **crane** (vertical travel), **pan/tilt** (rotation from a
fixed point), **track** (following a moving subject), **handheld** (sway enabled;
only where a human operator could plausibly be).

### 0.4 Runtime budget

| # | Scene | Runtime | Shots | Location |
|---|---|---|---|---|
| 1 | Arrival | 0:32 | 7 | Arctic exterior |
| 2 | The Signal | 0:28 | 8 | Command module |
| 3 | The Seam | 0:26 | 7 | Excavation face |
| 4 | The Door | 0:20 | 5 | Ice tunnel |
| 5 | The Guardian | 0:34 | 8 | Aegis chamber |
| 6 | The Warning | 0:24 | 6 | Aegis chamber / myth wall |
| 7 | Time Passes | 0:18 | 6 | Chamber (montage) |
| 8 | The Lab Alive | 0:26 | 7 | Chamber laboratory |
| 9 | The Second Signal | 0:20 | 5 | Shaft / descent |
| 10 | The Sovereign | 0:32 | 8 | Prison cavern |
| 11 | The Order | 0:24 | 6 | Chamber laboratory |
| 12 | Activation | 0:22 | 6 | Aegis chest mechanism |
| 13 | Aegis Wakes | 0:34 | 9 | Chamber |
| 14 | The Prisoner Wakes | 0:24 | 6 | Prison cavern |
| 15 | Containment Fails | 0:28 | 8 | Chamber / tunnel / surface |
| 16 | The Fight | 0:26 | 7 | Chamber floor |
| 17 | The Detonation | 0:22 | 6 | Chamber / surface |
| 18 | Aftermath | 0:24 | 6 | Chamber ruin |
| 19 | Fifteen Years | 0:12 | 3 | Black / title |
| 20 | A Normal Morning | 0:23 | 6 | Kai's bedroom |
| | **Total** | **8:19** | **130** | |

---

## PART 1 — CHARACTER DESIGN

One body language for the whole cast. Everyone is built from the same
`Cast.buildHuman` R15-proportioned block skeleton already in the project (head
≈15% of standing height, shoulders ≈2.25 head widths, legs ≈48.5% of height,
relaxed hand falling to upper thigh). **No character gets a different body
construction.** Identity comes from clothing, hair, silhouette accessories,
posture and motion signature — nothing else. No sculpted anatomy, no face
textures, no realistic humanoid proportions, no bare mannequin bodies.

Faces stay at the current 7-flat-block level (two eyes, two pupils, two brows,
one mouth). Emotion is carried by **posture, head timing and hands**, because
that is what this project can actually render well.

### 1.1 DR. LYRA REN — the one who leans in

*Reads as:* a field researcher who moves toward the thing she does not
understand. The only person in the film whose curiosity outruns her caution.

**Silhouette.** Scale 1.00 (reference height). Off-white Arctic research parka
(`ivory` 210,211,198) cut to mid-thigh, hood down and bunched at the back of the
neck so her head shape stays readable in profile. Dark technical undersuit
(`dark` 25,32,39) visible at the collar, cuffs and below the parka hem. Insulated
boots with a visibly thicker sole block than the other scientists — she is the
one who walks on raw ice. Gloves are dark, thin, and *often off* — the one
costume detail that changes across the film (see the ledger, 4.1).

**Signature objects.** Translation scanner on the left hip, a flat slab with a
small cyan screen, the only Neon on her entire body and no larger than a palm.
Compact radio clipped at the left shoulder strap. A dark wrist device on her left
forearm, plain and unremarkable in this film — it is what receives the core
fragment in the story, so it must be visible early and never explained.

**Posture at rest.** Weight slightly forward on the balls of the feet. Head sits
about 5 degrees ahead of the spine. Shoulders low and loose.

**Motion signature.** She *approaches*. Given any new object, her default is one
step closer, hand half-raised before she decides to touch. Her head turns before
her torso; her torso follows late. When she is thinking, her hands stop
completely — this is her tell, and the film uses it three times (2.03, 8.04,
11.05). When frightened she does **not** step back; she plants and looks harder.

**Camera side.** Screen-right (`speakerSide` +1). She keeps that side for the
entire film.

### 1.2 DR. ELIAN VOSS — the one who checks again

*Reads as:* analytical, cautious, happier with an instrument than with a person.

**Silhouette.** Scale 1.06 — slightly taller than Lyra, narrower. Deep slate-blue
technical coat (37,48,65), high collar, an ivory scarf tail that hangs asymmetric
over his right shoulder — his most recognizable silhouette element from behind
and at distance. Dark trousers, standard expedition boots, utility belt with
cable loops. Small optical lens elements at his temple, cyan, tiny.

**Posture at rest.** Upright but slightly closed: shoulders drawn marginally
inward, forearms near his body, elbows rarely leaving his ribs.

**Motion signature.** **Small gestures only.** His entire gesture vocabulary
lives inside a box about one forearm wide at chest height. He touches equipment
rather than pointing at it. His attention default is *downward at a screen*, so
every time he lifts his head it means something. He notices people before he
notices phenomena — in Scene 2 he reacts to Lyra, not to the signal. Under
stress he becomes *more* still, not less.

**Camera side.** Screen-left (−1).

### 1.3 GENERAL CORVIN HALE — the one who decides

*Reads as:* command. He is not a villain; he is the man who is certain, and
certainty is what breaks the world.

**Silhouette.** Scale 1.12, the largest human in the film. Dark military parka
(25,32,39) with a deep red trim panel at the shoulder (132,66,62) — the only warm
accent in the expedition's palette, which makes him trackable in a crowd from
any distance. Grey hair. Squared shoulder line, reinforced. Boots with visible
hard shell. No handheld instrument, ever: his hands are free, and that is the
point.

**Posture at rest.** Fully upright, weight even, chin level, hands either
clasped behind him or flat at his sides.

**Motion signature.** **Economy.** He gestures roughly a quarter as often as
Voss. When he does move, he moves *once* and completely — a single full turn of
the whole body rather than a head-swivel. He is the fastest in the cast to
react to a physical threat and the slowest to react to information. He steps
*toward* danger to direct other people away from it.

**Camera side.** Screen-left (−1), shares Voss's side — so the film's recurring
shot geometry is Lyra facing the two of them. That is the argument in Scene 11
pre-built into the coverage.

### 1.4 The ensemble

Seven scientists, seven soldiers, seven workers, procedurally varied by colour,
scale (0.92–1.08), headwear and accessory from a fixed seed. Their design job is
to be **legible by role at a glance and busy at all times**.

- **Workers** — heavy orange-trimmed coveralls, hoods up, bulkiest silhouette,
  always holding or moving an object (case, cable spool, ice tool, drill
  control). Their activity loop: `OperateDrill`, `CarryCase`, `CheckCable`,
  `ClearIce`. Never empty-handed.
- **Soldiers** — dark parkas, rifle slung muzzle-down across the back, the only
  characters who face *outward* from the group. Loop: `Radio`,
  `SecurityWatch`, `CheckWrist`, `PatrolIdle`. They stand at doors and at the
  perimeter, never beside a scientist as decoration.
- **Scientists** — ivory-to-ice coats with orange trim, each with exactly one
  instrument. Loop: `TypingConsole`, `CheckingTablet`, `AdjustingCable`,
  `Monitoring`, `WritingNotes`.

**Ensemble rule.** At any moment in any populated frame, at most one third of
visible background characters may be in an idle phase, and each of them must be
mid-task, not waiting. When a principal speaks, only characters within roughly
8 studs break off to listen; the rest keep working. That is already how
`Sequences.lua` staggers listeners — it is being promoted here from a trick to a
law.

### 1.5 KAI — present day

*Reads as:* an ordinary teenager in an ordinary room, fifteen years and one
world away from everything we just watched.

Same R15 block construction as the expedition cast — this is the whole point of
the design language, and it must be obvious that he belongs to the same film.
**Simpler clothing than anyone in the Arctic**: plain dark trousers, a worn
mid-tone jacket over a light shirt, ordinary shoes. No instrument, no belt rig,
no hood, no accessory. Scale 1.00, the same as Lyra — a quiet visual rhyme, never
pointed at.

**Posture at rest.** Relaxed and slightly loose-shouldered; the only character in
the film with no professional posture at all.

**Motion signature.** Unhurried and small. He handles objects the way people
handle objects they own — without looking at them all the way.

### 1.6 AEGIS ZERO — the Guardian

The machine the player will pilot. Designed here so the reveal shots have
something specific to reveal.

**Proportions (in head-units, head = 1).** Total standing height **7.5 heads**,
deliberately shorter and denser than a "tall robot" so it reads as *heavy* rather
than tall. Sensor head 1.0 — small, no face, a single horizontal optic band.
Shoulder span **3.4 heads**, the widest thing about it. Chest block 2.0 tall and
deep enough to hold the core. Waist **1.6 heads wide** — a clear narrowing, the
single most important silhouette line on the machine. Thighs 2.0 long and nearly
as wide as the waist. Lower legs 2.0, flaring to feet **1.4 heads long** with a
visible sole plane and a heel that extends behind the ankle.

**Construction, outside in.** A darker internal mechanical layer (`metal`
53,65,71 and `dark` 25,32,39) is visible *between* armour plates at every joint:
neck, shoulder, elbow, wrist, waist, hip, knee, ankle. Armour shells (cool
off-white/grey, `ivory` tinted toward `ice`) sit on top of that layer and never
meet each other directly — there is always a dark gap where a joint bends.
Pistons and servos exist **only at joints that actually rotate in the rig**, one
per axis, and they must visibly compress when that joint closes. A piston that
does not move is deleted, not decorated.

**Colour law.** Off-white/grey armour, dark internals, cyan (115,204,214) energy.
Cyan appears in exactly four places: the chest core (a recessed disc, the
brightest thing on the machine), the optic band, thin seam lines at the
shoulders and spine, and the joint interiors when powered. **Total Neon surface
must stay under about 4% of the machine.** No glowing panels, no glowing limbs,
no light spilling from the armour itself.

**Damage state (as found, per story.txt).** Right shoulder plate torn open,
exposing internals. Three dark blades embedded in the back at differing angles.
Left half of the faceplate cracked, the optic band interrupted there. Frost
patches on all upward-facing surfaces. Both hands closed around chain links that
run down into the floor. All of this is permanent — it survives into gameplay's
version of the design.

**Motion law.** Aegis is heavy, controlled, and *sequenced*: hips lead, torso
follows a beat later, head last. Every acceleration and deceleration eases at
both ends (the existing `heavy()` quintic curve). A step is: weight transfer →
lift → carry → plant → knee compresses ~8 degrees → torso settles → head
re-levels. Nothing on the machine moves at constant speed. It never moves two
limbs at the same speed in the same direction.

### 1.7 THE SOVEREIGN BELOW — the Prisoner

**The design test:** its silhouette, filled solid black at 100 pixels tall, must
read as *alive*. If it reads as a tower, a stack, or a pile of shapes, it is
wrong and gets rebuilt before it enters a single shot.

**Anatomy, top to bottom.** A **sensory head** — an elongated, forward-canted
wedge carrying six closed violet eyes in two staggered rows, asymmetric, not a
grid. A **short thick neck** that can crane the head well ahead of the body. An
**upper trunk** that is broad, armoured in overlapping plates, and *tapers* to a
narrower lower trunk — the taper is what stops it reading as a rectangular
column. **Six limbs**: two long articulated forelimbs ending in four-digit
claws, each digit individually jointed at two points; two mid-limbs, shorter,
folded tight against the trunk when dormant; two powerful hind legs with a
reversed knee and a broad three-point foot that visibly contacts the floor.
Broken **wing slabs** fold along the back like collapsed scaffolding. Dark
material spreads outward from its contact points across the ice like frozen
roots — this is environment, not body, and it stays after the creature moves.

**Scale.** Roughly **2.2× Aegis Zero standing**, but it is never seen standing
upright until Scene 14. Dormant it is a folded mass, which is what makes the
unfolding read.

**Colour law.** Body is charcoal blue-black (≈18,20,28) — darker than every
other dark in the film so it separates even in the prison's low key. Violet
(reserve a deep value, ≈90,58,140, not the bright 164,118,224 used elsewhere)
appears **only** as thin seams between plates, as the eyes, and as a faint bleed
along the root-spread. **Under 6% violet surface.** It is never a purple object.

**Motion law — the opposite of Aegis.** Its default is *absolute stillness*: not
an idle cycle, genuinely static, which no other thing in the film does. It moves
in **bursts**: hold, then one fast committed motion, then hold again (the
existing `sudden()` curve). **The head always commits before the body** — the
head turns, holds, and only then does the trunk rotate to follow. Its limbs do
not ease out; they arrive and stop hard. Before any lunge, the hind legs and
trunk **compress** for at least 0.25s. It tracks targets with the head
continuously while the rest of it is frozen — that alone is most of "alive."

### 1.8 WARDENS (background)

Small, simplified versions of the same biomechanics: same charcoal, same violet
seams, four limbs instead of six, no wing slabs, no eye rows — one single eye
band. In this film they are **silhouettes in ice at distance**, plus exactly one
that breaks free in 14.05. They must read as *the same species* as the
Sovereign, one tier down. Fourteen instances at varied scale and rotation, never
a uniform grid.

---

## PART 2 — ENVIRONMENT AND LIGHT DESIGN

Six sets. Each is built as a complete physical place, keyed to the existing
`Env.Zones` sound-stage layout so nothing overlaps. Each set below lists its
enclosure, its contents, its named light sources, and its camera-legal volume —
**the region the camera may occupy**, which is defined at design time so no shot
ever needs a wall removed.

### 2.1 SET A — Expedition Base Seven, Arctic exterior (`Z.BaseCenter`)

**Read:** enormous, cold, and indifferent. The base must look *small*.

**Ground.** A snow plain extending to the horizon in every direction, gently
undulating, with wind-carved ridges running consistently on one axis (the wind
direction — every drifting particle, every flag and every cable sway agrees with
it). A dark iceberg mass rises to the north-east, roughly 8× the height of the
tallest base structure; it is the only vertical landmark and it anchors every
exterior frame.

**The base.** Eight linked prefab modules on skids, arranged in a shallow
horseshoe opening away from the wind: command module (largest, the only one we
go inside), two habitat modules, a generator module with visible exhaust plume,
two storage modules, a comms mast with guy-wires, and the excavation shelter
over the drill head. Cable runs between all of them, sagging, pinned at intervals
by stakes. Crates and fuel drums stacked in the lee of buildings, never in the
open. Six tracked vehicles: two parked at the habitat, one under service with a
panel open, two at the excavation, one arriving.

**Scale references, mandatory in exterior frames.** At least one of: a human, a
vehicle, or a lit module window must be visible in every wide shot, positioned
so the landscape dwarfs it.

**Light plan.** Key: an overcast polar sky, low and flat from roughly 20 degrees
above the horizon, cool (`ice` toward `snow`). Fill: bounce from the snow itself
— strong, from below, which is what makes Arctic exteriors read correctly and
keeps faces under hoods legible. Practicals: warm module windows (255,219,167),
orange perimeter lamps on poles, vehicle headlamps, and handheld work lights.
Atmosphere: dense but not opaque — the iceberg must stay visible as a value, not
disappear. Snow moves across the *ground plane* in low sheets as well as falling;
ground movement is what sells wind.

**Camera-legal volume.** Unrestricted above ground level, but never below 1.2
studs (the camera does not go inside the snow) and never closer than 2 studs to a
module wall.

### 2.2 SET B — Command module interior (`Z.Command`)

**Read:** a working room, cramped, warm, full of the expedition's real business.

**Enclosure.** Full six surfaces — floor, ceiling, and four walls including the
+Z wall that was missing until the last repair pass. One door to the exterior on
the −X wall with a visible vestibule and a hanging insulated flap. Two small
windows on the +Z wall, frost-edged, showing the exterior as bright and
blown-out relative to the interior — that contrast is the room's most valuable
asset and must be preserved, not graded away.

**Contents.** A central plot table with a topographic ice map, the room's
anchor. Along the −Z wall, the signal station: three stacked monitors, the pulse
display, a rack of instruments. Along the +X wall, a comms desk with the radio
set. Cable trunking along the ceiling edge, coffee-stage clutter (thermoses,
paper, a coat over a chair back). Ceiling structure visible: three beams, ducting,
three recessed lamps.

**Standing positions (locked).** Lyra at the signal station, −Z wall, facing the
monitors. Voss at the plot table's north edge. Hale enters through the −X door
and occupies the room's open centre. Two scientists at the comms desk. One
soldier inside the vestibule, facing the door.

**Light plan.** Key: the three ceiling lamps, warm-neutral, brightness low enough
that the monitors read as bright by comparison. Fill: monitor glow, cool, on the
faces of whoever stands at the signal station — this is the room's characteristic
look and Lyra spends the scene inside it. Accent: window daylight, cold, raking
in from +Z. No ambient lift beyond the readability floor.

**Camera-legal volume.** The room is designed 4 studs larger on each axis than
the furniture needs, specifically so a 46-degree lens can sit in a corner and see
the plot table with the far wall behind it. Camera stays 1.5 studs clear of every
wall and below the ceiling beams.

### 2.3 SET C — Ice tunnel and the ancient door (`Z.Door`)

**Read:** the transition from human world to old world.

**Enclosure.** A bored ice tunnel, roughly 12 studs across, with visible drill
scoring on the walls, timber-and-steel shoring at intervals, a cable run and a
string of temporary work lamps along the left wall, and a duckboard floor over
raw ice. It slopes downward. The tunnel is *closed*: ice above, ice on both
sides, floor below. At its end, a flat wall of ancient material with the symbol
ring — which is visibly not ice and not rock, and is the first constructed thing
in the film.

**Light plan.** Key: the string of work lamps, warm, at 6-stud intervals along
one wall — which means characters walking the tunnel pass through alternating
light and shadow. That rhythm is the scene's entire visual idea. Fill: cold
bounce off the ice walls. Accent: helmet and handheld lamps carried by the
characters, which are the only lights that move.

### 2.4 SET D — The Aegis chamber (`Z.ChamberFloor` / `Z.ChamberCenter`)

**Read:** an ancient constructed hall, not a cave. Big enough that Aegis Zero
kneeling does not touch the ceiling; small enough that when it stands, it nearly
does.

**Enclosure.** A full 360-degree constructed ring — already true in the current
build and preserved. Floor: a fitted plate floor with a circular seal ring inlaid
at centre, 40 studs across, its segments meeting in a visible joint pattern.
Ceiling: a ribbed vault, ribs descending into wall pilasters, ~55 studs at the
apex. Walls: the myth wall (relief carvings) on the far −X side; the entrance
arch from the tunnel on +Z; two deliberate ice breaches on the +X wall where the
glacier has cracked the structure open — **these are the only places raw cave is
visible**, and they are framed as damage, with ice spilling inward onto the floor
and light filtering through them.

**Structure.** A perimeter walkway one level up, reached by two stairs, with
railings — this is where the camera and the characters get their high angles
honestly. Four support pillars at the ring's cardinal points. Chains descend from
Aegis Zero's hands into a circular shaft at the centre of the seal ring, which is
the physical link to Set E and must be visible in frame whenever the chamber is
shown wide.

**Aegis Zero's position (locked).** Kneeling on the seal ring, facing +Z toward
the entrance, right knee down, left knee up, both hands forward and down gripping
the chains. This never changes until Scene 13.

**Light plan (pre-research).** Key: cold daylight bleeding through the two ice
breaches, high and from +X — directional, raking, and the reason the chamber has
shadow direction at all. Fill: the expedition's own handheld and tripod lamps,
warm, low, and *placed in frame* so the audience can see where the light comes
from. Accent: the core, cyan, at zero strength initially — it is dark in these
scenes. The floor plane must remain visible at all times (readability floor).

**Light plan (post-research, Scene 8 onward).** Adds: four lamp trees on the
chamber floor, a lit analysis station, monitor glow, and cable-strung work lamps
around the perimeter walkway. The room becomes brighter and *more human* — the
contrast with Scene 5's cold emptiness is the montage's whole payoff.

**Light plan (emergency, Scene 15 onward).** Practical-driven: dark neutral
shadow carries the scene, red comes only from placed emergency practicals at the
pillars and the entrance arch, plus a small cool fill so silhouettes still
separate. Never a red-tinted global ambient.

### 2.5 SET E — The prison cavern (`Z.PrisonCenter`)

**Read:** older, wetter, wrong. Not built by the same hands as the chamber.

**Enclosure.** A natural cavern with a constructed floor only at the near end —
an ancient ledge and a stair descending from the shaft, with a low retaining wall
at the drop edge. Beyond the ledge the floor falls away into the ice basin where
the Sovereign is embedded. The cavern has a visible ceiling (ice, ribbed with
pressure fractures) at ~90 studs and far walls at ~200 studs, both of which must
remain faintly visible so the space reads as enclosed rather than infinite black.

**Contents.** The Sovereign, frozen into the basin floor, folded. The chain
anchor points where Aegis Zero's chains terminate — four of them, driven into the
ice around the creature, which is the visual proof of the connection between the
two sets. The Warden field: fourteen smaller silhouettes in the ice at varying
distances and depths, most only partially visible. Frozen root-spread radiating
from the Sovereign across the basin.

**Light plan.** Key: a cold shaft of light from the opening above, falling on the
ledge — which is where humans stand, so humans are always the best-lit thing in
this set. Fill: two dim violet practicals *placed low in the basin*, at modest
range, providing bounce that defines the cavern volume without reaching the
ledge. Accent: the Sovereign's eye seams, which are the only bright violet.
**Explicit check:** the Sovereign's silhouette must separate from the cavern
background at all times. If it does not, raise the basin fill, not the creature's
emissive.

### 2.6 SET F — Kai's home, present day (above Daren's garage)

**Read:** small, warm, lived-in, safe. The tonal opposite of everything before it.

**Enclosure.** The bedroom is a genuine closed volume: floor, ceiling, four
walls, one door to the living area on the interior wall, one window on the
exterior wall looking out at the neighbourhood. The existing `buildHome()` volume
above the garage is the right footprint; this design closes it properly and
designs the camera path to fit inside it rather than looking in through a missing
wall.

**Contents.** Bed against the wall opposite the window, unmade. Desk under the
window with a task lamp, a disassembled small device and hand tools laid out in
a working order (not scattered) — this is Kai's character, stated without
dialogue: he takes things apart. A chair, pushed back. A shelf with a framed
photo (Daren and a younger Kai), a few books, a spare part or two. A jacket over
the chair back — the object he picks up in 20.04. Clothes on the floor near the
bed. A poster on the door-side wall.

**Camera-legal volume.** The room is sized so a 55-degree lens can sit in the
corner diagonally opposite the bed and hold bed, desk, window and door in one
frame. The opening shot of Scene 20 starts tight at the window and pulls back
into that corner — a path entirely inside the room. **No shot in Scene 20 is
taken from outside a wall.**

**Light plan.** Key: daylight through the window, warm morning, from a low angle
— the first warm key light in the film. Fill: bounce off the light wall opposite.
Practical: the desk lamp, on, slightly redundant in the daylight, which is
exactly what a real desk lamp left on overnight looks like. No emergency colour,
no cyan, no violet anywhere in this set.

---

## PART 3 — THE STORYBOARD

---

### SCENE 1 — ARRIVAL · 0:32 · Set A

*Purpose: establish isolation and scale before any mystery, and show an
expedition that was already working before we arrived.*

**1.01 — TRANSMISSION** · 5s · 46° · static, black frame
Full black. No image. We hear wind first, then a radio transmission opening on a
squelch: *"Arctic Expedition Seven to Command. We have reached the signal's
origin."* A subtitle carries it, attributed to RADIO. The black is held long
enough to be uncomfortable — this is the last quiet the film has.
**Cut motivation:** the transmission ends mid-breath, and the image arrives on
the silence after it.
**Light:** none. Blackout frame; the exterior preset is already applied
underneath so shot 1.02 does not flash on.

**1.02 — THE PLAIN** · 6s · 70° · slow dolly right, level
The widest frame in the film. Foreground: nothing but snow, moving — low sheets
of spindrift crossing the frame left to right along the wind axis, close enough
to the lens to blur. Middle ground: an unbroken white plain, ridged, with no
object on it. Background: the dark iceberg mass at frame right, and a flat
overcast sky with no sun disc. The camera dollies right at a speed just fast
enough to notice, which makes the ridge lines parallax and proves the plain has
depth. Roughly four seconds in, a single dark speck appears at the base of the
iceberg — a vehicle, tiny, with a thread of exhaust. It is not centred and the
camera does not chase it.
**Cut motivation:** the eye finds the speck; the film cuts before the audience
finishes asking what it is.
**Light:** exterior key, flat overcast, snow bounce filling everything. High
overall brightness but no white-out — the ridges must hold shadow.

**1.03 — CONVOY, LONG LENS** · 4s · 30° · static
A compressed telephoto frame. Foreground: a wind-carved ridge crossing the lower
third, out of focus in silhouette. Middle ground: three tracked vehicles in
column, heat shimmer and snow spray off their tracks, crawling left to right,
heavily compressed by the lens so they appear to barely advance. Background: the
iceberg wall filling the top two thirds, its striations visible, absolutely
dwarfing the column. The vehicles look like insects on it.
**Cut motivation:** scale is understood; now get close to it.
**Light:** same key; atmospheric haze between camera and iceberg is what sells the
distance.

**1.04 — TRACK LEVEL** · 4s · 62° · low track, camera travelling with the lead vehicle
Camera 2 studs off the snow, just ahead of and beside the lead vehicle's track
unit. Foreground: the track links passing camera-left, throwing snow toward the
lens. Middle ground: the vehicle's flank, scratched and frosted, the expedition
number stencilled on it, a worker riding the exterior step holding a rail with
one hand and steadying a strapped case with the other. Background: the plain
sliding by, and the first perimeter pole of the base entering frame at the far
right.
**Cut motivation:** the perimeter pole enters frame — we have arrived.
**Light:** key still flat; the vehicle's headlamp throws a weak warm pool ahead
of it that we can see cross the snow.

**1.05 — BASE SEVEN** · 5s · 63° · crane up and forward, slow pace
The reveal of the base, and it must feel *small*. Camera begins at head height
behind the perimeter line and cranes up and forward. Foreground: a perimeter pole
with an orange lamp and a torn wind flag, and a stack of fuel drums. Middle
ground: the horseshoe of eight modules, warm windows lit against the grey, the
generator's exhaust plume bending downwind, cable runs sagging between buildings,
two parked vehicles, the comms mast. Background: the excavation shelter and drill
rig at the far side of the horseshoe, and beyond everything, the iceberg and the
empty plain, which occupies more of the frame than the base does. A location card
fades in low: **THE NORTH POLE / FIFTEEN YEARS BEFORE THE INVASION.**
**Cut motivation:** the card completes; the camera has stopped climbing.
**Light:** the first practicals of the film — warm windows and orange lamps
reading against the cold key, which is what makes the base look inhabited.

**1.06 — WORK** · 4s · 55° · handheld, slow pan following a carried load
Inside the base now, at ground level between two modules. Foreground: two workers
carrying a long crate between them, passing right to left directly across the
lens, their boots compressing snow. Middle ground: a third worker paying out
cable from a spool and pinning it with a stake; a scientist crouched at an
instrument case with the lid open, reading a display and writing on a pad
balanced on her knee. Background: the command module's lit door with the
insulated flap swinging, and a soldier standing beside it facing outward, rifle
slung, scanning the perimeter — not watching the scientists. Every person in this
frame is mid-task, and nobody looks at camera.
**Cut motivation:** the crate clears frame left, opening the view to the command
module door.
**Light:** exterior key plus spill from the module door; the handheld sway is
motivated because we are at human height inside a working camp.

**1.07 — INSIDE** · 4s · 58° · dolly forward through the vestibule
The camera follows the two workers' path to the command module and pushes through
the door flap. Foreground: the flap edge passing the lens, then the vestibule's
hanging coats. Middle ground: the soldier at the vestibule turning slightly to
let the camera past, then the interior opening up — the plot table, the map, the
warm lamp light. Background: the signal station on the far wall, three monitors,
and a figure in an off-white parka standing at them with her back to us. Exposure
shifts as we cross the threshold: the exterior blows out behind us, the interior
resolves.
**Cut motivation:** none — this shot is the scene transition. It carries us into
Scene 2 without a cut.
**Light:** a real exposure transition from exterior key to the command module's
warm lamps. The windows behind Lyra are now the brightest thing in frame.

---

### SCENE 2 — THE SIGNAL · 0:28 · Set B

*Purpose: introduce three people through what they are doing, and let the
discovery travel between them instead of hitting them all at once.*

**2.01 — THE ROOM WORKING** · 4s · 55° · slow dolly in, continuing 1.07's move
The move from 1.07 continues without a cut, decelerating. Foreground: the plot
table edge with the ice map, a mug, a pair of gloves. Middle ground: Voss at the
table's far edge, head down, moving a marker across the map and comparing it
against a tablet in his left hand — small movements, elbows in. Two scientists at
the comms desk on the right, one speaking into a handset, one writing.
Background: Lyra at the signal station, three-quarter back to us, cool monitor
light on the side of her face, her scanner in her left hand at hip height.
Nobody speaks. The room has a working hum.
**Cut motivation:** the camera settles; we have chosen who to watch.
**Light:** ceiling lamps warm and low; monitor glow cold on Lyra; window daylight
raking cold from the right.

**2.02 — OVER VOSS** · 4s · 46° · static, over-shoulder
Camera behind Voss's right shoulder. Foreground: his shoulder and ivory scarf
tail, soft, occupying frame left. Middle ground: the room's open centre.
Background: Lyra at the station, now in clearer view, working — her right hand
adjusting a dial, her left holding the scanner up to compare it to the monitor.
She is talking quietly to herself, or to no one. This is the audience's first
clean look at her, and she is busy.
**Cut motivation:** her right hand stops moving.
**Light:** unchanged. The monitors are the key on her face from this angle, which
is why she reads cool and everyone else reads warm.

**2.03 — HER HANDS STOP** · 3s · 35° · static, tight
Tight on Lyra's hands at the console. Foreground: the dial, her fingers resting
on it, the scanner's small cyan screen at the bottom of frame. Middle ground:
the console surface, a printed chart, a pen. The hands stop. Not a flinch — they
simply cease, and hold for a full second while nothing else in the frame changes.
Her thumb stays on the dial. **Her hands stop before her head turns. This is the
first beat of the entire story and it is played on hands, not on a face.**
**Cut motivation:** the stillness becomes unbearable at about two and a half
seconds.
**Light:** the cyan scanner screen and the cold monitor spill; her sleeve cuff
and the dark undersuit read clearly, no blowout on the ivory parka.

**2.04 — SHE CHECKS AGAIN** · 3s · 44° · small push in
Profile-ish on Lyra at the station. Foreground: the edge of the monitor bezel,
out of focus. Middle ground: Lyra. Her head comes up, she looks at the middle
monitor, then she deliberately looks *down* at her own scanner, then back up to
the monitor again — the full check-twice, because she does not trust the reading.
Her weight shifts a half-step closer to the console. Background: the room behind
her, soft, still working, Voss's silhouette out of focus at frame right.
**Cut motivation:** her second look confirms it; she draws breath to speak — and
we cut away before she does.
**Light:** monitor key, slightly brighter as the pulse display changes state.

**2.05 — VOSS NOTICES HER** · 3s · 46° · static
Back at the plot table. Foreground: the map and his marker, which is still
moving. Middle ground: Voss, head down. Then his hand stops, and only afterward
does his head lift and turn toward the station. He does not look at the monitors.
He looks at *Lyra.* Background: the vestibule and the soldier at the door,
unaffected, still facing out.
**Cut motivation:** his head completes its turn.
**Light:** warm ceiling key on Voss, which contrasts against Lyra's cold-lit
coverage and keeps the two of them visually separate through the scene.

**2.06 — THE DISPLAY** · 3s · 38° · static, then a single slow tilt down
*Only now* does the camera look at the signal. Foreground: instrument rack edge.
Middle ground: the pulse display, three vertical bars rising and falling — three
pulses, a gap, three pulses again, mechanically regular. Background: Lyra's
sleeve and shoulder entering frame at the right edge as she leans in, so the
display is never a disembodied screen. The camera tilts down slightly to include
her scanner coming into frame beside it, showing the same three-pulse pattern
from a second source.
**Cut motivation:** the pattern repeats a third time and the repetition is
understood.
**Light:** display glow is the key. Everything else in frame is falloff.

**2.07 — HALE** · 4s · 50° · static
The door flap swings and Hale enters from the vestibule, bringing a wedge of
cold exterior light and snow with him. Foreground: the plot table's near edge.
Middle ground: Hale stopping two steps inside, taking the room in with one
unhurried full-body turn — no head-swivel. He is looking at the *operation*: the
comms desk, the map, the status boards. Background: Lyra and Voss at the far
wall, both now still, both looking at the same monitor. Hale's attention lands on
them last, because two of his researchers being motionless is the anomaly, not
the screen.
**Cut motivation:** his gaze arrives on them, and the floor moves.
**Light:** a brief cold spill from the opened door washing across the warm
interior, then closing away as the flap falls — a light change with a visible
physical cause.

**2.08 — THE ICE ANSWERS** · 4s · 55° · handheld, small shake
A wide of the room from the +Z corner, showing all four principals in one frame
with the ceiling and both side walls visible — the room is unambiguously a room.
A deep impact travels through the structure. Foreground: dust drifting down from
a ceiling beam, and a mug walking a few millimetres across the plot table.
Middle ground: Voss putting a hand flat on the table; the two comms scientists
turning; the soldier taking one step in from the vestibule and looking at the
ceiling, not at the people. Background: Lyra and Hale — Lyra looks *down*, at the
floor, because she has just understood the signal is beneath them; Hale looks at
Lyra. Three different reactions, three different directions of attention, one
event.
**Cut motivation:** the vibration dies out and the room holds its breath.
**Light:** unchanged, but the hanging lamps sway slightly for the remainder of the
shot, moving shadows across the walls — the cheapest and most convincing proof
that something physically happened.
**Continuity:** the lamps keep swaying for the first two seconds of any later
command-module shot in this sequence. The mug stays where it walked to.

---

### SCENE 3 — THE SEAM · 0:26 · Set A, excavation face

*Purpose: the discovery arrives one detail at a time, and the characters are
curious, not terrified.*

**3.01 — THE DRILL** · 4s · 58° · static low, slight upward tilt
Under the excavation shelter. Foreground: the drill's hydraulic leg and a
vibrating cable, close to the lens. Middle ground: the drill head turning in the
ice, ice dust jetting horizontally away from it in the wind, a worker at the
control stand with both hands on the levers and his hood up, another worker
watching the depth gauge and calling numbers back. Background: shelter frame,
snow blowing through the open side, the base beyond it.
**Cut motivation:** the pitch of the drill changes.
**Light:** exterior key through the open shelter side; two work lamps clamped to
the shelter frame provide warm rim on the workers.

**3.02 — IT HITS SOMETHING** · 2s · 44° · handheld
Tight on the bore. Foreground: ice chips leaping upward out of the hole, a shower
of them, brighter and faster than the dust before. Middle ground: the drill head
shuddering and kicking back in its mount. Background: the control worker's hands
snapping the lever back. The shot is short and physical.
**Cut motivation:** the drill stops.
**Light:** unchanged; the chips catch the work lamps and read as sparks of white.

**3.03 — WHAT IS DOWN THERE** · 4s · 50° · slow push in and tilt down
Three workers clearing the hole by hand with picks and a brush, the ice lifting
away in plates. Foreground: a worker's back and shoulder, moving. Middle ground:
the exposed floor of the excavation, and in it, a patch of something grey that is
not ice and not rock — flat, with a machined edge. The camera pushes in past the
worker's shoulder as he leans out of the way, which is what opens the view.
Background: two more workers and a soldier standing at the pit edge looking down,
plus the pit wall showing the ice strata we drilled through.
**Cut motivation:** the machined edge is recognizable as machined.
**Light:** a handheld work lamp held by one of the pit-edge figures swings across
the patch, which is what makes the surface catch and read as metal.

**3.04 — SHE TAKES HER GLOVE OFF** · 5s · 40° · static, then small push
Lyra in the pit, crouched. Foreground: the metal surface, frost-covered, filling
the lower third. Middle ground: Lyra pulling her right glove off with her teeth —
her hand is bare for the first time — and wiping the frost away with her palm in
two passes. Under the frost: a seam. A long, deliberate line between two plates,
perfectly straight, with a second line branching from it at an angle no
geological process makes. Her hand stops on it. Background: the pit wall and a
worker holding the lamp for her, arm extended, staying out of her way.
**Cut motivation:** the seam is legible.
**Light:** the held work lamp is the key, raking almost parallel to the surface —
which is the only lighting angle that makes a seam visible at all. This is a
deliberate, motivated, *physical* lighting choice and it must be built that way.
**Continuity:** her right glove is off from here until 8.02, where she is shown
wearing it again.

**3.05 — IT ANSWERS** · 3s · 32° · static, very tight
Macro on the seam under her bare palm. Foreground: the seam, her fingertips at
the frame edge. A faint cyan line runs *along* the seam, from the top of frame to
the bottom, in about half a second, and is gone. Almost nothing. Then, a beat
later, a vibration — visible only as the frost crystals on the plate jumping
about a millimetre and resettling. No sound sting, no flare, no particle burst.
**Cut motivation:** the vibration stops.
**Light:** the same raking lamp. The cyan line is dim enough to be doubted.

**3.06 — CURIOSITY, NOT FEAR** · 4s · 46° · static
Lyra's coverage. Foreground: her bare hand still on the metal — **she does not
pull it away.** Middle ground: Lyra, looking down at her own hand, then up and
along the plate, tracking the seam's direction with her eyes, then leaning
*further in.* Her expression reads as interest. Background: the worker with the
lamp glancing at her, and Voss arriving at the pit edge above and behind, going
down on one knee to see, his hands on the lip.
**Cut motivation:** her eyes travel along the seam and out of frame, and the
camera goes where she looked.
**Light:** lamp key from low, cold ambient fill from the sky above the pit.

**3.07 — IT KEEPS GOING** · 4s · 66° · crane up and back, slow pace
The answer to her look. The camera rises out of the pit and pulls back.
Foreground: the pit edge and the two figures in it, shrinking. Middle ground: the
excavation trench — and now we can see that the exposed grey plate is not a patch.
It runs the entire length of the trench and disappears under the ice at both
ends, and where the ice is thinner, more of it ghosts through, pale, continuing
far past the dig. Background: the base, the shelter, the plain, the iceberg. The
humans in frame are tiny against a shape that has no visible end.
**Cut motivation:** the scale is understood; we go looking for the way in.
**Light:** back to full exterior key. The under-ice metal reads as a paler value
inside the blue of the glacier — a value shift, not a glow.

---

### SCENE 4 — THE DOOR · 0:20 · Set C

*Purpose: cross from the human world into the old one, on foot, at human pace.*

**4.01 — THE TUNNEL** · 5s · 58° · slow track backward, leading the walkers
Camera retreats down the sloping tunnel ahead of the group. Foreground: the
duckboard floor and the cable run passing beneath the lens. Middle ground: Lyra
walking at the front, lamp in hand, the beam swinging across the drill-scored
ice; Voss a half-pace behind her checking a handheld instrument as he walks and
occasionally glancing up to avoid the shoring beams; two soldiers behind them,
one with a shoulder lamp. Background: the tunnel mouth far behind, a small
rectangle of grey daylight getting smaller. As they walk, they pass through the
work lamps' alternating pools — light, shadow, light, shadow — four times.
**Cut motivation:** the beam ahead stops finding ice.
**Light:** the strung work lamps at 6-stud intervals are the key; the ice walls
bounce cold fill; the carried lamps are the only moving light.

**4.02 — THE WALL THAT IS NOT ICE** · 3s · 50° · static
Foreground: Lyra's lamp beam entering frame from the left and sweeping right.
Middle ground: the beam finds a flat surface — dark, matte, absolutely flat,
meeting the raw ice at a hard edge. It is the first man-made-looking thing in
the tunnel and the transition from natural to constructed happens inside a single
lamp sweep. Background: the tunnel's shoring receding, the group's silhouettes
entering frame at the bottom edge.
**Cut motivation:** the beam reaches the symbol ring.
**Light:** her single moving lamp is doing all the work; everything it is not on
is dark, and the ice walls give just enough bounce to keep the tunnel's shape.

**4.03 — SYMBOLS** · 4s · 36° · static, tight
Foreground: Lyra's bare right hand rising into frame. Middle ground: the ring of
carved symbols on the door, shallow, worn, filled with frost. Her fingers brush
one and the frost comes away. Her other hand raises the scanner beside it; the
scanner's cyan screen throws a small second light onto the carving. Background:
the flat door surface, Voss's lamp beam crossing it behind her.
**Cut motivation:** she presses one symbol and it gives.
**Light:** her lamp from the side and the scanner's small cyan fill — two
sources, both in frame, both held by her.

**4.04 — IT OPENS** · 5s · 55° · slow pull back
Foreground: the group in near silhouette, backs to us, stepping away as the door
moves. Middle ground: the door parting along a seam nobody had noticed, the two
halves sliding into the walls with a grinding of old mechanism; frost breaking
off the seam in sheets and falling. Background: darkness behind the door — not a
lit interior, just black with a faint cold gradient, and the barest suggestion of
a vaulted edge catching a lamp beam.
**Cut motivation:** the doors stop, and nobody moves.
**Light:** the tunnel work lamps still key the group from behind, making them
silhouettes against the dark opening — the strongest and cheapest "threshold"
image available.

**4.05 — THRESHOLD** · 3s · 62° · handheld, forward with the group
Camera behind and slightly above the group as they step through, the lens passing
under the door lintel. Foreground: the lintel edge crossing the top of frame.
Middle ground: the backs of four people, lamps raised, beams diverging into a
space large enough that none of them reach a far wall. Background: darkness with
depth — dust in the beams proves there is air and volume ahead.
**Cut motivation:** a lamp beam glances off something metallic far ahead.
**Light:** the chamber preset takes over at zero awakening; the carried lamps are
the only light sources in frame.

---

### SCENE 5 — THE GUARDIAN · 0:34 · Set D

*Purpose: the first mecha reveal, built entirely out of parts and human scale.
The full machine is not seen until the last shot of the scene.*

**5.01 — THE FLOOR IS A FLOOR** · 3s · 44° · static low, then tilt up 15°
Camera at ankle height on the chamber floor. Foreground: Lyra's boots stepping
into frame and stopping; the floor beneath them is not ice — it is a fitted plate
floor with visible joints running away toward the back of frame. Middle ground:
the joint pattern converging, her lamp's pool of light on it. Background: dark.
The first fact the chamber states is "this was built," and it states it on the
floor before it states it anywhere else.
**Cut motivation:** her lamp beam lifts off the floor.
**Light:** her handheld lamp only, low and raking so the floor joints read.

**5.02 — SOMETHING IN THE BEAM** · 3s · 50° · static, following the beam
Foreground: dust in the lamp beam. Middle ground: the beam travels up and right
and stops on a surface — curved, grey, plated, with a dark gap running through
it. It is impossible to tell what it is. It is very large. Background: black.
**Cut motivation:** a second lamp arrives from frame left and widens the pool,
showing more.
**Light:** two carried lamps, both from below. Every reveal in this scene is lit
from below by held lamps, which is both physically honest and makes the machine
look enormous.

**5.03 — THE FOOT** · 4s · 46° · slow crane up, pace Slow
Foreground: the plate floor and the first lamp. Middle ground: what the beams are
on is a **foot** — a sole plane flat on the floor, a heel extending behind an
ankle joint, toe plates, and a dark internal layer visible in the ankle gap. The
camera cranes slowly upward along it. **Lyra walks into frame at the right and
stops beside it.** Her head does not reach the top of the ankle. Background: the
darkness above, which the lamps do not reach.
**Cut motivation:** the crane exhausts the lamp light and runs out of visible
machine.
**Light:** two lamps from below; the frost on the machine's upward surfaces
catches and reads. The scene's brightness stays near the readability floor and
never above it.

**5.04 — UP INTO THE DARK** · 3s · 62° · static, steep low angle
Foreground: Lyra at the bottom of frame, looking up, lamp raised — she is small
in the corner of the frame, and she is the scale key for everything above her.
Middle ground: the lower leg rising away from her, plating and piston housings
visible, a knee joint at the top edge where the beam falls off. Background:
blackness continuing upward with no visible end, and one rib of the ceiling
vault just barely catching light at the very top — enough to say the room has a
ceiling without showing how far away it is.
**Cut motivation:** she lowers her lamp and turns toward a sound of tensioned
metal.
**Light:** her raised lamp, plus a faint cold wash from the ice breaches high on
the +X wall, which is the only non-carried light in the chamber.

**5.05 — THE HANDS AND THE CHAINS** · 5s · 42° · slow dolly along the chain line, pace Slow
Foreground: a chain link, huge, frosted, passing close to the lens, the camera
travelling along the chain. Middle ground: the chain rising out of the floor
shaft and up to where it terminates — inside a closed metal **hand**, four
fingers wrapped over the link, a thumb across it, the wrist joint's internal
layer visible. The grip is deliberate. Background: the second hand, further away,
doing exactly the same thing on a second chain, and the shaft opening in the
floor from which both chains emerge.
**Cut motivation:** Lyra says, quietly, *"It's holding them."* — and the camera
goes to find out what a thing that holds chains looks like.
**Light:** lamps below, plus a faint pale glow from the open shaft in the floor —
the prison's light, which we will not understand for another four minutes.

**5.06 — THE CHEST** · 4s · 50° · slow crane up, pace Slow
Foreground: the shoulders of two soldiers entering the chamber at the bottom of
frame, lamps sweeping. Middle ground: the torso — a broad armoured chest, and at
its centre, a recessed circular core, **dark**, unlit, with a ring of small
symbols around its rim. The narrow mechanical waist is visible below it, the
clear silhouette break between chest and hips. Background: the ribbed vault
beginning to catch the edges of the soldiers' lamps.
**Cut motivation:** a lamp finds the torn right shoulder.
**Light:** four carried lamps now, from below and from both sides; the core is
conspicuously *not* a light source.

**5.07 — IT LOST A FIGHT** · 4s · 44° · slow pan left to right
Foreground: nothing; this is a clean read of damage. Middle ground: the right
shoulder plate peeled back and torn open, internal structure exposed and
frost-filled; the camera pans right across the back to find three dark blades
embedded at different angles, each one buried to different depths, one with the
armour cracked around it. Background: the myth wall, far behind, out of focus,
noticed but not yet read. Voss is visible below, standing still, looking up, his
tablet hanging forgotten at his side.
**Cut motivation:** the pan reaches the head and stops.
**Light:** unchanged.

**5.08 — THE GUARDIAN** · 8s · 57° · wide crane from the perimeter walkway, pace Slow
The full reveal, and the only shot in the scene that shows the whole machine.
Camera on the perimeter walkway, one level up — an honest camera position that
exists in the set. Foreground: the walkway railing along the bottom of frame,
and the silhouette of a soldier's head and shoulder at frame left leaning on it.
Middle ground: **Aegis Zero, kneeling** on the seal ring at the chamber's centre
— right knee down on the ring, left knee up, head bowed, both arms forward and
down, both hands closed on chains that run into the shaft. Frost on every upward
surface. The damaged faceplate, the torn shoulder, the blades in the back, all
legible in one silhouette. Background: the myth wall behind it, the ribbed vault
above, the two ice breaches on the right wall with cold daylight coming through
them, and the entrance arch far left. Human figures are scattered across the
floor around its feet at a size that makes the machine unambiguous. Nobody says
anything for the whole eight seconds.
**Cut motivation:** the shot has nothing left to give; it ends on stillness.
**Light:** the two ice breaches are now doing real work as a cold directional
key from high right, raking across the machine's plating. Carried lamps fill from
below. The core stays dark. **Readability check: the floor plane, all human
silhouettes, and the far wall must all be visible in this frame.**

---

### SCENE 6 — THE WARNING · 0:24 · Set D, myth wall

*Purpose: the audience learns what the machine is for, from the environment and
from Lyra's face — not from a lecture.*

**6.01 — THE WALL** · 4s · 55° · slow dolly right along the wall
Foreground: Lyra walking right to left through the bottom of frame, her lamp
raking across the wall surface. Middle ground: the myth wall's relief carvings
sliding past — figures, a circular motif, a rectangular door shape, a many-limbed
shape. They are too fast to read and that is deliberate. Background: Aegis Zero's
kneeling silhouette occupying the right third of frame, out of focus, the wall
literally behind the machine.
**Cut motivation:** she stops walking.
**Light:** her moving lamp, raking, which is how relief carving reads at all.

**6.02 — THE THREE PANELS** · 4s · 40° · static, three small push-ins
Tight on three relief panels in sequence, the camera making a small push on each.
Panel one: a standing figure with a wide shoulder span, holding a door closed.
Panel two: the same figure, kneeling, with lines descending from its hands. Panel
three: behind the door, a many-limbed shape with rows of marks where eyes would
be. Foreground: frost in the carved channels; Lyra's bare hand entering frame to
clear each one. Background: the wall surface.
**Cut motivation:** her hand stops on the third panel.
**Light:** lamp raking from screen left, consistent across all three.

**6.03 — TRANSLATION** · 5s · 44° · static
Lyra's coverage, screen-right per her locked camera side. Foreground: her scanner
held up beside the carving, cyan screen glow on the underside of her jaw. Middle
ground: Lyra, reading — her eyes moving along the symbols, her lips moving
slightly before she speaks. She says: *"It isn't instructions. It's a warning."*
Background: the wall, and Voss arriving behind her shoulder at a slight distance,
**not** stopping his own work — he is still holding a reading in his other hand
and glances at it once mid-line before looking back to her.
**Cut motivation:** Hale's voice from off-screen asks what it says.
**Light:** lamp key from the left, scanner fill from below, cold breach light as
a rim on her hood — three sources, all placed.

**6.04 — WHAT IT SAYS** · 4s · 46° · static, reverse angle
Reverse on Hale and Voss, screen-left, their side of the axis. Foreground: the
blurred edge of Lyra's shoulder at the frame's left edge, holding the geometry.
Middle ground: Hale, arms at his sides, looking past Voss at the machine rather
than at the wall; Voss with his head tilted, listening properly. Lyra, off
screen, reads: *"When the Guardian rises, the Prisoner rises with it. The
Guardian is not sleeping. The Guardian is holding the door closed."* Background:
the chamber floor, two soldiers walking a perimeter behind them, and a scientist
crouched at an instrument case — the room keeps working through the most
important line in the scene.
**Cut motivation:** Hale's eyes move down, toward the floor. He has understood
the word *door* geographically, not metaphorically.
**Light:** warm carried lamps key both men; the machine behind them is a cold
mass.

**6.05 — WHICH DOOR** · 4s · 50° · static, then tilt down
Foreground: Hale's boots and the plate floor. Middle ground: the seal ring's
inlaid segments, and the chains lying across them. The camera tilts down and
follows the chains to the shaft opening at the ring's centre. Background: the
shaft, and below it, a very faint pale-violet light that is not any colour
anything else in this chamber has produced.
**Cut motivation:** the violet is noticed.
**Light:** first appearance of violet in the film, at very low intensity, as a
bounce from below. It must be subtle enough that a viewer could miss it.

**6.06 — NOBODY SAYS ANYTHING** · 3s · 62° · static wide
A wide on the chamber floor at the shaft, holding all three principals and the
machine in one frame with the vault above. Foreground: the shaft edge and the
chains. Middle ground: Lyra at the shaft's edge looking down into it, one step
closer than anyone else; Voss two paces back with his instrument raised toward
the shaft; Hale behind both, turning his head from the shaft to the machine and
back — the only movement in frame. Background: Aegis Zero kneeling, the myth
wall, two soldiers at the entrance arch.
**Cut motivation:** hold, then dissolve into the montage.
**Light:** unchanged, with the violet bleed steady from below.
**Continuity:** the shaft's violet bleed is present in every subsequent chamber
shot until the emergency lighting takes over in 15.01.

---

### SCENE 7 — TIME PASSES · 0:18 · Set D

*Purpose: turn an excavation into a working facility, visibly, in six clear
actions. This is the only place in the film where cuts skip time.*

The montage uses **matched camera positions**: each shot returns to a framing we
have already seen in Scene 5 or 6, with the room changed. That is what makes time
read as elapsed rather than as teleportation.

**7.01 — SCAFFOLD** · 3s · 55° · static (matched to 5.04's angle)
Same steep low angle on Aegis Zero's lower leg as 5.04, but now a scaffold tower
is being bolted together beside it. Foreground: a worker on the second level
passing a clamp down to another worker below; the exchange is completed on
screen. Middle ground: the leg, now with a work platform at knee height.
Background: the dark above, now with two clamp lamps hung from the scaffold.
**Cut motivation:** the clamp is tightened.
**Light:** carried lamps being replaced by *mounted* lamps — the change from
handheld to installed light is the montage's core visual idea.

**7.02 — POWER** · 3s · 50° · slow dolly along a cable run
Foreground: an orange cable being paid out along the floor toward camera, a
worker walking backward with the spool. Middle ground: the cable joining a trunk
of six others, all running toward a generator skid at the chamber wall with its
housing open and a technician inside it. Background: the machine's feet, and a
lamp tree being raised into position by two workers.
**Cut motivation:** the lamp tree's lights come on.
**Light:** the moment the lamp tree strikes, the chamber's fill rises — a visible
lighting change with a visible cause, on screen, in shot.

**7.03 — THE STATION** · 3s · 46° · static
Foreground: monitor backs and cable spaghetti. Middle ground: the analysis
station being assembled at the machine's right side — Voss setting a monitor onto
a frame, a scientist plugging a rack, a third running a keyboard cable.
Background: Aegis Zero's chest, the dark core, framed *between* the monitors,
which is how the station is aligned: it faces the core.
**Cut motivation:** a monitor wakes up and fills with data.
**Light:** monitor glow becomes a new cold light source in the chamber.

**7.04 — SECURITY** · 3s · 55° · slow pan
Foreground: a sandbag-and-crate position being stacked at the entrance arch by
two soldiers, one passing, one placing. Middle ground: the arch itself, with a
barrier and a light being fixed above it. Background: the tunnel beyond, and a
tracked vehicle at its far mouth unloading cases — a sightline from the deep
interior all the way out, established once so the evacuation route in Scene 15 is
already understood by the audience.
**Cut motivation:** the pan reaches the myth wall.
**Light:** a new warm practical above the arch.

**7.05 — THE WALL, DOCUMENTED** · 3s · 44° · static (matched to 6.02)
The myth wall's three panels again, in the same framing as 6.02, but now with a
survey grid strung over them, numbered markers at each panel, a lamp on a stand
and a camera on a tripod. Foreground: Lyra's hand placing marker number nine.
Middle ground: the panels, now clearly lit and clearly legible — the audience can
finally read the carvings they were shown too fast in Scene 6. Background: the
chamber, brighter, busier, unrecognizable as the same dark room.
**Cut motivation:** she lowers her hand and the montage ends.
**Light:** a stand lamp, static and properly placed. The wall is no longer a
mystery-lit surface; it has been *studied.*

**7.06 — TWO WEEKS LATER** · 3s · 63° · slow crane up from the floor
The matched pair to 5.08, from the same walkway position. Foreground: the walkway
railing, now with cable trunking taped along it and a clipboard hanging.
Middle ground: the same kneeling machine, unchanged, frost gone from its lower
surfaces where people have been working, scaffolding on both sides, lamp trees
around its feet, the analysis station at its right, cables everywhere.
Background: the vault, the two ice breaches, the arch with its new barrier. The
machine has not moved a millimetre. Everything around it has changed completely.
**Cut motivation:** hold, then straight into Scene 8.
**Light:** the full post-research chamber plan, roughly twice as bright as 5.08,
warm from installed practicals, cold from the breaches, cyan only from monitors.

---

### SCENE 8 — THE LAB ALIVE · 0:26 · Set D

*Purpose: a room where people actually work, and the ancient technology's first
response — carried entirely by reactions before any effect appears.*

**8.01 — THE ROOM AT WORK** · 4s · 60° · slow dolly left, at standing height
A floor-level wide holding the whole working facility. Foreground: a technician
crossing the lens right to left carrying a cable coil, and a crate corner.
Middle ground: the analysis station with Lyra at it; Voss at the secondary
console eight studs to her left, his back three-quarters to her; a scientist at
the generator skid; a second technician walking a repeating route between the
station and the skid, actually delivering something each trip. Background: two
soldiers at the entrance arch — at the *door*, not beside the scientists — one
facing out into the tunnel, one checking a wrist unit. Aegis Zero's legs and
lower torso rise behind the station, cropped by the top of frame.
**Cut motivation:** the dolly settles on Lyra.
**Light:** installed warm practicals key; monitors give cold fill; the breaches
rake cold from high right. The machine is a large dark presence, not a lit
subject.

**8.02 — LYRA WORKING** · 4s · 44° · static, screen-right
Foreground: the analysis station's monitor edge and a stack of printouts weighted
with a tool. Middle ground: Lyra, gloved again, working — cross-referencing a
frame of symbols on screen against a printed sheet, one hand on a dial, moving
between them at a natural working rhythm. She is not waiting for a cue. She says
something short to Voss without looking up. Background: the machine's chest and
dark core directly behind her, framed by the station, out of focus.
**Cut motivation:** Voss answers from off-screen.
**Light:** monitor key, cool, on her face; a warm practical rim from behind
camera-left.

**8.03 — VOSS AT HIS CONSOLE** · 4s · 46° · static, screen-left
Reverse geometry on Voss. Foreground: the blurred back of Lyra's shoulder at
frame right. Middle ground: Voss at the secondary console, answering her —
**and he keeps reading his screen for the first two thirds of his line before
looking up at her.** His gesture is one small hand movement at chest height.
Background: the technician arriving at the generator skid, handing something
over, and leaving again — a complete background action with a beginning and an
end. A soldier walks the back of frame from left to right, going somewhere.
**Cut motivation:** a small mechanical sound, off-screen, from the machine.
**Light:** warm key from the practical above his console, cold monitor fill from
below.

**8.04 — SHE STOPS** · 3s · 40° · static
Back to Lyra's framing from 8.02, identical. Foreground: unchanged. Middle
ground: Lyra — her hand on the dial stops. Then, a full second later, her head
comes up. Then, another beat later, her whole body turns toward the machine. The
*order* is the performance: hands, head, body, each with a real pause between
them. Background: the dark core behind her, still dark.
**Cut motivation:** her body completes its turn and she is looking off-frame at
the machine.
**Light:** unchanged. Nothing about the lighting has told us anything yet.

**8.05 — VOSS SEES HER** · 2s · 46° · static
Voss's framing from 8.03. Middle ground: Voss's typing stops mid-word. He looks
at Lyra, not at the machine — for the second time in the film, he reads the room
through a person. Background: the technician, mid-route, slowing and looking
between them; the soldier at the arch has not noticed anything at all.
**Cut motivation:** both of them are now looking the same direction, so the
camera finally follows.
**Light:** unchanged.

**8.06 — THE CORE** · 4s · 38° · static, very slow push
*Now* the camera looks at the machine. Foreground: the top edge of the analysis
station monitors, and Lyra's shoulder at the bottom-left corner — the machine is
never shown without a human anchor in this scene. Middle ground: the recessed
core. A single thin cyan line moves across one arc of its rim, travels perhaps a
third of the way round, and fades. The core itself does not light. Background:
the chest plating and the narrow waist below, in shadow.
**Cut motivation:** the line dies out, and for two full seconds nothing happens.
**Light:** the cyan arc is a low-intensity emissive on a small surface. It must
not spill onto the room. Nothing else changes.

**8.07 — THE SECOND SIGNAL, AND HALE** · 5s · 55° · handheld, small
Wide on the station area. Foreground: printouts lifting slightly off the desk.
Middle ground: a second, longer cyan line moves through a seam in the chest
plating and down toward the waist — visible, still small — and the room responds:
Lyra takes **one step toward** the machine; Voss stands up and takes **one step
back**; the technician stops where he is and looks to Voss. Background: Hale, who
has been off-frame at the entrance arch, turns and starts walking in. He does not
run. He arrives in frame at the end of the shot, and the first thing he does is
look at the monitors, not at the machine.
**Cut motivation:** Hale asks, flatly, whether that was a response.
**Light:** the cyan seam adds a faint travelling accent across the plating. The
room's lighting is otherwise unchanged — the *characters* have told the story.
**Continuity:** from here, the core's rim carries a faint standing cyan value
(well below the intensity of any monitor) in every subsequent chamber shot.

---

### SCENE 9 — THE SECOND SIGNAL · 0:20 · Set D → Set E

*Purpose: the realization that there are two objects, and a descent that feels
like going somewhere.*

**9.01 — TWO SOURCES** · 4s · 40° · static
Foreground: Voss's hands on his console. Middle ground: his monitor, showing two
traces. One is the three-pulse signal we have known since Scene 2, drawn cyan,
aligned with the machine. The second trace is new, violet, at a different
frequency, and it does **not** line up with the first. Voss's finger moves
between the two. Background: Lyra leaning in over his shoulder — she has crossed
the room since 8.07 and we see her arrive here, so her position is accounted for.
**Cut motivation:** her finger taps the violet trace.
**Light:** monitor key, cold, both faces.

**9.02 — DIRECTION** · 3s · 46° · static
Foreground: a handheld directional instrument in Lyra's hands, held flat.
Middle ground: Lyra turning slowly on the spot with it, reading the response —
and stopping when she is facing the floor shaft. She tilts the instrument
**downward.** Background: Voss watching her turn, Hale a few paces behind him
with his arms at his sides.
**Cut motivation:** the instrument points down, and so does everyone's attention.
**Light:** chamber practicals; the shaft's violet bleed is now the motivated
reason the floor under her glows faintly.

**9.03 — THE SHAFT MOUTH** · 4s · 55° · crane down over the shaft edge
Foreground: the seal ring's inlay and the chain links disappearing over the lip.
Middle ground: the camera cranes down past the shaft edge, revealing an ancient
stair spiralling the shaft wall, and rigging the expedition has installed — a
safety line, three clamp lamps at intervals going down, a winch frame at the top.
Background: the shaft's depth, dark, with the violet bleed stronger further down
and the four chains running in parallel into it.
**Cut motivation:** the descent has been made physically possible.
**Light:** installed clamp lamps going down the shaft, and violet from below;
this shot is what explains all subsequent prison lighting.

**9.04 — DESCENT** · 5s · 58° · track downward alongside the group
Camera descends beside the stair. Foreground: the shaft wall, ancient and
pressure-cracked, sliding upward past the lens. Middle ground: Lyra descending
first, one hand on the safety line, lamp clipped at her shoulder; Voss behind
her, moving more carefully, one hand always on the wall; two soldiers behind him.
Background: below them, a widening — the shaft is opening out into something much
larger, and the quality of the light changes from close and warm to distant and
cold.
**Cut motivation:** the shaft wall ends and the space opens.
**Light:** clamp lamps passing as pools, exactly like the tunnel's rhythm in
4.01, deliberately rhyming — the film's second descent, built the same way.

**9.05 — THE LEDGE** · 4s · 66° · static, wide, from behind the group
Foreground: the ancient ledge's retaining wall and the four figures arriving on
it, small in the bottom third of frame, lamps raised. Middle ground: the cavern —
an ice basin falling away beyond the ledge, ribbed ice ceiling far above with a
cold shaft of daylight falling through an opening onto the ledge itself.
Background: a huge, low, dark mass at the far side of the basin that the lamps
absolutely do not reach, and around it, at varying distances, a scatter of
smaller irregular shapes frozen into the ice. None of it is identifiable. The
scale of the room is the shot's only statement.
**Cut motivation:** hold, and let the audience try to resolve the dark mass.
**Light:** prison preset. The cold shaft of daylight on the ledge means the four
humans are the brightest, most readable things in the frame — a rule for this
entire set. The basin has dim violet bounce that defines its volume. **The far
wall and the ceiling must remain faintly visible; this is never a black screen.**

---

### SCENE 10 — THE SOVEREIGN · 0:32 · Set E

*Purpose: the creature reveal, built from anatomy and one movement. It is alive
before it is seen.*

**10.01 — ROOTS** · 4s · 46° · slow dolly forward, low
Foreground: the basin ice at knee height, and spreading across it, black material
in branching veins — frozen roots, radiating from somewhere ahead. The camera
follows them in the direction they thicken. Middle ground: the veins converging,
getting wider and more numerous. Background: dark.
**Cut motivation:** the roots converge on something solid.
**Light:** a carried lamp from behind camera rakes across the ice; the black
material reads as absence, not as surface.

**10.02 — THE CLAW** · 4s · 42° · static, slow tilt up
Foreground: ice. Middle ground: where the roots meet, a shape resolves out of the
ice — four dark digits, each with two visible joints, half-buried, curled. It is
not a rock and it is not a machine. Between two of the plates on the back of the
hand, a thin violet seam. Background: black, and above, the faint suggestion of
something much larger continuing upward.
**Cut motivation:** the tilt runs out of light.
**Light:** the same single raking lamp. The violet seam is the only emissive and
it is no wider than a finger.

**10.03 — SCALE** · 4s · 50° · static, wide
Foreground: the claw from 10.02, now in full, at frame left. Middle ground: Lyra
walking into frame at the right and stopping at a distance from it, lamp raised.
**A single digit of that hand is longer than she is tall.** Background: the
basin, the dark mass rising behind the hand, unresolved.
**Cut motivation:** her lamp lifts from the hand toward the mass.
**Light:** her lamp plus the ledge's daylight shaft behind her, giving her a rim
so she reads cleanly against the dark.

**10.04 — FOLDED** · 4s · 55° · slow dolly right
Foreground: an ice ridge crossing frame. Middle ground: the camera travels across
the creature's flank and we read structure for the first time — overlapping
armour plates, a limb folded hard against the trunk with its joints stacked, a
second limb behind it, and the collapsed slabs of a wing folded along the back
like scaffolding that has come down. None of it is symmetrical. The plates are
charcoal blue-black, and the seams between them carry violet at very low value.
Background: the far cavern wall, faintly visible, which keeps the creature
readable as a mass in front of something.
**Cut motivation:** the dolly reaches the head.
**Light:** two lamps at low angle from the ledge, plus basin violet bounce. The
creature's body is darker than everything around it — it separates by being
*darker*, not by glowing.

**10.05 — SIX CLOSED EYES** · 4s · 36° · static
Foreground: ice crystals on the plating, very close, out of focus. Middle ground:
the head — an elongated forward-canted wedge, and along it, two staggered rows of
closed eyes, six in total, asymmetrically placed, each a slit of dark seam. The
head is angled slightly toward the ledge, which is a fact the audience registers
without being told. Background: darkness and the faintest cavern wall.
**Cut motivation:** hold. Nothing happens. That is the point.
**Light:** a single cold lamp from the ledge, raking; the closed eyes are *not*
lit from within.

**10.06 — THE ARMY** · 4s · 63° · slow crane up and back, pace Slow
Foreground: the head from 10.05 at the bottom of frame, going out of focus as we
pull. Middle ground: the creature's full mass resolving as the camera rises —
still folded, still ambiguous in outline, occupying the centre of the basin.
Background: **the other shapes.** Fourteen smaller silhouettes frozen in the ice
around it at varying depths and rotations, some almost fully buried, some with a
limb or a head clear of the surface, receding into the dark until they can no
longer be counted. The audience understands there are more than fourteen.
**Cut motivation:** the pull-back stops; the count is not finishable.
**Light:** basin violet bounce at its strongest here, defining the field; the
ledge's daylight shaft far behind, giving depth.

**10.07 — IT MOVES** · 5s · 40° · static, absolutely locked off
The most important shot in the scene and the camera does nothing at all. Middle
ground: the creature's hand from 10.02/10.03, in frame, still. Nothing else moves
in frame — not dust, not light. Three full seconds of dead stillness. Then **one
digit closes.** One. It travels a short distance, fast, and stops hard — no ease
out. Then stillness again. Foreground: nothing, so there is no doubt about what
moved. Background: nothing, same reason.
**Cut motivation:** the digit stops, and the cut lands on the silence after it.
**Light:** unchanged, which is critical — **no light change accompanies the
movement.** The audience learns it is alive from motion alone.

**10.08 — THEY UNDERSTAND** · 3s · 50° · handheld
Back on the ledge, reverse. Foreground: the retaining wall. Middle ground: the
four humans. Lyra has both hands on the retaining wall and has leaned *forward*.
A soldier has brought his rifle down off his shoulder into his hands without
raising it. Voss has taken a step back and is looking at his instrument, then at
the creature, then at the instrument — checking, because checking is what he does
when he is frightened. Background: the basin and the dark mass, out of focus.
**Cut motivation:** the scene has stated its fact; cut to the consequence.
**Light:** the ledge daylight shaft keys all four; no one is glowing, no one is
silhouetted into illegibility.
**Continuity:** the soldier's rifle stays in his hands, not on his shoulder, for
the rest of the film.

---

### SCENE 11 — THE ORDER · 0:24 · Set D

*Purpose: the decision that causes everything. An argument staged in a working
room, with the room still working.*

**11.01 — BACK UP TOP** · 3s · 58° · static wide
The chamber laboratory, busier than Scene 8 — the discovery below has changed
the tempo. Foreground: a technician carrying a case past the lens at speed.
Middle ground: Hale at the analysis station with two officers, pointing once at
a monitor; Voss arriving from the shaft with his hood pushed back; Lyra a few
steps behind him, still pulling her safety line clip off. Background: soldiers at
the arch, now three instead of two; a lamp tree being repositioned.
**Cut motivation:** Lyra's clip comes free and she walks into the argument.
**Light:** full post-research chamber plan.

**11.02 — "THE GREATEST WEAPON"** · 4s · 46° · static, screen-left
Foreground: the analysis station's monitor edge. Middle ground: Voss, making the
case — that what they have found is the most significant object in human history
and that it can be understood. His gestures stay small and specific: he touches
the monitor's screen twice, at two different points, rather than waving at the
machine. Hale is beside him, listening without moving at all. Background: Aegis
Zero's chest and the dark core, framed deliberately between the two men.
**Cut motivation:** Lyra answers from off-screen, and the camera goes to her.
**Light:** monitor cold from the front, warm practical from above and behind.

**11.03 — "IT CHOSE TO STAY"** · 5s · 44° · static, screen-right
Lyra's side of the axis. Foreground: nothing between camera and her; her
coverage is the most direct in the scene, because she is the one being direct.
Middle ground: Lyra, holding her printed translation but **not reading from it**
— she knows it. She says the machine was not buried here, that it chose to
remain, and that the chains are not restraints. She gestures once, downward, at
the floor. Background: the chains on the floor behind her, in frame, and the
shaft — the evidence is literally in the shot with her.
**Cut motivation:** Hale speaks.
**Light:** warm key from her left, monitor fill cold on her right side, breach
light rimming her hood. Her ivory parka holds fold detail and does not blow out.

**11.04 — HALE DECIDES** · 5s · 42° · static, screen-left, slight low angle
Foreground: the out-of-focus shoulder of one of his officers at frame right.
Middle ground: Hale. He says that they did not cross half the planet to bury it
again, and that the machine will be brought online under controlled power. He
moves exactly once during the line — a single full-body turn to face the machine
on the word he lands on. The low angle is slight; he is not made monstrous.
Background: the machine behind him, and behind that the myth wall, out of focus.
**Cut motivation:** the decision is made; cut to the person it lands on.
**Light:** warm key from high, deliberately more contrasted than Lyra's coverage
— his side of the room is harder-lit than hers for the whole scene.

**11.05 — SHE STOPS MOVING** · 3s · 40° · static
Lyra's framing again, matched to 11.03. Middle ground: Lyra's hands, holding the
translation, go still. Her jaw sets. She does not argue further, and she does not
step back. Her eyes move — to the machine, to the floor, to Hale — working the
problem. This is the third and last use of her "hands stop" tell, and it now
means something different than it did in Scene 2. Background: unchanged from
11.03; the chains and shaft still behind her.
**Cut motivation:** she makes a decision of her own and starts walking.
**Light:** unchanged.

**11.06 — THE ROOM PREPARES** · 4s · 60° · slow dolly right
The consequence, shown as work. Foreground: a power trunk being dragged across
the floor toward the machine, two workers on it. Middle ground: a lift platform
rising up the machine's right side with Voss and a technician on it; a scientist
running new cable up the scaffold; Hale's officers clearing people back from the
seal ring. Background: Lyra walking the opposite direction to everyone else, into
the frame's depth, toward the scaffold's base — she is going up too, and she is
going up alone.
**Cut motivation:** she reaches the ladder.
**Light:** unchanged; the lift platform carries a lamp that moves up the machine's
flank, throwing a travelling pool of light up its plating.

---

### SCENE 12 — ACTIVATION · 0:22 · Set D, the chest mechanism

*Purpose: the cause. The audience must be able to say afterwards: they fed it
power and spoke the key; the core accepted; the chains carried it down; that woke
the other one.*

**12.01 — THE MECHANISM** · 4s · 38° · static
Foreground: the lift platform's rail and Voss's hands setting a clamp. Middle
ground: the core, close — a recessed disc with a ring of symbols around its rim,
and beside it, now, a human power coupling clamped to the plating with a thick
cable running down out of frame. Two systems, one ancient, one built last week,
touching. Background: the chest plating and the torn shoulder above.
**Cut motivation:** Voss confirms the coupling is seated.
**Light:** a work lamp clamped to the platform rail; cold monitor spill from
below; the core's faint standing cyan value on its rim.

**12.02 — THE WORDS** · 4s · 40° · static
Foreground: the symbol ring on the core's rim, shallow-focus. Middle ground:
Lyra, arriving on the platform, looking at the activation symbols. She has the
translation in one hand and she does not need it. She glances down — at the
floor, at the chains, at the shaft, all far below — before she looks back at the
symbols. Background: the chamber floor below, deep and busy.
**Cut motivation:** Hale's voice from below tells her to read it, or the machine
translation will.
**Light:** the platform work lamp keys her from the side; below her, the
chamber's lamp trees give a warm up-light that reads as depth.

**12.03 — SHE PUTS HER HAND ON IT** · 4s · 36° · static, tight
Foreground: the core's surface, the symbol ring. Middle ground: Lyra's bare right
hand — the glove comes off again, and the callback to Scene 3 is the point —
placed flat against the mechanism. Her hand is small on it. She speaks: *"Guardian
of the final light, awaken and answer humanity's call."* Background: her face,
out of focus behind her own hand.
**Cut motivation:** the last word lands.
**Light:** unchanged, until the final frames, when the cyan value under her hand
begins to rise — starting *around her fingers*, spreading outward.

**12.04 — THE CORE ACCEPTS** · 4s · 34° · static, very slow push
Foreground: the edge of her hand withdrawing from frame. Middle ground: the core.
The symbol ring lights, one symbol at a time, going round — a legible, countable
sequence, not a flash. When the ring completes, the recessed disc itself lifts
about a stud and rotates a quarter turn with a mechanical sound, and the first
real cyan light of the film comes on inside it: not bright, but *deep*, like
something seen through water. Background: the chest plating, now with its seams
faintly lit from inside.
**Cut motivation:** the coupling cable snaps taut.
**Light:** the core becomes a genuine light source and begins to key the plating
around it. This is the first time anything on the machine illuminates its
surroundings, and from here it only grows.

**12.05 — THE DRAW** · 3s · 46° · static, low, looking along the cable run
The cause chain, made visible in one shot. Foreground: the power trunk cable on
the floor, running away from camera toward the machine, and it **jumps** — the
slack pulling straight as the load hits it. Middle ground: the generator skid at
frame left, its needles swinging across their dials, a technician putting both
hands on the housing. Background: Hale watching the gauges, not the machine.
**Cut motivation:** the needles peg.
**Light:** the generator skid's indicator lamps change from green to amber, a
small, specific, readable light change.

**12.06 — DOWN THE CHAIN** · 3s · 44° · static, tight on the chain at the shaft lip
Foreground: the chain links crossing the seal ring, the shaft lip behind them.
Middle ground: a cyan pulse travels *along the chain*, link to link, from the
machine's hands toward the shaft, and **over the edge, down.** It is a discrete,
trackable thing moving through a physical conductor. Background: the shaft
opening, dark, swallowing it.
**Cut motivation:** the pulse disappears into the shaft. The audience knows
exactly where it went.
**Light:** the travelling pulse briefly lights each link as it passes and leaves
it dark again. Nothing else changes.
**Continuity:** this is the film's causal spine. Everything that happens in
Scene 14 is the answer to this pulse, and the answer comes back up the same
chains.

---

### SCENE 13 — AEGIS WAKES · 0:34 · Set D

*Purpose: the machine's startup, as power moving through a body — not as lights
turning on. Ends with the audience understanding its weight.*

**13.01 — INSIDE FIRST** · 4s · 40° · static
Foreground: a gap between two armour plates at the machine's flank, filling the
frame. Middle ground: inside the gap, the dark internal layer — and within it,
cyan light coming up slowly, illuminating the internal structure from behind and
revealing mechanical detail we have never been shown. Nothing on the *outside*
of the machine has changed. Background: none; the gap is the frame.
**Cut motivation:** a mechanism inside the gap unlocks and shifts with a hard
clack.
**Light:** internal cyan, entirely contained by the plating. The outside stays
dark.

**13.02 — UNLOCKS** · 3s · 44° · static, moving down the body in cuts
Three small mechanical events in one shot, at three points in frame: a shoulder
lock rotating and disengaging, a hip clamp releasing, an ankle collar dropping a
few millimetres. Each one is a separate visible mechanism doing a separate visible
job. Foreground: frost breaking loose from each and falling. Middle ground: the
plating around each. Background: chamber lamp trees, out of focus, and people
running out from under the machine.
**Cut motivation:** the last collar drops and the whole body settles a fraction
under its own weight — a tiny movement, the first the machine has made.
**Light:** joint interiors now show cyan where they were dark.

**13.03 — THE FINGERS** · 4s · 42° · static, tight on the right hand
Foreground: the chain link in the hand's grip. Middle ground: the fingers. The
index finger's first joint moves — a few degrees, testing. Then stops. Then the
whole hand closes one notch tighter on the chain, and the chain's anchor point in
the floor creaks and shifts a stud. Background: the seal ring's plates and, out of
focus, the shaft. The machine's first deliberate act is to hold *harder.*
**Cut motivation:** the anchor gives, and the sound of it carries.
**Light:** joint interiors cyan; the lamp tree below keys the hand warm; the
contrast of the two is what makes the hand read as three-dimensional.

**13.04 — THE SHOULDERS** · 3s · 46° · static
Foreground: the analysis station monitors at the bottom edge, with Voss's head
and shoulders below them, looking up. Middle ground: the shoulder assembly — the
whole upper body rises about a stud as the shoulders roll back and settle into an
active position, the armour plates re-seating against each other in sequence, not
all at once. Frost sheets off the back and falls past camera. Background: the
vault above.
**Cut motivation:** the head begins to lift.
**Light:** spine seams now carry cyan; the frost falling through the lamp trees'
beams is the shot's best motion cue.

**13.05 — THE HEAD** · 5s · 44° · slow crane up with the head's rise
Foreground: none — clean. Middle ground: the head, bowed since Scene 5, lifting.
It rises slowly, the neck's internal layer visible and lit cyan from inside, and
it keeps rising until the head is level. Then, and only then, the optic band
comes on: not a flash — it fills from the centre outward across the band, and it
is **interrupted at the crack in the left faceplate**, so the damage remains
legible even in its most iconic image. Background: the ribbed vault behind the
head.
**Cut motivation:** the optic band completes and the head turns, very slightly,
toward the people below.
**Light:** the optic band and core are now genuine sources keying the chamber's
upper volume cyan. The warm lamp trees below and the cold breach light above are
still present, so the room has three light colours at once and still reads.

**13.06 — IT SEES THEM** · 3s · 55° · static, from the chamber floor looking up
Foreground: the backs of heads — Voss, two technicians, a soldier, all at the
bottom of frame, all looking up, none of them running yet. Middle ground: the
machine's head, far above, turned down toward them; the chest core lit; the torn
shoulder catching cyan from inside. Background: the vault. The composition is
built so the humans occupy the bottom eighth of the frame.
**Cut motivation:** the chains go taut and the seal ring cracks.
**Light:** the machine is now the room's brightest object, lighting the people
below from above — the first shot in the film where the machine lights the humans
instead of the reverse.

**13.07 — THE SEAL** · 4s · 57° · high static, looking down at the ring
Foreground: nothing; a clean plan view. Middle ground: the seal ring, seen from
above, its inlaid segments separating along their joints as the machine's weight
comes off the kneeling knee — plates lifting, ice cracking out of the joints,
the shaft's opening widening. Background: the machine's shoulders and head
filling the top of the frame, and a scatter of human figures running outward from
the ring in four different directions.
**Cut motivation:** the knee comes up.
**Light:** violet is now visible from the widening shaft, mixing with the core's
cyan on the ring plates — the two colours meeting on the floor is the first
visual statement that the two things are connected.

**13.08 — IT STANDS** · 5s · 60° · low wide, slight crane up, pace Slow
The weight shot. Foreground: the seal ring's broken plates and a lamp tree
knocked at an angle. Middle ground: **the stand** — the raised knee takes load,
the hips drive up and forward first, the torso follows a beat behind, the head
last and slightly late, over-travelling a few degrees before settling level. The
trailing leg drags its foot and then plants. The machine is now at full height
and its head is close enough to the vault ribs to make the room feel small.
Background: the vault, the myth wall, the arch, with people visible at the frame
edges running for it.
**Cut motivation:** the machine takes its first step.
**Light:** the core and optic band travel upward through the room as it rises,
sweeping cyan across the vault ribs — a moving light with an obvious source.

**13.09 — THE FIRST STEP** · 3s · 50° · static low, camera on the floor
Foreground: the plate floor, close, and a fallen clipboard and a coil of cable
lying on it. Middle ground: a foot enters the top of frame, descends, and lands.
On contact: the knee compresses about eight degrees, the upper body settles a
beat later, dust jumps off the floor in a ring, and the clipboard and cable in
the foreground hop once. Background: human legs, running, at the far edge of
frame.
**Cut motivation:** hard cut on the impact, down to the prison.
**Light:** the foot's descent shadows the foreground before it lands — the
shadow arrives first, which is what sells the mass.

---

### SCENE 14 — THE PRISONER WAKES · 0:24 · Set E

*Purpose: the answer to 12.06, and the Sovereign's movement contrasted against
Aegis's.*

**14.01 — THE PULSE ARRIVES** · 3s · 44° · static, tight on a chain anchor
Foreground: one of the four chain anchors driven into the basin ice, with the
black root material grown around it. Middle ground: the cyan pulse from 12.06
arrives down the chain, reaches the anchor, and stops. A beat. Then the root
material around the anchor lights from within — **violet**, travelling *outward*
along the roots, away from the anchor, in every direction. Background: the basin
ice, catching the spreading violet.
**Cut motivation:** the violet reaches the edge of frame and keeps going.
**Light:** a travelling emissive along a physical path, which we have already
been taught to read. No ambient change yet.

**14.02 — ONE EYE** · 4s · 36° · static, locked off
Foreground: none. Middle ground: the head from 10.05, the six closed eye seams.
The violet arrives along the plating. **One eye opens** — the lowest of the six,
not the most obvious one — and it does not fade in. It opens mechanically, a
shutter of plates retracting, and behind it there is depth. It is looking
slightly off-axis, at nothing. Then it rotates and finds the ledge. Background:
dark.
**Cut motivation:** the eye finds the camera's side of the room.
**Light:** one small violet source. **The creature's body must still be readable
by its own darkness against the basin — check this frame specifically.**

**14.03 — THE HEAD COMMITS** · 4s · 42° · static
Foreground: ice ridge, low. Middle ground: the head. It turns — fast, one
committed motion, no ease out — through a large angle to face the ledge fully,
and stops dead. **The body does not move at all.** Two seconds of the head
pointed at the humans while the trunk remains exactly as it was. Then the
remaining five eyes open in a ragged sequence, over about a second, not
simultaneously. Background: the folded mass of the body, unchanged.
**Cut motivation:** the trunk finally begins to rotate to follow the head.
**Light:** six violet sources now, still small, still not lighting the room.

**14.04 — IT TAKES ITS OWN WEIGHT** · 5s · 55° · slow pull back, low
Foreground: ice, cracking — fractures racing outward across the basin floor
toward camera. Middle ground: the creature unfolding. A forelimb extends and its
claw plants on the basin floor; the trunk lifts; a hind leg comes under it and
takes load; the ice shell that has encased it for millennia breaks off in sheets
and falls. Each limb arrives and stops hard, with no settle — the opposite of
Aegis's easing. Background: the cavern, and the wing slabs beginning to rise off
the back.
**Cut motivation:** the mass has come off the floor.
**Light:** the violet seams are now numerous enough to define its whole outline
from within, but the body stays overwhelmingly dark. Basin bounce rises slightly
because there is more emissive area, not because the ambient was raised.

**14.05 — ONE OF THEM BREAKS FREE** · 4s · 46° · handheld
Foreground: one of the smaller frozen silhouettes, close, the ice around it
crazing. Middle ground: it comes out of the ice in one burst — a Warden, a tier
smaller, same charcoal, same violet seams, a single eye band — lands on the basin
floor in a crouch and holds absolutely still. It looks like a smaller sentence of
the same language. Background: three more shapes beginning to crack out of the
ice behind it, and beyond them, more.
**Cut motivation:** it turns its head toward the ledge and the soldiers react.
**Light:** unchanged; the handheld is motivated because we are effectively at
the soldiers' eye line now.

**14.06 — RETREAT** · 4s · 58° · handheld, fast
On the ledge. Foreground: the retaining wall and a dropped lamp rolling.
Middle ground: three distinct behaviours in one frame — the two soldiers move
**forward** to the wall and raise their weapons, putting themselves between the
basin and the stair; Voss moves **backward** toward the stair and stops at its
foot to hold the safety line out for whoever comes next; and **Lyra does not
move at all**, still at the wall, still watching, until Voss physically takes her
sleeve. She goes, but she goes last, and she looks back.
**Cut motivation:** she is pulled out of frame and the camera holds one beat on
the empty wall.
**Light:** the ledge's cold daylight shaft still keys the humans; the basin
behind them is a dark field with violet points in it.
**Continuity:** Voss's grip on Lyra's sleeve is the reason they arrive upstairs
together in 15.02.

---

### SCENE 15 — CONTAINMENT FAILS · 0:28 · Sets D, C, A

*Purpose: evacuation where every person has a destination. Chaos we can read.*

**15.01 — EMERGENCY** · 3s · 57° · static wide
The chamber. Foreground: the broken seal ring and the widened shaft. Middle
ground: the chamber's normal lighting cuts out in one frame and the emergency
practicals strike — red units at the four pillars and above the entrance arch,
plus a small cool fill from the breaches. The room does not become red; it
becomes **dark, with red sources in it.** Aegis Zero stands at the ring, head
turned toward the shaft. Background: people already moving toward the arch.
**Cut motivation:** a klaxon note and the first runner reaches the arch.
**Light:** emergency preset. **Check: floor plane visible, every silhouette
separated, shadows neutral not red-tinted.**
**Continuity:** emergency lighting stays on for the rest of the Arctic sequence.

**15.02 — OUT OF THE SHAFT** · 4s · 50° · handheld, track backward
Foreground: the shaft's winch frame and safety line whipping. Middle ground:
Lyra and Voss coming up out of the shaft together — Voss first, hauling, Lyra
after, both of them arriving at the top and immediately separating: **he goes
left toward the console bank, she goes right toward the scaffold.** Two soldiers
come up behind them and go straight to the shaft edge and face down into it.
Background: the chamber, red-lit, with the machine's cyan at the top of frame.
**Cut motivation:** their paths diverge and the camera picks one.
**Light:** red practicals rim them; the shaft below pushes violet up past their
legs.

**15.03 — HALE DIRECTS** · 4s · 55° · static
Foreground: a crate and a running technician crossing frame. Middle ground:
Hale, planted at the entrance arch — **the one fixed point in a moving frame.**
He is pointing people through: researchers to the tunnel, a wounded man handed
off to two others, a soldier redirected to the shaft. He does not run and he does
not leave. Every person who passes him is given a direction by a single gesture
and then goes that way. Background: the tunnel beyond the arch, with the string
of work lamps and the vehicle at its far end — the route we established in 7.04,
being used.
**Cut motivation:** he shouts a name and the camera follows it.
**Light:** the arch practical above him, plus red from the pillars behind.

**15.04 — JOBS, NOT PANIC** · 4s · 58° · slow pan right
One pan across the chamber floor showing four distinct, simultaneous, legible
purposes. Foreground: a scientist gathering sample cases and dropping two on
purpose to carry the third. Middle ground: two technicians staying at the
generator skid, hands on breakers, working the emergency shutdown sequence
instead of running; a soldier walking a wounded colleague out with an arm under
his shoulder; three researchers in a line moving toward the arch, one of them
pulling another by the coat. Background: the shaft, with two soldiers still
facing down into it, weapons up, not retreating. Nobody runs in a random
direction.
**Cut motivation:** the pan reaches the shaft and something comes out of it.
**Light:** red practicals plus the generator skid's amber indicators, which are
the only non-red colour on the floor and therefore draw the eye exactly where
Scene 17 will need it.

**15.05 — IT COMES UP** · 4s · 46° · handheld
Foreground: the shaft lip. Middle ground: a clawed forelimb comes over the lip
and plants — the Sovereign is ascending through the shaft it was sealed under.
The two soldiers at the edge fire, and the muzzle flashes are brief and small
against it. Background: the chamber and the red pillars. The limb does not
flinch.
**Cut motivation:** the soldiers break and move to Hale's line.
**Light:** muzzle flashes as brief practicals; violet rising from the shaft.

**15.06 — THE TUNNEL** · 3s · 55° · track backward ahead of the evacuees
Foreground: the tunnel floor and duckboards. Middle ground: a column of people
moving up the tunnel at pace, lamps swinging, one soldier at the front and one at
the back — a *formation*, not a mob. A researcher stumbles on the duckboards and
the person behind picks her up without stopping.
Background: the chamber's red glow receding behind them.
**Cut motivation:** daylight appears at the tunnel mouth.
**Light:** the strung work lamps, some of them out now, some flickering; red
spill from behind; grey daylight ahead.

**15.07 — SURFACE** · 3s · 63° · static wide
Exterior, base. Foreground: the tunnel mouth with people emerging into the wind.
Middle ground: two tracked vehicles loading, a soldier at each ramp counting
people aboard by touching each one's shoulder; the comms mast with a technician
at its base working a radio. Background: the base, the plain, the storm heavier
than it was in Scene 1 — the weather has worsened across the film, which is the
cheapest possible continuity of elapsed time.
**Cut motivation:** the ground shakes.
**Light:** exterior key, darker than Scene 1 — later in the day, heavier cloud.
Vehicle headlamps and perimeter lamps read strongly now.

**15.08 — FROM BELOW** · 3s · 62° · static, low
Foreground: snow and a fuel drum. Middle ground: the ice surface between the
tunnel mouth and the excavation **cracks** — a fracture line running across
frame, wide enough to see down into, with violet light in it. A worker running
across that ground changes direction to avoid it, which is how we know it is
real. Background: the base modules, the comms mast leaning slightly.
**Cut motivation:** cut back down into the chamber for the fight.
**Light:** violet from the fracture, low, from below, on the snow — the first
time the creature's colour reaches the surface world.

---

### SCENE 16 — THE FIGHT · 0:26 · Set D

*Purpose: short, physical, readable. Every attack is a sequence of body
mechanics, and effects only ever appear at contact.*

**16.01 — FACING** · 4s · 60° · static wide, from the perimeter walkway
Foreground: the walkway railing. Middle ground: the two of them in one frame for
the first time — Aegis Zero standing on the broken ring, feet planted, hands
open at its sides; the Sovereign fully out of the shaft, lower than Aegis but far
longer, its head low and forward, six eyes on the machine. Neither moves.
Background: the chamber, red-lit, the myth wall behind them, humans gone from the
floor. Three full seconds of stillness in a wide frame, which is what makes the
first movement land.
**Cut motivation:** the Sovereign's hind legs compress.
**Light:** cyan from the machine on one side of the room, violet from the
creature on the other, red practicals between them. Three sources, three
positions, all placed.

**16.02 — THE LUNGE** · 3s · 50° · static low, slight whip pan to follow
Foreground: floor plates. Middle ground: the Sovereign holds, compresses — hind
legs and trunk folding down for a quarter second — then **launches**, crossing the
frame fast and low with its forelimbs leading. The camera does not cut during the
movement; it pans to hold it, so the distance travelled is honest. Background:
the machine, braced, its feet sliding backward a stud as it takes the impact.
**Cut motivation:** contact.
**Light:** at contact only — a brief flare where claw meets chest plating, plus
sparks and a puff of frost knocked off the plating. Nothing before contact.

**16.03 — WEIGHT AGAINST WEIGHT** · 4s · 46° · handheld, close
Foreground: the machine's forearm, close, holding the creature's forelimb away
from it. Middle ground: the two of them locked, both straining — the machine's
elbow servo visibly compressing, the creature's digits gripping and slipping on
the plating, scoring it. The machine's rear foot slides backward another half
stud, and the floor plate under it lifts at one edge. Background: red, blurred.
**Cut motivation:** the machine plants and stops sliding.
**Light:** contact sparks intermittently at the grip point; the machine's core
under-lights the creature's head from below, which is the shot's best image.

**16.04 — THE PUNCH** · 5s · 50° · static, three-quarter, full-body
The film's signature mechanical action, and it is shown *complete*, in one shot,
from an angle where the whole body is visible. Foreground: nothing — clean.
Middle ground: the sequence, in order, all of it legible: the machine **plants
its left foot**, transfers weight onto it, **rotates its hips**, the torso
follows, the right shoulder **pulls back** and the arm cocks, then the chain
drives forward — shoulder, then elbow extending, then the hand arriving last —
and **contact**. The creature's head snaps aside, its trunk rotates with the
force, its near foot **slides and repositions** to stay up, and its forelimbs
come up late in reaction. The machine continues slightly through the punch, then
**recovers its balance**, pulling the arm back and re-squaring its feet.
Background: the myth wall and the vault, in frame, so the action has a space.
**Cut motivation:** the recovery completes.
**Light:** a single bright contact flash at the impact frame, lasting under three
frames, followed by sparks and a dust ring at the creature's feet where it slid.
No light before the arm arrives.

**16.05 — IT DOES NOT STAY DOWN** · 3s · 44° · static
Foreground: the creature's head at frame left, low, where the punch put it.
Middle ground: it holds there, absolutely still, for a beat and a half — and
then the head turns back toward the machine without the body moving at all.
Background: the machine, out of focus, resetting its stance.
**Cut motivation:** the creature's mid-limbs unfold — two limbs we have not seen
used yet.
**Light:** unchanged.

**16.06 — FOUR LIMBS** · 4s · 55° · handheld
Foreground: the machine's back and shoulder, close, from behind. Middle ground:
the Sovereign comes forward using four limbs at once, in an irregular rhythm —
not a gallop, not a walk, something wrong — and drives the machine backward
across the chamber floor. The machine's feet leave twin furrows in the plating.
Background: **the generator skid and the power trunk at the chamber wall**, which
the machine is being driven toward. The audience is shown the destination before
the collision.
**Cut motivation:** the machine's back reaches the skid.
**Light:** amber indicator lamps on the skid become prominent as they get closer
— the shot is *lighting* its own Chekhov's gun.

**16.07 — IMPACT** · 3s · 50° · static
Foreground: the generator skid's housing at frame right. Middle ground: the
machine is driven back into the bank; the skid's housing crumples, the power
coupling at the machine's chest is torn half free, and the trunk cable whips. An
arc jumps between the torn coupling and the skid — white-blue, brief, repeated.
Background: the chamber.
**Cut motivation:** the arc repeats a second time and a technician's voice calls
a warning.
**Light:** the arc is a hard, brief, moving practical that throws hard shadows
across the chamber for the frames it exists. It is the first warning sign of the
detonation.
**Continuity:** the coupling is torn and arcing from here until 17.04. The
generator bank is damaged and stays damaged.

---

### SCENE 17 — THE DETONATION · 0:22 · Sets D, A

*Purpose: a catastrophe with a specific physical source, visible warning signs, a
human cause, and a blast the audience can actually see.*

**17.01 — SHE GOES UP** · 4s · 50° · track upward with the lift platform
Foreground: the platform's rail and Lyra's hands on the control. Middle ground:
Lyra riding the lift up the machine's flank — alone, deliberate, while everything
below her is coming apart. Her face is lit from below by the arcing coupling in
flashes. Background: the chamber floor falling away, red-lit, with the fight
happening at the frame's edge — she is ascending *past* a fight.
**Cut motivation:** the platform reaches the core.
**Light:** arc flashes from below, red practicals, core cyan from the side.

**17.02 — THE FRAGMENT** · 5s · 38° · static, tight
Foreground: the open core, lit cyan, its disc still lifted and rotated from
12.04. Middle ground: Lyra's bare hand reaching into it and closing on something
small; she draws it out — a fragment, cyan, the size of a thumb. She presses it
into the **wrist device** we have seen on her left forearm since Scene 1, and it
seats with a click. The core's light drops noticeably when the fragment leaves
it. Background: her face, catching the fragment's light, then losing it.
**Cut motivation:** she looks down at the generator bank.
**Light:** the fragment is the brightest small object in the film for two
seconds, and its removal visibly *dims* the machine — cause and effect in one
shot.

**17.03 — WARNING SIGNS** · 4s · 46° · handheld, quick coverage
Four specific pieces of evidence, in one continuous handheld move across the
chamber floor: the generator bank's indicators going from amber to red; the
chamber's emergency lamps dropping and flickering in sympathy; a technician
backing away from the breaker panel with both hands raised and shouting; and the
arc at the torn coupling now continuous rather than intermittent. Foreground:
cable on the floor whipping. Background: the two combatants, out of focus, still
fighting.
**Cut motivation:** Lyra puts her hand on the platform's emergency release.
**Light:** the flicker is the shot's engine. Every flicker is the emergency
practicals dimming and recovering, never a global brightness swing, and the floor
stays visible in the darkest frame.

**17.04 — SHE MAKES IT HAPPEN** · 4s · 44° · static
Foreground: the breaker panel at the generator bank, a red lever guarded by a
cage. Middle ground: Lyra, on the floor now, arriving at the panel — she has come
down, and we saw the platform start down, so it is accounted for. She throws the
cage back and pulls the lever, dumping the full plant load into the damaged
trunk. Background: she looks up, once, at the machine. The machine's head is
turned down toward her.
**Cut motivation:** the lever bottoms out.
**Light:** every indicator on the bank goes to red at once; the arc at the
coupling becomes a continuous white-blue column.

**17.05 — THE BLAST** · 3s · 55° · static, from the perimeter walkway
The explosion, seen as a physical event with a location. Foreground: the walkway
railing, a fixed reference the blast passes. Middle ground: **the generator bank
detonates.** The initial flash is bright but lasts under three frames and is
localized to the bank — the rest of the frame stays visible throughout. A
shockwave front moves outward from it as a visible ring of displaced dust,
crossing the chamber floor at a readable speed; it reaches the pillars, the
scaffold, the seal ring, and the two combatants in that order. The scaffold
comes apart, the near pillar cracks and sheds, and the vault's ribs begin to
drop. Background: the myth wall, visible, then obscured by dust — obscured by
*dust*, not by white.
**Cut motivation:** the shockwave reaches the machine and the creature.
**Light:** the flash is short and local. Afterwards the chamber is lit by fire
at the bank and by the surviving red practicals. **No full-frame white-out. No
bloom bath. The blast centre, the floor, the architecture and every silhouette
must remain identifiable in every frame of this shot.**

**17.06 — FROM THE SURFACE** · 2s · 60° · static wide, exterior
Foreground: the base, the vehicles, figures on the snow flattening themselves or
bracing against vehicles. Middle ground: the ice over the excavation **lifts**,
breaks, and drops — a collapse crater forming across the dig, throwing snow and
fragments outward and downwind. The comms mast goes over. Background: the plain
and the iceberg, unchanged and indifferent, which is the point.
**Cut motivation:** the collapse settles and the film slows down.
**Light:** a brief orange under-light from the collapse venting, then only
exterior key, storm, and vehicle lamps.

---

### SCENE 18 — AFTERMATH · 0:24 · Sets A, D, E

*Purpose: slow down. Show consequences. Leave exactly one question.*

**18.01 — QUIET** · 5s · 63° · static wide, exterior, very slow push
Foreground: snow falling through the frame, heavier than before, and a scatter of
debris on the ice — a torn panel, a case, a dropped glove. Middle ground: the
collapse crater where the excavation was, venting a slow column of steam and
dust that the wind bends. Two tracked vehicles at a distance with their lamps on,
people moving between them slowly, carrying and helping rather than running.
Background: the base, half of it gone, the comms mast down across a module.
Nobody speaks for the whole shot.
**Cut motivation:** hold on the steam column, then cut down.
**Light:** exterior key at its dimmest — late, storm-heavy — with vehicle lamps
and one surviving perimeter lamp as the only warm sources.

**18.02 — THE RUIN** · 4s · 57° · slow dolly, chamber
Foreground: a fallen vault rib lying across the floor plates, smoking at one end.
Middle ground: the chamber, wrecked — the scaffold collapsed, the analysis
station crushed under debris, the generator bank burning low, the seal ring
buried under fallen rock, cable ends sparking intermittently. Smoke lies in
layers at two heights, caught in the surviving red practicals. Background: the
myth wall, cracked across two of its three panels but still legible.
**Cut motivation:** the dolly passes something cyan in the rubble.
**Light:** two surviving red practicals, the burning bank, and shafts of grey
daylight now coming down through the collapsed ceiling — a new light source with
an obvious cause.
**Continuity:** smoke, the fallen rib, the collapsed scaffold and the burning
bank persist in every subsequent chamber shot.

**18.03 — NEITHER OF THEM IS THERE** · 4s · 55° · static
Foreground: rubble. Middle ground: the centre of the chamber where the two of
them were fighting — **empty**, with the floor collapsed through into the shaft
below, the edges of the hole still shedding debris. Deep scoring on the remaining
plates where something very heavy was dragged. Background: the vault's open sky
hole above, snow already falling through it into the chamber.
**Cut motivation:** the camera tilts down into the hole.
**Light:** daylight from above, red from the sides, dark below.

**18.04 — SURVIVORS** · 4s · 50° · handheld, gentle
Exterior, at a vehicle ramp. Foreground: a medical case open on the snow, hands
working in it. Middle ground: Voss, sitting on the ramp edge, a dressing on his
temple, holding someone else's instrument case in his lap and not looking at it.
He is counting people as they pass, silently, which we can read from his eyes
moving. Hale stands a few paces away with a radio handset, listening, not
speaking — the first time in the film he has no instruction to give. Background:
soldiers loading, a scientist wrapped in a blanket, snow.
**Cut motivation:** Hale lowers the handset.
**Light:** vehicle lamps warm from one side, storm daylight cold from the other.

**18.05 — NOBODY SAYS HER NAME** · 4s · 46° · static
Foreground: the open door of a vehicle. Middle ground: an empty seat, and beside
it, a folded off-white parka that is not on anybody. Voss looks at it once and
then away. Hale does not look at it at all. Background: the crater, out of focus
behind them through the vehicle's window. The film never shows a body and never
states what happened.
**Cut motivation:** the vehicle door closes.
**Light:** the vehicle's dome lamp, warm and weak.

**18.06 — SOMETHING IS STILL TRANSMITTING** · 3s · 40° · static, tight
The one unresolved question, stated in a single image. Foreground: a handheld
instrument lying in the snow where it was dropped, half-covered, its small screen
still on. Middle ground: on that screen, a trace — **three pulses, a gap, three
pulses.** The same signal from Scene 2, still coming, from beneath a collapsed
excavation that everyone has left. Background: snow accumulating over the
instrument as we hold.
**Cut motivation:** the screen is covered by snow, and the film goes to black.
**Light:** the screen is the only light in frame; snow falling through it.
**Design note:** this is the *only* mystery the opening leaves open. It is not
accompanied by a shot of the creature's eye, a distant ship, or a second hook.
One question, held clean.

---

### SCENE 19 — FIFTEEN YEARS · 0:12

**19.01 — BLACK** · 4s · — · black frame
Full black. Wind, fading, until there is nothing. Four seconds is long. It is
supposed to be.
**Cut motivation:** the silence is complete.

**19.02 — TITLE** · 5s · — · black frame, title card
**THE DAY THE SKY BROKE**, centred, held, then faded. Nothing else on screen.
**Cut motivation:** the title clears.

**19.03 — FIFTEEN YEARS LATER** · 3s · — · black frame, card
A second card, smaller and lower: **FIFTEEN YEARS LATER.** It fades, and the
first sound of the present day — ordinary, domestic, a street outside — begins
*before* the image does.
**Cut motivation:** sound leads picture into Scene 20.

---

### SCENE 20 — A NORMAL MORNING · 0:23 · Set F

*Purpose: tonal reset, character established without exposition, and a handoff to
gameplay that never breaks the frame.*

**20.01 — LIGHT ON A WALL** · 4s · 50° · static, very slow push
Foreground: a slatted window blind, close, with warm morning light coming through
it. Middle ground: the light's bars falling across a wall, a shelf, and the edge
of a desk — dust moving slowly in the beams. Background: out of focus, the room.
The first warm light in the film, and the first shot in six minutes with no
tension in it at all.
**Cut motivation:** a sound from the bed side of the room.
**Light:** window daylight, warm, low-angle, keying everything. The desk lamp is
also on, weakly, redundant in the daylight.

**20.02 — THE DESK** · 4s · 46° · slow dolly left
Foreground: hand tools laid out in working order, a small device half
disassembled with its cover beside it, a coil of wire. Middle ground: the desk,
the lamp, a notebook with sketches. Background: the shelf above, holding a framed
photo of a man and a much younger boy outside a garage, a few books, and a spare
part. Nobody has said a word and we already know what this person does and who
raised him.
**Cut motivation:** the dolly reaches the bed.
**Light:** unchanged; the desk lamp gives the tools a second, harder shadow.

**20.03 — KAI** · 4s · 50° · static
Foreground: the bed's footboard. Middle ground: **Kai sits up** — an ordinary,
unhurried movement, one hand pushing off the mattress, a pause on the edge of the
bed, a look toward the window. He is in the same R15 body language as everyone
in the Arctic, in much plainer clothes. Background: the door, closed, and the
poster beside it. The camera does not push in on him and there is no music
sting.
**Cut motivation:** he stands.
**Light:** window key from camera-left, warm; bounce fill from the light wall
behind camera. No rim, no effects.

**20.04 — HE PICKS UP HIS JACKET** · 4s · 46° · slow pan following him
Foreground: the chair back. Middle ground: Kai crossing to the chair, taking the
jacket off it, and pulling it on — handling it the way people handle their own
things, without looking at it the whole time. On the way he touches the
half-disassembled device on the desk once, absently, and moves a tool a few
inches. Background: the window, the desk, the shelf. The room has been
established from three angles and it has four walls, a ceiling, a door and a
window in every one of them.
**Cut motivation:** he turns toward the door.
**Light:** unchanged.

**20.05 — THE HANDOFF BEGINS** · 4s · 55° · slow pull back to the gameplay camera
The cinematic camera moves, in one continuous motion, from its framing into the
exact position, distance, height and angle a normal gameplay camera occupies
behind the character. Foreground: nothing. Middle ground: Kai, seen from behind
at gameplay distance, standing near the door. Background: the room, all of it —
bed, window, desk, shelf, the whole set readable in the last cinematic frame.
The HUD fades in over the last second of the move: integrity bar, action bar,
objective field, all at low opacity rising to full.
**Cut motivation:** the camera arrives at the gameplay relationship.
**Light:** unchanged. **The lighting must not change at the handoff** — the
cinematic's bedroom light values and gameplay's must be the same values, or the
seam is visible.

**20.06 — CONTROL** · 3s · gameplay · no cut
The camera is already where it needs to be, and the character is already standing
at the bedroom's gameplay spawn point, inside the room, clear of every wall and
every piece of furniture. Control is enabled. The objective appears: **"Go
downstairs and find Uncle Daren."** There is no cut, no fade, no black frame and
no teleport. The player's first action happens in the same continuous shot the
film ended on.
**Requirement:** the camera transfers to the player's Humanoid only *after* the
character is confirmed positioned at `KaiBedroomSpawn`. See 6.4 — this ordering
is a real prerequisite, not a polish item.

---

## PART 4 — CONTINUITY LEDGER

The world is one continuous physical place. This table is the authority on what
is true at each point. **A shot may not contradict the ledger.** When a scene is
implemented, its ledger row is checked against the built state before the scene
is signed off.

### 4.1 Character state

| After | Lyra | Voss | Hale | Ensemble |
|---|---|---|---|---|
| 2.08 | at signal station, cold-lit, gloved | at plot table, marker in hand | entered, standing centre | lamps swaying; mug displaced |
| 3.06 | **right glove off**, in the pit | at the pit edge, one knee down | not present | one worker holding her lamp |
| 6.06 | at the shaft edge, closest of the three | two paces back, instrument raised | behind both, turning head | two soldiers at the arch |
| 8.02 | **gloved again**, at analysis station | at secondary console, 8 studs left | at the arch, off-frame | technician running a fixed route |
| 10.08 | at the ledge wall, leaning forward | one step back, checking instrument | not present (surface) | **soldier's rifle now in hands, not slung** |
| 14.06 | last to leave, looks back | has her sleeve | not present | soldiers forward at the wall |
| 15.02 | up the shaft, goes **right** to scaffold | up the shaft, goes **left** to consoles | at the arch, fixed | two soldiers face down the shaft |
| 17.04 | at the breaker panel, **glove off again** | evacuating with the column | at the arch, then surface | technicians off the breakers |
| 18.05 | **absent** — parka on the seat, no body shown | on the vehicle ramp, dressing on temple | radio handset, silent | loading |

### 4.2 World state

| Event | State created | Persists until |
|---|---|---|
| 2.08 deep impact | ceiling lamps swaying, mug displaced | end of Scene 2 |
| 3.03 excavation | metal plate exposed in the trench | permanent |
| 4.04 door opens | ancient door open, halves recessed in the walls | permanent |
| 6.05 | faint violet bleed from the floor shaft | overtaken by 15.01 emergency |
| 7.01–7.06 research build | scaffold, lamp trees, cable trunks, analysis station, arch barrier, survey grid on the myth wall | until 17.05 destroys them |
| 8.06 | faint standing cyan on the core rim | grows continuously to 13.05 |
| 12.04 | **core disc lifted and rotated open** | permanent — it is still open in 17.02 |
| 12.05 | generator indicators amber | → red at 17.03 |
| 13.07 | seal ring plates broken, shaft mouth widened | permanent |
| 15.01 | **emergency lighting on** (red practicals + neutral shadow + cool fill) | rest of the Arctic sequence |
| 15.08 | surface ice fractured with violet in it | until 17.06 collapse |
| 16.03 | claw scoring on the machine's chest plating | permanent, including into gameplay's Aegis design |
| 16.07 | generator housing crushed, coupling torn, arcing | → 17.05 detonation |
| 17.02 | **core fragment removed; core visibly dimmer** | permanent — this is the object Kai inherits |
| 17.05 | scaffold down, station crushed, near pillar shed, vault ribs dropped, bank burning, smoke in layers | every shot of Scene 18 |
| 17.06 | surface collapse crater, comms mast down, base half destroyed | every exterior shot of Scene 18 |
| 18.02 | daylight shafts through the collapsed ceiling | end of the Arctic sequence |

### 4.3 The four rhymes

Deliberate visual repetitions. Each is a matched framing, and the match must be
built, not approximated.

1. **5.08 ↔ 7.06** — the same walkway framing of the kneeling machine, before and
   after the research build. The machine has not moved; everything else has.
2. **6.02 ↔ 7.05** — the same three relief panels, first lit by a swinging
   handheld lamp and unreadable, then properly lit on a stand and legible.
3. **4.01 ↔ 9.04** — two descents, both built on the rhythm of passing lamps.
4. **2.06 ↔ 18.06** — the three-pulse signal, on a monitor in a warm working
   room, and on a dropped instrument in the snow with nobody left to read it.

---

## PART 5 — THE LIGHTING BIBLE

### 5.1 The four laws

1. **Every light has a placed, visible or inferable source.** Sky, window, lamp
   tree, work lamp, handheld lamp, monitor, muzzle flash, arc, fire, core, eye
   seam. Nothing is lit by an unexplained ambient lift.
2. **No character is a light source.** Zero PointLights, SpotLights or Neon
   material on any human rig part — body, head or clothing. The only sanctioned
   emissive on a human is a held instrument's small screen. (This is currently
   true in the codebase and must stay true.)
3. **The readability floor, checked per shot.** The floor plane is visible; every
   present character's silhouette separates from its background; light clothing
   retains fold and shadow; dark bodies separate from dark backgrounds by value.
   If a mood breaks the floor, the *key* comes down and the *fill* stays — the
   fill is never taken below the floor to make something feel darker.
4. **No white-out.** The blast flash in 17.05 is the brightest frame in the film
   and it lasts under three frames and is localized to the generator bank. At no
   point does any effect erase a face, a silhouette or the architecture.

### 5.2 Per-location plan

| Location | Key | Fill | Accent | Notes |
|---|---|---|---|---|
| Arctic exterior | flat overcast sky, ~20° elevation, cool | snow bounce from below (strong — this is what makes faces under hoods legible) | warm module windows, orange perimeter lamps, vehicle headlamps | atmosphere dense but the iceberg must stay a visible value |
| Command module | three ceiling lamps, warm, low | monitor glow, cold | cold window daylight raking from +Z | monitors must read bright *because the room is dim*, not because they are boosted |
| Ice tunnel | strung work lamps at 6-stud intervals, warm | cold ice-wall bounce | carried lamps (the only moving lights) | the alternating light/shadow rhythm is the set's whole idea |
| Chamber, pre-research | cold daylight through the two ice breaches, high +X | carried handheld lamps, in frame | none — the core is dark | every reveal in Scene 5 is lit from below by held lamps |
| Chamber, post-research | installed lamp trees, warm | monitor banks, cold | breach light, cold, from high right | roughly 2× the brightness of pre-research; the montage's payoff |
| Chamber, emergency | red practicals at pillars and arch | small cool fill | core cyan, shaft violet, arc white-blue, fire orange | **shadows stay neutral.** Red comes only from placed units, never from a red ambient |
| Prison cavern | cold daylight shaft onto the ledge — humans are always best-lit here | two low violet practicals in the basin, modest range, never reaching the ledge | eye seams, root-spread bleed | the Sovereign separates by being *darker* than its background, not by glowing |
| Kai's bedroom | warm morning window light, low angle | bounce off the light wall | desk lamp, weakly redundant | the only warm key in the film; must match gameplay's values exactly |

### 5.3 Emissive budget

| Object | Max emissive surface | Intensity ceiling |
|---|---|---|
| Aegis Zero | ~4% (core disc, optic band, shoulder/spine seams, joint interiors) | the core is the machine's brightest point; nothing else on it approaches it |
| Sovereign Below | ~6% (six eyes, plate seams, root bleed) | never bright enough to key the cavern; the basin practicals do that |
| Wardens | ~3% (one eye band, a few seams) | below the Sovereign at all times |
| Humans | one held instrument screen, palm-sized | must not light the holder's face more than a nearby practical does |

### 5.4 Per-shot lighting checklist

Every shot, before sign-off, answers: *Where is the key coming from, physically?*
*Is the floor visible?* *Does every silhouette separate?* *Does light clothing
still have shadow in its folds?* *Is any character emitting light?* *Does any
effect exceed three frames at peak brightness?* A shot that fails any of these is
relit, not shipped.

---

## PART 6 — IMPLEMENTATION ORDER

**Nothing below is built out of order, and no scene begins before the previous
scene has passed its gate.** This is the part of the plan that is easiest to
violate and most expensive to violate.

### 6.1 Phase 0 — the test bench (before any scene work)

A plain baseplate test place. Nothing from this cinematic enters a shot until it
has passed here, on the baseplate, watched in Studio.

**0.A — The human rig.** One character, one baseplate. Must: stand upright
without drift for 60 seconds; walk 40 studs and stop without foot slide; turn 180
degrees in place; gesture and return to idle; sit and stand. Zero floating, zero
sideways rotation, zero self-illumination, zero joint deformation. `Cast.lua`
already has the upright-validation warning — it must stay silent for the full
run. **Only when this passes do humans enter Scene 1.**

**0.B — Aegis Zero.** Alone on the baseplate at final design (Part 1.6). Must
perform, in isolation and in this order: the full startup sequence (internal
light, unlocks, fingers, shoulders, head, optic band); stand from kneeling; take
six steps with correct weight, knee compression and body settle; turn 90 degrees;
throw the 16.04 punch as a complete body sequence and recover balance. **Only
when this passes does Aegis enter Scene 5.** It appears in Scene 5 as a static
kneeling prop, which is a lower bar — but the awakening in Scene 13 is written
against the full list, so the full list is the gate.

**0.C — The Sovereign Below.** Alone on the baseplate at final design (Part 1.7).
The silhouette test first: filled solid black at 100 pixels, does it read as
alive? Then: dormant folded pose; the single-digit movement of 10.07; head
commits before body; unfold and take its own weight; four-limb irregular walk;
the compress-and-lunge of 16.02. **Only when this passes does the Sovereign enter
Scene 10.**

**0.D — Camera and light rigs.** The `Camera.applyShot` pacing curves and the
`NPLighting` presets validated on the bench against Part 5's readability floor,
with the existing Studio-only obstruction/inside/bounds reports clean.

### 6.2 Phase order

Each phase: build the set → place and animate the cast → lay in the camera →
light it → check it against the ledger → **watch it in Studio** → sign off. Then
the next phase.

| Phase | Scenes | Set built | Rigs required | Gate |
|---|---|---|---|---|
| 1 | 1 | A (exterior) | humans (0.A), vehicles | Seven shots play; nothing floats; base reads small; storm and drift agree on one wind axis |
| 2 | 2 | B (command module) | humans | The staggered reaction (hands → head → Voss → screen → Hale) reads without dialogue; room is fully enclosed from every camera position used |
| 3 | 3–4 | A excavation, C (tunnel/door) | humans, drill | The seam reveal reads at 3.04's raking light; door opens without clipping; tunnel lamp rhythm works |
| 4 | 5–6 | D (chamber, pre-research) | **Aegis (0.B)**, humans | The eight-shot partial reveal never shows the whole machine before 5.08; 5.08 passes the readability floor |
| 5 | 7–8 | D (post-research overlay) | humans | 7.06 matches 5.08's framing exactly; the lab is alive during dialogue; 8.04–8.06's reaction-before-effect order reads |
| 6 | 9–10 | E (prison) | **Sovereign (0.C)**, humans | 10.07's single-digit move lands with no light change; the creature separates from the background in every prison frame |
| 7 | 11–12 | D | humans, Aegis | The causal chain (power + phrase → core → chain pulse → shaft) is understandable to someone who has never read this document |
| 8 | 13–14 | D, E | Aegis, Sovereign | 13.09's first step reads as weight; 14.03's head-before-body contrast against Aegis's easing is visible |
| 9 | 15 | D, C, A | full cast | Every evacuating character has a visible destination; emergency lighting passes the readability floor |
| 10 | 16 | D | Aegis, Sovereign | **16.04's punch is legible as a full body sequence with no effect before the contact frame.** This is the single hardest gate in the film |
| 11 | 17–18 | D, A (damaged states) | full cast | The blast's source is identifiable; no frame exceeds the white-out rule; the ledger's damage persists across every aftermath shot |
| 12 | 19–20 | F (bedroom) | Kai | The room is closed from every camera position; the handoff has no cut, no fade, no lighting change, and no teleport visible to the player |

### 6.3 Mapping to the codebase

This plan is a rewrite of the *content* of the existing North Pole cinematic, not
a new system. It lands in the modules that already exist:

- `src/client/NorthPole/Env.lua` — Sets A–E (Part 2). The chamber's ice breaches,
  the perimeter walkway, the shaft rigging and the post-research overlay as a
  separate switchable state are the main additions.
- `src/client/NorthPole/Cast.lua` — Part 1's design sheets. The human rig is
  close to correct already; `buildAegisZero` and `biomech()` are the two known
  "still reads as primitive blocks" gaps and are Phase 0.B / 0.C's work.
- `src/client/NorthPole/Camera.lua` — unchanged in architecture; this plan needs
  the existing `pace` curves plus one genuinely new capability, a camera that
  travels between two arbitrary CFrames over a shot's duration for the crane and
  dolly moves (1.05, 3.07, 5.03, 9.03, 20.05).
- `src/client/NorthPole/Lighting.lua` — Part 5.2's table, one preset per row,
  plus a `chamberResearch` state that does not exist yet.
- `src/client/NorthPole/Sequences.lua` — the 130 shots of Part 3, replacing the
  current 38.
- `src/client/Opening.lua` — the handoff (20.05–20.06) only.
- `src/shared/Config.lua` — `Cinematic.TotalTargetSeconds` moves from 210 to 500.
- **Unchanged:** `CutsceneRunner.lua`, all server gameplay, Scenes 2/4/9's own
  cutscenes. This plan touches none of them.

### 6.4 Prerequisites that are real blockers

1. **The bedroom camera CFrame is not available to the client.** 20.05 requires
   the cinematic to move the camera to the gameplay camera position in Kai's
   bedroom, which means the client must know where the bedroom is. Today nothing
   replicates `KaiBedroomSpawn` (the last session deliberately cut a scripted
   bedroom pan for exactly this reason, and used a 0.4s blackout hold instead).
   Phase 12 cannot produce a cut-free handoff until that value is replicated.
   This is a small, contained change, and it is required.
2. **Studio time.** Nothing in this container can watch a single frame of this
   film. Every gate in 6.2 is a *watch it in Studio* gate. A plan this specific
   about motion, light and weight is worth exactly as much as the playtests
   behind it.
3. **Audio is out of scope and stays out.** `OpeningAudioConfig.lua` has the
   wiring points; every cue named in Part 3 (radio, wind, drill, impact, servo,
   arc, blast) maps to an existing blank field. No asset IDs are invented.

---

## PART 7 — DECISIONS MADE, AND WHAT THEY COST

Recorded so they can be argued with rather than rediscovered.

1. **"Warden" → "the Sovereign Below."** Taken to avoid re-introducing the exact
   naming collision this codebase already spent a session untangling. See 0.1.
2. **Runtime 8:19, up from the current 3:30 — and this is the decision most
   worth arguing about.** The brief asks for staggered reactions, partial
   reveals, legible body mechanics and an unhurried aftermath; those cost
   seconds, and 130 shots at this level of coverage land at 8:19. That is a long
   time to hold a player before they touch the controls. Hold-to-skip is the
   release valve, and the first user-facing shot is a 5-second black frame with
   a radio line — the cheapest possible place for an impatient player to bail
   out. **If it needs to come down, the compression path is fixed in advance, in
   this order:** cut Scene 7 from six shots to four (−6s); tighten Scene 11's
   argument to four shots (−9s); trim Scene 15 to six shots by folding 15.06 and
   15.07 together (−6s); shorten Scene 18 to four shots, keeping 18.02 and
   18.06 (−8s); and take one second off every shot longer than 4s in Scenes 1–4
   (−11s). That path reaches ~7:00 without touching a single reveal, the causal
   chain, the fight, or the handoff. **Nothing in Scenes 5, 10, 12, 13, 16 or 20
   may be compressed** — those are the reveals and the mechanics the entire plan
   exists to protect.
3. **The catastrophe is caused by Lyra, deliberately.** The brief asked for a
   specific physical source; `story.txt` asked for Lyra to seal it away again.
   Both are satisfied by the generator bank: established in 7.02, loaded in
   12.05, damaged in 16.07, and dumped by her hand in 17.04. The alternative —
   an accidental overload — is a weaker scene and leaves her with nothing to do.
4. **One mystery only: the signal is still transmitting.** The alien carrier and
   the deep-space shots that the current build ends on are cut. They are a second
   and third hook competing with the first, and the brief explicitly asked for
   one strong unresolved question. The carrier belongs to a later chapter.
5. **The core fragment is shown, not explained.** Lyra's wrist device is visible
   from Scene 1 and never discussed. In 17.02 it receives the fragment. Chapter
   One's existing dialogue already depends on that object; this makes it a thing
   the audience has seen rather than a thing they are told about.
6. **No body, no death stated.** 18.05 is a parka on an empty seat.
   `Dialogues.lua`'s Scene 5/6 lines deliberately preserve "I don't know if she
   died," and this opening must not close that door.
7. **The Scene 16 fight is 26 seconds and contains one punch.** The brief asked
   for short and highly readable over long and busy. One fully-animated body
   sequence that the audience can follow is worth more than six that they cannot,
   and 16.04 is written to be watchable in a single unbroken wide shot — which is
   also the most demanding thing in this entire plan to animate.

