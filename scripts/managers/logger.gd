extends Node

## Logger — Error tracking and crash log management.
## Captures script errors, tracks unclean shutdowns, and writes user://crash.log.
## Keeps log capped at ~200KB with automatic rotation.

const LOG_PATH := "user://crash.log"
const MARKER_PATH := "user://session_open"
const MAX_LOG_SIZE := 200 * 1024  # 200 KB

var _log_buffer: String = ""
var _session_open_marker_written: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Check for unclean shutdown from previous session
	if FileAccess.file_exists(MARKER_PATH):
		_log_entry("WARN", "Previous session ended uncleanly")
		var dir := DirAccess.open(MARKER_PATH.get_base_dir())
		if dir:
			dir.remove(MARKER_PATH.get_file())

	# Write current session marker
	_write_session_marker()

	# Log startup
	var version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	var scene: String = "unknown"
	if get_tree() and get_tree().current_scene:
		scene = get_tree().current_scene.name
	_log_entry("INFO", "Session started v%s (scene: %s)" % [version, scene])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_clear_session_marker()

func _log_entry(level: String, message: String) -> void:
	var timestamp: String = "%.1f" % (Time.get_ticks_msec() / 1000.0)
	var version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	var scene: String = "unknown"
	if get_tree() and get_tree().current_scene:
		scene = get_tree().current_scene.name
	var character: String = "none"
	if is_instance_valid(ProgressionManager):
		character = ProgressionManager.selected_character

	var entry: String = "[%s] [%s] v%s | scene=%s char=%s | %s\n" % [
		timestamp, level, version, scene, character, message
	]

	_log_buffer += entry
	_flush_if_needed()

func _flush_if_needed() -> void:
	if _log_buffer.is_empty():
		return

	# Read existing log
	var existing: String = ""
	if FileAccess.file_exists(LOG_PATH):
		var file := FileAccess.open(LOG_PATH, FileAccess.READ)
		if file:
			existing = file.get_as_text()

	var combined: String = existing + _log_buffer

	# Truncate if too large
	if combined.length() > MAX_LOG_SIZE:
		# Keep the last 150KB of the log
		var keep_size := 150 * 1024
		if combined.length() > keep_size:
			combined = combined.substr(combined.length() - keep_size)
		combined = "[... log rotated ...]\n" + combined

	# Write back
	var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(combined)
		_log_buffer = ""

func _write_session_marker() -> void:
	if _session_open_marker_written:
		return
	var file := FileAccess.open(MARKER_PATH, FileAccess.WRITE)
	if file:
		file.store_string(str(Time.get_ticks_msec()))
		_session_open_marker_written = true

func _clear_session_marker() -> void:
	if not FileAccess.file_exists(MARKER_PATH):
		return
	var dir := DirAccess.open(MARKER_PATH.get_base_dir())
	if dir:
		if dir.remove(MARKER_PATH.get_file()) != OK:
			push_warning("Failed to clear session marker")

# Public API for explicit error logging
func log_error(message: String, error_context: String = "") -> void:
	_log_entry("ERROR", "%s %s" % [message, error_context])

func log_warn(message: String) -> void:
	_log_entry("WARN", message)

func log_info(message: String) -> void:
	_log_entry("INFO", message)

# Hook into risky lifecycle points
func log_save_attempt() -> void:
	_log_entry("DEBUG", "Attempting save...")

func log_save_success() -> void:
	_log_entry("DEBUG", "Save successful")

func log_save_failed(error: String) -> void:
	_log_entry("ERROR", "Save failed: %s" % error)

func log_load_attempt() -> void:
	_log_entry("DEBUG", "Attempting load...")

func log_load_success() -> void:
	_log_entry("DEBUG", "Load successful")

func log_load_failed(error: String) -> void:
	_log_entry("ERROR", "Load failed: %s" % error)

func log_run_started(level: int, character: String) -> void:
	_log_entry("INFO", "Run started: level=%d character=%s" % [level, character])

func log_run_ended(reason: String) -> void:
	_log_entry("INFO", "Run ended: %s" % reason)
