## Dedicated character catalog module screen (data-driven, read-only seeds).
extends Control

signal back_requested
signal character_selected(character_id: StringName)

const CARD_SCENE_PATH: String = "res://scenes/screens/character/character_card.tscn"
const STATUS_ALL_FMT: String = "共 %d 位角色"
const STATUS_FILTER_FMT: String = "找到 %d 位角色"
const STATUS_EMPTY: String = "沒有符合的角色"
const STATUS_LOAD_FAIL: String = "角色圖鑑載入失敗"
const STATUS_LOADING: String = "載入中…"
const DETAIL_EMPTY: String = "請選擇角色"
const SEED_HINT: String = "此為開發樣本（development seed），非正式世界觀角色。"
const CARD_MIN_WIDTH: float = 150.0

@onready var _title_label: Label = %TitleLabel
@onready var _back_button: Button = %BackButton
@onready var _search_edit: LineEdit = %SearchEdit
@onready var _status_label: Label = %StatusLabel
@onready var _card_scroll: ScrollContainer = %CardScroll
@onready var _card_grid: GridContainer = %CardGrid
@onready var _detail_panel: PanelContainer = %DetailPanel
@onready var _detail_glyph: Label = %DetailGlyph
@onready var _detail_name: Label = %DetailName
@onready var _detail_species: Label = %DetailSpecies
@onready var _detail_summary: Label = %DetailSummary
@onready var _detail_description: Label = %DetailDescription
@onready var _detail_tags: Label = %DetailTags
@onready var _detail_seed_hint: Label = %DetailSeedHint
@onready var _empty_label: Label = %EmptyLabel
@onready var _error_label: Label = %ErrorLabel
@onready var _content_row: Control = %ContentRow

var _screen_id: StringName = &""
var _configured: bool = false
var _ready_done: bool = false
var _signals_bound: bool = false
var _all_characters: Array[CharacterDefinition] = []
var _visible_characters: Array[CharacterDefinition] = []
var _cards_by_id: Dictionary = {}
var _selected_id: StringName = &""
var _load_ok: bool = false
var _load_error: String = ""
var _catalog_source_path: String = CharacterCatalog.DEFAULT_PATH


func _ready() -> void:
	_ready_done = true
	_bind_signals()
	AppState.set_phase(AppState.Phase.MODULE)
	if _configured:
		_reload_catalog_and_ui()
	elif NavigationState.get_current_screen() == ScreenRegistry.SCREEN_CHARACTER:
		configure_screen(ScreenRegistry.SCREEN_CHARACTER)
	call_deferred("_refresh_columns")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_columns()


func _bind_signals() -> void:
	if _signals_bound:
		return
	if _back_button != null and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _search_edit != null and not _search_edit.text_changed.is_connected(_on_search_changed):
		_search_edit.text_changed.connect(_on_search_changed)
	_signals_bound = true


## Accepts only SCREEN_CHARACTER. Safe before or after enter tree.
func configure_screen(screen_id: StringName) -> bool:
	if screen_id != ScreenRegistry.SCREEN_CHARACTER:
		# Avoid push_error pollution for expected negative-path tests when possible;
		# still fail closed for GameShell.
		return false

	_screen_id = screen_id
	_configured = true
	AppState.set_phase(AppState.Phase.MODULE)

	if _ready_done:
		_bind_signals()
		_reload_catalog_and_ui()
	return true


func set_catalog_source_path(path: String) -> void:
	_catalog_source_path = path
	if _ready_done and _configured:
		_reload_catalog_and_ui()


func _reload_catalog_and_ui() -> void:
	if _title_label != null:
		_title_label.text = "角色圖鑑"
	if _back_button != null:
		_back_button.text = "返回"
	if _search_edit != null:
		_search_edit.placeholder_text = "搜尋角色、物種或標籤"

	_set_status(STATUS_LOADING)
	_hide_states()
	var result: Dictionary = CharacterCatalog.load_from_path(_catalog_source_path)
	_load_ok = bool(result.get("ok", false))
	_load_error = str(result.get("error", ""))
	_all_characters.clear()
	_visible_characters.clear()
	_cards_by_id.clear()
	_selected_id = &""

	if not _load_ok:
		_show_error_state(_load_error if not _load_error.is_empty() else STATUS_LOAD_FAIL)
		_clear_detail()
		_rebuild_cards()
		return

	for item in result.get("characters", []):
		if item is CharacterDefinition:
			_all_characters.append(item as CharacterDefinition)

	_apply_filter(_current_query())
	_refresh_columns()


func _current_query() -> String:
	if _search_edit == null:
		return ""
	return _search_edit.text.strip_edges()


func _on_search_changed(_new_text: String) -> void:
	_apply_filter(_current_query())


func _apply_filter(raw_query: String) -> void:
	var query: String = raw_query.strip_edges()
	_visible_characters.clear()
	if not _load_ok:
		_rebuild_cards()
		return

	for def in _all_characters:
		if _matches(def, query):
			_visible_characters.append(def)

	if query.is_empty():
		_set_status(STATUS_ALL_FMT % _visible_characters.size())
	else:
		_set_status(STATUS_FILTER_FMT % _visible_characters.size())

	if _visible_characters.is_empty():
		_selected_id = &""
		_show_empty_state()
		_clear_detail()
	else:
		_hide_states()
		if not _has_visible_id(_selected_id):
			_selected_id = _visible_characters[0].get_id()
		_update_detail_for_selected()

	_rebuild_cards()


func _matches(def: CharacterDefinition, query: String) -> bool:
	if query.is_empty():
		return true
	var q: String = query.to_lower()
	if def.get_display_name().to_lower().find(q) >= 0:
		return true
	if def.get_species().to_lower().find(q) >= 0:
		return true
	for tag in def.get_tags():
		if tag.to_lower().find(q) >= 0:
			return true
	return false


func _has_visible_id(id: StringName) -> bool:
	if String(id).is_empty():
		return false
	for def in _visible_characters:
		if def.get_id() == id:
			return true
	return false


func _rebuild_cards() -> void:
	if _card_grid == null:
		return
	for child in _card_grid.get_children():
		_card_grid.remove_child(child)
		child.queue_free()
	_cards_by_id.clear()

	var packed: PackedScene = load(CARD_SCENE_PATH) as PackedScene
	if packed == null:
		return

	for def in _visible_characters:
		var card: Button = packed.instantiate() as Button
		if card == null:
			continue
		_card_grid.add_child(card)
		if card.has_method("configure"):
			card.call("configure", def)
		if card.has_method("set_selected"):
			card.call("set_selected", def.get_id() == _selected_id)
		if card.has_signal("card_activated"):
			card.card_activated.connect(_on_card_activated)
		_cards_by_id[def.get_id()] = card

	call_deferred("_refresh_columns")


func _on_card_activated(character_id: StringName) -> void:
	if character_id == _selected_id:
		# Re-click same card: keep selection, no duplicate side effects.
		_sync_card_selection()
		return
	_selected_id = character_id
	_update_detail_for_selected()
	_sync_card_selection()
	character_selected.emit(character_id)


func _sync_card_selection() -> void:
	for id in _cards_by_id.keys():
		var card: Object = _cards_by_id[id]
		if card != null and is_instance_valid(card) and card.has_method("set_selected"):
			card.call("set_selected", id == _selected_id)


func _update_detail_for_selected() -> void:
	var def: CharacterDefinition = _find_visible(_selected_id)
	if def == null:
		_clear_detail()
		return
	if _detail_name != null:
		_detail_name.text = def.get_display_name()
	if _detail_species != null:
		_detail_species.text = def.get_species()
	if _detail_summary != null:
		_detail_summary.text = def.get_summary()
	if _detail_description != null:
		_detail_description.text = def.get_description()
	if _detail_tags != null:
		_detail_tags.text = "標籤：%s" % " · ".join(def.get_tags())
	if _detail_seed_hint != null:
		_detail_seed_hint.visible = def.is_development_seed()
		_detail_seed_hint.text = SEED_HINT
	if _detail_glyph != null:
		_detail_glyph.text = def.get_placeholder_glyph()
	if _detail_panel != null:
		_detail_panel.visible = true


func _find_visible(id: StringName) -> CharacterDefinition:
	for def in _visible_characters:
		if def.get_id() == id:
			return def
	return null


func _clear_detail() -> void:
	if _detail_name != null:
		_detail_name.text = DETAIL_EMPTY
	if _detail_species != null:
		_detail_species.text = ""
	if _detail_summary != null:
		_detail_summary.text = ""
	if _detail_description != null:
		_detail_description.text = ""
	if _detail_tags != null:
		_detail_tags.text = ""
	if _detail_seed_hint != null:
		_detail_seed_hint.visible = false
	if _detail_glyph != null:
		_detail_glyph.text = "?"


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _show_empty_state() -> void:
	if _empty_label != null:
		_empty_label.visible = true
		_empty_label.text = STATUS_EMPTY
	if _error_label != null:
		_error_label.visible = false
	_set_status(STATUS_EMPTY)


func _show_error_state(message: String) -> void:
	if _error_label != null:
		_error_label.visible = true
		_error_label.text = message if not message.is_empty() else STATUS_LOAD_FAIL
	if _empty_label != null:
		_empty_label.visible = false
	_set_status(STATUS_LOAD_FAIL)


func _hide_states() -> void:
	if _empty_label != null:
		_empty_label.visible = false
	if _error_label != null:
		_error_label.visible = false


func _refresh_columns() -> void:
	if _card_grid == null:
		return
	var width: float = 0.0
	if _card_scroll != null:
		width = _card_scroll.size.x
	if width <= 1.0 and _card_grid != null:
		width = _card_grid.size.x
	if width <= 1.0 and _content_row != null:
		width = _content_row.size.x
	if width <= 1.0:
		width = size.x
	# Available width drives columns (not only global viewport guess).
	var cols: int = 2
	if width >= 520.0:
		cols = maxi(3, int(floor(width / CARD_MIN_WIDTH)))
	elif width >= 300.0:
		cols = 2
	else:
		cols = 2
	_card_grid.columns = cols


func _on_back_pressed() -> void:
	request_back()


func request_back() -> bool:
	var ok: bool = NavigationState.go_back_or_fallback()
	if ok:
		back_requested.emit()
	return ok


func get_screen_id() -> StringName:
	return _screen_id


func get_back_button() -> Button:
	return _back_button


func get_search_edit() -> LineEdit:
	return _search_edit


func get_title_text() -> String:
	if _title_label == null:
		return "角色圖鑑"
	return _title_label.text


func get_status_text() -> String:
	if _status_label == null:
		return ""
	return _status_label.text


func get_selected_id() -> StringName:
	return _selected_id


func get_result_count() -> int:
	return _visible_characters.size()


func get_visible_character_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for def in _visible_characters:
		ids.append(def.get_id())
	return ids


func get_all_character_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for def in _all_characters:
		ids.append(def.get_id())
	return ids


func get_detail_name_text() -> String:
	if _detail_name == null:
		return ""
	return _detail_name.text


func get_detail_species_text() -> String:
	if _detail_species == null:
		return ""
	return _detail_species.text


func get_detail_summary_text() -> String:
	if _detail_summary == null:
		return ""
	return _detail_summary.text


func get_detail_description_text() -> String:
	if _detail_description == null:
		return ""
	return _detail_description.text


func get_detail_tags_text() -> String:
	if _detail_tags == null:
		return ""
	return _detail_tags.text


func is_empty_state_visible() -> bool:
	return _empty_label != null and _empty_label.visible


func is_error_state_visible() -> bool:
	return _error_label != null and _error_label.visible


func is_load_ok() -> bool:
	return _load_ok


func get_load_error() -> String:
	return _load_error


func get_card_count() -> int:
	if _card_grid == null:
		return 0
	return _card_grid.get_child_count()


func get_card_grid() -> GridContainer:
	return _card_grid


func get_card_scroll() -> ScrollContainer:
	return _card_scroll


func get_detail_panel() -> PanelContainer:
	return _detail_panel


func get_grid_columns() -> int:
	if _card_grid == null:
		return 0
	return _card_grid.columns


func select_character_for_test(character_id: StringName) -> bool:
	if not _has_visible_id(character_id):
		return false
	_on_card_activated(character_id)
	return true


func set_search_text_for_test(text: String) -> void:
	if _search_edit == null:
		return
	_search_edit.text = text
	_on_search_changed(text)
