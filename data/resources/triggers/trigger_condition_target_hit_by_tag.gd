class_name TriggerConditionTargetHitByTag
extends Resource
## Trigger condition: the event target was recently hit by an ability with a specific tag.

@export var tag: String = ""       ## Required ability tag on the hit that marked the target
@export var window: float = 3.0   ## Maximum seconds since the hit (inclusive)
