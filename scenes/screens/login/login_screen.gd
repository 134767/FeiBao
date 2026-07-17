## Login shell: single "開始遊戲" action, in-memory player name only.
extends Control

signal login_succeeded(player_name: String)

const MIN_LEN: int = 1
const MAX_LEN: int = 12

@onready var _title_label: Label = %TitleLabel
@onready var _name_input: LineEdit = %NameInput
@onready var _start_button: Button = %StartButton
@onready var _validation_label: Label = %ValidationLabel

var _signals_bound: bool = false


func _ready() -> void:
	AppState.set_phase(AppState.Phase.LOGIN)
	_title_label.text = "FeiBao"
	_name_input.max_length = MAX_LEN
	_name_input.placeholder_text = "玩家名稱"
	_start_button.text = "開始遊戲"
	_validation_label.text = ""
	_bind_signals()
	_name_input.grab_focus()


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


func submit_player_name(value: String) -> bool:
	var result: Dictionary = validate_player_name(value)
	if not bool(result["valid"]):
		_validation_label.text = str(result["error"])
		return false

	var normalized: String = str(result["normalized"])
	AppState.set_player_name(normalized)
	AppState.set_phase(AppState.Phase.LOGIN)
	_validation_label.text = ""
	login_succeeded.emit(normalized)
	var ok: bool = NavigationState.navigate_to(NavigationState.SCREEN_LOBBY, true)
	if not ok:
		push_error("LoginScreen: navigate_to lobby failed")
		return false
	return true


func get_name_input() -> LineEdit:
	return _name_input


func get_start_button() -> Button:
	return _start_button


func get_validation_message() -> String:
	return _validation_label.text


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
