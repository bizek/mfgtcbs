class_name RunReportView
extends RefCounted

## Preloaded under an alias rather than the bare class_name — a newly added class_name is not in
## the editor's global class list until it rescans, and this file already learned that lesson the
## hard way once (see the note in extraction_success_screen.gd).
const UIIconsRef := preload("res://scripts/ui/ui_icons.gd")

## RunReportView — the shared after-action report renderer.
##
## Both endings deserve the same report. The extraction screen was rebuilt on 2026-08-02 into a
## full breakdown; the death screen was still four lines, even though RunReportManager had been
## collecting every one of those numbers on death too and simply had no reader. Rather than paste
## ~200 lines of row builders into a second screen and let the two drift, they now share this.
##
## Everything here is static and takes a parent VBox. It renders; it decides nothing about which
## sections a screen wants or in what order — that stays with the screens, because a win and a
## death genuinely want different emphasis.
##
## FONT SIZES ARE 16, FULL STOP. The success screen used to pass 17 and 21 into _make_label, which
## the 2026-08-03 font pass missed because the size arrived as a variable and the audit only
## resolved literals at override call-sites. m5x7 is 16px-native, so 17 and 21 land glyph stems on
## fractional pixels. Emphasis comes from COLOUR and rule lines, per CLAUDE.md — never from size.

const FONT_PATH: String = "res://assets/fonts/m5x7.ttf"
const FS: int = 16

## Rank colours for a breakdown — brightest at the top, cooling down the list, so the biggest
## contributor is obvious at a glance without reading a single number.
const RANK_COLORS: Array[Color] = [
	Color(1.00, 0.86, 0.30),   ## gold
	Color(1.00, 0.62, 0.25),   ## amber
	Color(0.85, 0.48, 0.85),   ## violet
	Color(0.45, 0.75, 1.00),   ## blue
	Color(0.55, 0.80, 0.55),   ## green
]
const RANK_COLOR_TAIL: Color = Color(0.55, 0.58, 0.62)

## The same ramp in reds, for the "what hit you" breakdown. Incoming damage wants to read as a
## threat, not as an achievement — using the gold ramp for both made a lethal enemy look like a
## trophy on the mockup.
const THREAT_COLORS: Array[Color] = [
	Color(1.00, 0.35, 0.30),
	Color(0.95, 0.48, 0.28),
	Color(0.88, 0.55, 0.42),
	Color(0.78, 0.55, 0.55),
	Color(0.68, 0.55, 0.60),
]

const COL_HEADING: Color = Color(0.55, 0.62, 0.68)
const COL_GOOD: Color    = Color(0.55, 0.90, 0.55)
const COL_BAD: Color     = Color(0.95, 0.45, 0.45)
const COL_NEUTRAL: Color = Color(0.85, 0.88, 0.92)
const COL_GOLD: Color    = Color(1.0, 0.82, 0.2)
const COL_LABEL: Color   = Color(0.72, 0.76, 0.80)
const COL_MUTED: Color   = Color(0.5, 0.5, 0.5)

## Row geometry, summing to the scroll width minus the scrollbar.
const ROW_NAME_W: float = 150.0
const ROW_BAR_W: float = 150.0
const ROW_VALUE_W: float = 118.0
const BAR_H: float = 9.0

## Entries below this share are folded into one "everything else" row, so a long tail of 0.4%
## chip damage cannot push the sections below it off the bottom of the scroll.
const MIN_SHARE: float = 0.02

const SCROLL_SIZE: Vector2 = Vector2(440, 196)


# ── Sections ──────────────────────────────────────────────────────────────────────────────────

static func combat_section(lv: VBoxContainer, summary: Dictionary) -> void:
	if summary.is_empty():
		return
	heading(lv, "COMBAT")
	var dealt: float = float(summary.get("damage_dealt", 0.0))
	var taken: float = float(summary.get("damage_taken", 0.0))
	var healed: float = float(summary.get("healed", 0.0))

	stat(lv, "Damage dealt", fmt(dealt), COL_GOOD)
	stat(lv, "Damage taken", fmt(taken), COL_BAD)
	if healed > 0.0:
		stat(lv, "Healed", fmt(healed), COL_GOOD)
	stat(lv, "Biggest hit", fmt(float(summary.get("biggest_hit", 0.0))), COL_NEUTRAL)
	## Net survival margin — the "how close was that" number.
	if taken > 0.0:
		stat(lv, "Damage ratio", "%.1fx" % (dealt / taken),
			COL_GOOD if dealt >= taken else COL_BAD)


## Which of the player's abilities carried the run.
static func dealt_breakdown(lv: VBoxContainer, summary: Dictionary) -> void:
	_breakdown(lv, "DAMAGE BY ABILITY", summary.get("abilities", []),
		float(summary.get("damage_dealt", 0.0)), RANK_COLORS)


## Which enemies actually cost the player HP. The answer to "what killed me" at the level that
## changes how you play the next run — the killing blow alone tells you who landed the last hit,
## which is often not who did the damage.
static func taken_breakdown(lv: VBoxContainer, summary: Dictionary) -> void:
	_breakdown(lv, "WHAT HIT YOU", summary.get("threats", []),
		float(summary.get("damage_taken", 0.0)), THREAT_COLORS)


static func _breakdown(lv: VBoxContainer, title: String, entries: Array, total: float,
		ramp: Array[Color]) -> void:
	if entries.is_empty():
		return
	heading(lv, title)
	var rank: int = 0
	var tail_damage: float = 0.0
	var tail_hits: int = 0
	for entry in entries:
		var share: float = float(entry["share"])
		if share < MIN_SHARE and rank >= ramp.size():
			tail_damage += float(entry["damage"])
			tail_hits += int(entry["hits"])
			continue
		bar_row(lv, str(entry["name"]), float(entry["damage"]), share, int(entry["hits"]),
			ramp[rank] if rank < ramp.size() else RANK_COLOR_TAIL)
		rank += 1
	if tail_damage > 0.0:
		bar_row(lv, "everything else", tail_damage,
			(tail_damage / total) if total > 0.0 else 0.0, tail_hits, RANK_COLOR_TAIL)


# ── Row builders ──────────────────────────────────────────────────────────────────────────────

## One row of a breakdown: name, proportional bar, value + share + hit count.
static func bar_row(parent: VBoxContainer, row_name: String, damage: float, share: float,
		hits: int, col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := label(row_name, col)
	name_lbl.custom_minimum_size = Vector2(ROW_NAME_W, 0)
	name_lbl.clip_text = true
	row.add_child(name_lbl)

	## Track + fill. The fill is sized directly rather than by stretch ratio so a 3% entry still
	## renders a visible sliver instead of collapsing to nothing.
	var track := Control.new()
	track.custom_minimum_size = Vector2(ROW_BAR_W, BAR_H)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track_bg := ColorRect.new()
	track_bg.color = Color(1, 1, 1, 0.07)
	track_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.add_child(track_bg)
	var fill := ColorRect.new()
	fill.color = col
	fill.position = Vector2.ZERO
	fill.size = Vector2(maxf(ROW_BAR_W * share, 2.0), BAR_H)
	track.add_child(fill)
	row.add_child(track)

	var value_lbl := label("%s  %d%%  (%dx)" % [fmt(damage), int(round(share * 100.0)), hits], col)
	value_lbl.custom_minimum_size = Vector2(ROW_VALUE_W, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_lbl)

	parent.add_child(row)


## Label-on-the-left, value-on-the-right stat line.
static func stat(parent: VBoxContainer, text: String, value: String, col: Color) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := label(text, COL_LABEL)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := label(value, col)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	parent.add_child(row)


static func heading(parent: VBoxContainer, text: String) -> void:
	line(parent, "── %s ──────────────────" % text, COL_HEADING)


static func line(parent: VBoxContainer, text: String, col: Color) -> void:
	parent.add_child(label(text, col))


## A manifest line that ends in a rarity PILL rather than bracket text.
##
## The haul is the payoff moment of a run, and "[RARE]" was carrying that entirely in punctuation.
## The pill is the UI pack's own tag art, colour-matched to LootTables.RARITY_COLORS.
##
## Falls back to the exact previous string when the tag sheet is unavailable, so this can never
## leave a loot line with the rarity silently missing — the one thing worse than plain text here.
static func tagged_line(parent: VBoxContainer, text: String, col: Color, rarity: String) -> void:
	var tag: Control = UIIconsRef.rarity_tag(rarity)
	if tag == null:
		line(parent, "%s  [%s]" % [text, rarity.to_upper()], col)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(label(text, col))
	row.add_child(tag)
	parent.add_child(row)


static func label(text: String, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	var settings := LabelSettings.new()
	if ResourceLoader.exists(FONT_PATH):
		settings.font = load(FONT_PATH)
	settings.font_size     = FS
	settings.font_color    = col
	settings.outline_size  = 1
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.85)
	lbl.label_settings = settings
	return lbl


# ── Helpers ───────────────────────────────────────────────────────────────────────────────────

## The scrollable body both screens insert above their button. SHOW_AS_NEEDED (Godot's default),
## never SHOW_NEVER — per CLAUDE.md, which would clip the breakdown on a long run.
static func make_scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = SCROLL_SIZE
	var lv := VBoxContainer.new()
	lv.name = "Body"
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 3)
	scroll.add_child(lv)
	return scroll


## RunReportManager is a sibling of the screen's parent (both live under MainArena). Returns {}
## in any mode that has no tracker — training room, flat arena — so every section degrades to
## "just don't draw it" rather than erroring.
static func summary_for(screen: Node) -> Dictionary:
	var parent: Node = screen.get_parent()
	if parent == null:
		return {}
	var rr: Node = parent.get_node_or_null("RunReportManager")
	if rr == null or not rr.has_method("get_summary"):
		return {}
	return rr.get_summary()


## Thousands separators. A five-figure damage total reads as an achievement; "48213" reads as
## noise, and these screens are supposed to land emotionally.
static func fmt(value: Variant) -> String:
	var n: int = int(round(float(value)))
	var s: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
