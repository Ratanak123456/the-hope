# The cast as Roblox avatars

Visual pass on every human in the North Pole opening, taking them from small
articulated mannequins to Roblox-avatar masses. Baseline HEAD `4c31411`. The
rig underneath did not change: Motor6D names and hierarchy, joint HEIGHTS and
limb LENGTHS (sole drop still 2.81 at scale 1), joint limits, `Cast.place`,
`Cast.walk`, `Cast.stepAnimate`, grounding, the look-at and upright checks.

## Offline lineup (`./tools/scenecheck/run.sh lineup`)

Geometry and pose only, with no Roblox lighting.

| File | What it shows |
|---|---|
| `group-benchmark.png` | Hale, Voss and Lyra next to a plain six-block classic-avatar dummy (grey, right). Head-to-torso ratio now matches it (1.3/2.2 vs 1.44/2.4). |
| `leads-front/threequarter/side.png` | The three leads at conversation distance. |
| `leads-silhouette.png` | **The acceptance test.** Colour thrown away: Hale has the flat square crown, headset bump and the widest shoulders; Voss is tall and narrow with a slanted sweep; Lyra has the bell-shaped bob. |
| `group-scientists.png` | Lab-coat researchers, goggles pushed up, a technician in goggles, an analyst: four outfit outlines rather than one coat recoloured. |
| `group-crew.png` | Workers (hard hat/hood, hi-vis vest, packs, tools) and security (helmets, goggles, armour collar, rifles). |

## Studio (Play mode, real lighting)

| File | What it shows |
|---|---|
| `studio-06a-before-ots-fix.png` | **A defect only Studio showed.** The over-the-shoulder reverse was tuned for the old 0.8 head; with the 1.3 head and bob, Lyra's hair covered half the frame. |
| `studio-06a-after-ots-fix.png`, `studio-06f-after-ots-fix.png`, `studio-07f2-after-ots-fix.png` | After: Hale clear, Lyra's hair cropped at the frame edge. |
| `studio-06-command-master.png` | The command room master. |
| `studio-06b-voss-command-room.png` | Hale, Voss and a technician in one medium. |
| `studio-06h-lyra-closeup.png` | Lyra close: flat graphic face, AR lens, parka, orange strap and scanner. |
| `studio-07e2-lyra-voss-hale.png` | All three leads outdoors. |
