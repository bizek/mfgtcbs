class_name HealthComponent
extends Node
## Mutable HP and shield state for an entity.

signal health_changed(current_hp: float, max_hp: float)
signal died(entity: Node2D)
signal death_prevented(entity: Node2D)
signal shield_depleted(entity: Node2D)

var max_hp: float = 100.0
var current_hp: float = 100.0
var shield_hp: float = 0.0
var is_dead: bool = false
var last_overkill: float = 0.0  ## Excess damage past 0 HP on the killing blow
var _death_prevention_count: int = 0  ## Number of active statuses with prevents_death


func setup(hp: float) -> void:
	max_hp = hp
	current_hp = hp
	health_changed.emit(current_hp, max_hp)


func apply_damage(hit_data) -> float:
	if is_dead:
		return 0.0

	var amount: float
	if hit_data is HitData:
		amount = hit_data.amount
	else:
		amount = hit_data.get("amount", 0.0)

	# Shield absorption
	if shield_hp > 0.0:
		var absorbed := minf(shield_hp, amount)
		shield_hp -= absorbed
		amount -= absorbed
		if hit_data is HitData:
			EventBus.on_absorb.emit(get_parent(), hit_data, absorbed)
		if shield_hp <= 0.0:
			shield_depleted.emit(get_parent())

	var previous_hp := current_hp
	current_hp = maxf(current_hp - amount, 0.0)
	var actual_damage := previous_hp - current_hp
	health_changed.emit(current_hp, max_hp)

	if current_hp <= 0.0 and not is_dead:
		if _death_prevention_count > 0:
			current_hp = 1.0
			health_changed.emit(current_hp, max_hp)
			death_prevented.emit(get_parent())
			return previous_hp - current_hp
		last_overkill = amount - actual_damage
		is_dead = true
		died.emit(get_parent())

	return actual_damage


func apply_healing(amount: float) -> void:
	if is_dead:
		return
	current_hp = minf(current_hp + amount, max_hp)
	health_changed.emit(current_hp, max_hp)


func add_shield(amount: float, _source: String = "") -> void:
	shield_hp += amount
