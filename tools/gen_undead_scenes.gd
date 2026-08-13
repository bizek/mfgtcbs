@tool
extends RefCounted

## Generates the 14 Catacombs enemy scenes from the Minifantasy_Undead_Creatures pack.
##
## Enemy scenes are CharacterBody2D + AnimatedSprite2D with the SpriteFrames baked in as
## sub-resources (see scenes/enemies/cave_brute.tscn). Hand-writing fourteen of those is not
## viable and hand-editing .tscn is forbidden by CLAUDE.md, so they are built through Godot's
## own PackedScene serialisation instead — the same result the editor would produce.
##
## Row convention: enemy.gd renders enemies from ONE row and mirrors with flip_h (enemy.gd:408),
## exactly as all 15 shipped enemy scenes do, so only one facing row is sliced per anim. The
## pack's other three facing rows are unused for the same reason they are unused on every
## existing enemy — that is an engine-wide convention, not an oversight in this pack.
##
## The `idle_risen` flag handles this pack's dormant skeletons: their "Idle_Activation_
## Deactivation" sheets are NOT four facing rows but three SEQUENCES — row 0 is a single frame
## of inert bones, row 1 is the rise, row 2 the collapse. Slicing row 0 as idle would leave a
## chasing skeleton rendered as a pile of bones, so those take the LAST frames of row 1, which
## are the risen, standing poses.

const PACK: String = "res://assets/minifantasy/Minifantasy_Undead_Creatures_v1.0/Minifantasy_Undead_Creatures_Assets/"
const GEN: String  = "res://assets/generated/skeletal_rider/"
const CELL: int = 32

## Frame timings come from each creature's Animation_Info.txt: 200ms (5fps) idle/walk,
## 100ms (10fps) attack/dmg/die.
const FPS_SLOW: float = 5.0
const FPS_FAST: float = 10.0


## spec: { anim: [path, row, first_frame, count, fps, loop] }
static func _specs() -> Dictionary:
	return {
		"CryptFodder": {
			"scene": "crypt_fodder",
			"anims": {
				## last 3 of row 1 = risen and standing (see idle_risen note above)
				"idle":   [PACK + "Headless_Skeleton/Idle_Activate_Deactivate.png", 1, 2, 3, FPS_SLOW, true],
				"walk":   [PACK + "Headless_Skeleton/Walk.png", 0, 0, 3, FPS_SLOW, true],
				"attack": [PACK + "Headless_Skeleton/Attack.png", 0, 0, 5, FPS_FAST, false],
				"damage": [PACK + "Headless_Skeleton/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Headless_Skeleton/Die.png", 0, 0, 13, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		"CryptSwarmer": {
			"scene": "crypt_swarmer",
			"anims": {
				"idle":   [PACK + "Jumping_Skull/Idle.png", 0, 0, 1, FPS_SLOW, true],
				## Jump IS this creature's locomotion — the pack ships no Walk for it. This is the
				## one legitimate use of a Jump sheet in a game with no jump.
				"walk":   [PACK + "Jumping_Skull/Jump.png", 0, 0, 9, FPS_SLOW, true],
				## Attack.png ships at 1920x1280 — 320px cells, a 10x-scaled authoring artifact.
				## Attack_without_effect.png is the same animation at the pack's real 32px.
				"attack": [PACK + "Jumping_Skull/Attack_without_effect.png", 0, 0, 6, FPS_FAST, false],
				"damage": [PACK + "Jumping_Skull/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Jumping_Skull/Die.png", 0, 0, 13, FPS_FAST, false],
			}, "body": Vector2(8, 8), "hurt": Vector2(12, 12),
		},
		"CryptSkirmisher": {
			"scene": "crypt_skirmisher",
			"anims": {
				"idle":   [PACK + "Reanimated_Skeleton_Warrior/Idle_Activation_Deactivation.png", 1, 2, 3, FPS_SLOW, true],
				"walk":   [PACK + "Reanimated_Skeleton_Warrior/Walk.png", 0, 0, 3, FPS_SLOW, true],
				"attack": [PACK + "Reanimated_Skeleton_Warrior/Attack.png", 0, 0, 7, FPS_FAST, false],
				"damage": [PACK + "Reanimated_Skeleton_Warrior/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Reanimated_Skeleton_Warrior/Die.png", 0, 0, 14, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		"CryptRaider": {
			"scene": "crypt_raider",
			"anims": {
				"idle":   [PACK + "Reanimated_Zombie_Warrior/Idle.png", 0, 0, 12, FPS_SLOW, true],
				"walk":   [PACK + "Reanimated_Zombie_Warrior/Walk.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [PACK + "Reanimated_Zombie_Warrior/Attack.png", 0, 0, 5, FPS_FAST, false],
				"damage": [PACK + "Reanimated_Zombie_Warrior/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Reanimated_Zombie_Warrior/Die.png", 0, 0, 22, FPS_FAST, false],
			}, "body": Vector2(11, 11), "hurt": Vector2(15, 15),
		},
		"CryptArcher": {
			"scene": "crypt_archer",
			"anims": {
				"idle":   [PACK + "Reanimated_Skeleton_Archer/Idle_Activation_Deactivation.png", 1, 2, 3, FPS_SLOW, true],
				"walk":   [PACK + "Reanimated_Skeleton_Archer/Walk.png", 0, 0, 3, FPS_SLOW, true],
				"attack": [PACK + "Reanimated_Skeleton_Archer/Attack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [PACK + "Reanimated_Skeleton_Archer/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Reanimated_Skeleton_Archer/Die.png", 0, 0, 14, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		"CryptZombieArcher": {
			"scene": "crypt_zombie_archer",
			"anims": {
				"idle":   [PACK + "Reanimated_Zombie_Archer/Idle.png", 0, 0, 12, FPS_SLOW, true],
				"walk":   [PACK + "Reanimated_Zombie_Archer/Walk.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [PACK + "Reanimated_Zombie_Archer/Attack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [PACK + "Reanimated_Zombie_Archer/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Reanimated_Zombie_Archer/Die.png", 0, 0, 15, FPS_FAST, false],
			}, "body": Vector2(11, 11), "hurt": Vector2(15, 15),
		},
		"CryptCaster": {
			"scene": "crypt_caster",
			"anims": {
				"idle":   [PACK + "Reanimated_Skeleton_Mage/Idle_Activation_Deactivation.png", 1, 2, 3, FPS_SLOW, true],
				"walk":   [PACK + "Reanimated_Skeleton_Mage/Walk.png", 0, 0, 3, FPS_SLOW, true],
				"attack": [PACK + "Reanimated_Skeleton_Mage/Cast.png", 0, 0, 6, FPS_FAST, false],
				"damage": [PACK + "Reanimated_Skeleton_Mage/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Reanimated_Skeleton_Mage/Die.png", 0, 0, 14, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		"CryptZombieCaster": {
			"scene": "crypt_zombie_caster",
			"anims": {
				"idle":   [PACK + "Reanimated_Zombie_Mage/Idle.png", 0, 0, 12, FPS_SLOW, true],
				"walk":   [PACK + "Reanimated_Zombie_Mage/Walk.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [PACK + "Reanimated_Zombie_Mage/Cast.png", 0, 0, 6, FPS_FAST, false],
				"damage": [PACK + "Reanimated_Zombie_Mage/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Reanimated_Zombie_Mage/Die.png", 0, 0, 15, FPS_FAST, false],
			}, "body": Vector2(11, 11), "hurt": Vector2(15, 15),
		},
		"CryptGhost": {
			"scene": "crypt_ghost",
			"anims": {
				"idle":   [PACK + "Ghost/Idle_Fly.png", 0, 0, 6, FPS_SLOW, true],
				## The Ghost has no Walk sheet — it flies, so Idle_Fly is its locomotion too.
				"walk":   [PACK + "Ghost/Idle_Fly.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [PACK + "Ghost/Attack.png", 0, 0, 7, FPS_FAST, false],
				"damage": [PACK + "Ghost/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Ghost/Die.png", 0, 0, 12, FPS_FAST, false],
			}, "body": Vector2(10, 10), "hurt": Vector2(14, 14),
		},
		"CryptBrute": {
			"scene": "crypt_brute",
			"anims": {
				"idle":   [PACK + "Zombie_Bear/Idle.png", 0, 0, 16, FPS_SLOW, true],
				"walk":   [PACK + "Zombie_Bear/Walk.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [PACK + "Zombie_Bear/Attack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [PACK + "Zombie_Bear/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Zombie_Bear/Die.png", 0, 0, 18, FPS_FAST, false],
			}, "body": Vector2(14, 12), "hurt": Vector2(18, 16),
		},
		"CryptHeavy": {
			"scene": "crypt_heavy",
			"anims": {
				"idle":   [PACK + "Zombie_Minotaur/Idle.png", 0, 0, 12, FPS_SLOW, true],
				"walk":   [PACK + "Zombie_Minotaur/Walk.png", 0, 0, 5, FPS_SLOW, true],
				"attack": [PACK + "Zombie_Minotaur/Attack.png", 0, 0, 8, FPS_FAST, false],
				"damage": [PACK + "Zombie_Minotaur/Dmg_flattened.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Zombie_Minotaur/Die.png", 0, 0, 18, FPS_FAST, false],
			}, "body": Vector2(14, 14), "hurt": Vector2(18, 18),
		},
		"CryptCavalry": {
			"scene": "crypt_cavalry",
			"anims": {
				## Horse + Rider composited (tools/composite_rider.py) — the pack ships them as
				## frame-matched layers and enemy.gd drives a single sprite.
				"idle":   [GEN + "Idle.png", 1, 2, 3, FPS_SLOW, true],
				"walk":   [GEN + "Walk.png", 0, 0, 4, FPS_SLOW, true],
				"attack": [GEN + "Attack.png", 0, 0, 6, FPS_FAST, false],
				"damage": [GEN + "Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [GEN + "Die.png", 0, 0, 15, FPS_FAST, false],
			}, "body": Vector2(14, 12), "hurt": Vector2(18, 16),
		},
		"SkeletonMinotaur": {
			"scene": "skeleton_minotaur",
			"anims": {
				"idle":   [PACK + "Skeleton_Minotaur/Idle_activate_deactivate.png", 1, 4, 3, FPS_SLOW, true],
				"walk":   [PACK + "Skeleton_Minotaur/Walk_layer 2.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [PACK + "Skeleton_Minotaur/Attack.png", 0, 0, 7, FPS_FAST, false],
				"damage": [PACK + "Skeleton_Minotaur/Dmg_layer 1.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Skeleton_Minotaur/Die.png", 0, 0, 16, FPS_FAST, false],
			}, "body": Vector2(16, 16), "hurt": Vector2(22, 22),
		},
		"ZombieGiant": {
			"scene": "zombie_giant",
			"anims": {
				"idle":   [PACK + "Zombie_Giant/Idle.png", 0, 0, 14, FPS_SLOW, true],
				"walk":   [PACK + "Zombie_Giant/Walk.png", 0, 0, 6, FPS_SLOW, true],
				"attack": [PACK + "Zombie_Giant/Attack.png", 0, 0, 7, FPS_FAST, false],
				"damage": [PACK + "Zombie_Giant/Dmg.png", 0, 0, 4, FPS_FAST, false],
				"death":  [PACK + "Zombie_Giant/Die.png", 0, 0, 15, FPS_FAST, false],
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
