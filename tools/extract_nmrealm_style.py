"""Extract the Nightmare Realm block style from Ben's hand-authored blocks.

v2 — the style is mined from Block_NMRealm_00_Entry + Block_NMRealm_01_Isles
(Ben's reference blocks, painted in LDtk), replacing the v1 premade-scene
mining which produced context-free scatter. The premade remains useful only
as tile-usage documentation; placement intent comes from Ben's blocks.

Outputs tools/block_style_nmrealm.json with:
  - prop stamps: clustered assemblies from Ethereal_Props of both blocks
    (stone pillars, bones, rubble). NO shadow pairing — Ben doesn't use prop
    shadows in this biome. Flora region hard-blacklisted.
  - scratch units: connected sprites from the Solid_Tileset claw/hatch decal
    regions, weighted by Ben's actual tile usage in Isles. These paint the
    "something massive crashed through here" ground scarring.
  - scratch profile: coverage fraction per distance-to-void, measured from
    Isles — scratches halo the holes (peak ~4-6 tiles out) as if the thing
    punched through this layer and kept going.

Platform + ruined-wall grammars are hand-coded constants in block_compiler.py
(decoded from Ben's Isles wall assemblies), not part of this pack.

Usage:
    python tools/extract_nmrealm_style.py
"""
import json
import os
from collections import Counter, defaultdict, deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LVL_DIR = os.path.join(ROOT, "assets", "Maps", "Levels", "Level 1 - Caves")
SHEET = os.path.join(ROOT, "assets", "minifantasy", "Minifantasy_Nightmare_Realm_v1.0",
                     "Minifantasy_Nightmare_Realm_Assets", "Tileset", "Solid",
                     "Solid_Tileset.png")
OUT = os.path.join(ROOT, "tools", "block_style_nmrealm.json")
G = 8
W, H = 81, 60

REF_BLOCKS = ["Block_NMRealm_00_Entry", "Block_NMRealm_01_Isles"]
# props sheet region Ben vetoed (plant-looking flora)
FLORA = (104, 144, 40, 80)   # x0, x1, y0, y1

# Solid_Tileset regions holding the scratch/debris decal sprites Ben paints on
# Ethereal_Floor (main diagonal hatch family + the small debris rows)
SCRATCH_REGIONS = [(264, 320, 472, 544), (24, 224, 584, 624), (24, 224, 640, 728)]


def load(name):
    with open(os.path.join(LVL_DIR, name + ".ldtkl"), encoding="utf-8") as f:
        return json.load(f)


def layer(lvl, name):
    return next((l for l in lvl["layerInstances"] if l["__identifier"] == name), None)


# ---------------------------------------------------------------------------
# Prop stamps from Ben's Ethereal_Props layers
# ---------------------------------------------------------------------------
SIZE_CLASSES = [("debris", 8), ("small", 16), ("medium", 32), ("large", 10 ** 9)]


def size_class(w_px, h_px):
    m = max(w_px, h_px)
    for name, limit in SIZE_CLASSES:
        if m <= limit:
            return name
    return "large"


def extract_props():
    stamp_index = {}
    floor_area = 0
    inst_total = 0
    for block in REF_BLOCKS:
        lvl = load(block)
        auto = layer(lvl, "EtherealAutoLayer")
        floor_area += sum(1 for v in auto["intGridCsv"] if v == 1)
        cells = defaultdict(list)
        for t in layer(lvl, "Ethereal_Props")["gridTiles"]:
            sx, sy = t["src"]
            if FLORA[0] <= sx <= FLORA[1] and FLORA[2] <= sy <= FLORA[3]:
                continue
            if t["f"]:
                continue          # loader ignores flip flags
            cells[(t["px"][0] // G, t["px"][1] // G)].append((sx, sy))
        # 8-connected clustering, reach 1 cell (adjacent pillars merge into the
        # multi-pillar clusters Ben composes)
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
                    "layer": "Ethereal_Props", "shadow_layer": None,
                    "class": size_class((x1 - x0 + 1) * G, (y1 - y0 + 1) * G),
                    "w_cells": x1 - x0 + 1, "h_cells": y1 - y0 + 1,
                    "tiles": tiles, "shadow_tiles": [],
                    "count": 0, "sources": [],
                }
            stamp_index[sig]["count"] += 1
            inst_total += 1
            if block not in stamp_index[sig]["sources"]:
                stamp_index[sig]["sources"].append(block)
    stamps = sorted(stamp_index.values(), key=lambda s: -s["count"])
    for i, s in enumerate(stamps):
        s["id"] = f"props_{i:03d}"
    print(f"props: {len(stamps)} distinct stamps, {inst_total} instances, "
          f"classes {Counter(s['class'] for s in stamps)}")
    density = Counter()
    for s in stamps:
        density[s["class"]] += s["count"]
    density = {k: round(v * 1000.0 / (floor_area / 1), 2) for k, v in density.items()}
    print("prop density per 1000 floor tiles (both refs):", density)
    return stamps, density


# ---------------------------------------------------------------------------
# Scratch decal units: connected sprites in the tileset decal regions
# ---------------------------------------------------------------------------
def extract_scratch_units(usage):
    img = Image.open(SHEET).convert("RGBA")
    px = img.load()
    units = []
    for (rx0, rx1, ry0, ry1) in SCRATCH_REGIONS:
        seen = set()
        for sy in range(ry0, ry1):
            for sx in range(rx0, rx1):
                if (sx, sy) in seen or px[sx, sy][3] == 0:
                    continue
                comp = [(sx, sy)]
                seen.add((sx, sy))
                dq = deque([(sx, sy)])
                while dq:
                    x, y = dq.popleft()
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            n = (x + dx, y + dy)
                            if (rx0 <= n[0] < rx1 and ry0 <= n[1] < ry1
                                    and n not in seen and px[n[0], n[1]][3] > 0):
                                seen.add(n)
                                dq.append(n)
                                comp.append(n)
                if len(comp) < 4:
                    continue
                cells = sorted({(x // G * G, y // G * G) for (x, y) in comp})
                x0 = min(c[0] for c in cells)
                y0 = min(c[1] for c in cells)
                tiles = [[(cx - x0) // G, (cy - y0) // G, cx, cy, 0] for (cx, cy) in cells]
                weight = sum(usage.get((cx, cy), 0) for (cx, cy) in cells)
                if weight == 0:
                    continue      # Ben never painted this unit
                units.append({
                    "tiles": tiles,
                    "w_cells": max(t[0] for t in tiles) + 1,
                    "h_cells": max(t[1] for t in tiles) + 1,
                    "weight": round(weight / len(cells), 1),
                })
    units.sort(key=lambda u: -u["weight"])
    print(f"scratch units: {len(units)} "
          f"(sizes {[ (u['w_cells'], u['h_cells']) for u in units[:12] ]})")
    return units


def scratch_profile():
    """Coverage fraction (scratch tiles / island cells) per distance-to-void,
    measured from Ben's Isles."""
    lvl = load("Block_NMRealm_01_Isles")
    auto = layer(lvl, "EtherealAutoLayer")
    csv = auto["intGridCsv"]
    island = [[csv[y * W + x] == 1 for x in range(W)] for y in range(H)]
    INF = 10 ** 9
    dist = [[INF] * W for _ in range(H)]
    dq = deque()
    for y in range(H):
        for x in range(W):
            if not island[y][x]:
                dist[y][x] = 0
                dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and dist[ny][nx] > dist[y][x] + 1:
                dist[ny][nx] = dist[y][x] + 1
                dq.append((nx, ny))
    CAP = 24
    cells_at = Counter()
    hits_at = Counter()
    usage = Counter()
    for y in range(H):
        for x in range(W):
            if island[y][x]:
                cells_at[min(dist[y][x], CAP)] += 1
    scratched = set()
    for t in layer(lvl, "Ethereal_Floor")["gridTiles"]:
        usage[tuple(t["src"])] += 1
        scratched.add((t["px"][0] // G, t["px"][1] // G))
    for (cx, cy) in scratched:
        hits_at[min(dist[cy][cx], CAP)] += 1
    profile = {str(d): round(hits_at[d] / cells_at[d], 4) if cells_at[d] else 0.0
               for d in range(1, CAP + 1)}
    print("scratch coverage by distance:", {k: profile[k] for k in list(profile)[:12]}, "...")
    return profile, usage


def main():
    stamps, density = extract_props()
    profile, usage = scratch_profile()
    units = extract_scratch_units(usage)
    pack = {
        "_generated_by": "tools/extract_nmrealm_style.py (v2 — Ben's reference blocks)",
        "_source_blocks": REF_BLOCKS,
        "grid": G,
        "class_counts": {},
        "density_per_1000_floor_tiles": {"refs": density},
        "stamps": stamps,
        "scratch_units": units,
        "scratch_profile": profile,
    }
    pack["class_counts"] = dict(Counter(s["class"] for s in stamps for _ in range(s["count"])))
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(pack, f, indent=1)
        f.write("\n")
    print("Wrote", OUT)


if __name__ == "__main__":
    main()
