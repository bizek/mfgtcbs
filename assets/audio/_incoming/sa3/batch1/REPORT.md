# Stable Audio 3 Small-SFX takes

seeds [11, 12, 13] · 8 steps · loudness-matched within each sound

## combo_drop (oneshot)

| file | prompt | notes |
|---|---|---|
| `suno_s11.wav` | suno | 0.54s |
| `suno_s12.wav` | suno | 0.50s |
| `suno_s13.wav` | suno | 0.53s |
| `sa3_s11.wav` | sa3 | 0.80s |
| `sa3_s12.wav` | sa3 | 0.80s |
| `sa3_s13.wav` | sa3 | 0.80s |

Prompts:

- **suno**: `soft breathy exhale whoosh, gentle downward pitch fall, airy and calm, close and dry, 0.6 seconds, no impact, no music`
- **sa3**: `a single soft breathy exhale, gentle airy sigh falling in pitch, close dry recording`

## channel_loop_fire (loop)

| file | prompt | notes |
|---|---|---|
| `suno_s11.wav` | suno | seam ok (jump 0.02 flux 0.76 level 0.87); level swing 20.6 dB, cut at 2.15s |
| `suno_s12.wav` | suno | seam ok (jump 0.0 flux 0.52 level 0.93); level swing 33.4 dB, cut at 2.20s |
| `suno_s13.wav` | suno | seam ok (jump 0.14 flux 0.71 level 0.39); level swing 20.6 dB, cut at 1.15s |
| `sa3_s11.wav` | sa3 | seam ok (jump 0.12 flux 0.73 level 0.68); level swing 11.9 dB, cut at 2.00s |
| `sa3_s12.wav` | sa3 | seam ok (jump 0.0 flux 0.4 level 1.12); level swing 12.7 dB, cut at 2.70s |
| `sa3_s13.wav` | sa3 | seam ok (jump 0.03 flux 0.28 level 0.72); level swing 14.1 dB, cut at 2.55s |

Prompts:

- **suno**: `steady low roaring fire, furnace whoosh with soft crackle, constant intensity, seamless 2 second loop, no music, no melody, no drums`
- **sa3**: `steady low roaring furnace fire with soft crackling, constant intensity, close dry recording`

## channel_loop_arcane (loop)

| file | prompt | notes |
|---|---|---|
| `suno_s11.wav` | suno | seam ok (jump 0.04 flux 0.65 level 0.98); level swing 8.5 dB, cut at 1.19s |
| `suno_s12.wav` | suno | seam ok (jump 0.09 flux 0.63 level 1.32); level swing 25.6 dB, cut at 0.87s |
| `suno_s13.wav` | suno | seam ok (jump 0.09 flux 0.48 level 0.98); level swing 7.8 dB, cut at 1.96s |
| `sa3_s11.wav` | sa3 | seam ok (jump 0.23 flux 1.21 level 0.8); level swing 20.8 dB, cut at 0.73s |
| `sa3_s12.wav` | sa3 | seam ok (jump 0.09 flux 0.57 level 0.95); level swing 19.2 dB, cut at 0.70s |
| `sa3_s13.wav` | sa3 | seam ok (jump 0.06 flux 0.38 level 0.8); level swing 9.4 dB, cut at 2.59s |

Prompts:

- **suno**: `dry rattling bones and dark whispering hiss over a faint eerie hum, steady texture, seamless 2 second loop, no music, no melody, no drums`
- **sa3**: `dry rattling bones and a dark breathy hiss over a faint eerie low hum, steady dark magic texture`

## channel_loop_martial (loop)

| file | prompt | notes |
|---|---|---|
| `suno_s11.wav` | suno | seam ok (jump 0.22 flux 0.86 level 0.74); level swing 25.0 dB, cut at 3.16s |
| `suno_s12.wav` | suno | seam ok (jump 0.11 flux 0.59 level 0.45); level swing 46.1 dB, cut at 2.15s |
| `suno_s13.wav` | suno | seam ok (jump 0.07 flux 0.72 level 0.46); level swing 22.5 dB, cut at 2.64s |
| `sa3_s11.wav` | sa3 | SEAM SUSPECT (jump 0.0 flux 0.59 level 1.6); level swing 21.9 dB, cut at 2.09s |
| `sa3_s12.wav` | sa3 | seam ok (jump 0.04 flux 0.96 level 0.59); level swing 23.0 dB, cut at 2.78s |
| `sa3_s13.wav` | sa3 | seam ok (jump 0.01 flux 0.31 level 0.69); level swing 22.3 dB, cut at 3.28s |

Prompts:

- **suno**: `low steady ground rumble with faint chainmail and armor shuffle, tense and physical, seamless 2 second loop, no music, no melody, no drums`
- **sa3**: `low steady ground rumble with faint chainmail and metal armor shuffling, tense and heavy, close dry recording`

## What the spectrograms show (Claude: visual check only, I can't hear)

`<sound>.png` in this folder shows each sound's takes left to right: current in-game, suno s11/s12/s13, sa3 s11/s12/s13.

- **combo_drop**: none of the takes shows the downward pitch fall the current sound has. The `suno` takes are dark, steady breath noise (about 0.5 s). The `sa3` takes are brighter and carry tonal bands, which may be a *voiced* exhale ("haah"). They also ran the full 0.8 s cap, so the fade at the end is mine, not the model's.
- **channel_loop_fire**: the `sa3` takes look like the brief: steady broadband roar with sparse thin crackles (12–14 dB swing). The `suno`-prompt takes swell in bursts (20–33 dB swing), so they fail "level stays flat".
- **channel_loop_arcane**: the steadiest are `suno_s11`, `suno_s13` (~8 dB) and `sa3_s13` (~9 dB). `suno_s12` has two sharp clicks. `sa3_s12` drops out and comes back halfway, and `sa3_s11` has a strong tonal line with a gap.
- **channel_loop_martial**: every take pulses (22–46 dB swing). The `suno` ones have rhythmic dips, which may read as beats. All of them show a thin constant line near the top of the spectrum (high whine?). If you hear it, a 14 kHz low-pass at install removes it.

Every loop's seam measured clean except `channel_loop_martial/sa3_s11` (borderline). Listen to the `_x4` files, which play the loop four times.
