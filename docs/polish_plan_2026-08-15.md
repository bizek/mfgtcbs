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

### 1.1 The Catacombs and Nightmare Realm have no music

*(verified 2026-08-15)* `ls assets/audio/music/` → `boss.ogg`, `caves.ogg`, `hub.ogg`. That's all.
`mus_catacombs` → `catacombs.ogg` and `mus_nightmare_realm` → `nightmare_realm.ogg` are referenced
by the sound table and do not exist; `AudioManager` no-ops on missing files, so every run in
biomes 2–3 plays nothing. A shipped biome with no music is the loudest remaining "prototype" tell
now that scene fades and the Grim HUD are in.

**Do:** two loopable tracks (~1.5–2 min each), forged in REAPER against the existing `caves.ogg`
as the mix reference. `threshold.ogg` / `inferno.ogg` wait for their biomes (Tier 3).

### 1.2 Held channels are still silent — three loop beds

*(verified 2026-08-15)* `AudioManager.play_channel_loop` is wired and called
(`player.gd:1691`, keyed by `SoundTable.CHANNEL_LOOP_BY_KIT`), and
`ls assets/audio/sfx/combat/` contains **no `channel_loop_*` files**. This is the same
wired-but-assetless state first recorded 2026-08-02:

```
channel_loop_fire.ogg      low roaring bed      (Immolate, Hellfire)
channel_loop_arcane.ogg    dry rattle/whisper   (Bone / Bramble Barrage)
channel_loop_martial.ogg   low physical rumble  (Taunt, Dictum, dome)
```

Seamless ~2s loops, quiet enough to sit under the per-beat hits. Drop them in and they light up
with **no code change**.

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

### 2.1 NEW GAME still skips the hub

*(verified 2026-08-15)* `main_menu.gd:279` / `:316` — NEW GAME still goes straight to
`main_arena.tscn` as The Drifter; CONTINUE goes to the hub (`:266`). With biome selection now live
in the launch panel, a first-run player never sees the biome choice either. The question from the
08-08 plan is unchanged and unanswered: **intended, or should NEW GAME land in the hub?**

### 2.2 The mod rework has still never been felt in a run *(carried)*

96 mods / 24 evolutions, verified statically and in simulation. Re-check
`mod_levelup_rework_plan.md` §"Still open" at session start; if still open, the cheap version is a
Training Room pass per class (mod bench landed in `e88481e`), the real one is Ben playing.

### 2.3 Mod rarity and pricing *(carried)*

Flat `MOD_PRICE`, unweighted 8-deep class pools, rarity pills describing a distinction the economy
no longer makes. **Needs Ben:** restore rarity (drop weight + price) or embrace the flat roster and
retire the pills. Verify the merchant still charges flat before building anything.

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
5. Then the Tier 2 decisions (2.1, 2.3, 2.4 need Ben's word; 2.5 needs a design look), and the
   Tier 3 walls when Ben picks a biome identity.

Step 0 and Tier 1 need nothing from Ben except Godot open (Step 0) and a yes on un-excluding
audio (Tier 1). The four standing decisions are: NEW GAME flow (2.1), mod rarity (2.3), phase
dial (2.4), and the next biome's identity (3.1).
