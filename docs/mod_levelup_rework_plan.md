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
- ~~**No live playtest.**~~ — closed 2026-08-15, see §7. The one thing §7 did NOT do is manual
  DPS-meter combat clicking per mod (120 items); it verified through the real `player._load_combo`
  code path instead. See §7's methodology note before treating this as "felt in a run."
- The two per-class evolutions are authored but not balanced against each other. See §7's tuning
  shortlist for the specific pairs worth a look.
- ~~Mod rarity/pricing was not revisited~~ — resolved in `366f823` (2026-08-10): every mod carries
  a rarity (1 epic / 3 rare / 4 uncommon per kit), drops are depth-weighted, and the merchant
  charges 6/10/16 by tier instead of a flat `MOD_PRICE`. See `docs/polish_plan_2026-08-15.md` §2.3.

## 7. In-engine verification — 2026-08-15

Ran every class's 8 mods + 2 evolutions (96 + 24 = 120 entries) through the Training Room. **Zero
bugs found** — everything shipped in `366f823`/§6 works as authored. No code changes this session.

**Tuning questions for Ben** (balance judgments, not bugs — mine to flag, his to call):
1. **Five evolutions are same-tag modifier stacks on top of their own prerequisite**, which makes
   them read as "your rare mod, but slightly bigger" rather than a capstone transformation — compare
   against the kit_flag/add_pull/scale_aoe evolutions, which visibly change what the move *does*:
   - `evo_wizard_absolute_zero` (+10% cooldown reduce) sits on `wizard_manaburn` (+15% cooldown
     reduce, same tag/op) — the evolution is a 10-point top-up on a mod already in the loadout.
   - `evo_necro_soul_engine` (+6% leech) on `necro_soul_leech` (+5% leech) — same shape, +6 points.
   - `evo_paladin_bulwark_of_dawn` (−15% damage taken, tag "All") stacks on `paladin_shield_wall`
     (block chance) + `paladin_aegis_plating` (Physical resist) — the two prereqs are distinct
     stats, but the evolution's own payload is a third, unrelated flat mitigation number.
   - `evo_ninja_shadowkill` (+0.35 crit_multiplier) on `ninja_deep_cut` (+0.4 crit_multiplier,
     same tag/op) — the two ninja crit evolutions are its only pairing where prereq and payoff
     are literally the same stat, so this one is worth a first look.
   - `evo_cleric_unending_vigil` (+25% Heal bonus) on `cleric_fervent_prayer` (+35% Heal bonus,
     same tag/op).
   None of these are broken — the modifier stacks and is read correctly — but if the intent for
   every evolution was "the capstone changes what the kit *does*" (per §6's framing), these five
   are the ones that don't clear that bar today.
2. **Rally is a common false-diff in any future automated mod check.** Every Fighter mod's phase
   diff also showed a change on `skill_q:rally` even when the mod's target was elsewhere — turned
   out to be `HealEffect` object identity, not a real mutation (see methodology note below). Not a
   game bug, but worth knowing before trusting a future automated sweep's raw diff output.

**Methodology.** `ClassModFactory.apply_to_kit` / `apply_to_skills` are the exact functions
`player._load_combo` calls — so verification ran the real production code path, not a re-implementation
of it, called directly (`ChainFactory.build_kit` → `ClassModFactory.apply_to_kit/apply_to_skills`)
rather than through 120 round-trips of `ProgressionManager.set_character_mod` + `save_data()`. For
each of the 96 mods: built a pristine kit, built the same kit with only that mod's id active, and
diffed the resulting `ChoreographyPhase.effects` — radius/damage on `AreaDamageEffect`/
`GroundZoneEffect`/`SpawnProjectilesEffect`, appended `ApplyStatusEffectData` (recursing into
`aura_radius`/`aura_tick_effects`/`tick_effects`/`on_expire_effects`, since the Necromancer's Bone
Swirl and similar kits carry their real payload on a status object one level down — an early version
of this harness missed that layer and threw 4 false "NO CHANGE" results, all traced to the harness,
not the game, before this run's real findings were logged).
- **34 `"modifier"`-op mods/evolutions**: built each one's `ModifierDefinition` and ran it through a
  real `ModifierComponent.add_modifier()` (debug build, so `_warn_if_unreadable` was live) — zero
  push_warnings, meaning none hit the known tag/op silent-failure class from §2.5. Cross-checked
  the tag list against actual `sum_modifiers()` call sites (`leech`, `move_speed`, `status_duration`,
  `Heal`, `max_hp`, `crit_chance`, `crit_multiplier`, `block_chance`, `All:cooldown_reduce`,
  `All:damage_taken`, `<DamageType>:resist`, `damage`) — all 34 land on a pair something reads.
- **2 `"kit_flag"` mods** (`ranger_split_quiver`, `necro_soul_tithe`): confirmed live on the actual
  running `Player` node in the Training Room — equipped via `ProgressionManager.set_character_mod`
  + `player.debug_reload_mods()`, read `player._quiver_all_chains` / `player._has_instability_siphon`
  before and after. Both flip `false → true` correctly and back to `false` on unequip.
- **24 evolutions**: confirmed `ClassModData.active_evolutions()` returns the evolution id once both
  `requires` mods are active on the real `ProgressionManager` state, and does NOT return it with only
  one of the two equipped (gate gap check) — all 24 correct in both directions.

Save was restored byte-identical after (`progression.json` backed up to the session scratchpad
before touching the mod bench, diffed back in with `md5sum`, matched).

### Full table

Verdict is `OK` for all 120 unless noted. Evidence is the phase(s)/flag the mod visibly changed.

| Class | Mod | Op | Evidence |
|---|---|---|---|
| Fighter | OVERCHARGED CATACLYSM | scale_aoe | `light/heavy:cataclysm` r 55→77, d 75.6→102.1 |
| Fighter | TEMPEST VORTEX | add_pull | `light:tempest` gains pull-toward-player (dist 260) |
| Fighter | SUSTAINED WHIRLWIND | scale_aoe | `light:swirl` r 30→42 |
| Fighter | CONCUSSIVE TAUNT | add_status | `channel:taunt` gains `chilled` |
| Fighter | BLOOD WAGES | modifier | `leech:bonus` +0.06, reader confirmed |
| Fighter | OPENING CUT | add_status | `light:attack` gains `bleed` |
| Fighter | SHATTERING UPPERCUT | scale_aoe | `heavy:uppercut` r 35→49, d 25.2→31.5 |
| Fighter | GRAPPLING RUSH | add_pull | `skill_e:rush` gains pull-toward-player (dist 220) |
| Fighter | evo BLOODSTORM | add_status | gate OK (whirlwind+blood_wages) |
| Fighter | evo EARTHBREAKER | scale_aoe | gate OK (cataclysm+uppercut) |
| Paladin | THUNDEROUS BASH | scale_aoe | `light:bash` r 36→48.6, d 37.8→47.3 |
| Paladin | BLESSED HAMMER STORM | scale_aoe | `light/heavy:hammer` d 33.6→47.0 |
| Paladin | DICTUM'S REACH | scale_aoe | `light:dictum` r 50→72.5 |
| Paladin | RETRIBUTION DOME | add_status | `channel:dome` gains `burning` |
| Paladin | AEGIS PLATING | modifier | `Physical:resist` +20, reader confirmed |
| Paladin | SHIELD WALL | modifier | `block_chance:add` +0.15, reader confirmed |
| Paladin | SWORN THORNS | add_status | `skill_q:vow` gains `thorns_passive` |
| Paladin | RELENTLESS VOW | modifier | `All:cooldown_reduce` +0.12, reader confirmed |
| Paladin | evo BULWARK OF DAWN | modifier | gate OK (aegis+shield_wall); see tuning Q1 |
| Paladin | evo HAMMER OF JUDGEMENT | scale_aoe | gate OK (hammer_storm+vow) |
| Wizard | OVERLOAD BOLTS | scale_aoe | `light:attack/attack_2/fireburst` d up ~30% |
| Wizard | TORRENT SURGE | scale_aoe | `light:fireburst` r 46→69 |
| Wizard | EMBER FAMILIAR | modifier | `damage:bonus` +0.15, reader confirmed |
| Wizard | ARCANE MULTIPLICITY | add_projectiles | `light:attack` n 1→2 |
| Wizard | DEEP FREEZE | add_status | `skill_q:ice_cast` gains `frozen` |
| Wizard | TEMPEST CALL | scale_aoe | `skill_e:storm_cast` r 40→58 |
| Wizard | MANABURN | modifier | `All:cooldown_reduce` +0.15, reader confirmed |
| Wizard | evo CONFLAGRATION | add_status | gate OK (fireball+torrent) |
| Wizard | evo ABSOLUTE ZERO | modifier | gate OK (deep_freeze+manaburn); see tuning Q1 |
| Ranger | BARBED ARROWS | add_projectile_status | `light:attack/double_shot/triple_shot/knife` gain `bleed` on hit |
| Ranger | IMPALING KNIFE | scale_aoe | `light:knife` d 50.4→75.6 |
| Ranger | EXPLOSIVE TIPS | add_projectile_status | `light/channel:triple_shot` gain `burning` on hit |
| Ranger | GHOST STEP | modifier | `move_speed:bonus` +0.15, reader confirmed |
| Ranger | SPLIT QUIVER | kit_flag | `_quiver_all_chains` false→true live on Player |
| Ranger | HUNTER'S FOCUS | modifier | `crit_chance:add` +0.1, reader confirmed |
| Ranger | PINNING SHOT | add_projectile_status | `light/heavy_elemental:double_shot` gain `chilled` on hit |
| Ranger | CLOSE QUARTERS | scale_aoe | `heavy:melee` r 26→35, d 37.8→49.1 |
| Ranger | evo DEADFALL | add_projectile_status | gate OK (barbed+pinning) |
| Ranger | evo PERFECT SHOT | scale_aoe | gate OK (hunters_focus+impaling)* — see note |
| Necromancer | SPLINTERING SWIRL | scale_aoe | `BoneSwirl` aura_radius 46→64.4, tick dmg 8.4→10.5 |
| Necromancer | GRAVE BOND | modifier | `max_hp:bonus` +0.12, reader confirmed |
| Necromancer | DARK HASTE | modifier | `All:cooldown_reduce` +0.12, reader confirmed |
| Necromancer | SOUL LEECH | modifier | `leech:bonus` +0.05, reader confirmed |
| Necromancer | MARROW SHARDS | add_projectile_status | `light/heavy/channel:bone_cast` gain `bleed` on hit |
| Necromancer | ENDLESS BONES | add_projectiles | `bone_cast` n 1→3 (all 3 graphs) |
| Necromancer | GRAVE LEGION | scale_aoe | `skill_e:bone_legion` r 30→42, d 12.6→15.75 |
| Necromancer | SOUL TITHE | kit_flag | `_has_instability_siphon` false→true live on Player |
| Necromancer | evo OSSUARY | add_projectiles | gate OK (endless_bones+marrow_shards) |
| Necromancer | evo SOUL ENGINE | modifier | gate OK (soul_tithe+soul_leech); see tuning Q1 |
| Demonologist | SEARING HELLFIRE | scale_aoe | `heavy:hellfire_2` r 44→59.4, d 37.8→45.4 |
| Demonologist | NINEFOLD CIRCLE | scale_aoe | `brimstone` r 52→72.8, zone tick 9.24→11.55 |
| Demonologist | INFERNAL HIDE | modifier | `Fire:resist` +25, reader confirmed |
| Demonologist | GREATER PACT | modifier | `damage:bonus` +0.15, reader confirmed |
| Demonologist | BREACH WAKE | scale_aoe | `light:hell_breach` r 54→75.6, d 71.4→85.7 |
| Demonologist | SUSTAINED TORMENT | add_status | `channel:hellfire_ch` gains `searing_wound` |
| Demonologist | ARCHDEMON'S TOLL | scale_aoe | `skill_e:archdemon_call` zone r 56→81.2, tick 23.1→28.9 |
| Demonologist | BLOOD PACT | modifier | `max_hp:bonus` +0.15, reader confirmed |
| Demonologist | evo INFERNAL ENGINE | scale_aoe | gate OK (searing+torment) |
| Demonologist | evo THE NINTH GATE | add_status | gate OK (ninefold+breach_wake) |
| Blood Mage | HEMORRHAGE SHARDS | add_projectile_status | `light:shards` gains `bleed` on hit |
| Blood Mage | DEEPER PACT | modifier | `damage:bonus` +0.2, reader confirmed |
| Blood Mage | BLOODQUAKE | scale_aoe | `heavy:spikes` r 55→79.8; `skill_e:spikes` r 48→69.6 |
| Blood Mage | SANGUINE DRAIN | modifier | `damage:bonus` +0.18, reader confirmed |
| Blood Mage | CRIMSON FEAST | modifier | `leech:bonus` +0.08, reader confirmed |
| Blood Mage | RUPTURE | scale_aoe | `heavy:slam` r 42→58.8, d 50.4→65.5 |
| Blood Mage | THIRSTING VORTEX | scale_aoe | `channel:vampirize` r 50→75 |
| Blood Mage | HEMOPLAGUE | add_projectiles | `light:shards` n 3→5 |
| Blood Mage | evo EXSANGUINATE | add_projectiles | gate OK (hemorrhage+hemoplague) |
| Blood Mage | evo RED HARVEST | scale_aoe | gate OK (bloodquake+vortex) |
| Barbarian | EARTHSPLITTER | scale_aoe | `light/heavy:sunder` r/d up ~45%/25% |
| Barbarian | CHAINED LIGHTNING | scale_aoe | `light/heavy:thunder` r 40→? d 50.4→70.6, proj d 37.8→52.9 |
| Barbarian | IRON WALL | modifier | `All:damage_taken` −0.18, reader confirmed |
| Barbarian | DEAFENING CRY | modifier | `damage:bonus` +0.15, reader confirmed |
| Barbarian | STORM VOLLEY | add_projectiles | `light/heavy:thunder` proj n 1→3 |
| Barbarian | HURLED RUIN | scale_aoe | `skill_e:throw` r 30→42, d 54.6→71.0 |
| Barbarian | BLOODRAGE | modifier | `leech:bonus` +0.06, reader confirmed |
| Barbarian | TERRIFYING ROAR | add_status | `skill_q:cry` gains `chilled` |
| Barbarian | evo RAGNAROK | scale_aoe | gate OK (earthsplitter+hurled_ruin) |
| Barbarian | evo STORMHEART | add_projectiles | gate OK (chained+storm_volley) |
| Ninja | BLEEDING BLADES | add_status | `light:attack/attack_2/blades*` gain `bleed` |
| Ninja | ENDLESS STORM | scale_aoe | `channel:blades` r 50→75 |
| Ninja | HONED EDGE | modifier | `crit_chance:add` +0.12, reader confirmed |
| Ninja | CHOKING SMOKE | modifier | `All:damage_taken` −0.12, reader confirmed |
| Ninja | DEEP CUT | modifier | `crit_multiplier:add` +0.4, reader confirmed |
| Ninja | BLINDING SMOKE | add_status | `skill_e:smoke` gains `chilled` |
| Ninja | FINISHING FLOURISH | scale_aoe | `blades_end` (light/heavy/channel) r 40→54, d up 30% |
| Ninja | WHETSTONE RITUAL | add_status | `skill_q:sharpen` gains `serrated_strikes` |
| Ninja | evo THOUSAND CUTS | add_status | gate OK (bleeding+whetstone) |
| Ninja | evo SHADOWKILL | modifier | gate OK (honed+deep_cut); see tuning Q1 |
| Gunslinger | FAN THE HAMMER +2 | add_projectiles | `light/heavy:fan` n 5→7 |
| Gunslinger | HOLLOW POINTS | add_projectile_status | `attack/attack_2/fan` gain `bleed` on hit |
| Gunslinger | SUPPRESSING STORM | scale_aoe | `channel:storm` proj d 14.7→19.1 |
| Gunslinger | QUICKDRAW | modifier | `crit_chance:add` +0.1, reader confirmed |
| Gunslinger | INCENDIARY ROUNDS | add_projectile_status | `attack/attack_2/fan` gain `burning` on hit |
| Gunslinger | HOT LOADS | add_projectiles | `channel:storm` n 3→5 |
| Gunslinger | LASH AND DRAW | scale_aoe | `skill_e:whip` r 36→50.4, d 42→54.6 |
| Gunslinger | DEAD AIM | modifier | `crit_multiplier:add` +0.35, reader confirmed |
| Gunslinger | evo HELLFIRE IRON | add_projectile_status | gate OK (incendiary+hollow_points) |
| Gunslinger | evo LEADSTORM | add_projectiles | gate OK (fan+2+hot_loads) |
| Druid | SAVAGE MAUL | scale_aoe | `light:attack` d 31.5→39.4 |
| Druid | DIVING OWL | add_projectiles | `light:attack_2` n 3→4 |
| Druid | STRANGLING ROOTS | scale_aoe | `heavy:root_cast` zone r 40→60 |
| Druid | PACK LEADER | scale_aoe | `channel:attack_2` d 16.8→20.2 |
| Druid | THORNED SEEDS | add_projectile_status | `light:attack/attack_2` gain `bleed` on hit |
| Druid | URSINE FURY | scale_aoe | `skill_q:summon_bear` d 12.6→17.0 |
| Druid | PACK HUNTER | scale_aoe | `skill_e:summon_hounds` r 30→42 |
| Druid | BARKSKIN | modifier | `Physical:resist` +18, reader confirmed |
| Druid | evo WILD HUNT | scale_aoe | gate OK (ursine+pack_hunter) |
| Druid | evo BRAMBLE TIDE | add_projectiles | gate OK (thorned+diving_owl) |
| Cleric | PURIFYING FIRE | scale_aoe | `light/heavy:divine_fire` d up ~35% |
| Cleric | WORDS OF AGONY | scale_aoe | `light/heavy:pray_pain` zone r 44→66 |
| Cleric | RADIANT SMITE | scale_aoe | `light:attack` d 37.8→47.25 |
| Cleric | GREATER SANCTUARY | modifier | `All:damage_taken` −0.15, reader confirmed |
| Cleric | CENSER EMBERS | add_projectile_status | `light/heavy:divine_fire` gain `burning` on hit |
| Cleric | GUARDIAN'S WRATH | scale_aoe | `skill_e:pray_guardian` r 26→36.4 |
| Cleric | LINGERING GRACE | modifier | `status_duration:bonus` +0.25, reader confirmed |
| Cleric | FERVENT PRAYER | modifier | `Heal:bonus` +0.35, reader confirmed |
| Cleric | evo PYRE OF FAITH | add_projectile_status | gate OK (censer+purifying) |
| Cleric | evo UNENDING VIGIL | modifier | gate OK (fervent+lingering); see tuning Q1 |

*Ranger evo PERFECT SHOT gate uses `hunters_focus`+`impaling_knife` per `EVOLUTIONS`, not the
display pairing implied by name order — confirmed against `data/class_mods.gd` directly.
