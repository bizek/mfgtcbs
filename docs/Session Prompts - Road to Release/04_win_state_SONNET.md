# Task 04 — Win state: win flow, credits, account flag
**Tier**: 2 → Sonnet | **Depends on**: 02 (boss-gated portal extraction working)

---

<goal>
Give the game a terminal success condition. Today no win state, credits, or cleared-flag exists (verified in `docs/release_pipeline.md` → "End-Game / Win State"). Decision already made: extracting through the final boss-gated portal of the final biome (currently Caves; design intent is the last biome shipped in v1) triggers the win flow.
</goal>

<context>
- Read `docs/release_pipeline.md` "End-Game / Win State" section — the four decisions there are resolved as recommended: final-biome extraction = win; credits → hub return → account-level cleared flag; per-account flag + per-character "cleared with X" tracking; new-game+ cut to v1.5.
- Extraction completion flows through `ExtractionManager` (autoload) and `scripts/ui/extraction_success_screen.gd`. `ProgressionManager` owns save state. `GameManager` owns the run state machine.
- Make the "which biome/level is final" check data-driven (e.g. a flag on the level definition in `data/factories/level_data.gd`), not hardcoded to Caves, so adding a biome later doesn't rewrite this.
</context>

<requirements>
- Win flow: distinct win screen (reuse extraction_success_screen styling, clearly differentiated copy/visuals) → credits scene → hub.
- Credits scene: simple scrolling or paged text; content placeholder with Ben's name + asset credits (Minifantasy/Krishna Palacio license requires attribution — check `CommercialLicense.txt` in the asset packs and include required lines).
- `ProgressionManager`: account-level `game_cleared` flag + per-character cleared tracking, persisted in the save JSON; a second win must not corrupt anything.
- One cosmetic acknowledgment per cleared character is OPTIONAL — skip if it adds scope; the flag + records display is enough for v1.
- Scene changes via Godot MCP tools (never hand-edit .tscn). UI text sized for 3× viewport scaling.
- Verify: complete a debug-mode run end-to-end, confirm win flow plays, flag persists across relaunch, second win is safe.
</requirements>

<output_format>
Code + scenes + a grouped conventional commit. Summarize the verified flow.
</output_format>
