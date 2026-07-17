# REAPER-Synthesized SFX — 2026-07-12

60 sounds synthesized from scratch in REAPER (driven by Claude via the reaper-mcp bridge;
stock plugins only: ReaSynth, tonegenerator, pink noise JS, Rea* FX). No third-party
assets, no license concerns.

**Not wired in yet** — audition first (last SFX set was rejected, so these wait for
approval). Every file under `ogg/` already has the exact filename its `sound_table.gd`
slot expects; swap-in is a pure file copy onto `assets/audio/sfx/<subdir>/`, zero code
changes.

| Folder | Contents | Notes |
|---|---|---|
| `ogg/combat/` | swings (6), hits (15: physical/fire/cryo/shock/void ×3), crit, kill, deaths (5), block, dodge, boss_intro | positional slots are mono |
| `ogg/status/` | burn/chill/frozen/shocked/void apply stingers | fills the 5 TODO slots from the manifest |
| `ogg/pickup/` | xp ×2, currency ×2, weapon, mod, keystone | D-major-pentatonic palette |
| `ogg/ui/` | level_up, upgrade_select, click, panel open/close, purchase, error, cancel | |
| `ogg/extraction/` | warning, channel_start, channel_hum (2.0s seamless loop), complete, interrupted | replaces the spaceEngineLow stand-in |
| `ogg/dash/` | generic, teleport, deadly, dodge_roll | new — no sound_table entries yet, need wiring |
| `ogg/music/` | `gameplay_dnb_lofi.ogg` — 44.65s loopable chill DnB (172 BPM half-time, D minor, A/A'/B/A'' structure, vinyl noise bed) | candidate for a biome slot; loop starts on the downbeat kick |
| `*.wav` | raw 32-bit renders (pre-normalize masters) | keep for re-processing |

All OGGs peak-normalized to -1 dBFS; `sound_table.gd` `volume_db` offsets do the mixing.
Design palette: positive/reward sounds in D major pentatonic, hits are layered
noise+sine-sweep, elemental hits follow the manifest descriptors (crackle/sparkle/zap/warble).

Sources live in the session scratchpad (`recipes.py`, `sfx_lib.py`, `forge.py`) — ask
Claude to regenerate/tweak any sound by name.
