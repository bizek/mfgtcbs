class_name DamageCalculator
extends RefCounted
## Stateless utility. Takes source, target, ability, effect -> returns HitData.
## 8-step pipeline: base -> conversion -> offensive mods -> dodge -> block -> resist -> damage_taken -> crit.

const RESIST_K := 100.0  ## Tuning constant: 100 armor = 50% reduction


static func calculate_raw_hit(source: Node2D, target: Node2D,
		base_damage: float, damage_type: String = "Physical",
		ability = null, rng: RandomNumberGenerator = null) -> HitData:
	## Convenience: routes a raw damage value through the full 8-step pipeline.
	## Used by legacy callers that don't have a DealDamageEffect to hand in.
	var effect := DealDamageEffect.new()
	effect.damage_type = damage_type
	effect.base_damage = base_damage
	effect.scaling_attribute = ""
	effect.scaling_coefficient = 0.0
	return calculate_damage(source, target, ability, effect, rng)


static func calculate_damage(source: Node2D, target: Node2D,
		ability, effect, rng: RandomNumberGenerator = null) -> HitData:
	## ability: AbilityDefinition (Layer 2), effect: DealDamageEffect (Layer 2)
	## Both untyped until those Resource classes exist.
	var src_mods: ModifierComponent = source.modifier_component
	var tgt_mods: ModifierComponent = target.modifier_component

	# Step 1: Base hit — base_damage * (1 + scaling_value * coefficient)
	var scaling_value: float = 0.0
	if effect.scaling_attribute != "":
		scaling_value = src_mods.sum_modifiers(effect.scaling_attribute, "add")
	var raw: float = effect.base_damage * (1.0 + scaling_value * effect.scaling_coefficient)

	# Step 2: Conversion (once only, True damage immune)
	var original_type: String = effect.damage_type
	var damage_type: String = _apply_conversion(source, original_type)

	# Step 3: Offensive modifiers (additive within category)
	# Bonuses to both original and converted type apply
	# "All" bonus applies to every damage type
	var damage_bonus: float = src_mods.sum_modifiers(damage_type, "bonus")
	if damage_type != original_type:
		damage_bonus += src_mods.sum_modifiers(original_type, "bonus")
	damage_bonus += src_mods.sum_modifiers("All", "bonus")
	raw *= (1.0 + damage_bonus)

	# Step 4: Dodge check
	var dodge_chance: float = tgt_mods.sum_modifiers("dodge_chance", "add")
	if dodge_chance > 0.0 and (rng.randf() if rng else randf()) < dodge_chance:
		var dodge_hit := HitData.create(0.0, damage_type, source, target, ability)
		dodge_hit.original_damage_type = original_type
		dodge_hit.is_dodged = true
		EventBus.on_dodge.emit(source, target, dodge_hit)
		return dodge_hit

	# Step 5: Block check (partial mitigation)
	var is_blocked := false
	var block_mitigated := 0.0
	var block_chance: float = tgt_mods.sum_modifiers("block_chance", "add")
	if block_chance > 0.0 and (rng.randf() if rng else randf()) < block_chance:
		is_blocked = true
		var block_percent: float = tgt_mods.sum_modifiers("block_mitigation", "add")
		block_mitigated = raw * block_percent
		raw -= block_mitigated

	# Step 6: Resistance (per damage type — "armor" is Physical resist)
	# Pierce is percentage-based: 0.25 = ignore 25% of target's resistance
	var resist: float = tgt_mods.sum_modifiers(damage_type, "resist")
	var pierce: float = src_mods.sum_modifiers(damage_type, "pierce")
	var effective_resist: float = maxf(0.0, resist * (1.0 - pierce))
	raw *= (1.0 - effective_resist / (effective_resist + RESIST_K))

	# Step 6.5: Damage taken modifiers (status effects, abilities — additive then multiplied)
	var pre_dr: float = raw
	var damage_taken: float = tgt_mods.sum_modifiers(damage_type, "damage_taken")
	damage_taken += tgt_mods.sum_modifiers("All", "damage_taken")
	if damage_taken != 0.0:
		raw *= maxf(0.0, 1.0 + damage_taken)
	var dr_mitigated: float = pre_dr - raw

	# Step 7: Vulnerability (additive — per-type + "All")
	var vulnerability: float = tgt_mods.sum_modifiers(damage_type, "vulnerability")
	vulnerability += tgt_mods.sum_modifiers("All", "vulnerability")
	raw *= (1.0 + vulnerability)

	# Step 8: Crit
	var is_crit := false
	var crit_chance: float = src_mods.sum_modifiers("crit_chance", "add")
	if crit_chance > 0.0 and (rng.randf() if rng else randf()) < crit_chance:
		is_crit = true
		var crit_multiplier: float = src_mods.sum_modifiers("crit_multiplier", "add")
		raw *= (1.0 + crit_multiplier)

	# Build HitData
	var hit := HitData.create(maxf(raw, 0.0), damage_type, source, target, ability)
	hit.original_damage_type = original_type
	hit.is_crit = is_crit
	hit.is_blocked = is_blocked
	hit.block_mitigated = block_mitigated
	hit.dr_mitigated = dr_mitigated

	# Fire block event after HitData is constructed
	if is_blocked:
		EventBus.on_block.emit(source, target, hit, block_mitigated)

	return hit


static func calculate_healing(source: Node2D, target: Node2D,
		effect, rng: RandomNumberGenerator = null) -> float:
	## 4-step healing pipeline: base -> healing bonus -> healing received -> crit.
	## effect: HealEffect (Layer 2) — untyped until that Resource class exists.
	var src_mods: ModifierComponent = source.modifier_component
	var tgt_mods: ModifierComponent = target.modifier_component

	# Step 1: Base heal — scaling or percent-max-HP
	var raw: float
	if effect.percent_max_hp > 0.0:
		raw = target.health.max_hp * effect.percent_max_hp
	else:
		var scaling_value: float = 0.0
		if effect.scaling_attribute != "":
			scaling_value = src_mods.sum_modifiers(effect.scaling_attribute, "add")
		raw = effect.base_healing * (1.0 + scaling_value * effect.scaling_coefficient)

	# Step 2: Healing bonus (additive, from source)
	var healing_bonus: float = src_mods.sum_modifiers("Heal", "bonus")
	raw *= (1.0 + healing_bonus)

	# Step 3: Healing received (additive, from target)
	var healing_received: float = tgt_mods.sum_modifiers("Heal", "received_bonus")
	raw *= (1.0 + healing_received)

	# Step 4: Crit heal
	var crit_chance: float = src_mods.sum_modifiers("crit_chance", "add")
	if crit_chance > 0.0 and (rng.randf() if rng else randf()) < crit_chance:
		var crit_multiplier: float = src_mods.sum_modifiers("crit_multiplier", "add")
		raw *= (1.0 + crit_multiplier)

	# Curse check handled by EffectDispatcher (Layer 3)

	return maxf(raw, 0.0)


static func calculate_curse_damage(source: Node2D, target: Node2D,
		heal_amount: float) -> HitData:
	## Curse inversion: healing amount enters damage pipeline as typed damage.
	## Applies resistance + vulnerability only. No crit, no block, no dodge.
	var tgt_mods: ModifierComponent = target.modifier_component

	# Read curse damage type from the active Curse status
	var curse_def = target.status_effect_component.get_definition("curse")
	var curse_type: String = curse_def.curse_damage_type if curse_def and curse_def.curse_damage_type != "" else "Shadow"

	var raw: float = heal_amount

	# Resistance (same formula as damage pipeline Step 6)
	var resist: float = tgt_mods.sum_modifiers(curse_type, "resist")
	var effective_resist: float = maxf(0.0, resist)  # No pierce on curse damage
	raw *= (1.0 - effective_resist / (effective_resist + RESIST_K))

	# Vulnerability (same as damage pipeline Step 7 — per-type + "All")
	var vulnerability: float = tgt_mods.sum_modifiers(curse_type, "vulnerability")
	vulnerability += tgt_mods.sum_modifiers("All", "vulnerability")
	raw *= (1.0 + vulnerability)

	# No crit, no block, no dodge — create HitData directly
	var hit := HitData.create(maxf(raw, 0.0), curse_type, source, target, null)
	hit.original_damage_type = curse_type
	return hit


static func _apply_conversion(source: Node2D, original_type: String) -> String:
	if original_type == "True":
		return original_type
	var src_mods: ModifierComponent = source.modifier_component
	var conversion := src_mods.get_first_conversion(original_type)
	if conversion:
		EventBus.on_conversion.emit(source, original_type, conversion.target_type)
		return conversion.target_type
	return original_type
