# Task 33 — Level-up rework: class filtering + ability upgrades
**Tier**: 2 → Sonnet | **Depends on**: 31 (shared applicability model + approved design doc). Parallel-safe with 32.

---

<goal>
Rework the in-run level-up pool (locked with Ben, 2026-07-06): (1) **filter generic stat
upgrades by class relevance** using task 31's applicability resolver, and (2) **add per-class
ability upgrades** to the pool — in-run boosts to the class's own combo/skills (e.g. "+1
Whirlwind tick", "Fireball radius +30%", "Smoke Bomb cooldown −20%"). Evolutions stay, gated
where their ingredients are class-gated.
</goal>

<context>
- `scripts/managers/upgrade_manager.gd`: 22-entry generic pool + 12 evolution recipes. The
  existing `requires_melee` flag on Reach (generate_choices reads `melee_kit`) is the primitive
  this generalizes — REPLACE it with task 31's capability-tag resolver, one shared model across
  mods and upgrades, not two filtering systems.
- Dead picks to eliminate by filtering (verify per kit, don't assume): Multi Shot / Pierce /
  Bigger Shots on kits that emit no projectiles; Reach on kits with no melee hits. A kit's
  capability tags (task 31) answer this.
- Per-class ability upgrades live in a data file keyed by `melee_kit` (ModData/CharacterData
  style), applied through the same factory seam class mods use (kit param overrides /
  build_combo_modifiers pattern) but as IN-RUN, run-scoped boosts — they reset with
  UpgradeManager.reset(), never persist.
- Evolutions: execute D2 from `docs/design_audit_2026-07-06.md` — prune the 12 recipes to the
  ~6 most distinctive (Juggernaut/Fortress are the same recipe twice; kill redundant pairs),
  then audit each survivor's `requires` against filtered pools (an evolution whose ingredient
  can't appear for a class must not dangle); add 1–2 class-flavored evolution ideas to the
  summary for Ben if natural pairs emerge (don't implement without approval).
- `docs/class_mod_system.md` (task 31) should already sketch the per-class upgrade direction —
  follow it where it does; propose in-style where it's silent.
</context>

<requirements>
- generate_choices(): pool = filtered generics + the current class's ability upgrades, sensibly
  weighted (ability upgrades should feel special but not crowd out stats — state your weighting).
- 2–3 ability upgrades per class × 12 classes, each targeting a real kit element, each
  verifiably changing the ability in-run.
- Level-up panel: renders the new entries cleanly — class-colored accent or tag for ability
  upgrades; CHECK OVERFLOW before declaring done (CLAUDE.md level-up panel rule, 3× scaling).
- Full-run smoke test per archetype (one melee, one ranged, one caster kit): no dead picks
  offered, ability upgrades apply and reset next run.
- Passive-tree interaction sanity: tree bonuses (permanent) and level-up upgrades (run-scoped)
  stack by design — confirm no double-application through the shared seams.
</requirements>

<output_format>
UpgradeManager + data file + panel tweaks, grouped conventional commits. Summary: per-class
upgrade table, weighting rationale, filtering matrix (class × hidden generics).
</output_format>
