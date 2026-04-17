extends Area2D

## WeaponPickup — A rare weapon drop that appears after killing enemies.
## Shows the weapon name and tint colour so the player knows what they found.
## When collected, adds the weapon to GameManager's list for this run.
## On successful extraction, GameManager unlocks it in ProgressionManager.
## If you die, you lose it — same risk as any other extractable loot.

var weapon_id: String = ""
var rarity: String = "common"  ## Set by spawner — affects instability cost and visuals

var _magnetized: bool = false
var _target: Node2D = null
var _collected: bool = false
var _age: float = 0.0
var _beam_alpha: float = 1.0
var _tint: Color = Color.WHITE

const BEAM_DURATION: float = 2.5
const MAGNET_SPEED: float = 200.0

func _ready() -> void:
	collision_layer = 16  ## pickups (layer 5, bit 4)
	collision_mask  = 1   ## player body (layer 1, bit 0)
	monitoring      = true

	## Fetch tint from weapon data (safe — data is always loaded)
	if weapon_id in WeaponData.ALL:
		_tint = WeaponData.ALL[weapon_id].get("tint", Color.WHITE)

	## Collision circle
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)

	## Floating weapon-name label above the pickup
	_build_label()

	body_entered.connect(_on_body_entered)

func _build_label() -> void:
	if weapon_id.is_empty():
		return
	var display: String = WeaponData.ALL.get(weapon_id, {}).get("display_name", weapon_id)
	var rarity_color: Color = LootTables.RARITY_COLORS.get(rarity, Color.WHITE)
	var lbl := Label.new()
	lbl.text = "[" + rarity.to_upper() + "] " + display
	lbl.position = Vector2(-52.0, -30.0)

	var settings := LabelSettings.new()
	var font = load("res://assets/fonts/m5x7.ttf")
	if font:
		settings.font      = font
		settings.font_size = 10
	settings.outline_size  = 1
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.9)
	settings.font_color    = rarity_color
	lbl.label_settings     = settings
	add_child(lbl)

func _process(delta: float) -> void:
	_age += delta

	if _age < BEAM_DURATION:
		_beam_alpha = 1.0 - (_age / BEAM_DURATION)
	else:
		_beam_alpha = 0.0

	queue_redraw()

	if _magnetized and is_instance_valid(_target):
		var dir := (_target.global_position - global_position).normalized()
		global_position += dir * MAGNET_SPEED * delta
		if global_position.distance_to(_target.global_position) < 8.0:
			_collect()

func _draw() -> void:
	## Beam of light — tinted by rarity color, brightness scales with rarity
	var rarity_color: Color = LootTables.RARITY_COLORS.get(rarity, _tint)
	var rarity_idx: float = float(["common","uncommon","rare","epic","legendary"].find(rarity))
	var beam_w: float = 2.0 + rarity_idx * 0.8
	var beam_bright: float = 0.55 + rarity_idx * 0.09
	if _beam_alpha > 0.01:
		draw_rect(
			Rect2(-beam_w, -64.0, beam_w * 2.0, 62.0),
			Color(rarity_color.r, rarity_color.g, rarity_color.b, _beam_alpha * beam_bright)
		)
		draw_rect(
			Rect2(-beam_w * 2.5, -64.0, beam_w * 5.0, 62.0),
			Color(rarity_color.r, rarity_color.g, rarity_color.b, _beam_alpha * 0.18)
		)

	## Core orb — diamond shape (two overlapping rects rotated)
	## Outer square (rotated 45° = drawn as a larger flat rect + smaller rotated rect visually)
	## We fake a diamond with two overlapping rectangles
	draw_rect(Rect2(-5.0, -5.0, 10.0, 10.0), _tint)
	draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), Color(1.0, 1.0, 1.0, 0.88))

	## Tiny cross spark at center
	draw_rect(Rect2(-1.0, -4.0, 2.0, 8.0), Color(1.0, 1.0, 1.0, 0.65))
	draw_rect(Rect2(-4.0, -1.0, 8.0, 2.0), Color(1.0, 1.0, 1.0, 0.65))

## Called by player's PickupCollector Area2D when this enters pickup radius
func start_magnet(target: Node2D) -> void:
	_magnetized = true
	_target = target

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_collect()

func _collect() -> void:
	if _collected or weapon_id.is_empty():
		return
	_collected = true
	GameManager.add_collected_weapon(weapon_id, rarity)
	queue_free()
