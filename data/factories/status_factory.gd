class_name StatusFactory
extends RefCounted
## Builds all StatusEffectDefinitions for the game. Called once at startup.
## These are the engine-pattern equivalents of the old inline status effects.

## Cached definitions — built once, reused everywhere
static var burning: StatusEffectDefinition
static var bleed: StatusEffectDefinition
static var chilled: StatusEffectDefinition
static var frozen: StatusEffectDefinition
static var shocked: StatusEffectDefinition
static var void_touched: StatusEffectDefinition
static var shade_invisible: StatusEffectDefinition

static var _built: bool = false


static func build_all() -> void:
	if _built:
		return
	_built = true

	burning = _build_burning()
	bleed = _build_bleed()
	chilled = _build_chilled()
	frozen = _build_frozen()
	shocked = _build_shocked()
	void_touched = _build_void_touched()
	shade_invisible = _build_shade_invisible()


static func get_by_id(status_id: String) -> StatusEffectDefinition:
	build_all()
	match status_id:
		"burning", "fire":
			return burning
		"bleed":
			return bleed
		"chilled", "cryo":
			return chilled
		"frozen":
			return frozen
		"shocked", "shock":
			return shocked
		"void_touched":
			return void_touched
		"shade_invisible":
			return shade_invisible
	return null


static func _build_burning() -> StatusEffectDefinition:
	## 3 damage/sec for 3 seconds. Refreshes duration on reapply.
	var def := StatusEffectDefinition.new()
	def.status_id = "burning"
	def.tags = ["Fire", "DoT"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 3.0
	def.duration_refresh_mode = "overwrite"
	def.tick_interval = 1.0

	var tick_dmg := DealDamageEffect.new()
	tick_dmg.damage_type = "Fire"
	tick_dmg.base_damage = 3.0
	def.tick_effects = [tick_dmg]

	return def


static func _build_bleed() -> StatusEffectDefinition:
	## 2 damage/sec for 4 seconds. Refreshes duration on reapply.
	var def := StatusEffectDefinition.new()
	def.status_id = "bleed"
	def.tags = ["Physical", "DoT"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 4.0
	def.duration_refresh_mode = "overwrite"
	def.tick_interval = 1.0

	var tick_dmg := DealDamageEffect.new()
	tick_dmg.damage_type = "Physical"
	tick_dmg.base_damage = 2.0
	def.tick_effects = [tick_dmg]

	return def


static func _build_chilled() -> StatusEffectDefinition:
	## -30% move speed for 3 seconds. Stacks toward Frozen at 3 stacks.
	var def := StatusEffectDefinition.new()
	def.status_id = "chilled"
	def.tags = ["Ice", "CC"]
	def.is_positive = false
	def.max_stacks = 3
	def.base_duration = 3.0
	def.duration_refresh_mode = "overwrite"

	var slow_mod := ModifierDefinition.new()
	slow_mod.target_tag = "move_speed"
	slow_mod.operation = "bonus"
	slow_mod.value = -0.30
	slow_mod.source_name = "chilled"
	def.modifiers = [slow_mod]

	return def


static func _build_frozen() -> StatusEffectDefinition:
	## Stun for 1.5 seconds. Cannot move or act.
	var def := StatusEffectDefinition.new()
	def.status_id = "frozen"
	def.tags = ["Ice", "CC", "Stun"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 1.5
	def.disables_actions = true
	def.disables_movement = true

	return def


static func _build_shocked() -> StatusEffectDefinition:
	## Next hit chains 50% damage to nearest enemy within 100px, then consumed.
	## Shock chain needs access to incoming damage amount, which on_hit_received_effects
	## don't receive. Chain logic lives in enemy.take_damage() as a post-hit check.
	## This status is a marker that gets consumed on first hit.
	var def := StatusEffectDefinition.new()
	def.status_id = "shocked"
	def.tags = ["Lightning"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 5.0

	return def


static func _build_void_touched() -> StatusEffectDefinition:
	## Permanent debuff. On death: AOE explosion damaging nearby enemies + instability bleed.
	## Death explosion is handled by the entity's death callback since it needs
	## game-specific logic (instability system). This status marks the entity.
	var def := StatusEffectDefinition.new()
	def.status_id = "void_touched"
	def.tags = ["Void"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = -1.0  ## Permanent

	return def


static func _build_shade_invisible() -> StatusEffectDefinition:
	## Brief invisibility on dodge. 0.5 seconds.
	var def := StatusEffectDefinition.new()
	def.status_id = "shade_invisible"
	def.tags = ["Stealth"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = 0.5

	return def
