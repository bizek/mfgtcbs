"""Immolate / Hellfire channel bed - a low roar under the fire kits' held ticks.

Kits: demonologist (Immolate), blood_mage. SONG=2.0s - see music_lib for the
whole-second/whole-Hz loop rule. The roar body is broadband filtered noise, which
carries no phase to keep continuous across the seam (a flat gate over the full
render is already periodic); only the sustained sub tone underneath it needs an
integer-Hz drone. Two soft crackle ticks per loop keep it from reading as a static
hiss - a channel is a HOLD, so the bed has to survive being listened to on loop for
several seconds without flattening into wallpaper.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sfx_lib import *  # noqa: F401,F403,E402
from music_lib import drone_hz, gain, wobble  # noqa: E402

SONG = 2.0
ROOT_HZ = drone_hz(41, SONG)  # low body tone under the roar

CRACKLE_TIMES = [0.35, 1.15]


def both(times):
    return list(times) + [t + SONG for t in times]


def flat_gate(level, song):
    return [(0.0, level, 0), (2.0 * song, level, 0)]


def build_song():
    # broadband roar body: heavy low-pass + saturation for a warm, filthy growl
    noise_layer("roar_body", white=False, gate_pts=flat_gate(0.85, SONG),
                noise_db=6.0, vol_db=gain(-3.0),
                chain=[lowpass(0.22), sat(40.0)])
    # thin bright layer riding just above, gives the roar some air/edge
    noise_layer("roar_hiss", white=True, gate_pts=flat_gate(0.30, SONG),
                noise_db=2.0, vol_db=gain(-14.0),
                chain=[highpass(0.35, lp=0.65)])
    # sub body tone, one slow swell per loop so the roar visibly breathes
    tone_layer("roar_sub", shape=0,
                freq_pts=[(0.0, ROOT_HZ, 0), (2.0 * SONG, ROOT_HZ, 0)],
                amp_pts=wobble(-16.0, 4.0, 1, SONG), vol_db=gain(-2.0),
                chain=[lowpass(0.16), sat(25.0)])
    # crackle ticks: two per loop, short bright bursts
    gate = []
    for t in both(CRACKLE_TIMES):
        gate += gate_decay(t, 0.05, 0.9, attack=0.004, n=6)
    noise_layer("crackle", white=True, gate_pts=gate, noise_db=5.0, vol_db=gain(-8.0),
                chain=[highpass(0.3)])


if __name__ == "__main__":
    print(f"channel_loop_fire: {SONG:.1f}s loop, root {ROOT_HZ:.0f} Hz "
          f"({ROOT_HZ * SONG:.0f} whole cycles/loop)")
