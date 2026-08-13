"""Generate the two missing Crypt bookend blocks: Merchant and Portal.

Crypt grammar (from Ben's hand-painted Block_Crypt_00_Entry and the 10 generated
siblings): rectangular masses, straight runs, doorway gaps. Organic blobs belong to
caves, not to brick.

Self-checks the 3x3 clearance rule before writing so the compiler round-trip is a
confirmation rather than a search.
"""
import os

W, H = 81, 60
OUT = r"E:\Projects\extraction-survivors\blocks\crypt"


def new_grid():
    return [["." for _ in range(W)] for _ in range(H)]


def rect(g, x0, y0, x1, y1, ch="#"):
    """Inclusive solid rectangle."""
    for y in range(max(0, y0), min(H, y1 + 1)):
        for x in range(max(0, x0), min(W, x1 + 1)):
            g[y][x] = ch


def finish(g):
    """Re-open the seams and re-close the side border. Must be called LAST."""
    for y in list(range(3)) + list(range(H - 3, H)):
        for x in range(1, W - 1):
            g[y][x] = "."
    for y in range(H):
        g[y][0] = g[y][W - 1] = "#"


def walkable(c):
    return c in ".,-"


def check_clearance(g):
    """Mirror of the compiler's 3x3 window test: every walkable cell must sit in at
    least one fully-walkable 3x3 window."""
    bad = []
    ok = [[False] * W for _ in range(H)]
    for y in range(H - 2):
        for x in range(W - 2):
            if all(walkable(g[y + dy][x + dx]) for dy in range(3) for dx in range(3)):
                for dy in range(3):
                    for dx in range(3):
                        ok[y + dy][x + dx] = True
    for y in range(H):
        for x in range(W):
            if walkable(g[y][x]) and not ok[y][x]:
                bad.append((x, y))
    return bad


def check_connected(g):
    """Top seam must reach bottom seam through walkable cells."""
    from collections import deque
    seen = [[False] * W for _ in range(H)]
    q = deque()
    for x in range(W):
        if walkable(g[0][x]):
            q.append((x, 0)); seen[0][x] = True
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and not seen[ny][nx] and walkable(g[ny][nx]):
                seen[ny][nx] = True
                q.append((nx, ny))
    return any(seen[H - 1][x] for x in range(W))


def check_blobs(g, min_side=2):
    """Crypt: interior solid blobs not attached to the side border must be >= 2x2."""
    from collections import deque
    seen = [[False] * W for _ in range(H)]
    bad = []
    for y in range(H):
        for x in range(W):
            if g[y][x] != "#" or seen[y][x]:
                continue
            q = deque([(x, y)]); seen[y][x] = True
            cells = []
            touches_border = False
            while q:
                cx, cy = q.popleft()
                cells.append((cx, cy))
                if cx == 0 or cx == W - 1:
                    touches_border = True
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < W and 0 <= ny < H and not seen[ny][nx] and g[ny][nx] == "#":
                        seen[ny][nx] = True
                        q.append((nx, ny))
            if touches_border:
                continue
            xs = [c[0] for c in cells]; ys = [c[1] for c in cells]
            bw = max(xs) - min(xs) + 1
            bh = max(ys) - min(ys) + 1
            if bw < min_side or bh < min_side or len(cells) < 3:
                bad.append((min(xs), min(ys), bw, bh, len(cells)))
    return bad


def emit(name, header_lines, g):
    problems = []
    bad = check_clearance(g)
    if bad:
        problems.append("%d cells under 3-wide clearance, first at %s" % (len(bad), bad[0]))
    if not check_connected(g):
        problems.append("top seam does not reach bottom seam")
    blobs = check_blobs(g)
    if blobs:
        problems.append("undersized solid blobs: %s" % blobs)
    if problems:
        print("SELF-CHECK FAILED", name)
        for p in problems:
            print("   -", p)
        return False
    path = os.path.join(OUT, name + ".block")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        for line in header_lines:
            f.write(line + "\n")
        f.write("grid:\n")
        for row in g:
            f.write("".join(row) + "\n")
    print("self-check OK ->", path)
    return True


# ─────────────────────────────────────────────────────────────────────────────
# Block_Crypt_11_Merchant — a vaulted market hall.
#
# Narrow processional entry, a transverse wall with two doorways, a wide trading
# hall carrying the merchant alcove on the right, then a mirrored lower approach.
# ─────────────────────────────────────────────────────────────────────────────
g = new_grid()

# Upper approach — flanking vaults with a central aisle (cols 34..46)
rect(g, 6, 6, 31, 20)
rect(g, 49, 6, 74, 20)

# Transverse wall, rows 24-26, two 6-wide doorways
rect(g, 1, 24, 79, 26)
rect(g, 18, 24, 23, 26, ".")
rect(g, 57, 24, 62, 26, ".")

# Trading hall rows 30-45 — two ranks of pillars, 3x3, 5 cols apart
for px in (20, 34, 48):
    rect(g, px, 33, px + 2, 35)
    rect(g, px, 41, px + 2, 43)

# Merchant alcove on the right: ceiling / back wall / floor, open to the hall westward.
# 3 clear rows below the transverse wall (27,28,29) before the ceiling starts.
rect(g, 64, 30, 74, 32)
rect(g, 72, 33, 74, 38)
rect(g, 64, 39, 74, 41)

# Lower approach — mirror of the upper vaults
rect(g, 6, 47, 31, 55)
rect(g, 49, 47, 74, 55)

finish(g)
emit(
    "Block_Crypt_11_Merchant",
    [
        "name = Block_Crypt_11_Merchant",
        "biome = Caves",
        "style = crypt",
        "density = normal",
        "seed = 111",
        "spawn_zone = rect=full phase=Any density=Medium",
        # payload=merchant is what EventSpawnManager matches on explicitly
        # (event_spawn_manager.gd:37). Without it the block only qualifies through the
        # 0.3-0.7 depth fallback and could lose the merchant to another anchor.
        "marker = id=merchant_anchor tag=EventTrigger payload=merchant at=68,35",
        "extraction = kind=Locked at=10,35 radius=48 channel=3",
    ],
    g,
)

# ─────────────────────────────────────────────────────────────────────────────
# Block_Crypt_12_Portal — the descent's bottom bookend.
#
# BlockManager computes the portal at (level_width * 0.5, total_height - 24), i.e.
# bottom-centre of the whole stack, so the centre of the lower half stays clear.
# ─────────────────────────────────────────────────────────────────────────────
g = new_grid()

# Approach: heavy side masses either side of a wide aisle
rect(g, 4, 6, 15, 21)
rect(g, 65, 6, 76, 21)

# Free-standing piers in the aisle — 4x4, generously spaced so nothing pinches
rect(g, 24, 8, 27, 11)
rect(g, 53, 8, 56, 11)
rect(g, 24, 16, 27, 19)
rect(g, 53, 16, 56, 19)

# Gate wall rows 25-27, one wide central doorway
rect(g, 1, 25, 79, 27)
rect(g, 34, 25, 46, 27, ".")

# Terminal chamber rows 31-42: corner masses only, centre and bottom kept open
rect(g, 6, 31, 17, 40)
rect(g, 63, 31, 74, 40)

finish(g)
emit(
    "Block_Crypt_12_Portal",
    [
        "name = Block_Crypt_12_Portal",
        "biome = Caves",
        "style = crypt",
        "density = normal",
        "seed = 112",
        "spawn_zone = rect=full phase=Any density=Medium",
        # Matches Block_Caves_09_Portal: a Locked extraction off to the side, clear of
        # the computed portal position at bottom-centre.
        "extraction = kind=Locked at=71,50 radius=48 channel=3",
    ],
    g,
)
