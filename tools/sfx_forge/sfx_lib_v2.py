"""v2 additions: Supermassive reverb chain + Surge XT / Dexed instrument layers."""
import sys

sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent))
from sfx_lib import *  # noqa: F401,F403
from sfx_lib import _apply_chain
from forge import call, track, fx, setp, midi, notes

# â”€â”€ ValhallaSupermassive (all params normalized 0..1) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
SM = dict(mix=0, delaysync=1, delaynote=2, delay_ms=3, warp=4, clear=5,
          feedback=6, density=7, width=8, lowcut=9, highcut=10,
          modrate=11, moddepth=12, mode=13)


def supermassive(mix=0.3, feedback=0.5, density=0.7, mode=0.0, delay_ms=0.12,
                 width=0.85, lowcut=0.08, highcut=0.8, modrate=0.3, moddepth=0.35):
    """Supermassive as send-style tail. mode 0=Gemini (tight) .. 1 (huge/weird)."""
    return ("ValhallaSupermassive", {
        SM["mix"]: mix, SM["delaysync"]: 0.0, SM["delay_ms"]: delay_ms,
        SM["feedback"]: feedback, SM["density"]: density, SM["width"]: width,
        SM["lowcut"]: lowcut, SM["highcut"]: highcut, SM["modrate"]: modrate,
        SM["moddepth"]: moddepth, SM["mode"]: mode,
    })


# â”€â”€ Surge XT Scene A param indices (from surge_params.json dump) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
SG = dict(pitch=229, porta=230, noise_color=235, vol=237,
          ws_type=252, ws_drive=253,
          o1_type=256, o1_octave=257, o1_pitch=258, o1_shape=259,
          o1_w1=260, o1_w2=261, o1_sub=262, o1_udet=264, o1_uvoices=265,
          o1_vol=292, o1_mute=293,
          noise_vol=312, noise_mute=313,
          f1_type=317, f1_sub=318, f1_cut=319, f1_res=320, f1_env=321,
          aeg_a=329, aeg_d=331, aeg_s=333, aeg_r=334,
          feg_a=337, feg_d=339, feg_s=341, feg_r=342)


def surge_layer(name, seq, patch, vol_db=0.0, chain=(), item_len=4.0):
    """Surge XT track. patch: {SG key: normalized value}. seq: [(pitch, t, len, vel)]."""
    tr = track(name, vol_db)
    sg = fx(tr, "Surge XT")
    for key, val in patch.items():
        setp(tr, sg, SG[key], val)
    item = midi(tr, 0.0, item_len)
    notes(tr, item, seq)
    _apply_chain(tr, chain)
    return tr


# patch archetypes (normalized values; verified by probe renders)
def whoosh_patch(color=0.3, cutoff=0.45, reso=0.55, sweep=0.7,
                 attack=0.35, release=0.42):
    """Noise gen -> resonant LP with FEG sweep. Note length shapes the hump."""
    return {"o1_mute": 1.0, "noise_mute": 0.0, "noise_vol": 0.85,
            "noise_color": color, "f1_cut": cutoff, "f1_res": reso,
            "f1_env": 0.5 + sweep / 2, "feg_a": 0.0, "feg_d": 0.45,
            "feg_s": 0.0, "feg_r": 0.3,
            "aeg_a": attack, "aeg_d": 0.5, "aeg_s": 0.8, "aeg_r": release}


def zap_patch(cutoff=0.35, reso=0.85, sweep=0.85, decay=0.28):
    """Osc through screaming resonant LP, fast FEG drop = laser zap."""
    return {"o1_vol": 0.8, "f1_cut": cutoff, "f1_res": reso,
            "f1_env": 0.5 + sweep / 2, "feg_a": 0.0, "feg_d": decay,
            "feg_s": 0.0, "feg_r": 0.1,
            "aeg_a": 0.0, "aeg_d": 0.45, "aeg_s": 0.6, "aeg_r": 0.25}


def brass_patch(uvoices=0.6, udet=0.35, cutoff=0.55, attack=0.5):
    """Unison saw stack, slow swell â€” boss brass."""
    return {"o1_vol": 0.75, "o1_uvoices": uvoices, "o1_udet": udet,
            "f1_cut": cutoff, "f1_res": 0.15,
            "aeg_a": attack, "aeg_d": 0.6, "aeg_s": 1.0, "aeg_r": 0.5}


# â”€â”€ Dexed (default FM E-piano patch; FM bells via high notes) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def dexed_layer(name, seq, vol_db=0.0, chain=(), item_len=4.0):
    tr = track(name, vol_db)
    fx(tr, "Dexed")
    item = midi(tr, 0.0, item_len)
    notes(tr, item, seq)
    _apply_chain(tr, chain)
    return tr

