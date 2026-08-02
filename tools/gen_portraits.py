#!/usr/bin/env python3
"""Compose 32x32 character portraits from the Minifantasy Portrait Generator layers.

The original seven portraits (shipped in d385b3e) were composed the same way but by hand, via a
one-off Godot editor script, so the recipes were lost the moment it finished. Six characters
added since then had a `portrait` path in CharacterData pointing at a file that was never
created -- `hub_roster_panel.gd` guards with ResourceLoader.exists, so nothing crashed, the
roster just drew half its rows with a portrait and half without.

This exists so the recipes are DATA rather than a lost afternoon: to restyle a character, edit
its dict below and re-run. Every layer is an independent 32x32 PNG that is already aligned to
the same origin, so composing is a straight alpha-over in the order listed in LAYER_ORDER.

Usage:
    python tools/gen_portraits.py            # write any portrait that is missing
    python tools/gen_portraits.py --force    # rewrite all of them
    python tools/gen_portraits.py --check    # verify every layer path resolves, write nothing

Deliberately does NOT touch the original seven unless --force is passed: they are Ben's and
they shipped.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
GEN = (ROOT / "assets/minifantasy/Minifantasy_Portrait_Generator_Graphical_Assets_v1.0"
       / "Portrait_Generator/single_images")
OUT = ROOT / "assets/characters/portraits"

# Back-to-front. Skin first, features onto it, hair over the skull, then worn items on top.
# "eyes" lives in its own subfolder in the pack; everything else is flat in human/ or common/.
LAYER_ORDER = ["base", "ears", "nose", "mouth", "eyes", "brows", "hair", "beard",
               "moustache", "clothes", "hat"]

# Layers that come from common/ (shared across races) rather than the per-race folder.
COMMON = {"brows", "hair", "beard", "moustache", "clothes", "hat"}

# No "bg" layer anywhere on purpose: the shipped seven have transparent backgrounds and the
# roster panel draws its own card behind them.
#
# Each value is the filename SUFFIX after the category prefix. Skin-toned parts (base/ears/
# nose/mouth/eyes) are prefixed "human_<skin>_"; common parts are prefixed "common_<category>_".
# Choices below follow each character's actual in-game sprite, not invention -- the Deadeye's
# wide-brim hat, the Whisper's red headband, the Ravager's horned-helm blonde, the Verdant's
# hooded antlers, the Demon's black hood, the Devout's pale robe.
PORTRAITS: dict[str, dict[str, str]] = {
    # Gunslinger. Tech-augmented; the sprite reads as a dark wide-brim hat over a leather vest.
    "the_deadeye": {
        "skin": "brown",
        "ears": "normal", "nose": "straight", "mouth": "neutral", "eyes": "narrow_1",
        "brows": "brown_confident",
        "hair": "brown_short",
        "clothes": "brown_leather_vest",
        "hat": "black_leather_cowboy",
    },
    # Demonologist. Black hood, red robe, the hellfire palette (color_head 0.85,0.45,0.30).
    "the_demon": {
        "skin": "pale",
        "ears": "normal", "nose": "pointy", "mouth": "grit", "eyes": "angry_1",
        "brows": "black_aggressive",
        "hair": "black_long",
        "clothes": "red_robe",
        "hat": "black_hood",
    },
    # Cleric. The palest head colour in the roster (1.0,0.94,0.74); white robe, serene.
    "the_devout": {
        "skin": "pale",
        "ears": "normal", "nose": "small", "mouth": "neutral", "eyes": "round_1",
        "brows": "blonde_nice",
        "hair": "blonde_middle_part",
        "clothes": "white_robe",
    },
    # Barbarian. Blonde under the horned helm, full beard, brute harness.
    "the_ravager": {
        "skin": "brown",
        "ears": "normal", "nose": "big", "mouth": "grit", "eyes": "angry_1",
        "brows": "blonde_aggressive",
        "hair": "blonde_mane",
        "beard": "blonde_garibaldi",
        "clothes": "brown_leather_brute",
    },
    # Druid. Hooded and antlered in game; green hood + robe carry that without borrowing art.
    "the_verdant": {
        "skin": "brown",
        "ears": "normal", "nose": "straight", "mouth": "neutral", "eyes": "narrow_1",
        "brows": "brown_normal",
        "hair": "brown_long",
        "beard": "brown_classic",
        "clothes": "green_robe",
        "hat": "green_hood",
    },
    # Ninja. Entirely black but for the red headband, which is the one thing that reads at 32px.
    "the_whisper": {
        "skin": "pale",
        "ears": "normal", "nose": "small", "mouth": "neutral", "eyes": "narrow_1",
        "brows": "black_normal",
        "hair": "black_short",
        "clothes": "black_vest",
        "hat": "red_bandana",
    },
}


def layer_path(category: str, value: str, skin: str) -> Path:
    if category in COMMON:
        return GEN / "common" / f"common_{category}_{value}.png"
    if category == "eyes":
        return GEN / "human" / "human_eyes" / f"human_eyes_{skin}_{value}.png"
    if category == "base":
        return GEN / "human" / f"human_{skin}_base.png"
    return GEN / "human" / f"human_{skin}_{category}_{value}.png"


def resolve(name: str, recipe: dict[str, str]) -> tuple[list[Path], list[str]]:
    """Return (existing layer paths in draw order, list of problems)."""
    skin = recipe["skin"]
    paths: list[Path] = []
    problems: list[str] = []
    for category in LAYER_ORDER:
        if category == "base":
            value = ""
        elif category in recipe:
            value = recipe[category]
        else:
            continue  # optional layer this character does not use (no beard, no hat, ...)
        p = layer_path(category, value, skin)
        if not p.is_file():
            problems.append(f"{name}: {category}='{value}' -> missing {p.relative_to(ROOT)}")
        else:
            paths.append(p)
    return paths, problems


def compose(paths: list[Path]) -> Image.Image:
    canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for p in paths:
        layer = Image.open(p).convert("RGBA")
        if layer.size != (32, 32):
            raise SystemExit(f"layer {p} is {layer.size}, expected (32, 32)")
        canvas.alpha_composite(layer)
    return canvas


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="rewrite portraits that already exist")
    ap.add_argument("--check", action="store_true", help="validate layer paths, write nothing")
    args = ap.parse_args()

    if not GEN.is_dir():
        print(f"Portrait Generator assets not found at {GEN}", file=sys.stderr)
        return 1

    all_problems: list[str] = []
    resolved: dict[str, list[Path]] = {}
    for name, recipe in PORTRAITS.items():
        paths, problems = resolve(name, recipe)
        all_problems += problems
        resolved[name] = paths

    if all_problems:
        print(f"{len(all_problems)} unresolved layer(s):", file=sys.stderr)
        for p in all_problems:
            print(f"  {p}", file=sys.stderr)
        return 1
    print(f"All layers resolve for {len(PORTRAITS)} portrait(s).")
    if args.check:
        return 0

    OUT.mkdir(parents=True, exist_ok=True)
    for name, paths in resolved.items():
        dest = OUT / f"{name}.png"
        if dest.exists() and not args.force:
            print(f"  skip   {name}.png (exists)")
            continue
        compose(paths).save(dest)
        print(f"  wrote  {name}.png  ({len(paths)} layers)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
