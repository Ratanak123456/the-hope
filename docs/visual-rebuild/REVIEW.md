# Chapter 1 visual rebuild — live review record

Storyline and dialogue text are preserved. This is an ordered visual rebuild.

**Superseded 2026-09-16:** Pass 1's `HumanShell` (faceted-mesh garment/face
shells) and Pass 2's `HumanMotion` (layered procedural idle/gaze/gesture) -
both referenced below - were retired outright during a bug-fix/restoration
pass, not carried forward. The scientist deformation bug reported after this
rebuild, and the "no longer looks like Roblox" complaint, both trace to this
pass's own construction: `HumanShell.rebuild` mutated a shoulder joint's C0
after the rig had already been posed once without repositioning the geometry
built from it, and `Cast.stepAnimate`/`HumanMotion.apply` wrote overlapping
poses to the same joints for Lyra specifically with no single owner. See
`AGENT.md`'s "bug-fix/restoration pass" session entry for the full account
and what replaced it (a plain R15-block rig built directly in `Cast.lua`,
no separate shell layer, one animation function, hard rotation clamps). The
rest of this file (Pass 3 cast application, Pass 5 subtitles) still reflects
real, current work and was not touched.

## Baseline

The `baseline-20260915/` directory preserves the exact five source systems at
this task's start. `before/` contains an earlier snapshot and is retained.
The starting source already included incomplete human/alien/explosion changes;
those edits are not credited as work performed in this pass.

## Pass 1 — Lyra construction

**CURRENT PROBLEM:** Rectangular head carrier with added jaw geometry; broad
primitive shoulder caps; long wedge coat skirts; box limb segments; glove
geometry with an extended scanner-like finger shape.

**EXACT REPLACEMENT:** Closed faceted shells around the Motor6D skeleton.
A 0.90-stud head with planar cheeks and tapered chin, a visible neck, a
2.41-stud shoulder silhouette narrowing to a 1.42-stud waist, short thick
jacket, tapered sleeves, overlapping hidden elbow/hip/knee transitions,
mitten palm and separate thumb, thigh/calf taper and reinforced boots.
Only Lyra uses the new construction during this pass.

**EXACT MOTION/BEHAVIOR:** The shell follows the existing separate Motor6D
segments. No new animation is claimed in Pass 1. The comparison place offers
front/profile/three-quarter rotation and an optional existing-motion preview.

**PASS/FAIL CHECK:** First actual Studio run saved as
`captures/pass1-first-playtest.png`. Replacement silhouette is visibly distinct,
but this attempt failed review: shoulders too broad, patchy Fabric mapping on
triangle surfaces, and floating forehead goggles. Those were corrected in the
source. Revised silhouette review is pending. The screenshot labels in the
first attempt were reversed by the front camera's right vector; corrected in
the comparison script. The player avatar also intruded; removed from the review.

## Review place

Build with:

```
rojo build tools/visual-review/review.project.json -o /tmp/HumanComparison.rbxlx
```

Open the file in Studio and press Play. `1`: front; `2`: profile; `3`: three-quarter;
`P`: toggle existing-motion preview. The comparison is excluded from the game.

## Pass 2 — Lyra motion

**CURRENT PROBLEM:** Base idles were symmetric; dialogue gestures stopped or
repeated in place; impact reactions did not show weight transfer.

**EXACT REPLACEMENT:** `HumanMotion.lua` layers a left-foot-forward stance,
three-second waist/shoulder breathing, 4.6-second micro-actions, head-first
gaze with delayed torso follow, timed speaking emphasis, articulated stepping
(hip, knee, ankle and opposite arm), and a braced crouch/recoil.

**EXACT MOTION/BEHAVIOR:** The layer is evaluated after activity selection and
before Motor6D evaluation. Root translation is only a small stance offset;
visible travel is expressed by the limb joints. The isolated review place
includes a timed idle, speaking, brace and walk cycle.

**PASS/FAIL CHECK:** Luau static check passes. Studio timing review is wired,
but the separate motion capture is pending after the construction capture.

## Pass 3 — important human cast

`HumanShell.rebuild` is now applied to every cinematic human, scientist,
worker and soldier through the common `Cast.buildHuman` path. The original
Motor6D skeleton remains internal; visible carrier parts are hidden beneath
the new jacket, trousers, gloves, boots and matte face shells.

## Pass 5 — subtitle shape

**CURRENT PROBLEM:** The original subtitle was a wide dark rounded rectangle
covering actors (captured at `captures/subtitle-before.png`).

**EXACT REPLACEMENT:** `Opening.lua` now uses a transparent lower-center
CanvasGroup with no UICorner or panel fill: cyan 16px speaker name above
24px off-white medium dialogue, 62% maximum width, and a restrained text
stroke. The existing 0.18-second fade is retained; no panel motion is used.

**PASS/FAIL CHECK:** Source check passes and the old panel is removed from the
construction. A fresh full-opening capture is still required after the main
game reconnects.

## Remaining ordered passes

2. Human idle, gaze, gesture, recoil, stepping, and foot-pivot turns.
3. Apply verified human construction to important cast members.
4. Conversation blocking, speaker/listener/background performances, activation.
5. Subtitle panel removal and compact text group.
6–7. Creature anatomy followed by articulation and reveal choreography.
8–9. Mecha armor/mechanics followed by startup and contact-driven animation.
10. Local blast, force reactions, debris and aftermath.
11. Skin/uniform exposure checks.
12. Camera framing that shows gestures, steps, contact and environment.

No full-opening visual acceptance is claimed by static checks or a successful
Rojo build. Each system needs its own before/after evidence.
