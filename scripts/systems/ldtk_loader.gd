class_name LdtkLoader
extends Node2D

## LdtkLoader — loads an LDtk level (.ldtk project + level identifier) into the scene.
##
## Schema contract: docs/ldtk_schema.md (v1). Mismatched schema_version is rejected.
##
## Public entry point: load_level(ldtk_project_path, level_identifier) -> Dictionary.
##   Returns a result dict with:
##     ok: bool
##     errors: Array[String]      — fatal problems (caller should abort)
##     warnings: Array[String]    — non-fatal (caller may log + continue)
##     level_name: String
##     biome: String              — BiomeId enum value (e.g. "Caves")
##     biome_id: int              — 1..5, mapped from biome
##     player_spawn_pos: Vector2
##     player_facing: String      — "Up"/"Down"/"Left"/"Right"
##     boss_spawn_pos: Vector2 (or NAN if unset)
##     boss_id: String
##     boss_intro_delay: float
##     boss_camera_zoom: float
##     level_exit_pos: Vector2 (or NAN if unset)
##     next_level_id: String
##     exit_transition: String
##     monster_spawns: String
##     loot_pool: String
##     music_id: String
##     recommended_player_level: int
##     tags: Array[String]
##     misc_notes: Array[String]
##     misc_overrides: Dictionary  — parsed key=value (string→Variant)
##     regions: Array[Dictionary]  — {kind, id, rect (Rect2 in level-local px), enter_seal, kill_quota, timer_seconds}
##     extractions: Array[Dictionary] — {kind, position, unlock_radius, channel_seconds, notes}
##     spawn_zones: Array[Dictionary] — {phase, density, rect, enemy_pool_override, min_distance_from_player}
##     markers: Array[Dictionary]  — {tag, id, position, payload}
##     obstacles: Array[Dictionary] — {kind, position, variant_index, collision_radius, scale}
##     pxWid: int / pxHei: int     — level pixel size (used for camera bounds)
##
## Side effects (added as children of self):
##   - One TileMapLayer per Tiles/AutoLayer layer with a bound tileset.
##   - One StaticBody2D per merged Wall rectangle (greedy 2D merge of Collision IntGrid).
##   - One StaticBody2D per merged PropCollision rectangle (paint-to-add prop/feature colliders).
##   - One Sprite2D + StaticBody2D per Obstacle entity (placeholder colored rect for now).
##
## Caller responsibilities (wire up in MainArena):
##   - Set Player.global_position = result.player_spawn_pos.
##   - Configure ExtractionManager handlers using result.extractions.
##   - Hand result.spawn_zones to EnemySpawnManager (API addition pending).
##   - LevelDirector consumes result.regions for kill_quota / boss sealing (TBD).
##
## Markers fire the `marker_loaded` signal as they're parsed; subscribe before calling load_level.

signal marker_loaded(tag: String, id: String, position: Vector2, payload: String)

const SCHEMA_VERSION: int = 1

const BIOME_TO_LEVEL_ID: Dictionary = {
	"Caves": 1,
	"Catacombs": 2,
	"NightmareRealm": 3,
	"Threshold": 4,
	"Inferno": 5,
}

## IntGrid value identifiers must match docs/ldtk_schema.md §2.
const INTGRID_FLOOR: int = 1
const INTGRID_WALL: int = 2
const INTGRID_PIT: int = 3
const INTGRID_LOWCOVER: int = 4
const INTGRID_SPAWNBLOCK: int = 5

## Collision layer 3 — walls block player (layer 1) + enemies (layer 2). Matches arena_generator.gd.
const WALL_COLLISION_LAYER: int = 3

## Dedicated paint-to-add collision IntGrid layer (docs/ldtk_schema.md §3). Inverse polarity from
## `Collision`: unpainted = nothing, any nonzero cell = solid. Lets the author brush collision over
## props (Caves_Props) and select Cave_Tiles features without touching the floor-flooded Collision
## layer. Optional — absent on a block means no extra colliders.
const PAINT_COLLISION_LAYER_NAME: String = "PropCollision"

## Cached project-level data, populated on each load_level call.
var _project_dir: String = ""
var _tileset_uid_to_def: Dictionary = {}      ## uid (int) → tileset def dict
var _entity_uid_to_def: Dictionary = {}       ## uid (int) → entity def dict
var _tilemap_layers: Array[Node] = []         ## children we created (cleared between loads)
var _collision_bodies: Array[Node] = []
var _obstacle_nodes: Array[Node] = []


# ─── Public API ───────────────────────────────────────────────────────────────

func load_level(ldtk_project_path: String, level_identifier: String) -> Dictionary:
	var result: Dictionary = _empty_result()
	_clear_children()

	## --- Read project file ---
	var project: Dictionary = _read_json(ldtk_project_path, result)
	if not result.ok:
		return result
	_project_dir = ldtk_project_path.get_base_dir()
	_index_defs(project)

	## --- Locate the target level entry in worldLevels (or `levels` for embedded) ---
	var level_entry: Dictionary = _find_level_entry(project, level_identifier)
	if level_entry.is_empty():
		_fatal(result, "Level '%s' not found in project '%s'." % [level_identifier, ldtk_project_path])
		return result

	## --- Resolve external .ldtkl if present ---
	var level_data: Dictionary = level_entry
	var ext_rel: String = level_entry.get("externalRelPath", "")
	if ext_rel != "":
		var ext_path: String = _project_dir.path_join(ext_rel)
		level_data = _read_json(ext_path, result)
		if not result.ok:
			return result

	## --- Validate schema_version BEFORE doing anything ---
	var schema_version: int = _get_level_field_value(level_data, "schema_version", 0)
	if schema_version != SCHEMA_VERSION:
		_fatal(result, "schema_version mismatch: level has %d, importer expects %d. Re-run tools/apply_ldtk_schema.py and update the level." % [schema_version, SCHEMA_VERSION])
		return result

	## --- Read biome (drives floor/music/wave defaults) ---
	var biome: String = _get_level_field_value(level_data, "biome", "")
	result.biome = biome
	result.biome_id = BIOME_TO_LEVEL_ID.get(biome, 0)
	if result.biome_id == 0:
		_warn(result, "Unknown biome '%s' — caller should fall back to defaults." % biome)

	result.pxWid = int(level_data.get("pxWid", 0))
	result.pxHei = int(level_data.get("pxHei", 0))

	## --- Layer pass: render tiles, build collision, gather entity instances ---
	var entity_instances: Array = []
	for layer_inst in level_data.get("layerInstances", []):
		var ltype: String = layer_inst.get("__type", "")
		match ltype:
			"Tiles":
				_render_tile_layer(layer_inst, false, result)
			"AutoLayer":
				_render_tile_layer(layer_inst, true, result)
			"IntGrid":
				## IntGrid layers also carry autoLayerTiles when an auto-rule paints over them.
				if not layer_inst.get("autoLayerTiles", []).is_empty():
					_render_tile_layer(layer_inst, true, result)
				var intgrid_id: String = layer_inst.get("__identifier", "")
				if intgrid_id == "Collision":
					_build_wall_collision(layer_inst, result)
				elif intgrid_id == PAINT_COLLISION_LAYER_NAME:
					_build_paint_collision(layer_inst, result)
			"Entities":
				entity_instances = layer_inst.get("entityInstances", [])
			_:
				_warn(result, "Skipping unknown layer type '%s' (identifier=%s)." % [ltype, layer_inst.get("__identifier", "?")])

	## --- Entity pass: dispatch by identifier ---
	var level_instructions_count: int = 0
	for ent in entity_instances:
		var ident: String = ent.get("__identifier", "")
		match ident:
			"Level_Instructions":
				level_instructions_count += 1
				_apply_level_instructions(ent, result)
			"Region":
				_collect_region(ent, result)
			"Extraction":
				_collect_extraction(ent, result)
			"EnemySpawnZone":
				_collect_spawn_zone(ent, result)
			"Obstacle":
				_collect_obstacle(ent, result)
			"Marker":
				_collect_marker(ent, result)
			_:
				_warn(result, "Unknown entity identifier '%s' at %s — skipping." % [ident, ent.get("__grid", [])])

	## --- Post-validation ---
	if level_instructions_count == 0:
		_warn(result, "Level has no Level_Instructions entity. Player spawn / exit will be unset.")
	elif level_instructions_count > 1:
		_warn(result, "Level has %d Level_Instructions entities — exactly 1 expected. First wins." % level_instructions_count)

	_validate_regions(result)
	_validate_extractions(result)

	return result


# ─── Result struct helpers ────────────────────────────────────────────────────

func _empty_result() -> Dictionary:
	return {
		"ok": true,
		"errors": [],
		"warnings": [],
		"level_name": "",
		"biome": "",
		"biome_id": 0,
		"pxWid": 0,
		"pxHei": 0,
		"player_spawn_pos": Vector2(NAN, NAN),
		"player_facing": "Down",
		"boss_spawn_pos": Vector2(NAN, NAN),
		"boss_id": "",
		"boss_intro_delay": 1.5,
		"boss_camera_zoom": 1.0,
		"level_exit_pos": Vector2(NAN, NAN),
		"next_level_id": "",
		"exit_transition": "Fade",
		"monster_spawns": "",
		"loot_pool": "",
		"music_id": "",
		"recommended_player_level": 1,
		"tags": [],
		"misc_notes": [],
		"misc_overrides": {},
		"regions": [],
		"extractions": [],
		"spawn_zones": [],
		"markers": [],
		"obstacles": [],
	}


func _fatal(result: Dictionary, msg: String) -> void:
	result.ok = false
	result.errors.append(msg)
	push_error("[LdtkLoader] " + msg)


func _warn(result: Dictionary, msg: String) -> void:
	result.warnings.append(msg)
	push_warning("[LdtkLoader] " + msg)


# ─── JSON / project indexing ──────────────────────────────────────────────────

## Project JSON cache — avoids re-reading the same file for every block in a descent.
static var _project_cache: Dictionary = {}

func _read_json(path: String, result: Dictionary) -> Dictionary:
	if LdtkLoader._project_cache.has(path):
		return LdtkLoader._project_cache[path]
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_fatal(result, "Could not open '%s' (err=%d)." % [path, FileAccess.get_open_error()])
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fatal(result, "Failed to parse JSON at '%s'." % path)
		return {}
	LdtkLoader._project_cache[path] = parsed
	return parsed


func _index_defs(project: Dictionary) -> void:
	_tileset_uid_to_def.clear()
	_entity_uid_to_def.clear()
	var defs: Dictionary = project.get("defs", {})
	for ts in defs.get("tilesets", []):
		_tileset_uid_to_def[int(ts.get("uid", 0))] = ts
	for ed in defs.get("entities", []):
		_entity_uid_to_def[int(ed.get("uid", 0))] = ed


func _find_level_entry(project: Dictionary, identifier: String) -> Dictionary:
	for lvl in project.get("levels", []):
		if lvl.get("identifier", "") == identifier:
			return lvl
	return {}


func _get_level_field_value(level: Dictionary, identifier: String, default_val: Variant) -> Variant:
	for fi in level.get("fieldInstances", []):
		if fi.get("__identifier", "") == identifier:
			var v: Variant = fi.get("__value", null)
			return v if v != null else default_val
	return default_val


# ─── Tile / auto-layer rendering ──────────────────────────────────────────────

func _render_tile_layer(layer_inst: Dictionary, is_auto: bool, result: Dictionary) -> void:
	var tileset_uid: int = int(layer_inst.get("__tilesetDefUid", 0))
	if tileset_uid == 0:
		return  ## unbound tileset — nothing to render
	var ts_def: Dictionary = _tileset_uid_to_def.get(tileset_uid, {})
	if ts_def.is_empty():
		_warn(result, "Layer '%s' references unknown tileset uid %d — skipping." % [layer_inst.get("__identifier", "?"), tileset_uid])
		return

	## Build a Godot TileSet for this layer (only the atlas cells it uses — see below).
	var tile_size: int = int(ts_def.get("tileGridSize", 8))
	var tex_path: String = _resolve_tileset_texture(ts_def)
	if tex_path == "" or not ResourceLoader.exists(tex_path):
		_warn(result, "Tileset '%s' texture not found at '%s' — skipping layer." % [ts_def.get("identifier", "?"), tex_path])
		return
	var tex: Texture2D = load(tex_path)

	## Tiles live in autoLayerTiles (auto/intgrid) or gridTiles (manual). Gather them
	## up-front so the tileset only pre-creates the atlas cells this layer references —
	## pre-creating the whole atlas is O(cells^2) (create_tile is O(n) per call) and
	## dominated descent load (prop layers spent 12-21 s, two placing zero tiles).
	var tiles: Array = layer_inst.get("autoLayerTiles", []) if is_auto else layer_inst.get("gridTiles", [])
	var used_atlas: Dictionary = {}
	for t in tiles:
		var s: Array = t.get("src", [0, 0])
		@warning_ignore("integer_division")
		used_atlas[Vector2i(int(s[0]) / tile_size, int(s[1]) / tile_size)] = true
	var godot_ts: TileSet = _build_godot_tileset(tex, tile_size, used_atlas)

	## Use a TileMapLayer per LDtk layer so layer ordering / z-index is per-layer.
	var tml: TileMapLayer = TileMapLayer.new()
	tml.name = layer_inst.get("__identifier", "TileLayer")
	tml.tile_set = godot_ts

	## Assign z-index so tile layers render behind entities (player/enemies are z=0).
	## Covers both schema names and actual Level_0 identifiers.
	## Order mirrors LDtk's layer list (top of list = drawn in front): floor at the
	## bottom, structural overlays (Cave_Pillars: rims, caps, trims) above the floor,
	## shadows above those, prop layers in front so props are never hidden under
	## rim/cap overlay lines.
	const LAYER_Z: Dictionary = {
		"Background": -5, "CavesBackground": -5, "CryptTiles": -4,
		"EtherealAutoLayer": -4,
		"FloorAuto": -3, "Cave_Tiles": -3, "Ethereal_Floor": -3,
		"Cave_Pillars": -2, "CavesShadows": -2, "CryptLayer": -2,
		"CaveEntrances": -2, "Caves_PropsShadows": -2, "CryptProps_Shadows": -2,
		"CryptShadows": -2, "Ethereal_Shadows": -2, "Ethereal_Props_Shadows": -2,
		"Ethereal_Walls": -2,
		"WallsAuto": -1,
		"Decoration": 2,
	}
	var layer_id: String = layer_inst.get("__identifier", "")
	tml.z_index = LAYER_Z.get(layer_id, -1)

	add_child(tml)
	_tilemap_layers.append(tml)

	for t in tiles:
		var px: Array = t.get("px", [0, 0])
		var src: Array = t.get("src", [0, 0])
		@warning_ignore("integer_division")
		var coords := Vector2i(int(px[0]) / tile_size, int(px[1]) / tile_size)
		@warning_ignore("integer_division")
		var atlas := Vector2i(int(src[0]) / tile_size, int(src[1]) / tile_size)
		## TODO(flip): LDtk packs flip flags in `t.f` (0/1/2/3 = none/x/y/xy).
		##             TileMapLayer needs alternative tile IDs for flipped variants;
		##             defer until we hit a layer that actually flips tiles.
		tml.set_cell(coords, 0, atlas)


func _resolve_tileset_texture(ts_def: Dictionary) -> String:
	var rel: String = ts_def.get("relPath", "")
	if rel == "":
		return ""
	## LDtk's relPath is relative to the .ldtk file's directory.
	var abs_path: String = _project_dir.path_join(rel).simplify_path()
	## Convert OS path → res:// path for ResourceLoader.
	if abs_path.begins_with("res://"):
		return abs_path
	var project_root: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var normalized: String = abs_path.replace("\\", "/")
	if normalized.begins_with(project_root):
		return "res://" + normalized.substr(project_root.length()).lstrip("/")
	return abs_path  ## last-resort; will likely fail ResourceLoader.exists


func _build_godot_tileset(tex: Texture2D, tile_size: int, used_atlas: Dictionary) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile_size, tile_size)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(tile_size, tile_size)
	## Create only the atlas cells this layer references (keys of used_atlas).
	## Pre-creating the full atlas is O(cells^2) — create_tile is O(n) per call — and
	## most cells go unused. Bounds-guard stray src coords: an out-of-range cell
	## wouldn't have existed under the old full-grid build either, so set_cell skips it.
	@warning_ignore("integer_division")
	var cols: int = tex.get_width() / tile_size
	@warning_ignore("integer_division")
	var rows: int = tex.get_height() / tile_size
	for coord: Vector2i in used_atlas:
		if coord.x >= 0 and coord.y >= 0 and coord.x < cols and coord.y < rows:
			src.create_tile(coord)
	ts.add_source(src, 0)
	return ts


# ─── Collision: greedy 2D merge of Wall cells into rectangles ─────────────────

func _build_wall_collision(layer_inst: Dictionary, result: Dictionary) -> void:
	var cw: int = int(layer_inst.get("__cWid", 0))
	var ch: int = int(layer_inst.get("__cHei", 0))
	var grid_size: int = int(layer_inst.get("__gridSize", 8))
	var csv: Array = layer_inst.get("intGridCsv", [])
	if cw == 0 or ch == 0 or csv.size() != cw * ch:
		_warn(result, "Collision layer dimensions invalid (cw=%d ch=%d csv=%d) — skipping wall collision." % [cw, ch, csv.size()])
		return

	## Solid cells = explicitly painted Wall (value 2) OR empty/void (value 0).
	## Floor (value 1) is the only passable value — the user paints walkable ground,
	## and anything unpainted is treated as a solid cave wall.
	var is_solid: PackedByteArray = PackedByteArray()
	is_solid.resize(cw * ch)
	for i in csv.size():
		var v: int = int(csv[i])
		is_solid[i] = 1 if (v == 0 or v == INTGRID_WALL) else 0
	_merge_solid_grid(is_solid, cw, ch, grid_size)


func _build_paint_collision(layer_inst: Dictionary, result: Dictionary) -> void:
	## PropCollision layer: paint-to-add. Any nonzero cell is solid; unpainted cells are ignored
	## (inverse of the Collision layer). Used for prop / Cave_Tiles feature colliders.
	var cw: int = int(layer_inst.get("__cWid", 0))
	var ch: int = int(layer_inst.get("__cHei", 0))
	var grid_size: int = int(layer_inst.get("__gridSize", 8))
	var csv: Array = layer_inst.get("intGridCsv", [])
	if cw == 0 or ch == 0 or csv.size() != cw * ch:
		_warn(result, "%s layer dimensions invalid (cw=%d ch=%d csv=%d) — skipping prop collision." % [PAINT_COLLISION_LAYER_NAME, cw, ch, csv.size()])
		return

	var is_solid: PackedByteArray = PackedByteArray()
	is_solid.resize(cw * ch)
	for i in csv.size():
		is_solid[i] = 1 if int(csv[i]) != 0 else 0
	_merge_solid_grid(is_solid, cw, ch, grid_size)


## Greedy 2D merge of solid cells into maximal rectangles, spawning one StaticBody2D per rect.
## Shared by the Collision (wall) and PropCollision (paint) builders.
func _merge_solid_grid(is_solid: PackedByteArray, cw: int, ch: int, grid_size: int) -> void:
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(cw * ch)

	for y in ch:
		for x in cw:
			var idx: int = y * cw + x
			if is_solid[idx] == 0 or visited[idx] == 1:
				continue
			## Maximal rectangle starting at (x,y).
			var w: int = 1
			while x + w < cw and is_solid[idx + w] == 1 and visited[idx + w] == 0:
				w += 1
			var h: int = 1
			while y + h < ch:
				var row_ok: bool = true
				var row_start: int = (y + h) * cw + x
				for dx in w:
					if is_solid[row_start + dx] == 0 or visited[row_start + dx] == 1:
						row_ok = false
						break
				if not row_ok:
					break
				h += 1
			## Mark cells visited.
			for dy in h:
				for dx in w:
					visited[(y + dy) * cw + x + dx] = 1
			_spawn_wall_body(x * grid_size, y * grid_size, w * grid_size, h * grid_size)


func _spawn_wall_body(px: int, py: int, w: int, h: int) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(px + w * 0.5, py + h * 0.5)
	body.collision_layer = WALL_COLLISION_LAYER
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	col.shape = shape
	body.add_child(col)
	add_child(body)
	_collision_bodies.append(body)


# ─── Entity dispatch ──────────────────────────────────────────────────────────

func _apply_level_instructions(ent: Dictionary, result: Dictionary) -> void:
	var fields: Dictionary = _ent_fields_to_dict(ent)
	## Numeric defaults are set in _empty_result; only overwrite when present.
	result.level_name = fields.get("Level_Name", "")
	result.monster_spawns = fields.get("Monster_Spawns", "")
	result.boss_id = fields.get("Boss_Spawn", "")
	result.loot_pool = fields.get("Loot_Pool", "")
	result.music_id = fields.get("Music_Id", "")
	result.recommended_player_level = int(fields.get("Recommended_Player_Level", 1))

	var tags_raw: Variant = fields.get("Tags", [])
	if tags_raw is Array:
		for t in tags_raw:
			if t != null:
				result.tags.append(str(t))

	var notes_raw: Variant = fields.get("Misc_Notes", [])
	if notes_raw is Array:
		for n in notes_raw:
			if n != null:
				result.misc_notes.append(str(n))

	var overrides_raw: Variant = fields.get("Misc_Overrides", [])
	if overrides_raw is Array:
		for kv in overrides_raw:
			_apply_misc_override(str(kv) if kv != null else "", result)

	if fields.has("Player_Spawn_Pos"):
		result.player_spawn_pos = _grid_point_to_pos(fields["Player_Spawn_Pos"], ent)
	if fields.has("Player_Facing"):
		result.player_facing = str(fields["Player_Facing"])
	if fields.has("Boss_Spawn_Pos") and fields["Boss_Spawn_Pos"] != null:
		result.boss_spawn_pos = _grid_point_to_pos(fields["Boss_Spawn_Pos"], ent)
	result.boss_intro_delay = float(fields.get("Boss_Intro_Delay", 1.5))
	result.boss_camera_zoom = float(fields.get("Boss_Camera_Zoom", 1.0))
	if fields.has("Level_Exit_Pos") and fields["Level_Exit_Pos"] != null:
		result.level_exit_pos = _grid_point_to_pos(fields["Level_Exit_Pos"], ent)
	result.next_level_id = fields.get("Next_Level_Id", "")
	result.exit_transition = fields.get("Exit_Transition", "Fade")

	## Cross-field consistency checks.
	if result.boss_id != "" and is_nan(result.boss_spawn_pos.x):
		_warn(result, "Boss_Spawn='%s' set but Boss_Spawn_Pos is unset — boss will not spawn." % result.boss_id)
	if result.boss_id == "" and not is_nan(result.boss_spawn_pos.x):
		_warn(result, "Boss_Spawn_Pos set but Boss_Spawn id is empty — point will be ignored.")


func _apply_misc_override(kv: String, result: Dictionary) -> void:
	if kv == "":
		return
	var eq: int = kv.find("=")
	if eq < 1:
		_warn(result, "Misc_Override '%s' is not key=value — ignoring." % kv)
		return
	var key: String = kv.substr(0, eq).strip_edges()
	var val: String = kv.substr(eq + 1).strip_edges()
	const KNOWN: Array = ["difficulty", "phase_timer_1", "phase_timer_2", "phase_timer_3",
		"phase_timer_4", "phase_timer_5", "seed", "xp_multiplier", "extraction_reward_multiplier"]
	if not KNOWN.has(key):
		_warn(result, "Unknown Misc_Override key '%s' — caller will see it but should ignore." % key)
	## Coerce to number when the string parses cleanly; otherwise keep string.
	if val.is_valid_int():
		result.misc_overrides[key] = val.to_int()
	elif val.is_valid_float():
		result.misc_overrides[key] = val.to_float()
	else:
		result.misc_overrides[key] = val


func _collect_region(ent: Dictionary, result: Dictionary) -> void:
	var fields: Dictionary = _ent_fields_to_dict(ent)
	result.regions.append({
		"kind": str(fields.get("kind", "Maze")),
		"id": str(fields.get("id", "")),
		"rect": _ent_bbox(ent),
		"enter_seal": bool(fields.get("enter_seal", false)),
		"kill_quota": int(fields.get("kill_quota", 0)),
		"timer_seconds": float(fields.get("timer_seconds", 0.0)),
	})


func _collect_extraction(ent: Dictionary, result: Dictionary) -> void:
	var fields: Dictionary = _ent_fields_to_dict(ent)
	result.extractions.append({
		"kind": str(fields.get("kind", "Timed")),
		"position": _ent_bbox(ent).get_center(),
		"unlock_radius": float(fields.get("unlock_radius", 48.0)),
		"channel_seconds": float(fields.get("channel_seconds", 3.0)),
		"notes": str(fields.get("notes", "")),
	})


func _collect_spawn_zone(ent: Dictionary, result: Dictionary) -> void:
	var fields: Dictionary = _ent_fields_to_dict(ent)
	result.spawn_zones.append({
		"phase": str(fields.get("phase", "Any")),
		"density": str(fields.get("density", "Medium")),
		"rect": _ent_bbox(ent),
		"enemy_pool_override": str(fields.get("enemy_pool_override", "")),
		"min_distance_from_player": float(fields.get("min_distance_from_player", 300.0)),
	})


func _collect_obstacle(ent: Dictionary, result: Dictionary) -> void:
	var fields: Dictionary = _ent_fields_to_dict(ent)
	## Obstacle pivots at bottom-center (0.5,1.0); px is the ground point clicked.
	var pos: Vector2 = _ent_px(ent)
	var info: Dictionary = {
		"kind": str(fields.get("kind", "Rock")),
		"position": pos,
		"variant_index": int(fields.get("variant_index", 0)),
		"collision_radius": float(fields.get("collision_radius", 18.0)),
		"scale": float(fields.get("scale", 3.0)),
	}
	result.obstacles.append(info)
	_spawn_obstacle_node(info)


func _collect_marker(ent: Dictionary, result: Dictionary) -> void:
	var fields: Dictionary = _ent_fields_to_dict(ent)
	var info: Dictionary = {
		"tag": str(fields.get("tag", "LootSpawn")),
		"id": str(fields.get("id", "")),
		"position": _ent_bbox(ent).get_center(),
		"payload": str(fields.get("payload", "")),
	}
	result.markers.append(info)
	marker_loaded.emit(info.tag, info.id, info.position, info.payload)


# ─── Obstacle spawning (placeholder — sprite mapping TBD) ─────────────────────

func _spawn_obstacle_node(info: Dictionary) -> void:
	## Placeholder visual: solid-color rect sized by ObstacleKind. Replace with sprite
	## lookup once LdtkObstacleData is built (per docs/ldtk_schema.md §10).
	var body := StaticBody2D.new()
	body.position = info.position
	body.collision_layer = WALL_COLLISION_LAYER
	body.collision_mask = 0
	var radius: float = info.collision_radius
	if radius > 0.0:
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = radius
		col.shape = shape
		body.add_child(col)
	var stub := ColorRect.new()
	var size: float = max(radius * 2.0, 16.0)
	stub.size = Vector2(size, size)
	stub.position = Vector2(-size * 0.5, -size * 0.5)
	stub.color = _obstacle_placeholder_color(info.kind)
	body.add_child(stub)
	add_child(body)
	_obstacle_nodes.append(body)


func _obstacle_placeholder_color(kind: String) -> Color:
	match kind:
		"Rock":       return Color(0.42, 0.40, 0.38)
		"Crate":      return Color(0.55, 0.38, 0.20)
		"Pillar":     return Color(0.65, 0.62, 0.55)
		"Bones":      return Color(0.85, 0.82, 0.70)
		"Tree":       return Color(0.18, 0.42, 0.22)
		"Stalagmite": return Color(0.30, 0.28, 0.36)
		_:            return Color(0.50, 0.50, 0.50)


# ─── Entity field helpers ─────────────────────────────────────────────────────

func _ent_fields_to_dict(ent: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for fi in ent.get("fieldInstances", []):
		out[fi.get("__identifier", "")] = fi.get("__value", null)
	return out


func _ent_px(ent: Dictionary) -> Vector2:
	## LDtk's `px` is the entity's PIVOT point in level pixel space (NOT the
	## top-left). For Obstacle (pivot 0.5,1.0) this is the bottom-center ground
	## point the author clicked — exactly where we want the collider.
	var px: Array = ent.get("px", [0, 0])
	return Vector2(float(px[0]), float(px[1]))


func _ent_bbox(ent: Dictionary) -> Rect2:
	## Pivot-correct bounding box. top_left = px - (pivotX*w, pivotY*h).
	var px: Vector2 = _ent_px(ent)
	var w: float = float(ent.get("width", 0))
	var h: float = float(ent.get("height", 0))
	var ed: Dictionary = _entity_uid_to_def.get(int(ent.get("defUid", 0)), {})
	var pivot_x: float = float(ed.get("pivotX", 0.0))
	var pivot_y: float = float(ed.get("pivotY", 0.0))
	return Rect2(px.x - pivot_x * w, px.y - pivot_y * h, w, h)


func _grid_point_to_pos(point_value: Variant, ent: Dictionary) -> Vector2:
	## Point fields serialize as {"cx": int, "cy": int}. Convert to pixel center of the cell.
	if point_value == null or not (point_value is Dictionary):
		return Vector2(NAN, NAN)
	var pv: Dictionary = point_value
	## Grid size lives on the layer the entity belongs to; entities also have __grid in pixels
	## but the Point value is in grid cells. Use the entity's __grid + width/height to derive
	## cell size, falling back to 8 (project default).
	var grid: int = 8
	var ent_grid: Array = ent.get("__grid", [])
	var ent_px: Array = ent.get("px", [])
	if ent_grid.size() == 2 and ent_px.size() == 2 and int(ent_grid[0]) > 0:
		grid = int(round(float(ent_px[0]) / float(ent_grid[0]))) if int(ent_grid[0]) > 0 else 8
		if grid <= 0:
			grid = 8
	return Vector2(int(pv.get("cx", 0)) * grid + grid * 0.5, int(pv.get("cy", 0)) * grid + grid * 0.5)


# ─── Validation ───────────────────────────────────────────────────────────────

func _validate_regions(result: Dictionary) -> void:
	if result.regions.is_empty():
		_warn(result, "Level has no Region entities — gameplay rules (spawn / boss seal) will not apply.")
		return
	## Sort by top-Y and check no-gap top→bottom tiling. We tolerate ±1 px rounding.
	var sorted: Array = result.regions.duplicate()
	sorted.sort_custom(func(a, b): return a.rect.position.y < b.rect.position.y)
	var prev_bottom: float = sorted[0].rect.position.y
	for r in sorted:
		var top: float = r.rect.position.y
		if abs(top - prev_bottom) > 1.0:
			_warn(result, "Region '%s' (%s) does not tile cleanly with its neighbour above (gap=%.1fpx)." % [r.id, r.kind, top - prev_bottom])
		prev_bottom = r.rect.position.y + r.rect.size.y
	var boss_count: int = 0
	for r in result.regions:
		if r.kind == "Boss":
			boss_count += 1
	if boss_count > 1:
		_warn(result, "Level has %d Boss regions — schema expects exactly 1." % boss_count)


func _validate_extractions(result: Dictionary) -> void:
	for e in result.extractions:
		var inside: bool = false
		for r in result.regions:
			if (r.kind == "Maze" or r.kind == "Boss") and (r.rect as Rect2).has_point(e.position):
				inside = true
				break
		if not inside and not result.regions.is_empty():
			_warn(result, "Extraction (%s) at %s is not inside any Maze/Boss region." % [e.kind, e.position])


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _clear_children() -> void:
	for n in _tilemap_layers:
		if is_instance_valid(n):
			n.queue_free()
	for n in _collision_bodies:
		if is_instance_valid(n):
			n.queue_free()
	for n in _obstacle_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_tilemap_layers.clear()
	_collision_bodies.clear()
	_obstacle_nodes.clear()
