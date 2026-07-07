# Task 31 — Class mod & upgrade architecture (two-layer design + plumbing)
**Tier**: 3 → Opus (cross-system design: loot, armory, codex, combo runner, level-ups)
**Depends on**: 30 (all 12 classes exist — the design doc must cover every kit) AND 34 (class
gear & rarity system — mods equip onto that gear; D1 in `docs/design_audit_2026-07-06.md` §3.1
was RESOLVED as class-locked rarity gear, so the two-layer mod model below stands as designed:
generic mods + class mods, socketed into gear whose rarity sets slot count). Blocks 32, 33.

---

<goal>
Design and plumb the **two-layer mod model** (locked with Ben, 2026-07-06) so mod/upgrade content
matches the per-class combat kits:
1. **Generic layer** — the existing weapon mods (`data/mods.gd`) stay, but gain **applicability
   tags** and are filtered so a class never sees mods that do nothing for its kit ("you don't see
   the Spark mods while playing as the Drifter").
2. **Class layer** — a NEW ability-mod family: per-class mods that modify that class's combo
   nodes, RMB special, Q/E skills, or dash (e.g. "Swirl pulls enemies in", "Fireball leaves
   burning ground", "Fan the Hammer +2 shots").

This task delivers the architecture, the design doc for all 12 classes, and a working pilot.
Task 32 authors the full content; task 33 applies the same applicability model to level-ups.
</goal>

<context>
Ground truth to read first (verify in the working copy, docs may lag):
- Every character runs a combo kit and DROPS weapon auto-fire — `player.gd::set_combo_ability`
  ("the combo IS the attack"). Mods already reach combos via `WeaponFactory.build_combo_modifiers`
  / `build_combo_passives` (see player.gd ~460-500) — that seam is the precedent for the class layer.
- `data/mods.gd` (15 generic mods), `data/factories/mod_combo_factory.gd` + the 69-pair combo
  matrix + Codex discovery (CodexManager), armory equip flow, mod pickups as extractable loot,
  mod slot enforcement, insurance valuation — ALL currently assume one flat mod pool. Map every
  touchpoint before designing.
- ChainFactory/SkillFactory build the kits from data; combo phases fire through
  EffectDispatcher. Class mods should modify kit DATA at build time (phase params, effect
  values, added effects) or attach statuses/modifiers — never bespoke per-mod code paths.
</context>

<requirements>
ARCHITECTURE (implement):
- Applicability model: tags on each generic mod (e.g. `requires: ["projectile"]`,
  `requires: ["melee_hit"]`) matched against per-kit capability tags derived from
  CharacterData/ChainFactory (a kit declares what it emits: projectiles, melee hits, statuses…).
  One shared resolver used by loot rolls, the merchant, the armory, and (task 33) the level-up
  pool. Decide and document the edge case: what happens to an ALREADY-OWNED mod when the player
  switches character (recommendation: armory shows it greyed "no effect for this class", never
  destroyed — loadouts are per-character anyway).
- Loot: drop rolls draw from the applicable pool for the CURRENT character (plus class mods for
  that class at some weight). Unusable drops must be impossible mid-run.
- Class-mod family: a `class_mods` data file/section in the ModData style — id, class, target
  (combo phase / skill id / dash), effect params, color, desc. Applied at kit build time through
  one factory seam (ChainFactory/SkillFactory param overrides or the build_combo_modifiers
  pattern). Zero behavior in data files (CLAUDE.md).
- Codex/combo matrix: generic-mod combos keep working; decide + document how class mods interact
  (recommendation v1: class mods do NOT participate in the elemental combo matrix — keep the 69
  pairs intact; note it as future space). Codex discovery must not regress.
- Check insurance valuation + save/load for the new mod kind (defensive .get(), old saves clean).

DESIGN DOC (deliverable for Ben's approval — content itself is task 32):
- `docs/class_mod_system.md`: the architecture above, plus a per-class table of **3–4 proposed
  class mods for each of the 12 classes**, each tied to a real kit element (read every kit in
  ChainFactory/SkillFactory — no invented abilities), with effect sketch + drop source.

PILOT (proof the seam works):
- Implement 2 class mods for the Fighter end-to-end (data → drop → armory equip → visible
  in-run effect on the combo), validate-compiled and smoke-tested. This locks the pattern task
  32 mass-produces.
</requirements>

<output_format>
Plumbing code + docs/class_mod_system.md + 2 pilot mods, grouped conventional commits. Summary:
the architecture decisions, the touchpoint list, and the per-class mod table for Ben's redline.
Ben approves the doc before task 32 runs.
</output_format>
