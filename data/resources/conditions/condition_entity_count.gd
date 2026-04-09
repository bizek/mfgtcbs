class_name ConditionEntityCount
extends Resource
## Condition: at least min_count entities of the specified faction exist.

@export var faction: String = "enemy"   ## "enemy", "ally"
@export var min_count: int = 1          ## Minimum entities required
@export var range: float = 0.0          ## Max distance from source (0 = unlimited)
@export var exclude_range: float = 0.0  ## Fails if ANY entity is closer than this (0 = disabled)
