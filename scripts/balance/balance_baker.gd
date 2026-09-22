class_name BalanceBaker
extends RefCounted

## BalanceBaker — write tuned values back into the .gd source they came from.
##
## ── Why bake at all ───────────────────────────────────────────────────────────
##
## The override layer ships and is authoritative, so a tuned game works perfectly well
## without ever baking. What baking buys is that `data/characters.gd` keeps telling the
## truth. Without it, the source slowly becomes a set of numbers nobody plays with, and
## every future reader — including future sessions of this work — reasons from values the
## game does not use. Baking also makes a tuning pass a normal, reviewable `git diff`
## instead of an opaque JSON blob.
##
## ── What it can and cannot reach ──────────────────────────────────────────────
##
## Bakeable, because the value is a literal in a table:
##   character/*      data/characters.gd
##   weapon/*         data/weapons.gd
##   player_stat/_global/*   player.gd BASE_STATS
##   enemy/*          data/factories/enemies/*.gd
##   difficulty/*     game_manager.gd + enemy_spawn_manager.gd
##
## NOT bakeable, and reported rather than silently dropped:
##   chain/*          the numbers are built by code in chain_factory.gd / skill_factory.gd,
##                    not written as a table — there is no literal to rewrite
##   player_stat/<character>/*   source has no per-character stat sheet; CharacterData only
##                    carries hp/armor/speed, so there is nowhere to put the other 50
##   hitbox/*         lives in scenes/player.tscn, and CLAUDE.md forbids hand-editing .tscn
##                    (it silently strips unowned nodes and loses font UIDs)
##
## Anything not baked stays in the override file and keeps working. The report says which,
## so "I baked and half my tuning vanished" cannot happen quietly.
##
## ── Safety ────────────────────────────────────────────────────────────────────
##
## Every rewrite requires EXACTLY ONE unambiguous match for the literal being replaced. Zero
## matches or several, and that value is skipped and reported rather than guessed at. The
## project is a git repo: `git diff` after a bake is the real review step, and the editor's
## status line says so.

const CHARACTERS: String = "res://data/characters.gd"
const WEAPONS: String = "res://data/weapons.gd"
const PLAYER: String = "res://scripts/entities/player.gd"
const GAME_MANAGER: String = "res://scripts/managers/game_manager.gd"
const SPAWN_MANAGER: String = "res://scripts/managers/enemy_spawn_manager.gd"
const ENEMY_DIR: String = "res://data/factories/enemies/"


## Bake every bakeable override, clear those paths, and leave the rest alone.
## Returns { written: int, files: int, skipped: Array[String] }.
static func bake() -> Dictionary:
	## Two distinct maps, and the distinction matters. `edits` is a READ CACHE — locating
	## which of 24 enemy factories owns an id means opening most of them — while `touched`
	## is the set that actually changed. Writing everything in the read cache would rewrite
	## a dozen untouched files per bake: same bytes, but new mtimes, which makes Godot offer
	## "files modified outside" on files nobody edited and makes the report lie about scope.
	var edits: Dictionary = {}          ## file path -> source text (read cache)
	var touched: Dictionary = {}        ## file path -> true (actually rewritten)
	var baked: Array[String] = []
	var skipped: Array[String] = []

	for path: String in BalanceOverrides.overridden_paths():
		var parts: PackedStringArray = path.split("/")
		if parts.size() < 2:
			skipped.append("%s (malformed path)" % path)
			continue
		var domain: String = parts[0]
		var ok: bool = false
		match domain:
			"character":
				ok = _bake_character(edits, touched, path, parts)
			"weapon":
				ok = _bake_weapon(edits, touched, path, parts)
			"player_stat":
				ok = _bake_player_stat(edits, touched, path, parts, skipped)
			"enemy":
				ok = _bake_enemy(edits, touched, path, parts)
			"difficulty":
				ok = _bake_difficulty(edits, touched, path, parts)
			"chain":
				skipped.append("%s — combo phases are built in code, not a table" % path)
				continue
			"hitbox":
				skipped.append("%s — lives in scenes/player.tscn, which must not be hand-edited" % path)
				continue
			_:
				skipped.append("%s (unknown domain '%s')" % [path, domain])
				continue
		if ok:
			baked.append(path)
		elif not _already_reported(skipped, path):
			skipped.append("%s — no single unambiguous literal to rewrite" % path)

	if baked.is_empty():
		return {"written": 0, "files": 0, "skipped": skipped}

	for file_path: String in touched.keys():
		var f := FileAccess.open(file_path, FileAccess.WRITE)
		if f == null:
			push_warning("BalanceBaker: cannot write %s" % file_path)
			return {"written": 0, "files": 0,
				"skipped": skipped + ["could not write %s — nothing was baked" % file_path]}
		f.store_string(str(edits[file_path]))
		f.close()

	## Only clear what actually made it into source. A path that was skipped keeps its
	## override, so the tuned game is unchanged by baking either way.
	for path: String in baked:
		BalanceOverrides.clear_value(path)
	BalanceOverrides.save()

	return {"written": baked.size(), "files": touched.size(), "skipped": skipped}


static func _already_reported(skipped: Array[String], path: String) -> bool:
	for s: String in skipped:
		if s.begins_with(path):
			return true
	return false


static func _source(edits: Dictionary, file_path: String) -> String:
	if edits.has(file_path):
		return str(edits[file_path])
	if not FileAccess.file_exists(file_path):
		return ""
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	edits[file_path] = text
	return text


# ─── Number formatting ────────────────────────────────────────────────────────

## Render a value the way the surrounding source writes numbers: if the literal being
## replaced had a decimal point, keep one, so a float table does not sprout bare ints and
## start inferring `int` on the next read.
static func _num(value: float, was_float: bool) -> String:
	if not was_float:
		return str(int(round(value)))
	if is_equal_approx(value, round(value)):
		return "%.1f" % value
	var s: String = "%.4f" % value
	## Trim trailing zeros but always leave one decimal.
	while s.ends_with("0") and not s.ends_with(".0"):
		s = s.substr(0, s.length() - 1)
	return s


# ─── Table entry spans ────────────────────────────────────────────────────────

## The [start, end) character span of one top-level entry in a `const ALL` table — the
## region between `\n\t"<id>": {` and the next entry at that indent (or the table's end).
##
## Computed from the actual entry starts rather than from an id pattern, so it does not
## care what characters or weapons are called.
static func _entry_span(src: String, entry_id: String) -> Vector2i:
	var re := RegEx.new()
	re.compile('\\n\\t"([^"\\n]+)":\\s*\\{')
	var matches: Array[RegExMatch] = re.search_all(src)
	for i in range(matches.size()):
		var m: RegExMatch = matches[i]
		if m.get_string(1) != entry_id:
			continue
		var start: int = m.get_start()
		var end: int = src.length()
		if i + 1 < matches.size():
			end = matches[i + 1].get_start()
		return Vector2i(start, end)
	return Vector2i(-1, -1)


## Replace `"<key>": <number>` inside [span], requiring exactly one match.
## Returns the new source, or "" when the match was not unique.
static func _replace_key_in_span(src: String, span: Vector2i, key: String, value: float) -> String:
	if span.x < 0:
		return ""
	var region: String = src.substr(span.x, span.y - span.x)
	var re := RegEx.new()
	re.compile('("%s"\\s*:\\s*)(-?\\d+(\\.\\d+)?)' % key)
	var found: Array[RegExMatch] = re.search_all(region)
	if found.size() != 1:
		return ""
	var m: RegExMatch = found[0]
	var was_float: bool = m.get_string(2).contains(".")
	var replaced: String = region.substr(0, m.get_start(2)) + _num(value, was_float) \
			+ region.substr(m.get_end(2))
	return src.substr(0, span.x) + replaced + src.substr(span.y)


## Replace a standalone `<prefix><number>` assignment, requiring exactly one match.
static func _replace_assignment(src: String, pattern: String, value: float) -> String:
	var re := RegEx.new()
	re.compile(pattern)
	var found: Array[RegExMatch] = re.search_all(src)
	if found.size() != 1:
		return ""
	var m: RegExMatch = found[0]
	var lit: String = m.get_string(m.get_group_count())
	var was_float: bool = lit.contains(".")
	return src.substr(0, m.get_start(m.get_group_count())) + _num(value, was_float) \
			+ src.substr(m.get_end(m.get_group_count()))


# ─── Per-domain bakers ────────────────────────────────────────────────────────

static func _bake_character(edits: Dictionary, touched: Dictionary, path: String,
		parts: PackedStringArray) -> bool:
	if parts.size() != 3:
		return false
	var src: String = _source(edits, CHARACTERS)
	if src.is_empty():
		return false
	var out: String = _replace_key_in_span(src, _entry_span(src, parts[1]), parts[2],
			BalanceOverrides.get_float(path, 0.0))
	if out.is_empty():
		return false
	edits[CHARACTERS] = out
	touched[CHARACTERS] = true
	return true


static func _bake_weapon(edits: Dictionary, touched: Dictionary, path: String,
		parts: PackedStringArray) -> bool:
	if parts.size() != 3:
		return false
	var src: String = _source(edits, WEAPONS)
	if src.is_empty():
		return false
	var out: String = _replace_key_in_span(src, _entry_span(src, parts[1]), parts[2],
			BalanceOverrides.get_float(path, 0.0))
	if out.is_empty():
		return false
	edits[WEAPONS] = out
	touched[WEAPONS] = true
	return true


## Only the GLOBAL baseline can be baked — see the header. A per-character stat has no
## home in source, so it is reported with the reason rather than counted as a failure.
static func _bake_player_stat(edits: Dictionary, touched: Dictionary, path: String,
		parts: PackedStringArray, skipped: Array[String]) -> bool:
	if parts.size() != 3:
		return false
	if parts[1] != BalanceOverrides.GLOBAL:
		skipped.append(("%s — per-character stat sheets have no home in source "
			+ "(CharacterData carries only hp/armor/speed); kept as an override") % path)
		return false
	var src: String = _source(edits, PLAYER)
	if src.is_empty():
		return false
	var anchor: int = src.find("const BASE_STATS: Dictionary = {")
	if anchor < 0:
		return false
	var close: int = src.find("\n}", anchor)
	if close < 0:
		return false
	var out: String = _replace_key_in_span(src, Vector2i(anchor, close + 2), parts[2],
			BalanceOverrides.get_float(path, 0.0))
	if out.is_empty():
		return false
	edits[PLAYER] = out
	touched[PLAYER] = true
	return true


## Enemies live one-per-factory-function across 24 files. The function that owns an id is
## the one containing `def.enemy_id = "<id>"`; the rewrite is bounded to that function so a
## file holding a dozen `create_*` variants cannot cross-contaminate.
static func _bake_enemy(edits: Dictionary, touched: Dictionary, path: String,
		parts: PackedStringArray) -> bool:
	if parts.size() != 3:
		return false
	var enemy_id: String = parts[1]
	var field: String = parts[2]
	var value: float = BalanceOverrides.get_float(path, 0.0)

	var file_path: String = _enemy_file_for(edits, enemy_id)
	if file_path.is_empty():
		return false
	var src: String = _source(edits, file_path)
	var span: Vector2i = _enemy_fn_span(src, enemy_id)
	if span.x < 0:
		return false
	var region: String = src.substr(span.x, span.y - span.x)

	var re := RegEx.new()
	if field == "max_hp":
		## Lives inside the base_stats dictionary literal rather than as a property.
		re.compile('("max_hp"\\s*:\\s*)(-?\\d+(\\.\\d+)?)')
	else:
		re.compile('(def\\.%s\\s*=\\s*)(-?\\d+(\\.\\d+)?)' % field)
	var found: Array[RegExMatch] = re.search_all(region)
	if found.size() != 1:
		return false
	var m: RegExMatch = found[0]
	var was_float: bool = m.get_string(2).contains(".")
	var replaced: String = region.substr(0, m.get_start(2)) + _num(value, was_float) \
			+ region.substr(m.get_end(2))
	edits[file_path] = src.substr(0, span.x) + replaced + src.substr(span.y)
	touched[file_path] = true
	return true


## Locating the id assignment needs a REGEX, not a string find.
##
## Most factories align their assignments (`def.enemy_id       = "crypt_ghost"`) while a few
## do not (`def.enemy_id = "fodder"`). A literal single-space search finds only the second
## kind, which made the baker quietly refuse ~60 of the 71 enemies while reporting them as
## "no unambiguous literal" — a true-sounding message for the wrong reason.
static func _enemy_id_regex(enemy_id: String) -> RegEx:
	var re := RegEx.new()
	re.compile('def\\.enemy_id\\s*=\\s*"%s"' % enemy_id)
	return re


static func _enemy_file_for(edits: Dictionary, enemy_id: String) -> String:
	var dir := DirAccess.open(ENEMY_DIR)
	if dir == null:
		return ""
	var re: RegEx = _enemy_id_regex(enemy_id)
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var full: String = ENEMY_DIR + file_name
		if re.search(_source(edits, full)) != null:
			return full
	return ""


## The span of the `static func` that sets this enemy's id, from its `static func` line to
## the next one (or end of file).
static func _enemy_fn_span(src: String, enemy_id: String) -> Vector2i:
	var id_match: RegExMatch = _enemy_id_regex(enemy_id).search(src)
	if id_match == null:
		return Vector2i(-1, -1)
	var at: int = id_match.get_start()
	var re := RegEx.new()
	re.compile("(?m)^static func ")
	var matches: Array[RegExMatch] = re.search_all(src)
	var start: int = 0
	var end: int = src.length()
	for i in range(matches.size()):
		var s: int = matches[i].get_start()
		if s <= at:
			start = s
			end = matches[i + 1].get_start() if i + 1 < matches.size() else src.length()
		else:
			break
	return Vector2i(start, end)


static func _bake_difficulty(edits: Dictionary, touched: Dictionary, path: String,
		parts: PackedStringArray) -> bool:
	if parts.size() != 2:
		return false
	var key: String = parts[1]
	var value: float = BalanceOverrides.get_float(path, 0.0)

	if key.begins_with("phase_duration_"):
		return _bake_array_slot(edits, touched, GAME_MANAGER, "PHASE_DURATIONS",
				int(key.trim_prefix("phase_duration_")), value)
	if key.begins_with("hp_mult_"):
		return _bake_array_slot(edits, touched, SPAWN_MANAGER, "PHASE_HP_MULT",
				int(key.trim_prefix("hp_mult_")), value)
	if key.begins_with("spawn_mult_"):
		return _bake_array_slot(edits, touched, SPAWN_MANAGER, "PHASE_SPAWN_MULT",
				int(key.trim_prefix("spawn_mult_")), value)

	match key:
		"scale_period":
			return _bake_simple(edits, touched, GAME_MANAGER,
					"(const DIFFICULTY_SCALE_PERIOD: float = )(-?\\d+(\\.\\d+)?)", value)
		"scale_rate":
			return _bake_simple(edits, touched, GAME_MANAGER,
					"(const DIFFICULTY_SCALE_RATE: float = )(-?\\d+(\\.\\d+)?)", value)
		"max_enemies":
			return _bake_simple(edits, touched, SPAWN_MANAGER,
					"(var max_enemies: int = )(-?\\d+)", value)
	return false


static func _bake_simple(edits: Dictionary, touched: Dictionary, file_path: String,
		pattern: String, value: float) -> bool:
	var src: String = _source(edits, file_path)
	if src.is_empty():
		return false
	var re := RegEx.new()
	re.compile(pattern)
	var found: Array[RegExMatch] = re.search_all(src)
	if found.size() != 1:
		return false
	var m: RegExMatch = found[0]
	var was_float: bool = m.get_string(2).contains(".")
	edits[file_path] = src.substr(0, m.get_start(2)) + _num(value, was_float) + src.substr(m.get_end(2))
	touched[file_path] = true
	return true


## Rewrite one slot of a `const NAME: Array = [a, b, c]` literal, preserving the others and
## the original spacing around the `=`.
static func _bake_array_slot(edits: Dictionary, touched: Dictionary, file_path: String,
		const_name: String, idx: int, value: float) -> bool:
	var src: String = _source(edits, file_path)
	if src.is_empty():
		return false
	var re := RegEx.new()
	re.compile("(const %s: Array\\s*=\\s*\\[)([^\\]]*)(\\])" % const_name)
	var found: Array[RegExMatch] = re.search_all(src)
	if found.size() != 1:
		return false
	var m: RegExMatch = found[0]
	var body: String = m.get_string(2)
	var items: PackedStringArray = body.split(",")
	if idx < 0 or idx >= items.size():
		return false
	var was_float: bool = items[idx].contains(".")
	## Keep the original leading whitespace so the table stays aligned.
	var lead: String = ""
	for i in range(items[idx].length()):
		if items[idx][i] == " " or items[idx][i] == "\t":
			lead += items[idx][i]
		else:
			break
	items[idx] = lead + _num(value, was_float)
	edits[file_path] = src.substr(0, m.get_start(2)) + ",".join(items) + src.substr(m.get_end(2))
	touched[file_path] = true
	return true
