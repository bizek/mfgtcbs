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
## Task 15: real CC0 assets (Kenney.nl SFX packs + OpenGameArt.org CC0 music),
## sourced and licensed per docs/asset_inventory.md. Remaining P2 entries with
## no good-fit free asset are left pointing at nonexistent paths — AudioManager
## no-ops on missing files, and docs/audio_asset_manifest.md lists them as TODO.

const ALL: Dictionary = {
	# ── Combat: weapon swings (P1 — "weapon fire") ───────────────────────────
	## "sfx_swing_light" was removed 2026-08-02: it had no caller anywhere. Light-chain
	## swings play through the sfx_combo_step pitch ladder instead (AudioManager._on_combo_step),
	## which is what gives the chain its rising cadence. Its three swing_light_*.ogg streams are
	## still in use below by sfx_projectile_fire.
	## Weapon/ability fire (P2 "weapon fire") — no dedicated CC0 asset found, so these
	## alias the swing whooshes with wider pitch variance (manifest §synthesis). Fired
	## from EventBus.on_ability_used for every non-combo ability (player weapons and
	## enemy ability wind-ups); heavy combo swings keep the on-hit swing SFX path, light
	## combo swings ride on_combo_step (sfx_combo_step ladder below).
	"sfx_projectile_fire": {
		"streams": [
			"res://assets/audio/sfx/combat/swing_light_0.ogg",
			"res://assets/audio/sfx/combat/swing_light_1.ogg",
			"res://assets/audio/sfx/combat/swing_light_2.ogg",
		],
		"volume_db": -13.0, "max_per_frame": 2, "pitch_variance": 0.18,
		"positional": true, "min_interval_ms": 45,
	},
	"sfx_melee_swing_arc": {
		"streams": [
			"res://assets/audio/sfx/combat/swing_heavy_0.ogg",
			"res://assets/audio/sfx/combat/swing_heavy_1.ogg",
			"res://assets/audio/sfx/combat/swing_heavy_2.ogg",
		],
		"volume_db": -12.0, "max_per_frame": 2, "pitch_variance": 0.12,
		"positional": true, "min_interval_ms": 45,
	},
	"sfx_swing_heavy": {
		"streams": [
			"res://assets/audio/sfx/combat/swing_heavy_0.ogg",
			"res://assets/audio/sfx/combat/swing_heavy_1.ogg",
			"res://assets/audio/sfx/combat/swing_heavy_2.ogg",
		],
		"volume_db": -6.0, "max_per_frame": 2, "positional": true,
	},
	## Combo cadence ladder (docs/combo_feedback_spec.md): the light-chain step swing, pitched up
	## per step at runtime (AudioManager pitch_semitones). One fixed stream + near-zero variance —
	## a 1.5-semitone-per-step ladder is only legible if the base note barely wobbles.
	"sfx_combo_step": {
		"streams": ["res://assets/audio/sfx/combat/swing_light_0.ogg"],
		"volume_db": -9.0, "max_per_frame": 2, "positional": true,
		"pitch_variance": 0.02,
	},
	## Chain-drop "exhale": soft downward breath when a chain at depth >= 2 lapses. Non-positional
	## (player-centric feedback). Asset from the sfx_forge combo_drop recipe.
	"sfx_combo_drop": {
		"streams": ["res://assets/audio/sfx/combat/combo_drop.ogg"],
		"volume_db": -14.0, "max_per_frame": 1, "pitch_variance": 0.04,
		"min_interval_ms": 250,
	},

	# ── Combat: hits by damage type (P1) ─────────────────────────────────────
	"sfx_hit_physical": {
		"streams": [
			"res://assets/audio/sfx/combat/hit_physical_0.ogg",
			"res://assets/audio/sfx/combat/hit_physical_1.ogg",
			"res://assets/audio/sfx/combat/hit_physical_2.ogg",
		],
		"volume_db": -8.0, "max_per_frame": 3, "positional": true,
	},
	"sfx_hit_fire": {
		"streams": [
			"res://assets/audio/sfx/combat/hit_fire_0.ogg",
			"res://assets/audio/sfx/combat/hit_fire_1.ogg",
			"res://assets/audio/sfx/combat/hit_fire_2.ogg",
		],
		"volume_db": -10.0, "max_per_frame": 3, "positional": true,
	},
	"sfx_hit_cryo": {
		"streams": [
			"res://assets/audio/sfx/combat/hit_cryo_0.ogg",
			"res://assets/audio/sfx/combat/hit_cryo_1.ogg",
			"res://assets/audio/sfx/combat/hit_cryo_2.ogg",
		],
		"volume_db": -8.0, "max_per_frame": 3, "positional": true,
	},
	"sfx_hit_shock": {
		"streams": [
			"res://assets/audio/sfx/combat/hit_shock_0.ogg",
			"res://assets/audio/sfx/combat/hit_shock_1.ogg",
			"res://assets/audio/sfx/combat/hit_shock_2.ogg",
		],
		"volume_db": -11.0, "max_per_frame": 3, "positional": true,
	},
	"sfx_hit_void": {
		"streams": [
			"res://assets/audio/sfx/combat/hit_void_0.ogg",
			"res://assets/audio/sfx/combat/hit_void_1.ogg",
			"res://assets/audio/sfx/combat/hit_void_2.ogg",
		],
		"volume_db": -9.0, "max_per_frame": 3, "positional": true,
	},

	# ── Combat: crit / kill / deaths (P1) ────────────────────────────────────
	"sfx_crit": {
		"streams": ["res://assets/audio/sfx/combat/crit.ogg"],
		"volume_db": -6.0, "max_per_frame": 2, "min_interval_ms": 50,
	},
	"sfx_kill": {
		## Positional so the kill confirm reads as "that enemy died", not a
		## disembodied global thunk over whatever weapon is firing.
		"streams": ["res://assets/audio/sfx/combat/kill.ogg"],
		"volume_db": -8.0, "max_per_frame": 2, "min_interval_ms": 60, "positional": true,
	},
	"sfx_death_enemy_normal": {
		"streams": [
			"res://assets/audio/sfx/combat/death_enemy_normal_0.ogg",
			"res://assets/audio/sfx/combat/death_enemy_normal_1.ogg",
		],
		"volume_db": -9.0, "max_per_frame": 2, "positional": true,
	},
	"sfx_death_enemy_elite": {
		"streams": ["res://assets/audio/sfx/combat/death_enemy_elite.ogg"],
		"volume_db": -6.0, "positional": true,
	},
	"sfx_death_enemy_boss": {
		"streams": ["res://assets/audio/sfx/combat/death_enemy_boss.ogg"],
		"volume_db": -3.0,
	},
	"sfx_death_player": {
		"streams": ["res://assets/audio/sfx/combat/death_player.ogg"],
		"volume_db": -4.0, "max_per_frame": 1, "pitch_variance": 0.0,
	},

	# ── Combat: mitigation (P2 — real assets) ────────────────────────────────
	"sfx_block": {
		"streams": ["res://assets/audio/sfx/combat/block.ogg"],
		"volume_db": -9.0, "positional": true,
	},
	"sfx_dodge": {
		"streams": ["res://assets/audio/sfx/combat/dodge.ogg"],
		"volume_db": -11.0, "positional": true,
	},

	# ── Status applications (P2 — no good-fit free asset yet, TODO) ─────────
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
	## "A ward snaps on" — the Q/E self-buffs (Steeled, Hallowed, Blessed, Battle Fury, Honed
	## Edge, Loaded Chambers, Aegis, Second Wind). No dedicated asset exists for these, so it is
	## block.ogg pitched up half an octave and dropped in level: a block IS a ward catching
	## something, and at +6 it reads as a shimmer rather than an impact.
	##
	## Scope note (2026-08-02): the buffs are deliberately the ONLY statuses added here. The
	## obvious next candidate, bleed, was rejected — it lands on the same frame as the hit that
	## caused it, so it layers a second impact under sfx_hit_physical and just makes mud. That is
	## the exact mistake already documented and removed from _on_hit_dealt. Statuses worth
	## sounding are the ones that land with nothing else playing; the rest need real assets.
	## ── Held-channel beds (2026-08-02) ────────────────────────────────────────
	## A channel's per-beat sounds ride on_hit_dealt, so they only fire when a beat CONNECTS.
	## Hold one while missing and the ability is completely silent — nothing distinguishes
	## "channelling into empty air" from "not channelling". These sustained beds fix that.
	##
	## THE FILES DO NOT EXIST YET. AudioManager.play_channel_loop stays silent (one warning)
	## until they do, which is deliberate: the only true loop asset in the library is
	## extraction_channel_hum.ogg, and re-voicing THAT would put an extraction cue — a
	## high-stakes gameplay signal — under ordinary combat. Better silent than misleading.
	##
	## To render (REAPER, docs/audio_pipeline.md): three seamless ~2s loops, low and unobtrusive,
	## mixed to sit UNDER the beat hits rather than compete with them. Suggested character —
	##   channel_loop_fire:     a low roaring bed (Immolate, Hellfire)
	##   channel_loop_arcane:   a dry rattling/whispering bed (Bone Barrage, Bramble Barrage)
	##   channel_loop_martial:  a low physical rumble (Taunt, Dictum, the Reckoning dome)
	## Drop them in assets/audio/sfx/combat/ and they light up with no code change.
	"sfx_channel_loop_fire": {
		"streams": ["res://assets/audio/sfx/combat/channel_loop_fire.ogg"],
		"volume_db": -18.0, "loop": true,
	},
	"sfx_channel_loop_arcane": {
		"streams": ["res://assets/audio/sfx/combat/channel_loop_arcane.ogg"],
		"volume_db": -18.0, "loop": true,
	},
	"sfx_channel_loop_martial": {
		"streams": ["res://assets/audio/sfx/combat/channel_loop_martial.ogg"],
		"volume_db": -18.0, "loop": true,
	},
	"sfx_status_buff_apply": {
		"streams": ["res://assets/audio/sfx/combat/block.ogg"],
		"volume_db": -13.0, "pitch_semitones": 6.0, "pitch_variance": 0.05,
		"positional": true, "min_interval_ms": 120,
	},

	# ── Pickups (P1: xp/currency/weapon; P2: mod/keystone — real assets) ────
	"sfx_pickup_xp": {
		"streams": [
			"res://assets/audio/sfx/pickup/pickup_xp_0.ogg",
			"res://assets/audio/sfx/pickup/pickup_xp_1.ogg",
		],
		"volume_db": -10.0, "max_per_frame": 2, "min_interval_ms": 45,
	},
	"sfx_pickup_currency": {
		"streams": [
			"res://assets/audio/sfx/pickup/pickup_currency_0.ogg",
			"res://assets/audio/sfx/pickup/pickup_currency_1.ogg",
		],
		"volume_db": -9.0, "max_per_frame": 2, "min_interval_ms": 45,
	},
	"sfx_pickup_weapon": {
		"streams": ["res://assets/audio/sfx/pickup/pickup_weapon.ogg"],
		"volume_db": -6.0, "max_per_frame": 1,
	},
	"sfx_pickup_mod": {
		"streams": ["res://assets/audio/sfx/pickup/pickup_mod.ogg"],
		"volume_db": -8.0, "max_per_frame": 1,
	},
	"sfx_pickup_keystone": {
		"streams": ["res://assets/audio/sfx/pickup/pickup_keystone.ogg"],
		"volume_db": -6.0, "max_per_frame": 1,
	},

	# ── Progression / UI (P1: level_up; P2: rest — real assets) ─────────────
	"sfx_level_up": {
		"streams": ["res://assets/audio/sfx/ui/level_up.ogg"],
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
	"sfx_ui_cancel": {
		"streams": ["res://assets/audio/sfx/ui/ui_cancel.ogg"],
		"volume_db": -8.0,
	},

	# ── Extraction lifecycle (P1: complete; P2: rest — real assets) ─────────
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
		"volume_db": -12.0, "pitch_variance": 0.0, "loop": true,
	},
	"sfx_extraction_channel_complete": {
		"streams": ["res://assets/audio/sfx/extraction/extraction_channel_complete.ogg"],
		"volume_db": -4.0, "max_per_frame": 1, "pitch_variance": 0.0,
	},
	"sfx_extraction_interrupted": {
		"streams": ["res://assets/audio/sfx/extraction/extraction_interrupted.ogg"],
		"volume_db": -6.0, "pitch_variance": 0.0,
	},

	# ── Boss (P2 — real asset) ───────────────────────────────────────────────
	"sfx_boss_intro": {
		"streams": ["res://assets/audio/sfx/combat/boss_intro.ogg"],
		"volume_db": -3.0, "max_per_frame": 1, "pitch_variance": 0.0,
	},

	# ── Dashes (task 15 — synthesized in-house, see _incoming/reaper_sfx) ───
	"sfx_dash_generic": {
		"streams": ["res://assets/audio/sfx/dash/dash_generic.ogg"],
		"volume_db": -11.0, "max_per_frame": 1, "min_interval_ms": 100,
	},
	"sfx_dash_teleport": {
		"streams": ["res://assets/audio/sfx/dash/dash_teleport.ogg"],
		"volume_db": -10.0, "max_per_frame": 1, "min_interval_ms": 100,
	},
	"sfx_dash_deadly": {
		"streams": ["res://assets/audio/sfx/dash/dash_deadly.ogg"],
		"volume_db": -10.0, "max_per_frame": 1, "min_interval_ms": 100,
	},
	"sfx_dash_dodge_roll": {
		"streams": ["res://assets/audio/sfx/dash/dash_dodge_roll.ogg"],
		"volume_db": -11.0, "max_per_frame": 1, "min_interval_ms": 100,
	},
}

## Music tracks: id → { stream, volume_db }. Looping is handled by AudioManager
## (finished → replay), so tracks work whether or not import loop points are set.
const MUSIC: Dictionary = {
	"mus_hub": {
		"stream": "res://assets/audio/music/hub.ogg",
		"volume_db": -8.0,
	},
	"mus_caves": {
		"stream": "res://assets/audio/music/caves.ogg",
		"volume_db": -6.0,
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
		"stream": "res://assets/audio/music/boss.ogg",
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
	## Self-cast wards and buffs (2026-08-02). These land on the player from a Q/E cast with no
	## competing sound on the frame, which is what makes them worth voicing — see the scope note
	## on sfx_status_buff_apply. Unmapped statuses stay silent by design.
	"steeled": "sfx_status_buff_apply",           ## Fighter — Second Wind's ward
	"hallowed": "sfx_status_buff_apply",          ## Paladin — Lay on Hands
	"blessed": "sfx_status_buff_apply",
	"battle_fury": "sfx_status_buff_apply",
	"honed_edge": "sfx_status_buff_apply",
	"loaded_chambers": "sfx_status_buff_apply",   ## Gunslinger — Reload
	"aegis_shield": "sfx_status_buff_apply",
	"second_wind": "sfx_status_buff_apply",
}

## melee_kit id → the sustained bed played while that kit holds a channel.
## Grouped by timbre rather than one-per-kit: three beds cover twelve kits without twelve
## renders, and a channel bed is background texture, not an identity cue.
## Kits absent from this map simply get no bed.
const CHANNEL_LOOP_BY_KIT: Dictionary = {
	"demonologist": "sfx_channel_loop_fire",     ## Immolate
	"blood_mage":   "sfx_channel_loop_fire",
	"wizard":       "sfx_channel_loop_arcane",
	"necromancer":  "sfx_channel_loop_arcane",   ## Bone Barrage
	"druid":        "sfx_channel_loop_arcane",   ## Bramble Barrage
	"cleric":       "sfx_channel_loop_arcane",
	"fighter":      "sfx_channel_loop_martial",  ## Taunt
	"paladin":      "sfx_channel_loop_martial",  ## Dictum / Reckoning dome
	"barbarian":    "sfx_channel_loop_martial",
	"ninja":        "sfx_channel_loop_martial",
	"gunslinger":   "sfx_channel_loop_martial",
	"ranger":       "sfx_channel_loop_martial",
}

## pickup_type (EventBus.on_pickup payload) → sound ID.
const PICKUP_SOUND: Dictionary = {
	"xp": "sfx_pickup_xp",
	"currency": "sfx_pickup_currency",
	"weapon": "sfx_pickup_weapon",
	"mod": "sfx_pickup_mod",
	"keystone": "sfx_pickup_keystone",
}
