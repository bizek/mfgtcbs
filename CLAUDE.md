# CLAUDE.md — Extraction Survivors

## Project Context

This is a Godot 4 (GDScript) game project. There are NO web servers, dev servers, package.json, or
Node/npm tooling — do not look for them or attempt to start one.

Top-down 2D survivor / extraction hybrid. WASD movement, **manual cursor-aim combo combat**
(auto-fire survives only as a debug toggle), horde encounters, 5-phase run clock, extraction loop.
The default run path is **descent mode** (block-based vertical levels), not the flat arena. Built on
a ported component-based combat engine with data-driven content creation.

**Developer:** Solo dev (Ben) + Claude. Ben provides creative direction. Claude handles all code.

## Root Cause Over Bandaids (the XY Problem)

When implementing, troubleshooting, or fixing bugs: always work from the [XY Problem](https://xyproblem.info/)
principle. Someone hits problem X, guesses that Y is the solution, and asks for help with Y — but Y
is the wrong approach, or a symptom-level patch, and chasing it wastes effort or hides the real
issue. Before implementing a fix:

- Identify the actual root cause, not just the symptom in front of you (an error message, a single
  failing case, the specific line a stack trace points to).
- If a requested change (Y) looks like it's patching around a deeper problem (X), say so and propose
  addressing X — don't silently comply with a bandaid.
- Fix only the actual root cause. Don't layer a defensive check, fallback, or special-case branch on
  top of broken behavior when the correct fix is to make the underlying behavior correct.
- This project's own history is full of X/Y traps that looked like the real fix at first glance —
  see `Logger` name shadowing, the hub-panel editor-truncation footgun, and the m5x7 font-grid saga
  below. When something "almost works" or needs a workaround, treat that as a signal to dig one
  level deeper before writing the workaround.

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
- **The editor does not fully LOAD the five hub panel scenes, so saving one truncates it.**
  Measured 2026-08-07, then re-tested from scratch because the first write-up of it here was wrong.
  What is actually true:
  - The `.tscn` files are **valid and complete**. `hub_roster_panel.tscn` declares 32 nodes, 27 of
    them parented under `PanelBase/ContentContainer` — a node owned by the instanced
    `hub_panel_base.tscn`.
  - **The runtime is fine.** `PackedScene.instantiate()` returns the full tree in *all three* edit
    states, `GEN_EDIT_STATE_MAIN` included. The panels render correctly in game. Nothing about
    these scenes is malformed.
  - **The editor's edited-scene tree contains only 8 of those nodes.** Reproduced on an untouched
    file and on a pristine copy. Saving from that state writes the 8 and drops the other 27
    (278 lines from `hub_roster_panel.tscn`), leaving a scene that still loads and renders an
    empty panel. Reverted via git.
  - Adding the `[editable path="PanelBase"]` marker sets `is_editable_instance` true but does **not**
    restore the missing nodes, so that is not the fix.

  The five affected scenes are `hub_roster_panel`, `hub_launch_panel`, `hub_records_panel`,
  `hub_workshop_panel`, `hub_armory_panel`. **Never save one** — not via MCP `save_scene`, not from
  the editor. Change their behaviour from `hub_panel_base.gd` at runtime instead, which is how the
  project theme reaches them. Before saving *any* scene, `git diff` it afterwards and treat a large
  deletion count as data loss rather than cleanup.

  Two practical corollaries. If Godot offers **"Files have been modified outside Godot"** for one of
  these, choose **Reload from disk** — "Ignore external changes" keeps a possibly-truncated
  in-memory copy that the next save would persist. And the truncation is visible: if the Scene dock
  shows a hub panel with nothing under `PanelBase/ContentContainer`, that tab is unsafe to save.
- Before editing scenes or loaders, confirm you are targeting the correct file/scene (e.g., not
  Base Camp/Map.tscn), and never auto-generate new random IDs that overwrite committed scenes.
- **3x viewport scaling.** 640x360 renders to 1920x1080 — all UI text/font sizes must stay legible
  after the upscale.
- **Pixel grid — what the engine snaps and what it cannot (audit 2026-08-17).**
  `snap_2d_transforms_to_pixel` + `snap_2d_vertices_to_pixel` are on and round every canvas item's
  origin, its parent transform (the camera included) and every vertex at draw time, so fractional
  *positions* — odd-width panels centred at x.5, `TextureRect` centring, camera shake, the player's
  sub-pixel physics position — are already crisp. **Never round a position by hand for crispness**;
  `player.gd` used to and it only fed jitter into the pile anchor. What snapping cannot fix, and
  what every new site must respect: **scale is an integer** (sprites, `TextureRect`, `Button.icon`,
  `_draw`), **rotation is a quarter turn** (`_pile_snap_quarter`) or the art has directional rows,
  **the window scales by integers** (`display/window/stretch/scale_mode=integer` — keep it; that
  setting was `fractional` until 2026-08-17, which is why a maximised or dragged window rendered
  every pixel a different size while an exact 2x/3x window looked fine). To fit pixel art in a
  box: the largest integer multiple that fits (`hud._fit_glyph_icon`) or bake the factor into an
  `ImageTexture` with `Image.INTERPOLATE_NEAREST` (`GameCursor._texture_for`,
  `UIIcons.window_button_scaled`); never `Button.expand_icon`, never `STRETCH_SCALE` /
  `STRETCH_KEEP_ASPECT*` into an arbitrary size (`KEEP_ASPECT_CENTERED` *upscales* to fit — use
  `STRETCH_KEEP_CENTERED` for native size). To cover a rect: the smallest integer factor that
  covers, then `KEEP_CENTERED` + `EXPAND_IGNORE_SIZE` (`main_arena._setup_floor`). Rounded
  `StyleBoxFlat` → `anti_aliasing = false` (Godot defaults it on and feathers every edge).
  Nine-patch `StyleBoxTexture` bands → `AXIS_STRETCH_MODE_TILE` (`_nine` in the theme builder
  does this now; STRETCH scaled the Grim frames' dashed rivet border unevenly on every wide
  button). Debug tools' vector font goes through `DebugUI.crisp_vector_font()` — AA off,
  sub-pixel off, autohinter on — because an anti-aliased face at 9-14px in a 640x360 buffer is
  what made the training room / anim lab text look blurry after the upscale. The
  remaining fixed fractional scales are art-size calls listed for Ben in clerveu's audit report
  (`pixel_grid_audit_2026-08-17.md`, delivered outside this repo): the enemy `sprite_scale` table
  (~20 factories at 0.8–3.2), pickups at 0.75, guardian 2.5/0.65 + its 1.06 breathe tween, the
  1.10 extraction zoom punch, arbitrary-angle rotations of pack art; do not "fix" those without him.
- **Font sizes are 16 or 32. Nothing else.** `m5x7.ttf` is a 16px-native pixel font — every glyph
  coordinate sits on a 1024/16 = 64-unit grid, so one design pixel equals one screen pixel *only*
  at 16 and its integer multiples. At any other size the stems land on fractional pixels and,
  with `antialiasing=0` + `hinting=0` in the import, snap unevenly (some 1px, some 2px) before the
  3x upscale magnifies the mess. **Body/headings = 16, screen titles = 32.** There is no crisp
  "slightly bigger" — 19 was the game-wide default until 2026-08-03 and was the reason everything
  outside the results screen looked soft. Section hierarchy comes from color and rule lines
  (`── COMBAT ──────`), not size. Also: any new screen must apply the font — `game_over_screen.gd`
  had shipped with none and rendered in Godot's default vector font.
  **Below 16, glyphs FUSE, not just soften.** At 14 a 5px-wide glyph scales to 4.375px and the
  1px inter-letter gap disappears: "Fire" renders with `ir` welded into one blob, `R` reads as
  `A`, `s` as `a`. This is an illegibility bug, not a polish issue — it is why `anim_lab_panel.gd`
  deliberately does not use the pixel font. **Never set a player-facing size below 16.**
  **Counting sites: grep for digits is WRONG and will under-report by ~half.** Most sizes come
  from named constants (`FS_MD`, `FS_XS`, `_FS_LG`, `FS_TINY`) applied via
  `add_theme_font_size_override("font_size", FS_MD)`. Resolve the constants.
  **PASS COMPLETE 2026-08-03. Inventory: 191 sites, 173 crisp, 18 off-grid — and all 18 are in
  debug tools** (anim lab, debug panel, entity inspector, passive-tree debug, ldtk test harness),
  which are deliberately left alone.
  **That "leave them alone" rested on an assumption the project Theme silently broke, 2026-08-07.**
  The debug panels are dense and size text at 9–14px, which worked because Godot's built-in
  **vector** font was the default and a vector face stays readable that small; `training_panel.gd`
  even carried a comment saying so. When `grim_theme.tres` became the project theme its default font
  is **m5x7 @ 16**, so "the default theme font" silently started meaning the pixel font and all 18
  sites became m5x7 below its native grid. Ben, 2026-08-09: *"PACK looks like FACh, HIT BACK looks
  like KIT BACh, TRAINING ROOM looks almost like russian typescript."* Fixed by asking for the
  vector font explicitly — `DebugUI.use_vector_font(panel_root)` (`scripts/debug/debug_ui.gd`)
  assigns a Theme that sets **only** `default_font`, so every StyleBox, colour and constant still
  falls through to the Grim theme and no layout moves. **The lesson generalises: a project-wide
  default is not a no-op for code that was relying on the previous default.** When you change a
  theme default, grep for who was depending on the old one.
  **Correction 2026-08-07 said "two survive". It was FOUR. All four fixed 2026-08-08.**
  `glyph_bar.gd` set `normal_font_size` to 14, `keystone_pickup.gd` set
  `LabelSettings.font_size = 14`, and `merchant.gd` + `summon_altar.gd` both passed **11** to
  `GlyphBar.rich_prompt(size, color)`. Each was invisible to a different search: the second is a
  `LabelSettings` property rather than an `add_theme_font_size_override` call, and the last two
  pass the size as a **plain function argument**, so no grep for override sites — the exact method
  both previous audits used — could reach any of them. **When counting font sites, resolve shared
  helpers that take a size parameter, not just override call sites.**
  `GlyphBar.rich_prompt` now routes its argument through `Settings.snap_font_size()` and
  `push_warning`s on a miss, so that seam cannot produce an off-grid prompt again. Widths were
  measured before the change, not eyeballed: all four fit their fixed containers at 16 with room
  (merchant 41/120, altar 94/140, keystone 48/120, settings hint bar 117px ending at x=580).
  m3x6 was never needed; every sub-16 site went to 16 and reflowed instead.
  **The project `Theme` now supplies m5x7 @ 16 as the default font** (`assets/ui/grim_theme.tres`,
  wired via `project.godot [gui] theme/custom`, built by `tools/build_ui_theme.gd`). A new Control
  therefore renders in the pixel font *without* the script doing anything — the whole class of bug
  below is now a default rather than a thing to remember. The existing per-script font overrides
  still win and were left alone; the theme is a floor, not a replacement.
  **A font_size override alone fixed nothing — the FONT had to be applied too.** Five player-facing
  scripts sized text but never set a font, so they rendered in Godot's default vector font:
  `pause_menu.gd`, `insurance_panel.gd`, `arena_generator.gd`, `extraction_zone_base.gd`,
  `ldtk_exit_zone.gd` (plus `game_over_screen.gd`, fixed earlier in the pass). Each now has a local
  `_apply_pixel_font(c)` helper. **Check for this on any new screen** — it is invisible in a diff
  and obvious on screen.
  **The one deliberate exception: floating damage numbers.** `combat_feedback_manager` draws at
  `FONT_SIZE = 7` via `draw_string`, and its `font` is never assigned, so it falls back to
  `ThemeDB.fallback_font`. Because that is a *vector* font it does not fuse at 7px — so this is a
  style inconsistency (vector type in a pixel game), not the crispness bug, and the earlier note
  claiming "9/10/14, needs m3x6" was wrong on both counts. Left alone on purpose: forcing m5x7 at
  16 would nearly double the size of every damage number over the play field.
  **DECIDED 2026-08-09 — keep them exactly as they are** (Ben: *"honestly the damage numbers never
  gave me issue"*). Four candidates were rendered in-engine at true scale over the play field
  before asking: the current vector @ 7, m5x7 @ 16, and the packs' TCG bitmap digits at 16x16 and
  8x8 (`All_Exclusives_20260409/Addons/User_Interface/TCG_UI/Numbers_*`). This is a settled choice
  now, not an open question — **do not "fix" it**. If it is ever reopened: 8x8 is already ruled out
  (its glyphs fuse into blobs) and m3x6 is not on disk.
  **`Settings.TEXT_SIZE_SCALE` — resolved, with a caveat.** Scaled sizes now go through
  `Settings.scaled_font_size()` → `snap_font_size()`, which returns the nearest multiple of 16 and
  never less than 16, so no setting can produce an off-grid size. Consequence stated plainly: at
  base-16 text, SMALL (0.85→13.6) and LARGE (1.25→20) both snap back to 16 and are **no-ops** —
  with a 16px-native font there is no crisp in-between, only 16 and 32. Also worth knowing before
  trusting this setting at all: **only 8 of 151 font sites route through it** (`hud.gd`,
  `first_run_overlay.gd`); everything else hardcodes 16 or 32. Making it mean something game-wide
  is a separate job, and LARGE would have to be 2.0.
  **Layout footgun this exposed:** shrinking body text narrows any container that sizes to its
  content minimum, which surfaces latent layout bugs. `hub_launch_panel.gd` used a bare `Panel`
  (not a container — it never stretches children) so its brief column had always hugged content;
  at 16 it collapsed to a ~90px ribbon. Fixed to `PanelContainer`. Re-check panels after any
  font-size change.
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
