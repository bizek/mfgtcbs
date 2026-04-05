# Infrastructure Status

Every primitive the engine must support for all future content to be pure data. When every row says "done," no new system code is needed — characters, weapons, mods, upgrades, and enemies are just new combinations of existing behaviors, stats, and effects.

Updated: 2026-04-01

---

## Manager Layer (Autoload Singletons)

Designed as 11 autoloaded singletons in architecture_blueprint.md. Implemented as standalone scripts registered in project.godot.

| Manager | Script exists | Functional in code | Notes |
|---|---|---|---|
| GameManager | **yes** | **yes** | State machine, phase timer, instability, loot tracking, extraction type enum |
| CombatManager | **yes** | **yes** | Flat armor formula, crit roll, knockback, death detection |
| UpgradeManager | **yes** | **yes** | 12 stat-boost pool, generate_choices(), apply_upgrade() |
| EnemySpawnManager | **yes** | **yes** | Wave composition, elite chance, carrier/herald pacing, difficulty multiplier |
| ExtractionManager | **yes** | **yes** | Channel timer, speed multiplier, interrupt, reset |
| ProgressionManager | **yes** | **yes** | Save/load JSON, resource currency, character/weapon/mod unlocks, statistics |
| StatManager | **no** | **no** | Absorbed into player.gd (flat_mods + percent_mods dictionaries) — not a singleton |
| LootManager | **no** | **no** | Loot drop logic lives in main_arena.gd._on_entity_killed(); no dedicated singleton |
| ArenaManager | **no** | **no** | Arena setup in main_arena.gd + ArenaGenerator; no singleton for multi-arena loading |
| AudioManager | **no** | **no** | No implementation; no script file exists |
| UIManager | **no** | **no** | Each UI scene manages itself; no central singleton |

**Done: 6/11.** StatManager, LootManager, ArenaManager are functional but not extracted into singletons — acceptable for current scope. AudioManager and UIManager are entirely absent.

---

## Damage Pipeline

Steps in `combat_manager.gd:resolve_hit()` and applied inline by weapon behaviors.

| Step | Implemented | Notes |
|---|---|---|
| 1. Crit roll (chance × multiplier) | **yes** | Rolls randf() < crit_chance, applies multiplier |
| 2. Flat armor reduction | **yes** | max(raw - armor, 1.0); defender.get_armor() |
| 3. Knockback application | **yes** | Direction from attacker→defender, magnitude 160 px; armor-scaled on player |
| 4. Damage type routing | **no** | All hits go through same formula regardless of damage type; no type-specific resist/vuln layers |
| 5. Damage resistance modifiers | **no** | Designed (damage_resistance stat) but no code reads it |
| 6. Vulnerability / bonus damage taken | **no** | Designed (Illuminated status, v1.5) but not implemented |
| 7. DOT tick damage | **yes** | Burning: 1 dmg/sec tick in enemy._tick_statuses(); bypasses armor |
| 8. Shield absorption | **no** | Designed as secondary HP bar but no shield stat or absorption code |
| 9. Death detection | **yes** | is_dead() check after take_damage(); entity_killed signal emitted |

**Done: 5/9.** Damage type routing (resist/vuln layers) and shield are the largest structural gaps. DOT bypasses armor (intentional for now, but needs review when resist layers land).

---

## Stat System

Stats tracked in `player.gd:stats` dictionary, modified through `flat_mods` and `percent_mods`. Final value: `(base + flat) * (1 + percent)`.

### Offensive Stats

| Stat | Tracked on player | Modified by upgrades | Reads in combat code | First needed by |
|---|---|---|---|---|
| damage | **yes** | **yes** | **yes** | All weapons |
| attack_speed | **yes** | **yes** | **yes** | All weapons |
| crit_chance | **yes** | **yes** | **yes** | CombatManager |
| crit_multiplier | **yes** | **yes** | **yes** | CombatManager |
| projectile_count | **yes** | **yes** | **yes** | Projectile/spread weapons |
| pierce | **yes** | **yes** | **yes** | Projectile.gd |
| projectile_size | **yes** | **yes** | **yes** | Projectile.gd (scale_factor) |
| AOE / projectile range | listed | **no** | **no** | Explosive mod, melee range |
| projectile_speed | listed | **no** | **no** | Projectile.gd (hardcoded per weapon) |
| DOT intensity | **no** | **no** | **no** | Status effect damage scaling |

### Defensive Stats

| Stat | Tracked on player | Modified by upgrades | Reads in combat code | First needed by |
|---|---|---|---|---|
| max_hp / hp | **yes** | **yes** | **yes** | Health system |
| armor | **yes** | **yes** | **yes** | CombatManager.get_armor() |
| dodge_chance | **yes** | **no** | **yes** | Shade passive; no upgrade for it yet |
| shield | **no** | **no** | **no** | Designed; no code for secondary HP bar |
| health_regen | **no** | **no** | **no** | Designed; no passive regen tick |
| damage_resistance | **no** | **no** | **no** | Designed; stat slot missing from player stats dict |
| knockback_resistance | **no** | **no** | **no** | Designed; would reduce apply_knockback() force |

### Utility Stats

| Stat | Tracked on player | Modified by upgrades | Reads in code | First needed by |
|---|---|---|---|---|
| move_speed | **yes** | **yes** | **yes** | _physics_process |
| pickup_radius | **yes** | **yes** | **yes** | PickupCollector shape radius |
| extraction_speed | **yes** | **yes** | **yes** | ExtractionManager.start_channel() |
| loot_find | **yes** | **no** | partial | Scavenger passive sets it; no code reads it for drop rates yet |
| xp_gain | **no** | **no** | **no** | Designed; add_xp() uses hardcoded enemy xp_value |
| cooldown_reduction | **no** | **no** | **no** | Needed when active abilities land |
| luck | **no** | **no** | **no** | Designed; would affect rarity rolls and reroll pool |
| vision_radius | **no** | **no** | **no** | Phase 4-5 dark phases only |

**Done: Offensive 7/10 | Defensive 3/7 | Utility 4/8.** Dodge is tracked but not yet an upgradeable stat. Loot_find exists but nothing reads it. Shield, health regen, and damage resistance are structural gaps.

---

## Damage Types

Damage types defined in `data/weapons.gd` and `data/mods.gd`. Applied via enemy.apply_status() and CombatManager.resolve_hit(). No type-specific resist/vuln layers yet — all types go through the same flat armor formula.

| Damage type | Weapon using it | Associated status applied | Status implemented | First needed by |
|---|---|---|---|---|
| Physical | Standard Sidearm, Plasma Blade, Warden's Repeater, Spark's Pistol, Herald's Beacon | None | N/A | All basic weapons |
| Fire | Ember Beam, fire mod | Burning (DOT) | **yes** | Ember Beam, fire mod |
| Cryo | Frost Scattergun, cryo mod | Chilled → Frozen | **yes** | Frost Scattergun, cryo mod |
| Shock | Lightning Orb, shock mod | Shocked (chain) | **yes** | Lightning Orb, shock mod |
| Void | Void Mortar | Void-Touched (instability bleed on death) | **no** | Void Mortar — damage type fires but no status applied |
| Toxic | not yet | Corroded (armor shred) | **no** | v1.5 |
| Radiant | not yet | Illuminated (bonus damage taken) | **no** | v1.5 |

**Done: 4/5 v1 types have associated status effects.** Void damage type exists on the mortar weapon but Void-Touched status (instability bleed on enemy death) is unimplemented. CombatManager does not route by damage type — this is pre-structural for resist/vuln systems.

---

## Status Effects

Applied via `enemy.apply_status(effect, params)`. Tracked in enemy._statuses dict. Ticked in `enemy._tick_statuses(delta)`.

| Status effect | apply_status() branch exists | Tick/expire logic | Visual feedback | Interaction with other statuses | First needed by |
|---|---|---|---|---|---|
| Burning | **yes** | **yes** — 1 dmg/sec DOT tick | CPUParticles2D orange emitter | Refreshes on reapply | Fire mod, Ember Beam |
| Chilled | **yes** | **yes** — duration timer, speed_mult applied | Sprite blue tint | Stacks toward Frozen | Cryo mod, Frost Scattergun |
| Frozen | **yes** | **yes** — 1.5s stun, then thaws | Bright ice-blue sprite | Clears cryo stacks | 3× Cryo stacks |
| Shocked | **yes** | On-hit: chain then remove; timer expiry | Yellow spark burst + shimmer tween | Consumed by next hit | Shock mod, Lightning Orb |
| Void-Touched | **no** | **no** | — | — | Void Mortar (unimplemented) |
| Stunned (generic) | **no** | **no** | — | — | Any stun ability (future) |
| Corroded | **no** | **no** | — | — | Toxic damage (v1.5) |
| Illuminated | **no** | **no** | — | — | Radiant damage (v1.5) |

**Done: 4/8.** The 4 combat statuses covering physical-adjacent elements all work. Void-Touched (the signature "risky loot" status) is absent — enemies die but no instability bleed fires. Mechanical statuses (stunned, corroded, illuminated) await their damage types.

---

## Weapon Behaviors

Implemented in `player.gd:_fire_weapon()` as match arms. Each behavior drives a distinct combat pattern.

| Behavior | Script logic exists | Mod system wired | Visual feedback | Used by |
|---|---|---|---|---|
| projectile | **yes** | **yes** | Projectile.tscn (per-enemy hit, pierce, chain, explosive) | Standard Sidearm, Warden's Repeater, Spark's Pistol, Herald's Beacon |
| spread | **yes** | **yes** | Same as projectile, multiple projectiles per fire | Frost Scattergun |
| beam | **yes** | **yes** — _apply_direct_hit_mods() | Line2D flash with glow layer, fades in 0.06s | Ember Beam |
| orbit | **yes** | partial — orbit_orb.gd handles contact; no projectile mods | Persistent Area2D orbs orbiting player | Lightning Orb |
| artillery | **yes** | **yes** — _apply_direct_hit_mods() on detonation | Ground marker with warning flash, explosion ring + particles | Void Mortar |
| melee | **yes** | **yes** — _apply_direct_hit_mods() | Polygon2D arc with edge Line2D, fades in 0.13s | Plasma Blade |

**Done: 6/6.** All designed behaviors are implemented. Orbit mods (pierce, chain, explosive) are not wired through orbit_orb.gd — only elemental status, lifesteal, and size apply. Multi-weapon slots (Armory Expansion II → 3 weapons) are architected in ProgressionManager but only 1 active weapon fires at a time.

---

## Weapon Mods

Defined in `data/mods.gd:ModData.ALL`. Applied to projectile weapons via `player._apply_mods_to_projectile()` and to direct-hit weapons via `player._apply_direct_hit_mods()`. Loaded from ProgressionManager.weapon_mods at run start.

| Mod | Definition exists | Applied to projectile weapons | Applied to direct-hit weapons (beam/melee/artillery) | Applied to orbit weapon | First needed by |
|---|---|---|---|---|---|
| pierce | **yes** | **yes** | N/A (no projectile) | **no** | Projectile builds |
| chain | **yes** | **yes** | **yes** — _do_chain_hit() | **no** | Any weapon |
| explosive | **yes** | **yes** | **yes** — _do_explosion() | **no** | Any weapon |
| fire (elemental) | **yes** | **yes** | **yes** | **no** | Any weapon |
| cryo (elemental) | **yes** | **yes** | **yes** | **no** | Any weapon |
| shock (elemental) | **yes** | **yes** | **yes** | **no** | Any weapon |
| lifesteal | **yes** | **yes** | **yes** — heal(raw * pct) | **no** | Any weapon |
| size | **yes** | **yes** — scale_factor on Projectile | **no** (no hitbox scaling) | **no** | Projectile weapons |
| crit_amp | **yes** | **yes** — flat mods loaded at _ready | **yes** (same flat mods) | **yes** | Any weapon |
| instability_siphon | **yes** | **yes** — via CombatManager.entity_killed signal | **yes** | **yes** | Instability management builds |

**Done: 10/10 defined.** All mods have definitions and dispatch paths. Coverage gaps: orbit weapon receives none of pierce/chain/explosive/elemental/lifesteal/size. Size mod scales projectile sprite but does not affect melee arc radius or artillery AOE radius. Pickup and auto-equip mid-run works via mod_pickup.gd + player.reload_mods().

---

## Enemy Roster

Enemy scenes in `scenes/enemies/`. Base class in `scripts/entities/enemy.gd`. EnemyGuardian is a standalone script (no base class inheritance).

| Enemy type | Scene exists | Script exists | Elite variant | Status effects received | First spawn time | Notes |
|---|---|---|---|---|---|---|
| Fodder | **yes** | inherits enemy.gd | **yes** | all 4 | 0s | Basic chaser |
| Swarmer | **yes** | inherits enemy.gd | **yes** | all 4 | 0s | Fast, low HP, spawns in packs of 3-5 |
| Brute | **yes** | inherits enemy.gd | **yes** | all 4 | 120s | High HP, slow |
| Caster | **yes** | enemy_caster.gd | **yes** | all 4 | 120s | Fires enemy projectiles, stays at range |
| Carrier | **yes** | enemy_carrier.gd | **yes** | all 4 | 240s | Flees player; drops loot on kill |
| Stalker | **yes** | enemy_stalker.gd | **yes** | all 4 | 240s | Invisible until player is close |
| Herald | **yes** | enemy_herald.gd | **yes** | all 4 | 240s | Buff aura for nearby enemies; spawns with pack |
| Guardian (miniboss) | instantiated at runtime | enemy_guardian.gd | N/A | **no** | guarded extraction event | 300 HP base, scales with phase; drops keystone |
| Finisher/execution state | **no** | **no** | — | — | — | Designed (low-HP vulnerable state + proximity auto-execute) but not implemented |

**Done: 7/8 enemy types.** All designed v1 enemy types are present and spawn correctly. Guardian is fully functional. Finisher mechanic (enemy enters vulnerable state below 10-15% HP, auto-executed on proximity) is entirely absent. Void-Touched explode-on-death is missing from all enemy deaths.

---

## Enemy AI Behaviors

Behaviors implemented in each enemy script's `_physics_process`. All enemies use get_tree().get_nodes_in_group() scans — no spatial partitioning.

| AI behavior | Implemented | Used by |
|---|---|---|
| Chase player | **yes** | All enemy types |
| Sustained contact damage (poll interval) | **yes** | All enemy types |
| Flee from player | **yes** | Carrier |
| Stationary + ranged attack | **yes** | Caster |
| Invisibility reveal on proximity | **yes** | Stalker |
| Buff aura (nearby ally stat boost) | **yes** | Herald |
| Miniboss HP bar broadcast | **yes** | Guardian → GameManager.guardian_state_changed signal |
| Spatial grid / performance partitioning | **no** | Not implemented — full group scan each frame |
| Pathfinding around obstacles | **no** | All enemies walk directly toward player; obstacles not avoided |
| Respawn hardening (guardian only) | **yes** | Guardian — +35% stats per spawn_count |

**Done: 7/10.** Pathfinding and spatial partitioning will become necessary when obstacle cover is added to arenas. Current direct-chase is fine for open arenas.

---

## Upgrade System

Upgrade pool managed by `upgrade_manager.gd`. Applied to player via `player.apply_stat_upgrade()`.

### Level-Up Choice Presentation

| Feature | Implemented | Notes |
|---|---|---|
| Generate N random choices from pool | **yes** | Pool shuffled; first N taken |
| Apply chosen upgrade to player | **yes** | flat/percent mod dispatch |
| Upgrade rarity tiers (Common/Uncommon/Rare/Epic) | **no** | All 12 upgrades are same rarity; no tier weighting |
| Reroll system (2 base rerolls per run) | **no** | Not implemented; generate_choices() always draws fresh |
| Luck stat influence on rarity rolls | **no** | Luck stat does not exist |
| 4 choices instead of 3 at higher levels | **no** | Count hardcoded to 3 in level_up_screen |

### Upgrade Categories

| Category | Upgrades defined | In pool | Functional | First needed by |
|---|---|---|---|---|
| Stat boosts (passive) | 12 | **yes** | **yes** | All runs |
| Active abilities | **no** | **no** | **no** | Herald character, any active-ability build |
| Synergy triggers | **no** | **no** | **no** | Crit shockwave, DOT explosion, etc. |
| Extraction perks | partial — extraction_speed only | **yes** | **yes** | Extraction build archetype |
| Corruption upgrades | **no** | **no** | **no** | Core tension feature — "+50% Damage, 2× extraction time" |
| Evolution / Fusion recipes | **no** | **no** | **no** | End-game build goals |

**Done: 2/6 upgrade categories.** Stat boosts and one extraction perk work. Active abilities, synergy triggers, corruption upgrades, and evolution recipes are all absent. These are the depth layer that converts stat-boost spam into actual build-crafting.

---

## Extraction Types

All four extraction types are wired in `main_arena.gd`. ExtractionManager handles the channel timer for all of them.

| Extraction type | Zone spawns in arena | Player can interact | Channel completes | Special logic | Notes |
|---|---|---|---|---|---|
| Timed | **yes** — spawns when extraction_window_opened fires | **yes** — body_entered triggers start_channel() | **yes** | Window open 18s, closes after; portal respawns next cycle | Fully functional |
| Guarded | **yes** — persistent marker at fixed position | **yes** — but only when guardian is dead and window active | **yes** | Guardian respawns every 45s harder (spawn_count +1); window 25s | Fully functional |
| Locked (keystone) | **yes** — persistent locked marker | **yes** — only when player_has_keystone is true | **yes** — 2s fast channel | Guardian drops keystone guaranteed first kill | Fully functional |
| Sacrifice | **yes** — persistent sacrifice marker | **yes** — opens sacrifice UI | **yes** — after confirming sacrifice | sacrifice_weapon / sacrifice_mod / sacrifice_all_loot on GameManager | Fully functional; all sacrifice variants work |
| Channel interrupted on hit | **no** | N/A | N/A | ExtractionManager.interrupt_channel() only called on death | Gap: currently player channels freely while being attacked |
| Emergency extraction perk (auto-extract at low HP) | **no** | N/A | N/A | Designed as upgrade; no code | Extraction perks upgrade category |

**Done: 4/4 extraction types functional.** Key design intent gap: channel is not interrupted by taking damage — player can tank hits through an extraction. This removes most of the extraction tension.

---

## Hub System

Hub scene in `scenes/hub.tscn`, driven by `scripts/hub.gd`. Five panel scripts in `scripts/ui/hub_*.gd`.

| Feature | Script exists | Functional | Notes |
|---|---|---|---|
| Armory panel (equip weapon + mods) | **yes** | **yes** | Select weapon from unlocked list; drag/slot mods per weapon slot |
| Roster panel (unlock + select character) | **yes** | **yes** | Purchase with resources; select active character |
| Workshop panel (hub upgrades) | **yes** | **yes** | insurance_license (300), armory_expansion (750) |
| Records panel (lifetime stats) | **yes** | **yes** | Displays all ProgressionManager statistics |
| Launch panel (start run) | **yes** | **yes** | Triggers scene transition to main_arena |
| Hub visual tier (cosmetic upgrade based on spending) | **yes** | **yes** | get_hub_tier() returns 0/1/2 based on total_resources_spent |
| Second weapon slot (armory_expansion) | **yes** | partial | ProgressionManager.starting_weapon_slots() returns 2; only 1 weapon fires mid-run |
| Third weapon slot (armory_expansion II) | **no** | **no** | Not designed or implemented yet |
| Insurance mechanic (keep 1 loot on death) | **no** | **no** | Upgrade purchasable but no code reads insurance_license during death |
| Reroll capacity upgrade | **no** | **no** | Reroll system absent |
| Lore fragment display | **no** | **no** | Designed; no collection or display code |

**Done: 5/5 panels functional.** Hub visual tier works. Insurance upgrade can be purchased but has no runtime effect. Second weapon slot saves but only one weapon fires. Third weapon slot not yet designed.

---

## Meta-Progression

Managed by `progression_manager.gd`. Persisted to `user://progression.json`.

| Feature | Tracked | Persisted | Applied at run start | Notes |
|---|---|---|---|---|
| Resource currency | **yes** | **yes** | N/A (hub spending) | Earned from kills + loot value on extraction/death |
| Character unlocks + selection | **yes** | **yes** | **yes** | All 7 characters defined; stats + passives load in player._ready() |
| Weapon unlocks | **yes** | **yes** | **yes** | Unlocked weapons appear in armory |
| Mod collection (owned_mods) | **yes** | **yes** | **yes** | Mod inventory, slotted per weapon |
| Hub upgrades owned | **yes** | **yes** | partial | insurance_license tracked but not applied; armory_expansion tracked and read |
| Run statistics | **yes** | **yes** | N/A | total_runs, extractions, deaths, deepest_phase, total_kills, most_loot_extracted |
| Death penalty (25% loot as meta resources) | **yes** | **yes** | N/A | record_death() awards 25% of carried loot value |
| Successful extraction resources | **yes** | **yes** | N/A | record_extraction() awards earned resources |
| Loot risk (weapons/mods lost on death) | **yes** | **yes** | N/A | collected_weapons/mods cleared in new run; only committed to ProgressionManager on extraction |
| Locked extraction phase bonus (25-100%) | **yes** | **yes** | N/A | last_run_loot multiplied by phase depth bonus |
| Character cosmetic skins | **no** | **no** | N/A | Not designed for v1 |
| Research tree (persistent run-to-run upgrades) | **no** | **no** | N/A | Designed as v1.5+ feature |

**Done: 9/11 meta-progression features.** Loot risk loop (find → risk → extract → keep vs. die → lose) is fully wired. Insurance is the only purchased upgrade with no runtime effect.

---

## Arena System

Arena setup split between `scripts/main_arena.gd` and `scripts/arena_generator.gd`.

| Feature | Implemented | Notes |
|---|---|---|
| Arena bounds (hard walls) | **yes** | WallTop/Bottom/Left/Right static bodies; camera limited to bounds |
| Floor tiling (textured) | **yes** | TextureRect floor with MiniFantasy ForgottenPlains tile |
| ArenaGenerator (obstacles, cover) | **yes** | arena_generator.gd generates layout; details require reading script |
| Enemy spawn zones (edge spawning) | **yes** | _get_edge_spawn_position() in EnemySpawnManager |
| Extraction point placement | **yes** | Fixed positions hardcoded in main_arena.gd constants |
| Environmental hazards (damage zones, traps) | **no** | Designed; no implementation |
| Pathfinding obstacles (NavigationRegion2D) | **no** | Enemies walk directly; no NavMesh baked |
| Multiple phase arenas (5 distinct environments) | **no** | Single arena for all phases; no phase transition |
| Phase-themed enemy/hazard data files | **no** | Arena content is hardcoded, not data-driven |
| Hidden spots / keystone locations | **no** | Keystone dropped by guardian; no hidden location mechanic |

**Done: 5/10.** Arena is functional for prototype. Phase 5 vision (5 themed arenas loaded from data files) requires ArenaManager singleton, data-driven arena definitions, and NavigationRegion2D — none of which exist yet.

---

## Audio System

Designed as AudioManager autoload singleton with phase-based music transitions.

| Feature | Script exists | Functional | Notes |
|---|---|---|---|
| AudioManager singleton | **no** | **no** | Not implemented |
| Music (phase-based tracks) | **no** | **no** | No audio assets or playback code |
| SFX (hit, death, pickup, extraction) | **no** | **no** | No AudioStreamPlayer nodes or SFX assets |
| Ambient transitions (phase → phase) | **no** | **no** | No phase transition system exists either |
| UI sounds (menu navigation) | **no** | **no** | Hub panels have no audio |

**Done: 0/5.** Audio is entirely absent. The game runs in silence. This is a known defer — no audio assets have been integrated.

---

## UI System

UI driven by individual scene scripts (hud.gd, level_up_screen.gd, etc.). No UIManager singleton.

| Feature | Script exists | Functional | Notes |
|---|---|---|---|
| HUD — health bar | **yes** | **yes** | Reads health_changed signal from player |
| HUD — XP bar | **yes** | **yes** | Reads xp_changed signal from player |
| HUD — instability meter | **yes** | **yes** | Color-coded by tier; reads instability_changed from GameManager |
| HUD — kill counter | **yes** | **yes** | Reads GameManager.kills |
| HUD — extraction channel bar | **yes** | **yes** | Reads extraction_channel_progress |
| HUD — guardian HP bar | **yes** | **yes** | Reads guardian_state_changed signal |
| HUD — minimap | **no** | **no** | Designed; not implemented |
| Floating damage numbers | **yes** | **yes** | damage_number.gd: color-coded, tween rise+fade |
| Level-up screen (3 choices) | **yes** | **yes** | Pauses game; applies via UpgradeManager |
| Game over screen | **yes** | **yes** | Shows run stats; restart / hub buttons |
| Extraction success screen | **yes** | **yes** | Loot summary, resource award, hub/restart |
| Debug panel (F1 hotkey) | **yes** | **yes** | Spawn enemies, trigger events, toggle god mode |
| Phase transition overlay | **no** | **no** | Designed; no phase transition system exists |
| Damage type / status color coding | partial | partial | Damage numbers exist; no type-specific colors yet |
| UIManager singleton | **no** | **no** | Each UI scene is self-contained; no central manager |

**Done: 10/15.** Core gameplay HUD is complete. Minimap and phase transition are the meaningful missing pieces. UIManager absence is acceptable for current scope.

---

## Active Ability System

Designed as the second half of the hybrid auto-attack + active ability combat model. Ability slots defined on player. Herald passive already sets ability_slots = 2.

| Feature | Implemented | Notes |
|---|---|---|
| Ability slot variables on player | **yes** | ability_slots, ability_damage_mult, ability_cdr_mult declared on player |
| Ability input detection | **no** | No keybind or activation code |
| Cooldown timer per slot | **no** | No cooldown tracking |
| Ability data definitions | **no** | No ability resource/dictionary format |
| Any ability content (Dash, Shield, AoE Nuke, etc.) | **no** | Zero ability content |
| Ability upgrade on second pick | **no** | Level 1→2→3 upgrade path not designed in code |

**Done: 0/6 functional.** Ability framework is scaffolded (slot count, damage/CDR multipliers for Herald) but has zero content. The hybrid combat model cannot be tested until at least one active ability exists.

---

## Summary — What Unlocks What

| Next buildout | Infrastructure it forces |
|---|---|
| **Void-Touched status** | enemy.apply_status("void_touched") branch, on-death explosion dealing damage + instability increment, Void Mortar feels intentionally dangerous |
| **Channel interrupted on damage** | ExtractionManager.interrupt_channel() called from player.take_damage() when is_channeling; extraction tension as designed |
| **Any active ability** | Ability data format, input binding (e.g. Space), cooldown timer per slot, ability damage dispatch through existing CombatManager |
| **Upgrade rarity tiers + reroll** | Rarity field on upgrade definitions, weighted pool draw, reroll_count tracking on UpgradeManager, reroll button in level_up_screen |
| **Corruption upgrades** | New upgrade category with a "downside" field; UpgradeManager applies the stat penalty alongside the bonus; opens "risk/reward build identity" |
| **Insurance mechanic** | ProgressionManager.has_upgrade("insurance_license") check in record_death(); preserve one weapon or mod from collected_weapons/mods |
| **Second weapon slot (runtime)** | Player loads weapon_2 data from ProgressionManager.selected_weapon_2; second fire_timer; _fire_weapon_2() dispatches independently |
| **Loot_find actual reads** | LootDrop._drop_loot_table() (or main_arena equivalent) checks player.loot_find when rolling for loot type/rarity |
| **Synergy triggers + evolution recipes** | TriggerComponent or signal-based listener system; evolution checker in UpgradeManager comparing owned upgrade IDs against recipe table |
| **Environmental hazards** | DamageZone Area2D with tick_damage; DisplacementZone with push force; ArenaGenerator places them from data |
| **Multiple arenas / phase transitions** | ArenaManager singleton, arena data files, NavigationRegion2D per arena, phase_started signal drives arena swap |
| **Audio** | AudioManager singleton; AudioStreamPlayer nodes per bus; sounds hooked onto existing signals (damage_dealt, entity_killed, extraction_complete, etc.) |
