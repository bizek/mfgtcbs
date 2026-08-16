"""Bone Barrage / Bramble Barrage channel bed - a dry rattle/whisper.

Kits: wizard, necromancer (Bone Barrage), druid (Bramble Barrage), cleric. SONG=2.0s
(music_lib loop rule). Deliberately DRY - no reverb send on either layer - because
"dry rattle" is the brief and a wet arcane bed would read as the same family as the
roar/rumble beds instead of its own texture. No sustained tone either: arcane here
means rattling/whispering, not droning.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sfx_lib import *  # noqa: F401,F403,E402
from music_lib import gain  # noqa: E402

SONG = 2.0

# 8 dry ticks per loop, deliberately uneven spacing so the rattle doesn't read
# as a metronome.
RATTLE_TIMES = [0.05, 0.28, 0.55, 0.80, 1.05, 1.30, 1.58, 1.82]


def both(times):
    return list(times) + [t + SONG for t in times]


def flat_gate(level, song):
    return [(0.0, level, 0), (2.0 * song, level, 0)]


def build_song():
    # base airy whisper: bright filtered hiss, ring-modulated for a raspy edge
    noise_layer("whisper_body", white=True, gate_pts=flat_gate(0.35, SONG),
                noise_db=1.0, vol_db=gain(-9.0),
                chain=[ringmod(41.0, 22.0, 8.0), highpass(0.30, lp=0.72)])
    # dry rattle ticks: short bright bursts, no reverb send - keeps it dry
    gate = []
    for i, t in enumerate(both(RATTLE_TIMES)):
        dur = 0.018 + 0.01 * (i % 3)
        gate += gate_decay(t, dur, 0.75, attack=0.002, n=4)
    noise_layer("rattle", white=True, gate_pts=gate, noise_db=4.0, vol_db=gain(-6.0),
                chain=[highpass(0.45)])


if __name__ == "__main__":
    print(f"channel_loop_arcane: {SONG:.1f}s loop, {len(RATTLE_TIMES)} rattle ticks/loop")
