class_name SimMode
extends RefCounted

## SimMode — is this process a headless balance-sim worker (tools/sim/)?
##
## The sim drives the real game in batch: it swaps characters, equips mods and applies level-up
## picks hundreds of times per sweep. Several of those paths persist by design
## (ProgressionManager.set_character_mod → save_data, Settings setters → save_settings), and a
## worker runs against the SAME user:// directory as the player — Godot 4.6 has no command-line
## switch to point it elsewhere. Without this gate a sweep would overwrite Ben's real save with
## whatever loadout the last scenario happened to leave behind.
##
## Read from the command line rather than set by the runner, because the autoloads that save
## finish their _ready() before any --script code runs; a flag the runner sets would arrive too
## late to guard a save made during boot.
##
##   godot --headless --script res://tools/sim/sim_runner.gd -- --sim --job=<path>

const FLAG: String = "--sim"

static var _cached: int = -1   ## -1 unknown, 0 no, 1 yes


static func active() -> bool:
	if _cached < 0:
		_cached = 1 if OS.get_cmdline_user_args().has(FLAG) else 0
	return _cached == 1
