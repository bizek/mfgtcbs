class_name MerchantShop
extends Control

## MerchantShop — modal shop UI opened by Merchant when player presses E.
## Offers random weapons, mods, keystone, and a stability bundle.
## Purchases deduct from GameManager.loot_carried via spend_loot().

signal closed

const PIXEL_FONT_PATH: String = "res://assets/fonts/m5x7.ttf"
const PANEL_W: float = 380.0
const PANEL_H: float = 300.0
const VW: float = 640.0
const VH: float = 360.0

const WEAPON_PRICE: int = 12
## Mods are priced by rarity as of 2026-08-10. This was a flat 8 for all 96, which made the
## shelf a coin-flip rather than a choice — an epic and a +10% modifier cost the same.
## Anchored so the mean sits near the old flat 8, and so an epic mod reads as roughly a
## weapon-and-a-half without touching the town portal's 25 (the run's biggest decision).
const MOD_PRICE_BY_RARITY: Dictionary = { "uncommon": 6, "rare": 10, "epic": 16 }
const MOD_PRICE: int = 8   ## fallback only, for an id with no rarity

static func mod_price(mod_id: String) -> int:
	return int(MOD_PRICE_BY_RARITY.get(ClassModData.rarity_of(mod_id), MOD_PRICE))
const KEYSTONE_PRICE: int = 20
const STABILITY_PRICE: int = 15
const STABILITY_REDUCTION: int = 20
## The most expensive thing on the shelf, on purpose. It is bought with loot_carried — the haul
## you are trying to get out with — so the price IS the decision: you give up a slice of the run
## to guarantee you keep the rest. Cheap enough to be reachable by the merchant block (~50% depth),
## dear enough that taking it means skipping a weapon and a mod.
const TOWN_PORTAL_PRICE: int = 25

var _pixel_font: Font = null
var _loot_counter: Label = null


func build() -> void:
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		_pixel_font = load(PIXEL_FONT_PATH)

	var offers: Array[Dictionary] = _generate_offers()
	_build_ui(offers)
	UINav.focus_first(self)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		AudioManager.play_ui("sfx_ui_cancel")
		closed.emit()
		get_viewport().set_input_as_handled()


func _generate_offers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	## 2 random weapons (exclude already-collected)
	var weapon_ids: Array = WeaponData.ALL.keys()
	weapon_ids.shuffle()
	var weapons_added: int = 0
	for wid: String in weapon_ids:
		if weapons_added >= 2:
			break
		var wd: Dictionary = WeaponData.ALL[wid]
		result.append({
			"type": "weapon",
			"id": wid,
			"display": str(wd.get("display_name", wid)),
			"price": WEAPON_PRICE,
			"color": Color(0.80, 0.75, 0.55),
			"sold": false,
		})
		weapons_added += 1

	## 2 random mods from the CURRENT character's roster (2026-08-08). The merchant used to draw
	## from ModData.ALL, which meant most of its stock was either inapplicable or — as it turned
	## out — inert. Drawing from droppable_pool means everything on the shelf is usable by the
	## character standing in front of it.
	var mod_ids: Array = ModApplicability.droppable_pool(ProgressionManager.selected_character)
	mod_ids.shuffle()
	var mods_added: int = 0
	for mid: String in mod_ids:
		if mods_added >= 2:
			break
		var md: Dictionary = ModApplicability.get_mod(mid)
		var mrar: String = ClassModData.rarity_of(mid)
		result.append({
			"type": "mod",
			"id": mid,
			"display": str(md.get("name", mid)),
			"price": mod_price(mid),
			## Rarity colour, so the shelf reads at a glance instead of every mod being the
			## same blue. Same palette the pickups and the haul manifest use.
			"color": LootTables.RARITY_COLORS.get(mrar, Color(0.55, 0.80, 0.90)),
			"sold": false,
		})
		mods_added += 1

	## Keystone (only if player doesn't have one)
	if not GameManager.player_has_keystone:
		result.append({
			"type": "keystone",
			"id": "keystone",
			"display": "KEYSTONE  (opens locked extraction)",
			"price": KEYSTONE_PRICE,
			"color": Color(1.0, 0.88, 0.10),
			"sold": false,
		})

	## Town portal — descent only, since it opens a gateway and gateways need the block stack.
	## Offered only when you have none: a second one would do nothing, the first ends the run.
	if GameManager.use_descent_mode and not GameManager.player_has_town_portal:
		result.append({
			"type": "town_portal",
			"id": "town_portal",
			"display": "TOWN PORTAL  (escape anywhere, [T])",
			"price": TOWN_PORTAL_PRICE,
			"color": Color(0.62, 0.78, 1.0),
			"sold": false,
		})

	## Stability bundle
	result.append({
		"type": "stability",
		"id": "stability",
		"display": "Stability Bundle  (-20 instability)",
		"price": STABILITY_PRICE,
		"color": Color(0.45, 0.82, 0.62),
		"sold": false,
	})

	return result


func _build_ui(offers: Array[Dictionary]) -> void:
	## Dark overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := Panel.new()
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.position = Vector2((VW - PANEL_W) * 0.5, (VH - PANEL_H) * 0.5)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.052, 0.040, 0.97)
	style.border_color = Color(0.70, 0.58, 0.10)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	## Title bar
	var title_bg := ColorRect.new()
	title_bg.color = Color(0.20, 0.16, 0.02)
	title_bg.size = Vector2(PANEL_W, 22.0)
	panel.add_child(title_bg)

	var title_lbl := Label.new()
	title_lbl.text = "MERCHANT"
	title_lbl.position = Vector2(8.0, 4.0)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.18))
	panel.add_child(title_lbl)

	## Loot counter — top-right of panel
	var loot_lbl := Label.new()
	loot_lbl.name = "LootCounter"
	loot_lbl.text = "Haul: %d" % int(GameManager.loot_carried)
	loot_lbl.position = Vector2(PANEL_W - 110.0, 5.0)
	loot_lbl.size = Vector2(100.0, 14.0)
	loot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	loot_lbl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.50))
	panel.add_child(loot_lbl)
	_loot_counter = loot_lbl

	var sub_lbl := Label.new()
	sub_lbl.text = "Spend haul for goods and passage."
	sub_lbl.position = Vector2(8.0, 26.0)
	sub_lbl.add_theme_color_override("font_color", Color(0.58, 0.55, 0.38))
	panel.add_child(sub_lbl)

	## Scrollable offer list
	const LIST_Y: float = 46.0
	const LIST_H: float = 208.0
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(6.0, LIST_Y)
	scroll.size = Vector2(PANEL_W - 12.0, LIST_H)
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(PANEL_W - 16.0, 0.0)
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	for offer: Dictionary in offers:
		var row := _build_offer_row(offer)
		vbox.add_child(row)

	UINav.wire_scroll_follow(scroll)

	## Separator + Leave button
	var sep := ColorRect.new()
	sep.color = Color(0.35, 0.28, 0.05)
	sep.size = Vector2(PANEL_W, 1.0)
	sep.position = Vector2(0.0, PANEL_H - 30.0)
	panel.add_child(sep)

	var leave_btn := Button.new()
	leave_btn.text = "LEAVE"
	leave_btn.size = Vector2(PANEL_W - 16.0, 22.0)
	leave_btn.position = Vector2(8.0, PANEL_H - 26.0)
	leave_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	leave_btn.add_theme_color_override("font_color", Color(0.58, 0.55, 0.40))
	leave_btn.pressed.connect(func():
		AudioManager.play_ui("sfx_ui_cancel")
		closed.emit())
	panel.add_child(leave_btn)

	var glyph_bar := GlyphBar.build([["confirm", "Buy"], ["back", "Leave"]])
	glyph_bar.process_mode = Node.PROCESS_MODE_ALWAYS
	glyph_bar.position = Vector2(0.0, PANEL_H - 40.0)
	glyph_bar.size = Vector2(PANEL_W, 12.0)
	panel.add_child(glyph_bar)


func _build_offer_row(offer: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var col: Color = Color(offer.get("color", Color.WHITE))

	var name_lbl := Label.new()
	name_lbl.text = str(offer.get("display", ""))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", col)
	row.add_child(name_lbl)

	var price: int = int(offer.get("price", 0))
	var price_lbl := Label.new()
	price_lbl.text = "%d HAUL" % price
	price_lbl.custom_minimum_size = Vector2(56.0, 0.0)
	price_lbl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.40))
	row.add_child(price_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "BUY"
	buy_btn.custom_minimum_size = Vector2(44.0, 18.0)
	buy_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	buy_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.20))

	var cap_offer: Dictionary = offer.duplicate()
	buy_btn.pressed.connect(func(): _on_buy(cap_offer, row, buy_btn))
	row.add_child(buy_btn)

	return row


func _on_buy(offer: Dictionary, row: HBoxContainer, btn: Button) -> void:
	var price: int = int(offer.get("price", 0))
	if not GameManager.spend_loot(float(price)):
		AudioManager.play_ui("sfx_ui_error")
		## Flash row to indicate insufficient loot
		var t := row.create_tween()
		t.tween_property(row, "modulate", Color(1.0, 0.3, 0.3), 0.05)
		t.tween_property(row, "modulate", Color(1.0, 1.0, 1.0), 0.22)
		return

	AudioManager.play_ui("sfx_ui_purchase")
	if _loot_counter != null:
		_loot_counter.text = "Haul: %d" % int(GameManager.loot_carried)

	var type_key: String = str(offer.get("type", ""))
	match type_key:
		"weapon":
			var wid: String = str(offer.get("id", ""))
			if not GameManager.collected_weapons.has(wid):
				GameManager.collected_weapons.append(wid)
		"mod":
			var mid: String = str(offer.get("id", ""))
			if not GameManager.collected_mods.has(mid):
				GameManager.collected_mods.append(mid)
		"keystone":
			GameManager.pickup_keystone()
		"town_portal":
			GameManager.grant_town_portal()
		"stability":
			GameManager.modify_instability(-STABILITY_REDUCTION)

	btn.disabled = true
	row.modulate = Color(0.55, 0.55, 0.55, 0.65)
