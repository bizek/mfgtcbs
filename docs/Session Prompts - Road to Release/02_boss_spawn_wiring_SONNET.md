# Task 02 — Wire boss spawning from LdtkLevelDirector
**Tier**: 2 → Sonnet | **Depends on**: 01 (clean tree)

---

<goal>
Replace the boss-spawn stub so LDtk-authored boss encounters actually spawn the boss. Currently `_on_ldtk_boss_should_spawn` at `scripts/main_arena.gd:413` only logs a warning ("boss scene wiring TBD").
</goal>

<context>
- Read `docs/engine_reference.md` ("New Enemy", "Choreography") and `docs/block_architecture.md` first.
- `LdtkLevelDirector` (`scripts/systems/ldtk_level_director.gd`) emits `boss_should_spawn(boss_id: String, spawn_pos: Vector2)` when the PreBoss kill quota is met; connected at `main_arena.gd:286`.
- The Heart of the Deep boss already exists: `data/factories/enemies/heart_of_the_deep_data.gd`, registered in `enemy_registry.gd`, with reward payout + unique mod (commits 9033904, c9147b0). The descent's Portal block gates extraction on the boss climax.
- `EnemySpawnManager` (autoload) handles normal spawns — check how it instantiates enemies from EnemyRegistry and reuse that path rather than inventing a new one.
</context>

<requirements>
- `boss_id` resolves through EnemyRegistry; unknown ids push_warning and no-op (no crash).
- Spawn at `spawn_pos`; verify the position is within the descent's expanded world bounds, not the default ±800×±600 arena.
- Boss death must still trigger the existing climax gate / reward payout flow — trace that flow before wiring and do not duplicate it.
- Emit/route through existing EventBus signals; no new autoloads.
- Test by running a descent in debug mode (F1–F5 hotkeys available via `GameManager.debug_mode`) and confirming the boss spawns, fights, dies, and the portal unlocks.
</requirements>

<output_format>
Code changes in `scripts/main_arena.gd` (and only where necessary elsewhere), plus a grouped conventional commit. Report the verified in-game flow in your summary.
</output_format>
