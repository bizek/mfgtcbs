## WeaponData — Static database of all weapons in the game.
## Read by the player to configure behavior, and by the weapon pickup system.
## Each weapon overrides the player's base stats and drives a specific behavior pattern.
##
## Behavior types (from mechanical_vocabulary.md):
##   projectile — straight-firing bolt, basic auto-attack
##   spread     — cone of projectiles in one burst
##   beam       — instant-hit raycast with Line2D visual, rapid ticks
##   orbit      — persistent orbs circling the player
##   artillery  — delayed AoE at a ground target near nearest enemy
##   melee      — arc swing hitbox around the player
class_name WeaponData

const ALL: Dictionary = {

	## ─── Hurled Steel ────────────────────────────────────────────────────────
	## The default starter weapon. A spinning blade hurled at the nearest enemy.
	"Hurled Steel": {
		"id":              "Hurled Steel",
		"display_name":    "Hurled Steel",
		"description":     "you wanna get close to use this?",
		"behavior":        "projectile",
		"damage_type":     "physical",
		"damage":          11.0,
		"attack_speed":    1.0,     ## shots per second
		"projectile_speed": 400.0,
		"lifetime":        1.2,     ## range = speed×lifetime ≈ 480px (manual-aim range nerf 2026-06-24)
		"projectile_count": 1,
		"spread_angle":    10.0,    ## total cone width in degrees (±5°)
		"tint":            Color.WHITE,
		"drop_weight":     10,      ## now a generic mid-run drop (retired as a character starter 2026-06-24)
		"mod_slots":       2,       ## mod slots available for this weapon
		"unlock_id":       "",      ## empty = always available, no blueprint required
	},

	## ─── Hunter's Bow ─────────────────────────────────────────────────────────
	## The Scavenger's (Ranger) signature: a fast, accurate single arrow. Uses her
	## existing bow "SingleShot" attack animation. Replaced Hurled Steel on the Ranger 2026-06-24.
	"Hunter's Bow": {
		"id":              "Hunter's Bow",
		"display_name":    "Hunter's Bow",
		"description":     "A swift arrow to the nearest threat.",
		"behavior":        "projectile",
		"damage_type":     "physical",
		"damage":          13.0,
		"attack_speed":    1.1,
		"projectile_speed": 460.0,   ## arrows fly fast
		"lifetime":        1.15,     ## range ≈ 530px — long ranger reach
		"projectile_count": 1,
		"spread_angle":    4.0,      ## tight, accurate
		"tint":            Color(0.85, 0.78, 0.55),   ## fletched-wood tan
		"drop_weight":     0,        ## class gear — selected by smart-loot, not the generic pool
		"mod_slots":       1,
		"unlock_id":       "",
		## ── class-gear fields (task 34) — The Scavenger's GREEN ──
		"class_lock":      "The Scavenger",
		"kit":             "ranger",
		"rarity":          "uncommon",
		"tier":            "green",
	},

	## ─── Frost Scattergun ─────────────────────────────────────────────────────
	## Five projectiles in a wide cone. Shreds at close range; falls off fast.
	"Frost Scattergun": {
		"id":              "Frost Scattergun",
		"display_name":    "Frost Scattergun",
		"description":     "5-shot cryo cone. Lethal up close.",
		"behavior":        "spread",
		"damage_type":     "cryo",
		"damage":          8.0,     ## per projectile (×5 = 40 total potential)
		"attack_speed":    0.85,
		"projectile_speed": 340.0,
		"lifetime":        0.68,    ## ~230px range at this speed
		"projectile_count": 5,
		"spread_angle":    52.0,    ## total cone width
		"tint":            Color(0.55, 0.88, 1.0),   ## icy blue-white
		"drop_weight":     10,
		"mod_slots":       2,
		"unlock_id":       "Frost Scattergun",
		"blueprint_cost":  300,
	},

	## ─── Ember Beam ───────────────────────────────────────────────────────────
	## Continuous rapid-tick damage to nearest enemy in range. Low per-hit,
	## but constant pressure. Orange fire-stream visual.
	"Ember Beam": {
		"id":              "Ember Beam",
		"display_name":    "Ember Beam",
		"description":     "Constant fire stream. Lower damage, never stops.",
		"behavior":        "beam",
		"damage_type":     "fire",
		"damage":          4.0,     ## per tick (×12/sec = 48 DPS base)
		"attack_speed":    12.0,    ## ticks per second
		"range":           240.0,   ## manual-aim range nerf 2026-06-24 (was 285)
		"tint":            Color(1.0, 0.42, 0.08),   ## deep orange-red
		"drop_weight":     10,
		"mod_slots":       1,
		"unlock_id":       "Ember Beam",
		"blueprint_cost":  300,
	},

	## ─── Lightning Orb ────────────────────────────────────────────────────────
	## Three electric orbs orbit the player permanently. They shock any enemy
	## they contact. Passive — no aiming required.
	"Lightning Orb": {
		"id":              "Lightning Orb",
		"display_name":    "Lightning Orb",
		"description":     "3 orbs orbit you. Touch enemies to shock them.",
		"behavior":        "orbit",
		"damage_type":     "shock",
		"damage":          17.0,    ## per orb contact (0.45s cooldown per enemy)
		"attack_speed":    1.0,     ## unused for orbit; kept for stat display
		"orbit_count":     3,
		"orbit_radius":    64.0,
		"orbit_speed":     1.8,     ## full rotations per second
		"tint":            Color(0.78, 0.95, 1.0),   ## electric white-blue
		"drop_weight":     10,
		"mod_slots":       1,
		"unlock_id":       "Lightning Orb",
		"blueprint_cost":  400,
	},

	## ─── Void Mortar ──────────────────────────────────────────────────────────
	## Lobs a shell at a spot near the nearest enemy. After a 1-second fuse,
	## it detonates in a large AoE. Slow fire rate, massive burst.
	"Void Mortar": {
		"id":              "Void Mortar",
		"display_name":    "Void Mortar",
		"description":     "Delayed AoE blast. Watch the ground.",
		"behavior":        "artillery",
		"damage_type":     "void",
		"damage":          31.0,    ## AoE on explosion
		"attack_speed":    0.40,    ## shots per second
		"range":           340.0,   ## max target range — manual-aim range nerf 2026-06-24 (was 380)
		"aoe_radius":      64.0,
		"fuse_time":        1.0,    ## seconds before detonation
		"tint":            Color(0.38, 0.08, 0.62),  ## dark purple-void
		"drop_weight":     0,
		"mod_slots":       1,
		"unlock_id":       "",
		## ── class-gear fields (task 34) — The Cursed's GREEN ──
		"class_lock":      "The Cursed",
		"kit":             "blood_mage",
		"rarity":          "uncommon",
		"tier":            "green",
	},

	## ─── Arcane Blade ─────────────────────────────────────────────────────────
	## Fast arc swings through enemies in a wide semicircle. Extremely high
	## damage but you have to be in their face. Very fast attack speed.
	## Arc grows with melee range mods; swing angle grows with arc mods.
	"Arcane Blade": {
		"id":              "Arcane Blade",
		"display_name":    "Arcane Blade",
		"description":     "High-damage arc swing. Get close or die.",
		"behavior":        "melee",
		"damage_type":     "physical",
		"damage":          25.0,
		"attack_speed":    1.8,     ## swings per second
		"range":           40.0,    ## melee reach in pixels — nerfed so size mod (+50%) feels impactful (→60px)
		"arc_degrees":     170.0,   ## swing arc width — nerfed for same reason (→255° with size mod)
		"tint":            Color(0.62, 0.28, 0.95),   ## arcane violet
		"drop_weight":     10,
		"mod_slots":       2,
		"unlock_id":       "Arcane Blade",
		"blueprint_cost":  400,
	},

	## ─── Character-exclusive starting weapons (drop_weight: 0 — never drop) ───

	## ─── Warden's Repeater ─────────────────────────────────────────────────
	## Slow, hard-hitting single bolt. Every shot is a commitment.
	"Warden's Repeater": {
		"id":              "Warden's Repeater",
		"display_name":    "Warden's Repeater",
		"description":     "Slow fire, heavy impact. Each shot counts.",
		"behavior":        "projectile",
		"damage_type":     "physical",
		"damage":          17.0,
		"attack_speed":    0.55,    ## slow fire rate
		"projectile_speed": 380.0,
		"lifetime":        1.5,     ## range ≈ 570px — longest reach (sniper identity); range nerf 2026-06-24
		"projectile_count": 1,
		"spread_angle":    6.0,
		"tint":            Color(0.82, 0.64, 0.28),  ## iron bronze
		"drop_weight":     0,
		"mod_slots":       1,
		"unlock_id":       "",
		## ── class-gear fields (task 34) — The Warden's GREEN ──
		"class_lock":      "The Warden",
		"kit":             "paladin",
		"rarity":          "uncommon",
		"tier":            "green",
	},

	## ─── Spark's Pistol ────────────────────────────────────────────────────
	## Rapid-fire pistol. Low per-shot damage, absurd fire rate.
	"Spark's Pistol": {
		"id":              "Spark's Pistol",
		"display_name":    "Spark's Pistol",
		"description":     "Rapid-fire burst. Fragile but relentless.",
		"behavior":        "projectile",
		"damage_type":     "physical",
		"damage":          8.0,
		"attack_speed":    2.0,     ## fast fire rate
		"projectile_speed": 440.0,
		"lifetime":        1.0,     ## range ≈ 440px — manual-aim range nerf 2026-06-24
		"projectile_count": 1,
		"spread_angle":    8.0,
		"tint":            Color(1.0, 0.95, 0.30),   ## electric yellow
		"drop_weight":     0,
		"mod_slots":       1,
		"unlock_id":       "",
	},

	## ─── Herald's Call ────────────────────────────────────────────────────
	## The Herald's GREEN. A struck chord that carries. The song does the rest.
	"Herald's Call": {
		"id":              "Herald's Call",
		"display_name":    "Herald's Call",
		"description":     "A struck chord that carries across the dark.",
		"damage_type":     "shock",
		"damage":          6.0,
		"tint":            Color(0.30, 0.86, 0.96),  ## herald teal
		"drop_weight":     0,
		"mod_slots":       1,
		"unlock_id":       "",
		"class_lock":      "The Herald",
		"kit":             "bard",
		"rarity":          "uncommon",
		"tier":            "green",
	},

	# ═══════════════════════════════════════════════════════════════════════════
	# CLASS GEAR (task 34) — class-locked weapon lines, green/blue/purple tiers.
	# Weapons feed only `damage` + `damage_type` into the combo kit (ChainFactory);
	# behavior fields are retired here. Blue/purple gate into the drop pool via
	# `unlock_id` (Research). `modifiers` = intrinsic stat lines applied on equip
	# (player.gd). Purple `unique` id → GearUniqueFactory. Selected by smart-loot
	# per class/tier, NOT the generic drop_weight pool (all drop_weight 0).
	# ═══════════════════════════════════════════════════════════════════════════

	## ─── Fighter / The Drifter (Physical) ───────────────────────────────────
	"Mercenary's Edge": {
		"id": "Mercenary's Edge", "display_name": "Mercenary's Edge",
		"description": "A plain, honest blade. It does the job and asks no questions.",
		"damage_type": "physical", "damage": 25.0, "tint": Color(0.85, 0.85, 0.90),
		"drop_weight": 0, "mod_slots": 1, "unlock_id": "",
		"class_lock": "The Drifter", "kit": "fighter", "rarity": "uncommon", "tier": "green",
	},
	"Sellsword's Warbrand": {
		"id": "Sellsword's Warbrand", "display_name": "Sellsword's Warbrand",
		"description": "Balanced steel, weighted for the long fight.",
		"damage_type": "physical", "damage": 34.0, "tint": Color(0.85, 0.85, 0.90),
		"drop_weight": 0, "mod_slots": 2, "unlock_id": "gear_fighter_blue",
		"class_lock": "The Drifter", "kit": "fighter", "rarity": "rare", "tier": "blue",
		"modifiers": [ {"tag": "attack_speed", "op": "bonus", "value": 0.08} ],
	},
	"Bloodsworn Greatblade": {
		"id": "Bloodsworn Greatblade", "display_name": "Bloodsworn Greatblade",
		"description": "Every kill feeds the next swing. It never wants to stop.",
		"damage_type": "physical", "damage": 40.0, "tint": Color(0.90, 0.80, 0.85),
		"drop_weight": 0, "mod_slots": 3, "unlock_id": "gear_fighter_purple",
		"class_lock": "The Drifter", "kit": "fighter", "rarity": "epic", "tier": "purple",
		"modifiers": [ {"tag": "damage", "op": "bonus", "value": 0.08}, {"tag": "crit_chance", "op": "add", "value": 0.05} ],
		"unique": "u_rampage",
	},

	## ─── Ranger / The Scavenger (Physical) — GREEN = Hunter's Bow above ──────
	"Longstrider Bow": {
		"id": "Longstrider Bow", "display_name": "Longstrider Bow",
		"description": "Drawn slow, loosed true. Reaches clear across the dark.",
		"damage_type": "physical", "damage": 18.0, "tint": Color(0.85, 0.78, 0.55),
		"drop_weight": 0, "mod_slots": 2, "unlock_id": "gear_ranger_blue",
		"class_lock": "The Scavenger", "kit": "ranger", "rarity": "rare", "tier": "blue",
		"modifiers": [ {"tag": "crit_chance", "op": "add", "value": 0.06} ],
	},
	"Widowmaker": {
		"id": "Widowmaker", "display_name": "Widowmaker",
		"description": "One arrow finds the gap. The wound does the rest.",
		"damage_type": "physical", "damage": 21.0, "tint": Color(0.88, 0.80, 0.58),
		"drop_weight": 0, "mod_slots": 3, "unlock_id": "gear_ranger_purple",
		"class_lock": "The Scavenger", "kit": "ranger", "rarity": "epic", "tier": "purple",
		"modifiers": [ {"tag": "crit_chance", "op": "add", "value": 0.08}, {"tag": "crit_multiplier", "op": "add", "value": 0.20} ],
		"unique": "u_hemorrhage",
	},

	## ─── Paladin / The Warden (Physical) — GREEN = Warden's Repeater above ───
	"Oathkeeper Repeater": {
		"id": "Oathkeeper Repeater", "display_name": "Oathkeeper Repeater",
		"description": "Blessed iron. Each bolt is a vow kept.",
		"damage_type": "physical", "damage": 23.0, "tint": Color(0.86, 0.72, 0.40),
		"drop_weight": 0, "mod_slots": 2, "unlock_id": "gear_paladin_blue",
		"class_lock": "The Warden", "kit": "paladin", "rarity": "rare", "tier": "blue",
		"modifiers": [ {"tag": "max_hp", "op": "add", "value": 25.0} ],
	},
	"Aegis of the Fallen": {
		"id": "Aegis of the Fallen", "display_name": "Aegis of the Fallen",
		"description": "Forged from the shields of the dead. They stand with you still.",
		"damage_type": "physical", "damage": 27.0, "tint": Color(0.90, 0.78, 0.48),
		"drop_weight": 0, "mod_slots": 3, "unlock_id": "gear_paladin_purple",
		"class_lock": "The Warden", "kit": "paladin", "rarity": "epic", "tier": "purple",
		"modifiers": [ {"tag": "max_hp", "op": "add", "value": 35.0}, {"tag": "Physical", "op": "resist", "value": 6.0} ],
		"unique": "u_retribution",
	},

	## ─── Wizard / The Spark (Fire) ──────────────────────────────────────────
	"Apprentice Flame": {
		"id": "Apprentice Flame", "display_name": "Apprentice Flame",
		"description": "A candle's worth of the real fire. Enough to start.",
		"damage_type": "fire", "damage": 8.0, "tint": Color(1.0, 0.55, 0.18),
		"drop_weight": 0, "mod_slots": 1, "unlock_id": "",
		"class_lock": "The Spark", "kit": "wizard", "rarity": "uncommon", "tier": "green",
	},
	"Emberfocus Rod": {
		"id": "Emberfocus Rod", "display_name": "Emberfocus Rod",
		"description": "Channels the burn tighter, hotter, meaner.",
		"damage_type": "fire", "damage": 11.0, "tint": Color(1.0, 0.50, 0.15),
		"drop_weight": 0, "mod_slots": 2, "unlock_id": "gear_wizard_blue",
		"class_lock": "The Spark", "kit": "wizard", "rarity": "rare", "tier": "blue",
		"modifiers": [ {"tag": "damage", "op": "bonus", "value": 0.10} ],
	},
	"Cinderbrand": {
		"id": "Cinderbrand", "display_name": "Cinderbrand",
		"description": "Overcharged past reason. Everything it touches catches.",
		"damage_type": "fire", "damage": 13.0, "tint": Color(1.0, 0.42, 0.10),
		"drop_weight": 0, "mod_slots": 3, "unlock_id": "gear_wizard_purple",
		"class_lock": "The Spark", "kit": "wizard", "rarity": "epic", "tier": "purple",
		"modifiers": [ {"tag": "damage", "op": "bonus", "value": 0.12}, {"tag": "crit_chance", "op": "add", "value": 0.05} ],
		"unique": "u_wildfire",
	},

	## ─── Rogue / The Shade (Physical) ───────────────────────────────────────
	"Shadowfang": {
		"id": "Shadowfang", "display_name": "Shadowfang",
		"description": "A thin blade for close, quiet work.",
		"damage_type": "physical", "damage": 25.0, "tint": Color(0.72, 0.72, 0.82),
		"drop_weight": 0, "mod_slots": 1, "unlock_id": "",
		"class_lock": "The Shade", "kit": "rogue", "rarity": "uncommon", "tier": "green",
	},
	"Nightslip Daggers": {
		"id": "Nightslip Daggers", "display_name": "Nightslip Daggers",
		"description": "Twin edges that find the seam every time.",
		"damage_type": "physical", "damage": 34.0, "tint": Color(0.72, 0.72, 0.82),
		"drop_weight": 0, "mod_slots": 2, "unlock_id": "gear_rogue_blue",
		"class_lock": "The Shade", "kit": "rogue", "rarity": "rare", "tier": "blue",
		"modifiers": [ {"tag": "crit_chance", "op": "add", "value": 0.06} ],
	},
	"Whispering Death": {
		"id": "Whispering Death", "display_name": "Whispering Death",
		"description": "You won't feel the first cut. You won't get a second.",
		"damage_type": "physical", "damage": 40.0, "tint": Color(0.78, 0.74, 0.88),
		"drop_weight": 0, "mod_slots": 3, "unlock_id": "gear_rogue_purple",
		"class_lock": "The Shade", "kit": "rogue", "rarity": "epic", "tier": "purple",
		"modifiers": [ {"tag": "crit_chance", "op": "add", "value": 0.08}, {"tag": "move_speed", "op": "bonus", "value": 0.06} ],
		"unique": "u_serrated",
	},

	## ─── Bard / The Herald (Lightning) — GREEN = Herald's Call above ─────────
	"Resonant Lute": {
		"id": "Resonant Lute", "display_name": "Resonant Lute",
		"description": "Strung with storm-wire. The chord bites.",
		"damage_type": "shock", "damage": 8.0, "tint": Color(0.30, 0.86, 0.96),
		"drop_weight": 0, "mod_slots": 2, "unlock_id": "gear_bard_blue",
		"class_lock": "The Herald", "kit": "bard", "rarity": "rare", "tier": "blue",
		"modifiers": [ {"tag": "damage", "op": "bonus", "value": 0.10} ],
	},
	"Chorus of the Void": {
		"id": "Chorus of the Void", "display_name": "Chorus of the Void",
		"description": "A hundred voices under one. They sing the horde apart.",
		"damage_type": "shock", "damage": 10.0, "tint": Color(0.40, 0.90, 1.0),
		"drop_weight": 0, "mod_slots": 3, "unlock_id": "gear_bard_purple",
		"class_lock": "The Herald", "kit": "bard", "rarity": "epic", "tier": "purple",
		"modifiers": [ {"tag": "damage", "op": "bonus", "value": 0.12}, {"tag": "attack_speed", "op": "bonus", "value": 0.06} ],
		"unique": "u_discord",
	},

	## ─── Barbarian / The Ravager (Physical) ─────────────────────────────────
	"Ravager's Cleaver": {
		"id": "Ravager's Cleaver", "display_name": "Ravager's Cleaver",
		"description": "Too heavy for anyone sane. He swings it like a stick.",
		"damage_type": "physical", "damage": 25.0, "tint": Color(0.88, 0.60, 0.30),
		"drop_weight": 0, "mod_slots": 1, "unlock_id": "",
		"class_lock": "The Ravager", "kit": "barbarian", "rarity": "uncommon", "tier": "green",
	},
	"Stormforged Axe": {
		"id": "Stormforged Axe", "display_name": "Stormforged Axe",
		"description": "Quenched in a thunderhead. The storm follows the blade.",
		"damage_type": "physical", "damage": 34.0, "tint": Color(0.88, 0.60, 0.30),
		"drop_weight": 0, "mod_slots": 2, "unlock_id": "gear_barbarian_blue",
		"class_lock": "The Ravager", "kit": "barbarian", "rarity": "rare", "tier": "blue",
		"modifiers": [ {"tag": "damage", "op": "bonus", "value": 0.08} ],
	},
	"Skullcleaver": {
		"id": "Skullcleaver", "display_name": "Skullcleaver",
		"description": "The more it drinks, the harder it swings. So does he.",
		"damage_type": "physical", "damage": 40.0, "tint": Color(0.92, 0.55, 0.28),
		"drop_weight": 0, "mod_slots": 3, "unlock_id": "gear_barbarian_purple",
		"class_lock": "The Ravager", "kit": "barbarian", "rarity": "epic", "tier": "purple",
		"modifiers": [ {"tag": "damage", "op": "bonus", "value": 0.10}, {"tag": "max_hp", "op": "add", "value": 20.0} ],
		"unique": "u_bloodrage",
	},

	## ─── Ninja / The Whisper (Physical) ─────────────────────────────────────
	"Whisper's Kiss": {
		"id": "Whisper's Kiss", "display_name": "Whisper's Kiss",
		"description": "Short, silent, and always where you aren't looking.",
		"damage_type": "physical", "damage": 25.0, "tint": Color(0.68, 0.72, 0.80),
		"drop_weight": 0, "mod_slots": 1, "unlock_id": "",
		"class_lock": "The Whisper", "kit": "ninja", "rarity": "uncommon", "tier": "green",
	},
	"Twin Fangs": {
		"id": "Twin Fangs", "display_name": "Twin Fangs",
		"description": "A blade for each hand. Neither ever waits its turn.",
		"damage_type": "physical", "damage": 34.0, "tint": Color(0.68, 0.72, 0.80),
		"drop_weight": 0, "mod_slots": 2, "unlock_id": "gear_ninja_blue",
		"class_lock": "The Whisper", "kit": "ninja", "rarity": "rare", "tier": "blue",
		"modifiers": [ {"tag": "crit_chance", "op": "add", "value": 0.06} ],
	},
	"Death's Whisper": {
		"id": "Death's Whisper", "display_name": "Death's Whisper",
		"description": "The last thing they hear. Barely.",
		"damage_type": "physical", "damage": 40.0, "tint": Color(0.74, 0.78, 0.86),
		"drop_weight": 0, "mod_slots": 3, "unlock_id": "gear_ninja_purple",
		"class_lock": "The Whisper", "kit": "ninja", "rarity": "epic", "tier": "purple",
		"modifiers": [ {"tag": "crit_chance", "op": "add", "value": 0.10}, {"tag": "crit_multiplier", "op": "add", "value": 0.25} ],
		"unique": "u_killing_edge",
	},

	## ─── Blood Mage / The Cursed (Void) — GREEN = Void Mortar above ─────────
	"Sanguine Sigil": {
		"id": "Sanguine Sigil", "display_name": "Sanguine Sigil",
		"description": "It reads your blood and asks for more.",
		"damage_type": "void", "damage": 42.0, "tint": Color(0.55, 0.20, 0.75),
		"drop_weight": 0, "mod_slots": 2, "unlock_id": "gear_blood_mage_blue",
		"class_lock": "The Cursed", "kit": "blood_mage", "rarity": "rare", "tier": "blue",
		"modifiers": [ {"tag": "leech", "op": "bonus", "value": 0.05} ],
	},
	"Heart-Eater": {
		"id": "Heart-Eater", "display_name": "Heart-Eater",
		"description": "What it takes from them, it gives to you. Mostly.",
		"damage_type": "void", "damage": 50.0, "tint": Color(0.62, 0.24, 0.82),
		"drop_weight": 0, "mod_slots": 3, "unlock_id": "gear_blood_mage_purple",
		"class_lock": "The Cursed", "kit": "blood_mage", "rarity": "epic", "tier": "purple",
		"modifiers": [ {"tag": "leech", "op": "bonus", "value": 0.08}, {"tag": "damage", "op": "bonus", "value": 0.08} ],
		"unique": "u_sanguine",
	},

	## ─── Gunslinger / The Deadeye (Physical) ────────────────────────────────
	"Peacemaker": {
		"id": "Peacemaker", "display_name": "Peacemaker",
		"description": "Six chambers and a steady hand. That's the whole trick.",
		"damage_type": "physical", "damage": 8.0, "tint": Color(0.89, 0.66, 0.36),
		"drop_weight": 0, "mod_slots": 1, "unlock_id": "",
		"class_lock": "The Deadeye", "kit": "gunslinger", "rarity": "uncommon", "tier": "green",
	},
	"Twin Sixguns": {
		"id": "Twin Sixguns", "display_name": "Twin Sixguns",
		"description": "Twice the barrels, twice the noise, half the mercy.",
		"damage_type": "physical", "damage": 11.0, "tint": Color(0.89, 0.66, 0.36),
		"drop_weight": 0, "mod_slots": 2, "unlock_id": "gear_gunslinger_blue",
		"class_lock": "The Deadeye", "kit": "gunslinger", "rarity": "rare", "tier": "blue",
		"modifiers": [ {"tag": "attack_speed", "op": "bonus", "value": 0.10} ],
	},
	"Deadman's Hand": {
		"id": "Deadman's Hand", "display_name": "Deadman's Hand",
		"description": "Aces and eights. The storm never misses twice.",
		"damage_type": "physical", "damage": 13.0, "tint": Color(0.92, 0.62, 0.30),
		"drop_weight": 0, "mod_slots": 3, "unlock_id": "gear_gunslinger_purple",
		"class_lock": "The Deadeye", "kit": "gunslinger", "rarity": "epic", "tier": "purple",
		"modifiers": [ {"tag": "attack_speed", "op": "bonus", "value": 0.12}, {"tag": "crit_chance", "op": "add", "value": 0.06} ],
		"unique": "u_fanfire",
	},

	## ─── Druid / The Verdant (Physical / poison) ────────────────────────────
	"Thornstaff": {
		"id": "Thornstaff", "display_name": "Thornstaff",
		"description": "Living wood, still growing. It remembers the forest.",
		"damage_type": "physical", "damage": 25.0, "tint": Color(0.45, 0.72, 0.42),
		"drop_weight": 0, "mod_slots": 1, "unlock_id": "",
		"class_lock": "The Verdant", "kit": "druid", "rarity": "uncommon", "tier": "green",
	},
	"Heartwood Stave": {
		"id": "Heartwood Stave", "display_name": "Heartwood Stave",
		"description": "Cut from the oldest tree. It lends you its patience.",
		"damage_type": "physical", "damage": 34.0, "tint": Color(0.45, 0.72, 0.42),
		"drop_weight": 0, "mod_slots": 2, "unlock_id": "gear_druid_blue",
		"class_lock": "The Verdant", "kit": "druid", "rarity": "rare", "tier": "blue",
		"modifiers": [ {"tag": "max_hp", "op": "add", "value": 20.0} ],
	},
	"World-Root": {
		"id": "World-Root", "display_name": "World-Root",
		"description": "A splinter of the tree that holds the deep together.",
		"damage_type": "physical", "damage": 40.0, "tint": Color(0.50, 0.78, 0.46),
		"drop_weight": 0, "mod_slots": 3, "unlock_id": "gear_druid_purple",
		"class_lock": "The Verdant", "kit": "druid", "rarity": "epic", "tier": "purple",
		"modifiers": [ {"tag": "max_hp", "op": "add", "value": 30.0}, {"tag": "damage", "op": "bonus", "value": 0.08} ],
		"unique": "u_blightbloom",
	},

	## ─── Cleric / The Devout (Fire / radiant) ───────────────────────────────
	"Ember Censer": {
		"id": "Ember Censer", "display_name": "Ember Censer",
		"description": "Swung on a chain, trailing holy smoke and coals.",
		"damage_type": "fire", "damage": 25.0, "tint": Color(1.0, 0.80, 0.40),
		"drop_weight": 0, "mod_slots": 1, "unlock_id": "",
		"class_lock": "The Devout", "kit": "cleric", "rarity": "uncommon", "tier": "green",
	},
	"Sanctified Censer": {
		"id": "Sanctified Censer", "display_name": "Sanctified Censer",
		"description": "Blessed at every altar it has passed. The fire remembers.",
		"damage_type": "fire", "damage": 34.0, "tint": Color(1.0, 0.80, 0.40),
		"drop_weight": 0, "mod_slots": 2, "unlock_id": "gear_cleric_blue",
		"class_lock": "The Devout", "kit": "cleric", "rarity": "rare", "tier": "blue",
		"modifiers": [ {"tag": "max_hp", "op": "add", "value": 20.0} ],
	},
	"Pyre of Judgment": {
		"id": "Pyre of Judgment", "display_name": "Pyre of Judgment",
		"description": "The last rite, made a weapon. It burns the unworthy and mends the faithful.",
		"damage_type": "fire", "damage": 40.0, "tint": Color(1.0, 0.74, 0.34),
		"drop_weight": 0, "mod_slots": 3, "unlock_id": "gear_cleric_purple",
		"class_lock": "The Devout", "kit": "cleric", "rarity": "epic", "tier": "purple",
		"modifiers": [ {"tag": "max_hp", "op": "add", "value": 25.0}, {"tag": "damage", "op": "bonus", "value": 0.08} ],
		"unique": "u_benediction",
	},
}

## Returns the IDs of all weapons eligible to drop during runs (drop_weight > 0).
## NOTE: class gear (task 34) is drop_weight 0 — it is selected by the smart-loot
## system (main_arena) per class/tier, not through this generic weighted pool.
static func get_droppable_ids() -> Array:
	var result: Array = []
	for id in ALL:
		if ALL[id].get("drop_weight", 0) > 0:
			result.append(id)
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# CLASS-GEAR LOOKUPS (task 34)
# ═══════════════════════════════════════════════════════════════════════════════

## True if a weapon id is class gear (has the class-gear schema fields).
static func is_class_gear(weapon_id: String) -> bool:
	return ALL.get(weapon_id, {}).has("kit")

## The weapon's rarity key ("uncommon"/"rare"/"epic"), or "" if not class gear.
static func get_weapon_rarity(weapon_id: String) -> String:
	return str(ALL.get(weapon_id, {}).get("rarity", ""))

## The weapon's tier ("green"/"blue"/"purple"), or "" if not class gear.
static func get_weapon_tier(weapon_id: String) -> String:
	return str(ALL.get(weapon_id, {}).get("tier", ""))

## The class (char_id) a weapon is locked to, or "" if universal/legacy.
static func get_weapon_class(weapon_id: String) -> String:
	return str(ALL.get(weapon_id, {}).get("class_lock", ""))

## Intrinsic stat-line modifiers on a weapon (Array of {tag, op, value}); [] if none.
static func get_weapon_modifiers(weapon_id: String) -> Array:
	return ALL.get(weapon_id, {}).get("modifiers", [])

## Purple unique id on a weapon ("" if none).
static func get_weapon_unique(weapon_id: String) -> String:
	return str(ALL.get(weapon_id, {}).get("unique", ""))

## The {green, blue, purple} weapon ids for a kit. Missing tiers map to "".
## Used by the smart-loot drop system to pick a class weapon at a rolled rarity.
static func get_class_line(kit_id: String) -> Dictionary:
	var line: Dictionary = { "green": "", "blue": "", "purple": "" }
	for id in ALL:
		var w: Dictionary = ALL[id]
		if w.get("kit", "") != kit_id:
			continue
		line[w.get("tier", "green")] = id
	return line

## Weapon id for a kit at a given rarity key ("uncommon"→green, "rare"→blue,
## "epic"→purple). Returns "" if that class/tier doesn't exist.
static func get_class_weapon_for_rarity(kit_id: String, rarity: String) -> String:
	var tier: String = { "uncommon": "green", "rare": "blue", "epic": "purple" }.get(rarity, "green")
	return str(get_class_line(kit_id).get(tier, ""))
