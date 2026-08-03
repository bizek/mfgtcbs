# CLAUDE.md — Extraction Survivors

## Project Context

This is a Godot 4 (GDScript) game project. There are NO web servers, dev servers, package.json, or
Node/npm tooling — do not look for them or attempt to start one.

Top-down 2D survivor / extraction hybrid. WASD movement, **manual cursor-aim combo combat**
(auto-fire survives only as a debug toggle), horde encounters, 5-phase run clock, extraction loop.
The default run path is **descent mode** (block-based vertical levels), not the flat arena. Built on
a ported component-based combat engine with data-driven content creation.

**Developer:** Solo dev (Ben) + Claude. Ben provides creative direction. Claude handles all code.

- Always type array element access (avoid `:=` on untyped array access — it causes type inference crashes).
- When modifying weapon/mod/status code, check for cooldown_base=0.0 cases that could fire effects on the player immediately.
- Search the uncommitted working copy, not just git history, when locating code.

## Architecture

Component-based entity system with data-driven content. CombatOrchestrator (scene-owned, child of MainArena) manages all combat subsystems. All effects route through `EffectDispatcher`. New content = new data factories, not new scripts.

### Autoloads
`EventBus` (combat signal bus), `GameManager` (state machine, phases, difficulty), `ProgressionManager` (save/load, unlocks, meta-progression), `UpgradeManager` (level-up choices), `EnemySpawnManager` (wave composition, spawn timing), `ExtractionManager` (channeling state), `CodexManager` (combo discovery/mastery), `LootTables` (drop rolls), `Settings` (options + persistence), `AudioManager` (SFX/music routing), `InputGlyphs` (kb/controller prompt glyphs), `AchievementManager` (detection + unlock), `Logger` (levelled logging), `GameCursor` (the game's own mouse cursor — reticle in play, arrow in menus)

> **`Logger` cannot be reached by its bare name.** Godot 4.6 ships a NATIVE `Logger` class which
> wins name resolution, so `Logger.log_info(...)` compiles and then fails at runtime with
> *Static function "log_info()" not found in base "GDScriptNativeClass"*. Use
> `get_node("/root/Logger")`. Nothing outside `logger.gd` had ever called it, which is why this
> stayed hidden until 2026-08-02.

Source of truth is `project.godot [autoload]`. `MCPScreenshot` / `MCPInputService` / `MCPGameInspector` are editor-tooling autoloads from the `godot_mcp` addon, not game systems.

### Entity Components
Every entity owns: `HealthComponent`, `ModifierComponent`, `AbilityComponent`, `BehaviorComponent`, `StatusEffectComponent`, `TriggerComponent`. The player additionally owns `SkillComponent` (Q/E skill slots, built per kit by `SkillFactory`). Contract in `scripts/entities/entity_interface.gd`.

### Tick Order
`CombatOrchestrator.tick()`: SpatialGrid rebuild → FlowField re-flood check → per-entity
(StatusEffect.tick → AbilityComponent.tick_cooldowns → BehaviorComponent.tick) → ground-zone ticks
→ dead-reference cleanup. The player is skipped in the BehaviorComponent step — it ticks its own
behavior from `_physics_process` because it is input-driven.

### Key Pipelines
- **Damage**: 8-step in DamageCalculator (base → conversion → offensive mods → dodge → block → resist → damage_taken → vulnerability → crit)
- **Effects**: EffectDispatcher type-switches on 16 effect Resource types → delegates to subsystems
- **Abilities**: BehaviorComponent resolves targets → emits signal → entity fires EffectDispatcher
- **Statuses**: StatusEffectComponent manages stacking, duration, modifier sync, aura ticks, trigger registration
- **Combo chains**: a kit's light/heavy/channel graph is one `AbilityDefinition` whose `ChoreographyDefinition` has one phase per node; `ChoreographyRunner` (shared by `player.gd` and `enemy.gd`) walks it, branching on `ConditionInputBuffered` / `ConditionInputHeld`

## Documentation

**Tier 1 — engine + grammar (read for any implementation work):**

| Doc | Contents |
|-----|----------|
| `docs/engine_reference.md` | **Read this first for any implementation work.** Full engine reference: all systems, data patterns, effect/targeting vocabularies, wiring examples. Includes enemy role taxonomy and extraction system. |
| `docs/combat_chain_architecture.md` | **The combo-chain combat layer** — the game's identity system. Combo-graph-as-choreography, the input-condition seam, `ChoreographyRunner`, held channels, kit composition. Shipped; read before touching any kit, chain, or skill. |
| `docs/mechanical_vocabulary.md` | Game-specific mechanical vocabulary: damage types, status effects, weapon behaviors, mod effects, class-mod ops, triggers |
| `docs/core_framework_decisions.md` | Formulas: damage, XP curve, phase timing, enemy scaling, instability thresholds, economy |
| `docs/architecture_blueprint.md` | Architectural principles, save-system policy, performance constraints |
| `docs/diagrams.md` | Mermaid diagrams: state machine, autoload map, orchestrator ownership, tick order, damage pipeline, signal hub |

**Tier 2 — subsystem references:**

| Doc | Contents |
|-----|----------|
| `docs/class_mod_system.md` | Two-layer mod model: kit capability tags, generic-mod applicability, `ClassModFactory`, per-class mod rosters |
| `docs/mod_interaction_matrix.md` | Generic-mod combos: two-mod pairs and triples with resolved effects |
| `docs/passive_tree.md` + `docs/passive_tree_spec.md` | Passive tree data contract (59 nodes), gate rules, rendering recipe; spec holds the design intent |
| `docs/hub_reference.md` | Hub stations: what each panel does, what's implemented vs planned |
| `docs/boss_authoring_reference.md` | Boss/miniboss authoring: choreography patterns, telegraphs, phase structure |
| `docs/spell_effects_inventory.md` | Spell Effects packs I+II coverage record: every sheet's layout, fps, and engine home |
| `docs/ui_pack_inventory.md` | Minifantasy UI Overhaul coverage record: every sheet's layout + atlas bands, what the game actually uses (one file), and the ranked gap list. Read before any UI/theme/glyph/cursor work |
| `docs/dev_tools.md` | Training Room (flat sandbox: dummies, live class swap, DPS meter, slow-mo) and Animation Lab (F10: trim/retime anims, re-pin hit frames, author intro/loop/outro staging for held abilities) |
| `docs/audio_pipeline.md` + `docs/audio_asset_manifest.md` | AudioManager/SoundTable wiring, REAPER forge tooling, per-sound manifest |
| `docs/release_pipeline.md` | Export presets, `build.ps1`, itch.io/Steam packaging |
| `docs/asset_inventory.md` | Free asset sources, palette-shift strategy, license tracking |

**Tier 3 — level authoring:**

| Doc | Contents |
|-----|----------|
| `docs/ldtk_schema.md` | LDtk schema contract: entity defs, enums, level fields, IntGrid values, layer stack — read first for any level work |
| `docs/ldtk_workflow.md` | LDtk authoring workflow: where files live, biome asset map, how to add a level/biome, arena design principles |
| `docs/block_sketch_workflow.md` | **Preferred path for new descent blocks**: text sketch → `tools/block_compiler.py` → .ldtkl + PNG preview. Sketch format, grid legend, validators, prop decorator. Use the `/blockgen` skill for the full operating procedure |

**Live worklist:** `docs/Session Prompts - Road to Release/00_EXECUTION_PLAN.md` is the release plan and is **current** — it carries a per-task status table verified against source. As of 2026-07-21 there are **no unstarted tasks left**: 15 (audio wiring) is partial — channel loops and dash/skill/pet stingers outstanding — and 24 (Steam) / 25 (store copy) are blocked on Ben. Read the plan's own status table rather than this line for detail. The numbered prompt files beside it are self-contained session prompts.

**Historical / point-in-time** (design records and playtest logs — do NOT treat as current state): `character_overhaul_design.md`, `pacing_rebalance.md`, `fighter_kit_spec.md`, `combo_feedback_spec.md`, `dash.md`, `manual_fire.md`, `design_audit_2026-07-06.md`, `verification_findings.md`, `cave_audit.md`, `clerveu_triage_prompts.md`, `ability_playtest_checklist.md`, `block_architecture.md`, `block_system_implementation_notes.md`, `biome_authoring_template.md`, `hub_ui_redesign_prompts.md`, `sprite_catalogue.md`, `item_icon_catalogue.md`, `weapon-scaling-reference.md` (frozen — see below), and everything under `docs/design_archive/`, `docs/obsidian/`, `docs/Archived Session Prompts - Completed/`.

**Direction note (Ben, 2026-07-21):** weapons are becoming **class-locked, not transferable between characters**, and the **mod system gets a fresh pass** once the current character/attack/ability polish phase is done. Treat `weapon-scaling-reference.md` and `mod_interaction_matrix.md` as frozen records of the old model — do not extend them, and don't assume cross-character weapon portability in new work.

### When to read what

| Task | Read these |
|------|-----------|
| **Any implementation** | `engine_reference.md` (always) |
| **Kits / combos / Q-E skills / dashes** | `combat_chain_architecture.md` + `engine_reference.md` → "Combo-Chain Combat Layer" |
| **New enemy/boss** | `engine_reference.md` → "New Enemy" + "Enemy Role Taxonomy" · `boss_authoring_reference.md` |
| **New weapon** | `engine_reference.md` → "New Weapon" + WeaponData/WeaponFactory patterns |
| **New status/buff/debuff** | `engine_reference.md` → "New Status Effect" + "Trigger System" |
| **Mods** | `class_mod_system.md` (class layer) · `mod_interaction_matrix.md` (generic layer) |
| **Combat balancing** | `core_framework_decisions.md` + `mechanical_vocabulary.md` |
| **Game design questions** | `architecture_blueprint.md` (design principles section) |
| **Hub / meta-progression** | `hub_reference.md` · `passive_tree.md` |
| **Extraction mechanics** | `engine_reference.md` → "Extraction System" section |
| **Level / map authoring** | `ldtk_schema.md` + `ldtk_workflow.md` + `block_sketch_workflow.md` |

## Project Orientation

- When reading project state, verify against actual source files rather than trusting docs, which are often stale (e.g., loader status).
- Docs were audited and reconciled with code on 2026-07-21 — findings and remaining open items in `docs/doc_audit_2026-07-21.md`. The fastest-drifting section in the whole doc set is `engine_reference.md`'s content-coverage list; re-grep `data/` before trusting a "no content uses this" claim.

## In-Game Testing — Training Room ONLY (non-negotiable)

**Every in-game test Claude runs MUST happen in the Training Room. Never start a real run.**
(Ben, 2026-07-26, after a "training room" probe silently became a live run and killed him.)
A real run spawns waves that chase and kill the player, so the measurement dies before it yields
anything and the tokens are wasted. Use the F11 Training Panel's own controls: live class swap,
dummy spawn, **DUMMIES HIT BACK** toggle, DPS meter, slow-mo, PACK / CLEAR.

**The footgun — read this before writing any entry code.** `TrainingPanel._exit_tree()`
(`scripts/ui/training_panel.gd:68`) sets `GameManager.training_mode = false` unless its own
`_reloading` flag is set. `change_scene_to_file()` frees the old scene *before* the new one's
`_ready()`, so **re-entering the training room from inside the training room clears the flag on
the way out** and `main_arena._ready()` then builds a real run — waves, phase clock, death screen.
Setting `training_mode = true` before the scene change does not help; the panel's exit runs after it.

Entry procedure:
- **Not currently in the room** — set `GameManager.training_mode = true`, then
  `change_scene_to_file("res://scenes/main_arena.tscn")`.
- **Already in the room** (swapping class) — do NOT change scene. Set
  `ProgressionManager.selected_character`, then drive the panel's own reload
  (`_cycle_class`, which sets `_reloading` so the flag survives). If you must change scene
  anyway, call `TrainingPanel.keep_training_mode()` on the live panel FIRST.
- **Always assert on arrival, before measuring anything:** `GameManager.training_mode == true`
  AND a `TrainingPanel` exists in the tree. If either is false, you are in a real run — stop.
- Turn **HIT BACK OFF** unless the test is about damage the player takes; dummies deal contact
  damage by default and will flood any `on_hit_dealt` log. Filter event logs by
  `source == player` regardless.
- Restart the played scene only when GDScript changed — the running process caches compiled
  scripts, so edits are invisible until a fresh `play_scene`.

## Content Creation — The Pattern

All content follows the data factory pattern: `static func create() -> Resource`. Register in the appropriate registry. The engine wires everything automatically.

- **New enemy type**: Data factory → EnemyDefinition → register in EnemyRegistry → add scene + spawn logic
- **New weapon**: Entry in WeaponData.ALL → WeaponFactory builds AbilityDefinition automatically
- **New status effect**: StatusEffectDefinition in StatusFactory or inline → applied via ApplyStatusEffectData effect
- **New modifier**: ModifierDefinition → added to entity's ModifierComponent
- **Enemy with abilities**: AbilityDefinition on auto_attack/skills → BehaviorComponent handles targeting + cooldowns
- **Boss with phases**: ChoreographyDefinition on AbilityDefinition.choreography → enemy.gd executes automatically
- **Reactive effects**: TriggerListenerDefinition on StatusEffectDefinition.trigger_listeners → TriggerComponent handles EventBus wiring

## Coding Conventions

- GDScript, typed variables: `var speed: float = 200.0`
- Godot 4.6.1-stable, Compatibility renderer (editor build; `project.godot config/features` carries the coarser "4.6" feature tag)
- 640x360 viewport, 3x integer scaling to 1920x1080
- Collision layers (source of truth: `project.godot [layer_names]`): 1=player, 2=enemies, 3=player_projectiles, 4=enemy_projectiles, 5=pickups, 6=extraction. There is no named "walls" layer — level collision is built by `LdtkLoader` on the default layer.
- Signals for inter-system communication, autoloads for managers
- Entity scenes: CharacterBody2D for player/enemies, Area2D for pickups/projectiles
- File organization: `scripts/systems/`, `scripts/components/`, `scripts/entities/`, `scripts/managers/`, `scripts/ui/`, `data/resources/`, `data/factories/`
- All Resource subclasses: `@export` properties, zero behavior. Logic lives in dispatchers/components.
- Never invent patterns when existing ones work. Route through EffectDispatcher. Use ModifierDefinition for stats. Use StatusEffectDefinition for timed effects.

## Godot Rules

- **Never hand-edit `.tscn` files.** Use the Godot MCP editor tools (or the editor itself) for all
  scene structure changes. Hand-editing silently strips unowned nodes on instanced sub-scenes, and
  loses font UIDs.
- Before editing scenes or loaders, confirm you are targeting the correct file/scene (e.g., not
  Base Camp/Map.tscn), and never auto-generate new random IDs that overwrite committed scenes.
- **3x viewport scaling.** 640x360 renders to 1920x1080 — all UI text/font sizes must stay legible
  after the upscale.
- Spatial/positioning work: verify coordinates against the bounds of the mode you're targeting.
  Descent mode (default) is `Rect2(0, 0, level_width≈648, total_height)` — all-positive coords,
  height varies with the block stack. The flat arena (training room, non-descent LDtk fallback) is
  ±800 x ±600 centred on the origin. `main_arena.gd` `ARENA_HALF_W/H` are the flat-arena constants.
- F8/F9 are Godot's built-in Stop/Pause hotkeys, not crashes — don't diagnose them as errors, and
  never bind features to them.

## Verification

- Always verify changes live in the Godot MCP editor before reporting them as working; do not claim features work until confirmed in-engine (e.g., dash phasing, manual fire, animations).

## Level Generation

- Do not auto-generate/scatter decorations (props, scratches) with collision unless explicitly requested; keep decorative passes non-colliding and hand touch-ups to the user.

## UI Panel Changes

- After resizing or adding rows to any hub UI panel, verify against the current viewport size and wrap scrollable content in a ScrollContainer with SHOW_AS_NEEDED (never SHOW_NEVER, which clips).
- When adding new content to level-up or armory panels, check for overflow before declaring done.

## Commit Workflow

- Before declaring a commit done, run `git status` and `git diff` to verify zero unstaged or untracked files remain. Stage project.godot and any status/docs files explicitly.
- When asked to commit, always run `git status` after staging and before committing to confirm no files are missed.
- Use grouped conventional commit messages.

## Gameplay Implementation Rules

- Knockback and similar forces must be gated on i-frames to avoid pinball effects.
- New status effects must defensively handle missing keys (e.g., 'timer') on existing status entries.
- **Pets/companions are autonomous entities, never lerp-glued to the player.** The standard
  (set by FireFamiliar/BloodElemental, Ben 2026-07-05): own constant-speed locomotion with
  catch-up, hunt prey within a player-centric leash, settle/roam with hysteresis when idle.
  All future pets inherit these mechanics unless Ben specifies otherwise or a mod/item
  changes the behavior.
- **Character asset packs must be FULLY utilized for what they're there for.** Each Minifantasy
  class pack ships complete kits: all four facing rows (the player faces the mouse cursor using
  the real directional rows — never flip_h when a left/right row exists), frame-matched `_Effect`
  overlay sheets, and special-animation packages (projectiles, directional trails, impacts,
  explosions). Wire the pack's own pieces; never substitute another character's assets or a
  procedural stand-in when the pack provides the real one. (Ben, 2026-07-04.)

## Key Technical Details

- Flat-arena bounds: ±800 x ±600 pixels (descent mode uses its own block-stack bounds — see Godot Rules)
- ProjectileManager: 256-slot pooled parallel arrays, `_draw()` rendering, zero node churn
- CombatFeedbackManager: 128-slot pooled, composite damage numbers per frame
- SpatialGrid: cell-based proximity queries, rebuilt every frame
- Resistance formula: `raw * (1.0 - resist / (resist + 100.0))`
- XP formula: `base(10) * (1.0 + (level - 1) * 0.3)`
- Debug mode: `GameManager.debug_mode = true` enables the debug panel and entity inspector. Hotkeys: F1 panel, F2 god mode, F3 level-up, F4 skip extraction, F5 test telegraph / inspector toggle, F6 spawn miniboss, F7 spawn final boss, F10 Animation Lab, F11 Training Room panel. (F8/F9 are Godot's own Stop/Pause — never bind them.)
- Run modes on `GameManager`: `use_descent_mode` (block-based vertical descent, the default path) and `training_mode` (flat sandbox, no waves/clock/extraction). Combat and loot scaling read `get_effective_phase()` — spatial depth in descent mode, wall-clock `phase_number` otherwise.
