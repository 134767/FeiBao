## Minimal application phase state. No player save data.
extends Node

enum Phase {
	BOOTSTRAP,
	FOUNDATION,
}

var _phase: Phase = Phase.BOOTSTRAP


func _ready() -> void:
	_phase = Phase.BOOTSTRAP


func get_phase() -> Phase:
	return _phase


func set_phase(phase: Phase) -> void:
	_phase = phase


func reset() -> void:
	_phase = Phase.BOOTSTRAP


func phase_name() -> String:
	match _phase:
		Phase.BOOTSTRAP:
			return "BOOTSTRAP"
		Phase.FOUNDATION:
			return "FOUNDATION"
		_:
			return "UNKNOWN"
