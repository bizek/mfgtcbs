class_name SpawnProjectilesEffect
extends Resource
## Effect sub-resource: spawn projectiles that deliver effects on contact.

@export var projectile: ProjectileConfig         ## What each projectile is
@export var spawn_pattern: String = "radial"     ## "radial", "at_targets", "aimed_single", "spread"
@export var count: int = 8                       ## Projectile count (for radial and spread)
@export var spawn_offset: Vector2 = Vector2.ZERO ## Offset from entity center
@export var spread_angle: float = 10.0           ## Total cone width in degrees (for spread pattern)
