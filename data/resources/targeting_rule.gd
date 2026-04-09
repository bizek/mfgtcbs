class_name TargetingRule
extends Resource
## Defines how an ability selects its targets.

@export var type: String = "nearest_enemy"  ## "nearest_enemy", "nearest_enemies", "furthest_enemy",
                                            ## "lowest_hp_ally", "self", "all_enemies_in_range",
                                            ## "self_centered_burst", "all_allies"
@export var max_range: float = 0.0         ## Max distance (0 = unlimited)
@export var max_targets: int = 1           ## How many targets
@export var height: float = 0.0            ## Rectangle height for area targeting (0 = unused)
@export var min_nearby: int = 0            ## Min OTHER enemies within nearby_radius of target (0 = no cluster filter)
@export var nearby_radius: float = 0.0     ## Radius for cluster check around resolved target
@export var target_status_id: String = ""  ## Status ID for stack-based targeting
