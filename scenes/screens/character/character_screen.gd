## Dedicated character catalog module screen with ownership filters and representative select.
## Reads PlayerData only; does not FileAccess / encode saves itself.
extends Control

signal back_requested
signal character_selected(character_id: StringName)
signal representative_changed(character_id: StringName)

const CARD_SCENE_PATH: String = "res://scenes/screens/character/character_card.tscn"
const STATUS_ALL_FMT: String = "共 %d 位角色"
const STATUS_FILTER_FMT: String = "找到 %d 位角色"
const STATUS_EMPTY: String = "沒有符合的角色"
const STATUS_LOAD_FAIL: String = "角色圖鑑載入失敗"
const STATUS_LOADING: String = "載入中…"
const DETAIL_EMPTY: String = "請選擇角色"
const SEED_HINT: String = "此為開發樣本（development seed），非正式世界觀角色。"
const CARD_MIN_WIDTH: float = 150.0
const OWNERSHIP_SUMMARY_FMT: String = "已持有 %d / %d"
const MSG_REP_SUCCESS: String = "已設為代表角色"
const MSG_REP_SAVE_FAIL: String = "無法儲存代表角色，請再試一次"
const MSG_REP_NOT_OWNED: String = "尚未持有此角色"

const FILTER_ALL: StringName = &"ALL"
const FILTER_OWNED: StringName = &"OWNED"
const FILTER_UNOWNED: StringName = &"UNOWNED"

@onready var _title_label: Label = %TitleLabel
@onready var _back_button: Button = %BackButton
@onready var _search_edit: LineEdit = %SearchEdit
@onready var _status_label: Label = %StatusLabel
@onready var _ownership_summary_label: Label = %OwnershipSummaryLabel
@onready var _filter_all_button: Button = %FilterAllButton
@onready var _filter_owned_button: Button = %FilterOwnedButton
@onready var _filter_unowned_button: Button = %FilterUnownedButton
@onready var _card_scroll: ScrollContainer = %CardScroll
@onready var _card_grid: GridContainer = %CardGrid
@onready var _detail_panel: PanelContainer = %DetailPanel
@onready var _detail_glyph: Label = %DetailGlyph
@onready var _detail_name: Label = %DetailName
@onready var _detail_species: Label = %DetailSpecies
@onready var _detail_summary: Label = %DetailSummary
@onready var _detail_description: Label = %DetailDescription
@onready var _detail_tags: Label = %DetailTags
@onready var _detail_ownership_label: Label = %DetailOwnershipLabel
@onready var _detail_representative_label: Label = %DetailRepresentativeLabel
@onready var _set_representative_button: Button = %SetRepresentativeButton
@onready var _mutation_message_label: Label = %MutationMessageLabel
@onready var _detail_seed_hint: Label = %DetailSeedHint
@onready var _empty_label: Label = %EmptyLabel
@onready var _error_label: Label = %ErrorLabel
@onready var _content_row: Control = %ContentRow

var _screen_id: StringName = &""
var _configured: bool = false
var _ready_done: bool = false
var _signals_bound: bool = false
var _player_data_signals_bound: bool = false
var _all_characters: Array[CharacterDefinition] = []
var _visible_characters: Array[CharacterDefinition] = []
var _cards_by_id: Dictionary = {}
## Detail-panel focus (inspect). Not the profile representative.
var _focused_id: StringName = &""
var _representative_id: StringName = &""
var _owned_ids: Dictionary = {}
var _ownership_filter: StringName = FILTER_ALL
var _load_ok: bool = false
var _load_error: String = ""
var _catalog_source_path: String = CharacterCatalog.DEFAULT_PATH
var _player_data_ok: bool = true
var _player_data_error: String = ""
## Test-only counter for ownership full-refresh calls (not shown in UI).
var _ownership_refresh_count_for_tests: int = 0


func _ready() -> void:
	_ready_done = true
	_bind_signals()
	_bind_player_data_signals()
	AppState.set_phase(AppState.Phase.MODULE)
	if _configured:
		_reload_catalog_and_ui()
	elif NavigationState.get_current_screen() == ScreenRegistry.SCREEN_CHARACTER:
		configure_screen(ScreenRegistry.SCREEN_CHARACTER)
	call_deferred("_refresh_columns")


func _exit_tree() -> void:
	_unbind_player_data_signals()


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
	if _filter_all_button != null and not _filter_all_button.pressed.is_connected(_on_filter_all):
		_filter_all_button.pressed.connect(_on_filter_all)
	if _filter_owned_button != null and not _filter_owned_button.pressed.is_connected(_on_filter_owned):
		_filter_owned_button.pressed.connect(_on_filter_owned)
	if _filter_unowned_button != null and not _filter_unowned_button.pressed.is_connected(_on_filter_unowned):
		_filter_unowned_button.pressed.connect(_on_filter_unowned)
	if _set_representative_button != null and not _set_representative_button.pressed.is_connected(_on_set_representative_pressed):
		_set_representative_button.pressed.connect(_on_set_representative_pressed)
	_signals_bound = true


func _bind_player_data_signals() -> void:
	if _player_data_signals_bound:
		return
	if not is_instance_valid(PlayerData):
		return
	# Single authoritative UI refresh path: profile_changed only.
	# character_granted / selected_character_changed still fire from PlayerData
	# but must not each rebuild the ownership UI.
	if not PlayerData.profile_changed.is_connected(_on_player_profile_changed):
		PlayerData.profile_changed.connect(_on_player_profile_changed)
	_player_data_signals_bound = true


func _unbind_player_data_signals() -> void:
	if not _player_data_signals_bound:
		return
	if is_instance_valid(PlayerData):
		if PlayerData.profile_changed.is_connected(_on_player_profile_changed):
			PlayerData.profile_changed.disconnect(_on_player_profile_changed)
	_player_data_signals_bound = false


## Accepts only SCREEN_CHARACTER. Safe before or after enter tree.
func configure_screen(screen_id: StringName) -> bool:
	if screen_id != ScreenRegistry.SCREEN_CHARACTER:
		return false

	_screen_id = screen_id
	_configured = true
	AppState.set_phase(AppState.Phase.MODULE)

	if _ready_done:
		_bind_signals()
		_bind_player_data_signals()
		_reload_catalog_and_ui()
	return true


func set_catalog_source_path(path: String) -> void:
	_catalog_source_path = path
	if _ready_done and _configured:
		_reload_catalog_and_ui()


func _ensure_player_data() -> void:
	_player_data_ok = true
	_player_data_error = ""
	if not is_instance_valid(PlayerData):
		_player_data_ok = false
		_player_data_error = "PlayerData unavailable"
		_owned_ids.clear()
		_representative_id = &""
		return
	if not PlayerData.is_initialized():
		PlayerData.initialize()
	_sync_ownership_from_player_data()


func _sync_ownership_from_player_data() -> void:
	_owned_ids.clear()
	_representative_id = &""
	if not is_instance_valid(PlayerData):
		return
	for id in PlayerData.get_owned_character_ids():
		_owned_ids[str(id)] = true
	_representative_id = PlayerData.get_selected_character_id()


func _reload_catalog_and_ui() -> void:
	if _title_label != null:
		_title_label.text = "角色圖鑑"
	if _back_button != null:
		_back_button.text = "返回"
	if _search_edit != null:
		_search_edit.placeholder_text = "搜尋角色、物種或標籤"
	if _filter_all_button != null:
		_filter_all_button.text = "全部"
	if _filter_owned_button != null:
		_filter_owned_button.text = "已持有"
	if _filter_unowned_button != null:
		_filter_unowned_button.text = "未持有"
	_set_mutation_message("")

	_set_status(STATUS_LOADING)
	_hide_states()
	_ensure_player_data()

	var result: Dictionary = CharacterCatalog.load_from_path(_catalog_source_path)
	_load_ok = bool(result.get("ok", false))
	_load_error = str(result.get("error", ""))
	_all_characters.clear()
	_visible_characters.clear()
	_cards_by_id.clear()
	_focused_id = &""

	if not _load_ok:
		_show_error_state(_load_error if not _load_error.is_empty() else STATUS_LOAD_FAIL)
		_clear_detail()
		_update_ownership_summary()
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


func _on_filter_all() -> void:
	_set_ownership_filter(FILTER_ALL)


func _on_filter_owned() -> void:
	_set_ownership_filter(FILTER_OWNED)


func _on_filter_unowned() -> void:
	_set_ownership_filter(FILTER_UNOWNED)


func _set_ownership_filter(mode: StringName) -> void:
	if _ownership_filter == mode:
		_update_filter_button_styles()
		return
	_ownership_filter = mode
	_apply_filter(_current_query())


func _apply_filter(raw_query: String) -> void:
	var query: String = raw_query.strip_edges()
	_visible_characters.clear()
	if not _load_ok:
		_rebuild_cards()
		_update_filter_button_styles()
		return

	for def in _all_characters:
		if not _matches(def, query):
			continue
		if not _matches_ownership(def):
			continue
		_visible_characters.append(def)

	if query.is_empty() and _ownership_filter == FILTER_ALL:
		_set_status(STATUS_ALL_FMT % _visible_characters.size())
	else:
		_set_status(STATUS_FILTER_FMT % _visible_characters.size())

	_update_ownership_summary()
	_update_filter_button_styles()

	if _visible_characters.is_empty():
		_focused_id = &""
		_show_empty_state()
		_clear_detail()
	else:
		_hide_states()
		if not _has_visible_id(_focused_id):
			_focused_id = _pick_initial_focus_id()
		_update_detail_for_focused()

	_rebuild_cards()


func _pick_initial_focus_id() -> StringName:
	# Prefer representative if still visible under current search/filter.
	if _has_visible_id(_representative_id):
		return _representative_id
	if not _visible_characters.is_empty():
		return _visible_characters[0].get_id()
	return &""


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


func _matches_ownership(def: CharacterDefinition) -> bool:
	var owned: bool = _is_owned_id(def.get_id())
	if _ownership_filter == FILTER_OWNED:
		return owned
	if _ownership_filter == FILTER_UNOWNED:
		return not owned
	return true


func _is_owned_id(id: StringName) -> bool:
	return _owned_ids.has(str(id))


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
		var owned: bool = _is_owned_id(def.get_id())
		var is_rep: bool = def.get_id() == _representative_id
		if card.has_method("configure"):
			card.call("configure", def, owned, is_rep)
		if card.has_method("set_focused"):
			card.call("set_focused", def.get_id() == _focused_id)
		elif card.has_method("set_selected"):
			card.call("set_selected", def.get_id() == _focused_id)
		if card.has_signal("card_activated"):
			card.card_activated.connect(_on_card_activated)
		_cards_by_id[def.get_id()] = card

	call_deferred("_refresh_columns")


func _on_card_activated(character_id: StringName) -> void:
	if character_id == _focused_id:
		_sync_card_focus()
		return
	_focused_id = character_id
	_set_mutation_message("")
	_update_detail_for_focused()
	_sync_card_focus()
	character_selected.emit(character_id)


func _sync_card_focus() -> void:
	for id in _cards_by_id.keys():
		var card: Object = _cards_by_id[id]
		if card == null or not is_instance_valid(card):
			continue
		if card.has_method("set_focused"):
			card.call("set_focused", id == _focused_id)
		elif card.has_method("set_selected"):
			card.call("set_selected", id == _focused_id)


func _update_detail_for_focused() -> void:
	var def: CharacterDefinition = _find_visible(_focused_id)
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
	_update_detail_ownership_controls(def)


func _update_detail_ownership_controls(def: CharacterDefinition) -> void:
	var owned: bool = _is_owned_id(def.get_id())
	var is_rep: bool = def.get_id() == _representative_id

	if _detail_ownership_label != null:
		_detail_ownership_label.text = "已持有" if owned else "尚未持有"
	if _detail_representative_label != null:
		_detail_representative_label.text = "目前代表角色" if is_rep else ""

	if _set_representative_button == null:
		return
	if not owned:
		_set_representative_button.text = "尚未持有"
		_set_representative_button.disabled = true
	elif is_rep:
		_set_representative_button.text = "目前代表角色"
		_set_representative_button.disabled = true
	else:
		_set_representative_button.text = "設為代表角色"
		_set_representative_button.disabled = false


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
	if _detail_ownership_label != null:
		_detail_ownership_label.text = ""
	if _detail_representative_label != null:
		_detail_representative_label.text = ""
	if _set_representative_button != null:
		_set_representative_button.text = "設為代表角色"
		_set_representative_button.disabled = true


func _update_ownership_summary() -> void:
	if _ownership_summary_label == null:
		return
	var total: int = _all_characters.size()
	var owned_count: int = 0
	if is_instance_valid(PlayerData):
		# Known owned only: IDs present in loaded catalog.
		var catalog_ids: Dictionary = {}
		for def in _all_characters:
			catalog_ids[str(def.get_id())] = true
		for id_key in _owned_ids.keys():
			if catalog_ids.has(str(id_key)):
				owned_count += 1
	_ownership_summary_label.text = OWNERSHIP_SUMMARY_FMT % [owned_count, total]


func _update_filter_button_styles() -> void:
	_style_filter_button(_filter_all_button, _ownership_filter == FILTER_ALL)
	_style_filter_button(_filter_owned_button, _ownership_filter == FILTER_OWNED)
	_style_filter_button(_filter_unowned_button, _ownership_filter == FILTER_UNOWNED)


func _style_filter_button(btn: Button, active: bool) -> void:
	if btn == null:
		return
	btn.disabled = false
	btn.modulate = Color(1.1, 1.05, 0.85, 1.0) if active else Color(1, 1, 1, 1)


func _on_set_representative_pressed() -> void:
	if String(_focused_id).is_empty():
		return
	if not _is_owned_id(_focused_id):
		_set_mutation_message(MSG_REP_NOT_OWNED)
		return
	if not is_instance_valid(PlayerData):
		_set_mutation_message(MSG_REP_SAVE_FAIL)
		return

	var result: Dictionary = PlayerData.select_character(_focused_id)
	if not bool(result.get("ok", false)):
		# Save/domain failure: profile and badges unchanged — message only, no full rebuild.
		_set_mutation_message(MSG_REP_SAVE_FAIL)
		return

	if bool(result.get("changed", false)):
		# UI rebuild is owned exclusively by profile_changed (emitted by PlayerData).
		_set_mutation_message(MSG_REP_SUCCESS)
		var actual_rep: StringName = PlayerData.get_selected_character_id()
		# Defensive fallback only if signal path did not sync representative.
		if _representative_id != actual_rep:
			_sync_ownership_from_player_data()
			_refresh_ownership_ui_preserve_focus()
		representative_changed.emit(actual_rep)
	# changed=false: no error UI rewrite


func _refresh_ownership_ui_preserve_focus() -> void:
	_ownership_refresh_count_for_tests += 1
	var keep_focus: StringName = _focused_id
	_apply_filter(_current_query())
	if _has_visible_id(keep_focus):
		_focused_id = keep_focus
		_update_detail_for_focused()
		_sync_card_focus()


func _on_player_profile_changed(_revision: int) -> void:
	if not _ready_done or not _configured:
		return
	_sync_ownership_from_player_data()
	_refresh_ownership_ui_preserve_focus()


func reset_ownership_refresh_count_for_tests() -> void:
	_ownership_refresh_count_for_tests = 0


func get_ownership_refresh_count_for_tests() -> int:
	return _ownership_refresh_count_for_tests


func _set_mutation_message(text: String) -> void:
	if _mutation_message_label != null:
		_mutation_message_label.text = text
		_mutation_message_label.visible = not text.is_empty()


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


func get_focused_id() -> StringName:
	return _focused_id


## Backward-compatible alias: selected == focused (detail inspect).
func get_selected_id() -> StringName:
	return _focused_id


func get_representative_id() -> StringName:
	return _representative_id


func get_ownership_filter() -> StringName:
	return _ownership_filter


func get_owned_count() -> int:
	var catalog_ids: Dictionary = {}
	for def in _all_characters:
		catalog_ids[str(def.get_id())] = true
	var count: int = 0
	for id_key in _owned_ids.keys():
		if catalog_ids.has(str(id_key)):
			count += 1
	return count


func get_total_catalog_count() -> int:
	return _all_characters.size()


func get_set_representative_button() -> Button:
	return _set_representative_button


func get_detail_ownership_text() -> String:
	if _detail_ownership_label == null:
		return ""
	return _detail_ownership_label.text


func get_detail_representative_text() -> String:
	if _detail_representative_label == null:
		return ""
	return _detail_representative_label.text


func get_mutation_message() -> String:
	if _mutation_message_label == null:
		return ""
	return _mutation_message_label.text


func get_ownership_summary_text() -> String:
	if _ownership_summary_label == null:
		return ""
	return _ownership_summary_label.text


func get_filter_all_button() -> Button:
	return _filter_all_button


func get_filter_owned_button() -> Button:
	return _filter_owned_button


func get_filter_unowned_button() -> Button:
	return _filter_unowned_button


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


func set_ownership_filter_for_test(mode: StringName) -> void:
	_set_ownership_filter(mode)


func press_set_representative_for_test() -> void:
	_on_set_representative_pressed()
