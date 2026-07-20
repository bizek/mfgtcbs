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
PLATFORM = "P"        # nmrealm only: raised platform (solid, on top of island floor)
RUINWALL = "W"        # nmrealm only: ruined wall line (walkable decor, like Ben's)
LEGEND = WALKABLE | SOLID | {PLATFORM, RUINWALL}

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
APRON_SCALLOP = (168, 96)


def apron_xs(n, lo=232, hi=280):
    """The apron is a designed strip (lo..hi step 8): left edge, gradient middle,
    right edge. Sample it proportionally IN ORDER — never shuffle, the tiles only
    read as a ramp in sequence."""
    if n <= 1:
        return [lo] * max(n, 0)
    return [lo + 8 * round(i * (hi - lo) / 8 / (n - 1)) for i in range(n)]
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

# ---------------------------------------------------------------------------
# Crypt visual grammar (from Block_Crypt_00_Entry + the CryptLayer auto-rules)
# ---------------------------------------------------------------------------
# Architectural brick walls: a top row, then repeating two-row brick courses.
# The brick floor itself is NOT hand-painted: the CryptLayer IntGrid's active
# auto-rules bake it (incl. edge trims where floor meets wall) — the compiler
# evaluates those rules from the project defs, so an LDtk re-save re-bakes
# identically.
CRYPT_TOP = [(72, 104), (64, 104)]        # wall top row (weighted: variant rare)
CRYPT_COURSE_A = [(72, 112), (64, 112)]   # brick course, upper row
CRYPT_COURSE_B = [(72, 120), (64, 120)]   # brick course, lower row
CRYPT_BORDER_L, CRYPT_BORDER_R = (32, 64), (80, 64)
CRYPT_FLOOR_LAYER = "CryptLayer"          # IntGrid whose rules bake the floor
CRYPT_WALL_LAYER = "CryptTiles"

# ---------------------------------------------------------------------------
# Nightmare Realm visual grammar (mined from the asset pack's premade scene by
# tools/extract_nmrealm_style.py — see block_style_nmrealm.json)
# ---------------------------------------------------------------------------
# Inverted world: `#` is VOID (black emptiness the island floats in), walkable
# cells are the island. The island surface + scalloped edges are baked from
# Ben's 33 EtherealAutoLayer auto-rules (Solid_Tileset).
NM_FLOOR_LAYER = "EtherealAutoLayer"      # IntGrid whose rules bake the island
NM_WALL_LAYER = "Ethereal_Walls"
NM_DETAIL_LAYER = "Ethereal_Floor"        # scratch decals over the baked floor

# `P` raised platform — Ben's rectangle grammar (decoded from his touched-up
# Isles): cap row on top, edged fill interior, 3-row face at the bottom.
NM_PLAT_TOP_TL, NM_PLAT_TOP_TR = (208, 376), (224, 440)
NM_PLAT_TOP_MID = [(128, 448)] * 6 + [(40, 448)] * 2 + [(216, 440)] * 2
NM_PLAT_EDGE_L, NM_PLAT_EDGE_R = (104, 472), (224, 448)
NM_PLAT_FILL = (216, 312)
NM_PLAT_FACE_L = [(16, 480), (16, 488), (16, 496)]
NM_PLAT_FACE_R = [(240, 480), (240, 488), (240, 496)]
NM_PLAT_FACE_COLS = [    # (3-row column family, weight)
    ([(40, 512), (40, 520), (40, 528)], 5),
    ([(216, 344), (216, 80), (200, 496)], 3),
    ([(128, 512), (128, 520), (128, 528)], 2),
]

# `W` ruined wall lines (from Ben's Isles wall assemblies): horizontal walls
# are 3-column end caps + repeating crumble courses (caps carry a 4th top row,
# courses don't -> ragged silhouette); vertical walls are single brick columns,
# optionally spire-capped. Walkable decor — Ben gives them no collision.
NM_HWALL_CAP_L = [(512, 320), (520, 320), (528, 320)]   # top row of the caps
NM_HWALL_CAP_COLS_L = [512, 520, 528]
NM_HWALL_CAP_COLS_R = [544, 552, 560]
NM_HWALL_CAP_ROWS = [328, 336, 344]
NM_HWALL_COURSE = [(536, 328), (536, 336), (536, 344)]
NM_HWALL_COURSE_VAR = [(536, 360), (536, 368), (536, 376)]
NM_VWALL_TOP = (560, 432)
NM_VWALL_BODY = [(560, 440), (560, 448)]
NM_VWALL_BOT = [(560, 456), (560, 464), (560, 472)]
NM_SPIRE = [(464, 400), (472, 400), (480, 400),         # 3x4 broken-spire cap
            (464, 408), (472, 408), (480, 408),
            (464, 416), (472, 416), (480, 416),
            (464, 424), (472, 424), (480, 424)]

STYLES = {
    "caves": {
        "pack": STYLE_PACK,
        "min_blob_w": 3, "min_blob_h": 4, "rims": True,
        "world_y": 0,
    },
    "crypt": {
        "pack": os.path.join(ROOT, "tools", "block_style_crypt.json"),
        "min_blob_w": 2, "min_blob_h": 2, "rims": False,
        "world_y": 506,   # Block_Crypt_00_Entry's row in the LDtk world view
    },
    "nmrealm": {
        "pack": os.path.join(ROOT, "tools", "block_style_nmrealm.json"),
        "min_blob_w": 3, "min_blob_h": 3, "rims": False,
        "world_y": 1006,  # Block_NMRealm_00_Entry2's row in the LDtk world view
        # prop densities measured from Ben's Entry + Isles ("normal" = his look)
        "density_presets": {
            "none":   {"debris": 0.0, "small": 0.0, "medium": 0.0, "large": 0.0},
            "sparse": {"debris": 1.7, "small": 0.5, "medium": 1.8, "large": 0.9},
            "normal": {"debris": 2.8, "small": 0.8, "medium": 3.0, "large": 1.6},
            "dense":  {"debris": 4.2, "small": 1.2, "medium": 4.5, "large": 2.3},
        },
    },
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
        self.style = "caves"     # visual grammar: caves | crypt
        self.floor = FLOOR_DEFAULT
        self.density = "sparse"
        self.scratches = "off"   # nmrealm ground scarring: off = Ben hand-paints
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
        elif key == "style":
            if val not in STYLES:
                raise ValueError(f"{path}: unknown style {val!r}")
            sk.style = val
        elif key == "floor":
            a, b = val.split(",")
            sk.floor = (int(a), int(b))
        elif key == "density":
            if val not in DENSITY_PRESETS:
                raise ValueError(f"{path}: unknown density {val!r}")
            sk.density = val
        elif key == "scratches":
            if val not in ("off", "auto"):
                raise ValueError(f"{path}: scratches must be off|auto, got {val!r}")
            sk.scratches = val
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
# Validation helpers (pure functions on sketch)
# ---------------------------------------------------------------------------
def check_obstacle_islands(sk, min_size=2):
    """Flood fill over '#' cells; flag interior islands too small to see at game scale.

    A tiny isolated collision blob (1×1, 2×1, etc.) is invisible at 640×360 during
    combat but fully blocks movement — the classic snag.  Border-attached cells are
    exempt (they are part of the map boundary, always rendered as walls).  For caves
    style, 1-row rim *lines* (h==1, w>=min_size) are also exempt — the scalloped rim
    grammar makes them visually present.
    """
    errors = []
    g = sk.grid
    style = STYLES[sk.style]
    seen = set()
    for y in range(BLOCK_H):
        for x in range(BLOCK_W):
            if g[y][x] != "#" or (x, y) in seen:
                continue
            comp = []
            stack = [(x, y)]
            seen.add((x, y))
            while stack:
                cx, cy = stack.pop()
                comp.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if (0 <= nx < BLOCK_W and 0 <= ny < BLOCK_H
                            and (nx, ny) not in seen and g[ny][nx] == "#"):
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if any(cx in (0, BLOCK_W - 1) or cy in (0, BLOCK_H - 1)
                   for cx, cy in comp):
                continue  # attached to outer border — exempt
            xs = [c[0] for c in comp]
            ys = [c[1] for c in comp]
            w = max(xs) - min(xs) + 1
            h = max(ys) - min(ys) + 1
            area = len(comp)
            # caves 1-row rim lines (e.g. choke lip) are visually scalloped — exempt
            # them as long as the line is wide enough to register during gameplay
            if h == 1 and style.get("rims", False) and w >= min_size:
                continue
            if w < min_size or h < min_size or area < 3:
                errors.append(
                    f"obstacle island at ({min(xs)},{min(ys)}) "
                    f"bbox={w}x{h} area={area}: too small to see at game scale "
                    f"(need bbox>={min_size}x{min_size} and area>=3)"
                )
    return errors


def check_narrow_corridors(sk):
    """Warn on walkable runs exactly 1 cell wide for more than 4 connected cells.

    A 1-cell (8px) corridor causes the same snag as a small obstacle island but
    from the walkable side — enemies and the player both clip on the invisible
    micro-walls at each edge.  Runs of 1-4 cells are tolerable (doorway slivers);
    anything longer is a design error to fix.
    """
    warnings_out = []
    g = sk.grid

    def walk(x, y):
        if not (0 <= x < BLOCK_W and 0 <= y < BLOCK_H):
            return False
        return g[y][x] in WALKABLE or g[y][x] == RUINWALL

    def is_1wide(x, y):
        return ((not walk(x, y - 1) and not walk(x, y + 1)) or
                (not walk(x - 1, y) and not walk(x + 1, y)))

    seen = set()
    for y in range(BLOCK_H):
        for x in range(BLOCK_W):
            if not walk(x, y) or not is_1wide(x, y) or (x, y) in seen:
                continue
            comp = []
            stack = [(x, y)]
            seen.add((x, y))
            while stack:
                cx, cy = stack.pop()
                comp.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if (0 <= nx < BLOCK_W and 0 <= ny < BLOCK_H
                            and (nx, ny) not in seen
                            and walk(nx, ny) and is_1wide(nx, ny)):
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if len(comp) > 4:
                xs = [c[0] for c in comp]
                ys = [c[1] for c in comp]
                warnings_out.append(
                    f"narrow corridor at ({min(xs)},{min(ys)}) "
                    f"is 1 cell wide for {len(comp)} cells "
                    f"(snag risk; max tolerable is 4)"
                )
    return warnings_out


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
def validate(sk, min_obstacle_size=2):
    errors = []
    warnings = []
    g = sk.grid
    if len(g) != BLOCK_H:
        errors.append(f"grid has {len(g)} rows, expected {BLOCK_H}")
    for y, row in enumerate(g):
        if len(row) != BLOCK_W:
            errors.append(f"row {y} has {len(row)} chars, expected {BLOCK_W}")
        for x, ch in enumerate(row):
            if ch not in LEGEND:
                errors.append(f"row {y} col {x}: unknown char {ch!r}")
            elif ch in (PLATFORM, RUINWALL) and sk.style != "nmrealm":
                errors.append(f"row {y} col {x}: {ch!r} is nmrealm-only")
    if errors:
        return errors, []

    def walk(x, y):
        # RUINWALL is walkable decor (Ben's convention: no collision on ruins)
        return g[y][x] in WALKABLE or g[y][x] == RUINWALL

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
                style = STYLES[sk.style]
                if h == 1:
                    if not style["rims"]:
                        errors.append(f"solid blob at ({min(xs)},{min(ys)}) is 1 row tall; "
                                      f"style '{sk.style}' has no rim grammar")
                    continue  # 1-row rim line — supported by caves
                if w < style["min_blob_w"] or h < style["min_blob_h"]:
                    errors.append(f"solid blob at ({min(xs)},{min(ys)}) is {w}x{h}; "
                                  f"style '{sk.style}' needs >={style['min_blob_w']} wide "
                                  f"and >={style['min_blob_h']} tall")
    # nmrealm platforms: blobs of P, min 3x4 (top row + 3-row south face), fully
    # surrounded by island floor (the learned grammar was mined island-interior),
    # and clear of seams
    if sk.style == "nmrealm":
        seen_p = set()
        for y in range(BLOCK_H):
            for x in range(BLOCK_W):
                if g[y][x] != PLATFORM or (x, y) in seen_p:
                    continue
                comp = [(x, y)]
                seen_p.add((x, y))
                stack = [(x, y)]
                while stack:
                    cx, cy = stack.pop()
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = cx + dx, cy + dy
                        if (0 <= nx < BLOCK_W and 0 <= ny < BLOCK_H
                                and (nx, ny) not in seen_p and g[ny][nx] == PLATFORM):
                            seen_p.add((nx, ny))
                            stack.append((nx, ny))
                            comp.append((nx, ny))
                xs = [c[0] for c in comp]
                ys = [c[1] for c in comp]
                w, h = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
                if w < 3 or h < 4:
                    errors.append(f"platform at ({min(xs)},{min(ys)}) is {w}x{h}; "
                                  f"needs >=3 wide and >=4 tall (top + 3-row face)")
                if len(comp) != w * h:
                    errors.append(f"platform at ({min(xs)},{min(ys)}) is not rectangular "
                                  f"(Ben's platform grammar is cap/fill/face rows)")
                if min(ys) < 4 or max(ys) > BLOCK_H - 6 or min(xs) < 3 or max(xs) > BLOCK_W - 4:
                    errors.append(f"platform at ({min(xs)},{min(ys)}) too close to seams/border")
                bad = next(((cx + dx, cy + dy) for cx, cy in comp
                            for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                            if 0 <= cx + dx < BLOCK_W and 0 <= cy + dy < BLOCK_H
                            and g[cy + dy][cx + dx] not in WALKABLE
                            and g[cy + dy][cx + dx] != PLATFORM), None)
                if bad:
                    errors.append(f"platform at ({min(xs)},{min(ys)}) touches void at {bad}; "
                                  f"platforms must sit on island floor")
        # ruined walls: straight 1-cell lines, horizontal len>=8 (two 3-col caps
        # + courses) or vertical len>=5; must not hang into the void
        seen_w = set()
        for y in range(BLOCK_H):
            for x in range(BLOCK_W):
                if g[y][x] != RUINWALL or (x, y) in seen_w:
                    continue
                comp = [(x, y)]
                seen_w.add((x, y))
                stack = [(x, y)]
                while stack:
                    cx, cy = stack.pop()
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = cx + dx, cy + dy
                        if (0 <= nx < BLOCK_W and 0 <= ny < BLOCK_H
                                and (nx, ny) not in seen_w and g[ny][nx] == RUINWALL):
                            seen_w.add((nx, ny))
                            stack.append((nx, ny))
                            comp.append((nx, ny))
                xs = [c[0] for c in comp]
                ys = [c[1] for c in comp]
                w, h = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
                if not ((h == 1 and w == len(comp)) or (w == 1 and h == len(comp))):
                    errors.append(f"ruined wall at ({min(xs)},{min(ys)}) must be a straight "
                                  f"1-cell horizontal or vertical line")
                elif h == 1 and w < 8:
                    errors.append(f"horizontal ruined wall at ({min(xs)},{min(ys)}) is {w} long; "
                                  f"needs >=8 (3-col caps + courses)")
                elif w == 1 and h < 5:
                    errors.append(f"vertical ruined wall at ({min(xs)},{min(ys)}) is {h} long; "
                                  f"needs >=5")
                if h == 1 and any(not (0 <= yy < BLOCK_H) or g[yy][cx] == "#"
                                  for cx, cy in comp for yy in (cy + 1, cy + 2, cy + 3)):
                    errors.append(f"horizontal ruined wall at ({min(xs)},{min(ys)}) needs 3 "
                                  f"non-void rows below (courses render there)")
    if not sk.spawn_zones:
        errors.append("no spawn_zone defined (block_architecture.md §3: at least one required)")
    errors += check_obstacle_islands(sk, min_obstacle_size)
    warnings += check_narrow_corridors(sk)
    return errors, warnings


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


class TileOpacity:
    """Per-tile opacity check against the tileset PNG. Semi-transparent structural
    tiles (trims, some face tiles) were designed to stack over floor in LDtk;
    the game renders one tile per cell, so they need a floor underlay on
    Cave_Tiles with the tile itself overlaid on Cave_Pillars."""

    def __init__(self, sheet_path):
        from PIL import Image
        self.img = Image.open(sheet_path).convert("RGBA")
        self.cache = {}

    def opaque(self, src):
        if src not in self.cache:
            tile = self.img.crop((src[0], src[1], src[0] + GRID, src[1] + GRID))
            alpha = tile.getchannel("A")
            self.cache[src] = alpha.getextrema()[0] > 0
        return self.cache[src]


def render_structure(sk, rng, defs):
    """Floor flood + wall grammar. Returns (TilePainter, intgrid list)."""
    g = sk.grid
    p = TilePainter()
    intgrid = [0] * (BLOCK_W * BLOCK_H)

    caves_ts = defs.tilesets_by_uid[defs.layers["Cave_Tiles"]["tilesetDefUid"]]
    opacity = TileOpacity(os.path.normpath(
        os.path.join(os.path.dirname(PROJECT_PATH), caves_ts["relPath"])))

    def ps(x, y, src):
        """Structural put: opaque tiles go straight to Cave_Tiles; tiles with
        transparent pixels get a floor underlay + overlay on Cave_Pillars."""
        if opacity.opaque(src):
            p.put("Cave_Tiles", x, y, src)
        else:
            p.put("Cave_Tiles", x, y, sk.floor)
            p.put("Cave_Pillars", x, y, src)

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
                # A rim segment resuming after a cut starts with the end-cap piece.
                base = RIM_BASE if cell(x, y0 - 1) == "-" else sk.floor
                p.put("Cave_Tiles", x, y0, base)
                piece = RIM_CAP_L if cell(x - 1, y0) in WALKABLE else rng.choice(RIM_PIECES)
                p.put("Cave_Pillars", x, y0, piece)
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
                        ps(x, y, EDGE_L["void"])
                    elif edge_right:
                        ps(x, y, EDGE_R["void"])
                    else:
                        ps(x, y, VOID)
                elif role == "face_top":
                    if y == y0 and not at_top and cell(x, y0 - 1) in WALKABLE:
                        # run's top row with walkable above (ridge seen from behind):
                        # scalloped rim, base continues the tile above; segment
                        # resuming after a cut starts with the end-cap piece
                        base = RIM_BASE if cell(x, y0 - 1) == "-" else sk.floor
                        p.put("Cave_Tiles", x, y, base)
                        piece = (RIM_CAP_L if cell(x - 1, y) in WALKABLE
                                 else rng.choice(RIM_PIECES))
                        p.put("Cave_Pillars", x, y, piece)
                    elif edge_left:
                        ps(x, y, EDGE_L["face_top"])
                    elif edge_right:
                        ps(x, y, EDGE_R["face_top"])
                    else:
                        ps(x, y, rng.choice(FACE_TOP))
                elif role == "face_mid":
                    if edge_left:
                        ps(x, y, EDGE_L["face_mid"])
                    elif edge_right:
                        ps(x, y, EDGE_R["face_mid"])
                    else:
                        ps(x, y, rng.choice(FACE_MID))
                elif role == "face_bot":
                    if edge_left:
                        ps(x, y, EDGE_L["trim"])
                    elif edge_right:
                        ps(x, y, EDGE_R["trim"])
                    else:
                        ps(x, y, rng.choice(FACE_BOT))

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
                    # The ramp formula (fill + side sticks + dotted apron) is
                    # designed for the choke's light-dirt corridor context —
                    # against plain floor every piece of it reads as floating
                    # clutter. Plain-floor gaps get NO dressing: the band's own
                    # cut edges already render clean rocky shoulders (doorway).
                    corridor_ctx = any(cell(gx, y - 2) == "-" for gx in span)
                    if not corridor_ctx:
                        continue  # x already advanced past the span
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
                        if row_i < 2:
                            cols = span
                            xs_seq = apron_xs(len(cols))
                        else:
                            # last row: 2-tile scallop shoulders, narrow center taper
                            shoulder = 2 if len(span) >= 7 else 1
                            cols = span[shoulder:-shoulder]
                            if not cols:
                                break
                            xs_seq = apron_xs(len(cols), 240, 272)
                            for s in range(shoulder):
                                p.put("Cave_Tiles", span[s], yy, APRON_SCALLOP)
                                p.put("Cave_Tiles", span[-1 - s], yy, APRON_SCALLOP)
                        for gx, xs in zip(cols, xs_seq):
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
    return p, {"Collision": intgrid}, {}


# ---------------------------------------------------------------------------
# Crypt rendering — brick walls + rule-baked floor
# ---------------------------------------------------------------------------
def bake_intgrid_rules(defs, layer_name, mask, oob=False):
    """Evaluate the project's active auto-rules for an IntGrid layer over a
    boolean mask (True = value 1). First matching rule wins per cell, exactly
    like LDtk (chance=1, no modulo/flip rules expected). Returns autoLayerTiles.

    oob=True treats out-of-bounds neighbors as value 1 — mirrors the layer's
    outOfBoundsValue=1 in LDtk, so island floors continue seamlessly across
    block seams instead of baking an edge line at every seam row.
    """
    ld = defs.layers[layer_name]
    ts = defs.tilesets_by_uid[ld["tilesetDefUid"]]
    grid = ts["tileGridSize"]
    sheet_cols = ts["pxWid"] // grid

    rules = []
    for g in ld.get("autoRuleGroups", []):
        if not g.get("active", True):
            continue
        for r in g["rules"]:
            if r["active"]:
                tile_ids = r.get("tileRectsIds") or [[tid] for tid in r.get("tileIds", [])]
                rules.append((r["size"], r["pattern"], tile_ids[0][0], r["uid"]))

    def at(x, y):
        if not (0 <= x < BLOCK_W and 0 <= y < BLOCK_H):
            return oob
        return mask[y][x]

    tiles = []
    for y in range(BLOCK_H):
        for x in range(BLOCK_W):
            if not mask[y][x]:
                continue
            for size, pattern, tid, rule_uid in rules:
                half = size // 2
                match = True
                for i, pv in enumerate(pattern):
                    if pv == 0:
                        continue
                    nx, ny = x + i % size - half, y + i // size - half
                    hit = at(nx, ny)
                    if (pv > 0 and not hit) or (pv < 0 and hit):
                        match = False
                        break
                if match:
                    src = [(tid % sheet_cols) * grid, (tid // sheet_cols) * grid]
                    tiles.append({
                        "px": [x * GRID, y * GRID], "src": src, "f": 0, "t": tid,
                        "d": [rule_uid, y * BLOCK_W + x], "a": 1,
                    })
                    break
    return tiles


def render_structure_crypt(sk, rng, defs):
    """Crypt: architectural brick walls; floor baked by CryptLayer auto-rules.
    Returns (painter, intgrids dict, autotiles dict)."""
    g = sk.grid
    p = TilePainter()
    intgrid = [0] * (BLOCK_W * BLOCK_H)

    def cell(x, y):
        if 0 <= x < BLOCK_W and 0 <= y < BLOCK_H:
            return g[y][x]
        return "#"

    def pick(variants):
        return variants[1] if rng.random() < 0.12 else variants[0]

    # collision + floor mask ('-' has no special meaning in crypt: plain floor)
    floor_mask = [[False] * BLOCK_W for _ in range(BLOCK_H)]
    for y in range(BLOCK_H):
        for x in range(BLOCK_W):
            ch = cell(x, y)
            if ch in WALKABLE:
                intgrid[y * BLOCK_W + x] = IG_SPAWNBLOCK if ch == "," else IG_FLOOR
                floor_mask[y][x] = True
            elif ch == "#":
                intgrid[y * BLOCK_W + x] = IG_WALL if 0 < x < BLOCK_W - 1 else 0

    # map border columns
    for y in range(BLOCK_H):
        p.put(CRYPT_WALL_LAYER, 0, y, CRYPT_BORDER_L)
        p.put(CRYPT_WALL_LAYER, BLOCK_W - 1, y, CRYPT_BORDER_R)

    # walls: per-column vertical runs — top row, then alternating brick courses
    for x in range(1, BLOCK_W - 1):
        y = 0
        while y < BLOCK_H:
            if cell(x, y) != "#":
                y += 1
                continue
            y0 = y
            while y < BLOCK_H and cell(x, y) == "#":
                y += 1
            y1 = y - 1
            for yy in range(y0, y1 + 1):
                i = yy - y0
                if i == 0:
                    src = pick(CRYPT_TOP)
                elif i % 2 == 1:
                    src = pick(CRYPT_COURSE_A)
                else:
                    src = pick(CRYPT_COURSE_B)
                p.put(CRYPT_WALL_LAYER, x, yy, src)

    # floor: CryptLayer IntGrid mask + rule-baked autoLayerTiles
    crypt_csv = [1 if floor_mask[i // BLOCK_W][i % BLOCK_W] else 0
                 for i in range(BLOCK_W * BLOCK_H)]
    auto = bake_intgrid_rules(defs, CRYPT_FLOOR_LAYER, floor_mask)

    return p, {"Collision": intgrid, CRYPT_FLOOR_LAYER: crypt_csv}, {CRYPT_FLOOR_LAYER: auto}


def render_structure_nmrealm(sk, rng, defs):
    """Nightmare Realm: floating island over black void. Island floor baked by
    Ben's EtherealAutoLayer auto-rules; raised platforms (P) and ruined wall
    lines (W) rendered on Ethereal_Walls with Ben's grammar (decoded from his
    Entry + touched-up Isles). Returns (painter, intgrids dict, autotiles dict)."""
    g = sk.grid
    p = TilePainter()
    intgrid = [0] * (BLOCK_W * BLOCK_H)

    # collision + island mask ('-' has no special meaning here: plain floor;
    # platforms get floor beneath; ruined walls are walkable decor like Ben's)
    island = [[False] * BLOCK_W for _ in range(BLOCK_H)]
    plats = []
    walls = []
    seen = set()
    for y in range(BLOCK_H):
        for x in range(BLOCK_W):
            ch = g[y][x]
            if ch in WALKABLE or ch == RUINWALL:
                intgrid[y * BLOCK_W + x] = IG_SPAWNBLOCK if ch == "," else IG_FLOOR
                island[y][x] = True
            elif ch == PLATFORM:
                intgrid[y * BLOCK_W + x] = IG_WALL
                island[y][x] = True
            elif ch == "#":
                intgrid[y * BLOCK_W + x] = IG_WALL if 0 < x < BLOCK_W - 1 else 0
            if ch in (PLATFORM, RUINWALL) and (x, y) not in seen:
                comp = [(x, y)]
                seen.add((x, y))
                stack = [(x, y)]
                while stack:
                    cx, cy = stack.pop()
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = cx + dx, cy + dy
                        if (0 <= nx < BLOCK_W and 0 <= ny < BLOCK_H
                                and (nx, ny) not in seen and g[ny][nx] == ch):
                            seen.add((nx, ny))
                            stack.append((nx, ny))
                            comp.append((nx, ny))
                (plats if ch == PLATFORM else walls).append(comp)

    # --- platforms: Ben's rectangle grammar (cap row / edged fill / 3-row face)
    for comp in plats:
        xs = [c[0] for c in comp]
        ys = [c[1] for c in comp]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        for x in range(x0, x1 + 1):
            if x == x0:
                p.put(NM_WALL_LAYER, x, y0, NM_PLAT_TOP_TL)
            elif x == x1:
                p.put(NM_WALL_LAYER, x, y0, NM_PLAT_TOP_TR)
            else:
                p.put(NM_WALL_LAYER, x, y0, rng.choice(NM_PLAT_TOP_MID))
        for y in range(y0 + 1, y1 - 2):
            for x in range(x0, x1 + 1):
                src = (NM_PLAT_EDGE_L if x == x0 else
                       NM_PLAT_EDGE_R if x == x1 else NM_PLAT_FILL)
                p.put(NM_WALL_LAYER, x, y, src)
        face_pool = [fam for fam, wgt in NM_PLAT_FACE_COLS for _ in range(wgt)]
        for x in range(x0, x1 + 1):
            col = (NM_PLAT_FACE_L if x == x0 else
                   NM_PLAT_FACE_R if x == x1 else rng.choice(face_pool))
            for i, src in enumerate(col):
                p.put(NM_WALL_LAYER, x, y1 - 2 + i, src)

    # --- ruined wall lines
    for comp in walls:
        xs = [c[0] for c in comp]
        ys = [c[1] for c in comp]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        if y0 == y1:
            # horizontal: 3-col end caps (with top row) + crumble courses below
            for i, cx in enumerate(range(x0, x0 + 3)):
                p.put(NM_WALL_LAYER, cx, y0, NM_HWALL_CAP_L[i])
                for r, ry in enumerate(NM_HWALL_CAP_ROWS):
                    p.put(NM_WALL_LAYER, cx, y0 + 1 + r, (NM_HWALL_CAP_COLS_L[i], ry))
            for i, cx in enumerate(range(x1 - 2, x1 + 1)):
                p.put(NM_WALL_LAYER, cx, y0, (NM_HWALL_CAP_COLS_R[i], 320))
                for r, ry in enumerate(NM_HWALL_CAP_ROWS):
                    p.put(NM_WALL_LAYER, cx, y0 + 1 + r, (NM_HWALL_CAP_COLS_R[i], ry))
            for cx in range(x0 + 3, x1 - 2):
                col = NM_HWALL_COURSE_VAR if rng.random() < 0.15 else NM_HWALL_COURSE
                for r, src in enumerate(col):
                    p.put(NM_WALL_LAYER, cx, y0 + 1 + r, src)
        else:
            # vertical: brick column, sometimes spire-capped (spills 1 col wide)
            p.put(NM_WALL_LAYER, x0, y0, NM_VWALL_TOP)
            for i, cy in enumerate(range(y0 + 1, y1 - 2)):
                p.put(NM_WALL_LAYER, x0, cy, NM_VWALL_BODY[i % 2])
            for i, src in enumerate(NM_VWALL_BOT):
                p.put(NM_WALL_LAYER, x0, y1 - 2 + i, src)
            if rng.random() < 0.35 and y0 >= 4 and 1 <= x0 - 1 and x0 + 1 <= BLOCK_W - 2:
                for i, src in enumerate(NM_SPIRE):
                    p.put(NM_WALL_LAYER, x0 - 1 + i % 3, y0 - 4 + i // 3, src)

    # island floor: EtherealAutoLayer IntGrid + rule-baked tiles (oob=island so
    # seams continue into the neighboring block instead of baking an edge line)
    nm_csv = [1 if island[i // BLOCK_W][i % BLOCK_W] else 0
              for i in range(BLOCK_W * BLOCK_H)]
    auto = bake_intgrid_rules(defs, NM_FLOOR_LAYER, island, oob=True)

    return p, {"Collision": intgrid, NM_FLOOR_LAYER: nm_csv}, {NM_FLOOR_LAYER: auto}


# ---------------------------------------------------------------------------
# Decorator — prop stamps
# ---------------------------------------------------------------------------
def decorate_scratches(sk, painter, rng, pack):
    """nmrealm ground scarring: claw/hatch decals scattered with coverage that
    follows Ben's measured distance-to-void profile — dense halos around the
    holes (as if something punched through this layer and kept going), fading
    with distance. Painted on Ethereal_Floor over the baked island."""
    from collections import deque
    g = sk.grid
    profile = {int(k): v for k, v in pack["scratch_profile"].items()}
    units = pack["scratch_units"]
    if not units:
        return 0
    weights = [u["weight"] for u in units]
    avg_cells = sum(len(u["tiles"]) * u["weight"] for u in units) / sum(weights)
    scale = {"none": 0.0, "sparse": 0.6, "normal": 1.0, "dense": 1.4}[sk.density]

    # BFS distance to void ('#'), same metric the profile was measured with
    INF = 10 ** 9
    dist = [[INF] * BLOCK_W for _ in range(BLOCK_H)]
    dq = deque()
    for y in range(BLOCK_H):
        for x in range(BLOCK_W):
            if g[y][x] == "#":
                dist[y][x] = 0
                dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < BLOCK_W and 0 <= ny < BLOCK_H and dist[ny][nx] > dist[y][x] + 1:
                dist[ny][nx] = dist[y][x] + 1
                dq.append((nx, ny))

    # patch gate: Ben paints scratches in contiguous swaths, not salt-and-pepper.
    # A coarse random field keeps ~55% of 6x6-cell patches (boosted to preserve
    # overall coverage) so placements pool into flowing fields.
    PATCH = 6
    gate = {}
    for sy in range((BLOCK_H // PATCH) + 2):
        for sx in range((BLOCK_W // PATCH) + 2):
            gate[(sx, sy)] = rng.random() < 0.55

    placed = 0
    cap = max(profile)
    for y in range(2, BLOCK_H - 2):
        for x in range(1, BLOCK_W - 1):
            if g[y][x] not in WALKABLE:
                continue
            if not gate[(x // PATCH, y // PATCH)]:
                continue
            cov = profile.get(min(dist[y][x], cap), 0.0) * scale / 0.55
            if rng.random() >= cov / avg_cells:
                continue
            u = rng.choices(units, weights=weights, k=1)[0]
            cells = [(x + t[0], y + t[1]) for t in u["tiles"]]
            if any(not (0 < cx < BLOCK_W - 1 and 0 <= cy < BLOCK_H)
                   or g[cy][cx] not in WALKABLE for cx, cy in cells):
                continue
            for t in u["tiles"]:
                painter.put(NM_DETAIL_LAYER, x + t[0], y + t[1], (t[2], t[3]))
            placed += 1
    return placed


def decorate(sk, painter, rng):
    with open(STYLES[sk.style]["pack"], encoding="utf-8") as f:
        pack = json.load(f)
    scratches = 0
    if sk.style == "nmrealm" and sk.scratches == "auto":
        scratches = decorate_scratches(sk, painter, rng, pack)
    stamps_by_class = defaultdict(list)
    for s in pack["stamps"]:
        stamps_by_class[s["class"]].append(s)
    grid2 = pack["grid"]  # 2px

    g = sk.grid
    floor_cells = [(x, y) for y in range(BLOCK_H) for x in range(BLOCK_W)
                   if g[y][x] == "."]  # plain floor only: keep paths/seams cleaner
    n_floor = sum(1 for y in range(BLOCK_H) for x in range(BLOCK_W) if g[y][x] in WALKABLE)

    preset = STYLES[sk.style].get("density_presets", DENSITY_PRESETS)[sk.density]
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
    if scratches:
        placed["scratches"] = scratches
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
        # rect is authored as top-left x,y + size in px; "full" covers the block
        # minus a 3-tile margin. The entity pivot is (0.5, 0.5), so px must be
        # the rect CENTER — px at the corner shoves half the zone off the block.
        if z.get("rect", "full") == "full":
            x, y, w, h = 24, 24, BLOCK_W * GRID - 48, BLOCK_H * GRID - 48
        else:
            x, y, w, h = (int(v) for v in z["rect"].split(","))
        cx_, cy_ = x + w // 2, y + h // 2
        ents.append({
            "__identifier": "EnemySpawnZone", "__grid": [cx_ // GRID, cy_ // GRID],
            "__pivot": [0.5, 0.5], "__tags": ["gameplay", "spawn"], "__tile": None,
            "__smartColor": "#CC2222", "iid": make_iid(), "width": w, "height": h,
            "defUid": defs.entities["EnemySpawnZone"]["uid"], "px": [cx_, cy_],
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
            "__worldX": cx_, "__worldY": cy_,
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


def build_level(sk, defs, painter, intgrids, autotiles, level_uid, world_x, world_y):
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
        if ld["__type"] == "IntGrid":
            li["intGridCsv"] = intgrids.get(ident) or [0] * (li["__cWid"] * li["__cHei"])
        if ident in autotiles:
            li["autoLayerTiles"] = autotiles[ident]
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
    "EtherealAutoLayer": -4,
    "FloorAuto": -3, "Cave_Tiles": -3, "Ethereal_Floor": -3,
    "Cave_Pillars": -2, "CavesShadows": -2, "CryptLayer": -2,
    "CaveEntrances": -2, "Caves_PropsShadows": -2, "CryptProps_Shadows": -2,
    "CryptShadows": -2, "Ethereal_Shadows": -2, "Ethereal_Props_Shadows": -2,
    "Ethereal_Walls": -2,
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
        (li for li in level["layerInstances"]
         if (li["gridTiles"] or li["autoLayerTiles"]) and li["__tilesetDefUid"]),
        key=lambda li: LOADER_LAYER_Z.get(li["__identifier"], -1))
    for li in ordered:
        ts_uid = li["__tilesetDefUid"]
        ts = defs.tilesets_by_uid[ts_uid]
        gsz = ts["tileGridSize"]
        sheet = tileset_img(ts_uid)
        cells = {}                      # set_cell semantics: last tile per cell wins
        for t in li["autoLayerTiles"] + li["gridTiles"]:
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
def compile_sketch(path, project, defs, preview_only=False, min_obstacle_size=2):
    sk = parse_sketch(path)
    errors, warnings = validate(sk, min_obstacle_size)
    if warnings:
        for w in warnings:
            print(f"  WARN {sk.name}: {w}")
    if errors:
        print(f"FAIL {path} ({sk.name}):")
        for e in errors:
            print(f"  - {e}")
        return False

    rng = random.Random(sk.seed)
    if sk.style == "crypt":
        painter, intgrids, autotiles = render_structure_crypt(sk, rng, defs)
    elif sk.style == "nmrealm":
        painter, intgrids, autotiles = render_structure_nmrealm(sk, rng, defs)
    else:
        painter, intgrids, autotiles = render_structure(sk, rng, defs)
    placed = decorate(sk, painter, rng)

    existing = {lv["identifier"]: lv for lv in project["levels"]}
    if sk.name in existing:
        level_uid = existing[sk.name]["uid"]
        world_x, world_y = existing[sk.name]["worldX"], existing[sk.name]["worldY"]
    else:
        level_uid = project.get("nextUid", 1000)
        world_y = STYLES[sk.style]["world_y"]
        # place at the end of this style's row in the LDtk world view
        row = [lv["worldX"] for lv in project["levels"] if lv["worldY"] == world_y]
        world_x = max(row, default=-600) + 700

    level = build_level(sk, defs, painter, intgrids, autotiles, level_uid, world_x, world_y)

    # Hand-touch-up layers survive recompiles: Ben owns the nmrealm scratch
    # layer (Ethereal_Floor), so if the block already exists on disk, carry its
    # tiles over instead of regenerating/clearing them.
    preserve = {"nmrealm": ["Ethereal_Floor"]}.get(sk.style, [])
    existing_path = os.path.join(LEVELS_DIR, sk.name + ".ldtkl")
    if preserve and os.path.exists(existing_path):
        with open(existing_path, encoding="utf-8") as f:
            old = json.load(f)
        old_layers = {l["__identifier"]: l for l in old["layerInstances"]}
        for li in level["layerInstances"]:
            ident = li["__identifier"]
            if ident in preserve and ident in old_layers and old_layers[ident]["gridTiles"]:
                li["gridTiles"] = old_layers[ident]["gridTiles"]
                print(f"     preserved {len(li['gridTiles'])} hand-painted tiles on {ident}")

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


def run_audit(paths, min_obstacle_size=2):
    """Parse and validate .block files; print a markdown summary.  No compilation."""
    rows = []
    for path in sorted(paths):
        try:
            sk = parse_sketch(path)
            errors, warnings = validate(sk, min_obstacle_size)
            rows.append((sk.name, errors, warnings))
        except Exception as exc:
            rows.append((os.path.basename(path), [f"parse error: {exc}"], []))

    print(f"\n## Block Obstacle Audit  (min_obstacle_size={min_obstacle_size})\n")
    print(f"| Block | Errors | Warnings |")
    print(f"|-------|--------|----------|")
    for name, errs, warns in rows:
        err_cell = "; ".join(errs) if errs else "(none)"
        warn_cell = "; ".join(warns) if warns else "(none)"
        print(f"| {name} | {err_cell} | {warn_cell} |")

    n_err_blocks = sum(1 for _, e, _ in rows if e)
    n_warn_blocks = sum(1 for _, _, w in rows if w)
    print(f"\n{n_err_blocks} block(s) with errors, "
          f"{n_warn_blocks} block(s) with warnings "
          f"({len(rows)} total).")
    return n_err_blocks == 0


def main():
    raw = list(sys.argv[1:])
    preview_only = False
    audit_mode = False
    min_obstacle_size = 2
    paths = []
    i = 0
    while i < len(raw):
        a = raw[i]
        if a == "--preview-only":
            preview_only = True
        elif a == "--audit":
            audit_mode = True
        elif a == "--min-obstacle-size":
            i += 1
            min_obstacle_size = int(raw[i])
        elif a.startswith("--min-obstacle-size="):
            min_obstacle_size = int(a.split("=", 1)[1])
        elif a.startswith("--"):
            print(f"unknown flag {a!r}", file=sys.stderr)
            sys.exit(1)
        else:
            paths.append(a)
        i += 1

    if audit_mode:
        if not paths:
            import glob as _glob
            paths = _glob.glob(
                os.path.join(ROOT, "blocks", "**", "*.block"), recursive=True)
        if not paths:
            print("no .block files found under blocks/")
            sys.exit(1)
        ok = run_audit(paths, min_obstacle_size)
        sys.exit(0 if ok else 1)

    if not paths:
        print(__doc__)
        sys.exit(1)

    with open(PROJECT_PATH, encoding="utf-8") as f:
        project = json.load(f)
    defs = ProjectDefs(project)

    ok = True
    for path in paths:
        ok &= compile_sketch(path, project, defs, preview_only, min_obstacle_size)

    if ok and not preview_only:
        with open(PROJECT_PATH, "w", encoding="utf-8", newline="\n") as f:
            json.dump(project, f, indent="\t", ensure_ascii=False)
            f.write("\n")
        print(f"Registered in {PROJECT_PATH}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
