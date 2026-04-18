class_name EnemyDefinition
extends Resource
## Defines an enemy type. Pure data — consumed by entity setup.

@export var enemy_id: String = ""
@export var enemy_name: String = ""
@export var tags: Array[String] = []
@export var base_stats: Dictionary = {}        ## {"max_hp": 50.0, "damage": 10.0, "armor": 5.0, ...}
@export var auto_attack: AbilityDefinition
@export var skills: Array[SkillDefinition] = []
@export var sprite_sheet: SpriteFrames
@export var hit_frame: int = 3
@export var combat_role: String = "MELEE"      ## "MELEE" or "RANGED"
@export var engage_distance: float = 20.0
@export var move_speed: float = 25.0
@export var aggro_range: float = 0.0
@export var retarget_interval: float = 1.5
@export var preferred_range: float = 0.0
@export var aa_interval_override: float = 0.0  ## When > 0, overrides attack speed interval
@export var xp_value: float = 10.0
@export var is_elite: bool = false
@export var is_boss: bool = false
@export var boss_bar_color: Color = Color(0.80, 0.12, 0.12)  ## Boss health-bar tint (only used when is_boss)

## Arena survivor extensions
@export var contact_damage: float = 10.0
@export var base_armor: float = 0.0
@export var health_drop_chance: float = 0.05
@export var base_modulate: Color = Color.WHITE  ## Tint color for sprite
@export var sprite_scale: Vector2 = Vector2(1.0, 1.0)
@export var groups: Array[String] = []          ## Additional groups ("carriers", "guardians")
@export var behavior_type: String = "chase"     ## "chase", "ranged", "flee"
@export var knockback_multiplier: float = 1.0   ## < 1.0 for heavy enemies
@export var flee_despawn_at_bounds: bool = false ## Carrier-style: despawn silently at arena edge
@export var on_spawn_statuses: Array[StatusEffectDefinition] = []  ## Applied at setup (aura, stealth, etc.)
