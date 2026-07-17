"""High-level SFX vocabulary on top of forge.py.

Layer builders create one track each; a recipe = several layers + render.
All amplitude envelopes are in raw dB (tonegenerator Wet Mix -120..6,
pink-noise Wet 0..1), frequencies in real Hz.
"""
import math
import sys

sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent))
from forge import (  # noqa: E402
    call, reset, track, fx, setp, fx_env, midi, note, notes, render, BridgeError,
)

# â”€â”€ param index maps (from probe dump) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
TG = dict(wet_db=0, dry_db=1, freq=2, note=3, octave=4, fine=5, shape=6)
PN = dict(mode=0, noise_db=1, dry_db=2, out_db=3, wet=5)
SYN = dict(attack=0, release=1, square=2, saw=3, tri=4, vol=5, decay=6,
           xsine=7, xsine_tune=8, sustain=9, pw=10, detune=11, porta=13)
DELAY = dict(wet=0, dry=1, enabled=2, len_time=3, len_mus=4, fb=5, lp=6, hp=7, vol=10)
VERB = dict(wet=0, dry=1, size=2, damp=3, width=4, lp=6, hp=7)
PITCH = dict(wet=0, dry=1, semis=5, oct=6, vol=10)
DIST = dict(gain=0, hard=1, maxvol=2)
SAT = dict(amount=0)
RM = dict(diode=1, freq=2, fb=3, nonlin=4, mix=5, out=6)
CHOR = dict(length=0, voices=1, rate=2, fudge=3, wet_db=4, dry_db=5)
FLG = dict(length=0, fb=1, wet_db=2, dry_db=3, rate=4)
PHS = dict(rate=0, fmin=1, fmax=2, fb=3, wet_db=4)
CLIP = dict(boost=0, brick=1)

SILENT = -120.0


# â”€â”€ envelope shapes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def decay_db(t0, dur, peak_db=0.0, attack=0.004, drop=60.0):
    """Percussive envelope: linear dB decay = exponential amplitude decay."""
    return [(max(0.0, t0 - 0.002), SILENT, 0),
            (t0 + attack, peak_db, 0),
            (t0 + attack + dur, peak_db - drop, 0),
            (t0 + attack + dur + 0.01, SILENT, 0)]


def swell_db(t0, dur, peak_db=0.0, rise=0.4, edge_db=-45.0):
    """Whoosh hump: exponential rise to peak, exponential fall."""
    return [(max(0.0, t0 - 0.002), SILENT, 0),
            (t0 + 0.001, edge_db, 0),
            (t0 + dur * rise, peak_db, 0),
            (t0 + dur, edge_db, 0),
            (t0 + dur + 0.01, SILENT, 0)]


def hold_db(t0, dur, level_db=0.0, a=0.01, r=0.05):
    return [(max(0.0, t0 - 0.002), SILENT, 0), (t0 + a, level_db, 0),
            (t0 + dur - r, level_db, 0), (t0 + dur, SILENT, 0)]


def sweep(t0, dur, f0, f1, n=10, curve=1.0):
    """Frequency envelope Hz, exponential glide."""
    pts = []
    for i in range(n + 1):
        f = (i / n) ** curve
        hz = f0 * ((f1 / f0) ** f)
        pts.append((t0 + dur * f, hz, 0))
    return pts


# gate envelopes for pink-noise Wet (0..1 linear amplitude)

def gate_decay(t0, dur, peak=1.0, attack=0.003, n=8):
    pts = [(max(0.0, t0 - 0.002), 0.0, 0), (t0 + attack, peak, 0)]
    for i in range(1, n + 1):
        f = i / n
        pts.append((t0 + attack + (dur - attack) * f, peak * ((1 - f) ** 2.2), 0))
    pts.append((t0 + dur + 0.01, 0.0, 0))
    return pts


def gate_swell(t0, dur, peak=1.0, rise=0.4, n=10):
    pts = [(max(0.0, t0 - 0.002), 0.0, 0)]
    for i in range(n + 1):
        f = i / n
        amp = peak * ((f / rise) ** 1.5) if f <= rise else peak * ((1 - (f - rise) / (1 - rise)) ** 1.8)
        pts.append((t0 + dur * f, min(peak, max(0.0, amp)), 0))
    pts.append((t0 + dur + 0.01, 0.0, 0))
    return pts


# â”€â”€ layer builders â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def tone_layer(name, shape=0, freq_pts=None, amp_pts=None, vol_db=0.0, chain=()):
    """tonegenerator layer. shape 0/1/2. freq_pts in Hz, amp_pts in dB (Wet Mix)."""
    tr = track(name, vol_db)
    tg = fx(tr, "tonegenerator")
    setp(tr, tg, TG["dry_db"], -120.0)
    setp(tr, tg, TG["shape"], shape)
    setp(tr, tg, TG["wet_db"], SILENT)  # silent unless enveloped
    if freq_pts:
        fx_env(tr, tg, TG["freq"], freq_pts)
    if amp_pts:
        fx_env(tr, tg, TG["wet_db"], amp_pts)
    _apply_chain(tr, chain)
    return tr


def noise_layer(name, white=True, gate_pts=None, noise_db=0.0, vol_db=0.0, chain=()):
    """pink-noise JS layer; gate_pts on Wet (0..1)."""
    tr = track(name, vol_db)
    pn = fx(tr, "pink noise")
    setp(tr, pn, PN["mode"], 1.0 if white else 0.0)
    setp(tr, pn, PN["dry_db"], -25.0)
    setp(tr, pn, PN["noise_db"], noise_db)
    setp(tr, pn, PN["wet"], 0.0)
    if gate_pts:
        fx_env(tr, pn, PN["wet"], gate_pts)
    _apply_chain(tr, chain)
    return tr


def synth_layer(name, seq, attack=0.003, decay=0.15, sustain=0.0, release=0.08,
                square=0.0, saw=0.0, tri=0.0, xsine=0.0, porta=0.0,
                vol=0.7, vol_db=0.0, chain=(), item_len=4.0):
    """ReaSynth layer. seq: [(pitch, start, len, vel)]."""
    tr = track(name, vol_db)
    syn = fx(tr, "ReaSynth")
    setp(tr, syn, SYN["attack"], attack)
    setp(tr, syn, SYN["decay"], decay)
    setp(tr, syn, SYN["sustain"], sustain)
    setp(tr, syn, SYN["release"], release)
    setp(tr, syn, SYN["square"], square)
    setp(tr, syn, SYN["saw"], saw)
    setp(tr, syn, SYN["tri"], tri)
    setp(tr, syn, SYN["xsine"], xsine)
    setp(tr, syn, SYN["porta"], porta)
    setp(tr, syn, SYN["vol"], vol)
    item = midi(tr, 0.0, item_len)
    notes(tr, item, seq)
    _apply_chain(tr, chain)
    return tr


def _apply_chain(tr, chain):
    """chain: [(fx_name, {param_index: value} | {(env, param_index): points})]"""
    for fx_name, params in chain:
        i = fx(tr, fx_name)
        for key, val in params.items():
            if isinstance(key, tuple):  # ("env", param_idx)
                fx_env(tr, i, key[1], val)
            else:
                setp(tr, i, key, val)


# common chain fragments

def verb(size=0.4, wet=0.35, damp=0.5, lp=1.0, dry=1.0):
    return ("ReaVerbate", {VERB["size"]: size, VERB["wet"]: wet, VERB["damp"]: damp,
                           VERB["lp"]: lp, VERB["dry"]: dry})


def lowpass(amount, hp=0.0):
    """ReaDelay as filter: zero-length tap, dry off, wet unity, lowpass 0..1."""
    return ("ReaDelay", {DELAY["dry"]: 0.0, DELAY["wet"]: 1.0, DELAY["len_time"]: 0.0,
                         DELAY["len_mus"]: 0.0, DELAY["fb"]: 0.0, DELAY["lp"]: amount,
                         DELAY["hp"]: hp, DELAY["vol"]: 1.0})


def highpass(amount, lp=1.0):
    return lowpass(lp, hp=amount)


def echo(time_s=0.12, fb=0.4, wet=0.35, lp=1.0):
    """Real delay taps (len_time normalized 0..1 over 0..10s)."""
    return ("ReaDelay", {DELAY["dry"]: 1.0, DELAY["wet"]: wet, DELAY["len_time"]: time_s / 10.0,
                         DELAY["len_mus"]: 0.0, DELAY["fb"]: fb, DELAY["lp"]: lp,
                         DELAY["vol"]: 1.0})


def dist(gain=15.0, hard=4.0, maxv=-9.0):
    return ("Distortion", {DIST["gain"]: gain, DIST["hard"]: hard, DIST["maxvol"]: maxv})


def sat(pct=35.0):
    return ("Saturation", {SAT["amount"]: pct})


def ringmod(freq=40.0, mix=60.0, nonlin=15.0):
    return ("ring modulator", {RM["freq"]: freq, RM["mix"]: mix, RM["nonlin"]: nonlin})


def flanger(length=6.0, fb=-9.0, rate=1.5, wet=-9.0, dry=-3.0):
    return ("Flanger", {FLG["length"]: length, FLG["fb"]: fb, FLG["rate"]: rate,
                        FLG["wet_db"]: wet, FLG["dry_db"]: dry})


def phaser(rate=2.0, fmin=300.0, fmax=3000.0, wet=-3.0):
    return ("phaser", {PHS["rate"]: rate, PHS["fmin"]: fmin, PHS["fmax"]: fmax,
                       PHS["wet_db"]: wet})


def chorus(length=20.0, voices=3.0, rate=0.8, wet=-6.0, dry=-6.0):
    return ("Chorus", {CHOR["length"]: length, CHOR["voices"]: voices, CHOR["rate"]: rate,
                       CHOR["wet_db"]: wet, CHOR["dry_db"]: dry})


def master_clipper():
    """Soft clipper on master to prevent inter-layer clipping."""
    if call("TrackFX_GetCount", [-1])["ret"] == 0:
        i = fx(-1, "Soft Clipper")
        setp(-1, i, CLIP["boost"], 0.0)
        setp(-1, i, CLIP["brick"], -1.0)


def build(name, layers_fn, length, tail=0.4, subdir=""):
    """reset -> master clipper -> layers -> render -> verify. Returns (path, secs, peak)."""
    reset()
    master_clipper()
    layers_fn()
    result = render(name, length, tail, subdir)
    print(f"  {name}: {result[1]}s peak {result[2]}")
    return result

