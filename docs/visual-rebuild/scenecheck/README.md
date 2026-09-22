# Composition review — 2026-09-22

Rendered by `./tools/scenecheck/run.sh` from the real modules: `MenuScene`
builds the welcome screen's hangar, `Env`/`Cast`/`Sequences` build the opening
and `Camera.applyShot` puts the lens where each shot puts it.

**These are not Studio screenshots.** There is no Roblox material, light,
shadow, fog or post-processing in them — the shading is one fixed key plus
ambient. Read them for framing, scale, blocking, depth and what crops which
edge. Do not read them for brightness, glow or colour. `tools/scenecheck/README.md`
has the full list of what they can and cannot answer.

`menu-framing.txt` and `opening-framing.txt` give the same information as
numbers: each element's span as a percentage of the half-frame at its own
distance, where -100% is the left edge and +100% the right. That is the part
that catches an element which is not in shot at all.

| frame | what to look at |
|---|---|
| `menu.png` | The welcome screen. The foreground layer (gantry left, case bottom-left, crates right) is the fix: all of it used to be outside the frustum. The mecha is the instant block placeholder — the real `AegisRig` armour replaces it a frame later in game and cannot be built here. |
| `02_ArcticEstablishing-at-*.png` | Arrival. Foreground ridges, the marked route as a leading line, the convoy, the lit site, background ice. |
| `03_ConvoyTracking.png` | The truck alongside. Value separation between tyre, panel and hull; the wheel spokes; marker poles as passing foreground rather than a wipe. |
| `03b_WheelContact.png` | The wheel insert: rim, five spokes, hub and the contact patch on snow. |
| `04_GateArrival.png` / `05_WorkingBaseReveal.png` | Destination, then the site as a place. |
| `06_CommandMaster.png` | The lab master. Lyra at the island foreground-left, Hale standing back, Voss across the island — all three faces readable. This shot used to be taken from behind all three. |
| `06b_VossSignal.png` / `06e_LyraCalling.png` | Medium coverage at eye level. |
| `06c_HaleSpacecraft.png` | Over-the-shoulder: Hale is the subject, the near shoulder crops the right edge. This shot used to be a 1.5-stud close-up of a face, because the over-the-shoulder branch was never reached and the fallback framing put the lens inside Lyra. |
| `07b_IceFragments.png` / `10_AegisFoot.png` / `29d_EvacuationVehicles.png` | Three shots that were being silently relocated by the camera's unstick fallback. |
| `16_PrisonDescent.png` | The new observation ledge. These marks previously had no floor under them at all. |
| `18_PrisonAndFrozenArmy.png` | The cavern wide. |
