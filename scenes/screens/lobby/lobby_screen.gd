## Lobby shell with registry-driven module navigation.
extends Control

signal module_requested(screen_id: StringName)
signal module_navigation_failed(screen_id: StringName)
## Compatibility alias.
signal module_selected(module_id: StringName)

const NAV_FAIL_MSG: String = "暫時無法開啟此功能"

@onready var _greeting_label: Label = %GreetingLabel
@onready var _status_label: Label = %StatusLabel
@onready var _grid: GridContainer = %ModuleGrid

var _buttons: Dictionary = {}
var _signals_bound: bool = false
var _navigate_override: Callable = Callable()


func _ready() -> void:
	AppState.set_phase(AppState.Phase.LOBBY)
	_refresh_greeting()
	_status_label.text = ""
	_configure_grid_columns()
	_build_module_buttons()
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)


func _exit_tree() -> void:
	var vp: Viewport = get_viewport()
	if vp != null and vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.disconnect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	_configure_grid_columns()


func _configure_grid_columns() -> void:
	if _grid == null or not is_instance_valid(_grid):
		return
	if not is_inside_tree():
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	_grid.columns = 2


func _refresh_greeting() -> void:
	var name_text: String = AppState.get_player_name()
	if name_text.is_empty():
		name_text = "玩家"
	_greeting_label.text = "歡迎，%s" % name_text


func _build_module_buttons() -> void:
	if _signals_bound:
		return
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_buttons.clear()

	for module_id in ScreenRegistry.get_module_ids():
		var button := Button.new()
		button.name = "Feature_%s" % str(module_id)
		button.text = ScreenRegistry.get_display_title(module_id)
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_module_pressed.bind(module_id))
		_grid.add_child(button)
		_buttons[module_id] = button
	_signals_bound = true


func set_navigate_override(callback: Callable) -> void:
	_navigate_override = callback


func clear_navigate_override() -> void:
	_navigate_override = Callable()


func _navigate_to_module(module_id: StringName) -> bool:
	if _navigate_override.is_valid():
		return bool(_navigate_override.call(module_id))
	return NavigationState.navigate_to(module_id, true)


func _on_module_pressed(module_id: StringName) -> void:
	module_requested.emit(module_id)
	module_selected.emit(module_id)
	var ok: bool = _navigate_to_module(module_id)
	if ok:
		_status_label.text = ""
	else:
		_status_label.text = NAV_FAIL_MSG
		module_navigation_failed.emit(module_id)
		push_error("LobbyScreen: navigate_to module failed: %s" % str(module_id))


func get_greeting_text() -> String:
	return _greeting_label.text


func get_status_text() -> String:
	return _status_label.text


func get_module_ids() -> Array[StringName]:
	return ScreenRegistry.get_module_ids()


func get_placeholder_ids() -> Array[StringName]:
	return get_module_ids()


func get_module_button(screen_id: StringName) -> Button:
	if _buttons.has(screen_id):
		return _buttons[screen_id] as Button
	return null


func get_placeholder_button(feature_id: StringName) -> Button:
	return get_module_button(feature_id)


func contains_text(needle: String) -> bool:
	return _tree_contains_text(self, needle)


func _tree_contains_text(node: Node, needle: String) -> bool:
	if node is Label and needle in (node as Label).text:
		return true
	if node is Button and needle in (node as Button).text:
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false


func has_lower_left_avatar() -> bool:
	return has_node("LowerLeftAvatar") or has_node("%LowerLeftAvatar")
