## Login shell: prefill from PlayerData, persist on valid submit, never auto-login.
extends Control

signal login_succeeded(player_name: String)

const MIN_LEN: int = 1
const MAX_LEN: int = 12
const INTERNAL_NAV_FAIL_MSG: String = "暫時無法開始遊戲，請再試一次"
const SAVE_FAIL_MSG: String = "無法儲存玩家資料，請再試一次"
const ROLLBACK_FAIL_MSG: String = "玩家資料回復失敗，請再試一次"

@onready var _title_label: Label = %TitleLabel
@onready var _name_input: LineEdit = %NameInput
@onready var _start_button: Button = %StartButton
@onready var _validation_label: Label = %ValidationLabel
@onready var _notice_label: Label = %NoticeLabel

var _signals_bound: bool = false
## Optional test hook: when valid, replaces NavigationState.navigate_to for lobby.
var _navigate_to_lobby_override: Callable = Callable()
var _last_rollback_ok: bool = true
var _last_rollback_disk_ok: bool = true


func _ready() -> void:
	AppState.set_phase(AppState.Phase.LOGIN)
	_title_label.text = "FeiBao"
	_name_input.max_length = MAX_LEN
	_name_input.placeholder_text = "玩家名稱"
	_start_button.text = "開始遊戲"
	_validation_label.text = ""
	_apply_player_data_notice()
	_prefill_saved_name()
	_bind_signals()
	_name_input.grab_focus()


func _apply_player_data_notice() -> void:
	if _notice_label == null:
		return
	var notice: String = PlayerData.get_user_notice()
	_notice_label.text = notice
	_notice_label.visible = not notice.is_empty()


func _prefill_saved_name() -> void:
	var saved: String = PlayerData.get_player_name()
	if saved.is_empty():
		return
	_name_input.text = saved
	# Prefill only — never auto-submit or auto-navigate.


func _bind_signals() -> void:
	if _signals_bound:
		return
	if not _start_button.pressed.is_connected(_on_start_pressed):
		_start_button.pressed.connect(_on_start_pressed)
	if not _name_input.text_submitted.is_connected(_on_text_submitted):
		_name_input.text_submitted.connect(_on_text_submitted)
	_signals_bound = true


func _on_start_pressed() -> void:
	submit_player_name(_name_input.text)


func _on_text_submitted(text: String) -> void:
	submit_player_name(text)


func validate_player_name(value: String) -> Dictionary:
	var normalized: String = value.strip_edges()
	if normalized.is_empty():
		return {
			"valid": false,
			"normalized": normalized,
			"error": "請輸入玩家名稱",
		}
	if normalized.length() < MIN_LEN:
		return {
			"valid": false,
			"normalized": normalized,
			"error": "玩家名稱至少需要 %d 個字元" % MIN_LEN,
		}
	if normalized.length() > MAX_LEN:
		return {
			"valid": false,
			"normalized": normalized,
			"error": "玩家名稱最多 %d 個字元" % MAX_LEN,
		}
	return {
		"valid": true,
		"normalized": normalized,
		"error": "",
	}


## Overridable navigation step (tests may inject failure via set_navigate_to_lobby_override).
func _navigate_to_lobby() -> bool:
	if _navigate_to_lobby_override.is_valid():
		return bool(_navigate_to_lobby_override.call())
	return NavigationState.navigate_to(NavigationState.SCREEN_LOBBY, true)


func set_navigate_to_lobby_override(callback: Callable) -> void:
	_navigate_to_lobby_override = callback


func clear_navigate_to_lobby_override() -> void:
	_navigate_to_lobby_override = Callable()


func submit_player_name(value: String) -> bool:
	_last_rollback_ok = true
	_last_rollback_disk_ok = true
	var result: Dictionary = validate_player_name(value)
	if not bool(result["valid"]):
		_validation_label.text = str(result["error"])
		return false

	var normalized: String = str(result["normalized"])

	# Capture full memory + primary/tmp/backup snapshot before any write.
	var cap: Dictionary = PlayerData.capture_persistence_transaction()
	if not bool(cap.get("ok", false)):
		_validation_label.text = SAVE_FAIL_MSG
		return false
	var transaction: Dictionary = cap.get("transaction", {}) as Dictionary

	# Persist first; only navigate after save succeeds.
	# save_text itself restores artifacts on internal write failure.
	var save_result: Dictionary = PlayerData.save_player_name(normalized)
	if not bool(save_result.get("ok", false)):
		_validation_label.text = SAVE_FAIL_MSG
		return false

	AppState.set_phase(AppState.Phase.LOGIN)

	var ok: bool = _navigate_to_lobby()
	if not ok:
		# Complete transaction rollback: profile, AppState, and all artifacts.
		var rb: Dictionary = PlayerData.rollback_persistence_transaction(transaction)
		_last_rollback_ok = bool(rb.get("ok", false))
		_last_rollback_disk_ok = bool(rb.get("disk_ok", false))
		if _last_rollback_ok and _last_rollback_disk_ok:
			_validation_label.text = INTERNAL_NAV_FAIL_MSG
		else:
			_validation_label.text = "%s（%s）" % [INTERNAL_NAV_FAIL_MSG, ROLLBACK_FAIL_MSG]
		push_error("LoginScreen: navigate_to lobby failed")
		return false

	_validation_label.text = ""
	login_succeeded.emit(normalized)
	return true


func get_name_input() -> LineEdit:
	return _name_input


func get_start_button() -> Button:
	return _start_button


func get_validation_message() -> String:
	return _validation_label.text


func get_notice_message() -> String:
	if _notice_label == null:
		return ""
	return _notice_label.text


func get_last_rollback_ok() -> bool:
	return _last_rollback_ok


func get_last_rollback_disk_ok() -> bool:
	return _last_rollback_disk_ok


func count_primary_buttons() -> int:
	return _count_buttons_recursive(self)


func _count_buttons_recursive(node: Node) -> int:
	var total: int = 0
	if node is Button:
		total += 1
	for child in node.get_children():
		total += _count_buttons_recursive(child)
	return total


func contains_forbidden_text(needle: String) -> bool:
	return _tree_contains_text(self, needle)


func _tree_contains_text(node: Node, needle: String) -> bool:
	if node is Label:
		if needle in (node as Label).text:
			return true
	if node is Button:
		if needle in (node as Button).text:
			return true
	if node is LineEdit:
		if needle in (node as LineEdit).placeholder_text:
			return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false
