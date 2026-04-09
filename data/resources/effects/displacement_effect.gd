class_name DisplacementEffect
extends Resource
## Effect sub-resource: displace an entity along a path, apply effects on arrival.
## Supports: throw (arc to destination), knockback (linear away), pull (toward source),
## charge (move caster toward target).

## Who gets displaced: "target" (targets[0]) or "self" (the caster).
@export var displaced: String = "target"

## Where they go: "to_target" (toward targets[1]), "away_from_source" (knockback),
## "toward_source" (pull).
@export var destination: String = "to_target"

## Motion shape: "arc" (parabolic) or "linear" (straight line).
@export var motion: String = "arc"

## Flight duration in seconds.
@export var duration: float = 0.5

## Peak height for arc motion (ignored for linear).
@export var arc_height: float = 40.0

## Distance for direction-based displacement (knockback/pull). Ignored for "to_target".
## When distance_min > 0, actual distance is randomized between distance_min and distance.
@export var distance: float = 30.0

## Minimum distance for random range (0 = use distance as fixed value).
@export var distance_min: float = 0.0

## Rotate displaced entity during flight (clockwise, one full turn).
@export var rotate: bool = false

## Bounce distance after arrival (0 = no bounce). Direction = away from arrival point.
@export var bounce_distance: float = 0.0

## Teleport displaced entity to source position before starting motion ("grab" effect).
@export var teleport_to_source: bool = false

## Effects applied to the displaced entity on arrival.
@export var on_arrival_displaced_effects: Array[Resource] = []

## Effects applied to the destination entity on arrival (only for "to_target").
@export var on_arrival_destination_effects: Array[Resource] = []

## Effects applied to BOTH displaced and destination entities on arrival.
@export var on_arrival_both_effects: Array[Resource] = []

## Animation to play on displaced entity during flight ("" = no animation, entity freezes).
@export var displacement_animation: String = ""
