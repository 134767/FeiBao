## Shared module frame for all six Lobby entries. No gameplay content.
extends Control

signal back_requested
signal module_activated(screen_id: StringName)

const STATUS_PLACEHOLDER: String = "此功能將於後續版本開放"

@onready var _title_label: Label = %TitleLabel
@onready var _status_label: Label = %BodyLabel
@onready var _back_button: Button = %BackButton

var _screen_id: StringName = &""
var _configured: bool = false
var _ready_done: bool = false
var _signals_bound: bool = false
var _activated_emitted: bool = false


func _ready() -> void:
	_ready_done = true
	_bind_signals()
	AppState.set_phase(AppState.Phase.MODULE)
	if _configured:
		_apply_ui()
		_emit_activated_once()
	elif ScreenRegistry.is_module(NavigationState.get_current_screen()):
		configure_screen(NavigationState.get_current_screen())


func _bind_signals() -> void:
	if _signals_bound:
		return
	if _back_button != null and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	_signals_bound = true


## Accepts only Registry module IDs. Safe before or after enter tree.
func configure_screen(screen_id: StringName) -> bool:
	if not ScreenRegistry.is_module(screen_id):
		push_error("ModuleScreen.configure_screen: not a module id '%s'" % str(screen_id))
		return false

	_screen_id = screen_id
	_configured = true
	_activated_emitted = false
	AppState.set_phase(AppState.Phase.MODULE)

	if _ready_done:
		_bind_signals()
		_apply_ui()
		_emit_activated_once()
	return true


func _apply_ui() -> void:
	if _title_label == null or _status_label == null or _back_button == null:
		return
	_title_label.text = ScreenRegistry.get_display_title(_screen_id)
	_status_label.text = STATUS_PLACEHOLDER
	_back_button.text = "返回"


func _emit_activated_once() -> void:
	if _activated_emitted:
		return
	if not _configured:
		return
	_activated_emitted = true
	module_activated.emit(_screen_id)


func _on_back_pressed() -> void:
	request_back()


func request_back() -> bool:
	var ok: bool = NavigationState.go_back_or_fallback()
	if ok:
		back_requested.emit()
	else:
		push_error("ModuleScreen: back failed for '%s'" % str(_screen_id))
	return ok


func get_screen_id() -> StringName:
	return _screen_id


## Compatibility with intermediate tests.
func get_module_id() -> StringName:
	return _screen_id


func get_title_text() -> String:
	if _title_label == null:
		return ScreenRegistry.get_display_title(_screen_id)
	return _title_label.text


func get_status_text() -> String:
	if _status_label == null:
		return STATUS_PLACEHOLDER if _configured else ""
	return _status_label.text


func get_body_text() -> String:
	return get_status_text()


func get_back_button() -> Button:
	return _back_button


## Compatibility alias.
func configure_for_screen(screen_id: StringName) -> void:
	configure_screen(screen_id)


func request_return_to_lobby() -> bool:
	return request_back()
