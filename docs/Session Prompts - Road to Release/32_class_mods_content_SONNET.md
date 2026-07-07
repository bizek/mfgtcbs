# Task 32 — Class mods: full content pass
**Tier**: 2 → Sonnet | **Depends on**: 31 (architecture + Ben-approved `docs/class_mod_system.md`). Parallel-safe with 33.

---

<goal>
Author every class mod approved in `docs/class_mod_system.md` (3–4 per class × 12 classes,
minus the 2 Fighter pilots task 31 already shipped) and finish the integration surfaces.
</goal>

<context>
- `docs/class_mod_system.md` is AUTHORITATIVE — implement the approved table, do not re-design.
  The Fighter pilots from task 31 are the exact pattern: data entry → factory seam → effect.
- CLAUDE.md rules apply: data files are @export/static data only, effects route through
  EffectDispatcher, ModifierDefinition for stats, StatusEffectDefinition for timed effects,
  watch cooldown_base=0.0 self-fire, new statuses handle missing keys defensively.
</context>

<requirements>
- All class mods implemented and validate-compiled; each verifiably changes its target ability
  (list a one-line test recipe per mod for Ben's playtest).
- Drop integration: class mods appear in loot at the weight the design doc specifies, only for
  the matching class; generic-mod filtering (task 31) confirmed working for every class (spot
  check: melee-only kit sees no projectile-behavior mods in a full debug run).
- Armory: class mods render with class tag/color, equip/unequip works, greyed state for
  wrong-class mods per the task-31 decision. Check panel overflow at 3× (CLAUDE.md armory rule).
- Codex: class mods listed per the task-31 decision (own section or excluded — follow the doc).
- Save/load round-trip with equipped class mods; old saves load clean.
- Update `docs/class_mod_system.md` status column (designed → shipped) and
  `docs/mechanical_vocabulary.md` with the new mod family vocabulary.
</requirements>

<output_format>
Data + integration code, grouped conventional commits (content vs integration). Summary: per-class
shipped-mod table + Ben's per-mod test recipes.
</output_format>
