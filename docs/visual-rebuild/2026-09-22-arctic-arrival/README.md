# Scene 1 — the Arctic convoy arrival

Frames captured in **Roblox Studio Play mode** (0.739.0) from a Rojo live-sync
of the working tree, 2026-09-22, after the convoy-arrival pass. Baseline is
HEAD `e3898783a72c0886f3a8de8c8f635a5746371118`.

| File | What it shows |
|---|---|
| `01-arrival-approach.png` | The single crane, mid-move: both trucks on the route with clear air between them, the marker line running to the gate, the base lit beyond, ice relief in the near corners. Previously this stretch was four separate shots. |
| `02-arrival-gate.png` | The lead truck at the gate. The gate is now declared foreground, so the camera shoots past it instead of correcting away from it. |
| `03-arrival-parked.png` | The held final composition: two convoy trucks parked nose-to-tail with visible separation, the two service vehicles clear of the lane, the apron and the research site. |

## Studio diagnostics for this pass

```
01_BlackRadio     188 frames, 0 corrections / blocks / failures
02_ArcticArrival  631 frames, 0 corrections / blocks / failures
06_CommandMaster  170 frames, 0 corrections / blocks / failures
0 [OpeningCamera] warnings   0 [ActorValidation] warnings
```

Read with `ValidateEveryFrame` set on `workspace.NorthPoleCinematic`, which
makes `Camera.applyShot` print its report on every frame rather than only a
shot's first. That attribute is a diagnostic, not shipped code — it is what
found the defect below, which a first-frame-only report could not see.

## The defect this found

`02_ArcticArrival` reported clean on its first frame and then, 9.4s into a 14s
take, **collapsed**: the `GateSign` crossed the sightline for exactly 2 frames
as the lead truck passed under the gate, `Camera.applyShot` found no clear
angle, abandoned the framing, and then held a 54-degree orbit for the remaining
194 frames. One deliberate crane became two shots, from two frames of an object
the shot exists to look past.

Neither offline harness could see it: `castcheck`'s Roblox shim answered the
obstruction ray with a vertical ground probe, so it reported every
downward-looking exterior shot as blocked and this one as no worse than the
rest. That shim now does a real segment sweep for oblique rays (see
`tools/castcheck/roblox.luau`), which is what made the offline and Studio
answers agree.
