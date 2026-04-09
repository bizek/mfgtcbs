extends Area2D

## KeystonePickup — Rare key that unlocks the Locked Extraction point.
## Guaranteed drop from the first guardian kill per phase.
## 5% chance from elite kills (spawned by main_arena._on_entity_killed).
## Collecting sets GameManager.player_has_keystone = true.

const PIXEL_FONT_PATH: String = "res://assets/fonts/m5x7.ttf"

func _ready() -> void:
	collision_layer = 16  ## pickups layer (bit 4 = layer 5)
	collision_mask = 1   ## detect player body

	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 22)
	cs.shape = rect
	add_child(cs)

	_build_visuals()
	body_entered.connect(_on_body_entered)

func _build_visuals() -> void:
	## Tall light beam — visible from across the arena
	var beam := ColorRect.new()
	beam.color = Color(1.0, 0.85, 0.10, 0.20)
	beam.size = Vector2(18, 420)
	beam.position = Vector2(-9, -420)
	add_child(beam)

	## Outer halo ring
	var halo := ColorRect.new()
	halo.color = Color(1.0, 0.82, 0.08, 0.32)
	halo.size = Vector2(30, 30)
	halo.position = Vector2(-15, -15)
	add_child(halo)

	## Main gem body (gold)
	var gem := ColorRect.new()
	gem.color = Color(1.0, 0.88, 0.10)
	gem.size = Vector2(14, 14)
	gem.position = Vector2(-7, -7)
	add_child(gem)

	## Bright core
	var core := ColorRect.new()
	core.color = Color(1.0, 1.0, 0.92)
	core.size = Vector2(6, 6)
	core.position = Vector2(-3, -3)
	add_child(core)

	## "KEYSTONE" label above gem
	var lbl := Label.new()
	lbl.text = "KEYSTONE"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-40, -30)
	lbl.modulate = Color(1.0, 0.88, 0.18)
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		var ls := LabelSettings.new()
		ls.font = load(PIXEL_FONT_PATH)
		ls.font_size = 10
		ls.outline_size = 1
		ls.outline_color = Color(0.0, 0.0, 0.0, 0.9)
		lbl.label_settings = ls
	else:
		lbl.add_theme_font_size_override("font_size", 10)
	add_child(lbl)

	## Gem spin
	var spin := create_tween().set_loops()
	spin.tween_property(gem, "rotation", TAU, 2.2)

	## Halo pulse
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulse.tween_property(halo, "modulate:a", 0.18, 0.55)
	pulse.tween_property(halo, "modulate:a", 1.0, 0.55)

	## Beam pulse (slower)
	var bpulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	bpulse.tween_property(beam, "modulate:a", 0.25, 1.6)
	bpulse.tween_property(beam, "modulate:a", 1.0, 1.6)

	## Bob up/down
	var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	bob.tween_property(self, "position:y", position.y - 4.0, 0.7)
	bob.tween_property(self, "position:y", position.y, 0.7)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.pickup_keystone()
		queue_free()
