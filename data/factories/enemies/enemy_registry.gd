class_name EnemyRegistry
extends RefCounted
## Central registry for all enemy definitions. Built once, cached.

static var _definitions: Dictionary = {}
static var _built: bool = false


static func build_all() -> void:
	if _built:
		return
	_built = true
	_definitions["fodder"] = FodderData.create()
	_definitions["swarmer"] = SwarmerData.create()
	_definitions["brute"] = BruteData.create()
	_definitions["carrier"] = CarrierData.create()
	_definitions["stalker"] = StalkerData.create()
	_definitions["caster"] = CasterData.create()
	_definitions["guardian"] = GuardianData.create()
	_definitions["herald"] = HeraldData.create()
	## Phase 5 Phase-Warped variants
	_definitions["warped_fodder"] = WarpedEnemyData.create_warped_fodder()
	_definitions["warped_swarmer"] = WarpedEnemyData.create_warped_swarmer()
	_definitions["warped_brute"] = WarpedEnemyData.create_warped_brute()
	_definitions["warped_caster"] = WarpedEnemyData.create_warped_caster()


static func get_def(enemy_id: String) -> EnemyDefinition:
	build_all()
	return _definitions.get(enemy_id)


static func get_all() -> Dictionary:
	build_all()
	return _definitions
