"""Composite the Skeletal_Horse rider onto the horse.

The pack ships the mount and its rider as separate, FRAME-MATCHED sheets (identical
dimensions per animation), clearly intended to be layered. enemy.gd drives exactly one
AnimatedSprite2D, so rather than orphan the whole Rider/ folder — five sheets — they are
merged here into combined sheets under assets/generated/.

Verified frame-matched before compositing; the script refuses any pair that is not.
"""
from PIL import Image
import os

PACK = (r"E:\Projects\extraction-survivors\assets\minifantasy"
        r"\Minifantasy_Undead_Creatures_v1.0\Minifantasy_Undead_Creatures_Assets"
        r"\Skeletal_Horse")
OUT = r"E:\Projects\extraction-survivors\assets\generated\skeletal_rider"

PAIRS = [
    ("Idle_Activation_Deactivation_horse.png", "Rider/Idle_Activation_Deactivation_raider.png", "Idle.png"),
    ("Walk_horse.png",                          "Rider/Walk_raider.png",                        "Walk.png"),
    ("Attack_horse.png",                        "Rider/Attack_rider.png",                       "Attack.png"),
    ("Dmg_horse.png",                           "Rider/Dmg_raider.png",                         "Dmg.png"),
    ("Die_horse.png",                           "Rider/Die_raider.png",                         "Die.png"),
]

os.makedirs(OUT, exist_ok=True)
for horse_rel, rider_rel, out_name in PAIRS:
    h = Image.open(os.path.join(PACK, horse_rel)).convert("RGBA")
    r = Image.open(os.path.join(PACK, rider_rel.replace("/", os.sep))).convert("RGBA")
    if h.size != r.size:
        raise SystemExit("NOT frame-matched: %s %s vs %s %s" % (horse_rel, h.size, rider_rel, r.size))
    out = h.copy()
    out.alpha_composite(r)          # rider draws over the mount
    out.save(os.path.join(OUT, out_name))
    print("%-12s <- %-42s + %-40s  %s" % (out_name, horse_rel, rider_rel, h.size))
print("wrote", len(PAIRS), "composited sheets to", OUT)
