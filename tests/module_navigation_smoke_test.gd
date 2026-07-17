## Module navigation foundation smoke tests (0.3.0).
extends RefCounted

var passed: int = 0
var failed: int = 0
var results: PackedStringArray = PackedStringArray()
var _tree: SceneTree
var _shell: Control = null


func setup(tree: SceneTree) -> void:
	_tree = tree


func run_all() -> void:
	_run_registry_tests()
	_run_module_screen_tests()
	_run_shell_module_flow_tests()
	_cleanup_shell()


func _nav() -> Node:
	return _tree.root.get_node("NavigationState")


func _app() -> Node:
	return _tree.root.get_node("AppState")


func _run_registry_tests() -> void:
	var expected: Array[StringName] = [
		&"adventure", &"character", &"party", &"inventory", &"farm", &"settings",
	]
	_assert_true("module_registry_path_exists", ResourceLoader.exists("res://scenes/screens/module/module_screen.tscn"))
	_assert_true("module_registry_scene_instantiable", _scene_instantiable("res://scenes/screens/module/module_screen.tscn"))

	for module_id in expected:
		_assert_true("module_registry_has_%s" % str(module_id), ScreenRegistry.has_screen(module_id))
		_assert_true("module_registry_is_module_%s" % str(module_id), ScreenRegistry.is_module_screen(module_id))
		var path: String = ScreenRegistry.get_scene_path(module_id)
		_assert_eq(
			"module_registry_path_%s" % str(module_id),
			path,
			"res://scenes/screens/module/module_screen.tscn"
		)
		var title: String = ScreenRegistry.get_title(module_id)
		_assert_true("module_registry_title_%s" % str(module_id), not title.is_empty())
		var desc: String = ScreenRegistry.get_description(module_id)
		_assert_true("module_registry_desc_%s" % str(module_id), not desc.is_empty())

	var module_ids: Array[StringName] = ScreenRegistry.get_module_ids()
	_assert_eq("module_registry_count", module_ids.size(), 6)
	_assert_true("module_registry_validate", ScreenRegistry.validate_resources())


func _run_module_screen_tests() -> void:
	var packed: PackedScene = load("res://scenes/screens/module/module_screen.tscn") as PackedScene
	var module: Control = packed.instantiate() as Control
	_tree.root.add_child(module)
	module.call("configure_for_screen", &"character")

	_assert_eq("module_screen_id", str(module.call("get_module_id")), "character")
	_assert_eq("module_screen_title", str(module.call("get_title_text")), "角色")
	_assert_true("module_screen_body_placeholder", "後續版本" in str(module.call("get_body_text")))
	_assert_true("module_screen_has_back", module.call("get_back_button") != null)
	_assert_eq("module_screen_back_text", str((module.call("get_back_button") as Button).text), "返回")
	_assert_eq("module_app_phase", int(_app().call("get_phase")), 4) # MODULE
	_assert_eq("module_app_active_id", str(_app().call("get_active_module")), "character")

	module.queue_free()


func _run_shell_module_flow_tests() -> void:
	_cleanup_shell()
	_app().call("reset")
	_nav().call("reset", &"boot")

	var packed: PackedScene = load("res://scenes/shell/game_shell.tscn") as PackedScene
	_shell = packed.instantiate() as Control
	_tree.root.add_child(_shell)

	# Fast-forward to lobby
	var boot: Node = _shell.call("get_active_screen")
	if boot != null and boot.has_method("advance_to_login"):
		boot.call("advance_to_login")
	else:
		_nav().call("replace_with", &"login")
	var login: Node = _shell.call("get_active_screen")
	_assert_true("module_flow_login_submit", login.call("submit_player_name", "ModUser") == true)
	_assert_eq("module_flow_at_lobby", str(_shell.call("get_active_screen_id")), "lobby")

	# Navigate each module via Lobby button + verify back
	var lobby: Control = _shell.call("get_active_screen") as Control
	var module_ids: Array[StringName] = [
		&"adventure", &"character", &"party", &"inventory", &"farm", &"settings",
	]
	for module_id in module_ids:
		_assert_eq("module_flow_start_lobby_%s" % str(module_id), str(_shell.call("get_active_screen_id")), "lobby")
		var btn: Button = lobby.call("get_module_button", module_id) as Button
		_assert_true("module_flow_btn_%s" % str(module_id), btn != null)
		btn.emit_signal("pressed")
		_assert_eq("module_flow_active_%s" % str(module_id), str(_shell.call("get_active_screen_id")), str(module_id))
		_assert_eq("module_flow_host_children_%s" % str(module_id), int(_shell.call("get_screen_host_child_count")), 1)

		var module_node: Control = _shell.call("get_active_screen") as Control
		_assert_true("module_flow_node_%s" % str(module_id), module_node != null)
		_assert_eq("module_flow_configured_%s" % str(module_id), str(module_node.call("get_module_id")), str(module_id))
		_assert_eq(
			"module_flow_title_%s" % str(module_id),
			str(module_node.call("get_title_text")),
			ScreenRegistry.get_title(module_id)
		)

		# Back button returns to lobby
		var back_btn: Button = module_node.call("get_back_button") as Button
		back_btn.emit_signal("pressed")
		_assert_eq("module_flow_back_%s" % str(module_id), str(_shell.call("get_active_screen_id")), "lobby")
		lobby = _shell.call("get_active_screen") as Control

	# ui_cancel / NavigationState.go_back_or_lobby
	_nav().call("navigate_to", &"farm", true)
	_assert_eq("module_flow_cancel_prep", str(_shell.call("get_active_screen_id")), "farm")
	_assert_true("module_flow_go_back_or_lobby", _nav().call("go_back_or_lobby") == true)
	_assert_eq("module_flow_after_cancel", str(_shell.call("get_active_screen_id")), "lobby")

	# Fallback when history empty on module
	_nav().call("reset", &"settings")
	# Force shell to show settings without history
	_shell.call("_show_screen", &"settings")
	_assert_eq("module_flow_fallback_start", str(_nav().call("get_current_screen")), "settings")
	_assert_eq("module_flow_fallback_hist", int(_nav().call("get_history_size")), 0)
	_assert_true("module_flow_fallback_ok", _nav().call("go_back_or_lobby") == true)
	_assert_eq("module_flow_fallback_lobby", str(_nav().call("get_current_screen")), "lobby")

	# Unknown module id still rejected
	_assert_true("module_unknown_rejected", _nav().call("navigate_to", &"not_a_module") == false)


func _scene_instantiable(path: String) -> bool:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return false
	var n: Node = packed.instantiate()
	if n == null:
		return false
	n.free()
	return true


func _cleanup_shell() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.queue_free()
		_shell = null


func _assert_true(test_name: String, condition: bool) -> void:
	if condition:
		_pass(test_name)
	else:
		_fail(test_name, "expected true")


func _assert_eq(test_name: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_pass(test_name)
	else:
		_fail(test_name, "expected %s, got %s" % [str(expected), str(actual)])


func _pass(test_name: String) -> void:
	passed += 1
	var line: String = "[PASS] %s" % test_name
	results.append(line)
	print(line)


func _fail(test_name: String, reason: String) -> void:
	failed += 1
	var line: String = "[FAIL] %s: %s" % [test_name, reason]
	results.append(line)
	print(line)
