@tool
extends RefCounted

## Generates the 15 Nightmare Realm enemy scenes from the Minifantasy_Monster_Creatures pack.
##
## Enemy scenes are CharacterBody2D + AnimatedSprite2D with the SpriteFrames baked in as
## sub-resources (see scenes/enemies/cave_brute.tscn). Hand-writing fifteen of those is not
## viable and hand-editing .tscn is forbidden by CLAUDE.md, so they are built through Godot's
## own PackedScene serialisation instead — the same result the editor would produce. Same
## approach as tools/gen_undead_scenes.gd, which built the Catacombs roster.
##
## Row convention: enemy.gd renders enemies from ONE row and mirrors with flip_h (enemy.gd:408),
## exactly as every shipped enemy scene does, so only one facing row is sliced per anim. The
## pack's other three facing rows are unused for the same reason they are unused on every
## existing enemy — an engine-wide convention, not an oversight in this pack.
##
## Pack-specific traps this file handles, each found by rendering the sheet rather than
## reading its name:
##
##   - The Chest Mimic ships NO Attack sheet. Its Activation.png is 16 frames x 2 rows, and
##     frames 0-7 are still a closed, glowing chest — slicing from 0 would make its attack look
##     like an idle box. Frames 8-15 are the reveal: it sprouts legs, rears and bares fangs.
##     Those are the attack.
##   - The Predatory Mushroom ships no Walk sheet (it is rooted), so Idle doubles as its
##     locomotion — the same treatment the Catacombs Ghost got for the same reason.
##   - The Gargoyle and the Angel of Death both fly: Fly.png IS their walk.
##   - Werewolf/Transformation is 16 frames x 2 ROWS — a sequence (row 0 human collapsing,
##     row 1 wolf rising), not two facings. Unwired: enemy.gd has no mid-life transform hook.
##     The two shapes ship as two separate units instead (nm_swarmer / nm_stalker).
##   - The pack folder is spelled "Agressive Chest Mimic" (one g). That is the pack's typo,
##     not ours; the path has to match it exactly.

const PACK: String = "res://assets/minifantasy/Minifantasy_Monster_Creatures_v1.0/Minifantasy_Monster_Creatures_Assets/"
const CELL: int = 32

## 200ms (5fps) idle/walk, 100ms (10fps) attack/dmg/die — same cadence as the Catacombs roster.
const FPS_SLOW: float = 5.0
const FPS_FAST: float = 10.0


## spec: { anim: [path, row, first_frame, count, fps, loop] }
static func _specs() -> Dictionary:
	return {
		"NmFodder": {
			"scene": "nm_fodder",
			"anims": {
				"idle":   [PACK + "Giant_Rat/RatIdle.png", 0, 0, 13, FPS_SLOW, true],
				"walk":   [PACK + "Giant_Rat/RatWalk.png", 0, 0, 4, FPS_SLOW, true],
				"attack": [PACK + "Giant_Rat/RatAttack.png", 0, 0, 5, FPS_FAST, false],
				"damage": [PACK + "Giant_Rat/RatDmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Giant_Rat/RatDie.png", 0, 0, 11, FPS_FAST, false],
			}, "body": Vector2(10, 9), "hurt": Vector2(14, 13),
		},
		"NmSwarmer": {
			"scene": "nm_swarmer",
			"anims": {
				"idle":   [PACK + "Werewolf/Wolf_Shape/Minifantasy_WerewolfWolfIdle.png", 0, 0, 23, FPS_SLOW, true],
				"walk":   [PACK + "Werewolf/Wolf_Shape/Minifantasy_WerewolfWolfWalk.png", 0, 0, 4, FPS_SLOW, true],
				"attack": [PACK + "Werewolf/Wolf_Shape/Minifantasy_WerewolfWolfAttack.png", 0, 0, 6, FPS_FAST, false],
				"damage": [PACK + "Werewolf/Wolf_Shape/Minifantasy_WerewolfWolfDmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Werewolf/Wolf_Shape/Minifantasy_WerewolfWolfDie.png", 0, 0, 16, FPS_FAST, false],
			}, "body": Vector2(11, 9), "hurt": Vector2(15, 13),
		},
		"NmSkirmisher": {
			"scene": "nm_skirmisher",
			"anims": {
				"idle":   [PACK + "Gnoll/Idle_gnoll.png", 0, 0, 20, FPS_SLOW, true],
				"walk":   [PACK + "Gnoll/Walk_gnoll.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [PACK + "Gnoll/Attack_gnoll.png", 0, 0, 8, FPS_FAST, false],
				"damage": [PACK + "Gnoll/Dmg_gnoll.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Gnoll/Die_gnoll.png", 0, 0, 16, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		"NmStalker": {
			"scene": "nm_stalker",
			"anims": {
				"idle":   [PACK + "Werewolf/Human_Shape/Minifantasy_WerewolfHumanIdle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [PACK + "Werewolf/Human_Shape/Minifantasy_WerewolfHumanWalk.png", 0, 0, 4, FPS_SLOW, true],
				"attack": [PACK + "Werewolf/Human_Shape/Minifantasy_WerewolfHumanAttack.png", 0, 0, 4, FPS_FAST, false],
				"damage": [PACK + "Werewolf/Human_Shape/Minifantasy_WerewolfHumanDmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Werewolf/Human_Shape/Minifantasy_WerewolfHumanDie.png", 0, 0, 12, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		"NmRaider": {
			"scene": "nm_raider",
			"anims": {
				"idle":   [PACK + "Deep_One/DeepOneIdle.png", 0, 0, 20, FPS_SLOW, true],
				"walk":   [PACK + "Deep_One/DeepOneWalk.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [PACK + "Deep_One/DeepOneAttack.png", 0, 0, 6, FPS_FAST, false],
				"damage": [PACK + "Deep_One/DeepOneDmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Deep_One/DeepOneDie.png", 0, 0, 25, FPS_FAST, false],
			}, "body": Vector2(11, 11), "hurt": Vector2(15, 15),
		},
		"NmAmbusher": {
			"scene": "nm_ambusher",
			"anims": {
				"idle":   [PACK + "Chest_Mimic/Agressive Chest Mimic/AggressiveChestMimicIdle.png", 0, 0, 2, FPS_SLOW, true],
				"walk":   [PACK + "Chest_Mimic/Agressive Chest Mimic/AggressiveChestMimicWalk.png", 0, 0, 6, FPS_SLOW, true],
				## frames 8-15 of Activation = the reveal (legs out, reared, fangs) — see header
				"attack": [PACK + "Chest_Mimic/Agressive Chest Mimic/AggressiveChestMimicActivation.png", 0, 8, 8, FPS_FAST, false],
				"damage": [PACK + "Chest_Mimic/Agressive Chest Mimic/AggressiveChestMimicDmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Chest_Mimic/Agressive Chest Mimic/AggressiveChestMimicDie.png", 0, 0, 18, FPS_FAST, false],
			}, "body": Vector2(11, 10), "hurt": Vector2(15, 14),
		},
		"NmLurker": {
			"scene": "nm_lurker",
			"anims": {
				"idle":   [PACK + "Chest_Mimic/Shy Chest Mimic/ShyChestMimicIdle.png", 0, 0, 2, FPS_SLOW, true],
				"walk":   [PACK + "Chest_Mimic/Shy Chest Mimic/ShyChestMimicWalk.png", 0, 0, 6, FPS_SLOW, true],
				## same reveal-is-the-attack treatment as the Aggressive variant
				"attack": [PACK + "Chest_Mimic/Shy Chest Mimic/ShyChestMimicActivation.png", 0, 8, 8, FPS_FAST, false],
				"damage": [PACK + "Chest_Mimic/Shy Chest Mimic/ShyChestMimicDmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Chest_Mimic/Shy Chest Mimic/ShyChestMimicDie.png", 0, 0, 18, FPS_FAST, false],
			}, "body": Vector2(10, 9), "hurt": Vector2(14, 13),
		},
		"NmAerial": {
			"scene": "nm_aerial",
			"anims": {
				"idle":   [PACK + "Gargoyle/GargoyleIdle.png", 0, 0, 16, FPS_SLOW, true],
				## it flies — Fly IS its locomotion, so Walk.png goes unused for this unit
				"walk":   [PACK + "Gargoyle/GargoyleFly.png", 0, 0, 5, FPS_SLOW, true],
				"attack": [PACK + "Gargoyle/GargoyleAttack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [PACK + "Gargoyle/GargoyleDmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Gargoyle/GargoyleDie.png", 0, 0, 34, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		"NmArcher": {
			"scene": "nm_archer",
			"anims": {
				"idle":   [PACK + "Rat_People/RatPeopleIdle.png", 0, 0, 23, FPS_SLOW, true],
				"walk":   [PACK + "Rat_People/RatPeopleWalk.png", 0, 0, 4, FPS_SLOW, true],
				"attack": [PACK + "Rat_People/RatPeopleAttackOrthogonal.png", 0, 0, 12, FPS_FAST, false],
				"damage": [PACK + "Rat_People/RatPeopleDmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Rat_People/RatPeopleDie.png", 0, 0, 16, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		"NmCaster": {
			"scene": "nm_caster",
			"anims": {
				"idle":   [PACK + "Brain_Slayer/BrainSlayerIdle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [PACK + "Brain_Slayer/BrainSlayerWalk.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [PACK + "Brain_Slayer/BrainSlayerOrthogonalAttack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [PACK + "Brain_Slayer/BrainSlayerDmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Brain_Slayer/BrainSlayerDie.png", 0, 0, 18, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		"NmRoyal": {
			"scene": "nm_royal",
			"anims": {
				"idle":   [PACK + "Rat_People_Royalty/Idle.png", 0, 0, 12, FPS_SLOW, true],
				"walk":   [PACK + "Rat_People_Royalty/Walk.png", 0, 0, 6, FPS_SLOW, true],
				## Throw_Rat IS the monarch's attack — the thrown rat is its projectile
				"attack": [PACK + "Rat_People_Royalty/Throw_Rat.png", 0, 0, 20, FPS_FAST, false],
				"damage": [PACK + "Rat_People_Royalty/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Rat_People_Royalty/Die.png", 0, 0, 19, FPS_FAST, false],
			}, "body": Vector2(11, 11), "hurt": Vector2(15, 15),
		},
		"NmSpore": {
			"scene": "nm_spore",
			"anims": {
				"idle":   [PACK + "Predatory_Mushroom/Idle.png", 0, 0, 12, FPS_SLOW, true],
				## no Walk sheet — it is rooted, so Idle doubles as locomotion (cf. the Ghost)
				"walk":   [PACK + "Predatory_Mushroom/Idle.png", 0, 0, 12, FPS_SLOW, true],
				"attack": [PACK + "Predatory_Mushroom/Spores_Attack.png", 0, 0, 17, FPS_FAST, false],
				"damage": [PACK + "Predatory_Mushroom/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Predatory_Mushroom/Die.png", 0, 0, 20, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		"NmBrute": {
			"scene": "nm_brute",
			"anims": {
				"idle":   [PACK + "Demon_Spider/DemonSpiderIdle.png", 0, 0, 20, FPS_SLOW, true],
				"walk":   [PACK + "Demon_Spider/DemonSpiderWalk.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [PACK + "Demon_Spider/DemonSpiderAttack.png", 0, 0, 6, FPS_FAST, false],
				"damage": [PACK + "Demon_Spider/DemonSpiderDmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Demon_Spider/DemonSpiderDie.png", 0, 0, 27, FPS_FAST, false],
			}, "body": Vector2(14, 12), "hurt": Vector2(18, 16),
		},
		"NmHeavy": {
			"scene": "nm_heavy",
			"anims": {
				"idle":   [PACK + "Giant/GiantIdle.png", 0, 0, 25, FPS_SLOW, true],
				"walk":   [PACK + "Giant/GiantWalk.png", 0, 0, 8, FPS_SLOW, true],
				"attack": [PACK + "Giant/GiantAttack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [PACK + "Giant/GiantDmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Giant/GiantDie.png", 0, 0, 32, FPS_FAST, false],
			}, "body": Vector2(16, 14), "hurt": Vector2(20, 18),
		},
		"CentaurKing": {
			"scene": "centaur_king",
			"anims": {
				"idle":   [PACK + "Centaur_King/CentaurKingIdle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [PACK + "Centaur_King/CentaurKingWalk.png", 0, 0, 4, FPS_SLOW, true],
				"attack": [PACK + "Centaur_King/CentaurKingAttack.png", 0, 0, 7, FPS_FAST, false],
				"damage": [PACK + "Centaur_King/CentaurKingDmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Centaur_King/CentaurKingDie.png", 0, 0, 20, FPS_FAST, false],
			}, "body": Vector2(16, 14), "hurt": Vector2(20, 18),
		},
		"AngelOfDeath": {
			"scene": "angel_of_death",
			"anims": {
				"idle":   [PACK + "Angel_of_Death/AngelOfDeathIdle.png", 0, 0, 6, FPS_SLOW, true],
				## it flies and has no Walk sheet at all — Fly IS its locomotion
				"walk":   [PACK + "Angel_of_Death/AngelOfDeathFly.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [PACK + "Angel_of_Death/AngelOfDeathAttack.png", 0, 0, 6, FPS_FAST, false],
				"damage": [PACK + "Angel_of_Death/AngelOfDeathDmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Angel_of_Death/AngelOfDeathDie.png", 0, 0, 19, FPS_FAST, false],
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
			## Guard the slice against the sheet: an off-sheet region renders as empty, silently.
			var need_w: int = (first + count) * CELL
			var need_h: int = (row + 1) * CELL
			if tex.get_width() < need_w or tex.get_height() < need_h:
				log.append("  SLICE OUT OF BOUNDS %s/%s: sheet %dx%d, needs %dx%d" % [
					node_name, anim_name, tex.get_width(), tex.get_height(), need_w, need_h])
				ok = false
				continue
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, fps)
			frames.set_animation_loop(anim_name, loop)
			for i in count:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2((first + i) * CELL, row * CELL, CELL, CELL)
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
