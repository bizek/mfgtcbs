"""Build the three held-channel bed loops: render, extract, normalize, encode.

  python build_channel_loops.py [fire|arcane|martial|all]

Unlike the biome music (music_lib.render_two_periods + extract_period), these beds
lean on continuously-running noise generators for their body - and noise has no
phase to lock across a loop seam the way a MIDI note or oscillator does. Placing
the same event twice a period apart (music_lib's trick) only makes DETERMINISTIC
content periodic; a live noise stream sliced at two different absolute times is
just two uncorrelated points. So after extracting the settled second period, the
true TAIL is folded into the true HEAD with a short equal-power crossfade (the
standard ambient-loop splice) - fading the head into unrelated future render
material doesn't touch the actual seam and was tried and measured worse.

Also unlike the biome music, these are peak-normalized like ordinary SFX rather
than LUFS-matched to a music reference: SoundTable already applies -18 dB on
playback to sit the bed under the beat hits, so the source file should read like a
normal, present sfx render.

Writes OGG + a seam-proof WAV into the staging folder. Nothing is copied into
assets/audio/sfx/combat/ - install_channel_loops.py does that.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import numpy as np  # noqa: E402

import music_lib as ml  # noqa: E402

STAGE = Path(r"E:\Projects\extraction-survivors\assets\audio\_incoming\reaper_music")
TARGET_PEAK_DB = -6.0
XFADE_SEC = 0.04  # 40ms equal-power crossfade folding the render's tail into its head

TRACKS = {}
PROBES = {
    "channel_loop_fire": (0.6, 1.0, 1.4),
    "channel_loop_arcane": (0.6, 1.0, 1.4),
    "channel_loop_martial": (0.6, 1.0, 1.4),
}
# music_lib.seam_report's "musical visibility" transition window is a fixed 1.0s -
# sized for tracks tens of seconds long. On a 2.0s loop that window is half the
# whole track, so pre/post regions for any two probes nearly coincide and the
# check degenerates into "first half vs second half" rather than testing whether
# the wrap point looks like a local event. Scale it down to fit these loops.
SEAM_WINDOW_SEC = 0.2


def _load():
    import channel_loop_fire as fire
    import channel_loop_arcane as arcane
    import channel_loop_martial as martial
    TRACKS["channel_loop_fire"] = (fire.build_song, fire.SONG)
    TRACKS["channel_loop_arcane"] = (arcane.build_song, arcane.SONG)
    TRACKS["channel_loop_martial"] = (martial.build_song, martial.SONG)


def extract_loop_xfade(raw_path, song, xfade):
    """Extract the settled second period (music_lib.extract_period), then fold its
    true tail into its true head with a short equal-power crossfade.

    seg has length n and is meant to repeat back-to-back; the click lives at the
    seg[-1] -> seg[0] join, which are NOT adjacent samples in the original render.
    Blending seg[0:xf] (natural head) with seg[n-xf:n] (natural tail) at the START
    of the output and dropping the redundant xf tail samples makes both output
    boundaries land on originally-adjacent sample pairs:
      output[-1] (= seg[n-xf-1]) -> output[0] (~= seg[n-xf], fade_out~=1 at i=0)
      output[xf-1] (~= seg[xf-1], fade_in~=1 at i=xf-1) -> output[xf] (= seg[xf])
    Output is n - xf samples long (a shade under `song`, well inside "~2s").
    """
    seg, sr = ml.extract_period(raw_path, song)
    n = len(seg)
    xf = int(round(xfade * sr))
    t = np.linspace(0.0, np.pi, xf)
    fade_in = 0.5 * (1.0 - np.cos(t))    # 0 -> 1, equal-power-ish
    fade_out = 1.0 - fade_in
    blended_head = seg[:xf] * fade_in[:, None] + seg[n - xf:n] * fade_out[:, None]
    loop = np.concatenate([blended_head, seg[xf:n - xf]], axis=0)
    return loop, sr


def _transition_w(mono, sr, t, w_sec):
    """Same measurement as music_lib._transition but with a window sized to fit
    a short loop instead of the module's fixed 1.0s (built for full-length music)."""
    w, n = int(w_sec * sr), len(mono)
    i = int(t * sr) % n
    pre = np.take(mono, range(i - w, i), mode="wrap")
    post = np.take(mono, range(i, i + w), mode="wrap")

    def spec(x):
        s = np.abs(np.fft.rfft(x * np.hanning(len(x))))
        return s / (s.sum() + 1e-12)

    a, b = spec(pre), spec(post)
    cos = float((a * b).sum() / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-12))
    r = lambda x: 20 * np.log10(float(np.sqrt((x ** 2).mean())) + 1e-12)  # noqa: E731
    return r(post) - r(pre), cos


def seam_report_short(loop, sr, label, probes, w_sec):
    """music_lib.seam_report's click check (window-independent) plus a musical-
    visibility check using a window scaled to the loop length."""
    mono = loop.mean(axis=1)
    steps = np.abs(np.diff(mono))
    seam_step = abs(mono[0] - mono[-1])
    p999 = float(np.percentile(steps, 99.9))
    ratio = seam_step / (p999 + 1e-12)

    d_seam, cos_seam = _transition_w(mono, sr, 0.0, w_sec)
    print(f"  seam {label}:")
    print(f"    click: step across join {seam_step:.2e} vs 99.9th pct interior "
          f"{p999:.2e}  ratio {ratio:.2f}  {'OK' if ratio <= 1.0 else 'CLICK RISK'}")
    print(f"    loop point:  rms {d_seam:+.1f} dB   spectral cos {cos_seam:.4f}")

    verdict = "OK"
    if probes:
        ds = [_transition_w(mono, sr, t, w_sec) for t in probes]
        lo = min(c for _, c in ds)
        dmax = max(abs(d) for d, _ in ds)
        print(f"    interior probes ({len(probes)} @ {w_sec*1000:.0f}ms window): "
              f"cos {lo:.4f}-{max(c for _, c in ds):.4f}, rms delta up to {dmax:.1f} dB")
        if cos_seam >= lo - 0.005 and abs(d_seam) <= dmax + 0.5:
            print("    -> seam sits inside the spread of ordinary transitions: "
                  "not audible as a restart")
        else:
            verdict = "SEAM STANDS OUT"
            print(f"    -> {verdict}: the join is a bigger event than any interior probe")
    return ratio, cos_seam, verdict


def finalize_peak(name, raw_path, song, out_dir, target_peak_db, probes=()):
    loop, sr = extract_loop_xfade(raw_path, song, XFADE_SEC)
    peak = float(np.abs(loop).max())
    target = 10 ** (target_peak_db / 20.0)
    gain_db = 20.0 * np.log10(target / (peak + 1e-12))
    loop *= target / (peak + 1e-12)

    probe_wav = Path(out_dir) / f"{name}_loop.wav"
    ml.write_wav(loop, sr, probe_wav)
    print(f"  {name}: raw peak {20*np.log10(peak+1e-12):.1f} dBFS -> "
          f"gain {gain_db:+.2f} dB -> peak {target_peak_db:.1f} dBFS")

    ratio, cosine, verdict = seam_report_short(loop, sr, name, probes, SEAM_WINDOW_SEC)

    ogg = ml.encode_ogg(loop, sr, Path(out_dir) / f"{name}.ogg")
    i1, lra1, tp1 = ml.lufs(ogg)
    print(f"  {name}.ogg: {i1:.1f} LUFS  LRA {lra1:.1f}  true peak {tp1:.1f} dBFS  "
          f"{len(loop)/sr:.2f}s")
    return dict(name=name, ogg=ogg, lufs=i1, lra=lra1, peak=tp1,
                secs=len(loop) / sr, seam_ratio=ratio, seam_cosine=cosine,
                seam_verdict=verdict)


def run(name, reuse=False):
    fn, song = TRACKS[name]
    print(f"\n=== {name} ===")
    raw = STAGE / f"{name}_raw.wav"
    if reuse and raw.exists():
        print(f"  reusing existing render {raw.name}")
    else:
        print(f"  loop {song:.2f}s, rendering 2 periods ({2*song:.1f}s)")
        raw = ml.render_two_periods(name, fn, song, STAGE, tempo=120.0, settle=60.0)
        ml.save_project(STAGE / f"{name}.rpp")
    ml.clip_report(raw)
    # periodicity_report's correlation window is 3s - built for long music tracks,
    # wider than our whole 2s loop period. The check that actually matters for a
    # short bed is the seam itself, which finalize_peak's seam_report covers.
    return finalize_peak(name, raw, song, STAGE, TARGET_PEAK_DB, PROBES[name])


if __name__ == "__main__":
    _load()
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    reuse = "--reuse" in sys.argv
    which = args[0] if args else "all"
    names = ({"channel_loop_fire", "channel_loop_arcane", "channel_loop_martial"}
              if which == "all" else {f"channel_loop_{which}"})
    names = [n for n in TRACKS if n in names]

    results = [run(n, reuse) for n in names]

    print("\n=== summary ===")
    print(f"{'bed':22} {'secs':>6} {'LUFS':>7} {'LRA':>6} {'TP dB':>7} "
          f"{'seam':>6} {'cos':>7}  verdict")
    for r in results:
        print(f"{r['name']:22} {r['secs']:>6.2f} {r['lufs']:>7.1f} {r['lra']:>6.1f} "
              f"{r['peak']:>7.1f} {r['seam_ratio']:>6.2f} {r['seam_cosine']:>7.4f}  "
              f"{r['seam_verdict']}")
