# LDtk Authoring Workflow

The day-to-day guide for designing levels in LDtk. Companion to [`ldtk_schema.md`](ldtk_schema.md)
(the contract) — this doc covers **how to use it**.

Read order if you've never authored a level here: `ldtk_schema.md` first, then this.

---

## Quick Reference — Where Things Live

```
assets/Maps/Levels/                    ← all biome projects live here
├── Level 1 - Caves.ldtk              ← biome 1 (Caves)
│   └── Level 1 - Caves/              ← external level files
│       ├── Level_0.ldtkl
│       └── Level_1.ldtkl
├── Level 2 - Catacombs.ldtk          ← biome 2 (TBD)
│   └── ...
└── Level X - <Biome>.ldtk            ← one project per biome

assets/minifantasy/                    ← all source-art tilesets/sprites
├── Minifantasy_DeepCaves_v2.0/
│   └── Minifantasy_DeepCaves_Assets/
│       └── Tileset/
│           ├── CavesTileset.png        ← Caves wall+floor tiles
│           └── CavesTilesetShadows.png
├── Minifantasy_Crypt_Of_The_Forgotten_v1.0/
│   └── ... /Tileset/Tileset.png        ← Catacombs tiles
├── Minifantasy_Hellscape_v1.0/
│   └── ... /Tileset/                    ← Inferno tiles
└── Minifantasy_Plants_&_Foliage_v1.0/
    └── ... /Plains_And_Forests/         ← organic decoration

docs/
├── ldtk_schema.md                     ← THE CONTRACT — read first
└── ldtk_workflow.md                   ← THIS FILE — daily reference

scripts/systems/
└── ldtk_loader.gd                     ← (TBD) Godot-side importer

tools/
└── apply_ldtk_schema.py               ← schema bootstrapper for new biome files
```

---

## Biome Asset Map

When you author a level for a biome, these are the assets the importer expects to find.
**Paths are relative to project root.** All tilesets are 8×8 grid.

| Biome | Tileset(s) | Floor preview | Prop sheet | Notes |
|-------|-----------|---------------|-----------|-------|
| **Caves** | `assets/minifantasy/Minifantasy_DeepCaves_v2.0/Minifantasy_DeepCaves_Assets/Tileset/CavesTileset.png` (+ `CavesTilesetShadows.png` overlay) | `Premade_h-floor.png` in same `PremadeScene/SeparateLayers/` folder | `Minifantasy_ForgottenPlains/props/Minifantasy_ForgottenPlainsProps.png` for rocks | Existing `.ldtk` already wired. |
| **Catacombs** | `assets/minifantasy/Minifantasy_Crypt_Of_The_Forgotten_v1.0/Minifantasy_Crypt_Of_The_Forgotten_Assets/Tileset/Tileset.png` | (TBD) | (TBD) | Auto-rules already authored on `CryptLayer` in current file — should move to a fresh `Level 2 - Catacombs.ldtk`. |
| **NightmareRealm** | TBD — need source pack pick | — | — | Stub. |
| **Threshold** | TBD | — | — | Stub. |
| **Inferno** | `assets/minifantasy/Minifantasy_Hellscape_v1.0/Minifantasy_Hellscape_Assets/Tileset/` | `_Premade Scene/Separate Layers/Premade_l-ground.png` | TBD | Tileset on disk; no .ldtk yet. |

> **When picking a tileset for a new biome:** prefer Minifantasy packs that already have a
> `Premade Scene` directory — those include floor textures we can flood the `Background`
> tile layer with as a baseline.

---

## Authoring a New Level (existing biome)

You're adding a new level inside a biome that already has a `.ldtk` project file
(e.g. adding `Level_2` to `Level 1 - Caves.ldtk`).

1. **Open** the biome's `.ldtk` in LDtk.
2. **World view** (top-right toggle) → click an empty area near the existing levels →
   **New level**. Drag it next to the others.
3. Set level **size** to `648 × 1504` (default, vertical strip).
4. Set **Level properties** (right panel) — only two fields here:
   - `biome` → matches the file's biome (e.g. `Caves`)
   - `schema_version` → **must equal `1`** (importer rejects mismatches)
5. **Layer order, top-to-bottom** (LDtk panel = render order, top = on top):
   - `Entities` ← place gameplay markers here
   - `Collision` ← paint Wall/Pit/etc. with the IntGrid tool
   - `Decoration` ← hand-place props (chests, bones)
   - `WallsAuto` ← driven by Collision IntGrid value `Wall=2`
   - `FloorAuto` ← driven by Collision IntGrid value `Floor=1`
   - `Background` ← single-tile flood for the base color
6. **Paint the level shape** — start on `Collision`. Paint `Wall=2` for solid walls,
   leave `Floor=1` (or use eraser) for walkable. The `WallsAuto` and `FloorAuto`
   layers will auto-render the right tiles.
7. **Drop ONE `Level_Instructions` entity** (anywhere on the level — top-left corner is conventional). Fill out:
   - Core: `Level_Name`, `Monster_Spawns`, `Boss_Spawn`, `Loot_Pool`
   - Game: `Music_Id`, `Recommended_Player_Level`, `Tags`
   - Player: click `Player_Spawn_Pos` → click a cell at the top of the level. Set `Player_Facing` to `Down`.
   - Boss: click `Boss_Spawn_Pos` → click a cell inside the Boss region. Set `Boss_Intro_Delay`, `Boss_Camera_Zoom` if needed. Skip these if `Boss_Spawn` is empty.
   - Exit: click `Level_Exit_Pos` → click a cell at the bottom of the Boss region. Set `Next_Level_Id` (e.g. `"Level_1"`) or leave empty for end-of-biome. Set `Exit_Transition` (default `Fade`).
   - Notes: drop design intent + Claude instructions into `Misc_Notes` (multi-line, multi-entry).
   - Overrides: any per-level tweaks go into `Misc_Overrides` as `key=value` strings (e.g. `difficulty=1.5`).
8. **Place regions** on the `Entities` layer:
   - One `Region(kind=Maze)` covering the top section.
   - One `Region(kind=PreBoss)` below it. Set `kill_quota` (e.g. 30) or `timer_seconds` (e.g. 45).
   - One `Region(kind=Boss)` at the bottom. Set `enter_seal=true`.
   - **Regions must tile top-to-bottom with NO GAPS.** Drag handles to fit.
9. **Place spatial entities**:
   - At least one `Extraction(kind=Timed)` in the `Maze` region as an early-leave option (skip if you want to force boss-kill flow).
   - `EnemySpawnZone`s sized to fit each region. Set `phase` and `density`. Use higher `density` in `PreBoss`.
   - `Obstacle`s for cover/cosmetics. Pick `kind` from `Rock/Crate/Pillar/Bones/Tree/Stalagmite`.
   - `Marker`s for any scripted positions (loot piles, lore beats, camera shots).
10. **Save.** LDtk writes the level to its `.ldtkl` external file.

---

## Authoring a New Biome

Bigger lift — bootstraps a new `.ldtk` project. See `ldtk_schema.md` §9 for the conceptual
checklist; here's the operational steps:

1. **Pick a tileset folder** in `assets/minifantasy/` for the biome's visual identity.
2. **Add the biome name to the `BiomeId` enum** in `ldtk_schema.md` §4 (append, never reorder).
3. **Add a stub entry to `data/factories/level_data.gd`** `LEVELS` dict with the matching integer key.
   Use the existing `Caves` entry as a template.
4. **Bootstrap the `.ldtk` file**:
   - Easiest: in LDtk, **File → New project**, save as `assets/Maps/Levels/Level X - <Biome>.ldtk`.
   - Set: `defaultLevelWidth=648`, `defaultLevelHeight=1504`, `defaultGridSize=8`,
     `externalLevels=true`, `identifierStyle=Capitalize`.
   - Add the biome's tilesets via **Tilesets** panel.
   - **Save and close LDtk**, then run:
     ```
     python tools/apply_ldtk_schema.py "assets/Maps/Levels/Level X - <Biome>.ldtk"
     ```
     This injects all enums, level fields, entity defs, and the `Entities` layer matching the schema.
5. **Reopen in LDtk.** Manually add the four remaining tile/auto layers
   (`Background`, `FloorAuto`, `WallsAuto`, `Decoration`) — these need visual setup
   (tileset binding, auto-rules) that the bootstrap script doesn't try to automate.
6. **Author levels** following the previous section.

---

## Common Mistakes & Fixes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Importer rejects level | `schema_version` doesn't match current schema (`1`) | Open level properties → set `schema_version=1`. |
| Boss never spawns | `PreBoss` region has both `kill_quota=0` AND `timer_seconds=0` | Set at least one. |
| Player walks through walls | Painted `Floor=1` instead of `Wall=2` | Repaint Collision with the right IntGrid value. |
| Two regions overlap | Regions must tile, not stack | Drag region edges to abut, not overlap. |
| Level exit never unlocks | `Boss_Spawn` field is set but `Boss_Spawn_Pos` is unset (or vice versa) | Either fill in both, or empty both (no-boss level — exit unlocks immediately). |
| Player spawns at (0, 0) | `Player_Spawn_Pos` Point field on `Level_Instructions` is unset | Click the `Player_Spawn_Pos` field, then click a cell on the level. |
| Boss spawns at the wrong place | `Boss_Spawn_Pos` is outside the `Boss` region | Move the point inside the Boss region rectangle. |
| Auto-tiles look wrong | `WallsAuto`/`FloorAuto` not bound to the correct tileset | Open layer settings, set `Tileset` to the biome's main tileset. |
| Editor shows wrong colors on IntGrid | Pre-existing IntGrid value names from before schema | Re-run `tools/apply_ldtk_schema.py` to canonicalize. |

---

## When You Type `/level <name>` (future)

Once the importer (`scripts/systems/ldtk_loader.gd`) and the `level` slash command exist,
the workflow will be:

1. You type `/level cave_2` (or any `<biome>_<level_index>` style identifier).
2. Claude looks up the matching `.ldtkl` in `assets/Maps/Levels/`.
3. Claude verifies it conforms to the schema (regions tile, required entities present, schema_version matches).
4. Claude tells you what's missing or out-of-spec, OR runs `LdtkLoader` via the Godot MCP to load it in-engine for testing.

For now (importer not built yet), `/level <name>` will at minimum:
- Open the right `.ldtk` / `.ldtkl` files in your context
- Validate the schema
- Tell you exactly what to add next based on what's already there

---

## Arena Design Principles

These principles apply regardless of biome or level index. They complement the structural rules in `ldtk_schema.md` with the intent behind placement decisions.

**Spawn zones cover multiple directions.** Enemies should come from at least two distinct zones in any given region. A player who holds one corner should still face pressure from another direction — `EnemySpawnZone`s placed only on one side create exploitable safe spots.

**Extraction points are always visible.** Players should see extraction options without exploration. In a vertical strip this means the camera framing (or a minimap) exposes the Timed/Guarded extraction locations early. Never tuck an extraction behind a corridor the player hasn't unlocked yet.

**No dead ends.** Every passage the player can enter must have an exit path. Getting geometry-trapped is a design failure, not a difficulty feature. Test every branch: if pressing forward from any point leaves no escape route, open one.

**Obstacles create kiting paths, not safe rooms.** Obstacles should break line-of-sight and create natural movement corridors, not enclosed pockets the player can camp indefinitely. A cluster of pillars the player can circle around is good; a three-walled alcove the player can stand in while enemies funnel single-file is not.

**Hazards offer risk/reward, not unavoidable punishment.** Environmental hazard zones should sit between the player and something valuable (an extraction point, a loot spot, a better kiting path). Blocking a critical path with unavoidable damage is a design failure; placing a damage zone the player can choose to cross or go around is correct.

**Hidden spots reward exploration.** One to three `Marker(tag=LootSpawn)` entities per level, tucked in slightly out-of-the-way positions (behind obstacles, in a narrow side passage, at the edge of a region). Not on the critical path. Finding one should feel like a discovery.

**Regions tile cleanly.** The importer asserts no gaps between Region entities. Overlap is an error. When laying out a level, size each Region to abut the next with no pixel gaps — drag handles until the boundaries touch.

---

## Doc Cross-References

- [`ldtk_schema.md`](ldtk_schema.md) — entity/enum/field/layer contract
- [`engine_reference.md`](engine_reference.md) — engine systems the importer integrates with (includes Extraction System section)
- [`asset_inventory.md`](asset_inventory.md) — license tracking for tilesets
- [`core_framework_decisions.md`](core_framework_decisions.md) — wave timing, enemy scaling
