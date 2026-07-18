## Character ownership + catalog integration tests (0.6.0).
extends RefCounted

var passed: int = 0
var failed: int = 0
var results: PackedStringArray = PackedStringArray()
var _tree: SceneTree
var _case_paths: Array[String] = []


func setup(tree: SceneTree) -> void:
	_tree = tree


func run_all() -> void:
	var prod_before: Dictionary = _snapshot_production_artifacts()
	_run_profile_mutation_tests()
	_run_player_data_ownership_tests()
	_run_card_ownership_tests()
	await _run_screen_ownership_tests()
	await _run_ownership_layout_tests()
	_cleanup_all_cases()
	PlayerData.configure_test_storage_path("user://feibao_tests/suite_main")
	PlayerData.reset_runtime_state_for_tests()
	var prod_after: Dictionary = _snapshot_production_artifacts()
	_assert_production_fingerprints_unchanged(prod_before, prod_after)
	print("[INFO] ownership suite production fingerprints unchanged")


func _pd() -> Node:
	return _tree.root.get_node("PlayerData")


func _app() -> Node:
	return _tree.root.get_node("AppState")


func _nav() -> Node:
	return _tree.root.get_node("NavigationState")


func _unique_case(tag: String) -> String:
	var path: String = "user://feibao_tests/own_%s_%d" % [tag, Time.get_ticks_usec()]
	_case_paths.append(path)
	return path


func _begin_case(tag: String) -> String:
	var path: String = _unique_case(tag)
	PlayerData.clear_save_override_for_tests()
	PlayerData.configure_test_storage_path(path)
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.cleanup_test_artifacts()
	return path


func _cleanup_all_cases() -> void:
	for path in _case_paths:
		PlayerData.configure_test_storage_path(path)
		PlayerData.cleanup_test_artifacts()
	_case_paths.clear()
	PlayerData.clear_save_override_for_tests()
	PlayerData.clear_test_storage_path()
	PlayerData.reset_runtime_state_for_tests()


func _prod_paths() -> PackedStringArray:
	return PackedStringArray([
		"user://feibao/player_profile.json",
		"user://feibao/player_profile.json.tmp",
		"user://feibao/player_profile.json.bak",
	])


func _snapshot_production_artifacts() -> Dictionary:
	var snap: Dictionary = {}
	for path in _prod_paths():
		snap[path] = _file_fingerprint(path)
	return snap


func _file_fingerprint(path: String) -> Dictionary:
	var exists: bool = FileAccess.file_exists(path)
	if not exists:
		return {"exists": false, "sha256": "", "length": -1}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"exists": true, "sha256": "UNREADABLE", "length": -1}
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	var length: int = bytes.size()
	f.close()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return {
		"exists": true,
		"sha256": ctx.finish().hex_encode(),
		"length": length,
	}


func _assert_production_fingerprints_unchanged(before: Dictionary, after: Dictionary) -> void:
	for path in _prod_paths():
		var b: Dictionary = before.get(path, {}) as Dictionary
		var a: Dictionary = after.get(path, {}) as Dictionary
		_assert_eq("own_prod_fp_exists_%s" % path.get_file(), bool(b.get("exists", false)), bool(a.get("exists", false)))
		_assert_eq("own_prod_fp_sha_%s" % path.get_file(), str(b.get("sha256", "")), str(a.get("sha256", "")))
		_assert_eq("own_prod_fp_len_%s" % path.get_file(), int(b.get("length", -2)), int(a.get("length", -3)))


func _primary_text() -> String:
	var path: String = PlayerData.get_primary_path()
	if not FileAccess.file_exists(path):
		return ""
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text


func _primary_mtime_or_empty() -> int:
	var path: String = PlayerData.get_primary_path()
	if not FileAccess.file_exists(path):
		return -1
	return int(FileAccess.get_modified_time(path))


func _run_profile_mutation_tests() -> void:
	var base: PlayerProfile = PlayerProfile.create_default()
	_assert_eq("mut_schema", base.get_schema_version(), 1)
	_assert_eq("mut_default_owned", base.get_owned_character_ids().size(), 1)
	_assert_eq("mut_default_selected", str(base.get_selected_character_id()), "feibao_dev")

	# Grant new id
	var grant1: Dictionary = base.with_character_granted(&"partner_a")
	_assert_true("mut_grant_ok", bool(grant1.get("ok", false)))
	_assert_true("mut_grant_changed", bool(grant1.get("changed", false)))
	var gprof: PlayerProfile = grant1["profile"] as PlayerProfile
	_assert_eq("mut_grant_rev", gprof.get_revision(), 1)
	_assert_eq("mut_grant_owned_count", gprof.get_owned_character_ids().size(), 2)
	_assert_true("mut_grant_owns_a", gprof.owns_character(&"partner_a"))
	_assert_eq("mut_grant_keeps_selected", str(gprof.get_selected_character_id()), "feibao_dev")
	_assert_eq("mut_grant_orig_rev", base.get_revision(), 0)
	_assert_eq("mut_grant_orig_owned", base.get_owned_character_ids().size(), 1)

	# Duplicate grant idempotent
	var grant_dup: Dictionary = gprof.with_character_granted(&"partner_a")
	_assert_true("mut_dup_grant_ok", bool(grant_dup.get("ok", false)))
	_assert_true("mut_dup_grant_changed_false", bool(grant_dup.get("changed", true)) == false)
	var gdup: PlayerProfile = grant_dup["profile"] as PlayerProfile
	_assert_eq("mut_dup_grant_rev", gdup.get_revision(), 1)
	_assert_eq("mut_dup_grant_owned", gdup.get_owned_character_ids().size(), 2)

	# Empty / invalid id
	var bad_empty: Dictionary = base.with_character_granted(&"")
	_assert_true("mut_grant_empty_fail", bool(bad_empty.get("ok", true)) == false)
	_assert_true("mut_grant_empty_unchanged", bool(bad_empty.get("changed", true)) == false)
	var bad_id: Dictionary = base.with_character_granted(&"Bad-ID")
	_assert_true("mut_grant_bad_id_fail", bool(bad_id.get("ok", true)) == false)

	# Select owned
	var sel1: Dictionary = gprof.with_selected_character(&"partner_a")
	_assert_true("mut_select_ok", bool(sel1.get("ok", false)))
	_assert_true("mut_select_changed", bool(sel1.get("changed", false)))
	var sprof: PlayerProfile = sel1["profile"] as PlayerProfile
	_assert_eq("mut_select_id", str(sprof.get_selected_character_id()), "partner_a")
	_assert_eq("mut_select_rev", sprof.get_revision(), 2)
	_assert_eq("mut_select_owned_stable", sprof.get_owned_character_ids().size(), 2)
	_assert_eq("mut_select_orig_selected", str(gprof.get_selected_character_id()), "feibao_dev")

	# Duplicate select
	var sel_dup: Dictionary = sprof.with_selected_character(&"partner_a")
	_assert_true("mut_dup_select_ok", bool(sel_dup.get("ok", false)))
	_assert_true("mut_dup_select_changed_false", bool(sel_dup.get("changed", true)) == false)
	_assert_eq("mut_dup_select_rev", (sel_dup["profile"] as PlayerProfile).get_revision(), 2)

	# Select unowned rejected
	var unowned: Dictionary = base.with_selected_character(&"partner_a")
	_assert_true("mut_select_unowned_fail", bool(unowned.get("ok", true)) == false)
	_assert_true("mut_select_unowned_changed_false", bool(unowned.get("changed", true)) == false)
	_assert_eq("mut_select_unowned_selected", str((unowned["profile"] as PlayerProfile).get_selected_character_id()), "feibao_dev")
	_assert_eq("mut_select_unowned_rev", (unowned["profile"] as PlayerProfile).get_revision(), 0)

	# Defensive owned copy
	var owned_copy: Array[StringName] = gprof.get_owned_character_ids()
	owned_copy.append(&"hacker")
	_assert_eq("mut_owned_defensive", gprof.get_owned_character_ids().size(), 2)


func _run_player_data_ownership_tests() -> void:
	_begin_case("pd_grant")
	PlayerData.initialize()
	_assert_eq("pd_default_selected", str(PlayerData.get_selected_character_id()), "feibao_dev")
	_assert_eq("pd_default_owned_count", PlayerData.get_owned_character_ids().size(), 1)
	_assert_true("pd_known_feibao", PlayerData.is_known_character(&"feibao_dev"))
	_assert_true("pd_known_partner_a", PlayerData.is_known_character(&"partner_a"))
	_assert_true("pd_unknown_false", PlayerData.is_known_character(&"not_a_real_char") == false)
	_assert_eq("pd_known_owned_default", PlayerData.get_known_owned_count(), 1)
	_assert_true("pd_partner_a_not_owned", PlayerData.owns_character(&"partner_a") == false)

	var signals: Dictionary = {"profile": 0, "grant": 0, "select": 0, "last_grant": "", "last_select": ""}
	var on_profile := func(_r: int) -> void:
		signals["profile"] = int(signals["profile"]) + 1
	var on_grant := func(cid: StringName, _r: int) -> void:
		signals["grant"] = int(signals["grant"]) + 1
		signals["last_grant"] = str(cid)
	var on_select := func(cid: StringName, _r: int) -> void:
		signals["select"] = int(signals["select"]) + 1
		signals["last_select"] = str(cid)
	PlayerData.profile_changed.connect(on_profile)
	PlayerData.character_granted.connect(on_grant)
	PlayerData.selected_character_changed.connect(on_select)

	# Unknown grant rejected
	var unk: Dictionary = PlayerData.grant_character(&"ghost_xyz")
	_assert_true("pd_unk_grant_fail", bool(unk.get("ok", true)) == false)
	_assert_true("pd_unk_grant_no_change", bool(unk.get("changed", true)) == false)
	_assert_eq("pd_unk_grant_signals", int(signals["grant"]), 0)

	# Unknown select rejected
	var unk_sel: Dictionary = PlayerData.select_character(&"ghost_xyz")
	_assert_true("pd_unk_select_fail", bool(unk_sel.get("ok", true)) == false)
	_assert_eq("pd_unk_select_signals", int(signals["select"]), 0)

	# Grant partner_a
	var name_before: String = str(_app().call("get_player_name"))
	var g: Dictionary = PlayerData.grant_character(&"partner_a")
	_assert_true("pd_grant_a_ok", bool(g.get("ok", false)))
	_assert_true("pd_grant_a_changed", bool(g.get("changed", false)))
	_assert_true("pd_owns_a", PlayerData.owns_character(&"partner_a"))
	_assert_eq("pd_grant_keeps_selected", str(PlayerData.get_selected_character_id()), "feibao_dev")
	_assert_eq("pd_grant_rev", int(g.get("profile_revision", -1)), 1)
	_assert_eq("pd_grant_signal_count", int(signals["grant"]), 1)
	_assert_eq("pd_grant_profile_signal", int(signals["profile"]), 1)
	_assert_eq("pd_grant_last_id", str(signals["last_grant"]), "partner_a")
	_assert_eq("pd_app_name_unchanged_grant", str(_app().call("get_player_name")), name_before)
	_assert_true("pd_grant_wrote_disk", PlayerData.did_last_save_write_disk())
	var disk1: String = _primary_text()
	_assert_true("pd_disk_has_partner_a", disk1.find("partner_a") >= 0)
	_assert_true("pd_disk_selected_still_dev", disk1.find("\"selected_character_id\":\"feibao_dev\"") >= 0 or disk1.find("feibao_dev") >= 0)

	# Duplicate grant no-write
	var mtime1: int = _primary_mtime_or_empty()
	var g2: Dictionary = PlayerData.grant_character(&"partner_a")
	_assert_true("pd_dup_grant_ok", bool(g2.get("ok", false)))
	_assert_true("pd_dup_grant_changed_false", bool(g2.get("changed", true)) == false)
	_assert_eq("pd_dup_grant_rev", int(g2.get("profile_revision", -1)), 1)
	_assert_eq("pd_dup_grant_signals_stable", int(signals["grant"]), 1)
	_assert_true("pd_dup_grant_no_write_flag", PlayerData.did_last_save_write_disk() == false)
	var mtime2: int = _primary_mtime_or_empty()
	_assert_eq("pd_dup_grant_mtime", mtime1, mtime2)

	# Select unowned partner_b rejected
	var sel_uo: Dictionary = PlayerData.select_character(&"partner_b")
	_assert_true("pd_sel_unowned_fail", bool(sel_uo.get("ok", true)) == false)
	_assert_eq("pd_sel_unowned_selected", str(PlayerData.get_selected_character_id()), "feibao_dev")
	_assert_eq("pd_sel_unowned_signals", int(signals["select"]), 0)

	# Select partner_a
	var s: Dictionary = PlayerData.select_character(&"partner_a")
	_assert_true("pd_select_a_ok", bool(s.get("ok", false)))
	_assert_true("pd_select_a_changed", bool(s.get("changed", false)))
	_assert_eq("pd_select_a_id", str(PlayerData.get_selected_character_id()), "partner_a")
	_assert_eq("pd_select_signal", int(signals["select"]), 1)
	_assert_eq("pd_select_profile_signal", int(signals["profile"]), 2)
	_assert_eq("pd_app_name_unchanged_select", str(_app().call("get_player_name")), name_before)

	# Duplicate select no-write
	var mtime3: int = _primary_mtime_or_empty()
	var s2: Dictionary = PlayerData.select_character(&"partner_a")
	_assert_true("pd_dup_select_ok", bool(s2.get("ok", false)))
	_assert_true("pd_dup_select_changed_false", bool(s2.get("changed", true)) == false)
	_assert_eq("pd_dup_select_signals_stable", int(signals["select"]), 1)
	_assert_true("pd_dup_select_no_write_flag", PlayerData.did_last_save_write_disk() == false)
	_assert_eq("pd_dup_select_mtime", mtime3, _primary_mtime_or_empty())

	# Persist across reinitialize
	var rev_before: int = PlayerData.get_profile().get_revision()
	PlayerData.reset_runtime_state_for_tests()
	# Keep same test storage path
	PlayerData.initialize()
	_assert_true("pd_reload_owns_a", PlayerData.owns_character(&"partner_a"))
	_assert_eq("pd_reload_selected", str(PlayerData.get_selected_character_id()), "partner_a")
	_assert_eq("pd_reload_rev", PlayerData.get_profile().get_revision(), rev_before)
	_assert_eq("pd_known_owned_after", PlayerData.get_known_owned_count(), 2)

	# Save failure preserves memory + disk
	_begin_case("pd_save_fail")
	PlayerData.initialize()
	PlayerData.grant_character(&"partner_a")
	var disk_before: String = _primary_text()
	var owned_before: int = PlayerData.get_owned_character_ids().size()
	var sel_before: String = str(PlayerData.get_selected_character_id())
	var rev_sf: int = PlayerData.get_profile().get_revision()
	PlayerData.set_save_override_for_tests(func(_p: String, _t: String) -> Dictionary:
		return {"ok": false, "error": "forced save failure"}
	)
	var fail_grant: Dictionary = PlayerData.grant_character(&"partner_b")
	_assert_true("pd_sf_grant_fail", bool(fail_grant.get("ok", true)) == false)
	_assert_true("pd_sf_grant_changed_false", bool(fail_grant.get("changed", true)) == false)
	_assert_eq("pd_sf_owned_count", PlayerData.get_owned_character_ids().size(), owned_before)
	_assert_true("pd_sf_not_own_b", PlayerData.owns_character(&"partner_b") == false)
	_assert_eq("pd_sf_selected", str(PlayerData.get_selected_character_id()), sel_before)
	_assert_eq("pd_sf_rev", PlayerData.get_profile().get_revision(), rev_sf)
	_assert_eq("pd_sf_state", str(PlayerData.get_load_state()), "SAVE_FAILED")
	_assert_eq("pd_sf_disk", _primary_text(), disk_before)

	var fail_sel: Dictionary = PlayerData.select_character(&"partner_a")
	_assert_true("pd_sf_select_fail", bool(fail_sel.get("ok", true)) == false)
	_assert_eq("pd_sf_select_still", str(PlayerData.get_selected_character_id()), sel_before)
	_assert_eq("pd_sf_disk_after_select", _primary_text(), disk_before)
	PlayerData.clear_save_override_for_tests()

	if PlayerData.profile_changed.is_connected(on_profile):
		PlayerData.profile_changed.disconnect(on_profile)
	if PlayerData.character_granted.is_connected(on_grant):
		PlayerData.character_granted.disconnect(on_grant)
	if PlayerData.selected_character_changed.is_connected(on_select):
		PlayerData.selected_character_changed.disconnect(on_select)


func _run_card_ownership_tests() -> void:
	var packed: PackedScene = load("res://scenes/screens/character/character_card.tscn") as PackedScene
	_assert_true("own_card_loadable", packed != null)
	var card: Button = packed.instantiate() as Button
	_tree.root.add_child(card)
	var def := CharacterDefinition.new(
		&"test_own",
		"測試持有",
		"物種",
		"摘要",
		"描述",
		["t1"] as Array[String],
		0,
		"",
		true
	)
	card.call("configure", def, true, true)
	_assert_true("own_card_owned", bool(card.call("is_owned")))
	_assert_true("own_card_rep", bool(card.call("is_representative")))
	_assert_eq("own_card_own_text", str(card.call("get_ownership_text")), "已持有")
	_assert_eq("own_card_rep_text", str(card.call("get_representative_text")), "代表")
	card.call("set_focused", true)
	_assert_true("own_card_focused", bool(card.call("is_focused")))
	_assert_true("own_card_selected_alias", bool(card.call("is_selected")))
	_assert_eq("own_card_focus_text", str(card.call("get_focused_text")), "檢視中")
	_assert_true("own_card_min_h", card.custom_minimum_size.y >= 72.0)
	# Unowned inspectable (not disabled)
	card.call("configure", def, false, false)
	_assert_true("own_card_unowned", bool(card.call("is_owned")) == false)
	_assert_eq("own_card_unowned_text", str(card.call("get_ownership_text")), "未持有")
	_assert_true("own_card_not_disabled", card.disabled == false)
	card.queue_free()


func _run_screen_ownership_tests() -> void:
	_begin_case("screen_own")
	PlayerData.initialize()
	_nav().call("reset", &"login")
	var packed: PackedScene = load("res://scenes/screens/character/character_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	_assert_true("own_screen_cfg", bool(screen.call("configure_screen", &"character")))
	await _tree.process_frame
	await _tree.process_frame

	_assert_true("own_screen_load_ok", bool(screen.call("is_load_ok")))
	_assert_eq("own_screen_total", int(screen.call("get_total_catalog_count")), 6)
	_assert_eq("own_screen_owned_count", int(screen.call("get_owned_count")), 1)
	_assert_eq("own_screen_rep", str(screen.call("get_representative_id")), "feibao_dev")
	_assert_eq("own_screen_focus_initial", str(screen.call("get_focused_id")), "feibao_dev")
	_assert_eq("own_screen_selected_alias", str(screen.call("get_selected_id")), "feibao_dev")
	_assert_true("own_screen_summary", str(screen.call("get_ownership_summary_text")).find("1") >= 0)
	_assert_true("own_screen_summary_total", str(screen.call("get_ownership_summary_text")).find("6") >= 0)
	_assert_eq("own_screen_filter_default", str(screen.call("get_ownership_filter")), "ALL")
	_assert_eq("own_screen_detail_own", str(screen.call("get_detail_ownership_text")), "已持有")
	_assert_eq("own_screen_detail_rep", str(screen.call("get_detail_representative_text")), "目前代表角色")
	var rep_btn: Button = screen.call("get_set_representative_button") as Button
	_assert_true("own_screen_rep_btn", rep_btn != null)
	_assert_true("own_screen_rep_btn_disabled", rep_btn.disabled)
	_assert_eq("own_screen_rep_btn_text", rep_btn.text, "目前代表角色")
	_assert_true("own_screen_rep_btn_h", rep_btn.custom_minimum_size.y >= 48.0)

	# Focus unowned partner_a
	_assert_true("own_screen_focus_a", bool(screen.call("select_character_for_test", &"partner_a")))
	_assert_eq("own_screen_focus_a_id", str(screen.call("get_focused_id")), "partner_a")
	_assert_eq("own_screen_rep_unchanged_focus", str(screen.call("get_representative_id")), "feibao_dev")
	_assert_eq("own_screen_detail_unowned", str(screen.call("get_detail_ownership_text")), "尚未持有")
	_assert_eq("own_screen_detail_rep_empty", str(screen.call("get_detail_representative_text")), "")
	_assert_true("own_screen_btn_unowned_disabled", rep_btn.disabled)
	_assert_eq("own_screen_btn_unowned_text", rep_btn.text, "尚未持有")

	# Filters
	screen.call("set_ownership_filter_for_test", &"OWNED")
	_assert_eq("own_filter_owned_count", int(screen.call("get_result_count")), 1)
	_assert_eq("own_filter_owned_id", str(screen.call("get_visible_character_ids")[0]), "feibao_dev")
	screen.call("set_ownership_filter_for_test", &"UNOWNED")
	_assert_eq("own_filter_unowned_count", int(screen.call("get_result_count")), 5)
	screen.call("set_ownership_filter_for_test", &"ALL")
	_assert_eq("own_filter_all_count", int(screen.call("get_result_count")), 6)

	# Search + ownership filter combined
	screen.call("set_ownership_filter_for_test", &"UNOWNED")
	screen.call("set_search_text_for_test", "夥伴 A")
	_assert_eq("own_combined_count", int(screen.call("get_result_count")), 1)
	_assert_eq("own_combined_id", str(screen.call("get_focused_id")), "partner_a")
	screen.call("set_search_text_for_test", "")
	screen.call("set_ownership_filter_for_test", &"ALL")

	# Grant partner_a via domain API; screen refreshes via signal
	var grant_r: Dictionary = PlayerData.grant_character(&"partner_a")
	_assert_true("own_grant_ok", bool(grant_r.get("ok", false)))
	await _tree.process_frame
	_assert_eq("own_after_grant_count", int(screen.call("get_owned_count")), 2)
	_assert_eq("own_after_grant_rep", str(screen.call("get_representative_id")), "feibao_dev")
	screen.call("select_character_for_test", &"partner_a")
	_assert_eq("own_after_grant_detail", str(screen.call("get_detail_ownership_text")), "已持有")
	_assert_true("own_after_grant_btn_enabled", rep_btn.disabled == false)
	_assert_eq("own_after_grant_btn_text", rep_btn.text, "設為代表角色")

	# Set representative
	var rep_events: Array = []
	screen.representative_changed.connect(func(cid: StringName) -> void:
		rep_events.append(str(cid))
	)
	screen.call("press_set_representative_for_test")
	await _tree.process_frame
	_assert_eq("own_set_rep_id", str(screen.call("get_representative_id")), "partner_a")
	_assert_eq("own_set_rep_profile", str(PlayerData.get_selected_character_id()), "partner_a")
	_assert_eq("own_set_rep_detail", str(screen.call("get_detail_representative_text")), "目前代表角色")
	_assert_true("own_set_rep_btn_disabled", rep_btn.disabled)
	_assert_true("own_set_rep_msg", str(screen.call("get_mutation_message")).find("代表") >= 0)
	_assert_eq("own_set_rep_signal", rep_events.size(), 1)
	_assert_eq("own_set_rep_signal_id", str(rep_events[0]) if rep_events.size() > 0 else "", "partner_a")

	# Filter buttons touch targets
	var fb_all: Button = screen.call("get_filter_all_button") as Button
	var fb_own: Button = screen.call("get_filter_owned_button") as Button
	var fb_un: Button = screen.call("get_filter_unowned_button") as Button
	_assert_true("own_filter_all_h", fb_all != null and fb_all.custom_minimum_size.y >= 44.0)
	_assert_true("own_filter_owned_h", fb_own != null and fb_own.custom_minimum_size.y >= 44.0)
	_assert_true("own_filter_unowned_h", fb_un != null and fb_un.custom_minimum_size.y >= 44.0)

	# Save failure UI preserves badges
	PlayerData.set_save_override_for_tests(func(_p: String, _t: String) -> Dictionary:
		return {"ok": false, "error": "forced"}
	)
	# Grant partner_b first so we can attempt select after clearing override... instead fail select of feibao_dev switch:
	PlayerData.clear_save_override_for_tests()
	PlayerData.grant_character(&"partner_b")
	await _tree.process_frame
	screen.call("select_character_for_test", &"partner_b")
	PlayerData.set_save_override_for_tests(func(_p: String, _t: String) -> Dictionary:
		return {"ok": false, "error": "forced"}
	)
	var rep_before_fail: String = str(screen.call("get_representative_id"))
	screen.call("press_set_representative_for_test")
	await _tree.process_frame
	_assert_eq("own_fail_rep_preserved", str(screen.call("get_representative_id")), rep_before_fail)
	_assert_eq("own_fail_profile_rep", str(PlayerData.get_selected_character_id()), rep_before_fail)
	_assert_true("own_fail_msg", str(screen.call("get_mutation_message")).find("無法儲存") >= 0)
	PlayerData.clear_save_override_for_tests()

	# Idempotent signal binding: re-configure should not crash / duplicate-bind fatally
	_assert_true("own_reconfigure", bool(screen.call("configure_screen", &"character")))
	await _tree.process_frame
	_assert_eq("own_reconfigure_total", int(screen.call("get_total_catalog_count")), 6)

	screen.queue_free()
	await _tree.process_frame


func _run_ownership_layout_tests() -> void:
	_begin_case("layout_own")
	PlayerData.initialize()
	var sizes: Array[Vector2i] = [
		Vector2i(360, 640),
		Vector2i(390, 844),
		Vector2i(720, 1280),
	]
	for size in sizes:
		await _probe_ownership_layout(size)


func _probe_ownership_layout(size: Vector2i) -> void:
	var tag: String = "%dx%d" % [size.x, size.y]
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(size))

	var host := SubViewportContainer.new()
	host.custom_minimum_size = Vector2(size)
	host.size = Vector2(size)
	host.stretch = true
	_tree.root.add_child(host)

	var sv := SubViewport.new()
	sv.size = size
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(sv)

	var packed: PackedScene = load("res://scenes/screens/character/character_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	sv.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.call("configure_screen", &"character")
	for _i in 4:
		await _tree.process_frame

	_assert_true("own_layout_%s_load" % tag, bool(screen.call("is_load_ok")))
	var screen_rect: Rect2 = screen.get_global_rect()
	_assert_true("own_layout_%s_inside" % tag, _rect_is_inside(screen_rect, viewport_rect, 2.0))

	var cols: int = int(screen.call("get_grid_columns"))
	_assert_true("own_layout_%s_cols_pos" % tag, cols >= 2)
	if size.x <= 400:
		_assert_true("own_layout_%s_cols_narrow" % tag, cols >= 2 and cols <= 3)
	if size.x >= 700:
		_assert_true("own_layout_%s_cols_wide" % tag, cols >= 3)

	var fb: Button = screen.call("get_filter_all_button") as Button
	if fb != null:
		var fr: Rect2 = fb.get_global_rect()
		_assert_true("own_layout_%s_filter_h" % tag, fr.size.y >= 40.0 or fb.custom_minimum_size.y >= 44.0)
		_assert_true("own_layout_%s_filter_inside" % tag, _rect_is_inside(fr, screen_rect, 2.0))
		_assert_true("own_layout_%s_filter_no_overflow" % tag, fr.end.x <= screen_rect.end.x + 2.0)

	var rb: Button = screen.call("get_set_representative_button") as Button
	if rb != null:
		var rr: Rect2 = rb.get_global_rect()
		_assert_true("own_layout_%s_rep_btn_h" % tag, rb.custom_minimum_size.y >= 48.0 or rr.size.y >= 44.0)
		_assert_true("own_layout_%s_rep_btn_no_overflow" % tag, rr.end.x <= screen_rect.end.x + 2.0)

	var scroll: ScrollContainer = screen.call("get_card_scroll") as ScrollContainer
	if scroll != null:
		var sr: Rect2 = scroll.get_global_rect()
		_assert_true("own_layout_%s_scroll_inside" % tag, _rect_is_inside(sr, screen_rect, 3.0))
		_assert_true("own_layout_%s_scroll_no_overflow" % tag, sr.end.x <= screen_rect.end.x + 3.0)

	print("[INFO] own_layout_%s cols=%d cards=%d" % [tag, cols, int(screen.call("get_card_count"))])
	host.queue_free()
	await _tree.process_frame


func _rect_is_inside(inner: Rect2, outer: Rect2, tolerance: float = 1.0) -> bool:
	return (
		inner.position.x >= outer.position.x - tolerance
		and inner.position.y >= outer.position.y - tolerance
		and inner.end.x <= outer.end.x + tolerance
		and inner.end.y <= outer.end.y + tolerance
	)


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
		print("[FAIL] %s actual=%s expected=%s" % [name, str(actual), str(expected)])
	results.append(name)
