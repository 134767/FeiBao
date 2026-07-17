## Lobby shell with six non-functional module placeholders.
extends Control

signal placeholder_selected(feature_id: StringName)

const PLACEHOLDER_IDS: Array[StringName] = [
	&"adventure",
	&"character",
	&"party",
	&"inventory",
	&"farm",
	&"settings",
]

const PLACEHOLDER_LABELS: Dictionary = {
	&"adventure": "冒險",
	&"character": "角色",
	&"party": "隊伍",
	&"inventory": "背包",
	&"farm": "農場",
	&"settings": "設定",
}

const STATUS_PLACEHOLDER: String = "此功能將於後續版本開放"

@onready var _greeting_label: Label = %GreetingLabel
@onready var _status_label: Label = %StatusLabel
@onready var _grid: GridContainer = %ModuleGrid

var _buttons: Dictionary = {}
var _signals_bound: bool = false


func _ready() -> void:
	AppState.set_phase(AppState.Phase.LOBBY)
	_refresh_greeting()
	_status_label.text = ""
	_configure_grid_columns()
	_build_placeholders()
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
	# Narrow portrait: 2 columns. Design width 720 may use 2 or 3 — fixed 2 for determinism.
	var width: float = vp.get_visible_rect().size.x
	if width >= 700.0:
		_grid.columns = 2
	else:
		_grid.columns = 2


func _refresh_greeting() -> void:
	var name_text: String = AppState.get_player_name()
	if name_text.is_empty():
		name_text = "玩家"
	_greeting_label.text = "歡迎，%s" % name_text


func _build_placeholders() -> void:
	if _signals_bound:
		return
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_buttons.clear()

	for feature_id in PLACEHOLDER_IDS:
		var button := Button.new()
		button.name = "Feature_%s" % str(feature_id)
		button.text = str(PLACEHOLDER_LABELS.get(feature_id, str(feature_id)))
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_placeholder_pressed.bind(feature_id))
		_grid.add_child(button)
		_buttons[feature_id] = button
	_signals_bound = true


func _on_placeholder_pressed(feature_id: StringName) -> void:
	_status_label.text = STATUS_PLACEHOLDER
	placeholder_selected.emit(feature_id)
	# Do not navigate — modules do not exist yet.


func get_greeting_text() -> String:
	return _greeting_label.text


func get_status_text() -> String:
	return _status_label.text


func get_placeholder_ids() -> Array[StringName]:
	return PLACEHOLDER_IDS.duplicate()


func get_placeholder_button(feature_id: StringName) -> Button:
	if _buttons.has(feature_id):
		return _buttons[feature_id] as Button
	return null


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
	# Explicitly no avatar control in this foundation.
	return has_node("LowerLeftAvatar") or has_node("%LowerLeftAvatar")
