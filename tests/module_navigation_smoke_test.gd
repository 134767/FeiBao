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
	const PATH_MODULE: String = "res://scenes/screens/module/module_screen.tscn"
	const PATH_CHARACTER: String = "res://scenes/screens/character/character_screen.tscn"
	const PATH_PARTY: String = "res://scenes/screens/party/party_screen.tscn"
	for mid in modules:
		_assert_eq("registry_title_%s" % str(mid), ScreenRegistry.get_display_title(mid), titles[mid])
		_assert_eq("registry_kind_%s" % str(mid), str(ScreenRegistry.get_kind(mid)), "module")
		_assert_eq("registry_fallback_%s" % str(mid), str(ScreenRegistry.get_back_fallback(mid)), "lobby")
		var expected_path: String = PATH_MODULE
		if mid == &"character":
			expected_path = PATH_CHARACTER
		elif mid == &"party":
			expected_path = PATH_PARTY
		_assert_eq("registry_path_%s" % str(mid), ScreenRegistry.get_scene_path(mid), expected_path)
		_assert_true("registry_path_exists_%s" % str(mid), ResourceLoader.exists(ScreenRegistry.get_scene_path(mid)))
		_assert_true("registry_is_module_%s" % str(mid), ScreenRegistry.is_module(mid))
	_assert_eq("registry_character_dedicated", ScreenRegistry.get_scene_path(&"character"), PATH_CHARACTER)
	_assert_eq("registry_party_dedicated", ScreenRegistry.get_scene_path(&"party"), PATH_PARTY)
	_assert_eq("registry_adventure_placeholder", ScreenRegistry.get_scene_path(&"adventure"), PATH_MODULE)
	_assert_eq("registry_inventory_placeholder", ScreenRegistry.get_scene_path(&"inventory"), PATH_MODULE)
	_assert_eq("registry_farm_placeholder", ScreenRegistry.get_scene_path(&"farm"), PATH_MODULE)
	_assert_eq("registry_settings_placeholder", ScreenRegistry.get_scene_path(&"settings"), PATH_MODULE)

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

	# Shared ModuleScreen content contract for remaining placeholder modules only.
	# Character and Party use dedicated screens.
	var placeholder_modules: Array[StringName] = [
		&"adventure", &"inventory", &"farm", &"settings"
	]
	for mid in placeholder_modules:
		var module: Control = packed.instantiate() as Control
		_tree.root.add_child(module)
		_assert_true("module_cfg_after_%s" % str(mid), module.call("configure_screen", mid) == true)
		_assert_eq("module_id_after_%s" % str(mid), str(module.call("get_screen_id")), str(mid))
		_assert_eq("module_title_after_%s" % str(mid), str(module.call("get_title_text")), ScreenRegistry.get_display_title(mid))
		_assert_eq("module_status_after_%s" % str(mid), str(module.call("get_status_text")), "此功能將於後續版本開放")
		_assert_eq("module_phase_after_%s" % str(mid), int(_app().call("get_phase")), 4)
		_assert_true(
			"module_no_desc_label_%s" % str(mid),
			module.find_child("DescriptionLabel", true, false) == null
		)
		_assert_true("module_no_text_說明_%s" % str(mid), _tree_contains_visible_text(module, "說明") == false)
		_assert_true("module_no_世界故事_%s" % str(mid), _tree_contains_visible_text(module, "世界故事") == false)
		_assert_true("module_no_關卡_%s" % str(mid), _tree_contains_visible_text(module, "關卡") == false)
		_assert_true("module_no_戰鬥_%s" % str(mid), _tree_contains_visible_text(module, "戰鬥") == false)
		_assert_true("module_no_物品_%s" % str(mid), _tree_contains_visible_text(module, "物品") == false)
		_assert_eq("module_button_count_%s" % str(mid), _count_buttons(module), 1)
		var back: Button = module.call("get_back_button") as Button
		_assert_true("module_back_exists_%s" % str(mid), back != null)
		_assert_eq("module_back_text_%s" % str(mid), back.text, "返回")
		_assert_true("module_back_height_%s" % str(mid), back.custom_minimum_size.y >= 48.0)
		module.queue_free()

	# ModuleScreen still accepts character id for shared-frame compatibility, but shell uses dedicated path.
	var char_mod: Control = packed.instantiate() as Control
	_tree.root.add_child(char_mod)
	_assert_true("module_cfg_character_compat", char_mod.call("configure_screen", &"character") == true)
	_assert_eq("module_id_character_compat", str(char_mod.call("get_screen_id")), "character")
	char_mod.queue_free()

	# module_activated after tree
	var after: Control = packed.instantiate() as Control
	_tree.root.add_child(after)
	var after_count: Array = [0]
	var after_id: Array = [""]
	after.module_activated.connect(func(sid: StringName) -> void:
		after_count[0] = int(after_count[0]) + 1
		after_id[0] = str(sid)
	)
	_assert_true("activated_after_cfg_ok", after.call("configure_screen", &"adventure") == true)
	_assert_eq("activated_after_tree_count", int(after_count[0]), 1)
	_assert_eq("activated_after_tree_id", str(after_id[0]), "adventure")
	_assert_eq("activated_after_phase", int(_app().call("get_phase")), 4)
	_assert_eq("activated_after_title", str(after.call("get_title_text")), "冒險")
	print("[INFO] module_activated after tree: count=1 id=adventure")
	after.queue_free()

	# module_activated before tree (connect before add_child, after configure)
	var pre: Control = packed.instantiate() as Control
	_assert_true("module_cfg_before_tree", pre.call("configure_screen", &"party") == true)
	var before_count: Array = [0]
	var before_id: Array = [""]
	pre.module_activated.connect(func(sid: StringName) -> void:
		before_count[0] = int(before_count[0]) + 1
		before_id[0] = str(sid)
	)
	_tree.root.add_child(pre)
	_assert_eq("activated_before_tree_count", int(before_count[0]), 1)
	_assert_eq("activated_before_tree_id", str(before_id[0]), "party")
	_assert_eq("module_id_before_tree", str(pre.call("get_screen_id")), "party")
	_assert_eq("module_title_before_tree", str(pre.call("get_title_text")), "隊伍")
	_assert_eq("module_status_before_tree", str(pre.call("get_status_text")), "此功能將於後續版本開放")
	print("[INFO] module_activated before tree: count=1 id=party")
	pre.queue_free()

	# invalid IDs: no activation, id unchanged (nav not on module to avoid auto-configure in _ready)
	_nav().call("reset", &"login")
	var inv: Control = packed.instantiate() as Control
	_tree.root.add_child(inv)
	var inv_count: Array = [0]
	inv.module_activated.connect(func(_sid: StringName) -> void:
		inv_count[0] = int(inv_count[0]) + 1
	)
	var id_before: String = str(inv.call("get_screen_id"))
	_assert_true("module_reject_boot", inv.call("configure_screen", &"boot") == false)
	_assert_true("module_reject_login", inv.call("configure_screen", &"login") == false)
	_assert_true("module_reject_lobby", inv.call("configure_screen", &"lobby") == false)
	_assert_true("module_reject_unknown", inv.call("configure_screen", &"xyz") == false)
	_assert_eq("invalid_config_activation_count", int(inv_count[0]), 0)
	_assert_eq("invalid_config_id_unchanged", str(inv.call("get_screen_id")), id_before)
	print("[INFO] invalid configure activation_count=0")
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
		if mid == &"character":
			_assert_true(
				"shell_character_dedicated_scene",
				str(mod.get_script().resource_path).ends_with("character_screen.gd")
			)
		elif mid == &"party":
			_assert_true(
				"shell_party_dedicated_scene",
				str(mod.get_script().resource_path).ends_with("party_screen.gd")
			)
		else:
			_assert_true(
				"shell_placeholder_module_scene_%s" % str(mid),
				str(mod.get_script().resource_path).ends_with("module_screen.gd")
			)
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

	_run_ui_cancel_tests()
	print("[INFO] shell module flow and host child count checks passed")


func _run_ui_cancel_tests() -> void:
	# History case: Lobby → Adventure → ui_cancel
	_nav().call("reset", &"lobby")
	_nav().call("navigate_to", &"adventure", true)
	_assert_eq("ui_cancel_hist_prep", str(_shell.call("get_active_screen_id")), "adventure")
	var cancel_hist := InputEventAction.new()
	cancel_hist.action = "ui_cancel"
	cancel_hist.pressed = true
	_shell.call("_unhandled_input", cancel_hist)
	_assert_eq("ui_cancel_hist_nav", str(_nav().call("get_current_screen")), "lobby")
	_assert_eq("ui_cancel_hist_active", str(_shell.call("get_active_screen_id")), "lobby")
	_assert_eq("ui_cancel_hist_host_1", int(_shell.call("get_screen_host_child_count")), 1)
	print("[INFO] ui_cancel history case: adventure -> lobby")

	# Empty-history fallback: reset farm then cancel
	_nav().call("reset", &"farm")
	_assert_eq("ui_cancel_fb_prep", str(_shell.call("get_active_screen_id")), "farm")
	_assert_eq("ui_cancel_fb_hist0", int(_nav().call("get_history_size")), 0)
	var cancel_fb := InputEventAction.new()
	cancel_fb.action = "ui_cancel"
	cancel_fb.pressed = true
	_shell.call("_unhandled_input", cancel_fb)
	_assert_eq("ui_cancel_fb_nav", str(_nav().call("get_current_screen")), "lobby")
	_assert_eq("ui_cancel_fb_active", str(_shell.call("get_active_screen_id")), "lobby")
	_assert_eq("ui_cancel_fb_hist", int(_nav().call("get_history_size")), 0)
	_assert_eq("ui_cancel_fb_host_1", int(_shell.call("get_screen_host_child_count")), 1)
	print("[INFO] ui_cancel fallback case: farm -> lobby hist=0")

	# Login no-op
	_nav().call("reset", &"login")
	_assert_eq("ui_cancel_login_prep", str(_shell.call("get_active_screen_id")), "login")
	var cancel_login := InputEventAction.new()
	cancel_login.action = "ui_cancel"
	cancel_login.pressed = true
	_shell.call("_unhandled_input", cancel_login)
	_assert_eq("ui_cancel_login_nav", str(_nav().call("get_current_screen")), "login")
	_assert_eq("ui_cancel_login_active", str(_shell.call("get_active_screen_id")), "login")
	_assert_eq("ui_cancel_login_host_1", int(_shell.call("get_screen_host_child_count")), 1)
	print("[INFO] ui_cancel login no-op; quit not invoked")


func _cleanup_shell() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.queue_free()
		_shell = null


func _tree_contains_visible_text(node: Node, needle: String) -> bool:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return false
	if node is Label and needle in (node as Label).text:
		return true
	if node is Button and needle in (node as Button).text:
		return true
	for child in node.get_children():
		if _tree_contains_visible_text(child, needle):
			return true
	return false


func _count_buttons(node: Node) -> int:
	var total: int = 0
	if node is Button:
		total += 1
	for child in node.get_children():
		total += _count_buttons(child)
	return total


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
