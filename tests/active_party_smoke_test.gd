## Active party formation + schema v2 migration tests (0.7.0).
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
	_run_codec_schema_dispatch_tests()
	_run_profile_party_tests()
	_run_player_data_migration_tests()
	_run_player_data_party_tests()
	await _run_party_screen_tests()
	await _run_party_layout_tests()
	_cleanup_all_cases()
	PlayerData.configure_test_storage_path("user://feibao_tests/suite_main")
	PlayerData.reset_runtime_state_for_tests()
	var prod_after: Dictionary = _snapshot_production_artifacts()
	_assert_production_fingerprints_unchanged(prod_before, prod_after)
	print("[INFO] active party suite production fingerprints unchanged")


func _app() -> Node:
	return _tree.root.get_node("AppState")


func _nav() -> Node:
	return _tree.root.get_node("NavigationState")


func _unique_case(tag: String) -> String:
	var path: String = "user://feibao_tests/party_%s_%d" % [tag, Time.get_ticks_usec()]
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
	if not FileAccess.file_exists(path):
		return {"exists": false, "sha256": "", "length": -1}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"exists": true, "sha256": "UNREADABLE", "length": -1}
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return {"exists": true, "sha256": ctx.finish().hex_encode(), "length": bytes.size()}


func _assert_production_fingerprints_unchanged(before: Dictionary, after: Dictionary) -> void:
	for path in _prod_paths():
		var b: Dictionary = before.get(path, {}) as Dictionary
		var a: Dictionary = after.get(path, {}) as Dictionary
		_assert_eq("party_prod_fp_exists_%s" % path.get_file(), bool(b.get("exists", false)), bool(a.get("exists", false)))
		_assert_eq("party_prod_fp_sha_%s" % path.get_file(), str(b.get("sha256", "")), str(a.get("sha256", "")))
		_assert_eq("party_prod_fp_len_%s" % path.get_file(), int(b.get("length", -2)), int(a.get("length", -3)))


func _schema1_json(name: String = "A", selected: String = "feibao_dev", rev: int = 0, owned: String = "feibao_dev") -> String:
	return (
		'{"schema_version":1,"profile_kind":"local_player","player_name":"%s",'
		% name
		+ '"owned_character_ids":[%s],"selected_character_id":"%s","revision":%d}'
		% [_owned_json_list(owned), selected, rev]
	)


func _owned_json_list(owned_csv: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for piece in owned_csv.split(","):
		parts.append('"%s"' % piece.strip_edges())
	return ",".join(parts)


func _schema2_json(
	name: String = "A",
	selected: String = "feibao_dev",
	party_csv: String = "feibao_dev",
	rev: int = 0,
	owned_csv: String = "feibao_dev"
) -> String:
	return (
		'{"schema_version":2,"profile_kind":"local_player","player_name":"%s",'
		% name
		+ '"owned_character_ids":[%s],"selected_character_id":"%s",'
		% [_owned_json_list(owned_csv), selected]
		+ '"active_party_character_ids":[%s],"revision":%d}'
		% [_owned_json_list(party_csv), rev]
	)


func _primary_text() -> String:
	var path: String = PlayerData.get_primary_path()
	if not FileAccess.file_exists(path):
		return ""
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t: String = f.get_as_text()
	f.close()
	return t


func _write_primary(text: String) -> void:
	var path: String = PlayerData.get_primary_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _party_ids_str(profile: PlayerProfile) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for id in profile.get_active_party_character_ids():
		parts.append(str(id))
	return ",".join(parts)


func _run_codec_schema_dispatch_tests() -> void:
	var s1: Dictionary = PlayerProfileCodec.parse_json_text(_schema1_json("Hero", "feibao_dev", 3))
	_assert_true("codec_s1_ok", bool(s1.get("ok", false)))
	_assert_eq("codec_s1_source", int(s1.get("source_schema_version", -1)), 1)
	_assert_true("codec_s1_migration", bool(s1.get("migration_required", false)))
	var p1: PlayerProfile = s1.get("profile") as PlayerProfile
	_assert_true("codec_s1_profile", p1 != null)
	if p1 != null:
		_assert_eq("codec_s1_memory_schema", p1.get_schema_version(), 2)
		_assert_eq("codec_s1_rev_unchanged", p1.get_revision(), 3)
		_assert_eq("codec_s1_party", _party_ids_str(p1), "feibao_dev")
		_assert_eq("codec_s1_selected", str(p1.get_selected_character_id()), "feibao_dev")

	var s10: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":1.0,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev","revision":0}'
	)
	_assert_true("codec_s1_0_ok", bool(s10.get("ok", false)))

	var s15: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":1.5,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev","revision":0}'
	)
	_assert_true("codec_s1_5_reject", bool(s15.get("ok", true)) == false)
	_assert_true("codec_s1_5_null", s15.get("profile") == null)

	var s2: Dictionary = PlayerProfileCodec.parse_json_text(_schema2_json())
	_assert_true("codec_s2_ok", bool(s2.get("ok", false)))
	_assert_eq("codec_s2_source", int(s2.get("source_schema_version", -1)), 2)
	_assert_true("codec_s2_no_migration", bool(s2.get("migration_required", true)) == false)

	var s20: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":2.0,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev",'
		+ '"active_party_character_ids":["feibao_dev"],"revision":0}'
	)
	_assert_true("codec_s2_0_ok", bool(s20.get("ok", false)))

	var s25: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":2.5,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev",'
		+ '"active_party_character_ids":["feibao_dev"],"revision":0}'
	)
	_assert_true("codec_s2_5_reject", bool(s25.get("ok", true)) == false)

	var s0: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":0,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev","revision":0}'
	)
	_assert_true("codec_s0_reject", bool(s0.get("ok", true)) == false)
	var s3: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":3,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev",'
		+ '"active_party_character_ids":["feibao_dev"],"revision":0}'
	)
	_assert_true("codec_s3_reject", bool(s3.get("ok", true)) == false)

	var s1_extra: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":1,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev",'
		+ '"active_party_character_ids":["feibao_dev"],"revision":0}'
	)
	_assert_true("codec_s1_extra_party_reject", bool(s1_extra.get("ok", true)) == false)

	var s2_missing: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":2,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev","revision":0}'
	)
	_assert_true("codec_s2_missing_party_reject", bool(s2_missing.get("ok", true)) == false)

	var empty_party: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":2,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev",'
		+ '"active_party_character_ids":[],"revision":0}'
	)
	_assert_true("codec_empty_party_reject", bool(empty_party.get("ok", true)) == false)

	var size4: Dictionary = PlayerProfileCodec.parse_json_text(
		_schema2_json("A", "feibao_dev", "feibao_dev,partner_a,partner_b,partner_c", 0, "feibao_dev,partner_a,partner_b,partner_c")
	)
	_assert_true("codec_party4_reject", bool(size4.get("ok", true)) == false)

	var dup_party: Dictionary = PlayerProfileCodec.parse_json_text(
		_schema2_json("A", "feibao_dev", "feibao_dev,feibao_dev", 0, "feibao_dev")
	)
	_assert_true("codec_dup_party_reject", bool(dup_party.get("ok", true)) == false)

	var not_owned_party: Dictionary = PlayerProfileCodec.parse_json_text(
		_schema2_json("A", "feibao_dev", "partner_a", 0, "feibao_dev")
	)
	_assert_true("codec_party_not_owned_reject", bool(not_owned_party.get("ok", true)) == false)

	var sel_not_in_party: Dictionary = PlayerProfileCodec.parse_json_text(
		_schema2_json("A", "partner_a", "feibao_dev", 0, "feibao_dev,partner_a")
	)
	_assert_true("codec_sel_outside_party_ok", bool(sel_not_in_party.get("ok", false)))

	var unknown_owned: Dictionary = PlayerProfileCodec.parse_json_text(
		_schema2_json("A", "ghost_x", "ghost_x", 0, "ghost_x")
	)
	_assert_true("codec_unknown_owned_party_ok", bool(unknown_owned.get("ok", false)))

	var enc: Dictionary = PlayerProfileCodec.encode_profile(PlayerProfile.create_default())
	_assert_true("codec_encode_ok", bool(enc.get("ok", false)))
	_assert_true("codec_encode_newline", str(enc.get("text", "")).ends_with("\n"))
	_assert_eq("codec_encode_schema", int(enc.get("schema_version", -1)), 2)
	_assert_true("codec_encode_has_party", str(enc.get("text", "")).find("active_party_character_ids") >= 0)
	var round: Dictionary = PlayerProfileCodec.parse_json_text(str(enc.get("text", "")))
	_assert_true("codec_round_ok", bool(round.get("ok", false)))
	print("[INFO] codec schema dispatch passed")


func _run_profile_party_tests() -> void:
	var def: PlayerProfile = PlayerProfile.create_default()
	_assert_eq("prof_schema2", def.get_schema_version(), 2)
	_assert_eq("prof_party_size", def.get_active_party_size(), 1)
	_assert_eq("prof_leader", str(def.get_party_leader_character_id()), "feibao_dev")
	_assert_eq("prof_party0", str(def.get_active_party_character_ids()[0]), "feibao_dev")
	var copy: Array[StringName] = def.get_active_party_character_ids()
	copy.append(&"hack")
	_assert_eq("prof_party_defensive", def.get_active_party_size(), 1)

	# Need owned partner for add: grant first
	var g: Dictionary = def.with_character_granted(&"partner_a")
	var owned: PlayerProfile = g["profile"] as PlayerProfile
	var add1: Dictionary = owned.with_party_member_added(&"partner_a")
	_assert_true("prof_add_ok", bool(add1.get("ok", false)))
	_assert_true("prof_add_changed", bool(add1.get("changed", false)))
	var p2: PlayerProfile = add1["profile"] as PlayerProfile
	_assert_eq("prof_add_size", p2.get_active_party_size(), 2)
	_assert_eq("prof_add_sel", str(p2.get_selected_character_id()), "feibao_dev")
	_assert_eq("prof_add_rev", p2.get_revision(), 2) # grant+1 add+1 from default 0

	var dup_add: Dictionary = p2.with_party_member_added(&"partner_a")
	_assert_true("prof_dup_add_ok", bool(dup_add.get("ok", false)))
	_assert_true("prof_dup_add_no_change", bool(dup_add.get("changed", true)) == false)

	var unowned: Dictionary = def.with_party_member_added(&"partner_a")
	_assert_true("prof_unowned_add_fail", bool(unowned.get("ok", true)) == false)

	var g2: Dictionary = p2.with_character_granted(&"partner_b")
	var p3base: PlayerProfile = g2["profile"] as PlayerProfile
	var add_b: Dictionary = p3base.with_party_member_added(&"partner_b")
	var full: PlayerProfile = add_b["profile"] as PlayerProfile
	_assert_eq("prof_full_size", full.get_active_party_size(), 3)
	var g3: Dictionary = full.with_character_granted(&"partner_c")
	var full_owned: PlayerProfile = g3["profile"] as PlayerProfile
	var add_full: Dictionary = full_owned.with_party_member_added(&"partner_c")
	_assert_true("prof_full_reject", bool(add_full.get("ok", true)) == false)

	var rem: Dictionary = full.with_party_member_removed(&"partner_b")
	_assert_true("prof_rem_ok", bool(rem.get("ok", false)))
	var after_rem: PlayerProfile = rem["profile"] as PlayerProfile
	_assert_eq("prof_rem_size", after_rem.get_active_party_size(), 2)
	_assert_eq("prof_rem_sel", str(after_rem.get_selected_character_id()), "feibao_dev")

	var rem_abs: Dictionary = after_rem.with_party_member_removed(&"partner_c")
	_assert_true("prof_rem_absent_ok", bool(rem_abs.get("ok", false)))
	_assert_true("prof_rem_absent_no_change", bool(rem_abs.get("changed", true)) == false)

	var only: PlayerProfile = PlayerProfile.create_default()
	var rem_last: Dictionary = only.with_party_member_removed(&"feibao_dev")
	_assert_true("prof_rem_last_fail", bool(rem_last.get("ok", true)) == false)

	var move: Dictionary = after_rem.with_party_member_moved(&"partner_a", 0)
	_assert_true("prof_move_ok", bool(move.get("ok", false)))
	var moved: PlayerProfile = move["profile"] as PlayerProfile
	_assert_eq("prof_move_leader", str(moved.get_party_leader_character_id()), "partner_a")
	_assert_eq("prof_move_sel", str(moved.get_selected_character_id()), "feibao_dev")
	var move_same: Dictionary = moved.with_party_member_moved(&"partner_a", 0)
	_assert_true("prof_move_same_no_change", bool(move_same.get("changed", true)) == false)
	var move_bad: Dictionary = moved.with_party_member_moved(&"partner_a", 9)
	_assert_true("prof_move_bad_idx", bool(move_bad.get("ok", true)) == false)
	_assert_eq("prof_orig_party", def.get_active_party_size(), 1)
	print("[INFO] profile party mutations passed")


func _run_player_data_migration_tests() -> void:
	_begin_case("mig_s1")
	_write_primary(_schema1_json("MigUser", "feibao_dev", 2))
	var fp_before: Dictionary = _file_fingerprint(PlayerData.get_primary_path())
	PlayerData.initialize()
	_assert_eq("mig_state", str(PlayerData.get_load_state()), "LOADED_PRIMARY")
	_assert_true("mig_pending", PlayerData.is_profile_migration_pending())
	_assert_eq("mig_source", PlayerData.get_loaded_source_schema_version(), 1)
	_assert_eq("mig_memory_schema", PlayerData.get_profile().get_schema_version(), 2)
	_assert_eq("mig_party", str(PlayerData.get_party_leader_character_id()), "feibao_dev")
	_assert_eq("mig_name", PlayerData.get_player_name(), "MigUser")
	_assert_true("mig_no_boot_write", PlayerData.did_last_save_write_disk() == false)
	var fp_after: Dictionary = _file_fingerprint(PlayerData.get_primary_path())
	_assert_eq("mig_fp_sha", str(fp_before.get("sha256")), str(fp_after.get("sha256")))
	_assert_true("mig_disk_still_s1", _primary_text().find('"schema_version":1') >= 0 or _primary_text().find('"schema_version": 1') >= 0)

	# no-change does not write
	var g_dup: Dictionary = PlayerData.grant_character(&"feibao_dev")
	_assert_true("mig_dup_ok", bool(g_dup.get("ok", false)))
	_assert_true("mig_dup_no_change", bool(g_dup.get("changed", true)) == false)
	_assert_true("mig_still_pending", PlayerData.is_profile_migration_pending())
	_assert_true("mig_dup_no_write", PlayerData.did_last_save_write_disk() == false)

	# changed save converts to schema 2
	PlayerData.grant_character(&"partner_a")
	_assert_true("mig_grant_ok", PlayerData.owns_character(&"partner_a"))
	_assert_true("mig_cleared", PlayerData.is_profile_migration_pending() == false)
	_assert_eq("mig_source_after", PlayerData.get_loaded_source_schema_version(), 2)
	_assert_true("mig_disk_s2", _primary_text().find("active_party_character_ids") >= 0)
	_assert_true("mig_disk_schema2", _primary_text().find('"schema_version":2') >= 0 or _primary_text().find('"schema_version": 2') >= 0)
	_assert_eq("mig_party_after_grant", PlayerData.get_active_party_character_ids().size(), 1)

	# save failure keeps pending
	_begin_case("mig_fail")
	_write_primary(_schema1_json("FailUser", "feibao_dev", 1))
	PlayerData.initialize()
	_assert_true("mig_fail_pending", PlayerData.is_profile_migration_pending())
	PlayerData.set_save_override_for_tests(func(_p: String, _t: String) -> Dictionary:
		return {"ok": false, "error": "forced"}
	)
	var disk_before: String = _primary_text()
	var fail: Dictionary = PlayerData.grant_character(&"partner_a")
	_assert_true("mig_fail_ok_false", bool(fail.get("ok", true)) == false)
	_assert_true("mig_fail_still_pending", PlayerData.is_profile_migration_pending())
	_assert_eq("mig_fail_source", PlayerData.get_loaded_source_schema_version(), 1)
	_assert_eq("mig_fail_disk", _primary_text(), disk_before)
	_assert_true("mig_fail_not_own", PlayerData.owns_character(&"partner_a") == false)
	PlayerData.clear_save_override_for_tests()

	# backup recovery schema 1
	_begin_case("mig_bak")
	var primary: String = PlayerData.get_primary_path()
	DirAccess.make_dir_recursive_absolute(primary.get_base_dir())
	var bak: FileAccess = FileAccess.open(primary + ".bak", FileAccess.WRITE)
	bak.store_string(_schema1_json("BakUser", "feibao_dev", 4))
	bak.close()
	var pri: FileAccess = FileAccess.open(primary, FileAccess.WRITE)
	pri.store_string("{not json")
	pri.close()
	PlayerData.initialize()
	_assert_eq("mig_bak_state", str(PlayerData.get_load_state()), "RECOVERED_BACKUP")
	_assert_true("mig_bak_pending", PlayerData.is_profile_migration_pending())
	_assert_eq("mig_bak_source", PlayerData.get_loaded_source_schema_version(), 1)
	_assert_eq("mig_bak_name", PlayerData.get_player_name(), "BakUser")

	# transaction includes migration state
	_begin_case("mig_tx")
	_write_primary(_schema1_json("TxUser", "feibao_dev", 0))
	PlayerData.initialize()
	var cap: Dictionary = PlayerData.capture_persistence_transaction()
	_assert_true("mig_tx_cap", bool(cap.get("ok", false)))
	var tx: Dictionary = cap.get("transaction", {}) as Dictionary
	_assert_true("mig_tx_pending_field", bool(tx.get("profile_migration_pending", false)))
	_assert_eq("mig_tx_source_field", int(tx.get("loaded_source_schema_version", -1)), 1)
	PlayerData.grant_character(&"partner_a")
	_assert_true("mig_tx_after_not_pending", PlayerData.is_profile_migration_pending() == false)
	var rb: Dictionary = PlayerData.rollback_persistence_transaction(tx)
	_assert_true("mig_tx_rb_ok", bool(rb.get("ok", false)))
	_assert_true("mig_tx_rb_pending", PlayerData.is_profile_migration_pending())
	_assert_eq("mig_tx_rb_source", PlayerData.get_loaded_source_schema_version(), 1)
	print("[INFO] player data migration passed")


func _run_player_data_party_tests() -> void:
	_begin_case("pd_party")
	PlayerData.initialize()
	_assert_eq("pd_party_default_size", PlayerData.get_active_party_character_ids().size(), 1)
	_assert_eq("pd_party_leader", str(PlayerData.get_party_leader_character_id()), "feibao_dev")
	_assert_true("pd_party_in", PlayerData.is_character_in_active_party(&"feibao_dev"))

	var sig: Dictionary = {"profile": 0, "party": 0, "last_party": ""}
	var on_p := func(_r: int) -> void:
		sig["profile"] = int(sig["profile"]) + 1
	var on_party := func(ids: Array, _r: int) -> void:
		sig["party"] = int(sig["party"]) + 1
		var parts: PackedStringArray = PackedStringArray()
		for id in ids:
			parts.append(str(id))
		sig["last_party"] = ",".join(parts)
	PlayerData.profile_changed.connect(on_p)
	PlayerData.party_changed.connect(on_party)

	var unk: Dictionary = PlayerData.add_party_member(&"ghost_xyz")
	_assert_true("pd_unk_add_fail", bool(unk.get("ok", true)) == false)
	var unowned: Dictionary = PlayerData.add_party_member(&"partner_a")
	_assert_true("pd_unowned_add_fail", bool(unowned.get("ok", true)) == false)

	PlayerData.grant_character(&"partner_a")
	_assert_eq("pd_grant_party_unchanged", PlayerData.get_active_party_character_ids().size(), 1)
	var add: Dictionary = PlayerData.add_party_member(&"partner_a")
	_assert_true("pd_add_ok", bool(add.get("ok", false)))
	_assert_true("pd_add_changed", bool(add.get("changed", false)))
	_assert_eq("pd_add_size", PlayerData.get_active_party_character_ids().size(), 2)
	_assert_eq("pd_add_sel", str(PlayerData.get_selected_character_id()), "feibao_dev")
	_assert_eq("pd_add_party_sig", int(sig["party"]), 1)
	_assert_true("pd_add_wrote", PlayerData.did_last_save_write_disk())

	var dup: Dictionary = PlayerData.add_party_member(&"partner_a")
	_assert_true("pd_dup_add_ok", bool(dup.get("ok", false)))
	_assert_true("pd_dup_add_no_change", bool(dup.get("changed", true)) == false)
	_assert_eq("pd_dup_party_sig", int(sig["party"]), 1)

	PlayerData.grant_character(&"partner_b")
	PlayerData.add_party_member(&"partner_b")
	_assert_eq("pd_full_size", PlayerData.get_active_party_character_ids().size(), 3)
	PlayerData.grant_character(&"partner_c")
	var full: Dictionary = PlayerData.add_party_member(&"partner_c")
	_assert_true("pd_full_reject", bool(full.get("ok", true)) == false)

	var rem: Dictionary = PlayerData.remove_party_member(&"partner_b")
	_assert_true("pd_rem_ok", bool(rem.get("ok", false)))
	_assert_eq("pd_rem_size", PlayerData.get_active_party_character_ids().size(), 2)

	var move: Dictionary = PlayerData.move_party_member(&"partner_a", 0)
	_assert_true("pd_move_ok", bool(move.get("ok", false)))
	_assert_eq("pd_move_leader", str(PlayerData.get_party_leader_character_id()), "partner_a")
	_assert_eq("pd_move_sel", str(PlayerData.get_selected_character_id()), "feibao_dev")

	# restart
	var party_before: String = str(sig["last_party"])
	var rev: int = PlayerData.get_profile().get_revision()
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	_assert_eq("pd_reload_leader", str(PlayerData.get_party_leader_character_id()), "partner_a")
	_assert_eq("pd_reload_size", PlayerData.get_active_party_character_ids().size(), 2)
	_assert_eq("pd_reload_rev", PlayerData.get_profile().get_revision(), rev)

	# save failure preserves
	PlayerData.set_save_override_for_tests(func(_p: String, _t: String) -> Dictionary:
		return {"ok": false, "error": "forced"}
	)
	var disk: String = _primary_text()
	var size_before: int = PlayerData.get_active_party_character_ids().size()
	var fail_add: Dictionary = PlayerData.add_party_member(&"partner_b")
	_assert_true("pd_sf_fail", bool(fail_add.get("ok", true)) == false)
	_assert_eq("pd_sf_size", PlayerData.get_active_party_character_ids().size(), size_before)
	_assert_eq("pd_sf_disk", _primary_text(), disk)
	PlayerData.clear_save_override_for_tests()
	var retry: Dictionary = PlayerData.add_party_member(&"partner_b")
	_assert_true("pd_retry_ok", bool(retry.get("ok", false)))
	_assert_eq("pd_retry_state", str(PlayerData.get_load_state()), "LOADED_PRIMARY")

	if PlayerData.profile_changed.is_connected(on_p):
		PlayerData.profile_changed.disconnect(on_p)
	if PlayerData.party_changed.is_connected(on_party):
		PlayerData.party_changed.disconnect(on_party)
	print("[INFO] player data party domain passed party_before=%s" % party_before)


func _run_party_screen_tests() -> void:
	_begin_case("screen_party")
	PlayerData.initialize()
	_nav().call("reset", &"login")
	_assert_eq("reg_party_path", ScreenRegistry.get_scene_path(&"party"), "res://scenes/screens/party/party_screen.tscn")
	_assert_eq("reg_adv_path", ScreenRegistry.get_scene_path(&"adventure"), "res://scenes/screens/module/module_screen.tscn")

	var packed: PackedScene = load("res://scenes/screens/party/party_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	_assert_true("ps_cfg", bool(screen.call("configure_screen", &"party")))
	_assert_true("ps_reject_char", bool(screen.call("configure_screen", &"character")) == false)
	await _tree.process_frame
	await _tree.process_frame

	_assert_eq("ps_size", int(screen.call("get_party_size")), 1)
	_assert_eq("ps_leader", str(screen.call("get_leader_id")), "feibao_dev")
	_assert_eq("ps_roster", int(screen.call("get_roster_count")), 1)
	_assert_true("ps_summary", str(screen.call("get_party_summary_text")).find("1") >= 0)
	_assert_true("ps_leader_sum", str(screen.call("get_leader_summary_text")).find("飛寶") >= 0 or str(screen.call("get_leader_summary_text")).find("feibao") >= 0)
	var slots: Container = screen.call("get_party_slots_container") as Container
	_assert_true("ps_three_slots", slots != null and slots.get_child_count() == 3)

	var add_btn: Button = screen.call("get_add_button") as Button
	var rem_btn: Button = screen.call("get_remove_button") as Button
	_assert_true("ps_add_min_h", add_btn != null and add_btn.custom_minimum_size.y >= 48.0)
	_assert_true("ps_rem_min_h", rem_btn != null and rem_btn.custom_minimum_size.y >= 48.0)
	_assert_true("ps_back_min_h", (screen.call("get_back_button") as Button).custom_minimum_size.y >= 48.0)

	# grant partner_a refreshes roster not party (via profile_changed)
	screen.call("reset_party_refresh_count_for_tests")
	PlayerData.grant_character(&"partner_a")
	await _tree.process_frame
	_assert_eq("ps_grant_refresh", int(screen.call("get_party_refresh_count_for_tests")), 1)
	_assert_eq("ps_grant_party", int(screen.call("get_party_size")), 1)
	_assert_eq("ps_grant_roster", int(screen.call("get_roster_count")), 2)

	_assert_true("ps_focus_a", bool(screen.call("focus_character_for_test", &"partner_a")))
	_assert_true("ps_add_enabled", add_btn.disabled == false)
	screen.call("reset_party_refresh_count_for_tests")
	var add_events: Array = []
	screen.party_member_added.connect(func(cid: StringName) -> void:
		add_events.append(str(cid))
	)
	screen.call("press_add_for_test")
	await _tree.process_frame
	_assert_eq("ps_add_refresh", int(screen.call("get_party_refresh_count_for_tests")), 1)
	_assert_eq("ps_add_size", int(screen.call("get_party_size")), 2)
	_assert_eq("ps_add_signal", add_events.size(), 1)
	_assert_eq("ps_add_sel", str(PlayerData.get_selected_character_id()), "feibao_dev")

	screen.call("reset_party_refresh_count_for_tests")
	screen.call("press_add_for_test")
	_assert_eq("ps_dup_add_refresh", int(screen.call("get_party_refresh_count_for_tests")), 0)

	_assert_true("ps_focus_a2", bool(screen.call("focus_character_for_test", &"partner_a")))
	screen.call("reset_party_refresh_count_for_tests")
	screen.call("press_remove_for_test")
	await _tree.process_frame
	_assert_eq("ps_rem_refresh", int(screen.call("get_party_refresh_count_for_tests")), 1)
	_assert_eq("ps_rem_size", int(screen.call("get_party_size")), 1)
	# Focus must land on remaining party member, not the removed roster card.
	_assert_eq("ps_rem_focus", str(screen.call("get_focused_id")), "feibao_dev")
	_assert_true("ps_rem_focus_in_party", PlayerData.is_character_in_active_party(&"feibao_dev"))
	_assert_true(
		"ps_rem_detail_party",
		str(screen.call("get_detail_status_text")).find("隊伍") >= 0
		or str(screen.call("get_detail_status_text")).find("領隊") >= 0
	)
	# Action state: only leader left → remove disabled, move disabled.
	_assert_true("ps_rem_after_remove_disabled", rem_btn.disabled)
	_assert_true("ps_move_l_disabled_after", (screen.call("get_move_left_button") as Button).disabled)
	_assert_true("ps_move_r_disabled_after", (screen.call("get_move_right_button") as Button).disabled)

	# cannot remove last
	_assert_true("ps_focus_dev", bool(screen.call("focus_character_for_test", &"feibao_dev")))
	_assert_true("ps_rem_disabled", rem_btn.disabled)
	screen.call("reset_party_refresh_count_for_tests")
	screen.call("press_remove_for_test")
	_assert_eq("ps_rem_last_refresh", int(screen.call("get_party_refresh_count_for_tests")), 0)
	_assert_eq("ps_rem_last_focus", str(screen.call("get_focused_id")), "feibao_dev")

	# reorder
	PlayerData.grant_character(&"partner_b")
	await _tree.process_frame
	screen.call("focus_character_for_test", &"partner_a")
	screen.call("press_add_for_test")
	await _tree.process_frame
	screen.call("focus_character_for_test", &"partner_b")
	screen.call("press_add_for_test")
	await _tree.process_frame
	_assert_eq("ps_three", int(screen.call("get_party_size")), 3)
	screen.call("focus_character_for_test", &"partner_b")
	screen.call("reset_party_refresh_count_for_tests")
	var order_events: Array = []
	screen.party_order_changed.connect(func(ids: Array) -> void:
		order_events.append(ids.size())
	)
	screen.call("press_move_left_for_test")
	await _tree.process_frame
	_assert_eq("ps_move_refresh", int(screen.call("get_party_refresh_count_for_tests")), 1)
	_assert_eq("ps_move_signal", order_events.size(), 1)
	_assert_eq("ps_focus_kept", str(screen.call("get_focused_id")), "partner_b")
	_assert_eq("ps_sel_still", str(PlayerData.get_selected_character_id()), "feibao_dev")

	# save failure message only
	screen.call("focus_character_for_test", &"feibao_dev")
	# ensure feibao not alone for remove - actually party has 3
	PlayerData.set_save_override_for_tests(func(_p: String, _t: String) -> Dictionary:
		return {"ok": false, "error": "forced"}
	)
	var size_bf: int = int(screen.call("get_party_size"))
	screen.call("reset_party_refresh_count_for_tests")
	screen.call("press_remove_for_test")
	_assert_eq("ps_fail_refresh", int(screen.call("get_party_refresh_count_for_tests")), 0)
	_assert_eq("ps_fail_size", int(screen.call("get_party_size")), size_bf)
	_assert_true("ps_fail_msg", str(screen.call("get_mutation_message")).find("無法儲存") >= 0)
	PlayerData.clear_save_override_for_tests()

	# reconfigure idempotent
	_assert_true("ps_reconfig", bool(screen.call("configure_screen", &"party")))
	await _tree.process_frame
	screen.call("reset_party_refresh_count_for_tests")
	# trigger external change - remove partner_b if present else partner_a
	if PlayerData.is_character_in_active_party(&"partner_b"):
		PlayerData.remove_party_member(&"partner_b")
	else:
		PlayerData.remove_party_member(&"partner_a")
	await _tree.process_frame
	_assert_eq("ps_reconfig_refresh", int(screen.call("get_party_refresh_count_for_tests")), 1)

	screen.queue_free()
	await _tree.process_frame

	# Dedicated remove middle / tail / leader focus consistency suite.
	await _run_remove_focus_matrix_tests()
	print("[INFO] party screen tests passed")


func _run_remove_focus_matrix_tests() -> void:
	_begin_case("remove_focus_matrix")
	PlayerData.initialize()
	PlayerData.grant_character(&"partner_a")
	PlayerData.grant_character(&"partner_b")
	PlayerData.add_party_member(&"partner_a")
	PlayerData.add_party_member(&"partner_b")
	# party: [feibao_dev, partner_a, partner_b]
	var packed: PackedScene = load("res://scenes/screens/party/party_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	screen.call("configure_screen", &"party")
	await _tree.process_frame
	await _tree.process_frame
	_assert_eq("rf_party3", int(screen.call("get_party_size")), 3)

	# remove middle partner_a → focus partner_b
	_assert_true("rf_mid_focus", bool(screen.call("focus_character_for_test", &"partner_a")))
	screen.call("reset_party_refresh_count_for_tests")
	screen.call("press_remove_for_test")
	await _tree.process_frame
	_assert_eq("rf_mid_refresh", int(screen.call("get_party_refresh_count_for_tests")), 1)
	_assert_eq("rf_mid_party", int(screen.call("get_party_size")), 2)
	_assert_eq("rf_mid_focus_id", str(screen.call("get_focused_id")), "partner_b")
	_assert_eq("rf_mid_slot_vis", str(screen.call("get_focused_slot_character_id")), "partner_b")
	_assert_eq("rf_mid_roster_vis", str(screen.call("get_focused_roster_character_id")), "partner_b")
	_assert_true("rf_mid_detail", str(screen.call("get_detail_name_text")).find("夥伴") >= 0 or str(screen.call("get_detail_name_text")).length() > 0)
	_assert_true("rf_mid_add_disabled", (screen.call("get_add_button") as Button).disabled)
	_assert_true("rf_mid_rem_enabled", (screen.call("get_remove_button") as Button).disabled == false)

	# restore 3 for leader remove: add partner_a back
	screen.call("focus_character_for_test", &"partner_a")
	screen.call("press_add_for_test")
	await _tree.process_frame
	# party order may be [feibao_dev, partner_b, partner_a] or similar size 3
	_assert_eq("rf_restored_size", int(screen.call("get_party_size")), 3)

	# remove tail (last party member) → exact previous remaining member (not always leader).
	var party_ids: Array = screen.call("get_party_ids")
	_assert_true("rf_tail_setup_size", party_ids.size() >= 2)
	var tail_id: StringName = party_ids[party_ids.size() - 1] as StringName
	var expected_previous_id: StringName = party_ids[party_ids.size() - 2] as StringName
	_assert_true("rf_tail_focus", bool(screen.call("focus_character_for_test", tail_id)))
	screen.call("reset_party_refresh_count_for_tests")
	screen.call("press_remove_for_test")
	await _tree.process_frame
	_assert_eq("rf_tail_refresh", int(screen.call("get_party_refresh_count_for_tests")), 1)
	_assert_eq("rf_tail_size", int(screen.call("get_party_size")), 2)
	var after_tail: Array = screen.call("get_party_ids")
	_assert_true("rf_tail_was_removed", after_tail.has(tail_id) == false)
	_assert_eq("rf_tail_focus_id", str(screen.call("get_focused_id")), str(expected_previous_id))
	_assert_eq("rf_tail_slot_vis", str(screen.call("get_focused_slot_character_id")), str(expected_previous_id))
	_assert_eq("rf_tail_roster_vis", str(screen.call("get_focused_roster_character_id")), str(expected_previous_id))
	_assert_true("rf_tail_add_disabled", (screen.call("get_add_button") as Button).disabled)
	_assert_true("rf_tail_rem_enabled", (screen.call("get_remove_button") as Button).disabled == false)

	# rebuild known party for leader remove: ensure [feibao_dev, partner_a, partner_b]
	while int(screen.call("get_party_size")) > 1:
		var cur: Array = screen.call("get_party_ids")
		var rem_id: StringName = cur[cur.size() - 1] as StringName
		if rem_id == &"feibao_dev":
			break
		screen.call("focus_character_for_test", rem_id)
		screen.call("press_remove_for_test")
		await _tree.process_frame
	# Now only leader left; re-add a and b
	if not PlayerData.is_character_in_active_party(&"partner_a"):
		screen.call("focus_character_for_test", &"partner_a")
		screen.call("press_add_for_test")
		await _tree.process_frame
	if not PlayerData.is_character_in_active_party(&"partner_b"):
		screen.call("focus_character_for_test", &"partner_b")
		screen.call("press_add_for_test")
		await _tree.process_frame
	# Ensure leader is feibao_dev at 0
	if str(screen.call("get_leader_id")) != "feibao_dev":
		# move feibao to 0 via domain
		PlayerData.move_party_member(&"feibao_dev", 0)
		await _tree.process_frame
	_assert_eq("rf_leader_setup", str(screen.call("get_leader_id")), "feibao_dev")
	_assert_eq("rf_leader_size3", int(screen.call("get_party_size")), 3)

	_assert_true("rf_leader_focus", bool(screen.call("focus_character_for_test", &"feibao_dev")))
	screen.call("reset_party_refresh_count_for_tests")
	screen.call("press_remove_for_test")
	await _tree.process_frame
	_assert_eq("rf_leader_refresh", int(screen.call("get_party_refresh_count_for_tests")), 1)
	_assert_eq("rf_leader_new", str(screen.call("get_leader_id")), "partner_a")
	_assert_eq("rf_leader_focus_id", str(screen.call("get_focused_id")), "partner_a")
	_assert_eq("rf_leader_slot_vis", str(screen.call("get_focused_slot_character_id")), "partner_a")
	_assert_eq("rf_leader_roster_vis", str(screen.call("get_focused_roster_character_id")), "partner_a")

	# save failure preserves focus + UI
	var focus_bf: String = str(screen.call("get_focused_id"))
	var detail_bf: String = str(screen.call("get_detail_name_text"))
	var size_bf: int = int(screen.call("get_party_size"))
	PlayerData.set_save_override_for_tests(func(_p: String, _t: String) -> Dictionary:
		return {"ok": false, "error": "forced"}
	)
	screen.call("reset_party_refresh_count_for_tests")
	screen.call("press_remove_for_test")
	_assert_eq("rf_fail_refresh", int(screen.call("get_party_refresh_count_for_tests")), 0)
	_assert_eq("rf_fail_focus", str(screen.call("get_focused_id")), focus_bf)
	_assert_eq("rf_fail_size", int(screen.call("get_party_size")), size_bf)
	_assert_eq("rf_fail_detail", str(screen.call("get_detail_name_text")), detail_bf)
	_assert_true("rf_fail_msg", str(screen.call("get_mutation_message")).find("無法儲存") >= 0)
	PlayerData.clear_save_override_for_tests()

	screen.queue_free()
	await _tree.process_frame
	print("[INFO] remove focus matrix passed")


func _run_party_layout_tests() -> void:
	_begin_case("layout_party")
	PlayerData.initialize()
	var sizes: Array[Vector2i] = [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]
	for size in sizes:
		await _probe_party_layout(size)


func _probe_party_layout(size: Vector2i) -> void:
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
	var packed: PackedScene = load("res://scenes/screens/party/party_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	sv.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.call("configure_screen", &"party")
	# Populate full owned roster so narrow viewports have real vertical overflow.
	PlayerData.grant_character(&"partner_a")
	PlayerData.grant_character(&"partner_b")
	PlayerData.grant_character(&"partner_c")
	PlayerData.grant_character(&"partner_d")
	PlayerData.grant_character(&"partner_e")
	for _i in 5:
		await _tree.process_frame
	screen.call("configure_screen", &"party")
	for _i2 in 4:
		await _tree.process_frame

	var screen_rect: Rect2 = screen.get_global_rect()
	_assert_true("pl_%s_screen_inside" % tag, _rect_h_inside(screen_rect, viewport_rect, 2.0))

	# Strict roster columns: 360/390 → 2, 720 → 4 (not >=3).
	var cols: int = int(screen.call("get_grid_columns"))
	if size.x <= 400:
		_assert_eq("pl_%s_cols" % tag, cols, 2)
	if size.x >= 700:
		_assert_eq("pl_%s_cols" % tag, cols, 4)

	var body_scroll: ScrollContainer = screen.call("get_body_scroll") as ScrollContainer
	_assert_true("pl_%s_body_scroll" % tag, body_scroll != null)
	_assert_true(
		"pl_%s_h_scroll_disabled" % tag,
		body_scroll != null and int(body_scroll.horizontal_scroll_mode) == int(ScrollContainer.SCROLL_MODE_DISABLED)
	)

	# Strict scrollable range: max_value - page (not max_value > 0 alone).
	var vbar: ScrollBar = null
	var vmax: float = 0.0
	var vpage: float = 0.0
	var vmin: float = 0.0
	var scrollable_range: float = 0.0
	var body_content_h: float = 0.0
	if body_scroll != null:
		await _tree.process_frame
		await _tree.process_frame
		vbar = body_scroll.get_v_scroll_bar()
		if vbar != null:
			vmin = float(vbar.min_value)
			vmax = float(vbar.max_value)
			vpage = float(vbar.page)
			scrollable_range = maxf(0.0, vmax - vpage)
		var body_content: Control = body_scroll.get_child(0) as Control if body_scroll.get_child_count() > 0 else null
		if body_content != null:
			body_content_h = body_content.size.y
		print(
			"[INFO] scroll_diag_%s vp=%dx%d body_scroll=%.1fx%.1f vmin=%.1f vmax=%.1f page=%.1f range=%.1f content_h=%.1f"
			% [tag, size.x, size.y, body_scroll.size.x, body_scroll.size.y, vmin, vmax, vpage, scrollable_range, body_content_h]
		)
		# 360 and 390 must have real overflow; 720 may fit.
		if size.x <= 400:
			_assert_true("pl_%s_v_scrollable_range" % tag, scrollable_range > 0.5)

	var controls: Array = [
		["back", screen.call("get_back_button"), 48.0],
		["add", screen.call("get_add_button"), 48.0],
		["remove", screen.call("get_remove_button"), 48.0],
		["move_l", screen.call("get_move_left_button"), 48.0],
		["move_r", screen.call("get_move_right_button"), 48.0],
	]
	for entry in controls:
		var key: String = str(entry[0])
		var btn: Button = entry[1] as Button
		var min_h: float = float(entry[2])
		_assert_true("pl_%s_%s_exists" % [tag, key], btn != null)
		if btn == null:
			continue
		_assert_true("pl_%s_%s_min" % [tag, key], btn.custom_minimum_size.y >= min_h)
		# Ensure reachable via BodyScroll, then measure actual rect height + viewport intersection.
		screen.call("ensure_control_visible_for_test", btn)
		await _tree.process_frame
		var br: Rect2 = btn.get_global_rect()
		_assert_true("pl_%s_%s_actual_h" % [tag, key], br.size.y >= min_h)
		_assert_true("pl_%s_%s_no_h_overflow" % [tag, key], br.end.x <= screen_rect.end.x + 2.0)
		if body_scroll != null and key != "back":
			var srect: Rect2 = body_scroll.get_global_rect()
			_assert_true(
				"pl_%s_%s_in_body_viewport" % [tag, key],
				br.intersects(srect) and br.position.y + 1.0 >= srect.position.y - 2.0 and br.end.y <= srect.end.y + 4.0
			)

	var slots: Container = screen.call("get_party_slots_container") as Container
	_assert_true("pl_%s_slots" % tag, slots != null and slots.get_child_count() == 3)
	if slots != null:
		for si in slots.get_child_count():
			var slot: Control = slots.get_child(si) as Control
			if slot == null:
				continue
			screen.call("ensure_control_visible_for_test", slot)
			await _tree.process_frame
			var sr: Rect2 = slot.get_global_rect()
			_assert_true(
				"pl_%s_slot%d_h" % [tag, si],
				slot.custom_minimum_size.y >= 72.0 and sr.size.y >= 72.0
			)
			_assert_true("pl_%s_slot%d_no_h_overflow" % [tag, si], sr.end.x <= screen_rect.end.x + 2.0)

	var grid: GridContainer = screen.call("get_roster_grid") as GridContainer
	if grid != null and grid.get_child_count() > 0:
		var card: Control = grid.get_child(0) as Control
		if card != null:
			screen.call("ensure_control_visible_for_test", card)
			await _tree.process_frame
			var cr: Rect2 = card.get_global_rect()
			_assert_true("pl_%s_roster_card_h" % tag, card.custom_minimum_size.y >= 72.0 and cr.size.y >= 72.0)
			_assert_true("pl_%s_roster_card_no_h_overflow" % tag, cr.end.x <= screen_rect.end.x + 2.0)

	# Reachability: detail + bottom actions fully inside BodyScroll viewport after ensure_visible.
	var detail: PanelContainer = screen.call("get_detail_panel") as PanelContainer
	if detail != null and body_scroll != null:
		screen.call("ensure_control_visible_for_test", detail)
		await _tree.process_frame
		var dr: Rect2 = detail.get_global_rect()
		_assert_true("pl_%s_detail_no_h_overflow" % tag, dr.end.x <= screen_rect.end.x + 3.0)
		var scroll_rect: Rect2 = body_scroll.get_global_rect()
		_assert_true("pl_%s_detail_reachable" % tag, dr.intersects(scroll_rect))
		# Scroll to absolute bottom: last action row must remain fully visible.
		if body_scroll.get_v_scroll_bar() != null:
			body_scroll.scroll_vertical = int(body_scroll.get_v_scroll_bar().max_value)
			await _tree.process_frame
		var move_r: Button = screen.call("get_move_right_button") as Button
		if move_r != null:
			screen.call("ensure_control_visible_for_test", move_r)
			await _tree.process_frame
			var mr: Rect2 = move_r.get_global_rect()
			var srect2: Rect2 = body_scroll.get_global_rect()
			_assert_true(
				"pl_%s_bottom_actions_visible" % tag,
				mr.intersects(srect2) and mr.end.y <= srect2.end.y + 4.0 and mr.size.y >= 48.0
			)
			print(
				"[INFO] bottom_diag_%s action_rect=%s body_vp=%s range=%.1f"
				% [tag, str(mr), str(srect2), scrollable_range]
			)

	print(
		"[INFO] party_layout_%s cols=%d range=%.1f vmax=%.1f page=%.1f"
		% [tag, cols, scrollable_range, vmax, vpage]
	)
	host.queue_free()
	await _tree.process_frame


func _rect_h_inside(inner: Rect2, outer: Rect2, tolerance: float = 1.0) -> bool:
	return (
		inner.position.x >= outer.position.x - tolerance
		and inner.end.x <= outer.end.x + tolerance
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
