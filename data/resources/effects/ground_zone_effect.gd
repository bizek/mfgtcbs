class_name GroundZoneEffect
extends Resource
## Effect sub-resource: spawn a persistent ground zone at a world position.
## The zone ticks periodically, applying effects to entities within its radius.

@export var zone_id: String = ""                  ## For identification/debugging
@export var radius: float = 20.0                  ## Radius in pixels
@export var duration: float = 4.0                 ## How long the zone persists (seconds)
@export var tick_interval: float = 0.5            ## How often tick_effects fire (seconds)
@export var target_faction: String = "enemy"      ## "enemy" or "ally" — which faction is affected
@export var tick_effects: Array[Resource] = []    ## Effects applied to entities in range each tick
@export var debug_color: Color = Color(0.8, 0.4, 0.0, 1.0) ## Debug circle fill color
