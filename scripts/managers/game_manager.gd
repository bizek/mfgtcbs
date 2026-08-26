extends Node

## GameManager — Game state machine, phase transitions, run lifecycle

## Debug mode — set true during development, false before shipping.
## Enables F1 panel, F2/F3/F4 hotkeys, and the debug_* helper methods.
var debug_mode: bool = true

## When true (requires debug_mode) and current_level == 1, MainArena loads
## Level_0 from the LDtk project instead of using ArenaGenerator.
var use_ldtk_level_1: bool = true

## When true (requires use_ldtk_level_1), uses block-based vertical descent
## instead of loading a single monolithic level.
var use_descent_mode: bool = true

## Training room (F11 / main-menu entry): MainArena runs on a flat arena with no wave
## spawning, no phase clock and no extraction — just the player, dummies and the training
## panel. Set before change_scene_to_file("res://scenes/main_arena.tscn").
var training_mode: bool = false

signal run_started
signal phase_started(phase_number: int)
signal phase_timer_updated(time_remaining: float)
signal extraction_window_opened
signal extraction_window_closed
signal player_died
## "the run ended without extracting" — death OR abandon. Anything that just needs to tear a run
## down (stop the music, interrupt an extraction channel, finalize the run report, close the
## first-run overlay, show the results screen) listens HERE, not to player_died, so abandoning
## doesn't leave those systems believing the run is still going. `player_died` remains for anything
## that genuinely means "the player was killed".
signal run_failed(abandoned: bool)
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

## Descent mode: spatial depth (0.0-1.0, from DepthTracker), pushed once/frame by
## MainArena. phase_number still advances on the wall-clock timer below (other
## code depends on phase_started firing — carrier/herald resets, miniboss arm),
## but combat/loot scaling should read get_effective_phase() instead of
## phase_number directly, so difficulty tracks the player's block position
## instead of how long the run has been running.
var descent_depth_progress: float = 0.0

func set_descent_depth(progress: float) -> void:
	descent_depth_progress = clampf(progress, 0.0, 1.0)

## Returns the phase tier (1-5) that combat/loot scaling should use. In descent
## mode this is derived from spatial depth; everywhere else it's the wall-clock
## phase_number.
func get_effective_phase() -> int:
	if not use_descent_mode:
		return phase_number
	return clampi(int(descent_depth_progress * float(MAX_PHASES)) + 1, 1, MAX_PHASES)

## Difficulty scaling — time-based for prototype
const DIFFICULTY_SCALE_PERIOD: float = 30.0
const DIFFICULTY_SCALE_RATE: float = 0.15
var difficulty_multiplier: float = 1.0

## Loot and instability (decoupled — instability tracks per-item weights, not raw loot value)
##
## PLAYER-FACING NAME: **HAUL**. This is what you are carrying and stand to LOSE — it is zeroed on
## death and banked on extraction. Its counterpart is ProgressionManager.resources, player-facing
## **VAULT**, which is banked and safe.
##
## The names were split on 2026-08-03. Before that the UI called this "LOOT" and the banked total
## "RESOURCES"/"RES", plus "gold" in one achievement — four names for two things, and the two that
## mattered read as synonyms. That distinction is the entire reason the extraction tension exists:
## the whole game is deciding when to stop converting HAUL into more HAUL and go bank it.
##
## The identifiers were deliberately NOT renamed: `resources` is a save key, so renaming it costs a
## migration and buys the player nothing. If you touch UI copy, use HAUL and VAULT. "loot" is still
## fine as a verb and as the word for stuff on the ground — you loot things, and what you carry out
## is your haul.
var loot_carried: float = 0.0
var instability: float = 0.0
var peak_instability: float = 0.0  ## High-water mark for results screen
var last_run_loot: float = 0.0  ## Preserved after extraction clears loot_carried
var last_run_was_win: bool = false  ## True if the just-completed extraction cleared the final biome

## Weapons picked up during this run. Cleared on new run; unlocked in ProgressionManager
## on successful extraction. Lost on death (same risk as other loot).
var collected_weapons: Array = []

## Mods found during this run and bagged (no open weapon slot).
## Unlocked in ProgressionManager on successful extraction. Lost on death.
var collected_mods: Array = []
var collected_trinkets: Array = []   ## universal trinkets bagged this run (task 34)

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

## Town portal — a bought escape you spend WHEN YOU CHOOSE, as opposed to the free gateway that
## arrives on the phase clock and is a bus you either catch or miss. That timing control is the
## whole product: it is worth loot precisely because it works at 90% depth, mid-miniboss, the
## moment a run goes wrong. It pays the same 1.0x as the free escape — you are buying safety, not
## a bonus (see EXTRACTION_PAYOUT).
##
## Unlike the keystone this deliberately SURVIVES _advance_phase(): a keystone is a per-phase key
## the run hands you, a town portal is a thing you paid for and keep until you spend it.
var player_has_town_portal: bool = false
signal town_portal_changed(has_portal: bool)

## Final boss gate — when true, Phase 5 extraction channel is locked.
## Flipped true when the boss spawns, false when it dies.
var final_boss_alive: bool = false

## Which extraction type completed — used for phase bonus calculations.
## Values: "timed", "guarded", "locked", "sacrifice"
var active_extraction_type: String = "timed"

## ── Extraction payout curve ───────────────────────────────────────────────────────────────────
## What leaving is worth, by how far you got before you left.
##
## DELIBERATELY CONVEX — each further rung pays disproportionately more, not equally more.
## Dying loses the whole haul, so every "push on" is a gamble against a guaranteed alternative,
## and the break-even survival odds are 1/multiplier. Ben's first sketch was a flat 1.0/1.2/1.4,
## which needs 71% / 83% / 86% survival to be worth taking — odds that RISE as the run gets
## harder, so every successive push is a worse bet than the last and the rational play is always
## to leave at the first window. That would let the escape hatch eat the descent it was added to
## rescue. This curve asks roughly the same confidence at every rung instead.
##
## THESE NUMBERS ARE PROVISIONAL. They are constants precisely so tuning them is a one-line edit
## once the density pass lands and real survival rates exist to set them against (Ben 2026-08-02:
## "before we remove mob numbers, lets give player's methods of dealing with it").
##
## A type absent from this table pays 1.0 — every flat-arena extraction is unaffected.
const EXTRACTION_PAYOUT: Dictionary = {
	"gateway": 1.0,          ## the free escape hatch, available at any window
	"miniboss": 1.7,         ## earned: the descent miniboss died at 50% depth
	"descent_portal": 3.0,   ## the whole descent — ten blocks and the boss at the bottom
}

## The multiplier actually applied to the run that just ended, for the results screen to show.
var last_run_payout_mult: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	## Listen to extraction completion via signal (not direct call)
	ExtractionManager.extraction_complete.connect(on_extraction_complete)
	## Track kills via combat signal instead of direct register_kill() calls
	EventBus.on_kill.connect(_on_entity_killed_eb)
	## Deferred: GameManager is the FIRST autoload, so Logger (declared last in project.godot)
	## does not exist yet during _ready. One frame later every autoload is up.
	_validate_content.call_deferred()


## Debug-only content sweep. Class mods and ability upgrades bind to phases by ANIMATION NAME,
## and a kit edit that renames a phase turns them into silent no-ops — no error, no symptom,
## just a level-up choice that does nothing (seven entries were dead this way on 2026-08-02).
## Builds every kit once at startup and reports anything that resolves to no phase.
## debug_mode-gated: this costs 12 kit builds and players never need it.
## NOTE ON `Logger`: it is reached through get_node("/root/Logger"), NOT by the bare autoload
## name. Godot 4.6 ships a NATIVE `Logger` class, and it wins name resolution — writing
## `Logger.log_info(...)` here compiles and then fails at runtime with
## 'Static function "log_info()" not found in base "GDScriptNativeClass"'. These three calls
## were the first code outside logger.gd ever to call the autoload, which is why the collision
## had not surfaced before. Anything else that wants the crash log must do the same.
func _validate_content() -> void:
	if not debug_mode:
		return
	var problems: Array[String] = ClassModFactory.validate_anim_targets()
	## Same failure shape one layer over: a level-up entry naming a status StatusFactory does not
	## build resolves to null and applies nothing, just as silently.
	problems.append_array(UpgradeManager.validate_status_ids())
	## Third shape of the same failure, and the one that had actually shipped: an ability upgrade
	## that resolves perfectly but is never REACHABLE, because get_upgrades_for_kit walks
	## ORDER_BY_KIT rather than ALL. On 2026-08-07 the Druid was running on one of its three
	## upgrades — the Tier 0.1 rewrite renamed two entries and left ORDER_BY_KIT pointing at the
	## old ids, which the anim validator cannot see because a missing id never becomes a target.
	problems.append_array(AbilityUpgradeData.validate_kit_order())
	## Fourth shape: the reachability check for the CLASS MOD layer, which had none. ORDER is the
	## only route into loot/armory/merchant, so an entry missing from it is unobtainable while
	## looking perfectly healthy to validate_anim_targets — its target resolves fine, the player
	## simply can never own it. `ranger_split_quiver` had shipped this way (found 2026-08-08).
	problems.append_array(ClassModData.validate_order())
	## Fifth shape, and the only one that is a NUMBERS drift rather than a dead reference: an
	## evolution consumes its prerequisites, so one that grants less than they did is a level-up
	## that makes the player weaker. Every id resolves, so the other four validators see nothing.
	## Five of nine recipes were in this state on 2026-08-22 — JUGGERNAUT was strictly worse than
	## the two Vitality picks it ate.
	problems.append_array(UpgradeManager.validate_evolution_math())
	var log_node: Node = get_node_or_null("/root/Logger")
	if problems.is_empty():
		print("[content] All class-mod / ability-upgrade anim targets and upgrade statuses resolve.")
		if log_node:
			log_node.log_info("Content validation: all anim targets and upgrade statuses resolve.")
		return
	## push_warning so it lands in the editor's error list too — a dead entry is invisible in
	## play, so the startup sweep is the only place it can announce itself.
	push_warning("[content] %d DEAD content entries (they apply nothing)"
		% problems.size())
	for p: String in problems:
		push_warning("[content]   " + p)
		if log_node:
			log_node.log_warn("Dead content entry: " + p)

func _process(delta: float) -> void:
	if current_state != GameState.RUN_ACTIVE or is_paused:
		return

	## Training room: no clock, no phases, no extraction pressure — the run never advances.
	if training_mode:
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
	collected_trinkets.clear()
	run_equipped_mods.clear()
	run_loot_manifest.clear()
	insured_item = ""
	player_has_keystone = false
	player_has_town_portal = false
	town_portal_changed.emit(false)
	guardian_killed_this_phase = false
	final_boss_alive = false
	active_extraction_type = "timed"
	last_run_payout_mult = 1.0
	last_run_was_win = false

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
	_settle_lost_run()
	player_died.emit()
	run_failed.emit(false)


## Walking out on a run mid-descent (pause menu → Abandon Run, Ben 2026-08-01). Mechanically it
## settles EXACTLY like dying — same 25% salvage, same rollback of everything picked up this run,
## same insurance rule — because the only honest difference between bleeding out and leaving is
## which one the player chose. What it does NOT do is record a death: it is its own stat
## (ProgressionManager.record_abandon), so the death count stays a count of deaths.
func abandon_run() -> void:
	_settle_lost_run()
	run_failed.emit(true)


## Shared teardown for a run that ends without extracting. Loot is settled by whichever end screen
## responds to the signal; this owns the state flip and the mid-run inventory rollback.
func _settle_lost_run() -> void:
	if phase_number > ProgressionManager.run_stats.get("deepest_phase", 0):
		ProgressionManager.run_stats["deepest_phase"] = phase_number
	current_state = GameState.GAME_OVER

	var _insured := insured_item
	var has_insurance: bool = not _insured.is_empty() \
			and ProgressionManager.has_upgrade("insurance_license")

	## Rollback mid-run equipped mods — death loses everything except the insured item.
	## Keyed by CHARACTER since 2026-08-08 (mod slots moved off weapons onto the character).
	for char_id in run_equipped_mods:
		for slot in run_equipped_mods[char_id]:
			var mid_mod: String = run_equipped_mods[char_id][slot]
			if has_insurance and mid_mod == _insured:
				## Commit the insured slot so it survives death
				if not ProgressionManager.character_mods.has(char_id):
					ProgressionManager.character_mods[char_id] = []
				while ProgressionManager.character_mods[char_id].size() <= slot:
					ProgressionManager.character_mods[char_id].append("")
				ProgressionManager.character_mods[char_id][slot] = mid_mod
			else:
				if ProgressionManager.character_mods.has(char_id):
					if slot < ProgressionManager.character_mods[char_id].size():
						ProgressionManager.character_mods[char_id][slot] = ""

	## Preserve insured collected weapon or mod
	if has_insurance:
		if _insured in collected_weapons:
			ProgressionManager.add_weapon(_insured)
		elif _insured in collected_mods:
			ProgressionManager.add_mod(_insured)
		elif _insured in collected_trinkets:
			ProgressionManager.add_trinket(_insured)

	run_equipped_mods.clear()
	ProgressionManager.save_data()

const EXTRACTION_FANFARE_DELAY: float = 0.45  ## room for MainArena's flash/zoom beat before pause+success screen

func on_extraction_complete() -> void:
	## Let the extraction fanfare (flash/zoom, wired off ExtractionManager.extraction_complete
	## directly in MainArena) play before the run pauses and the success screen appears.
	await get_tree().create_timer(EXTRACTION_FANFARE_DELAY, true, false, true).timeout
	if phase_number > ProgressionManager.run_stats.get("deepest_phase", 0):
		ProgressionManager.run_stats["deepest_phase"] = phase_number
	current_state = GameState.EXTRACTION_SUCCESS
	set_paused(true)
	## Win condition: cleared the final biome's Phase 5 boss gate and extracted.
	last_run_was_win = phase_number >= MAX_PHASES and LevelData.is_final_biome(current_level)
	if last_run_was_win:
		ProgressionManager.record_win(ProgressionManager.selected_character)
	## Preserve loot value for results screen before clearing
	last_run_loot = loot_carried
	## Apply locked extraction loot bonus based on phase depth
	if active_extraction_type == "locked":
		var phase_bonuses: Array = [0.0, 0.0, 0.0, 0.25, 0.50, 1.00]
		var bonus: float = phase_bonuses[clampi(phase_number, 0, 5)]
		last_run_loot *= (1.0 + bonus)
	## How far you got before leaving. Types absent from the table pay 1.0, so nothing outside
	## descent changes behaviour.
	last_run_payout_mult = EXTRACTION_PAYOUT.get(active_extraction_type, 1.0)
	last_run_loot *= last_run_payout_mult
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
	## Trinkets bank to the shared universal inventory. So do weapons — `unlocked_weapons` is one
	## flat list for the whole roster, NOT a per-character stash. What keeps another class's gear
	## out of your hands is the armory/level-up filter (WeaponData.equippable_for), added
	## 2026-08-08; before that this comment claimed a filter that did not exist and every
	## character could equip everything.
	for trinket_id in collected_trinkets:
		ProgressionManager.add_trinket(trinket_id)
	## Commit mid-run equipped mods to permanent save (keyed by character since 2026-08-08)
	for char_id in run_equipped_mods:
		for slot in run_equipped_mods[char_id]:
			var mid_mod: String = run_equipped_mods[char_id][slot]
			if not ProgressionManager.character_mods.has(char_id):
				ProgressionManager.character_mods[char_id] = []
			while ProgressionManager.character_mods[char_id].size() <= slot:
				ProgressionManager.character_mods[char_id].append("")
			ProgressionManager.character_mods[char_id][slot] = mid_mod
	run_equipped_mods.clear()
	ProgressionManager.save_data()
	extraction_successful.emit()

func pickup_keystone() -> void:
	player_has_keystone = true
	keystone_picked_up.emit()


func grant_town_portal() -> void:
	player_has_town_portal = true
	town_portal_changed.emit(true)


## Spend it. Returns false if there was nothing to spend, so the caller can leave the player's
## loot alone and say so rather than silently eating a purchase.
func consume_town_portal() -> bool:
	if not player_has_town_portal:
		return false
	player_has_town_portal = false
	town_portal_changed.emit(false)
	return true

## Track a mod equipped mid-run so it can be rolled back on death or committed on extraction.
## Keyed by CHARACTER since 2026-08-08 — mod slots live on the character, not the weapon.
func equip_mod_mid_run(char_id: String, slot: int, mod_id: String) -> void:
	if not run_equipped_mods.has(char_id):
		run_equipped_mods[char_id] = {}
	run_equipped_mods[char_id][slot] = mod_id

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
## The signed counterpart to add_instability — same value, but clamped at zero so a reduction
## cannot go negative. It MUST update the high-water mark too: it did not until 2026-08-03, so
## every void-touched death (enemy.gd raises instability by 2 through here) was invisible to
## peak_instability, and both results screens under-reported the peak the run actually hit.
func modify_instability(delta: int) -> void:
	instability = maxf(instability + float(delta), 0.0)
	peak_instability = maxf(peak_instability, instability)
	instability_changed.emit(instability)

## Called when a bagged mod pickup is collected during a run.
## Mod is at risk until extraction — lost on death, unlocked on success.
func add_collected_mod(mod_id: String, rarity: String = "common") -> void:
	collected_mods.append(mod_id)
	var inst_cost: float = float(LootTables.RARITY_INSTABILITY.get(rarity, 5))
	add_instability(inst_cost)
	var mod_name: String = str(ModApplicability.get_mod(mod_id).get("name", mod_id))
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

## Called when the player picks up a universal trinket drop during a run (task 34).
## At risk until extraction — lost on death, banked to owned_trinkets on success.
func add_collected_trinket(trinket_id: String, rarity: String = "common") -> void:
	collected_trinkets.append(trinket_id)
	var inst_cost: float = float(LootTables.RARITY_INSTABILITY.get(rarity, 5))
	add_instability(inst_cost)
	var display_name: String = TrinketData.ALL[trinket_id].get("display_name", trinket_id) if TrinketData.ALL.has(trinket_id) else trinket_id
	run_loot_manifest.append({ "type": "trinket", "name": display_name, "value": inst_cost, "rarity": rarity })

## Returns the current instability tier dictionary from LootTables.
func get_instability_tier() -> Dictionary:
	return LootTables.get_instability_tier(instability)

## Returns enemy HP/damage multiplier based on instability tier.
func get_instability_multiplier() -> float:
	return 1.0 + get_instability_tier().stat_bonus

## Returns bonus elite spawn rate from instability.
func get_instability_elite_bonus() -> float:
	return get_instability_tier().elite_bonus

## Called by the descent portal to open the extraction window regardless of phase timer.
func open_extraction_window_immediate() -> void:
	if extraction_window_active or current_state != GameState.RUN_ACTIVE:
		return
	_open_extraction_window()

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
				match_name = str(ModApplicability.get_mod(item_id).get("name", item_id))
			if entry.name == match_name:
				var cost: float = entry.value
				run_loot_manifest.remove_at(i)
				return cost
	return float(LootTables.RARITY_INSTABILITY.get("uncommon", 8))
