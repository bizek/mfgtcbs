"""SFX v2: all 60 sounds rebuilt with Surge XT / Dexed / Valhalla Supermassive.

Strategy: sfx_lib.verb is patched to Supermassive BEFORE importing recipes, so
every v1 recipe inherits the better reverb automatically. Then the families
that benefit from real synthesis are re-architected below.
Run: python recipes_v2.py <category|name|all>
"""
import sys
from pathlib import Path

SP = str(__import__("pathlib").Path(__file__).parent)
sys.path.insert(0, SP)

import forge
forge.OUT_DIR = Path(r"E:\Projects\extraction-survivors\assets\audio\_incoming\reaper_sfx_v2")

import sfx_lib
from sfx_lib_v2 import supermassive, surge_layer, dexed_layer, whoosh_patch, zap_patch, brass_patch


def _sm_verb(size=0.4, wet=0.35, damp=0.5, lp=1.0, dry=1.0):
    """Supermassive stand-in for every v1 verb() call site."""
    return supermassive(mix=min(0.6, wet * 0.95),
                        feedback=0.3 + size * 0.5,
                        density=0.6 + size * 0.3,
                        mode=size * 0.35,
                        delay_ms=0.08 + size * 0.15,
                        highcut=0.5 + lp * 0.35,
                        moddepth=0.3 + damp * 0.2)


sfx_lib.verb = _sm_verb          # patch BEFORE recipes import binds it
import recipes                    # noqa: E402  (inherits patched verb)
from recipes import R, CATEGORIES  # noqa: E402
from sfx_lib import (             # noqa: E402
    noise_layer, tone_layer, synth_layer, decay_db, swell_db, hold_db, sweep,
    gate_decay, gate_swell, lowpass, highpass, echo, dist, sat, ringmod,
    flanger, phaser, chorus, build,
)

verb = _sm_verb

# â•â•â• re-architected families â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

# swings: Surge noise->resonant LP whoosh (real filter sweep, not phaser fake)
def _swing_v2(color, cutoff, dur, vol_db, extra=()):
    def b():
        surge_layer("whoosh", [(60, 0.0, dur, 104)],
                    whoosh_patch(color=color, cutoff=cutoff, reso=0.6,
                                 attack=0.22, release=0.3),
                    vol_db=vol_db, chain=list(extra))
    return b

R["swing_light_0"] = (_swing_v2(0.62, 0.5, 0.13, 9.0), 0.16, 0.15)
R["swing_light_1"] = (_swing_v2(0.68, 0.55, 0.11, 9.0), 0.14, 0.15)
R["swing_light_2"] = (_swing_v2(0.55, 0.46, 0.15, 9.0), 0.18, 0.15)


def _swing_heavy_v2(color, cutoff, dur, thud_f):
    def b():
        surge_layer("whoosh", [(48, 0.0, dur, 110)],
                    whoosh_patch(color=color, cutoff=cutoff, reso=0.5,
                                 attack=0.3, release=0.38),
                    vol_db=9.0, chain=[sat(30.0)])
        tone_layer("weight", shape=0, freq_pts=sweep(0.0, dur + 0.08, thud_f, thud_f * 0.55),
                   amp_pts=swell_db(0.0, dur + 0.08, -9.0, rise=0.4))
    return b

R["swing_heavy_0"] = (_swing_heavy_v2(0.18, 0.34, 0.22, 95), 0.28, 0.2)
R["swing_heavy_1"] = (_swing_heavy_v2(0.22, 0.38, 0.19, 110), 0.25, 0.2)
R["swing_heavy_2"] = (_swing_heavy_v2(0.12, 0.30, 0.26, 85), 0.32, 0.2)


# combo drop "exhale" (docs/combo_feedback_spec.md, mechanism E): a chain lapsing is a breath
# out, not a fail buzzer — reversed swing energy: soft pink-noise swell that darkens as it
# fades, under a quiet downward sigh. Deliberately smaller than any swing.
def _combo_drop_v2():
    noise_layer("breath", white=False, gate_pts=gate_swell(0.0, 0.32, 0.45, rise=0.2),
                noise_db=-4.0, chain=[lowpass(0.42, hp=0.08)])
    tone_layer("sigh", shape=0, freq_pts=sweep(0.0, 0.30, 400, 190),
               amp_pts=decay_db(0.0, 0.32, -18.0, attack=0.03))

R["combo_drop"] = (_combo_drop_v2, 0.38, 0.25)


# shock hits: Surge resonance zap + noise crack
def _hit_shock_v2(note, decay, dur):
    def b():
        surge_layer("zap", [(note, 0.0, dur, 112)],
                    zap_patch(cutoff=0.3, reso=0.88, sweep=0.9, decay=decay),
                    vol_db=8.0, chain=[dist(12.0, 5.0, -10.0)])
        noise_layer("crack", white=True, gate_pts=gate_decay(0.0, 0.02, 1.0),
                    noise_db=4.0, chain=[highpass(0.3)])
    return b

R["hit_shock_0"] = (_hit_shock_v2(79, 0.26, 0.06), 0.12, 0.12)
R["hit_shock_1"] = (_hit_shock_v2(83, 0.22, 0.05), 0.10, 0.12)
R["hit_shock_2"] = (_hit_shock_v2(74, 0.30, 0.08), 0.14, 0.12)


def _shocked_apply_v2():
    surge_layer("zap", [(88, 0.008, 0.04, 100)],
                zap_patch(cutoff=0.4, reso=0.82, sweep=0.8, decay=0.2), vol_db=6.0)
    noise_layer("arc", white=True, gate_pts=gate_decay(0.0, 0.018, 1.0),
                noise_db=4.0, chain=[highpass(0.3)])
R["shocked_apply"] = (_shocked_apply_v2, 0.12, 0.1)


# void hits: keep sine-fall DNA, Supermassive dark warble replaces flanger
def _hit_void_v2(f0, dur):
    def b():
        tone_layer("fall", shape=0, freq_pts=sweep(0.0, dur, f0, 52),
                   amp_pts=decay_db(0.0, dur, -4.0),
                   chain=[ringmod(28.0, 45.0),
                          supermassive(mix=0.4, feedback=0.7, density=0.5, mode=0.62,
                                       lowcut=0.0, highcut=0.45, modrate=0.5, moddepth=0.7)])
        noise_layer("dark", white=False, gate_pts=gate_swell(0.0, dur, 0.5, rise=0.55),
                    noise_db=0.0, chain=[lowpass(0.22)])
    return b

R["hit_void_0"] = (_hit_void_v2(330, 0.19), 0.22, 0.5)
R["hit_void_1"] = (_hit_void_v2(290, 0.17), 0.20, 0.5)
R["hit_void_2"] = (_hit_void_v2(380, 0.22), 0.25, 0.5)


# cryo pings + crit: Dexed FM bells
def _hit_cryo_v2(n1, dur):
    def b():
        noise_layer("shard", white=True, gate_pts=gate_decay(0.0, 0.06, 0.8),
                    noise_db=2.0, chain=[highpass(0.45)])
        dexed_layer("bell", [(n1, 0.0, dur, 104), (n1 + 4, 0.02, dur * 0.7, 82)],
                    vol_db=7.0,
                    chain=[supermassive(mix=0.22, feedback=0.55, density=0.8,
                                        mode=0.05, highcut=0.9)])
    return b

R["hit_cryo_0"] = (_hit_cryo_v2(101, 0.1), 0.15, 0.35)
R["hit_cryo_1"] = (_hit_cryo_v2(103, 0.09), 0.13, 0.35)
R["hit_cryo_2"] = (_hit_cryo_v2(99, 0.12), 0.17, 0.35)


def _crit_v2():
    dexed_layer("bell", [(105, 0.0, 0.1, 112), (100, 0.012, 0.07, 78)], vol_db=8.0,
                chain=[echo(0.055, 0.25, 0.22),
                       supermassive(mix=0.18, feedback=0.45, density=0.85, highcut=0.95)])
    noise_layer("snap", white=True, gate_pts=gate_decay(0.0, 0.014, 0.9),
                noise_db=2.0, chain=[highpass(0.35)])
R["crit"] = (_crit_v2, 0.16, 0.4)


# dashes / dodge: Surge whooshes
def _dodge_v2():
    surge_layer("swish", [(72, 0.0, 0.09, 100)],
                whoosh_patch(color=0.75, cutoff=0.6, reso=0.55, attack=0.18, release=0.25),
                vol_db=8.0)
R["dodge"] = (_dodge_v2, 0.14, 0.12)


def _dash_generic_v2():
    surge_layer("whoosh", [(64, 0.0, 0.11, 104)],
                whoosh_patch(color=0.5, cutoff=0.52, reso=0.62, attack=0.2, release=0.28),
                vol_db=8.5)
R["dash_generic"] = (_dash_generic_v2, 0.16, 0.12)


def _dash_teleport_v2():
    surge_layer("zip", [(76, 0.0, 0.05, 106), (83, 0.045, 0.05, 100), (88, 0.09, 0.06, 96)],
                zap_patch(cutoff=0.45, reso=0.7, sweep=0.7, decay=0.3), vol_db=6.0,
                chain=[supermassive(mix=0.35, feedback=0.6, density=0.85, mode=0.15,
                                    highcut=0.95, moddepth=0.5)])
    dexed_layer("spark", [(105, 0.1, 0.12, 92)], vol_db=4.0)
R["dash_teleport"] = (_dash_teleport_v2, 0.3, 0.45)


def _dash_deadly_v2():
    surge_layer("blade", [(70, 0.0, 0.08, 108)],
                whoosh_patch(color=0.85, cutoff=0.62, reso=0.75, attack=0.12, release=0.22),
                vol_db=8.0, chain=[flanger(3.0, -5.0, 6.0, -6.0, -4.0)])
    dexed_layer("ring", [(99, 0.05, 0.1, 76)], vol_db=1.0)
R["dash_deadly"] = (_dash_deadly_v2, 0.2, 0.25)


def _dash_dodge_roll_v2():
    surge_layer("r1", [(52, 0.0, 0.09, 96), (50, 0.13, 0.1, 84)],
                whoosh_patch(color=0.15, cutoff=0.34, reso=0.45, attack=0.25, release=0.3),
                vol_db=8.0)
R["dash_dodge_roll"] = (_dash_dodge_roll_v2, 0.3, 0.15)


# boss intro: Surge unison brass + riser + sub
def _boss_intro_v2():
    surge_layer("brass", [(38, 0.0, 1.5, 106), (41, 0.0, 1.5, 96), (45, 0.02, 1.48, 92),
                          (50, 0.05, 1.45, 86)],
                brass_patch(uvoices=0.7, udet=0.4, cutoff=0.42, attack=0.45),
                vol_db=9.0,
                chain=[sat(35.0), supermassive(mix=0.42, feedback=0.75, density=0.9,
                                               mode=0.3, delay_ms=0.2)])
    noise_layer("riser", white=False, gate_pts=gate_swell(0.0, 1.6, 0.6, rise=0.85),
                noise_db=4.0, chain=[highpass(0.1, lp=0.6)])
    tone_layer("sub", shape=0, freq_pts=[(0.0, 36.7, 0), (1.8, 36.7, 0)],
               amp_pts=swell_db(0.0, 1.8, -6.0, rise=0.6))
R["boss_intro"] = (_boss_intro_v2, 2.0, 1.8)


# player death: Dexed EP dirge
def _death_player_v2():
    dexed_layer("dirge", [(69, 0.0, 0.4, 92), (65, 0.35, 0.4, 86), (62, 0.7, 0.9, 94)],
                vol_db=8.0,
                chain=[lowpass(0.55), supermassive(mix=0.45, feedback=0.7, density=0.85,
                                                   mode=0.25, highcut=0.6)])
    tone_layer("under", shape=0, freq_pts=sweep(0.2, 1.2, 150, 60, curve=1.3),
               amp_pts=swell_db(0.2, 1.2, -16.0, rise=0.3))
R["death_player"] = (_death_player_v2, 1.5, 1.6)


# pickups & UI: Dexed FM (same note data as v1, better instrument)
def _chime_v2(n1, n2, d1):
    def b():
        dexed_layer("chime", [(n1, 0.0, d1, 100), (n2, 0.02, d1, 80)], vol_db=8.0,
                    chain=[supermassive(mix=0.2, feedback=0.5, density=0.8, highcut=0.92)])
    return b

R["pickup_xp_0"] = (_chime_v2(81, 86, 0.1), 0.16, 0.3)
R["pickup_xp_1"] = (_chime_v2(83, 88, 0.09), 0.15, 0.3)


def _coin_v2(n1, n2, gap):
    def b():
        dexed_layer("coin", [(n1, 0.0, 0.035, 108), (n2, gap, 0.04, 100)], vol_db=8.0,
                    chain=[highpass(0.15)])
    return b

R["pickup_currency_0"] = (_coin_v2(95, 100, 0.045), 0.13, 0.2)
R["pickup_currency_1"] = (_coin_v2(97, 93, 0.05), 0.14, 0.2)


def _pickup_weapon_v2():
    dexed_layer("arp", [(74, 0.0, 0.1, 96), (78, 0.05, 0.1, 98), (81, 0.10, 0.12, 102),
                        (86, 0.15, 0.3, 106)],
                vol_db=8.0,
                chain=[chorus(18.0, 3.0, 1.2),
                       supermassive(mix=0.28, feedback=0.55, density=0.8, mode=0.1)])
R["pickup_weapon"] = (_pickup_weapon_v2, 0.45, 0.6)


def _pickup_mod_v2():
    dexed_layer("arp", [(81, 0.0, 0.08, 96), (83, 0.055, 0.08, 98), (86, 0.11, 0.18, 102)],
                vol_db=8.0, chain=[ringmod(220.0, 20.0, 8.0), echo(0.07, 0.2, 0.18)])
R["pickup_mod"] = (_pickup_mod_v2, 0.32, 0.35)


def _pickup_keystone_v2():
    dexed_layer("crystal", [(86, 0.0, 0.55, 102), (81, 0.0, 0.55, 74), (93, 0.06, 0.4, 68)],
                vol_db=8.0,
                chain=[chorus(26.0, 4.0, 0.6, -8.0, -5.0),
                       supermassive(mix=0.45, feedback=0.72, density=0.85, mode=0.2,
                                    moddepth=0.55)])
R["pickup_keystone"] = (_pickup_keystone_v2, 0.8, 1.2)


def _level_up_v2():
    dexed_layer("fanfare", [(74, 0.0, 0.1, 98), (78, 0.09, 0.1, 100), (81, 0.18, 0.1, 102),
                            (86, 0.27, 0.3, 108), (90, 0.44, 0.42, 112)],
                vol_db=8.0,
                chain=[echo(0.12, 0.3, 0.28),
                       supermassive(mix=0.32, feedback=0.6, density=0.85, mode=0.12)])
    noise_layer("sparkle", white=True, gate_pts=gate_swell(0.35, 0.5, 0.25, rise=0.5),
                noise_db=-4.0, chain=[highpass(0.55)])
R["level_up"] = (_level_up_v2, 1.0, 1.0)


def _upgrade_select_v2():
    dexed_layer("sel", [(74, 0.0, 0.06, 88), (81, 0.07, 0.1, 98)], vol_db=8.0,
                chain=[supermassive(mix=0.15, feedback=0.4, density=0.75)])
R["upgrade_select"] = (_upgrade_select_v2, 0.2, 0.25)


def _ui_click_v2():
    dexed_layer("tick", [(93, 0.0, 0.028, 102)], vol_db=8.0, chain=[lowpass(0.6)])
R["ui_click"] = (_ui_click_v2, 0.06, 0.08)


def _ui_purchase_v2():
    dexed_layer("coins", [(97, 0.0, 0.035, 104), (102, 0.05, 0.035, 100),
                          (97, 0.10, 0.04, 96)], vol_db=8.0, chain=[highpass(0.15)])
    dexed_layer("confirm", [(76, 0.14, 0.15, 96)], vol_db=6.0,
                chain=[supermassive(mix=0.18, feedback=0.45, density=0.8)])
R["ui_purchase"] = (_ui_purchase_v2, 0.35, 0.35)


def _ui_cancel_v2():
    dexed_layer("cancel", [(69, 0.0, 0.06, 84), (65, 0.07, 0.09, 80)], vol_db=7.0)
R["ui_cancel"] = (_ui_cancel_v2, 0.2, 0.2)


def _extraction_complete_v2():
    dexed_layer("fanfare", [(74, 0.0, 0.12, 100), (81, 0.1, 0.12, 104), (86, 0.2, 0.5, 110)],
                vol_db=8.0,
                chain=[echo(0.11, 0.3, 0.3),
                       supermassive(mix=0.45, feedback=0.7, density=0.85, mode=0.2)])
    tone_layer("surge", shape=0, freq_pts=sweep(0.0, 0.5, 300, 1200),
               amp_pts=swell_db(0.0, 0.55, -14.0, rise=0.7))
    noise_layer("shimmer", white=True, gate_pts=gate_swell(0.3, 0.6, 0.3, rise=0.4),
                noise_db=-4.0, chain=[highpass(0.5)])
R["extraction_channel_complete"] = (_extraction_complete_v2, 1.2, 1.4)


# â•â•â• runner â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "all"
    names = list(R.keys()) if arg == "all" else CATEGORIES.get(arg, [arg] if arg in R else [])
    if not names:
        print(f"unknown: {arg}"); sys.exit(1)
    failed = []
    for name in names:
        fn, length, tail = R[name]
        try:
            build(name, fn, length, tail)
        except Exception as e:
            failed.append(name)
            print(f"  {name}: FAILED - {e}")
    print(f"\n{len(names) - len(failed)} ok, {len(failed)} failed {failed if failed else ''}")

