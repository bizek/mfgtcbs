class_name ProjectileConfig
extends Resource
## Configures how a single projectile behaves. Pure data.

# --- Motion ---
@export var motion_type: String = "directional"  ## "directional", "aimed", "homing"
@export var speed: float = 80.0                  ## Pixels/sec
@export var max_range: float = 0.0               ## Max travel distance (0 = screen bounds)
@export var arc_height: float = 0.0              ## Parabolic arc peak height (0 = straight line)

# --- Visual ---
@export var sprite_frames: SpriteFrames
@export var use_directional_anims: bool = true   ## true = pick anim from direction ("n","ne","e"...)
@export var animation: String = ""               ## Single anim name if not directional
@export var visual_scale: Vector2 = Vector2.ONE
@export var fallback_color: Color = Color(1.0, 0.5, 0.1, 0.9) ## Procedural circle color when no sprite_frames

# --- Hit Detection ---
@export var hit_radius: float = 8.0              ## Distance at which a target is "hit"

# --- On-Hit Behavior ---
@export var pierce_count: int = 0                ## 0 = destroy on first hit, -1 = infinite
@export var on_hit_effects: Array = [] ## DealDamageEffect, ApplyStatusEffectData, etc.

# --- Ricochet (wall bounce) ---
@export var bounce_count: int = 0                ## Number of wall bounces (0 = none)

# --- On-Expire Behavior (split, etc.) ---
@export var on_expire_effects: Array = []        ## SpawnProjectilesEffect etc. fired when projectile expires or runs out of pierces

# --- Impact VFX (optional) ---
@export var impact_sprite_frames: SpriteFrames   ## One-shot VfxEffect on hit (null = none)
@export var impact_animation: String = ""

# --- Impact AOE (splash damage) ---
@export var impact_aoe_radius: float = 0.0       ## Splash radius around impact (0 = no splash)
@export var impact_aoe_effects: Array = []        ## Effects on splash targets
