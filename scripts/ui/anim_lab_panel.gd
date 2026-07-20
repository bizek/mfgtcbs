extends CanvasLayer

## AnimLabPanel — Ben's animation workbench (F10, debug mode only).
##
## Pick any of the current character's animations, scrub which SHEET COLUMNS play (from/to),
## retime it (fps), and re-pin the choreography hit_frame — live, in-game. Apply saves to
## res://data/anim_overrides.json and rebuilds the player's SpriteFrames + kit on the spot,
## so the next swing uses the new slice. CharacterSpriteFactory applies the same overrides on
## every future load (they persist across runs; exported builds read the file too).
##
## from/to are inclusive column indices into the sheet (0-based). hit_frame is an index into
## the TRIMMED animation (-1 = keep whatever the kit code authored).

var player_ref: Node2D = null

var _panel: PanelContainer = null
var _anim_select: OptionButton = null
var _preview: AnimatedSprite2D = null
var _frame_label: Label = null
var _info_label: Label = null
var _from_spin: SpinBox = null
var _to_spin: SpinBox = null
var _fps_spin: SpinBox = null
var _hit_spin: SpinBox = null
var _status_label: Label = null

var _char_id: String = ""
var _sheet_cols: int = 0        ## columns available on the selected anim's sheet
var _default_count: int = 0     ## frame_count from the data table
var _default_fps: float = 10.0


func _ready() -> void:
	layer = 127
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()


func setup(player: Node2D) -> void:
	player_ref = player
	_char_id = ProgressionManager.selected_character
	_populate_anims()


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.debug_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		_panel.visible = not _panel.visible
		if _panel.visible:
			_reload_selected()


func _process(_delta: float) -> void:
	if _panel.visible and _preview and _preview.sprite_frames and _frame_label:
		var total: int = _preview.sprite_frames.get_frame_count(_preview.animation)
		_frame_label.text = "frame %d / %d" % [_preview.frame, total - 1]


# ─── Panel construction ───────────────────────────────────────────────────────

func _build_panel() -> void:
	var pc := PanelContainer.new()
	pc.position = Vector2(475.0, 45.0)
	pc.visible = false
	_panel = pc
	add_child(pc)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.04, 0.08, 0.93)
	bg.set_corner_radius_all(3)
	bg.set_content_margin_all(5.0)
	pc.add_theme_stylebox_override("panel", bg)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	pc.add_child(v)

	v.add_child(_label("ANIMATION LAB  (F10)", 10, Color(1.0, 0.85, 0.3)))

	_anim_select = OptionButton.new()
	_anim_select.custom_minimum_size = Vector2(150.0, 14.0)
	_anim_select.add_theme_font_size_override("font_size", 9)
	_anim_select.item_selected.connect(func(_i: int) -> void: _reload_selected())
	v.add_child(_anim_select)

	## Preview box: dark backdrop, sprite at 2x.
	var box := Panel.new()
	box.custom_minimum_size = Vector2(150.0, 76.0)
	var box_bg := StyleBoxFlat.new()
	box_bg.bg_color = Color(0.10, 0.10, 0.14, 1.0)
	box_bg.set_corner_radius_all(2)
	box.add_theme_stylebox_override("panel", box_bg)
	v.add_child(box)
	_preview = AnimatedSprite2D.new()
	_preview.position = Vector2(75.0, 40.0)
	_preview.scale = Vector2(2.0, 2.0)
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(_preview)

	_frame_label = _label("frame 0 / 0", 9, Color(0.8, 0.8, 0.85))
	v.add_child(_frame_label)
	_info_label = _label("", 9, Color(0.6, 0.65, 0.7))
	v.add_child(_info_label)

	_from_spin = _spin_row(v, "From col", 0)
	_to_spin = _spin_row(v, "To col", 0)
	_fps_spin = _spin_row(v, "FPS", 10, 1.0, 60.0, 0.5)
	_hit_spin = _spin_row(v, "Hit frame", -1, -1.0, 63.0, 1.0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	row.add_child(_button("REPLAY", _replay_preview))
	row.add_child(_button("APPLY+SAVE", _apply_and_save))
	row.add_child(_button("CLEAR", _clear_override))

	_status_label = _label("", 9, Color(0.5, 0.9, 0.5))
	v.add_child(_status_label)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
		l.add_theme_font_override("font", load("res://assets/fonts/m5x7.ttf"))
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 9)
	b.pressed.connect(cb)
	return b


func _spin_row(parent: VBoxContainer, label_text: String, value: float,
		min_v: float = 0.0, max_v: float = 63.0, step: float = 1.0) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var l := _label(label_text, 9, Color(0.85, 0.85, 0.9))
	l.custom_minimum_size = Vector2(56.0, 0.0)
	row.add_child(l)
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(70.0, 13.0)
	s.add_theme_font_size_override("font_size", 9)
	s.value_changed.connect(func(_v: float) -> void: _replay_preview())
	row.add_child(s)
	return s


# ─── Behavior ─────────────────────────────────────────────────────────────────

func _populate_anims() -> void:
	_anim_select.clear()
	var anims: Dictionary = CharacterData.ALL.get(_char_id, {}).get("sprite", {}).get("anims", {})
	var names: Array = anims.keys()
	names.sort()
	for n in names:
		_anim_select.add_item(str(n))
	if _anim_select.item_count > 0:
		_anim_select.select(0)
		_reload_selected()


func _selected_anim() -> String:
	if _anim_select.item_count == 0:
		return ""
	return _anim_select.get_item_text(_anim_select.selected)


## Refresh spinboxes + preview from the data table and any saved override.
func _reload_selected() -> void:
	var anim: String = _selected_anim()
	if anim == "":
		return
	var meta: Dictionary = CharacterData.ALL.get(_char_id, {}).get("sprite", {})
	var spec: Array = meta.get("anims", {}).get(anim, [])
	if spec.size() < 3:
		return
	var frame_size: int = int(meta.get("frame_size", 32))
	var raw_sheet: String = str(spec[0])
	var path: String = raw_sheet if raw_sheet.begins_with("res://") else str(meta.get("dir", "")) + raw_sheet
	_default_count = int(spec[1])
	_default_fps = float(spec[2])
	_sheet_cols = 0
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex:
			_sheet_cols = int(tex.get_width() / float(frame_size))
	var ov: Dictionary = CharacterSpriteFactory.get_anim_override(_char_id, anim)
	_from_spin.set_value_no_signal(float(ov.get("from", 0)))
	_to_spin.set_value_no_signal(float(ov.get("to", _default_count - 1)))
	_fps_spin.set_value_no_signal(float(ov.get("fps", _default_fps)))
	_hit_spin.set_value_no_signal(float(ov.get("hit_frame", -1)))
	_info_label.text = "sheet: %d cols · table: %d fr @ %.0f fps%s" % [
			_sheet_cols, _default_count, _default_fps, "  [OVERRIDDEN]" if not ov.is_empty() else ""]
	_replay_preview()


## Rebuild the preview slice from the CURRENT spinbox values (unsaved — pure preview).
func _replay_preview() -> void:
	var anim: String = _selected_anim()
	if anim == "" or _sheet_cols <= 0:
		return
	var meta: Dictionary = CharacterData.ALL.get(_char_id, {}).get("sprite", {})
	var spec: Array = meta.get("anims", {}).get(anim, [])
	if spec.size() < 3:
		return
	var frame_size: int = int(meta.get("frame_size", 32))
	var raw_sheet: String = str(spec[0])
	var path: String = raw_sheet if raw_sheet.begins_with("res://") else str(meta.get("dir", "")) + raw_sheet
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if tex == null:
		return
	var first: int = clampi(int(_from_spin.value), 0, _sheet_cols - 1)
	var last: int = clampi(int(_to_spin.value), first, _sheet_cols - 1)
	var frames := SpriteFrames.new()
	frames.clear_all()
	frames.add_animation(&"lab")
	frames.set_animation_loop(&"lab", true)
	frames.set_animation_speed(&"lab", maxf(_fps_spin.value, 1.0))
	## Preview the front-right row (row 0 per the facing contract); single-row sheets use row 0 anyway.
	for i in range(first, last + 1):
		var cell := AtlasTexture.new()
		cell.atlas = tex
		cell.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		cell.filter_clip = true
		frames.add_frame(&"lab", cell)
	_preview.sprite_frames = frames
	_preview.play(&"lab")


func _apply_and_save() -> void:
	var anim: String = _selected_anim()
	if anim == "":
		return
	var data: Dictionary = {
		"from": int(_from_spin.value),
		"to": int(_to_spin.value),
		"fps": _fps_spin.value,
	}
	if int(_hit_spin.value) >= 0:
		data["hit_frame"] = int(_hit_spin.value)
	## Drop entries that match the table defaults so the file only stores real changes.
	if data["from"] == 0 and data["to"] == _default_count - 1 \
			and is_equal_approx(data["fps"], _default_fps) and not data.has("hit_frame"):
		_clear_override()
		return
	if CharacterSpriteFactory.save_anim_override(_char_id, anim, data):
		_rebuild_player()
		_status_label.text = "saved + applied: " + anim
	else:
		_status_label.text = "SAVE FAILED (file not writable)"


func _clear_override() -> void:
	var anim: String = _selected_anim()
	if anim == "":
		return
	CharacterSpriteFactory.save_anim_override(_char_id, anim, {})
	_rebuild_player()
	_reload_selected()
	_status_label.text = "override cleared: " + anim


## Rebuild the live player: fresh SpriteFrames (picks up slice overrides) + fresh kit
## (picks up hit_frame overrides).
func _rebuild_player() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	if player_ref.has_method("_apply_character_sprite"):
		player_ref._apply_character_sprite()
	if player_ref.has_method("_load_combo"):
		player_ref._load_combo()
