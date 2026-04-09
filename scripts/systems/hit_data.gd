class_name HitData
extends RefCounted
## Runtime damage result from DamageCalculator. Not serialized.

var amount: float = 0.0
var damage_type: String = "Physical"
var original_damage_type: String = "Physical"
var is_crit: bool = false
var is_blocked: bool = false
var is_dodged: bool = false
var block_mitigated: float = 0.0
var dr_mitigated: float = 0.0
var source: Node2D = null
var target: Node2D = null
var ability = null  # Will be AbilityDefinition once Layer 2 is built
var is_reflected: bool = false  ## True for thorns/reflect damage — prevents recursive reflection


static func create(p_amount: float, p_damage_type: String, p_source: Node2D,
		p_target: Node2D, p_ability = null) -> HitData:
	var h := HitData.new()
	h.amount = p_amount
	h.damage_type = p_damage_type
	h.original_damage_type = p_damage_type
	h.source = p_source
	h.target = p_target
	h.ability = p_ability
	return h
