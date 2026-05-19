# Block System Implementation Notes

**Date:** 2026-05-19

## Files Created

| File | Purpose |
|---|---|
| `scripts/systems/block_manager.gd` | Block assembly, spawn zone registration, event anchor collection, debug overlay |
| `assets/Maps/Levels/Level 1 - Caves/Block_Caves_01_Open.ldtkl` | Open variant — no obstacles, calm block |
| `assets/Maps/Levels/Level 1 - Caves/Block_Caves_02_Pillars.ldtkl` | Pillars variant — 5 stalagmite clusters |
| `assets/Maps/Levels/Level 1 - Caves/Block_Caves_03_Choke.ldtkl` | Chokepoint variant — central narrow gap |
| `assets/Maps/Levels/Level 1 - Caves/Block_Caves_04_Split.ldtkl` | Split path variant — central wall spine |
| `assets/Maps/Levels/Level 1 - Caves/Block_Caves_05_Merchant.ldtkl` | Merchant variant — gated alcove with Locked extraction |
| `tools/generate_blocks.py` | Generation script for block .ldtkl files (re-runnable) |
| `docs/block_architecture.md` | Design document |
| `docs/cave_audit.md` | Pre-rebuild audit |

## Files Modified

| File | Change |
|---|---|
| `scripts/main_arena.gd` | Added `_using_descent`, `_block_manager` vars; `_setup_ldtk_descent()` method; descent bounds for spawning |
| `scripts/managers/game_manager.gd` | Added `use_descent_mode: bool` flag |
| `scripts/ui/debug_panel.gd` | F8 hotkey for block debug overlay |
| `assets/Maps/Levels/Level 1 - Caves.ldtk` | Registered 5 block levels in project |
| `assets/Maps/Levels/Level 1 - Caves/Level_0.ldtkl` | Maze area cleared (rows 52-79 → floor) |

## How to Enable

Set both flags in `game_manager.gd`:
```
var use_ldtk_level_1: bool = true
var use_descent_mode: bool = true
```
Run with `debug_mode = true`. MainArena will build a 10-block descent instead of loading Level_0.

## Known Issues

1. **No visual tiles yet.** Block collision IntGrid is painted but LDtk auto-rule tiles are not generated (they're created by LDtk editor, not at runtime). The loader creates TileMapLayers but they'll be empty until blocks are opened and saved in LDtk editor.
2. **Merchant gate not implemented.** The Block_Caves_05_Merchant has the collision geometry for the gate wall but no runtime gate-toggling logic. Task 4.2 will add this.
3. **No DepthTracker yet.** BlockManager exposes `block_bounds` and `get_block_index_at_y()` for it. Task 3.1 will build the tracker.
4. **No EventSpawnManager yet.** BlockManager exposes `get_event_anchors()` for it. Task 4.1 will build the manager.

## Architecture Decision: One LdtkLoader Per Block

Each block gets its own `LdtkLoader` instance positioned at the cumulative Y offset. This means:
- Child nodes (TileMapLayers, StaticBody2Ds) are automatically positioned correctly
- Entity data (spawn zones, markers, extractions) needs manual Y-offset adjustment (done in `build_descent()`)
- To unload a block: just `queue_free()` its loader — all children go with it
- 10 blocks × 6 layers = ~60 TileMapLayers. Should be fine but profile if FPS drops.
