class_name LevelData
extends RefCounted
## Per-level definitions for all five circles.
## Each level owns: a floor texture, per-phase wave compositions (enemy_id → weight),
## and a scene_map (level-specific enemy_id → .tscn path).
##
## Wave compositions use level-specific IDs for the first three phases where theming
## matters most. Later phases fall through to EnemySpawnManager's generic WAVE_COMPOSITION
## if a key has no entry in scene_map (e.g. "stalker", "anchor" are shared across levels).
##
## New level: add an entry to LEVELS. Register its enemy IDs in EnemyRegistry and
## add .tscn scenes. EnemySpawnManager and MainArena read from here automatically.

const LEVELS: Dictionary = {
	1: {
		"name": "The Cave",
		"floor_path": "res://assets/minifantasy/Minifantasy_DeepCaves_v2.0/Minifantasy_DeepCaves_Assets/PremadeScene/SeparateLayers/Premade_h-floor.png",
		## Per-phase wave composition (index 0 = phase 1). Weights must sum to 1.0.
		"wave_composition": [
			## Phase 1 — tiny goblins, bats, and skirmishers swarm in
			{"cave_fodder": 0.55, "cave_skirmisher": 0.25, "cave_bat": 0.20},
			## Phase 2 — raiders and bats join, regular goblins supplement
			{"cave_fodder": 0.30, "cave_skirmisher": 0.20, "cave_swarmer": 0.20,
				"cave_bat": 0.15, "cave_raider": 0.15},
			## Phase 3 — trolls lumber in alongside the full goblin tribe
			{"cave_fodder": 0.20, "cave_skirmisher": 0.15, "cave_swarmer": 0.20,
				"cave_raider": 0.20, "cave_brute": 0.15, "cave_bat": 0.10},
			## Phase 4 — specialist pressure (stalker/guardian use base scenes)
			{"cave_fodder": 0.10, "cave_swarmer": 0.20, "cave_raider": 0.15,
				"cave_brute": 0.10, "stalker": 0.25, "guardian": 0.20},
			## Phase 5 — warped variants; anchor uses base scene
			{"cave_swarmer": 0.12, "anchor": 0.48, "warped_fodder": 0.10,
				"warped_swarmer": 0.10, "warped_brute": 0.10, "warped_caster": 0.10},
		],
		## Maps level-specific enemy IDs to their .tscn paths.
		## IDs not listed here fall back to EnemySpawnManager's base scene lookup.
		"scene_map": {
			"cave_fodder":     "res://scenes/enemies/cave_fodder.tscn",
			"cave_swarmer":    "res://scenes/enemies/swarmer.tscn",
			"cave_brute":      "res://scenes/enemies/cave_brute.tscn",
			"cave_bat":        "res://scenes/enemies/cave_bat.tscn",
			"cave_raider":     "res://scenes/enemies/cave_raider.tscn",
			"cave_skirmisher": "res://scenes/enemies/cave_skirmisher.tscn",
		},
	},

	## ── Levels 2–5: stubs — add scene_map + wave_composition as each is built ──

	2: {
		"name": "The Catacombs",
		"floor_path": "",
		"wave_composition": [],
		"scene_map": {},
	},
	3: {
		"name": "The Nightmare Realm",
		"floor_path": "",
		"wave_composition": [],
		"scene_map": {},
	},
	4: {
		"name": "The Threshold",
		"floor_path": "",
		"wave_composition": [],
		"scene_map": {},
	},
	5: {
		"name": "The Inferno",
		"floor_path": "res://assets/minifantasy/Minifantasy_Hellscape_v1.0/Minifantasy_Hellscape_Assets/_Premade Scene/Separate Layers/Premade_l-ground.png",
		"wave_composition": [],
		"scene_map": {},
	},
}


static func get_level(level_id: int) -> Dictionary:
	return LEVELS.get(level_id, {})


static func get_wave_composition(level_id: int) -> Array:
	return get_level(level_id).get("wave_composition", [])


static func get_floor_path(level_id: int) -> String:
	return get_level(level_id).get("floor_path", "")


static func get_scene_map(level_id: int) -> Dictionary:
	return get_level(level_id).get("scene_map", {})


static func get_level_name(level_id: int) -> String:
	return get_level(level_id).get("name", "Unknown")


## Returns true if the level has a defined wave_composition (not just stubs).
static func is_configured(level_id: int) -> bool:
	return not get_wave_composition(level_id).is_empty()
