class_name SoundTable
extends RefCounted
## Data-driven sound registry. Adding a sound to the game = adding an entry here
## (plus dropping the file under assets/audio/). AudioManager preloads every
## stream listed at boot and warns once (then no-ops) for any missing file, so
## the game runs fine with zero audio assets present.
##
## SFX entry schema (all keys optional except "streams"):
##   streams          Array[String]  — one picked at random per play (variation support)
##   bus              String         — target audio bus (default "SFX")
##   volume_db        float          — base volume offset (default 0.0)
##   pitch_variance   float          — random pitch ±range, e.g. 0.08 = ±8% (default 0.08)
##   max_per_frame    int            — K: same-sound instances allowed per frame (default 2)
##   min_interval_ms  int            — cross-frame retrigger throttle (default 30)
##   positional       bool           — true = AudioStreamPlayer2D pool at world pos (default false)
##   loop             bool           — true = plays on the dedicated loop player (default false)
##
## Sound IDs follow docs/audio_asset_manifest.md (sfx_*, mus_*, amb_*).
## Placeholder files are synthesized WAVs, clearly named placeholder_*.wav —
## replace the paths here when real assets land (see docs/audio_pipeline.md).

const ALL: Dictionary = {
	# ── Combat: hits by damage type (P1) ─────────────────────────────────────
	"sfx_hit_physical": {
		"streams": ["res://assets/audio/sfx/combat/placeholder_hit_physical.wav"],
		"volume_db": -8.0, "max_per_frame": 3, "positional": true,
	},
	"sfx_hit_fire": {
		"streams": ["res://assets/audio/sfx/combat/placeholder_hit_fire.wav"],
		"volume_db": -8.0, "max_per_frame": 3, "positional": true,
	},
	"sfx_hit_cryo": {
		"streams": ["res://assets/audio/sfx/combat/placeholder_hit_cryo.wav"],
		"volume_db": -8.0, "max_per_frame": 3, "positional": true,
	},
	"sfx_hit_shock": {
		"streams": ["res://assets/audio/sfx/combat/placeholder_hit_shock.wav"],
		"volume_db": -8.0, "max_per_frame": 3, "positional": true,
	},
	"sfx_hit_void": {
		"streams": ["res://assets/audio/sfx/combat/placeholder_hit_void.wav"],
		"volume_db": -8.0, "max_per_frame": 3, "positional": true,
	},

	# ── Combat: crit / kill / deaths (P1) ────────────────────────────────────
	"sfx_crit": {
		"streams": ["res://assets/audio/sfx/combat/placeholder_crit.wav"],
		"volume_db": -6.0, "max_per_frame": 2, "min_interval_ms": 50,
	},
	"sfx_kill": {
		"streams": ["res://assets/audio/sfx/combat/placeholder_kill.wav"],
		"volume_db": -7.0, "max_per_frame": 2, "min_interval_ms": 60,
	},
	"sfx_death_enemy_normal": {
		"streams": ["res://assets/audio/sfx/combat/placeholder_death_enemy.wav"],
		"volume_db": -9.0, "max_per_frame": 2, "positional": true,
	},
	"sfx_death_enemy_elite": {
		"streams": ["res://assets/audio/sfx/combat/death_enemy_elite.ogg"],
		"volume_db": -6.0, "positional": true,
	},
	"sfx_death_enemy_boss": {
		"streams": ["res://assets/audio/sfx/combat/death_enemy_boss.ogg"],
		"volume_db": -4.0,
	},
	"sfx_death_player": {
		"streams": ["res://assets/audio/sfx/combat/placeholder_death_player.wav"],
		"volume_db": -4.0, "max_per_frame": 1, "pitch_variance": 0.0,
	},

	# ── Combat: mitigation (P2 — table-ready, files pending) ─────────────────
	"sfx_block": {
		"streams": ["res://assets/audio/sfx/combat/block.ogg"],
		"volume_db": -9.0, "positional": true,
	},
	"sfx_dodge": {
		"streams": ["res://assets/audio/sfx/combat/dodge.ogg"],
		"volume_db": -9.0, "positional": true,
	},

	# ── Status applications (P2 — table-ready, files pending) ────────────────
	"sfx_status_burn_apply": {
		"streams": ["res://assets/audio/sfx/status/burn_apply.ogg"],
		"volume_db": -10.0, "positional": true, "min_interval_ms": 80,
	},
	"sfx_status_chill_apply": {
		"streams": ["res://assets/audio/sfx/status/chill_apply.ogg"],
		"volume_db": -10.0, "positional": true, "min_interval_ms": 80,
	},
	"sfx_status_frozen": {
		"streams": ["res://assets/audio/sfx/status/frozen.ogg"],
		"volume_db": -9.0, "positional": true, "min_interval_ms": 80,
	},
	"sfx_status_shocked_apply": {
		"streams": ["res://assets/audio/sfx/status/shocked_apply.ogg"],
		"volume_db": -10.0, "positional": true, "min_interval_ms": 80,
	},
	"sfx_status_void_apply": {
		"streams": ["res://assets/audio/sfx/status/void_apply.ogg"],
		"volume_db": -10.0, "positional": true, "min_interval_ms": 80,
	},

	# ── Pickups (P1) ─────────────────────────────────────────────────────────
	"sfx_pickup_xp": {
		"streams": ["res://assets/audio/sfx/pickup/placeholder_pickup_xp.wav"],
		"volume_db": -10.0, "max_per_frame": 2, "min_interval_ms": 45,
	},
	"sfx_pickup_currency": {
		"streams": ["res://assets/audio/sfx/pickup/placeholder_pickup_currency.wav"],
		"volume_db": -9.0, "max_per_frame": 2, "min_interval_ms": 45,
	},
	"sfx_pickup_weapon": {
		"streams": ["res://assets/audio/sfx/pickup/placeholder_pickup_weapon.wav"],
		"volume_db": -6.0, "max_per_frame": 1,
	},
	"sfx_pickup_mod": {
		"streams": ["res://assets/audio/sfx/pickup/pickup_mod.ogg"],
		"volume_db": -6.0, "max_per_frame": 1,
	},
	"sfx_pickup_keystone": {
		"streams": ["res://assets/audio/sfx/pickup/pickup_keystone.ogg"],
		"volume_db": -5.0, "max_per_frame": 1,
	},

	# ── Progression / UI (P1 + P2) ───────────────────────────────────────────
	"sfx_level_up": {
		"streams": ["res://assets/audio/sfx/ui/placeholder_level_up.wav"],
		"volume_db": -4.0, "max_per_frame": 1, "pitch_variance": 0.0,
	},
	"sfx_upgrade_select": {
		"streams": ["res://assets/audio/sfx/ui/upgrade_select.ogg"],
		"volume_db": -8.0,
	},
	"sfx_ui_click": {
		"streams": ["res://assets/audio/sfx/ui/ui_click.ogg"],
		"volume_db": -8.0,
	},
	"sfx_ui_panel_open": {
		"streams": ["res://assets/audio/sfx/ui/ui_panel_open.ogg"],
		"volume_db": -8.0,
	},
	"sfx_ui_panel_close": {
		"streams": ["res://assets/audio/sfx/ui/ui_panel_close.ogg"],
		"volume_db": -8.0,
	},
	"sfx_ui_purchase": {
		"streams": ["res://assets/audio/sfx/ui/ui_purchase.ogg"],
		"volume_db": -7.0,
	},
	"sfx_ui_error": {
		"streams": ["res://assets/audio/sfx/ui/ui_error.ogg"],
		"volume_db": -8.0,
	},

	# ── Extraction lifecycle (P1: complete; P2: rest) ────────────────────────
	"sfx_extraction_warning": {
		"streams": ["res://assets/audio/sfx/extraction/extraction_warning.ogg"],
		"volume_db": -5.0, "max_per_frame": 1, "pitch_variance": 0.0,
	},
	"sfx_extraction_channel_start": {
		"streams": ["res://assets/audio/sfx/extraction/extraction_channel_start.ogg"],
		"volume_db": -7.0, "pitch_variance": 0.0,
	},
	"sfx_extraction_channel_loop": {
		"streams": ["res://assets/audio/sfx/extraction/extraction_channel_hum.ogg"],
		"volume_db": -10.0, "pitch_variance": 0.0, "loop": true,
	},
	"sfx_extraction_channel_complete": {
		"streams": ["res://assets/audio/sfx/extraction/placeholder_extraction_complete.wav"],
		"volume_db": -4.0, "max_per_frame": 1, "pitch_variance": 0.0,
	},
	"sfx_extraction_interrupted": {
		"streams": ["res://assets/audio/sfx/extraction/extraction_interrupted.ogg"],
		"volume_db": -6.0, "pitch_variance": 0.0,
	},

	# ── Boss (P2) ────────────────────────────────────────────────────────────
	"sfx_boss_intro": {
		"streams": ["res://assets/audio/sfx/combat/boss_intro.ogg"],
		"volume_db": -3.0, "max_per_frame": 1, "pitch_variance": 0.0,
	},
}

## Music tracks: id → { stream, volume_db }. Looping is handled by AudioManager
## (finished → replay), so tracks work whether or not import loop points are set.
const MUSIC: Dictionary = {
	"mus_hub": {
		"stream": "res://assets/audio/music/placeholder_hub.wav",
		"volume_db": -8.0,
	},
	"mus_caves": {
		"stream": "res://assets/audio/music/placeholder_caves.wav",
		"volume_db": -8.0,
	},
	"mus_catacombs": {
		"stream": "res://assets/audio/music/catacombs.ogg",
		"volume_db": -8.0,
	},
	"mus_nightmare_realm": {
		"stream": "res://assets/audio/music/nightmare_realm.ogg",
		"volume_db": -8.0,
	},
	"mus_threshold": {
		"stream": "res://assets/audio/music/threshold.ogg",
		"volume_db": -8.0,
	},
	"mus_inferno": {
		"stream": "res://assets/audio/music/inferno.ogg",
		"volume_db": -8.0,
	},
	"mus_boss": {
		"stream": "res://assets/audio/music/placeholder_boss.wav",
		"volume_db": -7.0,
	},
}

## Engine damage_type strings (see HitData / CombatFeedbackManager.TYPE_COLORS)
## → manifest sound IDs. The manifest uses cryo/shock naming; the engine uses
## Ice/Lightning. "True" damage reuses the physical impact.
const HIT_SOUND_BY_DAMAGE_TYPE: Dictionary = {
	"Physical": "sfx_hit_physical",
	"Fire": "sfx_hit_fire",
	"Ice": "sfx_hit_cryo",
	"Lightning": "sfx_hit_shock",
	"Void": "sfx_hit_void",
	"True": "sfx_hit_physical",
}

## status_id → sound ID. Statuses not listed are silent by design (no warning).
const STATUS_SOUND: Dictionary = {
	"burning": "sfx_status_burn_apply",
	"chilled": "sfx_status_chill_apply",
	"frozen": "sfx_status_frozen",
	"shocked": "sfx_status_shocked_apply",
	"void_touched": "sfx_status_void_apply",
}

## pickup_type (EventBus.on_pickup payload) → sound ID.
const PICKUP_SOUND: Dictionary = {
	"xp": "sfx_pickup_xp",
	"currency": "sfx_pickup_currency",
	"weapon": "sfx_pickup_weapon",
	"mod": "sfx_pickup_mod",
	"keystone": "sfx_pickup_keystone",
}
