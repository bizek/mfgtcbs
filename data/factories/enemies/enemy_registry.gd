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


static func get_def(enemy_id: String) -> EnemyDefinition:
	build_all()
	return _definitions.get(enemy_id)


static func get_all() -> Dictionary:
	build_all()
	return _definitions
