extends CanvasLayer

## Level-Up Screen — Pauses game, shows 3 upgrade choices, resumes on pick

signal upgrade_selected(upgrade: Dictionary)

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var choices_container: VBoxContainer = $Panel/VBox/ChoicesContainer

var _glyph_bar: GlyphBar

const WEAPON_SWAP_COST: float = 30.0

## --- Card identity (2026-08-03) ---
## The pool gained roles, but every generic card still rendered as undifferentiated white text, so
## the crowd answers read exactly as flat as the stat sticks they exist to stand out from. Each
## card now carries a role colour on its name, a left accent bar, and a leading glyph — the glyph
## because colour alone is not a cue for a colourblind player, and this is a 640x360 game where
## hue is most of what a 210px card can spend.
##
## GLYPHS ARE ASCII ON PURPOSE. m5x7 has no coverage for the decorative Unicode marks: the ★ and ✦
## this screen used until now were silently falling back to Godot's default vector font, so the
## one glyph meant to make a card feel special was also the one blurry thing on it. Every mark
## below is verified present in m5x7 — check with FontFile.has_char() before adding another.
const C_CROWD:   Color = Color(1.00, 0.55, 0.28)   ## burst orange — hits many at once
const C_SPACE:   Color = Color(0.42, 0.82, 1.00)   ## cyan — distance and mobility
const C_SURVIVE: Color = Color(0.48, 0.85, 0.48)   ## green — endure what lands
const C_POWER:   Color = Color(0.88, 0.86, 0.78)   ## bone white — the baseline stat stick
const C_EVO:     Color = Color(1.00, 0.85, 0.15)   ## gold, unchanged
const C_DESC:    Color = Color(0.70, 0.69, 0.66)   ## descriptions stay neutral so they stay legible
const C_CARD_BG: Color = Color(0.082, 0.075, 0.063) ## matches the hub card plate (hub_armory_panel)

const ROLE_COLORS: Dictionary = {
	"crowd": C_CROWD, "space": C_SPACE, "survive": C_SURVIVE, "power": C_POWER,
}
## Shapes chosen to stay apart at 16px: a burst, a chevron pair, a wall, a plus.
const ROLE_GLYPHS: Dictionary = {
	"crowd": "*", "space": "»", "survive": "#", "power": "+",
}
const EVO_GLYPH: String = "&"   ## an evolution is literally two upgrades fused — "and" fits
const KIT_GLYPH: String = "^"   ## your kit steps up

const CARD_SIZE: Vector2 = Vector2(210, 40)
## Usable text width inside a card: CARD_SIZE.x minus the 9px left inset (clear of the accent bar)
## and the 4px right one. Descriptions are the widest thing on a card and ten of them run past it —
## every evolution, plus three kit upgrades, the worst at 285px. They clipped on the old single-
## string button too; wrapping is what actually fixes it.
const CARD_TEXT_WIDTH: float = 197.0
const CARD_MAX_DESC_LINES: int = 2

var player_ref: Node2D = null
var _choices: Array[Dictionary] = []
var _rerolls_remaining: int = 0

## ── Select-then-confirm ──────────────────────────────────────────────────────
## Picking used to apply the moment a card was pressed. The screen opens mid-combat while the
## player is holding or mashing attack, so a click already in flight landed on whatever card
## happened to be under the cursor and the upgrade was spent before it had been read (Ben,
## 2026-08-09: "you'll be kinda mashing attack, its easy to accidentally select something and
## not even know what you selected").
##
## Two independent guards, because either alone leaves a hole:
##   • a card press now SELECTS; only the CONFIRM button applies, and it sits apart from the
##     cards so a mash at the cursor's position cannot reach it;
##   • presses are ignored for INPUT_LOCK after the screen opens, which catches the click that
##     was already travelling when it appeared. Without this, the first mash still selects —
##     harmless now, but it would make the highlight jump for no reason the player can see.
const INPUT_LOCK: float = 0.25

var _selected: int = -1
var _confirm_btn: Button = null
var _cards: Array[Button] = []
var _lock_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	## "Select", not "Pick" — the button no longer commits the choice on its own.
	_glyph_bar = GlyphBar.build([["confirm", "Select"]])
	$Panel/VBox.add_child(_glyph_bar)

func setup(player: Node2D) -> void:
	player_ref = player
	player_ref.leveled_up.connect(_on_player_leveled_up)

func _on_player_leveled_up(new_level: int) -> void:
	title_label.text = "LEVEL %d!" % new_level
	_rerolls_remaining = ProgressionManager.get_max_rerolls()
	_selected = -1
	_lock_timer = INPUT_LOCK
	_choices = UpgradeManager.generate_choices(3)
	## Visible BEFORE building: _show_choices ends with UINav.focus_first,
	## which only considers visible controls — grabbing while the layer is
	## still hidden finds nothing and leaves controller focus dead.
	visible = true
	_show_choices()
	GameManager.enter_level_up()

func _show_choices() -> void:
	## Clear old buttons
	for child in choices_container.get_children():
		child.queue_free()

	## Load pixel font for buttons (same font used by the HUD)
	var pixel_font: FontFile = load("res://assets/fonts/m5x7.ttf")

	## Create a button for each choice. All three share one height so the row reads as a row.
	_cards.clear()
	var card_h: float = _card_height_for(_choices, pixel_font)
	for i in range(_choices.size()):
		var btn := _build_choice_card(_choices[i], pixel_font, card_h)
		btn.pressed.connect(_on_choice_pressed.bind(i))
		UINav.apply_focus_ring(btn)
		choices_container.add_child(btn)
		_cards.append(btn)

	## Reroll button
	var reroll_btn := Button.new()
	reroll_btn.custom_minimum_size = Vector2(210, 30)
	reroll_btn.disabled = _rerolls_remaining <= 0
	reroll_btn.text = "Reroll  [%d left]" % _rerolls_remaining
	reroll_btn.pressed.connect(_on_reroll_pressed)
	UINav.apply_focus_ring(reroll_btn)
	choices_container.add_child(reroll_btn)

	## The commit. Separate control, below the cards, disabled until something is chosen —
	## so nothing can be spent by a click that lands where a card happens to be.
	_confirm_btn = Button.new()
	_confirm_btn.custom_minimum_size = Vector2(210, 30)
	_confirm_btn.disabled = true
	_confirm_btn.text = "CONFIRM"
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	UINav.apply_focus_ring(_confirm_btn)
	choices_container.add_child(_confirm_btn)

	_build_weapon_cache(pixel_font)
	_refresh_selection()
	UINav.focus_first(choices_container)


func _process(delta: float) -> void:
	if _lock_timer > 0.0:
		_lock_timer -= delta


## Repaint the cards so the chosen one is obvious, and enable the commit.
##
## Dimming alone is not enough of a signal here: the cards are ALREADY colour-coded by role, so
## "the brighter one" competes with four accent colours and the focus ring, which sits on
## whichever card the keyboard/controller last moved to and is often a different card entirely.
## So the button says what it is about to spend. That is the literal complaint this change
## exists to answer — "easy to accidentally select something and not even know what you
## selected" — and a name is unambiguous where a brightness step is not.
func _refresh_selection() -> void:
	for i in range(_cards.size()):
		var chosen: bool = (i == _selected)
		_cards[i].modulate = Color(1, 1, 1) if chosen else Color(0.55, 0.55, 0.60)
	if _confirm_btn == null:
		return
	_confirm_btn.disabled = _selected < 0
	if _selected < 0:
		_confirm_btn.text = "PICK ONE"
		return
	## Measured: the longest name sampled puts this at 170px against a 210px button, but
	## clip_text guarantees a future longer one can never push the card row wider.
	_confirm_btn.clip_text = true
	_confirm_btn.text = "CONFIRM:  %s" % str(_choices[_selected].get("name", ""))

## One choice card. A Button holding its own layout rather than a two-line `text` string, because
## the name and the description want different colours and Button.text can only be one.
##
## Children are anchored, not laid out by a Container, so the Button is NOT a container and its
## minimum size stays exactly CARD_SIZE. That is deliberate: the level-up Panel is a PanelContainer
## that grows to fit its content, and a card free to grow with its text could push the panel past
## the 360px viewport on a long description.
## Uniform card height for the offered set: one name line plus however many lines the LONGEST
## description on offer needs, capped. Sizing every card to the tallest keeps the row square —
## three different heights would read as a layout bug rather than as emphasis. The cap is safe:
## the widest description in the game measures 285px, which is two lines at 197px.
func _card_height_for(choices: Array[Dictionary], pixel_font: FontFile) -> float:
	var line_h: float = 18.0
	if pixel_font:
		line_h = pixel_font.get_string_size("Ag", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).y
	var max_lines: int = 1
	for c: Dictionary in choices:
		if not pixel_font:
			break
		var w: float = pixel_font.get_string_size(
			str(c.get("description", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		max_lines = maxi(max_lines, clampi(ceili(w / CARD_TEXT_WIDTH), 1, CARD_MAX_DESC_LINES))
	return maxf(CARD_SIZE.y, line_h * float(1 + max_lines) + 4.0)


func _build_choice_card(upgrade: Dictionary, pixel_font: FontFile, card_h: float) -> Button:
	var accent: Color = C_POWER
	var glyph: String = "+"
	## Capstones share the evolution's gold plate. They are not evolutions mechanically — nothing
	## is consumed and apply_upgrade routes them as ordinary ability upgrades — but to the player
	## they are the same thing: the card you only see once you have built toward it.
	if upgrade.get("is_evolution", false) or upgrade.get("is_capstone", false):
		accent = C_EVO
		glyph = EVO_GLYPH
	elif upgrade.get("is_ability_upgrade", false):
		accent = CharacterData.ALL.get(
			ProgressionManager.selected_character, {}).get("color", Color.WHITE)
		glyph = KIT_GLYPH
	else:
		var role: String = upgrade.get("role", "power")
		accent = ROLE_COLORS.get(role, C_POWER)
		glyph = ROLE_GLYPHS.get(role, "+")

	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(CARD_SIZE.x, card_h)
	## UINav.apply_focus_ring only overrides "focus", and draws border-only on top — these three
	## do not fight it.
	btn.add_theme_stylebox_override("normal", _card_style(accent, 0.06))
	btn.add_theme_stylebox_override("hover", _card_style(accent, 0.16))
	btn.add_theme_stylebox_override("pressed", _card_style(accent, 0.24))

	## Left accent bar — the same 3-4px strip the hub cards use to signal state.
	var strip := ColorRect.new()
	strip.color = accent
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.anchor_left = 0.0
	strip.anchor_top = 0.0
	strip.anchor_right = 0.0
	strip.anchor_bottom = 1.0
	strip.offset_left = 0.0
	strip.offset_top = 0.0
	strip.offset_right = 3.0
	strip.offset_bottom = 0.0
	btn.add_child(strip)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 1)
	margin.add_theme_constant_override("margin_bottom", 1)
	btn.add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)

	col.add_child(_card_line("%s %s" % [glyph, str(upgrade.get("name", "?"))], accent, pixel_font))
	var desc := _card_line(str(upgrade.get("description", "")), C_DESC, pixel_font)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(desc)
	return btn


func _card_line(text: String, color: Color, pixel_font: FontFile) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_color_override("font_color", color)
	return lbl


## Card plate: the hub's dark card colour pulled a little toward the role hue, framed in a dimmed
## version of the same hue so the border belongs to the card instead of outlining it.
func _card_style(accent: Color, tint: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_CARD_BG.lerp(accent, tint)
	sb.border_color = C_CARD_BG.lerp(accent, 0.35)
	sb.set_border_width_all(1)
	return sb


func _build_weapon_cache(pixel_font: FontFile) -> void:
	var current_weapon: String = player_ref.get_active_weapon_id()
	var available: Array[String] = []
	for weapon_id in ProgressionManager.unlocked_weapons:
		if weapon_id == current_weapon:
			continue
		## Class-lock (2026-08-08). Blue/purple class gear carries an `unlock_id`, so without this
		## the mid-run cache happily offered the Warden's hammer to the Shade — the one weapon
		## offer in the game that could hand you gear your kit is not built around.
		if not WeaponData.equippable_for(weapon_id, ProgressionManager.selected_character):
			continue
		var wdata: Dictionary = WeaponData.ALL.get(weapon_id, {})
		if wdata.get("unlock_id", "").is_empty():
			continue  ## Skip starters — they're always available, not a mid-run prize
		available.append(weapon_id)

	if available.is_empty():
		return

	## Pick one random weapon to offer — you don't get to browse the full cache
	var offered: String = available[randi() % available.size()]
	var wdata: Dictionary = WeaponData.ALL[offered]

	var sep := HSeparator.new()
	choices_container.add_child(sep)

	var header := Label.new()
	header.text = "- WEAPON CACHE  [%.0f / %.0f haul] -" % [GameManager.loot_carried, WEAPON_SWAP_COST]
	header.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choices_container.add_child(header)

	var display: String = wdata.get("display_name", offered)
	var desc: String    = wdata.get("description", "")
	var btn := Button.new()
	btn.text = "%s\n%s\n[Cost: 30 haul - drops current weapon]" % [display, desc]
	btn.custom_minimum_size = Vector2(210, 52)
	btn.disabled = GameManager.loot_carried < WEAPON_SWAP_COST
	btn.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	btn.pressed.connect(_on_weapon_swap_pressed.bind(offered))
	choices_container.add_child(btn)

func _on_weapon_swap_pressed(weapon_id: String) -> void:
	if not GameManager.spend_loot(WEAPON_SWAP_COST):
		AudioManager.play_ui("sfx_ui_error")
		return
	AudioManager.play_ui("sfx_ui_purchase")
	player_ref.drop_current_weapon()
	player_ref.switch_weapon(weapon_id)
	visible = false
	GameManager.exit_level_up()

func _on_reroll_pressed() -> void:
	if _rerolls_remaining <= 0:
		return
	AudioManager.play_ui("sfx_ui_click")
	_rerolls_remaining -= 1
	## A reroll replaces every card, so any existing selection refers to an upgrade that is no
	## longer on offer. Clearing it also re-disables CONFIRM, which is the behaviour you want:
	## a fresh set has to be chosen from again.
	_selected = -1
	_choices = UpgradeManager.generate_choices(3)
	_show_choices()

## Pressing a card SELECTS it. Nothing is spent here — see the note on INPUT_LOCK.
func _on_choice_pressed(index: int) -> void:
	if _lock_timer > 0.0:
		return
	if _selected == index:
		return
	_selected = index
	AudioManager.play_ui("sfx_ui_click")
	_refresh_selection()


## The only path that actually spends the level-up.
func _on_confirm_pressed() -> void:
	if _lock_timer > 0.0 or _selected < 0 or _selected >= _choices.size():
		return
	var upgrade: Dictionary = _choices[_selected]
	AudioManager.play_ui("sfx_upgrade_select")
	UpgradeManager.apply_upgrade(upgrade, player_ref)
	upgrade_selected.emit(upgrade)
	_selected = -1
	visible = false
	GameManager.exit_level_up()
