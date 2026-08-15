# Execution Plan — Polish 2026-08-15

Generated 2026-08-15 by Prompto from `docs/polish_plan_2026-08-15.md`. Each numbered file in this
folder is a **self-contained session prompt**: paste one per fresh Claude Code session in this repo.
CLAUDE.md auto-loads, so prompts reference repo files and docs rather than inlining them — but each
prompt carries its own evidence and verification steps, so it works on any model with no memory of
this planning session.

Move completed prompts to `docs/Archived Session Prompts - Completed/` with a `pol15_` prefix.

## Tier → model mapping

| Suffix | Tier | Model | Use for |
|--------|------|-------|---------|
| HAIKU | 1 — Light | claude-haiku-4-5 | Mechanical, low-risk tasks |
| SONNET | 2 — Standard | claude-sonnet-5 | Implementation from clear spec |
| OPUS | 3 — Heavy | claude-opus-5 | Design, creative, cross-system work |

A prompt routed SONNET runs fine on OPUS (wasted tokens, not wasted work). The reverse is a risk.
No task in this plan scored Tier 1 — the cheapest real work here still needs in-engine verification.

## Status at a glance

| Task | Status | Gate |
|---|---|---|
| 01 land the Nightmare Realm | ✅ done (2026-08-15) | 16 scenes generated, EnemyRegistry/level_data verified in-engine, smoke-tested (entry/waves/merchant/portal/miniboss/boss all confirmed), committed |
| 02 biome music ×2 | ⬜ gated | **HUMAN D-A:** Ben un-excludes audio (excluded 2026-08-08, pre-dates biomes 2–3 shipping) |
| 03 channel loop beds ×3 | ⬜ gated | same gate as 02 |
| 04 skill/pet stingers | ⬜ gated | same gate as 02 |
| 05 NEW GAME → hub | ⬜ gated | **HUMAN D-B:** Ben decides plan §2.1 |
| 06 mod rarity: restore or retire | ⬜ gated | **HUMAN D-C:** Ben decides plan §2.3 |
| 07 phase dial | ⬜ gated | **HUMAN D-D:** Ben decides plan §2.4 (incl. what the dial shows in descent) |
| 08 mod rework Training Room pass | ⬜ ready | none (Ben's *felt* playtest is separate and still wanted) |
| 09 Holy Hammer / Reckoning redesign | ⬜ ready | Ben approves the pitch mid-session |
| 10 hub NPC speech bubbles (optional) | ⬜ ready | none — lowest priority in the set |
| 11 next biome (Threshold / Inferno) | ⬜ gated | **HUMAN D-E:** Ben picks biome + pack + identity |
| 12 game-wide TEXT_SIZE_SCALE | ⬜ ready | none |

**HUMAN (Ben), not prompts:** the five decisions above (D-A…D-E), the combo-drop feel pass
(`combo_drop.ogg` is on disk now), a real felt playtest of the mod rework, Steam App ID (RTR 24),
final game name / store copy (RTR 25 — decision D5), capsule art / screenshots / trailer.
RTR tasks 24–25 already have session prompts in `docs/Session Prompts - Road to Release/` — reuse
those, don't rewrite them.

## Phases

### Phase P0 — Land the tree (everything else stacks on this)
- 01 [SONNET] Finish, verify, and commit the Nightmare Realm

### Phase P1 — Audio (after P0 + gate D-A)
- 02 [OPUS] Biome music: `catacombs.ogg` + `nightmare_realm.ogg`
- 03 [SONNET] Channel loop beds ×3 — **not ∥ with 04** (both edit `sound_table.gd`)
- 04 [SONNET] Skill/pet stingers — closes RTR task 15

### Phase P2 — Decisions cashed in + verification (after P0; each gated on its decision)
- 05 [SONNET] ∥ NEW GAME lands in the hub — after D-B
- 06 [SONNET] ∥ Mod rarity: restore or retire — after D-C
- 07 [SONNET] ∥ Phase dial on the HUD — after D-D
- 08 [SONNET] Mod rework Training Room verification pass — no gate; run **before** 09/11 stack
  content on an unfelt system

### Phase P3 — Design and content walls
- 09 [OPUS] Holy Hammer / Reckoning redesign — after 08 ideally
- 10 [SONNET] Hub NPC speech bubbles — optional, anytime
- 11 [OPUS] Next biome — after D-E; 01's commit is the template
- 12 [SONNET] TEXT_SIZE_SCALE game-wide — anytime, but **not ∥ with 05/06/07** (broad UI overlap)

## Dependency chains (strict)

- 01 → everything (dirty working tree until it commits)
- D-A → 02, 03, 04; 03 → 04 or 04 → 03 (shared `sound_table.gd`, either order)
- D-B → 05 · D-C → 06 · D-D → 07 · D-E → 11
- 08 before 09 and 11 (verify the mod layer before building on top of it)
- 12 conflicts with 05/06/07 on files, not on logic — just don't run them concurrently

## Token budget estimate

- Tier 2 (9 tasks): ~1.5k in / ~3k out each → ~40k
- Tier 3 (3 tasks): ~3k in / ~7k out each → ~30k
- **Prompt-level total: ~70k tokens.** As with the RTR plan, session file reads/edits dominate in
  practice — this ranks relative cost, not absolute spend. The single biggest real-cost item is 11
  (a biome is a project); the best value-per-token is 02+03 (two silent biomes get voices).
