"""Taunt / Dictum / Reckoning dome channel bed - a low physical rumble.

Kits: fighter (Taunt), paladin (Dictum, the Reckoning dome), barbarian, ninja,
gunslinger, ranger. SONG=2.0s (music_lib loop rule). Physical, not elemental: no
crackle, no whisper, just a filtered noise rumble under a low sub tone, plus two
low thuds per loop for a marching/pulse feel that reads as effort rather than
magic.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sfx_lib import *  # noqa: F401,F403,E402
from music_lib import drone_hz, gain, wobble  # noqa: E402

SONG = 2.0
ROOT_HZ = drone_hz(37, SONG)

THUD_TIMES = [0.4, 1.4]  # even 1s pulse, offset off the loop seam on purpose -
                          # a thud attack landing exactly at t=0 collides with the
                          # wrap point and reads as a click, not a hit


def both(times):
    return list(times) + [t + SONG for t in times]


def flat_gate(level, song):
    return [(0.0, level, 0), (2.0 * song, level, 0)]


def build_song():
    # filtered noise rumble bed
    noise_layer("rumble_body", white=False, gate_pts=flat_gate(0.75, SONG),
                noise_db=5.0, vol_db=gain(-4.0),
                chain=[lowpass(0.18), sat(30.0)])
    # sub tone, one slow swell per loop
    tone_layer("rumble_sub", shape=0,
                freq_pts=[(0.0, ROOT_HZ, 0), (2.0 * SONG, ROOT_HZ, 0)],
                amp_pts=wobble(-14.0, 1.0, 1, SONG), vol_db=gain(-1.0),
                chain=[lowpass(0.14)])
    # low physical thuds: two per loop, pitch-drop percussive hits
    thud_events = []
    for t in both(THUD_TIMES):
        thud_events.append(((t, 95.0, 0), (t + 0.12, 55.0, 0)))
    thud_f = sorted((p for pair in thud_events for p in pair), key=lambda p: p[0])
    thud_a = []
    for t in both(THUD_TIMES):
        thud_a += decay_db(t, 0.16, -6.0, attack=0.006, drop=40.0)
    thud_a.sort(key=lambda p: p[0])
    tone_layer("thud", shape=0, freq_pts=thud_f, amp_pts=thud_a, vol_db=gain(0.0),
                chain=[lowpass(0.30), sat(20.0)])


if __name__ == "__main__":
    print(f"channel_loop_martial: {SONG:.1f}s loop, root {ROOT_HZ:.0f} Hz "
          f"({ROOT_HZ * SONG:.0f} whole cycles/loop), {len(THUD_TIMES)} thuds/loop")
