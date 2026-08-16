"""Copy auditioned channel-loop beds from staging into the game.

  python install_channel_loops.py [fire|arcane|martial|all]

The pipeline (docs/audio_pipeline.md) is: render to assets/audio/_incoming/,
audition there, then move into assets/audio/sfx/combat/. build_channel_loops.py
does the first half; this does the second. No GDScript changes are needed - the
SoundTable entries for sfx_channel_loop_fire/arcane/martial already point at these
exact filenames.
"""
import shutil
import sys
from pathlib import Path

STAGE = Path(r"E:\Projects\extraction-survivors\assets\audio\_incoming\reaper_music")
DEST = Path(r"E:\Projects\extraction-survivors\assets\audio\sfx\combat")
NAMES = ("channel_loop_fire", "channel_loop_arcane", "channel_loop_martial")

if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    names = NAMES if which == "all" else (f"channel_loop_{which}",)
    for name in names:
        src = STAGE / f"{name}.ogg"
        if not src.exists():
            raise SystemExit(f"not staged: {src} - run build_channel_loops.py first")
        dst = DEST / f"{name}.ogg"
        shutil.copy2(src, dst)
        print(f"  {src.name} -> {dst}  ({dst.stat().st_size / 1024:.0f} KB)")
    print("Rescan the Godot filesystem to (re)generate the .import files.")
