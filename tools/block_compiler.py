"""Block compiler — compiles .block text sketches into LDtk block levels.

Pipeline:  sketch (.block) -> validate -> render walls/floor -> decorate props
           -> emit .ldtkl + register in parent .ldtk -> render PNG preview

The visual grammar (which tiles form pillars, ridges, borders, faces) was
reverse-engineered from Ben's hand-painted blocks; the prop decorator stamps
assemblies extracted from those same blocks (tools/block_style_caves.json,
regenerate with tools/extract_prop_stamps.py).

Sketch format (line-based, `key = value`, repeatable keys):

    name = Block_Caves_10_ChokeA
    biome = Caves
    floor = 160,128                          # optional; default 160,200
    density = sparse                         # none|sparse|normal|dense
    seed = 331
    spawn_zone = rect=full phase=Any density=Medium
    marker = id=event_anchor_01 payload=any at=40,20
    extraction = kind=Locked at=69,30 radius=48 channel=2
    grid:
    <60 rows x 81 chars>

Grid legend:
    .  floor (walkable)
    ,  floor + SpawnBlock (walkable, enemies won't spawn on it)
    -  light dirt path/corridor floor (walkable)
    #  solid rock (border columns, ridges, pillars, bands — auto-tiled)

Usage:
    python tools/block_compiler.py blocks/caves/03_choke_a.block [more.block ...]
    python tools/block_compiler.py --preview-only blocks/caves/*.block
"""
import json
import os
import random
import sys
import uuid
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT_PATH = os.path.join(ROOT, "assets", "Maps", "Levels", "Level 1 - Caves.ldtk")
LEVELS_DIR = os.path.join(ROOT, "assets", "Maps", "Levels", "Level 1 - Caves")
STYLE_PACK = os.path.join(ROOT, "tools", "block_style_caves.json")
PREVIEW_DIR = os.path.join(ROOT, "blocks", "previews")

BLOCK_W, BLOCK_H = 81, 60
GRID = 8

WALKABLE = {".", ",", "-"}
SOLID = {"#"}
LEGEND = WALKABLE | SOLID

# IntGrid values (docs/ldtk_schema.md §2)
IG_FLOOR, IG_WALL, IG_SPAWNBLOCK = 1, 2, 5

# ---------------------------------------------------------------------------
# Caves visual grammar (reverse-engineered from hand-painted blocks)
# ---------------------------------------------------------------------------
FLOOR_DEFAULT = (160, 200)
FLOOR_PATH = (256, 96)        # light dirt corridor
FACE_TOP = [(24, 8), (32, 8), (40, 8)]       # dark upper face
FACE_MID = [(24, 16), (32, 16), (40, 16)]    # lit face
FACE_BOT = [(24, 24), (32, 24), (40, 24)]    # face bottom / trim
VOID = (56, 48)                              # pure black interior
CAP_ROW = (168, 8)                           # scalloped cap base row
CAP_INNER = [(24, 48), (32, 48)]             # dark cap overlay pieces
CAP_CORNER_L, CAP_CORNER_R = (56, 80), (8, 80)
EDGE_L = {"void": (56, 32), "face_top": (56, 56), "face_mid": (56, 64), "trim": (56, 72)}
EDGE_R = {"void": (8, 32), "face_top": (8, 56), "face_mid": (8, 64), "trim": (8, 72)}
BORDER_L, BORDER_R = (8, 32), (56, 32)       # map border columns (x=0 / x=80)
RIM_PIECES = [(224, 0), (232, 0), (240, 0)]  # scallop overlay (thin rims, cap edges)
RIM_CAP_L, RIM_CAP_R = (136, 88), (280, 88)
RIM_BASE = (256, 128)                        # darker dirt under rim overlay rows
GAP_EDGE_L, GAP_EDGE_R = (232, 136), (272, 136)
# gap-through-ridge dressing (from hand-painted 03_Choke gap):
GAP_FILL = (256, 128)                        # darker dirt through the cut
GAP_SIDE_L, GAP_SIDE_R = (232, 120), (280, 120)
APRON_YS = (128, 136, 144)                   # 3 apron rows below the band
APRON_X_END_L, APRON_X_END_R = 232, 280
APRON_X_MID = (240, 248, 256, 264, 272)
APRON_SCALLOP = (168, 96)
# pillar SW shadow (CavesShadows, 8px layer): column left of pillar + inner col
SHADOW_LEFT = [(120, 8), (120, 24), (120, 32), (120, 40)]
SHADOW_INNER = [(128, 24), (128, 32), (128, 40)]

DENSITY_PRESETS = {
    # stamp instances per 1000 floor tiles, by size class
    "none":   {"debris": 0.0, "small": 0.0, "medium": 0.0, "large": 0.0},
    "sparse": {"debris": 1.9, "small": 0.6, "medium": 1.0, "large": 0.4},
    "normal": {"debris": 4.5, "small": 1.5, "medium": 1.6, "large": 0.4},
    "dense":  {"debris": 7.0, "small": 2.0, "medium": 2.0, "large": 0.8},
}


def make_iid():
    return str(uuid.uuid4())


# ---------------------------------------------------------------------------
# Sketch parsing
# ---------------------------------------------------------------------------
class Sketch:
    def __init__(self):
        self.name = None
        self.biome = "Caves"
        self.floor = FLOOR_DEFAULT
        self.density = "sparse"
        self.seed = 0
        self.spawn_zones = []
        self.markers = []
        self.extractions = []
        self.grid = []           # list of rows (strings)


def parse_kv(text):
    """'k=v k2=v2' -> dict"""
    out = {}
    for tok in text.split():
        if "=" in tok:
            k, v = tok.split("=", 1)
            out[k] = v
    return out


def parse_sketch(path):
    sk = Sketch()
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()
    it = iter(range(len(lines)))
    in_grid = False
    for i in it:
        line = lines[i]
        if in_grid:
            row = line.rstrip()
            if row.strip() == "":
                continue
            sk.grid.append(row)
            continue
        stripped = line.split("#", 1)[0].strip() if not line.strip().startswith("#") else ""
        if not stripped:
            continue
        if stripped == "grid:":
            in_grid = True
            continue
        if "=" not in stripped:
            raise ValueError(f"{path}:{i + 1}: cannot parse line: {line!r}")
        key, val = (s.strip() for s in stripped.split("=", 1))
        if key == "name":
            sk.name = val
        elif key == "biome":
            sk.biome = val
        elif key == "floor":
            a, b = val.split(",")
            sk.floor = (int(a), int(b))
        elif key == "density":
            if val not in DENSITY_PRESETS:
                raise ValueError(f"{path}: unknown density {val!r}")
            sk.density = val
        elif key == "seed":
            sk.seed = int(val)
        elif key == "spawn_zone":
            sk.spawn_zones.append(parse_kv(val))
        elif key == "marker":
            sk.markers.append(parse_kv(val))
        elif key == "extraction":
            sk.extractions.append(parse_kv(val))
        else:
            raise ValueError(f"{path}:{i + 1}: unknown key {key!r}")
    if not sk.name:
        raise ValueError(f"{path}: missing 'name ='")
    return sk


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
def validate(sk):
    errors = []
    g = sk.grid
    if len(g) != BLOCK_H:
        errors.append(f"grid has {len(g)} rows, expected {BLOCK_H}")
    for y, row in enumerate(g):
        if len(row) != BLOCK_W:
            errors.append(f"row {y} has {len(row)} chars, expected {BLOCK_W}")
        for x, ch in enumerate(row):
            if ch not in LEGEND:
                errors.append(f"row {y} col {x}: unknown char {ch!r}")
    if errors:
        return errors

    def walk(x, y):
        return g[y][x] in WALKABLE

    # border columns must be solid
    for y in range(BLOCK_H):
        if g[y][0] != "#" or g[y][BLOCK_W - 1] != "#":
            errors.append(f"row {y}: border columns (0 and {BLOCK_W - 1}) must be '#'")
            break
    # seam rows: rows 0-2 and 57-59 walkable across cols 2..78 (block_architecture.md §2)
    for y in list(range(3)) + list(range(BLOCK_H - 3, BLOCK_H)):
        bad = [x for x in range(2, BLOCK_W - 2) if not walk(x, y)]
        if bad:
            errors.append(f"seam row {y} has solid cells at cols {bad[:8]}{'...' if len(bad) > 8 else ''}")

    # connectivity: flood fill from top seam must reach bottom seam
    seen = set()
    stack = [(x, 0) for x in range(2, BLOCK_W - 2) if walk(x, 0)]
    seen.update(stack)
    while stack:
        x, y = stack.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < BLOCK_W and 0 <= ny < BLOCK_H and (nx, ny) not in seen and walk(nx, ny):
                seen.add((nx, ny))
                stack.append((nx, ny))
    if not any((x, BLOCK_H - 1) in seen for x in range(2, BLOCK_W - 2)):
        errors.append("no walkable path from top seam to bottom seam")
    orphans = sum(1 for y in range(BLOCK_H) for x in range(BLOCK_W)
                  if walk(x, y) and (x, y) not in seen)
    if orphans:
        errors.append(f"{orphans} walkable cells unreachable from top seam (orphaned pockets)")

    # corridor width: every walkable cell must be inside some fully-walkable 3x3 window
    def in_3x3(x, y):
        for cx in range(max(1, x - 1), min(BLOCK_W - 1, x + 2)):
            for cy in range(max(1, y - 1), min(BLOCK_H - 1, y + 2)):
                if all(walk(cx + dx, cy + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                    return True
        return False

    narrow = [(x, y) for y in range(BLOCK_H) for x in range(1, BLOCK_W - 1)
              if walk(x, y) and not in_3x3(x, y)]
    if narrow:
        errors.append(f"{len(narrow)} walkable cells in passages narrower than 3 tiles, "
                      f"first at {narrow[0]} (player needs 24px clearance)")

    # interior solid blobs must be at least 3 wide and 4 tall to render properly
    seen_s = set()
    for y in range(BLOCK_H):
        for x in range(1, BLOCK_W - 1):
            if g[y][x] == "#" and (x, y) not in seen_s:
                comp = [(x, y)]
                seen_s.add((x, y))
                stack = [(x, y)]
                while stack:
                    cx, cy = stack.pop()
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = cx + dx, cy + dy
                        if (0 <= nx < BLOCK_W and 0 <= ny < BLOCK_H
                                and (nx, ny) not in seen_s and g[ny][nx] == "#"):
                            seen_s.add((nx, ny))
                            stack.append((nx, ny))
                            comp.append((nx, ny))
                if any(cx in (0, BLOCK_W - 1) for cx, cy in comp):
                    continue  # attached to border — any shape ok
                xs = [c[0] for c in comp]
                ys = [c[1] for c in comp]
                w, h = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
                if h == 1:
                    continue  # 1-row rim line — supported
                if w < 3 or h < 4:
                    errors.append(f"solid blob at ({min(xs)},{min(ys)}) is {w}x{h}; "
                                  f"interior blobs must be >=3 wide and >=4 tall (or exactly 1 tall for rims)")
    if not sk.spawn_zones:
        errors.append("no spawn_zone defined (block_architecture.md §3: at least one required)")
    return errors


# ---------------------------------------------------------------------------
# Wall / floor rendering
# ---------------------------------------------------------------------------
class TilePainter:
    """Accumulates tiles per layer, ONE tile per cell (later put replaces earlier).

    The game's LdtkLoader renders each LDtk layer as a single TileMapLayer via
    set_cell — one tile per cell, no stacking. Overlay-over-base effects must
    therefore use a higher layer (Cave_Pillars renders above Cave_Tiles), never
    stacked tiles within one layer.
    """

    def __init__(self):
        self.layers = defaultdict(dict)   # layer -> {(px, py): (srcx, srcy, flip)}

    def put(self, layer, x, y, src, flip=0, grid=GRID):
        self.layers[layer][(x * grid, y * grid)] = (src[0], src[1], flip)

    def put_px(self, layer, px, py, src_x, src_y, flip=0):
        self.layers[layer][(px, py)] = (src_x, src_y, flip)

    def tiles(self, layer):
        return [(px, py, s[0], s[1], s[2]) for (px, py), s in self.layers[layer].items()]


def render_structure(sk, rng):
    """Floor flood + wall grammar. Returns (TilePainter, intgrid list)."""
    g = sk.grid
    p = TilePainter()
    intgrid = [0] * (BLOCK_W * BLOCK_H)

    def cell(x, y):
        if 0 <= x < BLOCK_W and 0 <= y < BLOCK_H:
            return g[y][x]
        return "#"  # out of bounds = solid

    # --- floor + intgrid ---
    for y in range(BLOCK_H):
        for x in range(BLOCK_W):
            ch = cell(x, y)
            if ch in WALKABLE:
                intgrid[y * BLOCK_W + x] = IG_SPAWNBLOCK if ch == "," else IG_FLOOR
                p.put("Cave_Tiles", x, y, FLOOR_PATH if ch == "-" else sk.floor)
            elif ch == "#":
                intgrid[y * BLOCK_W + x] = IG_WALL if 0 < x < BLOCK_W - 1 else 0

    # --- map border columns ---
    for y in range(BLOCK_H):
        p.put("Cave_Tiles", 0, y, BORDER_L)
        p.put("Cave_Tiles", BLOCK_W - 1, y, BORDER_R)

    # --- interior solid runs, column by column ---
    # classify per-column vertical runs of '#' (excluding border columns)
    runs_by_col = defaultdict(list)
    for x in range(1, BLOCK_W - 1):
        y = 0
        while y < BLOCK_H:
            if cell(x, y) == "#":
                y0 = y
                while y < BLOCK_H and cell(x, y) == "#":
                    y += 1
                runs_by_col[x].append((y0, y - 1))
            else:
                y += 1

    roles = {}   # (x, y) -> row role of solid cells, for the gap-ramp pass
    for x, runs in runs_by_col.items():
        for (y0, y1) in runs:
            h = y1 - y0 + 1
            left_open = cell(x - 1, y0) in WALKABLE or x == 1
            right_open = cell(x + 1, y0) in WALKABLE or x == BLOCK_W - 2
            edge_left = cell(x - 1, (y0 + y1) // 2) in WALKABLE
            edge_right = cell(x + 1, (y0 + y1) // 2) in WALKABLE

            if h == 1:
                # thin rim line (choke north lip): scallop overlay on Cave_Pillars.
                # Base tile continues whatever is above the rim (regular floor above ->
                # regular floor behind the scallops; corridor above -> darker dirt).
                base = RIM_BASE if cell(x, y0 - 1) == "-" else sk.floor
                p.put("Cave_Tiles", x, y0, base)
                p.put("Cave_Pillars", x, y0, rng.choice(RIM_PIECES))
                if cell(x - 1, y0) in WALKABLE and cell(x - 1, y0 - 1) in WALKABLE:
                    p.put("Cave_Pillars", x - 1, y0, RIM_CAP_L)
                if cell(x + 1, y0) in WALKABLE and cell(x + 1, y0 - 1) in WALKABLE:
                    p.put("Cave_Pillars", x + 1, y0, RIM_CAP_R)
                continue

            at_top = y0 == 0
            # row roles from bottom: face_bot, face_mid, face_top, then void, then cap
            rows = {}
            rows[y1] = "face_bot"
            if y1 - 1 >= y0:
                rows[y1 - 1] = "face_mid"
            if y1 - 2 >= y0:
                rows[y1 - 2] = "face_top"
            for y in range(y0, max(y0, y1 - 2)):
                rows[y] = "void"
            if not at_top and h >= 4:
                rows[y0] = "cap"

            for y in range(y0, y1 + 1):
                role = rows[y]
                roles[(x, y)] = role
                if role == "cap":
                    p.put("Cave_Tiles", x, y, CAP_ROW)
                    if edge_left:
                        p.put("Cave_Pillars", x, y, CAP_CORNER_L)
                    elif edge_right:
                        p.put("Cave_Pillars", x, y, CAP_CORNER_R)
                    else:
                        p.put("Cave_Pillars", x, y, rng.choice(CAP_INNER))
                elif role == "void":
                    if edge_left:
                        p.put("Cave_Tiles", x, y, EDGE_L["void"])
                    elif edge_right:
                        p.put("Cave_Tiles", x, y, EDGE_R["void"])
                    else:
                        p.put("Cave_Tiles", x, y, VOID)
                elif role == "face_top":
                    if y == y0 and not at_top and cell(x, y0 - 1) in WALKABLE:
                        # run's top row with walkable above (ridge seen from behind):
                        # scalloped rim, base continues the tile above
                        base = RIM_BASE if cell(x, y0 - 1) == "-" else sk.floor
                        p.put("Cave_Tiles", x, y, base)
                        p.put("Cave_Pillars", x, y, rng.choice(RIM_PIECES))
                    elif edge_left:
                        p.put("Cave_Tiles", x, y, EDGE_L["face_top"])
                    elif edge_right:
                        p.put("Cave_Tiles", x, y, EDGE_R["face_top"])
                    else:
                        p.put("Cave_Tiles", x, y, rng.choice(FACE_TOP))
                elif role == "face_mid":
                    if edge_left:
                        p.put("Cave_Tiles", x, y, EDGE_L["face_mid"])
                    elif edge_right:
                        p.put("Cave_Tiles", x, y, EDGE_R["face_mid"])
                    else:
                        p.put("Cave_Tiles", x, y, rng.choice(FACE_MID))
                elif role == "face_bot":
                    if edge_left:
                        p.put("Cave_Tiles", x, y, EDGE_L["trim"])
                    elif edge_right:
                        p.put("Cave_Tiles", x, y, EDGE_R["trim"])
                    else:
                        p.put("Cave_Tiles", x, y, rng.choice(FACE_BOT))

            # gap side trims: only where a path cuts past the face rows
            # (plain-floor neighbors get nothing — pillars stay clean).
            # Partially transparent -> Cave_Pillars so the path shows through.
            if left_open and h >= 3 and cell(x - 1, y1 - 1) == "-":
                p.put("Cave_Pillars", x - 1, y1 - 1, GAP_EDGE_L)
            if right_open and h >= 3 and cell(x + 1, y1 - 1) == "-":
                p.put("Cave_Pillars", x + 1, y1 - 1, GAP_EDGE_R)

    # --- gap dressing: a walkable span cutting through a ridge face gets the
    # darker fill, side trims, and a 3-row shaded apron below (hand-painted
    # 03_Choke gap grammar; the shading comes from the shadows tileset) ---
    for y in range(BLOCK_H):
        x = 1
        while x < BLOCK_W - 1:
            if cell(x, y) in WALKABLE and roles.get((x - 1, y)) == "face_mid":
                gx0 = x
                while x < BLOCK_W - 1 and cell(x, y) in WALKABLE:
                    x += 1
                if roles.get((x, y)) == "face_mid" and x - gx0 <= 14:
                    span = list(range(gx0, x))
                    # darker dirt fill through the cut (rim + lit-face rows);
                    # all opaque -> replace floor on Cave_Tiles directly
                    for gx in span:
                        p.put("Cave_Tiles", gx, y - 1, GAP_FILL)
                        p.put("Cave_Tiles", gx, y, GAP_FILL)
                    p.put("Cave_Tiles", span[0], y, GAP_SIDE_L)
                    p.put("Cave_Tiles", span[-1], y, GAP_SIDE_R)
                    # apron: rows at face_bot and two below, tapering to scallops.
                    # Row 128 is opaque (Cave_Tiles); rows 136/144 have transparent
                    # pixels and must overlay on Cave_Pillars (renders above) so
                    # the floor shows through in-game.
                    for row_i, ysrc in enumerate(APRON_YS):
                        yy = y + 1 + row_i
                        if yy >= BLOCK_H:
                            break
                        layer = "Cave_Tiles" if row_i == 0 else "Cave_Pillars"
                        cols = span if row_i < 2 else span[1:-1]
                        if row_i == 2:
                            p.put("Cave_Tiles", span[0], yy, APRON_SCALLOP)
                            p.put("Cave_Tiles", span[-1], yy, APRON_SCALLOP)
                        for i, gx in enumerate(cols):
                            if i == 0:
                                xs = APRON_X_END_L
                            elif i == len(cols) - 1:
                                xs = APRON_X_END_R
                            else:
                                xs = rng.choice(APRON_X_MID)
                            p.put(layer, gx, yy, (xs, ysrc))
                continue
            x += 1

    # --- SW shadows for interior blobs (pillar look) ---
    seen = set()
    for y in range(BLOCK_H):
        for x in range(1, BLOCK_W - 1):
            if cell(x, y) == "#" and (x, y) not in seen and cell(x - 1, y) in WALKABLE:
                # left edge of a blob: walk down its left side
                y0 = y
                while cell(x, y0 - 1) == "#" and cell(x - 1, y0 - 1) in WALKABLE:
                    y0 -= 1
                y1 = y0
                while cell(x, y1 + 1) == "#" and cell(x - 1, y1 + 1) in WALKABLE:
                    y1 += 1
                for yy in range(y0, y1 + 1):
                    seen.add((x, yy))
                if y1 - y0 + 1 >= 3:  # only meaningful blobs get shadows
                    seq = SHADOW_LEFT
                    for i, yy in enumerate(range(y0 + 1, min(y1 + 1, y0 + 1 + len(seq)))):
                        p.put("CavesShadows", x - 1, yy, seq[min(i, len(seq) - 1)])
    return p, intgrid


# ---------------------------------------------------------------------------
# Decorator — prop stamps
# ---------------------------------------------------------------------------
def decorate(sk, painter, rng):
    with open(STYLE_PACK, encoding="utf-8") as f:
        pack = json.load(f)
    stamps_by_class = defaultdict(list)
    for s in pack["stamps"]:
        stamps_by_class[s["class"]].append(s)
    grid2 = pack["grid"]  # 2px

    g = sk.grid
    floor_cells = [(x, y) for y in range(BLOCK_H) for x in range(BLOCK_W)
                   if g[y][x] == "."]  # plain floor only: keep paths/seams cleaner
    n_floor = sum(1 for y in range(BLOCK_H) for x in range(BLOCK_W) if g[y][x] in WALKABLE)

    preset = DENSITY_PRESETS[sk.density]
    occupied = set()   # 8px cells already claimed by a stamp (loose spacing)

    def try_place(stamp, attempts=40):
        w_t = max(1, (stamp["w_cells"] * grid2 + GRID - 1) // GRID)   # width in 8px tiles
        h_t = max(1, (stamp["h_cells"] * grid2 + GRID - 1) // GRID)
        for _ in range(attempts):
            x, y = rng.choice(floor_cells)
            # keep off the seams so stitching always reads clean
            if y < 4 or y > BLOCK_H - 5 - h_t:
                continue
            cells = [(x + dx, y + dy) for dx in range(w_t) for dy in range(h_t)]
            pad = [(x + dx, y + dy) for dx in range(-1, w_t + 1) for dy in range(-1, h_t + 1)]
            if any(not (0 <= cx < BLOCK_W and 0 <= cy < BLOCK_H) or g[cy][cx] != "."
                   for cx, cy in cells):
                continue
            if stamp["class"] != "debris" and any(c in occupied for c in pad):
                continue
            for c in cells:
                occupied.add(c)
            # paint: stamp coords are in 2px cells relative to stamp origin
            ox, oy = x * GRID, y * GRID
            for (dx, dy, sx, sy, fl) in stamp["tiles"]:
                painter.put_px(stamp["layer"], ox + dx * grid2, oy + dy * grid2, sx, sy, fl)
            if stamp["shadow_layer"]:
                for (dx, dy, sx, sy, fl) in stamp["shadow_tiles"]:
                    px_, py_ = ox + dx * grid2, oy + dy * grid2
                    if 0 <= px_ < BLOCK_W * GRID and 0 <= py_ < BLOCK_H * GRID:
                        painter.put_px(stamp["shadow_layer"], px_, py_, sx, sy, fl)
            return True
        return False

    placed = {c: 0 for c in preset}
    for cls in ("large", "medium", "small", "debris"):
        pool = stamps_by_class.get(cls, [])
        if not pool:
            continue
        target = round(preset[cls] * n_floor / 1000.0)
        weights = [s["count"] for s in pool]
        for _ in range(target):
            stamp = rng.choices(pool, weights=weights, k=1)[0]
            if try_place(stamp):
                placed[cls] += 1
    return placed


# ---------------------------------------------------------------------------
# LDtk emission
# ---------------------------------------------------------------------------
class ProjectDefs:
    """Resolves identifiers -> uids from the parent .ldtk so nothing is hardcoded."""

    def __init__(self, project):
        self.project = project
        self.layers = {ld["identifier"]: ld for ld in project["defs"]["layers"]}
        self.tilesets = {ts["identifier"]: ts for ts in project["defs"]["tilesets"]}
        self.tilesets_by_uid = {ts["uid"]: ts for ts in project["defs"]["tilesets"]}
        self.entities = {ed["identifier"]: ed for ed in project["defs"]["entities"]}

    def entity_field(self, entity, field):
        ed = self.entities[entity]
        for fd in ed["fieldDefs"]:
            if fd["identifier"] == field:
                return fd
        raise KeyError(f"{entity}.{field}")

    def tile_id(self, tileset_uid, src):
        ts = self.tilesets_by_uid[tileset_uid]
        grid = ts["tileGridSize"]
        cwid = ts["pxWid"] // grid
        return (src[1] // grid) * cwid + (src[0] // grid)


def build_field(defs, entity, field, ftype, value, editor_val=None):
    fd = defs.entity_field(entity, field)
    inst = {"__identifier": field, "__type": ftype, "__value": value,
            "__tile": None, "defUid": fd["uid"], "realEditorValues": []}
    if editor_val is not None:
        inst["realEditorValues"] = [editor_val]
    return inst


def build_entities(sk, defs):
    ents = []
    for z in sk.spawn_zones:
        if z.get("rect", "full") == "full":
            x, y, w, h = 80, 80, 488, 320
        else:
            x, y, w, h = (int(v) for v in z["rect"].split(","))
        ents.append({
            "__identifier": "EnemySpawnZone", "__grid": [x // GRID, y // GRID],
            "__pivot": [0.5, 0.5], "__tags": ["gameplay", "spawn"], "__tile": None,
            "__smartColor": "#CC2222", "iid": make_iid(), "width": w, "height": h,
            "defUid": defs.entities["EnemySpawnZone"]["uid"], "px": [x, y],
            "fieldInstances": [
                build_field(defs, "EnemySpawnZone", "phase", "LocalEnum.SpawnPhase",
                            z.get("phase", "Any"),
                            {"id": "V_String", "params": [z.get("phase", "Any")]}),
                build_field(defs, "EnemySpawnZone", "density", "LocalEnum.SpawnDensity",
                            z.get("density", "Medium"),
                            {"id": "V_String", "params": [z.get("density", "Medium")]}),
                build_field(defs, "EnemySpawnZone", "enemy_pool_override", "String", ""),
                build_field(defs, "EnemySpawnZone", "min_distance_from_player", "Float",
                            float(z.get("min_dist", 300))),
            ],
            "__worldX": x, "__worldY": y,
        })
    for m in sk.markers:
        gx, gy = (int(v) for v in m["at"].split(","))
        ents.append({
            "__identifier": "Marker", "__grid": [gx, gy], "__pivot": [0, 0],
            "__tags": ["gameplay", "marker"], "__tile": None, "__smartColor": "#FFCC22",
            "iid": make_iid(), "width": 8, "height": 8,
            "defUid": defs.entities["Marker"]["uid"], "px": [gx * GRID, gy * GRID],
            "fieldInstances": [
                build_field(defs, "Marker", "tag", "LocalEnum.MarkerTag",
                            m.get("tag", "EventTrigger"),
                            {"id": "V_String", "params": [m.get("tag", "EventTrigger")]}),
                build_field(defs, "Marker", "id", "String", m.get("id", ""),
                            {"id": "V_String", "params": [m.get("id", "")]}),
                build_field(defs, "Marker", "payload", "String", m.get("payload", ""),
                            {"id": "V_String", "params": [m.get("payload", "")]}),
            ],
            "__worldX": gx * GRID, "__worldY": gy * GRID,
        })
    for e in sk.extractions:
        gx, gy = (int(v) for v in e["at"].split(","))
        kind = e.get("kind", "Timed")
        ents.append({
            "__identifier": "Extraction", "__grid": [gx, gy], "__pivot": [0.5, 0.5],
            "__tags": ["gameplay", "extraction"], "__tile": None, "__smartColor": "#3FFF55",
            "iid": make_iid(), "width": 96, "height": 96,
            "defUid": defs.entities["Extraction"]["uid"], "px": [gx * GRID, gy * GRID],
            "fieldInstances": [
                build_field(defs, "Extraction", "kind", "LocalEnum.ExtractionType", kind,
                            {"id": "V_String", "params": [kind]}),
                build_field(defs, "Extraction", "unlock_radius", "Float",
                            float(e.get("radius", 48))),
                build_field(defs, "Extraction", "channel_seconds", "Float",
                            float(e.get("channel", 3))),
                build_field(defs, "Extraction", "notes", "String", ""),
            ],
            "__worldX": gx * GRID, "__worldY": gy * GRID,
        })
    return ents


def build_level(sk, defs, painter, intgrid, level_uid, world_x, world_y):
    layer_instances = []
    for ld in defs.project["defs"]["layers"]:
        ident = ld["identifier"]
        ts_uid = ld.get("tilesetDefUid")
        ts = defs.tilesets_by_uid.get(ts_uid) if ts_uid else None
        li = {
            "__identifier": ident,
            "__type": ld["__type"],
            "__cWid": BLOCK_W * GRID // ld["gridSize"],
            "__cHei": BLOCK_H * GRID // ld["gridSize"],
            "__gridSize": ld["gridSize"],
            "__opacity": ld.get("displayOpacity", 1),
            "__pxTotalOffsetX": 0, "__pxTotalOffsetY": 0,
            "__tilesetDefUid": ts_uid,
            "__tilesetRelPath": ts["relPath"] if ts else None,
            "iid": make_iid(),
            "levelId": level_uid,
            "layerDefUid": ld["uid"],
            "pxOffsetX": 0, "pxOffsetY": 0,
            "visible": True,
            "optionalRules": [],
            "intGridCsv": [],
            "autoLayerTiles": [],
            "seed": random.randint(1000000, 9999999),
            "overrideTilesetUid": None,
            "gridTiles": [],
            "entityInstances": [],
        }
        if ident == "Collision":
            li["intGridCsv"] = intgrid
        elif ld["__type"] == "IntGrid":
            li["intGridCsv"] = [0] * (li["__cWid"] * li["__cHei"])
        if ident == "Entities":
            li["entityInstances"] = build_entities(sk, defs)
        if ident in painter.layers and ld["__type"] == "Tiles":
            tiles = []
            for (px, py, sx, sy, fl) in painter.tiles(ident):
                tiles.append({
                    "px": [px, py],
                    "src": [sx, sy],
                    "f": fl,
                    "t": defs.tile_id(ts_uid, (sx, sy)),
                    "d": [(py // ld["gridSize"]) * li["__cWid"] + (px // ld["gridSize"])],
                    "a": 1,
                })
            li["gridTiles"] = tiles
        layer_instances.append(li)

    biome_fd = None
    schema_fd = None
    # level fields live on the project defs
    for fd in defs.project["defs"]["levelFields"]:
        if fd["identifier"] == "biome":
            biome_fd = fd
        elif fd["identifier"] == "schema_version":
            schema_fd = fd

    return {
        "__header__": {
            "fileType": "LDtk Project JSON",
            "app": "LDtk",
            "doc": "https://ldtk.io/json",
            "schema": "https://ldtk.io/files/JSON_SCHEMA.json",
            "appAuthor": "Sebastien 'deepnight' Benard",
            "appVersion": defs.project["appBuildId"] if "appBuildId" in defs.project else "1.5.3",
            "url": "https://ldtk.io",
        },
        "identifier": sk.name,
        "iid": make_iid(),
        "uid": level_uid,
        "worldX": world_x, "worldY": world_y, "worldDepth": 0,
        "pxWid": BLOCK_W * GRID, "pxHei": BLOCK_H * GRID,
        "__bgColor": "#696A79", "bgColor": None,
        "useAutoIdentifier": False,
        "bgRelPath": None, "bgPos": None, "bgPivotX": 0.5, "bgPivotY": 0.5,
        "__smartColor": "#ADADB5", "__bgPos": None,
        "externalRelPath": None,
        "fieldInstances": [
            {"__identifier": "biome", "__type": "LocalEnum.BiomeId", "__value": sk.biome,
             "__tile": None, "defUid": biome_fd["uid"],
             "realEditorValues": [{"id": "V_String", "params": [sk.biome]}]},
            {"__identifier": "schema_version", "__type": "Int", "__value": 1,
             "__tile": None, "defUid": schema_fd["uid"],
             "realEditorValues": [{"id": "V_Int", "params": [1]}]},
        ],
        "layerInstances": layer_instances,
    }


def register_level(project, level, name):
    """Add/replace the level entry in the parent project."""
    project["levels"] = [lv for lv in project["levels"] if lv["identifier"] != name]
    entry = {k: level[k] for k in (
        "identifier", "iid", "uid", "worldX", "worldY", "worldDepth",
        "pxWid", "pxHei", "__bgColor", "bgColor", "useAutoIdentifier",
        "bgRelPath", "bgPos", "bgPivotX", "bgPivotY", "__smartColor", "__bgPos",
        "fieldInstances")}
    # relative to the .ldtk project file — must include the level subfolder
    entry["externalRelPath"] = os.path.basename(LEVELS_DIR) + "/" + name + ".ldtkl"
    entry["layerInstances"] = None
    project["levels"].append(entry)
    if project.get("nextUid", 0) <= level["uid"]:
        project["nextUid"] = level["uid"] + 1


# ---------------------------------------------------------------------------
# PNG preview
# ---------------------------------------------------------------------------
# Mirrors LdtkLoader's LAYER_Z map + default (-1) — keep in sync with
# scripts/systems/ldtk_loader.gd _render_tile_layer.
LOADER_LAYER_Z = {
    "Background": -5, "CavesBackground": -5, "CryptTiles": -4,
    "FloorAuto": -3, "Cave_Tiles": -2,
    "WallsAuto": -1,
    "Decoration": 2,
}


def render_preview(level, defs, out_path, scale=2):
    """Game-accurate preview: emulates LdtkLoader rendering, NOT LDtk's.

    - one tile per cell per layer (set_cell semantics: last tile in gridTiles wins)
    - layers sorted by the loader's z-index map; equal z = child add order
      (layerInstances order), later children render on top
    """
    from PIL import Image
    img = Image.new("RGBA", (BLOCK_W * GRID, BLOCK_H * GRID), (18, 18, 22, 255))
    tileset_cache = {}

    def tileset_img(ts_uid):
        if ts_uid not in tileset_cache:
            ts = defs.tilesets_by_uid[ts_uid]
            path = os.path.normpath(os.path.join(os.path.dirname(PROJECT_PATH), ts["relPath"]))
            tileset_cache[ts_uid] = Image.open(path).convert("RGBA")
        return tileset_cache[ts_uid]

    ordered = sorted(
        (li for li in level["layerInstances"] if li["gridTiles"] and li["__tilesetDefUid"]),
        key=lambda li: LOADER_LAYER_Z.get(li["__identifier"], -1))
    for li in ordered:
        ts_uid = li["__tilesetDefUid"]
        ts = defs.tilesets_by_uid[ts_uid]
        gsz = ts["tileGridSize"]
        sheet = tileset_img(ts_uid)
        cells = {}                      # set_cell semantics: last tile per cell wins
        for t in li["gridTiles"]:
            cells[(t["px"][0], t["px"][1])] = (t["src"][0], t["src"][1], t["f"])
        for (px, py), (sx, sy, fl) in cells.items():
            tile = sheet.crop((sx, sy, sx + gsz, sy + gsz))
            if fl & 1:
                tile = tile.transpose(Image.FLIP_LEFT_RIGHT)
            if fl & 2:
                tile = tile.transpose(Image.FLIP_TOP_BOTTOM)
            img.alpha_composite(tile, (px, py))
    if scale != 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def compile_sketch(path, project, defs, preview_only=False):
    sk = parse_sketch(path)
    errors = validate(sk)
    if errors:
        print(f"FAIL {path} ({sk.name}):")
        for e in errors:
            print(f"  - {e}")
        return False

    rng = random.Random(sk.seed)
    painter, intgrid = render_structure(sk, rng)
    placed = decorate(sk, painter, rng)

    existing = {lv["identifier"]: lv for lv in project["levels"]}
    if sk.name in existing:
        level_uid = existing[sk.name]["uid"]
        world_x, world_y = existing[sk.name]["worldX"], existing[sk.name]["worldY"]
    else:
        level_uid = project.get("nextUid", 1000)
        world_x = max((lv["worldX"] + 700 for lv in project["levels"]), default=100)
        world_y = 0

    level = build_level(sk, defs, painter, intgrid, level_uid, world_x, world_y)

    preview_path = os.path.join(PREVIEW_DIR, sk.name + ".png")
    render_preview(level, defs, preview_path)

    if not preview_only:
        out_path = os.path.join(LEVELS_DIR, sk.name + ".ldtkl")
        with open(out_path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(level, f, indent="\t", ensure_ascii=False)
            f.write("\n")
        register_level(project, level, sk.name)
        print(f"OK   {sk.name}: {out_path}")
    else:
        print(f"OK   {sk.name}: (preview only)")
    print(f"     props placed: {placed}   preview: {preview_path}")
    return True


def main():
    args = [a for a in sys.argv[1:]]
    preview_only = "--preview-only" in args
    paths = [a for a in args if not a.startswith("--")]
    if not paths:
        print(__doc__)
        sys.exit(1)

    with open(PROJECT_PATH, encoding="utf-8") as f:
        project = json.load(f)
    defs = ProjectDefs(project)

    ok = True
    for path in paths:
        ok &= compile_sketch(path, project, defs, preview_only)

    if ok and not preview_only:
        with open(PROJECT_PATH, "w", encoding="utf-8", newline="\n") as f:
            json.dump(project, f, indent="\t", ensure_ascii=False)
            f.write("\n")
        print(f"Registered in {PROJECT_PATH}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
