## Minimal application phase + in-memory player name. No disk save.
extends Node

enum Phase {
	BOOTSTRAP,
	BOOT,
	LOGIN,
	LOBBY,
}

var _phase: Phase = Phase.BOOTSTRAP
var _player_name: String = ""


func _ready() -> void:
	_phase = Phase.BOOTSTRAP
	_player_name = ""


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


func reset() -> void:
	_phase = Phase.BOOTSTRAP
	_player_name = ""


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
		_:
			return "UNKNOWN"
