extends SceneTree

## Balance-sim worker entry point. Thin on purpose.
##
##   Godot_v4.6.1-stable_win64.exe --headless --path . --fixed-fps 60 \
##       --script res://tools/sim/sim_runner.gd -- --sim --job=<abs path> --out=<abs path>
##
## Why a loader and not the driver itself: a --script SceneTree is compiled BEFORE the engine
## registers the autoload singletons, so any bare `GameManager` / `ProgressionManager` in this
## file is an unknown identifier and the worker dies at parse. The driver is `load()`ed from
## _initialize(), after the autoloads exist, and can use them normally.
##
## `--fixed-fps 60` is what makes a worker faster than real time: it drops the real-time sync,
## so every frame advances exactly 1/60 s of game time however fast the CPU gets through it.
## (--headless already forces it; stated explicitly so the timing contract is visible.)
##
## `--sim` is load-bearing: it is what SimMode reads to stop every persistent write. The runner
## refuses to start without it rather than risk a sweep writing into the real save.

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--sim"):
		printerr("[sim] refusing to run without --sim (it gates every save write — see SimMode)")
		quit(2)
		return
	var driver_script: GDScript = load("res://tools/sim/sim_driver.gd")
	var driver: Node = driver_script.new()
	driver.name = "SimDriver"
	root.add_child.call_deferred(driver)
