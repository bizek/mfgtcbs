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
		"lifetime":        3.0,     ## seconds before projectile expires
		"projectile_count": 1,
		"spread_angle":    10.0,    ## total cone width in degrees (±5°)
		"tint":            Color.WHITE,
		"drop_weight":     0,       ## 0 = never drops; always available as default
		"mod_slots":       2,       ## mod slots available for this weapon
		"unlock_id":       "",      ## empty = always available, no blueprint required
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
		"range":           285.0,
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
		"range":           380.0,   ## max target range
		"aoe_radius":      64.0,
		"fuse_time":        1.0,    ## seconds before detonation
		"tint":            Color(0.38, 0.08, 0.62),  ## dark purple-void
		"drop_weight":     10,
		"mod_slots":       2,
		"unlock_id":       "Void Mortar",
		"blueprint_cost":  500,
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
		"lifetime":        3.5,
		"projectile_count": 1,
		"spread_angle":    6.0,
		"tint":            Color(0.82, 0.64, 0.28),  ## iron bronze
		"drop_weight":     0,
		"mod_slots":       2,
		"unlock_id":       "",
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
		"lifetime":        3.0,
		"projectile_count": 1,
		"spread_angle":    8.0,
		"tint":            Color(1.0, 0.95, 0.30),   ## electric yellow
		"drop_weight":     0,
		"mod_slots":       1,
		"unlock_id":       "",
	},

	## ─── Herald's Call ────────────────────────────────────────────────────
	## Mediocre slow auto-fire. The Herald's power comes from abilities.
	"Herald's Call": {
		"id":              "Herald's Call",
		"display_name":    "Herald's Call",
		"description":     "Weak auto-fire. The call draws power from elsewhere.",
		"behavior":        "projectile",
		"damage_type":     "physical",
		"damage":          6.0,
		"attack_speed":    0.80,
		"projectile_speed": 360.0,
		"lifetime":        3.0,
		"projectile_count": 1,
		"spread_angle":    14.0,
		"tint":            Color(0.30, 0.86, 0.96),  ## herald teal
		"drop_weight":     0,
		"mod_slots":       1,
		"unlock_id":       "",
	},
}

## Returns the IDs of all weapons eligible to drop during runs (drop_weight > 0).
static func get_droppable_ids() -> Array:
	var result: Array = []
	for id in ALL:
		if ALL[id].get("drop_weight", 0) > 0:
			result.append(id)
	return result
