## Module navigation foundation smoke tests (0.3.0 full spec).
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
	_run_navigation_tests()
	_run_module_screen_tests()
	_run_lobby_tests()
	_run_shell_module_flow_tests()
	_cleanup_shell()


func _nav() -> Node:
	return _tree.root.get_node("NavigationState")


func _app() -> Node:
	return _tree.root.get_node("AppState")


func _run_registry_tests() -> void:
	var ids: Array[StringName] = ScreenRegistry.get_registered_ids()
	_assert_eq("registry_screen_count", ids.size(), 9)
	var modules: Array[StringName] = ScreenRegistry.get_module_ids()
	_assert_eq("registry_module_count", modules.size(), 6)
	_assert_eq("registry_module_order_0", str(modules[0]), "adventure")
	_assert_eq("registry_module_order_1", str(modules[1]), "character")
	_assert_eq("registry_module_order_2", str(modules[2]), "party")
	_assert_eq("registry_module_order_3", str(modules[3]), "inventory")
	_assert_eq("registry_module_order_4", str(modules[4]), "farm")
	_assert_eq("registry_module_order_5", str(modules[5]), "settings")

	var unique: Dictionary = {}
	for mid in modules:
		unique[mid] = true
	_assert_eq("registry_module_ids_unique", unique.size(), 6)

	var titles: Dictionary = {
		&"adventure": "冒險",
		&"character": "角色",
		&"party": "隊伍",
		&"inventory": "背包",
		&"farm": "農場",
		&"settings": "設定",
	}
	for mid in modules:
		_assert_eq("registry_title_%s" % str(mid), ScreenRegistry.get_display_title(mid), titles[mid])
		_assert_eq("registry_kind_%s" % str(mid), str(ScreenRegistry.get_kind(mid)), "module")
		_assert_eq("registry_fallback_%s" % str(mid), str(ScreenRegistry.get_back_fallback(mid)), "lobby")
		_assert_eq(
			"registry_path_%s" % str(mid),
			ScreenRegistry.get_scene_path(mid),
			"res://scenes/screens/module/module_screen.tscn"
		)
		_assert_true("registry_path_exists_%s" % str(mid), ResourceLoader.exists(ScreenRegistry.get_scene_path(mid)))
		_assert_true("registry_is_module_%s" % str(mid), ScreenRegistry.is_module(mid))

	_assert_eq("registry_boot_kind", str(ScreenRegistry.get_kind(&"boot")), "system")
	_assert_eq("registry_login_kind", str(ScreenRegistry.get_kind(&"login")), "auth")
	_assert_eq("registry_lobby_kind", str(ScreenRegistry.get_kind(&"lobby")), "home")
	_assert_true("registry_boot_path", ResourceLoader.exists(ScreenRegistry.get_scene_path(&"boot")))
	_assert_true("registry_login_path", ResourceLoader.exists(ScreenRegistry.get_scene_path(&"login")))
	_assert_true("registry_lobby_path", ResourceLoader.exists(ScreenRegistry.get_scene_path(&"lobby")))

	_assert_true("registry_unknown_has_false", ScreenRegistry.has_screen(&"nope") == false)
	_assert_eq("registry_unknown_path_empty", ScreenRegistry.get_scene_path(&"nope"), "")
	_assert_eq("registry_unknown_title_empty", ScreenRegistry.get_display_title(&"nope"), "")
	_assert_true("registry_validate_metadata", ScreenRegistry.validate_metadata())
	_assert_true("registry_validate_resources", ScreenRegistry.validate_resources())
	print("[INFO] registry metadata/resources validated; modules=%s" % str(modules))


func _run_navigation_tests() -> void:
	var nav: Node = _nav()
	nav.call("reset", &"lobby")
	_assert_true("nav_lobby_to_adventure", nav.call("navigate_to", &"adventure", true) == true)
	_assert_eq("nav_current_adventure", str(nav.call("get_current_screen")), "adventure")
	_assert_eq("nav_history_has_lobby", int(nav.call("get_history_size")), 1)
	_assert_true("nav_go_back_to_lobby", nav.call("go_back") == true)
	_assert_eq("nav_after_go_back_lobby", str(nav.call("get_current_screen")), "lobby")

	for mid in ScreenRegistry.get_module_ids():
		nav.call("reset", &"lobby")
		_assert_true("nav_to_%s" % str(mid), nav.call("navigate_to", mid, true) == true)
		_assert_eq("nav_current_%s" % str(mid), str(nav.call("get_current_screen")), str(mid))
		_assert_true("nav_back_from_%s" % str(mid), nav.call("go_back") == true)
		_assert_eq("nav_back_lobby_%s" % str(mid), str(nav.call("get_current_screen")), "lobby")

	# Module no history → fallback lobby via replace
	nav.call("reset", &"settings")
	_assert_eq("nav_fallback_hist_empty", int(nav.call("get_history_size")), 0)
	_assert_true("nav_fallback_from_module", nav.call("go_back_or_fallback") == true)
	_assert_eq("nav_fallback_to_lobby", str(nav.call("get_current_screen")), "lobby")
	_assert_eq("nav_fallback_no_history_pollution", int(nav.call("get_history_size")), 0)

	# Login no history → false
	nav.call("reset", &"login")
	_assert_true("nav_login_fallback_false", nav.call("go_back_or_fallback") == false)
	_assert_eq("nav_login_still_login", str(nav.call("get_current_screen")), "login")

	# Lobby no history → false
	nav.call("reset", &"lobby")
	_assert_true("nav_lobby_fallback_false", nav.call("go_back_or_fallback") == false)
	_assert_eq("nav_lobby_still_lobby", str(nav.call("get_current_screen")), "lobby")

	# Repeat same module no stack
	nav.call("reset", &"lobby")
	nav.call("navigate_to", &"farm", true)
	var h1: int = int(nav.call("get_history_size"))
	_assert_true("nav_same_module_ok", nav.call("navigate_to", &"farm", true) == true)
	_assert_eq("nav_same_module_no_stack", int(nav.call("get_history_size")), h1)

	_assert_true("nav_unknown_rejected", nav.call("navigate_to", &"not_a_module") == false)
	print("[INFO] navigation history/fallback cases passed")


func _run_module_screen_tests() -> void:
	var packed: PackedScene = load("res://scenes/screens/module/module_screen.tscn") as PackedScene

	# configure after tree
	for mid in ScreenRegistry.get_module_ids():
		var module: Control = packed.instantiate() as Control
		_tree.root.add_child(module)
		_assert_true("module_cfg_after_%s" % str(mid), module.call("configure_screen", mid) == true)
		_assert_eq("module_id_after_%s" % str(mid), str(module.call("get_screen_id")), str(mid))
		_assert_eq("module_title_after_%s" % str(mid), str(module.call("get_title_text")), ScreenRegistry.get_display_title(mid))
		_assert_eq("module_status_after_%s" % str(mid), str(module.call("get_status_text")), "此功能將於後續版本開放")
		_assert_eq("module_phase_after_%s" % str(mid), int(_app().call("get_phase")), 4)
		var back: Button = module.call("get_back_button") as Button
		_assert_true("module_back_exists_%s" % str(mid), back != null)
		_assert_true("module_back_height_%s" % str(mid), back.custom_minimum_size.y >= 48.0)
		module.queue_free()

	# configure before tree
	var pre: Control = packed.instantiate() as Control
	_assert_true("module_cfg_before_tree", pre.call("configure_screen", &"party") == true)
	_tree.root.add_child(pre)
	_assert_eq("module_id_before_tree", str(pre.call("get_screen_id")), "party")
	_assert_eq("module_title_before_tree", str(pre.call("get_title_text")), "隊伍")
	_assert_eq("module_status_before_tree", str(pre.call("get_status_text")), "此功能將於後續版本開放")
	pre.queue_free()

	# invalid IDs
	var inv: Control = packed.instantiate() as Control
	_tree.root.add_child(inv)
	_assert_true("module_reject_boot", inv.call("configure_screen", &"boot") == false)
	_assert_true("module_reject_login", inv.call("configure_screen", &"login") == false)
	_assert_true("module_reject_lobby", inv.call("configure_screen", &"lobby") == false)
	_assert_true("module_reject_unknown", inv.call("configure_screen", &"xyz") == false)
	inv.queue_free()

	# back signal once
	_nav().call("reset", &"lobby")
	_nav().call("navigate_to", &"adventure", true)
	var mback: Control = packed.instantiate() as Control
	_tree.root.add_child(mback)
	mback.call("configure_screen", &"adventure")
	var sig_count: Array = [0]
	mback.back_requested.connect(func() -> void:
		sig_count[0] = int(sig_count[0]) + 1
	)
	_assert_true("module_back_request_ok", mback.call("request_back") == true)
	_assert_eq("module_back_signal_count", int(sig_count[0]), 1)
	_assert_eq("module_back_current_lobby", str(_nav().call("get_current_screen")), "lobby")
	mback.queue_free()
	print("[INFO] module screen configure before/after and back signal passed")


func _run_lobby_tests() -> void:
	_app().call("set_player_name", "NavUser")
	var packed: PackedScene = load("res://scenes/screens/lobby/lobby_screen.tscn") as PackedScene
	var lobby: Control = packed.instantiate() as Control
	_tree.root.add_child(lobby)

	var ids: Array = lobby.call("get_module_ids")
	_assert_eq("lobby_module_count", ids.size(), 6)
	_assert_true("lobby_no_world_story", lobby.call("contains_text", "世界故事") == false)
	_assert_true("lobby_no_avatar", lobby.call("has_lower_left_avatar") == false)

	var expected_titles: Dictionary = {
		&"adventure": "冒險",
		&"character": "角色",
		&"party": "隊伍",
		&"inventory": "背包",
		&"farm": "農場",
		&"settings": "設定",
	}
	for mid in ids:
		var btn: Button = lobby.call("get_module_button", mid) as Button
		_assert_true("lobby_btn_exists_%s" % str(mid), btn != null)
		_assert_eq("lobby_btn_text_%s" % str(mid), btn.text, expected_titles[mid])

	# All six buttons navigate
	for mid in ids:
		_nav().call("reset", &"lobby")
		var req_count: Array = [0]
		lobby.module_requested.connect(func(_id: StringName) -> void:
			req_count[0] = int(req_count[0]) + 1
		, CONNECT_ONE_SHOT)
		var btn2: Button = lobby.call("get_module_button", mid) as Button
		btn2.emit_signal("pressed")
		_assert_eq("lobby_nav_current_%s" % str(mid), str(_nav().call("get_current_screen")), str(mid))
		_assert_eq("lobby_status_clear_%s" % str(mid), str(lobby.call("get_status_text")), "")
		_assert_eq("lobby_module_requested_once_%s" % str(mid), int(req_count[0]), 1)
		print("[INFO] lobby button signal navigated to %s" % str(mid))

	# Navigation failure injection
	_nav().call("reset", &"lobby")
	var hist_before: int = int(_nav().call("get_history_size"))
	lobby.call("set_navigate_override", func(_id: StringName) -> bool:
		return false
	)
	var fail_count: Array = [0]
	lobby.module_navigation_failed.connect(func(_id: StringName) -> void:
		fail_count[0] = int(fail_count[0]) + 1
	)
	var adv_btn: Button = lobby.call("get_module_button", &"adventure") as Button
	adv_btn.emit_signal("pressed")
	_assert_eq("lobby_fail_stays", str(_nav().call("get_current_screen")), "lobby")
	_assert_eq("lobby_fail_hist", int(_nav().call("get_history_size")), hist_before)
	_assert_eq("lobby_fail_msg", str(lobby.call("get_status_text")), "暫時無法開啟此功能")
	_assert_eq("lobby_fail_signal_once", int(fail_count[0]), 1)
	lobby.call("clear_navigate_override")
	print("[INFO] lobby navigation failure override passed")

	lobby.queue_free()


func _run_shell_module_flow_tests() -> void:
	_cleanup_shell()
	_app().call("reset")
	_nav().call("reset", &"boot")

	var packed: PackedScene = load("res://scenes/shell/game_shell.tscn") as PackedScene
	_shell = packed.instantiate() as Control
	_tree.root.add_child(_shell)

	var boot: Node = _shell.call("get_active_screen")
	if boot != null and boot.has_method("advance_to_login"):
		boot.call("advance_to_login")
	else:
		_nav().call("replace_with", &"login")
	var login: Node = _shell.call("get_active_screen")
	_assert_true("shell_login_ok", login.call("submit_player_name", "ShellUser") == true)
	_assert_eq("shell_at_lobby", str(_shell.call("get_active_screen_id")), "lobby")

	var lobby: Control = _shell.call("get_active_screen") as Control
	for mid in ScreenRegistry.get_module_ids():
		var btn: Button = lobby.call("get_module_button", mid) as Button
		btn.emit_signal("pressed")
		_assert_eq("shell_active_%s" % str(mid), str(_shell.call("get_active_screen_id")), str(mid))
		_assert_eq("shell_host_1_%s" % str(mid), int(_shell.call("get_screen_host_child_count")), 1)
		var mod: Control = _shell.call("get_active_screen") as Control
		_assert_eq("shell_cfg_id_%s" % str(mid), str(mod.call("get_screen_id")), str(mid))
		var back: Button = mod.call("get_back_button") as Button
		back.emit_signal("pressed")
		_assert_eq("shell_back_lobby_%s" % str(mid), str(_shell.call("get_active_screen_id")), "lobby")
		lobby = _shell.call("get_active_screen") as Control

	# empty history fallback via system back API
	_nav().call("reset", &"farm")
	_assert_true("shell_fallback_ok", _nav().call("go_back_or_fallback") == true)
	_assert_eq("shell_fallback_lobby", str(_nav().call("get_current_screen")), "lobby")

	# duplicate screen_changed same id
	_nav().call("reset", &"lobby")
	_nav().call("navigate_to", &"settings", true)
	var c1: int = int(_shell.call("get_screen_host_child_count"))
	_nav().call("navigate_to", &"settings", true)
	_assert_eq("shell_no_dup_children", int(_shell.call("get_screen_host_child_count")), c1)
	print("[INFO] shell module flow and host child count checks passed")


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
