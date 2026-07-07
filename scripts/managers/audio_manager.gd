extends Node

## AudioManager — pooled, EventBus-driven audio playback. Autoload (audio must
## work in both hub and arena; combat subsystems under CombatOrchestrator die
## with the arena scene, so a scene-owned node can't own music or hub SFX).
##
## Owns four fixed pools, created once in _ready(), never destroyed:
##   • 10 AudioStreamPlayer   — global/UI SFX (player-centric feedback, pickups, UI)
##   • 16 AudioStreamPlayer2D — positional combat SFX (hits, deaths, statuses)
##   •  2 AudioStreamPlayer   — music (current track + crossfade target)
##   •  1 AudioStreamPlayer   — dedicated loop voice (extraction channel hum)
## Worst-case simultaneous voices = 29, bounded by the pools regardless of how
## many combat events fire. Per-sound limiting (max_per_frame K, min_interval_ms,
## -2 dB stacking falloff) keeps the loudest frame from clipping; see
## docs/audio_pipeline.md for the math.
##
## Gameplay code never calls this directly for combat sounds — everything routes
## through EventBus / manager signals. Direct calls are only for non-EventBus
## moments: play_ui() for UI clicks, play_music() at hub/menu load.
##
## New sound = new entry in SoundTable (data/factories/sound_table.gd).
## Missing file → one warning at first play, then silent no-op.

const GLOBAL_POOL_SIZE := 10
const POSITIONAL_POOL_SIZE := 16
const CROSSFADE_DURATION := 1.5
const POSITIONAL_MAX_DISTANCE := 480.0  ## ~1.5 view-widths at 640x360 — off-screen combat fades out

const DEFAULT_PITCH_VARIANCE := 0.08
const DEFAULT_MAX_PER_FRAME := 2
const DEFAULT_MIN_INTERVAL_MS := 30
const STACK_FALLOFF_DB := -2.0  ## each extra same-frame instance of a sound plays quieter

# --- Pools ---
var _global_pool: Array[AudioStreamPlayer] = []
var _global_next: int = 0
var _pos_pool: Array[AudioStreamPlayer2D] = []
var _pos_next: int = 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_active: int = 0  ## index into _music_players of the audible track
var _loop_player: AudioStreamPlayer = null

# --- Preloaded streams ---
var _sfx_streams: Dictionary = {}    ## sound_id -> Array[AudioStream] (only files that exist)
var _music_streams: Dictionary = {}  ## music_id -> AudioStream

# --- Limiter state ---
var _frame_counts: Dictionary = {}   ## sound_id -> instances played this frame (cleared each frame)
var _last_play_ms: Dictionary = {}   ## sound_id -> Time.get_ticks_msec() of last play
var _missing_warned: Dictionary = {} ## sound_id -> true once we've warned about a missing file

# --- Music state ---
var _current_music_id: String = ""
var _music_before_boss: String = ""  ## biome track to restore after final_boss_defeated
var _music_tween: Tween = null
var _active_loop_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  ## UI sounds must play while paused
	_build_pools()
	_preload_streams()
	_connect_signals()


func _process(_delta: float) -> void:
	_frame_counts.clear()


# ── Pool construction ─────────────────────────────────────────────────────────

func _build_pools() -> void:
	for i in GLOBAL_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = Settings.BUS_SFX
		add_child(p)
		_global_pool.append(p)

	for i in POSITIONAL_POOL_SIZE:
		var p2 := AudioStreamPlayer2D.new()
		p2.bus = Settings.BUS_SFX
		p2.max_distance = POSITIONAL_MAX_DISTANCE
		add_child(p2)
		_pos_pool.append(p2)

	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = Settings.BUS_MUSIC
		m.finished.connect(_on_music_finished.bind(i))
		add_child(m)
		_music_players.append(m)

	_loop_player = AudioStreamPlayer.new()
	_loop_player.bus = Settings.BUS_SFX
	_loop_player.finished.connect(_on_loop_finished)
	add_child(_loop_player)


func _preload_streams() -> void:
	## All loading happens here at boot — no load() calls during combat.
	for sound_id in SoundTable.ALL:
		var entry: Dictionary = SoundTable.ALL[sound_id]
		var streams: Array = []
		for path in entry.get("streams", []):
			if ResourceLoader.exists(path):
				var stream: AudioStream = load(path)
				if stream:
					streams.append(stream)
		if not streams.is_empty():
			_sfx_streams[sound_id] = streams

	for music_id in SoundTable.MUSIC:
		var path: String = SoundTable.MUSIC[music_id].get("stream", "")
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream:
				_music_streams[music_id] = stream


func _connect_signals() -> void:
	# Combat (EventBus)
	EventBus.on_hit_dealt.connect(_on_hit_dealt)
	EventBus.on_crit.connect(_on_crit)
	EventBus.on_kill.connect(_on_kill)
	EventBus.on_death.connect(_on_death)
	EventBus.on_block.connect(_on_block)
	EventBus.on_dodge.connect(_on_dodge)
	EventBus.on_status_applied.connect(_on_status_applied)
	EventBus.on_pickup.connect(_on_pickup)

	# Run lifecycle (GameManager)
	GameManager.run_started.connect(_on_run_started)
	GameManager.final_boss_spawned.connect(_on_final_boss_spawned)
	GameManager.final_boss_defeated.connect(_on_final_boss_defeated)
	GameManager.player_died.connect(_on_player_died)
	GameManager.extraction_successful.connect(_on_extraction_successful)
	GameManager.extraction_window_opened.connect(_on_extraction_window_opened)

	# Extraction channel (ExtractionManager)
	ExtractionManager.extraction_channel_started.connect(_on_extraction_channel_started)
	ExtractionManager.extraction_interrupted.connect(_on_extraction_interrupted)
	ExtractionManager.extraction_complete.connect(_on_extraction_channel_complete)

	# Progression
	UpgradeManager.level_up_ready.connect(_on_level_up_ready)


# ── Public API ────────────────────────────────────────────────────────────────

## Play a sound by table ID. Pass a world position for positional sounds;
## positional entries with no position fall back to the global pool.
func play(sound_id: String, world_pos: Variant = null) -> void:
	var entry: Dictionary = SoundTable.ALL.get(sound_id, {})
	if entry.is_empty():
		if not _missing_warned.has(sound_id):
			_missing_warned[sound_id] = true
			push_warning("[AudioManager] Unknown sound_id '%s' — no SoundTable entry" % sound_id)
		return

	var streams: Array = _sfx_streams.get(sound_id, [])
	if streams.is_empty():
		if not _missing_warned.has(sound_id):
			_missing_warned[sound_id] = true
			push_warning("[AudioManager] No audio file on disk for '%s' — muting it" % sound_id)
		return

	# Limiting: allow up to K instances within one frame (composite hits layer),
	# but across frames throttle to min_interval_ms (zero-cooldown spam defense).
	var count: int = _frame_counts.get(sound_id, 0)
	var max_per_frame: int = entry.get("max_per_frame", DEFAULT_MAX_PER_FRAME)
	if count >= max_per_frame:
		return
	if count == 0:
		var now: int = Time.get_ticks_msec()
		var min_interval: int = entry.get("min_interval_ms", DEFAULT_MIN_INTERVAL_MS)
		if now - int(_last_play_ms.get(sound_id, -100000)) < min_interval:
			return
		_last_play_ms[sound_id] = now
	_frame_counts[sound_id] = count + 1

	var stream: AudioStream = streams[randi() % streams.size()]
	var volume_db: float = entry.get("volume_db", 0.0) + STACK_FALLOFF_DB * count
	var variance: float = entry.get("pitch_variance", DEFAULT_PITCH_VARIANCE)
	var pitch: float = 1.0 + randf_range(-variance, variance)
	var bus: String = entry.get("bus", Settings.BUS_SFX)

	if entry.get("loop", false):
		_start_loop(sound_id, stream, volume_db, bus)
		return

	if entry.get("positional", false) and world_pos is Vector2:
		var p2 := _acquire_positional()
		p2.global_position = world_pos
		p2.stream = stream
		p2.volume_db = volume_db
		p2.pitch_scale = pitch
		p2.bus = bus
		p2.play()
	else:
		var p := _acquire_global()
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.bus = bus
		p.play()


## UI sounds — call sites are hub panels / menus (non-EventBus moments).
func play_ui(sound_id: String) -> void:
	play(sound_id)


## Crossfade to a music track by table ID. No-op if it's already playing.
func play_music(music_id: String) -> void:
	if music_id == _current_music_id:
		return
	_current_music_id = music_id

	var stream: AudioStream = _music_streams.get(music_id)
	if stream == null:
		if not _missing_warned.has(music_id):
			_missing_warned[music_id] = true
			push_warning("[AudioManager] No music file on disk for '%s' — fading out instead" % music_id)
		stop_music()
		return

	var volume_db: float = SoundTable.MUSIC[music_id].get("volume_db", 0.0)
	var outgoing: AudioStreamPlayer = _music_players[_music_active]
	_music_active = 1 - _music_active
	var incoming: AudioStreamPlayer = _music_players[_music_active]

	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()

	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(incoming, "volume_db", volume_db, CROSSFADE_DURATION)
	if outgoing.playing:
		_music_tween.tween_property(outgoing, "volume_db", -40.0, CROSSFADE_DURATION)
		_music_tween.chain().tween_callback(outgoing.stop)


## Fade out whatever music is playing.
func stop_music(fade_duration: float = 1.0) -> void:
	_current_music_id = ""
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	var player: AudioStreamPlayer = _music_players[_music_active]
	if not player.playing:
		return
	_music_tween = create_tween()
	_music_tween.tween_property(player, "volume_db", -40.0, fade_duration)
	_music_tween.tween_callback(player.stop)


func stop_loop() -> void:
	_active_loop_id = ""
	_loop_player.stop()


# ── Pool acquisition (round-robin with steal, house style) ────────────────────

func _acquire_global() -> AudioStreamPlayer:
	## Prefer an idle player; if all are busy, steal the next slot round-robin —
	## the oldest sounds are the most expendable during heavy combat.
	for i in GLOBAL_POOL_SIZE:
		var idx := (_global_next + i) % GLOBAL_POOL_SIZE
		if not _global_pool[idx].playing:
			_global_next = (idx + 1) % GLOBAL_POOL_SIZE
			return _global_pool[idx]
	var stolen := _global_pool[_global_next]
	_global_next = (_global_next + 1) % GLOBAL_POOL_SIZE
	return stolen


func _acquire_positional() -> AudioStreamPlayer2D:
	for i in POSITIONAL_POOL_SIZE:
		var idx := (_pos_next + i) % POSITIONAL_POOL_SIZE
		if not _pos_pool[idx].playing:
			_pos_next = (idx + 1) % POSITIONAL_POOL_SIZE
			return _pos_pool[idx]
	var stolen := _pos_pool[_pos_next]
	_pos_next = (_pos_next + 1) % POSITIONAL_POOL_SIZE
	return stolen


func _start_loop(sound_id: String, stream: AudioStream, volume_db: float, bus: String) -> void:
	if _active_loop_id == sound_id and _loop_player.playing:
		return
	_active_loop_id = sound_id
	_loop_player.stream = stream
	_loop_player.volume_db = volume_db
	_loop_player.bus = bus
	_loop_player.play()


func _on_loop_finished() -> void:
	## Manual looping — works whether or not import loop points are set.
	if _active_loop_id != "":
		_loop_player.play()


func _on_music_finished(index: int) -> void:
	if index == _music_active and _current_music_id != "":
		_music_players[index].play()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _entity_pos(entity: Variant) -> Variant:
	if entity is Node2D and is_instance_valid(entity):
		return (entity as Node2D).global_position
	return null


# ── EventBus handlers ─────────────────────────────────────────────────────────

func _on_hit_dealt(source: Variant, target: Variant, hit_data: Variant) -> void:
	var damage_type: String = "Physical"
	if hit_data is HitData:
		damage_type = hit_data.damage_type
	elif hit_data is Dictionary:
		damage_type = hit_data.get("damage_type", "Physical")
	var sound_id: String = SoundTable.HIT_SOUND_BY_DAMAGE_TYPE.get(damage_type, "sfx_hit_physical")
	play(sound_id, _entity_pos(target))
	_play_swing_sfx(source, hit_data)


## Weapon swing feel (P1 "weapon fire"): HitData.ability threads the AbilityDefinition through
## from ChainFactory's per-kit combos, whose ability_id always ends "_light"/"_heavy" for the
## base melee combo (per kit dispatcher table). Special skill/channel abilities (fan, summon,
## torrent, storm, etc.) don't match either suffix and are silent here by design — they're
## sfx_channel_loop/sfx_projectile_fire territory (P2, not yet wired).
func _play_swing_sfx(source: Variant, hit_data: Variant) -> void:
	if not (hit_data is HitData):
		return
	var ability: AbilityDefinition = hit_data.ability
	if ability == null or not ability.tags.has("Combo"):
		return
	if ability.ability_id.ends_with("_light"):
		play("sfx_swing_light", _entity_pos(source))
	elif ability.ability_id.ends_with("_heavy"):
		play("sfx_swing_heavy", _entity_pos(source))


func _on_crit(_source: Variant, _target: Variant, _hit_data: Variant) -> void:
	play("sfx_crit")


func _on_kill(_killer: Variant, _victim: Variant) -> void:
	play("sfx_kill")


func _on_death(entity: Variant) -> void:
	if not is_instance_valid(entity):
		return
	if entity.is_in_group("player"):
		play("sfx_death_player")
		return
	if entity.get("is_elite"):
		play("sfx_death_enemy_elite", _entity_pos(entity))
	else:
		play("sfx_death_enemy_normal", _entity_pos(entity))


func _on_block(_source: Variant, target: Variant, _hit_data: Variant, _mitigated: float) -> void:
	play("sfx_block", _entity_pos(target))


func _on_dodge(_source: Variant, target: Variant, _hit_data: Variant) -> void:
	play("sfx_dodge", _entity_pos(target))


func _on_status_applied(_source: Variant, target: Variant, status_id: String, _stacks: int) -> void:
	## Unmapped statuses are silent by design — no warning.
	var sound_id: String = SoundTable.STATUS_SOUND.get(status_id, "")
	if sound_id != "":
		play(sound_id, _entity_pos(target))


func _on_pickup(_entity: Variant, pickup_type: String) -> void:
	var sound_id: String = SoundTable.PICKUP_SOUND.get(pickup_type, "")
	if sound_id != "":
		play(sound_id)


# ── Lifecycle handlers ────────────────────────────────────────────────────────

func _on_run_started() -> void:
	play_music(LevelData.get_music_id(GameManager.current_level))


func _on_final_boss_spawned(_display_name: String) -> void:
	_music_before_boss = _current_music_id
	play("sfx_boss_intro")
	play_music("mus_boss")


func _on_final_boss_defeated() -> void:
	play("sfx_death_enemy_boss")
	if _music_before_boss != "":
		play_music(_music_before_boss)
		_music_before_boss = ""


func _on_player_died() -> void:
	stop_loop()
	stop_music(2.0)


func _on_extraction_successful() -> void:
	play("sfx_extraction_channel_complete")
	stop_music(2.0)


func _on_extraction_window_opened() -> void:
	play("sfx_extraction_warning")


func _on_extraction_channel_started() -> void:
	play("sfx_extraction_channel_start")
	play("sfx_extraction_channel_loop")


func _on_extraction_interrupted() -> void:
	stop_loop()
	play("sfx_extraction_interrupted")


func _on_extraction_channel_complete() -> void:
	stop_loop()


func _on_level_up_ready(_choices: Array) -> void:
	play("sfx_level_up")
