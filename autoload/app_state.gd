## Minimal application phase + in-memory player name. No disk save.
extends Node

enum Phase {
	BOOTSTRAP,
	BOOT,
	LOGIN,
	LOBBY,
	MODULE,
}

var _phase: Phase = Phase.BOOTSTRAP
var _player_name: String = ""
var _active_module_id: StringName = &""


func _ready() -> void:
	_phase = Phase.BOOTSTRAP
	_player_name = ""
	_active_module_id = &""


func get_phase() -> Phase:
	return _phase


func set_phase(phase: Phase) -> void:
	_phase = phase


func set_player_name(value: String) -> void:
	_player_name = value.strip_edges()


func get_player_name() -> String:
	return _player_name


func has_player_name() -> bool:
	return not _player_name.is_empty()


func clear_player_name() -> void:
	_player_name = ""


func set_active_module(module_id: StringName) -> void:
	_active_module_id = module_id


func get_active_module() -> StringName:
	return _active_module_id


func clear_active_module() -> void:
	_active_module_id = &""


func reset() -> void:
	_phase = Phase.BOOTSTRAP
	_player_name = ""
	_active_module_id = &""


func phase_name() -> String:
	match _phase:
		Phase.BOOTSTRAP:
			return "BOOTSTRAP"
		Phase.BOOT:
			return "BOOT"
		Phase.LOGIN:
			return "LOGIN"
		Phase.LOBBY:
			return "LOBBY"
		Phase.MODULE:
			return "MODULE"
		_:
			return "UNKNOWN"
