## Lobby shell with six module navigation entries.
extends Control

signal module_selected(module_id: StringName)

const MODULE_IDS: Array[StringName] = [
	&"adventure",
	&"character",
	&"party",
	&"inventory",
	&"farm",
	&"settings",
]

const MODULE_LABELS: Dictionary = {
	&"adventure": "冒險",
	&"character": "角色",
	&"party": "隊伍",
	&"inventory": "背包",
	&"farm": "農場",
	&"settings": "設定",
}

@onready var _greeting_label: Label = %GreetingLabel
@onready var _status_label: Label = %StatusLabel
@onready var _grid: GridContainer = %ModuleGrid

var _buttons: Dictionary = {}
var _signals_bound: bool = false


func _ready() -> void:
	AppState.set_phase(AppState.Phase.LOBBY)
	AppState.clear_active_module()
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
	# Deterministic 2-column portrait grid for all supported widths.
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

	for module_id in MODULE_IDS:
		var button := Button.new()
		button.name = "Feature_%s" % str(module_id)
		button.text = str(MODULE_LABELS.get(module_id, str(module_id)))
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_module_pressed.bind(module_id))
		_grid.add_child(button)
		_buttons[module_id] = button
	_signals_bound = true


func _on_module_pressed(module_id: StringName) -> void:
	_status_label.text = ""
	module_selected.emit(module_id)
	var ok: bool = NavigationState.navigate_to(module_id, true)
	if not ok:
		_status_label.text = "無法開啟模組，請稍後再試"
		push_error("LobbyScreen: navigate_to module failed: %s" % str(module_id))


func get_greeting_text() -> String:
	return _greeting_label.text


func get_status_text() -> String:
	return _status_label.text


func get_module_ids() -> Array[StringName]:
	return MODULE_IDS.duplicate()


## Backward-compatible alias used by existing tests.
func get_placeholder_ids() -> Array[StringName]:
	return get_module_ids()


func get_module_button(module_id: StringName) -> Button:
	if _buttons.has(module_id):
		return _buttons[module_id] as Button
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
