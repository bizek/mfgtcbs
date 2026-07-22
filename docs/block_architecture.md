# Block-Tile Architecture — Cave Descent System

**Date:** 2026-05-19
**Status:** Design document — **implemented**. Tasks 2.2/2.3 shipped; descent runs on `BlockManager` +
`DepthTracker` + `LdtkLevelDirector`. Kept for the design rationale. **Block authoring has moved on:**
blocks are no longer hand-painted — write a `.block` text sketch and compile it. See
`docs/block_sketch_workflow.md` and the `/blockgen` skill.

---

## 1. Block Dimensions

| Property | Value | Justification |
|---|---|---|
| **Width** | 648px (81 tiles) | Matches existing level width. Full camera viewport width. |
| **Height** | 480px (60 tiles) | ~1.3 screens tall (viewport = 360px). Player at 200px/s with ~40% effective descent rate (dodging/fighting) takes ~6s to cross. |
| **Grid** | 8px | Standard Minifantasy tile size. |
| **Blocks per descent** | 10 | Total height = 4800px. Effective descent time ~60-90s with combat, fitting comfortably within 180-240s phase timers. |

**Why 480px:** At 120-200px/s player speed, shorter blocks (240px) become trivial corridors. Taller blocks (480px) give room for a combat encounter, a terrain feature, and breathing space. 60 tiles tall × 81 wide = 4,860 cells per block — small enough for fast iteration in LDtk.

**Why 10 blocks:** 10 × 480px = 4800px total descent. Enough variety to feel procedural without drowning in content authoring. Can tune to 8 or 12 without architectural changes.

---

## 2. Connection Rules

**Full-width open seam.** The top 3 rows and bottom 3 rows of every block must be entirely Floor (IntGrid value 1) across the full walkable width (columns 2-78, with wall border on columns 0-1 and 79-80).

```
Block N:
  ┌──────────────────────────┐
  │ WW FFFFFFFFFFFFFFFFFF WW │  rows 0-2: open seam (entry)
  │ WW                    WW │
  │ WW   [block content]  WW │  rows 3-56: authored content
  │ WW                    WW │
  │ WW FFFFFFFFFFFFFFFFFF WW │  rows 57-59: open seam (exit)
  └──────────────────────────┘
Block N+1:
  ┌──────────────────────────┐
  │ WW FFFFFFFFFFFFFFFFFF WW │  rows 0-2: open seam (entry)
  ...
```

**W** = wall border (IntGrid 0). **F** = floor (IntGrid 1). The 3-row seam ensures the player can never get stuck at a block boundary even if they're at the extreme edge.

**No explicit "door" entity.** Blocks are always open at top and bottom. Committed descent (can't go back) is enforced by the BlockManager at runtime, not by geometry — when the player crosses into block N+1, block N-1's collision and visuals can be freed.

---

## 3. Block Content Rules

### Must Have
- Floor path from top seam to bottom seam (reachable by player collision box)
- Wall border (2 tiles) on left and right edges
- At least one `EnemySpawnZone` entity with appropriate phase/density

### Must Not Have
- Dead ends that look like real paths (1-tile pockets, corridors that lead nowhere)
- Passages narrower than 3 tiles (24px) — player collision shape needs clearance
- Level_Instructions entity (only the first block needs metadata; handled by BlockManager)
- Region entities (block system replaces the region model)

### May Have
- Interior walls, pillars, obstacles (Rock, Stalagmite) for tactical variety
- `Marker` entities with tag="event_anchor" for merchant/altar placement
- `EnemySpawnZone` entities gated to specific phases
- Pit tiles (IntGrid 3) as visual variety
- SpawnBlock tiles (IntGrid 5) near seams to prevent enemies spawning on top of the player

---

## 4. Variant Strategy

**5 variants for Caves biome:**

| Variant | Name | Character | Event Anchors |
|---|---|---|---|
| 1 | `Block_Caves_01_Open` | Wide open floor, minimal obstacles. Calm block. | None |
| 2 | `Block_Caves_02_Pillars` | 4-6 stalagmite/rock pillars creating sight-line breaks. | 1 generic anchor |
| 3 | `Block_Caves_03_Choke` | Central chokepoint (3-4 tile gap) with open areas above and below. | 1 generic anchor |
| 4 | `Block_Caves_04_Split` | Two parallel paths separated by a wall spine, reconnecting at bottom. | 1 generic anchor |
| 5 | `Block_Caves_05_Merchant` | Wide central chamber with a gated alcove on one side. Merchant spawns at chamber center; locked extraction zone behind gate. | 1 merchant-specific anchor |

**Selection rules:**
- Variant 5 is **never randomly selected**. BlockManager places it at the merchant's assigned depth.
- Variants 1-4 are shuffled with no-repeat constraint (no two identical adjacent blocks).
- Variant 1 (Open) is weighted 2x higher in the first 3 blocks to give the player a gentle start.

**Differentiation axes:** obstacle density (0 → 6), path count (1 → 2), chokepoint presence (yes/no), chamber width variance.

---

## 5. Event Anchor System

**Uses the existing `Marker` entity** from the LDtk schema. No new entity types needed.

| Tag | ID | Payload | Meaning |
|---|---|---|---|
| `EventTrigger` | `event_anchor_01` | `"any"` | Generic anchor — EventSpawnManager can place merchant or altar here |
| `EventTrigger` | `merchant_anchor` | `"merchant"` | Merchant-only anchor (Variant 5 block) |
| `EventTrigger` | `altar_anchor` | `"altar"` | Altar-only anchor (if needed — can also use "any") |

The loader already parses Marker entities and emits `marker_loaded(tag, id, position, payload)`. BlockManager collects these with Y-offset applied, then passes them to EventSpawnManager.

**Event placement flow:**
1. BlockManager loads blocks, collects all Marker entities with tag="EventTrigger"
2. Adjusts positions by block Y-offset
3. EventSpawnManager receives anchor list, assigns events by depth preference
4. Event entities (Merchant, SummonAltar) spawned at assigned anchor world positions

---

## 6. Stitching Strategy

### Approach: One LdtkLoader per block, offset by position

Each block is loaded as a separate `LdtkLoader` instance (extends Node2D). The loader creates its tile layers and collision bodies as children, all at level-local coordinates (0,0 origin). The BlockManager offsets each loader's `position.y` by cumulative block height.

```
BlockManager (Node, child of MainArena)
├── LdtkLoader "block_0" (position.y = 0)
│   ├── TileMapLayer (Collision auto-tiles)
│   ├── TileMapLayer (Cave_Tiles)
│   ├── StaticBody2D (merged collision)
│   └── ...
├── LdtkLoader "block_1" (position.y = 480)
│   ├── ...
├── LdtkLoader "block_2" (position.y = 960)
│   ├── ...
└── ... (10 total)
```

### Why this approach

- **Simplest integration.** Each LdtkLoader call is identical to the current single-level path. No loader modifications needed.
- **Clean memory management.** To unload a block, just `queue_free()` its LdtkLoader — all children go with it.
- **Position offsetting is trivial.** Node2D.position.y handles all coordinate transforms automatically for child nodes (TileMapLayers, StaticBody2Ds, Sprites).

### What needs manual offsetting

Entity data (positions returned in the `result` dictionary) is in level-local coordinates. BlockManager must add `block_y_offset` to:
- `result.spawn_zones[].rect.position.y` — before registering with EnemySpawnManager
- `result.markers[].position.y` — before passing to EventSpawnManager
- `result.obstacles[].position.y` — before any gameplay queries
- `result.extractions[].position.y` — before spawning extraction zones

Node children (TileMapLayers, StaticBody2Ds) are automatically offset by the parent LdtkLoader's position — no manual adjustment needed.

### Camera limits

```
camera.limit_left = 0
camera.limit_right = 648  (block width)
camera.limit_top = 0
camera.limit_bottom = total_blocks * 480  (total descent height)
```

### Performance consideration

10 blocks × ~6 layers per block = ~60 TileMapLayers. Each block also has merged collision StaticBody2Ds (count varies by wall complexity). This should be fine for Godot 4's renderer — TileMapLayers are batched and StaticBody2Ds are cheap when static. Profile if FPS drops below 60.

**Optional optimization (deferred):** Only keep 3 blocks loaded at a time (current + one above + one below). Queue_free distant blocks. Not needed unless performance is an issue.

---

## 7. What This Replaces

| Old System | New System | Migration |
|---|---|---|
| Region entities (Maze/PreBoss/Boss) | Block progression (numbered blocks) | Remove Region entities from block levels. LdtkLevelDirector not created in descent mode. |
| Single monolithic level | 10 assembled blocks | `_setup_ldtk_descent()` replaces `_setup_ldtk_level()` when descent_mode=true |
| Kill quota → boss spawn | Depth progress → bottom portal | DepthTracker tracks progress; portal at last block's bottom |
| 4 extraction zones (fixed positions) | Bottom portal + mid-descent events | Timed extraction at bottom; merchant/altar events via anchors |
| Arena bounds (±800×±600 or single level) | Tall composite level (648×4800) | Camera limits adjusted; spawn bounds = full descent rect |

### Files affected

- `scripts/main_arena.gd` — new `_setup_ldtk_descent()` method
- `scripts/systems/ldtk_level_director.gd` — skipped in descent mode (not deleted; still used for non-descent levels)
- `scripts/managers/game_manager.gd` — `descent_mode` flag, `spend_loot()` method
- `scripts/managers/enemy_spawn_manager.gd` — may need spawn zone re-registration as blocks load/unload

### Files NOT affected

- `scripts/systems/ldtk_loader.gd` — no changes needed, used as-is
- `scripts/extraction/` — existing extraction scripts used unchanged
- `docs/ldtk_schema.md` — no schema changes; blocks use existing entity types

---

## 8. Open Questions

1. **Block unloading:** Should blocks behind the player be freed for memory, or kept loaded? Keeping all 10 is simpler but uses more memory. Freeing requires re-spawning collision if player somehow backtracks. **Recommendation:** Keep all loaded (10 blocks is small). Add unloading later only if profiling shows a problem.

2. **Enemy spawning scope:** Should enemies spawn in all blocks or only near the player? Currently `EnemySpawnManager` spawns within registered zones relative to player position with `min_distance_from_player`. This naturally limits spawns to nearby blocks. **Recommendation:** Register all block spawn zones at start; let the existing distance check handle scoping.

3. **Level_Instructions entity:** Blocks don't have individual Level_Instructions. The descent's metadata (biome, music, loot pool) comes from the first block or from a separate configuration. **Recommendation:** Put one Level_Instructions entity in `Block_Caves_01_Open` (the first block is always this variant for calm starts). Or have BlockManager hardcode descent metadata per biome.

4. **Transition between blocks:** The plan says "committed downward progression — can't go back between blocks." Should there be a visible barrier (e.g., rocks falling) or just no gameplay reason to backtrack? **Recommendation:** Start with no barrier. The monster horde naturally pushes the player forward. Add a collapsing passage VFX later if playtesting shows players backtracking excessively.
