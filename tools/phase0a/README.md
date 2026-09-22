# Phase 0.A — the human rig test bench

The first gate in `docs/opening/VISUAL_DIRECTION.md`'s build order. **No
cinematic scene may use a human until this passes.** Nothing here touches the
Arctic environment, Aegis Zero, the Sovereign, Kai's bedroom, the cinematic
lighting, or any scene module.

## Current gate: OPEN — visual acceptance pending

The 2026-09-21 repair changes turn prediction, support release, braking targets,
pelvis transfer, and the explanation gesture. The final repaired sources still
need the complete Studio visual review. Desktop automation was paused at the
user's request while they were using the desktop. Numerical passes do not
approve Phase 0.A or authorize Phase 0.B.

Studio Editor Quality Level and Auto FRM Level remain at 21 by explicit user
instruction. Their original values are unknown. See
[the settings record](../../docs/visual-rebuild/phase0a/STUDIO-SETTINGS.md).

## What is being tested

One canonical human prototype, alone, on a bare baseplate, with a neutral
background and one neutral key light. No props, no fog, no Bloom, no
ColorCorrection, no particles, no dialogue UI and no cinematic camera moves —
nothing that could flatter or conceal a bad pose.

The foundation is six modules in `src/shared/Human/`:

| module | role |
|---|---|
| `Skeleton.lua` | R15 proportions, joint table, forward kinematics, two-bone leg IK |
| `Pose.lua` | the additive layer solver and joint-ownership rules |
| `Locomotion.lua` | gait, world-locked foot planting, pelvis height |
| `Actor.lua` | layers, command timeline, per-frame solve order |
| `Build.lua` | the visible rig (the only file that touches Instances) |
| `Validate.lua` | the numeric checks, run every frame |

`src/client/NorthPole/Cast.lua` is **untouched**. The cinematic still runs on
its existing rig; migrating it onto this foundation is later work, gated on
this phase passing its visual review.

## Running the Studio test

Serve the isolated project on its own port so the game's own Rojo session can
stay connected in a separate Studio window:

```
rojo serve phase0a.project.json --port 34873
```

Then in a **separate, empty** Studio place, connect the Rojo plugin to port
34873 and press Play. That place contains only `ReplicatedStorage.Human` and
one `StarterPlayerScripts` script — no city, no menu, no cinematic, by
construction.

Build the disk artifact before review: `rojo build phase0a.project.json -o phase0a.rbxlx`.

`Timeline.lua` supplies the same full take to Studio and the offline harness.
Additional controls: `G` isolated gesture, `D` straight stops at three speeds,
`T` turns confined to cruise speed, `N` pause and advance one 1/60-second frame.

Controls: `1` three-quarter view · `2` front · `3` side · `4` silhouette
toggle · `L` lock the camera to the world instead of following · `Space`
pause on the current frame · `R` restart the timeline.

## The performance it plays

One continuous take, in this order, with the current segment named on screen:

1. stand and hold an idle (5s)
2. look small-left, small-right, then large-left (the torso only assists on
   the large one)
3. one conversational gesture, three times, to expose per-repeat distortion
4. a 90° turn — head, then torso, then a foot, then the root, then the second
   foot settles
5. walk 20 studs and stop
6. walk again, turn 60° while moving, walk a short leg, stop a second time
7. one backward step
8. one flinch
9. a long final idle, for drift

## Reading the on-screen numbers

The HUD reports every check every frame, with the worst value seen so far.
These measure what the eye cannot: a four-thousandth-of-a-stud foot slide, or
a pose offset that drifts a thousandth of a radian per cycle.

| check | passes when |
|---|---|
| `rootUpright` | the world root has exactly zero pitch and roll |
| `torsoUpright` | the torso's up vector stays above the standing threshold |
| `feetGrounded` | a planted sole is on the floor plane; a swinging one is above it |
| `noFootSlide` | a planted foot's world target does not move, at all, while planted |
| `kneeDirection` | a bent knee's pivot is forward of the hip-to-ankle line |
| `elbowDirection` | a bent elbow's pivot is behind the shoulder-to-wrist line |
| `armClearsTorso` | no hand is inside the torso volume |
| `headOnNeck` | the head's neck pivot stays coincident with the torso's |
| `legReach` | no leg is asked to stretch past its own length |
| `noResidualPose` | no action layer is still contributing once the action is over |
| `noAccumulation` | matched samples are identical |

Plus a rig scan: zero `Light` instances and zero Neon parts anywhere on the
character.

## Offline rendering

`offline/render.py` draws the rig from the same solved transforms, as a
flat-shaded z-buffer render with a one-stud ground grid, and writes the views
to `docs/visual-rebuild/phase0a/`:

```
tools/phase0a/offline/run.sh                 # numeric checks
python3 tools/phase0a/offline/build.py tools/phase0a/offline/dump.luau
tools/.bin/luau tools/phase0a/offline/bundle.generated.luau > frames.json
python3 tools/phase0a/offline/render.py frames.json docs/visual-rebuild/phase0a
```

It is **not** a Studio screenshot - no Roblox materials, no engine lighting,
no real shadows. It shows geometry, proportion, silhouette and pose, which is
what a rig review turns on, and it is how the four defects in the first visual
pass were found (see below). Capture points are keyed to command transitions,
not wall-clock times, because commands finish when their own state machine
says so.

## What the first visual pass found

The maths passed every check and the character still looked wrong. In order:

1. **Proportions were realistic-human, not Roblox.** Head at 15% of standing
   height and 0.44 of torso width rendered as a low-poly realistic human -
   the brief's explicit failure case. Now 19.3% and 0.63, with the torso
   shortened and the legs lengthened on a second pass.
2. **Arms were inside the torso footprint** (centre 0.85 vs torso half-width
   0.9) so they never separated in silhouette. Arms now sit flush outside.
3. **The standing knee bent 23.6 degrees.** A 0.05-stud "crouch" near full
   extension is a huge angle; the stand pose is now specified as a 5-degree
   bend and the height derived from it.
4. **The step model did not close.** The swing lasted a whole stride of body
   travel, so every foot landed 0.3 strides *behind* the hip and the walk
   rendered as a collapsed splay. Stance and swing are now a consistent
   budget (TRAIL 0.30 / AHEAD 0.70 / SWING 0.40 of stride).

Also added: a short first step out of standstill, and `Loco.squareUp`, which
recovers the neutral stance one foot at a time while idle - without it the
final idle never matched the first, because a walk, a back step and a flinch
each leave a foot where it landed.

## Offline verification

The rig maths also runs headlessly, outside Roblox, against a CFrame/Vector3
shim — executing the **real module source**, not a port of it:

```
tools/phase0a/offline/run.sh
```

It reports the derived proportions, IK placement error across a grid of
targets, bend directions, the full demo timeline under the same validator,
a 40-repeat distortion test, an exact-neutral-return test, and a
distance-versus-time step-cycle test. `bundle.generated.luau` is generated
output; edit `run.luau` and `shim.luau` instead.

**This does not replace the visual pass.** It proves the maths is right. Only
a person watching Studio can say whether the result looks like a Roblox
person, which is the actual Phase 0.A acceptance criterion.

## What to judge by eye

Pause (`Space`) at any ordinary frame and ask whether the character still
looks like a Roblox person standing on the floor. Specifically:

- Does the neutral stance read as R15 — stable head, upper and lower torso,
  upper and lower arms, hands, upper and lower legs, feet — rather than
  disconnected rods or a low-poly humanoid from another game?
- In silhouette (`4`), is the body construction still readable?
- Does the idle stay restrained, with the feet genuinely planted?
- On a small look, does only the neck move?
- Does the gesture bend from the right pivots, and does the arm return to the
  same rest it left?
- Does the turn read as head → torso → foot → root → foot, not as a chess
  piece rotating?
- During the walk, is the supporting foot fixed against the ground?
- At the stop, does the last step complete and plant before the idle resumes?
- After everything, is the final idle structurally identical to the first?

If any of those fail visually, Phase 0.A fails regardless of the numbers, and
the human rig does not enter a cinematic scene.

## Repair mechanics and limits

- Nominal gait-height budget: 0.12 studs at scale 1. Early-release budget:
  0.14. Total normal body-height travel is limited to 0.18 studs, including
  bob and ambient pose. The existing `pelvisSupported` ceiling remains 0.22.
- Straight strides retain a normal cadence; turns shorten them according to
  yaw rate. Both translation and correctly signed yaw enter turn prediction.
  Projected foot twist beyond 40 degrees also requests a deliberate release.
- Braking predicts stopping travel and landing speed. Airborne targets adjust
  at a bounded rate; planted targets remain unchanged until a step starts.
- Small touchdown preparation and a 0.60 studs/second correction-rate bound
  replace sudden weight-transfer dips. Raw IK demand is still reported.
- `bodyDrop` and `bodyVerticalRate` measure the final torso position, independent
  of the correction limiter. The latter fails above 0.85 studs/second during
  ordinary motion. `targetReach` catches unreachable ankles that an IK chain
  can otherwise conceal through an ankle translation.
- The support-base test is a double-support geometric proxy, not a dynamics
  simulation or a proof of balance during single support.
- Gesture: small shoulder preparation, delayed elbow-led rise, restrained
  outward hand path, hold, and slower return. Its timing still needs visual
  acceptance in Studio from front, side, and three-quarter views.

Resume review in this order: `D`, `T`, then `R` for the full take uninterrupted.
Replay with `Space` and `N` to examine transfers and stopping frame by frame.
Use `G` and the three camera views for the gesture peak. Do not approve the
phase until moving turns, deceleration, corrective footfalls, and the gesture
all read naturally, followed by the complete regression take.
