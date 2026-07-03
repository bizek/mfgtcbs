extends SceneTree

## Headless smoke test: load blocks through LdtkLoader exactly like the game does.
## Run after compiling blocks (catches registration/path/parse errors the PNG
## preview cannot):
##
##   E:\Godot\Godot_v4.6.1-stable_win64.exe --headless --path . \
##       --script res://tools/test_block_load.gd [-- BlockA BlockB ...]
##
## With no block arguments, tests every level registered in the Caves project.

const LDTK_PATH: String = "res://assets/Maps/Levels/Level 1 - Caves.ldtk"

func _init() -> void:
	var loader_script: GDScript = load("res://scripts/systems/ldtk_loader.gd")

	var blocks: Array[String] = []
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for a in args:
		blocks.append(a)
	if blocks.is_empty():
		var f := FileAccess.open(LDTK_PATH, FileAccess.READ)
		var project: Dictionary = JSON.parse_string(f.get_as_text())
		for lv: Dictionary in project["levels"]:
			blocks.append(lv["identifier"])

	var all_ok: bool = true
	for block_id in blocks:
		var loader: Node2D = loader_script.new()
		get_root().add_child(loader)
		var result: Dictionary = loader.load_level(LDTK_PATH, block_id)
		var ok: bool = result.get("ok", false)
		print("[TEST] %-30s ok=%s errors=%s" % [block_id, ok, str(result.get("errors", []))])
		if not ok:
			all_ok = false
		loader.queue_free()
	print("[TEST] ALL_OK=%s" % all_ok)
	quit(0 if all_ok else 1)
