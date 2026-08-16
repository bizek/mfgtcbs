# Mod + Level-Up Rework — plan

**Status: COMPLETE (2026-08-08).** All five sequencing steps have shipped. Written 2026-08-01 as a
survey + recommendation; steps 1–4 landed between 2026-08-02 and 2026-08-07, and step 5 (the mod
layers) landed 2026-08-08 along with the class-locked weapon prerequisite. The original analysis is
preserved below with per-section outcome notes, because the *reasoning* is still the reference for
why the systems are shaped the way they are.

Read §6 first for what actually happened — including the one measurement that changed the plan.

## 0. Why it is gated

The roster is 12/12 implemented, but the kits are still moving (three of them changed tonight). Mods
and level-ups both *reach into kits* — `AbilityUpgradeData` targets specific phase anim names, and
`ClassModFactory` mutates choreography phases in place. Every kit edit invalidates some of them. So
the gate is right; this doc just makes sure the rework starts from facts.

> **Outcome.** The gate held. All three validators exist and run at startup in debug builds via
> `GameManager._validate_content`, and a fourth (`ClassModData.validate_order`) was added on
> 2026-08-08 after it caught a shipped bug — see §6.

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
1. Freeze the roster. — **done**, 12/12.
2. Write the anim-target validator (§2.3) and fix whatever it finds. **Do this first** — it tells
   you how much existing content is already dead. — **done 2026-08-02**, found 7 dead entries.
3. Fix the tag/operation class of bug (§2.5) and add an assertion for unknown tag/op pairs. —
   **done**, `ModifierComponent._warn_if_unreadable`. The suspected instance was investigated and
   was NOT a bug; correction recorded at the bottom of `polish_plan_2026-08-01.md`.
4. Expand ability upgrades to 8/kit with ranks. — **done 2026-08-07**: 73 entries, 6–7 per kit,
   rankable via `MAX_RANK_BY_OP`, guarded by `validate_kit_order`.
5. Only then touch the mod layers, since class-locked weapons have to land first. —
   **done 2026-08-08**, see §6.

## 4. What not to change
- `ModApplicability` / capability tags — the right abstraction, keep.
- The `op` vocabulary shared by `ClassModData` and `AbilityUpgradeData` (`scale_aoe`, `add_status`,
  `add_projectile_status`, `add_projectiles`, `modifier`). One code path serves both layers; that is
  the good part of the current design and the rework should widen it, not replace it.
- Run-scoped vs persistent separation (`UpgradeManager.reset()` vs `ProgressionManager`). Correct.

> **Outcome — all three held.** `ModApplicability` survived and shrank to one layer;
> `KIT_CAPABILITIES` is still read by `UpgradeManager` for projectile-gated picks. The `op`
> vocabulary was widened, not replaced: mod evolutions reuse it exactly, which is why the capstone
> layer needed no new machinery. Run/persistent separation is untouched.

---

## 5. The measurement that changed the plan

Taken 2026-08-08, before writing any step-5 code. **13 of the 18 generic mods were already dead for
every character in the game**, and had been since combo kits shipped.

`player.gd`'s attack loop gates on `_combo_ability != null`. All twelve characters have a
`melee_kit`, so `_combo_ability` is never null, so `_weapon_ability` — the thing `WeaponFactory`
baked generic mods into — was never fired by anyone. `set_combo_ability` even disconnects the
auto-attack signal explicitly.

| | mods | why |
|---|---|---|
| **Live** | `crit_amp`, `lifesteal`, `multishot`, `instability_siphon` | route through `ModifierComponent` or a player flag; the live-projectile-sync seam in `player.gd` carries `projectile_count`/`pierce`/`projectile_size` into combo projectiles |
| **Live on one weapon** | `size` | read directly by the Lightning Orb orbit path |
| **Dead** | pierce, chain, explosive, fire, cryo, shock, split, gravity, ricochet, accelerating, dot_applicator, napalm, abyssal_pull | baked into a `ProjectileConfig` nothing fires |

Same for the matrix: of 69 pairs + 8 triples in `ModComboFactory`, only **4 pairs and 1 passive**
reached the player. `abyssal_pull` was the final boss's exclusive reward and did nothing.

This made §2.4 an understatement. Retiring the generic layer was not a design sacrifice — it was
mostly deleting code that had not run in months. It also explains a live asymmetry that had gone
unnoticed: the level-up `pierce_up` / `projectile_size_up` picks worked (modifiers) while the *mod*
versions of the same thing did not (ProjectileConfig).

## 6. What shipped — step 5, 2026-08-08

Ben's four calls, then the work.

**Decisions.**
1. **Enforce the class lock**, with the six legacy starters staying universal. Each character now
   sees exactly 9 weapons: its own 3 + the 6 legacies.
2. **Mod slots move onto the character** — 3 slots, drawn from that character's roster. The
   per-weapon `mod_slots` field and `weapon_mods` storage retire.
3. **8 mods per character** (96 total, up from 49) **plus 1–2 mod evolutions** as the capstone.
4. **Collapse the 16 stat sticks to 7 rankable lines**, accepting the evolution-recipe rewrite.

**Prerequisite — the class lock was half-built, which was worse than not built.** 36 of 42 weapons
carried `class_lock`; `WeaponData.get_weapon_class()` had exactly one caller (a roster badge); the
armory listed `unlocked_weapons` raw; and `game_manager.gd` carried a comment asserting a filter
that did not exist. Now: `WeaponData.equippable_for()` is the single gate, applied at **two** sites
— the armory picker *and* the level-up weapon cache, which also drew from `unlocked_weapons` and
would have offered another class's gear mid-run. `get_character_loadout` self-heals stale saves.

**Two bugs found in passing.**
- `ranger_split_quiver` was in `ClassModData.ALL` and read by `player._load_combo`, but **not in
  `ORDER`**. `ids_for_kit` walks ORDER, so SPLIT QUIVER could never drop and never appeared in the
  armory — fully authored, wired, and unobtainable. Same failure shape as the 2026-08-07
  `validate_kit_order` bug, one layer down. Fixed, and `ClassModData.validate_order()` now guards
  both directions plus evolution reachability.
- `game_manager.gd`'s "armory filters by class_lock" comment was false. Rewritten to state what is
  actually true (one flat stash + a UI-level filter).

**The mod layers.** `data/mods.gd` and `data/factories/mod_combo_factory.gd` are deleted.
`WeaponFactory.build_weapon_ability` lost its `active_mods` parameter entirely — removed rather than
defaulted, so it cannot quietly come back — and the file went 673 → 379 lines. `ModApplicability`
collapsed to one layer. Save format is **v2**, with `_migrate_v1_to_v2` dropping `weapon_mods` and
filtering retired ids out of `owned_mods`.

Retired effects that were worth keeping found homes:
- `instability_siphon` → `necro_soul_tithe`, a Shade `kit_flag` class mod. Soul-harvest is that
  character's whole thesis, and this was the only generic mod whose *effect* was worth preserving.
- The boss's `abyssal_pull` reward → a guaranteed unowned mod from your own class roster, which
  works and reads better on a repeat clear with a different character.

**The codex was rebuilt, not deleted.** It was 100% generic-mod content, so retiring the matrix
emptied it. `ComboRegistry` now enumerates the 24 mod evolutions; `CodexManager`, `CodexEntry`,
`MasteryApplicator` and `codex_grid_panel` are all generic over `ModCombo` and were untouched, and
`CodexManager.load_data()` already skipped unrecognised ids, so existing saves just drop stale rows.
`ComboEffectResolver` went from ~380 lines to ~100: **its entire projectile half had zero callers**
— its own docstring carried a step-by-step ProjectileManager integration guide that was never
performed, so no behavior combo had ever recorded a trigger or reached mastery.

**Level-up pool.** 26 entries → 18 (8 stat lines + 10 status procs), but **34 stat picks across
ranks** versus 16 one-offs, so the menu no longer runs dry. Roles from the 2026-08-03 pass are
carried over deliberately — the reservation and weighting logic depends on the crowd/space/survive/
power spread. Five evolution recipes named ids that stopped existing and were rewritten onto the
surviving lines; naming a line twice now means "take it to rank 2", and `_get_available_evolution`
counts copies rather than testing membership (a plain `in` check would have handed out Glass Cannon
at half cost).

**Verified in-engine** (fresh compiles via `CACHE_MODE_IGNORE` — the editor serves stale copies of
edited scripts through their `class_name`, which is exactly what must not be tested against):
96 mods / 8 per kit · 24 evolutions / 2 per kit · 24 codex entries · `validate_order()`,
`validate_anim_targets()` and `validate_status_ids()` all clean · every modifier tag checked against
the set of tags that actually have readers · evolution gating verified at each rank boundary.

Save migration was verified against the committed `tests/save_snapshots/v1.json`, which happens to
be the exact case that matters — it carries `weapon_mods: {"Mercenary's Edge": ["crit_amp"]}` and an
`owned_mods` mixing two generic ids with two class ids. After migration: `weapon_mods` gone,
`lifesteal` and `abyssal_pull` dropped, both class mods preserved, version stamped 2.

### Still open
- **No live playtest.** Everything above is static verification plus editor-side simulation. The mod
  rosters have not been felt in a run, and the 8-per-class numbers are first-pass values.
- The two per-class evolutions are authored but not balanced against each other.
- ~~Mod rarity/pricing was not revisited~~ — resolved in `366f823` (2026-08-10): every mod carries
  a rarity (1 epic / 3 rare / 4 uncommon per kit), drops are depth-weighted, and the merchant
  charges 6/10/16 by tier instead of a flat `MOD_PRICE`. See `docs/polish_plan_2026-08-15.md` §2.3.
