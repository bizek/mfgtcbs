class_name AreaDamageEffect
extends Resource
## Effect sub-resource: deal damage to all enemies within a radius of the target's position.
## Full damage pipeline (DamageCalculator) runs per target — not raw/flat damage.

@export var damage_type: String = "Physical"
@export var scaling_attribute: String = ""      ## Modifier tag to scale from ("" = no scaling)
@export var scaling_coefficient: float = 1.0
@export var base_damage: float = 1.0
@export var aoe_radius: float = 20.0
## Optional per-hit effects executed on each enemy this AoE damages (e.g. Galvanized Bleed spread).
@export var on_hit_effects: Array = []
