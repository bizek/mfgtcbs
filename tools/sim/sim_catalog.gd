extends SceneTree

## Dumps the content catalog the Python stages need — characters, kits, the level-up pool, each
## kit's ability upgrades (with ranks and prerequisites), evolution recipes and class-mod rosters —
## straight from the live data classes, so the stages never hard-code a list that can drift.
##
##   godot --headless --path . --script res://tools/sim/sim_catalog.gd -- --sim --out=<json>
##
## Thin loader for the same reason as sim_runner.gd: autoloads do not exist yet when a --script
## SceneTree compiles, so the body lives in sim_catalog_impl.gd.

func _initialize() -> void:
	var impl: GDScript = load("res://tools/sim/sim_catalog_impl.gd")
	var n: Node = impl.new()
	root.add_child.call_deferred(n)
