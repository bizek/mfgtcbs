class_name ApplyShieldEffect
extends Resource
## Effect sub-resource: apply shield HP to targets.

@export var scaling_attribute: String = ""      ## Modifier tag to scale from ("" = no scaling)
@export var scaling_coefficient: float = 1.0
@export var base_shield: float = 0.0
