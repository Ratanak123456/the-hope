# Phase 0.A repair review — 2026-09-21

**Gate remains OPEN. Phase 0.B is not authorized.**

The repaired disk artifact was rebuilt with Rojo. All eight embedded scripts
were compared with the current source files and matched exactly. The adjacent
SHA-256 manifest identifies this revision. Luau compilation passed.

## Changes

Turn prediction now uses the correct yaw-rate sign and heading extracted from
the facing vector, including headings beyond 90 degrees. Turns shorten steps
and predict support geometry and foot twist. Braking updates airborne landing
targets using stopping travel and projected speed. Supporting feet retain their
world-space targets until an explicit release. There is no last-frame landing
snap into a clamped support radius.

The pelvis has a nominal 0.12-stud correction budget, an early-release budget
of 0.14, and a total normal body-height bound of 0.18. The original 0.22-stud
pelvisSupported failure threshold remains unchanged. Touchdown preparation
anticipates the small weight transfer; the correction is rate-limited to
0.60 studs/second. Gait contribution fades through stopping instead of
vanishing in one frame. The explanation gesture now uses a small outward
shoulder preparation followed by elbow flexion, a hold, and a slower return.

Added body-height, actual vertical-rate, and unreachable-target checks.
The existing double-support-base check remains active. The tests include
intentional invalid body poses so the new checks must detect failures rather
than merely pass this sequence.

## Numerical evidence

The complete shared Studio timeline passes all checks at 30, 60, and 120 fps.
Actual maximum body drop: 0.1381 / 0.1381 / 0.1547 studs respectively.
Maximum normal body vertical speed: 0.7322 studs/second across those runs.
Straight stops from 1.0–3.4 studs/second, cruise-only turns through 120 degrees,
combined turning/stopping, both turn directions from multiple initial headings,
40 repeated gestures, and neutral return pass. Full output is in
`offline-results-20260921.txt`.

## Visual verdict: pending, not a pass

An earlier repair revision was opened in actual Studio and rendered, but the
final revision has NOT completed the requested runtime visual review. Desktop
input was stopped when the user said they were using the desktop and requested
continued code checks. Earlier screenshots must not be treated as evidence
for the final artifact.

Consequently, the final revision's moving-turn crouch/collapse, deceleration
height, naturalness of corrective footfalls, and conversational quality of the
gesture remain unapproved. No claim that the character now looks natural is
supported yet. Resume with isolated stops, cruise turns, then the full take at
normal speed; replay frame by frame and inspect the gesture from all three
views. Reload the rebuilt disk artifact before doing so.

No Cast.lua, North Pole cinematic, Aegis Zero, Sovereign, or story-scene file
was edited. No unrelated Studio-place changes were saved. Global Editor
Quality Level and Auto FRM Level remain at 21 under the user's explicit
instruction; original values are unknown. See STUDIO-SETTINGS.md.
