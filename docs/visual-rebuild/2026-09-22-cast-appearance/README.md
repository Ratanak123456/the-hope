# The cast, redesigned — appearance pass

Every human in the North Pole opening, rebuilt as an indexed appearance
**profile** rather than one `buildHuman` body recoloured twenty-four times.
Baseline is HEAD `f6c58ae43c6bd2e160dbb9947c6ef12bb4da07c3`.

The rig did not change. Motor6D hierarchy, joint directions, joint limits,
grounding, `Cast.place`, `Cast.walk`, `Cast.stepAnimate`, the pose system, the
look-at system, the upright validator, foot correction and PerformanceDirector
ownership are all untouched. What changed is what the blocks look like.

## Frames

These are `tools/scenecheck` renders — real module geometry, real poses, no
Roblox materials or lighting. Read them for silhouette, proportion and
readability, never for how anything will be lit.

| File | What it shows |
|---|---|
| `leads-front.png` / `leads-threequarter.png` / `leads-side.png` | Lyra, Voss and Hale at conversation distance. |
| `leads-silhouette.png` / `leads-threequarter-silhouette.png` | **The acceptance test.** Every colour thrown away. Hale is the widest by a clear margin with the smallest head volume; Voss is the narrowest with a peaked crown; Lyra has the widest head outline and an asymmetric fringe. |
| `group-leads.png` + silhouette | Leads plus scientists 1-3. |
| `group-scientists.png` + silhouette | Scientists 4-8. |
| `group-crew.png` + silhouette | Three security silhouettes and three of the excavation crew. |
| `command-room-master.png` | The three leads on their real marks, in the real set, at the real master framing. |
| `command-room-lyra.png` | Lyra in close coverage. |

## What the three leads are built from

|  | Hair | Face | Build | Head coverage | In hand / on body |
|---|---|---|---|---|---|
| **Lyra** | LayeredBob, dark brown, asymmetric fringe, side layers to the jaw | Soft | Average | single temple AR lens | scanner, hip pouch, orange shoulder strap |
| **Voss** | SidePart, black, one heavy sweep, tight temples | Sharp | Light | two thin rectangular lenses | scarf, tablet |
| **Hale** | CrewCut, grey, low sides, raised front | Mature + jaw shadow | Broad | none | shoulder yoke, rank marker, heavy belt, **slung** rifle |

They disagree on hair volume, shoulder width, head coverage and held
silhouette, which is what survives being rendered as flat grey. Lyra and Voss
no longer share eyewear — they used to wear the identical pair of cyan
rectangles, which made the two scientists in the room read as a matched set.

## Studio

| File | What it shows |
|---|---|
| `studio-command-room.png` | The command room in Play mode, real lighting: Hale, Voss and a technician in one frame. Nobody glows, and the three read as three people. |
| `studio-hale-before-fix.png` | **A defect only real lighting showed.** Hale's rust yoke edge crossed his rust coat placket and the two together read as a heraldic red cross on his chest. Invisible in a flat offline render. The yoke edge is now defined by value (a darker shade of his own coat) instead of by hue; `studio-command-room.png` is after. |
| `studio-lineup-eye-level.png` | The lineup standing in Studio at eye level — varied coats, skin tones, builds and hair silhouettes under Studio's default light. |

## Status

Offline: `./tools/check.sh` clean, `./tools/castcheck/run.sh` 49,699 checks /
0 failures, `./tools/phase0a/offline/run.sh` all pass, `rojo build` produces a
place.

Studio: the cast was watched in the running command room and the one defect it
revealed was fixed and re-confirmed in a second Play run. What was NOT done is
a systematic front/three-quarter/side/silhouette photo set taken inside Studio
— the edit-mode camera cannot be driven from a script (it overrides its own
CFrame every frame) and the orbit had to be done by synthetic mouse drags. The
silhouette evidence in this folder is therefore the offline renderer's, and the
Studio evidence is the cinematic's own camera.
