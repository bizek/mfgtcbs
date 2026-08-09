class_name ComboEffectResolver
extends Node
## Runtime combo discovery + mastery tracker.
##
## A "combo" is a MOD EVOLUTION since 2026-08-08 (ClassModData.EVOLUTIONS) — a capstone that fires
## when both of its roster mods are equipped on the character. This node owns the codex side of
## that: marking an evolution revealed the first time it does work in a run, counting triggers
## toward mastery, and emitting the discovery flash.
##
## ── WHAT THIS REPLACED, AND WHY IT SHRANK FROM ~380 LINES TO THIS ────────────────────
## The old version had two halves and BOTH were dead:
##
##   1. `notify_projectile_hit/expire/bounce` — hooks for behavior combos whose effects
##      ModComboFactory baked into ProjectileConfig. Its own docstring carried a step-by-step
##      integration guide for ProjectileManager (parallel `_proj_combo_ids` array, calls from
##      `_on_hit` / `_on_bounce` / `_fire_on_expire`). **That integration was never done.** The
##      three methods had zero callers anywhere in the project — verified 2026-08-08 — so no
##      behavior combo has ever recorded a trigger or reached mastery.
##
##   2. Elemental-reaction handlers on EventBus (`_on_status_applied` and friends) firing ids
##      like `frostfire` / `conductor`. Those were ELEMENTAL_ELEMENTAL combos over the generic
##      elemental mods, which retired with the rest of that layer. The ids no longer exist in
##      the registry, so keeping the handlers would have meant a push_warning on every status
##      application in the game.
##
## What replaces them is deliberately simpler: an evolution is REVEALED when the player lands a
## hit while it is active. That is honest — the evolution genuinely is modifying that hit, because
## ClassModFactory folded it into the kit at build time — and it needs no per-effect plumbing.

## Emitted the first time a combo fires in a run (CodexEntry.revealed transitions false→true).
## HUD listens to show a discovery flash banner.
## combo_type matches ModCombo.ComboType enum value so HUD can style triples differently.
signal combo_first_triggered(combo_id: StringName, combo_name: String, combo_type: int)

## Emitted when a capstone of the rarest tier fires for the first time.
## Separate signal so HUD can trigger a more dramatic effect.
signal triple_combo_first_triggered(combo_id: StringName, combo_name: String)

var combat_manager: Node2D = null

## Evolutions active for the current loadout. Refreshed on demand rather than every hit —
## _load_combo is the only thing that can change it, and it is not on a hot path.
var _active: Array[StringName] = []
var _active_dirty: bool = true


func _ready() -> void:
	EventBus.on_hit_dealt.connect(_on_hit_dealt)


## Called by player._load_combo (via CombatOrchestrator) when the mod loadout changes.
func invalidate_active() -> void:
	_active_dirty = true


func _refresh_active() -> void:
	_active_dirty = false
	_active.clear()
	var char_id: String = ProgressionManager.selected_character
	var kit_id: String = ModApplicability.kit_of(char_id)
	if kit_id.is_empty():
		return
	var equipped: Array = ProgressionManager.get_active_class_mods(char_id)
	for evo_id: String in ClassModData.active_evolutions(kit_id, equipped):
		_active.append(StringName(evo_id))
		## Discovery is "you assembled it", which is true the moment it is equipped —
		## the reveal below is the stronger "you used it".
		CodexManager.discover_combo(StringName(evo_id))


func _on_hit_dealt(source: Node2D, _target: Node2D, _hit_data: Variant) -> void:
	## Player hits only — an enemy landing a hit says nothing about the player's build.
	if source == null or not source.is_in_group("player"):
		return
	if _active_dirty:
		_refresh_active()
	for combo_id: StringName in _active:
		_fire_combo(combo_id)


## ── Core record + signal ──────────────────────────────────────────────────────────

func _fire_combo(combo_id: StringName) -> void:
	## Central dispatch: record trigger in CodexManager, emit discovery signals.
	## Safe to call frequently — CodexManager.record_trigger is O(1).
	if not CodexManager:
		return
	if not CodexManager.entries.has(combo_id):
		push_warning("ComboEffectResolver: unknown combo_id '%s'" % combo_id)
		return

	var entry: CodexEntry = CodexManager.entries[combo_id]
	var first_reveal: bool = not entry.revealed

	if first_reveal:
		CodexManager.reveal_combo(combo_id)
		combo_first_triggered.emit(combo_id, entry.combo.combo_name, entry.combo.combo_type)
		if entry.combo.combo_type == ModCombo.ComboType.TRIPLE_LEGENDARY:
			triple_combo_first_triggered.emit(combo_id, entry.combo.combo_name)

	CodexManager.record_trigger(combo_id)
