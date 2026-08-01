# Animation Playback Rate Audit — 2026-07-31

Authored rates come from the 234 `AnimationInfo.txt` / `_Info.txt` / `Animation_Info.txt` files under
`assets/minifantasy/**`. Effective rates were **measured**, not read: `CharacterSpriteFactory.build()`
was run for all 12 characters inside the live editor process and every `SpriteFrames`
animation's `get_animation_speed()` / `get_frame_count()` read back, so the Animation Lab override
layer (`data/anim_overrides.json`) is already baked in. Non-character rates (world FX, pets,
ground zones) are plain literals with no override layer and were read from source.

**Status: all findings actioned 2026-07-31.** The audit ran first and Ben took the two feel calls
(#1 and #3); the rest were unambiguous. Applied changes are recorded per finding below and
re-measured in-engine afterwards.

| # | Finding | Outcome |
|---|---|---|
| 1 | Shockwave ring at 57.8 fps | **Fixed** — `SHOCKWAVE_FPS = 26.0`, duration now derived (1.00 s). Ben's call: slow it, don't subsample |
| 2 | Spark `attack_fx` desynced from `attack` | **Fixed** — override added; both now 0.250 s, verified live |
| 3 | `HELLBREACH_FISSURE_FPS` | **Fixed** — 20 → 24, locked to the body per Ben |
| 4 | Mirror Archer at literal pack rates | **Fixed** — now 9 / 10 / 24, matching the Scavenger |
| 5 | Archdemon fps derived from a duration | **Fixed** — dependency inverted; rate leads, lifetime follows |
| 6 | Corpse ground decal 16 vs body 18 | **Fixed** — aligned to 18 |
| 7–8 | Warden Dictum/Dome outros, `heal_word` borrow | **No change** — frame-count staging, not rate defects; documented as known |
| 9 | Ravager / Verdant have no authored rates | **No change possible** — informational |

Verification: all three edited `.gd` files re-parsed from disk and their constant maps read back
(`SHOCKWAVE_FPS 26.0`, `SHOCKWAVE_TIME 1.0`, `HELLBREACH_FISSURE_FPS 24.0`, `ARCHDEMON_SPELL_FPS 11.0`,
mirror `9.0 / 10.0 / 24.0`, `DRAW_DELAY 0.25`); `ARCHDEMON_SPELL_LIFE == SkillFactory.ARCHDEMON_SPELL_TIME`
asserted equal; The Spark's four attack/overlay animations re-measured off a freshly built
`SpriteFrames` at 24 fps / 0.250 s across base and all facings. Editor error list unchanged from its
pre-existing baseline.

**Confirmed in motion — Training Room, 2026-07-31.** Entered from the main menu with
`training_mode` set before the scene change, asserted on arrival (`training_mode == true` +
`TrainingPanel` present) and again after the class swap; HIT BACK off, all dummies at
`contact_damage 0.0`; class change driven through the panel's own `_cycle_class`. `progression.json`
backed up beforehand and verified byte-identical afterwards (backup removed).

| Check | Measured live | Frames |
|---|---|---|
| Shockwave ring | 26 fps · 26 frames · **1.000 s** | steps cleanly through the whole expansion — a real ring, not a flash |
| Hell Breach fissure (direct) | 24 fps · 17 frames · **0.708 s** | crack opens east and grows to a full molten fissure |
| Hell Breach (real light chain) | body and fissure both 24 fps | swing → slam → crack resolves as the body returns to idle |
| Mirror Archer vs Scavenger | idle 9/9, walk 10/10, shot 24/24 | side by side, matched cadence; mirror looses on her beat |

Open for Ben's eye, not correctness: the ring is now a **1.00 s swell** where it was a 0.45 s pop.
It reads correctly and the art finally plays, but it is a materially different beat behind
Reckoning, Second Wind, Aegis and Taunt. If it wants to be quicker, the lever is `SHOCKWAVE_FPS` —
the duration follows it, and the Line2D edge follows the duration.

---

## The baseline you have to subtract first

**Every Minifantasy pack authors actions at 100ms/frame (10fps) and idle/walk at 200ms/frame (5fps).**
That is the entire authored vocabulary — there are exactly two rates in the whole asset library,
plus one exception (Wizard Teleport, 50ms/20fps).

The game plays essentially nothing at those rates, and shouldn't: a 15-frame Hellfire at 10fps is
1.5s, in a kit whose combo cadence is 0.2s. Measured across all 12 rosters the house band is
**1.5×–2.6× authored, median 2.0×**. Sheets authored at 200ms land at 3.2×–4.8× because the game
normalises to a wall-clock feel, not to a multiplier.

So **"ratio vs authored" is a bad detector on its own** — it would flag all 216 animations. The three
detectors that actually separate signal from the house style:

1. the rate is **computed from a gameplay duration** (the pattern behind both known bugs),
2. the rate **breaks a pair the pack authored as matched** (body ↔ `_fx` overlay, body ↔ composite sheet),
3. the rate is **out of band relative to its own kit or its own siblings**.

Ranked findings follow, most suspect first.

---

## 1. `SHOCKWAVE` — 57.8 fps, derived from a tween duration `[ACCIDENTAL — highest confidence]`

`scripts/entities/player.gd:2906`

```
var fps: float = float(SHOCKWAVE_FRAMES) / SHOCKWAVE_TIME    ## 26 / 0.45 = 57.8
```

| | |
|---|---|
| Sheet | `Spell Effects/Electric/Tileable_Effect/Premade_Spell_Effects/Electric_Expansive_Shock.png` (26 frames, verified) |
| Authored | 10 fps → 2.60 s |
| Effective | **57.8 fps → 0.45 s** |
| Ratio | **5.8×** — the highest in the codebase by more than 2× |

This is the Brimstone bug verbatim, and worse. The constant carries its own confession:

```
const SHOCKWAVE_TIME: float = 0.45   ## match the old tween's beat exactly — feel must not change
```

The 0.45s came from a Line2D tween that predates the sheet. When the pack's expanding-shock art was
retrofitted in, the art was made to serve the number rather than the number being re-derived from the
art. Nothing about 0.45s is an animation decision.

Practical consequence: at 57.8 fps against a 60Hz present, the sheet advances ~1 frame per rendered
frame. It is right at the edge — the moment the game dips below 60fps, or a frame is dropped, the ring
skips frames outright. And a 26-frame authored *expansion* compressed into 0.45s cannot read as an
expansion; it reads as a flash.

Four callers share it: Reckoning, Second Wind, Aegis, Taunt.

**Suggested resolution for Ben:** decide the ring's duration from the art, not the tween — e.g. pin
`SHOCKWAVE_FPS = 26.0` (2.6× authored, dead centre of the house band) and let `SHOCKWAVE_TIME` fall
out at 1.0s, then check whether that reads as too slow for a Taunt pop. If 0.45s really is the feel
you want, the sheet is the wrong sheet for it and it should be trimmed to ~12 frames rather than
sped up 5.8×.

---

## 2. The Spark: `attack_fx` desyncs from `attack` `[ACCIDENTAL — confirmed live]`

`data/anim_overrides.json` → `"The Spark"`

Measured in the built `SpriteFrames`, all five rows (base + 4 facings):

| anim | frames | effective fps | duration |
|---|---|---|---|
| `attack` (body) | 6 | **24** (Lab override, source says 30) | 0.29 s |
| `attack_fx` (overlay) | 6 | **30** (no override) | **0.20 s** |

`Wizard_Attack.png` and `Wizard_Attack_Effect.png` are a frame-matched pair from the pack. The Lab
override slowed the body to 24 and left the overlay at 30, so **the fire overlay finishes 90 ms before
the swing it belongs to** — the last third of the swing plays with no effect on it.

This is an oversight rather than a choice, and the override file proves it: the same session's edit
overrode `attack_2` **and** `attack_2_fx` together to 24. Only `attack_fx` was missed.

It is on the Spark's most-used move — `chain_factory.gd:584`, light chain node 0.

**Fix:** add `"attack_fx": {"fps": 24.0, "from": 0, "to": 6}` to the Spark's override block, matching
the `attack_2_fx` entry beside it.

Every other body/`_fx` pair in the game was checked and matches (Fighter ×5, Warden ×4, Cursed ×4,
Ravager ×2, Whisper ×2, Deadeye, Ranger ×2, Devout ×3).

---

## 3. `HELLBREACH_FISSURE_FPS = 20.0` — the START HERE item `[SUSPECT — no rationale, breaks a documented composite]`

`scripts/entities/player.gd:385`

`Hell_Breach/AnimationInfo.txt` says 100ms/frame for **both** `Hell_Breach` (13f, 32px) and
`Hell_Breach_Spell` (17f, 64px) — frame counts verified off the PNGs — and adds an explicit
composition instruction:

> start "Hell_Breach_Spell" aligned with the Demonologist Character after the jump landing in the "Hell_Breach" animation

So this is not two independent animations. It is one authored composite with a designed offset.

| | authored | in game |
|---|---|---|
| body `hell_breach` | 13f @ 10 → 1.30 s | 13f @ **24** → 0.54 s (2.4×) |
| slam / landing frame (f5) | 0.50 s in | 0.21 s in |
| fissure `Hell_Breach_Spell` | 17f @ 10 → 1.70 s | 17f @ **20** → 0.85 s (2.0×) |
| fissure : body rate | 1.00 | **0.83** |

The two halves of a welded composite are being played at different speeds. The fissure runs **17%
slow relative to its own body**, and outlives it by 0.52 s.

What makes 20 suspect isn't the 2.0× — that's mid-band. It's that **20 matches nothing**:

- not the pack rate (10),
- not the body it is composited onto (24),
- not its two sibling world-FX constants in the same kit — `BRIMSTONE_SIGIL_FPS` is 10.0 (pack rate,
  just corrected in d06655b) and the Archdemon spell resolves to 11.0. Both sit at ~pack rate; this
  one alone sits at 2×.

And unlike `brimstone` (36fps) or `pact_ritual` (16fps), which each carry a paragraph of Ben's
reasoning in `characters.gd`, `HELLBREACH_FISSURE_FPS` has no comment justifying the number at all.
It reads as a value someone picked because it looked about right.

**Suggested resolution:** set it to **24.0**, locking it to the body it is authored to be composited
with (17f → 0.71s, ends 0.92s after the beat starts). That restores the authored 1:1 rate relationship
while keeping the kit's 2.4× cadence. 10.0 would be pack-faithful but 1.7s is far too long for a beat
whose body is 0.54s.

Worth Ben's eyes on-screen either way — this one is a judgement call, not a defect.

---

## 4. The Mirror Archer animates at half the speed of the archer it mirrors `[ACCIDENTAL — visible side-by-side]`

`scripts/entities/mirror_archer.gd:27-34`

This is the only thing in the game that takes the pack rate **literally**, and it does so correctly
and with a citation:

```
## Frame durations come from the pack's own AnimationInfo.txt: 100ms (10fps) for Single Shot,
## 200ms (5fps) for Idle and Walk.
```

The problem is that it stands next to The Scavenger, running **the same three sheets**, at 1.8–2.4×
those rates:

| sheet | Mirror Archer | The Scavenger | mirror is |
|---|---|---|---|
| `Ranger_Idle.png` (16f) | 5 fps → 3.20 s | 9 fps → 1.78 s | 1.8× slower |
| `Ranger_walk.png` (4f) | 5 fps → 0.80 s | 10 fps → 0.40 s | 2.0× slower |
| `Ranger_SingleShot_Diagonal.png` (10f) | 10 fps → 1.00 s | 24 fps → 0.42 s | 2.4× slower |

Two identical sprites on screen at once, one moving at half speed. Being right about the pack rate
doesn't help when nothing else in the game uses it.

Note this also sets it apart from every other companion, which all sit in a consistent pet house
style of idle 8–10 / move 10–12 / attack 14: `angry_demon.gd` (10/12/14), `skeletal_champion.gd`
(10/12/14), `spirit_guardian.gd` (8/10/14), `fire_familiar.gd` (8/–/14), `blood_elemental.gd`
(8/10/18). The Mirror Archer is the only outlier.

**Suggested resolution:** match the Scavenger's own rates (9/10/24) so the reflection reads as a
reflection. `DRAW_DELAY` is correctly derived from `SHOT_FPS`, so raising the fps automatically
retimes the loose — nothing else needs touching.

---

## 5. Archdemon spell fps derived from a gameplay duration `[STRUCTURAL — currently benign]`

`scripts/entities/player.gd:2223`

```
var fps: float = float(ARCHDEMON_SPELL_FRAMES) / maxf(ARCHDEMON_SPELL_LIFE, 0.01)   ## 27 / 2.45 = 11.0
```

Authored 10 fps; effective 11.0 fps; **1.1×**. Visually fine today — this is not a bug you can see.

It is on the list because the dependency runs the wrong way. The comment already admits it:

```
## Must equal SkillFactory.ARCHDEMON_SPELL_TIME (27 frames @ ~11 fps ≈ 2.45s).
```

The art rate is currently a *coincidence* of a balance number. The day anyone retunes the E skill's
zone duration for balance reasons, the animation silently retimes with it — exactly how Brimstone
became 4.5fps. Inverting it (`ARCHDEMON_SPELL_LIFE = FRAMES / FPS`, with `FPS` a named constant)
costs nothing and makes the balance knob unable to touch the art.

Same shape, already handled correctly elsewhere: `telegraph_2d.gd:70` also derives speed from a
gameplay duration, but does it deliberately (a telegraph *must* fill its wind-up), states the
authored rate in the code (`## sheet is authored at 10 fps`), and expresses the result as a
`speed_scale` off that baseline. That's the pattern to copy.

---

## 6–8. Low-priority frame/rate drift

**6. Corpse ground decal vs its own body.** `player.gd:2599` plays
`Stand_Alone_Rise_Corpse_Ground.png` (18f) at 16 fps → 1.13 s, while `rise_corpse` (18f, same folder,
same count) runs at 18 fps → 1.00 s. Authored is 5 fps for both. A 0.13 s drift between a decal and
the summon it sits under. Trivial; align to 18 if it's ever noticed.

**7. Warden Dictum/Dome staged channels — overlay outlives body.** All rates are a correct, uniform
20 fps; the mismatch is frame counts across sheets. `dictum_outro` is 3 frames (0.15 s) but
`dictum_outro_fx` (BladesEnd) is 10 frames (0.50 s) — the blades keep resolving for 0.35 s after the
Paladin's body has finished putting them away. Same shape on `dome_outro` (3f / 0.15 s) vs
`dome_outro_fx` + `dome_outro_base` (8f / 0.40 s). Not an fps bug; a staging decision, and possibly
the intended "the dome lingers" read. Flagged so it's a known quantity.

**8. Warden `heal_word` cross-pack borrow.** Body `_PaladinDictum` (15f) and overlay
`HealingWordsPrayEffect` (22f) both at 20 fps → 0.75 s vs 1.10 s. Inherent to borrowing the Cleric's
overlay onto a Paladin body; the two sheets were never frame-matched. Nothing to fix unless the
trailing 0.35 s of glow reads wrong.

---

## 9. Two characters have no authored ground truth at all `[INFORMATIONAL]`

**`Minifantasy_TrueHeroes_v1.0` ships no `AnimationInfo.txt` anywhere in the pack.** That covers
Barbarian, Druid and Rogue — so **The Ravager** and **The Verdant** (and the Rogue bomb assets) cannot
be audited against a pack rate. Their 28 animations were judged on kit-internal consistency only, and
all sit inside the house band relative to their peers. The extremes worth knowing about:

- `The Verdant / attack_2` — 4f @ 26 fps = **0.15 s**, the shortest body animation of any character
  (comparable: Whisper `dash_out` 0.14 s, Drifter `rush` 0.17 s, so it's in company).
- `The Ravager / sunder` — 6f @ 13 fps, the slowest non-channel action in the roster; deliberate
  (it's the heavy ground-crack, frame-matched to `sunder_fx` at the same 13).

If the Ravager or Verdant ever feel off, there is no pack rate to fall back on — the reference has to
come from the neighbouring kits.

---

## Verified correct — deliberate deviations, leave alone

Checked and confirmed as intentional, either by an in-code rationale or by an enforced coupling:

| Rate | Ratio | Why it's right |
|---|---|---|
| `brimstone` 36 fps | 3.6× | Ben 2026-07-30, with the reasoning in `characters.gd` — puts the 19f ritual at 0.53 s, in line with `attack` (0.50) and `hell_breach` (0.54) |
| `pact_ritual` 16 fps | 1.6× | Shares the Summon_Ritual sheet with `brimstone` deliberately so the Q summon can read as a ceremony (1.19 s) |
| `hell_breach` body 24 fps | 2.4× | Matches the kit's 0.50–0.58 s beat; 10 fps would be 1.30 s |
| `NECRO_SWIRL_FPS` 12.0 | 1.2× | Documented (`## 1.5 rev/s — pack-native is 10 fps`), and the rise↔orbit coupling is enforced so the spin rate can't seam |
| `blades` 10 / `blades_fx` 30 | 1.0× / 3.0× | Different frame counts (4 vs 12) chosen so **both land on 0.40 s**. The only player animation in the game running at exactly the authored rate |
| `GroundZoneVfx.FPS` 10.0 | 1.0× | `## every pack sheet is authored at 100ms/frame` — verified true across all six tileable elements |
| `StatusVfxFactory.FPS` 10.0 | 1.0× | `## every sheet in both packs is authored at 100ms/frame` — verified |
| `BRIMSTONE_SIGIL_FPS` 10.0 | 1.0× | The d06655b fix; confirmed against `Summon_Demon/AnimationInfo.txt` |
| `telegraph_2d.gd` | derived | Duration-derived **by design** (a telegraph must fill its wind-up), states the authored baseline in code |
| Lab overrides on the Spark (`fireball_2` 28→11, `summon` 18→12, `torrent` 30→13, `damage` 15→12) | 1.1–1.3× | Ben's own Animation Lab edits; all pull *toward* the pack rate, not away |
| Pet house style (idle 8–10 / move 10–12 / attack 14) | ~2× | Consistent across all five companions |

---

## Coverage

- 216 character animations across 12 rosters, measured live post-override.
- 12 world-FX / decal spawn sites in `player.gd`.
- 6 companion/pet sprite builders, 1 projectile, 1 orbit orb.
- `GroundZoneVfx` (6 elements), `StatusVfxFactory`, `player_vfx_helper`, `telegraph_2d`.
- 234 pack info files parsed; 40 referenced sheets have no authored rate (all of `TrueHeroes_v1.0`,
  plus environment/prop art that isn't animated by us).
- `telegraph_speed_scale` was checked as a fourth rate layer — it is set only by boss data factories
  (`heart_of_the_deep`, `warped_colossus`) and never applies to the player.
