extends Node

## GameManager — Game state machine, phase transitions, run lifecycle

## Debug mode — set true during development, false before shipping.
## Enables F1 panel, F2/F3/F4 hotkeys, and the debug_* helper methods.
var debug_mode: bool = true

signal run_started
signal phase_started(phase_number: int)
signal phase_timer_updated(time_remaining: float)
signal extraction_window_opened
signal extraction_window_closed
signal player_died
signal extraction_successful
signal game_paused
signal game_unpaused
signal loot_changed(new_value: float)
signal instability_changed(new_value: float)
signal keystone_picked_up
signal guardian_state_changed(hp: float, max_hp: float, show_bar: bool)
signal boss_state_changed(id: String, hp: float, max_hp: float, show_bar: bool, display_name: String, color: Color)
signal final_boss_spawned(display_name: String)
signal final_boss_defeated

enum GameState {
	MENU,
	RUN_ACTIVE,
	LEVEL_UP,
	EXTRACTING,
	GAME_OVER,
	EXTRACTION_SUCCESS
}

var current_state: GameState = GameState.MENU
var current_level: int = 1  ## Which circle (1–5). Set from hub before start_run().
var phase_number: int = 1
var phase_timer: float = 0.0
var phase_duration: float = PHASE_DURATIONS[0]
var extraction_window_timer: float = 0.0
var extraction_window_duration: float = 18.0 ## Portal stays open 18 seconds
var extraction_window_active: bool = false
var run_time: float = 0.0
var kills: int = 0
var is_paused: bool = false

## Phase configuration
const PHASE_DURATIONS: Array = [180.0, 210.0, 240.0, 210.0, 240.0]
const PHASE_NAMES: Array = ["The Threshold", "The Descent", "The Deep", "The Abyss", "The Core"]
const MAX_PHASES: int = 5

## Difficulty scaling — time-based for prototype
const DIFFICULTY_SCALE_PERIOD: float = 30.0
const DIFFICULTY_SCALE_RATE: float = 0.15
var difficulty_multiplier: float = 1.0

## Loot and instability (decoupled — instability tracks per-item weights, not raw loot value)
var loot_carried: float = 0.0
var instability: float = 0.0
var peak_instability: float = 0.0  ## High-water mark for results screen
var last_run_loot: float = 0.0  ## Preserved after extraction clears loot_carried

## Weapons picked up during this run. Cleared on new run; unlocked in ProgressionManager
## on successful extraction. Lost on death (same risk as other loot).
var collected_weapons: Array = []

## Mods found during this run and bagged (no open weapon slot).
## Unlocked in ProgressionManager on successful extraction. Lost on death.
var collected_mods: Array = []

## Mods equipped to weapons mid-run. { weapon_id: { slot_index: mod_id } }
## Committed on extraction, rolled back on death.
var run_equipped_mods: Dictionary = {}

## Loot manifest — itemized log of everything collected this run for results screen.
## Each entry: { "type": "resource"/"weapon"/"mod", "name": String, "value": float, "rarity": String }
var run_loot_manifest: Array = []

## Insurance — per-run only, cleared at run start. Requires insurance_license upgrade.
var insured_item: String = ""

signal insured_item_changed(item_id: String)

## Keystone state — reset each run. One keystone held at a time.
var player_has_keystone: bool = false
var guardian_killed_this_phase: bool = false  ## Tracks first guardian kill per phase

## Final boss gate — when true, Phase 5 extraction channel is locked.
## Flipped true when the boss spawns, false when it dies.
var final_boss_alive: bool = false

## Which extraction type completed — used for phase bonus calculations.
## Values: "timed", "guarded", "locked", "sacrifice"
var active_extraction_type: String = "timed"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	## Listen to extraction completion via signal (not direct call)
	ExtractionManager.extraction_complete.connect(on_extraction_complete)
	## Track kills via combat signal instead of direct register_kill() calls
	EventBus.on_kill.connect(_on_entity_killed_eb)

func _process(delta: float) -> void:
	if current_state != GameState.RUN_ACTIVE or is_paused:
		return

	run_time += delta
	phase_timer += delta
	phase_timer_updated.emit(phase_duration - phase_timer)

	## Update difficulty over time
	difficulty_multiplier = 1.0 + (run_time / DIFFICULTY_SCALE_PERIOD) * DIFFICULTY_SCALE_RATE
	
	## Check if phase timer reached duration — open extraction window
	if phase_timer >= phase_duration and not extraction_window_active:
		_open_extraction_window()
	
	## Count down extraction window
	if extraction_window_active:
		extraction_window_timer -= delta
		if extraction_window_timer <= 0.0:
			_close_extraction_window()

## Call before start_run() to set which circle the player is entering.
func set_level(level_id: int) -> void:
	current_level = clampi(level_id, 1, 5)

func start_run() -> void:
	current_state = GameState.RUN_ACTIVE
	phase_number = 1
	phase_timer = 0.0
	phase_duration = PHASE_DURATIONS[0]
	run_time = 0.0
	kills = 0
	difficulty_multiplier = 1.0
	extraction_window_active = false
	is_paused = false
	loot_carried = 0.0
	instability = 0.0
	peak_instability = 0.0
	collected_weapons.clear()
	collected_mods.clear()
	run_equipped_mods.clear()
	run_loot_manifest.clear()
	insured_item = ""
	player_has_keystone = false
	guardian_killed_this_phase = false
	final_boss_alive = false
	active_extraction_type = "timed"

	## Cursed passive: start every run in the Unsettled instability tier
	var char_id: String = ProgressionManager.selected_character
	if CharacterData.ALL.has(char_id):
		if CharacterData.ALL[char_id].get("passive_id", "none") == "cursed_passive":
			instability = 31.0
			peak_instability = 31.0

	run_started.emit()
	phase_started.emit(phase_number)

	## Emit initial loot/instability so HUD reflects any starting values
	if instability > 0.0:
		loot_changed.emit(loot_carried)
		instability_changed.emit(instability)

func _on_entity_killed_eb(_killer: Node, victim: Node) -> void:
	if victim.is_in_group("enemies"):
		kills += 1

func set_paused(paused: bool) -> void:
	if paused == is_paused:
		return
	is_paused = paused
	get_tree().paused = paused
	if paused:
		game_paused.emit()
	else:
		game_unpaused.emit()

func enter_level_up() -> void:
	current_state = GameState.LEVEL_UP
	set_paused(true)

func exit_level_up() -> void:
	current_state = GameState.RUN_ACTIVE
	set_paused(false)

func set_insured_item(item_id: String) -> void:
	insured_item = item_id
	insured_item_changed.emit(item_id)

func on_player_died() -> void:
	if phase_number > ProgressionManager.run_stats.get("deepest_phase", 0):
		ProgressionManager.run_stats["deepest_phase"] = phase_number
	current_state = GameState.GAME_OVER

	var _insured := insured_item
	var has_insurance: bool = not _insured.is_empty() \
			and ProgressionManager.has_upgrade("insurance_license")

	## Rollback mid-run equipped mods — death loses everything except the insured item
	for weapon_id in run_equipped_mods:
		for slot in run_equipped_mods[weapon_id]:
			var mid_mod: String = run_equipped_mods[weapon_id][slot]
			if has_insurance and mid_mod == _insured:
				## Commit the insured slot so it survives death
				if not ProgressionManager.weapon_mods.has(weapon_id):
					ProgressionManager.weapon_mods[weapon_id] = []
				while ProgressionManager.weapon_mods[weapon_id].size() <= slot:
					ProgressionManager.weapon_mods[weapon_id].append("")
				ProgressionManager.weapon_mods[weapon_id][slot] = mid_mod
			else:
				if ProgressionManager.weapon_mods.has(weapon_id):
					if slot < ProgressionManager.weapon_mods[weapon_id].size():
						ProgressionManager.weapon_mods[weapon_id][slot] = ""

	## Preserve insured collected weapon or mod
	if has_insurance:
		if _insured in collected_weapons:
			ProgressionManager.add_weapon(_insured)
		elif _insured in collected_mods:
			ProgressionManager.add_mod(_insured)

	run_equipped_mods.clear()
	ProgressionManager.save_data()
	player_died.emit()

func on_extraction_complete() -> void:
	if phase_number > ProgressionManager.run_stats.get("deepest_phase", 0):
		ProgressionManager.run_stats["deepest_phase"] = phase_number
	current_state = GameState.EXTRACTION_SUCCESS
	set_paused(true)
	## Preserve loot value for results screen before clearing
	last_run_loot = loot_carried
	## Apply locked extraction loot bonus based on phase depth
	if active_extraction_type == "locked":
		var phase_bonuses: Array = [0.0, 0.0, 0.0, 0.25, 0.50, 1.00]
		var bonus: float = phase_bonuses[clampi(phase_number, 0, 5)]
		last_run_loot *= (1.0 + bonus)
	## Note: run_loot_manifest is NOT cleared here — results screen reads it
	loot_carried = 0.0
	instability = 0.0
	loot_changed.emit(loot_carried)
	instability_changed.emit(instability)
	## Unlock all weapons and mods collected this run
	for weapon_id in collected_weapons:
		ProgressionManager.add_weapon(weapon_id)
	for mod_id in collected_mods:
		ProgressionManager.add_mod(mod_id)
	## Commit mid-run equipped mods to permanent save
	for weapon_id in run_equipped_mods:
		for slot in run_equipped_mods[weapon_id]:
			var mid_mod: String = run_equipped_mods[weapon_id][slot]
			if not ProgressionManager.weapon_mods.has(weapon_id):
				ProgressionManager.weapon_mods[weapon_id] = []
			while ProgressionManager.weapon_mods[weapon_id].size() <= slot:
				ProgressionManager.weapon_mods[weapon_id].append("")
			ProgressionManager.weapon_mods[weapon_id][slot] = mid_mod
	run_equipped_mods.clear()
	ProgressionManager.save_data()
	extraction_successful.emit()

func pickup_keystone() -> void:
	player_has_keystone = true
	keystone_picked_up.emit()

func equip_mod_mid_run(weapon_id: String, slot: int, mod_id: String) -> void:
	if not run_equipped_mods.has(weapon_id):
		run_equipped_mods[weapon_id] = {}
	run_equipped_mods[weapon_id][slot] = mod_id

func add_loot(value: float) -> void:
	loot_carried += value
	loot_changed.emit(loot_carried)

func add_instability(amount: float) -> void:
	instability += amount
	peak_instability = maxf(peak_instability, instability)
	instability_changed.emit(instability)

## Spend loot for an in-run purchase (e.g. weapon swap). Returns false if insufficient.
func spend_loot(amount: float) -> bool:
	if loot_carried < amount:
		return false
	loot_carried = maxf(loot_carried - amount, 0.0)
	loot_changed.emit(loot_carried)
	return true

## Adjusts instability by delta (can be negative — e.g. Instability Siphon on kill).
## Clamps to zero minimum so the meter never goes below Stable.
func modify_instability(delta: int) -> void:
	instability = maxf(instability + float(delta), 0.0)
	instability_changed.emit(instability)

## Called when a bagged mod pickup is collected during a run.
## Mod is at risk until extraction — lost on death, unlocked on success.
func add_collected_mod(mod_id: String, rarity: String = "common") -> void:
	collected_mods.append(mod_id)
	var inst_cost: float = float(LootTables.RARITY_INSTABILITY.get(rarity, 5))
	add_instability(inst_cost)
	var mod_name: String = ModData.ALL[mod_id].get("name", mod_id) if ModData.ALL.has(mod_id) else mod_id
	run_loot_manifest.append({ "type": "mod", "name": mod_name, "value": inst_cost, "rarity": rarity })

## Called when the player picks up a weapon drop during a run.
## Weapon is at risk until extraction — lost on death, unlocked on success.
func add_collected_weapon(weapon_id: String, rarity: String = "common") -> void:
	if weapon_id not in collected_weapons:
		collected_weapons.append(weapon_id)
	var inst_cost: float = float(LootTables.RARITY_INSTABILITY.get(rarity, 5))
	add_instability(inst_cost)
	var display_name: String = WeaponData.ALL[weapon_id].get("display_name", weapon_id) if WeaponData.ALL.has(weapon_id) else weapon_id
	run_loot_manifest.append({ "type": "weapon", "name": display_name, "value": inst_cost, "rarity": rarity })

## Returns the current instability tier dictionary from LootTables.
func get_instability_tier() -> Dictionary:
	return LootTables.get_instability_tier(instability)

## Returns enemy HP/damage multiplier based on instability tier.
func get_instability_multiplier() -> float:
	return 1.0 + get_instability_tier().stat_bonus

## Returns bonus elite spawn rate from instability.
func get_instability_elite_bonus() -> float:
	return get_instability_tier().elite_bonus

func _open_extraction_window() -> void:
	extraction_window_active = true
	extraction_window_timer = extraction_window_duration
	extraction_window_opened.emit()

func _close_extraction_window() -> void:
	extraction_window_active = false
	extraction_window_closed.emit()
	if phase_number < MAX_PHASES:
		_advance_phase()
	## Phase 5 or beyond: no more timed extraction windows. Player must find another way out.

func _advance_phase() -> void:
	phase_number += 1
	phase_timer = 0.0
	phase_duration = PHASE_DURATIONS[clampi(phase_number - 1, 0, PHASE_DURATIONS.size() - 1)]
	guardian_killed_this_phase = false
	player_has_keystone = false
	if phase_number < MAX_PHASES:
		final_boss_alive = false
	phase_started.emit(phase_number)

func is_extraction_allowed() -> bool:
	## Gate extraction attempts on the final boss. Lower phases are unaffected.
	if phase_number >= MAX_PHASES and final_boss_alive:
		return false
	return true

## Debug helpers — only called from DebugPanel when debug_mode is true.
func debug_open_extraction() -> void:
	if extraction_window_active or current_state != GameState.RUN_ACTIVE:
		return
	phase_timer = phase_duration  ## Snap phase timer so window stays open
	_open_extraction_window()

## Sacrifice a specific weapon from collected_weapons. Returns true if found and removed.
func sacrifice_weapon(weapon_id: String) -> bool:
	var idx: int = collected_weapons.find(weapon_id)
	if idx < 0:
		return false
	collected_weapons.remove_at(idx)
	## Look up instability cost from manifest, fall back to uncommon cost
	var inst_refund: float = _find_manifest_instability("weapon", weapon_id)
	instability = maxf(instability - inst_refund, 0.0)
	instability_changed.emit(instability)
	return true

## Sacrifice a specific mod from collected_mods. Returns true if found and removed.
func sacrifice_mod(mod_id: String) -> bool:
	var idx: int = collected_mods.find(mod_id)
	if idx < 0:
		return false
	collected_mods.remove_at(idx)
	var inst_refund: float = _find_manifest_instability("mod", mod_id)
	instability = maxf(instability - inst_refund, 0.0)
	instability_changed.emit(instability)
	return true

## Sacrifice all generic loot (zeroes loot and instability).
func sacrifice_all_loot() -> void:
	loot_carried = 0.0
	instability = 0.0
	loot_changed.emit(loot_carried)
	instability_changed.emit(instability)

## Find the instability cost of a manifest entry by type and name for refund on sacrifice.
func _find_manifest_instability(type: String, item_id: String) -> float:
	for i in range(run_loot_manifest.size() - 1, -1, -1):
		var entry: Dictionary = run_loot_manifest[i]
		if entry.type == type:
			## Match by name (display name for weapons, mod name for mods)
			var match_name: String = ""
			if type == "weapon":
				match_name = WeaponData.ALL[item_id].get("display_name", item_id) if WeaponData.ALL.has(item_id) else item_id
			elif type == "mod":
				match_name = ModData.ALL[item_id].get("name", item_id) if ModData.ALL.has(item_id) else item_id
			if entry.name == match_name:
				var cost: float = entry.value
				run_loot_manifest.remove_at(i)
				return cost
	return float(LootTables.RARITY_INSTABILITY.get("uncommon", 8))
