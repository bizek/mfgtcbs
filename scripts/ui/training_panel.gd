extends CanvasLayer

## TrainingPanel — the training room's control deck (GameManager.training_mode).
##
## A flat arena with no clock, no waves and no extraction: dummies stand still and take hits so
## abilities can be read frame by frame. Built after Ben's 2026-07-20 pass, where a full run was
## needed to test one channel — and Reckoning couldn't be tested at all, because its own tick
## damage killed everything before the dome could soak a hit.
##
## Controls (panel is always visible here; F11 hides it):
##   CLASS ◀ ▶     swap character live — sprite, kit, weapon, passives all rebuild
##   DUMMIES       respawn the stationary row (they never die: HP tops back up)
##   HIT BACK      dummies deal contact damage — the only way to charge Guard / Reckoning
##   PACK          spawn live chasing fodder for pathing / AoE / knockback tests
##   CLEAR         remove every enemy
##   SLOW-MO       0.25x time — pairs with the Animation Lab (F10) for reading hit frames
##   HEAL          top the player back up
## The readout tracks damage dealt: total, DPS over the last 5s, and best single hit.

const DUMMY_SCENE_PATH: String = "res://scenes/enemies/fodder.tscn"
const DUMMY_COUNT: int = 5
const DUMMY_SPACING: float = 58.0
const DUMMY_HP: float = 1.0e9        ## effectively unkillable; HP is topped back up each frame
const DUMMY_ROW_OFFSET: Vector2 = Vector2(0.0, -110.0)
const PACK_SIZE: int = 8
const DPS_WINDOW: float = 5.0
const SLOW_SCALE: float = 0.25
const FS: int = 11        ## body font size (matches DebugPanel)
const FS_TITLE: int = 12

## The panel sits at y=45 in a 360px viewport, so this is what is left with a small margin.
const PANEL_W: float = 170.0
const PANEL_MAX_H: float = 290.0

var player_ref: Node2D = null
var arena_ref: Node2D = null

var _panel: PanelContainer = null
var _class_label: Label = null
var _dps_label: Label = null
var _total_label: Label = null
var _hit_back_btn: Button = null
var _slow_btn: Button = null
var _audit_label: Label = null

var _dummies: Array[Node2D] = []
var _hit_back: bool = false
var _slow: bool = false
## Rolling damage log: [timestamp_sec, amount] pairs inside the DPS window.
var _damage_log: Array = []
var _total_damage: float = 0.0
var _best_hit: float = 0.0
var _char_ids: Array = []
var _reloading: bool = false   ## class swap reloads the room — keep training_mode set
var _mod_rows: Array[Label] = []
var _mod_hint: Label = null


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_char_ids = CharacterData.ALL.keys()
	_build_panel()
	EventBus.on_hit_dealt.connect(_on_hit_dealt)


func setup(player: Node2D, arena: Node2D) -> void:
	player_ref = player
	arena_ref = arena
	_refresh_class_label()
	call_deferred("_spawn_dummies")


func _exit_tree() -> void:
	## Never leave the engine in slow motion or the flag set for the next real run —
	## unless we're the ones reloading the room for a class swap.
	Engine.time_scale = 1.0
	if not _reloading:
		GameManager.training_mode = false


## Tell the panel it is being torn down to be REPLACED by another training session, not to leave
## the room — so _exit_tree keeps GameManager.training_mode set.
##
## Without this, re-entering the training room while already inside it silently starts a REAL RUN:
## change_scene_to_file() frees this scene before the new one's _ready(), so our _exit_tree clears
## the flag on the way out and main_arena._ready() then builds waves, a phase clock and an
## extraction. Setting training_mode = true before the scene change does not help — we run after it.
## (Cost a live playtest, Ben 2026-07-26. See CLAUDE.md "In-Game Testing".)
func keep_training_mode() -> void:
	_reloading = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_panel.visible = not _panel.visible


func _process(_delta: float) -> void:
	## Dummies are immortal sandbags: keep them topped up and rooted.
	var now: float = Time.get_ticks_msec() / 1000.0
	for d in _dummies:
		if not is_instance_valid(d):
			continue
		if d.health:
			d.health.current_hp = d.health.max_hp
			d.health.is_dead = false
		d.is_alive = true
		d.contact_damage = 12.0 if _hit_back else 0.0

	## Rolling DPS over the trailing window.
	var cutoff: float = now - DPS_WINDOW
	while not _damage_log.is_empty() and float(_damage_log[0][0]) < cutoff:
		_damage_log.pop_front()
	var windowed: float = 0.0
	for entry in _damage_log:
		windowed += float(entry[1])
	if _dps_label:
		_dps_label.text = "DPS %0.0f   best %0.0f" % [windowed / DPS_WINDOW, _best_hit]
	if _total_label:
		_total_label.text = "total %0.0f" % _total_damage


func _on_hit_dealt(source: Node2D, _target: Node2D, hit_data) -> void:
	if source != player_ref:
		return
	var amount: float = hit_data.amount if hit_data is HitData else 0.0
	if amount <= 0.0:
		return
	_total_damage += amount
	_best_hit = maxf(_best_hit, amount)
	_damage_log.append([Time.get_ticks_msec() / 1000.0, amount])


# ─── Panel ────────────────────────────────────────────────────────────────────

func _build_panel() -> void:
	var pc := PanelContainer.new()
	pc.position = Vector2(5.0, 45.0)
	_panel = pc
	add_child(pc)
	## Vector font for the whole subtree — see DebugUI for why this is now explicit.
	## Without it the FS/FS_TITLE sizes below render in m5x7 under its 16px native
	## grid, where glyphs fuse: "PACK" reads as "FACh".
	DebugUI.use_vector_font(pc)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.07, 0.05, 0.93)
	bg.set_corner_radius_all(3)
	bg.set_content_margin_all(5.0)
	pc.add_theme_stylebox_override("panel", bg)

	## Scrolled, because the deck now carries a mod bench and level-up controls on top of the
	## original rows and would otherwise run past the 360px viewport. SHOW_AS_NEEDED per
	## CLAUDE.md — SHOW_NEVER clips instead of scrolling, which hides controls silently.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PANEL_W, PANEL_MAX_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	pc.add_child(scroll)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	v.add_child(_label("TRAINING ROOM  (F11)", FS_TITLE, Color(0.5, 1.0, 0.5)))

	## Class swap row.
	var class_row := HBoxContainer.new()
	class_row.add_theme_constant_override("separation", 3)
	v.add_child(class_row)
	class_row.add_child(_button("<", func() -> void: _cycle_class(-1), 20.0))
	_class_label = _label("", FS, Color(1.0, 1.0, 1.0))
	_class_label.custom_minimum_size = Vector2(118.0, 0.0)
	_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_row.add_child(_class_label)
	class_row.add_child(_button(">", func() -> void: _cycle_class(1), 20.0))

	_dps_label = _label("DPS 0   best 0", FS, Color(1.0, 0.85, 0.4))
	v.add_child(_dps_label)
	_total_label = _label("total 0", FS, Color(0.75, 0.75, 0.8))
	v.add_child(_total_label)
	v.add_child(_button("RESET METER", _reset_meter))

	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 3)
	v.add_child(r1)
	r1.add_child(_button("DUMMIES", _spawn_dummies))
	_hit_back_btn = _button("HIT BACK: OFF", _toggle_hit_back)
	r1.add_child(_hit_back_btn)

	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 3)
	v.add_child(r2)
	r2.add_child(_button("PACK", _spawn_pack))
	r2.add_child(_button("CLEAR", _clear_enemies))

	var r3 := HBoxContainer.new()
	r3.add_theme_constant_override("separation", 3)
	v.add_child(r3)
	_slow_btn = _button("SLOW-MO: OFF", _toggle_slow)
	r3.add_child(_slow_btn)
	r3.add_child(_button("HEAL", _heal_player))

	## ── Level up ─────────────────────────────────────────────────────────────
	## Dummies are unkillable by design, so no kill ever pays XP and the level-up screen is
	## otherwise unreachable in here without opening the F1 panel. These grant exactly enough
	## XP to cross the threshold, the same arithmetic debug_panel uses.
	v.add_child(_label("── LEVEL UP ──", FS, Color(0.55, 0.85, 1.0)))
	var lv := HBoxContainer.new()
	lv.add_theme_constant_override("separation", 3)
	v.add_child(lv)
	lv.add_child(_button("LEVEL +1", func() -> void: _grant_levels(1)))
	lv.add_child(_button("LEVEL +5", func() -> void: _grant_levels(5)))

	## ── Mod bench ────────────────────────────────────────────────────────────
	## Three slots, each cycling this character's own roster of eight plus empty. Swaps apply
	## live via player.debug_reload_mods(), so a mod can be judged without leaving the room.
	v.add_child(_label("── MODS ──", FS, Color(1.0, 0.75, 0.4)))
	_mod_rows.clear()
	for slot in range(ProgressionManager.class_mod_slots()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		v.add_child(row)
		row.add_child(_button("<", func() -> void: _cycle_mod(slot, -1), 16.0))
		var lbl := _label("", FS, Color(1.0, 0.88, 0.6))
		lbl.custom_minimum_size = Vector2(120.0, 0.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.clip_text = true
		row.add_child(lbl)
		row.add_child(_button(">", func() -> void: _cycle_mod(slot, 1), 16.0))
		_mod_rows.append(lbl)

	v.add_child(_button("GRANT ALL MODS", _grant_all_mods))
	_mod_hint = _label("", FS, Color(0.6, 0.75, 0.6))
	v.add_child(_mod_hint)

	## AUDIT TIMING sits BELOW the mod bench on purpose. The panel scrolls, and whatever is
	## last is what falls off the fold — the bench is used every session, the timing audit
	## occasionally, so the audit is the one that should need a scroll.
	v.add_child(_button("AUDIT TIMING", _audit_timing))
	_audit_label = _label("", FS, Color(0.75, 0.8, 0.85))
	v.add_child(_audit_label)

	v.add_child(_label("F10 anim lab · F1 debug", FS, Color(0.55, 0.6, 0.65)))
	_refresh_mod_rows()


## Godot's built-in VECTOR font, applied to the panel root by DebugUI.use_vector_font().
## The m5x7 pixel font below its native 16px size renders illegibly at this viewport
## scale (Ben, 2026-07-20). That used to happen for free because the engine default was
## a vector face; since the project Theme landed (2026-08-07) the default is m5x7, so it
## has to be asked for. Sizes match DebugPanel.
func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", FS)
	if min_w > 0.0:
		b.custom_minimum_size = Vector2(min_w, 15.0)
	b.pressed.connect(cb)
	return b


# ─── Actions ──────────────────────────────────────────────────────────────────

func _refresh_class_label() -> void:
	if _class_label:
		_class_label.text = ProgressionManager.selected_character


## Swap character by reloading the room. Re-running the player's load steps in place would
## stack every source-tagged modifier (passive_*, weapon uniques, trinkets) from the previous
## class on top of the new one — a scene reload is the only clean rebuild, and in a sandbox
## with nothing to lose it costs a blink.
func _cycle_class(step: int) -> void:
	if _char_ids.is_empty():
		return
	var idx: int = _char_ids.find(ProgressionManager.selected_character)
	idx = wrapi(idx + step, 0, _char_ids.size())
	ProgressionManager.selected_character = _char_ids[idx]
	_reloading = true
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _spawn_dummies() -> void:
	if player_ref == null or arena_ref == null:
		return
	for d in _dummies:
		if is_instance_valid(d):
			d.queue_free()
	_dummies.clear()
	if not ResourceLoader.exists(DUMMY_SCENE_PATH):
		return
	var scene: PackedScene = load(DUMMY_SCENE_PATH)
	var origin: Vector2 = player_ref.global_position + DUMMY_ROW_OFFSET
	var start_x: float = -DUMMY_SPACING * (DUMMY_COUNT - 1) * 0.5
	for i in range(DUMMY_COUNT):
		var d: Node2D = scene.instantiate()
		arena_ref.add_child(d)
		d.global_position = origin + Vector2(start_x + i * DUMMY_SPACING, 0.0)
		## Rooted, unkillable, harmless (until HIT BACK). _process keeps HP pinned.
		d.max_hp = DUMMY_HP
		d.base_move_speed = 0.0
		d.contact_damage = 0.0
		d.xp_value = 0.0
		d.health_drop_chance = 0.0
		if d.health:
			d.health.setup(DUMMY_HP)
		_dummies.append(d)


func _toggle_hit_back() -> void:
	_hit_back = not _hit_back
	_hit_back_btn.text = "HIT BACK: ON" if _hit_back else "HIT BACK: OFF"


## Live fodder that actually chase — for pathing, knockback, AoE and charm tests.
func _spawn_pack() -> void:
	if player_ref == null or arena_ref == null or not ResourceLoader.exists(DUMMY_SCENE_PATH):
		return
	var scene: PackedScene = load(DUMMY_SCENE_PATH)
	for i in range(PACK_SIZE):
		var angle: float = TAU * float(i) / float(PACK_SIZE)
		var e: Node2D = scene.instantiate()
		arena_ref.add_child(e)
		e.global_position = player_ref.global_position + Vector2(cos(angle), sin(angle)) * 150.0


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	_dummies.clear()


func _toggle_slow() -> void:
	_slow = not _slow
	var scale: float = SLOW_SCALE if _slow else 1.0
	Engine.time_scale = scale
	## Hit-stop restores to the arena's ambient scale — without this a single crit would
	## quietly cancel slow-mo mid-inspection.
	if arena_ref and is_instance_valid(arena_ref):
		arena_ref.base_time_scale = scale
	_slow_btn.text = "SLOW-MO: ON" if _slow else "SLOW-MO: OFF"


## Audit the live class's combo graphs against the sheets they actually play (full report goes to
## the Logger / output; the panel shows the headline so you know whether to go read it).
func _audit_timing() -> void:
	if not (player_ref and is_instance_valid(player_ref)):
		return
	var report: Array[String] = ComboTimingAudit.run(player_ref)
	for line in report:
		print(line)
	if _audit_label:
		_audit_label.text = report[0].replace("ComboTimingAudit ", "")


func _heal_player() -> void:
	if player_ref and is_instance_valid(player_ref) and player_ref.health:
		player_ref.health.current_hp = player_ref.health.max_hp
		player_ref.health_changed.emit(player_ref.health.current_hp, player_ref.health.max_hp)


## ── Level up ─────────────────────────────────────────────────────────────────

## Grant exactly enough XP to cross `count` thresholds. add_xp's own loop emits leveled_up once
## per threshold, so the level-up screen queues up that many times — the same behaviour, and the
## same arithmetic, as debug_panel's "Level Up x5".
func _grant_levels(count: int) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	var sim_level: int = player_ref.level
	var sim_xp: float = player_ref.xp
	var total: float = 0.0
	for _i in range(count):
		var to_next: float = player_ref.xp_base * (1.0 + (sim_level - 1) * player_ref.xp_growth)
		total += maxf(to_next - sim_xp, 0.0) + 0.1
		sim_xp = 0.0
		sim_level += 1
	player_ref.add_xp(total)


## ── Mod bench ────────────────────────────────────────────────────────────────

## This character's roster plus an empty entry at the front, so a slot can be cleared.
func _mod_options() -> Array:
	var opts: Array = [""]
	opts.append_array(ModApplicability.class_mod_ids_for(ProgressionManager.selected_character))
	return opts


func _mod_display(mod_id: String) -> String:
	if mod_id.is_empty():
		return "— empty —"
	return str(ClassModData.ALL.get(mod_id, {}).get("name", mod_id))


func _refresh_mod_rows() -> void:
	var char_id: String = ProgressionManager.selected_character
	var equipped: Array = ProgressionManager.get_character_mods(char_id)
	for slot in range(_mod_rows.size()):
		var mid: String = ""
		if slot < equipped.size() and equipped[slot] is String:
			mid = equipped[slot]
		_mod_rows[slot].text = _mod_display(mid)
	if _mod_hint:
		var owned: int = ProgressionManager.owned_mods.size()
		_mod_hint.text = "roster %d · owned %d" % [_mod_options().size() - 1, owned]


## Step a slot through this character's roster and apply it live.
##
## Deliberately NOT gated on ownership: this is a sandbox for judging what a mod does, and
## requiring the drop first would defeat the point. set_character_mod consumes a copy from
## owned_mods only if one is there, so an unowned pick just equips.
##
## Note these writes DO persist — set_character_mod calls save_data(), same as the armory.
## That is why GRANT ALL MODS exists next to it: with the full roster owned, any loadout you
## leave behind in here is one click to undo in the hub.
func _cycle_mod(slot: int, dir: int) -> void:
	var char_id: String = ProgressionManager.selected_character
	var opts: Array = _mod_options()
	if opts.size() <= 1:
		return
	var equipped: Array = ProgressionManager.get_character_mods(char_id)
	var current: String = ""
	if slot < equipped.size() and equipped[slot] is String:
		current = equipped[slot]
	var idx: int = opts.find(current)
	if idx < 0:
		idx = 0
	idx = wrapi(idx + dir, 0, opts.size())
	var next_id: String = opts[idx]

	if next_id.is_empty():
		ProgressionManager.remove_character_mod(char_id, slot)
	else:
		ProgressionManager.set_character_mod(char_id, slot, next_id)

	if player_ref and is_instance_valid(player_ref) and player_ref.has_method("debug_reload_mods"):
		player_ref.debug_reload_mods()
	_refresh_mod_rows()


## Put every class mod in the game into owned_mods, so the armory and the merchant have the
## whole set available and nothing has to be farmed to be tested. Skips ids already held, so
## pressing it twice does not build a pile of duplicates.
func _grant_all_mods() -> void:
	var added: int = 0
	for mod_id: String in ClassModData.ALL.keys():
		if not ProgressionManager.owned_mods.has(mod_id):
			ProgressionManager.owned_mods.append(mod_id)
			added += 1
	ProgressionManager.save_data()
	_refresh_mod_rows()
	if _mod_hint:
		_mod_hint.text = "granted %d (owned %d)" % [added, ProgressionManager.owned_mods.size()]


func _reset_meter() -> void:
	_total_damage = 0.0
	_best_hit = 0.0
	_damage_log.clear()
