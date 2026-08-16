@tool
extends RefCounted

## Generates the 19 Threshold enemy scenes from Minifantasy_Dark_Brotherhood (the cult) and
## Minifantasy_Dark_Orc_Army (the army). Same approach as tools/gen_nightmare_scenes.gd and
## tools/gen_undead_scenes.gd: build the CharacterBody2D + AnimatedSprite2D through Godot's
## own PackedScene serialisation, because hand-writing nineteen .tscn files is not viable and
## hand-editing .tscn is forbidden by CLAUDE.md.
##
## Row convention: enemy.gd renders enemies from ONE row and mirrors with flip_h
## (enemy.gd:408), as every shipped enemy scene does, so only one facing row is sliced per
## anim. Both packs ship four facing rows; the other three go unused for the same engine-wide
## reason they do on every existing enemy.
##
## THE TRAP THIS FILE EXISTS TO HANDLE: **cell size is not constant across these packs.**
## gen_nightmare_scenes.gd could hardcode CELL = 32; here that would silently mis-slice five
## units. The Flagellant, Dark Abomination and Dark Hound are 40x40, and the Cave Troll is
## 48x48, while everything else is 32x32. An oversized creature drawn on a 32px stride does
## not error — it renders the top-left corner of each frame and looks like a cropped bug. So
## every spec carries its own `cell`, derived from `Dmg.png` height / 4 (Dmg is 4 frames x 4
## facings in both packs) and verified against every sheet before writing.
##
## Other pack-specific notes, each found by measuring the sheet rather than reading its name:
##
##   - Die.png is ONE row in both packs, not four. Death slices from row 0, which is what the
##     bounds check below expects; requesting row 1 of a death sheet would silently produce
##     an off-sheet, invisible animation.
##   - The Devoted Stalker, Warbreed Arbalist and Orc Scout have NO Attack.png. Their attack
##     is Shot_Orthogonal.png — a body animation of the shot being fired. (Only the Stalker
##     also ships a separate Shot_Projectile.png; see threshold_enemy_data.gd.)
##   - The Warg has no Attack.png either: Bite.png IS its attack.
##   - The Dark Channeler has neither Attack nor Shot. Possess.png is its cast animation,
##     and its Possess_Acolyte / Possess_Hound / Possess_Zealot sheets are deliberately
##     unwired — they are mid-life transforms and enemy.gd has no hook for that. Same call
##     the Monster pack's Werewolf/Transformation got.
##   - The Orc Raider ships both Attack.png and Bite.png. Attack (the weapon swing) is the
##     attack; Bite is left unwired rather than replacing a perfectly good swing.

const BROTHERHOOD: String = "res://assets/minifantasy/Minifantasy_Dark_Brotherhood_v1.0/Dark_Brotherhood/"
const ORCS: String = "res://assets/minifantasy/Minifantasy_Dark_Orc_Army_v1.0/Dark_Orc_Army/"

## Both packs document the same cadence in their _AnimationInfo.txt: 200ms (5fps) for
## Idle/Walk, 100ms (10fps) for Attack/Dmg/Die. Identical to the Catacombs and Nightmare
## rosters, so the whole game's enemies share one timing language.
const FPS_SLOW: float = 5.0
const FPS_FAST: float = 10.0


## spec: { cell, scene, anims: { anim: [path, row, first_frame, count, fps, loop] }, body, hurt }
static func _specs() -> Dictionary:
	return {
		# ── the cult ──────────────────────────────────────────────────────────
		"ThFodder": {
			"cell": 32, "scene": "th_fodder",
			"anims": {
				"idle":   [BROTHERHOOD + "Cannon_Fodder/Acolyte/Idle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [BROTHERHOOD + "Cannon_Fodder/Acolyte/Walk.png", 0, 0, 4, FPS_SLOW, true],
				"attack": [BROTHERHOOD + "Cannon_Fodder/Acolyte/Attack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [BROTHERHOOD + "Cannon_Fodder/Acolyte/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [BROTHERHOOD + "Cannon_Fodder/Acolyte/Die.png", 0, 0, 24, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		"ThSwarmer": {
			"cell": 32, "scene": "th_swarmer",
			"anims": {
				"idle":   [BROTHERHOOD + "Cannon_Fodder/Hound/Idle.png", 0, 0, 20, FPS_SLOW, true],
				"walk":   [BROTHERHOOD + "Cannon_Fodder/Hound/Walk.png", 0, 0, 4, FPS_SLOW, true],
				"attack": [BROTHERHOOD + "Cannon_Fodder/Hound/Attack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [BROTHERHOOD + "Cannon_Fodder/Hound/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [BROTHERHOOD + "Cannon_Fodder/Hound/Die.png", 0, 0, 15, FPS_FAST, false],
			}, "body": Vector2(11, 9), "hurt": Vector2(15, 13),
		},
		"ThZealot": {
			"cell": 32, "scene": "th_zealot",
			"anims": {
				"idle":   [BROTHERHOOD + "Cannon_Fodder/Zealot/Idle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [BROTHERHOOD + "Cannon_Fodder/Zealot/Walk.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [BROTHERHOOD + "Cannon_Fodder/Zealot/Attack.png", 0, 0, 11, FPS_FAST, false],
				"damage": [BROTHERHOOD + "Cannon_Fodder/Zealot/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [BROTHERHOOD + "Cannon_Fodder/Zealot/Die.png", 0, 0, 14, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		# ── the devoted ───────────────────────────────────────────────────────
		"ThSkirmisher": {
			"cell": 32, "scene": "th_skirmisher",
			"anims": {
				"idle":   [BROTHERHOOD + "Devoted_Brothers/Devoted_Blade/Idle.png", 0, 0, 21, FPS_SLOW, true],
				"walk":   [BROTHERHOOD + "Devoted_Brothers/Devoted_Blade/Walk.png", 0, 0, 4, FPS_SLOW, true],
				"attack": [BROTHERHOOD + "Devoted_Brothers/Devoted_Blade/Attack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [BROTHERHOOD + "Devoted_Brothers/Devoted_Blade/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [BROTHERHOOD + "Devoted_Brothers/Devoted_Blade/Die.png", 0, 0, 24, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		"ThSentinel": {
			"cell": 32, "scene": "th_sentinel",
			"anims": {
				"idle":   [BROTHERHOOD + "Devoted_Brothers/Devoted_Sentinel/Idle.png", 0, 0, 21, FPS_SLOW, true],
				"walk":   [BROTHERHOOD + "Devoted_Brothers/Devoted_Sentinel/Walk.png", 0, 0, 4, FPS_SLOW, true],
				"attack": [BROTHERHOOD + "Devoted_Brothers/Devoted_Sentinel/Attack.png", 0, 0, 6, FPS_FAST, false],
				"damage": [BROTHERHOOD + "Devoted_Brothers/Devoted_Sentinel/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [BROTHERHOOD + "Devoted_Brothers/Devoted_Sentinel/Die.png", 0, 0, 26, FPS_FAST, false],
			}, "body": Vector2(11, 11), "hurt": Vector2(15, 15),
		},
		"ThArcher": {
			"cell": 32, "scene": "th_archer",
			"anims": {
				"idle":   [BROTHERHOOD + "Devoted_Brothers/Devoted_Stalker/Idle.png", 0, 0, 21, FPS_SLOW, true],
				"walk":   [BROTHERHOOD + "Devoted_Brothers/Devoted_Stalker/Walk.png", 0, 0, 4, FPS_SLOW, true],
				## no Attack sheet — the shot IS the attack
				"attack": [BROTHERHOOD + "Devoted_Brothers/Devoted_Stalker/Shot_Orthogonal.png", 0, 0, 11, FPS_FAST, false],
				"damage": [BROTHERHOOD + "Devoted_Brothers/Devoted_Stalker/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [BROTHERHOOD + "Devoted_Brothers/Devoted_Stalker/Die.png", 0, 0, 15, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		# ── the chosen ────────────────────────────────────────────────────────
		"ThCaster": {
			"cell": 32, "scene": "th_caster",
			"anims": {
				"idle":   [BROTHERHOOD + "Choosen_Ones/Dark_Channeler/Idle.png", 0, 0, 20, FPS_SLOW, true],
				"walk":   [BROTHERHOOD + "Choosen_Ones/Dark_Channeler/Walk.png", 0, 0, 4, FPS_SLOW, true],
				## Possess IS the cast — see the header on why the three Possess_<unit> sheets stay unwired
				"attack": [BROTHERHOOD + "Choosen_Ones/Dark_Channeler/Possess.png", 0, 0, 15, FPS_FAST, false],
				"damage": [BROTHERHOOD + "Choosen_Ones/Dark_Channeler/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [BROTHERHOOD + "Choosen_Ones/Dark_Channeler/Die.png", 0, 0, 19, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		"ThFlagellant": {
			"cell": 40, "scene": "th_flagellant",
			"anims": {
				"idle":   [BROTHERHOOD + "Choosen_Ones/Flagellant/Idle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [BROTHERHOOD + "Choosen_Ones/Flagellant/Walk.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [BROTHERHOOD + "Choosen_Ones/Flagellant/Attack.png", 0, 0, 13, FPS_FAST, false],
				"damage": [BROTHERHOOD + "Choosen_Ones/Flagellant/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [BROTHERHOOD + "Choosen_Ones/Flagellant/Die.png", 0, 0, 28, FPS_FAST, false],
			}, "body": Vector2(11, 11), "hurt": Vector2(15, 15),
		},
		# ── the possessed ─────────────────────────────────────────────────────
		"ThPossessed": {
			"cell": 32, "scene": "th_possessed",
			"anims": {
				"idle":   [BROTHERHOOD + "Possessed/Dark_Cultist/Idle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [BROTHERHOOD + "Possessed/Dark_Cultist/Walk.png", 0, 0, 8, FPS_SLOW, true],
				"attack": [BROTHERHOOD + "Possessed/Dark_Cultist/Attack.png", 0, 0, 16, FPS_FAST, false],
				"damage": [BROTHERHOOD + "Possessed/Dark_Cultist/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [BROTHERHOOD + "Possessed/Dark_Cultist/Die.png", 0, 0, 19, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		"ThHound": {
			"cell": 40, "scene": "th_hound",
			"anims": {
				"idle":   [BROTHERHOOD + "Possessed/Dark_Hound/Idle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [BROTHERHOOD + "Possessed/Dark_Hound/Walk.png", 0, 0, 4, FPS_SLOW, true],
				"attack": [BROTHERHOOD + "Possessed/Dark_Hound/Attack.png", 0, 0, 9, FPS_FAST, false],
				"damage": [BROTHERHOOD + "Possessed/Dark_Hound/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [BROTHERHOOD + "Possessed/Dark_Hound/Die.png", 0, 0, 24, FPS_FAST, false],
			}, "body": Vector2(12, 10), "hurt": Vector2(16, 14),
		},
		"ThAbomination": {
			"cell": 40, "scene": "th_abomination",
			"anims": {
				"idle":   [BROTHERHOOD + "Possessed/Dark_Abomination/Idle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [BROTHERHOOD + "Possessed/Dark_Abomination/Walk.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [BROTHERHOOD + "Possessed/Dark_Abomination/Attack.png", 0, 0, 9, FPS_FAST, false],
				"damage": [BROTHERHOOD + "Possessed/Dark_Abomination/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [BROTHERHOOD + "Possessed/Dark_Abomination/Die.png", 0, 0, 28, FPS_FAST, false],
			}, "body": Vector2(14, 12), "hurt": Vector2(18, 16),
		},
		# ── the army ──────────────────────────────────────────────────────────
		"ThRaider": {
			"cell": 32, "scene": "th_raider",
			"anims": {
				"idle":   [ORCS + "Lesser_Orcs/Orc_Raider/Idle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [ORCS + "Lesser_Orcs/Orc_Raider/Walk.png", 0, 0, 4, FPS_SLOW, true],
				"attack": [ORCS + "Lesser_Orcs/Orc_Raider/Attack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [ORCS + "Lesser_Orcs/Orc_Raider/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [ORCS + "Lesser_Orcs/Orc_Raider/Die.png", 0, 0, 28, FPS_FAST, false],
			}, "body": Vector2(11, 11), "hurt": Vector2(15, 15),
		},
		"ThBerserker": {
			"cell": 32, "scene": "th_berserker",
			"anims": {
				"idle":   [ORCS + "Warbreed_Orcs/Warbreed_Berserker/Idle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [ORCS + "Warbreed_Orcs/Warbreed_Berserker/Walk.png", 0, 0, 4, FPS_SLOW, true],
				"attack": [ORCS + "Warbreed_Orcs/Warbreed_Berserker/Attack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [ORCS + "Warbreed_Orcs/Warbreed_Berserker/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [ORCS + "Warbreed_Orcs/Warbreed_Berserker/Die.png", 0, 0, 18, FPS_FAST, false],
			}, "body": Vector2(11, 11), "hurt": Vector2(15, 15),
		},
		"ThPhalanx": {
			"cell": 32, "scene": "th_phalanx",
			"anims": {
				"idle":   [ORCS + "Warbreed_Orcs/Warbreed_Phalanx/Idle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [ORCS + "Warbreed_Orcs/Warbreed_Phalanx/Walk.png", 0, 0, 4, FPS_SLOW, true],
				"attack": [ORCS + "Warbreed_Orcs/Warbreed_Phalanx/Attack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [ORCS + "Warbreed_Orcs/Warbreed_Phalanx/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [ORCS + "Warbreed_Orcs/Warbreed_Phalanx/Die.png", 0, 0, 18, FPS_FAST, false],
			}, "body": Vector2(12, 12), "hurt": Vector2(16, 16),
		},
		"ThArbalist": {
			"cell": 32, "scene": "th_arbalist",
			"anims": {
				"idle":   [ORCS + "Warbreed_Orcs/Warbreed_Arbalist/Idle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [ORCS + "Warbreed_Orcs/Warbreed_Arbalist/Walk.png", 0, 0, 4, FPS_SLOW, true],
				## no Attack sheet — the shot IS the attack
				"attack": [ORCS + "Warbreed_Orcs/Warbreed_Arbalist/Shot_Orthogonal.png", 0, 0, 12, FPS_FAST, false],
				"damage": [ORCS + "Warbreed_Orcs/Warbreed_Arbalist/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [ORCS + "Warbreed_Orcs/Warbreed_Arbalist/Die.png", 0, 0, 18, FPS_FAST, false],
			}, "body": Vector2(11, 11), "hurt": Vector2(15, 15),
		},
		"ThWarg": {
			"cell": 32, "scene": "th_warg",
			"anims": {
				"idle":   [ORCS + "Others/Warg/Idle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [ORCS + "Others/Warg/Walk.png", 0, 0, 4, FPS_SLOW, true],
				## no Attack sheet — Bite IS its attack
				"attack": [ORCS + "Others/Warg/Bite.png", 0, 0, 8, FPS_FAST, false],
				"damage": [ORCS + "Others/Warg/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [ORCS + "Others/Warg/Die.png", 0, 0, 28, FPS_FAST, false],
			}, "body": Vector2(12, 9), "hurt": Vector2(16, 13),
		},
		"ThTroll": {
			"cell": 48, "scene": "th_troll",
			"anims": {
				"idle":   [ORCS + "Others/Cave_Troll/Idle.png", 0, 0, 10, FPS_SLOW, true],
				"walk":   [ORCS + "Others/Cave_Troll/Walk.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [ORCS + "Others/Cave_Troll/Attack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [ORCS + "Others/Cave_Troll/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [ORCS + "Others/Cave_Troll/Die.png", 0, 0, 40, FPS_FAST, false],
			}, "body": Vector2(17, 15), "hurt": Vector2(22, 20),
		},
		# ── bosses ────────────────────────────────────────────────────────────
		"RitualGuard": {
			"cell": 32, "scene": "ritual_guard",
			"anims": {
				"idle":   [BROTHERHOOD + "Choosen_Ones/Ritual_Guard/Idle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [BROTHERHOOD + "Choosen_Ones/Ritual_Guard/Walk.png", 0, 0, 4, FPS_SLOW, true],
				"attack": [BROTHERHOOD + "Choosen_Ones/Ritual_Guard/Attack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [BROTHERHOOD + "Choosen_Ones/Ritual_Guard/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [BROTHERHOOD + "Choosen_Ones/Ritual_Guard/Die.png", 0, 0, 26, FPS_FAST, false],
			}, "body": Vector2(16, 14), "hurt": Vector2(20, 18),
		},
		"PaleChampion": {
			"cell": 32, "scene": "pale_champion",
			"anims": {
				"idle":   [ORCS + "Others/Pale_Champion/Idle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [ORCS + "Others/Pale_Champion/Walk.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [ORCS + "Others/Pale_Champion/Attack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [ORCS + "Others/Pale_Champion/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [ORCS + "Others/Pale_Champion/Die.png", 0, 0, 21, FPS_FAST, false],
			}, "body": Vector2(18, 18), "hurt": Vector2(24, 24),
		},
	}


static func generate() -> Array[String]:
	var log: Array[String] = []
	var enemy_script: Script = load("res://scripts/entities/enemy.gd")
	var specs: Dictionary = _specs()

	for node_name: String in specs:
		var spec: Dictionary = specs[node_name]
		var anims: Dictionary = spec["anims"]
		var cell: int = spec["cell"]

		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		var ok: bool = true
		for anim_name: String in anims:
			var a: Array = anims[anim_name]
			var path: String = a[0]
			var row: int = a[1]
			var first: int = a[2]
			var count: int = a[3]
			var fps: float = a[4]
			var loop: bool = a[5]
			var tex: Texture2D = load(path)
			if tex == null:
				log.append("  MISSING SHEET %s -> %s" % [node_name, path])
				ok = false
				continue
			## Guard the slice against the sheet: an off-sheet region renders as empty,
			## silently. With per-unit cell sizes this check is doing real work — a 40px
			## creature sliced at 32 passes a naive path check and renders cropped.
			var need_w: int = (first + count) * cell
			var need_h: int = (row + 1) * cell
			if tex.get_width() < need_w or tex.get_height() < need_h:
				log.append("  SLICE OUT OF BOUNDS %s/%s (cell %d): sheet %dx%d, needs %dx%d" % [
					node_name, anim_name, cell, tex.get_width(), tex.get_height(), need_w, need_h])
				ok = false
				continue
			## Catch the inverse too: a cell size that does not divide the sheet evenly means
			## the spec's `cell` is wrong, even though every slice happens to fit.
			if tex.get_width() % cell != 0 or tex.get_height() % cell != 0:
				log.append("  CELL MISMATCH %s/%s: sheet %dx%d not divisible by cell %d" % [
					node_name, anim_name, tex.get_width(), tex.get_height(), cell])
				ok = false
				continue
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, fps)
			frames.set_animation_loop(anim_name, loop)
			for i in count:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2((first + i) * cell, row * cell, cell, cell)
				at.filter_clip = true          ## required for small art on a larger stride
				frames.add_frame(anim_name, at)
		if not ok:
			continue

		var body := CharacterBody2D.new()
		body.name = node_name
		body.collision_layer = 2               ## enemies
		body.collision_mask = 3                ## player + enemies
		body.set_script(enemy_script)

		var sprite := AnimatedSprite2D.new()
		sprite.name = "Sprite"
		sprite.sprite_frames = frames
		sprite.animation = &"idle"
		sprite.autoplay = "idle"
		body.add_child(sprite)
		sprite.owner = body

		var hurtbox := Area2D.new()
		hurtbox.name = "Hurtbox"
		hurtbox.collision_layer = 2
		hurtbox.collision_mask = 0
		body.add_child(hurtbox)
		hurtbox.owner = body

		var hurt_shape := CollisionShape2D.new()
		hurt_shape.name = "CollisionShape"
		var hr := RectangleShape2D.new()
		hr.size = spec["hurt"]
		hurt_shape.shape = hr
		hurtbox.add_child(hurt_shape)
		hurt_shape.owner = body

		var body_shape := CollisionShape2D.new()
		body_shape.name = "CollisionShape"
		var br := RectangleShape2D.new()
		br.size = spec["body"]
		body_shape.shape = br
		body.add_child(body_shape)
		body_shape.owner = body

		var packed := PackedScene.new()
		if packed.pack(body) != OK:
			log.append("  PACK FAILED %s" % node_name)
			body.free()
			continue
		var out_path: String = "res://scenes/enemies/%s.tscn" % spec["scene"]
		var err: int = ResourceSaver.save(packed, out_path)
		log.append("  %s  %s  (%d anims)" % ["OK  " if err == OK else "ERR ", out_path, frames.get_animation_names().size()])
		body.free()

	return log
