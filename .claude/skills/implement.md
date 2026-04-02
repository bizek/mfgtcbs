---
name: implement
description: Start any implementation task. Front-loads the full-context read discipline that this project's interdependent systems require. Use at the start of every coding session before writing any code.
disable-model-invocation: true
argument-hint: [brief description of what to implement]
---

# Implement: $ARGUMENTS

## Before you read a single file or write a single line of code, understand this.

You are not adding a feature. You are extending interdependent systems where a weapon behavior flows through the combat manager, interacts with 10 mod effects, 3 status effect types, 7 character passives, 4 extraction types, and the instability economy. Every system in this game touches every other system through signals, shared state on GameManager, and the player entity that sits at the center of all of it.

### Why you must read the docs and code yourself, in full, in this context

**What happens when you skip docs or read only "the files you think are relevant":**
- You build a new weapon behavior that doesn't call `_apply_mods_to_projectile()` or `_apply_direct_hit_mods()`, so 10 mods silently stop working with it
- You add a damage source that bypasses `CombatManager.resolve_hit()`, so knockback, crit, armor, and damage numbers all break
- You add a new enemy that doesn't call `EnemySpawnManager.on_enemy_died()` on death, so `active_enemies` drifts and spawning breaks
- You add loot that doesn't route through `GameManager.add_loot()`, so instability doesn't rise and the core extraction tension vanishes
- You build a new pickup that doesn't implement `start_magnet()`, so the player's pickup radius stat does nothing
- You add a character passive that works in `_apply_passive_mods()` but forget to handle it in `get_armor()`, `take_damage()`, or `is_invisible()` where the other passives are checked
- You create a new system that calls managers directly instead of using signals, breaking the observer pattern the entire architecture depends on

**Ben cannot catch these errors from playtesting alone.** The design docs are his verification layer. If you skip them and build something that contradicts the spec, it compounds silently until it becomes an expensive teardown.

**Subagents cannot do this work.** They work from a summary prompt without the full implementation context. They will miss interactions between systems, get ordering wrong, and produce conclusions that look right but aren't. The understanding of how systems intersect must exist in YOUR context — the main conversation where the implementation happens.

---

## The Reading Discipline

### Step 1: Determine what you're building and what it touches.

Read the task description. Before opening any file, map which systems this work intersects. Use this dependency map:

```
GameManager (state machine, phase timer, loot/instability, collected weapons/mods, keystone)
    ↕ signals ↕
ExtractionManager (channel state, 4 extraction type flows in main_arena.gd)
    ↕ signals ↕
EnemySpawnManager (wave composition, phase-gated enemy types, elite chance, carrier/herald pacing)
    ↕ signals ↕
CombatManager (damage resolution, flat armor, crit, knockback → damage_dealt / entity_killed signals)
    ↕ signals ↕
player.gd (stats, 6 weapon behaviors, mod system, 7 character passives, XP/leveling, iframes, dodge)
    ↕ signals ↕
enemy.gd (base chase AI, status effects: burning/chilled/frozen/shocked, elite modifier, contact damage)
    ↕ signals ↕
UpgradeManager (level-up choices, stat boost pool)
    ↕ signals ↕
ProgressionManager (save/load JSON, unlocked weapons/mods/characters, hub upgrades, run stats)
```

A new weapon touches: `data/weapons.gd`, `player.gd` (fire behavior + mod application), `projectile.gd` (if projectile-based), `CombatManager`, and potentially `main_arena.gd` (drop tables).

A new enemy touches: `scripts/entities/enemy.gd` (base class), `EnemySpawnManager` (wave composition), `main_arena.gd` (scene preloads + drop logic), `CombatManager` (damage interface), and potentially the status effect system.

A new character touches: `data/characters.gd`, `player.gd` (_load_character_stats, _apply_passive_mods, potentially get_armor/take_damage/is_invisible), `data/weapons.gd` (if exclusive weapon), `hub_roster_panel.gd`, `hub_launch_panel.gd`.

A new mod touches: `data/mods.gd`, `player.gd` (_load_weapon_mods, _apply_mods_to_projectile or _apply_direct_hit_mods), `projectile.gd` (if projectile effect), `enemy.gd` (if status effect), `hub_armory_panel.gd`, `mod_pickup.gd`.

### Step 2: Read the design docs — yourself, in full, no subagents.

Use this table to determine which docs to read. **Always read CLAUDE.md first** — it has the quick-reference formulas and prototype scope. Then read docs based on what you're building:

| Task Category | Required Docs |
|---|---|
| **Any task** | `CLAUDE.md` (always) |
| Combat / weapons / damage | `docs/core_framework_decisions.md`, `docs/mechanical_vocabulary.md`, `docs/systems_design_part1.md` |
| Enemies / spawning / AI | `docs/systems_design_part2.md`, `docs/mechanical_vocabulary.md`, `docs/core_framework_decisions.md` |
| Loot / extraction / instability | `docs/systems_design_part2.md`, `docs/core_framework_decisions.md` |
| Meta-progression / hub / characters | `docs/systems_design_part3.md` |
| Architecture / new systems | `docs/architecture_blueprint.md`, `docs/core_framework_decisions.md` |
| New content types (mods, upgrades) | `docs/mechanical_vocabulary.md`, `docs/systems_design_part1.md` |
| Visual / assets | `docs/asset_inventory.md` |
| Methodology questions | `docs/game_dev_methodology.md` |
| Project foundation / values | `docs/seed_document.md` |

Read the FULL file — do not grep for snippets. Partial reads cause tunnel vision and missed interactions. The docs contain 8 phases of deliberate design work and represent locked decisions unless Ben says otherwise.

### Step 3: Read the ENTIRE codebase — yourself, in full.

The codebase is ~35 scripts. Read ALL of them (skip `addons/`). Read them in parallel batches where possible — but read them in the main context, not via subagents.

**Batch 1 — Managers (the backbone):**
- `scripts/managers/game_manager.gd` — state machine, phase timer, loot/instability, keystone, collected weapons/mods
- `scripts/managers/combat_manager.gd` — damage resolution: flat armor, crit, knockback, damage_dealt/entity_killed signals
- `scripts/managers/upgrade_manager.gd` — level-up choice pool, stat boost application
- `scripts/managers/enemy_spawn_manager.gd` — wave composition, phase-gated types, elite chance, carrier/herald pacing
- `scripts/managers/extraction_manager.gd` — channel state, speed multiplier, complete/interrupt signals
- `scripts/managers/progression_manager.gd` — save/load JSON, unlocked weapons/mods/characters, hub upgrades, run stats

**Batch 2 — Data (static databases):**
- `data/characters.gd` — CharacterData.ALL: 7 characters, base stats, passive IDs, unlock costs, colors
- `data/weapons.gd` — WeaponData.ALL: 10 weapons, behavior types, damage/speed/range, mod slots, tints
- `data/mods.gd` — ModData.ALL: 10 mods, effect types, params (pierce count, chain range, DOT values, etc.)

**Batch 3 — Entities (the actors):**
- `scripts/entities/player.gd` — stats, 6 weapon fire behaviors, mod application, 7 passive implementations, XP/leveling, iframes, dodge, knockback
- `scripts/entities/enemy.gd` — base chase AI, contact damage (cooldown + sustained polling), status effects (burning DOT, chilled slow, frozen stun, shocked chain), elite modifier, death drops
- `scripts/entities/projectile.gd` — movement, pierce, mod effects (chain bounce, explosive AOE, elemental status, lifesteal)
- `scripts/entities/orbit_orb.gd` — Lightning Orb behavior, per-enemy hit cooldown, reads player's live damage stat
- `scripts/entities/enemy_guardian.gd` — miniboss, phase scaling, respawn hardening, keystone drops
- `scripts/entities/enemy_caster.gd` — ranged AI, preferred range, fires enemy_projectile
- `scripts/entities/enemy_carrier.gd` — flees player, drops valuable loot, despawns at arena edge
- `scripts/entities/enemy_stalker.gd` — near-invisible until close, burst damage
- `scripts/entities/enemy_herald.gd` — aura buff (+30% damage, +20% speed) to nearby enemies
- `scripts/entities/enemy_projectile.gd` — slow, visible, dodgeable, procedural draw

**Batch 4 — Pickups:**
- `scripts/pickups/xp_gem.gd` — poll-based magnet (checks pickup_radius each frame), grants XP
- `scripts/pickups/health_orb.gd` — magnet + heal
- `scripts/pickups/loot_drop.gd` — gold orb + light beam, adds to GameManager.loot_carried (raises instability)
- `scripts/pickups/weapon_pickup.gd` — tinted beam + label, adds to GameManager.collected_weapons (at risk until extraction)
- `scripts/pickups/mod_pickup.gd` — auto-equips to open slot or bags for extraction, purple hex visual
- `scripts/pickups/keystone_pickup.gd` — unlocks Locked Extraction, tall light beam, spin + bob

**Batch 5 — Scenes:**
- `scripts/main_arena.gd` — THE root scene. Wires everything together. 4 extraction zone state machines, loot/weapon/mod drop logic, camera, damage numbers, floor setup. This is the longest file (~960 lines).
- `scripts/arena_generator.gd` — procedural layout: wall collision, rock obstacles, extraction markers at fixed positions, spawn zone hints
- `scripts/hub.gd` — hub room with 5 interactive stations, panel system, player movement, torch flicker, visual tier

**Batch 6 — UI:**
- `scripts/ui/hud.gd` — health/XP bars, loot counter, extraction window countdown, keystone indicator, guardian health bar, extraction arrow
- `scripts/ui/level_up_screen.gd` — pauses game, 3 upgrade buttons, pixel font
- `scripts/ui/game_over_screen.gd` — death stats, 25% loot penalty, return to hub
- `scripts/ui/extraction_success_screen.gd` — run stats, full loot reward, weapons unlocked, return to hub
- `scripts/ui/damage_number.gd` — floating text, crit = yellow + larger, rises and fades
- `scripts/ui/debug_panel.gd` — F1-F4 hotkeys, god mode, spawn buttons, give weapons/mods/resources
- `scripts/ui/hub_panel_base.gd` — shared panel chrome (background, title bar, close button, style helpers)
- `scripts/ui/hub_launch_panel.gd` — shows loadout, BEGIN DESCENT button
- `scripts/ui/hub_armory_panel.gd` — weapon selection + mod slot management + mod picker sub-view
- `scripts/ui/hub_workshop_panel.gd` — permanent hub upgrades (Insurance License, Armory Expansion)
- `scripts/ui/hub_records_panel.gd` — lifetime stats display
- `scripts/ui/hub_roster_panel.gd` — character list (left) + detail view (right), unlock/select

### Step 4: Design pillar checkpoint.

Before writing code, explicitly answer for each pillar. These are non-negotiable design rules from `docs/seed_document.md`:

1. **"The Extract Decision"** — Does this feature make the stay-or-go choice harder and more interesting? If it doesn't touch the extraction tension at all, is it pulling weight?
2. **"Respect the Clock"** — Does this add active, rewarding gameplay per minute? Every minute of a 15-20 minute run should be doing something.
3. **"Easy to Play, Hard to Master"** — Simple inputs (WASD + auto-fire), deep decision space (build choices, extraction timing, loot risk). Does this feature add complexity to inputs or depth to decisions?
4. **"The Descent"** — Does the atmosphere come through mechanics, not just visuals? The instability system IS this pillar — carrying more loot literally makes the world more hostile.
5. **"Ship It"** — Is this the simplest version that validates the idea? When in doubt, simpler option. Scope is the enemy. The prototype is disposable.

**If a feature fails Pillar 5, simplify first.** If it fails Pillar 1, ask Ben whether it belongs at all.

### Step 5: Infrastructure vs Content — decide before coding.

**Content work** = adding data entries and wiring existing systems. The patterns already exist:
- **New weapon:** Add entry to `WeaponData.ALL` in `data/weapons.gd`. If it uses an existing behavior type (projectile/spread/beam/orbit/artillery/melee), it works automatically. If it needs a new behavior, that's infrastructure.
- **New mod:** Add entry to `ModData.ALL` in `data/mods.gd`. Add handling in `player.gd:_apply_mods_to_projectile()` (for ranged) and/or `_apply_direct_hit_mods()` (for beam/melee/artillery). Add visual/status in `enemy.gd:apply_status()` if elemental.
- **New enemy:** Create script `extends "res://scripts/entities/enemy.gd"`, override `_physics_process` for behavior. Create `.tscn` scene. Add to `EnemySpawnManager` preloads in `main_arena.gd._ready()`. Add to wave composition in `EnemySpawnManager._spawn_wave()`.
- **New character:** Add entry to `CharacterData.ALL` in `data/characters.gd`. Add to `CharacterData.ORDER`. Handle passive in `player.gd:_apply_passive_mods()`. If passive affects combat, also handle in `get_armor()`, `take_damage()`, or `is_invisible()` as needed.
- **New upgrade:** Add entry to `UpgradeManager.upgrade_pool` in `scripts/managers/upgrade_manager.gd`. If it's a flat or percent stat boost, it works automatically through `player.gd:get_stat()`.
- **New pickup:** Follow the pattern: `extends Area2D`, collision layer 16 (pickups), implement `start_magnet()` for the player's PickupCollector, wire `body_entered` for direct collection.

**Infrastructure work** = new systems, new pipelines, new patterns. Examples: active abilities (Herald's passive references them but they don't exist), multiple phases (prototype is single escalating phase), the full Instability system (currently simplified: instability = loot_carried), audio system.

**The test:** "Can I do this by adding a data entry and connecting existing signals?" If yes = content. If no = infrastructure. **If infrastructure: present your approach to Ben before implementing.** Building the wrong foundation fast is slower than building the right one once.

### Step 6: Interaction audit — trace what happens with everything that already exists.

For every new feature, systematically check interactions with ALL of these cross-cutting systems:

**7 character passives:**
- The Drifter: no passive (baseline) — does the feature work with no special behavior?
- The Scavenger: +25% pickup radius, +15% loot_find — does the feature interact with pickup collection or loot drop rates?
- The Warden: armor doubles below 50% HP (in `get_armor()`) — does the feature involve damage taken or armor calculations?
- The Spark: +0.75 flat crit_multiplier (2.25x total) — does the feature involve damage dealt or crit calculations?
- The Shade: 15% dodge chance, 0.5s invisibility on dodge (`is_invisible()` checked by enemies) — does the feature involve hit detection, enemy targeting, or player visibility?
- The Herald: ability_damage_mult=1.3, ability_cdr_mult=0.8, ability_slots=2 — does the feature add active abilities?
- The Cursed: +20% all base stats, starts every run at instability=31 (Unsettled) — does the feature interact with starting state or base stat calculations?

**10 weapon mods** (applied via `_apply_mods_to_projectile` for ranged, `_apply_direct_hit_mods` for beam/melee/artillery):
- pierce (projectile passes through 3 enemies), chain (bounces to 1 nearby for 60% damage), explosive (AOE at impact, 30% damage)
- fire (burning DOT), cryo (chilled slow → frozen stun at 3 stacks), shock (chain 50% to nearest on next hit)
- lifesteal (5% of damage → HP), size (1.5x projectile scale), crit_amp (+15% crit chance, +0.3x crit damage)
- instability_siphon (kills reduce instability by 1 — hooks into CombatManager.entity_killed)

**6 weapon behaviors** (each has its own fire path in player.gd):
- projectile (`_fire_projectile_weapon`), spread (`_fire_spread_weapon`), beam (`_fire_beam_weapon`), orbit (self-managing OrbitOrb nodes), artillery (`_fire_artillery_weapon`), melee (`_fire_melee_weapon`)

**4 extraction types** (state machines in main_arena.gd):
- Timed: portal opens after phase_duration (180s), stays open for 18s, 4s channel
- Guarded: kill guardian → 25s extraction window, guardian respawns after 45s, each respawn +35% harder
- Locked: collect keystone from guardian/elites → 2s fast channel at locked zone, loot bonus by phase depth
- Sacrifice: destroy one carried item → instant extraction, available phase 2+

**Instability loop:**
- `GameManager.add_loot(value)` → `instability = loot_carried` → `get_instability_multiplier()` returns 1.0/1.15/1.3/1.5 based on tier → multiplied into enemy HP/damage via `apply_difficulty_scaling(effective_difficulty)` in EnemySpawnManager

**Elite system:**
- Any basic enemy has time-scaling chance to spawn as Elite (5% base, +0.4%/30s, cap 22%)
- Elite: 2x HP, 1.5x damage, +3 armor, 2.5x XP, gold pulsing glow
- Elites have 20% chance to drop a mod, 5% chance to drop a keystone

**Status effects on enemies** (in `enemy.gd`):
- Burning: orange particles + 3 dmg/sec DOT for 3s
- Chilled: blue tint + 30% slow for 3s, 3 stacks → Frozen (1.5s stun, ice-blue flash)
- Shocked: yellow spark + shimmer, next hit chains 50% damage to nearest enemy within 100px

### Step 7: Performance constraints.

- `max_enemies = 150` in EnemySpawnManager. Status effects tick per-enemy per-frame in `_tick_statuses()`. Particles are `CPUParticles2D` (CPU-side, not GPU compute).
- **No O(N^2) in `_physics_process`.** `get_tree().get_nodes_in_group("enemies")` is already O(N). Don't nest it inside another O(N) loop. The shock chain and herald aura already do single-pass nearest-enemy searches — follow that pattern.
- **No per-frame array allocations in hot paths.** `.filter()` creates a new array every call. Iterate and check inline in code that runs 150+ times per frame.
- **Particle budget.** Each enemy can have: 1 sprite, 1 hurtbox Area2D, 0-1 burn particle emitter, 0-1 shock particle burst, 0-1 elite glow tween. At 150 enemies that's 300-600 nodes. Don't add per-entity child nodes without considering this.
- **Signal fan-out.** `CombatManager.damage_dealt` fires for every hit. `CombatManager.entity_killed` fires for every kill. At high enemy density with fast weapons (Ember Beam at 12 ticks/sec, Spark's Pistol at 2/sec), these signals fire rapidly. Listeners must early-return cheaply when the event isn't relevant.
- **Tween cleanup.** Every `create_tween()` that loops or references a node must be killed when the node is freed. Orphaned tweens cause errors. Follow the existing pattern of storing tweens in vars and killing them before creating new ones (see `_hit_tween` pattern in `enemy.gd`).

### Step 8: Flag spec deviations before implementing.

If any data value, formula, behavior, or interaction differs from what's specified in the design docs:

- `docs/core_framework_decisions.md` — damage formula (`max(RawDamage - Armor, 1)`), XP curve (`Base(10) x (1 + (Level-1) x 0.3)`), phase timing, instability thresholds (Stable 0-30, Unsettled 31-70, Volatile 71-120, Critical 121+), economy numbers
- `docs/mechanical_vocabulary.md` — damage type definitions, status effect behaviors, weapon behavior types, mod effect definitions
- `docs/systems_design_part1.md` through `part3.md` — system behaviors, enemy roles, extraction rules, meta-progression structure

**State the deviation and your reasoning explicitly before writing code.** Ben designs from the docs. Silent deviations become invisible errors in future design work. If you think a number should be different, say so and explain why — don't just change it.

### Step 9: After Ben tests — update docs yourself.

- If you added something not in the current `CLAUDE.md` prototype scope, update the scope checklist.
- If you built new infrastructure, document what it supports, how to extend it, and what patterns it follows.
- If you changed a formula or threshold from what's in the design docs, update the doc to match reality.
- Never delegate doc updates to subagents. Write every doc change in the main context where you have line-by-line knowledge of what was built.
- Update the memory files in `.claude/projects/` if the change is significant enough to persist across conversations.
