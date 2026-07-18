## Dedicated battle session shell screen (0.9.0). No real combat.
extends Control

signal back_requested
signal leave_requested

const MSG_SHELL: String = "戰鬥系統殼層 · 尚無真實戰鬥"
const MSG_NO_SESSION: String = "沒有有效的戰鬥工作階段"
const MSG_LEAVE: String = "離開戰鬥"
const SEED_HINT: String = "本頁為戰鬥工作階段殼層，非正式戰鬥。"
const PARTY_LINE_FMT: String = "%d. %s%s"
const LEADER_MARK: String = "（領隊）"
const STAGE_LINE_FMT: String = "關卡：%s"
const AREA_LINE_FMT: String = "區域：%s"
const SUMMARY_LINE_FMT: String = "%s"
const PARTY_HEADER_FMT: String = "出戰隊伍 %d 人"

@onready var _title_label: Label = %TitleLabel
@onready var _back_button: Button = %BackButton
@onready var _leave_button: Button = %LeaveButton
@onready var _seed_hint_label: Label = %SeedHintLabel
@onready var _body_scroll: ScrollContainer = %BodyScroll
@onready var _body_content: Control = %BodyContent
@onready var _stage_name_label: Label = %StageNameLabel
@onready var _area_name_label: Label = %AreaNameLabel
@onready var _stage_summary_label: Label = %StageSummaryLabel
@onready var _shell_status_label: Label = %ShellStatusLabel
@onready var _party_header_label: Label = %PartyHeaderLabel
@onready var _party_list_label: Label = %PartyListLabel
@onready var _error_label: Label = %ErrorLabel

var _screen_id: StringName = &""
var _configured: bool = false
var _ready_done: bool = false
var _signals_bound: bool = false
var _session_signals_bound: bool = false
var _session_ok: bool = false
var _leave_count_for_tests: int = 0


func _ready() -> void:
	_ready_done = true
	_bind_signals()
	_bind_session_signals()
	AppState.set_phase(AppState.Phase.MODULE)
	if _configured:
		_reload_all()
	elif NavigationState.get_current_screen() == ScreenRegistry.SCREEN_BATTLE:
		configure_screen(ScreenRegistry.SCREEN_BATTLE)


func _exit_tree() -> void:
	_unbind_session_signals()


func _bind_signals() -> void:
	if _signals_bound:
		return
	if _back_button != null and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _leave_button != null and not _leave_button.pressed.is_connected(_on_leave_pressed):
		_leave_button.pressed.connect(_on_leave_pressed)
	_signals_bound = true


func _bind_session_signals() -> void:
	if is_instance_valid(BattleSession) and not _session_signals_bound:
		if not BattleSession.session_changed.is_connected(_on_session_changed):
			BattleSession.session_changed.connect(_on_session_changed)
		_session_signals_bound = true


func _unbind_session_signals() -> void:
	if is_instance_valid(BattleSession) and _session_signals_bound:
		if BattleSession.session_changed.is_connected(_on_session_changed):
			BattleSession.session_changed.disconnect(_on_session_changed)
	_session_signals_bound = false


func configure_screen(screen_id: StringName) -> bool:
	if screen_id != ScreenRegistry.SCREEN_BATTLE:
		return false
	_screen_id = screen_id
	_configured = true
	AppState.set_phase(AppState.Phase.MODULE)
	if _ready_done:
		_bind_signals()
		_bind_session_signals()
		_reload_all()
	return true


func _reload_all() -> void:
	if _title_label != null:
		_title_label.text = "戰鬥"
	if _back_button != null:
		_back_button.text = "返回"
		_back_button.custom_minimum_size = Vector2(maxf(_back_button.custom_minimum_size.x, 96), 48)
	if _leave_button != null:
		_leave_button.text = MSG_LEAVE
		_leave_button.custom_minimum_size = Vector2(maxf(_leave_button.custom_minimum_size.x, 120), 48)
	if _seed_hint_label != null:
		_seed_hint_label.text = SEED_HINT
	if _shell_status_label != null:
		_shell_status_label.text = MSG_SHELL
	_hide_error()
	_apply_session_ui()


func _apply_session_ui() -> void:
	_session_ok = is_instance_valid(BattleSession) and BattleSession.has_active_session()
	if not _session_ok:
		if _stage_name_label != null:
			_stage_name_label.text = ""
		if _area_name_label != null:
			_area_name_label.text = ""
		if _stage_summary_label != null:
			_stage_summary_label.text = ""
		if _party_header_label != null:
			_party_header_label.text = ""
		if _party_list_label != null:
			_party_list_label.text = ""
		_show_error(MSG_NO_SESSION)
		if _leave_button != null:
			_leave_button.disabled = false
		return

	_hide_error()
	if _stage_name_label != null:
		_stage_name_label.text = STAGE_LINE_FMT % BattleSession.get_stage_display_name()
	if _area_name_label != null:
		_area_name_label.text = AREA_LINE_FMT % BattleSession.get_area_display_name()
	if _stage_summary_label != null:
		_stage_summary_label.text = SUMMARY_LINE_FMT % BattleSession.get_stage_summary()
	var party_ids: Array[StringName] = BattleSession.get_party_character_ids()
	var names: Array[String] = BattleSession.get_party_display_names()
	var leader_id: StringName = BattleSession.get_leader_character_id()
	if _party_header_label != null:
		_party_header_label.text = PARTY_HEADER_FMT % party_ids.size()
	if _party_list_label != null:
		var lines: PackedStringArray = PackedStringArray()
		for i in party_ids.size():
			var nm: String = names[i] if i < names.size() else str(party_ids[i])
			var mark: String = LEADER_MARK if party_ids[i] == leader_id else ""
			lines.append(PARTY_LINE_FMT % [i + 1, nm, mark])
		_party_list_label.text = "\n".join(lines)
	if _leave_button != null:
		_leave_button.disabled = false


func _on_session_changed(_stage_id: StringName, _active: bool) -> void:
	if not _ready_done or not _configured:
		return
	_apply_session_ui()


func _on_back_pressed() -> void:
	request_leave()


func _on_leave_pressed() -> void:
	request_leave()


## Clear memory session then leave via history/fallback (adventure).
func request_leave() -> bool:
	_leave_count_for_tests += 1
	if is_instance_valid(BattleSession) and BattleSession.has_active_session():
		BattleSession.clear_session()
	var ok: bool = NavigationState.go_back_or_fallback()
	if ok:
		leave_requested.emit()
		back_requested.emit()
	return ok


func _show_error(message: String) -> void:
	if _error_label != null:
		_error_label.visible = true
		_error_label.text = message


func _hide_error() -> void:
	if _error_label != null:
		_error_label.visible = false


func get_screen_id() -> StringName:
	return _screen_id


func get_back_button() -> Button:
	return _back_button


func get_leave_button() -> Button:
	return _leave_button


func get_body_scroll() -> ScrollContainer:
	return _body_scroll


func get_stage_name_text() -> String:
	if _stage_name_label == null:
		return ""
	return _stage_name_label.text


func get_area_name_text() -> String:
	if _area_name_label == null:
		return ""
	return _area_name_label.text


func get_stage_summary_text() -> String:
	if _stage_summary_label == null:
		return ""
	return _stage_summary_label.text


func get_party_list_text() -> String:
	if _party_list_label == null:
		return ""
	return _party_list_label.text


func get_party_header_text() -> String:
	if _party_header_label == null:
		return ""
	return _party_header_label.text


func get_shell_status_text() -> String:
	if _shell_status_label == null:
		return ""
	return _shell_status_label.text


func is_error_state_visible() -> bool:
	return _error_label != null and _error_label.visible


func get_error_text() -> String:
	if _error_label == null:
		return ""
	return _error_label.text


func is_session_ok() -> bool:
	return _session_ok


func get_leave_count_for_tests() -> int:
	return _leave_count_for_tests


func reset_leave_count_for_tests() -> void:
	_leave_count_for_tests = 0


func press_leave_for_test() -> void:
	_on_leave_pressed()


func ensure_control_visible_for_test(control: Control) -> void:
	if _body_scroll == null or control == null or not is_instance_valid(control):
		return
	if _body_scroll.has_method("ensure_control_visible"):
		_body_scroll.ensure_control_visible(control)
