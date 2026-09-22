# Welcome page → Arctic arrival → first command-room conversation

Before/after frames captured in **Roblox Studio Play mode** (0.739.0), from a
Rojo live-sync of the working tree, on 2026-09-22. Baseline is HEAD
`fb54413b7a064e242e3c343550cdb35a594e5e1f`.

These are rendered game frames, not offline renders — `tools/scenecheck` cannot
see a light, and the lighting questions were the ones that mattered here.

| File | What it shows |
|---|---|
| `01-welcome.png` | The menu mecha was buried to the hips and at default R15 scale, so the welcome screen was a torso with no machine under it. After: the full thirteen-stud Aegis standing on the bay floor, silhouetted against the open hangar door. |
| `02-arctic-establishing.png` | The establishing shot at 115 studs and 24° read as a tabletop model. After: 72 studs and 10°, with the convoy as a real foreground layer and the base small and high where distance puts it. |
| `03-wheel-contact.png` | The wheel face was a bright ten-arm "daisy" with a large hi-vis hub — the brightest object in the Arctic and, being ten-fold symmetric, nearly useless for reading rotation. After: five radial spokes, a small hub and one orange timing mark, so a quarter turn is obvious in a still frame. |
| `04-command-room.png` | General Hale delivering "Report." while lying horizontal on open snow. The whole command-room cast was drifting several studs per second and tumbling past upside down. After: the room, upright, in frame. |
| `05-command-master.png` | The master shot, before and after the arm pose, master height and lab-trim albedo changes. |

## Studio diagnostics at the end of the pass

```
17/17 in-scope shots play exactly as authored   (distance == authoredDistance,
                                                 corrected == false)
0 mid-shot camera corrections or collapses
0 [ActorValidation] warnings
```

The camera report is `[OpeningCamera]` in the Studio output; the posture
validator is `[ActorValidation]`. Both are Studio-only and both are printed to
the Studio log file, which is where these numbers were read from.
