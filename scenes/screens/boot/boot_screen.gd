## Minimal boot splash → replace to Login (no history entry for boot).
extends Control

signal boot_completed

var _advanced: bool = false


func _ready() -> void:
	AppState.set_phase(AppState.Phase.BOOT)
	# One deferred frame so the shell can paint; no multi-second timers.
	call_deferred("advance_to_login")


## Public entry for runtime and tests (idempotent).
func advance_to_login() -> void:
	if _advanced:
		return
	_advanced = true
	var ok: bool = NavigationState.replace_with(NavigationState.SCREEN_LOGIN)
	if not ok:
		push_error("BootScreen: failed to replace_with login")
		return
	boot_completed.emit()
