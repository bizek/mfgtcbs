class_name TriggerConditionEventEntityFaction
extends Resource
## Trigger condition: checks if a specific entity in the event belongs to a faction
## relative to the entity bearing the trigger.

@export var entity_role: String = "target"  ## "source" or "target"
@export var faction: String = "enemy"       ## "enemy" or "ally" (relative to trigger bearer)
