## Owned-character roster card for party formation (native controls only).
extends Button

signal card_activated(character_id: StringName)

const MIN_HEIGHT: float = 72.0
const TEXT_IN_PARTY: String = "隊伍中"
const TEXT_JOINABLE: String = "可加入"
const TEXT_REPRESENTATIVE: String = "代表"
const TEXT_FOCUSED: String = "檢視中"

var _definition: CharacterDefinition = null
var _in_party: bool = false
var _representative: bool = false
var _focused: bool = false
var _signals_bound: bool = false

@onready var _name_label: Label = %NameLabel
@onready var _party_state_label: Label = %PartyStateLabel
@onready var _status_label: Label = %StatusLabel
@onready var _glyph_label: Label = %GlyphLabel
@onready var _seed_badge: Label = %SeedBadge


func _ready() -> void:
	custom_minimum_size = Vector2(custom_minimum_size.x, maxf(custom_minimum_size.y, MIN_HEIGHT))
	_bind_signals()
	_apply_visual()
	if _definition != null:
		_apply_content()


func _bind_signals() -> void:
	if _signals_bound:
		return
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_signals_bound = true


func configure(
	definition: CharacterDefinition,
	in_party: bool = false,
	representative: bool = false
) -> void:
	_definition = definition
	_in_party = in_party
	_representative = representative
	if is_node_ready() and _name_label != null:
		_apply_content()
	elif is_node_ready():
		_apply_content()


func set_focused(focused: bool) -> void:
	_focused = focused
	_apply_visual()


func get_character_id() -> StringName:
	if _definition == null:
		return &""
	return _definition.get_id()


func is_in_party() -> bool:
	return _in_party


func is_representative() -> bool:
	return _representative


func is_focused() -> bool:
	return _focused


func get_party_state_text() -> String:
	return TEXT_IN_PARTY if _in_party else TEXT_JOINABLE


func _apply_content() -> void:
	if _definition == null:
		return
	if _name_label != null:
		_name_label.text = _definition.get_display_name()
	if _party_state_label != null:
		_party_state_label.text = get_party_state_text()
	if _seed_badge != null:
		_seed_badge.visible = _definition.is_development_seed()
		_seed_badge.text = "開發樣本"
	if _glyph_label != null:
		_glyph_label.text = _definition.get_placeholder_glyph()
	tooltip_text = "%s · %s" % [_definition.get_display_name(), get_party_state_text()]
	_apply_visual()


func _apply_visual() -> void:
	if _status_label != null:
		var parts: PackedStringArray = PackedStringArray()
		if _representative:
			parts.append(TEXT_REPRESENTATIVE)
		if _focused:
			parts.append(TEXT_FOCUSED)
		_status_label.visible = not parts.is_empty()
		_status_label.text = " · ".join(parts)
	if _party_state_label != null:
		_party_state_label.text = get_party_state_text()

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.bg_color = Color(0.12, 0.14, 0.18, 1.0)
	if _focused:
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = Color(0.95, 0.85, 0.35, 1.0)
		style.bg_color = Color(0.16, 0.18, 0.24, 1.0)
	elif _in_party:
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.45, 0.75, 0.95, 1.0)
	else:
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.35, 0.38, 0.45, 1.0)
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)
	add_theme_stylebox_override("disabled", style)


func _on_pressed() -> void:
	if _definition == null:
		return
	card_activated.emit(_definition.get_id())
