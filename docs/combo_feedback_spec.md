# Combo Cadence Feedback Spec

**Status:** Starter package A + C + E **implemented 2026-07-19** and verified in-engine (signal
chain, ladder SFX playback, pulse modulate, drop gating, channel-tick suppression). Wiring:
`ChoreographyRunner._fire` → `choreo_on_phase_hit` (player.gd) → `EventBus.on_combo_step` →
`AudioManager._on_combo_step` (sfx_combo_step, +1.5 st/step, cap +6); window-lapse →
`choreo_on_chain_timeout` → `EventBus.on_combo_dropped` → `sfx_combo_drop`. One asset pending:
`combo_drop.ogg` — render with REAPER open via `python tools/sfx_forge/recipes_v2.py combo_drop`
then `convert_v2.py` (mutes silently until then). Originally a design brief for Ben's redline,
responding to Clerveu's playtest note: *"borrow heavily from rhythm game principals… don't go all in."*

**Ground truth this is built on:** the combo graph runs on `ChoreographyRunner`
(`scripts/components/choreography_runner.gd`) — `tick()` gates chain-advance on `_hit_fired`
(buffer-during-swing, cancel-at-impact, lines 129–141), so **the moment the hit fires IS the cancel
window opening**. That single fact is what everything below hangs off. Finisher payoff already exists:
`ChoreographyPhase.is_finisher` → `choreo_on_finisher_hit()` (player.gd:1969) → `EventBus.on_finisher_hit`,
6-frame hitstop + 14-intensity shake (`main_arena.gd:43,52`). What's missing is everything *between*
step 1 and the finisher: today every step of a chain sounds identical (`_play_swing_sfx`,
audio_manager.gd:337 — same `sfx_swing_light` per step) and looks identical. The climb has no ladder.

---

## 1. Principles borrowed / rejected

**Borrowed:**
- **Escalation** — feedback grows with streak depth. The cheapest rhythm-game transfer: step 3 must
  sound and read bigger than step 1, even though mechanically it isn't.
- **The player is the metronome** — the game *confirms* the player's cadence rather than dictating one.
  All timing already lives in `ChoreographyPhase.wait_duration` and `CombatInputBuffer`; we surface it,
  we don't tighten it.
- **Legible windows** — rhythm games show you the beat. We show the cancel window opening (it's already
  a discrete runner event) instead of making players feel it out blind.
- **Graceful streak end** — a dropped chain gets a "release" cue, not a fail state.

**Rejected (explicitly, per Clerveu's own caveat):**
- Beatmaps, music-synced timing, any global clock. The combat beat is per-swing, per-player.
- Judgment text (Perfect/Good/Miss) and score meters. Screen is full at 640×360.
- Tighter input windows or timing-gated damage. Buffer-during-swing stays exactly as forgiving as it is.
- Mechanical rewards for tight cadence — listed once below (G) as a labeled option, recommended **deferred**.

---

## 2. Mechanism menu

| # | Mechanism | Feel goal | Systems touched | Size |
|---|---|---|---|---|
| A | Pitch-laddered step SFX | Hear yourself climb | AudioManager, runner→host hook | **S** * |
| B | Micro-hitstop ramp per step | Each step lands heavier | main_arena hitstop (exists) | **S** |
| C | Cancel-window pulse | See the beat, press on it | player sprite modulate tween | **S** |
| D | Step-scaled damage numbers | Depth visible in the numbers | CombatFeedbackManager | **S** |
| E | Chain-drop "exhale" | Streak end without punishment | AudioManager, runner end-path | **S** |
| F | Tight-cadence afterimage | Cosmetic "perfect" without saying it | CombatInputBuffer, sprite ghost | **M** |
| G | "Tempo" micro-buff (mechanical) | Cadence pays stats | StatusEffectDefinition (exists) | **M** |

\* A needs one flagged engine tweak — see below. Everything else runs on existing systems.

**A. Pitch-laddered step SFX.** Each successive node in a light chain plays its swing at a rising
pitch (~+1.5 semitones/step, reset on chain end). Depth is already implicit in the runner's
`_phase_index`; emit a small `on_combo_step(depth, is_finisher)` from the player host at hit-fire
(same spot `_hit_fired` flips, `notify_frame_changed`). **Flag:** `AudioManager.play()`
(audio_manager.gd:184) only does *random* pitch variance — needs an optional `pitch_offset` argument
(~5 lines). Alternative with zero API change: render 3–4 pitched variants per swing via the REAPER
pipeline and pick by depth — more assets, no engine touch. Either way this is the single highest-value
item: it converts mashing into music the player is making.

**B. Micro-hitstop ramp.** Combo steps get 0 / 1 / 2 frames of hitstop by depth; finisher keeps its 6
(`HITSTOP_FINISHER_FRAMES`). Pure data on the existing `_request_hitstop` path. **Risk:** per-hit
hitstop in a horde can feel sticky — gate to melee-combo hits only (they already carry the `"Combo"`
ability tag) and ship behind the existing `HITSTOP_ENABLED` toggle for A/B.

**C. Cancel-window pulse.** One subtle brightness tick on the *player sprite only* (modulate tween,
~0.1 s) at the instant `_hit_fired` flips true — i.e., exactly when a branch may cancel. Teaches
"press when the flash lands" with zero HUD footprint. Runner already has the optional-host-hook
pattern (`choreo_on_phase_anim`); add a sibling `choreo_on_hit_window_open()`. Readability-safe:
touches nothing but the one sprite the player is already watching.

**D. Step-scaled damage numbers.** Melee-combo hits at depth ≥ 2 render slightly scaled/warmed
numbers, reusing CombatFeedbackManager's existing crit-styling machinery (`CRIT_SCALE_MAX` etc.), well
below crit intensity. Cheapest item, but also lowest value — numbers are already dense. Take or leave.

**E. Chain-drop "exhale."** When a chain at depth ≥ 2 ends by *timeout* (runner `_on_phase_exit` →
`default_next = -1`), play a soft downward breath/whoosh. Distinguish timeout from finisher-end and
interrupt (dash/hurt stays silent — the player already knows why those ended). Emotionally this is an
exhale, not a buzzer: the ladder resetting to pitch 1 on the next press does the actual teaching.

**F. Tight-cadence afterimage.** `CombatInputBuffer` keeps `_last_press_ms`, so "press landed within
~120 ms of the window opening" is measurable with a tiny press-age getter. Reward tight cadence with a
brief afterimage/trail on the next swing — cosmetic only, never surfaced as a judgment. This is the
"Perfect" hit with the scoreboard deleted. Defer to v2: it needs the ghost-sprite plumbing and A+C
must exist first for tightness to even be perceivable.

**G. "Tempo" micro-buff (the mechanical option, labeled).** Same trigger as F grants a short
1-stack status (+small attack speed, cap 3) via existing `StatusEffectDefinition` machinery.
**Recommended: don't build yet.** This is precisely the "go all in" trap — it turns a feel layer into
an optimization the wiki will demand you play. If feel-first lands and players *ask* for stakes,
revisit.

---

## 3. Recommended starter package: A + C + E

The three form one closed loop with zero mechanical surface: **C** shows the beat (window opens),
**A** confirms the climb (pitch rises), **E** closes the phrase (breath out, ladder resets). Total
new engine surface: one `pitch_offset` param on `AudioManager.play()`, one optional runner host hook,
one `on_combo_step`-shaped signal. Everything else is data and one modulate tween. Estimated all-in:
a short session, plus a REAPER pass if we go pre-rendered variants for A.

Then B is the one-line follow-up once A+C+E are tuned (it's config on an existing system), D/F/G stay
parked.

---

## 4. Decisions (Ben redline, 2026-07-19)

1. **Pitch ladder source: runtime `pitch_scale`** (Ben confirmed). One `pitch_offset` param on
   `AudioManager.play()`; steps stay retunable as data.
2. **Ladder scope: light chain only** (Claude default, redlineable). The rising pitch covers the
   light-chain taps; the heavy finisher gets no extra accent note — its existing hitstop + shake
   (strongest in the game) already is the accent. Revisit only if finishers feel flat post-ladder.
3. **Pulse placement: character sprite modulate** (Claude default, redlineable). The "press now"
   flash brightens the player sprite itself for ~0.1 s — simplest option, and the player's eyes are
   already there at 640×360. The `_combo_fx` overlay alternative stays in the back pocket if tinting
   character art reads badly.
4. **Micro-hitstop (B): parked** (Ben confirmed). Horde stickiness risk isn't worth it now; revisit
   after A + C + E are tuned, behind the existing `HITSTOP_ENABLED` toggle.
5. **Exhale sound: one universal breath** (Claude default, redlineable). All 10 kits share a single
   soft downward whoosh on chain timeout; per-kit flavor is asset busywork for a deliberately subtle cue.
