## Stage selection card for AdventureScreen (native controls only).
extends Button

signal card_activated(stage_id: StringName)

const MIN_HEIGHT: float = 88.0
const TEXT_VIEWING: String = "檢視中"
const TEXT_PREPARED: String = "已準備"
const TEXT_SEED: String = "開發樣本"

var _definition: StageDefinition = null
var _viewing: bool = false
var _prepared: bool = false
var _signals_bound: bool = false

@onready var _name_label: Label = %NameLabel
@onready var _summary_label: Label = %SummaryLabel
@onready var _status_label: Label = %StatusLabel
@onready var _seed_badge: Label = %SeedBadge
@onready var _glyph_label: Label = %GlyphLabel


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


func configure(definition: StageDefinition, viewing: bool = false, prepared: bool = false) -> void:
	_definition = definition
	_viewing = viewing
	_prepared = prepared
	if is_node_ready():
		_apply_content()


func set_viewing(viewing: bool) -> void:
	_viewing = viewing
	_apply_visual()


func set_prepared(prepared: bool) -> void:
	_prepared = prepared
	_apply_visual()


func is_viewing() -> bool:
	return _viewing


func is_prepared() -> bool:
	return _prepared


func get_stage_id() -> StringName:
	if _definition == null:
		return &""
	return _definition.get_id()


func get_definition() -> StageDefinition:
	return _definition


func _apply_content() -> void:
	if _definition == null:
		return
	if _name_label != null:
		_name_label.text = _definition.get_display_name()
	if _summary_label != null:
		_summary_label.text = _definition.get_summary()
	if _seed_badge != null:
		_seed_badge.visible = _definition.is_development_seed()
		_seed_badge.text = TEXT_SEED
	if _glyph_label != null:
		_glyph_label.text = _definition.get_placeholder_glyph()
	tooltip_text = _definition.get_summary()
	_apply_visual()


func _apply_visual() -> void:
	if _status_label != null:
		var parts: PackedStringArray = PackedStringArray()
		if _viewing:
			parts.append(TEXT_VIEWING)
		if _prepared:
			parts.append(TEXT_PREPARED)
		_status_label.visible = not parts.is_empty()
		_status_label.text = " · ".join(parts)

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.bg_color = Color(0.12, 0.14, 0.18, 1.0)
	if _viewing:
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = Color(0.95, 0.85, 0.35, 1.0)
		style.bg_color = Color(0.16, 0.18, 0.24, 1.0)
	elif _prepared:
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
