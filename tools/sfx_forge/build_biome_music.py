"""Build the biome music tracks: render, extract the loop, match loudness, encode.

  python build_biome_music.py [catacombs|nightmare_realm|all]

Renders two full periods per track and keeps the second (see music_lib for why),
matches integrated loudness to caves.ogg, writes OGG + a WAV proof into the
staging folder, and saves a REAPER project per track for Ben's feel pass.
Nothing is copied into assets/audio/music/ - install_biome_music.py does that.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import music_lib as ml  # noqa: E402

STAGE = Path(r"E:\Projects\extraction-survivors\assets\audio\_incoming\reaper_music")
REF = Path(r"E:\Projects\extraction-survivors\assets\audio\music\caves.ogg")

TRACKS = {}

# ordinary interior instants to compare the loop seam against - bar lines for the
# Catacombs (two of them land on its bell tolls), even spacing for the pulse-less
# Nightmare Realm.
PROBES = {
    "catacombs": (16.0, 32.0, 48.0, 64.0, 80.0),
    "nightmare_realm": (20.0, 45.0, 60.0, 75.0, 95.0),
}


def _load():
    import music_catacombs as cat
    import music_nightmare as nm
    TRACKS["catacombs"] = (cat.build_song, cat.SONG, cat.BPM)
    TRACKS["nightmare_realm"] = (nm.build_song, nm.SONG, nm.TEMPO)


def run(name, target, reuse=False):
    fn, song, tempo = TRACKS[name]
    print(f"\n=== {name} ===")
    raw = STAGE / f"{name}_raw.wav"
    if reuse and raw.exists():
        print(f"  reusing existing render {raw.name}")
    else:
        print(f"  loop {song:.4f}s, rendering 2 periods ({2 * song:.1f}s)")
        raw = ml.render_two_periods(name, fn, song, STAGE, tempo=tempo)
        ml.save_project(STAGE / f"{name}.rpp")
    ml.clip_report(raw)
    ml.periodicity_report(raw, song)
    return ml.finalize(name, raw, song, STAGE, target, STAGE, PROBES[name])


if __name__ == "__main__":
    _load()
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    reuse = "--reuse" in sys.argv
    which = args[0] if args else "all"
    names = list(TRACKS) if which == "all" else [which]

    ref_i, ref_lra, ref_tp = ml.lufs(REF)
    print(f"reference caves.ogg: {ref_i:.1f} LUFS  LRA {ref_lra:.1f}  "
          f"true peak {ref_tp:.1f} dBFS")

    results = [run(n, ref_i, reuse) for n in names]

    print("\n=== summary vs caves.ogg ===")
    print(f"{'track':18} {'secs':>7} {'LUFS':>7} {'dLUFS':>7} {'LRA':>6} "
          f"{'TP dB':>7} {'seam':>6} {'cos':>7}")
    print(f"{'caves.ogg (ref)':18} {94.31:>7.2f} {ref_i:>7.1f} {0.0:>7.1f} "
          f"{ref_lra:>6.1f} {ref_tp:>7.1f} {'-':>6} {'-':>7}")
    for r in results:
        print(f"{r['name']:18} {r['secs']:>7.2f} {r['lufs']:>7.1f} "
              f"{r['lufs'] - ref_i:>+7.1f} {r['lra']:>6.1f} {r['peak']:>7.1f} "
              f"{r['seam_ratio']:>6.2f} {r['seam_cosine']:>7.4f}")
