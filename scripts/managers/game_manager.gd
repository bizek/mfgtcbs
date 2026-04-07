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

enum GameState {
	MENU,
	RUN_ACTIVE,
	LEVEL_UP,
	EXTRACTING,
	GAME_OVER,
	EXTRACTION_SUCCESS
}

var current_state: GameState = GameState.MENU
var phase_number: int = 1
var phase_timer: float = 0.0
var phase_duration: float = 180.0 ## 3 minutes for prototype single phase
var extraction_window_timer: float = 0.0
var extraction_window_duration: float = 18.0 ## Portal stays open 18 seconds
var extraction_window_active: bool = false
var run_time: float = 0.0
var kills: int = 0
var is_paused: bool = false

## Difficulty scaling — time-based for prototype
const DIFFICULTY_SCALE_PERIOD: float = 30.0
const DIFFICULTY_SCALE_RATE: float = 0.15
var difficulty_multiplier: float = 1.0

## Loot and instability
var loot_carried: float = 0.0
var instability: float = 0.0
var last_run_loot: float = 0.0  ## Preserved after extraction clears loot_carried

## Weapons picked up during this run. Cleared on new run; unlocked in ProgressionManager
## on successful extraction. Lost on death (same risk as other loot).
var collected_weapons: Array = []

## Mods found during this run and bagged (no open weapon slot).
## Unlocked in ProgressionManager on successful extraction. Lost on death.
var collected_mods: Array = []

## Keystone state — reset each run. One keystone held at a time.
var player_has_keystone: bool = false
var guardian_killed_this_phase: bool = false  ## Tracks first guardian kill per phase

## Which extraction type completed — used for phase bonus calculations.
## Values: "timed", "guarded", "locked", "sacrifice"
var active_extraction_type: String = "timed"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	## Listen to extraction completion via signal (not direct call)
	ExtractionManager.extraction_complete.connect(on_extraction_complete)
	## Track kills via combat signal instead of direct register_kill() calls
	CombatManager.entity_killed.connect(_on_entity_killed)

func _process(delta: float) -> void:
	if current_state != GameState.RUN_ACTIVE:
		return
	
	run_time += delta
	phase_timer += delta
	
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

func start_run() -> void:
	current_state = GameState.RUN_ACTIVE
	phase_number = 1
	phase_timer = 0.0
	run_time = 0.0
	kills = 0
	difficulty_multiplier = 1.0
	extraction_window_active = false
	is_paused = false
	loot_carried = 0.0
	instability = 0.0
	collected_weapons.clear()
	collected_mods.clear()
	player_has_keystone = false
	guardian_killed_this_phase = false
	active_extraction_type = "timed"

	## Cursed passive: start every run in the Unsettled instability tier
	var char_id: String = ProgressionManager.selected_character
	if CharacterData.ALL.has(char_id):
		if CharacterData.ALL[char_id].get("passive_id", "none") == "cursed_passive":
			loot_carried = 31.0
			instability  = 31.0

	run_started.emit()
	phase_started.emit(phase_number)

	## Emit initial loot/instability so HUD reflects any starting values
	if instability > 0.0:
		loot_changed.emit(loot_carried)
		instability_changed.emit(instability)

func _on_entity_killed(_killer: Node, victim: Node, _pos: Vector2) -> void:
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

func on_player_died() -> void:
	current_state = GameState.GAME_OVER
	player_died.emit()

func on_extraction_complete() -> void:
	current_state = GameState.EXTRACTION_SUCCESS
	set_paused(true)
	## Preserve loot value for results screen before clearing
	last_run_loot = loot_carried
	## Apply locked extraction loot bonus based on phase depth
	if active_extraction_type == "locked":
		var phase_bonuses: Array = [0.0, 0.0, 0.0, 0.25, 0.50, 1.00]
		var bonus: float = phase_bonuses[clampi(phase_number, 0, 5)]
		last_run_loot *= (1.0 + bonus)
	loot_carried = 0.0
	instability = 0.0
	loot_changed.emit(loot_carried)
	instability_changed.emit(instability)
	## Unlock all weapons and mods collected this run
	for weapon_id in collected_weapons:
		ProgressionManager.add_weapon(weapon_id)
	for mod_id in collected_mods:
		ProgressionManager.add_mod(mod_id)
	extraction_successful.emit()

func pickup_keystone() -> void:
	player_has_keystone = true
	keystone_picked_up.emit()

func add_loot(value: float) -> void:
	loot_carried += value
	instability = loot_carried  ## Simplified: instability tracks total loot value carried
	loot_changed.emit(loot_carried)
	instability_changed.emit(instability)

## Adjusts instability by delta (can be negative — e.g. Instability Siphon on kill).
## Clamps to zero minimum so the meter never goes below Stable.
func modify_instability(delta: int) -> void:
	instability = maxf(instability + float(delta), 0.0)
	loot_changed.emit(loot_carried)
	instability_changed.emit(instability)

## Called when a bagged mod pickup is collected during a run.
## Mod is at risk until extraction — lost on death, unlocked on success.
func add_collected_mod(mod_id: String) -> void:
	collected_mods.append(mod_id)
	add_loot(15.0)  ## Mods contribute 15 instability weight

## Called when the player picks up a weapon drop during a run.
## Weapon is at risk until extraction — lost on death, unlocked on success.
func add_collected_weapon(weapon_id: String) -> void:
	if weapon_id not in collected_weapons:
		collected_weapons.append(weapon_id)
	## Weapon pickups contribute 30 instability (meaningful risk weight)
	add_loot(30.0)

## Returns enemy HP/damage multiplier based on instability tier.
## Tiers: Stable(0-30)=×1.0, Unsettled(31-70)=×1.15, Volatile(71-120)=×1.3, Critical(121+)=×1.5
func get_instability_multiplier() -> float:
	if instability <= 30.0:
		return 1.0
	elif instability <= 70.0:
		return 1.15
	elif instability <= 120.0:
		return 1.3
	else:
		return 1.5

func _open_extraction_window() -> void:
	extraction_window_active = true
	extraction_window_timer = extraction_window_duration
	extraction_window_opened.emit()

func _close_extraction_window() -> void:
	extraction_window_active = false
	extraction_window_closed.emit()
	## After window closes, keep spawning — no more extraction until player dies

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
	loot_carried = maxf(loot_carried - 30.0, 0.0)
	instability = maxf(instability - 30.0, 0.0)
	loot_changed.emit(loot_carried)
	instability_changed.emit(instability)
	return true

## Sacrifice a specific mod from collected_mods. Returns true if found and removed.
func sacrifice_mod(mod_id: String) -> bool:
	var idx: int = collected_mods.find(mod_id)
	if idx < 0:
		return false
	collected_mods.remove_at(idx)
	loot_carried = maxf(loot_carried - 15.0, 0.0)
	instability = maxf(instability - 15.0, 0.0)
	loot_changed.emit(loot_carried)
	instability_changed.emit(instability)
	return true

## Sacrifice all generic loot (zeroes instability/loot value).
func sacrifice_all_loot() -> void:
	loot_carried = 0.0
	instability = 0.0
	loot_changed.emit(loot_carried)
	instability_changed.emit(instability)
