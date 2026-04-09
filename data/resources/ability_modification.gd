class_name AbilityModification
extends Resource
## Declares effects to add to an existing ability's execution.
## When the target ability fires, these additional effects execute through the
## same EffectDispatcher pipeline on the same targets.

@export var target_ability_id: String = ""           ## Which ability to modify
@export var additional_effects: Array[Resource] = [] ## Effect sub-resources to include
@export var on_displacement_arrival: bool = false    ## When true, effects fire at displacement arrival instead of hit frame
@export var cooldown_flat_reduction: float = 0.0     ## Flat seconds subtracted from ability's base cooldown
