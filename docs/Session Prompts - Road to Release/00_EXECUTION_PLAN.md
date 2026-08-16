# Execution Plan — Road to Release (M1–M7 + M2.5)

Generated 2026-06-10 by Prompto. Audited 2026-07-06. **Re-audited against code 2026-07-21** — see
the status table below; most of M3–M7 has shipped since the last audit and the plan body had not
been updated to reflect it.

Each numbered file in this folder is a self-contained session prompt. Paste one prompt per fresh
Claude Code session in this repo (CLAUDE.md auto-loads, so prompts reference repo files instead of
inlining them).

## Status at a glance (verified against source, 2026-07-21)

| Task | Status | Evidence |
|---|---|---|
| 01–03, 05–08 | ✅ done | archived with `rtr_` prefix |
| **04** win state | ✅ **done** (was recorded open) | `scripts/ui/win_screen.gd`, `scripts/ui/credits.gd`, `GameManager.last_run_was_win`, `final_boss_defeated` |
| 09 settings core | ✅ done | `scripts/managers/settings.gd`, `scripts/ui/settings_panel.gd` |
| 10 main menu | ✅ done | `scenes/main_menu.tscn`; NEW GAME now lands in `hub.tscn` (was `main_arena.tscn` as The Drifter) 2026-08-15 — `scripts/main_menu.gd` `_start_new_game()` |
| 11 save versioning | ✅ done (2026-07-21) | `SAVE_VERSION`, `_migrate_save`, corrupt backup, newer-version refusal; snapshot `tests/save_snapshots/v1.json`; 4 cases verified in-engine |
| 12 settings phase 2 | ✅ done | rebinding + `screen_shake` + `colorblind_mode` in `settings.gd` |
| 13 SFX manifest | ✅ done | `docs/audio_asset_manifest.md` |
| 14 audio architecture | ✅ done | `scripts/managers/audio_manager.gd`, `data/factories/sound_table.gd` (54 entries) |
| **15 audio wiring** | ✅ **done** (2026-08-15) | weapon fire wired via `on_ability_used`; dashes wired via `player._on_dash_started` (class-flavored: blink/blade/roll/generic); biome music for Catacombs + Nightmare Realm composed and shipped 2026-08-15 (`mus_catacombs`, `mus_nightmare_realm`); channel-loop beds (fire/arcane/martial) composed and shipped 2026-08-15 (`tools/sfx_forge/channel_loop_*.py`); **Q/E skills + pet summons wired 2026-08-15** — `SkillComponent.trigger()` now emits `EventBus.on_ability_used`, `AudioManager` routes on the ability's `tags[1]` category (`Buff`/`Offensive`/`Movement`/`Summon`, set per-skill in `SkillFactory._ability()`) to 4 shared stingers (`sfx_skill_buff/offensive/movement`, `sfx_summon_arrive`); verified in Training Room across demonologist (Summon×2), blood_mage (Summon), barbarian (Buff), ranger (Movement) |
| 16 onboarding | ✅ done | `scripts/ui/first_run_overlay.gd` |
| 17 juice pass | ✅ done | hit-stop / shake in `combat_utils.gd`, `player.gd`, `main_arena.gd`, shake respects `Settings.screen_shake` |
| 18 balance instrumentation | ✅ done | `scripts/systems/run_report_manager.gd` (debug-only) |
| 19 controller bindings | ✅ done | commit `19d28ef`; analog stick `be3c9a6` |
| 20 UI nav + glyphs | ✅ done | `ui_nav_utils.gd`, `glyph_bar.gd`, `InputGlyphs` autoload |
| 21 achievements | ✅ done | `AchievementManager`, `data/achievements.gd` (12), Records tab |
| 22 crash logging + version | ✅ done | `Logger` autoload, `config/version="0.0.3"` |
| 23 export presets | ✅ done | `export_presets.cfg`, `build.ps1`, both targets smoke-tested |
| **24 Steam** | 🚧 **blocked** | needs a Steam App ID from Ben |
| **25 store copy** | 🚧 **blocked** | needs the final game name (decision D5) |
| 26–28 passive tree | ✅ done | `data/passive_tree.gd` (59 nodes), `hub_passives_panel.gd` |
| 29 pacing pass 2 | ✅ done | move speeds rebalanced 2026-07-07 |
| 30 roster completion | ✅ done | 12/12 — Verdant + Devout |
| 31–33 class mods + level-up | ✅ done | 48 class mods, `ModApplicability`, `ability_upgrades.gd` (36) |
| 34 class gear & rarity | ✅ done | 42 weapons, `trinkets.gd`, `gear_unique_factory.gd` |

**Remaining work: the rest of 15 (audio wiring), and two Ben-blocked items (24, 25).** Task 11 (save versioning) shipped 2026-07-21 — the plan has no unstarted tasks left.

> Not an RTR-numbered task, but worth cross-referencing here: the HUD phase dial
> (`docs/polish_plan_2026-08-15.md` §2.4, `docs/ui_pack_inventory.md` §12) shipped 2026-08-15 —
> the last item flagged in this plan's Tier-2 carry list before the Steam/store-copy blocks.

> Note on scope drift: mods are getting a **fresh pass after the current character/ability polish
> phase**, and weapons are becoming class-locked rather than transferable (Ben, 2026-07-21). Treat
> any mod/weapon assumptions baked into the prompts below as provisional.

## How to Use

| Suffix | Tier | Model | Use for |
|--------|------|-------|---------|
| HAIKU | 1 — Light | claude-haiku-4-5 | Mechanical, low-risk tasks |
| SONNET | 2 — Standard | claude-sonnet-4-6 | Implementation from clear spec |
| OPUS | 3 — Heavy | claude-opus-4-8 | Architecture, design, cross-system work |

Run phases in order. Tasks inside a phase marked ∥ can run in parallel sessions
(no shared files). Move completed prompts to `docs/Archived Session Prompts - Completed/`.

## Phases

### Phase M1 — Close out the core loop ✅
- ~~01 [HAIKU] Commit cleanup~~ ✅
- ~~02 [SONNET] Boss spawning from LdtkLevelDirector~~ ✅
- ~~03 [SONNET] Inner block variants + altar markers~~ ✅ (block compiler now generates blocks)
- ~~04 [SONNET] Win state: win flow, credits, account flag~~ ✅ (shipped since the 2026-07-06 audit)
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

### Phase M3 — Product shell ✅
- ~~09 [SONNET] Settings system core~~ ✅
- ~~10 [SONNET] Main menu scene~~ ✅
- ~~11 [SONNET] ∥ Save versioning + migration scaffold~~ ✅ (2026-07-21). `SAVE_VERSION` + versioned
  saves, `_migrate_save()` incremental chain (v0→v1), corrupt-file backup to
  `user://save_corrupt_<unix>.json` + fresh start, newer-version refusal with a main-menu warning.
  Regression fixture `tests/save_snapshots/v1.json`. Four cases verified in-engine
  (versionless→migrate, v1 clean, corrupt→backup, v99→refuse).
- ~~12 [SONNET] Settings phase 2 — rebinding + accessibility~~ ✅

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
