"""Normalize (-1 dBFS), trim trailing silence, convert WAV -> OGG mirroring
the live sound_table.gd directory layout. Loop files are never trimmed/faded."""
import math
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent))
import forge
from pathlib import Path as _P
forge.OUT_DIR = _P(r'E:\Projects\extraction-survivors\assets\audio\_incoming\reaper_sfx_v2')
OUT_DIR = forge.OUT_DIR
from forge import read_wav
import numpy as np

OGG = OUT_DIR / "ogg"

# name -> (subdir, mono)
LAYOUT = {}
for n in (["swing_light_0", "swing_light_1", "swing_light_2",
           "swing_heavy_0", "swing_heavy_1", "swing_heavy_2",
           "kill", "death_enemy_normal_0", "death_enemy_normal_1",
           "death_enemy_elite", "block", "dodge"]
          + [f"hit_{t}_{i}" for t in ("physical", "fire", "cryo", "shock", "void") for i in range(3)]):
    LAYOUT[n] = ("combat", True)
for n in ("crit", "death_enemy_boss", "death_player", "boss_intro"):
    LAYOUT[n] = ("combat", False)
for n in ("burn_apply", "chill_apply", "frozen", "shocked_apply", "void_apply"):
    LAYOUT[n] = ("status", True)
for n in ("pickup_xp_0", "pickup_xp_1", "pickup_currency_0", "pickup_currency_1",
          "pickup_weapon", "pickup_mod", "pickup_keystone"):
    LAYOUT[n] = ("pickup", False)
for n in ("level_up", "upgrade_select", "ui_click", "ui_panel_open",
          "ui_panel_close", "ui_purchase", "ui_error", "ui_cancel"):
    LAYOUT[n] = ("ui", False)
for n in ("extraction_warning", "extraction_channel_start", "extraction_channel_hum",
          "extraction_channel_complete", "extraction_interrupted"):
    LAYOUT[n] = ("extraction", False)
for n in ("dash_generic", "dash_teleport", "dash_deadly", "dash_dodge_roll"):
    LAYOUT[n] = ("dash", False)

LOOPS = {"extraction_channel_hum"}
TARGET = 10 ** (-1.0 / 20.0)  # -1 dBFS

results, missing = [], []
for name, (sub, mono) in LAYOUT.items():
    src = OUT_DIR / f"{name}.wav"
    if not src.exists():
        missing.append(name)
        continue
    data, sr = read_wav(src)
    peak = float(np.abs(data).max())
    gain_db = 20 * math.log10(TARGET / peak)
    dst = OGG / sub / f"{name}.ogg"
    dst.parent.mkdir(parents=True, exist_ok=True)

    af = [f"volume={gain_db:.2f}dB"]
    cmd = ["ffmpeg", "-y", "-v", "error", "-i", str(src)]
    if name not in LOOPS:
        # trim trailing silence below -60 dBFS (+40ms grace)
        thresh = 10 ** (-60 / 20.0) / max(peak, 1e-9) * float(np.abs(data).max())
        above = np.nonzero(np.abs(data) > 10 ** (-60 / 20.0) * peak)[0]
        end = min(len(data), (above[-1] if len(above) else len(data)) + int(0.04 * sr))
        cmd += ["-t", f"{end / sr:.4f}"]
    cmd += ["-af", ",".join(af), "-ac", "1" if mono else "2",
            "-c:a", "libvorbis", "-qscale:a", "5", str(dst)]
    subprocess.run(cmd, check=True)
    results.append((name, sub, round(peak, 3), round(gain_db, 1)))

print(f"{len(results)} converted, {len(missing)} missing: {missing}")

# loop seam check for the hum
data, sr = read_wav(OUT_DIR / "extraction_channel_hum.wav")
w = int(0.05 * sr)
rms_a = float(np.sqrt((data[:w] ** 2).mean()))
rms_b = float(np.sqrt((data[-w:] ** 2).mean()))
print(f"hum loop seam: first 50ms rms={rms_a:.4f}, last 50ms rms={rms_b:.4f}, "
      f"ratio {max(rms_a, rms_b) / max(min(rms_a, rms_b), 1e-9):.2f}")

total = sum(1 for _ in OGG.rglob("*.ogg"))
print(f"total ogg files: {total}")


