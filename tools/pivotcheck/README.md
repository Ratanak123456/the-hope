# tools/pivotcheck — is `Model:PivotTo()` actually unstable here?

`src/client/NorthPole/Kit.lua`'s `rigid()` exists because an earlier session
concluded that calling `PivotTo` every frame accumulates error, on the
reasoning that PivotTo re-derives each part offset from the previous frame's
world CFrame and so squares any scale error in the stored basis on every call.
`Kit.rigid` freezes each offset once and re-applies it from a freshly built
target instead.

That claim was never measured against the real engine, and it is load-bearing:
every vehicle, the drill and the ancient door move through `Kit.rigid`.

## Result (Roblox Studio 0.739.0, 2026-09-22)

`PivotDrift.luau` builds a 25-part model shaped like the real truck body — an
off-axis hull plus assorted rotated pieces — and drives it for 4000 frames
along a path with continuous translation, yaw, pitch and roll. Both methods
move the same model the same way; afterwards it measures how far each part has
moved from its original offset in the model's own frame, and how far the
model's basis has drifted from orthonormal.

```
[PivotDrift] 4000 frames, 25 parts
  PivotTo   : max offset drift 0.000009344 studs, basis scale 1.000000039736
  Kit.rigid : max offset drift 0.000009344 studs, basis scale 1.000000039736
```

**Identical, and both negligible.** The residual 9.3e-6 studs is float32
quantisation of the part CFrames — the same for both methods — not
accumulation, and the basis stays orthonormal to eight decimal places. The
squaring mechanism is not reproduced by the engine.

## What was done about it

Nothing, deliberately. `Kit.rigid` is not wrong, it is not slower in any way
that matters here, and every vehicle shot in the cinematic is currently framed
and verified against it; swapping the transform architecture during a visual
pass would risk working shots to fix a problem that does not exist. The point
of this measurement is that the comment in `Kit.lua` should no longer be read
as "PivotTo is broken" — it is "PivotTo was suspected, measured, and cleared;
`rigid` is now just the explicit way this project moves frozen assemblies."

New code is free to use `Model:GetPivot()` / `Model:PivotTo()`.

## Running it

Paste `PivotDrift.luau` into the Studio command bar, or drop it into
`src/server/` as a `.server.lua` for one Play run and delete it afterwards
(that is how the numbers above were taken). It destroys its own models and
leaves nothing behind.
