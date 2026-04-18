extends Area2D

## ModPickup — A mod found during a run.
## On collection:
##   • If the player's current weapon has an open mod slot → auto-equip immediately.
##   • Otherwise → goes into the loot bag (GameManager.add_collected_mod), contributes
##     15 instability, and is unlocked in ProgressionManager on successful extraction.
## Visual: purple-tinted beam + hexagonal orb to distinguish from weapon/loot drops.

var mod_id: String = ""
var rarity: String = "common"  ## Set by spawner — affects instability cost and visuals

var _magnetized: bool = false
var _target: Node2D = null
var _collected: bool = false
var _age: float = 0.0
var _beam_alpha: float = 1.0
var _tint: Color = Color(0.72, 0.30, 1.0)  ## Default purple

const BEAM_DURATION: float = 2.5
const MAGNET_SPEED: float = 200.0

func _ready() -> void:
	collision_layer = 16  ## pickups layer (bit 4)
	collision_mask  = 1   ## player body (bit 0)
	monitoring      = true

	## Resolve tint from mod data
	if ModData.ALL.has(mod_id):
		_tint = ModData.ALL[mod_id].get("color", _tint)

	## Collision circle
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)

	_build_label()
	body_entered.connect(_on_body_entered)

func _build_label() -> void:
	if mod_id.is_empty():
		return
	var display: String = ModData.ALL.get(mod_id, {}).get("name", mod_id)
	var rarity_color: Color = LootTables.RARITY_COLORS.get(rarity, Color.WHITE)
	var lbl := Label.new()
	lbl.text = "[" + rarity.to_upper() + "] " + display
	lbl.position = Vector2(-60.0, -30.0)

	var settings := LabelSettings.new()
	var font = load("res://assets/fonts/m5x7.ttf")
	if font:
		settings.font      = font
		settings.font_size = 13
	settings.outline_size  = 1
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.9)
	settings.font_color    = rarity_color
	lbl.label_settings     = settings
	add_child(lbl)

func _process(delta: float) -> void:
	_age += delta
	_beam_alpha = maxf(1.0 - (_age / BEAM_DURATION), 0.0)
	queue_redraw()

	if _magnetized and is_instance_valid(_target):
		var dir := (_target.global_position - global_position).normalized()
		global_position += dir * MAGNET_SPEED * delta
		if global_position.distance_to(_target.global_position) < 8.0:
			_collect()

func _draw() -> void:
	## Vertical beam of light — tinted by rarity color, brightness scales with rarity
	var rarity_color: Color = LootTables.RARITY_COLORS.get(rarity, Color.WHITE)
	var beam_w: float = 2.0 + float(["common","uncommon","rare","epic","legendary"].find(rarity)) * 0.8
	var beam_bright: float = 0.55 + float(["common","uncommon","rare","epic","legendary"].find(rarity)) * 0.09
	if _beam_alpha > 0.01:
		draw_rect(
			Rect2(-beam_w, -64.0, beam_w * 2.0, 62.0),
			Color(rarity_color.r, rarity_color.g, rarity_color.b, _beam_alpha * beam_bright)
		)
		draw_rect(
			Rect2(-beam_w * 2.5, -64.0, beam_w * 5.0, 62.0),
			Color(rarity_color.r, rarity_color.g, rarity_color.b, _beam_alpha * 0.18)
		)

	## Hexagonal core orb (cross + diamond shape)
	draw_rect(Rect2(-5.0, -3.0, 10.0, 6.0), _tint)
	draw_rect(Rect2(-3.0, -5.0, 6.0, 10.0), _tint)
	draw_rect(Rect2(-2.5, -2.5, 5.0, 5.0), Color(_tint.r * 0.6, _tint.g * 0.6, _tint.b * 0.6))
	## Bright center
	draw_rect(Rect2(-1.5, -1.5, 3.0, 3.0), Color(1.0, 1.0, 1.0, 0.92))
	## Spark cross
	draw_rect(Rect2(-1.0, -5.0, 2.0, 10.0), Color(1.0, 1.0, 1.0, 0.55))
	draw_rect(Rect2(-5.0, -1.0, 10.0, 2.0), Color(1.0, 1.0, 1.0, 0.55))

## Called by player's PickupCollector Area2D when this enters pickup radius
func start_magnet(target: Node2D) -> void:
	_magnetized = true
	_target = target

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_collect()

func _collect() -> void:
	if _collected or mod_id.is_empty():
		return
	_collected = true

	## Try to auto-equip into an open weapon slot on the player's current weapon
	if _try_auto_equip():
		queue_free()
		return

	## No open slot — goes into the loot bag (extractable)
	GameManager.add_collected_mod(mod_id, rarity)
	var mod_name: String = ModData.ALL.get(mod_id, {}).get("name", mod_id)
	var rarity_color: Color = LootTables.RARITY_COLORS.get(rarity, Color(0.85, 0.55, 1.0))
	_show_notification("BAGGED: " + mod_name, rarity_color)
	queue_free()

func _try_auto_equip() -> bool:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return false
	if not player.has_method("get_active_weapon_id"):
		return false

	var weapon_id: String = player.get_active_weapon_id()
	if weapon_id.is_empty():
		return false

	var weapon_data: Dictionary = WeaponData.ALL.get(weapon_id, {})
	var max_slots: int = weapon_data.get("mod_slots", 1)
	var current_mods: Array = ProgressionManager.get_weapon_mods(weapon_id)

	## Find first empty slot
	for i in range(max_slots):
		var existing: String = current_mods[i] if i < current_mods.size() else ""
		if existing.is_empty():
			## Equip to in-memory state (so reload_mods() picks it up) but do NOT save to disk.
			## GameManager tracks it for rollback on death / commit on extraction.
			if not ProgressionManager.weapon_mods.has(weapon_id):
				ProgressionManager.weapon_mods[weapon_id] = []
			while ProgressionManager.weapon_mods[weapon_id].size() <= i:
				ProgressionManager.weapon_mods[weapon_id].append("")
			ProgressionManager.weapon_mods[weapon_id][i] = mod_id
			GameManager.equip_mod_mid_run(weapon_id, i, mod_id)

			## Tell the player to reload its mod set immediately
			if player.has_method("reload_mods"):
				player.reload_mods()

			var mod_name: String = ModData.ALL.get(mod_id, {}).get("name", mod_id)
			_show_notification("MOD EQUIPPED: " + mod_name, ModData.ALL.get(mod_id, {}).get("color", _tint))
			return true

	return false

func _show_notification(msg: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.top_level = true
	lbl.global_position = global_position + Vector2(-60.0, -44.0)

	var settings := LabelSettings.new()
	var font = load("res://assets/fonts/m5x7.ttf")
	if font:
		settings.font      = font
		settings.font_size = 15
	settings.outline_size  = 1
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.9)
	settings.font_color    = col
	lbl.label_settings     = settings

	get_tree().current_scene.add_child(lbl)
	var t := lbl.create_tween()
	t.tween_property(lbl, "global_position:y", lbl.global_position.y - 22.0, 1.4)
	t.parallel().tween_property(lbl, "modulate:a", 0.0, 1.4)
	t.tween_callback(lbl.queue_free)
