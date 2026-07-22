# Verification Findings — Late-Alpha Doc Audit

Generated: 2026-05-02

> **HISTORICAL — do not treat as current state.** This was the finding list for the 2026-05-02 doc
> pass, and other docs still cite it by section ("see verification_findings §5"). Those citations
> point at a snapshot of the codebase from before the combo-chain combat layer, the 12-class roster,
> the two-layer mod system, the passive tree, and descent mode. Several findings here have since been
> resolved (e.g. §8's extraction-window uncertainty — it is 18s, confirmed 2026-07-21).
>
> Superseded by the 2026-07-21 audit; see `docs/doc_audit_2026-07-21.md`.

---

## 1. Effect Types

- **Doc claims:** 15 (`architecture_blueprint.md` line 160; `engine_reference.md` table at line 361 also lists 15)
- **Code shows:** 16 (`scripts/systems/effect_dispatcher.gd`)
- **List (from code):**
  1. DealDamageEffect
  2. HealEffect
  3. ApplyStatusEffectData
  4. ApplyShieldEffect
  5. ApplyModifierEffectData
  6. AreaDamageEffect
  7. DisplacementEffect
  8. SpawnProjectilesEffect
  9. CleanseEffect
  10. ConsumeStacksEffect
  11. GroundZoneEffect
  12. SetMaxStacksEffect
  13. OverflowChainEffect
  14. ResurrectEffect
  15. SummonEffect
  16. **SpawnTelegraphEffect** ← missing from both doc tables
- **Action for docs:** Update `engine_reference.md` effect types table (add `SpawnTelegraphEffect`; update count from 15 → 16). Update `architecture_blueprint.md` line 160 ("15 effect types" → "16 effect types").

---

## 2. Trigger Conditions

- **Doc claims:** `engine_reference.md` (lines 155–162) lists 8 — matches code. `mechanical_vocabulary.md` line 280 claims "14 (6 high-freq + 8 low-freq)" — **mismatch**.
- **Code shows:** 8 conditions in `data/resources/triggers/`
- **List (from code):**
  1. TriggerConditionAbilityId
  2. TriggerConditionEventEntityFaction
  3. TriggerConditionHpThreshold
  4. TriggerConditionNotCrit
  5. TriggerConditionSourceIsSelf
  6. TriggerConditionStatusId
  7. TriggerConditionTargetHitByTag
  8. TriggerConditionTargetIsSelf
- **Action for docs:** Correct `mechanical_vocabulary.md` line 280 from "14 (6 high-freq + 8 low-freq)" to "8". The `engine_reference.md` list already matches.

---

## 3. Ability Conditions

- **Doc claims:** 6 (matches code)
- **Code shows:** 6 in `data/resources/conditions/`
- **List (from code):**
  1. ConditionCorpseExists
  2. ConditionEntityCount
  3. ConditionHpThreshold
  4. ConditionNoActiveSummon
  5. ConditionStackCount
  6. ConditionTakingDamage
- **Action for docs:** No correction needed.

---

## 4. Autoloads

- **Doc claims (CLAUDE.md / `engine_reference.md`):** EventBus, GameManager, ProgressionManager, UpgradeManager, EnemySpawnManager, ExtractionManager — 6 entries.
- **Code shows (`project.godot`):** 8 autoloads:
  1. EventBus → `res://scripts/autoloads/event_bus.gd`
  2. GameManager → `res://scripts/managers/game_manager.gd`
  3. UpgradeManager → `res://scripts/managers/upgrade_manager.gd`
  4. EnemySpawnManager → `res://scripts/managers/enemy_spawn_manager.gd`
  5. ExtractionManager → `res://scripts/managers/extraction_manager.gd`
  6. ProgressionManager → `res://scripts/managers/progression_manager.gd`
  7. **CodexManager** → `res://scripts/systems/codex_manager.gd` ← not in doc list
  8. **LootTables** → `res://data/loot_tables.gd` ← not in doc list
- **Action for docs:** Add CodexManager and LootTables to the autoload list in `CLAUDE.md` (Architecture → Autoloads section) and `engine_reference.md` Key File Locations table.

---

## 5. Character Roster

- **Doc claims:** 7 characters total; `core_framework_decisions.md` describes a "5+2" unlock split. Memory record confirms roster implemented 2026-03-19.
- **Code shows:** 7 characters in `data/characters.gd` (lines 8–146).

| ID | Display Name | Max HP | Armor | Move Speed | Starting Weapon | Passive (summary) |
|----|---|---|---|---|---|---|
| The Drifter | THE DRIFTER | 100.0 | 0.0 | 120.0 | Hurled Steel | Baseline — no passive |
| The Scavenger | THE SCAVENGER | 80.0 | 0.0 | 132.0 | Arcane Blade | +25% Pickup Radius, +15% Loot Find |
| The Warden | THE WARDEN | 150.0 | 5.0 | 96.0 | Warden's Repeater | Armor doubles below 50% HP |
| The Spark | THE SPARK | 60.0 | 0.0 | 126.0 | Spark's Pistol | +50% Crit Damage (2.25× total) |
| The Shade | THE SHADE | 75.0 | 0.0 | 144.0 | Arcane Blade | 15% Dodge; dodge grants 0.5s invisibility |
| The Herald | THE HERALD | 90.0 | 0.0 | 120.0 | Herald's Call | Abilities +30% dmg, −20% cooldown; extra ability slot |
| The Cursed | THE CURSED | 120.0 | 3.0 | 126.0 | Void Mortar | Starts Unsettled; +20% to all base stats |

- **Note:** `data/characters.gd` does not expose a separate `damage` base stat at the character level; damage scaling is handled through the modifier/upgrade system. The research agent found no `damage` field on character definitions. UNVERIFIED — search `data/characters.gd` line by line if a base damage stat is expected at character level.
- **Action for docs:** Roster table in `architecture_blueprint.md` / `systems_design_part1.md` can be updated with these exact values. The 5+2 unlock split needs verification against `ProgressionManager` (not checked in this pass).

---

## 6. Weapon Stats

Source: `data/weapons.gd` (lines 14–200). Doc reference: `docs/weapon-scaling-reference.md`.

| Weapon | Code damage | Code attack_speed | Code projectile_count | Code mod_slots | Doc notes | Status |
|---|---|---|---|---|---|---|
| Hurled Steel | 11.0 | 1.0 | 1 | 2 | Slots=2 ✓ | OK |
| Frost Scattergun | 8.0 | 0.85 | 5 | 2 | 5 proj ✓, slots=2 ✓ | OK |
| Ember Beam | 4.0 | 12.0 | — | 1 | Doc says "12 ticks/sec, 72 DPS base". 4.0 × 12.0 = **48 DPS**, not 72. | **MISMATCH** |
| Lightning Orb | 17.0 | 1.0 | — | 1 | Doc: "3 orbiting orbs, passive". No DPS figure to compare. | OK |
| Void Mortar | 31.0 | 0.40 | — | 2 | No DPS figure in doc. | OK |
| Arcane Blade | 25.0 | 1.8 | — | 2 | Doc says "2.5 swings/sec". Code has **1.8**. | **MISMATCH** |
| Warden's Repeater | 17.0 | 0.55 | 1 | 2 | Slots=2 ✓ | OK |
| Spark's Pistol | 8.0 | 2.0 | 1 | 1 | Doc: "2 shots/sec" ✓ | OK |
| Herald's Call | 6.0 | 0.80 | 1 | 1 | Doc: "Weak auto" — no specific speed claimed | OK |

**Mismatches:**
- **Ember Beam DPS:** Doc claims 72 DPS base (`weapon-scaling-reference.md` line 17). Code: 4.0 damage × 12.0 ticks/sec = 48 DPS. Either damage was reduced from ~6.0 to 4.0, or ticks/sec changed.
- **Arcane Blade attack_speed:** Doc claims 2.5 swings/sec (`weapon-scaling-reference.md` line 20). Code: 1.8.
- **Action for docs:** Correct `weapon-scaling-reference.md` Ember Beam DPS note (72 → 48) and Arcane Blade speed note (2.5 → 1.8).

---

## 7. Hub Panels

- **Doc claims (`architecture_blueprint.md`):** 8 panels: Armory, Workshop, Roster, Records, Research, Launch, Insurance, Codex.
- **Code shows (`scripts/ui/hub_*.gd`):** 7 files:
  - `hub_panel_base.gd` (base class, not a panel itself)
  - `hub_armory_panel.gd`
  - `hub_workshop_panel.gd`
  - `hub_research_panel.gd`
  - `hub_roster_panel.gd`
  - `hub_records_panel.gd`
  - `hub_launch_panel.gd`
- **Missing:** No `hub_insurance_panel.gd` and no `hub_codex_panel.gd` exist. CodexManager is wired as an autoload (`project.godot`) but has no hub UI panel script.
- **Action for docs:** Update panel list in `architecture_blueprint.md` from 8 to 6 implemented panels. Mark Insurance and Codex as "planned / not yet implemented". (Or verify whether Insurance/Codex panels live in scene files rather than dedicated scripts — UNVERIFIED.)

---

## 8. Extraction System Values

Source files: `scripts/managers/extraction_manager.gd`, `scripts/extraction/timed_extraction.gd`, `scripts/extraction/locked_extraction.gd`, `scripts/extraction/guarded_extraction.gd`, `scripts/extraction/sacrifice_extraction.gd`.
Doc reference: `core_framework_decisions.md` §Extraction Timing (lines 284–320).

| Type | Doc channel time | Code channel time | Doc window | Code window | Doc warning | Code warning | Notes |
|---|---|---|---|---|---|---|---|
| Timed | 4s | 4s ✓ | 18s | Not found in extraction files | 10s | Not found | Window/warning UNVERIFIED in code |
| Guarded | 4s | 4.0s ✓ | 25s | 25.0s ✓ | — | Guardian respawn=45s ✓ | WINDOW_DURATION constant matches doc |
| Locked | 2s | 2.0s ✓ | — | Keystone refunded on interrupt ✓ | — | — | Loot bonus not verified in code |
| Sacrifice | Instant | Instant ✓ | — | — | — | — | Availability at Phase 2+ not verified |

- **Timed extraction:** channel_duration base in ExtractionManager is 4.0s ✓. The 18s active window and 10s warning are not confirmed in the extraction files reviewed — may live in main_arena.gd or a timer controller. UNVERIFIED.
- **Action for docs:** No numerical corrections needed for confirmed values. Add "UNVERIFIED" note to timed window/warning in `core_framework_decisions.md` until code path is confirmed.

---

## 9. Phase Scaling Multipliers

Source: `scripts/managers/enemy_spawn_manager.gd` (lines 31–34).
Doc reference: `core_framework_decisions.md` §Phase Scaling Multiplier (lines 187–197).

| Phase | Doc HP | Code HP | Doc DMG | Code DMG | Doc Speed (move) | Code Spawn Rate | Metric match? |
|---|---|---|---|---|---|---|---|
| 1 | 1.0x | 1.0x ✓ | 1.0x | 1.0x ✓ | 1.0x | 1.0x | **No — different metric** |
| 2 | 1.5x | 1.5x ✓ | 1.3x | 1.2x ✗ | 1.1x | 1.2x ✗ | **No** |
| 3 | 2.5x | 2.5x ✓ | 1.6x | 1.4x ✗ | 1.15x | 1.5x ✗ | **No** |
| 4 | 4.0x | 4.0x ✓ | 2.0x | 1.7x ✗ | 1.2x | 1.8x ✗ | **No** |
| 5 | 6.0x | 6.0x ✓ | 2.5x | 2.0x ✗ | 1.25x | 2.2x ✗ | **No** |

**Key issues:**
1. **HP multipliers match exactly** (1.0 / 1.5 / 2.5 / 4.0 / 6.0 ✓).
2. **Damage multipliers are all lower in code** than in the doc. Doc: 1.3/1.6/2.0/2.5. Code: 1.2/1.4/1.7/2.0.
3. **The third column is completely different:** Doc calls it "Speed Multiplier" (enemy movement speed). Code names it `PHASE_SPAWN_MULT` (spawn rate multiplier), with different values (1.2/1.5/1.8/2.2 vs doc's 1.1/1.15/1.2/1.25). There is no `PHASE_SPEED_MULT` array in enemy_spawn_manager.gd. Either the speed scaling was cut or it is applied elsewhere.
- **Action for docs:** Update `core_framework_decisions.md` phase scaling table: correct damage column (3 values changed); replace "Speed Multiplier" column with "Spawn Rate Multiplier" using code values, and note that per-phase enemy move speed scaling is not currently implemented.

---

## 10. Hub UI Redesign Status

Files checked: all 7 `scripts/ui/hub_*.gd`.

All 6 content panels (`hub_armory_panel.gd`, `hub_workshop_panel.gd`, `hub_research_panel.gd`, `hub_roster_panel.gd`, `hub_records_panel.gd`, `hub_launch_panel.gd`) contain the dark industrial color constants (C_CARD, C_AMBER, C_BORDER, etc.) from `hub_ui_redesign_prompts.md`. The redesign is **fully applied** to all existing panels.

- **hub_panel_base.gd** — uses accent_color system + left strip / bottom bar chrome.
- **hub_armory_panel.gd** — full palette: C_CARD, C_AMBER, C_AMBER_HI, C_AMBER_LO, C_RED, C_BORDER, C_B_HOT, C_B_ACT.
- **hub_workshop_panel.gd** — full palette confirmed.
- **hub_research_panel.gd** — full palette confirmed.
- **hub_roster_panel.gd** — full palette confirmed.
- **hub_records_panel.gd** — C_BORDER, C_AMBER, C_T0, C_T2 (simpler panel — expected).
- **hub_launch_panel.gd** — card and border colors match palette inline (lines 54–55).
- **Action for docs:** `hub_ui_redesign_prompts.md` can be updated to note redesign complete for all 6 panels.

---

## 11. Audio

- **Doc claims:** No explicit audio-present claim in current docs; `asset_inventory.md` lists audio asset sources (MiniFantasy SFX packs, etc.) as planned.
- **Code/assets:** No `assets/audio/`, `assets/sfx/`, `assets/sound/`, or `assets/music/` directories exist. The `assets/` directory contains only: `CATALOGUE.md`, `Maps/`, `characters/`, `environment/`, `fonts/`, `minifantasy/`, `pickups/`.
- **Verdict:** Audio assets are completely absent. No audio implementation found.
- **Action for docs:** `asset_inventory.md` should note audio as "not yet integrated" rather than implying it is available. Add a doc note to `engine_reference.md` if AudioStreamPlayer wiring is absent.

---

## 12. Tutorial

- **Doc claims:** `CLAUDE.md` does not list TutorialManager as an autoload. No design doc mandates a shipped tutorial system.
- **Code shows:** No `TutorialManager` script found. No tutorial autoload in `project.godot`. `scripts/entities/player.gd` contains a single comment referencing "Phase 1 is exempt (tutorial phase)" as a hysteresis note, not a wired tutorial system.
- **Verdict:** No tutorial system shipped. Phase 1 serves informally as the tutorial phase.
- **Action for docs:** No correction needed — docs do not claim a tutorial is implemented.

---

## Summary of Doc Updates Needed

### `engine_reference.md`
- Effect types table: add `SpawnTelegraphEffect`; update count from 15 → 16.
- Autoload list: add CodexManager (`scripts/systems/codex_manager.gd`) and LootTables (`data/loot_tables.gd`).

### `architecture_blueprint.md`
- Line 160: "15 effect types" → "16 effect types"; add SpawnTelegraphEffect to the inline list.
- Hub panel list: update from 8 → 6 implemented; mark Insurance and Codex as unimplemented.
- Autoload list: add CodexManager and LootTables.

### `mechanical_vocabulary.md`
- Line 280: "Trigger Conditions | 14 (6 high-freq + 8 low-freq)" → "8".

### `core_framework_decisions.md`
- Phase scaling table (lines 191–197): correct damage column (1.3→1.2, 1.6→1.4, 2.0→1.7, 2.5→2.0); rename "Speed Multiplier" column to "Spawn Rate Multiplier" and replace values (1.1/1.15/1.2/1.25 → 1.2/1.5/1.8/2.2); note enemy move-speed scaling not implemented.

### `weapon-scaling-reference.md`
- Ember Beam row: DPS note "72 DPS base" → "48 DPS base" (4.0 × 12.0 ticks).
- Arcane Blade row: "2.5 swings/sec" → "1.8 swings/sec".

### `CLAUDE.md` (Architecture → Autoloads section)
- Add CodexManager and LootTables to the autoload bullet list.

### `asset_inventory.md`
- Mark audio section as "not yet integrated — zero audio files present in assets/".

### `hub_ui_redesign_prompts.md`
- Note redesign complete for all 6 content panels.

---

## Open Questions

1. **Ember Beam DPS drop:** Was base damage reduced from ~6 to 4, or ticks from 12 to 8? The change is definite but the commit history wasn't checked. Recommend `git log -p data/weapons.gd` to find when it changed.
2. **Timed extraction window/warning:** The 18s active window and 10s warning from `core_framework_decisions.md` were not found in the extraction scripts reviewed. They may live in `scripts/main_arena.gd` or a separate timer node. Recommend grep for `18.0` and `10.0` in arena/extraction code.
3. **Character base damage stat:** `data/characters.gd` may not define a per-character base damage multiplier (damage scaling appears to come from the upgrade system). Recommend reading `data/characters.gd` in full to confirm no `damage` field exists, and update character stat table in docs accordingly.
4. **Enemy move-speed phase scaling:** `PHASE_SPEED_MULT` does not exist in `enemy_spawn_manager.gd`. Either it was cut, or it is applied inside `enemy.gd` at spawn time via a different path. Recommend grep for `phase_speed` or `speed.*phase` in scripts/.
5. **Insurance and Codex hub panels:** No scripts found. Verify whether they are planned-only or if placeholder scenes exist in `scenes/ui/`.
6. **Locked extraction loot bonus (Phase 3+25%, Phase 4+50%, Phase 5+100%):** Not confirmed in code. Recommend reading `scripts/extraction/locked_extraction.gd` fully.

---

## Terminology Pass Applied

| File | Changes |
|------|---------|
| `docs/diagrams.md` | Added note under Diagram 12 (Extraction Flow) that only Timed extraction is shown; 4 types now ship; generalisation pending. |
| `docs/asset_inventory.md` | Replaced tileset table with biome-based mapping matching `ldtk_workflow.md`; updated enemies table `Phase Range` column to `Biome(s)` with biome names; updated ~20 Full Pack Inventory role entries from "Phase X" to biome names or TODO flags; updated audio, palette-strategy, and pipeline summary sections; updated intro strategy section. |
| `docs/core_framework_decisions.md` | Added `<!-- TODO: verify phase vs biome -->` comment above Arena Dimensions table and its companion note; table rows left untouched per constraint. |
| `docs/sprite_catalogue.md` | No changes — uses "phase" only for animation cycles, not run structure. |

---

## Architecture Blueprint Resolution

Took **Option B (slim consolidation).** The original `architecture_blueprint.md` was a pre-implementation design doc; its system specs (LootManager / ArenaManager / AudioManager / UIManager autoloads, JSON arena format, 7-panel hub) diverged from what shipped, and its system map and signal flows are now better-covered by `diagrams.md` and `engine_reference.md`. But two sections still carried unique value: the four Architecture Principles (design philosophy not stated elsewhere) and the Performance Considerations (pooling, enemy cap, particle budget). Rewrote the doc in place around those, plus a save-system policy note that complements (rather than duplicates) `engine_reference.md`'s Save/Load reference. Original preserved at `docs/design_archive/architecture_blueprint_pre_implementation.md`.

---

## Design-Phase Doc Archival

**Date:** 2026-05-02. Originals moved to `docs/design_archive/`.

`systems_design_part1.md`, `systems_design_part2.md`, and `systems_design_part3.md` were Phase 4 design outputs covering all 8 core systems. Most content described forward-looking intent rather than shipped implementation. The following sections were identified as still-current and lifted into active docs:

| Salvaged Content | Source | Destination | Notes |
|-----------------|--------|-------------|-------|
| Enemy Role Taxonomy (6 roles, elite modifiers, special types, phase composition table) | `part2.md` §System 4 | `engine_reference.md` §Enemy Role Taxonomy | Rewritten present-tense. v1.5 types (Parasites, Hive Minds, Phase Bosses) dropped — not designed/implemented. |
| Extraction System (4 types: Timed/Guarded/Locked/Sacrifice, all mechanics and timing values) | `part2.md` §System 6 | `engine_reference.md` §Extraction System | Timing values cross-checked against verification §8. v1.5 features (Unstable/Corrupted/Chain extraction) dropped. |
| Hub stations overview (6 implemented panels + 3 unimplemented) | `part3.md` §System 7 | `docs/hub_reference.md` (new file) | Roster reduced to 6 implemented panels per verification §7. Lore Archive, Codex, Insurance marked as not yet implemented. |
| Arena design principles (no dead ends, spawn from multiple directions, hazards as risk/reward, hidden spots) | `part3.md` §System 8 | `ldtk_workflow.md` §Arena Design Principles | Open-arena layout rules not lifted — design pivoted to LDtk vertical strips; those rules are obsolete. Phase visual theme descriptions not lifted — biome names don't map 1:1 to phases. |

**From `part1.md`:** §Stat list and definitions not lifted. `engine_reference.md` already covers the ModifierComponent implementation fully. The "felt as" design descriptions are intent only, not implementation reference.

**Stale cross-reference fixed:** `ldtk_workflow.md` previously linked to `systems_design_part2.md` for extraction system design; that link now points to `engine_reference.md` where the content lives.
