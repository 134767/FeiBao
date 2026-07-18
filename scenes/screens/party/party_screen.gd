## Dedicated active party formation screen. Reads/mutates only via PlayerData.
extends Control

signal back_requested
signal party_member_added(character_id: StringName)
signal party_member_removed(character_id: StringName)
signal party_order_changed(party_ids: Array[StringName])

const SLOT_SCENE_PATH: String = "res://scenes/screens/party/party_slot.tscn"
const ROSTER_CARD_PATH: String = "res://scenes/screens/party/party_roster_card.tscn"
const PARTY_SUMMARY_FMT: String = "隊伍 %d / %d"
const LEADER_SUMMARY_FMT: String = "領隊：%s"
const ROSTER_SUMMARY_FMT: String = "可用角色 %d"
const MSG_ADDED: String = "已加入隊伍"
const MSG_REMOVED: String = "已移出隊伍"
const MSG_MOVED: String = "已調整隊伍順序"
const MSG_FULL: String = "隊伍已滿"
const MSG_SAVE_FAIL: String = "無法儲存隊伍編成，請再試一次"
const MSG_MIGRATION_HINT: String = "舊版存檔已相容載入，將於下次成功儲存時更新格式"
const SLOT_COUNT: int = 3
## Viewport width threshold for 4-column roster (720 design); below → 2 columns.
const ROSTER_WIDE_MIN_WIDTH: float = 600.0

@onready var _title_label: Label = %TitleLabel
@onready var _back_button: Button = %BackButton
@onready var _page_scroll: ScrollContainer = %PageScroll
@onready var _page_content: Control = %PageContent
@onready var _party_summary_label: Label = %PartySummaryLabel
@onready var _leader_summary_label: Label = %LeaderSummaryLabel
@onready var _party_slots_container: Container = %PartySlotsContainer
@onready var _roster_summary_label: Label = %RosterSummaryLabel
@onready var _roster_grid: GridContainer = %RosterGrid
@onready var _detail_panel: PanelContainer = %DetailPanel
@onready var _detail_name_label: Label = %DetailNameLabel
@onready var _detail_status_label: Label = %DetailStatusLabel
@onready var _add_button: Button = %AddButton
@onready var _remove_button: Button = %RemoveButton
@onready var _move_left_button: Button = %MoveLeftButton
@onready var _move_right_button: Button = %MoveRightButton
@onready var _mutation_message_label: Label = %MutationMessageLabel
@onready var _empty_roster_label: Label = %EmptyRosterLabel
@onready var _error_label: Label = %ErrorLabel

var _screen_id: StringName = &""
var _configured: bool = false
var _ready_done: bool = false
var _signals_bound: bool = false
var _player_data_signals_bound: bool = false
var _catalog_defs: Array[CharacterDefinition] = []
var _defs_by_id: Dictionary = {}
var _party_ids: Array[StringName] = []
var _owned_ids: Dictionary = {}
var _representative_id: StringName = &""
var _focused_id: StringName = &""
var _load_ok: bool = false
var _load_error: String = ""
var _slot_nodes: Array = []
var _roster_cards: Dictionary = {}
var _party_refresh_count_for_tests: int = 0


func _ready() -> void:
	_ready_done = true
	_bind_signals()
	_bind_player_data_signals()
	AppState.set_phase(AppState.Phase.MODULE)
	if _configured:
		_reload_all()
	elif NavigationState.get_current_screen() == ScreenRegistry.SCREEN_PARTY:
		configure_screen(ScreenRegistry.SCREEN_PARTY)
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
	if _add_button != null and not _add_button.pressed.is_connected(_on_add_pressed):
		_add_button.pressed.connect(_on_add_pressed)
	if _remove_button != null and not _remove_button.pressed.is_connected(_on_remove_pressed):
		_remove_button.pressed.connect(_on_remove_pressed)
	if _move_left_button != null and not _move_left_button.pressed.is_connected(_on_move_left_pressed):
		_move_left_button.pressed.connect(_on_move_left_pressed)
	if _move_right_button != null and not _move_right_button.pressed.is_connected(_on_move_right_pressed):
		_move_right_button.pressed.connect(_on_move_right_pressed)
	_signals_bound = true


func _bind_player_data_signals() -> void:
	if _player_data_signals_bound:
		return
	if not is_instance_valid(PlayerData):
		return
	# Single authoritative refresh path: profile_changed only.
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


func configure_screen(screen_id: StringName) -> bool:
	if screen_id != ScreenRegistry.SCREEN_PARTY:
		return false
	_screen_id = screen_id
	_configured = true
	AppState.set_phase(AppState.Phase.MODULE)
	if _ready_done:
		_bind_signals()
		_bind_player_data_signals()
		_reload_all()
	return true


func _ensure_player_data() -> void:
	if is_instance_valid(PlayerData) and not PlayerData.is_initialized():
		PlayerData.initialize()


func _reload_all() -> void:
	if _title_label != null:
		_title_label.text = "隊伍編成"
	if _back_button != null:
		_back_button.text = "返回"
	if _add_button != null:
		_add_button.text = "加入隊伍"
	if _remove_button != null:
		_remove_button.text = "移出隊伍"
	if _move_left_button != null:
		_move_left_button.text = "左移"
	if _move_right_button != null:
		_move_right_button.text = "右移"

	_ensure_player_data()
	_hide_error()
	_set_mutation_message("")

	var result: Dictionary = CharacterCatalog.load_default()
	_load_ok = bool(result.get("ok", false))
	_load_error = str(result.get("error", ""))
	_catalog_defs.clear()
	_defs_by_id.clear()
	if _load_ok:
		for item in result.get("characters", []):
			if item is CharacterDefinition:
				var def: CharacterDefinition = item as CharacterDefinition
				_catalog_defs.append(def)
				_defs_by_id[str(def.get_id())] = def
	else:
		_show_error(_load_error if not _load_error.is_empty() else "角色圖鑑載入失敗")

	_sync_from_player_data()
	if String(_focused_id).is_empty() or (not _party_ids.has(_focused_id) and not _owned_ids.has(str(_focused_id))):
		_focused_id = _pick_initial_focus()
	_rebuild_slots()
	_rebuild_roster()
	_update_summaries()
	_update_detail_and_actions()
	_maybe_show_migration_hint()
	_refresh_columns()


func _sync_from_player_data() -> void:
	_party_ids.clear()
	_owned_ids.clear()
	_representative_id = &""
	if not is_instance_valid(PlayerData):
		return
	for id in PlayerData.get_active_party_character_ids():
		_party_ids.append(id)
	for id in PlayerData.get_owned_character_ids():
		_owned_ids[str(id)] = true
	_representative_id = PlayerData.get_selected_character_id()


func _pick_initial_focus() -> StringName:
	if not _party_ids.is_empty():
		return _party_ids[0]
	for def in _catalog_defs:
		if _owned_ids.has(str(def.get_id())):
			return def.get_id()
	return &""


func _rebuild_slots() -> void:
	if _party_slots_container == null:
		return
	for child in _party_slots_container.get_children():
		_party_slots_container.remove_child(child)
		child.queue_free()
	_slot_nodes.clear()

	var packed: PackedScene = load(SLOT_SCENE_PATH) as PackedScene
	if packed == null:
		return
	for i in SLOT_COUNT:
		var slot: Button = packed.instantiate() as Button
		if slot == null:
			continue
		_party_slots_container.add_child(slot)
		if i < _party_ids.size():
			var cid: StringName = _party_ids[i]
			var def: CharacterDefinition = _defs_by_id.get(str(cid), null) as CharacterDefinition
			slot.call("configure", i, def, cid, cid == _focused_id)
		else:
			slot.call("configure_empty", i)
		if slot.has_signal("slot_activated"):
			slot.slot_activated.connect(_on_slot_activated)
		_slot_nodes.append(slot)


func _rebuild_roster() -> void:
	if _roster_grid == null:
		return
	for child in _roster_grid.get_children():
		_roster_grid.remove_child(child)
		child.queue_free()
	_roster_cards.clear()

	var owned_defs: Array[CharacterDefinition] = []
	for def in _catalog_defs:
		if _owned_ids.has(str(def.get_id())):
			owned_defs.append(def)

	if _roster_summary_label != null:
		_roster_summary_label.text = ROSTER_SUMMARY_FMT % owned_defs.size()
	if _empty_roster_label != null:
		_empty_roster_label.visible = owned_defs.is_empty()
		_empty_roster_label.text = "尚無可用角色"

	var packed: PackedScene = load(ROSTER_CARD_PATH) as PackedScene
	if packed == null:
		return
	for def in owned_defs:
		var card: Button = packed.instantiate() as Button
		if card == null:
			continue
		_roster_grid.add_child(card)
		var in_party: bool = _party_ids.has(def.get_id())
		var is_rep: bool = def.get_id() == _representative_id
		card.call("configure", def, in_party, is_rep)
		card.call("set_focused", def.get_id() == _focused_id)
		if card.has_signal("card_activated"):
			card.card_activated.connect(_on_roster_activated)
		_roster_cards[def.get_id()] = card


func _update_summaries() -> void:
	if _party_summary_label != null:
		_party_summary_label.text = PARTY_SUMMARY_FMT % [_party_ids.size(), PlayerProfile.PARTY_MAX_SIZE]
	if _leader_summary_label != null:
		var leader: StringName = &"" if _party_ids.is_empty() else _party_ids[0]
		var leader_name: String = str(leader)
		if _defs_by_id.has(str(leader)):
			leader_name = (_defs_by_id[str(leader)] as CharacterDefinition).get_display_name()
		elif String(leader).is_empty():
			leader_name = "—"
		else:
			leader_name = "未知角色（%s）" % str(leader)
		_leader_summary_label.text = LEADER_SUMMARY_FMT % leader_name


func _update_detail_and_actions() -> void:
	var has_focus: bool = not String(_focused_id).is_empty()
	var in_party: bool = _party_ids.has(_focused_id)
	var party_index: int = _party_ids.find(_focused_id)
	var owned: bool = _owned_ids.has(str(_focused_id))
	var known: bool = _defs_by_id.has(str(_focused_id))

	if _detail_name_label != null:
		if not has_focus:
			_detail_name_label.text = "請選擇角色"
		elif known:
			_detail_name_label.text = (_defs_by_id[str(_focused_id)] as CharacterDefinition).get_display_name()
		else:
			_detail_name_label.text = "未知角色（%s）" % str(_focused_id)

	if _detail_status_label != null:
		if not has_focus:
			_detail_status_label.text = ""
		elif in_party:
			var parts: PackedStringArray = PackedStringArray(["隊伍中"])
			if party_index == 0:
				parts.append("領隊")
			if _focused_id == _representative_id:
				parts.append("代表角色")
			_detail_status_label.text = " · ".join(parts)
		elif owned:
			var st: String = "可加入"
			if _party_ids.size() >= PlayerProfile.PARTY_MAX_SIZE:
				st = MSG_FULL
			if _focused_id == _representative_id:
				st += " · 代表角色"
			_detail_status_label.text = st
		else:
			_detail_status_label.text = "未持有"

	var can_add: bool = has_focus and owned and known and not in_party and _party_ids.size() < PlayerProfile.PARTY_MAX_SIZE
	var can_remove: bool = has_focus and in_party and _party_ids.size() > PlayerProfile.PARTY_MIN_SIZE
	var can_left: bool = has_focus and in_party and party_index > 0
	var can_right: bool = has_focus and in_party and party_index >= 0 and party_index < _party_ids.size() - 1

	if _add_button != null:
		_add_button.disabled = not can_add
		_add_button.custom_minimum_size = Vector2(maxf(_add_button.custom_minimum_size.x, 96), 48)
	if _remove_button != null:
		_remove_button.disabled = not can_remove
		_remove_button.custom_minimum_size = Vector2(maxf(_remove_button.custom_minimum_size.x, 96), 48)
	if _move_left_button != null:
		_move_left_button.disabled = not can_left
		_move_left_button.custom_minimum_size = Vector2(maxf(_move_left_button.custom_minimum_size.x, 72), 48)
	if _move_right_button != null:
		_move_right_button.disabled = not can_right
		_move_right_button.custom_minimum_size = Vector2(maxf(_move_right_button.custom_minimum_size.x, 72), 48)
	if _back_button != null:
		_back_button.custom_minimum_size = Vector2(maxf(_back_button.custom_minimum_size.x, 96), 48)


func _maybe_show_migration_hint() -> void:
	if not is_instance_valid(PlayerData):
		return
	if PlayerData.is_profile_migration_pending():
		# Non-blocking hint; does not write disk.
		if _mutation_message_label != null and str(_mutation_message_label.text).is_empty():
			_set_mutation_message(MSG_MIGRATION_HINT)


func _refresh_party_ui_preserve_focus() -> void:
	_party_refresh_count_for_tests += 1
	var keep: StringName = _focused_id
	_sync_from_player_data()
	if _party_ids.has(keep) or _owned_ids.has(str(keep)):
		_focused_id = keep
	elif not _party_ids.is_empty():
		_focused_id = _party_ids[0]
	else:
		_focused_id = _pick_initial_focus()
	_rebuild_slots()
	_rebuild_roster()
	_update_summaries()
	_update_detail_and_actions()
	_refresh_columns()


func _on_player_profile_changed(_revision: int) -> void:
	if not _ready_done or not _configured:
		return
	_refresh_party_ui_preserve_focus()


func _on_slot_activated(character_id: StringName, _slot_index: int) -> void:
	_focused_id = character_id
	_set_mutation_message("")
	_sync_focus_visuals()
	_update_detail_and_actions()


func _on_roster_activated(character_id: StringName) -> void:
	_focused_id = character_id
	_set_mutation_message("")
	_sync_focus_visuals()
	_update_detail_and_actions()


func _sync_focus_visuals() -> void:
	for slot in _slot_nodes:
		if slot != null and is_instance_valid(slot) and slot.has_method("set_focused"):
			slot.call("set_focused", slot.call("get_character_id") == _focused_id)
	for id in _roster_cards.keys():
		var card: Object = _roster_cards[id]
		if card != null and is_instance_valid(card) and card.has_method("set_focused"):
			card.call("set_focused", id == _focused_id)


func _on_add_pressed() -> void:
	if String(_focused_id).is_empty():
		return
	if not is_instance_valid(PlayerData):
		_set_mutation_message(MSG_SAVE_FAIL)
		return
	var result: Dictionary = PlayerData.add_party_member(_focused_id)
	if not bool(result.get("ok", false)):
		_set_mutation_message(MSG_SAVE_FAIL if str(result.get("error", "")).find("full") < 0 else MSG_FULL)
		return
	if bool(result.get("changed", false)):
		_set_mutation_message(MSG_ADDED)
		party_member_added.emit(_focused_id)
	# UI rebuild via profile_changed only


func _on_remove_pressed() -> void:
	if String(_focused_id).is_empty():
		return
	if not is_instance_valid(PlayerData):
		_set_mutation_message(MSG_SAVE_FAIL)
		return
	var removing: StringName = _focused_id
	var idx: int = _party_ids.find(removing)
	# Pre-select fallback focus BEFORE mutation so the single profile_changed
	# rebuild highlights the surviving party member (not the removed roster card).
	var prior_focus: StringName = _focused_id
	if idx >= 0 and _party_ids.size() > 1:
		var provisional: Array[StringName] = []
		for id in _party_ids:
			if id != removing:
				provisional.append(id)
		if idx < provisional.size():
			_focused_id = provisional[idx]
		elif not provisional.is_empty():
			_focused_id = provisional[0]
	var result: Dictionary = PlayerData.remove_party_member(removing)
	if not bool(result.get("ok", false)):
		_focused_id = prior_focus
		_set_mutation_message(MSG_SAVE_FAIL)
		# No full rebuild on failure; keep badges as-is.
		return
	if bool(result.get("changed", false)):
		# Align with authoritative post-save party (defensive; should match provisional).
		var next_ids: Array = result.get("active_party_character_ids", []) as Array
		var still_valid: bool = false
		for item in next_ids:
			if item == _focused_id:
				still_valid = true
				break
		if not still_valid and not next_ids.is_empty():
			_focused_id = next_ids[0] as StringName
			# Light focus-only sync if provisional missed; does not rebuild tree again.
			_sync_focus_visuals()
			_update_detail_and_actions()
		_set_mutation_message(MSG_REMOVED)
		party_member_removed.emit(removing)


func _on_move_left_pressed() -> void:
	_move_focused(-1)


func _on_move_right_pressed() -> void:
	_move_focused(1)


func _move_focused(delta: int) -> void:
	if String(_focused_id).is_empty():
		return
	var idx: int = _party_ids.find(_focused_id)
	if idx < 0:
		return
	var target: int = idx + delta
	if not is_instance_valid(PlayerData):
		_set_mutation_message(MSG_SAVE_FAIL)
		return
	var keep: StringName = _focused_id
	var result: Dictionary = PlayerData.move_party_member(keep, target)
	if not bool(result.get("ok", false)):
		_set_mutation_message(MSG_SAVE_FAIL)
		return
	if bool(result.get("changed", false)):
		_focused_id = keep
		_set_mutation_message(MSG_MOVED)
		var ids: Array[StringName] = []
		for item in result.get("active_party_character_ids", []):
			ids.append(item as StringName)
		party_order_changed.emit(ids)


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
	if _roster_grid == null:
		return
	# Strict contract: narrow phones 2 columns; design-width (720) → exactly 4.
	var width: float = size.x
	if width <= 1.0 and _page_content != null:
		width = _page_content.size.x
	if width <= 1.0 and _page_scroll != null:
		width = _page_scroll.size.x
	var cols: int = 2
	if width >= ROSTER_WIDE_MIN_WIDTH:
		cols = 4
	_roster_grid.columns = cols


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


func get_party_ids() -> Array[StringName]:
	return _party_ids.duplicate()


func get_party_size() -> int:
	return _party_ids.size()


func get_leader_id() -> StringName:
	if _party_ids.is_empty():
		return &""
	return _party_ids[0]


func get_focused_id() -> StringName:
	return _focused_id


func get_roster_count() -> int:
	return _roster_cards.size()


func get_add_button() -> Button:
	return _add_button


func get_remove_button() -> Button:
	return _remove_button


func get_move_left_button() -> Button:
	return _move_left_button


func get_move_right_button() -> Button:
	return _move_right_button


func get_party_summary_text() -> String:
	if _party_summary_label == null:
		return ""
	return _party_summary_label.text


func get_leader_summary_text() -> String:
	if _leader_summary_label == null:
		return ""
	return _leader_summary_label.text


func get_mutation_message() -> String:
	if _mutation_message_label == null:
		return ""
	return _mutation_message_label.text


func get_detail_status_text() -> String:
	if _detail_status_label == null:
		return ""
	return _detail_status_label.text


func get_detail_name_text() -> String:
	if _detail_name_label == null:
		return ""
	return _detail_name_label.text


func get_roster_grid() -> GridContainer:
	return _roster_grid


func get_party_slots_container() -> Container:
	return _party_slots_container


func get_page_scroll() -> ScrollContainer:
	return _page_scroll


func get_detail_panel() -> PanelContainer:
	return _detail_panel


func get_grid_columns() -> int:
	if _roster_grid == null:
		return 0
	return _roster_grid.columns


## Scroll the page so target is visible (for narrow-viewport reachability).
func ensure_control_visible_for_test(control: Control) -> void:
	if _page_scroll == null or control == null or not is_instance_valid(control):
		return
	# Prefer ensure_control_visible when available (Godot 4 ScrollContainer).
	if _page_scroll.has_method("ensure_control_visible"):
		_page_scroll.ensure_control_visible(control)
		return
	var content: Control = _page_content
	if content == null:
		return
	var local_y: float = control.get_global_rect().position.y - content.get_global_rect().position.y
	var max_scroll: int = int(maxi(0.0, content.size.y - _page_scroll.size.y))
	_page_scroll.scroll_vertical = clampi(int(local_y - 8.0), 0, max_scroll)


func reset_party_refresh_count_for_tests() -> void:
	_party_refresh_count_for_tests = 0


func get_party_refresh_count_for_tests() -> int:
	return _party_refresh_count_for_tests


func focus_character_for_test(character_id: StringName) -> bool:
	if _party_ids.has(character_id) or _owned_ids.has(str(character_id)):
		_focused_id = character_id
		_sync_focus_visuals()
		_update_detail_and_actions()
		return true
	return false


func press_add_for_test() -> void:
	_on_add_pressed()


func press_remove_for_test() -> void:
	_on_remove_pressed()


func press_move_left_for_test() -> void:
	_on_move_left_pressed()


func press_move_right_for_test() -> void:
	_on_move_right_pressed()
