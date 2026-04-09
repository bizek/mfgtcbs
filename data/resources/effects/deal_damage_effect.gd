class_name DealDamageEffect
extends Resource
## Effect sub-resource: deal damage to targets.

@export var damage_type: String = "Physical"    ## "Physical", "Fire", "Ice", "Lightning", "Void"
@export var scaling_attribute: String = ""      ## Modifier tag to scale from ("damage", etc. — "" = no scaling)
@export var scaling_coefficient: float = 1.0
@export var base_damage: float = 0.0
