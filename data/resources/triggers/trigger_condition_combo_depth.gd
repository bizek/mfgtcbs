class_name TriggerConditionComboDepth
extends Resource
## Trigger condition: the combo depth carried by a combo event meets a threshold.
##
## Only meaningful on the three combo events (`on_combo_step`, `on_combo_dropped`), which pass
## `{"depth": int, ...}` as hit_data. On any other event the payload has no "depth" key and the
## condition fails closed — a listener that asks about combo depth on `on_kill` should not fire,
## it should be reported as authoring nonsense.
##
## The two dials are independent and both apply when both are set:
##   min_depth   — depth must be at least this. "Once you are 4 links deep, …"
##   multiple_of — depth must divide by this. "Every 3rd strike, …"
##
## Depth is 1-BASED (player.gd `_combo_step_depth`), so multiple_of 3 fires on steps 3, 6, 9.

@export var min_depth: int = 1        ## depth >= this (1 = any depth)
@export var multiple_of: int = 0      ## depth % this == 0 (0 or 1 = no modulo gate)
