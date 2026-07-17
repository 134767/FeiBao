## Application shell: hosts one active screen; uses NavigationState (not SceneRouter).
extends Control

const THEME_PATH: String = "res://ui/themes/feibao_theme.tres"

@onready var _screen_host: Control = %ScreenHost

var _active_screen_id: StringName = &""
var _active_screen: Control = null
var _signal_connected: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_theme()
	if not _signal_connected:
		if not NavigationState.screen_changed.is_connected(_on_screen_changed):
			NavigationState.screen_changed.connect(_on_screen_changed)
		_signal_connected = true
	NavigationState.reset(NavigationState.SCREEN_BOOT)
	_show_screen(NavigationState.get_current_screen())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_handle_back()
		get_viewport().set_input_as_handled()


func _handle_back() -> void:
	NavigationState.go_back_or_fallback()


func _apply_theme() -> void:
	if ResourceLoader.exists(THEME_PATH):
		var theme_res: Theme = load(THEME_PATH) as Theme
		if theme_res != null:
			theme = theme_res


func _on_screen_changed(current: StringName, _previous: StringName) -> void:
	_show_screen(current)


func _show_screen(screen_id: StringName) -> void:
	if screen_id == _active_screen_id and _active_screen != null and is_instance_valid(_active_screen):
		return

	if not ScreenRegistry.has_screen(screen_id):
		push_error("GameShell: cannot show unregistered screen '%s'" % str(screen_id))
		return

	var path: String = ScreenRegistry.get_scene_path(screen_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("GameShell: scene missing for '%s' path=%s" % [str(screen_id), path])
		return

	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("GameShell: failed to load scene '%s'" % path)
		return

	var instance: Node = packed.instantiate()
	if instance == null or not (instance is Control):
		push_error("GameShell: failed to instantiate Control for '%s'" % str(screen_id))
		if instance != null:
			instance.free()
		return

	_clear_host()
	var control: Control = instance as Control
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Configure before enter tree when supported (ModuleScreen handles both orders).
	if control.has_method("configure_screen"):
		var ok: Variant = control.call("configure_screen", screen_id)
		if ok is bool and ok == false:
			push_error("GameShell: configure_screen failed for '%s'" % str(screen_id))
			control.free()
			return

	_screen_host.add_child(control)
	_active_screen = control
	_active_screen_id = screen_id


func _clear_host() -> void:
	if _screen_host == null:
		return
	for child in _screen_host.get_children():
		_screen_host.remove_child(child)
		child.queue_free()
	_active_screen = null
	_active_screen_id = &""


func get_active_screen_id() -> StringName:
	return _active_screen_id


func get_active_screen() -> Control:
	return _active_screen


func get_screen_host_child_count() -> int:
	if _screen_host == null:
		return 0
	return _screen_host.get_child_count()
