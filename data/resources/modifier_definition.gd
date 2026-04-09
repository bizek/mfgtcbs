class_name ModifierDefinition
extends Resource
## Universal modifier shape: modifier(target_tag, operation, value).
## Used by upgrades, weapon mods, status effects, character passives — all the same shape.

@export var target_tag: String = ""        ## What this modifies: "damage", "Physical", "Fire",
                                           ## "armor", "max_hp", "attack_speed", "crit_chance",
                                           ## "crit_multiplier", "move_speed", "pickup_radius",
                                           ## "projectile_count", "pierce", "projectile_size", "All"
@export var operation: String = "add"      ## "add", "bonus", "multiply", "resist", "negate", "pierce",
                                           ## "cooldown_reduce", "duration_modify", "range_modify",
                                           ## "received_bonus", "vulnerability"
@export var value: float = 0.0
@export var min_stacks: int = 0            ## When > 0, modifier only active at this stack count; value is flat (not per-stack)
@export var decay: bool = false            ## When true, value scales linearly from full -> 0 over status duration
@export var source_name: String = ""       ## For UI stat display
