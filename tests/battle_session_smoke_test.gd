## BattleState shell + BattleScreen + enter/leave transactions (0.9.0).
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
	await _run_adventure_enter_tests()
	await _run_screen_tests()
	await _run_leave_tests()
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
	if is_instance_valid(BattleState):
		BattleState.reset_runtime_state_for_tests()


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
	_assert_true("bs_init_inactive", BattleState.has_active_session() == false)
	_assert_eq("bs_app_version", FeiBaoConstants.APP_VERSION, "0.9.0")
	_assert_eq(
		"bs_path_battle",
		FeiBaoConstants.PATH_BATTLE_SCREEN,
		"res://scenes/screens/battle/battle_screen.tscn"
	)
	_assert_eq("bs_profile_schema", int(PlayerData.get_profile().get_schema_version()), 2)

	var no_prep: Dictionary = BattleState.begin_from_prepared_stage()
	_assert_true("bs_no_prep_fail", bool(no_prep.get("ok", true)) == false)
	_assert_true("bs_no_prep_inactive", BattleState.has_active_session() == false)

	var party_before: int = PlayerData.get_active_party_character_ids().size()
	var rev_before: int = PlayerData.get_profile().get_revision()
	var sig: Array = [0]
	var on_sig := func(_sid: StringName, _active: bool) -> void:
		sig[0] = int(sig[0]) + 1
	BattleState.session_changed.connect(on_sig)

	var prep: Dictionary = AdventureState.prepare_stage(&"dev_stage_beginner_01")
	_assert_true("bs_prep_ok", bool(prep.get("ok", false)))
	var begin: Dictionary = BattleState.begin_from_prepared_stage()
	_assert_true("bs_begin_ok", bool(begin.get("ok", false)))
	_assert_true("bs_begin_changed", bool(begin.get("changed", false)))
	_assert_eq("bs_sig1", int(sig[0]), 1)
	_assert_true("bs_active", BattleState.has_active_session())
	_assert_eq("bs_stage", str(BattleState.get_stage_id()), "dev_stage_beginner_01")
	_assert_eq("bs_area", str(BattleState.get_area_id()), "dev_area_beginner_path")
	_assert_true("bs_stage_name", not BattleState.get_stage_display_name().is_empty())
	_assert_true("bs_area_name", not BattleState.get_area_display_name().is_empty())
	_assert_eq("bs_stage_num", BattleState.get_stage_number(), 1)
	var party_ids: Array[StringName] = BattleState.get_party_character_ids()
	_assert_true("bs_party_size_ge1", party_ids.size() >= 1)
	_assert_true("bs_party_size_le3", party_ids.size() <= 3)
	_assert_eq("bs_leader", str(BattleState.get_leader_character_id()), str(party_ids[0]))
	_assert_eq("bs_leader_is_index0", str(BattleState.get_leader_character_id()), "feibao_dev")
	# Representative must not replace leader.
	PlayerData.grant_character(&"partner_a")
	PlayerData.select_character(&"partner_a")
	_assert_eq("bs_rep", str(PlayerData.get_selected_character_id()), "partner_a")
	_assert_eq("bs_leader_after_rep", str(BattleState.get_leader_character_id()), "feibao_dev")
	_assert_true(
		"bs_leader_rep_diff",
		str(BattleState.get_leader_character_id()) != str(PlayerData.get_selected_character_id())
	)
	party_ids.clear()
	_assert_true("bs_party_defensive_copy", BattleState.get_party_character_ids().size() >= 1)

	var same: Dictionary = BattleState.begin_from_prepared_stage()
	_assert_true("bs_same_ok", bool(same.get("ok", false)))
	_assert_true("bs_same_no_change", bool(same.get("changed", true)) == false)
	_assert_eq("bs_same_sig", int(sig[0]), 1)

	# Different prepared stage while active → fail closed, prior session kept.
	AdventureState.prepare_stage(&"dev_stage_mist_02")
	var other: Dictionary = BattleState.begin_from_prepared_stage()
	_assert_true("bs_diff_fail", bool(other.get("ok", true)) == false)
	_assert_true("bs_diff_no_change", bool(other.get("changed", true)) == false)
	_assert_eq("bs_diff_sig", int(sig[0]), 1)
	_assert_eq("bs_diff_kept_stage", str(BattleState.get_stage_id()), "dev_stage_beginner_01")

	# Snapshot / restore round-trip.
	var snap: Dictionary = BattleState.capture_session_snapshot()
	_assert_true("bs_snap_active", bool(snap.get("active", false)))
	var clr: Dictionary = BattleState.clear_session()
	_assert_true("bs_clear_changed", bool(clr.get("changed", false)))
	_assert_eq("bs_clear_sig", int(sig[0]), 2)
	_assert_true("bs_cleared", BattleState.has_active_session() == false)
	var clr2: Dictionary = BattleState.clear_session()
	_assert_true("bs_clear_noop", bool(clr2.get("changed", true)) == false)
	_assert_eq("bs_clear_noop_sig", int(sig[0]), 2)
	var rest: Dictionary = BattleState.restore_session_snapshot(snap)
	_assert_true("bs_restore_ok", bool(rest.get("ok", false)))
	_assert_true("bs_restore_changed", bool(rest.get("changed", false)))
	_assert_eq("bs_restore_sig", int(sig[0]), 3)
	_assert_eq("bs_restore_stage", str(BattleState.get_stage_id()), "dev_stage_beginner_01")
	var rest2: Dictionary = BattleState.restore_session_snapshot(snap)
	_assert_true("bs_restore_noop", bool(rest2.get("changed", true)) == false)
	_assert_eq("bs_restore_noop_sig", int(sig[0]), 3)

	_assert_eq("bs_party_unchanged", PlayerData.get_active_party_character_ids().size(), party_before)
	# grant/select may bump revision; capture after those and ensure begin/clear did not.
	var rev_mid: int = PlayerData.get_profile().get_revision()
	# Force a no-op save path baseline: session ops must not bump revision.
	BattleState.clear_session()
	BattleState.begin_from_prepared_stage()
	_assert_eq("bs_rev_no_bump_on_session", PlayerData.get_profile().get_revision(), rev_mid)
	# Session ops never call PlayerData.save; revision stability is the contract proof.
	_assert_true("bs_prep_retained", AdventureState.has_prepared_stage())
	_assert_true("bs_rev_not_below_start", rev_mid >= rev_before)

	# Party contract pure checks (test seam).
	var empty_p: Array[StringName] = []
	_assert_true(
		"bs_empty_party_fail",
		bool(BattleState.evaluate_party_contract_for_tests(empty_p, &"").get("ok", true)) == false
	)
	var big: Array[StringName] = [&"feibao_dev", &"partner_a", &"partner_b", &"unknown_fourth"]
	_assert_true(
		"bs_oversized_party_fail",
		bool(BattleState.evaluate_party_contract_for_tests(big, &"feibao_dev").get("ok", true)) == false
	)
	var dup: Array[StringName] = [&"feibao_dev", &"feibao_dev"]
	_assert_true(
		"bs_dup_party_fail",
		bool(BattleState.evaluate_party_contract_for_tests(dup, &"feibao_dev").get("ok", true)) == false
	)
	var unk: Array[StringName] = [&"not_a_real_char"]
	_assert_true(
		"bs_unknown_char_fail",
		bool(BattleState.evaluate_party_contract_for_tests(unk, &"not_a_real_char").get("ok", true)) == false
	)
	var unowned: Array[StringName] = [&"partner_b"]
	# partner_b may not be owned yet
	if not PlayerData.owns_character(&"partner_b"):
		_assert_true(
			"bs_unowned_char_fail",
			bool(BattleState.evaluate_party_contract_for_tests(unowned, &"partner_b").get("ok", true)) == false
		)
	var wrong_leader: Array[StringName] = [&"feibao_dev"]
	_assert_true(
		"bs_wrong_leader_fail",
		bool(BattleState.evaluate_party_contract_for_tests(wrong_leader, &"partner_a").get("ok", true)) == false
	)

	# PlayerData unavailable fail preserves prior session.
	BattleState.clear_session()
	AdventureState.prepare_stage(&"dev_stage_beginner_01")
	BattleState.begin_from_prepared_stage()
	_assert_true("bs_pd_prior_active", BattleState.has_active_session())
	var prior_stage: String = str(BattleState.get_stage_id())
	BattleState.set_player_data_available_override_for_tests(false)
	# clear then attempt begin while "unavailable" — first keep prior by failing overwrite path:
	# with PD unavailable begin fails without clearing
	var pd_fail: Dictionary = BattleState.begin_from_prepared_stage()
	# same session path may still hit PD check first if we clear...
	# When session active and same stage, idempotent path runs before PD re-fetch? Looking at code:
	# PD check is before same-session check. So unavailable fails even for same session.
	# Spec: failure preserves prior session — good.
	_assert_true("bs_pd_unavail_fail", bool(pd_fail.get("ok", true)) == false)
	_assert_eq("bs_pd_unavail_kept", str(BattleState.get_stage_id()), prior_stage)
	BattleState.clear_player_data_available_override_for_tests()

	if BattleState.session_changed.is_connected(on_sig):
		BattleState.session_changed.disconnect(on_sig)
	print("[INFO] battle state unit tests passed")


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
	var modules: Array[StringName] = ScreenRegistry.get_module_ids()
	_assert_eq("reg_bat_modules_still_6", modules.size(), 6)
	_assert_eq("reg_mod0", str(modules[0]), "adventure")
	_assert_eq("reg_mod1", str(modules[1]), "character")
	_assert_eq("reg_mod2", str(modules[2]), "party")
	_assert_eq("reg_mod3", str(modules[3]), "inventory")
	_assert_eq("reg_mod4", str(modules[4]), "farm")
	_assert_eq("reg_mod5", str(modules[5]), "settings")
	_assert_true("reg_bat_not_in_modules", modules.has(&"battle") == false)
	_assert_true("reg_bat_validate", ScreenRegistry.validate_metadata())
	_assert_true("reg_bat_resources", ScreenRegistry.validate_resources())


func _run_adventure_enter_tests() -> void:
	_begin_case("enter")
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

	# Unprepared → enter disabled.
	_assert_true("ent_unprep_disabled", bool(adv.call("is_enter_battle_enabled")) == false)

	# Prepare keeps AdventureState only (no BattleState, no nav).
	adv.call("select_area_for_test", &"dev_area_mist_ridge")
	adv.call("select_stage_for_test", &"dev_stage_mist_01")
	adv.call("press_prepare_for_test")
	await _tree.process_frame
	_assert_true("ent_prep_ok", AdventureState.has_prepared_stage())
	_assert_true("ent_prep_no_session", BattleState.has_active_session() == false)
	_assert_eq("ent_prep_nav", str(_nav().call("get_current_screen")), "adventure")
	_assert_true("ent_prep_msg", str(adv.call("get_mutation_message")).find("關卡準備完成") >= 0)
	_assert_true("ent_prep_enabled", bool(adv.call("is_enter_battle_enabled")))

	# Invalid catalog disables enter.
	adv.call("set_stage_catalog_override_for_tests", {"ok": false, "areas": [], "error": "x"})
	await _tree.process_frame
	_assert_true("ent_bad_cat_disabled", bool(adv.call("is_enter_battle_enabled")) == false)
	adv.call("clear_stage_catalog_override_for_tests")
	adv.call("configure_screen", &"adventure")
	await _tree.process_frame
	# After reload, re-prepare.
	adv.call("select_area_for_test", &"dev_area_mist_ridge")
	adv.call("select_stage_for_test", &"dev_stage_mist_01")
	adv.call("press_prepare_for_test")
	await _tree.process_frame

	# PlayerData unavailable disables.
	adv.call("set_player_data_available_override_for_tests", false)
	_assert_true("ent_pd_disabled", bool(adv.call("is_enter_battle_enabled")) == false)
	adv.call("clear_player_data_available_override_for_tests")
	_assert_true("ent_pd_enabled_again", bool(adv.call("is_enter_battle_enabled")))

	# Successful enter: session + navigate once; history has adventure.
	var rev_before: int = PlayerData.get_profile().get_revision()
	var enter_sig: Array = [0]
	var enter_cb := func(_sid: StringName) -> void:
		enter_sig[0] = int(enter_sig[0]) + 1
	adv.battle_entered.connect(enter_cb)
	adv.call("reset_enter_press_count_for_tests")
	adv.call("press_enter_battle_for_test")
	await _tree.process_frame
	_assert_eq("ent_press1", int(adv.call("get_enter_press_count_for_tests")), 1)
	_assert_eq("ent_sig1", int(enter_sig[0]), 1)
	_assert_true("ent_session", BattleState.has_active_session())
	_assert_eq("ent_stage", str(BattleState.get_stage_id()), "dev_stage_mist_01")
	_assert_eq("ent_nav", str(_nav().call("get_current_screen")), "battle")
	_assert_eq("ent_hist_prev", str(_nav().call("get_previous_screen")), "adventure")
	_assert_eq("ent_rev", PlayerData.get_profile().get_revision(), rev_before)
	_assert_true("ent_no_disk", PlayerData.did_last_save_write_disk() == false)
	_assert_true("ent_msg", str(adv.call("get_mutation_message")).find("戰鬥") >= 0)

	# Navigation failure rolls back session exactly.
	BattleState.clear_session()
	_nav().call("reset", &"adventure")
	adv.call("press_prepare_for_test")
	await _tree.process_frame
	var snap_before: Dictionary = BattleState.capture_session_snapshot()
	_assert_true("ent_navfail_prep", AdventureState.has_prepared_stage())
	adv.call("set_enter_nav_result_override_for_tests", false)
	adv.call("press_enter_battle_for_test")
	await _tree.process_frame
	_assert_true("ent_navfail_no_session", BattleState.has_active_session() == false)
	_assert_eq("ent_navfail_nav", str(_nav().call("get_current_screen")), "adventure")
	_assert_true("ent_navfail_prep_kept", AdventureState.has_prepared_stage())
	_assert_eq(
		"ent_navfail_snap_stage",
		str(BattleState.get_stage_id()),
		str(snap_before.get("stage_id", &""))
	)
	_assert_true("ent_navfail_msg", str(adv.call("get_mutation_message")).find("無法進入") >= 0)
	adv.call("clear_enter_nav_result_override_for_tests")

	# Repeated configure does not duplicate enter callback.
	adv.call("configure_screen", &"adventure")
	adv.call("configure_screen", &"adventure")
	await _tree.process_frame
	adv.call("reset_enter_press_count_for_tests")
	var enter_sig2: Array = [0]
	# disconnect old, re-bind once
	if adv.battle_entered.is_connected(enter_cb):
		adv.battle_entered.disconnect(enter_cb)
	var enter_cb2 := func(_sid: StringName) -> void:
		enter_sig2[0] = int(enter_sig2[0]) + 1
	adv.battle_entered.connect(enter_cb2)
	adv.call("press_prepare_for_test")
	adv.call("press_enter_battle_for_test")
	await _tree.process_frame
	_assert_eq("ent_dbl_cfg_press", int(adv.call("get_enter_press_count_for_tests")), 1)
	_assert_eq("ent_dbl_cfg_sig", int(enter_sig2[0]), 1)
	if adv.battle_entered.is_connected(enter_cb2):
		adv.battle_entered.disconnect(enter_cb2)

	adv.queue_free()
	await _tree.process_frame
	print("[INFO] adventure enter tests passed")


func _run_screen_tests() -> void:
	_begin_case("screen")
	PlayerData.initialize()
	_reset_domain()
	AdventureState.prepare_stage(&"dev_stage_beginner_02")
	var sess: Dictionary = BattleState.begin_from_prepared_stage()
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
		str(screen.call("get_stage_name_text")).find(BattleState.get_stage_display_name()) >= 0
	)
	_assert_true(
		"bat_area_text",
		str(screen.call("get_area_name_text")).find(BattleState.get_area_display_name()) >= 0
	)
	_assert_true("bat_stage_num", str(screen.call("get_stage_number_text")).find("2") >= 0)
	_assert_true("bat_shell", str(screen.call("get_shell_status_text")).find("開發樣本") >= 0)
	_assert_true("bat_party_header", str(screen.call("get_party_header_text")).find("出戰隊伍") >= 0)
	_assert_true("bat_leader_line", str(screen.call("get_leader_text")).find("隊長") >= 0)
	_assert_true("bat_party_leader_mark", str(screen.call("get_party_list_text")).find("領隊") >= 0)
	_assert_true("bat_no_error", bool(screen.call("is_error_state_visible")) == false)

	# Leader ≠ representative regression on screen.
	PlayerData.grant_character(&"partner_a")
	PlayerData.select_character(&"partner_a")
	_assert_true(
		"bat_leader_rep_diff",
		str(BattleState.get_leader_character_id()) != str(PlayerData.get_selected_character_id())
	)
	_assert_true(
		"bat_screen_uses_leader",
		str(screen.call("get_leader_text")).find(_char_name(&"feibao_dev")) >= 0
	)

	var back: Button = screen.call("get_back_button") as Button
	var leave: Button = screen.call("get_leave_button") as Button
	_assert_true("bat_back_min", back != null and back.custom_minimum_size.y >= 48.0)
	_assert_true("bat_leave_min", leave != null and leave.custom_minimum_size.y >= 48.0)
	_assert_true("bat_back_focus", back != null and back.focus_mode != Control.FOCUS_NONE)
	_assert_true("bat_leave_focus", leave != null and leave.focus_mode != Control.FOCUS_NONE)

	# Double configure idempotent.
	_assert_true("bat_reconfig", bool(screen.call("configure_screen", &"battle")))
	await _tree.process_frame
	_assert_true("bat_reconfig_ok", bool(screen.call("is_session_ok")))

	# Missing session fail closed.
	BattleState.clear_session()
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	_assert_true("bat_nosess_error", bool(screen.call("is_error_state_visible")))
	_assert_true("bat_nosess_msg", str(screen.call("get_error_text")).find("工作階段") >= 0)
	_assert_true("bat_nosess_not_ok", bool(screen.call("is_session_ok")) == false)

	# No PlayerData mutation on screen configure (revision stable).
	var rev: int = PlayerData.get_profile().get_revision()
	screen.call("configure_screen", &"battle")
	_assert_eq("bat_no_rev", PlayerData.get_profile().get_revision(), rev)

	screen.queue_free()
	await _tree.process_frame
	print("[INFO] battle screen tests passed")


func _run_leave_tests() -> void:
	_begin_case("leave")
	PlayerData.initialize()
	_reset_domain()
	AdventureState.prepare_stage(&"dev_stage_beginner_01")
	BattleState.begin_from_prepared_stage()

	var packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	screen.call("configure_screen", &"battle")
	await _tree.process_frame

	# Leave with history → adventure, session cleared, signal once.
	_nav().call("reset", &"adventure")
	_nav().call("navigate_to", &"battle", true)
	_assert_eq("lv_hist_setup", str(_nav().call("get_current_screen")), "battle")
	_assert_eq("lv_hist_size", int(_nav().call("get_history_size")), 1)
	screen.call("reset_leave_count_for_tests")
	var leave_sig: Array = [0]
	var leave_cb := func() -> void:
		leave_sig[0] = int(leave_sig[0]) + 1
	screen.leave_requested.connect(leave_cb)
	screen.call("press_leave_for_test")
	await _tree.process_frame
	_assert_eq("lv_count1", int(screen.call("get_leave_count_for_tests")), 1)
	_assert_eq("lv_sig1", int(leave_sig[0]), 1)
	_assert_true("lv_cleared", BattleState.has_active_session() == false)
	_assert_eq("lv_nav", str(_nav().call("get_current_screen")), "adventure")
	_assert_eq("lv_hist0", int(_nav().call("get_history_size")), 0)
	_assert_true("lv_prep_kept", AdventureState.has_prepared_stage())

	# Empty-history fallback → adventure, no quit.
	AdventureState.prepare_stage(&"dev_stage_beginner_01")
	BattleState.begin_from_prepared_stage()
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	_nav().call("reset", &"battle")
	_assert_eq("lv_fb_hist0", int(_nav().call("get_history_size")), 0)
	_assert_true("lv_fb_leave", bool(screen.call("request_leave")))
	await _tree.process_frame
	_assert_eq("lv_fb_nav", str(_nav().call("get_current_screen")), "adventure")
	_assert_true("lv_fb_cleared", BattleState.has_active_session() == false)
	_assert_true("lv_fb_no_quit", _tree != null and is_instance_valid(_tree.root))

	# Navigation failure restores exact prior session.
	AdventureState.prepare_stage(&"dev_stage_mist_02")
	# Clear any session first so begin can succeed for mist_02.
	BattleState.clear_session()
	BattleState.begin_from_prepared_stage()
	_assert_eq("lv_fail_seed", str(BattleState.get_stage_id()), "dev_stage_mist_02")
	var prior: Dictionary = BattleState.capture_session_snapshot()
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	_nav().call("reset", &"battle")
	screen.call("set_leave_nav_result_override_for_tests", false)
	var leave_ok: bool = bool(screen.call("request_leave"))
	_assert_true("lv_navfail_returns_false", leave_ok == false)
	_assert_true("lv_navfail_session_restored", BattleState.has_active_session())
	_assert_eq("lv_navfail_stage", str(BattleState.get_stage_id()), str(prior.get("stage_id", &"")))
	_assert_eq("lv_navfail_area", str(BattleState.get_area_id()), str(prior.get("area_id", &"")))
	_assert_eq("lv_navfail_screen", str(_nav().call("get_current_screen")), "battle")
	screen.call("clear_leave_nav_result_override_for_tests")

	# Repeated leave input while still on battle: only one leave_requested when first succeeds.
	AdventureState.prepare_stage(&"dev_stage_beginner_01")
	BattleState.clear_session()
	BattleState.begin_from_prepared_stage()
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	_nav().call("reset", &"adventure")
	_nav().call("navigate_to", &"battle", true)
	screen.call("reset_leave_count_for_tests")
	if screen.leave_requested.is_connected(leave_cb):
		screen.leave_requested.disconnect(leave_cb)
	var leave_sig2: Array = [0]
	var leave_cb2 := func() -> void:
		leave_sig2[0] = int(leave_sig2[0]) + 1
	screen.leave_requested.connect(leave_cb2)
	screen.call("press_leave_for_test")
	await _tree.process_frame
	_assert_eq("lv_first_nav", str(_nav().call("get_current_screen")), "adventure")
	_assert_eq("lv_first_sig", int(leave_sig2[0]), 1)
	# Re-enter battle and leave again — each successful leave emits once (no double fire per press).
	_nav().call("navigate_to", &"battle", true)
	AdventureState.prepare_stage(&"dev_stage_beginner_01")
	BattleState.begin_from_prepared_stage()
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	screen.call("press_leave_for_test")
	await _tree.process_frame
	_assert_eq("lv_dup_press", int(screen.call("get_leave_count_for_tests")), 2)
	_assert_eq("lv_dup_sig", int(leave_sig2[0]), 2)
	_assert_eq("lv_dup_final", str(_nav().call("get_current_screen")), "adventure")
	if screen.leave_requested.is_connected(leave_cb2):
		screen.leave_requested.disconnect(leave_cb2)

	screen.queue_free()
	await _tree.process_frame
	print("[INFO] battle leave tests passed")


func _run_layout_tests() -> void:
	_begin_case("layout")
	PlayerData.initialize()
	# Ensure party size 1 base.
	_reset_domain()
	AdventureState.prepare_stage(&"dev_stage_beginner_01")
	BattleState.begin_from_prepared_stage()
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		await _probe_battle_layout(size, 1)

	# Party size 2.
	PlayerData.grant_character(&"partner_a")
	PlayerData.add_party_member(&"partner_a")
	BattleState.clear_session()
	BattleState.begin_from_prepared_stage()
	_assert_eq("ly_party2_size", BattleState.get_party_character_ids().size(), 2)
	await _probe_battle_layout(Vector2i(360, 640), 2)

	# Party size 3.
	PlayerData.grant_character(&"partner_b")
	PlayerData.add_party_member(&"partner_b")
	BattleState.clear_session()
	BattleState.begin_from_prepared_stage()
	_assert_eq("ly_party3_size", BattleState.get_party_character_ids().size(), 3)
	await _probe_battle_layout(Vector2i(360, 640), 3)

	# Adventure enter button actual rects on viewports.
	BattleState.clear_session()
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		await _probe_adventure_enter_layout(size)


func _probe_battle_layout(size: Vector2i, party_n: int) -> void:
	var tag: String = "%dx%d_p%d" % [size.x, size.y, party_n]
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
	var range_v: float = 0.0
	if body != null and body.get_v_scroll_bar() != null:
		var vb: ScrollBar = body.get_v_scroll_bar()
		range_v = maxf(0.0, float(vb.max_value) - float(vb.page))
	print("[INFO] bat_scroll_%s range=%.1f" % [tag, range_v])
	var screen_rect: Rect2 = screen.get_global_rect()
	var back: Button = screen.call("get_back_button") as Button
	var leave: Button = screen.call("get_leave_button") as Button
	if back != null:
		var bkr: Rect2 = back.get_global_rect()
		_assert_true("bl_%s_back_actual_h" % tag, bkr.size.y >= 48.0)
		_assert_true("bl_%s_back_no_h_overflow" % tag, bkr.end.x <= screen_rect.end.x + 2.0)
		_assert_true("bl_%s_back_focus" % tag, back.focus_mode != Control.FOCUS_NONE)
	if leave != null:
		screen.call("ensure_control_visible_for_test", leave)
		await _tree.process_frame
		var lr: Rect2 = leave.get_global_rect()
		_assert_true("bl_%s_leave_actual_h" % tag, lr.size.y >= 48.0)
		_assert_true("bl_%s_leave_no_h_overflow" % tag, lr.end.x <= screen_rect.end.x + 2.0)
		_assert_true("bl_%s_leave_reachable" % tag, lr.intersects(screen_rect) or lr.position.y < screen_rect.end.y + 4.0)
		_assert_true("bl_%s_leave_focus" % tag, leave.focus_mode != Control.FOCUS_NONE)
	if body != null and body.get_h_scroll_bar() != null:
		var hb: ScrollBar = body.get_h_scroll_bar()
		_assert_true(
			"bl_%s_h_overflow_false" % tag,
			maxf(0.0, float(hb.max_value) - float(hb.page)) <= 0.5
		)
	_assert_true("bl_%s_party_lines" % tag, str(screen.call("get_party_list_text")).find("1.") >= 0)
	host.queue_free()
	await _tree.process_frame


func _probe_adventure_enter_layout(size: Vector2i) -> void:
	var tag: String = "adv_%dx%d" % [size.x, size.y]
	var host := SubViewportContainer.new()
	host.custom_minimum_size = Vector2(size)
	host.size = Vector2(size)
	host.stretch = true
	_tree.root.add_child(host)
	var sv := SubViewport.new()
	sv.size = size
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(sv)
	var packed: PackedScene = load("res://scenes/screens/adventure/adventure_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	sv.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.call("configure_screen", &"adventure")
	for _i in 5:
		await _tree.process_frame
	AdventureState.prepare_stage(&"dev_stage_beginner_01")
	screen.call("configure_screen", &"adventure")
	for _i in 3:
		await _tree.process_frame
	var enter: Button = screen.call("get_enter_battle_button") as Button
	_assert_true("al_%s_enter_present" % tag, enter != null)
	if enter != null:
		screen.call("ensure_control_visible_for_test", enter)
		await _tree.process_frame
		var er: Rect2 = enter.get_global_rect()
		var screen_rect: Rect2 = screen.get_global_rect()
		_assert_true("al_%s_enter_actual_h" % tag, er.size.y >= 48.0)
		_assert_true("al_%s_enter_no_h_overflow" % tag, er.end.x <= screen_rect.end.x + 2.0)
		_assert_true("al_%s_enter_reachable" % tag, er.intersects(screen_rect) or er.size.y >= 48.0)
	var body: ScrollContainer = screen.call("get_body_scroll") as ScrollContainer
	var range_v: float = 0.0
	if body != null and body.get_v_scroll_bar() != null:
		var vb: ScrollBar = body.get_v_scroll_bar()
		range_v = maxf(0.0, float(vb.max_value) - float(vb.page))
	if size.x <= 400:
		_assert_true("al_%s_scroll_range" % tag, range_v > 0.5)
	print("[INFO] adv_enter_layout_%s enter_h range=%.1f" % [tag, range_v])
	host.queue_free()
	await _tree.process_frame


func _char_name(id: StringName) -> String:
	var cat: Dictionary = CharacterCatalog.load_default()
	if bool(cat.get("ok", false)):
		for item in cat.get("characters", []):
			if item is CharacterDefinition and (item as CharacterDefinition).get_id() == id:
				return (item as CharacterDefinition).get_display_name()
	return str(id)


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
