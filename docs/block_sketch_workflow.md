# Block Sketch Workflow — Text-First Level Authoring

**Date:** 2026-07-02
**Replaces:** hand-painting descent blocks in LDtk (LDtk remains the polish tool for hero blocks).

The fast path for making new descent blocks: describe the block, Claude writes a text
sketch, the compiler produces a finished `.ldtkl` (walls, floor, props, shadows,
collision, entities) plus a PNG preview. You approve from the preview; nothing needs to
open LDtk or Godot until playtesting.

```
blocks/caves/<Name>.block      ← sketches (SOURCE OF TRUTH for generated blocks)
blocks/previews/<Name>.png     ← compiled previews (2x scale)
tools/block_compiler.py        ← the compiler
tools/block_style_caves.json   ← prop stamp library (extracted from hand-painted blocks)
tools/extract_prop_stamps.py   ← regenerates the stamp library
```

---

## Commands

```bash
# compile + write .ldtkl + register in the parent .ldtk + render preview
python tools/block_compiler.py blocks/caves/Block_Caves_10_ChokeA.block [more ...]

# render preview only (no files written to assets/)
python tools/block_compiler.py --preview-only blocks/caves/Block_Caves_10_ChokeA.block

# re-extract the prop stamp library after new hand-painted reference blocks
python tools/extract_prop_stamps.py

# REQUIRED after compiling: headless loader smoke test (catches registration /
# path / parse errors the PNG preview cannot). Exit code 0 = all blocks load.
E:\Godot\Godot_v4.6.1-stable_win64.exe --headless --path . --script res://tools/test_block_load.gd
```

Recompiling an existing name replaces its `.ldtkl` and keeps its uid/world position
(idempotent). **Any LDtk hand-edits to a generated block are lost on recompile** — either
treat the sketch as the only source, or rename the block in LDtk to fork it into a
hand-owned block.

---

## Sketch Format

Line-based `key = value`; repeatable keys for lists; `#` starts a comment (outside the grid).

```
name = Block_Caves_10_ChokeA
biome = Caves
floor = 160,128                    # optional tileset src; default 160,200
density = normal                   # none | sparse | normal | dense
seed = 20260702                    # decoration RNG seed; same seed = same props
spawn_zone = rect=full phase=Any density=Medium
marker = id=event_anchor_01 tag=EventTrigger payload=any at=40,15
extraction = kind=Locked at=69,30 radius=48 channel=2
grid:
<exactly 60 rows of exactly 81 chars>
```

### Grid legend

| Char | Meaning |
|---|---|
| `.` | floor (walkable) |
| `,` | floor + SpawnBlock (walkable, no enemy spawns — use near seams/events) |
| `-` | light dirt path / corridor floor (walkable; reads as a carved route) |
| `#` | solid rock — border columns, bands, ridges, pillars. Auto-tiled. |

### Structure rules (validated; compile fails with line/col messages)

- Grid is exactly 81×60. Columns 0 and 80 are `#` (map border).
- Seam rows 0–2 and 57–59 walkable across cols 2–78 (block stitching contract).
- A walkable path must connect top seam to bottom seam; no orphaned pockets.
- No passage narrower than 3 tiles (player clearance).
- Interior solid blobs: ≥3 wide and ≥4 tall (renders cap + void + rock face), **or**
  exactly 1 row tall — a thin scalloped rim line (the choke's north lip).
- At least one `spawn_zone`.

### How `#` renders (the extracted Caves grammar)

- Blob touching the map top edge → wall band: dark/lit/bottom face rows.
- Interior blob ≥4 tall → pillar/ridge: scalloped cap, black void interior, 3-row rock
  face at the bottom, SW floor shadows, side trims.
- 1-row blob → thin scallop rim (with `-` above/below it reads as a cliff lip).
- Blob top row with walkable cells above → rim overlay (ridge seen from behind).
- Collision = the same cells (`Wall=2` in the Collision IntGrid) — geometry and visuals
  can never disagree, which is the class of bug that plagued hand-painted blocks
  (02_Pillars walkable tips, 04_Split missing side walls).

### Decoration

The decorator scatters prop stamps — real assemblies extracted from the hand-painted
blocks (66 stamps: debris specks, bones, stalagmite columns with shadow pairing, rock
piles, stumps) — seeded and weighted by observed frequency. Density presets are
calibrated from the reference blocks (`sparse` ≈ 01_Open, `normal` ≈ 03_Choke). Props
avoid seams, paths, structures, and each other. Change `seed` to reroll placement.

---

## Typical Session

1. Ben: "two new choke variants, gaps mirrored" (or hands over an ASCII doodle).
2. Claude writes `blocks/caves/*.block`, runs `--preview-only`, checks the PNGs itself.
3. Ben reviews `blocks/previews/*.png`, requests tweaks (line numbers make edits surgical).
4. Compile for real. Block appears in the LDtk project, ready for the game.
5. To put it in the descent rotation: add its name to `normal_block_ids` in
   `scripts/main_arena.gd` (see `BLOCK_COUNT` region ~line 304).

## Crypt Style (`style = crypt`)

Second grammar, for crypt/catacomb blocks (sketches in `blocks/crypt/`). Same grid
legend, architectural rendering:

- Walls are brick: top row `(72,104)` + repeating two-row courses `(72,112)/(72,120)`
  (from `Block_Crypt_00_Entry`). Interior blobs can be as small as 2×2 (tomb slabs).
  No rim lines, no ramp dressing — gaps through walls are clean doorways.
- The brick **floor is baked from the CryptLayer IntGrid's active auto-rules** (read
  from the project defs at compile time — an LDtk re-save re-bakes identically).
  Floor-meets-wall edge trims come from those rules automatically.
- Prop stamps: `tools/block_style_crypt.json` (only 5 stamps from the single reference
  block — paint more reference props in LDtk and rerun the extractor to enrich it).
- New crypt blocks register on the crypt row of the world view (worldY = 506).
- Not wired to any descent rotation yet — the Catacombs descent flow doesn't exist.

## Current Limitations (v1)

- Caves + Crypt only. New biome = new grammar constants + stamp extraction from a few
  hand-painted reference blocks of that biome.
- No ponds/pits/water (`~`/`o` reserved, not implemented) — pin them by hand in LDtk on
  a forked copy, or wait for v2.
- Hero features (cave-mouth door, merchant gate, the Entry stump) are not generated —
  those stay hand-crafted.
- Gap-through-ridge side trims are approximate; judge from the preview.

## Cross-References

- [`ldtk_schema.md`](ldtk_schema.md) — entity/IntGrid contract the compiler targets
- [`ldtk_workflow.md`](ldtk_workflow.md) — manual LDtk authoring (hero blocks, biome setup)
- [`block_architecture.md`](block_architecture.md) — block dimensions, seams, descent stitching
