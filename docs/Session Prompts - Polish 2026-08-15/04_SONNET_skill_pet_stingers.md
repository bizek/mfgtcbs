# Task 04: Skill and pet stingers — close RTR task 15

> **Tier:** 2 → Sonnet-class · **Depends on:** 01 committed; Ben's gate D-A (un-exclude audio)
> **Not parallel with Task 03** (both may touch `sound_table.gd`).
> **Est. tokens:** ~1.5k in / ~3k out · Paste everything below the rule into a fresh session.

---

<goal>
Q/E skill casts and pet events have no voice. This is the last remainder of Road-to-Release
task 15 (audio wiring): weapon fire, dashes, and channel beds are done or in flight; skills and
pets are not started. Give them a small, category-keyed stinger set and wire it.
</goal>

<context>
- Verified 2026-08-15: `data/factories/sound_table.gd` has NO `sfx_skill*` / `sfx_pet*` /
  `sfx_summon*` entries. The dash pass is the template to copy: four shared stingers keyed by
  category (`sfx_dash_generic/teleport/deadly/dodge_roll`, entries at `sound_table.gd:315-330`,
  files in `assets/audio/sfx/dash/`, synthesized in-house via REAPER).
- Weapon-fire SFX are wired via the `on_ability_used` event (2026-07-09) — read how before
  choosing the skill seam. Skills live in `SkillComponent` (player-only, Q/E slots, built by
  `SkillFactory`); find where a successful cast is signalled and whether `on_ability_used`
  already fires there.
- Pets are autonomous entities (FireFamiliar, BloodElemental, Angry Demon, the Shade's
  summons…). The two moments worth voicing: **summon arrival** and, if cheap, a pet's first
  attack. Do not voice every pet hit — the mix is already dense.
- Scope discipline: a SMALL set of shared stingers keyed by category (e.g. cast_buff,
  cast_offensive, cast_movement, summon_arrive), NOT one sound per skill. 4–6 new assets total.
- Docs to consult: `docs/audio_pipeline.md` for the REAPER render path,
  `docs/audio_asset_manifest.md` to record the new assets.
</context>

<requirements>
- Pick each skill's category from data (the `SkillFactory` definitions), not from a hand-written
  per-skill map, so future skills get a voice automatically. A `skill_sound_category` field or a
  derivation from existing skill data — prefer derivation if the data supports it.
- Wire through the existing event/dispatcher seams; do not invent a new audio path.
  **Check for `cooldown_base = 0.0` cases** before hooking anything that fires on use — an
  effect that fires on the player immediately at build time must not stinger at spawn.
- Synthesize the assets via the REAPER MCP (render to `assets/audio/_incoming/`, move into
  place), matched in loudness to the dash stingers.
- Verify in the **Training Room only** (F11, HIT BACK OFF, filter event logs by
  `source == player`): cast Q and E on at least three kits with different categories, summon at
  least two different pets. Back up `progression.json` first; restore after.
- Update `docs/audio_asset_manifest.md` and mark task 15 CLOSED in
  `docs/Session Prompts - Road to Release/00_EXECUTION_PLAN.md`'s status table if nothing else
  remains there.
</requirements>

<output_format>
Assets + SoundTable entries + the one wiring seam, committed as one grouped conventional commit.
Report: the category derivation chosen, the seam used, per-kit verification results, and both
status tables updated.
</output_format>
