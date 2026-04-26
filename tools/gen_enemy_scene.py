"""Generate standalone enemy .tscn files using the cave_brute pattern.

Each enemy gets a unique Minifantasy sprite and full attack/damage/death/idle/walk
animation set (only row 0 — game is side-scrolling).
"""
from __future__ import annotations
import os
import secrets
import sys
from PIL import Image


PROJECT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def gen_uid() -> str:
    """13-char base32-ish UID matching Godot's format (uid://xxxxxxxxxxxxx)."""
    alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
    return "".join(secrets.choice(alphabet) for _ in range(13))


def gen_id(prefix: str = "") -> str:
    """5-char id suffix used in [ext_resource] / [sub_resource] ids."""
    alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
    return prefix + "".join(secrets.choice(alphabet) for _ in range(5))


def read_uid(import_path: str) -> str:
    with open(import_path, encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("uid="):
                return line.strip().split('"')[1]
    raise RuntimeError(f"no uid in {import_path}")


def png_cols(png_path: str) -> int:
    """Number of 32px frames across row 0."""
    w, _ = Image.open(png_path).size
    return w // 32


# enemy_name, ClassName, sprite_pack_dir, sprite_basename, anim_filename_map, hurtbox_size, body_size, scale
# anim_filename_map: { logical_name: source_filename } (without .png)
# Logical names are the keys used in the SpriteFrames dict (must be: attack/damage/death/idle/walk)
ENEMIES = [
    {
        "scene_filename": "brute.tscn",
        "node_name": "Brute",
        "pack_path": "assets/minifantasy/Minifantasy_Creatures_v3.3_Commercial_Version/Minifantasy_Creatures_Assets/Monsters/Cyclop",
        "anims": {
            "attack": ("CyclopAttack", 8.0, False),
            "damage": ("CyclopDmg",   12.0, False),
            "death":  ("CyclopDie",   6.0,  False),
            "idle":   ("CyclopIdle",  5.0,  True),
            "walk":   ("CyclopWalk",  5.0,  True),
        },
        "hurtbox": (16, 16),
        "body":    (12, 12),
    },
    {
        "scene_filename": "stalker.tscn",
        "node_name": "Stalker",
        "pack_path": "assets/minifantasy/Minifantasy_Creatures_v3.3_Commercial_Version/Minifantasy_Creatures_Assets/Beasts/Wolf",
        "anims": {
            "attack": ("WolfAttack", 8.0, False),
            "damage": ("WolfDmg",   12.0, False),
            "death":  ("WolfDie",   6.0,  False),
            "idle":   ("WolfIdle",  5.0,  True),
            "walk":   ("WolfWalk",  5.0,  True),
        },
        "hurtbox": (12, 10),
        "body":    (10, 8),
    },
    {
        "scene_filename": "carrier.tscn",
        "node_name": "Carrier",
        "pack_path": "assets/minifantasy/Minifantasy_Creatures_v3.3_Commercial_Version/Minifantasy_Creatures_Assets/Undead/Skeleton",
        "anims": {
            "attack": ("SkeletonAttack", 8.0, False),
            "damage": ("SkeletonDmg",   12.0, False),
            "death":  ("SkeletonDie",   6.0,  False),
            "idle":   ("SkeletonIdle",  5.0,  True),
            "walk":   ("SkeletonWalk",  5.0,  True),
        },
        "hurtbox": (10, 12),
        "body":    (8, 10),
    },
    {
        "scene_filename": "caster.tscn",
        "node_name": "Caster",
        "pack_path": "assets/minifantasy/Minifantasy_Undead_Creatures_v1.0/Minifantasy_Undead_Creatures_Assets/Reanimated_Zombie_Mage",
        # Cast is the attack, Die/Dmg/Idle/Walk match standard names
        "anims": {
            "attack": ("Cast",  8.0, False),
            "damage": ("Dmg",  12.0, False),
            "death":  ("Die",   6.0, False),
            "idle":   ("Idle",  5.0, True),
            "walk":   ("Walk",  5.0, True),
        },
        "hurtbox": (12, 12),
        "body":    (8, 10),
    },
    {
        "scene_filename": "herald.tscn",
        "node_name": "Herald",
        "pack_path": "assets/minifantasy/Minifantasy_Creatures_v3.3_Commercial_Version/Minifantasy_Creatures_Assets/Monsters/Minotaur",
        "anims": {
            "attack": ("MinotaurAttack", 8.0, False),
            "damage": ("MinotaurDmg",   12.0, False),
            "death":  ("MinotaurDie",   6.0,  False),
            "idle":   ("MinotaurIdle",  5.0,  True),
            "walk":   ("MinotaurWalk",  5.0,  True),
        },
        "hurtbox": (16, 16),
        "body":    (12, 12),
    },
]


SCRIPT_UID = "uid://cp7gnmjq6gvun"  # scripts/entities/enemy.gd


def render_scene(spec: dict) -> str:
    name = spec["node_name"]
    scene_uid = "uid://" + gen_uid()
    out: list[str] = []
    out.append(f'[gd_scene format=3 uid="{scene_uid}"]')
    out.append("")

    # External resources: script + each anim PNG
    out.append(f'[ext_resource type="Script" uid="{SCRIPT_UID}" path="res://scripts/entities/enemy.gd" id="1_script"]')
    ext_ids: dict[str, str] = {}  # anim_name -> ext_resource id
    for i, (anim_name, (basename, _speed, _loop)) in enumerate(spec["anims"].items(), start=2):
        ext_id = f"{i}_{gen_id()}"
        ext_ids[anim_name] = ext_id
        png_rel = os.path.join(spec["pack_path"], basename + ".png").replace("\\", "/")
        png_abs = os.path.join(PROJECT, png_rel)
        import_path = png_abs + ".import"
        if not os.path.exists(import_path):
            raise FileNotFoundError(f"Missing import file for {png_abs}")
        tex_uid = read_uid(import_path)
        out.append(f'[ext_resource type="Texture2D" uid="{tex_uid}" path="res://{png_rel}" id="{ext_id}"]')
    out.append("")

    # Per-anim AtlasTexture sub-resources (one per frame, row 0 only)
    atlas_ids: dict[str, list[str]] = {}  # anim_name -> [sub_id, ...]
    for anim_name, (basename, _speed, _loop) in spec["anims"].items():
        png_rel = os.path.join(spec["pack_path"], basename + ".png").replace("\\", "/")
        png_abs = os.path.join(PROJECT, png_rel)
        cols = png_cols(png_abs)
        atlas_ids[anim_name] = []
        for col in range(cols):
            sub_id = f"AT_{anim_name}_{col}_{gen_id()}"
            atlas_ids[anim_name].append(sub_id)
            out.append(f'[sub_resource type="AtlasTexture" id="{sub_id}"]')
            out.append(f'atlas = ExtResource("{ext_ids[anim_name]}")')
            out.append(f"region = Rect2({col * 32}, 0, 32, 32)")
            out.append("filter_clip = true")
            out.append("")

    # SpriteFrames sub-resource
    sf_id = f"SF_{name.lower()}_{gen_id()}"
    out.append(f'[sub_resource type="SpriteFrames" id="{sf_id}"]')
    out.append("animations = [")
    anim_blocks: list[str] = []
    for anim_name, (basename, speed, loop) in spec["anims"].items():
        frames_lines = []
        frames_lines.append("{")
        frames_lines.append('"frames": [')
        frame_entries = []
        for sub_id in atlas_ids[anim_name]:
            frame_entries.append(
                f'{{\n"duration": 1.0,\n"texture": SubResource("{sub_id}")\n}}'
            )
        frames_lines.append(", ".join(frame_entries))
        frames_lines.append("],")
        frames_lines.append(f'"loop": {"true" if loop else "false"},')
        frames_lines.append(f'"name": &"{anim_name}",')
        frames_lines.append(f'"speed": {speed}')
        frames_lines.append("}")
        anim_blocks.append("\n".join(frames_lines))
    out.append(", ".join(anim_blocks))
    out.append("]")
    out.append("")

    # Collision shapes
    hb_id = f"RS_hb_{gen_id()}"
    body_id = f"RS_body_{gen_id()}"
    out.append(f'[sub_resource type="RectangleShape2D" id="{hb_id}"]')
    out.append(f"size = Vector2({spec['hurtbox'][0]}, {spec['hurtbox'][1]})")
    out.append("")
    out.append(f'[sub_resource type="RectangleShape2D" id="{body_id}"]')
    out.append(f"size = Vector2({spec['body'][0]}, {spec['body'][1]})")
    out.append("")

    # Node tree
    out.append(f'[node name="{name}" type="CharacterBody2D"]')
    out.append("collision_layer = 2")
    out.append("collision_mask = 3")
    out.append('script = ExtResource("1_script")')
    out.append("")
    out.append('[node name="Sprite" type="AnimatedSprite2D" parent="."]')
    out.append(f'sprite_frames = SubResource("{sf_id}")')
    out.append('animation = &"idle"')
    out.append('autoplay = "idle"')
    out.append("")
    out.append('[node name="Hurtbox" type="Area2D" parent="."]')
    out.append("collision_layer = 2")
    out.append("collision_mask = 0")
    out.append("")
    out.append('[node name="CollisionShape" type="CollisionShape2D" parent="Hurtbox"]')
    out.append(f'shape = SubResource("{hb_id}")')
    out.append("")
    out.append('[node name="CollisionShape" type="CollisionShape2D" parent="."]')
    out.append(f'shape = SubResource("{body_id}")')

    return "\n".join(out) + "\n"


def main(argv: list[str]) -> int:
    out_dir = os.path.join(PROJECT, "scenes", "enemies")
    if not os.path.isdir(out_dir):
        print(f"missing {out_dir}", file=sys.stderr)
        return 1

    for spec in ENEMIES:
        out_path = os.path.join(out_dir, spec["scene_filename"])
        text = render_scene(spec)
        with open(out_path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        print(f"wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
