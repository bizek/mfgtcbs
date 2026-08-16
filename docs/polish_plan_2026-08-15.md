# Polish Plan — 2026-08-15

Successor to `polish_plan_2026-08-08.md`, which is now **closed**: its Tier 0 and Tier 1 shipped in
full, 3.1a (block-pool plumbing) landed, and 3.1b became The Catacombs (`1b09d25`). Since that plan
was written, biome selection also shipped — the launch panel cycles `LevelData.playable_ids()`
(`hub_launch_panel.gd:320-339`) — and biome 3, **The Nightmare Realm, is sitting half-landed in the
working tree right now**.

Same rules as both predecessors: **every line carries the check that proves it**, tiers rise in cost
and fall in certainty, and nothing here has been changed yet. Lines marked *(verified 2026-08-15)*
were checked for this document; lines marked *(carried)* come from a prior doc and must be
re-verified at the top of whatever session picks them up.

> **The headline is Step 0.** The Nightmare Realm's data layer is finished and uncommitted, but its
> `scene_map` names 16 enemy scenes and **only one exists on disk**. Nothing below should start on
> top of that tree.

**Session prompts for this plan** live in `docs/Session Prompts - Polish 2026-08-15/` — one
self-contained prompt per task, tier-routed (Prompto, 2026-08-15). Start from that folder's
`00_EXECUTION_PLAN.md`, which also carries the live status table for this plan.

---

## Step 0 — Land the Nightmare Realm (finish it, verify it, commit it)

*(verified 2026-08-15)* The working tree carries a complete biome-3 data layer:

- `data/factories/level_data.gd` — 5-phase `wave_composition` over 14 enemy ids, `blocks` dict with
  Entry/Merchant/Portal bookends + 9-block pool, full `scene_map`, `centaur_king` miniboss,
  `angel_of_death` final boss (+69 lines, uncommitted).
- `data/factories/enemies/enemy_registry.gd` — all 16 definitions registered (+18 lines).
- New factories: `nightmare_enemy_data.gd`, `centaur_king_data.gd`, `angel_of_death_data.gd`.
- New blocks: `Block_NMRealm_10_Merchant` / `_11_Portal` (.block sketches, .ldtkl, previews) —
  the bookends the NMRealm set never had, same gap the Crypt set had.
- `assets/Maps/Levels/Level 1 - Caves.ldtk` +108 lines (the two new levels registered).

**What's missing:** `ls scenes/enemies/` shows **only `nm_fodder.tscn`** of the 16 scenes the
`scene_map` references. `tools/gen_nightmare_scenes.gd` exists (untracked) and is presumably the
generator; it has produced one scene, or was only piloted.

**Do, in order:**

1. Run `tools/gen_nightmare_scenes.gd` (editor script — needs Godot open; ask Ben) to emit the 15
   missing scenes. Verify each against its factory's sprite paths — the Monster Creatures pack must
   be fully utilized per the pack rule (all facing rows, no substitutes).
2. Boot check: `EnemyRegistry.build_all()` must not error, and the startup content validators
   must pass clean.
3. Smoke-test a Nightmare Realm descent per the `/blockgen` convention: select level 3 from the
   launch panel, descend, confirm entry spawn is walkable, merchant and portal blocks reachable,
   waves spawn from the new roster, miniboss and boss appear.
4. Commit the whole biome as one grouped conventional commit (LDtk + blocks + previews + factories
   + scenes + tool). `git status` must be clean after.

---

## Tier 1 — Audio that is now player-facing debt

Audio was **deliberately excluded** from the 08-08 plan (Ben, 2026-08-08). That exclusion predates
biomes 2 and 3 shipping, and the calculus changed: two of the game's three playable biomes now run
**silent**. Recommend un-excluding at least 1.1; Ben should confirm.

All REAPER work renders to `assets/audio/_incoming` via the REAPER MCP bridge, per
`docs/audio_pipeline.md`.

### 1.1 The Catacombs and Nightmare Realm have no music — ✅ DONE 2026-08-15

*(was, verified 2026-08-15)* `ls assets/audio/music/` → `boss.ogg`, `caves.ogg`, `hub.ogg`. That's
all. `mus_catacombs` → `catacombs.ogg` and `mus_nightmare_realm` → `nightmare_realm.ogg` were
referenced by the sound table and did not exist; `AudioManager` no-ops on missing files, so every
run in biomes 2–3 played nothing.

**Done:** both tracks composed in REAPER and shipped, zero code changes.

| | Catacombs | Nightmare Realm |
|---|---|---|
| Loop | 96.0 s, 60 BPM, A Phrygian | 114.0 s, no pulse |
| Identity | processional footfall on beats 1 & 3, open fifths, crypt bell every 8 bars | 3 Hz detuned drone beat, consonant bells at off-grid times, Eb tritone 3×/loop |
| Loudness | −27.7 LUFS (exact match to `caves.ogg`) | −27.7 LUFS |
| Seam | step 0.16× interior noise floor | step 0.02× |

Sources: `tools/sfx_forge/music_catacombs.py`, `music_nightmare.py`, shared loop machinery in
`music_lib.py`; rebuild with `build_biome_music.py`, install with `install_biome_music.py`.
REAPER projects for a feel pass: `assets/audio/_incoming/reaper_music/*.rpp`.
**Ben still needs to listen** — every claim above is measurement, not ears.

`threshold.ogg` / `inferno.ogg` wait for their biomes (Tier 3), and `music_lib.py` is built to
take them.

### 1.2 Held channels are still silent — three loop beds ✅ DONE 2026-08-15

Shipped: `assets/audio/sfx/combat/channel_loop_{fire,arcane,martial}.ogg` (~2s seamless loops,
peak-normalized -6 dBFS, `SoundTable`'s existing -18 dB sits them under the per-beat hits).
Composed in REAPER via `tools/sfx_forge/channel_loop_{fire,arcane,martial}.py` +
`build_channel_loops.py`/`install_channel_loops.py` (same pipeline shape as the biome music,
peak-normalized like ordinary SFX rather than LUFS-matched). Zero code change — `player.gd:1691`
and `SoundTable.CHANNEL_LOOP_BY_KIT` already pointed at these exact paths.

In-engine verified in the Training Room 2026-08-15: RMB-hold starts the bed, it loops across the
seam, and releasing stops it — checked on demonologist (Immolate → fire), necromancer/The Shade
(Bone Barrage → arcane), and fighter/The Drifter (Taunt → martial).

The straight extraction technique used for the biome music (`music_lib.render_two_periods` +
`extract_period`) doesn't hold for these: it makes *duplicated deterministic events* periodic,
but the beds lean on continuously-running noise generators, which have no phase to lock. Fixed
with a standard ambient-loop splice instead — fold the extracted period's true tail into its true
head with a short equal-power crossfade (`build_channel_loops.extract_loop_xfade`). REAPER
projects for a feel pass: `assets/audio/_incoming/reaper_music/channel_loop_*.rpp`.
**Ben still needs to listen** — every claim above is measurement, not ears.

### 1.3 Skill and pet stingers — the last of RTR task 15

*(verified 2026-08-15)* Dash stingers shipped (4 files in `assets/audio/sfx/dash/`, entries at
`sound_table.gd:315-330`). A grep of `sound_table.gd` for `sfx_skill|sfx_pet|sfx_summon` returns
**nothing** — Q/E skill casts and pet events (summon arrival, pet attack) have no voice. This is
the final remainder of task 15. Scope it like the dash pass: a small set of shared stingers keyed
by category, not one per skill.

### 1.4 Combo-drop feel pass — Ben's ears, not code

*(verified 2026-08-15)* `combo_drop.ogg` now exists in `assets/audio/sfx/combat/` — the pending
REAPER render from the cadence pass has landed. What remains is Ben playing with it and saying
whether the exhale feels right. Nothing to build unless he wants it re-voiced.

---

## Tier 2 — Open decisions, carried from 08-08 (all still open, none re-decided)

### 2.1 NEW GAME still skips the hub — DECIDED, DONE

*(2026-08-15)* Decided: NEW GAME lands in the hub, same as CONTINUE. `_start_new_game()`
(`main_menu.gd`) now transitions to `res://scenes/hub.tscn` with the default `SceneTransition`
fade (matching CONTINUE) instead of `main_arena.tscn`; `ProgressionManager.reset_save()` is still
called first, so the new-game reset behaves exactly as before. The ERASE & START confirm button
(`_on_confirm_erase`) shares the same `_start_new_game()` call, so it inherited the fix with no
separate change. Verified in-engine: fresh-save NEW GAME → hub renders → LAUNCH PAD panel opens →
BEGIN DESCENT → first-run overlay's spawn cue fires as expected. `first_run_overlay.gd` needed no
change — it only exists as a child of the in-run HUD, so it was never reachable from the hub.

### 2.2 The mod rework has still never been felt in a run *(carried)*

96 mods / 24 evolutions, verified statically and in simulation. Re-check
`mod_levelup_rework_plan.md` §"Still open" at session start; if still open, the cheap version is a
Training Room pass per class (mod bench landed in `e88481e`), the real one is Ben playing.

### 2.3 Mod rarity and pricing — RESOLVED, premise was stale (2026-08-15)

This section (and RTR prompt `06_SONNET_mod_rarity.md`) described a flat `MOD_PRICE`,
unweighted drops, and rarity pills with nothing behind them. That was already fixed five days
earlier, in `366f823` (2026-08-10, "rarity that means something — drops, prices and a visible
tag"): every class mod carries a rarity (1 epic / 3 rare / 4 uncommon per kit), drops roll
weighted by depth (`ClassModData.droppable_pool_of_rarity`), and the merchant charges
6/10/16 by tier (`merchant_shop.gd` `MOD_PRICE_BY_RARITY`) instead of a flat 8. This carried
section was never re-verified against source before being copied into the 2026-08-15 plan —
it originated in `polish_plan_2026-08-08.md` and nothing updated it after 366f823 landed two
days later. No code change needed; closing as already-done, not gated.

### 2.4 The phase dial *(carried)*

`Minifantasy_GuiClock.png` / `Minifantasy_GuiDayNightDial.png` remain unwired; the phase flash
label is the only "where am I in the run" signal. A dial answers at a glance what a flash cannot.
**Needs Ben:** phase-display design call.

### 2.5 Holy Hammer / Reckoning redesigns *(carried, from the 2026-07-20 ability wave)*

Recorded as pending since the all-roster playtest. Verify against the current Cleric/Paladin kits
before designing — three kits have churned since.

### 2.6 Hub NPC emotions and speech bubbles *(carried)*

Still the lowest-priority item on the record. Listed so it survives.

---

## Tier 3 — The remaining content walls

### 3.1 Biomes 4 and 5 are stubs

*(verified 2026-08-15, from the level_data diff context)* `LEVELS[4]` "The Threshold" and
`LEVELS[5]` "The Inferno" are name + music id. No block prefix exists for either
(`blocks/` has caves, crypt, nmrealm, warp). Each is a Catacombs-sized job: block set via
`/blockgen`, enemy roster from an owned pack, wave table, bosses, music. **Do not start either
without Ben picking the pack and the biome identity.** The Nightmare Realm proves the pipeline:
data-only landing, scenes generated by tool, bookends compiled from sketches.

### 3.2 Game-wide `TEXT_SIZE_SCALE` *(carried, recorded in CLAUDE.md)*

8 of 151 font sites route through `Settings.scaled_font_size()`; LARGE would have to mean 2.0
(16→32) to do anything. This is the one real accessibility gap on the books. Medium-large,
mechanical, and it re-surfaces the layout footgun (containers that hug content minimum) — budget
a layout re-check per screen.

---

## Tier 4 — Release engineering (blocked on Ben, unchanged)

- **Steam (RTR 24):** needs a Steam App ID.
- **Store copy (RTR 25):** needs the final game name (decision D5). The itch channel
  (`bizek.itch.io`, web dashboard, `build.ps1` zips) is ready when the name is.
- **Capsule art, screenshots, trailer:** Ben's list, per `docs/release_pipeline.md`.

---

## Suggested order

1. **Step 0** — finish and commit the Nightmare Realm. Everything else stacks on a dirty tree
   until this lands.
2. **1.1 + 1.2** — biome music and channel beds in one REAPER sitting. Highest feel-per-hour
   remaining anywhere in the project.
3. **1.3** — skill/pet stingers, closing RTR task 15 for good.
4. **2.2** — play the mod rework (Ben), before more content stacks on it.
5. Then the remaining Tier 2 decisions (2.3, 2.4 need Ben's word; 2.5 needs a design look), and
   the Tier 3 walls when Ben picks a biome identity.

Step 0 and Tier 1 need nothing from Ben except Godot open (Step 0) and a yes on un-excluding
audio (Tier 1). 2.1 is now decided and done. The remaining standing decisions are: mod rarity (2.3), phase
dial (2.4), and the next biome's identity (3.1).
