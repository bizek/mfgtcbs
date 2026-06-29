# Execution Plan — Road to Release (M1–M7)

Generated 2026-06-10 by Prompto. Each numbered file in this folder is a self-contained
session prompt. Paste one prompt per fresh Claude Code session in this repo (CLAUDE.md
auto-loads, so prompts reference repo files instead of inlining them).

## How to Use

| Suffix | Tier | Model | Use for |
|--------|------|-------|---------|
| HAIKU | 1 — Light | claude-haiku-4-5 | Mechanical, low-risk tasks |
| SONNET | 2 — Standard | claude-sonnet-4-6 | Implementation from clear spec |
| OPUS | 3 — Heavy | claude-opus-4-8 | Architecture, design, cross-system work |

Run phases in order. Tasks inside a phase marked ∥ can run in parallel sessions
(no shared files). Move completed prompts to `docs/Archived Session Prompts - Completed/`.

## Phases

### Phase M1 — Close out the core loop
- 01 [HAIKU] Commit the dirty working tree in grouped conventional commits
- 02 [SONNET] ∥ Wire boss spawning from LdtkLevelDirector (replace the log stub)
- 03 [SONNET] ∥ Author 3–4 new inner block variants + altar markers
- 04 [SONNET] Win state: win flow, credits, account flag (after 02)
- **HUMAN (Ben):** paint `PropCollision` IntGrid layer in the LDtk GUI (see `docs/ldtk_schema.md` §2.1)

### Phase M2 — Character Overhaul
- 05 [OPUS] Archetype design doc — map 7 characters to True Heroes sprite sets (Ben reviews/approves)
- 06 [OPUS] Per-character sprite pipeline (SpriteFrames swap, animation states) — after 05
- 07 [SONNET] Identity alignment — rename, passives, starting weapons — after 05, ∥ with 06
- 08 [SONNET] Hub surfaces — portraits, roster panel, launch panel — after 06+07

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

### Phase M5 — Feel + onboarding
- 16 [SONNET] ∥ First-run onboarding tooltips
- 17 [SONNET] ∥ Juice pass (hit-stop, shake, boss intro, extraction fanfare)
- 18 [SONNET] Balance instrumentation + tuning — after Ben playtests with 16+17 in
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

- 02 → 04 (win flow triggers off boss-gated portal extraction)
- 05 → 06 → 08 and 05 → 07 → 08 (design doc feeds both implementation tracks)
- 09 → 10, 09 → 14 → 15 (settings buses before audio; menu links settings)
- 19 → 20, 21+23 → 24
