class_name TriggerListenerDefinition
extends Resource
## A listener that registers on the EventBus via TriggerComponent.
## When the specified event fires and all conditions pass, executes effects.

@export var event: String = ""                        ## "on_hit_dealt", "on_kill", "on_crit", etc.
@export var conditions: Array[Resource] = []          ## Typed trigger condition sub-resources
@export var effects: Array[Resource] = []             ## Typed effect sub-resources
@export var target_self: bool = false                 ## When true, effects target the entity bearing the trigger
@export var target_event_source: bool = false         ## When true, effects target the event source
