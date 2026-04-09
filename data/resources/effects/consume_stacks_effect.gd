class_name ConsumeStacksEffect
extends Resource
## Effect sub-resource: consume stacks of a status from the target.
## Executes per_stack_effects once per stack consumed (for scaling burst damage).
## Triggers the status's on_consume_effects hook and fires EventBus.on_status_consumed.

@export var status_id: String = ""
@export var stacks_to_consume: int = -1  ## -1 = all, positive = consume up to N
@export var per_stack_effects: Array = []  ## Effects to execute per stack consumed
