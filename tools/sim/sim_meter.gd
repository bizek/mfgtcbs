extends RefCounted

## SimMeter — what a scenario measured, read off the same EventBus signals RunReportManager and
## the Training Room DPS meter use.
##
## Offence is "damage landed on anything in the enemies group", not "hits whose source is the
## player". The distinction matters: pets and summons deal their own hits (FireFamiliar uses the
## player as attacker, but not every companion does), and in the training room nothing but the
## player's side ever damages an enemy. Counting by TARGET makes pet-heavy kits comparable with
## everyone else. The player-sourced share is still recorded separately.

var frames: int = 0

var _player: Node2D = null
var _active: bool = false

var dmg_total: float = 0.0
var dmg_player: float = 0.0
var dmg_other: float = 0.0
var hits: int = 0
var crits: int = 0
var kills: int = 0
var dmg_taken: float = 0.0
var hits_taken: int = 0
var healed: float = 0.0
var biggest_hit: float = 0.0
var abilities_used: Dictionary = {}   ## ability_id -> casts
var by_ability: Dictionary = {}       ## ability key -> {"damage", "hits"}
var taken_by: Dictionary = {}         ## enemy id -> damage
var first_kill_frame: int = -1
## Optional raw hit log (scenario "hit_log": true) — used to reconcile the meter against hand
## arithmetic, never by the reports.
var log_hits: bool = false
var hit_log: Array = []


func connect_bus() -> void:
	EventBus.on_hit_dealt.connect(_on_hit)
	EventBus.on_kill.connect(_on_kill)
	EventBus.on_heal.connect(_on_heal)
	EventBus.on_ability_used.connect(_on_ability_used)


func begin(player: Node2D) -> void:
	_player = player
	_active = true
	frames = 0
	dmg_total = 0.0
	dmg_player = 0.0
	dmg_other = 0.0
	hits = 0
	crits = 0
	kills = 0
	dmg_taken = 0.0
	hits_taken = 0
	healed = 0.0
	biggest_hit = 0.0
	abilities_used = {}
	by_ability = {}
	taken_by = {}
	first_kill_frame = -1
	hit_log = []


func _on_hit(source, target, hit_data) -> void:
	if not _active or target == null or not is_instance_valid(target):
		return
	var amount: float = hit_data.amount if hit_data is HitData else 0.0
	if target == _player:
		if amount > 0.0:
			dmg_taken += amount
			hits_taken += 1
			var key: String = "env"
			if source != null and is_instance_valid(source) and "enemy_id" in source:
				key = str(source.enemy_id)
			taken_by[key] = float(taken_by.get(key, 0.0)) + amount
		return
	if not target.is_in_group("enemies"):
		return
	dmg_total += amount
	hits += 1
	if log_hits and hit_log.size() < 400:
		hit_log.append([snappedf(frames / 60.0, 0.001), snappedf(amount, 0.01),
				hit_data is HitData and hit_data.is_crit,
				str(hit_data.ability.ability_id) if hit_data is HitData and hit_data.ability != null else "",
				str(target.name)])
	biggest_hit = maxf(biggest_hit, amount)
	if hit_data is HitData and hit_data.is_crit:
		crits += 1
	if source == _player:
		dmg_player += amount
	else:
		dmg_other += amount
	var akey: String = "other"
	if hit_data is HitData and hit_data.ability != null and "ability_id" in hit_data.ability:
		akey = str(hit_data.ability.ability_id)
		if akey == "":
			akey = "other"
	elif source != _player:
		akey = "companions"
	var row: Dictionary = by_ability.get(akey, {"damage": 0.0, "hits": 0})
	row["damage"] = float(row["damage"]) + amount
	row["hits"] = int(row["hits"]) + 1
	by_ability[akey] = row


func _on_kill(_killer, victim) -> void:
	if not _active or victim == null or not is_instance_valid(victim):
		return
	if victim.is_in_group("enemies"):
		kills += 1
		if first_kill_frame < 0:
			first_kill_frame = frames


func _on_heal(_source, target, amount: float) -> void:
	if _active and target == _player:
		healed += amount


func _on_ability_used(source, ability) -> void:
	if not _active or source != _player or ability == null:
		return
	var id: String = str(ability.ability_id) if "ability_id" in ability else "?"
	abilities_used[id] = int(abilities_used.get(id, 0)) + 1


func result() -> Dictionary:
	_active = false
	var secs: float = maxf(frames / 60.0, 1.0 / 60.0)
	return {
		"seconds": secs,
		"dps": dmg_total / secs,
		"dps_player": dmg_player / secs,
		"dps_other": dmg_other / secs,
		"dmg_total": dmg_total,
		"hits": hits,
		"crits": crits,
		"crit_rate": (float(crits) / hits) if hits > 0 else 0.0,
		"kills": kills,
		"kills_per_min": kills / secs * 60.0,
		"first_kill_s": (first_kill_frame / 60.0) if first_kill_frame >= 0 else -1.0,
		"dmg_taken": dmg_taken,
		"dtps": dmg_taken / secs,
		"hits_taken": hits_taken,
		"healed": healed,
		"biggest_hit": biggest_hit,
		"abilities_used": abilities_used,
		"by_ability": by_ability,
		"taken_by": taken_by,
		"hit_log": hit_log,
	}
