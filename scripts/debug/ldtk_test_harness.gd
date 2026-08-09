class_name LdtkTestHarness
extends Node2D

## Standalone debug harness for scripts/systems/ldtk_loader.gd.
##
## SETUP (one-time, in the Godot editor):
##   1. Create a new scene: scenes/debug/ldtk_test.tscn
##      Root: Node2D, attach this script.
##   2. Add child: Camera2D
##        - position (324, 752)   # center of a 648×1504 level
##        - zoom (0.5, 0.5)       # zoomed out to see whole strip
##        - enabled = true, make_current = true
##   3. Save and run the scene directly (F6 with the scene focused).
##
## What you'll see:
##   - Tile layers and merged wall colliders rendered into the viewport.
##   - Obstacle placeholder rects (gray/brown/etc by kind) for any Obstacle entities.
##   - Region overlays (semi-transparent colored rects) for Maze/PreBoss/Boss/Safe.
##   - Markers drawn as small yellow dots with their tag printed beside them.
##   - Player_Spawn / Boss_Spawn / Level_Exit drawn as labeled crosshairs.
##   - Console: full result dictionary dump + counts + warnings/errors.
##
## Tweak the constants below to point at a different .ldtk / level.

const LDTK_PROJECT_PATH: String = "res://assets/Maps/Levels/Level 1 - Caves.ldtk"
const LEVEL_IDENTIFIER: String = "Level_0"

## Visual overlay colors per region kind (alpha low so tiles show through).
const REGION_COLORS: Dictionary = {
	"Maze":    Color(0.2, 0.8, 0.9, 0.18),
	"PreBoss": Color(0.95, 0.55, 0.15, 0.18),
	"Boss":    Color(0.95, 0.18, 0.18, 0.22),
	"Safe":    Color(0.30, 0.85, 0.35, 0.18),
}

@onready var loader: LdtkLoader = LdtkLoader.new()


func _ready() -> void:
	add_child(loader)
	loader.marker_loaded.connect(_on_marker_loaded)
	var result: Dictionary = loader.load_level(LDTK_PROJECT_PATH, LEVEL_IDENTIFIER)
	_last_result = result
	_print_result_summary(result)
	_paint_overlays(result)
	queue_redraw()


# ─── Console dump ─────────────────────────────────────────────────────────────

func _print_result_summary(r: Dictionary) -> void:
	print("\n========== LdtkLoader result ==========")
	print("ok:                  ", r.ok)
	print("level_name:          ", r.level_name)
	print("biome / id:          ", r.biome, " / ", r.biome_id)
	print("size (px):           ", r.pxWid, " × ", r.pxHei)
	print("player_spawn_pos:    ", _v(r.player_spawn_pos), "  facing=", r.player_facing)
	print("boss_spawn_pos:      ", _v(r.boss_spawn_pos), "  id='", r.boss_id, "'")
	print("level_exit_pos:      ", _v(r.level_exit_pos), "  next='", r.next_level_id, "'  trans=", r.exit_transition)
	print("monster_spawns:      '", r.monster_spawns, "'")
	print("loot_pool:           '", r.loot_pool, "'")
	print("music_id:            '", r.music_id, "'")
	print("recommended_lvl:     ", r.recommended_player_level)
	print("tags:                ", r.tags)
	print("misc_overrides:      ", r.misc_overrides)
	print("misc_notes (count):  ", r.misc_notes.size())
	for n in r.misc_notes:
		print("  · ", n)
	print("----- counts -----")
	print("regions:     ", r.regions.size())
	for reg in r.regions:
		print("  ", reg.kind, " id='", reg.id, "' rect=", reg.rect, " seal=", reg.enter_seal,
			" quota=", reg.kill_quota, " timer=", reg.timer_seconds)
	print("extractions: ", r.extractions.size())
	for ext in r.extractions:
		print("  ", ext.kind, " @", ext.position, " r=", ext.unlock_radius, " ch=", ext.channel_seconds)
	print("spawn_zones: ", r.spawn_zones.size())
	for sz in r.spawn_zones:
		print("  phase=", sz.phase, " density=", sz.density, " rect=", sz.rect,
			" min_dist=", sz.min_distance_from_player)
	print("obstacles:   ", r.obstacles.size())
	print("markers:     ", r.markers.size())
	print("----- diagnostics -----")
	if r.errors.is_empty():
		print("errors:   (none)")
	else:
		print("errors:")
		for e in r.errors:
			print("  ✗ ", e)
	if r.warnings.is_empty():
		print("warnings: (none)")
	else:
		print("warnings:")
		for w in r.warnings:
			print("  ⚠ ", w)
	print("=======================================\n")


func _v(p: Vector2) -> String:
	if is_nan(p.x) or is_nan(p.y):
		return "<unset>"
	return "(%.1f, %.1f)" % [p.x, p.y]


# ─── Visual overlays drawn into the viewport ──────────────────────────────────

func _paint_overlays(r: Dictionary) -> void:
	## Region rectangles
	for reg in r.regions:
		var overlay := ColorRect.new()
		overlay.color = REGION_COLORS.get(reg.kind, Color(1, 1, 1, 0.1))
		overlay.size = (reg.rect as Rect2).size
		overlay.position = (reg.rect as Rect2).position
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(overlay)
		_label_at((reg.rect as Rect2).position + Vector2(4, 4), reg.kind + (" '" + reg.id + "'" if reg.id != "" else ""))

	## Spawn zone rectangles (red tint)
	for sz in r.spawn_zones:
		var z := ColorRect.new()
		z.color = Color(0.85, 0.15, 0.15, 0.18)
		z.size = (sz.rect as Rect2).size
		z.position = (sz.rect as Rect2).position
		z.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(z)
		_label_at((sz.rect as Rect2).position + Vector2(4, 4), "spawn[%s/%s]" % [sz.phase, sz.density])

	## Extraction markers (96×96 hollow squares)
	for ext in r.extractions:
		_label_at(ext.position + Vector2(8, -8), "EXTRACT:%s" % ext.kind)

	## Singletons
	if not is_nan(r.player_spawn_pos.x):
		_label_at(r.player_spawn_pos, "▼ PLAYER %s" % r.player_facing)
	if not is_nan(r.boss_spawn_pos.x):
		_label_at(r.boss_spawn_pos, "★ BOSS %s" % r.boss_id)
	if not is_nan(r.level_exit_pos.x):
		_label_at(r.level_exit_pos, "▲ EXIT → %s" % r.next_level_id)


func _label_at(pos: Vector2, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_color_override("font_color", Color(1, 1, 0.4))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_font_size_override("font_size", 10)
	## Vector font — 10px is well under m5x7's 16px grid, where glyphs fuse. This
	## harness is a Node2D, so there is no subtree theme to inherit from. See DebugUI.
	DebugUI.use_vector_font_on(lbl)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)


func _draw() -> void:
	## Crosshairs + extraction circles done in _draw so they layer on top.
	if _last_result == null:
		return
	var r: Dictionary = _last_result
	for ext in r.get("extractions", []):
		draw_circle(ext.position, ext.unlock_radius, Color(0.25, 1.0, 0.4, 0.35))
	if not is_nan(r.player_spawn_pos.x):
		_cross(r.player_spawn_pos, Color(0.4, 1.0, 0.4))
	if not is_nan(r.boss_spawn_pos.x):
		_cross(r.boss_spawn_pos, Color(1.0, 0.3, 0.3))
	if not is_nan(r.level_exit_pos.x):
		_cross(r.level_exit_pos, Color(1.0, 0.85, 0.2))
	for m in r.get("markers", []):
		draw_circle(m.position, 4.0, Color(1.0, 0.9, 0.2))


func _cross(p: Vector2, c: Color) -> void:
	draw_line(p + Vector2(-10, 0), p + Vector2(10, 0), c, 2.0)
	draw_line(p + Vector2(0, -10), p + Vector2(0, 10), c, 2.0)


## Cache the last result so _draw can reach it without re-loading.
var _last_result = null

func _on_marker_loaded(tag: String, id: String, pos: Vector2, payload: String) -> void:
	print("[marker_loaded] tag=", tag, " id='", id, "' pos=", pos, " payload='", payload, "'")
