# REAPER SFX v2 — 2026-07-12 (A/B against reaper_sfx/)

Same 60 sounds as `../reaper_sfx/` (v1), same filenames, rebuilt with the newly
installed free plugins. v1 is untouched — flip between the two `ogg/` trees to compare.

**What changed per family:**

| Family | v2 change |
|---|---|
| All reverb tails | ReaVerbate → **Valhalla Supermassive** (every sound with a tail) |
| Swings (6), dodge, dashes (4) | Re-architected: **Surge XT** noise → resonant lowpass with filter-envelope sweep (real whoosh instead of phaser-faked) |
| Shock hits (3), shocked_apply | **Surge XT** resonance zaps + noise crack |
| Cryo hits (3), crit | **Dexed** FM bells + icy Supermassive shimmer |
| Void hits (3) | Supermassive dark-warble mode replaces flanger |
| Pickups, UI chimes, fanfares, player death | **Dexed** FM electric-piano/bell voices replace ReaSynth sine |
| Boss intro | **Surge XT** unison saw brass stack + Supermassive hall |
| Physical/fire hits, kill, deaths, block, error, extraction warning/start/hum/interrupted | v1 architecture kept (they worked), Supermassive upgrade where reverb present |

Extraction hum still loops seamlessly (seam RMS ratio 1.03). All files
peak-normalized to -1 dBFS, positional slots mono, same directory layout as v1.

Recipes: `tools/sfx_forge/recipes_v2.py` (needs `sfx_lib_v2.py`, `surge_params.json`).
