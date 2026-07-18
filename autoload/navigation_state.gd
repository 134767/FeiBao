## In-app screen navigation (history stack). Distinct from SceneRouter.
extends Node

const SCREEN_BOOT: StringName = &"boot"
const SCREEN_LOGIN: StringName = &"login"
const SCREEN_LOBBY: StringName = &"lobby"
const SCREEN_ADVENTURE: StringName = &"adventure"
const SCREEN_BATTLE: StringName = &"battle"
const SCREEN_CHARACTER: StringName = &"character"
const SCREEN_PARTY: StringName = &"party"
const SCREEN_INVENTORY: StringName = &"inventory"
const SCREEN_FARM: StringName = &"farm"
const SCREEN_SETTINGS: StringName = &"settings"

signal screen_changed(current: StringName, previous: StringName)

var _current: StringName = SCREEN_BOOT
var _history: Array[StringName] = []


func _ready() -> void:
	reset(SCREEN_BOOT)


func reset(initial_screen: StringName = SCREEN_BOOT) -> void:
	var target: StringName = initial_screen
	if String(target).is_empty() or not ScreenRegistry.has_screen(target):
		push_error("NavigationState.reset: invalid initial screen '%s' — using boot" % str(initial_screen))
		target = SCREEN_BOOT

	var previous: StringName = _current
	_history.clear()
	_current = target
	if previous != _current:
		screen_changed.emit(_current, previous)


func navigate_to(screen_id: StringName, add_to_history: bool = true) -> bool:
	if String(screen_id).is_empty():
		push_error("NavigationState.navigate_to: empty screen id")
		return false
	if not ScreenRegistry.has_screen(screen_id):
		push_error("NavigationState.navigate_to: unregistered screen id '%s'" % str(screen_id))
		return false
	if screen_id == _current:
		return true

	var previous: StringName = _current
	if add_to_history and not String(_current).is_empty():
		_history.append(_current)
	_current = screen_id
	screen_changed.emit(_current, previous)
	return true


func replace_with(screen_id: StringName) -> bool:
	if String(screen_id).is_empty():
		push_error("NavigationState.replace_with: empty screen id")
		return false
	if not ScreenRegistry.has_screen(screen_id):
		push_error("NavigationState.replace_with: unregistered screen id '%s'" % str(screen_id))
		return false
	if screen_id == _current:
		return true

	var previous: StringName = _current
	_current = screen_id
	screen_changed.emit(_current, previous)
	return true


func go_back() -> bool:
	if _history.is_empty():
		return false
	var previous: StringName = _current
	_current = _history.pop_back()
	screen_changed.emit(_current, previous)
	return true


## History first; else ScreenRegistry back_fallback via replace_with (no history push).
func go_back_or_fallback() -> bool:
	if not _history.is_empty():
		return go_back()

	var fallback: StringName = ScreenRegistry.get_back_fallback(_current)
	if String(fallback).is_empty():
		return false
	if not ScreenRegistry.has_screen(fallback):
		push_error("NavigationState.go_back_or_fallback: invalid fallback '%s'" % str(fallback))
		return false
	if fallback == _current:
		return false
	return replace_with(fallback)


## Compatibility alias for intermediate call sites.
func go_back_or_lobby() -> bool:
	return go_back_or_fallback()


func get_current_screen() -> StringName:
	return _current


func get_previous_screen() -> StringName:
	if _history.is_empty():
		return &""
	return _history[_history.size() - 1]


func can_go_back() -> bool:
	return not _history.is_empty()


func get_history_size() -> int:
	return _history.size()
