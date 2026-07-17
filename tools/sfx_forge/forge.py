"""SFX forge: drive REAPER through the reaper-mcp file bridge.

Workflow per sound: reset() -> track() -> fx() -> notes / envelopes -> render().
Values for VST params are normalized 0..1; JS params use their real slider
range (use pmap()/get_param to inspect min/max).
"""
import json
import time
import wave
from pathlib import Path

BRIDGE = Path.home() / "AppData/Roaming/REAPER/Scripts/mcp_bridge_data"
OUT_DIR = Path(r"E:\Projects\extraction-survivors\assets\audio\_incoming\reaper_sfx")

_counter = 100


class BridgeError(RuntimeError):
    pass


def call(func, args, timeout=30.0, retries=2):
    global _counter
    last_err = None
    for attempt in range(retries + 1):
        _counter = (_counter % 500) + 101  # cycle 101..600, away from server range
        req = BRIDGE / f"request_{_counter}.json"
        resp = BRIDGE / f"response_{_counter}.json"
        resp.unlink(missing_ok=True)
        req.write_text(json.dumps({"func": func, "args": args}))
        deadline = time.time() + timeout
        while time.time() < deadline:
            if resp.exists():
                text = resp.read_text()
                if text.strip():
                    data = json.loads(text)
                    req.unlink(missing_ok=True)
                    resp.unlink(missing_ok=True)
                    if not data.get("ok", False):
                        raise BridgeError(f"{func}{args}: {data}")
                    return data
            time.sleep(0.03)
        req.unlink(missing_ok=True)
        last_err = f"{func}: timeout (attempt {attempt + 1}/{retries + 1})"
        time.sleep(1.0)
    raise BridgeError(last_err)


# â”€â”€ project state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def track_count():
    return call("CountTracks", [])["ret"]


def reset():
    """Delete every track; stop playback first so nothing holds pointers."""
    call("Stop", [])
    for i in range(track_count() - 1, -1, -1):
        call("DeleteTrack", [i])


def track(name, volume_db=0.0):
    idx = track_count()
    call("InsertTrackAtIndex", [idx, True])
    call("SetTrackName", [idx, name])
    if volume_db != 0.0:
        call("SetTrackVolume", [idx, volume_db])
    return idx


# â”€â”€ FX â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def fx(tr, name):
    r = call("TrackFX_AddByName", [tr, name, False, -1])
    if r["ret"] < 0:
        raise BridgeError(f"FX not found: {name}")
    return r["ret"]


def pmap(tr, fxi):
    """{param_name: (index, value, min, max)}"""
    n = call("TrackFX_GetNumParams", [tr, fxi])["ret"]
    out = {}
    for p in range(n):
        nm = call("TrackFX_GetParamName", [tr, fxi, p, 256])["ret"]
        g = call("TrackFX_GetParam", [tr, fxi, p])
        out[nm] = (p, g.get("value"), g.get("min"), g.get("max"))
    return out


def setp(tr, fxi, param, value):
    call("TrackFX_SetParam", [tr, fxi, param, value])


def fx_env(tr, fxi, param, points):
    """points: [(time, value, shape)] â€” value in the param's raw range."""
    call("GetFXEnvelope", [tr, fxi, param])
    for t, v, *rest in points:
        shape = rest[0] if rest else 0
        call("AddFXEnvelopePoint", [tr, fxi, param, t, v, shape])


# â”€â”€ MIDI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def midi(tr, start, length):
    return call("CreateMIDIItem", [tr, start, start + length])["item_index"]


def note(tr, item, pitch, start, length, vel=100, chan=0):
    call("InsertMIDINote", [tr, item, pitch, start, length, vel, chan])


def notes(tr, item, seq):
    """seq: [(pitch, start, length, vel)]"""
    for p, s, ln, v in seq:
        note(tr, item, p, s, ln, v)


# â”€â”€ render + verify â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def render(name, end_time, tail=0.5, subdir=""):
    out = OUT_DIR / subdir / f"{name}.wav" if subdir else OUT_DIR / f"{name}.wav"
    out.parent.mkdir(parents=True, exist_ok=True)
    call("RenderProject", [str(out), 0.0, end_time, tail, True], timeout=60)
    # rendering is async-ish; wait for the file to exist and stop growing
    deadline = time.time() + 30
    last = -1
    while time.time() < deadline:
        if out.exists():
            sz = out.stat().st_size
            if sz == last and sz > 0:
                break
            last = sz
        time.sleep(0.25)
    else:
        raise BridgeError(f"render never settled: {out}")
    return verify(out)


def read_wav(path):
    """Return (mono float64 array in -1..1, sample_rate). Handles 16/24/32-bit PCM."""
    import numpy as np
    with wave.open(str(path), "rb") as w:
        nch, sw, sr, nf = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(nf)
    if sw == 2:
        data = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0
    elif sw == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3)
        data = (
            (b[:, 0].astype(np.int32))
            | (b[:, 1].astype(np.int32) << 8)
            | (b[:, 2].astype(np.int32) << 16)
        )
        data = np.where(data >= 1 << 23, data - (1 << 24), data).astype(np.float64) / (1 << 23)
    elif sw == 4:
        data = np.frombuffer(raw, dtype=np.int32).astype(np.float64) / (1 << 31)
    else:
        raise BridgeError(f"unhandled sample width {sw}")
    if nch > 1:
        data = data.reshape(-1, nch).mean(axis=1)
    return data, sr


def verify(path):
    """Return (path, seconds, peak 0..1); raise if silent or empty."""
    data, sr = read_wav(path)
    secs = len(data) / sr
    import numpy as np
    peak = float(np.abs(data).max()) if len(data) else 0.0
    if secs < 0.05:
        raise BridgeError(f"{path.name}: too short ({secs:.3f}s)")
    if peak < 0.01:
        raise BridgeError(f"{path.name}: silent (peak {peak:.4f})")
    return path, round(secs, 3), round(peak, 3)

