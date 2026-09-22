# Phase 0.A Studio settings

Editor Quality Level and Auto FRM Level were changed to 21 during the
previous Phase 0.A Studio test. Their original values are unknown; no
reliable backup was found. On 2026-09-21 the user explicitly instructed us
to leave both at 21. Do not guess restoration values.

This repair pass does not change any other global Studio settings. Record
the previous value before any future essential global setting change.
Bench lighting is declared in phase0a.project.json and applied explicitly
by tools/phase0a/Phase0A.client.lua. It is isolated from story lighting.
