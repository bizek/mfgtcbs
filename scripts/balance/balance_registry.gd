class_name BalanceRegistry
extends RefCounted

## BalanceRegistry — the catalogue of every tunable number, DERIVED from live data.
##
## ── Why derived and not declared ──────────────────────────────────────────────
##
## The obvious build is a big hand-written list of fields. It would be wrong here for the
## same reason the content system is data-driven: a new character, weapon, enemy or combo
## phase is added by writing a data factory, and a hand-written catalogue would silently
## fail to grow with it. The tool would quietly stop covering the game, and nothing would
## say so.
##
## So the registry ENUMERATES: it walks `CharacterData.ALL`, `WeaponData.ALL`, the built
## `EnemyRegistry` definitions and a pristine build of each kit's combo graphs, and emits a
## BalanceField per number it finds. Add a 13th character and it appears in the editor with
## no edit here.
##
## What IS hand-written is the HINT table — label, range, units, docs and apply-mode for the
## stats worth describing well. A stat with no hint still shows up, with a range derived
## from its shipped value (BalanceField._auto_range). Hints are polish; enumeration is
## coverage. That split is the whole design.
##
## ── Structure ─────────────────────────────────────────────────────────────────
##
##   category  — CHARACTERS, PLAYER, WEAPONS, ENEMIES, COMBOS, DIFFICULTY
##     subject — one character / weapon / enemy / kit (the left nav's leaves)
##       field — one BalanceField (a row in the inspector)

const PlayerScript = preload("res://scripts/entities/player.gd")

const CAT_CHARACTER: String = "character"
const CAT_PLAYER: String = "player"
const CAT_WEAPON: String = "weapon"
const CAT_ENEMY: String = "enemy"
const CAT_CHAIN: String = "chain"
const CAT_DIFFICULTY: String = "difficulty"

## Subject ids under CAT_PLAYER — the two halves of "the player as a unit".
const SUBJ_STATS: String = "stats"
const SUBJ_HITBOX: String = "hitbox"

## Shipped hitbox geometry. These live in `scenes/player.tscn` as SubResource shapes, which
## the editor cannot address by path — so the shipped values are recorded here and
## `player._apply_hitbox_overrides()` writes them onto the live shapes at _ready.
## Keep in sync with the scene: Hurtbox 16x16, body CollisionShape 16x16.
## (The PickupCollector circle is not listed: it is derived from the pickup_radius stat
## every frame it matters, so the scene's value is never the one in play.)
const HITBOX_BASE: Dictionary = {
	"hurtbox_size": Vector2(16.0, 16.0),
	"body_size": Vector2(16.0, 16.0),
}


# ─── Categories & subjects ────────────────────────────────────────────────────

static func categories() -> Array[Dictionary]:
	return [
		{"id": CAT_CHARACTER, "label": "CHARACTERS"},
		{"id": CAT_PLAYER, "label": "PLAYER"},
		{"id": CAT_CHAIN, "label": "COMBOS"},
		{"id": CAT_WEAPON, "label": "WEAPONS"},
		{"id": CAT_ENEMY, "label": "ENEMIES"},
		{"id": CAT_DIFFICULTY, "label": "DIFFICULTY"},
	]


## Leaves under a category: {id, label, sub} where `sub` is the dim second line in the nav.
static func subjects(category: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match category:
		CAT_CHARACTER:
			for cid: String in CharacterData.ALL.keys():
				var cd: Dictionary = CharacterData.ALL[cid]
				out.append({
					"id": cid,
					"label": str(cd.get("display_name", cid)),
					"sub": "%s · %s" % [str(cd.get("char_class", "?")), cid],
				})
		CAT_PLAYER:
			out.append({"id": SUBJ_STATS, "label": "BASE STATS", "sub": "every character"})
			out.append({"id": SUBJ_HITBOX, "label": "HITBOX", "sub": "hurtbox · body"})
		CAT_CHAIN:
			for kit: String in kit_ids():
				out.append({
					"id": kit,
					"label": kit.to_upper(),
					"sub": _character_for_kit(kit),
				})
		CAT_WEAPON:
			for wid: String in WeaponData.ALL.keys():
				var wd: Dictionary = WeaponData.ALL[wid]
				var lock: String = str(wd.get("class_lock", ""))
				out.append({
					"id": wid,
					"label": wid,
					"sub": "%s · %s" % [str(wd.get("behavior", "?")), (lock if lock != "" else "generic")],
				})
		CAT_ENEMY:
			EnemyRegistry.build_all()
			for eid: String in EnemyRegistry.get_all().keys():
				var def: EnemyDefinition = EnemyRegistry.get_def(eid)
				if def == null:
					continue
				var role: String = "boss" if def.is_boss else ("elite" if def.is_elite else def.combat_role.to_lower())
				out.append({"id": eid, "label": def.enemy_name, "sub": "%s · %s" % [eid, role]})
		CAT_DIFFICULTY:
			out.append({"id": "curve", "label": "RUN CURVE", "sub": "phases · scaling · cap"})
	return out


## Every kit id that has a combo graph, read from the characters that name one.
static func kit_ids() -> Array[String]:
	var seen: Dictionary = {}
	var out: Array[String] = []
	for cid: String in CharacterData.ALL.keys():
		var kit: String = str((CharacterData.ALL[cid] as Dictionary).get("melee_kit", ""))
		if kit != "" and not seen.has(kit):
			seen[kit] = true
			out.append(kit)
	return out


static func _character_for_kit(kit: String) -> String:
	for cid: String in CharacterData.ALL.keys():
		if str((CharacterData.ALL[cid] as Dictionary).get("melee_kit", "")) == kit:
			return str((CharacterData.ALL[cid] as Dictionary).get("display_name", cid))
	return ""


## The weapon a kit is actually played with, so the phase numbers the editor shows are the
## ones a real run builds. Falls back to the generic starter.
static func _weapon_data_for_kit(kit: String) -> Dictionary:
	for cid: String in CharacterData.ALL.keys():
		var cd: Dictionary = CharacterData.ALL[cid]
		if str(cd.get("melee_kit", "")) == kit:
			var wid: String = str(cd.get("starting_weapon", ""))
			if WeaponData.ALL.has(wid):
				return WeaponData.ALL[wid]
	return WeaponData.ALL.get("Hurled Steel", {})


# ─── Fields ───────────────────────────────────────────────────────────────────

static func fields(category: String, subject: String) -> Array[BalanceField]:
	match category:
		CAT_CHARACTER:
			return _character_fields(subject)
		CAT_PLAYER:
			return _hitbox_fields() if subject == SUBJ_HITBOX else _player_stat_fields(BalanceOverrides.GLOBAL)
		CAT_CHAIN:
			return _chain_fields(subject)
		CAT_WEAPON:
			return _weapon_fields(subject)
		CAT_ENEMY:
			return _enemy_fields(subject)
		CAT_DIFFICULTY:
			return _difficulty_fields()
	return []


## Flat list across everything — what the search box filters and what validate() walks.
static func all_fields() -> Array[BalanceField]:
	var out: Array[BalanceField] = []
	for cat: Dictionary in categories():
		var cid: String = cat["id"]
		for subj: Dictionary in subjects(cid):
			out.append_array(fields(cid, subj["id"]))
	return out


static func field_by_path(path: String) -> BalanceField:
	for f: BalanceField in all_fields():
		if f.path == path:
			return f
	return null


# ─── Characters ───────────────────────────────────────────────────────────────

## A character's own three numbers, then its full per-character stat sheet.
##
## The stat sheet is the same list as PLAYER > BASE STATS but addressed per character, so
## "the Warden crits less" is one edit here and "everyone dashes sooner" is one edit there.
## BalanceOverrides.player_stat() resolves per-character first, global second.
static func _character_fields(char_id: String) -> Array[BalanceField]:
	var cd: Dictionary = CharacterData.ALL.get(char_id, {})
	if cd.is_empty():
		return []
	var out: Array[BalanceField] = []
	out.append(BalanceField.make(BalanceOverrides.character_path(char_id, "base_hp"),
			"Max HP", float(cd.get("base_hp", 100.0)), "IDENTITY")
			.ranged(1.0, 600.0, 1.0)
			.described("Starting health. Feeds HealthComponent and the max_hp modifier.", "hp")
			.applied(BalanceField.Apply.REBUILD))
	out.append(BalanceField.make(BalanceOverrides.character_path(char_id, "base_armor"),
			"Armor", float(cd.get("base_armor", 0.0)), "IDENTITY")
			.ranged(0.0, 100.0, 1.0)
			.described("Physical resist. raw * (1 - armor / (armor + 100)).", "res")
			.applied(BalanceField.Apply.REBUILD))
	out.append(BalanceField.make(BalanceOverrides.character_path(char_id, "base_move_speed"),
			"Move Speed", float(cd.get("base_move_speed", 54.0)), "IDENTITY")
			.ranged(10.0, 200.0, 1.0)
			.described("Pixels per second. The pacing rebalance put the roster in the 48-66 band.", "px/s")
			.applied(BalanceField.Apply.REBUILD))
	out.append_array(_player_stat_fields(char_id))
	_sort_by_section(out)
	return out


# ─── Player stats ─────────────────────────────────────────────────────────────

## One field per entry in player.BASE_STATS, for `char_id` (or _global for the baseline).
##
## Enumerated from the table rather than listed, so the ~60 per-kit stats the roster keeps
## growing (hammer_count, storm_waves, thrall_feed_cap, ...) are all present without anyone
## maintaining a list. Kit-specific stats are filed under their owner's section via the
## hint table, so the Warden's five hammer stats do not clutter the Spark's sheet.
static func _player_stat_fields(char_id: String) -> Array[BalanceField]:
	var out: Array[BalanceField] = []
	var kit_owner: String = _kit_owner_for_character(char_id)
	for stat: String in PlayerScript.BASE_STATS.keys():
		var hint: Dictionary = STAT_HINTS.get(stat, {})
		var owner: String = str(hint.get("owner", ""))
		## A kit-only stat is inert on every other character — show it on its owner (and on
		## the global sheet, where it sets the baseline for whoever does own it).
		if owner != "" and char_id != BalanceOverrides.GLOBAL and owner != kit_owner:
			continue
		var base_v: float = float(PlayerScript.BASE_STATS[stat])
		var f := BalanceField.make(BalanceOverrides.player_stat_path(char_id, stat),
				str(hint.get("label", _humanize(stat))), base_v,
				str(hint.get("section", "OTHER")))
		if hint.has("min"):
			f.ranged(float(hint["min"]), float(hint.get("max", 10.0)), float(hint.get("step", -1.0)))
		if hint.has("doc"):
			f.described(str(hint["doc"]), str(hint.get("suffix", "")))
		f.applied(BalanceField.Apply.REBUILD)
		if DERIVED_STATS.has(stat):
			f.derived(str(DERIVED_STATS[stat]))
		out.append(f)
	_sort_by_section(out)
	return out


## Stats that `_load_character_stats` writes and something downstream then OVERWRITES on every
## rebuild, so an override on them can never be observed.
##
## `max_hp` / `move_speed` are re-assigned from CharacterData two lines later; `damage`,
## `attack_speed` and `projectile_count` are re-assigned by `_load_equipped_weapon()` via
## `_set_base_stat(...)` from the equipped weapon. All five shipped as live spinboxes in the
## first build of this tool and all five did nothing — found by screenshotting the finished
## panel and noticing Max HP appeared twice on one character sheet.
const DERIVED_STATS: Dictionary = {
	"max_hp": "set by CHARACTERS · Max HP",
	"move_speed": "set by CHARACTERS · Move Speed",
	"damage": "set by the equipped WEAPON · Damage",
	"attack_speed": "set by the equipped WEAPON · Attack Speed",
	"projectile_count": "set by the equipped WEAPON · Projectile Count",
}


## Group fields under one heading each, keeping each section's internal order.
##
## Without this, sections come out in Dictionary key order and a heading repeats every time
## the key order jumps back to it — the Warden's sheet rendered IDENTITY / CORE / COMBAT /
## CORE / COMBAT. A stable partition rather than a sort, so the deliberate order inside a
## section (Max HP before Armor before Move Speed) survives.
static func _sort_by_section(fields: Array[BalanceField]) -> void:
	var order: Array[String] = []
	var buckets: Dictionary = {}
	for f: BalanceField in fields:
		if not buckets.has(f.section):
			buckets[f.section] = [] as Array[BalanceField]
			order.append(f.section)
		(buckets[f.section] as Array).append(f)
	fields.clear()
	for section: String in order:
		for f: BalanceField in (buckets[section] as Array):
			fields.append(f)


static func _kit_owner_for_character(char_id: String) -> String:
	return str((CharacterData.ALL.get(char_id, {}) as Dictionary).get("melee_kit", ""))


## Turn "dash_cooldown" into "Dash Cooldown" for stats with no hint entry.
static func _humanize(snake: String) -> String:
	var parts: PackedStringArray = snake.split("_")
	var words: PackedStringArray = PackedStringArray()
	for p: String in parts:
		words.append(p.capitalize() if p.length() > 0 else p)
	return " ".join(words)


## Labels, ranges, docs and ownership for the stats worth describing. Anything missing here
## still appears — this is polish, not the source of coverage.
##
## `owner` is a kit id: the stat only shows on that kit's character (and on the global
## sheet). It is how ~40 host-side kit stats stay out of eleven irrelevant stat sheets.
const STAT_HINTS: Dictionary = {
	"max_hp": {"section": "CORE", "label": "Max HP", "min": 1.0, "max": 600.0, "step": 1.0,
		"doc": "Overridden per character by CharacterData.base_hp.", "suffix": "hp"},
	"move_speed": {"section": "CORE", "label": "Move Speed", "min": 10.0, "max": 200.0, "step": 1.0,
		"doc": "Overridden per character by CharacterData.base_move_speed.", "suffix": "px/s"},
	"damage": {"section": "CORE", "label": "Damage", "min": 0.0, "max": 120.0, "step": 0.5,
		"doc": "The `damage` modifier tag every ability scales from."},
	"attack_speed": {"section": "CORE", "label": "Attack Speed", "min": 0.1, "max": 5.0, "step": 0.05,
		"doc": "Multiplier on ability cadence.", "suffix": "x"},
	"crit_chance": {"section": "COMBAT", "label": "Crit Chance", "min": 0.0, "max": 1.0, "step": 0.01,
		"doc": "0-1. Rolled last in the damage pipeline."},
	"crit_multiplier": {"section": "COMBAT", "label": "Crit Damage", "min": 1.0, "max": 5.0, "step": 0.05,
		"doc": "Damage multiplier on a crit.", "suffix": "x"},
	"melee_range": {"section": "COMBAT", "label": "Reach", "min": 0.25, "max": 3.0, "step": 0.05,
		"doc": "Multiplier on melee hit radius AND swing-effect size — the visual tracks it.", "suffix": "x"},
	"pickup_radius": {"section": "CORE", "label": "Pickup Radius", "min": 10.0, "max": 300.0, "step": 5.0,
		"doc": "THE control for pickup reach — it sets the collector circle directly every rebuild.", "suffix": "px"},
	"projectile_count": {"section": "COMBAT", "label": "Projectile Count", "min": 1.0, "max": 20.0, "step": 1.0},
	"pierce": {"section": "COMBAT", "label": "Pierce", "min": 0.0, "max": 20.0, "step": 1.0,
		"doc": "Extra enemies a projectile passes through. -1 would be infinite."},
	"projectile_size": {"section": "COMBAT", "label": "Projectile Size", "min": 0.25, "max": 4.0, "step": 0.05,
		"suffix": "x"},
	"dash_speed": {"section": "DASH", "label": "Dash Speed", "min": 100.0, "max": 1500.0, "step": 10.0,
		"suffix": "px/s"},
	"dash_cooldown": {"section": "DASH", "label": "Dash Cooldown", "min": 0.1, "max": 10.0, "step": 0.05,
		"doc": "Per-charge refill time.", "suffix": "s"},
	"dash_charges": {"section": "DASH", "label": "Dash Charges", "min": 1.0, "max": 6.0, "step": 1.0},
	"combo_window": {"section": "COMBO", "label": "Combo Window", "min": 0.25, "max": 3.0, "step": 0.05,
		"doc": "Multiplier on every phase's cancel window — the single biggest execution-floor lever.",
		"suffix": "x"},
	"combo_timeout": {"section": "COMBO", "label": "Combo Timeout", "min": 0.5, "max": 15.0, "step": 0.1,
		"doc": "Seconds without a landed hit before the counter resets.", "suffix": "s"},
	"combo_lock": {"section": "COMBO", "label": "Combo Lock", "min": 0.0, "max": 1.0, "step": 1.0,
		"doc": ">= 1 freezes the counter so it never decays."},
	## Kit-owned. Each is inert on every character but its owner.
	"pile_capacity": {"section": "BARBARIAN", "owner": "barbarian", "label": "Pile Capacity",
		"min": 1.0, "max": 24.0, "step": 1.0, "doc": "Enemies Pile Driver can carry at once."},
	"whirl_speed": {"section": "FIGHTER", "owner": "fighter", "label": "Whirlwind Speed Bonus",
		"min": 0.0, "max": 200.0, "step": 1.0, "doc": "FLAT px/s added while holding Whirlwind.", "suffix": "px/s"},
	"whirl_bolt_chance": {"section": "FIGHTER", "owner": "fighter", "label": "Whirlwind Bolt Chance",
		"min": 0.0, "max": 1.0, "step": 0.01},
	"hammer_count": {"section": "PALADIN", "owner": "paladin", "label": "Extra Hammers",
		"min": 0.0, "max": 8.0, "step": 1.0, "doc": "The base throw is always 1; this adds to it."},
	"hammer_damage": {"section": "PALADIN", "owner": "paladin", "label": "Hammer Damage Bonus",
		"min": 0.0, "max": 4.0, "step": 0.05, "suffix": "x"},
	"hammer_burst": {"section": "PALADIN", "owner": "paladin", "label": "Hammer Burst",
		"min": 0.0, "max": 1.0, "step": 1.0, "doc": "> 0: a hammer detonates where its spiral ends."},
	"reckoning_reflect": {"section": "PALADIN", "owner": "paladin", "label": "Reckoning Reflect +",
		"min": 0.0, "max": 4.0, "step": 0.05, "doc": "ADDED to DOME_REFLECT_MULT, not multiplied."},
	"aegis_bonus": {"section": "PALADIN", "owner": "paladin", "label": "Aegis Absorb +",
		"min": 0.0, "max": 2.0, "step": 0.05, "doc": "ADDED to ABSORB_SHIELD_FRAC."},
	"storm_damage": {"section": "WIZARD", "owner": "wizard", "label": "Storm Damage +",
		"min": 0.0, "max": 4.0, "step": 0.05, "doc": "ADDED to STORM_CALL_DAMAGE_MULT."},
	"storm_waves": {"section": "WIZARD", "owner": "wizard", "label": "Extra Storm Waves",
		"min": 0.0, "max": 6.0, "step": 1.0},
	"storm_linger": {"section": "WIZARD", "owner": "wizard", "label": "Storm Linger",
		"min": 0.0, "max": 12.0, "step": 0.25, "suffix": "s"},
	"familiar_count": {"section": "WIZARD", "owner": "wizard", "label": "Extra Familiars",
		"min": 0.0, "max": 6.0, "step": 1.0},
	"familiar_life": {"section": "WIZARD", "owner": "wizard", "label": "Familiar Lifetime +",
		"min": 0.0, "max": 60.0, "step": 1.0, "suffix": "s"},
	"ice_aura_damage": {"section": "WIZARD", "owner": "wizard", "label": "Ice Aura Damage",
		"min": 0.0, "max": 2.0, "step": 0.01, "doc": "Fraction of damage per tick inside the shard ring."},
	"blink_nova": {"section": "WIZARD", "owner": "wizard", "label": "Blink Nova",
		"min": 0.0, "max": 4.0, "step": 0.05, "doc": "Fraction of damage detonated where the blink STARTED."},
	"thrall_damage": {"section": "BLOOD MAGE", "owner": "blood_mage", "label": "Thrall Damage +",
		"min": 0.0, "max": 4.0, "step": 0.05},
	"thrall_feed_cap": {"section": "BLOOD MAGE", "owner": "blood_mage", "label": "Thrall Feed Cap +",
		"min": 0.0, "max": 30.0, "step": 1.0},
	"thrall_count": {"section": "BLOOD MAGE", "owner": "blood_mage", "label": "Extra Thralls",
		"min": 0.0, "max": 6.0, "step": 1.0},
	"thrall_immortal": {"section": "BLOOD MAGE", "owner": "blood_mage", "label": "Thrall Immortal",
		"min": 0.0, "max": 1.0, "step": 1.0},
	"pool_heal": {"section": "BLOOD MAGE", "owner": "blood_mage", "label": "Blood Pool Heal +",
		"min": 0.0, "max": 1.0, "step": 0.01},
	"vamp_heal": {"section": "BLOOD MAGE", "owner": "blood_mage", "label": "Vampirize Heal +",
		"min": 0.0, "max": 1.0, "step": 0.01},
	"blood_cost": {"section": "BLOOD MAGE", "owner": "blood_mage", "label": "Blood Cost +",
		"min": -1.0, "max": 1.0, "step": 0.01, "doc": "Negative makes Extract Power cheaper."},
	"demon_damage": {"section": "DEMONOLOGIST", "owner": "demonologist", "label": "Demon Damage +",
		"min": 0.0, "max": 4.0, "step": 0.05},
	"demon_life": {"section": "DEMONOLOGIST", "owner": "demonologist", "label": "Demon Lifetime +",
		"min": 0.0, "max": 60.0, "step": 1.0, "suffix": "s"},
	"demon_count": {"section": "DEMONOLOGIST", "owner": "demonologist", "label": "Extra Demons",
		"min": 0.0, "max": 6.0, "step": 1.0},
	"demon_rage": {"section": "DEMONOLOGIST", "owner": "demonologist", "label": "Demon Rage",
		"min": 0.0, "max": 1.0, "step": 1.0, "doc": "> 0 inverts the pact: your wounds enrage it."},
	"demon_burst": {"section": "DEMONOLOGIST", "owner": "demonologist", "label": "Demon Burst",
		"min": 0.0, "max": 4.0, "step": 0.05},
	"fissure_damage": {"section": "DEMONOLOGIST", "owner": "demonologist", "label": "Fissure Damage",
		"min": 0.0, "max": 4.0, "step": 0.05, "doc": "0 = the Hell Breach crack is pure VFX."},
	"ashen_power": {"section": "DEMONOLOGIST", "owner": "demonologist", "label": "Ashen Step Power +",
		"min": 0.0, "max": 4.0, "step": 0.05},
}


# ─── Hitbox ───────────────────────────────────────────────────────────────────

## The player's actual collision geometry.
##
## These are the only fields in the registry whose shipped values are recorded in code
## rather than read from where they live: the shapes are SubResources inside
## `scenes/player.tscn`, and CLAUDE.md forbids hand-editing .tscn files. So the editor
## writes overrides and `player._apply_hitbox_overrides()` stamps them onto the live shapes
## at _ready — the scene stays untouched and authoritative for the shipped numbers, which
## HITBOX_BASE mirrors.
static func _hitbox_fields() -> Array[BalanceField]:
	var out: Array[BalanceField] = []
	out.append(BalanceField.make(BalanceOverrides.hitbox_path("hurtbox_size"),
			"Hurtbox Size", HITBOX_BASE["hurtbox_size"], "GEOMETRY", BalanceField.Kind.VEC2)
			.ranged(2.0, 64.0, 1.0)
			.described("The rectangle enemies must overlap to damage you. 16x16 shipped — the sprite is 32x32, so this is deliberately smaller than the art.", "px")
			.applied(BalanceField.Apply.LIVE))
	out.append(BalanceField.make(BalanceOverrides.hitbox_path("body_size"),
			"Body Size", HITBOX_BASE["body_size"], "GEOMETRY", BalanceField.Kind.VEC2)
			.ranged(2.0, 64.0, 1.0)
			.described("The CharacterBody2D shape that collides with level walls. Growing this can wedge you in 16px chokes — the flow field seals those at 16.", "px")
			.applied(BalanceField.Apply.LIVE))
	## NOTE: there is deliberately no "pickup radius" field here.
	##
	## `player._update_pickup_radius()` assigns the collector circle unconditionally from
	## `get_stat("pickup_radius")`, so the 50.0 in player.tscn is overwritten the moment
	## _ready finishes and can never be observed. A tunable here would be a spinbox that
	## silently does nothing — the exact failure this layer exists to prevent. The real
	## control is the `pickup_radius` STAT, under PLAYER > BASE STATS and each character.
	return out


# ─── Weapons ──────────────────────────────────────────────────────────────────

const WEAPON_HINTS: Dictionary = {
	"damage": {"section": "CORE", "label": "Damage", "min": 0.0, "max": 150.0, "step": 0.5},
	"attack_speed": {"section": "CORE", "label": "Attack Speed", "min": 0.05, "max": 10.0, "step": 0.05,
		"doc": "Shots per second.", "suffix": "/s"},
	"projectile_speed": {"section": "PROJECTILE", "label": "Projectile Speed", "min": 20.0, "max": 1200.0,
		"step": 10.0, "suffix": "px/s"},
	"lifetime": {"section": "PROJECTILE", "label": "Lifetime", "min": 0.1, "max": 8.0, "step": 0.05,
		"doc": "Range = speed x lifetime. The 2026-06-24 manual-aim pass used this as the range nerf.",
		"suffix": "s"},
	"projectile_count": {"section": "PROJECTILE", "label": "Projectile Count", "min": 1.0, "max": 24.0, "step": 1.0},
	"spread_angle": {"section": "PROJECTILE", "label": "Spread", "min": 0.0, "max": 360.0, "step": 1.0,
		"doc": "Total cone width in degrees.", "suffix": "deg"},
	"aoe_radius": {"section": "AREA", "label": "AoE Radius", "min": 0.0, "max": 300.0, "step": 2.0, "suffix": "px"},
	"fuse_time": {"section": "AREA", "label": "Fuse", "min": 0.0, "max": 6.0, "step": 0.05, "suffix": "s"},
	"beam_range": {"section": "AREA", "label": "Beam Range", "min": 10.0, "max": 900.0, "step": 10.0, "suffix": "px"},
	"orbit_radius": {"section": "AREA", "label": "Orbit Radius", "min": 5.0, "max": 300.0, "step": 2.0, "suffix": "px"},
	"orbit_speed": {"section": "AREA", "label": "Orbit Speed", "min": 0.0, "max": 20.0, "step": 0.1},
	"mod_slots": {"section": "META", "label": "Mod Slots", "min": 0.0, "max": 6.0, "step": 1.0},
	"drop_weight": {"section": "META", "label": "Drop Weight", "min": 0.0, "max": 100.0, "step": 1.0,
		"doc": "0 = never in the generic pool (class gear is picked by smart-loot instead)."},
}

## Weapon dictionary keys that are identity/presentation, not balance. Everything else in a
## weapon entry becomes a field, so a new numeric key is covered automatically.
const WEAPON_SKIP: Dictionary = {
	"id": true, "display_name": true, "description": true, "behavior": true,
	"damage_type": true, "tint": true, "unlock_id": true, "class_lock": true,
	"kit": true, "rarity": true, "tier": true,
}


static func _weapon_fields(weapon_id: String) -> Array[BalanceField]:
	var wd: Dictionary = WeaponData.ALL.get(weapon_id, {})
	if wd.is_empty():
		return []
	var out: Array[BalanceField] = []
	for key: String in wd.keys():
		if WEAPON_SKIP.has(key):
			continue
		var v: Variant = wd[key]
		if not (v is float or v is int or v is bool):
			continue
		var hint: Dictionary = WEAPON_HINTS.get(key, {})
		var kind: BalanceField.Kind = BalanceField.Kind.FLOAT
		if v is bool:
			kind = BalanceField.Kind.BOOL
		elif v is int:
			kind = BalanceField.Kind.INT
		var f := BalanceField.make(BalanceOverrides.weapon_path(weapon_id, key),
				str(hint.get("label", _humanize(key))), v,
				str(hint.get("section", "OTHER")), kind)
		if hint.has("min"):
			f.ranged(float(hint["min"]), float(hint.get("max", 10.0)), float(hint.get("step", -1.0)))
		if hint.has("doc"):
			f.described(str(hint["doc"]), str(hint.get("suffix", "")))
		elif hint.has("suffix"):
			f.described("", str(hint["suffix"]))
		f.applied(BalanceField.Apply.REBUILD)
		out.append(f)
	return out


# ─── Enemies ──────────────────────────────────────────────────────────────────

## Property name on EnemyDefinition -> hint. "max_hp" is special-cased: it lives inside the
## `base_stats` dictionary rather than as a property.
const ENEMY_FIELDS: Array = [
	["max_hp", "CORE", "Max HP", 1.0, 20000.0, 1.0, "Lives in EnemyDefinition.base_stats.", "hp"],
	["contact_damage", "CORE", "Contact Damage", 0.0, 200.0, 0.5, "Damage dealt by touching the player.", ""],
	["move_speed", "CORE", "Move Speed", 0.0, 300.0, 1.0, "", "px/s"],
	["base_armor", "CORE", "Armor", 0.0, 200.0, 1.0, "raw * (1 - armor / (armor + 100)).", ""],
	["xp_value", "REWARD", "XP Value", 0.0, 500.0, 1.0, "", "xp"],
	["health_drop_chance", "REWARD", "Health Drop", 0.0, 1.0, 0.01, "0-1 chance of a heart on death.", ""],
	["aggro_range", "AI", "Aggro Range", 0.0, 900.0, 10.0, "0 = always aggressive.", "px"],
	["engage_distance", "AI", "Engage Distance", 0.0, 400.0, 2.0, "How close before it attacks.", "px"],
	["preferred_range", "AI", "Preferred Range", 0.0, 600.0, 5.0, "Ranged roles hold this distance.", "px"],
	["retarget_interval", "AI", "Retarget Interval", 0.1, 10.0, 0.1, "", "s"],
	["aa_interval_override", "AI", "Attack Interval", 0.0, 15.0, 0.05, "> 0 overrides attack-speed cadence.", "s"],
	["knockback_multiplier", "AI", "Knockback Taken", 0.0, 4.0, 0.05, "< 1 for heavy enemies.", "x"],
]


static func _enemy_fields(enemy_id: String) -> Array[BalanceField]:
	EnemyRegistry.build_all()
	var out: Array[BalanceField] = []
	for row: Array in ENEMY_FIELDS:
		var key: String = row[0]
		var base_v: float = EnemyRegistry.base_value(enemy_id, key)
		if is_nan(base_v):
			continue
		out.append(BalanceField.make(BalanceOverrides.enemy_path(enemy_id, key),
				str(row[2]), base_v, str(row[1]))
				.ranged(float(row[3]), float(row[4]), float(row[5]))
				.described(str(row[6]), str(row[7]))
				.applied(BalanceField.Apply.RESTART))
	return out


# ─── Combo chains ─────────────────────────────────────────────────────────────

## Every tunable number in a kit's combo graphs and Q/E skills.
##
## Built from a PRISTINE kit — no class mods, no run upgrades — because those layers are
## multiplicative on top and the shipped phase value is what "revert" has to restore.
##
## One semantic caveat, worth knowing before tuning damage here: a phase's damage numbers
## are ABSOLUTE and are computed at kit-build time from the equipped weapon
## (`hit.base_damage = dmg * SOME_MULT` all through ChainFactory). Overriding one therefore
## PINS that hit to a fixed number and it stops tracking the weapon — which is usually not
## what you want for a damage pass. To move a whole kit's damage while keeping the weapon
## relationship intact, tune the WEAPON's damage, or the player's `damage` stat.
##
## Phases are addressed by animation name, the same convention ClassModData and
## AbilityUpgradeData use, so an edit that renames a phase orphans the override visibly
## (validate() reports it) instead of silently reassigning it to a neighbour, which is what
## index addressing would do. A name that repeats inside one graph gets a "#n" suffix.
static func _chain_fields(kit_id: String) -> Array[BalanceField]:
	var out: Array[BalanceField] = []
	var weapon_data: Dictionary = _weapon_data_for_kit(kit_id)
	var abilities: Dictionary = ChainFactory.build_kit(kit_id, weapon_data)
	var skills: Dictionary = SkillFactory.build_kit_skills(kit_id, weapon_data)
	for slot: String in skills.keys():
		abilities[slot] = skills[slot]

	## Same walker the applier uses, so the address a field is emitted under and the address
	## the value is stamped back onto can never drift apart. See BalanceChain.
	BalanceChain.walk(abilities, func(graph: String, addr: String, phase: ChoreographyPhase) -> void:
		out.append_array(_phase_fields(kit_id, graph, addr,
				"%s · %s" % [graph.to_upper(), addr], phase)))
	return out


static func _phase_fields(kit_id: String, graph: String, addr: String, section: String,
		phase: ChoreographyPhase) -> Array[BalanceField]:
	var out: Array[BalanceField] = []

	## The cancel/branch window. Only "wait" phases have one — for anim_finished phases the
	## field is unread, so offering it would be a spinbox that does nothing.
	if phase.exit_type == "wait":
		out.append(BalanceField.make(BalanceOverrides.chain_path(kit_id, graph, addr, "window"),
				"Cancel Window", phase.wait_duration, section)
				.ranged(0.0, 3.0, 0.01)
				.described("Seconds the runner waits for your next input. The player's combo_window stat multiplies this.", "s")
				.applied(BalanceField.Apply.REBUILD))
	if not is_equal_approx(phase.telegraph_speed_scale, 1.0) or phase.exit_type == "wait":
		out.append(BalanceField.make(BalanceOverrides.chain_path(kit_id, graph, addr, "telegraph"),
				"Telegraph Speed", phase.telegraph_speed_scale, section)
				.ranged(0.1, 4.0, 0.05)
				.described("Sprite playback speed during the wind-up.", "x")
				.applied(BalanceField.Apply.REBUILD))
	out.append(BalanceField.make(BalanceOverrides.chain_path(kit_id, graph, addr, "hit_frame"),
			"Hit Frame", phase.hit_frame, section, BalanceField.Kind.INT)
			.ranged(-1.0, 40.0, 1.0)
			.described("Frame the effects fire on. -1 = on phase entry. The Animation Lab (F10) also writes this and wins.", "")
			.applied(BalanceField.Apply.REBUILD))

	out.append_array(_effect_fields(kit_id, graph, addr, section, phase.effects))
	return out


## Numbers inside a phase's effect list, addressed by type ordinal (aoe0, proj1, zone0...)
## so the path is stable as long as the phase's effect composition is.
static func _effect_fields(kit_id: String, graph: String, addr: String, section: String,
		effects: Array) -> Array[BalanceField]:
	var out: Array[BalanceField] = []
	var counts: Dictionary = {"aoe": 0, "proj": 0, "zone": 0, "heal": 0, "dmg": 0, "shield": 0, "push": 0}

	for e in effects:
		if e is AreaDamageEffect:
			var i: int = counts["aoe"]
			counts["aoe"] = i + 1
			var ad: AreaDamageEffect = e
			out.append(_ef(kit_id, graph, addr, "aoe%d_damage" % i, "AoE Damage", ad.base_damage, section)
					.ranged(0.0, 300.0, 0.5)
					.described("ABSOLUTE damage, baked at kit build as weapon_damage x this node's multiplier. Overriding it pins the number, so this hit stops tracking the weapon.", "dmg"))
			out.append(_ef(kit_id, graph, addr, "aoe%d_radius" % i, "AoE Radius", ad.aoe_radius, section)
					.ranged(0.0, 400.0, 1.0)
					.described("Hit-zone radius. The melee_range stat multiplies it, and the swing FX is scaled to match.", "px"))
			out.append(_ef(kit_id, graph, addr, "aoe%d_offset" % i, "AoE Forward Offset", ad.aoe_forward_offset, section)
					.ranged(0.0, 200.0, 1.0)
					.described("Pushes the hit circle along the aim. Keep it under the radius or enemies hugging you are missed.", "px"))
		elif e is SpawnProjectilesEffect:
			var i2: int = counts["proj"]
			counts["proj"] = i2 + 1
			var sp: SpawnProjectilesEffect = e
			out.append(_ef(kit_id, graph, addr, "proj%d_count" % i2, "Projectile Count", sp.count, section,
					BalanceField.Kind.INT).ranged(1.0, 32.0, 1.0))
			out.append(_ef(kit_id, graph, addr, "proj%d_spread" % i2, "Projectile Spread", sp.spread_angle, section)
					.ranged(0.0, 360.0, 1.0).described("Total cone width.", "deg"))
			if sp.projectile != null:
				out.append(_ef(kit_id, graph, addr, "proj%d_speed" % i2, "Projectile Speed",
						sp.projectile.speed, section).ranged(10.0, 1200.0, 10.0).described("", "px/s"))
				out.append(_ef(kit_id, graph, addr, "proj%d_hit_radius" % i2, "Projectile Hit Radius",
						sp.projectile.hit_radius, section).ranged(1.0, 80.0, 1.0).described("", "px"))
				out.append(_ef(kit_id, graph, addr, "proj%d_pierce" % i2, "Projectile Pierce",
						sp.projectile.pierce_count, section, BalanceField.Kind.INT)
						.ranged(-1.0, 20.0, 1.0).described("0 = dies on first hit, -1 = infinite."))
				out.append(_ef(kit_id, graph, addr, "proj%d_range" % i2, "Projectile Range",
						sp.projectile.max_range, section).ranged(0.0, 1200.0, 10.0)
						.described("0 = travel until screen bounds.", "px"))
		elif e is GroundZoneEffect:
			var i3: int = counts["zone"]
			counts["zone"] = i3 + 1
			var gz: GroundZoneEffect = e
			out.append(_ef(kit_id, graph, addr, "zone%d_radius" % i3, "Zone Radius", gz.radius, section)
					.ranged(0.0, 400.0, 1.0).described("", "px"))
			out.append(_ef(kit_id, graph, addr, "zone%d_duration" % i3, "Zone Duration", gz.duration, section)
					.ranged(0.0, 60.0, 0.25).described("", "s"))
			out.append(_ef(kit_id, graph, addr, "zone%d_tick" % i3, "Zone Tick Interval", gz.tick_interval, section)
					.ranged(0.05, 5.0, 0.05).described("", "s"))
		elif e is HealEffect:
			var i4: int = counts["heal"]
			counts["heal"] = i4 + 1
			var he: HealEffect = e
			out.append(_ef(kit_id, graph, addr, "heal%d_amount" % i4, "Heal Amount", he.base_healing, section)
					.ranged(0.0, 200.0, 1.0).described("", "hp"))
			out.append(_ef(kit_id, graph, addr, "heal%d_pct" % i4, "Heal % Max HP", he.percent_max_hp, section)
					.ranged(0.0, 1.0, 0.01).described("> 0 overrides the flat amount."))
		elif e is DealDamageEffect:
			var i5: int = counts["dmg"]
			counts["dmg"] = i5 + 1
			var dd: DealDamageEffect = e
			out.append(_ef(kit_id, graph, addr, "dmg%d_damage" % i5, "Direct Damage", dd.base_damage, section)
					.ranged(0.0, 300.0, 0.5)
					.described("ABSOLUTE damage, baked from the weapon at kit build. Overriding pins it off the weapon.", "dmg"))
		elif e is ApplyShieldEffect:
			var i6: int = counts["shield"]
			counts["shield"] = i6 + 1
			var sh: ApplyShieldEffect = e
			out.append(_ef(kit_id, graph, addr, "shield%d_amount" % i6, "Shield Amount", sh.base_shield, section)
					.ranged(0.0, 300.0, 0.5).described("Flat shield granted, plus any scaling_attribute contribution.", "hp"))
	return out


static func _ef(kit_id: String, graph: String, addr: String, field: String, label: String,
		base_v: Variant, section: String,
		kind: BalanceField.Kind = BalanceField.Kind.FLOAT) -> BalanceField:
	return BalanceField.make(BalanceOverrides.chain_path(kit_id, graph, addr, field),
			label, base_v, section, kind).applied(BalanceField.Apply.REBUILD)


# ─── Difficulty ───────────────────────────────────────────────────────────────

static func _difficulty_fields() -> Array[BalanceField]:
	var out: Array[BalanceField] = []
	for i in range(GameManager.PHASE_DURATIONS.size()):
		var nm: String = str(GameManager.PHASE_NAMES[i]) if i < GameManager.PHASE_NAMES.size() else str(i + 1)
		out.append(BalanceField.make(BalanceOverrides.difficulty_path("phase_duration_%d" % i),
				"P%d %s" % [i + 1, nm], float(GameManager.PHASE_DURATIONS[i]), "PHASE LENGTH")
				.ranged(10.0, 600.0, 5.0)
				.described("Seconds this phase runs before the clock advances.", "s")
				.applied(BalanceField.Apply.RESTART))
	out.append(BalanceField.make(BalanceOverrides.difficulty_path("scale_period"),
			"Ramp Period", GameManager.DIFFICULTY_SCALE_PERIOD, "DIFFICULTY RAMP")
			.ranged(5.0, 300.0, 5.0)
			.described("difficulty = 1 + (run_time / period) * rate.", "s")
			.applied(BalanceField.Apply.LIVE))
	out.append(BalanceField.make(BalanceOverrides.difficulty_path("scale_rate"),
			"Ramp Rate", GameManager.DIFFICULTY_SCALE_RATE, "DIFFICULTY RAMP")
			.ranged(0.0, 2.0, 0.01)
			.described("How much difficulty gains per ramp period.")
			.applied(BalanceField.Apply.LIVE))
	out.append(BalanceField.make(BalanceOverrides.difficulty_path("max_enemies"),
			"Enemy Cap", 90.0, "SPAWNING", BalanceField.Kind.INT)
			.ranged(5.0, 400.0, 5.0)
			.described("Hard cap on live enemies. Bosses bypass it.")
			.applied(BalanceField.Apply.LIVE))
	## PHASE_DMG_MULT is intentionally absent: nothing reads it (enemy damage does not
	## scale per phase today). A tuner for a dead constant is a control that silently
	## does nothing, which is the failure this whole layer exists to avoid.
	var mults: Array = [
		["hp_mult", "HP x", EnemySpawnManager.PHASE_HP_MULT, "ENEMY SCALING"],
		["spawn_mult", "Spawn x", EnemySpawnManager.PHASE_SPAWN_MULT, "ENEMY SCALING"],
	]
	for row: Array in mults:
		var key: String = row[0]
		var label: String = row[1]
		var arr: Array = row[2]
		for i in range(arr.size()):
			out.append(BalanceField.make(BalanceOverrides.difficulty_path("%s_%d" % [key, i]),
					"P%d %s" % [i + 1, label], float(arr[i]), str(row[3]))
					.ranged(0.1, 30.0, 0.1)
					.described("Multiplier applied to every enemy spawned in phase %d." % (i + 1), "x")
					.applied(BalanceField.Apply.LIVE))
	return out


# ─── Validation ───────────────────────────────────────────────────────────────

## Override paths that no longer resolve to a field — the tool's own version of
## ClassModFactory.validate_anim_targets().
##
## This is the failure mode that matters: rename a combo phase, delete a weapon, retire an
## enemy, and the override for it stays in the file doing nothing forever. Nothing would
## report it, and the file would slowly fill with lies about what is tuned. The editor
## surfaces this count in its footer and offers to prune.
static func orphaned_paths() -> Array[String]:
	var known: Dictionary = {}
	for f: BalanceField in all_fields():
		known[f.path] = true
	var out: Array[String] = []
	for p: String in BalanceOverrides.overridden_paths():
		if not known.has(p):
			out.append(p)
	return out


## Overrides that exist but cannot matter: either they equal the shipped value, or they sit on
## a DERIVED field that something downstream overwrites every rebuild. Both are noise in the
## change list, and the second kind is worse — it reads like tuning that is in effect.
##
## The derived case is reachable through history rather than through the UI: an override
## written before a field was known to be derived stays in the file, and PRUNE is how it
## leaves.
static func noop_paths() -> Array[String]:
	var out: Array[String] = []
	for f: BalanceField in all_fields():
		if f.is_noop_override() or (f.is_derived() and f.is_overridden()):
			out.append(f.path)
	return out
