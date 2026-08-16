"""Copy auditioned biome tracks from staging into the game.

  python install_biome_music.py [catacombs|nightmare_realm|all]

The pipeline (docs/audio_pipeline.md) is: render to assets/audio/_incoming/,
audition there, then move into assets/audio/music/. build_biome_music.py does the
first half; this does the second, so the shipped file is only ever one that was
listened to. Godot generates the .import on its next filesystem scan.

No GDScript changes are needed - the SoundTable entries for `mus_catacombs` and
`mus_nightmare_realm` already point at these exact filenames.
"""
import shutil
import sys
from pathlib import Path

STAGE = Path(r"E:\Projects\extraction-survivors\assets\audio\_incoming\reaper_music")
MUSIC = Path(r"E:\Projects\extraction-survivors\assets\audio\music")
NAMES = ("catacombs", "nightmare_realm")

if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    names = NAMES if which == "all" else (which,)
    for name in names:
        src = STAGE / f"{name}.ogg"
        if not src.exists():
            raise SystemExit(f"not staged: {src} - run build_biome_music.py first")
        dst = MUSIC / f"{name}.ogg"
        shutil.copy2(src, dst)
        print(f"  {src.name} -> {dst}  ({dst.stat().st_size / 1024:.0f} KB)")
    print("Rescan the Godot filesystem to (re)generate the .import files.")
