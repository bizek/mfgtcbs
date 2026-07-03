"""Extract reusable prop 'stamps' from hand-painted example blocks.

Prop layers (Caves_Props, Darkforestandrocks) are 2px-grid tile layers where each
decorative prop is an assembly of many 2x2px micro-tiles. This tool clusters painted
cells into stamps (one stamp = one prop assembly), pairs each stamp with its shadow
tiles (Caves_PropsShadows), dedupes identical assemblies, and writes a style pack
JSON consumed by block_compiler.py's decorator pass.

Usage:
    python tools/extract_prop_stamps.py            # writes tools/block_style_caves.json
"""
import json
import os
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LVL_DIR = os.path.join(ROOT, "assets", "Maps", "Levels", "Level 1 - Caves")
OUT_PATH = os.path.join(ROOT, "tools", "block_style_caves.json")

EXAMPLE_BLOCKS = [
    "Block_Caves_00_Entry",
    "Block_Caves_01_Open",
    "Block_Caves_02_Pillars",
    "Block_Caves_03_Choke",
    "Block_Caves_04_Split",
    "Block_Caves_05_Merchant",
    "Block_Caves_09_Portal",
]

# (prop layer, paired shadow layer). Both are 2px-grid layers.
PROP_LAYERS = [
    ("Caves_Props", "Caves_PropsShadows"),
    ("Darkforestandrocks", None),
]

GRID = 2                 # prop layer grid size in px
CLUSTER_REACH = 3        # chebyshev distance (in 2px cells) merged into one stamp
SHADOW_REACH = 2         # cells beyond stamp bbox searched for shadow tiles

# Size classes by stamp bbox (px). Debris = walk-over specks, large = big features.
SIZE_CLASSES = [
    ("debris", 8),
    ("small", 16),
    ("medium", 32),
    ("large", 10 ** 9),
]


def load_level(name):
    with open(os.path.join(LVL_DIR, name + ".ldtkl"), encoding="utf-8") as f:
        return json.load(f)


def layer_cells(lvl, layer_name):
    """{(cx, cy): [(srcx, srcy, flip), ...]} at 2px cell resolution."""
    li = next((l for l in lvl["layerInstances"] if l["__identifier"] == layer_name), None)
    cells = defaultdict(list)
    if li is None:
        return cells
    for t in li.get("gridTiles", []):
        cells[(t["px"][0] // GRID, t["px"][1] // GRID)].append(
            (t["src"][0], t["src"][1], t["f"]))
    return cells


def cluster(cells):
    """8-connected clusters with CLUSTER_REACH tolerance."""
    keys = set(cells)
    seen = set()
    out = []
    for start in keys:
        if start in seen:
            continue
        stack = [start]
        seen.add(start)
        comp = []
        while stack:
            c = stack.pop()
            comp.append(c)
            for dx in range(-CLUSTER_REACH, CLUSTER_REACH + 1):
                for dy in range(-CLUSTER_REACH, CLUSTER_REACH + 1):
                    n = (c[0] + dx, c[1] + dy)
                    if n in keys and n not in seen:
                        seen.add(n)
                        stack.append(n)
        out.append(comp)
    return out


def size_class(w_px, h_px):
    m = max(w_px, h_px)
    for name, limit in SIZE_CLASSES:
        if m <= limit:
            return name
    return "large"


def main():
    stamp_index = {}      # signature -> stamp dict
    class_counts = Counter()
    per_block_counts = defaultdict(Counter)
    floor_area = {}

    for block in EXAMPLE_BLOCKS:
        lvl = load_level(block)
        # approximate placeable floor area (tiles) for density calibration
        coll = next(l for l in lvl["layerInstances"] if l["__identifier"] == "Collision")
        floor_area[block] = sum(1 for v in coll["intGridCsv"] if v == 1)

        for prop_layer, shadow_layer in PROP_LAYERS:
            cells = layer_cells(lvl, prop_layer)
            if not cells:
                continue
            shadows = layer_cells(lvl, shadow_layer) if shadow_layer else {}
            comps = cluster(cells)

            # assign each shadow cluster exclusively to its nearest prop cluster,
            # so a stamp never inherits a neighboring prop's shadow (orphan shadows)
            shadow_by_comp = defaultdict(list)   # comp index -> [(cx, cy), ...]
            if shadows:
                comp_cells = [set(c) for c in comps]
                for sh_comp in cluster(shadows):
                    best_i, best_d = None, None
                    for i, pc in enumerate(comp_cells):
                        d = min(max(abs(sx - px), abs(sy - py))
                                for (sx, sy) in sh_comp for (px, py) in pc)
                        if best_d is None or d < best_d:
                            best_i, best_d = i, d
                    if best_i is not None and best_d <= SHADOW_REACH + 2:
                        shadow_by_comp[best_i].extend(sh_comp)

            for ci, comp in enumerate(comps):
                xs = [c[0] for c in comp]
                ys = [c[1] for c in comp]
                x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
                w_px, h_px = (x1 - x0 + 1) * GRID, (y1 - y0 + 1) * GRID
                tiles = []
                for (cx, cy) in sorted(comp):
                    for (sx, sy, f) in cells[(cx, cy)]:
                        tiles.append([cx - x0, cy - y0, sx, sy, f])
                shadow_tiles = []
                for (cx, cy) in shadow_by_comp.get(ci, []):
                    for (sx, sy, f) in shadows[(cx, cy)]:
                        shadow_tiles.append([cx - x0, cy - y0, sx, sy, f])
                sig = (prop_layer, tuple(sorted(map(tuple, tiles))))
                cls = size_class(w_px, h_px)
                if sig not in stamp_index:
                    stamp_index[sig] = {
                        "layer": prop_layer,
                        "shadow_layer": shadow_layer,
                        "class": cls,
                        "w_cells": x1 - x0 + 1,
                        "h_cells": y1 - y0 + 1,
                        "tiles": tiles,
                        "shadow_tiles": sorted(map(list, set(map(tuple, shadow_tiles)))),
                        "count": 0,
                        "sources": [],
                    }
                stamp_index[sig]["count"] += 1
                if block not in stamp_index[sig]["sources"]:
                    stamp_index[sig]["sources"].append(block)
                class_counts[cls] += 1
                per_block_counts[block][cls] += 1

    stamps = sorted(stamp_index.values(), key=lambda s: -s["count"])
    for i, s in enumerate(stamps):
        s["id"] = f"{s['layer']}_{i:03d}"

    # density calibration: stamp instances per 1000 floor tiles, per block
    density = {}
    for block, counts in per_block_counts.items():
        area = floor_area[block] or 1
        density[block] = {cls: round(n * 1000.0 / area, 2) for cls, n in counts.items()}

    pack = {
        "_generated_by": "tools/extract_prop_stamps.py",
        "_source_blocks": EXAMPLE_BLOCKS,
        "grid": GRID,
        "class_counts": dict(class_counts),
        "density_per_1000_floor_tiles": density,
        "stamps": stamps,
    }
    with open(OUT_PATH, "w", encoding="utf-8", newline="\n") as f:
        json.dump(pack, f, indent=1)
        f.write("\n")

    print(f"Wrote {OUT_PATH}")
    print(f"stamps: {len(stamps)} distinct, {sum(s['count'] for s in stamps)} instances")
    print(f"class counts: {dict(class_counts)}")
    print("density per 1000 floor tiles:")
    for block, d in density.items():
        print(f"  {block:<28} {d}")
    print("largest stamps:")
    for s in sorted(stamps, key=lambda s: -(s["w_cells"] * s["h_cells"]))[:8]:
        print(f"  {s['id']} class={s['class']} {s['w_cells']}x{s['h_cells']} cells "
              f"tiles={len(s['tiles'])} shadows={len(s['shadow_tiles'])} count={s['count']}")


if __name__ == "__main__":
    main()
