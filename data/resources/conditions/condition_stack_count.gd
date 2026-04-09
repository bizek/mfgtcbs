class_name ConditionStackCount
extends Resource
## Ability condition: requires stacks of a specific status effect within a range.

@export var status_id: String = ""
@export var min_stacks: int = 1
@export var max_stacks: int = -1  ## -1 = no upper bound. 0 = "only when status absent"
@export var target: String = "self"  ## "self" or "target"
