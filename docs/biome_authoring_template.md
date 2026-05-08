# Biome Authoring Template

A checklist-driven guide for taking a biome from stub to shippable.
**Caves is the canonical worked example throughout.** Biomes 2–5 (Catacombs, Nightmare Realm,
Threshold, Inferno) all follow this same sequence.

---

## What a Biome Consists Of

| Deliverable | Where it lives |
|-------------|---------------|
| LDtk project file | `assets/Maps/Levels/Level X - <Name>.ldtk` |
| External level files | `assets/Maps/Levels/Level X - <Name>/Level_N.ldtkl` |
| `LevelData` entry | `data/factories/level_data.gd` `LEVELS` dict |
| Enemy factory | `data/factories/enemies/<biome>_enemy_data.gd` |
| Enemy scenes | `scenes/enemies/<biome>_<name>.tscn` |
| EnemyRegistry registration | `data/factories/enemies/enemy_registry.gd` |
| Boss factory | `data/factories/enemies/<boss_name>_data.gd` |
| Boss scene | `scenes/enemies/<boss_name>.tscn` |

---

## Pre-Authoring Checklist

Make these decisions before opening LDtk. Write them down — you'll reference them in every step.

- **Theme / atmosphere** (1–2 sentences). Caves: underground goblin warrens, dripping rock, zero
  ambient light except fungi glow. This informs tileset choice, enemy silhouettes, and boss concept.

- **Level ID** — integer key in `LevelData.LEVELS`. Caves = `1`. Assign the next available integer
  from that file. Do NOT reuse an ID.

- **Tileset selection** — pick a Minifantasy pack from `assets/minifantasy/`. Prefer packs that
  include a `Premade Scene/Separate Layers/` directory; that gives you a ready-made floor texture
  for `floor_path`. See [ldtk_workflow.md](ldtk_workflow.md) "Biome Asset Map" for the current
  inventory of packs on disk.

- **Music placeholder** — a short string key (e.g. `"catacombs_ambient"`). The actual audio file
  doesn't need to exist yet; the key goes in `music_id` in LDtk and you move on.

- **Enemy lineup** (5–8 enemies). Aim for:
  - 2–3 cheap swarm units (fast, fragile, high spawn rate in early waves)
  - 1–2 mid-tier melee enemies (more HP, appear mid-run)
  - 1 tanky bruiser (low spawn weight, high threat)
  - Optional: 1 ranged or aerial variant for variety

  Caves: `cave_fodder`, `cave_skirmisher`, `cave_bat`, `cave_swarmer`, `cave_raider`, `cave_brute`.

- **Boss concept** (1 paragraph). The boss must have a silhouette distinct from Heart of the Deep
  (which is a massive slow pulsing orb with radial attacks). Distinguish by: movement pattern,
  attack geometry, arena role. Heart of the Deep occupies the center; a new boss might charge across
  the room, summon adds, or divide the arena with persistent hazards. Define the mechanic hook
  before writing any code.

---

## Step 1: Bootstrap the LDtk Project

Follow [ldtk_workflow.md](ldtk_workflow.md) — "Authoring a New Biome" — for the operational steps.
The schema checklist is in [ldtk_schema.md](ldtk_schema.md) §9.

**Biome-specific notes:**

- Name the file `Level X - <BiomeName>.ldtk` — LDtk creates the external level folder with the
  matching name automatically. Keep it.
- Append your biome's name to the `BiomeId` enum in your `.ldtk` project. **Append — never reorder.**
  The importer maps by name, not by integer index.
- Run `python tools/apply_ldtk_schema.py "assets/Maps/Levels/Level X - <Name>.ldtk"` immediately
  after saving a fresh project. This injects all entity defs, enums, and level fields so your
  Entities layer already knows about `PlayerSpawn`, `Region`, `Extraction`, `EnemySpawnZone`, etc.
- After the script runs, reopen in LDtk and manually bind the four visual layers
  (`Background`, `FloorAuto`, `WallsAuto`, `Decoration`) to your chosen tileset and configure
  auto-rules. The script can't automate tileset binding.

Caves reference: `assets/Maps/Levels/Level 1 - Caves.ldtk` with levels in
`assets/Maps/Levels/Level 1 - Caves/`.

---

## Step 2: `level_data.gd` Entry

Add an entry to `data/factories/level_data.gd` `LEVELS`. Until enemies and waves are ready, stub it
with empty arrays and fill as you go.

**Caves entry (complete, use as your template):**

```gdscript
1: {
    "name": "The Cave",
    "floor_path": "res://assets/minifantasy/Minifantasy_DeepCaves_v2.0/Minifantasy_DeepCaves_Assets/PremadeScene/SeparateLayers/Premade_h-floor.png",
    "wave_composition": [
        ## Phase 1 — tiny goblins, bats, and skirmishers swarm in
        {"cave_fodder": 0.55, "cave_skirmisher": 0.25, "cave_bat": 0.20},
        ## Phase 2 — raiders and bats join, regular goblins supplement
        {"cave_fodder": 0.30, "cave_skirmisher": 0.20, "cave_swarmer": 0.20,
            "cave_bat": 0.15, "cave_raider": 0.15},
        ## Phase 3 — trolls lumber in alongside the full goblin tribe
        {"cave_fodder": 0.20, "cave_skirmisher": 0.15, "cave_swarmer": 0.20,
            "cave_raider": 0.20, "cave_brute": 0.15, "cave_bat": 0.10},
        ## Phase 4 — specialist pressure (stalker/guardian use base scenes)
        {"cave_fodder": 0.10, "cave_swarmer": 0.20, "cave_raider": 0.15,
            "cave_brute": 0.10, "stalker": 0.25, "guardian": 0.20},
        ## Phase 5 — warped variants; anchor uses base scene
        {"cave_swarmer": 0.12, "anchor": 0.48, "warped_fodder": 0.10,
            "warped_swarmer": 0.10, "warped_brute": 0.10, "warped_caster": 0.10},
    ],
    "scene_map": {
        "cave_fodder":     "res://scenes/enemies/cave_fodder.tscn",
        "cave_swarmer":    "res://scenes/enemies/swarmer.tscn",
        "cave_brute":      "res://scenes/enemies/cave_brute.tscn",
        "cave_bat":        "res://scenes/enemies/cave_bat.tscn",
        "cave_raider":     "res://scenes/enemies/cave_raider.tscn",
        "cave_skirmisher": "res://scenes/enemies/cave_skirmisher.tscn",
    },
},
```

**Field guide for a new biome:**

| Field | Required | Notes |
|-------|----------|-------|
| `name` | yes | Hub display name. |
| `floor_path` | yes | `res://` path to a floor texture PNG. Use the biome tileset's `Premade Scene` directory as a source. |
| `wave_composition` | yes | Array of 5 dicts (one per phase). Weights must sum to `1.0` per phase. Keys are `enemy_id` strings. |
| `scene_map` | yes | Maps biome-specific `enemy_id` → `.tscn` path. IDs absent here fall back to `EnemySpawnManager`'s global scene lookup. Base-roster enemies (`stalker`, `guardian`, `anchor`, `warped_*`) live in the global lookup — omit them from `scene_map`. |

Start with `wave_composition: []` and `scene_map: {}`. Fill in as enemies are built (Step 4).
`LevelData.is_configured()` checks whether `wave_composition` is empty — the hub can gate the
biome until it's ready.

---

## Step 3: Author the Levels

Follow [ldtk_workflow.md](ldtk_workflow.md) — "Authoring a New Level" — for the full step-by-step.

**Required entities per level** (the importer will reject or malfunction without them):
- `PlayerSpawn` (1, at the top of the Maze region)
- `Region` entities tiling the level top-to-bottom with **no gaps**: `Maze` → `PreBoss` → `Boss`
- `BossSpawn` inside the `Boss` region (set `boss_id` to your biome's enum value)
- `LevelExit` at the bottom of the `Boss` region

**Strongly recommended:**
- At least one `Extraction(kind=Timed)` in the `Maze` region (early-leave option)
- `EnemySpawnZone`s covering at least two directions per region

Each level inside the biome shares the same tilesets and IntGrid conventions — you only pick
tilesets once per biome project.

---

## Step 4: Themed Enemies (5–8 per biome)

Create `data/factories/enemies/<biome>_enemy_data.gd` using the pattern from
`data/factories/enemies/cave_enemy_data.gd`.

**Annotated template — the Bat, Caves' lightest enemy:**

```gdscript
static func create_cave_bat() -> EnemyDefinition:
    var def := EnemyDefinition.new()
    def.enemy_id       = "cave_bat"        ## must match scene_map key and wave_composition key
    def.enemy_name     = "Cave Bat"        ## shown in debug panel / boss bar
    def.tags           = ["Melee", "Common", "Swarm", "Aerial"]
    def.base_stats     = {"max_hp": 5.0}
    def.combat_role    = "MELEE"
    def.move_speed     = 145.0             ## fastest cave enemy — pure swarm pressure
    def.contact_damage = 4.0
    def.base_armor     = 0.0
    def.xp_value       = 0.4
    def.health_drop_chance   = 0.03
    def.behavior_type        = "chase"     ## always chase; no ranged ability needed
    def.knockback_multiplier = 1.6         ## very light — gets batted around
    return def
```

**Stat reference from Caves:**

| Enemy | max_hp | move_speed | contact_damage | base_armor | xp_value | Role |
|-------|--------|-----------|----------------|-----------|---------|------|
| cave_fodder | 8 | 80 | 6 | 0 | 0.4 | cheap swarm |
| cave_skirmisher | 7 | 130 | 4 | 0 | 0.5 | fast scout |
| cave_bat | 5 | 145 | 4 | 0 | 0.4 | aerial swarm |
| cave_swarmer | 12 | 110 | 6 | 0 | 0.6 | standard pack |
| cave_raider | 22 | 95 | 9 | 1 | 1.2 | mid-tier melee |
| cave_brute | 90 | 38 | 20 | 8 | 5.0 | slow bruiser |

Use these as ballpark anchors when setting stats for a new biome. Scale HP up 15–25% per biome
tier (Caves=1, Inferno=5) unless the enemy role specifically calls for fragility.

**For enemies with abilities** (ranged, summon, elite), add `def.auto_attack` and/or `def.skills`
following the patterns in `engine_reference.md` → "New Enemy" and "Enemy Skills" sections.
All Caves enemies are simple `behavior_type = "chase"` units with no auto_attack — a new biome can
introduce its first ranged enemy here if the theme warrants it.

**After writing the factory:**

1. Add each `static func create_<id>()` call to `EnemyRegistry.build_all()` in
   `data/factories/enemies/enemy_registry.gd`:
   ```gdscript
   ## ── Level X — <BiomeName> ───────────────────────────────────
   _definitions["<biome>_fodder"] = <Biome>EnemyData.create_<biome>_fodder()
   ## ... repeat for each enemy
   ```
2. Create a scene for each enemy using the Godot MCP editor tools (do **not** hand-edit `.tscn`).
   Use an existing cave enemy scene as a structural reference.
3. Add the `enemy_id → .tscn path` mapping to `scene_map` in `level_data.gd`.

---

## Step 5: Wave Composition

Wave compositions are 5-element arrays in `LevelData.LEVELS[id].wave_composition`. Index 0 = Phase 1.

**Design principles (from Caves' composition):**

| Phase | Theme | Caves example |
|-------|-------|---------------|
| 1 | Biome introduction — cheapest units only | 55% fodder, 25% skirmisher, 20% bat |
| 2 | Second tier joins; swarm density peaks | Raiders and bats introduced; fodder stays dominant |
| 3 | Tanky units first appear; player must adapt | Brute enters at 15%; full goblin tribe active |
| 4 | Shared-roster specialists (`stalker`, `guardian`) | Reduces biome identity, increases mechanical pressure |
| 5 | Warped variants + `anchor`; biome enemies step back | anchor at 48%; all warped at 10% each |

**Rules to follow:**
- Weights must sum exactly to `1.0` per phase.
- Introduce units at low weight first — a unit that jumps from 0% to 20% in one phase feels jarring.
- Phase 4–5 can borrow from the shared base roster (`stalker`, `guardian`, `anchor`, `warped_*`);
  these use global scene lookups and don't need entries in your `scene_map`.
- The bruiser/elite-tier unit should never exceed ~15–20% weight; high HP units that spawn 60% of
  the time create stall loops.
- Elites (units tagged `["Elite"]`) are eligible from Phase 3 onward by convention. [VERIFY:
  confirm EnemySpawnManager has phase-gating for elite tags.]

**Per-level overrides** — if a specific level in the biome needs different wave weights (a boss
pre-chamber that adds more bruisers, a side room with all-bat pressure), use the `wave_overrides`
JSON field on the LDtk level instead of changing the biome default. See `ldtk_schema.md` §5 for format.

---

## Step 6: Biome Boss

The boss is an `EnemyDefinition` with `def.is_boss = true`, a `ChoreographyDefinition` on
`def.auto_attack`, and optional skills.

**Heart of the Deep is the canonical reference** (`data/factories/enemies/heart_of_the_deep_data.gd`).
Key things it does that every boss should do:

- Sets `def.groups = ["bosses"]` so the EnemySpawnManager treats it as a boss-class unit.
- `def.knockback_multiplier = 0.0` — bosses don't get kited by knockback.
- `def.boss_bar_color` — sets the color on the HP bar widget.
- Uses a stance machine via `ChoreographyDefinition` with HP-threshold branches
  (`ConditionHpThreshold`). A minimum viable boss can skip phases and use a flat looping choreography.
- Uses telegraphs (`SpawnTelegraphEffect`) on every dangerous attack. Do not ship a boss attack
  without a tell.

**Boss differentiation checklist** (avoid reskinning Heart of the Deep):
- Different movement speed / mobility pattern (Heart: nearly stationary at speed 13)
- Different attack geometry (Heart: radial AoE + linear projectile spread)
- Different phase trigger (Heart: HP %; an alternative is timer-based or kill-based stances)
- Different arena interaction (Heart: void pool ground hazard; alternatives: wall charges, add spawns)

**Registration:**
1. Create `data/factories/enemies/<boss_name>_data.gd` with a `static func create() -> EnemyDefinition`.
2. Add to `EnemyRegistry.build_all()`: `_definitions["<boss_id>"] = <BossName>Data.create()`.
3. Create the boss `.tscn` using the Godot MCP editor tools.
4. Add the boss `enemy_id` to `BossId` enum in the LDtk project (append, never reorder).
5. Set `boss_id` on the `BossSpawn` entity in each level that should spawn this boss.

---

## Step 7: Audio Placeholders

Until audio ships, set `music_id` to a biome-specific placeholder string (e.g. `"catacombs_ambient"`)
on each level in LDtk (Level properties panel). The audio system will log a warning about a missing
track and fall back to silence — that's acceptable during development.

Do **not** leave `music_id` empty across all levels; a placeholder string makes the eventual audio
hookup a search-and-replace rather than a manual re-audit of every level file.

---

## Step 8: Smoke Test

Run through this checklist in-engine before calling a biome done.

1. **Hub → biome select** — confirm the biome appears in the hub launch panel. If
   `LevelData.is_configured()` is `false`, the hub may gate it; fill `wave_composition` first.
2. **Character select** — pick any character; confirm no errors on scene load.
3. **Wave 1–3 (Maze region)** — kill enemies, confirm only Phase 1–3 enemy types spawn. Confirm
   at least one `Timed` extraction opens after the wave window.
4. **PreBoss region** — confirm higher spawn density, no extractions available. Confirm kill quota
   or timer triggers the boss after the threshold is met.
5. **Boss fight** — confirm boss spawns at `BossSpawn` position, health bar appears, boss is
   attackable and can kill the player. If the boss has multiple phases, verify the HP-threshold
   branches fire. Confirm boss uses telegraphs before damaging attacks.
6. **Boss kill** — confirm `LevelExit` unlocks immediately after boss death.
7. **Level exit** — walk into `LevelExit`, confirm transition fires (Fade/Cut/Stairs per
   `transition_kind`). If this is the last level, confirm return-to-hub fires.
8. **Reward screen** — confirm reward calculation runs and loot appears. [VERIFY: confirm
   ExtractionManager triggers on level exit as well as mid-run extraction.]
9. **Godot output panel** — zero errors during a clean run from hub → boss kill → exit.

---

## Acceptance Criteria

A biome is **shippable** when all of the following are true:

- [ ] LDtk file conforms to `ldtk_schema.md` (importer doesn't reject it; `schema_version=1`; regions tile cleanly)
- [ ] 5 wave-phases playable end-to-end with correct enemy spawns
- [ ] All themed enemies behave correctly (correct stats, behavior, no physics edge cases)
- [ ] Boss spawns in the `Boss` region, fights correctly, and dies without crashing
- [ ] Boss kill unlocks `LevelExit`; exit transition fires
- [ ] Extraction types that should appear in this biome do appear and can be used
- [ ] Extracting mid-run or after boss kill returns to hub with correct reward
- [ ] `music_id` placeholder is set on every level (real audio comes later)
- [ ] Godot output panel shows zero errors during a clean run
- [ ] `LevelData.is_configured(id)` returns `true`

---

## Quick Reference — Files to Create or Edit

| Step | File | Action |
|------|------|--------|
| 1 | `assets/Maps/Levels/Level X - <Name>.ldtk` | Create (LDtk) |
| 2 | `data/factories/level_data.gd` | Add `LEVELS[X]` entry |
| 4 | `data/factories/enemies/<biome>_enemy_data.gd` | Create |
| 4 | `data/factories/enemies/enemy_registry.gd` | Register all enemy IDs |
| 4 | `scenes/enemies/<biome>_<name>.tscn` | Create (Godot MCP) |
| 6 | `data/factories/enemies/<boss_name>_data.gd` | Create |
| 6 | `scenes/enemies/<boss_name>.tscn` | Create (Godot MCP) |

## Cross-References

| Doc | When to read it |
|-----|----------------|
| [`ldtk_schema.md`](ldtk_schema.md) | Entity/enum/field contract; §9 for new-biome checklist |
| [`ldtk_workflow.md`](ldtk_workflow.md) | Operational level-authoring steps; biome asset map |
| [`engine_reference.md`](engine_reference.md) | Enemy data factory patterns; boss choreography; ability/effect vocabulary |
| [`core_framework_decisions.md`](core_framework_decisions.md) | Wave timing, enemy scaling formulas, phase thresholds |
