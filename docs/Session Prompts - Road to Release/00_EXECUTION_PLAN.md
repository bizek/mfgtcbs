# Execution Plan — Road to Release (M1–M7 + M2.5)

Generated 2026-06-10 by Prompto. **Audited + updated 2026-07-06**: prompts 01–03 and 05–08 are
done (archived to `docs/Archived Session Prompts - Completed/` with an `rtr_` prefix);
**04 (win state) was skipped and is still open**; new Phase M2.5 added for the combo-combat /
class-identity consolidation (pacing pass 2, roster completion, passive tree 26–28, class
mod + level-up rework); prompts 13/16/18/19/20/21/25 revised for the 10-class combo-kit
combat model. Each numbered file in this folder is a self-contained session prompt. Paste one
prompt per fresh Claude Code session in this repo (CLAUDE.md auto-loads, so prompts reference
repo files instead of inlining them).

## How to Use

| Suffix | Tier | Model | Use for |
|--------|------|-------|---------|
| HAIKU | 1 — Light | claude-haiku-4-5 | Mechanical, low-risk tasks |
| SONNET | 2 — Standard | claude-sonnet-4-6 | Implementation from clear spec |
| OPUS | 3 — Heavy | claude-opus-4-8 | Architecture, design, cross-system work |

Run phases in order. Tasks inside a phase marked ∥ can run in parallel sessions
(no shared files). Move completed prompts to `docs/Archived Session Prompts - Completed/`.

## Phases

### Phase M1 — Close out the core loop ✅ (except 04)
- ~~01 [HAIKU] Commit cleanup~~ ✅
- ~~02 [SONNET] Boss spawning from LdtkLevelDirector~~ ✅
- ~~03 [SONNET] Inner block variants + altar markers~~ ✅ (block compiler now generates blocks)
- 04 [SONNET] **STILL OPEN** — Win state: win flow, credits, account flag (audit 2026-07-06:
  no win/credits/game-cleared code exists in scripts). Tasks 10, 21, 22, 25 reference it.
- **HUMAN (Ben):** paint `PropCollision` IntGrid layer in the LDtk GUI (see `docs/ldtk_schema.md` §2.1)

### Phase M2 — Character Overhaul ✅
- ~~05–08~~ ✅ — and the scope grew beyond the original plan: 10 characters live with per-class
  combo kits (LMB chains, RMB specials, Q/E skills, class dashes), manual cursor-aim default,
  quadrant facing. See `docs/character_overhaul_design.md`, `docs/combat_chain_architecture.md`.

### Phase M2.5 — Combat & class identity (added 2026-07-06; run before M5 balance work)
- 29 [SONNET] ∥ Pacing second pass — a further ~15–20% slowdown, "even more methodical"
- 30 [OPUS] Roster completion — The Druid + The Cleric (12/12; kit design needs Ben's approval)
- 26 [SONNET] ∥ Passive tree backend (data, points, save/load, run-start apply)
- 27 [OPUS] Passive tree behavior nodes — after 26
- 28 [OPUS] Passive tree hub UI — after 26 (affinity table benefits from 30)
- 34 [OPUS] Class gear & rarity system — class-locked themed weapons, 2 trinket slots,
  green/blue/purple, smart-loot bias (D1 RESOLVED — design in `design_audit_2026-07-06.md` §3.1)
  — after 30
- 31 [OPUS] Class mod & upgrade architecture — two-layer model + `class_mod_system.md` design
  doc (Ben approves) + Fighter pilot — after 34 **(the audit's remaining decisions feed
  10/16/17/25/26/33)**
- 32 [SONNET] ∥ Class mods full content pass — after 31
- 33 [SONNET] ∥ Level-up rework: class filtering + ability upgrades — after 31
- **HUMAN (Ben):** approve Druid/Cleric kits (30) and the class-mod design doc (31); playtest
  the pacing pass (29) and passive tree branches (26–28)

### Phase M3 — Product shell
- 09 [SONNET] Settings system core (audio buses, display, ConfigFile persistence, UI)
- 10 [SONNET] Main menu scene — after 09
- 11 [SONNET] ∥ Save versioning + migration scaffold
- 12 [SONNET] Settings phase 2 — rebinding + accessibility (can defer to post-M6)

### Phase M4 — Audio
- 13 [HAIKU] SFX/music asset manifest (shopping list for Ben)
- **HUMAN (Ben):** source/purchase audio assets per manifest (check Minifantasy SFX packs first)
- 14 [OPUS] Audio system architecture + core implementation — after 09 (needs buses)
- 15 [SONNET] Full SFX/music wiring pass — after 14 + assets on disk

### Phase M5 — Feel + onboarding (requires M2.5 done — tuning/copy target the final combat model)
- 16 [SONNET] ∥ First-run onboarding tooltips (rewritten for combo/skill/dash inputs)
- 17 [SONNET] ∥ Juice pass (hit-stop, shake, boss intro, extraction fanfare)
- 18 [SONNET] Balance instrumentation + tuning — after 29 + 31–33 and Ben's playtests with 16+17 in
- **HUMAN (Ben):** playtests with fresh-eyes friends between 17 and 18

### Phase M6 — Controller support
- 19 [SONNET] Gameplay bindings + twin-stick aim / auto-aim
- 20 [SONNET] UI focus navigation, hot-swap, prompt glyphs — after 19

### Phase M7 — Release engineering
- 21 [SONNET] ∥ Achievements system (12 achievements, hooks, toast, Records sub-panel)
- 22 [HAIKU] ∥ Crash logging + version display
- 23 [SONNET] Export presets + itch.io butler pipeline
- 24 [SONNET] Steam integration (GodotSteam, cloud saves, achievement sync) — after 21+23
- 25 [SONNET] Store page copy (short desc, long desc, tags) — anytime after M2
- **HUMAN (Ben):** capsule art, screenshots, trailer, smoke-test checklist (`docs/release_pipeline.md`), clean-machine build test

## Token Budget Estimate

- Tier 1 (3 tasks): ~400 in / ~800 out each → ~3.6k
- Tier 2 (17 tasks): ~1.5k in / ~3k out each → ~77k
- Tier 3 (3 tasks): ~3k in / ~6k out each → ~27k
- **Estimated prompt-level total: ~108k tokens** (excludes the session's own file reads/edits, which dominate in practice — this estimate ranks relative cost, not absolute spend)

## Dependency Chains (strict)

- ~~02~~ → 04 (win flow triggers off boss-gated portal extraction — 02 done, 04 unblocked)
- 26 → 27, 26 → 28 (passive tree backend before behaviors/UI)
- 30 → 34 → 31 → 32 and 31 → 33 (all 12 classes → gear/rarity system → class-mod design doc;
  approved doc before content + level-up rework)
- 29 + 31–33 → 18 (tune against the final pace and mod/upgrade pools)
- 09 → 10, 09 → 14 → 15 (settings buses before audio; menu links settings)
- 19 → 20, 21+23 → 24
