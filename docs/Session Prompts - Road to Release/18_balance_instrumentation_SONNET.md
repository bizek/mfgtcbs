# Task 18 — Balance instrumentation + tuning pass
**Tier**: 2 → Sonnet | **Depends on**: 16 + 17 in, and Ben's playtest notes available. Run LAST in M5.

---

<goal>
Instrument the descent for balance data, then apply a tuning pass combining the data with Ben's playtest notes (paste them below before running this session).
</goal>

<context>
- Formulas + intended curves: `docs/core_framework_decisions.md` (damage, XP, phase timing, enemy scaling, instability, economy) — this is the source of intent; tuning means moving numbers toward those curves.
- Run shape: 10-block Caves descent, merchant ~50% depth, boss-gated portal. 10 combo-kit characters (12 once Druid/Cleric ship) — per-character outlier analysis must account for kit differences (melee vs ranged combo kits), not just stats.
- Run AFTER the second pacing pass (task 29) and the class mod/level-up rework (tasks 31–33) — tuning against the old pace or the generic mod pool would be wasted work.
- Existing debug tooling: `GameManager.debug_mode`, F1–F5, debug panel, entity inspector.

**BEN'S PLAYTEST NOTES:** [PASTE PLAYTEST NOTES HERE — per-character feel, difficulty spikes, boring stretches, merchant pricing reactions, boss difficulty]
</context>

<requirements>
Instrumentation (build first):
- End-of-run balance report written to `user://run_report_<timestamp>.json` and printed to console in debug mode: per-block time + kills + damage taken, XP/level curve over time, gold earned/spent, weapon + mods used, death cause or extraction time, character id.
- Zero per-frame cost when debug_mode is off.

Tuning (data + notes driven):
- Time-to-kill curve across blocks 1→8 vs the intent in core_framework_decisions.md; XP pacing (target: steady level-ups, no dead stretch past mid-descent); merchant pricing vs typical gold-on-arrival; boss HP/damage vs an average build at portal depth; per-character outliers (any character >20% off the median clear performance per the notes).
- Change data values (enemy data factories, level_data, weapon data, spawn manager curves) — not systems. Every change: one line in the summary with old → new and the reason.
</requirements>

<output_format>
Instrumentation code + data-value changes, separate conventional commits (instrumentation vs tuning). Summary: tuning changelog table.
</output_format>
