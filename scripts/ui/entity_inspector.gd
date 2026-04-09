extends CanvasLayer

## EntityInspector — Click-to-inspect debug overlay for combat entities.
## Click any entity during combat to see its stats, statuses, modifiers, abilities.
## Click empty space or press ESC to deselect. Toggle with F5.
##
## Added as a child of MainArena when debug_mode is true.

const CLICK_RADIUS_SQ: float = 256.0  ## 16px click radius squared
const PANEL_WIDTH: float = 175.0
const PANEL_HEIGHT: float = 200.0
const LINE_HEIGHT: float = 8.0
const FONT_SIZE: int = 7
const HEADER_SIZE: int = 8

var _target: Node2D = null
var _visible: bool = true
var _panel: Control = null
var _scroll_offset: float = 0.0


func _ready() -> void:
	layer = 126
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()


func _build_panel() -> void:
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	_panel.draw.connect(_on_draw)


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.debug_mode:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			_visible = not _visible
			if not _visible:
				_target = null
			_panel.queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and _target != null:
			_target = null
			_panel.queue_redraw()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _visible:
			return
		_select_entity_at_mouse()
		_scroll_offset = 0.0
		_panel.queue_redraw()

	if event is InputEventMouseButton and _target != null:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_offset = maxf(_scroll_offset - LINE_HEIGHT * 3, 0.0)
			_panel.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_offset += LINE_HEIGHT * 3
			_panel.queue_redraw()


func _process(_delta: float) -> void:
	if _target != null:
		if not is_instance_valid(_target):
			_target = null
		_panel.queue_redraw()


func _select_entity_at_mouse() -> void:
	## Convert mouse position to game world coordinates and find nearest entity.
	var game_pos: Vector2 = _get_game_mouse_pos()
	var best: Node2D = null
	var best_dist_sq: float = CLICK_RADIUS_SQ

	# Check all entities
	for entity in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(entity):
			continue
		var d_sq: float = game_pos.distance_squared_to(entity.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = entity

	var player := get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var d_sq: float = game_pos.distance_squared_to(player.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = player

	_target = best


func _get_game_mouse_pos() -> Vector2:
	## Get mouse position in game world coordinates.
	var viewport := get_viewport()
	var canvas_xform := viewport.get_canvas_transform()
	var mouse_screen := viewport.get_mouse_position()
	return canvas_xform.affine_inverse() * mouse_screen


func _on_draw() -> void:
	if not _visible or _target == null or not is_instance_valid(_target):
		return

	var lines: Array = _build_info_lines()

	# Position panel near entity (in screen space)
	var viewport := get_viewport()
	var canvas_xform := viewport.get_canvas_transform()
	var entity_screen: Vector2 = canvas_xform * _target.global_position
	# Scale factor from game to screen
	var scale_factor: float = canvas_xform.x.x  # Uniform scale
	var panel_w: float = PANEL_WIDTH * scale_factor
	var panel_h: float = minf(PANEL_HEIGHT * scale_factor, (lines.size() + 2) * LINE_HEIGHT * scale_factor)
	var screen_size: Vector2 = viewport.get_visible_rect().size

	# Position to the right of entity, clamped to screen
	var panel_x: float = entity_screen.x + 20.0 * scale_factor
	var panel_y: float = entity_screen.y - panel_h * 0.3
	if panel_x + panel_w > screen_size.x:
		panel_x = entity_screen.x - panel_w - 20.0 * scale_factor
	panel_x = clampf(panel_x, 4.0, screen_size.x - panel_w - 4.0)
	panel_y = clampf(panel_y, 4.0, screen_size.y - panel_h - 4.0)

	var font: Font = ThemeDB.fallback_font
	var fs: float = FONT_SIZE * scale_factor
	var hs: float = HEADER_SIZE * scale_factor
	var lh: float = LINE_HEIGHT * scale_factor

	# Background
	var bg_rect := Rect2(panel_x, panel_y, panel_w, panel_h)
	_panel.draw_rect(bg_rect, Color(0.02, 0.02, 0.06, 0.92))
	_panel.draw_rect(bg_rect, Color(0.4, 0.4, 0.6, 0.5), false, 1.0)

	# Selection indicator ring (in game space via CanvasLayer — we draw in screen space)
	var ring_radius: float = 12.0 * scale_factor
	_panel.draw_arc(entity_screen, ring_radius, 0.0, TAU, 24, Color(1.0, 0.9, 0.2, 0.7), 1.5)

	# Draw lines with scroll
	var y: float = panel_y + lh
	var clip_top: float = panel_y
	var clip_bottom: float = panel_y + panel_h - lh * 0.5
	var line_idx: int = 0
	for line_data in lines:
		var draw_y: float = y - _scroll_offset * scale_factor
		if draw_y >= clip_top and draw_y <= clip_bottom:
			var text: String = line_data[0]
			var color: Color = line_data[1]
			var size: float = hs if line_data[2] else fs
			_panel.draw_string(font, Vector2(panel_x + 4.0 * scale_factor, draw_y), text, HORIZONTAL_ALIGNMENT_LEFT, panel_w - 8.0 * scale_factor, size, color)
		y += lh
		line_idx += 1


func _build_info_lines() -> Array:
	## Returns Array of [text: String, color: Color, is_header: bool]
	var lines: Array = []
	var entity := _target
	var white := Color(0.9, 0.9, 0.9)
	var gray := Color(0.6, 0.6, 0.6)
	var yellow := Color(1.0, 0.85, 0.2)
	var green := Color(0.4, 1.0, 0.4)
	var red := Color(1.0, 0.4, 0.4)
	var cyan := Color(0.4, 0.9, 1.0)
	var purple := Color(0.8, 0.5, 1.0)

	# Identity
	var name_str: String = ""
	if entity.get("_enemy_def") and entity._enemy_def:
		name_str = entity._enemy_def.enemy_name
	elif entity.get("entity_id"):
		name_str = entity.entity_id
	elif entity.is_in_group("player"):
		name_str = "Player"
	else:
		name_str = entity.name
	var faction_str: String = "PLAYER" if int(entity.faction) == 0 else "ENEMY"
	var role_str: String = entity.combat_role if entity.get("combat_role") else ""
	var elite_str: String = " [ELITE]" if entity.get("is_elite") and entity.is_elite else ""
	lines.append([name_str + elite_str, yellow, true])
	lines.append([faction_str + "  " + role_str, gray, false])

	# HP
	if entity.get("health") and entity.health:
		var hp_str: String = "HP: %.0f / %.0f" % [entity.health.current_hp, entity.health.max_hp]
		var hp_color: Color = green if entity.health.current_hp / entity.health.max_hp > 0.5 else red
		lines.append([hp_str, hp_color, false])
		if entity.health.shield_hp > 0.0:
			lines.append(["Shield: %.0f" % entity.health.shield_hp, cyan, false])

	# Stats
	lines.append(["", white, false])
	lines.append(["-- Stats --", yellow, true])
	if entity.get("contact_damage"):
		lines.append(["Contact Dmg: %.1f" % entity.contact_damage, white, false])
	if entity.get("base_move_speed"):
		lines.append(["Move Speed: %.1f" % entity.base_move_speed, white, false])
	if entity.get("modifier_component"):
		var armor: float = entity.modifier_component.sum_modifiers("Physical", "resist")
		if armor > 0.0:
			lines.append(["Armor: %.1f" % armor, white, false])
		var dmg_bonus: float = entity.modifier_component.sum_modifiers("All", "bonus")
		if dmg_bonus != 0.0:
			lines.append(["Dmg Bonus: %+.0f%%" % (dmg_bonus * 100.0), white, false])
		var speed_bonus: float = entity.modifier_component.sum_modifiers("move_speed", "bonus")
		if speed_bonus != 0.0:
			lines.append(["Speed Bonus: %+.0f%%" % (speed_bonus * 100.0), white, false])

	# Behavior state
	if entity.get("behavior_component") and entity.behavior_component:
		lines.append(["", white, false])
		lines.append(["-- Behavior --", yellow, true])
		var bc = entity.behavior_component
		var aa_timer: String = "%.1fs" % bc.auto_attack_timer
		var aa_interval: String = "%.2fs" % bc._get_effective_aa_interval()
		lines.append(["AA Timer: %s / %s" % [aa_timer, aa_interval], white, false])
		if entity.get("attack_target") and is_instance_valid(entity.attack_target):
			var target_name: String = entity.attack_target.name
			lines.append(["Target: " + target_name, gray, false])
		if entity.get("_behavior_type"):
			lines.append(["Behavior: " + entity._behavior_type, gray, false])

	# Abilities
	if entity.get("ability_component") and entity.ability_component:
		var ac = entity.ability_component
		var aa = ac.get_auto_attack()
		var slots = ac.get_display_slots()
		if aa or not slots.is_empty():
			lines.append(["", white, false])
			lines.append(["-- Abilities --", yellow, true])
			if aa:
				lines.append(["AA: " + aa.ability_name, cyan, false])
			for slot in slots:
				var cd_str: String = "ready" if slot.cooldown_remaining <= 0.0 else "%.1fs" % slot.cooldown_remaining
				var held_str: String = " [HELD]" if slot.is_held else ""
				lines.append(["  " + slot.definition.ability_name + ": " + cd_str + held_str, white, false])

	# Active statuses
	if entity.get("status_effect_component") and entity.status_effect_component:
		var sec = entity.status_effect_component
		var active_dict = sec.get("_active")
		if active_dict and not active_dict.is_empty():
			lines.append(["", white, false])
			lines.append(["-- Statuses --", yellow, true])
			for status_id in active_dict:
				var active = active_dict[status_id]
				var stacks: int = active.stacks if active.get("stacks") else 1
				var time_str: String
				if active.get("time_remaining") != null:
					if active.time_remaining < 0.0:
						time_str = "perm"
					else:
						time_str = "%.1fs" % active.time_remaining
				else:
					time_str = "?"
				var status_color: Color = green if active.definition.is_positive else red
				var stack_str: String = " x%d" % stacks if stacks > 1 else ""
				lines.append(["  %s%s  (%s)" % [status_id, stack_str, time_str], status_color, false])

	# Active modifiers
	if entity.get("modifier_component") and entity.modifier_component:
		var mc = entity.modifier_component
		if mc.has_method("get_all_modifiers"):
			var mods: Array = mc.get_all_modifiers()
			if not mods.is_empty():
				lines.append(["", white, false])
				lines.append(["-- Modifiers --", yellow, true])
				for mod in mods:
					var src: String = mod.source_name if mod.source_name != "" else "?"
					lines.append(["  %s: %s %s %.2f" % [src, mod.target_tag, mod.operation, mod.value], purple, false])

	# Trigger listeners
	if entity.get("trigger_component") and entity.trigger_component:
		var tc = entity.trigger_component
		var listeners = tc.get("_listeners")
		if listeners and not listeners.is_empty():
			lines.append(["", white, false])
			lines.append(["-- Triggers --", yellow, true])
			for event_name in listeners:
				var count: int = listeners[event_name].size()
				lines.append(["  %s: %d listeners" % [event_name, count], gray, false])

	return lines
