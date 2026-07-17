## Loads and validates res://data/game_config.json with safe defaults.
extends Node

const CONFIG_PATH: String = "res://data/game_config.json"

const DEFAULTS: Dictionary = {
	"app_name": "FeiBao",
	"app_version": "0.2.0",
	"design_width": 720,
	"design_height": 1280,
	"orientation": "portrait",
	"data_version": 1,
	"debug_mode": true,
}

var _config: Dictionary = {}
var _load_succeeded: bool = false
var _load_error: String = ""


func _ready() -> void:
	reload()


## Reload configuration from disk. Safe defaults applied on failure.
func reload() -> bool:
	_config = DEFAULTS.duplicate(true)
	_load_succeeded = false
	_load_error = ""

	if not FileAccess.file_exists(CONFIG_PATH):
		_load_error = "config file missing: %s" % CONFIG_PATH
		push_error("GameConfig: %s — using defaults" % _load_error)
		return false

	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		_load_error = "cannot open config: %s" % error_string(FileAccess.get_open_error())
		push_error("GameConfig: %s — using defaults" % _load_error)
		return false

	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_err: Error = json.parse(text)
	if parse_err != OK:
		_load_error = "JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()]
		push_error("GameConfig: %s — using defaults" % _load_error)
		return false

	var data: Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		_load_error = "config root must be a JSON object"
		push_error("GameConfig: %s — using defaults" % _load_error)
		return false

	_merge_and_validate(data as Dictionary)
	_load_succeeded = true
	return true


func _merge_and_validate(data: Dictionary) -> void:
	_config = DEFAULTS.duplicate(true)

	if data.has("app_name") and typeof(data["app_name"]) == TYPE_STRING:
		_config["app_name"] = data["app_name"]
	else:
		push_error("GameConfig: missing or invalid app_name — using default")

	if data.has("app_version") and typeof(data["app_version"]) == TYPE_STRING:
		_config["app_version"] = data["app_version"]
	else:
		push_error("GameConfig: missing or invalid app_version — using default")

	if data.has("design_width") and typeof(data["design_width"]) in [TYPE_INT, TYPE_FLOAT]:
		_config["design_width"] = int(data["design_width"])
	else:
		push_error("GameConfig: missing or invalid design_width — using default")

	if data.has("design_height") and typeof(data["design_height"]) in [TYPE_INT, TYPE_FLOAT]:
		_config["design_height"] = int(data["design_height"])
	else:
		push_error("GameConfig: missing or invalid design_height — using default")

	if data.has("orientation") and typeof(data["orientation"]) == TYPE_STRING:
		_config["orientation"] = data["orientation"]
	else:
		push_error("GameConfig: missing or invalid orientation — using default")

	if data.has("data_version") and typeof(data["data_version"]) in [TYPE_INT, TYPE_FLOAT]:
		_config["data_version"] = int(data["data_version"])
	else:
		push_error("GameConfig: missing or invalid data_version — using default")

	if data.has("debug_mode") and typeof(data["debug_mode"]) == TYPE_BOOL:
		_config["debug_mode"] = data["debug_mode"]
	else:
		push_error("GameConfig: missing or invalid debug_mode — using default")


## Read-only config lookup with optional fallback.
func get_value(key: String, fallback: Variant = null) -> Variant:
	if _config.has(key):
		return _config[key]
	if fallback != null:
		return fallback
	if DEFAULTS.has(key):
		return DEFAULTS[key]
	return null


func get_app_name() -> String:
	return str(get_value("app_name", DEFAULTS["app_name"]))


func get_app_version() -> String:
	return str(get_value("app_version", DEFAULTS["app_version"]))


func get_design_width() -> int:
	return int(get_value("design_width", DEFAULTS["design_width"]))


func get_design_height() -> int:
	return int(get_value("design_height", DEFAULTS["design_height"]))


func get_orientation() -> String:
	return str(get_value("orientation", DEFAULTS["orientation"]))


func is_debug_mode() -> bool:
	return bool(get_value("debug_mode", DEFAULTS["debug_mode"]))


func did_load_succeed() -> bool:
	return _load_succeeded


func get_load_error() -> String:
	return _load_error
