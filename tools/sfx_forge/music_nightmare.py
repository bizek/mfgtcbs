"""The Nightmare Realm (biome 3) - wrongness, not menace. 114 s loop, no pulse.

IDENTITY: the wave composition here is deliberately motley ("nothing here belongs
together" - level_data.gd). So this track has NO beat and no bar grid you can feel.
Nothing lands where you expect it, because there is nothing to expect. What holds
it together is a single low drone, and the drone is itself unstable: a 113 Hz tone
sits 47 cents above the 110 Hz bed and beats against it, while every layer's level
drifts on a different co-prime cycle count (4, 5, 7, 11 and 13 per loop) so the
composite never lines up the same way twice inside a pass.

The "beautiful in places" brief is carried by the bells: a soft, consonant A-minor
figure with a long shimmer, genuinely pretty - except it keeps arriving at times
that make no sense, and three times a loop it lands on Eb, the tritone against the
drone. Lovely and wrong at once, which is the biome.

WHY IT DOES NOT FATIGUE: the dissonance is intermittent, never sustained. The
tritone bell appears 3 times in 114 s and the tritone drone spends most of the loop
faded to nothing. Everything else is consonant with the root, so twenty minutes of
it reads as atmosphere rather than as an alarm.

WHY THE BEAT RATE IS 3 Hz AND NOT 1: drone frequencies must be whole Hz for the
loop seam to stay phase-continuous (see music_lib), so a detuned pair beats at a
whole number of Hz. The first build used 55/56, and its 1 Hz beat measured as the
most metronomic thing in either biome track (onset autocorrelation 0.93 at exactly
1.00 s) - a 60 BPM pulse, in the one biome that must not have one. Moving the pair
up to 110/113 puts the beat at 3 Hz, above the rate the ear hears as rhythm, so it
reads as roughness. There is no transient anywhere in the drone bed to entrain to.

MIX: bells peak around 1.5 kHz, everything else sits below 900 Hz. The 2-6 kHz
     combat band is left empty.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sfx_lib import *  # noqa: F403,E402
from music_lib import drone_hz, gain, wobble  # noqa: E402

SONG = 114.0          # whole seconds: required for phase-continuous drones
ILEN = 2 * SONG + 4.0
TEMPO = 40.0          # editor grid only - nothing in the track is on it
TRIM = -15.0

ROOT_HZ = drone_hz(55, SONG)       # A1 - the floor, kept low
OCT_HZ = drone_hz(110, SONG)       # A2 - the audible bed
DETUNE_HZ = drone_hz(113, SONG)    # +47 cents over A2 -> 3 Hz beat. See below.
SUB_HZ = drone_hz(28, SONG)        # sub floor, barely there
WRONG_HZ = drone_hz(78, SONG)      # ~tritone over A1. Mostly faded out.

# bells: A minor pentatonic (A C D E G) + Eb, the tritone, three times a loop
TRITONE = 75
BELL_TIMES = [4.2, 11.8, 17.3, 26.9, 33.1, 44.6, 52.0,
              61.4, 70.2, 79.9, 88.3, 97.1, 105.8]
BELL_PITCH = [69, 76, 72, 74, TRITONE, 79, 69,
              72, TRITONE, 76, 74, TRITONE, 72]
# every time below is hand-placed off any grid, and the gaps never repeat
WHISPER_TIMES = [2.1, 9.7, 15.2, 23.8, 31.5, 39.0, 47.7,
                 56.3, 64.8, 73.5, 82.9, 91.6, 100.4, 109.2]
THUD_TIMES = [7.3, 19.1, 34.7, 51.2, 68.9, 88.4, 103.1]


def both(times):
    """Event times in both rendered periods."""
    return list(times) + [t + SONG for t in times]


def build_song():
    # ── 1. the unstable drone bed ──────────────────────────────────────────────
    # co-prime wobble cycles (4/5/7/11/13) so no two layers share a period.
    #
    # The detuned pair is 110/113 Hz, NOT 55/56. A 55/56 pair beats at 1 Hz, and
    # measured against an onset-envelope autocorrelation that came out as the most
    # metronomic thing in either track (strength 0.93) - a 60 BPM pulse, which is
    # precisely what this biome must not have. 3 Hz is above the rate the ear reads
    # as rhythm, so 110/113 lands as roughness and wrongness instead of a beat.
    for name, hz, amp, lp, vol in (
            ("abyss_root", ROOT_HZ, wobble(-17.0, 2.0, 4, SONG), 0.24, TRIM - 9.0),
            ("abyss_oct", OCT_HZ, wobble(-10.0, 3.0, 11, SONG, 0.5), 0.34, TRIM - 1.0),
            ("abyss_detune", DETUNE_HZ, wobble(-15.0, 7.0, 7, SONG, 0.2), 0.34, TRIM - 4.0),
            ("abyss_wrong", WRONG_HZ, wobble(-22.0, 10.0, 5, SONG, 0.7), 0.30, TRIM - 8.0)):
        tone_layer(name, shape=0,
                   freq_pts=[(0.0, hz, 0), (ILEN, hz, 0)],
                   amp_pts=amp, vol_db=gain(vol),
                   chain=[lowpass(lp), verb(0.85, 0.26, damp=0.65)])
    tone_layer("abyss_sub", shape=0,
               freq_pts=[(0.0, SUB_HZ, 0), (ILEN, SUB_HZ, 0)],
               amp_pts=wobble(-22.0, 2.0, 13, SONG, 0.9), vol_db=gain(TRIM - 14.0),
               chain=[lowpass(0.14)])

    # ── 2. drift tone: wanders and never lands. Silent across the seam ─────────
    # Its glide is not phase-lockable, so it fades to nothing before each period
    # boundary - the one layer allowed to be non-periodic, made inaudible there.
    drift_f, drift_a = [], []
    for p in range(2):
        base = p * SONG
        for f, hz in ((0.0, 220.0), (0.17, 227.0), (0.33, 214.0), (0.50, 231.0),
                      (0.66, 219.0), (0.82, 224.0), (1.0, 220.0)):
            drift_f.append((base + f * SONG, hz, 0))
        drift_a += [(base + 0.0, -120.0, 0), (base + 7.0, -18.0, 0),
                    (base + 0.30 * SONG, -13.0, 0), (base + 0.52 * SONG, -22.0, 0),
                    (base + 0.74 * SONG, -14.0, 0), (base + SONG - 7.0, -120.0, 0)]
    tone_layer("drift_tone", shape=0, freq_pts=drift_f, amp_pts=drift_a,
               vol_db=gain(TRIM - 4.0),
               chain=[lowpass(0.60), chorus(30.0, 3.0, 0.22, -8.0, -6.0),
                      verb(0.9, 0.42, damp=0.5)])

    # ── 3. wrong bells: pretty, consonant, arriving at senseless times ─────────
    bells, shimmer = [], []
    for p in range(2):
        for t, pitch in zip(BELL_TIMES, BELL_PITCH):
            tt = t + p * SONG
            vel = 48 if pitch == TRITONE else 60
            bells.append((pitch, tt, 3.4, vel))
            shimmer.append((pitch + 12, tt + 0.03, 1.8, vel - 22))
    synth_layer("wrong_bells", bells, attack=0.006, decay=1.0, sustain=0.10,
                release=1.0, xsine=0.42, tri=0.18, vol=1.00, item_len=ILEN,
                vol_db=gain(TRIM + 3.0),
                chain=[lowpass(0.78), echo(1.37, 0.34, 0.28, lp=0.4),
                       verb(0.95, 0.58, damp=0.4)])
    synth_layer("bell_shimmer", shimmer, attack=0.01, decay=0.9, sustain=0.0,
                release=1.0, xsine=0.55, vol=0.50, item_len=ILEN, vol_db=gain(TRIM - 3.0),
                chain=[lowpass(0.78), verb(0.95, 0.58, damp=0.35)])

    # ── 4. whisper swells: vermin / psychic texture, ring-modulated noise ──────
    gate = []
    for i, t in enumerate(both(WHISPER_TIMES)):
        dur = 2.2 + 0.7 * ((i * 7) % 5) / 4.0        # irregular lengths too
        gate += gate_swell(t, dur, 0.42, rise=0.55, n=5)
    noise_layer("whisper_swells", white=False, gate_pts=gate, noise_db=-2.0,
                vol_db=gain(TRIM - 13.0),
                chain=[ringmod(37.0, 45.0, 12.0), lowpass(0.50, hp=0.10),
                       verb(0.9, 0.42, damp=0.5)])

    # ── 5. psychic thread: thin, quiet, wandering. Under everything ────────────
    th_f, th_a = [], []
    for p in range(2):
        base = p * SONG
        for f, hz in ((0.0, 1180.0), (0.25, 1340.0), (0.5, 1220.0),
                      (0.75, 1410.0), (1.0, 1180.0)):
            th_f.append((base + f * SONG, hz, 0))
        th_a += [(base + 0.0, -120.0, 0), (base + 13.0, -34.0, 0),
                 (base + 0.40 * SONG, -28.0, 0), (base + 0.62 * SONG, -38.0, 0),
                 (base + 0.85 * SONG, -30.0, 0), (base + SONG - 11.0, -120.0, 0)]
    tone_layer("psychic_thread", shape=0, freq_pts=th_f, amp_pts=th_a,
               vol_db=gain(TRIM - 11.0),
               chain=[lowpass(0.55, hp=0.30), verb(0.95, 0.58, damp=0.3)])

    # ── 6. unstable thuds: low, ring-modulated, never twice the same distance ──
    thud = []
    for i, t in enumerate(both(THUD_TIMES)):
        thud.append((31 + (i % 3), t, 0.5, 76 - 6 * (i % 3)))
    synth_layer("unstable_thud", thud, attack=0.004, decay=0.45, sustain=0.0,
                release=0.5, tri=0.3, vol=0.80, item_len=ILEN, vol_db=gain(TRIM - 1.0),
                chain=[ringmod(23.0, 30.0, 22.0), lowpass(0.42),
                       verb(0.7, 0.28, damp=0.6)])


if __name__ == "__main__":
    print(f"nightmare realm: {SONG:.0f}s loop, no pulse")
    for n, hz in (("root", ROOT_HZ), ("oct", OCT_HZ), ("detune", DETUNE_HZ),
                  ("sub", SUB_HZ), ("wrong", WRONG_HZ)):
        print(f"  {n:6} {hz:6.1f} Hz -> {hz * SONG:.0f} whole cycles per loop")
    print(f"  oct/detune beat {abs(DETUNE_HZ - OCT_HZ):.2f} Hz (roughness, not rhythm)")
    print(f"  tritone bells: {sum(1 for p in BELL_PITCH if p == TRITONE)} per loop")
