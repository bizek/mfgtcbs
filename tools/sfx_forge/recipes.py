"""All Extraction Survivors SFX recipes. Run: python recipes.py <category|name|all>

Categories: hits, swings, deaths, combatmisc, pickups, ui, status, extraction, dash
Sound palette: D-centered. Positive sounds = D major pentatonic; negative = low/dissonant.
"""
import sys

sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent))
from sfx_lib import *  # noqa: F401,F403,E402

# note freqs
D5, E5, FS5, G5, A5, B5 = 587.33, 659.26, 739.99, 783.99, 880.0, 987.77
CS6, D6, FS6, A6 = 1108.73, 1174.66, 1479.98, 1760.0
# midi numbers
mD3, mF3, mA3, mD4, mF4, mA4, mD5, mFS5, mA5, mD6, mFS6 = 50, 53, 57, 62, 65, 69, 74, 78, 81, 86, 90

R = {}  # name -> (builder, length, tail)


def recipe(name, length, tail=0.25):
    def deco(fn):
        R[name] = (fn, length, tail)
        return fn
    return deco


# â•â•â• HITS â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

def _hit_physical(lp_amt, f0, dur):
    def b():
        noise_layer("thud", white=False, gate_pts=gate_decay(0.0, dur, 1.0),
                    noise_db=8.0, chain=[lowpass(lp_amt), sat(45.0)])
        tone_layer("punch", shape=0, freq_pts=sweep(0.0, dur * 0.7, f0, 55),
                   amp_pts=decay_db(0.0, dur, -2.0), vol_db=2.0)
    return b

R["hit_physical_0"] = (_hit_physical(0.10, 165, 0.09), 0.14, 0.1)
R["hit_physical_1"] = (_hit_physical(0.13, 185, 0.08), 0.13, 0.1)
R["hit_physical_2"] = (_hit_physical(0.08, 145, 0.11), 0.16, 0.1)


def _hit_fire(dur, cr):
    def b():
        noise_layer("body", white=False, gate_pts=gate_decay(0.0, dur, 0.9),
                    noise_db=6.0, chain=[lowpass(0.35), sat(65.0)])
        for j, t in enumerate(cr):  # crackle ticks
            noise_layer(f"crk{j}", white=True, gate_pts=gate_decay(t, 0.018, 0.7),
                        noise_db=4.0, chain=[highpass(0.15)])
        tone_layer("warm", shape=0, freq_pts=sweep(0.0, dur, 115, 68),
                   amp_pts=decay_db(0.0, dur, -6.0))
    return b

R["hit_fire_0"] = (_hit_fire(0.17, (0.03, 0.08, 0.13)), 0.2, 0.12)
R["hit_fire_1"] = (_hit_fire(0.15, (0.02, 0.09)), 0.18, 0.12)
R["hit_fire_2"] = (_hit_fire(0.19, (0.04, 0.07, 0.11, 0.15)), 0.22, 0.12)


def _hit_cryo(ping, dur):
    def b():
        noise_layer("shard", white=True, gate_pts=gate_decay(0.0, 0.06, 0.8),
                    noise_db=2.0, chain=[highpass(0.45)])
        tone_layer("ping", shape=0, freq_pts=[(0.0, ping, 0), (dur, ping, 0)],
                   amp_pts=decay_db(0.005, dur, -4.0), chain=[verb(0.2, 0.15)])
        tone_layer("ping2", shape=0, freq_pts=[(0.0, ping * 1.26, 0), (dur, ping * 1.26, 0)],
                   amp_pts=decay_db(0.025, dur * 0.7, -13.0))
    return b

R["hit_cryo_0"] = (_hit_cryo(2793, 0.11), 0.15, 0.2)
R["hit_cryo_1"] = (_hit_cryo(3135, 0.09), 0.13, 0.2)
R["hit_cryo_2"] = (_hit_cryo(2489, 0.13), 0.17, 0.2)


def _hit_shock(f_hi, dur):
    def b():
        jag = [(0.0, f_hi, 0), (dur * 0.3, f_hi * 0.4, 0), (dur * 0.45, f_hi * 0.75, 0),
               (dur * 0.7, f_hi * 0.25, 0), (dur, f_hi * 0.15, 0)]
        tone_layer("zap", shape=2, freq_pts=jag, amp_pts=decay_db(0.0, dur, -5.0, attack=0.002),
                   chain=[ringmod(55.0, 55.0), dist(14.0, 6.0, -10.0)])
        noise_layer("crack", white=True, gate_pts=gate_decay(0.0, 0.022, 1.0),
                    noise_db=4.0, chain=[highpass(0.3)])
    return b

R["hit_shock_0"] = (_hit_shock(1500, 0.07), 0.11, 0.1)
R["hit_shock_1"] = (_hit_shock(1900, 0.06), 0.10, 0.1)
R["hit_shock_2"] = (_hit_shock(1200, 0.09), 0.13, 0.1)


def _hit_void(f0, dur):
    def b():
        tone_layer("fall", shape=0, freq_pts=sweep(0.0, dur, f0, 52),
                   amp_pts=decay_db(0.0, dur, -4.0),
                   chain=[ringmod(28.0, 45.0), flanger(9.0, -6.0, 3.5, -8.0, -3.0)])
        noise_layer("dark", white=False, gate_pts=gate_swell(0.0, dur, 0.5, rise=0.55),
                    noise_db=0.0, chain=[lowpass(0.22)])
    return b

R["hit_void_0"] = (_hit_void(330, 0.19), 0.22, 0.2)
R["hit_void_1"] = (_hit_void(290, 0.17), 0.20, 0.2)
R["hit_void_2"] = (_hit_void(380, 0.22), 0.25, 0.2)


# â•â•â• SWINGS â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

def _swing(white, dur, rise, lp_amt, hp_amt, ph_rate, vol_db=0.0):
    def b():
        noise_layer("whoosh", white=white, gate_pts=gate_swell(0.0, dur, 1.0, rise=rise),
                    noise_db=6.0, vol_db=vol_db,
                    chain=[lowpass(lp_amt, hp=hp_amt), phaser(ph_rate, 250, 2600, -3.0)])
    return b

R["swing_light_0"] = (_swing(True, 0.14, 0.32, 0.62, 0.22, 5.0), 0.16, 0.08)
R["swing_light_1"] = (_swing(True, 0.12, 0.38, 0.68, 0.26, 6.5), 0.14, 0.08)
R["swing_light_2"] = (_swing(True, 0.16, 0.28, 0.58, 0.19, 4.2), 0.18, 0.08)


def _swing_heavy(dur, rise, lp_amt, thud_f):
    def b():
        noise_layer("whoosh", white=False, gate_pts=gate_swell(0.0, dur, 1.0, rise=rise),
                    noise_db=8.0, chain=[lowpass(lp_amt), sat(30.0)])
        tone_layer("weight", shape=0, freq_pts=sweep(0.0, dur, thud_f, thud_f * 0.55),
                   amp_pts=swell_db(0.0, dur, -9.0, rise=rise))
    return b

R["swing_heavy_0"] = (_swing_heavy(0.26, 0.42, 0.30, 95), 0.28, 0.1)
R["swing_heavy_1"] = (_swing_heavy(0.23, 0.36, 0.34, 110), 0.25, 0.1)
R["swing_heavy_2"] = (_swing_heavy(0.30, 0.46, 0.26, 85), 0.32, 0.1)


# â•â•â• CRIT / KILL / DEATHS / MITIGATION â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

@recipe("crit", 0.16, 0.35)
def crit():
    tone_layer("ping", shape=0, freq_pts=[(0.0, A6, 0), (0.15, A6, 0)],
               amp_pts=decay_db(0.0, 0.12, -3.0, attack=0.002),
               chain=[echo(0.055, 0.25, 0.22)])
    tone_layer("ping2", shape=0, freq_pts=[(0.0, 2637.0, 0), (0.15, 2637.0, 0)],
               amp_pts=decay_db(0.012, 0.09, -9.0))
    noise_layer("snap", white=True, gate_pts=gate_decay(0.0, 0.014, 0.9),
                noise_db=2.0, chain=[highpass(0.35)])


@recipe("kill", 0.18, 0.2)
def kill():
    tone_layer("drop", shape=0, freq_pts=sweep(0.0, 0.09, 240, 82),
               amp_pts=decay_db(0.0, 0.11, -3.0), chain=[sat(40.0)])
    noise_layer("thump", white=False, gate_pts=gate_decay(0.0, 0.07, 0.9),
                noise_db=6.0, chain=[lowpass(0.12)])
    tone_layer("spark", shape=0, freq_pts=[(0.0, 1046.5, 0), (0.12, 1046.5, 0)],
               amp_pts=decay_db(0.035, 0.07, -14.0))


def _death_normal(f0, f1, dur):
    def b():
        tone_layer("blip", shape=2, freq_pts=sweep(0.0, dur, f0, f1),
                   amp_pts=decay_db(0.0, dur, -6.0),
                   chain=[dist(17.0, 5.0, -11.0), lowpass(0.45)])
    return b

R["death_enemy_normal_0"] = (_death_normal(420, 70, 0.20), 0.23, 0.1)
R["death_enemy_normal_1"] = (_death_normal(360, 58, 0.24), 0.27, 0.1)


@recipe("death_enemy_elite", 0.42, 0.3)
def death_elite():
    tone_layer("growl", shape=2, freq_pts=sweep(0.0, 0.35, 290, 46),
               amp_pts=decay_db(0.0, 0.36, -5.0),
               chain=[ringmod(33.0, 50.0), dist(15.0, 4.0, -11.0), lowpass(0.4)])
    noise_layer("body", white=False, gate_pts=gate_decay(0.02, 0.3, 0.7),
                noise_db=4.0, chain=[lowpass(0.2)])


@recipe("death_enemy_boss", 1.35, 1.2)
def death_boss():
    tone_layer("fall", shape=0, freq_pts=sweep(0.0, 1.1, 115, 30),
               amp_pts=decay_db(0.0, 1.15, -3.0),
               chain=[sat(50.0), flanger(11.0, -9.0, 0.7, -10.0, -2.0), verb(0.85, 0.55)])
    noise_layer("rumble", white=False, gate_pts=gate_decay(0.05, 1.0, 0.8),
                noise_db=8.0, chain=[lowpass(0.10), verb(0.8, 0.4)])
    noise_layer("debris", white=True, gate_pts=gate_decay(0.3, 0.25, 0.35),
                noise_db=0.0, chain=[lowpass(0.5)])


@recipe("death_player", 1.5, 1.0)
def death_player():
    synth_layer("dirge", [(mA4, 0.0, 0.4, 88), (mF4, 0.35, 0.4, 82), (mD4, 0.7, 0.85, 90)],
                attack=0.02, decay=0.5, sustain=0.4, release=0.35, tri=0.6,
                chain=[lowpass(0.5), verb(0.6, 0.45)])
    tone_layer("under", shape=0, freq_pts=sweep(0.2, 1.2, 150, 60, curve=1.3),
               amp_pts=swell_db(0.2, 1.2, -16.0, rise=0.3))


@recipe("block", 0.12, 0.25)
def block():
    tone_layer("clink", shape=2, freq_pts=[(0.0, 940.0, 0), (0.1, 940.0, 0)],
               amp_pts=decay_db(0.0, 0.07, 0.0, attack=0.002), vol_db=4.0,
               chain=[ringmod(870.0, 35.0, 25.0), highpass(0.12)])
    noise_layer("scrape", white=True, gate_pts=gate_decay(0.0, 0.04, 0.6),
                noise_db=0.0, chain=[highpass(0.3)])


@recipe("dodge", 0.14, 0.1)
def dodge():
    noise_layer("swish", white=True, gate_pts=gate_swell(0.0, 0.12, 0.9, rise=0.3),
                noise_db=4.0, chain=[highpass(0.35, lp=0.85), phaser(4.5, 500, 4000, -2.0)])


@recipe("boss_intro", 2.0, 1.5)
def boss_intro():
    synth_layer("brass", [(mD3, 0.0, 1.5, 100), (mF3, 0.0, 1.5, 92),
                          (mA3, 0.0, 1.5, 88), (mD4, 0.05, 1.45, 80)],
                attack=0.35, decay=0.3, sustain=1.2, release=0.5, saw=0.8,
                vol=0.45, chain=[lowpass(0.4), sat(40.0), verb(0.8, 0.5)])
    noise_layer("riser", white=False, gate_pts=gate_swell(0.0, 1.6, 0.6, rise=0.85),
                noise_db=4.0, chain=[highpass(0.1, lp=0.6)])
    tone_layer("sub", shape=0, freq_pts=[(0.0, 36.7, 0), (1.8, 36.7, 0)],
               amp_pts=swell_db(0.0, 1.8, -6.0, rise=0.6))


# â•â•â• PICKUPS â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

def _chime(n1, n2, d1):
    def b():
        synth_layer("chime", [(n1, 0.0, d1, 96), (n2, 0.02, d1, 78)],
                    attack=0.002, decay=0.14, sustain=0.0, release=0.08,
                    chain=[verb(0.22, 0.18)])
    return b

R["pickup_xp_0"] = (_chime(mA5, mD6, 0.1), 0.16, 0.25)
R["pickup_xp_1"] = (_chime(83, 88, 0.09), 0.15, 0.25)  # B5 + E6


def _coin(n1, n2, gap):
    def b():
        synth_layer("coin", [(n1, 0.0, 0.03, 100), (n2, gap, 0.035, 96)],
                    attack=0.001, decay=0.05, sustain=0.0, release=0.02,
                    square=0.5, chain=[highpass(0.2)])
    return b

R["pickup_currency_0"] = (_coin(95, 100, 0.045), 0.13, 0.15)  # B6 -> E7
R["pickup_currency_1"] = (_coin(97, 93, 0.05), 0.14, 0.15)    # C#7 -> A6


@recipe("pickup_weapon", 0.45, 0.45)
def pickup_weapon():
    synth_layer("arp", [(mD5, 0.0, 0.1, 90), (mFS5, 0.05, 0.1, 92),
                        (mA5, 0.10, 0.12, 96), (mD6, 0.15, 0.3, 100)],
                attack=0.003, decay=0.22, sustain=0.0, release=0.12,
                tri=0.5, square=0.25, chain=[chorus(18.0, 3.0, 1.2), verb(0.3, 0.25)])


@recipe("pickup_mod", 0.32, 0.3)
def pickup_mod():
    synth_layer("arp", [(mA5, 0.0, 0.08, 90), (mFS5 + 5, 0.055, 0.08, 92), (mD6, 0.11, 0.18, 96)],
                attack=0.002, decay=0.16, sustain=0.0, release=0.08, square=0.6,
                chain=[ringmod(220.0, 25.0, 8.0), echo(0.07, 0.2, 0.18)])


@recipe("pickup_keystone", 0.8, 0.9)
def pickup_keystone():
    synth_layer("crystal", [(mD6, 0.0, 0.55, 96), (mA5, 0.0, 0.55, 70)],
                attack=0.004, decay=0.55, sustain=0.15, release=0.3,
                xsine=0.4, chain=[chorus(26.0, 4.0, 0.6, -8.0, -5.0), verb(0.55, 0.45)])
    tone_layer("shimmer", shape=0, freq_pts=sweep(0.05, 0.5, 2349, 3520),
               amp_pts=swell_db(0.05, 0.55, -20.0, rise=0.4))


# â•â•â• UI / PROGRESSION â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

@recipe("level_up", 1.0, 0.8)
def level_up():
    synth_layer("fanfare", [(mD5, 0.0, 0.1, 92), (mFS5, 0.09, 0.1, 94), (mA5, 0.18, 0.1, 96),
                            (mD6, 0.27, 0.3, 102), (mFS6, 0.44, 0.42, 106)],
                attack=0.003, decay=0.3, sustain=0.25, release=0.2,
                square=0.35, tri=0.45, chain=[echo(0.12, 0.3, 0.28), verb(0.4, 0.3)])
    noise_layer("sparkle", white=True, gate_pts=gate_swell(0.35, 0.5, 0.25, rise=0.5),
                noise_db=-4.0, chain=[highpass(0.55)])


@recipe("upgrade_select", 0.2, 0.2)
def upgrade_select():
    synth_layer("sel", [(mD5, 0.0, 0.06, 84), (mA5, 0.07, 0.1, 92)],
                attack=0.002, decay=0.1, sustain=0.0, release=0.06,
                chain=[verb(0.18, 0.12)])


@recipe("ui_click", 0.06, 0.05)
def ui_click():
    synth_layer("tick", [(93, 0.0, 0.025, 96)],
                attack=0.001, decay=0.03, sustain=0.0, release=0.012,
                square=0.5, chain=[lowpass(0.5)])


@recipe("ui_panel_open", 0.2, 0.1)
def ui_panel_open():
    noise_layer("swish", white=True, gate_pts=gate_swell(0.0, 0.16, 0.55, rise=0.45),
                noise_db=0.0, chain=[lowpass(0.5, hp=0.15)])
    tone_layer("rise", shape=0, freq_pts=sweep(0.0, 0.15, 420, 880),
               amp_pts=swell_db(0.0, 0.15, -16.0, rise=0.5))


@recipe("ui_panel_close", 0.2, 0.1)
def ui_panel_close():
    noise_layer("swish", white=True, gate_pts=gate_swell(0.0, 0.15, 0.5, rise=0.4),
                noise_db=0.0, chain=[lowpass(0.42, hp=0.12)])
    tone_layer("fall", shape=0, freq_pts=sweep(0.0, 0.14, 880, 420),
               amp_pts=swell_db(0.0, 0.14, -16.0, rise=0.4))


@recipe("ui_purchase", 0.35, 0.3)
def ui_purchase():
    synth_layer("coins", [(97, 0.0, 0.03, 98), (102, 0.05, 0.03, 94), (97, 0.10, 0.035, 90)],
                attack=0.001, decay=0.05, sustain=0.0, release=0.02,
                square=0.5, chain=[highpass(0.2)])
    synth_layer("confirm", [(76, 0.14, 0.15, 92)],
                attack=0.003, decay=0.16, sustain=0.0, release=0.1,
                chain=[verb(0.2, 0.15)])


@recipe("ui_error", 0.38, 0.15)
def ui_error():
    for j, t in enumerate((0.0, 0.16)):
        tone_layer(f"buzz{j}", shape=2, freq_pts=[(t, 138.0, 0), (t + 0.1, 130.0, 0)],
                   amp_pts=hold_db(t, 0.1, -8.0, a=0.004, r=0.02),
                   chain=[dist(10.0, 3.0, -12.0)] if j == 0 else [dist(10.0, 3.0, -12.0)])


@recipe("ui_cancel", 0.2, 0.15)
def ui_cancel():
    synth_layer("cancel", [(mA4, 0.0, 0.06, 82), (mF4, 0.07, 0.09, 78)],
                attack=0.002, decay=0.09, sustain=0.0, release=0.05,
                tri=0.3)


# â•â•â• STATUS APPLIES â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

@recipe("burn_apply", 0.24, 0.15)
def burn_apply():
    for j, t in enumerate((0.0, 0.05, 0.1)):
        noise_layer(f"crk{j}", white=True, gate_pts=gate_decay(t, 0.02, 0.65),
                    noise_db=2.0, chain=[highpass(0.18)])
    tone_layer("ignite", shape=0, freq_pts=sweep(0.0, 0.13, 150, 430),
               amp_pts=swell_db(0.0, 0.15, -8.0, rise=0.6), chain=[sat(55.0)])


@recipe("chill_apply", 0.22, 0.25)
def chill_apply():
    tone_layer("crys", shape=0, freq_pts=sweep(0.0, 0.16, 2200, 1480),
               amp_pts=decay_db(0.0, 0.17, -7.0), chain=[verb(0.25, 0.2)])
    noise_layer("shimmer", white=True, gate_pts=gate_decay(0.0, 0.1, 0.35),
                noise_db=-2.0, chain=[highpass(0.55)])


@recipe("frozen", 0.3, 0.3)
def frozen():
    noise_layer("crack", white=True, gate_pts=gate_decay(0.0, 0.025, 1.0),
                noise_db=4.0, chain=[highpass(0.25)])
    tone_layer("d1", shape=0, freq_pts=[(0.015, 1318.5, 0), (0.28, 1318.5, 0)],
               amp_pts=decay_db(0.015, 0.22, -6.0), chain=[verb(0.3, 0.25)])
    tone_layer("d2", shape=0, freq_pts=[(0.015, A6, 0), (0.28, A6, 0)],
               amp_pts=decay_db(0.02, 0.19, -10.0))


@recipe("shocked_apply", 0.12, 0.1)
def shocked_apply():
    noise_layer("arc", white=True, gate_pts=gate_decay(0.0, 0.018, 1.0),
                noise_db=4.0, chain=[highpass(0.3)])
    tone_layer("snap", shape=2, freq_pts=[(0.008, 1600.0, 0), (0.05, 900.0, 0)],
               amp_pts=decay_db(0.008, 0.045, -7.0, attack=0.002),
               chain=[ringmod(60.0, 45.0)])


@recipe("void_apply", 0.3, 0.25)
def void_apply():
    tone_layer("pop", shape=0, freq_pts=sweep(0.0, 0.12, 500, 90),
               amp_pts=decay_db(0.0, 0.13, -5.0), chain=[ringmod(25.0, 55.0)])
    noise_layer("rev", white=False, gate_pts=gate_swell(0.05, 0.22, 0.5, rise=0.8),
                noise_db=2.0, chain=[lowpass(0.3)])


# â•â•â• EXTRACTION â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

@recipe("extraction_warning", 1.0, 0.4)
def extraction_warning():
    for t in (0.0, 0.48):
        tone_layer(f"al{int(t * 100)}", shape=1, freq_pts=sweep(t, 0.32, 620, 930),
                   amp_pts=hold_db(t, 0.36, -7.0, a=0.03, r=0.08),
                   chain=[echo(0.09, 0.2, 0.15)])


@recipe("extraction_channel_start", 0.8, 0.5)
def extraction_channel_start():
    tone_layer("root", shape=0, freq_pts=[(0.0, 82.4, 0), (0.75, 82.4, 0)],
               amp_pts=swell_db(0.0, 0.75, -4.0, rise=0.55))
    tone_layer("fifth", shape=0, freq_pts=[(0.2, 123.5, 0), (0.75, 123.5, 0)],
               amp_pts=swell_db(0.2, 0.55, -10.0, rise=0.5))
    noise_layer("air", white=False, gate_pts=gate_swell(0.0, 0.7, 0.3, rise=0.7),
                noise_db=0.0, chain=[lowpass(0.18)])


@recipe("extraction_channel_hum", 2.0, 0.0)
def extraction_channel_hum():
    # loopable: constant levels, no attack/release inside the loop region
    for f, db in ((82.4, -8.0), (164.8, -14.0), (247.2, -20.0)):
        tone_layer(f"h{int(f)}", shape=0, freq_pts=[(0.0, f, 0), (2.0, f, 0)],
                   amp_pts=[(0.0, db, 0), (2.0, db, 0)],
                   chain=[chorus(24.0, 2.0, 0.5, -14.0, -3.0)] if f > 100 else ())
    noise_layer("bed", white=False, gate_pts=[(0.0, 0.16, 0), (2.0, 0.16, 0)],
                noise_db=-6.0, chain=[lowpass(0.14)])


@recipe("extraction_channel_complete", 1.2, 1.0)
def extraction_channel_complete():
    synth_layer("fanfare", [(mD5, 0.0, 0.12, 94), (mA5, 0.1, 0.12, 98), (mD6, 0.2, 0.5, 104)],
                attack=0.004, decay=0.4, sustain=0.3, release=0.3,
                tri=0.5, square=0.2, chain=[echo(0.11, 0.3, 0.3), verb(0.5, 0.4)])
    tone_layer("surge", shape=0, freq_pts=sweep(0.0, 0.5, 300, 1200),
               amp_pts=swell_db(0.0, 0.55, -14.0, rise=0.7))
    noise_layer("shimmer", white=True, gate_pts=gate_swell(0.3, 0.6, 0.3, rise=0.4),
                noise_db=-4.0, chain=[highpass(0.5)])


@recipe("extraction_interrupted", 0.55, 0.3)
def extraction_interrupted():
    tone_layer("buzz", shape=2, freq_pts=sweep(0.0, 0.4, 130, 55),
               amp_pts=hold_db(0.0, 0.42, -6.0, a=0.006, r=0.1),
               chain=[dist(20.0, 6.0, -10.0), lowpass(0.5)])
    noise_layer("burst", white=True, gate_pts=gate_decay(0.0, 0.06, 0.8),
                noise_db=2.0, chain=[lowpass(0.6)])


# â•â•â• DASHES â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

@recipe("dash_generic", 0.16, 0.1)
def dash_generic():
    noise_layer("whoosh", white=True, gate_pts=gate_swell(0.0, 0.14, 0.9, rise=0.3),
                noise_db=4.0, chain=[lowpass(0.75, hp=0.18), phaser(3.5, 400, 3200, -3.0)])


@recipe("dash_teleport", 0.3, 0.35)
def dash_teleport():
    tone_layer("zip", shape=0, freq_pts=sweep(0.0, 0.1, 350, 1400),
               amp_pts=decay_db(0.0, 0.11, -6.0), chain=[chorus(12.0, 2.0, 3.0)])
    tone_layer("spark", shape=0, freq_pts=[(0.09, 2093.0, 0), (0.25, 2093.0, 0)],
               amp_pts=decay_db(0.09, 0.13, -10.0), chain=[verb(0.3, 0.3)])
    noise_layer("in", white=True, gate_pts=gate_swell(0.0, 0.09, 0.3, rise=0.75),
                noise_db=-2.0, chain=[highpass(0.4)])


@recipe("dash_deadly", 0.2, 0.2)
def dash_deadly():
    noise_layer("blade", white=True, gate_pts=gate_swell(0.0, 0.13, 0.85, rise=0.25),
                noise_db=4.0, chain=[highpass(0.4, lp=0.9), flanger(3.0, -5.0, 6.0, -6.0, -4.0)])
    tone_layer("ring", shape=0, freq_pts=[(0.05, 1245.0, 0), (0.18, 1245.0, 0)],
               amp_pts=decay_db(0.05, 0.1, -13.0))


@recipe("dash_dodge_roll", 0.3, 0.1)
def dash_dodge_roll():
    noise_layer("h1", white=False, gate_pts=gate_swell(0.0, 0.11, 0.8, rise=0.4),
                noise_db=4.0, chain=[lowpass(0.28)])
    noise_layer("h2", white=False, gate_pts=gate_swell(0.13, 0.12, 0.6, rise=0.4),
                noise_db=4.0, chain=[lowpass(0.22)])


# â•â•â• runner â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

CATEGORIES = {
    "hits": [k for k in R if k.startswith("hit_")],
    "swings": [k for k in R if k.startswith("swing_")],
    "deaths": [k for k in R if k.startswith("death_") or k in ("crit", "kill", "block", "dodge", "boss_intro")],
    "pickups": [k for k in R if k.startswith("pickup_")],
    "ui": [k for k in R if k.startswith("ui_") or k in ("level_up", "upgrade_select")],
    "status": ["burn_apply", "chill_apply", "frozen", "shocked_apply", "void_apply"],
    "extraction": [k for k in R if k.startswith("extraction_")],
    "dash": [k for k in R if k.startswith("dash_")],
}

if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "all"
    names = R.keys() if arg == "all" else CATEGORIES.get(arg, [arg] if arg in R else [])
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
    print(f"\n{len(list(names)) - len(failed)} ok, {len(failed)} failed {failed if failed else ''}")

