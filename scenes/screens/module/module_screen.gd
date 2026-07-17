## Shared module frame for all six Lobby entries. No gameplay content.
extends Control

signal back_requested

const PLACEHOLDER_BODY: String = "此模組內容將於後續版本開放"

@onready var _title_label: Label = %TitleLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _body_label: Label = %BodyLabel
@onready var _back_button: Button = %BackButton

var _module_id: StringName = &""
var _signals_bound: bool = false


func _ready() -> void:
	_bind_signals()
	# Default from navigation; GameShell may also call configure_for_screen.
	configure_for_screen(NavigationState.get_current_screen())


func _bind_signals() -> void:
	if _signals_bound:
		return
	if not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	_signals_bound = true


func configure_for_screen(screen_id: StringName) -> void:
	_module_id = screen_id
	AppState.set_phase(AppState.Phase.MODULE)
	AppState.set_active_module(screen_id)

	var title: String = ScreenRegistry.get_title(screen_id)
	var description: String = ScreenRegistry.get_description(screen_id)
	if title.is_empty():
		title = str(screen_id)
	if description.is_empty():
		description = "模組入口"

	_title_label.text = title
	_description_label.text = description
	_body_label.text = PLACEHOLDER_BODY
	_back_button.text = "返回"


func _on_back_pressed() -> void:
	back_requested.emit()
	request_return_to_lobby()


## Back button / programmatic return: history first, then lobby fallback.
func request_return_to_lobby() -> bool:
	var ok: bool = NavigationState.go_back_or_lobby()
	if not ok:
		push_error("ModuleScreen: failed to return from module '%s'" % str(_module_id))
	return ok


func get_module_id() -> StringName:
	return _module_id


func get_title_text() -> String:
	return _title_label.text


func get_description_text() -> String:
	return _description_label.text


func get_body_text() -> String:
	return _body_label.text


func get_back_button() -> Button:
	return _back_button
