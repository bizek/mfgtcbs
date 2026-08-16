"""The Catacombs (biome 2) - disciplined dread. 60 BPM, A Phrygian, 24 bars, 96 s loop.

IDENTITY: an ordered undead legion. It has a PULSE - a processional footfall on
beats 1 and 3 - because the horde here is ranked and drilled, not chaotic. At
60 BPM one beat is exactly one second, so the march lands on a slow human pulse.
The harmony is open fifths only (no thirds anywhere), which reads as ancient and
hollow rather than sad, and the mode is Phrygian, so the flat-2 (Bb) supplies the
dread without a sustained dissonance that would fatigue over a 20 minute run.

FORM: A (b0-7) | B (b8-15) | A' (b16-23), returning home to A for the loop.
      block roots   A  F  | Bb  A | G  A
      The B section holds the only melodic line in the track - a descending
      Phrygian figure through the flat-2. Everything else is texture, so there is
      no hook to wear out.

TUNING: centred on A because A is near-exact in whole Hz (A1 55.000, A2 110.000,
E3 165 is +2 cents). music_lib requires whole-Hz drones over a whole-second loop -
that is what makes the loop seam phase-continuous. See music_lib's docstring.

MIX: nothing above ~1.5 kHz except the bell's upper partials. The combat SFX bed
     (swings, hits, the combo pitch ladder) owns 2-6 kHz; this track stays out of it.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sfx_lib import *  # noqa: F403,E402
from music_lib import drone_hz, flat, gain, twice, wobble  # noqa: E402

BPM = 60.0
B = 60.0 / BPM                 # 1.0 s - one beat, one second
BAR = 4 * B                    # 4.0 s
BARS = 24
SONG = BARS * BAR              # 96.0 s exactly (whole seconds: required)
ILEN = 2 * SONG + 4.0          # MIDI item must cover both rendered periods

# every layer is trimmed by this. Set so the master soft clipper never engages -
# a clipped render collapses the crest factor and the track becomes a wall.
TRIM = -15.0

# ── harmony: 6 blocks of 4 bars, open fifths in A Phrygian (A Bb C D E F G) ────
#              block:  0   1   2   3   4   5
#              root:   A   F   Bb  A   G   A
BLOCK_ROOT = [45, 41, 46, 45, 43, 45]           # A2 F2 Bb2 A2 G2 A2
BLOCK_CHOIR = {                                 # root, fifth, octave - no thirds
    45: [45, 52, 57],    # A2  E3  A3
    41: [41, 48, 53],    # F2  C3  F3
    46: [46, 53, 58],    # Bb2 F3  Bb3
    43: [43, 50, 55],    # G2  D3  G3
}

DRONE_HZ = drone_hz(55, SONG)     # A1
OCTAVE_HZ = drone_hz(110, SONG)   # A2
FIFTH_HZ = drone_hz(165, SONG)    # E3 (+2 cents - inaudible, and a whole Hz)


def beats(bar, beat):
    return bar * BAR + beat * B


def build_song():
    # ── 1. crypt drone: the stone itself. Flat, phase-locked, never stops ───────
    # A1 is kept deliberately LOW. It is the floor, not the voice: a 55 Hz sine is
    # inaudible on laptop speakers but eats headroom, so the audible bed is the
    # octave and fifth above it (110/165 Hz, where caves.ogg also lives).
    tone_layer("crypt_drone", shape=0,
               freq_pts=[(0.0, DRONE_HZ, 0), (ILEN, DRONE_HZ, 0)],
               amp_pts=flat(-16.0, SONG), vol_db=gain(TRIM - 10.0),
               chain=[lowpass(0.22), verb(0.75, 0.20, damp=0.7)])

    # octave and fifth, breathing on co-prime cycle counts (3 and 4 per loop) so
    # the pair never lines up twice the same way inside one pass
    tone_layer("drone_octave", shape=0,
               freq_pts=[(0.0, OCTAVE_HZ, 0), (ILEN, OCTAVE_HZ, 0)],
               amp_pts=wobble(-9.0, 3.0, 3, SONG), vol_db=gain(TRIM - 1.0),
               chain=[lowpass(0.34), verb(0.8, 0.28, damp=0.6)])
    tone_layer("drone_fifth", shape=0,
               freq_pts=[(0.0, FIFTH_HZ, 0), (ILEN, FIFTH_HZ, 0)],
               amp_pts=wobble(-13.0, 3.5, 4, SONG, phase=0.3), vol_db=gain(TRIM - 2.0),
               chain=[lowpass(0.45), verb(0.85, 0.34, damp=0.55)])

    # ── 2. footfall: the march. Beats 1 and 3, dead on the grid - they are drilled ─
    # A2 rather than A1: a boot on stone, not a sub thump. Keeps the pulse audible
    # on small speakers, which is what makes this biome recognisable blind.
    foot = []
    for bar in range(BARS):
        foot.append((45, beats(bar, 0.0), 0.30, 100))   # A2 - left, the strong foot
        foot.append((45, beats(bar, 2.0), 0.30, 82))    # right, lighter
    synth_layer("footfall", twice(foot, SONG), attack=0.002, decay=0.26, sustain=0.0,
                release=0.09, tri=0.25, vol=0.85, item_len=ILEN, vol_db=gain(TRIM),
                chain=[lowpass(0.45), sat(15.0), verb(0.5, 0.15, damp=0.75)])

    # ── 3. rank shuffle: many feet landing a hair behind the beat. Loose on purpose ─
    gate = []
    for bar in range(BARS):
        for t0 in (beats(bar, 0.0) + 0.045, beats(bar, 2.0) + 0.06):
            for tt in (t0, t0 + SONG):
                gate += gate_swell(tt, 0.34, 0.5, rise=0.25, n=3)
    noise_layer("rank_shuffle", white=False, gate_pts=gate, noise_db=-4.0,
                vol_db=gain(TRIM - 12.0),
                chain=[lowpass(0.45, hp=0.05), verb(0.45, 0.2)])

    # ── 4. hollow choir: one open-fifth chord per 4-bar block, distant ─────────
    # decay/release are at ReaSynth's 1.0 s ceiling (see music_lib) - the long tail
    # comes from sustain holding the note plus the reverb, not from the envelope.
    choir, choir_low = [], []
    for blk in range(6):
        root = BLOCK_ROOT[blk]
        t0 = beats(blk * 4, 0.0)
        ln = 4 * BAR - 0.25
        for j, n in enumerate(BLOCK_CHOIR[root]):
            choir.append((n, t0 + j * 0.05, ln, 56))
        if blk >= 4:                                    # A' swells: the legion doubles
            choir_low.append((root - 12, t0 + 0.1, ln, 48))
    synth_layer("hollow_choir", twice(choir, SONG), attack=1.30, decay=0.9, sustain=0.75,
                release=1.0, tri=0.5, xsine=0.18, vol=1.05, item_len=ILEN,
                vol_db=gain(TRIM + 2.0),
                chain=[lowpass(0.60), chorus(26.0, 3.0, 0.35, -10.0, -3.0),
                       verb(0.85, 0.40, damp=0.55)])
    synth_layer("choir_low", twice(choir_low, SONG), attack=1.6, decay=0.9, sustain=0.7,
                release=1.0, tri=0.4, vol=0.75, item_len=ILEN, vol_db=gain(TRIM - 2.0),
                chain=[lowpass(0.40), verb(0.8, 0.32)])

    # ── 5. pedal: block root at A2, re-struck once per block ───────────────────
    pedal = []
    for blk in range(6):
        pedal.append((BLOCK_ROOT[blk], beats(blk * 4, 0.0), 4 * BAR - 0.4, 70))
        pedal.append((BLOCK_ROOT[blk] + 7, beats(blk * 4, 2.0), 3.4 * BAR, 52))
    synth_layer("pedal", twice(pedal, SONG), attack=0.9, decay=0.9, sustain=0.7,
                release=1.0, tri=0.35, vol=0.80, item_len=ILEN, vol_db=gain(TRIM - 1.0),
                chain=[lowpass(0.40), sat(10.0)])

    # ── 6. crypt bell: marks the form - one toll per 8-bar section (3 per loop) ─
    bell, bell_part = [], []
    for bar in (0, 8, 16):
        bell.append((57, beats(bar, 0.0), 5.5, 72))                # A3
        bell_part.append((76, beats(bar, 0.0) + 0.012, 2.2, 38))   # inharmonic ring
    synth_layer("crypt_bell", twice(bell, SONG), attack=0.004, decay=1.0, sustain=0.10,
                release=1.0, xsine=0.30, tri=0.2, vol=1.00, item_len=ILEN,
                vol_db=gain(TRIM + 3.0),
                chain=[lowpass(0.80), verb(0.9, 0.55, damp=0.5)])
    synth_layer("bell_partial", twice(bell_part, SONG), attack=0.003, decay=0.9,
                sustain=0.0, release=1.0, xsine=0.5, vol=0.50, item_len=ILEN,
                vol_db=gain(TRIM - 3.0),
                chain=[lowpass(0.80), verb(0.9, 0.52, damp=0.45)])

    # ── 7. descent motif: B section only. The one melodic idea in the track ────
    # Sits an octave above the choir (220-440 Hz) so it reads as a line rather
    # than disappearing into the pad.
    motif = [
        (65, beats(9, 0.0), 2.6, 60),    # F4
        (64, beats(10, 2.0), 2.2, 54),   # E4
        (60, beats(12, 0.0), 2.6, 56),   # C4
        (58, beats(13, 2.0), 2.4, 50),   # Bb3  <- the Phrygian flat-2, the dread note
        (57, beats(14, 0.0), 4.0, 58),   # A3
    ]
    synth_layer("descent_motif", twice(motif, SONG), attack=0.35, decay=1.0, sustain=0.30,
                release=1.0, xsine=0.35, tri=0.25, vol=0.90, item_len=ILEN,
                vol_db=gain(TRIM + 1.0),
                chain=[lowpass(0.70), echo(2 * B, 0.30, 0.24, lp=0.45),
                       verb(0.9, 0.46, damp=0.5)])


if __name__ == "__main__":
    print(f"catacombs: {BARS} bars @ {BPM:.0f} BPM = {SONG:.1f}s loop")
    for n, hz in (("drone", DRONE_HZ), ("octave", OCTAVE_HZ), ("fifth", FIFTH_HZ)):
        print(f"  {n:7} {hz:6.1f} Hz -> {hz * SONG:.0f} whole cycles per loop")
