## Minimal architecture foundation UI — no gameplay, no external art.
extends Control

@onready var _app_name_label: Label = %AppNameLabel
@onready var _version_label: Label = %VersionLabel
@onready var _title_label: Label = %TitleLabel
@onready var _runtime_label: Label = %RuntimeLabel
@onready var _status_label: Label = %StatusLabel
@onready var _smoke_button: Button = %SmokeTestButton


func _ready() -> void:
	_populate_labels()
	if not _smoke_button.pressed.is_connected(_on_smoke_test_pressed):
		_smoke_button.pressed.connect(_on_smoke_test_pressed)


func _populate_labels() -> void:
	_app_name_label.text = GameConfig.get_app_name()
	_version_label.text = "v%s" % GameConfig.get_app_version()
	_title_label.text = "Architecture Foundation"
	_runtime_label.text = _build_runtime_info()
	_status_label.text = "Status: Ready"
	_smoke_button.text = "Smoke Test"


func _build_runtime_info() -> String:
	var method: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"))
	var os_name: String = OS.get_name()
	var size: Vector2i = DisplayServer.window_get_size()
	return "Renderer: %s | OS: %s | Window: %dx%d" % [method, os_name, size.x, size.y]


func _on_smoke_test_pressed() -> void:
	_status_label.text = "Status: Smoke Test SUCCESS"
