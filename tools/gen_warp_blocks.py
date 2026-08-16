"""Author the 12 Threshold (Warp Lands) descent block sketches.

Companion to tools/gen_crypt_blocks.py. Writes blocks/warp/*.block; compile them
with tools/block_compiler.py afterwards.

The biome's identity is "someone opened a door they could not hold", and the
block grammar says it three ways:

  * VOIDS ARE CROSS-SHAPED. Every other biome's holes are organic blobs; here
    they are plus-signs and square windows, because the compiler fills a void
    blob with the matching rift sprite. A cross-shaped hole therefore reads as
    a tear in reality rather than as a missing chunk of floor.
  * ZONES ARE THE OTHER REALITIES. 'B' and 'R' cells are walkable, but their
    ground speckle and contour are drawn from the tileset's cyan and red
    variants, so the plane visibly disagrees with itself about what it is.
  * THE DISAGREEMENT ESCALATES WITH DEPTH. Early blocks are mostly intact
    purple plane with one tear; late blocks are more zone than plane, with the
    walkable route threading between tears.

Usage:
    python tools/gen_warp_blocks.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "blocks", "warp")
W, H = 81, 60

# Seam contract (docs/block_architecture.md §2): rows 0-2 and 57-59 must stay
# walkable across cols 2..78 so blocks stitch. Everything below keeps a 4-row
# margin instead of 3, which leaves the seam visibly clear rather than merely
# legal.
SEAM_TOP, SEAM_BOT = 4, H - 5


class Grid:
    def __init__(self):
        self.g = [["." for _ in range(W)] for _ in range(H)]
        for y in range(H):
            self.g[y][0] = "#"
            self.g[y][W - 1] = "#"

    def put(self, x, y, ch):
        if 1 <= x < W - 1 and SEAM_TOP <= y <= SEAM_BOT:
            self.g[y][x] = ch

    def cross(self, cx, cy, extent, arm, ch="#"):
        """Plus-shaped hole: `extent` across, `arm` thick. Sized to match the
        rift sprites the compiler paints into it (15/7 extent, 5/3 arm)."""
        h = extent // 2
        a = arm // 2
        for y in range(cy - h, cy + h + 1):
            for x in range(cx - h, cx + h + 1):
                if abs(x - cx) <= a or abs(y - cy) <= a:
                    self.put(x, y, ch)

    def window(self, cx, cy, size=11, ch="#"):
        """Square hole for the 2x2 'window' rift -- the clearest 'this is a
        doorway someone opened' shape in the pack."""
        h = size // 2
        for y in range(cy - h, cy + h + 1):
            for x in range(cx - h, cx + h + 1):
                self.put(x, y, ch)

    def blob(self, cx, cy, rx, ry, ch="#"):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.put(x, y, ch)

    def rect(self, x0, y0, x1, y1, ch):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, ch)

    def band(self, y0, y1, ch, x0=1, x1=W - 2):
        self.rect(x0, y0, x1, y1, ch)

    def rows(self):
        return ["".join(r) for r in self.g]


def zone_blob(gr, cx, cy, rx, ry, ch):
    """A reality patch. Only repaints walkable cells: a zone bleeding over a
    tear would erase the tear, and the tear is the point."""
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if not (1 <= x < W - 1 and SEAM_TOP <= y <= SEAM_BOT):
                continue
            if gr.g[y][x] != ".":
                continue
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                gr.g[y][x] = ch


def write(name, gr, *, seed, rifts=2, ground=0.22, density="normal", extra=()):
    lines = [
        f"name = {name}",
        "biome = Caves",
        "style = warp",
        f"density = {density}",
        f"rifts = {rifts}",
        f"ground = {ground}",
        f"seed = {seed}",
    ]
    extra = list(extra)
    if not any(e.startswith("spawn_zone") for e in extra):
        extra.append("spawn_zone = rect=full phase=Any density=Medium")
    lines += extra
    lines.append("grid:")
    lines += gr.rows()
    path = os.path.join(OUT_DIR, name + ".block")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return path


# ---------------------------------------------------------------------------
# The 12 blocks
# ---------------------------------------------------------------------------
def b00_entry():
    """Arrival. The plane is still mostly whole -- one small tear, one faint
    blue bruise. Wide open so the descent's first steps are never blocked."""
    gr = Grid()
    gr.cross(40, 30, 7, 3)
    zone_blob(gr, 18, 22, 9, 6, "B")
    return write("Block_Warp_00_Entry", gr, seed=20260816, rifts=1, ground=0.20)


def b01_tears():
    """Three clean plus-shaped tears in open ground: the grammar, stated."""
    gr = Grid()
    gr.cross(20, 18, 15, 5)
    gr.cross(60, 26, 15, 5)
    gr.cross(38, 44, 7, 3)
    zone_blob(gr, 62, 47, 11, 7, "B")
    return write("Block_Warp_01_Tears", gr, seed=20260817, rifts=2)


def b02_bruise():
    """A blue reality has soaked most of the block. Navigation is easy; the
    unease is that almost nothing here is the colour it started as."""
    gr = Grid()
    gr.cross(30, 24, 15, 5)
    gr.blob(62, 40, 7, 6)
    zone_blob(gr, 40, 30, 34, 22, "B")
    zone_blob(gr, 16, 48, 10, 6, "R")
    return write("Block_Warp_02_Bruise", gr, seed=20260818, rifts=3)


def b03_seam():
    """Blue holds the west, red the east, and a purple seam runs top to bottom
    between them -- the one strip of original reality left, and the safe road."""
    gr = Grid()
    zone_blob(gr, 16, 20, 15, 16, "B")
    zone_blob(gr, 16, 46, 13, 10, "B")
    zone_blob(gr, 65, 22, 14, 15, "R")
    zone_blob(gr, 64, 46, 13, 10, "R")
    gr.cross(24, 33, 7, 3)
    gr.cross(58, 35, 7, 3)
    return write("Block_Warp_03_Seam", gr, seed=20260819, rifts=2)


def b04_doorway():
    """The window rift, centred and unmissable: a square hole with panes, the
    literal door of the biome's premise. Flanked by two smaller tears."""
    gr = Grid()
    gr.window(40, 30, 11)
    gr.cross(16, 24, 7, 3)
    gr.cross(64, 38, 7, 3)
    zone_blob(gr, 40, 30, 22, 15, "R")
    return write("Block_Warp_04_Doorway", gr, seed=20260820, rifts=2)


def b05_lattice():
    """Six small tears in a loose grid. Nothing is dangerous alone; the route
    between them is what costs time."""
    gr = Grid()
    for (cx, cy) in ((18, 18), (40, 15), (62, 20), (20, 43), (42, 46), (63, 41)):
        gr.cross(cx, cy, 7, 3)
    zone_blob(gr, 40, 30, 12, 8, "B")
    return write("Block_Warp_05_Lattice", gr, seed=20260821, rifts=3)


def b06_causeway():
    """Two big voids leave a walkable isthmus. The first block that says no."""
    gr = Grid()
    gr.blob(18, 30, 13, 16)
    gr.blob(63, 30, 13, 16)
    gr.cross(40, 12, 7, 3)
    gr.cross(40, 48, 7, 3)
    zone_blob(gr, 40, 30, 9, 20, "R")
    return write("Block_Warp_06_Causeway", gr, seed=20260822, rifts=2)


def b07_contested():
    """Blue and red interleaved in bands with a big cross tear where they meet:
    the two realities are no longer taking turns, they are overlapping."""
    gr = Grid()
    gr.cross(40, 30, 15, 5)
    for i, y in enumerate(range(SEAM_TOP + 2, SEAM_BOT - 4, 9)):
        zone_blob(gr, 26 if i % 2 else 54, y + 4, 20, 5, "B" if i % 2 else "R")
    return write("Block_Warp_07_Contested", gr, seed=20260823, rifts=3)


def b08_spill():
    """One reality pouring down the block from the top seam to the bottom."""
    gr = Grid()
    zone_blob(gr, 44, 14, 16, 11, "R")
    zone_blob(gr, 40, 32, 13, 12, "R")
    zone_blob(gr, 36, 49, 15, 9, "R")
    gr.cross(16, 26, 15, 5)
    gr.cross(66, 40, 7, 3)
    return write("Block_Warp_08_Spill", gr, seed=20260824, rifts=2)


def b09_shatter():
    """Deepest inner block: a big tear, a window, and four small ones, with
    both other realities present. Maximum disagreement per square metre."""
    gr = Grid()
    gr.cross(24, 22, 15, 5)
    gr.window(60, 42, 11)
    for (cx, cy) in ((60, 16), (16, 46), (40, 34), (44, 52)):
        gr.cross(cx, cy, 7, 3)
    zone_blob(gr, 22, 44, 12, 8, "B")
    zone_blob(gr, 62, 24, 12, 9, "R")
    return write("Block_Warp_09_Shatter", gr, seed=20260825, rifts=3)


def b10_merchant():
    """Trader's ground. Deliberately calm: one distant tear, open floor, and
    the merchant anchor east with the locked extraction west, matching the
    Crypt and NMRealm merchant blocks."""
    gr = Grid()
    gr.cross(40, 14, 7, 3)
    zone_blob(gr, 40, 40, 16, 9, "B")
    return write(
        "Block_Warp_10_Merchant", gr, seed=20260826, rifts=1, density="sparse",
        extra=[
            "spawn_zone = rect=full phase=Any density=Medium",
            "marker = id=merchant_anchor tag=EventTrigger payload=merchant at=64,33",
            "extraction = kind=Locked at=10,33 radius=48 channel=3",
        ])


def b11_portal():
    """The way down. The window rift sits dead centre -- the door that started
    all of this -- with quiet ground around it and few spawns."""
    gr = Grid()
    gr.window(40, 30, 11)
    zone_blob(gr, 40, 30, 26, 17, "B")
    return write(
        "Block_Warp_11_Portal", gr, seed=20260827, rifts=1, density="sparse",
        extra=["spawn_zone = rect=full phase=Any density=Low"])


BUILDERS = [b00_entry, b01_tears, b02_bruise, b03_seam, b04_doorway, b05_lattice,
            b06_causeway, b07_contested, b08_spill, b09_shatter, b10_merchant,
            b11_portal]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for fn in BUILDERS:
        path = fn()
        print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
