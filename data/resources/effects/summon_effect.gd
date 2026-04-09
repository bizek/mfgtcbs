class_name SummonEffect
extends Resource
## Effect sub-resource: summon an entity during combat.

@export var summon_id: String = ""                # Unique ID for this summon type
@export var summon_class = null                   # Template definition for the summon (ClassDefinition equivalent — typed when Layer 6 entity defs exist)
@export var max_active: int = 1                   # Max simultaneous summons per summoner
@export var stat_map: Dictionary = {}             # Summon stat seeding from summoner modifiers
@export var duration: float = 0.0                 # Summon lifetime in seconds (0 = permanent, lives until killed)
@export var is_untargetable: bool = false          # True = excluded from spatial grid (can't be targeted)
@export var threat_modifier: float = 0.0          # Innate threat bias for the summon
