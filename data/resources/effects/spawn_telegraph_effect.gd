class_name SpawnTelegraphEffect
extends Resource
## Effect sub-resource: spawn a wind-up telegraph shape at a position.
## Used inside ChoreographyPhase effects during a wind-up phase, paired
## with a hit-frame damage effect in a later phase.

## Shape of the telegraph: "circle", "ring", "line", "cone"
@export var shape: String = "circle"

## Where the telegraph anchors:
##   "target_position"      — snap once at spawn to target.global_position
##   "target_follow"        — track target.global_position every frame
##   "source_position"      — snap to source.global_position (stationary)
##   "source_forward_line"  — line/cone originating at source, pointed at target
@export var anchor: String = "target_position"

@export var radius: float = 40.0          ## circle/ring radius (px)
@export var length: float = 120.0         ## line/cone length (px)
@export var width: float = 20.0           ## line width (px)
@export var cone_angle_deg: float = 45.0  ## cone arc (degrees)

@export var duration: float = 0.8         ## wind-up seconds (despawn at end)
@export var color: Color = Color(1.0, 0.25, 0.20, 0.55)
@export var fill_build_up: bool = true    ## fill alpha ramps 0→full over duration

## Optional tag; a later phase can cancel via TelegraphManager.cancel(source, id).
@export var telegraph_id: String = ""
