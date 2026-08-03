class_name GatewayExtraction
extends Node2D

## GatewayExtraction — the descent's early way out.
##
## Ben's pitch, 2026-08-02: "a guy coming through a portal on either side of the block the player
## is in ... maybe he has like a dome around it so monsters cant get in, it will feel like a real
## dash to safety, soon as the player touches the actual portal, it should be loading screen back
## to hub."
##
## Why it exists at all: descent mode had NO early exit. `_setup_extraction_zones()` is only
## reached on the flat-arena branch of MainArena, `BlockManager.get_extractions()` has never had a
## caller, and the only two Extraction entities in the whole live block set are keystone-Locked.
## So the phase clock opened an 18-second "EXTRACTION IN X" window five times a run with nothing
## behind it, and the only real way out of a descent was ten blocks plus the boss, or dying.
##
## The three parts, and why each is the way it is:
##
##  1. THE GATEWAY. `Magic_Gateway.png` from the All_Exclusives Miscellany addon, which happens to
##     be authored in exactly the three stages this needs: row 0 (27f) builds an arch out of
##     nothing, row 1 (4f) is a stable idle, row 2 (26f) unbuilds it. Frame counts measured off
##     the sheet's alpha, not eyeballed. 32px frames drawn at 1x so its pixels match the world —
##     scaling it up would make a doorway whose pixels are twice the size of the player's.
##
##  2. THE DOME. Enemies are pushed back out every physics frame rather than routed around via
##     the flow field: `register_solid_circle` only takes effect at `finalize()`, which rasterizes
##     the whole grid and is a load-time operation. Pushing is also the better read — the horde
##     visibly presses against the edge instead of politely pathing around it.
##
##  3. THE EXIT. Touching the arch calls `ExtractionManager.extract_now()` — no channel. See the
##     note there.
##
## The dome is generous and the arch is small on purpose: DOME_RADIUS is the safe pocket you dash
## into, PORTAL_RADIUS is the door you then step through. Reaching safety and choosing to leave
## are two separate beats.

const SHEET: String = "res://assets/minifantasy/All_Exclusives_20260409/Addons/_Miscellany/Magic_Gateway/Magic_Gateway.png"
const NPC_IDLE: String = "res://assets/minifantasy/Minifantasy_AMyriadOfNPCs_v.1.0/Minifantasy_NPCs_Assets/Premade_NPCs/Alchemist/Minifantasy_NPCsAlchemistIdle.png"
const NPC_WALK: String = "res://assets/minifantasy/Minifantasy_AMyriadOfNPCs_v.1.0/Minifantasy_NPCs_Assets/Premade_NPCs/Alchemist/Minifantasy_NPCsAlchemistWalk.png"

const CELL: int = 32
## Measured off the sheet's alpha: row 0 = 27 frames, row 1 = 4, row 2 = 26 (the 27th is empty).
const OPEN_FRAMES: int = 27
const IDLE_FRAMES: int = 4
const CLOSE_FRAMES: int = 26

## Pack authors at 100ms/frame. 27 frames at that rate is a 2.7s open, far too slow inside an
## 18-second window, so open/close run at 2.0x — dead centre of the house band established in
## docs/anim_rate_audit_2026-07-31.md. The idle stays at pack rate; it is an ambient shimmer and
## has no beat to hit.
const OPEN_FPS: float = 20.0
const IDLE_FPS: float = 10.0
const CLOSE_FPS: float = 20.0

## NPC rates follow the roster's own idle band (8-10) rather than the pack's 5.
const NPC_IDLE_FPS: float = 9.0
const NPC_WALK_FPS: float = 10.0

## The Minifantasy oblique style draws its four rows as DIAGONAL facings — same table as
## CharacterSpriteFactory.DIR_ROWS. The guy faces back the way the player will be coming from.
const NPC_ROW_DOWN_RIGHT: int = 0
const NPC_ROW_DOWN_LEFT: int = 1

const DOME_RADIUS: float = 58.0     ## the safe pocket
const PORTAL_RADIUS: float = 15.0   ## the door itself — step in and you are out
const NPC_OFFSET: float = 20.0      ## how far the guy stands to the side of the arch
const DOME_FILL_ALPHA: float = 0.45 ## see _build_dome — the ice is a shimmer, not a field

## The dome's edge is DRAWN rather than sprited. No pack in the project ships a dome or barrier
## (checked Spell Effects I and II, the Divine creatures, and the UI pack), and the boundary is
## load-bearing information — it is exactly where the horde stops — so it has to be unambiguous.
## A ground-zone fill alone reads as a puddle; the ring is what makes it a wall.
const DOME_EDGE_COLOR: Color = Color(0.70, 0.92, 1.0)
const DOME_EDGE_WIDTH: float = 1.5
const DOME_PULSE_HZ: float = 0.8
const DOME_PULSE_MIN: float = 0.35
const DOME_PULSE_MAX: float = 0.75

## A marker beam, because the gateway opens at the SIDE of the block and the viewport is only
## 320px from the player to the screen edge. Measured in a live descent: the player stood at
## x=316 and the gateway opened at x=624, putting its centre 12px from the right edge of the
## screen — visible, but not something you could confidently run at. A tall column stays legible
## when the arch itself is clipped, and reads from anywhere in the block.
const BEAM_HALF_HEIGHT: float = 190.0
const BEAM_WIDTH: float = 7.0
const BEAM_ALPHA_MIN: float = 0.10
const BEAM_ALPHA_MAX: float = 0.22

var _gate: AnimatedSprite2D = null
var _npc: AnimatedSprite2D = null
var _dome: GroundZoneVfx = null
var _player: Node2D = null
var _grid: SpatialGrid = null

var _open: bool = false
var _closing: bool = false
var _spent: bool = false            ## latched once the player leaves through it
var _payout_type: String = "gateway"
## True for the miniboss reward: survives the extraction window closing. MainArena checks it
## before tearing the gateway down.
var is_persistent: bool = false

static var _gate_frames: SpriteFrames = null
static var _npc_frames: SpriteFrames = null


## `face_left` orients the NPC toward the middle of the block (i.e. toward the player), so a
## gateway on the right of the block has its keeper looking left.
##
## `payout_type` is the key this extraction settles under (GameManager.EXTRACTION_PAYOUT) — the
## free window gateway is worth less than the one the miniboss's death earns you.
## `persistent` gateways ignore the extraction window closing: the miniboss reward stays open
## because you paid for it in blood, where the free one is a window you catch or miss.
func open_at(pos: Vector2, player: Node2D, grid: SpatialGrid, face_left: bool,
		payout_type: String = "gateway", persistent: bool = false) -> void:
	global_position = pos
	_player = player
	_grid = grid
	_payout_type = payout_type
	is_persistent = persistent

	_build_dome()
	_build_gate()
	_build_npc(face_left)
	_build_label()
	_open = true

	## The gateway's own arrival sting. Reuses the extraction channel start — this IS an
	## extraction opening, and it is the sound the player already associates with a way out.
	AudioManager.play("sfx_extraction_channel_start", global_position)


## Play the close-down and free ourselves when it finishes. Safe to call more than once.
func close_gateway() -> void:
	if _closing or _spent:
		return
	_closing = true
	_open = false
	if _npc != null and is_instance_valid(_npc):
		## The keeper steps back through before the arch comes down.
		var t := create_tween()
		t.tween_property(_npc, "modulate:a", 0.0, 0.35)
		t.tween_callback(_npc.queue_free)
	if _dome != null and is_instance_valid(_dome):
		_dome.queue_free()
		_dome = null
	if _gate != null and is_instance_valid(_gate):
		_gate.play("close")
		await _gate.animation_finished
	queue_free()


func _physics_process(_delta: float) -> void:
	if not _open or _spent:
		return
	_hold_the_line()
	_check_player()


func _process(_delta: float) -> void:
	if _open:
		queue_redraw()


## The dome boundary. Drawn under the arch and the bodies (z_index -1 via the parent's ordering
## is not available here, so it is drawn first and the sprites are children added after).
func _draw() -> void:
	if not _open:
		return
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var wave: float = 0.5 + 0.5 * sin(t * TAU * DOME_PULSE_HZ)

	## Marker beam first, so the dome edge and the arch draw over it.
	var beam_a: float = lerpf(BEAM_ALPHA_MIN, BEAM_ALPHA_MAX, wave)
	draw_rect(Rect2(-BEAM_WIDTH * 0.5, -BEAM_HALF_HEIGHT, BEAM_WIDTH, BEAM_HALF_HEIGHT * 2.0),
		Color(DOME_EDGE_COLOR.r, DOME_EDGE_COLOR.g, DOME_EDGE_COLOR.b, beam_a))

	var pulse: float = lerpf(DOME_PULSE_MIN, DOME_PULSE_MAX, wave)
	var col := Color(DOME_EDGE_COLOR.r, DOME_EDGE_COLOR.g, DOME_EDGE_COLOR.b, pulse)
	draw_arc(Vector2.ZERO, DOME_RADIUS, 0.0, TAU, 48, col, DOME_EDGE_WIDTH, true)


## The dome. Anything hostile inside the radius is pushed back to its edge every frame, so the
## pocket is genuinely safe rather than merely discouraging. Uses the spatial grid rather than
## the enemies group so a saturated arena stays a handful of checks.
func _hold_the_line() -> void:
	if _grid == null:
		return
	var inside: Array = _grid.get_nearby_in_range(global_position, 1, DOME_RADIUS * DOME_RADIUS)
	for e in inside:
		if not is_instance_valid(e) or not e.is_alive:
			continue
		var away: Vector2 = e.global_position - global_position
		if away.length_squared() <= 0.01:
			## Dead centre: pick a deterministic direction rather than dividing by zero.
			away = Vector2.RIGHT
		e.global_position = global_position + away.normalized() * DOME_RADIUS


func _check_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.global_position.distance_squared_to(global_position) > PORTAL_RADIUS * PORTAL_RADIUS:
		return
	_spent = true
	_open = false
	GameManager.active_extraction_type = _payout_type
	if not ExtractionManager.extract_now():
		## Refused (already extracted, or the final-boss gate is up) — stay open rather than
		## silently becoming furniture.
		_spent = false
		_open = true


# ── Construction ──────────────────────────────────────────────────────────────────────────────

func _build_dome() -> void:
	_dome = GroundZoneVfx.new()
	add_child(_dome)
	## "ice" reads as a cold ward rather than a hazard; every other element in the table is
	## something that hurts you, and this is the one circle in the game that means safety.
	## Duration 0 would expire it — it is given the window's length and killed on close instead.
	## Duration is the run's remaining length rather than the window's: GroundZoneVfx frees itself
	## when its timer expires, and this dome is killed explicitly by close_gateway() instead.
	if not _dome.setup("ice", DOME_RADIUS, 9999.0, Color(0.62, 0.86, 1.0)):
		_dome.queue_free()
		_dome = null
		return
	## setup() sets z_index = -1 to sit under bodies. That is an ABSOLUTE intent, so opt out of
	## relative stacking — otherwise it inherits this node's z and draws on top of the player.
	_dome.z_as_relative = false
	## At full strength the ice tiles fill the circle solid and read as a HAZARD — every element
	## in the ground-zone table is normally something that hurts you, and this is the one circle
	## in the game that means safety. Dropped to a shimmer so it says "warded ground" instead.
	_dome.modulate.a = DOME_FILL_ALPHA


## Names the thing, the same way TimedExtraction labels its zone. At the block's edge the arch
## can be half a screen away, and "a small red rectangle" is not self-evidently the way out.
func _build_label() -> void:
	var label := Label.new()
	label.name = "Label"
	label.text = "ESCAPE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(128.0, 0.0)
	label.position = Vector2(-64.0, -DOME_RADIUS - 22.0)
	label.modulate = DOME_EDGE_COLOR
	var fs := LabelSettings.new()
	if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
		fs.font = load("res://assets/fonts/m5x7.ttf")
	fs.font_size = 16
	fs.outline_size = 1
	fs.outline_color = Color(0.0, 0.0, 0.0, 0.9)
	label.label_settings = fs
	add_child(label)


func _build_gate() -> void:
	_gate = AnimatedSprite2D.new()
	_gate.sprite_frames = _get_gate_frames()
	_gate.centered = true
	add_child(_gate)
	_gate.play("open")
	## Hold the finished arch rather than freezing on the last open frame.
	_gate.animation_finished.connect(_on_gate_anim_finished)


func _on_gate_anim_finished() -> void:
	if _gate != null and is_instance_valid(_gate) and _gate.animation == &"open":
		_gate.play("idle")


func _build_npc(face_left: bool) -> void:
	_npc = AnimatedSprite2D.new()
	_npc.sprite_frames = _get_npc_frames()
	_npc.centered = true
	var row: int = NPC_ROW_DOWN_LEFT if face_left else NPC_ROW_DOWN_RIGHT
	_npc.animation = &"idle_dl" if row == NPC_ROW_DOWN_LEFT else &"idle_dr"
	add_child(_npc)
	## He arrives WITH the gateway: starts at the arch and steps aside as it finishes building.
	_npc.position = Vector2.ZERO
	_npc.modulate.a = 0.0
	var side: float = -NPC_OFFSET if face_left else NPC_OFFSET
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_npc, "modulate:a", 1.0, 0.4).set_delay(0.5)
	t.tween_property(_npc, "position", Vector2(side, 2.0), 0.6).set_delay(0.5) \
		.set_trans(Tween.TRANS_SINE)
	_npc.play()


# ── Frame building (cached statically — one gateway per run, but runs repeat) ──────────────────

static func _get_gate_frames() -> SpriteFrames:
	if _gate_frames != null:
		return _gate_frames
	var tex: Texture2D = load(SHEET) as Texture2D
	if tex == null:
		push_warning("[GatewayExtraction] Missing gateway sheet: %s" % SHEET)
		return SpriteFrames.new()
	_gate_frames = SpriteFrames.new()
	_gate_frames.remove_animation("default")
	_add_row(_gate_frames, tex, "open", 0, OPEN_FRAMES, OPEN_FPS, false)
	_add_row(_gate_frames, tex, "idle", 1, IDLE_FRAMES, IDLE_FPS, true)
	_add_row(_gate_frames, tex, "close", 2, CLOSE_FRAMES, CLOSE_FPS, false)
	return _gate_frames


static func _get_npc_frames() -> SpriteFrames:
	if _npc_frames != null:
		return _npc_frames
	var tex: Texture2D = load(NPC_IDLE) as Texture2D
	if tex == null:
		push_warning("[GatewayExtraction] Missing NPC sheet: %s" % NPC_IDLE)
		return SpriteFrames.new()
	_npc_frames = SpriteFrames.new()
	_npc_frames.remove_animation("default")
	## Both diagonal-facing idle rows, so the keeper can look either way down the block.
	_add_row(_npc_frames, tex, "idle_dr", NPC_ROW_DOWN_RIGHT, 16, NPC_IDLE_FPS, true)
	_add_row(_npc_frames, tex, "idle_dl", NPC_ROW_DOWN_LEFT, 16, NPC_IDLE_FPS, true)
	return _npc_frames


static func _add_row(frames: SpriteFrames, tex: Texture2D, anim: String, row: int,
		count: int, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * CELL, row * CELL, CELL, CELL)
		frames.add_frame(anim, at)
