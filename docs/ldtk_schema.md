# LDtk Schema — Extraction Survivors

**Schema Version: 1** — bump this header when you make a breaking change. The importer reads
each level's `schema_version` field (§5) and refuses to load mismatches.

The contract between LDtk-authored levels and the Godot-side importer (`LdtkLoader`, TBD).
Every level must conform to this schema. New biomes copy this schema verbatim — do not invent identifiers.

> **Why this matters:** identifiers in LDtk are matched by **exact string** by the importer.
> Renaming an entity from `EnemySpawnZone` to `SpawnZone` breaks every level you've already authored.
> Treat this file as load-bearing.

---

## 1. Project Settings

| Setting | Value | Notes |
|---|---|---|
| `defaultGridSize` | `8` | All tilesets are 8×8. Match this on every layer. |
| `worldLayout` | `Free` | Each level is independent; no auto-arrangement. |
| `externalLevels` | `true` | Each level saves to its own `.ldtkl` (cleaner git diffs). |
| `identifierStyle` | `Capitalize` | `PlayerSpawn`, not `player_spawn`. |
| `defaultLevelWidth` / `Height` | `648` / `1504` | Tall vertical strip — see §1.1 for level structure. |

> **Authoring rule:** keep one `.ldtk` project file **per biome** (e.g. `Level 1 - Caves.ldtk`,
> `Level 2 - Catacombs.ldtk`, etc.) and add multiple levels inside it (`Level_0`, `Level_1`, …).
> Each level inside a biome shares the biome's tilesets and IntGrid conventions.

### 1.1 Level Structure (vertical strip)

Levels are **tall vertical strips** the player descends through. The camera follows the player
down. A typical level reads top → bottom as:

```
┌─────────────────────────┐  y = 0          ← player spawns here
│                         │
│       MAZE AREA         │  Region: Maze
│   (winding corridors,   │  - small/medium fights, environmental hazards
│    branching paths,     │  - one or more Extraction points (early-leave option)
│    loot pickups)        │  - density: low/medium
│                         │
├─────────────────────────┤  Region: PreBoss
│   PRE-BOSS GAUNTLET     │  - opens up into a wider arena
│  (sustained horde, no   │  - high-density EnemySpawnZones, no early extractions
│   safe corner, builds   │  - kill quota or timer triggers boss spawn
│   pressure to boss)     │
│                         │
├─────────────────────────┤  Region: Boss
│      BOSS ARENA         │  - BossSpawn entity here
│   (final fight room,    │  - LevelExit appears after boss death
│    sealed once entered) │  - one Extraction here as guaranteed extract on victory
│                         │
└─────────────────────────┘  y = pxHei      ← LevelExit unlocks here on boss kill
```

Region boundaries are drawn with `Region` entities (see §6). The importer reads them and tells
`EnemySpawnManager` / `GameManager` which gameplay rules apply where.

> **Why vertical:** the player is always pushing forward (downward). Stopping = horde catches up.
> Compare to traditional arena survivor where you orbit the center.

---

## 2. IntGrid Values (collision + zoning)

Every biome's primary IntGrid layer (named `Collision`) uses these values exactly:

| Value | Identifier | Color | Meaning |
|---|---|---|---|
| `0` | *(empty)* | — | **Solid wall** — unpainted cells are treated as solid cave wall by the importer. Spawns StaticBody2D on collision layer 3. Paint `Floor` over any cell you want the player to walk on. |
| `1` | `Floor` | `#3A6B3A` | Walkable. No collider spawned. |
| `2` | `Wall` | `#3F2A1A` | Explicit solid wall. Also spawns StaticBody2D on collision layer 3. Use when you need a wall inside a floor-painted area. |
| `3` | `Pit` | `#1A1A2A` | Visual void. No collider (future: enemies pathfind around it). |
| `4` | `LowCover` | `#7A5A3A` | Solid for enemies, walkable for player projectiles (future). |
| `5` | `SpawnBlock` | `#552255` | Walkable, but `EnemySpawnManager` won't spawn on top of it. |

> **Authoring workflow:** paint `Floor` (value 1) everywhere you want the player to walk.
> Leave everything else unpainted — the importer treats unpainted cells as solid walls automatically.
> You rarely need to explicitly paint `Wall` (value 2) unless you want an interior wall inside a floor area.

> Identifiers must be exact. The importer keys off them, not the numeric value.
> Numeric value is just for fast painting in the LDtk UI.

### 2.1 `PropCollision` IntGrid (optional, paint-to-add)

A separate, optional IntGrid layer for adding collision over hand-painted props or `Cave_Tiles`
features when you authored visuals on tile layers instead of the `Collision` IntGrid. Inverse
polarity from `Collision`: **only painted (nonzero) cells are solid**; unpainted cells are ignored.

| Value | Identifier | Meaning |
|---|---|---|
| `1` | `Solid` | Spawns a `StaticBody2D` collider (collision layer 3 — blocks player + enemies). |

> The importer (`LdtkLoader._build_paint_collision`) greedy-merges painted cells into rectangles,
> exactly like the `Collision` wall builder. The layer renders nothing in-game. Absent on a level =
> no extra colliders (no warning).

### 2.2 Descent block edges — the ENTRY block caps the stack, inner blocks must not

Descent blocks are 81×60 cells (648×480 px) and stack vertically, so the `Collision` edges carry a
convention that is invisible in any single block and only makes sense across the whole stack:

| Block | Left/right columns | Top row (`cy=0`) | Bottom row (`cy=59`) | Void cells |
|---|---|---|---|---|
| **Entry** (`Block_*_00_Entry`) | solid | **solid — this is the world's ceiling** | open | **199** = 81 + 2×59 |
| **Inner / Merchant / Portal** | solid | **open — this is the seam to the block above** | open | **120** = 2×60 |

Only the entry block caps the top. Every other block leaves row 0 open, because that row is the
join to the block above — cap it and you wall off the descent. Conversely, if the *entry* block
leaves row 0 open there is nothing above y=0 at all: enemies shove the player straight out of the
world (measured at y=-17.6 before this was restored), and the camera stays clamped at `limit_top=0`
while the player drifts off the top of the screen.

The bottom row is open on every block, entry included. Nothing physically caps the bottom of the
stack — the Portal and its exit zone sit ~24px above `total_height`. That asymmetry is the shipped
behaviour and extraction works, but it has not been probed for whether a player can be pushed
below the last row.

**Known deviations (audited 2026-08-15, all 37 blocks — 35 conform):**

| Block | State | Consequence |
|---|---|---|
| `Block_Caves_09_Portal` | void=122, not 120 | Two extra corner cells. Harmless. |
| `Block_Warp_00_Entry` | void=4860 — the entire block is unpainted, i.e. wholly solid | No walkable ground at all. Long-standing; see the FlowField notes. |

`Block_NMRealm_00_Entry` was the third: it had row 0 open and no `Level_Instructions` at
all, so it carried both halves of the Catacombs failure into a biome nobody had played.
Brought into conformance 2026-08-15 — row 0 capped (void 120 → 199) and a spawn entity
added at cell (48,8). Its spawn cell is **not** the (39,14) the Caves and Crypt entries
share: that cell is inside a wall formation here. Measure clearance, don't copy the
number.

> **The failure this convention prevents, and why it survived an authoring pass.** `Block_Crypt_00_Entry`
> shipped with rows 0–29 unpainted. Per §2 that is *solid*, so the loader merged the block's whole top
> half into one 648×240 collider — with the block's own `Player_Spawn_Pos` inside it. Every static
> check passed: the level loaded, the stack built, waves and the boss were correct, and the block's
> art (a full `CryptLayer` floor flood plus the entrance arch) showed a walkable hall. Only the
> collision disagreed, and only at runtime. **Unpainted is solid — including in the half of the block
> you never got around to painting.** After changing any `Collision` layer, check the value counts
> against the table above; the two numbers 199 and 120 are the whole contract.

---

## 3. Layers (LDtk list order: top entry rendered last / on top)

Every biome uses **this exact stack**, from top to bottom in LDtk's layer panel.
LDtk renders bottom-up, so `Background` paints first and `Entities` sit on top of everything.

| # | Identifier | Type | Purpose |
|---|---|---|---|
| 1 | `Entities` | Entities | All gameplay markers (spawn, extraction, obstacles). |
| 2 | `Collision` | IntGrid | Walls, pits, cover. See §2. No tileset render. |
| – | `PropCollision` | IntGrid | **Optional, paint-to-add.** Any nonzero cell → solid collider. Inverse polarity from `Collision` (unpainted = nothing). Use to add collision over hand-painted props / `Cave_Tiles` features without floor-flooding `Collision`. Invisible in-game. See §2. |
| 3 | `Decoration` | Tiles | Hand-placed props on top of the floor (chests, bones, foliage). |
| 4 | `WallsAuto` | AutoLayer (over Collision) | Auto-tiled walls driven by IntGrid value `2`. |
| 5 | `FloorAuto` | AutoLayer (over Collision) | Auto-tiled floor driven by IntGrid value `1`. |
| 6 | `Background` | Tiles | Solid base fill (single tile flooded across the whole level). |

> **Why this order:** Entities on top so they're visible while editing. AutoLayers reference the
> Collision IntGrid below them. Background is the bottom-most catch-all so any unpainted cell
> still renders something.

---

## 4. Enums

Defined once in the `.ldtk` project, reused by entity field dropdowns. **Add new values to the
end of the list** — never reorder, since LDtk stores enum index in saves.

### `ExtractionType`
- `Timed` — opens after wave window. Default extraction.
- `Guarded` — guardian spawns at run start; clear it to use.
- `Locked` — requires Keystone item to unlock.
- `Sacrifice` — costs one carried loot item to use; always available.

### `SpawnPhase`
- `Phase1`, `Phase2`, `Phase3`, `Phase4`, `Phase5` — match the 5-phase extraction loop.
- `Any` — eligible during any phase.

### `SpawnDensity`
- `Low`, `Medium`, `High` — relative spawn weight within a phase.

### `BiomeId`
- `Caves`, `Catacombs`, `NightmareRealm`, `Threshold`, `Inferno`
- The importer maps these by name → integer key in `LevelData.LEVELS`. Mapping table lives in `LdtkLoader.BIOME_TO_LEVEL_ID` (TBD): `Caves=1, Catacombs=2, NightmareRealm=3, Threshold=4, Inferno=5`.

### `ObstacleKind`
- `Rock`, `Crate`, `Pillar`, `Bones`, `Tree`, `Stalagmite` — selects which sprite/footprint to use.

### `MarkerTag`
- `LootSpawn`, `EventTrigger`, `Cinematic` — generic tagged position for scripted use.

### `RegionKind`
- `Maze` — winding top section. Spawn rate low–medium, extractions allowed, player can backtrack.
- `PreBoss` — wider arena. Sustained horde. Kill quota or timer triggers boss spawn. No new extractions open here.
- `Boss` — sealed boss room. Walls close behind the player on entry (importer spawns invisible barriers). Boss spawns from `BossSpawn`. `LevelExit` unlocks on boss death.
- `Safe` — optional. Low/no spawn rate. Use for vendor rooms, lore beats, breathers between sections.

### `BossId`
- `CaveTroll`, `CryptLich`, `NightmareKing`, `ThresholdGuardian`, `InfernoLord` — one per biome; extend as bosses are designed.

---

## 5. Level Fields (set per `.ldtkl`)

Only two fields live as LDtk Level Fields — everything else moves to the
`Level_Instructions` entity (§6). Reason: the importer needs these two values
*before* it parses any entities (to route tilesets and reject bad versions).

| Field | Type | Required | Notes |
|---|---|---|---|
| `biome` | `BiomeId` enum | yes | Drives tileset, music, default wave composition lookup. |
| `schema_version` | Int | yes | Must equal the schema's current version (header at top of this file). Importer rejects mismatches before doing any work. Current version: **1**. |

> **Wave composition precedence** (highest wins): `EnemySpawnZone.enemy_pool_override` > `Level_Instructions.Monster_Spawns` > `LevelData.LEVELS[biome].wave_composition` (biome default).

---

## 6. Entities

Every entity below must exist in the project's `defs.entities`. Authoring uses the entity tool;
the importer matches **by `identifier`** when spawning Godot scenes/nodes.

> **Pivot rule:** All gameplay entities pivot at `(0.5, 0.5)` — center. The one exception is
> `Obstacle`, which pivots at `(0.5, 1.0)` (bottom-center) so the sprite "sits on" the
> tile-grid cell the author clicked.

---

### `Level_Instructions` (one per level — REQUIRED)

Per-level metadata bundle + folded singletons. Hans's pattern, extended: instead of
scattering metadata across the LDtk Level Properties panel AND maintaining 3 separate
singleton entities (PlayerSpawn / BossSpawn / LevelExit), one entity holds it all.
Easier to extend, easier to find, and gives Claude one definitive spot to read intent.

| Property | Value |
|---|---|
| Size | 8×8 |
| Color | `#00FF00` (bright green — distinct from gameplay markers) |
| Pivot | top-left `(0, 0)` (matches Hans's convention) |
| Tags | none |
| Max per level | unlimited (importer expects exactly 1 — flagged as warning if 0 or >1) |

#### Core metadata (Hans's 7)

| Field | Type | Notes |
|---|---|---|
| `Level_Name` | String | Display name (e.g. `"Goblin Stockade"`). |
| `Monster_Spawns` | String | Comma-separated enemy IDs the spawn pool draws from. Empty = biome default. |
| `Boss_Spawn` | String | Boss enemy ID (e.g. `"cave_troll"`). Empty = no boss on this level. |
| `Loot_Pool` | String | Loot pool identifier. Empty = biome default. |
| `Room_Distance_Tri` | Int array | Distance markers for room transitions / pacing tuning. |
| `Misc_Overrides` | String array | Free-form `key=value` strings. See "Known keys" below. |
| `Misc_Notes` | Text array (multi-line) | Design intent, instructions for Claude, hints. **Drop level descriptions here instead of in chat — they persist.** |

#### Game-specific metadata

| Field | Type | Notes |
|---|---|---|
| `Music_Id` | String | Audio bus key. Empty = biome default. |
| `Recommended_Player_Level` | Int | For hub UI gating/sorting. Default `1`. |
| `Tags` | String array | Free-form labels for `/level` routing and meta-progression filters (e.g. `"tutorial"`, `"boss-rush"`, `"shortcut"`). |

#### Folded singletons (Point fields)

Click a cell on the level to set each Point field. LDtk renders a marker with a line
back to the parent `Level_Instructions` entity.

| Field | Type | Notes |
|---|---|---|
| `Player_Spawn_Pos` | Point | **REQUIRED.** Where the player appears on level enter. |
| `Player_Facing` | `Facing` enum | Initial facing direction. Default `Down`. |
| `Boss_Spawn_Pos` | Point | Where the boss appears once PreBoss requirements are met. Set if `Boss_Spawn` is non-empty. Must lie inside a `Boss` region. |
| `Boss_Intro_Delay` | Float | Seconds between boss appearing and aggression. Default `1.5`. |
| `Boss_Camera_Zoom` | Float | Camera zoom override during boss fight. `1.0` = no change. |
| `Level_Exit_Pos` | Point | **REQUIRED.** Locked until boss dies (or immediately unlocked if `Boss_Spawn` is empty). |
| `Next_Level_Id` | String | LDtk identifier of the next level (e.g. `"Level_1"`). Empty = end of biome → return to hub. |
| `Exit_Transition` | `TransitionKind` enum | Visual transition. Default `Fade`. |

#### Known `Misc_Overrides` keys

Free-form key=value strings. Importer parses these and applies known keys; unknown keys
log a warning so typos don't fail silently.

| Key | Type | Effect |
|---|---|---|
| `difficulty` | Float | Multiplier applied to all enemy stats on this level. Default `1.0`. |
| `phase_timer_<N>` | Float | Override duration of phase N (1–5) in seconds. Empty = use core_framework_decisions defaults. |
| `seed` | Int | RNG seed for any procedural elements left in the level. |
| `xp_multiplier` | Float | XP gain multiplier for this level. Default `1.0`. |
| `extraction_reward_multiplier` | Float | Loot reward multiplier for extractions on this level. Default `1.0`. |

> **Authoring tip:** when describing a level to Claude, drop your description into
> `Misc_Notes` instead of pasting in chat. Persists in the file, future-Claude reads
> it without you re-explaining.

---

### `Extraction` (0–4 per level)

Optional. A level with no `Extraction` entities forces the player through the boss kill →
`LevelExit` flow. Recommended: at least one `Timed` extraction in the `Maze` region as an
early-leave option.

| Property | Value |
|---|---|
| Size | 96×96 (matches in-game marker footprint) |
| Color | `#3FFF55` (timed) — drawn as filled square in editor |
| Tags | `gameplay`, `extraction` |
| Max per level | 4 (one of each `ExtractionType`) |

| Field | Type | Default | Notes |
|---|---|---|---|
| `kind` | `ExtractionType` enum | `Timed` | Drives marker color, behavior, and unlock conditions. |
| `unlock_radius` | Float | `48.0` | Player must be within this radius to channel. |
| `channel_seconds` | Float | `3.0` | Time to extract once channeling starts. |
| `notes` | String | `""` | Author-only — not read by importer. |

---

### `EnemySpawnZone` (0–N per level)

A rectangular region that `EnemySpawnManager` may spawn enemies inside, weighted by phase.

| Property | Value |
|---|---|
| Size | Resizable rectangle (default 64×64) |
| Color | `#CC2222` with `0.3` alpha |
| Tags | `gameplay`, `spawn` |
| Resizable | YES |

| Field | Type | Default | Notes |
|---|---|---|---|
| `phase` | `SpawnPhase` enum | `Any` | When this zone is active. |
| `density` | `SpawnDensity` enum | `Medium` | Relative weight vs. other active zones. |
| `enemy_pool_override` | Multi-line String (JSON) | `""` | Optional per-zone enemy weights. Empty = level-wide default. Format: `{"cave_fodder":0.7,"cave_bat":0.3}` |
| `min_distance_from_player` | Float | `300.0` | Suppress spawns inside this radius from player. |

> Multiple zones can overlap in phase — all eligible zones contribute to the spawn pool.

---

### `Obstacle` (0–N per level)

A static collidable prop. The importer instantiates a sprite + StaticBody2D.

| Property | Value |
|---|---|
| Size | 16×16 (visual hint; actual sprite size determined by `kind`) |
| Color | `#8A6A4A` |
| Tags | `gameplay`, `static` |
| Resizable | NO |

| Field | Type | Default | Notes |
|---|---|---|---|
| `kind` | `ObstacleKind` enum | `Rock` | Selects sprite from biome's prop sheet (mapping in `LdtkObstacleData`). |
| `variant_index` | Int | `0` | Which sprite variant within the kind (0 = first). `-1` = random per-load. |
| `collision_radius` | Float | `18.0` | Circle collider radius. `0` = no collider (decorative). |
| `scale` | Float | `3.0` | Sprite scale (matches existing 3× obstacle convention). |

---

### `Marker` (0–N per level)

Generic tagged position for systems that need to find specific points. Read by name, not by type.

| Property | Value |
|---|---|
| Size | 8×8 |
| Color | `#FFCC22` |
| Tags | `gameplay`, `marker` |

| Field | Type | Default | Notes |
|---|---|---|---|
| `tag` | `MarkerTag` enum | `LootSpawn` | Categorizes the marker for system lookup. |
| `id` | String | `""` | Unique key within the level (e.g. `"cinematic_intro_camera"`). |
| `payload` | Multi-line String | `""` | Free-form data passed to whatever system reads this marker. |

> No `Decoration` entity exists. Use the `Decoration` **tile layer** (§3) for purely visual props —
> entities are reserved for things the importer needs to read fields from at runtime.

---

### `Region` (1–N per level — REQUIRED for vertical levels)

Rectangular zone that tags an area as Maze / PreBoss / Boss / Safe (see §4 `RegionKind`).
Drives spawn rules, extraction availability, camera framing, and boss-room sealing.

| Property | Value |
|---|---|
| Size | Resizable rectangle (default 256×256) |
| Color | varies by `kind` (Maze=cyan, PreBoss=orange, Boss=red, Safe=green) at `0.2` alpha |
| Tags | `gameplay`, `region` |
| Resizable | YES |

| Field | Type | Default | Notes |
|---|---|---|---|
| `kind` | `RegionKind` enum | `Maze` | Drives gameplay rules — see §4. |
| `id` | String | `""` | Optional unique key (e.g. `"east_corridor"`) for logs and scripted refs. |
| `enter_seal` | Bool | `false` | If true (typically for `Boss`), importer spawns invisible walls behind the player on first entry. |
| `kill_quota` | Int | `0` | For `PreBoss`: # of kills inside region before boss spawns. `0` = no quota. |
| `timer_seconds` | Float | `0.0` | For `PreBoss`: alternative to quota — boss spawns after this much time inside region. `0` = disabled. |

> Regions **must tile the level top-to-bottom with no gaps**. The importer asserts this.
> Overlapping regions are an error. Use a single `Boss` region per level.

---

> **Note on PlayerSpawn / BossSpawn / LevelExit:** these aren't standalone entities.
> They're folded into `Level_Instructions` as Point fields (see §6 above). This keeps
> all level-singleton config in one place.

---

## 7. Folder & File Conventions

```
assets/Maps/Levels/
├── Level 1 - Caves.ldtk            ← biome project
├── Level 1 - Caves/                ← external level folder
│   ├── Level_0.ldtkl
│   └── Level_1.ldtkl
├── Level 2 - Catacombs.ldtk
└── Level 2 - Catacombs/
    └── ...
```

- One `.ldtk` per biome.
- Level folder name **must** match the `.ldtk` filename (LDtk does this automatically).
- Tilesets stay in `assets/minifantasy/<pack>/...` — referenced by relative path from the `.ldtk`.

---

## 8. Importer Contract (for the Godot side)

When the importer (TBD) loads a `.ldtkl`, it must:

1. **Read level fields** → resolve `biome` → look up floor texture and default wave composition. Reject if `schema_version` doesn't match the importer's expected version.
2. **Locate the `Level_Instructions` entity** (exactly one expected). Read all 18 fields. Warn if missing or duplicated.
3. **Render layers in order** (Background → FloorAuto → WallsAuto → Decoration → Entities) — Entities layer becomes Godot nodes, the rest become `TileMapLayer` nodes.
4. **Iterate `Collision` IntGrid** → spawn `StaticBody2D` per `Wall` cell (merged into rectangles where adjacent for perf). If a `PropCollision` IntGrid layer is present, also spawn a merged `StaticBody2D` per nonzero cell (paint-to-add prop/feature collision — see §2.1).
5. **Apply Level_Instructions singletons:**
   - `Player_Spawn_Pos` + `Player_Facing` → set `Player` node position and facing.
   - `Boss_Spawn_Pos` + `Boss_Spawn` (id) + `Boss_Intro_Delay` + `Boss_Camera_Zoom` → register with `LevelDirector`; deferred until PreBoss requirements met. Skip if `Boss_Spawn` is empty.
   - `Level_Exit_Pos` + `Next_Level_Id` + `Exit_Transition` → spawn locked exit; `EventBus.boss_killed` listener unlocks it (or unlock immediately if `Boss_Spawn` is empty).
6. **Iterate the rest of the `Entities` layer:**
   - `Region` → register rect + kind with `LevelDirector`; enforces top-to-bottom no-gap rule.
   - `Extraction` → instantiate marker per `kind`. Reject any not inside a `Maze` or `Boss` region.
   - `EnemySpawnZone` → register region with `EnemySpawnManager` with phase/density weights.
   - `Obstacle` → spawn sprite + collider per `kind` and `variant_index`.
   - `Marker` → emit signal `EventBus.ldtk_marker_loaded(tag, id, position, payload)`.
7. **Apply Level_Instructions config:**
   - `Music_Id` → switch audio bus.
   - `Monster_Spawns` (if non-empty) → patch `EnemySpawnManager` enemy pool.
   - `Loot_Pool` (if non-empty) → patch `LootManager` pool.
   - `Misc_Overrides` → parse `key=value` strings; apply known keys (`difficulty`, `phase_timer_<N>`, `seed`, `xp_multiplier`, `extraction_reward_multiplier`); warn on unknown keys.
8. **LevelDirector wiring** — connects `EventBus.enemy_died` (for `kill_quota`) and a timer
   (for `timer_seconds`) per `PreBoss` region; emits `boss_should_spawn` when triggered.

---

## 9. Adding a New Biome — Checklist

1. Copy `Level 1 - Caves.ldtk` → `Level X - <Name>.ldtk`. Delete its existing levels.
2. Open in LDtk → swap tilesets to the new biome's pack (keep identifiers `<Biome>Tileset`, `<Biome>Tiles`, etc.).
3. Verify all 6 layers from §3 still exist; relink AutoLayers to the new tileset.
4. Confirm IntGrid values from §2 still exist on the `Collision` layer.
   - **If the biome ships descent blocks, check the edges against §2.2 before anything else.**
     Entry block: row 0 solid, void=199. Every other block: row 0 open, void=120. Getting this
     wrong produces a biome that loads, builds and spawns correctly and is still unplayable.
5. Add a new value to the `BiomeId` enum (append, never reorder).
6. Add a stub entry to `data/factories/level_data.gd` `LEVELS` matching the new `BiomeId`.
7. Create your first level. Set `biome` and `schema_version` level fields. Drop one `Level_Instructions` and fill out:
   - `Level_Name`, `Monster_Spawns`, `Boss_Spawn`, `Loot_Pool`, `Music_Id`, `Recommended_Player_Level`, `Tags`
   - Click `Player_Spawn_Pos` → click a cell at the top of the level
   - Click `Boss_Spawn_Pos` → click a cell inside the Boss region (skip if no boss)
   - Click `Level_Exit_Pos` → click a cell at the bottom of the Boss region
   - Set `Next_Level_Id` (e.g. `"Level_1"`) or leave empty for end-of-biome
   - Add `Misc_Notes` describing design intent and any Claude-facing instructions
8. Then drop spatial entities:
   - `Region`s tiling top-to-bottom (`Maze` → `PreBoss` → `Boss`) with no gaps
   - At least one `Extraction` in the `Maze` (early-leave option)
   - `EnemySpawnZone`s inside each region (phase/density tuned per region)
   - `Obstacle`s and `Marker`s as needed
9. Save. Run the game with `GameManager.debug_load_level(<biome_id>, <level_identifier>)` (TBD) to test.

---

## 10. What Lives Where (cheat sheet)

| You want to… | Edit |
|---|---|
| Add a new wave composition for caves | `data/factories/level_data.gd` (or per-level `Monster_Spawns` field on `Level_Instructions` in LDtk) |
| Add a new enemy variant | `data/factories/enemy_data.gd` + `scenes/enemies/<name>.tscn` |
| Add a new obstacle kind | This file (§6 `ObstacleKind`) + `LdtkObstacleData` (TBD) sprite mapping |
| Add a new boss | This file (§4 `BossId`) + boss scene + `BossRegistry` (TBD) |
| Add a new biome | This file (§9) + `LevelData.LEVELS` |
| Change collision behavior of `Wall` | This file (§2) + `LdtkLoader` collision builder (TBD) |
| Add collision over a hand-painted prop / tile feature | Paint `Solid` on the `PropCollision` IntGrid layer (§2.1) — no code change |
| Add a new entity type | This file (§6) + `LdtkLoader` entity dispatch (TBD) |
| Tweak boss spawn trigger | Set `kill_quota` / `timer_seconds` on the `PreBoss` `Region` in LDtk |
| Add a new Level_Instructions field | This file (§6 Level_Instructions) + `tools/apply_ldtk_schema.py` + rerun on every biome `.ldtk` |
| Tweak per-level difficulty / XP / loot multipliers | Add a `key=value` entry to `Misc_Overrides` on the level's `Level_Instructions` |
| Tell Claude about a level's design intent | Add a `Misc_Notes` entry on the level's `Level_Instructions` |
