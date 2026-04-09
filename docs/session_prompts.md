# Extraction Survivors — Implementation Session Prompts

**Purpose:** Pre-written prompts for Claude Sonnet sessions to implement each milestone. Copy-paste one session at a time. Each session is self-contained with full context so Sonnet doesn't need to explore.

**Usage:** Start a fresh Claude Code session. Paste the prompt. Let it work. Test in Godot. Move to next session.

---

## MILESTONE 1: Multi-Phase Runs (5x playtime)

### Session 1A: Phase Advance Logic in GameManager

```
I need you to add multi-phase run support to my Godot 4.3 survivors game. Currently runs are a single 3-minute phase. The design calls for 5 phases.

Read CLAUDE.md first for project conventions.

**Edit `scripts/managers/game_manager.gd`:**

1. Add these constants near the top (after the existing constants around line 44):

const PHASE_DURATIONS: Array = [180.0, 210.0, 240.0, 210.0, 240.0]
const PHASE_NAMES: Array = ["The Threshold", "The Descent", "The Deep", "The Abyss", "The Core"]
const MAX_PHASES: int = 5

2. Remove the fixed `phase_duration: float = 180.0` (line 35) and replace it with:

var phase_duration: float = PHASE_DURATIONS[0]

3. In `_close_extraction_window()` (currently at line 252), change it from doing nothing after closing the window to calling a new `_advance_phase()` method:

func _close_extraction_window() -> void:
    extraction_window_active = false
    extraction_window_closed.emit()
    if phase_number < MAX_PHASES:
        _advance_phase()
    ## Phase 5 or beyond: no more timed extraction windows. Player must find another way out.

4. Add the new `_advance_phase()` method right after `_close_extraction_window()`:

func _advance_phase() -> void:
    phase_number += 1
    phase_timer = 0.0
    phase_duration = PHASE_DURATIONS[clampi(phase_number - 1, 0, PHASE_DURATIONS.size() - 1)]
    guardian_killed_this_phase = false
    player_has_keystone = false
    phase_started.emit(phase_number)

5. In `start_run()` (line 100), update the line that sets phase_duration:

phase_duration = PHASE_DURATIONS[0]

6. Update the `deepest_phase` tracking — in `on_extraction_complete()` (line 167), add before the existing code:

if phase_number > ProgressionManager.run_stats.get("deepest_phase", 0):
    ProgressionManager.run_stats["deepest_phase"] = phase_number

Do the same in `on_player_died()` (line 155).

7. In `_process()`, add a phase timer signal emission for the HUD. After the line `phase_timer += delta` (line 85), add:

phase_timer_updated.emit(phase_duration - phase_timer)

Do NOT change any other logic. The `phase_started` signal already exists (line 10). The `phase_timer_updated` signal already exists (line 11).

After making changes, verify the file has no syntax errors by checking that all functions have matching indentation and no duplicate function names.
```

### Session 1B: Phase-Based Enemy Scaling

```
I need to convert my enemy spawn system from time-based phase gates to GameManager.phase_number-based gates.

Read CLAUDE.md first for project conventions.

**Edit `scripts/managers/enemy_spawn_manager.gd`:**

The file currently uses `PHASE2_TIME` (120.0 seconds) and `PHASE3_TIME` (240.0 seconds) constants to decide when to introduce new enemy types. I need to replace ALL time-based checks with `GameManager.phase_number` checks.

1. Remove the constants `PHASE2_TIME` and `PHASE3_TIME` (lines 24-25).

2. Add phase-based stat multiplier arrays near the top:

const PHASE_HP_MULT: Array = [1.0, 1.5, 2.5, 4.0, 6.0]
const PHASE_DMG_MULT: Array = [1.0, 1.3, 1.6, 2.0, 2.5]
const PHASE_SPAWN_MULT: Array = [1.0, 1.2, 1.5, 1.8, 2.2]

3. In `_process()`, change the carrier spawn check (line 66) from:
   `if run_time >= PHASE3_TIME` → `if GameManager.phase_number >= 3`

4. Change the herald spawn check (line 75) from:
   `if run_time >= PHASE3_TIME` → `if GameManager.phase_number >= 3`

5. In `_spawn_wave()`, change the brute spawn check (line 119) from:
   `if GameManager.run_time >= PHASE2_TIME` → `if GameManager.phase_number >= 2`

6. Change the caster spawn check (line 128) from:
   `if GameManager.run_time >= PHASE2_TIME` → `if GameManager.phase_number >= 2`

7. Change the stalker spawn check (line 136) from:
   `if GameManager.run_time >= PHASE3_TIME` → `if GameManager.phase_number >= 3`

8. Modify `_spawn_enemy_at_spawn_pos()` and `_spawn_single_enemy()` to apply phase multipliers. In both functions, where `effective_difficulty` is computed, multiply by the phase multiplier:

var phase_idx: int = clampi(GameManager.phase_number - 1, 0, 4)
var effective_difficulty: float = GameManager.difficulty_multiplier * GameManager.get_instability_multiplier() * PHASE_HP_MULT[phase_idx]

Do the same in `_spawn_enemy_at_edge()` and `_spawn_herald_pack()`.

9. Scale spawn count by phase. In `_spawn_wave()`, modify the count calculation (line 111):

var phase_idx: int = clampi(GameManager.phase_number - 1, 0, 4)
var count: int = mini(int(enemies_per_spawn * difficulty * PHASE_SPAWN_MULT[phase_idx]), max_enemies - active_enemies)

10. Also scale elite chance by phase. In `_get_elite_chance()`, add a phase bonus:

func _get_elite_chance() -> float:
    var phase_bonus: float = (GameManager.phase_number - 1) * 0.03
    return clampf(0.05 + (GameManager.run_time / 30.0) * 0.004 + phase_bonus, 0.05, 0.35)

11. Connect to phase_started to reset carrier/herald timers between phases. Add to `start_spawning()`:

if not GameManager.phase_started.is_connected(_on_phase_started):
    GameManager.phase_started.connect(_on_phase_started)

And add the handler:

func _on_phase_started(_phase: int) -> void:
    _carrier_timer = CARRIER_INTERVAL * 0.8
    _herald_timer = HERALD_INTERVAL

The brute/caster roll ramp rates (`BRUTE_ROLL_RAMP`, `CASTER_ROLL_RAMP`) can stay as-is since they use `GameManager.run_time` which still accumulates across phases — this means later phases have higher spawn chances for these enemies, which is correct.

Do NOT add new enemy types or change enemy scenes. Only modify spawn logic.
```

### Session 1C: HUD Phase Indicator + Transition Feedback

```
I need to add phase indicators to the HUD for my multi-phase run system.

Read CLAUDE.md first for project conventions. Important: This project uses a 4x viewport scaling factor. The viewport is 480x270. Font sizes should be small (10-16px) since they get scaled up 4x.

**Edit `scripts/ui/hud.gd`:**

The HUD scene is at `scenes/hud.tscn` — do NOT hand-edit the .tscn file. Build new UI elements programmatically in the script.

1. Add a phase name label. In `_ready()`, after the existing setup code, build a phase label programmatically:

var _phase_label: Label = null
var _phase_flash_label: Label = null
var _extraction_warning_label: Label = null

In `_ready()`, create the phase label in the top-center area:
- Position it centered at the top of the viewport (around x=240, y=2)
- Use the pixel font at `res://assets/fonts/m5x7.ttf`, size 12
- Color: white with slight transparency
- Initial text: "PHASE 1: THE THRESHOLD"

2. Connect to `GameManager.phase_started` signal. On phase change:
- Update the phase label text to `"PHASE %d: %s" % [phase, GameManager.PHASE_NAMES[phase - 1]]`
- Show a large centered flash label with the phase name that fades out over 2 seconds using a tween

3. Add a 10-second countdown warning before the extraction window opens. In `_process()`:
- Calculate `var time_remaining: float = GameManager.phase_duration - GameManager.phase_timer`
- When `time_remaining <= 10.0 and time_remaining > 0.0 and not GameManager.extraction_window_active`:
  - Show the warning label: `"EXTRACTION IN %d" % ceili(time_remaining)`
  - Color: yellow, blinking (toggle visibility every 0.5s using the existing `_blink_timer`)
- Hide the warning label otherwise

4. When `GameManager.phase_number >= GameManager.MAX_PHASES` (phase 5), show "THE CORE — NO TIMED EXIT" instead of the countdown.

Keep the existing extraction window label, loot-at-risk label, and all other HUD elements unchanged. The new elements should not overlap with TopLeft (HP/XP/loot) or TopRight (timer/kills).
```

### Session 1D: Extraction Zone Reset Between Phases

```
I need to make extraction zones reset and re-gate between phases in my multi-phase run system.

Read CLAUDE.md first for project conventions.

**Edit `scripts/main_arena.gd`:**

Currently `_setup_extraction_zones()` runs once at run start and gates zones by `GameManager.phase_number`. When phases advance, the zones need to update.

1. In `_ready()` or wherever signals are connected (around line 75), connect to the phase_started signal:

GameManager.phase_started.connect(_on_phase_advanced)

2. Add the handler:

func _on_phase_advanced(phase: int) -> void:
    ## Reset guardian for new phase
    if _guarded:
        _guarded.reset_for_new_phase()
    
    ## Activate guarded extraction if phase >= 3 (or always — it's a core extraction type)
    ## The guardian being alive IS the gate, so just activate it every phase
    if _guarded and phase >= 1:
        _guarded.activate()
    
    ## Sacrifice activates at phase 2+
    if _sacrifice and phase >= 2:
        _sacrifice.activate_label()
    
    ## Clear timed extraction reference (new one spawns when window opens)
    if _timed and is_instance_valid(_timed):
        _timed.queue_free()
        _timed = null
    
    ## Reset channeling state
    _active_channeling_type = ""
    ExtractionManager.channel_duration = 4.0

3. The guarded extraction needs a `reset_for_new_phase()` method. **Edit `scripts/extraction/guarded_extraction.gd`:**

Add a method that:
- Respawns the guardian at full health
- Resets the extraction state to "inactive" (guardian alive = locked)
- Resets visual state

Read the file first to understand its current state machine (it has states like "inactive", "guardian_alive", "active", "cooldown"). The reset should put it back to "guardian_alive" state with a fresh guardian.

4. Phase 5 special: In `_on_extraction_window_opened()`, add a guard at the top:

if GameManager.phase_number >= GameManager.MAX_PHASES:
    return  ## Phase 5 has no timed extraction

This prevents the timed portal from spawning in Phase 5. The player must use Guarded (kill guardian), Locked (find keystone), or Sacrifice to escape.

Do NOT modify the extraction zone positions or visual styling. Only modify state management.
```

---

## MILESTONE 2: Upgrade Evolutions

### Session 2A: Evolution Recipes + Detection + Application

```
I need to add an evolution/fusion system to the level-up upgrades. When a player has taken specific upgrade combinations, a "super-upgrade" should appear as a choice that replaces both prerequisites.

Read CLAUDE.md first for project conventions.

**Edit `scripts/managers/upgrade_manager.gd`:**

This file is small (46 lines). It has:
- `upgrade_pool`: Array of 11 stat boost dictionaries with keys: id, name, description, stat, type, value
- `player_upgrades`: Array of chosen upgrades
- `generate_choices(count)`: returns `count` random upgrades from the pool
- `apply_upgrade(upgrade, player)`: appends to player_upgrades, calls player.apply_stat_upgrade()
- `reset()`: clears player_upgrades

1. Add evolution recipe data after the upgrade_pool initialization:

var EVOLUTION_RECIPES: Array[Dictionary] = [
    {
        "id": "glass_cannon",
        "name": "GLASS CANNON",
        "description": "+40% Damage, +10% Crit Chance, -15 Max HP",
        "requires": ["damage_up", "crit_chance_up"],
        "is_evolution": true,
        "effects": [
            {"stat": "damage", "type": "percent", "value": 0.40},
            {"stat": "crit_chance", "type": "flat", "value": 0.10},
            {"stat": "max_hp", "type": "flat", "value": -15.0},
        ],
    },
    {
        "id": "juggernaut",
        "name": "JUGGERNAUT",
        "description": "+40 Max HP, +5 Armor",
        "requires": ["max_hp_up", "armor_up"],
        "is_evolution": true,
        "effects": [
            {"stat": "max_hp", "type": "flat", "value": 40.0},
            {"stat": "armor", "type": "flat", "value": 5.0},
        ],
    },
    {
        "id": "bullet_storm",
        "name": "BULLET STORM",
        "description": "+2 Projectiles, +25% Attack Speed",
        "requires": ["projectile_count_up", "attack_speed_up"],
        "is_evolution": true,
        "effects": [
            {"stat": "projectile_count", "type": "flat", "value": 2.0},
            {"stat": "attack_speed", "type": "percent", "value": 0.25},
        ],
    },
    {
        "id": "velocity",
        "name": "VELOCITY",
        "description": "+25% Move Speed, +20% Attack Speed",
        "requires": ["move_speed_up", "attack_speed_up"],
        "is_evolution": true,
        "effects": [
            {"stat": "move_speed", "type": "percent", "value": 0.25},
            {"stat": "attack_speed", "type": "percent", "value": 0.20},
        ],
    },
    {
        "id": "titan_rounds",
        "name": "TITAN ROUNDS",
        "description": "+40% Projectile Size, +50% Crit Damage",
        "requires": ["projectile_size_up", "crit_damage_up"],
        "is_evolution": true,
        "effects": [
            {"stat": "projectile_size", "type": "percent", "value": 0.40},
            {"stat": "crit_multiplier", "type": "flat", "value": 0.50},
        ],
    },
    {
        "id": "magnetar",
        "name": "MAGNETAR",
        "description": "+50% Pickup Radius, +2 Pierce",
        "requires": ["pickup_radius_up", "pierce_up"],
        "is_evolution": true,
        "effects": [
            {"stat": "pickup_radius", "type": "percent", "value": 0.50},
            {"stat": "pierce", "type": "flat", "value": 2.0},
        ],
    },
    {
        "id": "fortress",
        "name": "FORTRESS",
        "description": "+30 Max HP, +4 Armor, -10% Move Speed",
        "requires": ["max_hp_up", "armor_up"],
        "is_evolution": true,
        "effects": [
            {"stat": "max_hp", "type": "flat", "value": 30.0},
            {"stat": "armor", "type": "flat", "value": 4.0},
            {"stat": "move_speed", "type": "percent", "value": -0.10},
        ],
    },
    {
        "id": "assassin",
        "name": "ASSASSIN",
        "description": "+10% Crit Chance, +50% Crit Damage, +15% Move Speed",
        "requires": ["crit_chance_up", "crit_damage_up"],
        "is_evolution": true,
        "effects": [
            {"stat": "crit_chance", "type": "flat", "value": 0.10},
            {"stat": "crit_multiplier", "type": "flat", "value": 0.50},
            {"stat": "move_speed", "type": "percent", "value": 0.15},
        ],
    },
]

Note: "juggernaut" and "fortress" share the same requires. That's fine — `generate_choices` will only inject ONE evolution per level-up, so having multiple options for the same prereqs adds variety.

2. Track earned evolutions to prevent duplicates:

var earned_evolutions: Array[String] = []

3. Modify `generate_choices()` to check for available evolutions:

func generate_choices(count: int = 3) -> Array[Dictionary]:
    var pool_copy := upgrade_pool.duplicate()
    pool_copy.shuffle()
    var choices: Array[Dictionary] = []
    for i in range(mini(count, pool_copy.size())):
        choices.append(pool_copy[i])
    
    ## Check if player qualifies for any evolution
    var available_evo: Dictionary = _get_available_evolution()
    if not available_evo.is_empty():
        ## Replace the last choice with the evolution
        choices[choices.size() - 1] = available_evo
    
    return choices

4. Add the evolution detection helper:

func _get_available_evolution() -> Dictionary:
    var owned_ids: Array[String] = []
    for u in player_upgrades:
        owned_ids.append(u["id"])
    
    var eligible: Array[Dictionary] = []
    for recipe in EVOLUTION_RECIPES:
        if recipe["id"] in earned_evolutions:
            continue
        var has_all: bool = true
        for req in recipe["requires"]:
            if req not in owned_ids:
                has_all = false
                break
        if has_all:
            eligible.append(recipe)
    
    if eligible.is_empty():
        return {}
    return eligible[randi() % eligible.size()]

5. Modify `apply_upgrade()` to handle evolutions:

func apply_upgrade(upgrade: Dictionary, player: Node) -> void:
    if upgrade.get("is_evolution", false):
        _apply_evolution(upgrade, player)
    else:
        player_upgrades.append(upgrade)
        if player.has_method("apply_stat_upgrade"):
            player.apply_stat_upgrade(upgrade)
    upgrade_chosen.emit(upgrade)

6. Add evolution application that reverses prereqs and applies combined effect:

func _apply_evolution(evo: Dictionary, player: Node) -> void:
    ## Remove prerequisite upgrades and reverse their stats
    for req_id in evo["requires"]:
        for i in range(player_upgrades.size() - 1, -1, -1):
            if player_upgrades[i]["id"] == req_id:
                var old := player_upgrades[i]
                if player.has_method("remove_stat_upgrade"):
                    player.remove_stat_upgrade(old)
                player_upgrades.remove_at(i)
                break
    
    ## Apply each effect in the evolution
    for effect in evo["effects"]:
        var pseudo_upgrade := {
            "id": evo["id"],
            "stat": effect["stat"],
            "type": effect["type"],
            "value": effect["value"],
        }
        if player.has_method("apply_stat_upgrade"):
            player.apply_stat_upgrade(pseudo_upgrade)
    
    player_upgrades.append(evo)
    earned_evolutions.append(evo["id"])

7. Update `reset()`:

func reset() -> void:
    player_upgrades.clear()
    earned_evolutions.clear()

**Edit `scripts/entities/player.gd`:**

The player needs a `remove_stat_upgrade()` method to reverse a stat boost. Read the file first to find how `apply_stat_upgrade()` works (it uses flat_mods and percent_mods dictionaries or similar). Add a mirror method that subtracts instead of adds.

**Edit `scripts/ui/level_up_screen.gd`:**

In `_show_choices()`, give evolution choices a distinct visual:
- Check `upgrade.get("is_evolution", false)`
- If true, set the button's font color to gold (Color(1.0, 0.85, 0.15)) and add a "★ " prefix to the name
- Keep everything else the same
```

---

## MILESTONE 3: Elite Modifiers

### Session 3: Behavioral Elite Modifiers

```
I need to expand the elite enemy system from a simple stat boost to behavioral modifiers.

Read CLAUDE.md first for project conventions.

**Edit `scripts/entities/enemy.gd`:**

Currently `apply_elite_modifier()` (around line 173) just doubles HP, 1.5x damage, +3 armor, and applies a gold glow. I need it to also select and apply a behavioral modifier.

1. Add modifier constants near the top of the file:

enum EliteModifier { NONE, HASTING, EXPLODING, SHIELDED }
var elite_modifier: int = EliteModifier.NONE
var _shield_hp: float = 0.0
var _shield_max: float = 0.0

2. Modify `apply_elite_modifier()` to select a random modifier:

func apply_elite_modifier() -> void:
    ## Base elite stat boost (keep existing)
    max_hp *= 2.0
    hp = max_hp
    contact_damage *= 1.5
    armor += 3.0
    xp_value *= 2.5
    is_elite = true
    
    ## Select a random behavioral modifier
    var modifiers: Array = [EliteModifier.HASTING, EliteModifier.EXPLODING, EliteModifier.SHIELDED]
    elite_modifier = modifiers[randi() % modifiers.size()]
    
    ## Phase 4+: add a second modifier (different from first)
    ## Skip for now — just apply one modifier
    
    match elite_modifier:
        EliteModifier.HASTING:
            move_speed *= 2.0
            _base_modulate = Color(0.2, 1.0, 0.3, 1.0)
        EliteModifier.EXPLODING:
            _base_modulate = Color(1.0, 0.25, 0.1, 1.0)
        EliteModifier.SHIELDED:
            _shield_max = max_hp * 0.4
            _shield_hp = _shield_max
            _base_modulate = Color(0.3, 0.5, 1.0, 1.0)
    
    if sprite:
        sprite.modulate = _base_modulate
        var glow_tween := create_tween().set_loops()
        glow_tween.tween_property(sprite, "modulate", _base_modulate * 1.6, 0.45)
        glow_tween.tween_property(sprite, "modulate", _base_modulate * 0.7, 0.45)

3. Modify `take_damage()` to handle shields. Add at the very top of `take_damage()`, before the existing shock check:

    ## Shielded: absorb damage into shield first
    if _shield_hp > 0.0:
        _shield_hp -= amount
        if _shield_hp <= 0.0:
            ## Shield broken — apply remaining damage normally
            amount = -_shield_hp
            _shield_hp = 0.0
            _base_modulate = Color(1.0, 0.75, 0.1, 1.0)  ## Revert to gold (standard elite)
            if sprite:
                sprite.modulate = Color(6.0, 6.0, 6.0, 1.0)  ## Bright flash on shield break
                var break_tween := create_tween()
                break_tween.tween_property(sprite, "modulate", _base_modulate, 0.15)
            ## Spawn shield break particles
            VFXHelpers.spawn_burst(
                get_tree().current_scene, global_position,
                Color(0.3, 0.5, 1.0, 0.9), 10, 0.35, 40.0, 100.0, 2.0, 4.0,
                Vector2.ZERO)
        else:
            ## Shield still up — show hit but no HP damage
            if sprite:
                if _hit_tween and _hit_tween.is_valid():
                    _hit_tween.kill()
                sprite.modulate = Color(0.5, 0.7, 1.5, 1.0)
                _hit_tween = create_tween()
                _hit_tween.tween_property(sprite, "modulate", _base_modulate, 0.08)
            return  ## No HP damage while shield holds
    
    if amount <= 0.0:
        return

4. Modify `_die()` to handle exploding. Add right after the `_is_dead = true` and `died.emit(self)` lines, BEFORE the void_touched check:

    ## Exploding elite: AoE damage on death
    if elite_modifier == EliteModifier.EXPLODING:
        _exploding_death()

5. Add the exploding death method:

func _exploding_death() -> void:
    const EXPLODE_RADIUS: float = 60.0
    const EXPLODE_DAMAGE: float = 15.0
    ## Damage the player if in range
    var player := get_tree().get_first_node_in_group("player")
    if player and global_position.distance_to(player.global_position) <= EXPLODE_RADIUS:
        if player.has_method("take_damage"):
            CombatManager.resolve_hit(self, player, EXPLODE_DAMAGE, 0.0, 1.0)
    ## Visual: red expanding ring
    VFXHelpers.spawn_expanding_ring(
        get_tree().current_scene, global_position,
        Color(1.0, 0.2, 0.05, 0.6), EXPLODE_RADIUS, 1.2, 0.3)
    VFXHelpers.spawn_burst(
        get_tree().current_scene, global_position,
        Color(1.0, 0.35, 0.0, 0.9), 12, 0.4, 40.0, 120.0, 2.5, 5.0,
        Vector2.ZERO)

Read `scripts/helpers/vfx_helpers.gd` first to confirm the `spawn_expanding_ring` and `spawn_burst` method signatures match. Adjust parameters if needed.

Do NOT modify enemy subclass scripts (enemy_guardian.gd, etc.) — this all goes in the base enemy.gd.
```

---

## MILESTONE 4: New Weapon Mods (5 sessions, one per mod)

### Session 4A: Split Mod

```
I need to add a "Split" weapon mod to my Godot 4.3 survivors game. When a projectile with this mod hits an enemy or expires, it splits into 2-3 smaller projectiles at diverging angles.

Read CLAUDE.md first for project conventions.

**Step 1: Add mod data to `data/mods.gd`**

Add to the ALL dictionary:

"split": {
    "id": "split",
    "name": "SPLIT",
    "desc": "Projectiles split into 3 smaller shots on hit or expiry.",
    "color": Color(0.90, 0.55, 0.95),
    "effect_type": "split",
    "params": { "split_count": 3, "split_damage_mult": 0.4 },
},

Add "split" to the ORDER array.

**Step 2: Implement in projectile/weapon system**

Read `scripts/entities/projectile.gd` and `scripts/entities/weapon_controller.gd` first to understand how mods are currently applied.

The split mod should:
- When a projectile hits an enemy (on_hit or equivalent), spawn `split_count` new projectiles
- New projectiles spread evenly over a 90-degree arc centered on the original direction
- Each split projectile deals `original_damage * split_damage_mult` (40%)
- Split projectiles should NOT split again (add a `_is_split: bool = false` flag, set true on children)
- Split projectiles inherit the same weapon mods EXCEPT split (to avoid infinite recursion)
- Split projectiles have half the original lifetime remaining or 0.5s minimum

Follow the same pattern used by existing mods (chain, explosive) for spawning new entities from hit events.
```

### Session 4B: Gravity Mod

```
I need to add a "Gravity" weapon mod. Projectiles curve toward the nearest enemy.

Read CLAUDE.md first. Read `scripts/entities/projectile.gd` first.

**Add to `data/mods.gd` ALL dictionary:**

"gravity": {
    "id": "gravity",
    "name": "GRAVITY",
    "desc": "Projectiles curve toward the nearest enemy.",
    "color": Color(0.50, 0.20, 0.80),
    "effect_type": "gravity",
    "params": { "pull_strength": 300.0, "seek_range": 150.0 },
},

Add "gravity" to ORDER array.

**Implement in `scripts/entities/projectile.gd`:**

In the projectile's movement/physics_process:
- If the projectile has the gravity mod, find the nearest enemy within `seek_range` pixels
- Apply a steering force toward that enemy: `velocity += direction_to_enemy * pull_strength * delta`
- Normalize velocity to maintain original speed (adjust direction, not speed)
- Use the SpatialGrid if available for efficient enemy lookup, otherwise use `get_tree().get_nodes_in_group("enemies")` with distance check

This should be a gentle curve, not instant lock-on. The pull_strength controls how tight the turn is.
```

### Session 4C: Ricochet Mod

```
I need to add a "Ricochet" weapon mod. Projectiles bounce off arena walls instead of despawning.

Read CLAUDE.md first. Read `scripts/entities/projectile.gd` first.

**Add to `data/mods.gd` ALL dictionary:**

"ricochet": {
    "id": "ricochet",
    "name": "RICOCHET",
    "desc": "Projectiles bounce off arena walls up to 3 times.",
    "color": Color(0.75, 0.85, 0.95),
    "effect_type": "ricochet",
    "params": { "max_bounces": 3 },
},

Add "ricochet" to ORDER array.

**Implement in `scripts/entities/projectile.gd`:**

- Add a `_bounces_remaining: int = 0` variable
- When the ricochet mod is active, set `_bounces_remaining` from params
- When the projectile reaches the arena boundary (check against `GameManager` arena bounds or the bounds passed to the spawn system), reflect its velocity off the wall normal instead of despawning
- Decrement `_bounces_remaining` on each bounce
- When bounces run out, despawn normally
- Arena bounds are defined in main_arena.gd as ARENA_HALF_W=800, ARENA_HALF_H=600 (centered at origin)

Read how projectiles currently handle lifetime/despawn to find the right insertion point.
```

### Session 4D: Accelerating Mod

```
I need to add an "Accelerating" weapon mod. The weapon's attack speed increases the longer you continuously fire.

Read CLAUDE.md first. Read `scripts/entities/weapon_controller.gd` first.

**Add to `data/mods.gd` ALL dictionary:**

"accelerating": {
    "id": "accelerating",
    "name": "ACCELERATING",
    "desc": "Attack speed ramps up by 50% over 3 seconds of sustained fire.",
    "color": Color(0.95, 0.65, 0.15),
    "effect_type": "accelerating",
    "params": { "max_bonus": 0.5, "ramp_time": 3.0 },
},

Add "accelerating" to ORDER array.

**Implement in `scripts/entities/weapon_controller.gd`:**

- Track a `_sustained_fire_timer: float = 0.0` variable
- When the weapon fires, increment the timer by delta each frame (or by fire interval)
- When the weapon is NOT firing (no enemies in range, or between shots if gap > threshold), decay the timer toward 0
- Calculate bonus: `var accel_bonus: float = clampf(_sustained_fire_timer / ramp_time, 0.0, 1.0) * max_bonus`
- Apply the bonus as a multiplier to attack speed when computing fire rate
- Reset the timer on weapon switch or phase change

This mod is most impactful on fast-firing weapons (Ember Beam, Spark's Pistol) and least on slow weapons (Void Mortar).
```

### Session 4E: DOT Applicator Mod

```
I need to add a "DOT Applicator" weapon mod. All hits apply a bleed damage-over-time effect regardless of weapon damage type.

Read CLAUDE.md first. Read `scripts/entities/weapon_controller.gd` and `scripts/entities/enemy.gd` (the status effect system around the `apply_status` method) first.

**Add to `data/mods.gd` ALL dictionary:**

"dot_applicator": {
    "id": "dot_applicator",
    "name": "DOT APPLICATOR",
    "desc": "All hits apply Bleed: 2 dmg/sec for 4 seconds. Stacks duration.",
    "color": Color(0.85, 0.15, 0.15),
    "effect_type": "dot_applicator",
    "params": { "dot_damage": 2.0, "dot_duration": 4.0 },
},

Add "dot_applicator" to ORDER array.

**Implement:**

The enemy already has a fire DOT system in `apply_status("fire", params)`. The bleed DOT should work the same way but as a separate status.

1. In `scripts/entities/enemy.gd`, add a "bleed" case to `apply_status()` that works identically to "fire" (timer, dot_damage, tick_timer). Also add it to `_tick_statuses()`.

2. In the weapon hit resolution (wherever chain/explosive/elemental mods are applied on hit), add a check: if the weapon has the "dot_applicator" mod, call `enemy.apply_status("bleed", params)` on the hit target.

Keep it simple — reuse the fire DOT pattern exactly. The only visual difference: bleed particles should be red (Color(0.85, 0.1, 0.1)) instead of fire's orange.
```

---

## MILESTONE 5: New Enemy Types

### Session 5A: Mimic Enemy

```
I need to add a Mimic enemy type that disguises itself as a loot pickup and attacks when the player gets close.

Read CLAUDE.md first. Read `scripts/entities/enemy.gd` for the base enemy pattern. Read `scripts/pickups/mod_pickup.gd` or any pickup script to understand pickup visuals.

**Create new files:**
- `scripts/entities/enemy_mimic.gd`
- `scenes/enemies/mimic.tscn`

**Mimic behavior:**
1. Spawns looking identical to a mod pickup or weapon pickup (random)
2. Is in the "pickups" group initially, NOT "enemies" — no health bar, no enemy behavior
3. When the player enters a 50px radius trigger, the mimic:
   - Removes itself from "pickups" group, adds to "enemies" group
   - Plays a "reveal" animation (scale pop + color shift to hostile red)
   - Becomes a fast, aggressive melee enemy (HP: 25, speed: 140, damage: 20, armor: 0, XP: 3.0)
4. After reveal, behaves like a standard chase enemy (reuse base enemy.gd chase logic)

**Stats:**
- max_hp: 25.0 (fragile — meant to surprise, not tank)
- move_speed: 140.0 (fast burst after reveal)
- contact_damage: 20.0 (punishing surprise hit)
- armor: 0.0
- xp_value: 3.0

**Spawn integration — edit `scripts/managers/enemy_spawn_manager.gd`:**
- Add `@export var mimic_scene: PackedScene`
- At phase 2+, when a loot drop would normally spawn (you'll need to hook into the loot/pickup spawn flow), there's a 5% chance it spawns a mimic instead
- OR: spawn 1 mimic per phase transition, disguised at a random position. This is simpler.

**The simpler approach:** In `_on_phase_started()` in enemy_spawn_manager.gd, if `phase >= 2`, spawn 1 mimic at a random position within the arena. It sits there looking like loot until the player approaches.

The mimic scene structure should mirror other enemies: CharacterBody2D root, AnimatedSprite2D child named "Sprite", Area2D child named "Hurtbox" with CollisionShape2D. Also add an Area2D named "RevealTrigger" with a 50px radius circle for detecting player approach.

For the disguise visual: use a simple colored rectangle (like pickups use) — match the mod_pickup visual style. On reveal, swap to the enemy sprite.
```

### Session 5B: Anchor Enemy

```
I need to add an Anchor enemy type that plants itself at a location and creates a damaging zone around it, forcing the player to reroute or prioritize killing it.

Read CLAUDE.md first. Read `scripts/entities/enemy.gd` for the base enemy pattern.

**Create new files:**
- `scripts/entities/enemy_anchor.gd`
- `scenes/enemies/anchor.tscn`

**Anchor behavior:**
1. Spawns at a random arena position (not near player — use standard spawn position logic)
2. Does NOT chase the player. Completely stationary.
3. After a 1.5-second "planting" delay, creates a circular damage zone (radius: 80px)
4. The damage zone deals 5 damage per second to the player if they're inside it
5. The zone also applies a 20% slow to the player while inside
6. Visually: pulsing dark red/purple circle on the ground, with particles rising from the edges
7. When killed, the zone disappears immediately with a satisfying collapse effect

**Stats:**
- max_hp: 45.0 (tanky enough to require attention)
- move_speed: 0.0 (stationary)
- contact_damage: 0.0 (damage comes from the zone, not contact)
- armor: 2.0
- xp_value: 4.0

**Implementation:**
- Extend `scripts/entities/enemy.gd` (or CharacterBody2D directly)
- Override `_physics_process` to NOT chase the player
- Use a Timer or manual delta countdown for the planting delay
- The damage zone is an Area2D child with a CircleShape2D (radius 80)
- Check for player overlap every tick and deal damage (respect a damage interval like 1.0s to avoid instant-kill)
- The slow effect: when player enters zone, reduce player move speed by 20%. Restore on exit.
- Player slow should stack with at most 1 anchor (don't let 5 anchors make player immobile)

**Spawn integration — edit `scripts/managers/enemy_spawn_manager.gd`:**
- Add `@export var anchor_scene: PackedScene`
- At phase 2+, spawn 1 anchor every 45 seconds
- Phase 4+: spawn 2 per interval
- Anchors count toward the active_enemies cap

**The anchor scene structure:** CharacterBody2D root, AnimatedSprite2D child "Sprite" (can be a simple static sprite — small dark crystal/pillar shape), Area2D child "Hurtbox" for being attacked, Area2D child "DamageZone" with CircleShape2D radius 80 for dealing zone damage.

Don't forget to wire it in `scripts/main_arena.gd` — assign the scene to EnemySpawnManager.anchor_scene in `_ready()`, same pattern as existing enemy scene assignments.
```

---

## TESTING CHECKLIST

After completing each milestone, run through these in Godot:

**Milestone 1:**
- [ ] Run starts at Phase 1, timer counts down from 180s
- [ ] Extraction window opens at 0s, stays 18s, then closes
- [ ] Phase advances to 2 when window closes (HUD updates)
- [ ] New enemies appear at correct phases (Brutes at 2, Stalkers at 3)
- [ ] Phase 5 has NO timed extraction
- [ ] Guarded/Locked/Sacrifice work across phase transitions
- [ ] Guardian respawns between phases
- [ ] Full 5-phase run takes ~15-20 minutes

**Milestone 2:**
- [ ] Taking Damage Up + Crit Chance Up causes Glass Cannon to appear next level
- [ ] Evolution has gold/star visual in level-up screen
- [ ] Selecting evolution removes prerequisites from stat sheet
- [ ] Evolution stats apply correctly (verify HP loss for Glass Cannon)
- [ ] Can't earn same evolution twice

**Milestone 3:**
- [ ] Elites spawn with colored glow (green/red/blue) not just gold
- [ ] Hasting elites are noticeably faster
- [ ] Exploding elites deal AoE on death (check player takes damage)
- [ ] Shielded elites absorb hits (shield break visual + sound)

**Milestone 4:**
- [ ] Each new mod appears in data, can be equipped in armory
- [ ] Split: projectile spawns 3 smaller shots on hit
- [ ] Gravity: projectiles curve toward enemies
- [ ] Ricochet: projectiles bounce off walls
- [ ] Accelerating: fire rate increases during sustained fire
- [ ] DOT Applicator: bleed ticks appear on enemies

**Milestone 5:**
- [ ] Mimics look like pickups, reveal on approach
- [ ] Anchors create visible damage zones
- [ ] Both spawn at correct phase thresholds
