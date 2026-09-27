extends Node

## See sim_catalog.gd.

func _ready() -> void:
	var out_path: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
	var chars: Array = []
	for cid: String in CharacterData.ORDER:
		var d: Dictionary = CharacterData.ALL.get(cid, {})
		var kit: String = str(d.get("melee_kit", ""))
		var ups: Array = []
		for e: Dictionary in AbilityUpgradeData.get_upgrades_for_kit(kit):
			ups.append({"id": e.get("id", ""), "name": e.get("name", ""),
					"description": e.get("description", ""), "op": e.get("op", ""),
					"max_rank": AbilityUpgradeData.max_rank_of(e), "requires": e.get("requires", [])})
		var mods: Array = []
		for mid in ModApplicability.class_mod_ids_for(cid):
			var m: Dictionary = ClassModData.ALL.get(mid, {})
			mods.append({"id": mid, "name": m.get("name", mid), "description": m.get("description", ""),
					"rarity": ClassModData.rarity_of(mid)})
		var info: Dictionary = {}
		for k in d.keys():
			var v = d[k]
			if v is String or v is float or v is int or v is bool:
				info[k] = v
		chars.append({"id": cid, "kit": kit, "info": info,
				"caps": ModApplicability.capabilities_for_character(cid),
				"ability_upgrades": ups, "mods": mods,
				"mod_evolutions": ClassModData.evolutions_for_kit(kit).map(func(eid: String) -> Dictionary:
					var ev: Dictionary = ClassModData.EVOLUTIONS[eid]
					return {"id": eid, "name": ev.get("name", eid), "requires": ev.get("requires", []),
							"description": ev.get("desc", "")})})
	var pool: Array = []
	for e: Dictionary in UpgradeManager.upgrade_pool:
		pool.append({"id": e["id"], "name": e.get("name", ""), "description": e.get("description", ""),
				"role": e.get("role", "power"), "max_rank": int(e.get("max_rank", 1)),
				"requires_cap": e.get("requires_cap", ""), "type": e.get("type", "stat")})
	var evos: Array = []
	for e: Dictionary in UpgradeManager.EVOLUTION_RECIPES:
		evos.append({"id": e["id"], "name": e.get("name", ""), "description": e.get("description", ""),
				"requires": e["requires"]})
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		printerr("[catalog] cannot write " + out_path)
		get_tree().quit(2)
		return
	f.store_string(JSON.stringify({"characters": chars, "pool": pool, "evolutions": evos,
			"mod_slots": ProgressionManager.class_mod_slots()}, "  "))
	f.close()
	get_tree().quit(0)
