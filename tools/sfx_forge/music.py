"""Chill lofi DnB gameplay track â€” 172 BPM half-time, D minor, 32 bars, loopable.

Structure: A (sparse) / A' (+melody) / B (sustained pads, breathing) / A'' (+answer).
All synthesis: ReaSynth voices + gated noise snare + pink-noise vinyl bed.
"""
import sys

sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent))
from sfx_lib import *
from forge import call

BPM = 172.0
B = 60.0 / BPM              # one beat in seconds
BAR = 4 * B
BARS = 32
SONG = BARS * BAR           # ~44.65 s
ILEN = SONG + 0.5

# chord roots per 2-bar block, cycling D | Bb | F | C (i VI III VII in D minor)
ROOTS = [50, 46, 53, 48]     # D3 Bb2 F3 C3
BASS_ROOTS = [38, 34, 41, 36]  # D2 Bb1 F2 C2
CHORDS = {  # root midi -> voicing (Dm9, Bbmaj7, Fmaj7, Cadd9)
    50: [50, 53, 60, 64], 46: [46, 50, 53, 57],
    53: [53, 57, 60, 64], 48: [48, 52, 55, 62],
}


def beats(bar, beat):
    return bar * BAR + beat * B


def section(bar):
    return ("A", "A2", "B", "A3")[bar // 8]


def build_song():
    call("SetTempo", [BPM])

    # â”€â”€ kick: sine body + click transient â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    kicks = []
    for bar in range(BARS):
        kicks.append((beats(bar, 0.0), 112))
        kicks.append((beats(bar, 2.5), 96))
        if section(bar) != "B" and bar % 2 == 1:
            kicks.append((beats(bar, 1.75), 78))   # syncopated ghost
    seq_body = [(33, t, 0.13, v) for t, v in kicks]              # A1 ~55 Hz
    seq_click = [(86, t, 0.018, max(40, v - 45)) for t, v in kicks]
    synth_layer("kick_body", seq_body, attack=0.001, decay=0.13, sustain=0.0,
                release=0.05, vol=0.5, item_len=ILEN, chain=[sat(25.0)])
    synth_layer("kick_click", seq_click, attack=0.001, decay=0.02, sustain=0.0,
                release=0.01, square=0.4, vol=0.35, item_len=ILEN, chain=[lowpass(0.4)])

    # â”€â”€ snare: gated white noise + tone body, backbeat on 3 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    snares = []
    for bar in range(BARS):
        snares.append((beats(bar, 2.0), 1.0))
        if section(bar) in ("A2", "A3") and bar % 2 == 0:
            snares.append((beats(bar, 3.75), 0.4))  # ghost
    gate = []
    for t, amp in snares:
        gate += gate_decay(t, 0.11, amp * 0.9, attack=0.002)
    noise_layer("snare_noise", white=True, gate_pts=gate, noise_db=10.0, vol_db=1.0,
                chain=[lowpass(0.75, hp=0.12), verb(0.25, 0.15)])
    seq_sn = [(43, t, 0.06, int(70 * a + 30)) for t, a in snares]  # G2 body
    synth_layer("snare_body", seq_sn, attack=0.001, decay=0.07, sustain=0.0,
                release=0.03, tri=0.4, vol=0.4, item_len=ILEN, chain=[lowpass(0.5)])

    # â”€â”€ hats: high square ticks, swung 8ths, chip-lofi flavor â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    hat_seq = []
    for bar in range(BARS):
        dense = section(bar) in ("A2", "A3")
        for e in range(8):
            beat = e / 2.0
            if not dense and e % 2 == 1 and e not in (3, 7):
                continue
            t = beats(bar, beat) + (0.021 if e % 2 == 1 else 0.0)  # swing
            vel = 58 if e % 2 == 0 else 38
            if e == 0:
                vel = 66
            ln = 0.09 if (e == 7 and bar % 2 == 1) else 0.022      # open hat
            hat_seq.append((108, t, ln, vel))
    synth_layer("hats", hat_seq, attack=0.001, decay=0.03, sustain=0.0,
                release=0.012, square=0.55, vol=0.34, item_len=ILEN,
                chain=[highpass(0.55), verb(0.15, 0.08)])

    # â”€â”€ bass: dubby dotted pattern following the progression â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    bass_seq = []
    for bar in range(0, BARS, 2):
        root = BASS_ROOTS[(bar // 2) % 4]
        v = 96
        bass_seq += [
            (root, beats(bar, 0.0), 1.4 * B, v),
            (root, beats(bar, 2.5), 0.9 * B, v - 14),
            (root, beats(bar + 1, 0.5), 1.2 * B, v - 8),
        ]
        if section(bar) == "B":
            bass_seq.append((root + 12, beats(bar + 1, 2.5), 0.7 * B, v - 20))
        else:
            bass_seq.append((root, beats(bar + 1, 2.75), 0.6 * B, v - 18))
    synth_layer("bass", bass_seq, attack=0.008, decay=0.25, sustain=0.55,
                release=0.12, tri=0.3, vol=0.5, item_len=ILEN,
                chain=[lowpass(0.36), sat(22.0)])

    # â”€â”€ chords: dusty Rhodes-ish stabs / sustained pads in B â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    chord_seq = []
    for bar in range(BARS):
        root = ROOTS[(bar // 2) % 4]
        voicing = CHORDS[root]
        sec = section(bar)
        if sec == "B":
            if bar % 2 == 0:  # whole-note pad every 2 bars
                for j, n in enumerate(voicing):
                    chord_seq.append((n, beats(bar, 0.0) + j * 0.012, 2 * BAR * 0.95, 62))
        elif bar >= 4 or sec != "A":
            for j, n in enumerate(voicing):
                chord_seq.append((n, beats(bar, 1.5) + j * 0.010, 1.1 * B, 58))
            if bar % 2 == 1:
                for j, n in enumerate(voicing):
                    chord_seq.append((n, beats(bar, 3.5) + j * 0.010, 0.9 * B, 48))
    synth_layer("chords", chord_seq, attack=0.018, decay=0.5, sustain=0.35,
                release=0.3, tri=0.5, xsine=0.15, vol=0.55, item_len=ILEN,
                chain=[lowpass(0.42), chorus(22.0, 3.0, 0.7, -8.0, -4.0), verb(0.45, 0.3)])

    # â”€â”€ melody: sparse D-minor-pentatonic call/answer (A2/A3 only) â”€â”€â”€â”€â”€
    call_phrase = [(0.0, 74, 0.75, 66), (1.5, 77, 0.5, 58), (2.5, 81, 1.25, 68),
                   (4.0 + 0.5, 79, 0.75, 60), (4.0 + 2.0, 77, 0.5, 54), (4.0 + 2.75, 74, 1.0, 62)]
    answer_phrase = [(0.0, 81, 0.75, 64), (1.5, 84, 0.5, 60), (2.5, 79, 1.5, 66),
                     (4.0 + 1.5, 77, 0.75, 58), (4.0 + 2.5, 74, 1.25, 60)]
    mel_seq = []
    for start_bar, phrase in ((8, call_phrase), (12, call_phrase), (24, answer_phrase),
                              (28, answer_phrase)):
        for beat, n, ln, v in phrase:
            mel_seq.append((n, beats(start_bar, beat), ln * B, v))
    synth_layer("melody", mel_seq, attack=0.01, decay=0.4, sustain=0.25,
                release=0.2, xsine=0.25, vol=0.55, item_len=ILEN,
                chain=[lowpass(0.5), echo(0.75 * B, 0.35, 0.3, lp=0.5), verb(0.4, 0.3)])

    # â”€â”€ vinyl bed: soft pink hiss + sparse crackle ticks â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    crackle = [(0.0, 0.045, 0)]
    tick_times = [1.7, 4.3, 7.1, 9.9, 12.6, 15.2, 17.8, 20.5, 23.1, 25.9,
                  28.4, 30.7, 33.3, 36.1, 38.8, 41.4, 43.6]
    for t in tick_times:
        crackle += [(t, 0.045, 0), (t + 0.004, 0.30, 0), (t + 0.012, 0.045, 0)]
    crackle.append((SONG, 0.045, 0))
    noise_layer("vinyl", white=False, gate_pts=crackle, noise_db=-8.0, vol_db=-6.0,
                chain=[lowpass(0.35)])


if __name__ == "__main__":
    print(f"song length: {SONG:.2f}s ({BARS} bars at {BPM:.0f} BPM)")
    build("gameplay_dnb_lofi", build_song, SONG, tail=0.0, subdir="music")


