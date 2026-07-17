"""Analyze the rendered track (section levels, loop seam), then convert to OGG."""
import math
import subprocess
import sys

sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent))
from forge import OUT_DIR, read_wav
import numpy as np

SRC = OUT_DIR / "music" / "gameplay_dnb_lofi.wav"
data, sr = read_wav(SRC)
secs = len(data) / sr
peak = float(np.abs(data).max())
rms = float(np.sqrt((data ** 2).mean()))
print(f"length {secs:.2f}s  peak {peak:.3f}  rms {20*math.log10(rms):.1f} dBFS")

# per-section RMS (4 sections of 8 bars)
q = len(data) // 4
for i, name in enumerate(("A (sparse)", "A' (+melody)", "B (pads)", "A'' (+answer)")):
    seg = data[i * q:(i + 1) * q]
    print(f"  {name:14} rms {20*math.log10(np.sqrt((seg**2).mean())+1e-12):.1f} dBFS")

# loop seam: last 50ms vs first 50ms level
w = int(0.05 * sr)
a = float(np.sqrt((data[:w] ** 2).mean()))
b = float(np.sqrt((data[-w:] ** 2).mean()))
print(f"loop seam rms: start {a:.4f} / end {b:.4f}")

# beat check: autocorrelate onset envelope around expected beat period
env = np.abs(data)
hop = int(sr * 0.01)
frames = env[:len(env) // hop * hop].reshape(-1, hop).mean(axis=1)
d = np.diff(frames); d[d < 0] = 0
expect = int(round((60.0 / 172.0) / 0.01))
ac = np.correlate(d, d, "full")[len(d) - 1:]
window = ac[max(1, expect - 5):expect + 6]
best = int(np.argmax(window)) + max(1, expect - 5)
print(f"beat period: expected ~{expect * 10}ms, autocorr peak at {best * 10}ms")

# normalize to -1 dBFS and convert (no trim â€” loop must stay exact)
gain_db = 20 * math.log10(10 ** (-1.0 / 20.0) / peak)
dst = OUT_DIR / "ogg" / "music" / "gameplay_dnb_lofi.ogg"
dst.parent.mkdir(parents=True, exist_ok=True)
subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(SRC),
                "-af", f"volume={gain_db:.2f}dB", "-ac", "2",
                "-c:a", "libvorbis", "-qscale:a", "6", str(dst)], check=True)
print(f"converted -> {dst} (gain {gain_db:+.1f} dB)")

