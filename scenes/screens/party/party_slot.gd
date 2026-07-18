## Active party slot (native controls only). Index 0 is leader.
extends Button

signal slot_activated(character_id: StringName, slot_index: int)

const MIN_HEIGHT: float = 72.0

var _slot_index: int = 0
var _character_id: StringName = &""
var _definition: CharacterDefinition = null
var _empty: bool = true
var _focused: bool = false
var _signals_bound: bool = false

@onready var _index_label: Label = %IndexLabel
@onready var _name_label: Label = %NameLabel
@onready var _status_label: Label = %StatusLabel
@onready var _glyph_label: Label = %GlyphLabel


func _ready() -> void:
	custom_minimum_size = Vector2(custom_minimum_size.x, maxf(custom_minimum_size.y, MIN_HEIGHT))
	_bind_signals()
	_apply_visual()


func _bind_signals() -> void:
	if _signals_bound:
		return
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_signals_bound = true


func configure(
	slot_index: int,
	definition: CharacterDefinition,
	character_id: StringName,
	focused: bool = false
) -> void:
	_slot_index = slot_index
	_definition = definition
	_character_id = character_id
	_empty = false
	_focused = focused
	if is_node_ready():
		_apply_content()
	else:
		call_deferred("_apply_content")


func configure_empty(slot_index: int) -> void:
	_slot_index = slot_index
	_definition = null
	_character_id = &""
	_empty = true
	_focused = false
	if is_node_ready():
		_apply_content()
	else:
		call_deferred("_apply_content")


func set_focused(focused: bool) -> void:
	_focused = focused
	_apply_visual()


func get_character_id() -> StringName:
	return _character_id


func get_slot_index() -> int:
	return _slot_index


func is_empty() -> bool:
	return _empty


func is_leader() -> bool:
	return not _empty and _slot_index == 0


func get_status_text() -> String:
	if _status_label != null:
		return _status_label.text
	if _empty:
		return "空位"
	if is_leader():
		return "領隊"
	return "隊員"


func _apply_content() -> void:
	if _index_label != null:
		_index_label.text = "欄位 %d" % (_slot_index + 1)
	if _empty:
		if _name_label != null:
			_name_label.text = "空位"
		if _status_label != null:
			_status_label.text = "空位"
		if _glyph_label != null:
			_glyph_label.text = "·"
		tooltip_text = "空位 %d" % (_slot_index + 1)
	else:
		var display_name: String = ""
		if _definition != null:
			display_name = _definition.get_display_name()
			if _glyph_label != null:
				_glyph_label.text = _definition.get_placeholder_glyph()
		else:
			display_name = "未知角色（%s）" % str(_character_id)
			if _glyph_label != null:
				_glyph_label.text = "?"
		if _name_label != null:
			_name_label.text = display_name
		if _status_label != null:
			_status_label.text = "領隊" if is_leader() else "隊員"
		tooltip_text = display_name
	_apply_visual()


func _apply_visual() -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	if _empty:
		style.bg_color = Color(0.10, 0.10, 0.12, 1.0)
		style.border_color = Color(0.28, 0.28, 0.32, 1.0)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
	elif _focused:
		style.bg_color = Color(0.16, 0.18, 0.24, 1.0)
		style.border_color = Color(0.95, 0.85, 0.35, 1.0)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
	elif is_leader():
		style.bg_color = Color(0.14, 0.16, 0.22, 1.0)
		style.border_color = Color(0.45, 0.75, 0.95, 1.0)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	else:
		style.bg_color = Color(0.12, 0.14, 0.18, 1.0)
		style.border_color = Color(0.35, 0.38, 0.45, 1.0)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)
	add_theme_stylebox_override("disabled", style)


func _on_pressed() -> void:
	if _empty:
		return
	slot_activated.emit(_character_id, _slot_index)
