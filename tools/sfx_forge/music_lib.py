"""Loopable music helpers on top of forge.py / sfx_lib.py.

THE LOOP ARCHITECTURE (why this module exists)
----------------------------------------------
A naive render of [0, SONG] cuts every reverb tail at the loop point, so the
seam is audible as a sudden "swallow" of the room. The fix here is to render
the *periodic steady state* instead:

  1. Every discrete event is emitted TWICE - at t and at t + SONG.
  2. Every sustained layer holds a flat level across the whole 2*SONG render.
  3. We render [0, 2*SONG] and keep only the SECOND period, [SONG, 2*SONG].

By the start of the second period the reverb has fully rung up, so the extracted
period is exactly one cycle of the steady-state response of a signal that
repeats forever. The tail that "should" wrap into the head is already there.
No crossfade, no tail-splice, no numpy surgery on the seam.

The one remaining discontinuity is oscillator PHASE: a sustained sine only lands
on the same phase at SONG and 2*SONG if it completes a whole number of cycles per
period.

MEASURED 2026-08-15, the hard way: the JS tonegenerator's "Base Frequency (Hz)"
slider QUANTIZES TO WHOLE Hz (ask for 36.7049, get 37.0) and "Fine Tune (cents)"
quantizes to whole cents. So you cannot dial in an arbitrary frequency, and an
earlier version of this module that rounded frequencies to multiples of 1/SONG was
silently defeated - the render came out with the drone 0.4 cycles out of phase
across the loop and a plainly audible click (seam step 4.7x the interior maximum).

The fix, and the rule for every track built with this module:

    DRONE FREQUENCIES ARE WHOLE Hz, AND SONG IS A WHOLE NUMBER OF SECONDS.

integer Hz * integer seconds = integer cycles, so every sustained oscillator lands
on exactly the same phase at both ends of the loop with no rounding at all. Pick
tonal centres that are already near-integer in Hz - A is ideal (A1 55, A2 110,
E3 165 is +2 cents), which is why both biome tracks are centred on A.

The cost is that two drones cannot beat slower than 1 Hz against each other. Get
slow instability from the amplitude envelopes instead - those are exact.

Consequence for composition: sustained drones must be FLAT or exactly periodic (no
fade in/out at the ends), and `drone_hz()` will reject a non-integer frequency.
"""
import math
import subprocess
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import forge  # noqa: E402
from forge import call, reset, BridgeError  # noqa: E402
from sfx_lib import master_clipper  # noqa: E402

SR = 44100


def gain(db):
    """Linear multiplier for `db` dB.

    TRAP, measured 2026-08-15: `forge.track(name, volume_db)` and every
    `vol_db=` parameter in sfx_lib pass their value STRAIGHT INTO REAPER's
    D_VOL, which is a LINEAR gain - the name is a misnomer. Passing -15.0
    "dB" therefore applies 15x gain with inverted polarity, not -15 dB, and
    the render slams the master soft clipper into a 0.8 dB crest factor.

    Always wrap music levels: vol_db=gain(-18.0). forge.py is left alone
    because the committed SFX recipes were rendered against its behaviour.
    """
    return 10.0 ** (db / 20.0)


# ReaSynth parameter ceilings, probed 2026-08-15. Values above these are silently
# CLAMPED, which is easy to miss because nothing errors and the note still sounds:
#   Decay   max 1.0 s      Release max 1.0 s      Sustain max 2.0
#   Volume  max 2.0 (0.5 is roughly unity)        Attack  max 10.0 s
# So a long bell or choir tail CANNOT come from the synth envelope. Hold the note
# with `sustain` over a long MIDI note length and let the reverb carry the decay.
SYNTH_MAX_DECAY = 1.0
SYNTH_MAX_RELEASE = 1.0


# ── frequency snapping ────────────────────────────────────────────────────────

def drone_hz(freq, song):
    """Validate a sustained-oscillator frequency for a seamless loop.

    Enforces the rule in the module docstring: whole Hz over a whole-second loop.
    Returns the frequency unchanged so it reads as a declaration at the call site.
    """
    if abs(song - round(song)) > 1e-9:
        raise ValueError(
            f"SONG={song} must be a whole number of seconds - the tonegenerator "
            f"quantizes frequency to whole Hz, so that is the only way a drone "
            f"completes whole cycles across the loop.")
    if abs(freq - round(freq)) > 1e-9:
        raise ValueError(
            f"drone frequency {freq} Hz must be a whole number - the tonegenerator "
            f"rounds it to {round(freq)} Hz anyway, which would put the loop seam "
            f"out of phase. Pick an integer, or move the tonal centre (A works: "
            f"55 / 110 / 165 Hz).")
    return float(round(freq))


def cents(base_hz, c):
    """Frequency of `base_hz` detuned by `c` cents (both quantized as the plugin is)."""
    return round(base_hz) * 2.0 ** (round(c) / 1200.0)


# ── periodic event helper ─────────────────────────────────────────────────────

def twice(events, song, t_index=1):
    """Duplicate a list of event tuples one period later.

    `t_index` is the tuple position holding the start time (1 for ReaSynth
    (pitch, start, len, vel) sequences, 0 for (time, ...) pairs).
    """
    out = list(events)
    for e in events:
        e2 = list(e)
        e2[t_index] = e[t_index] + song
        out.append(tuple(e2))
    return out


def flat(level, song, pad=1.0):
    """Flat envelope across the full 2-period render (for sustained layers)."""
    return [(0.0, level, 0), (2.0 * song + pad, level, 0)]


def wobble(level_db, depth_db, cycles, song, phase=0.0, res=10):
    """Slow sine amplitude drift, exactly `cycles` per loop so it crosses the seam.

    `cycles` must be a whole number - that is what makes the envelope periodic at
    `song` and therefore continuous when the loop wraps. Use co-prime cycle counts
    on different layers to get a composite that never audibly repeats.
    """
    if cycles != int(cycles):
        raise ValueError(f"wobble cycles={cycles} must be a whole number per loop")
    pts, steps = [], int(cycles) * res
    for i in range(2 * steps + 1):
        t = i * (song / steps)
        v = level_db + depth_db * math.sin(2 * math.pi * (i / res + phase))
        pts.append((t, v, 0))
    return pts


# ── render ────────────────────────────────────────────────────────────────────

def render_two_periods(name, layers_fn, song, out_dir, tempo=None, settle=180.0):
    """reset -> clipper -> layers -> render [0, 2*song]. Returns the raw wav path."""
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    raw = out_dir / f"{name}_raw.wav"
    raw.unlink(missing_ok=True)

    reset()
    if tempo:
        call("SetTempo", [float(tempo)])
    master_clipper()
    layers_fn()

    call("RenderProject", [str(raw), 0.0, 2.0 * song, 0.0, True], timeout=120)
    deadline = time.time() + settle
    last = -1
    while time.time() < deadline:
        if raw.exists():
            sz = raw.stat().st_size
            if sz == last and sz > 0:
                break
            last = sz
        time.sleep(0.5)
    else:
        raise BridgeError(f"render never settled: {raw}")
    return raw


def save_project(path):
    """Save the current REAPER project to an explicit .rpp path."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    call("Main_SaveProjectEx", [0, str(path), 0])
    return path


# ── audio io ──────────────────────────────────────────────────────────────────

def decode(path):
    """Decode any audio file to (n, 2) float32 numpy + sample rate."""
    sr = int(subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "a:0",
         "-show_entries", "stream=sample_rate", "-of", "csv=p=0", str(path)],
        capture_output=True, text=True, check=True).stdout.strip())
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le",
         "-acodec", "pcm_f32le", "-ac", "2", "-"],
        capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64), sr


def encode_ogg(data, sr, path, quality=6):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    buf = data.astype(np.float32).tobytes()
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(sr), "-ac", "2",
         "-i", "-", "-c:a", "libvorbis", "-qscale:a", str(quality), str(path)],
        input=buf, check=True)
    return path


def write_wav(data, sr, path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(sr), "-ac", "2",
         "-i", "-", "-c:a", "pcm_s24le", str(path)],
        input=data.astype(np.float32).tobytes(), check=True)
    return path


# ── loudness ──────────────────────────────────────────────────────────────────

def lufs(path):
    """(integrated LUFS, LRA, true peak dBFS) via ffmpeg ebur128."""
    out = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", str(path),
         "-filter_complex", "ebur128=peak=true", "-f", "null", "-"],
        capture_output=True, text=True).stderr
    tail = out[out.rfind("Summary:"):]

    def grab(label):
        for line in tail.splitlines():
            s = line.strip()
            if s.startswith(label):
                return float(s.split()[1])
        return float("nan")

    return grab("I:"), grab("LRA:"), grab("Peak:")


# ── the loop extraction + seam analysis ───────────────────────────────────────

def extract_period(raw_path, song):
    """Keep the LAST full period: the steady state with reverb already rung up.

    Taking it from the end rather than at a fixed offset is deliberate. REAPER
    rounds the render end to a whole buffer, and `song * sr` is usually not an
    integer sample count anyway, so a fixed [n : 2n] slice can fall a few samples
    off the end of the file. Any window one period long taken from the settled
    region is equally valid, so anchor to the end and the rounding stops mattering.
    """
    data, sr = decode(raw_path)
    n = int(round(song * sr))
    if len(data) < 2 * n - int(0.25 * sr):
        raise RuntimeError(
            f"render too short: {len(data)} samples, need ~{2 * n} "
            f"({len(data) / sr:.2f}s vs {2 * song:.2f}s)")
    return data[-n:].copy(), sr


def periodicity_report(raw_path, song, strict=True):
    """Check the RENDER really repeats with period `song` before extracting a loop.

    This is the check that catches a defeated frequency snap: if a sustained
    oscillator is off-grid, x(t) and x(t + song) drift out of phase and the
    correlation collapses (it went NEGATIVE, -0.67, in the first catacombs build).
    Run this before finalize - it localises the fault to the composition rather
    than leaving you staring at a click in the finished file.
    """
    data, sr = decode(raw_path)
    m = data.mean(axis=1)
    n = int(round(song * sr))
    w = int(3.0 * sr)
    corrs = []
    for off in (0.25, 0.45, 0.65):
        a = int(off * n)
        x, y = m[a:a + w], m[a + n:a + n + w]
        if len(y) < w:
            break
        c = float((x * y).sum() / (np.linalg.norm(x) * np.linalg.norm(y) + 1e-12))
        corrs.append(c)
    worst = min(corrs) if corrs else float("nan")
    print(f"  periodicity @ {song:g}s: corr {' '.join(f'{c:+.4f}' for c in corrs)}"
          f"   worst {worst:+.4f}  {'OK' if worst > 0.90 else 'NOT PERIODIC'}")
    if strict and not worst > 0.90:
        raise RuntimeError(
            f"render does not repeat at {song}s (worst corr {worst:+.4f}). A sustained "
            f"oscillator is off-grid - see the frequency rule in music_lib's docstring.")
    return worst


def clip_report(raw_path):
    """How hard the master soft clipper is working. Wall-of-sound detector."""
    data, sr = decode(raw_path)
    m = np.abs(data).max(axis=1)
    peak = float(m.max())
    over1 = float((m > 10 ** (-1 / 20)).mean())
    over3 = float((m > 10 ** (-3 / 20)).mean())
    crest = 20 * math.log10(peak / (float(np.sqrt((data ** 2).mean())) + 1e-12) + 1e-12)
    flag = "OK" if over1 < 0.001 else "CLIPPING - drop layer levels"
    print(f"  render peak {20 * math.log10(peak + 1e-12):.1f} dBFS  crest {crest:.1f} dB  "
          f"above -1 dBFS {over1 * 100:.2f}%  above -3 dBFS {over3 * 100:.2f}%  {flag}")
    return over1, crest


def _transition(mono, sr, t):
    """(rms delta dB, spectral cosine) across the instant `t`, wrapping the loop."""
    w, n = int(1.0 * sr), len(mono)
    i = int(t * sr) % n
    pre = np.take(mono, range(i - w, i), mode="wrap")
    post = np.take(mono, range(i, i + w), mode="wrap")

    def spec(x):
        s = np.abs(np.fft.rfft(x * np.hanning(len(x))))
        return s / (s.sum() + 1e-12)

    a, b = spec(pre), spec(post)
    cos = float((a * b).sum() / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-12))
    r = lambda x: 20 * math.log10(float(np.sqrt((x ** 2).mean())) + 1e-12)  # noqa: E731
    return r(post) - r(pre), cos


def seam_report(loop, sr, label="", probes=()):
    """Seam check, in two parts.

    1. CLICK: the sample step across the wrap point vs the distribution of
       ordinary interior steps. A ratio <= 1 means the join is smaller than
       noise the waveform already contains, i.e. there is nothing to hear.

    2. MUSICAL VISIBILITY: whether the loop point stands out *as an event*.
       An absolute spectral-similarity threshold is the wrong test here - a
       track whose loop lands on a downbeat will always show a jump, because
       downbeats are jumps. So compare the loop point against `probes`, a list
       of ordinary interior instants. If the seam sits inside the spread of
       normal bar lines, the loop is not detectable as a restart.
    """
    mono = loop.mean(axis=1)
    steps = np.abs(np.diff(mono))
    seam_step = abs(mono[0] - mono[-1])
    p999 = float(np.percentile(steps, 99.9))
    ratio = seam_step / (p999 + 1e-12)

    d_seam, cos_seam = _transition(mono, sr, 0.0)
    print(f"  seam{' ' + label if label else ''}:")
    print(f"    click: step across join {seam_step:.2e} vs 99.9th pct interior "
          f"{p999:.2e}  ratio {ratio:.2f}  {'OK' if ratio <= 1.0 else 'CLICK RISK'}")
    print(f"    loop point:  rms {d_seam:+.1f} dB   spectral cos {cos_seam:.4f}")

    verdict = "OK"
    if probes:
        ds = [_transition(mono, sr, t) for t in probes]
        lo, hi = min(c for _, c in ds), max(c for _, c in ds)
        dmax = max(abs(d) for d, _ in ds)
        print(f"    interior bar lines ({len(probes)} probed): cos {lo:.4f}-{hi:.4f}, "
              f"rms delta up to {dmax:.1f} dB")
        if cos_seam >= lo - 0.005 and abs(d_seam) <= dmax + 0.5:
            print("    -> seam sits inside the spread of ordinary transitions: "
                  "not audible as a restart")
        else:
            verdict = "SEAM STANDS OUT"
            print(f"    -> {verdict}: the join is a bigger event than any interior bar line")
    return ratio, cos_seam, verdict


def finalize(name, raw_path, song, music_dir, target_lufs, stage_dir, probes=()):
    """Extract the loop, match loudness to target, write OGG + a seam-proof WAV."""
    loop, sr = extract_period(raw_path, song)

    # loudness match: measure the actual loop, then apply a single static gain
    probe = Path(stage_dir) / f"{name}_loop.wav"
    write_wav(loop, sr, probe)
    i0, lra0, tp0 = lufs(probe)
    gain_db = target_lufs - i0
    loop *= 10 ** (gain_db / 20.0)

    peak = float(np.abs(loop).max())
    print(f"  {name}: measured {i0:.1f} LUFS -> gain {gain_db:+.2f} dB "
          f"(LRA {lra0:.1f}, peak now {20 * math.log10(peak + 1e-12):.1f} dBFS)")

    write_wav(loop, sr, probe)
    ratio, cosine, verdict = seam_report(loop, sr, name, probes)

    ogg = encode_ogg(loop, sr, Path(music_dir) / f"{name}.ogg")
    i1, lra1, tp1 = lufs(ogg)
    print(f"  {name}.ogg: {i1:.1f} LUFS  LRA {lra1:.1f}  true peak {tp1:.1f} dBFS  "
          f"{len(loop) / sr:.2f}s")
    return dict(name=name, ogg=ogg, lufs=i1, lra=lra1, peak=tp1,
                secs=len(loop) / sr, seam_ratio=ratio, seam_cosine=cosine,
                seam_verdict=verdict)
