extends Node2D
## Auto-aim lock indicator (Settings.auto_aim). Corner brackets drawn over the enemy
## player.gd currently has locked, so the player can SEE what the next swing, cast or
## Shield Rush is going to point at without having aimed at anything.
##
## Lives as a top_level child of the player with a high z_index: the arena y-sorts, so a
## reticle drawn on the player node itself would be hidden behind any enemy standing
## below it. Purely cosmetic — it never participates in targeting.

## Box half-size is measured off the target's sprite, NOT its hurtbox: the size difference
## between a swarmer and a boss lives entirely in `EnemyDefinition.sprite_scale` (Ancient Troll
## 2.4x, Heart of the Deep 3.2x), which enemy.gd applies to the sprite while the authored
## collision shape stays small. A hurtbox-sized bracket would sit inside a boss's feet.
##
## Sheets are padded — a 32px fodder cell holds a ~16px zombie, a 48px goblin-king cell a ~26px
## king — so the on-screen frame extent is halved to approximate the drawn silhouette.
const SPRITE_FILL: float = 0.5
const BOX_PAD: float = 3.0    ## breathing room between silhouette and bracket, world px
const BOX_MIN: float = 7.0
const BOX_MAX: float = 56.0   ## keeps the 3.2x-scaled Heart of the Deep from filling the screen
const BOX_FALLBACK: float = 9.0  ## target has no readable sprite
## Corner arm length, proportional so a boss bracket doesn't read as four stray ticks.
const ARM_RATIO: float = 0.33
const ARM_MIN: float = 3.0
const ARM_MAX: float = 12.0

## Acquisition pop: the box eases in from this multiple of its resting size so a lock swap
## reads as a snap.
const POP_SCALE: float = 1.9
const POP_TIME: float = 0.12

const COLOR_LOCK := Color(0.941, 0.565, 0.188, 0.85)  ## hub amber — same accent the HUD uses

var target: Node2D = null

var _pop: float = 0.0     ## counts down POP_TIME after each new acquisition
var _last_target: Node2D = null
var _box: float = BOX_FALLBACK


func _ready() -> void:
	top_level = true
	z_index = 90
	z_as_relative = false


func _process(delta: float) -> void:
	if target != null and not is_instance_valid(target):
		target = null
	if target != _last_target:
		_last_target = target
		_pop = POP_TIME if target != null else 0.0
	visible = target != null
	if not visible:
		return
	_pop = maxf(_pop - delta, 0.0)
	## Re-measured every frame rather than cached on acquisition: sprite_scale is applied in
	## enemy setup and a kill-pop tween drives scale at runtime, so a cached size would lag.
	_box = _measure_box(target)
	## Round to whole pixels — the arena renders at 640x360 and a sub-pixel bracket shimmers.
	global_position = target.global_position.round()
	queue_redraw()


## Half-size of the bracket box for `enemy`, in world px.
func _measure_box(enemy: Node2D) -> float:
	var sprite: Node = enemy.get("sprite")
	if sprite == null or not is_instance_valid(sprite):
		return BOX_FALLBACK
	var frame: Vector2 = _frame_size(sprite)
	if frame == Vector2.ZERO:
		return BOX_FALLBACK
	## global_scale, not scale — folds in sprite_scale plus any scaling on the body itself.
	var s: Vector2 = sprite.global_scale
	var visual: Vector2 = Vector2(frame.x * absf(s.x), frame.y * absf(s.y))
	var half: float = maxf(visual.x, visual.y) * 0.5 * SPRITE_FILL
	return clampf(half + BOX_PAD, BOX_MIN, BOX_MAX)


## Pixel size of the sprite's current frame, or ZERO if it can't be read.
func _frame_size(sprite: Node) -> Vector2:
	if sprite is AnimatedSprite2D:
		var frames: SpriteFrames = sprite.sprite_frames
		if frames == null or not frames.has_animation(sprite.animation):
			return Vector2.ZERO
		var count: int = frames.get_frame_count(sprite.animation)
		if count <= 0:
			return Vector2.ZERO
		var tex: Texture2D = frames.get_frame_texture(sprite.animation, clampi(sprite.frame, 0, count - 1))
		return tex.get_size() if tex != null else Vector2.ZERO
	if sprite is Sprite2D:
		if sprite.texture == null:
			return Vector2.ZERO
		## Region/hframes aware: a sheet-backed Sprite2D reports the whole atlas otherwise.
		if sprite.region_enabled:
			return sprite.region_rect.size
		return sprite.texture.get_size() / Vector2(maxi(sprite.hframes, 1), maxi(sprite.vframes, 1))
	return Vector2.ZERO


func _draw() -> void:
	if target == null:
		return
	var t: float = _pop / POP_TIME  ## 1 -> 0 across the pop
	var half: float = _box * (1.0 + (POP_SCALE - 1.0) * t * t)
	var arm: float = clampf(half * ARM_RATIO, ARM_MIN, ARM_MAX)
	## Four corner L's: each is a horizontal arm + a vertical arm meeting at the corner.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := Vector2(sx * half, sy * half)
			draw_line(corner, corner - Vector2(sx * arm, 0.0), COLOR_LOCK, 1.0)
			draw_line(corner, corner - Vector2(0.0, sy * arm), COLOR_LOCK, 1.0)
