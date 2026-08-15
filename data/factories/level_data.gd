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
		## Last biome shipped in v1 — clearing its Phase 5 boss gate and extracting triggers
		## the win flow. Move this flag to whichever level ships last as new biomes land.
		"is_final_biome": true,
		"music_id": "mus_caves",
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
		## Cave bosses — real Minifantasy exclusives (Ancient_Troll / Goblin_King
		## packs) instead of the tinted Colossus/Heart stand-ins.
		"miniboss_id": "ancient_troll",
		"final_boss_id": "goblin_king",
		## ── Descent blocks ───────────────────────────────────────────────────
		## Which .ldtkl blocks this biome's descent is assembled from. Lived as
		## hardcoded string literals inside main_arena.gd's _setup_ldtk_descent()
		## until 2026-08-09, which is why 21 finished blocks for two OTHER biomes
		## (11 Block_Crypt_*, 10 Block_NMRealm_*) sat on disk unreachable — they
		## are registered in the same LDtk project and there was simply no code
		## path that could name them. A biome's blocks belong beside its waves.
		"blocks": {
			"count": 10,                                  ## Entry + 8 inner + Portal
			"entry": "Block_Caves_00_Entry",              ## fixed bookends, never shuffled
			"portal": "Block_Caves_09_Portal",
			"merchant": "Block_Caves_05_Merchant",        ## placed at merchant_depth
			"merchant_depth": 0.5,                        ## fraction of the way down
			## Inner shuffled pool. Add variants here as they are authored —
			## `blocks/caves/*.block` compiles into these (docs/block_sketch_workflow.md).
			"pool": [
				"Block_Caves_01_Open",
				"Block_Caves_02_Pillars",
				"Block_Caves_03_Choke",
				"Block_Caves_04_Split",
				"Block_Caves_10_ChokeA",
				"Block_Caves_11_ChokeB",
				"Block_Caves_12_PillarsB",
				"Block_Caves_13_SplitB",
				"Block_Caves_14_OpenB",
				"Block_Caves_15_Gauntlet",
			],
		},
		## Maps level-specific enemy IDs to their .tscn paths.
		## IDs not listed here fall back to EnemySpawnManager's base scene lookup.
		"scene_map": {
			"cave_fodder":     "res://scenes/enemies/cave_fodder.tscn",
			"cave_swarmer":    "res://scenes/enemies/swarmer.tscn",
			"cave_brute":      "res://scenes/enemies/cave_brute.tscn",
			"cave_bat":        "res://scenes/enemies/cave_bat.tscn",
			"cave_raider":     "res://scenes/enemies/cave_raider.tscn",
			"cave_skirmisher": "res://scenes/enemies/cave_skirmisher.tscn",
			"ancient_troll":   "res://scenes/enemies/ancient_troll.tscn",
			"goblin_king":     "res://scenes/enemies/goblin_king.tscn",
		},
	},

	## ── Levels 2–5: stubs — add scene_map + wave_composition as each is built ──

	2: {
		"name": "The Catacombs",
		"music_id": "mus_catacombs",   ## catacombs.ogg does not exist yet — AudioManager no-ops
		"floor_path": "res://assets/minifantasy/Minifantasy_Crypt_Of_The_Forgotten_v1.0/Minifantasy_Crypt_Of_The_Forgotten_Assets/Premade_Scene/Separate_Layers/g_floor.png",
		## Per-phase wave composition (index 0 = phase 1). Weights must sum to 1.0.
		## Undead roster from Minifantasy_Undead_Creatures — see CryptEnemyData.
		"wave_composition": [
			## Phase 1 — the dormant dead wake: loose bones and skulls
			{"crypt_fodder": 0.55, "crypt_swarmer": 0.25, "crypt_skirmisher": 0.20},
			## Phase 2 — armed skeletons and the first ranged pressure
			{"crypt_fodder": 0.28, "crypt_swarmer": 0.17, "crypt_skirmisher": 0.25,
				"crypt_archer": 0.18, "crypt_ghost": 0.12},
			## Phase 3 — zombies join; casters start punishing static play
			{"crypt_skirmisher": 0.20, "crypt_raider": 0.22, "crypt_archer": 0.15,
				"crypt_caster": 0.15, "crypt_ghost": 0.13, "crypt_brute": 0.15},
			## Phase 4 — heavies and cavalry; the biome's mid-fight identity
			{"crypt_raider": 0.18, "crypt_brute": 0.18, "crypt_cavalry": 0.18,
				"crypt_zombie_archer": 0.16, "crypt_zombie_caster": 0.15, "crypt_heavy": 0.15},
			## Phase 5 — everything heavy at once, ahead of the boss gate
			{"crypt_heavy": 0.24, "crypt_brute": 0.20, "crypt_cavalry": 0.18,
				"crypt_zombie_caster": 0.16, "crypt_zombie_archer": 0.12, "crypt_ghost": 0.10},
		],
		"miniboss_id": "skeleton_minotaur",
		"final_boss_id": "zombie_giant",
		## ── Descent blocks ───────────────────────────────────────────────────
		## 11 of these were authored in c537cd5 and sat unreachable until the block pool
		## moved into LevelData (3.1a). The Merchant and Portal bookends did not exist —
		## the Crypt set had no equivalent of Block_Caves_05/09 — and were generated for
		## this biome via the block compiler (blocks/crypt/*.block).
		"blocks": {
			"count": 10,                                  ## Entry + 8 inner + Portal
			"entry": "Block_Crypt_00_Entry",              ## fixed bookends, never shuffled
			"portal": "Block_Crypt_12_Portal",
			"merchant": "Block_Crypt_11_Merchant",
			"merchant_depth": 0.5,
			"pool": [
				"Block_Crypt_01_Hall",
				"Block_Crypt_02_Chambers",
				"Block_Crypt_03_Corridors",
				"Block_Crypt_04_Crossing",
				"Block_Crypt_05_Tombs",
				"Block_Crypt_06_Gallery",
				"Block_Crypt_07_Weave",
				"Block_Crypt_08_Vault",
				"Block_Crypt_09_Columns",
				"Block_Crypt_10_Antechambers",
			],
		},
		"scene_map": {
			"crypt_fodder":        "res://scenes/enemies/crypt_fodder.tscn",
			"crypt_swarmer":       "res://scenes/enemies/crypt_swarmer.tscn",
			"crypt_skirmisher":    "res://scenes/enemies/crypt_skirmisher.tscn",
			"crypt_raider":        "res://scenes/enemies/crypt_raider.tscn",
			"crypt_ghost":         "res://scenes/enemies/crypt_ghost.tscn",
			"crypt_brute":         "res://scenes/enemies/crypt_brute.tscn",
			"crypt_heavy":         "res://scenes/enemies/crypt_heavy.tscn",
			"crypt_cavalry":       "res://scenes/enemies/crypt_cavalry.tscn",
			"crypt_archer":        "res://scenes/enemies/crypt_archer.tscn",
			"crypt_zombie_archer": "res://scenes/enemies/crypt_zombie_archer.tscn",
			"crypt_caster":        "res://scenes/enemies/crypt_caster.tscn",
			"crypt_zombie_caster": "res://scenes/enemies/crypt_zombie_caster.tscn",
			"skeleton_minotaur":   "res://scenes/enemies/skeleton_minotaur.tscn",
			"zombie_giant":        "res://scenes/enemies/zombie_giant.tscn",
		},
	},
	3: {
		"name": "The Nightmare Realm",
		"music_id": "mus_nightmare_realm",   ## nightmare_realm.ogg does not exist yet — AudioManager no-ops
		"floor_path": "res://assets/minifantasy/Minifantasy_Nightmare_Realm_v1.0/Minifantasy_Nightmare_Realm_Assets/Premade/Separate_Layers/Premade_h-platforms_lvl_0.png",
		## Per-phase wave composition (index 0 = phase 1). Weights must sum to 1.0.
		## Monster bestiary from Minifantasy_Monster_Creatures — see NightmareEnemyData.
		## Unlike the Catacombs' ordered undead legion, this roster is deliberately motley:
		## the biome's identity is that nothing here belongs together.
		"wave_composition": [
			## Phase 1 — vermin and beasts: what scavenges a dead world
			{"nm_fodder": 0.50, "nm_swarmer": 0.28, "nm_skirmisher": 0.22},
			## Phase 2 — the humanoids arrive, and the first ranged pressure
			{"nm_fodder": 0.26, "nm_swarmer": 0.18, "nm_skirmisher": 0.24,
				"nm_stalker": 0.18, "nm_archer": 0.14},
			## Phase 3 — deep ones and psychics; casters start punishing static play
			{"nm_skirmisher": 0.16, "nm_stalker": 0.15, "nm_raider": 0.16, "nm_archer": 0.13,
				"nm_caster": 0.14, "nm_aerial": 0.16, "nm_lurker": 0.10},
			## Phase 4 — ambushers, royalty and spore turrets; the biome's mid-fight identity
			{"nm_raider": 0.14, "nm_ambusher": 0.14, "nm_lurker": 0.10, "nm_aerial": 0.14,
				"nm_royal": 0.14, "nm_spore": 0.12, "nm_brute": 0.14, "nm_caster": 0.08},
			## Phase 5 — everything heavy at once, ahead of the boss gate
			{"nm_heavy": 0.22, "nm_brute": 0.20, "nm_ambusher": 0.14, "nm_royal": 0.14,
				"nm_aerial": 0.12, "nm_spore": 0.10, "nm_raider": 0.08},
		],
		"miniboss_id": "centaur_king",
		"final_boss_id": "angel_of_death",
		## ── Descent blocks ───────────────────────────────────────────────────
		## 10 of these (00-09) were authored long before the biome was reachable. The
		## Merchant and Portal bookends did not exist — the NMRealm set had no equivalent
		## of Block_Caves_05/09 — and were generated for this biome via the block compiler
		## (blocks/nmrealm/*.block), the same gap the Crypt set had.
		"blocks": {
			"count": 10,                                  ## Entry + 8 inner + Portal
			"entry": "Block_NMRealm_00_Entry",            ## fixed bookends, never shuffled
			"portal": "Block_NMRealm_11_Portal",
			"merchant": "Block_NMRealm_10_Merchant",
			"merchant_depth": 0.5,
			"pool": [
				"Block_NMRealm_01_Isles",
				"Block_NMRealm_02_Scarred",
				"Block_NMRealm_03_Rift",
				"Block_NMRealm_04_Shards",
				"Block_NMRealm_05_Ruins",
				"Block_NMRealm_06_Shattered",
				"Block_NMRealm_07_Bastion",
				"Block_NMRealm_08_Straits",
				"Block_NMRealm_09_Fields",
			],
		},
		"scene_map": {
			"nm_fodder":      "res://scenes/enemies/nm_fodder.tscn",
			"nm_swarmer":     "res://scenes/enemies/nm_swarmer.tscn",
			"nm_skirmisher":  "res://scenes/enemies/nm_skirmisher.tscn",
			"nm_stalker":     "res://scenes/enemies/nm_stalker.tscn",
			"nm_raider":      "res://scenes/enemies/nm_raider.tscn",
			"nm_ambusher":    "res://scenes/enemies/nm_ambusher.tscn",
			"nm_lurker":      "res://scenes/enemies/nm_lurker.tscn",
			"nm_aerial":      "res://scenes/enemies/nm_aerial.tscn",
			"nm_archer":      "res://scenes/enemies/nm_archer.tscn",
			"nm_caster":      "res://scenes/enemies/nm_caster.tscn",
			"nm_royal":       "res://scenes/enemies/nm_royal.tscn",
			"nm_spore":       "res://scenes/enemies/nm_spore.tscn",
			"nm_brute":       "res://scenes/enemies/nm_brute.tscn",
			"nm_heavy":       "res://scenes/enemies/nm_heavy.tscn",
			"centaur_king":   "res://scenes/enemies/centaur_king.tscn",
			"angel_of_death": "res://scenes/enemies/angel_of_death.tscn",
		},
	},
	4: {
		"name": "The Threshold",
		"music_id": "mus_threshold",
		"floor_path": "",
		"wave_composition": [],
		"scene_map": {},
	},
	5: {
		"name": "The Inferno",
		"music_id": "mus_inferno",
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


## Music track ID (SoundTable.MUSIC key) for this level's biome.
static func get_music_id(level_id: int) -> String:
	return get_level(level_id).get("music_id", "mus_caves")


## Boss ids for this level. Unconfigured levels fall back to the generic bosses
## (the tinted Warped Colossus / Heart of the Deep, which reuse brute_scene).
static func get_miniboss_id(level_id: int) -> String:
	return get_level(level_id).get("miniboss_id", "warped_colossus")


static func get_final_boss_id(level_id: int) -> String:
	return get_level(level_id).get("final_boss_id", "heart_of_the_deep")


## Descent block config for a level: count, entry/portal/merchant bookends and the shuffled
## inner pool. Empty for a biome whose blocks are not authored yet — callers must check
## has_blocks() first, because building a descent from an empty pool produces a stack of
## bookends with nothing between them rather than an error.
static func get_blocks(level_id: int) -> Dictionary:
	return get_level(level_id).get("blocks", {})


## Returns true if this level can build a block descent at all.
static func has_blocks(level_id: int) -> bool:
	var b: Dictionary = get_blocks(level_id)
	return not b.is_empty() and not (b.get("pool", []) as Array).is_empty()


## Returns true if the level has a defined wave_composition (not just stubs).
static func is_configured(level_id: int) -> bool:
	return not get_wave_composition(level_id).is_empty()


## Returns true if clearing this level's Phase 5 boss gate and extracting is the win condition.
static func is_final_biome(level_id: int) -> bool:
	return get_level(level_id).get("is_final_biome", false)


## Level ids that can actually be launched — waves authored AND a block pool to descend.
##
## The launch pad's destination selector walks this, which means a biome becomes reachable the
## moment both halves of it exist, with no separate unlock list to keep in sync. Before this,
## GameManager.set_level() had no callers at all and current_level was permanently 1: The
## Catacombs would have shipped complete and unreachable, which is the same failure that left
## 21 authored blocks dead on disk.
static func playable_ids() -> Array[int]:
	var out: Array[int] = []
	for level_id: int in LEVELS:
		if is_configured(level_id) and has_blocks(level_id):
			out.append(level_id)
	out.sort()
	return out
