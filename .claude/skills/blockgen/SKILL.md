---
name: blockgen
description: Generate descent level blocks (caves, crypt, nmrealm) via the text-sketch block compiler. Use when Ben asks for new blocks, block variants, "/blockgen", or level layout work for the descent system. Handles sketch authoring, compiling, preview QA, and the required smoke test.
---

# Blockgen — Generate Descent Blocks

Compile text sketches into finished LDtk blocks (walls, floor, collision, props,
entities + PNG preview). **Never** hand-edit `.ldtkl`/`.ldtk` files or paint
tiles manually — the compiler owns generated blocks; the sketch is the source
of truth.

Read `docs/block_sketch_workflow.md` before your first block. This file is the
operating procedure; that doc is the format/grammar reference.

## Hard rules

1. **Hand-owned blocks are untouchable.** A block is compiler-owned **only if**
   a `.block` sketch exists in `blocks/<style>/`. Everything else is Ben's
   hand-painted work — NEVER create a sketch reusing one of those names, never
   modify their `.ldtkl`. Hand-owned today: all `Block_Caves_00..09`,
   `Block_Crypt_00_Entry`, `Block_NMRealm_00_Entry`, `Block_NMRealm_01_Isles`.
2. **Smoke test after every real compile** (not needed for `--preview-only`):
   ```
   E:\Godot\Godot_v4.6.1-stable_win64.exe --headless --path . --script res://tools/test_block_load.gd
   ```
   Must print `ALL_OK=true` and exit 0. PNG previews cannot catch
   registration/path errors; a bad registration silently breaks the descent.
3. **QA your own previews with the Read tool** before showing Ben. Never
   declare a block done from compiler exit codes alone.
4. **Ben's LDtk session fights the compiler** over `Level 1 - Caves.ldtk`. If
   LDtk is open, tell Ben to reload the project (File > Reload) before he saves
   anything, or his save will erase the new block's registration.
5. **Do not commit unless Ben asks.** When he does: stage only blockgen files
   (sketches, .ldtkl, previews, .ldtk, tool changes). Never stage his WIP
   (`scripts/ui/hud.gd`, pacing docs, cave/crypt `.ldtkl` resave noise).
6. **nmrealm scratches are Ben's.** `scratches = off` always (the default). He
   hand-paints ground scarring in LDtk afterward; recompiles preserve his
   `Ethereal_Floor` layer automatically.

## Workflow

1. Write sketch(es) to `blocks/<style>/<Name>.block` — generate the grid with
   the Python template below, don't type 4,860 characters by hand.
2. `python tools/block_compiler.py --preview-only blocks/<style>/<Name>.block`
3. Fix validator failures (see cheat sheet), then Read the preview PNG from
   `blocks/previews/` and judge it like Ben would: seams clean, structures
   coherent, props not clumped on paths.
4. Compile for real (same command without `--preview-only`), run the smoke
   test, confirm `ALL_OK=true`.
5. Report to Ben with preview paths. Blocks are NOT in any descent rotation
   automatically — caves rotation lives in `normal_block_ids`
   (`scripts/main_arena.gd` ~line 311); crypt/nmrealm have no rotation yet.

## Sketch format

```
name = Block_<Style>_<NN>_<Theme>     # NN continues the style's numbering
biome = Caves
style = caves | crypt | nmrealm
density = none | sparse | normal | dense       # normal = Ben's look
scratches = off                                # nmrealm only, keep off
seed = <int>                                   # unique per block
spawn_zone = rect=full phase=Any density=Medium
grid:
<exactly 60 rows x 81 chars>
```

Grid legend: `.` floor · `,` floor+SpawnBlock · `-` light path (caves only
visually) · `#` solid rock (caves/crypt) / **void** (nmrealm) · `P` platform
(nmrealm) · `W` ruined wall line (nmrealm).

## Universal grid constraints (validator-enforced)

- Cols 0 and 80 are `#`. Seam rows 0-2 and 57-59 walkable across cols 2-78.
- A walkable path must connect top seam to bottom seam; no orphan pockets.
- Every passage >= 3 tiles wide (3x3 window test).
- Interior `#` islands not attached to the outer border: bbox ≥ 2×2 AND area ≥ 3
  (`check_obstacle_islands`, tunable via `--min-obstacle-size`). Exception: caves
  1-row rim lines (scalloped visually) are exempt if width ≥ 2. Rationale: smaller
  blobs are invisible at 640×360 during heavy VFX combat — they snag without giving
  any tactical information (first-playtest finding, Clerveu 2026-07-18).
- No walkable corridor exactly 1 cell wide for more than 4 connected cells
  (`check_narrow_corridors` warns). Design toward 3-tile-wide passages; 1-cell slots
  are tolerable only as short doorway slivers (≤ 4 cells).
- At least one `spawn_zone`.

Per style:
- **caves**: interior `#` blobs >= 3 wide x 4 tall, or exactly 1 row tall
  (scallop rim). No tall solid spines (40-row slabs read as black voids).
- **crypt**: `#` blobs >= 2x2. Architectural shapes (rooms, corridors,
  doorway gaps) suit the brick grammar; organic shapes don't.
- **nmrealm**: `#` = void, blobs >= 3x3. `P` platforms: rectangular only,
  >= 3 wide x 4 tall, fully surrounded by floor, >= 3 cols / 4 rows from
  border and seams. `W` walls: straight 1-cell lines only (no L-shapes —
  leave a 1-cell crumble gap at corners); horizontal len >= 8 with 3 non-void
  rows below; vertical len >= 5. Walls are walkable decor (no collision).

## Grid generator template

```python
import math
W, H = 81, 60
def new_grid(): return [["." for _ in range(W)] for _ in range(H)]
def carve(g, cx, cy, rx, ry, phase, amp=0.16, lobes=3):   # organic void blob
    for y in range(H):
        for x in range(W):
            ang = math.atan2((y-cy)/ry, (x-cx)/rx if rx else 1)
            wob = 1.0 + amp*math.sin(lobes*ang + phase)
            if ((x-cx)/(rx*wob))**2 + ((y-cy)/(ry*wob))**2 <= 1.0:
                g[y][x] = "#"
def finish(g):                                            # seams + border, LAST
    for y in list(range(3)) + list(range(H-3, H)):
        for x in range(1, W-1): g[y][x] = "."
    for y in range(H): g[y][0] = g[y][W-1] = "#"
def hwall(g, y, x0, x1):
    for x in range(x0, x1+1): g[y][x] = "W"
def vwall(g, x, y0, y1):
    for y in range(y0, y1+1): g[y][x] = "W"
def plat(g, x0, y0, w, h):
    for y in range(y0, y0+h):
        for x in range(x0, x0+w): g[y][x] = "P"
```

Off-map ellipse centers (e.g. `cx=-3` or `cx=83`) carve bays into the sides.
Call `finish(g)` last — it re-opens the seams.

## Common validator failures

| Error | Fix |
|---|---|
| passages narrower than 3 tiles | move the two structures apart 2-3 cells |
| ruined wall must be straight | walls touching at corners merge into an L — leave a 1-cell gap |
| platform touches void | keep >= 1 floor ring around P; move P or shrink the hole |
| solid blob is WxH, needs >= ... | grow the blob or delete it |
| seam row has solid cells | a carve reached rows 0-2/57-59 — call `finish(g)` last |
| obstacle island too small (bbox/area) | grow the `#` blob to ≥ 2×2, or merge it into a neighboring mass; caves 1-row rims ok if w ≥ 2 |
| narrow corridor >4 cells (WARN) | widen walkable run to ≥ 3 cells, or break with an opening — 1-cell slots ≤ 4 are tolerated |

## Recompiling & style upkeep

- Recompiling an existing sketch keeps uid/world position and (nmrealm)
  preserves Ben's hand-painted `Ethereal_Floor` scarring. All other layers
  regenerate from the sketch.
- When Ben paints new reference props/blocks: rerun `python
  tools/extract_prop_stamps.py` (caves/crypt) or `python
  tools/extract_nmrealm_style.py` (nmrealm, mines his Entry + Isles), then
  recompile generated blocks if he wants the new look applied.
- New biome (Threshold, Inferno): read the pack's `Use_Guidelines.png` for
  intended tile assemblies first, then follow the nmrealm playbook (mine
  Ben's reference block + the pack's Premade/Separate_Layers). That's a
  compiler-extension task — flag it to Ben rather than improvising.
