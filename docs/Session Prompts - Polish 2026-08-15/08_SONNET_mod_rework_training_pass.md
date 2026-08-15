# Task 08: Mod rework verification pass — Training Room, all twelve classes

> **Tier:** 2 → Sonnet-class · **Depends on:** 01 committed · No decision gate.
> Run BEFORE tasks 09/11 stack content on an unfelt system. This is the systematic half; Ben's
> real felt playtest is separate and still wanted.
> **Est. tokens:** ~1.5k in / ~4k out · Paste everything below the rule into a fresh session.

---

<goal>
The mod rework (96 class mods across 12 characters + 24 evolutions) shipped verified statically
and in editor-side simulation, but has never been systematically exercised in-engine. Run every
class's mod roster through the Training Room, fix outright bugs on the spot, and hand Ben a
tuning-question list — bugs are yours, balance is his.
</goal>

<context>
- Status source: `docs/mod_levelup_rework_plan.md` §"Still open". **Re-read it first** — if a
  later session already ran this pass, narrow to what it left open or stop.
- The Training Room has a mod bench (landed `e88481e`) — mods can be applied in the room without
  a run. F11 panel: live class swap, dummy spawn, DPS meter. Class swap from INSIDE the room must
  go through the panel's own `_cycle_class` (CLAUDE.md documents the `_exit_tree` footgun that
  otherwise silently turns the room into a real run — re-read that section before starting).
- Known silent-failure classes to watch for, all with precedent in this repo: modifier
  tag:operation pairs that nothing reads (a validator guards SOME of this — check what it
  covers), `target.anim` names that no phase carries, statuses that don't resolve, and effects
  that fire instantly when `cooldown_base = 0.0`.
- HIT BACK OFF except when testing damage-taken mods; filter event logs by `source == player`.
</context>

<requirements>
- **Back up `progression.json` before entering the engine** — the mod/allocation paths call
  `save_data()`. Restore byte-identical after.
- Per class: apply each of its 8 mods one at a time; confirm each produces a MEASURABLE change
  (DPS meter delta, visible status, log line — name the evidence per mod). Then both evolutions.
- Restart the played scene whenever GDScript changed mid-pass — the process caches compiled
  scripts.
- Fix outright bugs (mod does nothing, wrong target, crash) in place. Tuning judgements
  (too strong / too weak / two evolutions unbalanced against each other) go to the report, not
  the code.
- Keep a running table: class · mod · evidence · verdict (works / fixed / tuning question).
</requirements>

<output_format>
1. Fixes committed (one grouped conventional commit if any).
2. The full 96+24 table appended to `docs/mod_levelup_rework_plan.md` under a dated
   "In-engine verification 2026-08-XX" heading, with the tuning-question shortlist for Ben at
   the top.
3. 00_EXECUTION_PLAN status table updated; confirm the save was restored and `git status` clean.
</output_format>
