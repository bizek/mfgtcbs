# Task 01: Finish, verify, and commit the Nightmare Realm

> **Tier:** 2 → Sonnet-class · **Depends on:** none · **Est. tokens:** ~1.5k in / ~3k out
> Paste everything below the rule into a fresh session.

---

<goal>
Biome 3 (The Nightmare Realm) is half-landed in the working tree: the data layer is complete and
uncommitted, but 15 of the 16 enemy scenes its `scene_map` references do not exist. Finish it,
verify it in-engine, and land it as one commit so the tree is clean for everything that follows.
</goal>

<context>
State of the working tree (verified 2026-08-15):

- `data/factories/level_data.gd` — LEVELS[3] fully authored: 5-phase `wave_composition` over 14
  `nm_*` ids, `blocks` dict (Entry `Block_NMRealm_00_Entry`, Merchant `_10_Merchant`, Portal
  `_11_Portal`, 9-block pool), full `scene_map`, miniboss `centaur_king`, boss `angel_of_death`.
- `data/factories/enemies/enemy_registry.gd` — all 16 definitions registered.
- New untracked factories: `nightmare_enemy_data.gd`, `centaur_king_data.gd`,
  `angel_of_death_data.gd` (Minifantasy_Monster_Creatures pack).
- New untracked blocks: `blocks/nmrealm/Block_NMRealm_10_Merchant.block` + `_11_Portal.block`,
  their compiled `.ldtkl` files and PNG previews.
- `assets/Maps/Levels/Level 1 - Caves.ldtk` modified (+108 lines — the two new levels registered).
- `scenes/enemies/` contains ONLY `nm_fodder.tscn` of the 16 scenes `scene_map` names.
- `tools/gen_nightmare_scenes.gd` (untracked) is the scene generator; it has produced one scene.

The launch panel already cycles biomes via `LevelData.playable_ids()`
(`scripts/ui/hub_launch_panel.gd:320-339`), so level 3 becomes selectable the moment its data is
valid. `mus_nightmare_realm` → `nightmare_realm.ogg` does not exist; `AudioManager` no-ops on
missing files — that is expected and handled by a separate task, not this one.
</context>

<requirements>
- **Ask Ben to open Godot first** — do not launch the editor yourself. The generator is an editor
  script.
- Read `tools/gen_nightmare_scenes.gd` before running it; confirm it emits all 15 missing scenes
  (`nm_swarmer` … `nm_heavy`, `centaur_king`, `angel_of_death`) and does not overwrite
  `nm_fodder.tscn` with different content than what is on disk.
- Run it via the Godot MCP (`execute_editor_script`). Verify every generated scene's sprite paths
  resolve and that each enemy uses the pack's real directional rows — full-asset-utilization rule:
  no flip_h where a left/right row exists, no substitute sheets.
- Boot check: project loads with zero script errors; `EnemyRegistry.build_all()` clean; the
  startup content validators in `GameManager._validate_content` pass with no warnings.
- **Back up `progression.json` before any in-engine testing** — allocate/refund paths call
  `save_data()` and overwrite Ben's real save. Restore byte-identical after.
- Smoke-test a Nightmare Realm descent per the `/blockgen` skill's smoke-test convention: select
  level 3 from the hub launch panel, descend, confirm the entry spawn is walkable, waves spawn
  from the `nm_*` roster, the merchant and portal blocks are reachable, and the miniboss/boss
  spawn hooks fire. God mode + suppressed spawns for traversal checks is fine (Ben authorised
  that pattern 2026-08-03); wave checks need spawns on.
- If a scene, factory, or block fails, fix it in place — that is this session's job, not a
  finding to report.
- Commit everything as ONE grouped conventional commit (LDtk + blocks + previews + factories +
  registry + level_data + scenes + tool + .uid files). Run `git status` after staging AND after
  committing; zero unstaged/untracked files may remain.
</requirements>

<output_format>
1. The commit, landed on `main`.
2. A short session report: what the generator produced, what the smoke test showed (per check),
   anything fixed along the way, and confirmation the save was restored and `git status` is clean.
3. Update the status table in `docs/Session Prompts - Polish 2026-08-15/00_EXECUTION_PLAN.md`
   (01 → ✅ with a one-line evidence note).
</output_format>
