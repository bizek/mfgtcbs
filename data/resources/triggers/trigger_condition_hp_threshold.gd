class_name TriggerConditionHpThreshold
extends Resource
## Trigger condition: the entity bearing the trigger has HP above/below a threshold.

@export var threshold: float = 0.4    ## HP ratio (0.0-1.0)
@export var direction: String = "below"  ## "below" or "above"
