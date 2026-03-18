extends Node

## CombatManager — Damage resolution using flat armor formula

signal damage_dealt(attacker: Node, defender: Node, amount: float, was_crit: bool)
signal entity_killed(killer: Node, victim: Node, position: Vector2)

func resolve_hit(attacker: Node, defender: Node, base_damage: float, crit_chance: float = 0.05, crit_multiplier: float = 1.5) -> void:
	if not is_instance_valid(defender) or not defender.has_method("take_damage"):
		return
	
	var raw_damage: float = base_damage
	var was_crit: bool = false
	
	## Crit roll
	if randf() < crit_chance:
		raw_damage *= crit_multiplier
		was_crit = true
	
	## Flat armor reduction
	var armor: float = 0.0
	if defender.has_method("get_armor"):
		armor = defender.get_armor()
	var final_damage: float = maxf(raw_damage - armor, 1.0)
	
	## Apply damage
	defender.take_damage(final_damage)
	damage_dealt.emit(attacker, defender, final_damage, was_crit)

	## Knockback: push defender away from attacker
	if defender.has_method("apply_knockback") and attacker is Node2D and defender is Node2D:
		var kb_dir: Vector2 = (defender.global_position - attacker.global_position).normalized()
		if kb_dir == Vector2.ZERO:
			kb_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		defender.apply_knockback(kb_dir * 160.0)

	## Check death
	if defender.has_method("is_dead") and defender.is_dead():
		entity_killed.emit(attacker, defender, defender.global_position)
