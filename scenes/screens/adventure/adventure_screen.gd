## Dedicated adventure area/stage selection screen (no real battle in 0.8.0).
extends Control

signal back_requested
signal stage_prepared(stage_id: StringName)

const CARD_SCENE_PATH: String = "res://scenes/screens/adventure/stage_card.tscn"
const MSG_PREPARE_OK: String = "關卡準備完成，戰鬥系統將於後續版本開放"
const MSG_PREPARE_FAIL: String = "無法準備此關卡"
const MSG_NO_PARTY: String = "無法讀取隊伍資料"
const MSG_CATALOG_FAIL: String = "冒險關卡資料載入失敗"
const SEED_HINT: String = "本頁內容為開發樣本，非正式世界觀。"
const PARTY_SUMMARY_FMT: String = "目前隊伍 %d 人 · 領隊：%s"
const STAGE_WIDE_MIN_WIDTH: float = 600.0

@onready var _title_label: Label = %TitleLabel
@onready var _back_button: Button = %BackButton
@onready var _seed_hint_label: Label = %SeedHintLabel
@onready var _body_scroll: ScrollContainer = %BodyScroll
@onready var _body_content: Control = %BodyContent
@onready var _area_buttons_row: HBoxContainer = %AreaButtonsRow
@onready var _area_name_label: Label = %AreaNameLabel
@onready var _area_summary_label: Label = %AreaSummaryLabel
@onready var _story_intro_label: Label = %StoryIntroLabel
@onready var _stage_grid: GridContainer = %StageGrid
@onready var _detail_name_label: Label = %DetailNameLabel
@onready var _detail_summary_label: Label = %DetailSummaryLabel
@onready var _detail_status_label: Label = %DetailStatusLabel
@onready var _party_summary_label: Label = %PartySummaryLabel
@onready var _prepare_button: Button = %PrepareButton
@onready var _mutation_message_label: Label = %MutationMessageLabel
@onready var _error_label: Label = %ErrorLabel

var _screen_id: StringName = &""
var _configured: bool = false
var _ready_done: bool = false
var _signals_bound: bool = false
var _adventure_signals_bound: bool = false
var _player_data_signals_bound: bool = false
var _areas: Array[StageAreaDefinition] = []
var _selected_area_id: StringName = &""
var _selected_stage_id: StringName = &""
## Independent of selection storage; updated only by _update_detail().
var _detail_stage_id: StringName = &""
var _area_buttons: Dictionary = {}
var _stage_cards: Dictionary = {}
var _load_ok: bool = false
var _load_error: String = ""
var _prepare_refresh_count_for_tests: int = 0
var _party_summary_refresh_count_for_tests: int = 0
## Test fixture overrides (null = production path).
var _stage_catalog_override_for_tests: Variant = null
var _player_data_available_override_for_tests: Variant = null


func _ready() -> void:
	_ready_done = true
	_bind_signals()
	_bind_domain_signals()
	AppState.set_phase(AppState.Phase.MODULE)
	if _configured:
		_reload_all()
	elif NavigationState.get_current_screen() == ScreenRegistry.SCREEN_ADVENTURE:
		configure_screen(ScreenRegistry.SCREEN_ADVENTURE)
	call_deferred("_refresh_columns")


func _exit_tree() -> void:
	_unbind_domain_signals()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_columns()


func _bind_signals() -> void:
	if _signals_bound:
		return
	if _back_button != null and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _prepare_button != null and not _prepare_button.pressed.is_connected(_on_prepare_pressed):
		_prepare_button.pressed.connect(_on_prepare_pressed)
	_signals_bound = true


func _bind_domain_signals() -> void:
	if is_instance_valid(AdventureState) and not _adventure_signals_bound:
		if not AdventureState.prepared_stage_changed.is_connected(_on_prepared_stage_changed):
			AdventureState.prepared_stage_changed.connect(_on_prepared_stage_changed)
		_adventure_signals_bound = true
	if is_instance_valid(PlayerData) and not _player_data_signals_bound:
		if not PlayerData.profile_changed.is_connected(_on_player_profile_changed):
			PlayerData.profile_changed.connect(_on_player_profile_changed)
		_player_data_signals_bound = true


func _unbind_domain_signals() -> void:
	if is_instance_valid(AdventureState) and _adventure_signals_bound:
		if AdventureState.prepared_stage_changed.is_connected(_on_prepared_stage_changed):
			AdventureState.prepared_stage_changed.disconnect(_on_prepared_stage_changed)
	_adventure_signals_bound = false
	if is_instance_valid(PlayerData) and _player_data_signals_bound:
		if PlayerData.profile_changed.is_connected(_on_player_profile_changed):
			PlayerData.profile_changed.disconnect(_on_player_profile_changed)
	_player_data_signals_bound = false


func configure_screen(screen_id: StringName) -> bool:
	if screen_id != ScreenRegistry.SCREEN_ADVENTURE:
		return false
	_screen_id = screen_id
	_configured = true
	AppState.set_phase(AppState.Phase.MODULE)
	if _ready_done:
		_bind_signals()
		_bind_domain_signals()
		_reload_all()
	return true


func _reload_all() -> void:
	if _title_label != null:
		_title_label.text = "冒險"
	if _back_button != null:
		_back_button.text = "返回"
		_back_button.custom_minimum_size = Vector2(maxf(_back_button.custom_minimum_size.x, 96), 48)
	if _seed_hint_label != null:
		_seed_hint_label.text = SEED_HINT
	if _prepare_button != null:
		_prepare_button.text = "準備此關卡"
		_prepare_button.custom_minimum_size = Vector2(maxf(_prepare_button.custom_minimum_size.x, 120), 48)
	_set_mutation_message("")
	_hide_error()

	var result: Dictionary = _load_stage_catalog()
	_load_ok = bool(result.get("ok", false))
	_load_error = str(result.get("error", ""))
	_areas.clear()
	if _load_ok:
		for item in result.get("areas", []):
			if item is StageAreaDefinition:
				_areas.append((item as StageAreaDefinition).duplicate_definition())
	else:
		_show_error(_load_error if not _load_error.is_empty() else MSG_CATALOG_FAIL)

	_restore_or_default_selection()
	_rebuild_area_buttons()
	_rebuild_stage_grid()
	_update_area_story()
	_update_detail()
	_update_party_summary()
	_update_prepare_button()
	_refresh_columns()


## Overridable dependency seam for StageCatalog (production default unchanged).
func _load_stage_catalog() -> Dictionary:
	if _stage_catalog_override_for_tests is Dictionary:
		return (_stage_catalog_override_for_tests as Dictionary).duplicate(true)
	return StageCatalog.load_default()


## Overridable dependency seam for PlayerData availability.
func _is_player_data_available() -> bool:
	if _player_data_available_override_for_tests != null:
		return bool(_player_data_available_override_for_tests)
	return is_instance_valid(PlayerData)


func _restore_or_default_selection() -> void:
	if not _load_ok or _areas.is_empty():
		_selected_area_id = &""
		_selected_stage_id = &""
		return
	var area: StageAreaDefinition = _find_area(_selected_area_id)
	if area == null:
		area = _areas[0]
		_selected_area_id = area.get_id()
	var stages: Array[StageDefinition] = area.get_stages()
	if stages.is_empty():
		_selected_stage_id = &""
		return
	var stage_ok: bool = false
	for s in stages:
		if s.get_id() == _selected_stage_id:
			stage_ok = true
			break
	if not stage_ok:
		_selected_stage_id = stages[0].get_id()


func _find_area(area_id: StringName) -> StageAreaDefinition:
	for a in _areas:
		if a.get_id() == area_id:
			return a
	return null


func _find_stage_in_selected(stage_id: StringName) -> StageDefinition:
	var area: StageAreaDefinition = _find_area(_selected_area_id)
	if area == null:
		return null
	return area.find_stage(stage_id)


func _rebuild_area_buttons() -> void:
	if _area_buttons_row == null:
		return
	for child in _area_buttons_row.get_children():
		_area_buttons_row.remove_child(child)
		child.queue_free()
	_area_buttons.clear()
	for area in _areas:
		var btn := Button.new()
		btn.text = area.get_display_name()
		btn.custom_minimum_size = Vector2(96, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = area.get_id() == _selected_area_id
		var aid: StringName = area.get_id()
		btn.pressed.connect(func() -> void:
			_on_area_pressed(aid)
		)
		_area_buttons_row.add_child(btn)
		_area_buttons[area.get_id()] = btn


func _rebuild_stage_grid() -> void:
	if _stage_grid == null:
		return
	for child in _stage_grid.get_children():
		_stage_grid.remove_child(child)
		child.queue_free()
	_stage_cards.clear()
	var area: StageAreaDefinition = _find_area(_selected_area_id)
	if area == null:
		return
	var packed: PackedScene = load(CARD_SCENE_PATH) as PackedScene
	if packed == null:
		return
	var prepared_id: StringName = &""
	if is_instance_valid(AdventureState):
		prepared_id = AdventureState.get_selected_stage_id()
	for stage in area.get_stages():
		var card: Button = packed.instantiate() as Button
		if card == null:
			continue
		_stage_grid.add_child(card)
		var viewing: bool = stage.get_id() == _selected_stage_id
		var prepared: bool = stage.get_id() == prepared_id
		card.call("configure", stage, viewing, prepared)
		if card.has_signal("card_activated"):
			card.card_activated.connect(_on_stage_card_activated)
		_stage_cards[stage.get_id()] = card


func _update_area_story() -> void:
	var area: StageAreaDefinition = _find_area(_selected_area_id)
	if area == null:
		if _area_name_label != null:
			_area_name_label.text = ""
		if _area_summary_label != null:
			_area_summary_label.text = ""
		if _story_intro_label != null:
			_story_intro_label.text = ""
		return
	if _area_name_label != null:
		_area_name_label.text = area.get_display_name()
	if _area_summary_label != null:
		_area_summary_label.text = area.get_summary()
	if _story_intro_label != null:
		_story_intro_label.text = area.get_story_intro()
	for id in _area_buttons.keys():
		var btn: Button = _area_buttons[id] as Button
		if btn != null:
			btn.button_pressed = id == _selected_area_id


func _update_detail() -> void:
	var stage: StageDefinition = _find_stage_in_selected(_selected_stage_id)
	var prepared_id: StringName = &""
	if is_instance_valid(AdventureState):
		prepared_id = AdventureState.get_selected_stage_id()
	if stage == null:
		_detail_stage_id = &""
		if _detail_name_label != null:
			_detail_name_label.text = "請選擇關卡"
		if _detail_summary_label != null:
			_detail_summary_label.text = ""
		if _detail_status_label != null:
			_detail_status_label.text = ""
		for id in _stage_cards.keys():
			var empty_card: Object = _stage_cards[id]
			if empty_card != null and is_instance_valid(empty_card):
				if empty_card.has_method("set_viewing"):
					empty_card.call("set_viewing", false)
				if empty_card.has_method("set_prepared"):
					empty_card.call("set_prepared", id == prepared_id)
		return
	_detail_stage_id = stage.get_id()
	if _detail_name_label != null:
		_detail_name_label.text = stage.get_display_name()
	if _detail_summary_label != null:
		_detail_summary_label.text = stage.get_summary()
	if _detail_status_label != null:
		var parts: PackedStringArray = PackedStringArray(["檢視中"])
		if stage.get_id() == prepared_id:
			parts.append("已準備")
		if stage.is_development_seed():
			parts.append("開發樣本")
		_detail_status_label.text = " · ".join(parts)
	for id in _stage_cards.keys():
		var card: Object = _stage_cards[id]
		if card != null and is_instance_valid(card):
			if card.has_method("set_viewing"):
				card.call("set_viewing", id == _selected_stage_id)
			if card.has_method("set_prepared"):
				card.call("set_prepared", id == prepared_id)


func _update_party_summary() -> void:
	_party_summary_refresh_count_for_tests += 1
	if _party_summary_label == null:
		return
	if not _is_player_data_available():
		_party_summary_label.text = MSG_NO_PARTY
		return
	if not PlayerData.is_initialized():
		PlayerData.initialize()
	var party: Array[StringName] = PlayerData.get_active_party_character_ids()
	var leader_id: StringName = PlayerData.get_party_leader_character_id()
	var leader_name: String = str(leader_id)
	var cat: Dictionary = CharacterCatalog.load_default()
	if bool(cat.get("ok", false)):
		for item in cat.get("characters", []):
			if item is CharacterDefinition and (item as CharacterDefinition).get_id() == leader_id:
				leader_name = (item as CharacterDefinition).get_display_name()
				break
	_party_summary_label.text = PARTY_SUMMARY_FMT % [party.size(), leader_name]


func _update_prepare_button() -> void:
	if _prepare_button == null:
		return
	var ok: bool = (
		_load_ok
		and not String(_selected_stage_id).is_empty()
		and _is_player_data_available()
		and is_instance_valid(AdventureState)
	)
	_prepare_button.disabled = not ok


func _on_area_pressed(area_id: StringName) -> void:
	if area_id == _selected_area_id:
		_update_area_story()
		return
	_selected_area_id = area_id
	var area: StageAreaDefinition = _find_area(area_id)
	if area != null:
		var stages: Array[StageDefinition] = area.get_stages()
		_selected_stage_id = stages[0].get_id() if not stages.is_empty() else &""
	else:
		_selected_stage_id = &""
	_set_mutation_message("")
	_rebuild_stage_grid()
	_update_area_story()
	_update_detail()
	_update_prepare_button()


func _on_stage_card_activated(stage_id: StringName) -> void:
	_selected_stage_id = stage_id
	_set_mutation_message("")
	_update_detail()
	_update_prepare_button()


func _on_prepare_pressed() -> void:
	# Handler is fail-safe even when Button.disabled is bypassed by tests/callers.
	if not _is_player_data_available():
		_set_mutation_message(MSG_NO_PARTY)
		return
	if not _load_ok or String(_selected_stage_id).is_empty():
		_set_mutation_message(MSG_PREPARE_FAIL)
		return
	if not is_instance_valid(AdventureState):
		_set_mutation_message(MSG_PREPARE_FAIL)
		return
	var result: Dictionary = AdventureState.prepare_stage(_selected_stage_id)
	if not bool(result.get("ok", false)):
		_set_mutation_message(MSG_PREPARE_FAIL)
		return
	if bool(result.get("changed", false)):
		# UI update via prepared_stage_changed single path.
		_set_mutation_message(MSG_PREPARE_OK)
		stage_prepared.emit(_selected_stage_id)
	else:
		_set_mutation_message(MSG_PREPARE_OK)


func _on_prepared_stage_changed(_area_id: StringName, _stage_id: StringName) -> void:
	if not _ready_done or not _configured:
		return
	_prepare_refresh_count_for_tests += 1
	_update_detail()
	_rebuild_stage_grid()
	_update_prepare_button()


func _on_player_profile_changed(_revision: int) -> void:
	if not _ready_done or not _configured:
		return
	# Party summary only; do not rebuild catalog or change stage selection.
	_update_party_summary()
	_update_prepare_button()


func _set_mutation_message(text: String) -> void:
	if _mutation_message_label != null:
		_mutation_message_label.text = text
		_mutation_message_label.visible = not text.is_empty()


func _show_error(message: String) -> void:
	if _error_label != null:
		_error_label.visible = true
		_error_label.text = message


func _hide_error() -> void:
	if _error_label != null:
		_error_label.visible = false


func _refresh_columns() -> void:
	if _stage_grid == null:
		return
	var width: float = size.x
	if width <= 1.0 and _body_scroll != null:
		width = _body_scroll.size.x
	var cols: int = 2
	if width >= STAGE_WIDE_MIN_WIDTH:
		cols = 4
	_stage_grid.columns = cols


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


func get_prepare_button() -> Button:
	return _prepare_button


func get_body_scroll() -> ScrollContainer:
	return _body_scroll


func get_stage_grid() -> GridContainer:
	return _stage_grid


func get_grid_columns() -> int:
	if _stage_grid == null:
		return 0
	return _stage_grid.columns


func get_selected_area_id() -> StringName:
	return _selected_area_id


func get_selected_stage_id() -> StringName:
	return _selected_stage_id


func get_visible_selected_area_id() -> StringName:
	for id in _area_buttons.keys():
		var btn: Button = _area_buttons[id] as Button
		if btn != null and btn.button_pressed:
			return id as StringName
	return &""


func get_visible_selected_stage_id() -> StringName:
	for id in _stage_cards.keys():
		var card: Object = _stage_cards[id]
		if card != null and is_instance_valid(card) and card.has_method("is_viewing"):
			if bool(card.call("is_viewing")):
				return id as StringName
	return &""


func get_detail_stage_id() -> StringName:
	return _detail_stage_id


func get_detail_name_text() -> String:
	if _detail_name_label == null:
		return ""
	return _detail_name_label.text


func is_error_state_visible() -> bool:
	return _error_label != null and _error_label.visible


func get_error_text() -> String:
	if _error_label == null:
		return ""
	return _error_label.text


func get_story_intro_text() -> String:
	if _story_intro_label == null:
		return ""
	return _story_intro_label.text


func get_area_name_text() -> String:
	if _area_name_label == null:
		return ""
	return _area_name_label.text


func get_party_summary_text() -> String:
	if _party_summary_label == null:
		return ""
	return _party_summary_label.text


func get_mutation_message() -> String:
	if _mutation_message_label == null:
		return ""
	return _mutation_message_label.text


func is_load_ok() -> bool:
	return _load_ok


func get_stage_card_count() -> int:
	return _stage_cards.size()


func select_area_for_test(area_id: StringName) -> bool:
	if _find_area(area_id) == null:
		return false
	_on_area_pressed(area_id)
	return true


func select_stage_for_test(stage_id: StringName) -> bool:
	if _find_stage_in_selected(stage_id) == null:
		return false
	_on_stage_card_activated(stage_id)
	return true


func press_prepare_for_test() -> void:
	_on_prepare_pressed()


func reset_prepare_refresh_count_for_tests() -> void:
	_prepare_refresh_count_for_tests = 0


func get_prepare_refresh_count_for_tests() -> int:
	return _prepare_refresh_count_for_tests


func reset_party_summary_refresh_count_for_tests() -> void:
	_party_summary_refresh_count_for_tests = 0


func get_party_summary_refresh_count_for_tests() -> int:
	return _party_summary_refresh_count_for_tests


func set_stage_catalog_override_for_tests(result: Dictionary) -> void:
	_stage_catalog_override_for_tests = result.duplicate(true)


func clear_stage_catalog_override_for_tests() -> void:
	_stage_catalog_override_for_tests = null


func set_player_data_available_override_for_tests(available: bool) -> void:
	_player_data_available_override_for_tests = available


func clear_player_data_available_override_for_tests() -> void:
	_player_data_available_override_for_tests = null


func ensure_control_visible_for_test(control: Control) -> void:
	if _body_scroll == null or control == null or not is_instance_valid(control):
		return
	if _body_scroll.has_method("ensure_control_visible"):
		_body_scroll.ensure_control_visible(control)
