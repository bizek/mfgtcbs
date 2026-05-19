# Cave LDtk Audit — Level 1 (Caves)

**Date:** 2026-05-19
**Purpose:** Foundation document for the cave descent rebuild. Documents current state before modifications.

---

## 1. LDtk Project File

**Path:** `assets/Maps/Levels/Level 1 - Caves.ldtk`
**Format:** LDtk 1.5.3 with external levels enabled
**Default level size:** 648×1504 px (81×188 tiles at 8px grid)
**World layout:** Free (levels positioned independently)

### Levels

| Identifier | Dimensions | Status |
|---|---|---|
| `Level_0` | 648×1504 px (81×188 tiles) | Active — collision painted, cave tiles placed, zero entities |
| `Level_1` | 648×1504 px (81×188 tiles) | Partial — crypt tiles (673) placed, zero collision, zero entities |

### Tilesets

| Identifier | UID | Source | Grid |
|---|---|---|---|
| CavesTileset | 2 | Minifantasy_DeepCaves_v2.0 | 8px |
| CavesTilesetShadows | 424 | Minifantasy_DeepCaves_v2.0 | 8px |
| Crypt | 431 | Minifantasy_Crypt | 8px |
| Internal_Icons | 515 | Embedded | 16px |

### Layer Definitions (render order: top → bottom)

| Layer | Type | Grid | Tileset | Purpose |
|---|---|---|---|---|
| Entities | Entities | 8px | — | Gameplay entities (spawns, zones, markers) |
| CryptTiles | Tiles | 8px | Crypt | Manual crypt tile placement |
| CryptLayer | IntGrid | 8px | Crypt | Crypt collision autotiles |
| Collision | IntGrid | 8px | CavesTileset | Primary collision: Floor=1, Wall=2, Pit=3, LowCover=4, SpawnBlock=5 |
| Cave_Tiles | Tiles | 8px | CavesTileset | Manual cave tile placement |
| CavesBackground | Tiles | 8px | CavesTileset | Parallax background |

### Entity Definitions

| Entity | UID | Size | Fields |
|---|---|---|---|
| Level_Instructions | 529 | 8×8 | Level_Name, Monster_Spawns, Boss_Spawn, Player_Spawn_Pos, Boss_Spawn_Pos, Level_Exit_Pos, BiomeId, schema_version, Tags, Misc_Overrides, Misc_Notes |
| Extraction | 474 | 96×96 | kind (Timed/Guarded/Locked/Sacrifice), unlock_radius, channel_seconds |
| EnemySpawnZone | 479 | 64×64 (resizable) | phase, density, enemy_pool_override, min_distance_from_player |
| Obstacle | 484 | 16×16 | kind, collision_radius, scale, variant_index |
| Marker | 489 | 8×8 | tag (LootSpawn/EventTrigger/Cinematic), id, payload |
| Region | 493 | 256×256 (resizable, hollow) | kind (Maze/PreBoss/Boss/Safe), id, enter_seal, kill_quota, timer_seconds |

---

## 2. Level_0 — Current State

### Collision Layer Analysis

- **Grid:** 81 columns × 188 rows = 15,228 cells
- **Value 0 (unpainted → solid wall):** 4,433 cells (29.1%)
- **Value 1 (Floor → walkable):** 10,795 cells (70.9%)
- **Values 2-5:** 0 cells (not used)

### Structural Zones

| Zone | Y-Tile Range | Height (tiles) | Floor Width | Character |
|---|---|---|---|---|
| Entrance | 0–3 | 3 | Narrow | Spawn area |
| Upper Open | 3–52 | 49 | Wide (~70+ tiles/row) | Spacious exploration |
| Transition | 52–62 | 10 | Narrowing | Funnel into maze |
| **Maze** | **62–78** | **16** | **12–13 tiles/row** | **Narrow branching passages (1–2 tiles wide). BROKEN — player cannot fit.** |
| Lower Open | 78–185 | 107 | Wide | Large open chamber |
| Exit | 185–188 | 3 | Narrow | Level end |

### Entity Placements

**11 entities total in Level_0:**

| Entity | Grid Pos | Px Pos | Size | Key Fields |
|---|---|---|---|---|
| Level_Instructions | (2,13) | (16,104) | 8×8 | Player_Spawn_Pos=(8,9), Level_Exit_Pos=(62,174), No boss, Facing=Down |
| Extraction (Timed) | (69,174) | (556,1396) | 96×96 | unlock_radius=48, channel_seconds=3 |
| EnemySpawnZone | (31,22) | (248,176) | resizable | Phase1, Low density |
| EnemySpawnZone | (39,110) | (312,880) | resizable | Phase2, Medium density |
| EnemySpawnZone | (37,138) | (296,1104) | resizable | Phase3, High density |
| EnemySpawnZone | (36,162) | (288,1296) | resizable | Any phase, Medium density |
| Obstacle (Rock) | (15,14) | (120,112) | 16×16 | radius=18, scale=3 |
| Obstacle (Rock) | (15,9) | (120,72) | 16×16 | radius=18, scale=3 |
| Obstacle (Rock) | (20,9) | (160,72) | 16×16 | radius=18, scale=3 |
| Region (Maze) | (40,43) | center=(324,348) | 648×696 | Y: 0–696px (rows 0–87), no kill quota |
| Region (PreBoss) | (40,104) | center=(324,836) | 648×280 | Y: 696–976px (rows 87–122), kill_quota=20 |
| Region (Boss) | (40,154) | center=(324,1236) | 648×520 | Y: 976–1496px (rows 122–187), enter_seal=true |

**Region coverage:** Maze (0–696px) → PreBoss (696–976px) → Boss (976–1496px). Continuous top-to-bottom with ~8px gap at bottom.

**Player spawn:** Grid (8,9) = px (64,72) — top of level in Maze region.
**Level exit:** Grid (62,174) = px (496,1392) — bottom of level in Boss region.

### Tile Layers

- **Cave_Tiles:** 1,049 manual tile placements (provides visual floor/wall textures)
- **CryptTiles:** 0 (inactive)
- **CavesBackground:** 0 (no parallax)

---

## 3. Level_1 — Current State

- **Collision:** 100% unpainted (all solid wall — no walkable space)
- **CryptTiles:** 673 tile instances (crypt-themed visual decoration)
- **CryptLayer IntGrid:** All values = 1 (full crypt autotile coverage)
- **Entities:** None
- **Status:** Early crypt-themed prototype. Not playable.

---

## 4. LDtk Loader Capabilities

**File:** `scripts/systems/ldtk_loader.gd` (684 lines)
**Class:** `LdtkLoader extends Node2D`
**Status:** Fully functional, production-ready.

### What It Does

| Capability | Status |
|---|---|
| Parse LDtk JSON + external .ldtkl files | Working |
| Schema version validation (v1) | Working |
| Load all 6 entity types with full field parsing | Working |
| Create TileMapLayer children per tile/auto layer | Working |
| Z-index assignment per layer (Background=-5, FloorAuto=-3, WallsAuto=-1, etc.) | Working |
| Greedy 2D rectangle merging for collision (IntGrid Wall + unpainted cells) | Working |
| Spawn StaticBody2D per merged collision rectangle (layer 3) | Working |
| Obstacle collision (CircleShape2D, configurable radius) | Working |
| Marker signal emission (`marker_loaded`) | Working |
| Region validation (no gaps, tiled top-to-bottom) | Working |
| Extraction-inside-region validation | Working |
| Level metadata extraction (biome, music, loot pool, difficulty) | Working |
| Tileset texture path resolution (relative → res://) | Working |

### Constants

- `SCHEMA_VERSION = 1`
- `BIOME_TO_LEVEL_ID`: Caves=1, Catacombs=2, NightmareRealm=3, Threshold=4, Inferno=5
- IntGrid: FLOOR=1, WALL=2, PIT=3, LOWCOVER=4, SPAWNBLOCK=5
- Collision layer: 3

### Public API

```
load_level(ldtk_project_path: String, level_identifier: String) -> Dictionary
signal marker_loaded(tag, id, position, payload)
```

---

## 5. Supporting Scripts

| Script | Lines | Purpose | Descent Impact |
|---|---|---|---|
| `ldtk_level_director.gd` | 151 | Boss sealing, kill quotas, exit unlock via regions | **Replaced** — block progression replaces region system |
| `ldtk_exit_zone.gd` | 93 | Proximity extraction channeling at level exit | **Reusable** — bottom portal of descent |
| `ldtk_test_harness.gd` | 180 | Debug scene for loader testing | Unaffected |

---

## 6. Rebuild Readiness

### Prerequisites Met

- [x] LDtk loader is fully functional and can load arbitrary levels from the project
- [x] Entity definitions exist for all needed types (Marker for event anchors, EnemySpawnZone, Extraction)
- [x] `main_arena.gd` has clean LDtk setup path with fallback to procedural
- [x] Camera limit, spawn zone registration, and player positioning patterns established
- [x] Collision system handles unpainted-as-wall convention

### Prerequisites Needed

- [ ] Level_0 has zero entities — no baseline gameplay wiring to preserve (clean slate for descent)
- [ ] Block variant levels must be authored with entities (Level_Instructions, spawn zones, markers)
- [ ] `main_arena.gd` needs new `_setup_ldtk_descent()` path alongside existing `_setup_ldtk_level()`
- [ ] Existing `LdtkLevelDirector` region logic does not apply to block-based descent — skip in descent mode
- [ ] Block stitching requires calling `LdtkLoader.load_level()` multiple times with Y-position offsets per loader instance

### Risk: Multiple LdtkLoader Instances

Each LdtkLoader creates child nodes (TileMapLayers, StaticBody2Ds). With 10-15 blocks:
- ~15 TileMapLayer nodes per active tile layer per block = ~45-90 total TileMapLayers
- ~15 sets of collision StaticBody2Ds (count depends on wall complexity)
- Performance must be validated early in Phase 2

---

## 7. Maze Area Detail

The maze (rows 62-78) has these characteristics:
- Floor cells drop from ~70/row (open area above) to ~12-13/row
- Passages are 1-2 tiles wide (8-16px) — player collision shape is larger than this
- Branching layout creates dead-end pockets
- No entities guide the player through — pure geometry puzzle that doesn't work

**Action:** Task 1.2 will clear rows 52-79 (transition + maze) to open floor, leaving upper open area and lower open area as one continuous space.

---

## Post-Cleanup State (Task 1.2)

**Date:** 2026-05-19

### Changes Made

1. **Collision IntGrid (rows 52-79):** All cells set to Floor (1), except 2-cell wall border on each edge (columns 0-1 and 79-80 remain Wall/0). This gives 77 floor tiles per row across 28 rows.
2. **Cave_Tiles layer:** Removed 86 manual tile placements that were in the maze area (Y 416-640px). These tiles were placed to match the old narrow passages and would look wrong over open floor.
3. **Auto-layer tiles:** The Collision layer's 10,795 auto-rule tiles will be regenerated by LDtk when the file is opened. They will automatically paint correct floor/wall visuals for the new open geometry.

### What Remains

- **Upper open area (rows 3-51):** Untouched, wide exploratory space
- **Cleared zone (rows 52-79):** Now fully open floor with wall borders — visually WIP, ready for block system
- **Lower open area (rows 80-185):** Untouched, large chamber
- **All 11 entities:** Untouched (Level_Instructions, Extraction, 4 SpawnZones, 3 Obstacles, 3 Regions)
- **Regions still defined:** Maze/PreBoss/Boss regions persist as entities but the Maze region's geometry is now open. These regions will be replaced by the block system.

### Note on LDtk Re-save

The file was modified via Python JSON serialization with tab indentation. When LDtk opens and re-saves this file, it will:
1. Regenerate all auto-layer tiles from the IntGrid values
2. Reformat the JSON to LDtk's native compact style
3. File size will normalize

The file is structurally valid JSON and the loader will parse it correctly.
