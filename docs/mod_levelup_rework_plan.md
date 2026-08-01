# Mod + Level-Up Rework — plan

**Status:** deliberately not started. Ben's note: *"Mods and level up power ups will need reworked
after all characters implemented and locked in."* Written 2026-08-01 so the rework is ready to start
the moment the roster freezes. This is a survey of what is actually there plus a recommendation —
no code has been changed.

## 0. Why it is gated

The roster is 12/12 implemented, but the kits are still moving (three of them changed tonight). Mods
and level-ups both *reach into kits* — `AbilityUpgradeData` targets specific phase anim names, and
`ClassModFactory` mutates choreography phases in place. Every kit edit invalidates some of them. So
the gate is right; this doc just makes sure the rework starts from facts.

## 1. The four systems that all do "power up"

They overlap heavily and none of them knows about the others.

| System | Where | Scope | Count |
|---|---|---|---|
| Generic level-up upgrades | `upgrade_manager.gd:111` `_build_upgrade_pool()` | run-scoped stats + 6 "status" procs | 22 entries |
| Class ability upgrades | `data/ability_upgrades.gd` | run-scoped, kit-specific phase mutations | 37 (3 per kit, 4 for necromancer) |
| Generic weapon mods | `data/mods.gd` + `mod_combo_factory.gd` | persist between runs, slotted in the hub armory | 22 mods, 69 pairs, 8 triples |
| Class mods | `data/class_mods.gd` + `class_mod_factory.gd` | per-class, capability-gated | Fighter pilot only |

**Both mod layers are frozen by direction** (CLAUDE.md, Ben 2026-07-21): weapons are becoming
class-locked and non-transferable, so `mod_interaction_matrix.md` and `weapon-scaling-reference.md`
describe a model the game is leaving. Do not extend them — the rework replaces them.

## 2. Concrete problems worth fixing (observed, not speculative)

1. **The generic pool is 16 stat sticks.** Of 22 entries, 16 are flat/percent stat bumps
   (`+20% Damage`, `+15% Attack Speed`, …). They are never a decision — you take the biggest number.
   The 6 "status" entries (Bloodthirst, Static Discharge, Serrated Strikes, Adrenaline Rush, Thorns,
   Second Wind) are the only generic picks with any texture, and they are one-time-only.
2. **Three ability upgrades per class is not enough to be a build.** `generate_choices` reserves one
   slot per level-up for a class upgrade, so a run exhausts a class's entire identity pool by level
   4 and every level-up after that is stat sticks. This is the single biggest structural problem.
3. **Ability upgrades bind to anim names.** `AbilityUpgradeData` targets `{"anim": "swirl"}` etc.
   Tonight's Paladin change (RMB is now Holy Hammer alone) and the Blood Mage change (the elemental
   left the light chain) are exactly the kind of edit that silently orphans one of these — the
   target simply never matches and the upgrade does nothing, with no error. **Add a startup
   validator that asserts every `target.anim` resolves in its kit** before doing anything else;
   it is cheap and it will find existing rot.
4. **The generic mod layer assumes portable weapons.** With weapons going class-locked, "22 generic
   mods × any weapon" stops being the shape of the system. The 69-pair interaction matrix is
   combinatorics built on an assumption that is being removed.
5. **Silent stat-tag failures.** `ModifierComponent.sum_modifiers` is a plain `tag:operation` lookup,
   so a modifier filed under the wrong pair is never read and never errors. There is at least one
   suspected live instance (`SkillFactory._ward_buff` files damage reduction as
   `("damage_taken","bonus")` while `DamageCalculator` reads `("All","damage_taken")`). A rework
   that adds modifiers without fixing this class of bug will add more of them.

## 3. Recommended shape

**Collapse four systems into two: a run layer and a meta layer.**

### Run layer — what you pick during a descent
- **Drop the pure stat sticks to ~6**, kept only as a "boring but safe" minority, and make them
  scale (a repeatable `+damage` that stacks) rather than 16 distinct one-offs.
- **Grow class ability upgrades from 3 to ~8 per kit**, and allow *ranks* so they can be taken more
  than once. This is where the level-up decision should live: at 8 × 3 ranks a class has a real
  build space and a run never falls back to stat sticks.
- Keep the reserved-slot weighting in `generate_choices` — the mechanism is right, the pool is thin.
- Keep evolutions (`_get_available_evolution`) as the capstone.

### Meta layer — what you bring in from the hub
- Fold **generic mods + class mods into one class-locked mod roster per character**, which is where
  the weapon direction already points. `ModApplicability` (task 31) already resolves capability tags
  and is the right foundation — it survives the rework.
- Retire the 69-pair generic interaction matrix. Per-class rosters give the same "combos matter" feel
  with a fraction of the combinatorics, and each pair can actually be tested.

### Sequencing
1. Freeze the roster.
2. Write the anim-target validator (§2.3) and fix whatever it finds. **Do this first** — it tells
   you how much existing content is already dead.
3. Fix the tag/operation class of bug (§2.5) and add an assertion for unknown tag/op pairs.
4. Expand ability upgrades to 8/kit with ranks. Largest content chunk; purely additive and testable
   per class in the Training Room.
5. Only then touch the mod layers, since class-locked weapons have to land first.

## 4. What not to change
- `ModApplicability` / capability tags — the right abstraction, keep.
- The `op` vocabulary shared by `ClassModData` and `AbilityUpgradeData` (`scale_aoe`, `add_status`,
  `add_projectile_status`, `add_projectiles`, `modifier`). One code path serves both layers; that is
  the good part of the current design and the rework should widen it, not replace it.
- Run-scoped vs persistent separation (`UpgradeManager.reset()` vs `ProgressionManager`). Correct.
