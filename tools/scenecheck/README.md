# tools/scenecheck — looking at the shots without Studio

`tools/castcheck` proves the opening's geometry is *correct*. This proves
nothing at all; it just lets you **see** it. Both are needed: the 2026-09-21
Phase 0.A review is on record as passing every numeric check while the
character still looked wrong, and this session found the reverse — a command
room whose camera, lighting and blocking all type-checked while the entire cast
stood on the ceiling and the master shot opened on three backs.

```sh
./tools/scenecheck/run.sh               # welcome screen + the opening's shots
./tools/scenecheck/run.sh menu          # just the welcome screen
./tools/scenecheck/run.sh opening 06    # just shots whose name contains "06"
```

Output lands in `docs/visual-rebuild/scenecheck/`: one PNG per capture, plus
`<set>-framing.txt`.

## What it is

`build.py` bundles the **real** modules (`MenuScene`, or
`Env`/`Cast`/`Sequences`/`Camera`) against `tools/castcheck`'s Roblox shim, so
the set is built by the code that ships and the lens is put where the shot puts
it. `dump.luau` / `menu.luau` run that and emit every visible part plus the
camera. `render.py` rasterises it, reusing `tools/phase0a/offline/render.py`'s
z-buffer rather than a second copy of it.

`frame_report.py` prints where each part lands as a percentage of the
half-frame at its own distance — −100% is the left edge, +100% the right. That
is the part that actually catches things:

- the welcome screen's whole foreground layer sat **outside the frustum** (the
  gantry column 8 studs past a 5-stud half-frame), so the "frame" the header
  comment describes was never in shot;
- its approach-lane chevrons ran from 2.6 to 15 studs, and the bay floor does
  not enter frame until ~18 — none of them was ever seen;
- a route marker flag sat 3.3 studs from the lens in the convoy tracking shot
  and covered a quarter of the frame.

None of those is visible in the source, and all three are one line of the
report.

## What it is NOT

**No Roblox materials, lights, shadows, fog, atmosphere or post-processing.**
Shading is one fixed key plus ambient; transparency blends toward the
background rather than compositing what is behind. So:

- **Trust it for** framing, scale, blocking, silhouette, depth layering,
  occlusion, what crops which edge, and whether a thing is in shot at all.
- **Do not trust it for** anything about brightness, contrast, glow, colour
  temperature or readability-under-light. A scene that leans on transparent
  haze planes (the menu hangar does) renders flatter here than it will.

Round parts are drawn as a few rotated slabs, so a snow drift reads chunkier
than it is. Async work is skipped (`task.spawn` is a no-op), so the welcome
screen shows its instant placeholder mecha, not the real `AegisRig` armour that
replaces it a frame later.

A real Studio playtest is still the only thing that settles lighting, and it is
still the load-bearing next step for everything in `AGENT.md`.
