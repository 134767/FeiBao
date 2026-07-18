## Minimal boot splash → initialize PlayerData → replace to Login (no history).
extends Control

signal boot_completed

var _advanced: bool = false
var _last_init_result: Dictionary = {}


func _ready() -> void:
	AppState.set_phase(AppState.Phase.BOOT)
	# One deferred frame so the shell can paint; no multi-second timers.
	call_deferred("advance_to_login")


## Public entry for runtime and tests (idempotent).
func advance_to_login() -> void:
	if _advanced:
		return
	_advanced = true

	# Load / recover local profile once before Login. Missing/corrupt never blocks Login.
	# Never auto-navigate to Lobby based on saved name.
	_last_init_result = PlayerData.initialize()

	var ok: bool = NavigationState.replace_with(NavigationState.SCREEN_LOGIN)
	if not ok:
		push_error("BootScreen: failed to replace_with login")
		return
	boot_completed.emit()


func get_last_init_result() -> Dictionary:
	return _last_init_result.duplicate()


func get_last_init_state() -> String:
	return str(_last_init_result.get("state", ""))


func has_advanced() -> bool:
	return _advanced
