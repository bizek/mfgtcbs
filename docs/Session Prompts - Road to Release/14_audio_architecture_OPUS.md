# Task 14 — Audio system architecture + core implementation
**Tier**: 3 → Opus | **Depends on**: 09 (audio buses exist), 13 (manifest exists). Assets need not all be on disk — build with placeholders for any missing.

---

<role>
You are building the audio system for a Godot 4.6 survivors game with zero existing audio code. The game runs hundreds of simultaneous combat events per second at peak; naive one-player-per-sound will not survive.
</role>

<objective>
Design and implement the full audio backbone: pooled SFX playback driven by EventBus signals, music playback with crossfade, settings integration. After this task, wiring a new sound = adding one entry to a data table (task 15 does the bulk wiring).
</objective>

<context>
- Read `docs/engine_reference.md` (EventBus signal vocabulary, pooled-system patterns — `ProjectileManager`'s 256-slot parallel arrays and `CombatFeedbackManager`'s 128-slot pool are the house style for high-frequency systems).
- `docs/audio_asset_manifest.md` (task 13) lists every sound ID, trigger, and priority.
- Buses Master/Music/SFX exist with settings sliders (task 09) — play into them; do not create new buses without need.
- Audio files will land under `assets/audio/` (sfx/ and music/ subfolders — create the structure).
- Autoload conventions: managers are autoloads; combat subsystems live under CombatOrchestrator. Audio must work in BOTH hub and arena, so an autoload (`AudioManager` or similar) is appropriate — justify the placement either way.
</context>

<constraints>
- Pooled `AudioStreamPlayer` set for UI/global SFX + pooled `AudioStreamPlayer2D` for positional combat SFX (decide pool sizes; document them). Zero node churn at runtime.
- Per-frame dedup/limiting: N simultaneous hits play at most K instances of the same sound with slight pitch variation (state your K and variance; the CombatFeedbackManager composite pattern is precedent).
- Data-driven sound table: sound ID → stream path(s), volume, pitch variance, bus, max concurrent. Missing file → warn once, no-op (the game must run fine with zero assets present).
- EventBus-driven: subscribe to combat signals; gameplay code must never call the audio system directly except for non-EventBus moments (UI clicks, music changes).
- Music: hub loop / arena loop / boss track with short crossfade on transition; hooks at hub load, run start, and boss spawn (boss spawn signal exists — see `boss_should_spawn` wiring in main_arena.gd).
- Respect cooldown_base=0.0 CLAUDE.md warning: any sound tied to weapon/status effects must tolerate zero-cooldown rapid fire without audio spam (the concurrency cap is the defense — test it).
</constraints>

<reasoning_guidance>
Decide the positional-vs-global split per manifest category before coding. Think through the loudest realistic frame (50+ enemies, AoE kill, pickups vacuuming) and verify the limiter math caps total voices. Prefer the simplest design that meets the constraints — this is a 2D pixel game, not a AAA mix; ducking/snapshot systems are out of scope.
</reasoning_guidance>

<output_format>
AudioManager (+ sound table data file) + music integration + folder structure, grouped conventional commits. Wire 5–10 P1 sounds end-to-end as proof (use any placeholder/free files if real assets aren't sourced yet, clearly named as placeholders). Update `docs/audio_pipeline.md` with the architecture and the "how to add a sound" recipe.
</output_format>

<success_criteria>
A debug run with assets present plays positional combat audio without clipping or spam at horde scale; sliders from settings affect everything correctly; task 15 can wire the remaining manifest entries by editing only the sound table.
</success_criteria>
