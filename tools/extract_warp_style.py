"""Extract the Warp Lands block style for The Threshold (biome 4).

Unlike the Nightmare Realm — where Ben had hand-painted two reference blocks to
mine — Block_Warp_00_Entry's `Warp_Props` layer is empty: the only thing Ben
authored there was the three AutoWarp rule sets, which the compiler reads
straight from the project defs and never needs a style pack for. So placement
intent has to come from the one place that has any: the pack's own premade
scene, which ships as separate layers.

That is the v1 mining path `extract_nmrealm_style.py` abandoned, and the reason
it was abandoned still applies — a premade is one artist composition, so the
stamps it yields are assemblies without a sense of how often to use them. What
makes it acceptable here is that it is only ever a starting point: paint props
onto Block_Warp_00_Entry in LDtk and rerun this with --from-blocks to replace
premade mining with Ben's own placement, exactly like the nmrealm v1 -> v2 move.

Outputs tools/block_style_warp.json:
  - prop stamps: connected assemblies from Premade_d-props.png, with each 8x8
    cell resolved back to its source coordinate in Props/_Props.png by exact
    pixel match. No shadow pairing (the ground here glows; cast shadows read
    wrong, and the nmrealm pack made the same call).
  - densities: stamp instances per 1000 ground cells, measured off
    Premade_j-ground.png so the presets are anchored to a real composition.

Usage:
    python tools/extract_warp_style.py
    python tools/extract_warp_style.py --from-blocks    # once Ben paints props
"""
import argparse
import json
import os
from collections import Counter, defaultdict

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(ROOT, "assets", "minifantasy", "Minifantasy_Warp_Lands_v1.0",
                    "Minifantasy_ Warp_Lands_Assets")
SHEET = os.path.join(PACK, "Props", "_Props.png")
PREMADE_PROPS = os.path.join(PACK, "Premade", "_Separate_Layers", "Premade_d-props.png")
PREMADE_GROUND = os.path.join(PACK, "Premade", "_Separate_Layers", "Premade_j-ground.png")
LVL_DIR = os.path.join(ROOT, "assets", "Maps", "Levels", "Level 1 - Caves")
OUT = os.path.join(ROOT, "tools", "block_style_warp.json")
G = 8
W, H = 81, 60

REF_BLOCKS = ["Block_Warp_00_Entry"]
PROPS_LAYER = "Warp_Props"

SIZE_CLASSES = [("debris", 8), ("small", 16), ("medium", 32), ("large", 10 ** 9)]

# ---------------------------------------------------------------------------
# Tileset geography (read off Tileset_Use_Guidelines.png, then verified in code)
# ---------------------------------------------------------------------------
# Tileset.png stacks three complete colour variants of the same terrain. The
# stride between them is exactly 336px: every shape below was checked to have
# an identical opaque-pixel count at y, y+336 and y+672, so a variant is a pure
# translation and one set of coordinates describes all three.
TILESET = os.path.join(PACK, "Tileset", "Tileset.png")
VARIANT_STRIDE = 336
VARIANTS = ["purple", "blue", "red"]      # order matches AutoWarpPurp/Blue/Red

# GROUND: a 5x3 block of speckle tiles per variant. These are what makes
# walkable land read as a surface at all -- the AutoWarp rules paint only the
# glowing contour at a zone's edge and leave the interior transparent, so
# without these the player walks on pure black and cannot tell land from void.
GROUND_BOX = (32, 72, 136, 160)           # x0, x1, y0, y1 of the purple variant

# RIFTS: the biome's signature landmark. Sizes are (w_cells, h_cells) and the
# coordinate is the purple variant's top-left cell.
RIFT_SHAPES = [
    ("big_cross",   616,  96, 15, 15),
    ("window",      512, 128, 11, 11),
    ("small_cross", 648,  24,  7,  7),
    ("bar_h",       536,  96,  5,  3),
    ("bar_v",       480, 152,  3,  5),
    ("glow",        488,  96,  3,  3),
    ("spark",       488,  64,  2,  2),
]


def extract_ground():
    """Per-variant list of ground speckle source coords."""
    img = Image.open(TILESET).convert("RGBA")
    px = img.load()
    x0, x1, y0, y1 = GROUND_BOX
    base = []
    for cy in range(y0, y1, G):
        for cx in range(x0, x1, G):
            if any(px[x, y][3] for y in range(cy, cy + G) for x in range(cx, cx + G)):
                base.append((cx, cy))
    out = {}
    for i, name in enumerate(VARIANTS):
        out[name] = [[x, y + i * VARIANT_STRIDE] for (x, y) in base]
    print(f"ground: {len(base)} speckle tiles x {len(VARIANTS)} variants")
    return out


def extract_rifts():
    """Per-variant rift stamps, as tile lists ready for the painter."""
    img = Image.open(TILESET).convert("RGBA")
    px = img.load()
    rifts = []
    for (name, sx, sy, w, h) in RIFT_SHAPES:
        entry = {"id": name, "w_cells": w, "h_cells": h, "variants": {}}
        for i, variant in enumerate(VARIANTS):
            oy = sy + i * VARIANT_STRIDE
            tiles = []
            for cy in range(h):
                for cx in range(w):
                    px0, py0 = sx + cx * G, oy + cy * G
                    if any(px[x, y][3] for y in range(py0, py0 + G)
                           for x in range(px0, px0 + G)):
                        tiles.append([cx, cy, px0, py0, 0])
            entry["variants"][variant] = tiles
        rifts.append(entry)
        print(f"  rift {name}: {w}x{h} cells, "
              f"{len(entry['variants']['purple'])} tiles")
    return rifts


def size_class(w_px, h_px):
    m = max(w_px, h_px)
    for name, limit in SIZE_CLASSES:
        if m <= limit:
            return name
    return "large"


def cell_bytes(px, cx, cy):
    """Raw RGBA of one 8x8 cell, or None if fully transparent."""
    out = bytearray()
    opaque = False
    for y in range(cy * G, cy * G + G):
        for x in range(cx * G, cx * G + G):
            r, g, b, a = px[x, y]
            if a == 0:
                out += b"\0\0\0\0"
            else:
                opaque = True
                out += bytes((r, g, b, a))
    return bytes(out) if opaque else None


def sheet_index():
    """cell content -> source pixel coord in _Props.png."""
    img = Image.open(SHEET).convert("RGBA")
    px = img.load()
    cols, rows = img.size[0] // G, img.size[1] // G
    index = {}
    dupes = 0
    for cy in range(rows):
        for cx in range(cols):
            key = cell_bytes(px, cx, cy)
            if key is None:
                continue
            if key in index:
                dupes += 1
                continue          # first occurrence wins; identical art anyway
            index[key] = (cx * G, cy * G)
    print(f"sheet: {len(index)} distinct non-empty cells ({dupes} duplicate cells)")
    return index


def cluster(cells):
    """8-connected clustering with reach 1, matching the nmrealm extractor so
    adjacent props merge into the assemblies the artist actually composed."""
    seen = set()
    for start in list(cells):
        if start in seen:
            continue
        stack, comp = [start], []
        seen.add(start)
        while stack:
            c = stack.pop()
            comp.append(c)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (c[0] + dx, c[1] + dy)
                    if n in cells and n not in seen:
                        seen.add(n)
                        stack.append(n)
        yield comp


def stamps_from_cells(cells, source_label, stamp_index):
    """cells: {(cx, cy): [(sx, sy), ...]} -> merge into stamp_index."""
    total = 0
    for comp in cluster(cells):
        xs = [c[0] for c in comp]
        ys = [c[1] for c in comp]
        x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
        tiles = []
        for (cx, cy) in sorted(comp):
            for (sx, sy) in cells[(cx, cy)]:
                tiles.append([cx - x0, cy - y0, sx, sy, 0])
        sig = tuple(sorted(map(tuple, tiles)))
        if sig not in stamp_index:
            stamp_index[sig] = {
                "layer": PROPS_LAYER, "shadow_layer": None,
                "class": size_class((x1 - x0 + 1) * G, (y1 - y0 + 1) * G),
                "w_cells": x1 - x0 + 1, "h_cells": y1 - y0 + 1,
                "tiles": tiles, "shadow_tiles": [],
                "count": 0, "sources": [],
            }
        stamp_index[sig]["count"] += 1
        total += 1
        if source_label not in stamp_index[sig]["sources"]:
            stamp_index[sig]["sources"].append(source_label)
    return total


def from_premade(index):
    img = Image.open(PREMADE_PROPS).convert("RGBA")
    px = img.load()
    cols, rows = img.size[0] // G, img.size[1] // G
    cells = defaultdict(list)
    misses = 0
    for cy in range(rows):
        for cx in range(cols):
            key = cell_bytes(px, cx, cy)
            if key is None:
                continue
            src = index.get(key)
            if src is None:
                misses += 1
                continue
            cells[(cx, cy)].append(src)
    print(f"premade: {len(cells)} prop cells resolved, {misses} unresolved "
          f"(unresolved cells are composited/offset art the tileset cannot express)")

    # Denominator is the premade's whole canvas, NOT the opaque cells of
    # Premade_j-ground.png: that layer is the sparse dotted GROUND detail (560
    # cells of 9906), so using it reported densities ~18x too high. Every cell
    # of the composition is walkable warp plane, which is what a block's land
    # mask means too.
    ground = Image.open(PREMADE_GROUND).convert("RGBA")
    area_cells = (ground.size[0] // G) * (ground.size[1] // G)
    print(f"premade canvas: {area_cells} cells")
    return cells, area_cells


def from_blocks(index):
    """Ben's own placement, once Warp_Props on a reference block is painted."""
    cells = defaultdict(list)
    ground_cells = 0
    used = []
    for name in REF_BLOCKS:
        path = os.path.join(LVL_DIR, name + ".ldtkl")
        with open(path, encoding="utf-8") as f:
            lvl = json.load(f)
        layers = {l["__identifier"]: l for l in lvl["layerInstances"]}
        tiles = layers[PROPS_LAYER]["gridTiles"]
        if not tiles:
            print(f"  {name}: {PROPS_LAYER} is empty, skipping")
            continue
        used.append(name)
        base = layers["AutoWarpPurp"]
        ground_cells += sum(1 for v in base["intGridCsv"] if v == 1)
        for t in tiles:
            if t["f"]:
                continue          # loader ignores flip flags
            cells[(t["px"][0] // G, t["px"][1] // G)].append(tuple(t["src"]))
    if not used:
        raise SystemExit(
            "--from-blocks: no reference block has painted props yet. Paint some "
            f"on {PROPS_LAYER} in LDtk first, or run without the flag to mine the "
            "pack's premade scene.")
    print(f"blocks: {len(cells)} prop cells from {used}")
    return cells, ground_cells


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from-blocks", action="store_true",
                    help="mine Ben's reference blocks instead of the premade scene")
    args = ap.parse_args()

    index = sheet_index()
    if args.from_blocks:
        cells, ground_cells = from_blocks(index)
        label = "+".join(REF_BLOCKS)
        source = "Ben's reference blocks"
    else:
        cells, ground_cells = from_premade(index)
        label = "Premade_d-props"
        source = "the pack's premade scene"

    stamp_index = {}
    total = stamps_from_cells(cells, label, stamp_index)
    stamps = sorted(stamp_index.values(), key=lambda s: -s["count"])
    for i, s in enumerate(stamps):
        s["id"] = f"props_{i:03d}"
    print(f"props: {len(stamps)} distinct stamps, {total} instances, "
          f"classes {Counter(s['class'] for s in stamps)}")

    per_class = Counter()
    for s in stamps:
        per_class[s["class"]] += s["count"]
    density = {k: round(v * 1000.0 / ground_cells, 2) for k, v in per_class.items()}
    print("prop density per 1000 ground cells:", density)

    pack = {
        "_generated_by": f"tools/extract_warp_style.py ({source})",
        "_source_blocks": [label],
        "grid": G,
        "class_counts": dict(Counter(s["class"] for s in stamps
                                     for _ in range(s["count"]))),
        "density_per_1000_floor_tiles": {"refs": density},
        "stamps": stamps,
        "ground_tiles": extract_ground(),
        "rifts": extract_rifts(),
    }
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(pack, f, indent=1)
        f.write("\n")
    print("Wrote", OUT)


if __name__ == "__main__":
    main()
