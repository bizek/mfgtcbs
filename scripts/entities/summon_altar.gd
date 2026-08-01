class_name SummonAltar
extends Node2D

## SummonAltar — in-world interactable. Scene-owned, spawned by EventSpawnManager.
## Player presses E to summon a forced-elite brute. On elite death: 2x loot drop,
## guaranteed keystone, and a 25-second extraction window at the altar position.
## One-time use per descent. Do NOT modify ExtractionManager core.

const INTERACT_RADIUS: float = 48.0
const PIXEL_FONT_PATH: String = "res://assets/fonts/m5x7.ttf"
const ELITE_ENEMY_ID: String = "brute"

var _player: Node2D = null
var _used: bool = false
var _prompt_label: RichTextLabel = null
var _status_label: Label = null
var _elite_enemy: Node2D = null
var _pixel_font: Font = null


func setup(pos: Vector2, player: Node2D) -> void:
	global_position = pos
	_player = player
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		_pixel_font = load(PIXEL_FONT_PATH)
	_build_visuals()


func _build_visuals() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.04, 0.16, 0.88)
	bg.size = Vector2(22.0, 22.0)
	bg.position = Vector2(-11.0, -11.0)
	add_child(bg)

	var gem := ColorRect.new()
	gem.color = Color(0.65, 0.15, 1.0)
	gem.size = Vector2(8.0, 8.0)
	gem.position = Vector2(-4.0, -4.0)
	add_child(gem)

	var spin := gem.create_tween().set_loops()
	spin.tween_property(gem, "rotation", TAU, 2.2)

	var name_lbl := Label.new()
	name_lbl.text = "SUMMON ALTAR"
	name_lbl.position = Vector2(-38.0, -28.0)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.75, 0.35, 1.0))
	if _pixel_font:
		name_lbl.add_theme_font_override("font", _pixel_font)
	add_child(name_lbl)

	## RichTextLabel so the bound input renders as the pack's keycap/button art.
	## The old "[E] Summon" brackets are gone — the keycap sprite is the bracket.
	var prompt := GlyphBar.rich_prompt(11, Color(0.80, 0.60, 1.0))
	prompt.text = "%s Summon  (Risky)" % InputGlyphs.action_glyph_bb("interact")
	prompt.position = Vector2(-36.0, 14.0)
	prompt.visible = false
	add_child(prompt)
	_prompt_label = prompt

	var status := Label.new()
	status.text = ""
	status.position = Vector2(-36.0, 26.0)
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	status.visible = false
	if _pixel_font:
		status.add_theme_font_override("font", _pixel_font)
	add_child(status)
	_status_label = status
	InputGlyphs.device_changed.connect(_on_input_device_changed)


func _on_input_device_changed(_is_joypad: bool) -> void:
	if _prompt_label:
		_prompt_label.text = "%s Summon  (Risky)" % InputGlyphs.action_glyph_bb("interact")


func _process(_delta: float) -> void:
	if _player == null:
		return
	var dist: float = _player.global_position.distance_to(global_position)
	var in_range: bool = dist <= INTERACT_RADIUS

	if _prompt_label:
		_prompt_label.visible = in_range and not _used

	if in_range and not _used and Input.is_action_just_pressed("interact"):
		_summon()

	## Poll for elite death when we can't use a signal
	if _elite_enemy != null and not is_instance_valid(_elite_enemy):
		_elite_enemy = null
		_on_elite_killed()


func _summon() -> void:
	_used = true
	if _prompt_label:
		_prompt_label.visible = false
	if _status_label:
		_status_label.text = "Summoned..."
		_status_label.visible = true

	var offset := Vector2(randf_range(-60.0, 60.0), randf_range(-40.0, 40.0))
	var spawn_pos: Vector2 = global_position + offset

	var elite: Node2D = EnemySpawnManager.spawn_forced_elite_at(ELITE_ENEMY_ID, spawn_pos)
	_elite_enemy = elite

	if elite == null:
		_on_elite_killed()
		return

	## Connect via EventBus if a direct signal isn't available
	EventBus.on_kill.connect(_check_elite_killed)


func _check_elite_killed(killer: Node, victim: Node) -> void:
	if victim == _elite_enemy:
		if EventBus.on_kill.is_connected(_check_elite_killed):
			EventBus.on_kill.disconnect(_check_elite_killed)
		_elite_enemy = null
		_on_elite_killed()


func _on_elite_killed() -> void:
	if _status_label:
		_status_label.text = "Defeated!"

	## 2x loot drop for current phase
	var phase_vals: Array = LootTables.RESOURCE_VALUES.get(
		GameManager.phase_number, [6, 14])
	var loot_amount: float = randf_range(float(phase_vals[0]), float(phase_vals[1])) * 2.0
	GameManager.loot_carried += loot_amount
	GameManager.loot_changed.emit(GameManager.loot_carried)

	## Keystone
	GameManager.pickup_keystone()

	## 25-second extraction window
	var window := AltarExtractionZone.new()
	window.name = "AltarExtractionZone"
	get_tree().current_scene.add_child(window)
	window.setup(global_position, _player, 25.0, _pixel_font)


func _exit_tree() -> void:
	if EventBus.on_kill.is_connected(_check_elite_killed):
		EventBus.on_kill.disconnect(_check_elite_killed)


## ── AltarExtractionZone ───────────────────────────────────────────────────────
## Temporary 25-second extraction zone spawned after the elite dies.
## Player stands inside it to channel an extraction. Self-destructs on expiry.

class AltarExtractionZone extends Node2D:
	const CHANNEL_RADIUS: float = 40.0

	var _player: Node2D = null
	var _timer: float = 0.0
	var _countdown_label: Label = null
	var _was_channeling: bool = false

	func setup(pos: Vector2, player: Node2D, duration: float, font: Font) -> void:
		global_position = pos
		_player = player
		_timer = duration
		_build_visuals(font)

	func _build_visuals(font: Font) -> void:
		var fill := ColorRect.new()
		fill.color = Color(0.0, 0.88, 0.28, 0.30)
		fill.size = Vector2(80.0, 80.0)
		fill.position = Vector2(-40.0, -40.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fill)

		var pulse := fill.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		pulse.tween_property(fill, "modulate:a", 0.3, 0.65)
		pulse.tween_property(fill, "modulate:a", 1.0, 0.65)

		var lbl := Label.new()
		lbl.position = Vector2(-36.0, -58.0)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.15, 1.0, 0.5))
		if font:
			lbl.add_theme_font_override("font", font)
		add_child(lbl)
		_countdown_label = lbl

	func _process(delta: float) -> void:
		_timer -= delta
		if _countdown_label:
			_countdown_label.text = "EXTRACT  %ds" % maxi(0, int(ceilf(_timer)))

		if _timer <= 0.0:
			if ExtractionManager.is_channeling:
				ExtractionManager.interrupt_channel()
			queue_free()
			return

		if _player == null:
			return

		var dist: float = _player.global_position.distance_to(global_position)
		var in_zone: bool = dist <= CHANNEL_RADIUS

		if in_zone and not ExtractionManager.is_channeling and GameManager.is_extraction_allowed():
			GameManager.active_extraction_type = "guarded"
			ExtractionManager.channel_duration = ProgressionManager.get_channel_duration()
			ExtractionManager.start_channel(1.0)
			_was_channeling = true
		elif _was_channeling and not in_zone and ExtractionManager.is_channeling:
			ExtractionManager.interrupt_channel()
			_was_channeling = false
