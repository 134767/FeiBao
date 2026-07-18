## Battle board + turn-loop screen (1.0.0). Session from BattleState; board truth from BattleRuntime.
extends Control

signal back_requested
signal leave_requested

const MSG_SHELL: String = "開發樣本：目前僅有盤面與回合流程"
const MSG_NO_SESSION: String = "沒有有效的戰鬥工作階段"
const MSG_NO_RUNTIME: String = "沒有有效的戰鬥盤面"
const MSG_CHAR_MISSING: String = "出戰角色定義缺失"
const MSG_LEAVE: String = "離開戰鬥"
const SEED_HINT: String = "本頁為戰鬥盤面開發樣本，非正式戰鬥內容。"
const PARTY_LINE_FMT: String = "%d. %s%s"
const LEADER_MARK: String = "（領隊）"
const STAGE_LINE_FMT: String = "關卡：%s"
const STAGE_NUM_FMT: String = "關卡編號：%d"
const AREA_LINE_FMT: String = "區域：%s"
const SUMMARY_LINE_FMT: String = "%s"
const PARTY_HEADER_FMT: String = "出戰隊伍 %d 人"
const LEADER_LINE_FMT: String = "隊長：%s"
const TURN_FMT: String = "回合：%d"
const MATCH_FMT: String = "上次消除：%d"
const CASCADE_FMT: String = "上次連鎖：%d"
const HINT_IDLE: String = "點選相鄰兩格交換；同格再點取消"
const CELL_MIN: float = 48.0

const ORB_COLORS: Dictionary = {
	BattleOrbKind.EMBER: Color(0.86, 0.32, 0.22),
	BattleOrbKind.TIDE: Color(0.22, 0.48, 0.86),
	BattleOrbKind.LEAF: Color(0.28, 0.68, 0.34),
	BattleOrbKind.LIGHT: Color(0.90, 0.82, 0.28),
	BattleOrbKind.SHADOW: Color(0.42, 0.30, 0.62),
}

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
@onready var _turn_label: Label = %TurnLabel
@onready var _match_label: Label = %MatchLabel
@onready var _cascade_label: Label = %CascadeLabel
@onready var _hint_label: Label = %HintLabel
@onready var _mutation_label: Label = %MutationLabel
@onready var _board_grid: GridContainer = %BoardGrid
@onready var _error_label: Label = %ErrorLabel

var _screen_id: StringName = &""
var _configured: bool = false
var _ready_done: bool = false
var _signals_bound: bool = false
var _session_signals_bound: bool = false
var _runtime_signals_bound: bool = false
var _session_ok: bool = false
var _runtime_ok: bool = false
var _leave_in_progress: bool = false
var _leave_count_for_tests: int = 0
var _leave_nav_result_override_for_tests: Variant = null
var _cell_buttons: Array[Button] = []
var _cell_callbacks: Array[Callable] = []


func _ready() -> void:
	_ready_done = true
	_bind_signals()
	_bind_session_signals()
	_bind_runtime_signals()
	AppState.set_phase(AppState.Phase.MODULE)
	if _configured:
		_reload_all()
	elif NavigationState.get_current_screen() == ScreenRegistry.SCREEN_BATTLE:
		configure_screen(ScreenRegistry.SCREEN_BATTLE)


func _exit_tree() -> void:
	_unbind_session_signals()
	_unbind_runtime_signals()
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


func _bind_runtime_signals() -> void:
	if is_instance_valid(BattleRuntime) and not _runtime_signals_bound:
		if not BattleRuntime.board_changed.is_connected(_on_runtime_board_changed):
			BattleRuntime.board_changed.connect(_on_runtime_board_changed)
		if not BattleRuntime.runtime_changed.is_connected(_on_runtime_changed):
			BattleRuntime.runtime_changed.connect(_on_runtime_changed)
		_runtime_signals_bound = true


func _unbind_runtime_signals() -> void:
	if is_instance_valid(BattleRuntime) and _runtime_signals_bound:
		if BattleRuntime.board_changed.is_connected(_on_runtime_board_changed):
			BattleRuntime.board_changed.disconnect(_on_runtime_board_changed)
		if BattleRuntime.runtime_changed.is_connected(_on_runtime_changed):
			BattleRuntime.runtime_changed.disconnect(_on_runtime_changed)
	_runtime_signals_bound = false


func configure_screen(screen_id: StringName) -> bool:
	if screen_id != ScreenRegistry.SCREEN_BATTLE:
		return false
	_screen_id = screen_id
	_configured = true
	AppState.set_phase(AppState.Phase.MODULE)
	if _ready_done:
		_bind_signals()
		_bind_session_signals()
		_bind_runtime_signals()
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
	if _hint_label != null:
		_hint_label.text = HINT_IDLE
	_hide_error()
	_ensure_board_cells()
	_apply_session_ui()
	_apply_runtime_ui()


func _ensure_board_cells() -> void:
	if _board_grid == null:
		return
	_board_grid.columns = BattleBoardModel.WIDTH
	# Rebuild only if count wrong (idempotent configure).
	if _cell_buttons.size() == BattleBoardModel.CELL_COUNT and _board_grid.get_child_count() == BattleBoardModel.CELL_COUNT:
		return
	for c in _board_grid.get_children():
		_board_grid.remove_child(c)
		c.queue_free()
	_cell_buttons.clear()
	_cell_callbacks.clear()
	for i in BattleBoardModel.CELL_COUNT:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(CELL_MIN, CELL_MIN)
		btn.focus_mode = Control.FOCUS_ALL
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.clip_text = true
		var xy: Vector2i = BattleBoardModel.xy_of(i)
		var cb := _make_cell_callback(xy.x, xy.y)
		btn.pressed.connect(cb)
		_board_grid.add_child(btn)
		_cell_buttons.append(btn)
		_cell_callbacks.append(cb)
	_wire_focus_neighbors()


func _make_cell_callback(x: int, y: int) -> Callable:
	return func() -> void:
		_on_cell_pressed(x, y)


func _wire_focus_neighbors() -> void:
	for y in BattleBoardModel.HEIGHT:
		for x in BattleBoardModel.WIDTH:
			var idx: int = BattleBoardModel.index_of(x, y)
			var btn: Button = _cell_buttons[idx]
			if x > 0:
				btn.focus_neighbor_left = btn.get_path_to(_cell_buttons[BattleBoardModel.index_of(x - 1, y)])
			if x < BattleBoardModel.WIDTH - 1:
				btn.focus_neighbor_right = btn.get_path_to(_cell_buttons[BattleBoardModel.index_of(x + 1, y)])
			if y > 0:
				btn.focus_neighbor_top = btn.get_path_to(_cell_buttons[BattleBoardModel.index_of(x, y - 1)])
			if y < BattleBoardModel.HEIGHT - 1:
				btn.focus_neighbor_bottom = btn.get_path_to(_cell_buttons[BattleBoardModel.index_of(x, y + 1)])


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


func _apply_runtime_ui() -> void:
	_runtime_ok = is_instance_valid(BattleRuntime) and BattleRuntime.has_active_runtime()
	if not _runtime_ok:
		if _session_ok:
			_show_error(MSG_NO_RUNTIME)
		_paint_empty_board()
		_update_status_labels()
		_set_board_input_enabled(false)
		return

	if _error_label != null and _error_label.text == MSG_NO_RUNTIME:
		_hide_error()
	_paint_board_from_runtime()
	_update_status_labels()
	var phase: StringName = BattleRuntime.get_phase()
	var can_input: bool = (
		not _leave_in_progress
		and phase != BattleRuntime.PHASE_RESOLVING
		and phase != BattleRuntime.PHASE_INACTIVE
	)
	_set_board_input_enabled(can_input)
	if _mutation_label != null:
		var msg: String = BattleRuntime.get_last_message()
		_mutation_label.text = msg
		_mutation_label.visible = not msg.is_empty()


func _paint_empty_board() -> void:
	_ensure_board_cells()
	for i in _cell_buttons.size():
		var btn: Button = _cell_buttons[i]
		btn.text = "·"
		btn.disabled = true
		btn.modulate = Color(0.7, 0.7, 0.7, 1)


func _paint_board_from_runtime() -> void:
	_ensure_board_cells()
	var cells: Array[StringName] = BattleRuntime.get_board_cells()
	var selected: Vector2i = BattleRuntime.get_selected_cell()
	for i in BattleBoardModel.CELL_COUNT:
		if i >= _cell_buttons.size():
			break
		var btn: Button = _cell_buttons[i]
		var xy: Vector2i = BattleBoardModel.xy_of(i)
		var kind: StringName = cells[i] if i < cells.size() else BattleOrbKind.EMPTY
		var symbol: String = BattleOrbKind.get_symbol(kind)
		var dname: String = BattleOrbKind.get_display_name(kind)
		btn.text = symbol
		btn.tooltip_text = "%s (%d,%d)" % [dname, xy.x, xy.y]
		btn.modulate = ORB_COLORS.get(kind, Color.WHITE) as Color
		var is_sel: bool = selected.x == xy.x and selected.y == xy.y
		if is_sel:
			btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			btn.add_theme_constant_override("outline_size", 4)
			btn.text = "[%s]" % symbol
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_color_override("font_outline_color")
			btn.remove_theme_constant_override("outline_size")


func _update_status_labels() -> void:
	var turn: int = 0
	var match_n: int = 0
	var cascade_n: int = 0
	if is_instance_valid(BattleRuntime) and BattleRuntime.has_active_runtime():
		turn = BattleRuntime.get_turn_count()
		match_n = BattleRuntime.get_last_match_count()
		cascade_n = BattleRuntime.get_last_cascade_count()
	if _turn_label != null:
		_turn_label.text = TURN_FMT % turn
	if _match_label != null:
		_match_label.text = MATCH_FMT % match_n
	if _cascade_label != null:
		_cascade_label.text = CASCADE_FMT % cascade_n


func _set_board_input_enabled(enabled: bool) -> void:
	for btn in _cell_buttons:
		btn.disabled = not enabled


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
	_apply_runtime_ui()


func _on_runtime_board_changed() -> void:
	if not _ready_done or not _configured:
		return
	_apply_runtime_ui()


func _on_runtime_changed(_active: bool) -> void:
	if not _ready_done or not _configured:
		return
	_apply_runtime_ui()


func _on_cell_pressed(x: int, y: int) -> void:
	if _leave_in_progress:
		return
	if not is_instance_valid(BattleRuntime) or not BattleRuntime.has_active_runtime():
		return
	BattleRuntime.select_cell(x, y)
	_apply_runtime_ui()


func _on_back_pressed() -> void:
	request_leave()


func _on_leave_pressed() -> void:
	request_leave()


## Leave: guard → capture runtime+state → clear runtime → clear state → navigate; restore on failure.
func request_leave() -> bool:
	_leave_count_for_tests += 1
	if _leave_in_progress:
		return false

	_leave_in_progress = true
	_sync_leave_controls()
	_set_board_input_enabled(false)

	var prior_runtime: Dictionary = {}
	var prior_state: Dictionary = {}
	if is_instance_valid(BattleRuntime):
		prior_runtime = BattleRuntime.capture_runtime_snapshot()
	if is_instance_valid(BattleState):
		prior_state = BattleState.capture_session_snapshot()

	if is_instance_valid(BattleRuntime) and BattleRuntime.has_active_runtime():
		BattleRuntime.clear_runtime()
	if is_instance_valid(BattleState) and BattleState.has_active_session():
		BattleState.clear_session()

	var nav_ok: bool = _navigate_leave()
	if not nav_ok:
		# Restore state first so runtime binding validation can succeed.
		if is_instance_valid(BattleState) and not prior_state.is_empty():
			BattleState.restore_session_snapshot(prior_state)
		if is_instance_valid(BattleRuntime) and not prior_runtime.is_empty():
			BattleRuntime.restore_runtime_snapshot(prior_runtime)
		_leave_in_progress = false
		_sync_leave_controls()
		_apply_session_ui()
		_apply_runtime_ui()
		return false

	leave_requested.emit()
	back_requested.emit()
	return true


func _navigate_leave() -> bool:
	if _leave_nav_result_override_for_tests is bool:
		return bool(_leave_nav_result_override_for_tests)
	return NavigationState.go_back_or_fallback()


func _sync_leave_controls() -> void:
	var enabled: bool = not _leave_in_progress
	if _back_button != null:
		_back_button.disabled = not enabled
	if _leave_button != null:
		_leave_button.disabled = not enabled


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


func get_board_grid() -> GridContainer:
	return _board_grid


func get_cell_button(x: int, y: int) -> Button:
	if not BattleBoardModel.in_bounds(x, y):
		return null
	var idx: int = BattleBoardModel.index_of(x, y)
	if idx < 0 or idx >= _cell_buttons.size():
		return null
	return _cell_buttons[idx]


func get_cell_buttons() -> Array[Button]:
	return _cell_buttons.duplicate()


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


func get_turn_text() -> String:
	return _turn_label.text if _turn_label != null else ""


func get_match_text() -> String:
	return _match_label.text if _match_label != null else ""


func get_cascade_text() -> String:
	return _cascade_label.text if _cascade_label != null else ""


func get_mutation_text() -> String:
	return _mutation_label.text if _mutation_label != null else ""


func is_error_state_visible() -> bool:
	return _error_label != null and _error_label.visible


func get_error_text() -> String:
	return _error_label.text if _error_label != null else ""


func is_session_ok() -> bool:
	return _session_ok


func is_runtime_ok() -> bool:
	return _runtime_ok


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


func press_cell_for_test(x: int, y: int) -> void:
	_on_cell_pressed(x, y)


func set_leave_nav_result_override_for_tests(ok: bool) -> void:
	_leave_nav_result_override_for_tests = ok


func clear_leave_nav_result_override_for_tests() -> void:
	_leave_nav_result_override_for_tests = null


func ensure_control_visible_for_test(control: Control) -> void:
	if _body_scroll == null or control == null or not is_instance_valid(control):
		return
	if _body_scroll.has_method("ensure_control_visible"):
		_body_scroll.ensure_control_visible(control)
