#!/usr/bin/env python
"""Assemble Godot MCP recorded frames into an animated GIF.

The Godot MCP `record_frames` command writes numbered PNGs to
`user://mcp_recorded_frames/`, which on Windows is
`%APPDATA%/Godot/app_userdata/Extraction Survivors/mcp_recorded_frames/`.
This turns that folder into a single GIF for sharing / attaching to a bug report.

Usage
-----
  python tools/frames_to_gif.py                        # newest run -> out/capture.gif
  python tools/frames_to_gif.py -o combo_twitch.gif    # name it
  python tools/frames_to_gif.py --fps 20 --scale 3     # slower / bigger
  python tools/frames_to_gif.py --src <folder>         # any folder of PNGs

Notes
-----
* `--fps` is the GIF's PLAYBACK rate, not the capture rate. If you recorded with
  `frame_interval: 2` at 60 fps the true capture rate was 30/s — pass `--fps 30`
  for real-time, or something lower for a slow-motion read of a single swing.
* `--scale` uses nearest-neighbour, so pixel art stays crisp.
* Frames are ordered by the number embedded in the filename, not lexically, so
  frame_10 does not sort before frame_2.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required:  python -m pip install Pillow")

DEFAULT_SRC = Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata" / \
    "Extraction Survivors" / "mcp_recorded_frames"
_NUM = re.compile(r"(\d+)")


def numbered_pngs(folder: Path) -> list[Path]:
    """PNGs in `folder`, ordered by the last number in the filename."""
    def key(p: Path) -> tuple[int, str]:
        nums = _NUM.findall(p.stem)
        return (int(nums[-1]) if nums else -1, p.stem)
    return sorted(folder.glob("*.png"), key=key)


def build_gif(frames: list[Path], out: Path, fps: float, scale: int,
              start: int, end: int | None) -> None:
    frames = frames[start:end]
    if not frames:
        sys.exit("No frames left after --start/--end trimming.")

    images: list[Image.Image] = []
    for path in frames:
        img = Image.open(path).convert("RGB")
        if scale != 1:
            img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        images.append(img)

    out.parent.mkdir(parents=True, exist_ok=True)
    duration_ms = max(20, int(round(1000.0 / fps)))
    images[0].save(
        out,
        save_all=True,
        append_images=images[1:],
        duration=duration_ms,
        loop=0,
        optimize=True,
        disposal=2,
    )
    size_kb = out.stat().st_size / 1024.0
    print(f"{out}  —  {len(images)} frames, {images[0].size[0]}x{images[0].size[1]}, "
          f"{duration_ms}ms/frame ({fps:g} fps), {size_kb:.0f} KB")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", type=Path, default=DEFAULT_SRC,
                    help="folder of PNGs (default: Godot's mcp_recorded_frames)")
    ap.add_argument("-o", "--out", type=Path, default=Path("out/capture.gif"),
                    help="output .gif path (default: out/capture.gif)")
    ap.add_argument("--fps", type=float, default=15.0,
                    help="GIF playback rate (default: 15)")
    ap.add_argument("--scale", type=int, default=2,
                    help="nearest-neighbour upscale (default: 2)")
    ap.add_argument("--start", type=int, default=0, help="first frame index to include")
    ap.add_argument("--end", type=int, default=None, help="stop before this frame index")
    ap.add_argument("--clear", action="store_true",
                    help="delete the source PNGs after a successful build")
    args = ap.parse_args()

    if not args.src.is_dir():
        sys.exit(f"No such folder: {args.src}\n"
                 "Record some frames first (Godot MCP `record_frames`), or pass --src.")

    frames = numbered_pngs(args.src)
    if not frames:
        sys.exit(f"No PNGs in {args.src}")

    build_gif(frames, args.out, args.fps, args.scale, args.start, args.end)

    if args.clear:
        for f in frames:
            f.unlink()
        print(f"cleared {len(frames)} source frames")


if __name__ == "__main__":
    main()
