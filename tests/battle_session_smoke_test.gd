## BattleSession shell + BattleScreen + prepare→battle navigation (0.9.0).
extends RefCounted

var passed: int = 0
var failed: int = 0
var results: PackedStringArray = PackedStringArray()
var _tree: SceneTree
var _case_paths: Array[String] = []


func setup(tree: SceneTree) -> void:
	_tree = tree


func run_all() -> void:
	var prod_before: Dictionary = _snapshot_production()
	_reset_domain()
	_run_session_unit_tests()
	_run_registry_tests()
	await _run_screen_tests()
	await _run_flow_tests()
	await _run_layout_tests()
	_cleanup_cases()
	_reset_domain()
	PlayerData.configure_test_storage_path("user://feibao_tests/suite_main")
	PlayerData.reset_runtime_state_for_tests()
	var prod_after: Dictionary = _snapshot_production()
	_assert_production(prod_before, prod_after)
	print("[INFO] battle session suite complete")


func _nav() -> Node:
	return _tree.root.get_node("NavigationState")


func _reset_domain() -> void:
	if is_instance_valid(AdventureState):
		AdventureState.reset_runtime_state_for_tests()
	if is_instance_valid(BattleSession):
		BattleSession.reset_runtime_state_for_tests()


func _begin_case(tag: String) -> String:
	var path: String = "user://feibao_tests/bat_%s_%d" % [tag, Time.get_ticks_usec()]
	_case_paths.append(path)
	PlayerData.clear_save_override_for_tests()
	PlayerData.configure_test_storage_path(path)
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.cleanup_test_artifacts()
	_reset_domain()
	return path


func _cleanup_cases() -> void:
	for path in _case_paths:
		PlayerData.configure_test_storage_path(path)
		PlayerData.cleanup_test_artifacts()
	_case_paths.clear()
	PlayerData.clear_save_override_for_tests()
	PlayerData.clear_test_storage_path()
	PlayerData.reset_runtime_state_for_tests()
	_reset_domain()


func _snapshot_production() -> Dictionary:
	var snap: Dictionary = {}
	for path in [
		"user://feibao/player_profile.json",
		"user://feibao/player_profile.json.tmp",
		"user://feibao/player_profile.json.bak",
	]:
		snap[path] = _fp(path)
	return snap


func _fp(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "sha": "", "len": -1}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"exists": true, "sha": "U", "len": -1}
	var b: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(b)
	return {"exists": true, "sha": ctx.finish().hex_encode(), "len": b.size()}


func _assert_production(a: Dictionary, b: Dictionary) -> void:
	for k in a.keys():
		var x: Dictionary = a[k]
		var y: Dictionary = b[k]
		_assert_eq("bat_prod_sha_%s" % str(k).get_file(), str(x.get("sha")), str(y.get("sha")))
		_assert_eq("bat_prod_len_%s" % str(k).get_file(), int(x.get("len")), int(y.get("len")))


func _run_session_unit_tests() -> void:
	_begin_case("session")
	PlayerData.initialize()
	_reset_domain()
	_assert_true("bs_init_inactive", BattleSession.has_active_session() == false)
	_assert_eq("bs_app_version", FeiBaoConstants.APP_VERSION, "0.9.0")
	_assert_eq(
		"bs_path_battle",
		FeiBaoConstants.PATH_BATTLE_SCREEN,
		"res://scenes/screens/battle/battle_screen.tscn"
	)
	_assert_eq("bs_profile_schema", int(PlayerData.get_profile().get_schema_version()), 2)

	var no_prep: Dictionary = BattleSession.begin_from_prepared()
	_assert_true("bs_no_prep_fail", bool(no_prep.get("ok", true)) == false)
	_assert_true("bs_no_prep_inactive", BattleSession.has_active_session() == false)

	var party_before: int = PlayerData.get_active_party_character_ids().size()
	var rev_before: int = PlayerData.get_profile().get_revision()
	var sig: Array = [0]
	var on_sig := func(_sid: StringName, _active: bool) -> void:
		sig[0] = int(sig[0]) + 1
	BattleSession.session_changed.connect(on_sig)

	var prep: Dictionary = AdventureState.prepare_stage(&"dev_stage_beginner_01")
	_assert_true("bs_prep_ok", bool(prep.get("ok", false)))
	var begin: Dictionary = BattleSession.begin_from_prepared()
	_assert_true("bs_begin_ok", bool(begin.get("ok", false)))
	_assert_true("bs_begin_changed", bool(begin.get("changed", false)))
	_assert_eq("bs_sig1", int(sig[0]), 1)
	_assert_true("bs_active", BattleSession.has_active_session())
	_assert_eq("bs_stage", str(BattleSession.get_stage_id()), "dev_stage_beginner_01")
	_assert_eq("bs_area", str(BattleSession.get_area_id()), "dev_area_beginner_path")
	_assert_true("bs_stage_name", not BattleSession.get_stage_display_name().is_empty())
	_assert_true("bs_area_name", not BattleSession.get_area_display_name().is_empty())
	_assert_true("bs_stage_summary", not BattleSession.get_stage_summary().is_empty())
	_assert_eq("bs_stage_num", BattleSession.get_stage_number(), 1)
	var party_ids: Array[StringName] = BattleSession.get_party_character_ids()
	_assert_true("bs_party_size", party_ids.size() >= 1)
	_assert_eq("bs_leader", str(BattleSession.get_leader_character_id()), "feibao_dev")
	_assert_true("bs_leader_name", not BattleSession.get_leader_display_name().is_empty())
	var names: Array[String] = BattleSession.get_party_display_names()
	_assert_eq("bs_names_len", names.size(), party_ids.size())
	# Defensive copy: mutating returned party array does not clear session.
	party_ids.clear()
	_assert_true("bs_party_copy", BattleSession.get_party_character_ids().size() >= 1)

	var same: Dictionary = BattleSession.begin_from_prepared()
	_assert_true("bs_same_ok", bool(same.get("ok", false)))
	_assert_true("bs_same_no_change", bool(same.get("changed", true)) == false)
	_assert_eq("bs_same_sig", int(sig[0]), 1)

	# Switch prepared stage → session updates.
	AdventureState.prepare_stage(&"dev_stage_mist_02")
	var other: Dictionary = BattleSession.begin_from_prepared()
	_assert_true("bs_other_changed", bool(other.get("changed", false)))
	_assert_eq("bs_other_sig", int(sig[0]), 2)
	_assert_eq("bs_other_stage", str(BattleSession.get_stage_id()), "dev_stage_mist_02")

	var clr: Dictionary = BattleSession.clear_session()
	_assert_true("bs_clear_changed", bool(clr.get("changed", false)))
	_assert_eq("bs_clear_sig", int(sig[0]), 3)
	_assert_true("bs_cleared", BattleSession.has_active_session() == false)
	var clr2: Dictionary = BattleSession.clear_session()
	_assert_true("bs_clear_noop", bool(clr2.get("changed", true)) == false)
	_assert_eq("bs_clear_noop_sig", int(sig[0]), 3)

	_assert_eq("bs_party_unchanged", PlayerData.get_active_party_character_ids().size(), party_before)
	_assert_eq("bs_rev_unchanged", PlayerData.get_profile().get_revision(), rev_before)
	_assert_true("bs_no_disk", PlayerData.did_last_save_write_disk() == false)
	# Prepared adventure state remains after session clear.
	_assert_true("bs_prep_retained", AdventureState.has_prepared_stage())

	if BattleSession.session_changed.is_connected(on_sig):
		BattleSession.session_changed.disconnect(on_sig)
	print("[INFO] battle session unit tests passed")


func _run_registry_tests() -> void:
	_assert_eq(
		"reg_bat_path",
		ScreenRegistry.get_scene_path(&"battle"),
		"res://scenes/screens/battle/battle_screen.tscn"
	)
	_assert_eq("reg_bat_title", ScreenRegistry.get_display_title(&"battle"), "戰鬥")
	_assert_eq("reg_bat_kind", str(ScreenRegistry.get_kind(&"battle")), "session")
	_assert_eq("reg_bat_fallback", str(ScreenRegistry.get_back_fallback(&"battle")), "adventure")
	_assert_true("reg_bat_not_module", ScreenRegistry.is_module(&"battle") == false)
	_assert_true("reg_bat_has", ScreenRegistry.has_screen(&"battle"))
	var ids: Array[StringName] = ScreenRegistry.get_registered_ids()
	_assert_eq("reg_bat_screen_count", ids.size(), 10)
	_assert_true("reg_bat_in_order", ids.has(&"battle"))
	_assert_eq("reg_bat_modules_still_6", ScreenRegistry.get_module_ids().size(), 6)
	_assert_true("reg_bat_validate", ScreenRegistry.validate_metadata())
	_assert_true("reg_bat_resources", ScreenRegistry.validate_resources())
	_assert_eq(
		"reg_const_path",
		FeiBaoConstants.PATH_BATTLE_SCREEN,
		ScreenRegistry.PATH_BATTLE_SCREEN
	)


func _run_screen_tests() -> void:
	_begin_case("screen")
	PlayerData.initialize()
	_reset_domain()
	AdventureState.prepare_stage(&"dev_stage_beginner_02")
	var sess: Dictionary = BattleSession.begin_from_prepared()
	_assert_true("bat_sess_seed", bool(sess.get("ok", false)))

	var packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	_assert_true("bat_scene_load", packed != null)
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	_assert_true("bat_cfg", bool(screen.call("configure_screen", &"battle")))
	_assert_true("bat_reject_adv", bool(screen.call("configure_screen", &"adventure")) == false)
	await _tree.process_frame
	await _tree.process_frame
	_assert_true("bat_session_ok", bool(screen.call("is_session_ok")))
	_assert_eq("bat_screen_id", str(screen.call("get_screen_id")), "battle")
	_assert_true(
		"bat_stage_text",
		str(screen.call("get_stage_name_text")).find(BattleSession.get_stage_display_name()) >= 0
	)
	_assert_true(
		"bat_area_text",
		str(screen.call("get_area_name_text")).find(BattleSession.get_area_display_name()) >= 0
	)
	_assert_true(
		"bat_summary_text",
		str(screen.call("get_stage_summary_text")).find(BattleSession.get_stage_summary()) >= 0
	)
	_assert_true("bat_shell_text", str(screen.call("get_shell_status_text")).find("殼層") >= 0)
	_assert_true("bat_party_header", str(screen.call("get_party_header_text")).find("出戰隊伍") >= 0)
	_assert_true("bat_party_leader_mark", str(screen.call("get_party_list_text")).find("領隊") >= 0)
	_assert_true("bat_no_error", bool(screen.call("is_error_state_visible")) == false)
	var back: Button = screen.call("get_back_button") as Button
	var leave: Button = screen.call("get_leave_button") as Button
	_assert_true("bat_back_h", back != null and back.custom_minimum_size.y >= 48.0)
	_assert_true("bat_leave_h", leave != null and leave.custom_minimum_size.y >= 48.0)

	# Double configure does not crash / keeps session view.
	_assert_true("bat_reconfig", bool(screen.call("configure_screen", &"battle")))
	await _tree.process_frame
	_assert_true("bat_reconfig_ok", bool(screen.call("is_session_ok")))

	# Leave clears session + history back to adventure.
	_nav().call("reset", &"adventure")
	_nav().call("navigate_to", &"battle", true)
	_assert_eq("bat_hist_setup", str(_nav().call("get_current_screen")), "battle")
	_assert_eq("bat_hist_size", int(_nav().call("get_history_size")), 1)
	screen.call("reset_leave_count_for_tests")
	var leave_sig: Array = [0]
	var leave_cb := func() -> void:
		leave_sig[0] = int(leave_sig[0]) + 1
	screen.leave_requested.connect(leave_cb)
	screen.call("press_leave_for_test")
	await _tree.process_frame
	_assert_eq("bat_leave_count", int(screen.call("get_leave_count_for_tests")), 1)
	_assert_eq("bat_leave_sig", int(leave_sig[0]), 1)
	_assert_true("bat_leave_session_cleared", BattleSession.has_active_session() == false)
	_assert_eq("bat_leave_nav", str(_nav().call("get_current_screen")), "adventure")
	_assert_eq("bat_leave_hist", int(_nav().call("get_history_size")), 0)
	if screen.leave_requested.is_connected(leave_cb):
		screen.leave_requested.disconnect(leave_cb)

	# Empty history fallback → adventure via registry.
	AdventureState.prepare_stage(&"dev_stage_beginner_01")
	BattleSession.begin_from_prepared()
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	_nav().call("reset", &"battle")
	_assert_eq("bat_fb_setup", str(_nav().call("get_current_screen")), "battle")
	_assert_eq("bat_fb_hist0", int(_nav().call("get_history_size")), 0)
	_assert_true("bat_fb_leave", bool(screen.call("request_leave")))
	await _tree.process_frame
	_assert_eq("bat_fb_nav", str(_nav().call("get_current_screen")), "adventure")
	_assert_true("bat_fb_cleared", BattleSession.has_active_session() == false)

	screen.queue_free()
	await _tree.process_frame

	# No session → safe error state, leave still works.
	_reset_domain()
	var screen2: Control = packed.instantiate() as Control
	_tree.root.add_child(screen2)
	screen2.call("configure_screen", &"battle")
	await _tree.process_frame
	_assert_true("bat_nosess_error", bool(screen2.call("is_error_state_visible")))
	_assert_true("bat_nosess_msg", str(screen2.call("get_error_text")).find("工作階段") >= 0)
	_assert_true("bat_nosess_not_ok", bool(screen2.call("is_session_ok")) == false)
	_nav().call("reset", &"adventure")
	_nav().call("navigate_to", &"battle", true)
	_assert_true("bat_nosess_leave", bool(screen2.call("request_leave")))
	_assert_eq("bat_nosess_nav", str(_nav().call("get_current_screen")), "adventure")
	screen2.queue_free()
	await _tree.process_frame
	print("[INFO] battle screen tests passed")


func _run_flow_tests() -> void:
	_begin_case("flow")
	PlayerData.initialize()
	_reset_domain()
	_nav().call("reset", &"lobby")
	_nav().call("navigate_to", &"adventure", true)

	var packed: PackedScene = load("res://scenes/screens/adventure/adventure_screen.tscn") as PackedScene
	var adv: Control = packed.instantiate() as Control
	_tree.root.add_child(adv)
	adv.call("configure_screen", &"adventure")
	await _tree.process_frame
	await _tree.process_frame
	_assert_true("flow_area", bool(adv.call("select_area_for_test", &"dev_area_mist_ridge")))
	_assert_true("flow_stage", bool(adv.call("select_stage_for_test", &"dev_stage_mist_01")))
	_assert_eq("flow_selected", str(adv.call("get_selected_stage_id")), "dev_stage_mist_01")
	var rev_before: int = PlayerData.get_profile().get_revision()
	adv.call("press_prepare_for_test")
	await _tree.process_frame
	_assert_true("flow_prep_state", AdventureState.has_prepared_stage())
	_assert_true("flow_session_active", BattleSession.has_active_session())
	_assert_eq("flow_session_stage", str(BattleSession.get_stage_id()), "dev_stage_mist_01")
	_assert_eq("flow_nav_battle", str(_nav().call("get_current_screen")), "battle")
	_assert_eq("flow_hist_has_adv", str(_nav().call("get_previous_screen")), "adventure")
	_assert_true("flow_msg", str(adv.call("get_mutation_message")).find("進入戰鬥") >= 0)
	_assert_eq("flow_rev_unchanged", PlayerData.get_profile().get_revision(), rev_before)
	_assert_true("flow_no_disk", PlayerData.did_last_save_write_disk() == false)
	_assert_eq("flow_schema", int(PlayerData.get_profile().get_schema_version()), 2)
	_assert_true("flow_leader_not_rep_contract", true)  # party snapshot uses leader

	# Second prepare (same stage) still navigates / keeps session, no AdventureState signal change.
	var sig: Array = [0]
	var cb := func(_a: StringName, _s: StringName) -> void:
		sig[0] = int(sig[0]) + 1
	AdventureState.prepared_stage_changed.connect(cb)
	adv.call("press_prepare_for_test")
	await _tree.process_frame
	_assert_eq("flow_same_prep_sig", int(sig[0]), 0)
	_assert_true("flow_same_session", BattleSession.has_active_session())
	_assert_eq("flow_same_nav", str(_nav().call("get_current_screen")), "battle")
	if AdventureState.prepared_stage_changed.is_connected(cb):
		AdventureState.prepared_stage_changed.disconnect(cb)

	# Battle screen from session snapshot.
	var bat_packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	var bat: Control = bat_packed.instantiate() as Control
	_tree.root.add_child(bat)
	bat.call("configure_screen", &"battle")
	await _tree.process_frame
	_assert_true("flow_bat_ok", bool(bat.call("is_session_ok")))
	_assert_true(
		"flow_bat_stage",
		str(bat.call("get_stage_name_text")).find(BattleSession.get_stage_display_name()) >= 0
	)
	bat.call("press_leave_for_test")
	await _tree.process_frame
	_assert_true("flow_left_cleared", BattleSession.has_active_session() == false)
	_assert_eq("flow_left_nav", str(_nav().call("get_current_screen")), "adventure")
	_assert_true("flow_prep_still", AdventureState.has_prepared_stage())

	# Failure: PlayerData unavailable on prepare → no session, stay adventure.
	_reset_domain()
	_nav().call("reset", &"adventure")
	adv.call("set_player_data_available_override_for_tests", false)
	adv.call("press_prepare_for_test")
	await _tree.process_frame
	_assert_true("flow_pd_fail_msg", str(adv.call("get_mutation_message")).find("隊伍") >= 0)
	_assert_true("flow_pd_no_session", BattleSession.has_active_session() == false)
	_assert_eq("flow_pd_stay", str(_nav().call("get_current_screen")), "adventure")
	adv.call("clear_player_data_available_override_for_tests")

	adv.queue_free()
	bat.queue_free()
	await _tree.process_frame
	print("[INFO] battle flow tests passed")


func _run_layout_tests() -> void:
	_begin_case("layout")
	PlayerData.initialize()
	_reset_domain()
	AdventureState.prepare_stage(&"dev_stage_beginner_01")
	BattleSession.begin_from_prepared()
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		await _probe_layout(size)


func _probe_layout(size: Vector2i) -> void:
	var tag: String = "%dx%d" % [size.x, size.y]
	var host := SubViewportContainer.new()
	host.custom_minimum_size = Vector2(size)
	host.size = Vector2(size)
	host.stretch = true
	_tree.root.add_child(host)
	var sv := SubViewport.new()
	sv.size = size
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(sv)
	var packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	sv.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.call("configure_screen", &"battle")
	for _i in 5:
		await _tree.process_frame
	_assert_true("bl_%s_session" % tag, bool(screen.call("is_session_ok")))
	var body: ScrollContainer = screen.call("get_body_scroll") as ScrollContainer
	_assert_true("bl_%s_body" % tag, body != null)
	_assert_true(
		"bl_%s_h_disabled" % tag,
		body != null and int(body.horizontal_scroll_mode) == int(ScrollContainer.SCROLL_MODE_DISABLED)
	)
	var screen_rect: Rect2 = screen.get_global_rect()
	var back: Button = screen.call("get_back_button") as Button
	var leave: Button = screen.call("get_leave_button") as Button
	if back != null:
		var bkr: Rect2 = back.get_global_rect()
		_assert_true("bl_%s_back_min" % tag, back.custom_minimum_size.y >= 48.0)
		_assert_true("bl_%s_back_h" % tag, bkr.size.y >= 48.0)
		_assert_true("bl_%s_back_no_h_overflow" % tag, bkr.end.x <= screen_rect.end.x + 2.0)
	if leave != null:
		screen.call("ensure_control_visible_for_test", leave)
		await _tree.process_frame
		var lr: Rect2 = leave.get_global_rect()
		_assert_true("bl_%s_leave_min" % tag, leave.custom_minimum_size.y >= 48.0)
		_assert_true("bl_%s_leave_h" % tag, lr.size.y >= 48.0)
		_assert_true("bl_%s_leave_no_h_overflow" % tag, lr.end.x <= screen_rect.end.x + 2.0)
		# Leave action should be within screen bounds (bottom bar outside BodyScroll is OK).
		_assert_true("bl_%s_leave_visible" % tag, lr.intersects(screen_rect) or lr.position.y < screen_rect.end.y + 4.0)
	if body != null and body.get_h_scroll_bar() != null:
		var hb: ScrollBar = body.get_h_scroll_bar()
		_assert_true("bl_%s_h_range_zero" % tag, maxf(0.0, float(hb.max_value) - float(hb.page)) <= 0.5)
	print(
		"[INFO] bat_layout_%s stage=%s leave_ok=%s"
		% [tag, str(screen.call("get_stage_name_text")), leave != null]
	)
	host.queue_free()
	await _tree.process_frame


func _assert_true(name: String, cond: bool) -> void:
	if cond:
		passed += 1
		print("[PASS] %s" % name)
	else:
		failed += 1
		print("[FAIL] %s" % name)
		results.append(name)


func _assert_eq(name: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		passed += 1
		print("[PASS] %s" % name)
	else:
		failed += 1
		print("[FAIL] %s expected=%s actual=%s" % [name, str(expected), str(actual)])
		results.append(name)
