## Reusable character catalog card (native controls only; no external art).
extends Button

signal card_activated(character_id: StringName)

const MIN_HEIGHT: float = 72.0

var _definition: CharacterDefinition = null
var _selected: bool = false
var _signals_bound: bool = false

@onready var _name_label: Label = %NameLabel
@onready var _species_label: Label = %SpeciesLabel
@onready var _tags_label: Label = %TagsLabel
@onready var _seed_badge: Label = %SeedBadge
@onready var _glyph_label: Label = %GlyphLabel
@onready var _selected_marker: Label = %SelectedMarker


func _ready() -> void:
	custom_minimum_size = Vector2(custom_minimum_size.x, maxf(custom_minimum_size.y, MIN_HEIGHT))
	_bind_signals()
	_apply_selected_visual()
	if _definition != null:
		_apply_content()


func _bind_signals() -> void:
	if _signals_bound:
		return
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_signals_bound = true


func configure(definition: CharacterDefinition) -> void:
	_definition = definition
	if is_inside_tree() and _name_label != null:
		_apply_content()
	elif is_node_ready():
		_apply_content()


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_selected_visual()


func is_selected() -> bool:
	return _selected


func get_character_id() -> StringName:
	if _definition == null:
		return &""
	return _definition.get_id()


func get_definition() -> CharacterDefinition:
	return _definition


func get_name_text() -> String:
	if _name_label == null:
		return "" if _definition == null else _definition.get_display_name()
	return _name_label.text


func get_species_text() -> String:
	if _species_label == null:
		return "" if _definition == null else _definition.get_species()
	return _species_label.text


func get_tags_text() -> String:
	if _tags_label == null:
		return ""
	return _tags_label.text


func get_glyph_text() -> String:
	if _glyph_label == null:
		return "" if _definition == null else _definition.get_placeholder_glyph()
	return _glyph_label.text


func get_seed_badge_visible() -> bool:
	if _seed_badge == null:
		return _definition != null and _definition.is_development_seed()
	return _seed_badge.visible


func _apply_content() -> void:
	if _definition == null:
		return
	if _name_label != null:
		_name_label.text = _definition.get_display_name()
	if _species_label != null:
		_species_label.text = _definition.get_species()
	if _tags_label != null:
		var tags: Array[String] = _definition.get_tags()
		var shown: PackedStringArray = PackedStringArray()
		var limit: int = mini(2, tags.size())
		for i in limit:
			shown.append(tags[i])
		_tags_label.text = " · ".join(shown)
	if _seed_badge != null:
		_seed_badge.visible = _definition.is_development_seed()
		_seed_badge.text = "開發樣本"
	if _glyph_label != null:
		_glyph_label.text = _definition.get_placeholder_glyph()
	tooltip_text = _definition.get_summary()
	_apply_selected_visual()


func _apply_selected_visual() -> void:
	# Selection must not rely on color alone: marker text + thicker border style.
	if _selected_marker != null:
		_selected_marker.visible = _selected
		_selected_marker.text = "已選" if _selected else ""
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 1.0)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	if _selected:
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = Color(0.95, 0.85, 0.35, 1.0)
		style.bg_color = Color(0.16, 0.18, 0.24, 1.0)
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
