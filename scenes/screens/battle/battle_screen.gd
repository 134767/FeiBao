## Dedicated battle session shell screen (0.9.0). No real combat.
## Renders BattleState session snapshot only — not live PlayerData as truth.
extends Control

signal back_requested
signal leave_requested

const MSG_SHELL: String = "戰鬥系統殼層 · 開發樣本 · 尚無真實戰鬥"
const MSG_NO_SESSION: String = "沒有有效的戰鬥工作階段"
const MSG_CHAR_MISSING: String = "出戰角色定義缺失"
const MSG_LEAVE: String = "離開戰鬥"
const SEED_HINT: String = "本頁為戰鬥工作階段殼層，非正式戰鬥。"
const PARTY_LINE_FMT: String = "%d. %s%s"
const LEADER_MARK: String = "（領隊）"
const STAGE_LINE_FMT: String = "關卡：%s"
const STAGE_NUM_FMT: String = "關卡編號：%d"
const AREA_LINE_FMT: String = "區域：%s"
const SUMMARY_LINE_FMT: String = "%s"
const PARTY_HEADER_FMT: String = "出戰隊伍 %d 人"
const LEADER_LINE_FMT: String = "隊長：%s"

@onready var _title_label: Label = %TitleLabel
@onready var _back_button: Button = %BackButton
@onready var _leave_button: Button = %LeaveButton
@onready var _seed_hint_label: Label = %SeedHintLabel
@onready var _body_scroll: ScrollContainer = %BodyScroll
@onready var _body_content: Control = %BodyContent
@onready var _stage_name_label: Label = %StageNameLabel
@onready var _stage_number_label: Label = %StageNumberLabel
@onready var _area_name_label: Label = %AreaNameLabel
@onready var _stage_summary_label: Label = %StageSummaryLabel
@onready var _shell_status_label: Label = %ShellStatusLabel
@onready var _leader_label: Label = %LeaderLabel
@onready var _party_header_label: Label = %PartyHeaderLabel
@onready var _party_list_label: Label = %PartyListLabel
@onready var _error_label: Label = %ErrorLabel

var _screen_id: StringName = &""
var _configured: bool = false
var _ready_done: bool = false
var _signals_bound: bool = false
var _session_signals_bound: bool = false
var _session_ok: bool = false
## Transaction lock for leave: set before clear/nav; held until exit on success; unlocked on nav failure.
var _leave_in_progress: bool = false
var _leave_count_for_tests: int = 0
var _leave_nav_result_override_for_tests: Variant = null


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
	# Instance-local cleanup only — do not touch BattleState, navigate, or emit leave signals.
	_leave_in_progress = false


func _bind_signals() -> void:
	if _signals_bound:
		return
	if _back_button != null and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _leave_button != null and not _leave_button.pressed.is_connected(_on_leave_pressed):
		_leave_button.pressed.connect(_on_leave_pressed)
	_signals_bound = true


func _bind_session_signals() -> void:
	if is_instance_valid(BattleState) and not _session_signals_bound:
		if not BattleState.session_changed.is_connected(_on_session_changed):
			BattleState.session_changed.connect(_on_session_changed)
		_session_signals_bound = true


func _unbind_session_signals() -> void:
	if is_instance_valid(BattleState) and _session_signals_bound:
		if BattleState.session_changed.is_connected(_on_session_changed):
			BattleState.session_changed.disconnect(_on_session_changed)
	_session_signals_bound = false


func configure_screen(screen_id: StringName) -> bool:
	if screen_id != ScreenRegistry.SCREEN_BATTLE:
		return false
	# Never clear an in-flight leave transaction — reconfigure must not unlock the guard.
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
		_back_button.focus_mode = Control.FOCUS_ALL
	if _leave_button != null:
		_leave_button.text = MSG_LEAVE
		_leave_button.custom_minimum_size = Vector2(maxf(_leave_button.custom_minimum_size.x, 120), 48)
		_leave_button.focus_mode = Control.FOCUS_ALL
	if _seed_hint_label != null:
		_seed_hint_label.text = SEED_HINT
	if _shell_status_label != null:
		_shell_status_label.text = MSG_SHELL
	_hide_error()
	_apply_session_ui()


func _apply_session_ui() -> void:
	_session_ok = is_instance_valid(BattleState) and BattleState.has_active_session()
	if not _session_ok:
		_clear_content_labels()
		_show_error(MSG_NO_SESSION)
		_sync_leave_controls()
		return

	var party_ids: Array[StringName] = BattleState.get_party_character_ids()
	var leader_id: StringName = BattleState.get_leader_character_id()
	var name_result: Dictionary = _resolve_party_display_names(party_ids)
	if not bool(name_result.get("ok", false)):
		_clear_content_labels()
		_show_error(str(name_result.get("error", MSG_CHAR_MISSING)))
		_session_ok = false
		_sync_leave_controls()
		return

	_hide_error()
	var names: Array[String] = []
	var raw_names: Variant = name_result.get("names", [])
	if raw_names is Array:
		for n in raw_names as Array:
			names.append(str(n))
	if _stage_name_label != null:
		_stage_name_label.text = STAGE_LINE_FMT % BattleState.get_stage_display_name()
	if _stage_number_label != null:
		_stage_number_label.text = STAGE_NUM_FMT % BattleState.get_stage_number()
	if _area_name_label != null:
		_area_name_label.text = AREA_LINE_FMT % BattleState.get_area_display_name()
	if _stage_summary_label != null:
		_stage_summary_label.text = SUMMARY_LINE_FMT % BattleState.get_stage_summary()
	if _leader_label != null:
		var leader_name: String = ""
		for i in party_ids.size():
			if party_ids[i] == leader_id and i < names.size():
				leader_name = names[i]
				break
		_leader_label.text = LEADER_LINE_FMT % leader_name
	if _party_header_label != null:
		_party_header_label.text = PARTY_HEADER_FMT % party_ids.size()
	if _party_list_label != null:
		var lines: PackedStringArray = PackedStringArray()
		for i in party_ids.size():
			var nm: String = names[i] if i < names.size() else ""
			var mark: String = LEADER_MARK if party_ids[i] == leader_id else ""
			lines.append(PARTY_LINE_FMT % [i + 1, nm, mark])
		_party_list_label.text = "\n".join(lines)
	_sync_leave_controls()


## Keep leave/back controls disabled while a leave transaction is in progress.
func _sync_leave_controls() -> void:
	var enabled: bool = not _leave_in_progress
	if _back_button != null:
		_back_button.disabled = not enabled
	if _leave_button != null:
		_leave_button.disabled = not enabled


func _clear_content_labels() -> void:
	if _stage_name_label != null:
		_stage_name_label.text = ""
	if _stage_number_label != null:
		_stage_number_label.text = ""
	if _area_name_label != null:
		_area_name_label.text = ""
	if _stage_summary_label != null:
		_stage_summary_label.text = ""
	if _leader_label != null:
		_leader_label.text = ""
	if _party_header_label != null:
		_party_header_label.text = ""
	if _party_list_label != null:
		_party_list_label.text = ""


## Resolve catalog display names; fail closed if any party id is missing (never use raw id as formal name).
func _resolve_party_display_names(party_ids: Array[StringName]) -> Dictionary:
	var names: Array[String] = []
	var cat: Dictionary = CharacterCatalog.load_default()
	if not bool(cat.get("ok", false)):
		return {"ok": false, "error": MSG_CHAR_MISSING, "names": names}
	var by_id: Dictionary = {}
	for item in cat.get("characters", []):
		if item is CharacterDefinition:
			var d: CharacterDefinition = item as CharacterDefinition
			by_id[d.get_id()] = d.get_display_name()
	for id in party_ids:
		if not by_id.has(id):
			return {"ok": false, "error": MSG_CHAR_MISSING, "names": []}
		var dn: String = str(by_id[id])
		if dn.is_empty():
			return {"ok": false, "error": MSG_CHAR_MISSING, "names": []}
		names.append(dn)
	return {"ok": true, "error": "", "names": names}


func _on_session_changed(_stage_id: StringName, _active: bool) -> void:
	if not _ready_done or not _configured:
		return
	_apply_session_ui()


func _on_back_pressed() -> void:
	request_leave()


func _on_leave_pressed() -> void:
	request_leave()


## Transaction: re-entrancy guard → snapshot → clear → navigate; restore session if navigation fails.
## Successful leave keeps the lock until this BattleScreen instance leaves the SceneTree.
func request_leave() -> bool:
	_leave_count_for_tests += 1
	if _leave_in_progress:
		# Reject duplicate input: no second clear, navigate, or signal emit.
		return false

	# Lock before any session clear or navigation so concurrent presses cannot re-enter.
	_leave_in_progress = true
	_sync_leave_controls()

	if not is_instance_valid(BattleState):
		var nav_only_ok: bool = _navigate_leave()
		if not nav_only_ok:
			_leave_in_progress = false
			_sync_leave_controls()
			return false
		leave_requested.emit()
		back_requested.emit()
		return true

	var prior: Dictionary = BattleState.capture_session_snapshot()
	if BattleState.has_active_session():
		BattleState.clear_session()

	var nav_ok: bool = _navigate_leave()
	if not nav_ok:
		BattleState.restore_session_snapshot(prior)
		_leave_in_progress = false
		_sync_leave_controls()
		_apply_session_ui()
		return false

	leave_requested.emit()
	back_requested.emit()
	# Success: retain lock so a still-alive node cannot fire a second transition.
	return true


func _navigate_leave() -> bool:
	if _leave_nav_result_override_for_tests is bool:
		return bool(_leave_nav_result_override_for_tests)
	return NavigationState.go_back_or_fallback()


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
	return _stage_name_label.text if _stage_name_label != null else ""


func get_stage_number_text() -> String:
	return _stage_number_label.text if _stage_number_label != null else ""


func get_area_name_text() -> String:
	return _area_name_label.text if _area_name_label != null else ""


func get_stage_summary_text() -> String:
	return _stage_summary_label.text if _stage_summary_label != null else ""


func get_leader_text() -> String:
	return _leader_label.text if _leader_label != null else ""


func get_party_list_text() -> String:
	return _party_list_label.text if _party_list_label != null else ""


func get_party_header_text() -> String:
	return _party_header_label.text if _party_header_label != null else ""


func get_shell_status_text() -> String:
	return _shell_status_label.text if _shell_status_label != null else ""


func is_error_state_visible() -> bool:
	return _error_label != null and _error_label.visible


func get_error_text() -> String:
	return _error_label.text if _error_label != null else ""


func is_session_ok() -> bool:
	return _session_ok


func get_leave_count_for_tests() -> int:
	return _leave_count_for_tests


func reset_leave_count_for_tests() -> void:
	_leave_count_for_tests = 0


func is_leave_in_progress_for_tests() -> bool:
	return _leave_in_progress


func press_leave_for_test() -> void:
	_on_leave_pressed()


func press_back_for_test() -> void:
	_on_back_pressed()


func set_leave_nav_result_override_for_tests(ok: bool) -> void:
	_leave_nav_result_override_for_tests = ok


func clear_leave_nav_result_override_for_tests() -> void:
	_leave_nav_result_override_for_tests = null


func ensure_control_visible_for_test(control: Control) -> void:
	if _body_scroll == null or control == null or not is_instance_valid(control):
		return
	if _body_scroll.has_method("ensure_control_visible"):
		_body_scroll.ensure_control_visible(control)
