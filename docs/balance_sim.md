# Balance Sim — headless bot sweeps

`tools/sim/` runs the real game headless, in the Training Room, with a bot pressing the real
input actions, and measures every kit, level-up pick, class mod and 3-mod loadout. The output is
one HTML report (`tools/sim/out/report.html`).

It replaces the *measuring* part of playtesting — "is this pick doing anything", "which kit is out
of line", "which mods combine" — not the *feel* part. Nothing it reports says whether a combo is
fun, a telegraph is readable or an animation lands right.

## Run it

```
python tools/sim/sim_stages.py all            # full sweep, ~2-4 h on 20 workers
python tools/sim/build_report.py              # → tools/sim/out/report.html
```

Stages, in order (each reads the previous one's output under `tools/sim/out/stages/`):

| Stage | What it does |
|---|---|
| `calibrate` | Searches each kit's play policy per arena (288-policy grid → top 8 on 3 seeds → horde / survival trials) |
| `baseline` | Level-1, no-mod profile of every kit (the roster comparison) |
| `picks` | Marginal value of every level-up pick at level 1; capstones and evolutions on top of their prerequisites |
| `mods` | Each class mod alone, then all 56 three-mod loadouts per kit |
| `greedy` | Best 8-pick build per kit, one pick at a time, following UpgradeManager's rank / prerequisite / evolution rules. `GREEDY_EXCLUDE` keeps Static Discharge and Lightning Reflexes out until their proc chain is fixed |
| `recheck` | After a targeted code fix: fresh baseline + just the named picks (`RECHECK_IDS`) under the current code, patched into picks.json — no full re-run |

Any stage can be limited to kits: `python tools/sim/sim_stages.py picks "The Drifter" ranger`.
Worker count: `SIM_WORKERS=20` (each headless worker is ~260 MB).

Results are cached by scenario + a fingerprint of every `.gd` under `scripts/ data/ tools/sim/` plus
`balance_overrides.json` / `anim_overrides.json`. Change game code or tuning and exactly the
affected results re-run; change only the report and nothing re-runs.

## The four arenas

| Arena | Measures |
|---|---|
| single | DPS on one rooted immortal dummy, starting at the policy's range |
| cluster | summed DPS on six rooted immortal dummies inside a 24 px circle |
| horde | kills/min on clumped packs of 60 HP chasing fodder, player immune — the only offence arena where on-kill procs fire |
| pressure | seconds to the first would-be death in a brawl: real enemy mix, hitting back, ramping count and difficulty, no escape-kiting |

## Safety

- **`--sim` gates every persistent write** (`scripts/utils/sim_mode.gd`): ProgressionManager.save_data,
  Settings.save_settings and the Logger's crash log / session marker all no-op in a worker, because
  Godot 4.6 has no switch to point a worker at a different `user://`. The runner refuses to start
  without the flag.
- Every scenario asserts `GameManager.training_mode` **and** a live TrainingPanel on arrival and
  aborts the worker otherwise (CLAUDE.md "In-Game Testing"). Scene changes go through the panel's
  `keep_training_mode()`.
- Workers are separate processes and never touch the open editor.

## Statistics

- Intervals come from each kit's **pooled** run-to-run variance (every build of that kit at once),
  not a per-build bootstrap — 2 seeds cannot estimate their own noise.
- Table verdicts (blue/red) are **Benjamini–Hochberg** adjusted at 10% FDR per table family.
- Rankings use **empirical-Bayes shrinkage** with a spike-and-slab prior fitted per kit and arena,
  so a noisy survival swing cannot top a table while a clearly significant one keeps its size.
- "Does nothing" is an **equivalence** claim (every offence interval inside ±5%), never just
  "not significant".

## Runaway scenarios

A scenario that hangs or overflows the engine is recorded as a finding, not a harness failure:
a worker whose log passes 32 MB (or runs past the timeout) is killed, its finished scenarios are
kept, and the rest are re-run one at a time so the culprit comes back as `{"crashed": true,
"error": <signature>}` — cached, so it never hangs a re-run. First caught 2026-09-27: the Static
Discharge on-crit proc chain overflowing the stack every frame (10.6 GB log before this existed).

## Harness facts that were not obvious

- A `--script` SceneTree compiles before autoloads are registered, so `sim_runner.gd` /
  `sim_catalog.gd` are thin loaders that `load()` the real body afterwards.
- The bot presses actions from a node with `process_physics_priority = -1000`, so a press is
  `just_pressed` in the player's own `_physics_process` on the same frame.
- `EnemySpawnManager.active_enemies` only counts down via the hookup `start_spawning()` makes,
  which the Training Room never calls — the sim sets the count itself, or spawning stops at 90.
- Survival was first measured as time-to-death with the bot kiting; the same build went down 0
  or 5 times depending on seed (it measured whether the bot cornered itself). First-down time in a
  brawl has a seed-to-seed CV of ~0.05–0.13.
- Validation: Drifter light-chain hits reconcile exactly with `chain_factory.gd` (0.9 / 0.7 /
  1.05 × 25 = 22.5 / 17.5 / 26.25, 0.75 s per loop).
