import sys, math
sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent))
from forge import OUT_DIR, read_wav
import numpy as np

data, sr = read_wav(OUT_DIR / "music" / "gameplay_dnb_lofi.wav")
sp = np.abs(np.fft.rfft(data * np.hanning(len(data)))) ** 2
freqs = np.fft.rfftfreq(len(data), 1 / sr)
bands = [("sub 20-80", 20, 80), ("bass 80-250", 80, 250), ("mids 250-2k", 250, 2000),
         ("high 2k-8k", 2000, 8000), ("air 8k+", 8000, 20000)]
total = sp[(freqs >= 20) & (freqs < 20000)].sum()
for name, lo, hi in bands:
    e = sp[(freqs >= lo) & (freqs < hi)].sum() / total * 100
    print(f"  {name:14} {e:5.1f}%")

