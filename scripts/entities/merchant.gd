class_name Merchant
extends Node2D

## Merchant — in-world vendor entity. Scene-owned, spawned by EventSpawnManager.
## Player approaches within 48px, presses E to open the MerchantShop UI.
## Persists for the entire descent.

const INTERACT_RADIUS: float = 48.0
const PIXEL_FONT_PATH: String = "res://assets/fonts/m5x7.ttf"

var _player: Node2D = null
var _prompt_label: RichTextLabel = null
var _shop_open: bool = false
var _shop_layer: CanvasLayer = null
var _pixel_font: Font = null


func setup(pos: Vector2, player: Node2D) -> void:
	global_position = pos
	_player = player
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		_pixel_font = load(PIXEL_FONT_PATH)
	_build_visuals()


func _build_visuals() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.10, 0.02, 0.90)
	bg.size = Vector2(22.0, 22.0)
	bg.position = Vector2(-11.0, -11.0)
	add_child(bg)

	var gem := ColorRect.new()
	gem.color = Color(0.95, 0.80, 0.10)
	gem.size = Vector2(8.0, 8.0)
	gem.position = Vector2(-4.0, -4.0)
	add_child(gem)

	var spin := gem.create_tween().set_loops()
	spin.tween_property(gem, "rotation", TAU, 2.0)

	var name_lbl := Label.new()
	name_lbl.text = "MERCHANT"
	## Self-centring: a fixed negative x offset assumes a text width, so it drifts the moment
	## the font size or the item name changes. Width + CENTER holds at any size.
	name_lbl.size = Vector2(120.0, 0.0)
	name_lbl.position = Vector2(-60.0, -28.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22))
	add_child(name_lbl)

	## RichTextLabel so the bound input renders as the pack's keycap/button art.
	## The old "[Q] Trade" brackets are gone — the keycap sprite is the bracket.
	var prompt := GlyphBar.rich_prompt(11, Color(0.85, 0.85, 0.70))
	prompt.text = "%s Trade" % InputGlyphs.action_glyph_bb("interact")
	prompt.size = Vector2(120.0, 0.0)
	prompt.position = Vector2(-60.0, 14.0)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.visible = false
	add_child(prompt)
	_prompt_label = prompt
	InputGlyphs.device_changed.connect(_on_input_device_changed)


func _on_input_device_changed(_is_joypad: bool) -> void:
	if _prompt_label:
		_prompt_label.text = "%s Trade" % InputGlyphs.action_glyph_bb("interact")


func _process(_delta: float) -> void:
	if _player == null or _shop_open:
		return
	var dist: float = _player.global_position.distance_to(global_position)
	var in_range: bool = dist <= INTERACT_RADIUS
	if _prompt_label:
		_prompt_label.visible = in_range
	if in_range and Input.is_action_just_pressed("interact"):
		_open_shop()


func _open_shop() -> void:
	if _shop_open:
		return
	_shop_open = true
	GameManager.set_paused(true)

	_shop_layer = CanvasLayer.new()
	_shop_layer.layer = 60
	_shop_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(_shop_layer)

	var shop := MerchantShop.new()
	shop.process_mode = Node.PROCESS_MODE_ALWAYS
	shop.closed.connect(_on_shop_closed)
	_shop_layer.add_child(shop)
	shop.build()


func _on_shop_closed() -> void:
	_shop_open = false
	GameManager.set_paused(false)
	if _shop_layer:
		_shop_layer.queue_free()
		_shop_layer = null
