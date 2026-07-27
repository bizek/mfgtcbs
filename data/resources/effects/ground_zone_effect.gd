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

## Persistent footprint drawn for the zone's whole life (GroundZoneVfx). One of the keys in
## GroundZoneVfx.ELEMENTS — "fire" / "ice" / "electric" / "poison" / "arcane" / "shadow".
## Empty = no footprint (the zone is invisible, which is what every zone used to be).
@export var vfx_element: String = ""
## Modulate applied to the footprint, so one sheet can serve several fantasies — the Poison
## tileable goes crimson for the Blood Mage's pool, green for the Druid's roots.
@export var vfx_tint: Color = Color.WHITE
