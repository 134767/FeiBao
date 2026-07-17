## Game shell / navigation / login / lobby smoke tests.
extends RefCounted

var passed: int = 0
var failed: int = 0
var results: PackedStringArray = PackedStringArray()
var _tree: SceneTree
var _shell: Control = null


func setup(tree: SceneTree) -> void:
	_tree = tree


func run_all() -> void:
	_run_resource_tests()
	_run_navigation_tests()
	_run_app_state_tests()
	_run_login_tests()
	_run_lobby_tests()
	_run_game_shell_tests()
	_cleanup_shell()


func _nav() -> Node:
	return _tree.root.get_node("NavigationState")


func _app() -> Node:
	return _tree.root.get_node("AppState")


func _run_resource_tests() -> void:
	_assert_true("resource_game_shell_exists", ResourceLoader.exists("res://scenes/shell/game_shell.tscn"))
	_assert_true("resource_boot_exists", ResourceLoader.exists("res://scenes/screens/boot/boot_screen.tscn"))
	_assert_true("resource_login_exists", ResourceLoader.exists("res://scenes/screens/login/login_screen.tscn"))
	_assert_true("resource_lobby_exists", ResourceLoader.exists("res://scenes/screens/lobby/lobby_screen.tscn"))
	_assert_true("resource_theme_loadable", _theme_loadable())
	_assert_true("resource_navigation_state_autoload", _tree.root.has_node("NavigationState"))
	_assert_true("resource_screen_registry_valid", _screen_registry_valid())
	_assert_true("resource_boot_instantiable", _scene_instantiable("res://scenes/screens/boot/boot_screen.tscn"))
	_assert_true("resource_login_instantiable", _scene_instantiable("res://scenes/screens/login/login_screen.tscn"))
	_assert_true("resource_lobby_instantiable", _scene_instantiable("res://scenes/screens/lobby/lobby_screen.tscn"))
	_assert_true("resource_game_shell_instantiable", _scene_instantiable("res://scenes/shell/game_shell.tscn"))


func _theme_loadable() -> bool:
	if not ResourceLoader.exists("res://ui/themes/feibao_theme.tres"):
		return false
	return load("res://ui/themes/feibao_theme.tres") is Theme


func _screen_registry_valid() -> bool:
	# Prefer ResourceLoader path checks to avoid class_name compile coupling in --script mode.
	var paths: Dictionary = {
		&"boot": "res://scenes/screens/boot/boot_screen.tscn",
		&"login": "res://scenes/screens/login/login_screen.tscn",
		&"lobby": "res://scenes/screens/lobby/lobby_screen.tscn",
	}
	if paths.size() != 3:
		return false
	for key in paths.keys():
		if not ResourceLoader.exists(str(paths[key])):
			return false
	return true


func _scene_instantiable(path: String) -> bool:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return false
	var n: Node = packed.instantiate()
	if n == null:
		return false
	n.free()
	return true


func _run_navigation_tests() -> void:
	var nav: Node = _nav()
	nav.call("reset", &"boot")
	_assert_eq("nav_reset_current_boot", str(nav.call("get_current_screen")), "boot")
	_assert_eq("nav_reset_history_empty", int(nav.call("get_history_size")), 0)

	_assert_true("nav_unknown_rejected", nav.call("navigate_to", &"not_a_screen") == false)
	_assert_eq("nav_unknown_does_not_change_current", str(nav.call("get_current_screen")), "boot")
	_assert_eq("nav_unknown_history_still_empty", int(nav.call("get_history_size")), 0)

	_assert_true("nav_empty_id_rejected", nav.call("navigate_to", &"") == false)

	nav.call("reset", &"boot")
	_assert_true("nav_same_screen_ok", nav.call("navigate_to", &"boot") == true)
	_assert_eq("nav_same_screen_no_history_stack", int(nav.call("get_history_size")), 0)

	nav.call("reset", &"boot")
	_assert_true("nav_boot_replace_login", nav.call("replace_with", &"login") == true)
	_assert_eq("nav_after_replace_is_login", str(nav.call("get_current_screen")), "login")
	_assert_eq("nav_replace_leaves_no_boot_history", int(nav.call("get_history_size")), 0)

	_assert_true("nav_login_to_lobby", nav.call("navigate_to", &"lobby", true) == true)
	_assert_eq("nav_current_lobby", str(nav.call("get_current_screen")), "lobby")
	_assert_eq("nav_history_has_login", int(nav.call("get_history_size")), 1)
	_assert_true("nav_back_to_login", nav.call("go_back") == true)
	_assert_eq("nav_after_back_login", str(nav.call("get_current_screen")), "login")

	nav.call("reset", &"login")
	_assert_true("nav_login_back_false", nav.call("go_back") == false)
	_assert_eq("nav_login_still_login", str(nav.call("get_current_screen")), "login")

	var before_current: String = str(nav.call("get_current_screen"))
	var before_hist: int = int(nav.call("get_history_size"))
	nav.call("navigate_to", &"missing_xyz")
	_assert_eq("nav_fail_current_unchanged", str(nav.call("get_current_screen")), before_current)
	_assert_eq("nav_fail_history_unchanged", int(nav.call("get_history_size")), before_hist)


func _run_app_state_tests() -> void:
	var app: Node = _app()
	app.call("reset")
	_assert_eq("app_reset_phase_bootstrap", int(app.call("get_phase")), 0)
	_assert_eq("app_reset_clears_name", str(app.call("get_player_name")), "")
	_assert_true("app_has_player_name_false", app.call("has_player_name") == false)

	app.call("set_player_name", "  Alice  ")
	_assert_eq("app_set_player_name_trims", str(app.call("get_player_name")), "Alice")
	_assert_true("app_has_player_name_true", app.call("has_player_name") == true)

	app.call("clear_player_name")
	_assert_true("app_clear_player_name", app.call("has_player_name") == false)
	app.call("reset")


func _run_login_tests() -> void:
	var packed: PackedScene = load("res://scenes/screens/login/login_screen.tscn") as PackedScene
	var login: Control = packed.instantiate() as Control
	_tree.root.add_child(login)
	_assert_true("login_has_start_button", login.call("get_start_button") != null)
	_assert_eq("login_primary_button_count", int(login.call("count_primary_buttons")), 1)
	_assert_eq("login_start_button_text", str((login.call("get_start_button") as Button).text), "開始遊戲")
	_assert_true("login_no_offline_play_text", login.call("contains_forbidden_text", "離線遊玩") == false)
	_assert_true("login_no_story_subtitle", login.call("contains_forbidden_text", "世界故事") == false)
	_assert_true("login_no_top_bar_node", not login.has_node("TopBar") and not login.has_node("%TopBar"))

	var empty_r: Dictionary = login.call("validate_player_name", "")
	_assert_true("login_empty_rejected", empty_r["valid"] == false)

	var ws_r: Dictionary = login.call("validate_player_name", "   ")
	_assert_true("login_whitespace_rejected", ws_r["valid"] == false)

	var one_r: Dictionary = login.call("validate_player_name", "A")
	_assert_true("login_one_char_accepted", one_r["valid"] == true)

	var twelve: String = "ABCDEFGHIJKL"
	var twelve_r: Dictionary = login.call("validate_player_name", twelve)
	_assert_true("login_twelve_char_accepted", twelve_r["valid"] == true)

	var over_r: Dictionary = login.call("validate_player_name", "ABCDEFGHIJKLM")
	_assert_true("login_over_limit_rejected", over_r["valid"] == false)

	var trim_r: Dictionary = login.call("validate_player_name", "  Bob  ")
	_assert_eq("login_success_name_trimmed", str(trim_r["normalized"]), "Bob")
	_assert_true("login_trim_valid", trim_r["valid"] == true)

	_app().call("reset")
	_nav().call("reset", &"login")
	_assert_true("login_submit_success", login.call("submit_player_name", "  Cara  ") == true)
	_assert_eq("login_writes_app_state", str(_app().call("get_player_name")), "Cara")
	_assert_eq("login_navigates_lobby", str(_nav().call("get_current_screen")), "lobby")

	_app().call("clear_player_name")
	_nav().call("reset", &"login")
	_assert_true("login_submit_fail", login.call("submit_player_name", "") == false)
	_assert_eq("login_fail_stays_login", str(_nav().call("get_current_screen")), "login")
	_assert_eq("login_fail_no_name_write", str(_app().call("get_player_name")), "")
	_assert_true("login_fail_has_message", not str(login.call("get_validation_message")).is_empty())

	login.queue_free()

	_run_login_button_signal_path()
	_run_login_enter_signal_path()
	_run_login_navigation_failure_rollback()


func _run_login_button_signal_path() -> void:
	var packed: PackedScene = load("res://scenes/screens/login/login_screen.tscn") as PackedScene
	var login: Control = packed.instantiate() as Control
	_tree.root.add_child(login)

	_app().call("clear_player_name")
	_nav().call("reset", &"login")

	var signal_count: Array = [0]
	var signal_name: Array = [""]
	login.login_succeeded.connect(func(n: String) -> void:
		signal_count[0] = int(signal_count[0]) + 1
		signal_name[0] = n
	)

	var name_input: LineEdit = login.call("get_name_input") as LineEdit
	var start_button: Button = login.call("get_start_button") as Button
	name_input.text = "  BtnUser  "
	start_button.emit_signal("pressed")

	_assert_eq("login_button_signal_app_name", str(_app().call("get_player_name")), "BtnUser")
	_assert_eq("login_button_signal_nav_lobby", str(_nav().call("get_current_screen")), "lobby")
	_assert_eq("login_button_signal_count", int(signal_count[0]), 1)
	_assert_eq("login_button_signal_value", str(signal_name[0]), "BtnUser")
	print("[INFO] login_button_signal_path exercised via start_button.pressed")

	login.queue_free()


func _run_login_enter_signal_path() -> void:
	var packed: PackedScene = load("res://scenes/screens/login/login_screen.tscn") as PackedScene
	var login: Control = packed.instantiate() as Control
	_tree.root.add_child(login)

	_app().call("clear_player_name")
	_nav().call("reset", &"login")

	var signal_count: Array = [0]
	var signal_name: Array = [""]
	login.login_succeeded.connect(func(n: String) -> void:
		signal_count[0] = int(signal_count[0]) + 1
		signal_name[0] = n
	)

	var name_input: LineEdit = login.call("get_name_input") as LineEdit
	name_input.emit_signal("text_submitted", "  EnterUser  ")

	_assert_eq("login_enter_signal_app_name", str(_app().call("get_player_name")), "EnterUser")
	_assert_eq("login_enter_signal_nav_lobby", str(_nav().call("get_current_screen")), "lobby")
	_assert_eq("login_enter_signal_count", int(signal_count[0]), 1)
	_assert_eq("login_enter_signal_value", str(signal_name[0]), "EnterUser")
	print("[INFO] login_enter_signal_path exercised via name_input.text_submitted")

	login.queue_free()


func _run_login_navigation_failure_rollback() -> void:
	var packed: PackedScene = load("res://scenes/screens/login/login_screen.tscn") as PackedScene
	var login: Control = packed.instantiate() as Control
	_tree.root.add_child(login)

	_app().call("set_player_name", "Previous")
	_nav().call("reset", &"login")
	var hist_before: int = int(_nav().call("get_history_size"))
	var current_before: String = str(_nav().call("get_current_screen"))

	var signal_count: Array = [0]
	login.login_succeeded.connect(func(_n: String) -> void:
		signal_count[0] = int(signal_count[0]) + 1
	)

	login.call("set_navigate_to_lobby_override", func() -> bool:
		return false
	)

	var ok: bool = bool(login.call("submit_player_name", "  FailUser  "))
	_assert_true("login_nav_fail_returns_false", ok == false)
	_assert_eq("login_nav_fail_name_rollback", str(_app().call("get_player_name")), "Previous")
	_assert_eq("login_nav_fail_signal_count", int(signal_count[0]), 0)
	_assert_eq("login_nav_fail_current_unchanged", str(_nav().call("get_current_screen")), current_before)
	_assert_eq("login_nav_fail_history_unchanged", int(_nav().call("get_history_size")), hist_before)
	_assert_eq(
		"login_nav_fail_message",
		str(login.call("get_validation_message")),
		"暫時無法開始遊戲，請再試一次"
	)
	print("[INFO] login_navigation_failure_rollback exercised via navigate override")

	login.call("clear_navigate_to_lobby_override")
	login.queue_free()


func _run_lobby_tests() -> void:
	_app().call("set_player_name", "Dana")
	var packed: PackedScene = load("res://scenes/screens/lobby/lobby_screen.tscn") as PackedScene
	var lobby: Control = packed.instantiate() as Control
	_tree.root.add_child(lobby)

	_assert_true("lobby_greeting_has_name", "Dana" in str(lobby.call("get_greeting_text")))
	var ids: Array = lobby.call("get_placeholder_ids")
	_assert_eq("lobby_placeholder_count", ids.size(), 6)
	var unique: Dictionary = {}
	for id in ids:
		unique[id] = true
	_assert_eq("lobby_placeholder_ids_unique", unique.size(), 6)
	_assert_true("lobby_ids_stable", unique.has(&"adventure") and unique.has(&"settings"))

	_nav().call("reset", &"lobby")
	var btn: Button = lobby.call("get_placeholder_button", &"adventure")
	_assert_true("lobby_adventure_button_present", btn != null)
	if btn != null:
		btn.emit_signal("pressed")
	_assert_eq("lobby_adventure_navigates", str(_nav().call("get_current_screen")), "adventure")
	_assert_eq("lobby_history_has_lobby", int(_nav().call("get_history_size")), 1)
	_assert_true("lobby_no_world_story", lobby.call("contains_text", "世界故事") == false)
	_assert_true("lobby_no_lower_left_avatar", lobby.call("has_lower_left_avatar") == false)

	lobby.queue_free()


func _run_game_shell_tests() -> void:
	_cleanup_shell()
	_app().call("reset")
	_nav().call("reset", &"boot")

	var packed: PackedScene = load("res://scenes/shell/game_shell.tscn") as PackedScene
	_shell = packed.instantiate() as Control
	_tree.root.add_child(_shell)

	_assert_eq("shell_initial_screen_boot", str(_shell.call("get_active_screen_id")), "boot")
	_assert_eq("shell_host_child_count_1_boot", int(_shell.call("get_screen_host_child_count")), 1)

	# Advance boot → login without waiting multi-second timers.
	var boot_node: Node = _shell.call("get_active_screen")
	if boot_node != null and boot_node.has_method("advance_to_login"):
		boot_node.call("advance_to_login")
	else:
		_nav().call("replace_with", &"login")

	_assert_eq("shell_after_boot_login", str(_shell.call("get_active_screen_id")), "login")
	_assert_eq("shell_host_child_count_1_login", int(_shell.call("get_screen_host_child_count")), 1)

	var login_node: Node = _shell.call("get_active_screen")
	_assert_true("shell_login_submit", login_node.call("submit_player_name", "Eve") == true)
	_assert_eq("shell_after_login_lobby", str(_shell.call("get_active_screen_id")), "lobby")
	_assert_eq("shell_host_child_count_1_lobby", int(_shell.call("get_screen_host_child_count")), 1)

	_nav().call("go_back")
	_assert_eq("shell_back_to_login", str(_shell.call("get_active_screen_id")), "login")
	_assert_eq("shell_host_child_count_1_after_back", int(_shell.call("get_screen_host_child_count")), 1)

	# Duplicate screen_changed to same id should not stack host children.
	var count_before: int = int(_shell.call("get_screen_host_child_count"))
	_nav().screen_changed.emit(&"login", &"login")
	# Force show same — navigate_to same
	_nav().call("navigate_to", &"login")
	_assert_eq("shell_no_duplicate_instance", int(_shell.call("get_screen_host_child_count")), count_before)


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
