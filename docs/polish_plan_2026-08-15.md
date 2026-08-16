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

### 2.4 The phase dial — DONE (2026-08-15)

Ben picked `Minifantasy_GuiClock.png` over the day/night dial, and wall-clock phase over descent
depth. Wired into `hud.gd`: a `PhaseDial` panel under the timer/kills plate, face + rotating hand
composited from the sheet's 16-frame sweep, hand colour flips blue→red while the extraction
window is open. Full detail (frame math, sheet layout, verification) in
`docs/ui_pack_inventory.md` §12. Verified live in the Training Room; descent-mode pass (same
wall-clock signal — not expected to differ) still needs Ben per the Training-Room-only testing
rule.

### 2.5 Holy Hammer / Reckoning redesigns — RESOLVED, premise was stale (2026-08-15)

Both are Warden (Paladin) abilities — the Devout/Cleric kit has neither — and both were redesigned
in `05e05ea` (2026-07-20, the ability polish wave itself), not left pending by it. What shipped:

- **Holy Hammer** stopped being a single slam and became the hammerdin spiral — one blessed hammer
  per RMB press, the phase self-looping so mashing RMB fans more hammers out at golden-angle
  offsets (`chain_factory._hammer_phase`, `player._spawn_holy_hammers`, `scripts/entities/holy_hammer.gd`).
- **Reckoning** replaced the old damaging Dome with a pure absorb channel: it deals nothing while
  held, drinks every incoming hit into `player._dome_absorbed` (cap 30% max HP), and detonates the
  stored total ×1.5 in r70 on release or cap (`player._detonate_reckoning`, `build_paladin_dome`).

They have been *tuned twice more since*, which is the clearest evidence the redesigns were live and
being felt: `62d2789` (2026-07-21) dropped the hammer spin 1.1→0.7 rev/s and anchored the spiral at
the cast point; `3e35f96` (2026-07-30) widened `HAMMER_WIN` 0.55→0.9s after the ComboTimingAudit
found the re-tap branch had only a ~50ms slice to fire in; `8a0ccae` (2026-08-01) slowed the spiral
to 34px/s out to 150px (1.8s → ~4.1s of life, ~2.9 revolutions) on Ben's "holy hammers should last
longer", and made RMB-tap open on Holy Hammer alone instead of repeating Shield Bash.

The carry is a memory-index artifact: `project_ability_fix_wave.md`'s one-line description says
"Holy Hammer/Reckoning redesigns pending" while its own body records them as **built and Ben-approved
on 2026-07-20**. That stale one-liner is what got copied forward into this plan. No code change
needed; closing as already-done, not gated.

Two of the four hammer MOD ideas approved in spirit on 2026-07-20 were then built on Ben's word the
same day this section was closed: **SHATTERING HAMMERS** (split-on-hit) and **BOUND SPIRAL**
(spiral-follows-player), both `kit_flag` class mods — see `class_mod_system.md` §Beyond phases.
They took the roster slots of BLESSED HAMMER STORM and DICTUM'S REACH, whose numbers survive in the
level-up pool; save migration v2→v3 renames the old ids in place.

Genuinely still open on the Warden, and *not* a redesign: whether the hammer window lapsing should
fire the combo-drop exhale (a feel call for Ben), and the two remaining mod ideas — elemental
recolors (Ben does art) and pierce-raises-hit-cap.

### 2.6 Hub NPC emotions and speech bubbles *(carried)*

Still the lowest-priority item on the record. Listed so it survives.

---

## Tier 3 — The remaining content walls

### 3.1 Biomes 4 and 5 are stubs — **4 DONE (2026-08-16), 5 remains**

*(originally verified 2026-08-15)* `LEVELS[4]` "The Threshold" and `LEVELS[5]` "The Inferno"
were name + music id, with no block prefix for either.

**`LEVELS[4]` The Threshold shipped 2026-08-16** (`4bc8841` blocks, `da7d5c6` roster).
Ben's inputs: Warp Lands tileset, **both** enemy packs split by depth, identity *"someone
opened a door they could not hold."*

- **Blocks:** new `warp` compiler style — inverted void world where land is painted by
  **three** IntGrid auto-layers (the pack ships purple/cyan/red variants of every terrain
  piece at a 336px stride). New `B`/`R` grid chars are walkable reality zones. Void blobs get
  filled with the matching rift sprite, so a cross-shaped hole reads as a tear.
  12 blocks via `tools/gen_warp_blocks.py`; headless loader test 12/12.
- **Roster:** 17 rank-and-file + 2 bosses across Dark_Brotherhood (phases 1–3) and
  Dark_Orc_Army (phases 4–5), with the Possessed tier as the hinge. `LevelData.playable_ids()`
  is now `[1, 2, 3, 4]`.
- **Outstanding:** `threshold.ogg` (task 02's pattern — id wired, file absent), and an
  in-engine descent smoke test with Ben's Godot open.

**`LEVELS[5]` The Inferno still stands**, and is now the cheapest biome the project will
ever build: the pipeline has been proven three times and the fourth run needed no engine
changes at all — only data, scenes, blocks and one compiler style. Hellscape is already the
`floor_path`. **Still do not start without Ben picking the enemy pack and the identity
sentence.** Unused creature packs that would fit: `Minifantasy_Creatures_v3.3`'s unwired
Monsters (Cyclop, Pumpkin_Horror, Trasgo, Wildfire) and the Feral/Lesser orc tiers this
biome deliberately skipped.

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
5. Then the remaining Tier 2 decisions (2.4 needs Ben's word; 2.3 and 2.5 both closed as
   already-done), and the Tier 3 walls when Ben picks a biome identity.

Step 0 and Tier 1 need nothing from Ben except Godot open (Step 0) and a yes on un-excluding
audio (Tier 1). 2.1, 2.3, and 2.4 are now decided and done.

**Updated 2026-08-16:** 3.1's standing decision was answered for biome 4 and The Threshold
shipped. The remaining standing decision is the same question for **biome 5, The Inferno**
(enemy pack + identity sentence), plus `threshold.ogg` and `inferno.ogg` on task 02's
pattern.
