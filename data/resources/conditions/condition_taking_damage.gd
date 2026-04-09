class_name ConditionTakingDamage
extends Resource
## Condition: entity has taken damage within a time window.

@export var window: float = 3.0  ## Seconds — condition is true if hit within this window
@export var required_tag: String = ""  ## If set, only hits from abilities with this tag count
