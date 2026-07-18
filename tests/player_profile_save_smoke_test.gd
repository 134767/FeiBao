## Player profile / codec / staged save / PlayerData / login persistence (0.5.0).
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
	_run_profile_tests()
	_run_codec_tests()
	_run_store_tests()
	_run_backup_preservation_tests()
	_run_player_data_tests()
	_run_path_containment_tests()
	_run_player_data_retry_state_tests()
	_run_boot_login_tests()
	_run_login_transaction_tests()
	_run_save_failure_restore_tests()
	_cleanup_all_cases()
	SaveFileStore.clear_test_write_failure_step()
	SaveFileStore.clear_test_restore_failure()
	# Restore suite isolation path for later suites.
	PlayerData.configure_test_storage_path("user://feibao_tests/suite_main")
	PlayerData.reset_runtime_state_for_tests()
	var prod_after: Dictionary = _snapshot_production_artifacts()
	_assert_production_fingerprints_unchanged(prod_before, prod_after)
	print("[INFO] production fingerprints unchanged")


func _pd() -> Node:
	return _tree.root.get_node("PlayerData")


func _app() -> Node:
	return _tree.root.get_node("AppState")


func _nav() -> Node:
	return _tree.root.get_node("NavigationState")


func _unique_case(tag: String) -> String:
	var path: String = "user://feibao_tests/case_%s_%d" % [tag, Time.get_ticks_usec()]
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
	var sha: String = bytes.hex_encode() # length evidence companion; also hash below
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	var digest: PackedByteArray = ctx.finish()
	return {
		"exists": true,
		"sha256": digest.hex_encode(),
		"length": length,
		"raw_hex_len": sha.length(),
	}


func _assert_production_fingerprints_unchanged(before: Dictionary, after: Dictionary) -> void:
	for path in _prod_paths():
		var b: Dictionary = before.get(path, {}) as Dictionary
		var a: Dictionary = after.get(path, {}) as Dictionary
		_assert_eq("prod_fp_exists_%s" % path.get_file(), bool(b.get("exists", false)), bool(a.get("exists", false)))
		_assert_eq("prod_fp_sha_%s" % path.get_file(), str(b.get("sha256", "")), str(a.get("sha256", "")))
		_assert_eq("prod_fp_len_%s" % path.get_file(), int(b.get("length", -2)), int(a.get("length", -3)))


func _run_profile_tests() -> void:
	var def: PlayerProfile = PlayerProfile.create_default()
	_assert_eq("profile_default_name", def.get_player_name(), "")
	_assert_eq("profile_default_revision", def.get_revision(), 0)
	_assert_eq("profile_default_selected", str(def.get_selected_character_id()), "feibao_dev")
	var owned: Array[StringName] = def.get_owned_character_ids()
	_assert_eq("profile_default_owned_count", owned.size(), 1)
	_assert_eq("profile_default_owned0", str(owned[0]), "feibao_dev")
	_assert_true("profile_owns_feibao", def.owns_character(&"feibao_dev"))
	_assert_true("profile_not_partner_a", def.owns_character(&"partner_a") == false)

	var copy_owned: Array[StringName] = def.get_owned_character_ids()
	copy_owned.append(&"mutated")
	_assert_eq("profile_owned_defensive_copy", def.get_owned_character_ids().size(), 1)

	var same: PlayerProfile = def.with_player_name("")
	_assert_eq("profile_same_name_rev", same.get_revision(), 0)
	var changed: PlayerProfile = def.with_player_name("Hero")
	_assert_eq("profile_changed_name", changed.get_player_name(), "Hero")
	_assert_eq("profile_changed_rev", changed.get_revision(), 1)
	_assert_eq("profile_original_immutable_name", def.get_player_name(), "")
	_assert_eq("profile_original_immutable_rev", def.get_revision(), 0)
	print("[INFO] player profile contract passed")


func _run_codec_tests() -> void:
	var profile: PlayerProfile = PlayerProfile.create_default().with_player_name("Coder")
	var encoded: Dictionary = PlayerProfileCodec.encode_profile(profile)
	_assert_true("codec_encode_ok", bool(encoded.get("ok", false)))
	var text: String = str(encoded.get("text", ""))
	_assert_true("codec_encode_newline", text.ends_with("\n"))

	var round: Dictionary = PlayerProfileCodec.parse_json_text(text)
	_assert_true("codec_round_trip_ok", bool(round.get("ok", false)))
	var rp: PlayerProfile = round.get("profile") as PlayerProfile
	_assert_true("codec_round_profile", rp != null)
	if rp != null:
		_assert_eq("codec_round_name", rp.get_player_name(), "Coder")
		_assert_eq("codec_round_rev", rp.get_revision(), 1)
		_assert_eq("codec_round_selected", str(rp.get_selected_character_id()), "feibao_dev")

	var s1: Dictionary = PlayerProfileCodec.parse_json_text(_profile_json(1, "local_player", "A", 0))
	_assert_true("codec_schema_1", bool(s1.get("ok", false)))
	var s10: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":1.0,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev","revision":0}'
	)
	_assert_true("codec_schema_1_0", bool(s10.get("ok", false)))
	var s15: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":1.5,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev","revision":0}'
	)
	_assert_true("codec_schema_1_5_rejected", bool(s15.get("ok", true)) == false)
	_assert_true("codec_schema_1_5_null", s15.get("profile") == null)

	var rev_frac: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":1,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev","revision":1.5}'
	)
	_assert_true("codec_rev_frac_rejected", bool(rev_frac.get("ok", true)) == false)

	var bad_kind: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":1,"profile_kind":"cloud","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev","revision":0}'
	)
	_assert_true("codec_kind_rejected", bool(bad_kind.get("ok", true)) == false)

	var extra: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":1,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev","revision":0,"token":"x"}'
	)
	_assert_true("codec_extra_rejected", bool(extra.get("ok", true)) == false)

	var untrimmed: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":1,"profile_kind":"local_player","player_name":" A ",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev","revision":0}'
	)
	_assert_true("codec_untrimmed_rejected", bool(untrimmed.get("ok", true)) == false)

	var long_name: String = "ABCDEFGHIJKLM" # 13
	var too_long: Dictionary = PlayerProfileCodec.parse_json_text(_profile_json(1, "local_player", long_name, 0))
	_assert_true("codec_name_too_long_rejected", bool(too_long.get("ok", true)) == false)

	var empty_owned: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":1,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":[],"selected_character_id":"feibao_dev","revision":0}'
	)
	_assert_true("codec_empty_owned_rejected", bool(empty_owned.get("ok", true)) == false)

	var bad_id: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":1,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["Bad-ID"],"selected_character_id":"Bad-ID","revision":0}'
	)
	_assert_true("codec_bad_owned_id_rejected", bool(bad_id.get("ok", true)) == false)

	var dup: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":1,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev","feibao_dev"],"selected_character_id":"feibao_dev","revision":0}'
	)
	_assert_true("codec_dup_owned_rejected", bool(dup.get("ok", true)) == false)

	var not_owned: Dictionary = PlayerProfileCodec.parse_json_text(
		'{"schema_version":1,"profile_kind":"local_player","player_name":"A",'
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"partner_a","revision":0}'
	)
	_assert_true("codec_selected_not_owned_rejected", bool(not_owned.get("ok", true)) == false)
	_assert_true("codec_fail_profile_null", not_owned.get("profile") == null)
	print("[INFO] profile codec strict validations passed")


func _profile_json(schema: int, kind: String, name: String, rev: int) -> String:
	return (
		'{"schema_version":%d,"profile_kind":"%s","player_name":"%s",'
		% [schema, kind, name]
		+ '"owned_character_ids":["feibao_dev"],"selected_character_id":"feibao_dev","revision":%d}'
		% rev
	)


func _run_store_tests() -> void:
	var case_dir: String = _unique_case("store")
	var primary: String = case_dir.path_join("player_profile.json")
	var validator := func(text: String) -> bool:
		return bool(PlayerProfileCodec.parse_json_text(text).get("ok", false))

	var missing: Dictionary = SaveFileStore.load_text(primary, validator)
	_assert_true("store_missing_ok_false", bool(missing.get("ok", true)) == false)
	_assert_eq("store_missing_source", str(missing.get("source", "")), "MISSING")

	var profile: PlayerProfile = PlayerProfile.create_default().with_player_name("StoreUser")
	var enc: Dictionary = PlayerProfileCodec.encode_profile(profile)
	_assert_true("store_encode_ok", bool(enc.get("ok", false)))
	var save1: Dictionary = SaveFileStore.save_text(primary, str(enc.get("text", "")), validator)
	_assert_true("store_save_ok", bool(save1.get("ok", false)))
	_assert_true("store_tmp_cleaned", FileAccess.file_exists(primary + ".tmp") == false)

	var load1: Dictionary = SaveFileStore.load_text(primary, validator)
	_assert_true("store_primary_load", bool(load1.get("ok", false)))
	_assert_eq("store_primary_source", str(load1.get("source", "")), "PRIMARY")

	# Second save creates backup
	var profile2: PlayerProfile = profile.with_player_name("StoreUser2")
	var enc2: Dictionary = PlayerProfileCodec.encode_profile(profile2)
	var save2: Dictionary = SaveFileStore.save_text(primary, str(enc2.get("text", "")), validator)
	_assert_true("store_save2_ok", bool(save2.get("ok", false)))
	_assert_true("store_backup_created", bool(save2.get("backup_created", false)))
	_assert_true("store_backup_exists", FileAccess.file_exists(primary + ".bak"))

	# Corrupt primary, valid backup recovery
	var f: FileAccess = FileAccess.open(primary, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var recovered: Dictionary = SaveFileStore.load_text(primary, validator)
	_assert_true("store_backup_recovery", bool(recovered.get("ok", false)))
	_assert_true("store_recovered_flag", bool(recovered.get("recovered_from_backup", false)))
	_assert_eq("store_recovered_source", str(recovered.get("source", "")), "BACKUP")
	_assert_true("store_corrupt_primary_preserved", FileAccess.file_exists(primary))

	# Both corrupt
	var b: FileAccess = FileAccess.open(primary + ".bak", FileAccess.WRITE)
	b.store_string("{bad")
	b.close()
	var both: Dictionary = SaveFileStore.load_text(primary, validator)
	_assert_true("store_both_corrupt", bool(both.get("ok", true)) == false)
	_assert_eq("store_both_source", str(both.get("source", "")), "CORRUPT")
	_assert_true("store_both_primary_kept", FileAccess.file_exists(primary))
	_assert_true("store_both_backup_kept", FileAccess.file_exists(primary + ".bak"))

	# Failed temporary validation leaves primary unchanged
	var good_primary: String = case_dir.path_join("good_primary.json")
	var good_text: String = str(PlayerProfileCodec.encode_profile(
		PlayerProfile.create_default().with_player_name("KeepMe")
	).get("text", ""))
	SaveFileStore.save_text(good_primary, good_text, validator)
	var bad_save: Dictionary = SaveFileStore.save_text(good_primary, "{bad", validator)
	_assert_true("store_bad_tmp_rejected", bool(bad_save.get("ok", true)) == false)
	var still: Dictionary = SaveFileStore.load_text(good_primary, validator)
	_assert_true("store_primary_unchanged_after_bad", bool(still.get("ok", false)))
	var still_p: PlayerProfile = PlayerProfileCodec.parse_json_text(str(still.get("text", ""))).get("profile")
	_assert_eq("store_primary_name_kept", still_p.get_player_name() if still_p else "", "KeepMe")

	var clean: Dictionary = SaveFileStore.remove_test_artifacts(primary)
	_assert_true("store_cleanup_ok", bool(clean.get("ok", false)))
	_assert_true("store_cleanup_primary_gone", FileAccess.file_exists(primary) == false)
	SaveFileStore.remove_test_artifacts(good_primary)
	print("[INFO] save file store staged write and recovery passed")


func _run_backup_preservation_tests() -> void:
	var validator := func(text: String) -> bool:
		return bool(PlayerProfileCodec.parse_json_text(text).get("ok", false))

	# corrupt primary + valid backup → recover, then save preserves backup hash
	var case1: String = _unique_case("bak_preserve")
	var primary1: String = case1.path_join("player_profile.json")
	var bak1: String = primary1 + ".bak"
	var t_old: String = str(PlayerProfileCodec.encode_profile(
		PlayerProfile.create_default().with_player_name("OldBak")
	).get("text", ""))
	var t_new: String = str(PlayerProfileCodec.encode_profile(
		PlayerProfile.create_default().with_player_name("NewPri")
	).get("text", ""))
	# Establish valid backup via two saves first
	SaveFileStore.save_text(primary1, t_old, validator)
	SaveFileStore.save_text(primary1, t_new, validator)
	# Now backup should be previous primary (OldBak chain). Re-seed known backup content.
	_write_raw(bak1, t_old)
	_write_raw(primary1, "{broken")
	var rec: Dictionary = SaveFileStore.load_text(primary1, validator)
	_assert_true("bak_rec_ok", bool(rec.get("ok", false)))
	_assert_true("bak_rec_flag", bool(rec.get("recovered_from_backup", false)))
	var bak_fp_before: Dictionary = _file_fingerprint(bak1)
	var save_after: Dictionary = SaveFileStore.save_text(primary1, t_new, validator)
	_assert_true("bak_rec_save_ok", bool(save_after.get("ok", false)))
	_assert_true("bak_rec_preserved_flag", bool(save_after.get("backup_preserved", false)))
	var bak_fp_after: Dictionary = _file_fingerprint(bak1)
	_assert_eq("bak_rec_hash_same", str(bak_fp_before.get("sha256", "")), str(bak_fp_after.get("sha256", "")))
	_assert_eq("bak_rec_len_same", int(bak_fp_before.get("length", -1)), int(bak_fp_after.get("length", -2)))
	var pri_load: Dictionary = SaveFileStore.load_text(primary1, validator)
	_assert_true("bak_rec_new_primary", bool(pri_load.get("ok", false)))
	var pri_prof: PlayerProfile = PlayerProfileCodec.parse_json_text(str(pri_load.get("text", ""))).get("profile")
	_assert_eq("bak_rec_new_name", pri_prof.get_player_name() if pri_prof else "", "NewPri")
	var bak_text: String = _read_raw(bak1)
	var bak_parse: Dictionary = PlayerProfileCodec.parse_json_text(bak_text)
	_assert_true("bak_still_parses", bool(bak_parse.get("ok", false)))
	var bak_prof: PlayerProfile = bak_parse.get("profile") as PlayerProfile
	_assert_eq("bak_still_old_name", bak_prof.get_player_name() if bak_prof else "", "OldBak")
	_assert_true("bak_rec_no_tmp", FileAccess.file_exists(primary1 + ".tmp") == false)

	# missing primary + valid backup
	var case2: String = _unique_case("miss_pri")
	var primary2: String = case2.path_join("player_profile.json")
	var bak2: String = primary2 + ".bak"
	_write_raw(bak2, t_old)
	var bak2_before: Dictionary = _file_fingerprint(bak2)
	var save_miss: Dictionary = SaveFileStore.save_text(primary2, t_new, validator)
	_assert_true("miss_pri_save_ok", bool(save_miss.get("ok", false)))
	var bak2_after: Dictionary = _file_fingerprint(bak2)
	_assert_eq("miss_pri_bak_hash", str(bak2_before.get("sha256")), str(bak2_after.get("sha256")))

	# valid primary + corrupt backup → backup repaired from valid primary
	var case3: String = _unique_case("fix_bak")
	var primary3: String = case3.path_join("player_profile.json")
	SaveFileStore.save_text(primary3, t_old, validator)
	_write_raw(primary3 + ".bak", "{badbak")
	var save_fix: Dictionary = SaveFileStore.save_text(primary3, t_new, validator)
	_assert_true("fix_bak_save_ok", bool(save_fix.get("ok", false)))
	_assert_true("fix_bak_created", bool(save_fix.get("backup_created", false)))
	var bak3_parse: Dictionary = PlayerProfileCodec.parse_json_text(_read_raw(primary3 + ".bak"))
	_assert_true("fix_bak_valid", bool(bak3_parse.get("ok", false)))

	# corrupt primary + missing backup → fail closed
	var case4: String = _unique_case("cor_only")
	var primary4: String = case4.path_join("player_profile.json")
	_write_raw(primary4, "{onlybroken")
	var fp4: Dictionary = _file_fingerprint(primary4)
	var save4: Dictionary = SaveFileStore.save_text(primary4, t_new, validator)
	_assert_true("cor_only_fail", bool(save4.get("ok", true)) == false)
	var fp4b: Dictionary = _file_fingerprint(primary4)
	_assert_eq("cor_only_hash", str(fp4.get("sha256")), str(fp4b.get("sha256")))
	_assert_true("cor_only_no_tmp", FileAccess.file_exists(primary4 + ".tmp") == false)

	# both corrupt → fail closed
	var case5: String = _unique_case("both_cor")
	var primary5: String = case5.path_join("player_profile.json")
	_write_raw(primary5, "{p")
	_write_raw(primary5 + ".bak", "{b")
	var p5a: Dictionary = _file_fingerprint(primary5)
	var b5a: Dictionary = _file_fingerprint(primary5 + ".bak")
	var save5: Dictionary = SaveFileStore.save_text(primary5, t_new, validator)
	_assert_true("both_cor_fail", bool(save5.get("ok", true)) == false)
	_assert_eq("both_cor_p_hash", str(p5a.get("sha256")), str(_file_fingerprint(primary5).get("sha256")))
	_assert_eq("both_cor_b_hash", str(b5a.get("sha256")), str(_file_fingerprint(primary5 + ".bak").get("sha256")))
	_assert_true("both_cor_no_tmp", FileAccess.file_exists(primary5 + ".tmp") == false)

	# missing primary + corrupt backup → fail closed
	var case6: String = _unique_case("miss_cor_bak")
	var primary6: String = case6.path_join("player_profile.json")
	_write_raw(primary6 + ".bak", "{cb")
	var b6a: Dictionary = _file_fingerprint(primary6 + ".bak")
	var save6: Dictionary = SaveFileStore.save_text(primary6, t_new, validator)
	_assert_true("miss_cor_bak_fail", bool(save6.get("ok", true)) == false)
	_assert_eq("miss_cor_bak_hash", str(b6a.get("sha256")), str(_file_fingerprint(primary6 + ".bak").get("sha256")))
	_assert_true("miss_cor_no_primary", FileAccess.file_exists(primary6) == false)

	SaveFileStore.remove_test_artifacts(primary1)
	SaveFileStore.remove_test_artifacts(primary2)
	SaveFileStore.remove_test_artifacts(primary3)
	SaveFileStore.remove_test_artifacts(primary4)
	SaveFileStore.remove_test_artifacts(primary5)
	SaveFileStore.remove_test_artifacts(primary6)
	print("[INFO] backup preservation policies passed")


func _write_raw(path: String, text: String) -> void:
	var dir: String = path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read_raw(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var t: String = f.get_as_text()
	f.close()
	return t


func _run_player_data_tests() -> void:
	# Missing: memory default, no write
	var path_miss: String = _begin_case("pd_miss")
	var init_miss: Dictionary = PlayerData.initialize()
	_assert_eq("pd_miss_state", str(init_miss.get("state", "")), "NEW_PROFILE")
	_assert_eq("pd_miss_name", PlayerData.get_player_name(), "")
	_assert_true("pd_miss_no_primary", FileAccess.file_exists(PlayerData.get_primary_path()) == false)
	_assert_true("pd_owns_feibao", PlayerData.owns_character(&"feibao_dev"))
	_assert_true("pd_not_partner_a", PlayerData.owns_character(&"partner_a") == false)
	_assert_eq("pd_selected", str(PlayerData.get_selected_character_id()), "feibao_dev")

	# Idempotent initialize
	var again: Dictionary = PlayerData.initialize()
	_assert_eq("pd_init_idempotent", str(again.get("state", "")), "NEW_PROFILE")

	# Valid save
	var save_ok: Dictionary = PlayerData.save_player_name("Saver")
	_assert_true("pd_save_ok", bool(save_ok.get("ok", false)))
	_assert_true("pd_save_changed", bool(save_ok.get("changed", false)))
	_assert_true("pd_save_wrote", PlayerData.did_last_save_write_disk())
	_assert_eq("pd_app_sync", str(_app().call("get_player_name")), "Saver")
	_assert_true("pd_primary_exists", FileAccess.file_exists(PlayerData.get_primary_path()))

	# Same name no rewrite flag
	var same: Dictionary = PlayerData.save_player_name("Saver")
	_assert_true("pd_same_ok", bool(same.get("ok", false)))
	_assert_true("pd_same_not_changed", bool(same.get("changed", true)) == false)

	# Reload primary
	PlayerData.reset_runtime_state_for_tests()
	var init_pri: Dictionary = PlayerData.initialize()
	_assert_eq("pd_primary_state", str(init_pri.get("state", "")), "LOADED_PRIMARY")
	_assert_eq("pd_primary_name", PlayerData.get_player_name(), "Saver")
	_assert_eq("pd_primary_app", str(_app().call("get_player_name")), "Saver")

	# Backup recovery
	var path_bak: String = _begin_case("pd_bak")
	PlayerData.initialize()
	PlayerData.save_player_name("BackupUser")
	PlayerData.save_player_name("BackupUser2") # create bak of previous
	var pri: String = PlayerData.get_primary_path()
	var badf: FileAccess = FileAccess.open(pri, FileAccess.WRITE)
	badf.store_string("BROKEN")
	badf.close()
	PlayerData.reset_runtime_state_for_tests()
	var init_bak: Dictionary = PlayerData.initialize()
	_assert_eq("pd_recovered_state", str(init_bak.get("state", "")), "RECOVERED_BACKUP")
	_assert_true("pd_recovered_notice", PlayerData.get_user_notice().length() > 0)
	_assert_true("pd_corrupt_primary_kept", FileAccess.file_exists(pri))

	# Both corrupt safe default
	var path_cor: String = _begin_case("pd_cor")
	PlayerData.initialize()
	PlayerData.save_player_name("X")
	PlayerData.save_player_name("Y")
	var p2: String = PlayerData.get_primary_path()
	var f1: FileAccess = FileAccess.open(p2, FileAccess.WRITE)
	f1.store_string("x")
	f1.close()
	var f2: FileAccess = FileAccess.open(p2 + ".bak", FileAccess.WRITE)
	f2.store_string("y")
	f2.close()
	PlayerData.reset_runtime_state_for_tests()
	var init_cor: Dictionary = PlayerData.initialize()
	_assert_eq("pd_corrupt_state", str(init_cor.get("state", "")), "SAFE_DEFAULT_CORRUPT")
	_assert_eq("pd_corrupt_name", PlayerData.get_player_name(), "")
	_assert_true("pd_corrupt_files_kept", FileAccess.file_exists(p2) and FileAccess.file_exists(p2 + ".bak"))

	# Save failure preserves profile + AppState
	var path_fail: String = _begin_case("pd_fail")
	PlayerData.initialize()
	PlayerData.save_player_name("Keep")
	_app().call("set_player_name", "Keep")
	PlayerData.set_save_override_for_tests(func(_path: String, _text: String) -> Dictionary:
		return {"ok": false, "backup_created": false, "error": "forced"}
	)
	var fail: Dictionary = PlayerData.save_player_name("NewName")
	_assert_true("pd_fail_ok_false", bool(fail.get("ok", true)) == false)
	_assert_eq("pd_fail_profile_name", PlayerData.get_player_name(), "Keep")
	_assert_eq("pd_fail_app_name", str(_app().call("get_player_name")), "Keep")
	PlayerData.clear_save_override_for_tests()

	# Test path guard (basic)
	_assert_true("pd_reject_prod_path", PlayerData.configure_test_storage_path("user://feibao") == false)
	_assert_true("pd_reject_root", PlayerData.configure_test_storage_path("user://feibao_tests") == false)
	_assert_true("pd_reject_other", PlayerData.configure_test_storage_path("user://other") == false)
	print("[INFO] PlayerData initialize/save/recovery passed")


func _run_path_containment_tests() -> void:
	var nested: Dictionary = SaveFileStore.normalize_test_storage_dir("user://feibao_tests/nested/case_b")
	_assert_true("path_nested_ok", bool(nested.get("ok", false)))
	_assert_eq("path_nested_value", str(nested.get("path", "")), "user://feibao_tests/nested/case_b")

	var trail: Dictionary = SaveFileStore.normalize_test_storage_dir("user://feibao_tests/case_c/")
	_assert_true("path_trail_ok", bool(trail.get("ok", false)))
	_assert_eq("path_trail_norm", str(trail.get("path", "")), "user://feibao_tests/case_c")

	_assert_true("path_lookalike_reject", PlayerData.configure_test_storage_path("user://feibao_tests_case") == false)
	_assert_true("path_prod_reject", PlayerData.configure_test_storage_path("user://feibao") == false)
	_assert_true("path_trav_reject", PlayerData.configure_test_storage_path("user://feibao_tests/../feibao") == false)
	_assert_true("path_multi_trav_reject", PlayerData.configure_test_storage_path("user://feibao_tests/a/../../feibao") == false)
	_assert_true("path_root_reject", PlayerData.configure_test_storage_path("user://feibao_tests/") == false)
	_assert_true("path_empty_reject", PlayerData.configure_test_storage_path("") == false)
	_assert_true("path_res_reject", PlayerData.configure_test_storage_path("res://feibao_tests/case") == false)

	# rejected configure preserves previous
	var keep: String = _begin_case("path_keep")
	_assert_true("path_keep_set", PlayerData.configure_test_storage_path(keep))
	_assert_true("path_keep_reject", PlayerData.configure_test_storage_path("user://feibao_tests/../feibao") == false)
	_assert_eq("path_keep_still", PlayerData.get_primary_path().get_base_dir(), keep)

	# rejected cleanup does not delete existing test case file
	PlayerData.initialize()
	PlayerData.save_player_name("KeepCase")
	var pri: String = PlayerData.get_primary_path()
	_assert_true("path_case_exists", FileAccess.file_exists(pri))
	var bad_clean: Dictionary = SaveFileStore.remove_test_artifacts("user://feibao/player_profile.json")
	_assert_true("path_bad_clean_fail", bool(bad_clean.get("ok", true)) == false)
	_assert_true("path_case_still_exists", FileAccess.file_exists(pri))

	# valid cleanup removes three artifacts
	var t_ok: Dictionary = SaveFileStore.remove_test_artifacts(pri)
	_assert_true("path_good_clean_ok", bool(t_ok.get("ok", false)))
	_assert_true("path_good_clean_pri", FileAccess.file_exists(pri) == false)
	_assert_true("path_good_clean_tmp", FileAccess.file_exists(pri + ".tmp") == false)
	_assert_true("path_good_clean_bak", FileAccess.file_exists(pri + ".bak") == false)
	print("[INFO] path containment guards passed")


func _run_player_data_retry_state_tests() -> void:
	var path: String = _begin_case("retry")
	PlayerData.initialize()
	PlayerData.save_player_name("RetryBase")
	PlayerData.set_save_override_for_tests(func(_p: String, _t: String) -> Dictionary:
		return {"ok": false, "backup_created": false, "error": "forced"}
	)
	var fail: Dictionary = PlayerData.save_player_name("RetryNew")
	_assert_true("retry_fail_ok", bool(fail.get("ok", true)) == false)
	_assert_eq("retry_fail_state", str(PlayerData.get_load_state()), "SAVE_FAILED")
	_assert_eq("retry_fail_name", PlayerData.get_player_name(), "RetryBase")
	_assert_eq("retry_fail_app", str(_app().call("get_player_name")), "RetryBase")
	PlayerData.clear_save_override_for_tests()
	var ok: Dictionary = PlayerData.save_player_name("RetryNew")
	_assert_true("retry_ok", bool(ok.get("ok", false)))
	_assert_eq("retry_state", str(PlayerData.get_load_state()), "LOADED_PRIMARY")
	_assert_eq("retry_error_cleared", PlayerData.get_last_error(), "")
	_assert_eq("retry_name", PlayerData.get_player_name(), "RetryNew")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	_assert_eq("retry_reload", PlayerData.get_player_name(), "RetryNew")
	var same: Dictionary = PlayerData.save_player_name("RetryNew")
	_assert_true("retry_same_ok", bool(same.get("ok", false)))
	_assert_true("retry_same_no_change", bool(same.get("changed", true)) == false)
	print("[INFO] PlayerData save failure retry state passed")


func _run_boot_login_tests() -> void:
	# Boot initializes before login; missing still enters login
	var path_boot: String = _begin_case("boot")
	_nav().call("reset", &"boot")
	var boot_packed: PackedScene = load("res://scenes/screens/boot/boot_screen.tscn") as PackedScene
	var boot: Control = boot_packed.instantiate() as Control
	_tree.root.add_child(boot)
	# _ready deferred advance
	await _tree.process_frame
	await _tree.process_frame
	_assert_eq("boot_nav_login", str(_nav().call("get_current_screen")), "login")
	_assert_eq("boot_init_state", str(boot.call("get_last_init_state")), "NEW_PROFILE")
	_assert_true("boot_advanced", bool(boot.call("has_advanced")))
	boot.call("advance_to_login") # idempotent
	_assert_eq("boot_idempotent_nav", str(_nav().call("get_current_screen")), "login")
	boot.queue_free()

	# Prefill without auto-login
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	PlayerData.save_player_name("PrefillMe")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	_nav().call("reset", &"login")
	var login_packed: PackedScene = load("res://scenes/screens/login/login_screen.tscn") as PackedScene
	var login: Control = login_packed.instantiate() as Control
	_tree.root.add_child(login)
	await _tree.process_frame
	var input: LineEdit = login.call("get_name_input") as LineEdit
	_assert_eq("login_prefill", input.text, "PrefillMe")
	_assert_eq("login_stays_login", str(_nav().call("get_current_screen")), "login")
	_assert_eq("login_not_lobby", str(_nav().call("get_current_screen")), "login")

	# Valid submit persists and navigates
	_assert_true("login_submit_ok", bool(login.call("submit_player_name", "PrefillMe")))
	_assert_eq("login_to_lobby", str(_nav().call("get_current_screen")), "lobby")
	login.queue_free()

	# Restart simulation reloads name
	PlayerData.reset_runtime_state_for_tests()
	var re: Dictionary = PlayerData.initialize()
	_assert_eq("restart_state", str(re.get("state", "")), "LOADED_PRIMARY")
	_assert_eq("restart_name", PlayerData.get_player_name(), "PrefillMe")

	# Save failure stays on login
	var path_sf: String = _begin_case("login_sf")
	PlayerData.initialize()
	_nav().call("reset", &"login")
	var login2: Control = login_packed.instantiate() as Control
	_tree.root.add_child(login2)
	PlayerData.set_save_override_for_tests(func(_p: String, _t: String) -> Dictionary:
		return {"ok": false, "backup_created": false, "error": "forced"}
	)
	_assert_true("login_save_fail", login2.call("submit_player_name", "Nope") == false)
	_assert_eq("login_save_fail_nav", str(_nav().call("get_current_screen")), "login")
	_assert_true(
		"login_save_fail_msg",
		str(login2.call("get_validation_message")).find("無法儲存") >= 0
	)
	PlayerData.clear_save_override_for_tests()
	login2.queue_free()

	# Navigation failure rolls back disk/profile/AppState
	var path_nf: String = _begin_case("login_nf")
	PlayerData.initialize()
	PlayerData.save_player_name("OldName")
	_app().call("set_player_name", "OldName")
	_nav().call("reset", &"login")
	var login3: Control = login_packed.instantiate() as Control
	_tree.root.add_child(login3)
	login3.call("set_navigate_to_lobby_override", func() -> bool: return false)
	_assert_true("login_nav_fail", login3.call("submit_player_name", "NewName") == false)
	_assert_eq("login_nav_fail_screen", str(_nav().call("get_current_screen")), "login")
	_assert_eq("login_nav_fail_app", str(_app().call("get_player_name")), "OldName")
	_assert_eq("login_nav_fail_profile", PlayerData.get_player_name(), "OldName")
	# Disk should reflect rollback
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	_assert_eq("login_nav_fail_disk", PlayerData.get_player_name(), "OldName")
	login3.queue_free()

	# Shell path: lobby greeting uses persisted name
	var path_shell: String = _begin_case("shell")
	PlayerData.initialize()
	_app().call("reset")
	_nav().call("reset", &"boot")
	var shell_packed: PackedScene = load("res://scenes/shell/game_shell.tscn") as PackedScene
	var shell: Control = shell_packed.instantiate() as Control
	_tree.root.add_child(shell)
	await _tree.process_frame
	await _tree.process_frame
	var login_screen: Node = shell.call("get_active_screen")
	if login_screen != null and login_screen.has_method("submit_player_name"):
		_assert_true("shell_login_persist", bool(login_screen.call("submit_player_name", "ShellPersist")))
		_assert_eq("shell_lobby", str(shell.call("get_active_screen_id")), "lobby")
		var lobby: Node = shell.call("get_active_screen")
		if lobby != null and lobby.has_method("get_greeting_text"):
			_assert_true(
				"shell_greeting_name",
				str(lobby.call("get_greeting_text")).find("ShellPersist") >= 0
			)
		elif lobby != null and lobby.has_method("get_greeting"):
			_assert_true(
				"shell_greeting_name",
				str(lobby.call("get_greeting")).find("ShellPersist") >= 0
			)
	shell.queue_free()

	print("[INFO] boot/login persistence and rollback passed")


func _run_login_transaction_tests() -> void:
	var login_packed: PackedScene = load("res://scenes/screens/login/login_screen.tscn") as PackedScene

	# --- existing profile + backup; failed navigation must restore all artifacts ---
	var path_tx: String = _begin_case("tx_existing")
	PlayerData.initialize()
	PlayerData.save_player_name("OlderName")
	PlayerData.save_player_name("OldName")
	var primary: String = PlayerData.get_primary_path()
	var snap_before: Dictionary = SaveFileStore.capture_artifact_snapshot(primary)
	_assert_true("tx_exist_snap_ok", bool(snap_before.get("ok", false)))
	_nav().call("reset", &"login")
	var login: Control = login_packed.instantiate() as Control
	_tree.root.add_child(login)
	login.call("set_navigate_to_lobby_override", func() -> bool: return false)
	_assert_true("tx_exist_nav_fail", login.call("submit_player_name", "NewName") == false)
	_assert_eq("tx_exist_profile", PlayerData.get_player_name(), "OldName")
	_assert_eq("tx_exist_app", str(_app().call("get_player_name")), "OldName")
	_assert_true("tx_exist_rollback_ok", bool(login.call("get_last_rollback_ok")))
	_assert_true("tx_exist_disk_ok", bool(login.call("get_last_rollback_disk_ok")))
	_assert_true("tx_exist_match", SaveFileStore.artifact_snapshot_matches(primary, snap_before))
	var bak_text: String = _read_raw(primary + ".bak")
	_assert_true("tx_exist_bak_not_new", bak_text.find("NewName") < 0)
	_assert_true("tx_exist_pri_not_new", _read_raw(primary).find("NewName") < 0)
	_write_raw(primary, "{broken")
	PlayerData.reset_runtime_state_for_tests()
	var init_rec: Dictionary = PlayerData.initialize()
	_assert_eq("tx_exist_rec_state", str(init_rec.get("state", "")), "RECOVERED_BACKUP")
	_assert_eq("tx_exist_rec_name", PlayerData.get_player_name(), "OlderName")
	login.queue_free()

	# --- first login failure leaves no files ---
	var _path_first: String = _begin_case("tx_first")
	PlayerData.initialize()
	_assert_eq("tx_first_state", str(PlayerData.get_load_state()), "NEW_PROFILE")
	_nav().call("reset", &"login")
	var login_f: Control = login_packed.instantiate() as Control
	_tree.root.add_child(login_f)
	login_f.call("set_navigate_to_lobby_override", func() -> bool: return false)
	_assert_true("tx_first_fail", login_f.call("submit_player_name", "FirstName") == false)
	_assert_eq("tx_first_profile", PlayerData.get_player_name(), "")
	_assert_eq("tx_first_rev", PlayerData.get_profile().get_revision(), 0)
	_assert_eq("tx_first_app", str(_app().call("get_player_name")), "")
	var p1: String = PlayerData.get_primary_path()
	_assert_true("tx_first_no_pri", FileAccess.file_exists(p1) == false)
	_assert_true("tx_first_no_tmp", FileAccess.file_exists(p1 + ".tmp") == false)
	_assert_true("tx_first_no_bak", FileAccess.file_exists(p1 + ".bak") == false)
	PlayerData.reset_runtime_state_for_tests()
	var init_new: Dictionary = PlayerData.initialize()
	_assert_eq("tx_first_restart", str(init_new.get("state", "")), "NEW_PROFILE")
	login_f.queue_free()

	# --- recovered backup transaction ---
	var path_rb: String = _begin_case("tx_rec")
	var pri_rb: String = path_rb.path_join("player_profile.json")
	var t_rec: String = str(PlayerProfileCodec.encode_profile(
		PlayerProfile.create_default().with_player_name("RecoveryName")
	).get("text", ""))
	_write_raw(pri_rb + ".bak", t_rec)
	_write_raw(pri_rb, "{corrupt_primary_bytes")
	PlayerData.configure_test_storage_path(path_rb)
	PlayerData.reset_runtime_state_for_tests()
	var init_rb: Dictionary = PlayerData.initialize()
	_assert_eq("tx_rec_init", str(init_rb.get("state", "")), "RECOVERED_BACKUP")
	var snap_rb: Dictionary = SaveFileStore.capture_artifact_snapshot(pri_rb)
	_nav().call("reset", &"login")
	var login_rb: Control = login_packed.instantiate() as Control
	_tree.root.add_child(login_rb)
	login_rb.call("set_navigate_to_lobby_override", func() -> bool: return false)
	_assert_true("tx_rec_fail", login_rb.call("submit_player_name", "CandidateName") == false)
	_assert_true("tx_rec_match", SaveFileStore.artifact_snapshot_matches(pri_rb, snap_rb))
	_assert_true("tx_rec_pri_corrupt", _read_raw(pri_rb).begins_with("{corrupt"))
	_assert_true("tx_rec_no_candidate_bak", _read_raw(pri_rb + ".bak").find("CandidateName") < 0)
	_assert_true("tx_rec_no_candidate_pri", _read_raw(pri_rb).find("CandidateName") < 0)
	PlayerData.reset_runtime_state_for_tests()
	var init_rb2: Dictionary = PlayerData.initialize()
	_assert_eq("tx_rec_reinit_state", str(init_rb2.get("state", "")), "RECOVERED_BACKUP")
	_assert_eq("tx_rec_reinit_name", PlayerData.get_player_name(), "RecoveryName")
	login_rb.queue_free()

	# --- preexisting temporary restored ---
	var _path_tmp: String = _begin_case("tx_tmp")
	PlayerData.initialize()
	PlayerData.save_player_name("TmpUser")
	var pri_tmp: String = PlayerData.get_primary_path()
	_write_raw(pri_tmp + ".tmp", "PREEXISTING_TMP_BYTES")
	var snap_tmp: Dictionary = SaveFileStore.capture_artifact_snapshot(pri_tmp)
	_nav().call("reset", &"login")
	var login_tmp: Control = login_packed.instantiate() as Control
	_tree.root.add_child(login_tmp)
	login_tmp.call("set_navigate_to_lobby_override", func() -> bool: return false)
	_assert_true("tx_tmp_fail", login_tmp.call("submit_player_name", "TmpCandidate") == false)
	_assert_true("tx_tmp_match", SaveFileStore.artifact_snapshot_matches(pri_tmp, snap_tmp))
	_assert_eq("tx_tmp_bytes", _read_raw(pri_tmp + ".tmp"), "PREEXISTING_TMP_BYTES")
	login_tmp.queue_free()

	# --- same-name transaction ---
	var _path_same: String = _begin_case("tx_same")
	PlayerData.initialize()
	PlayerData.save_player_name("SameName")
	var pri_same: String = PlayerData.get_primary_path()
	var snap_same: Dictionary = SaveFileStore.capture_artifact_snapshot(pri_same)
	_nav().call("reset", &"login")
	var login_same: Control = login_packed.instantiate() as Control
	_tree.root.add_child(login_same)
	login_same.call("set_navigate_to_lobby_override", func() -> bool: return false)
	_assert_true("tx_same_fail", login_same.call("submit_player_name", "SameName") == false)
	_assert_true("tx_same_match", SaveFileStore.artifact_snapshot_matches(pri_same, snap_same))
	login_same.queue_free()

	# --- rollback failure observability ---
	var _path_rf: String = _begin_case("tx_rf")
	PlayerData.initialize()
	PlayerData.save_player_name("RFBase")
	_nav().call("reset", &"login")
	var login_rf: Control = login_packed.instantiate() as Control
	_tree.root.add_child(login_rf)
	login_rf.call("set_navigate_to_lobby_override", func() -> bool: return false)
	SaveFileStore.set_test_restore_failure(true)
	_assert_true("tx_rf_fail", login_rf.call("submit_player_name", "RFNew") == false)
	_assert_eq("tx_rf_screen", str(_nav().call("get_current_screen")), "login")
	_assert_eq("tx_rf_profile", PlayerData.get_player_name(), "RFBase")
	_assert_eq("tx_rf_app", str(_app().call("get_player_name")), "RFBase")
	_assert_eq("tx_rf_state", str(PlayerData.get_load_state()), "SAVE_FAILED")
	_assert_true("tx_rf_error", PlayerData.get_last_error().length() > 0)
	_assert_true("tx_rf_msg", str(login_rf.call("get_validation_message")).find("無法開始") >= 0)
	_assert_true("tx_rf_rollback_flag", bool(login_rf.call("get_last_rollback_ok")) == false)
	SaveFileStore.clear_test_restore_failure()
	login_rf.queue_free()
	print("[INFO] login persistence transaction rollback passed")


func _run_save_failure_restore_tests() -> void:
	var validator := func(text: String) -> bool:
		return bool(PlayerProfileCodec.parse_json_text(text).get("ok", false))
	var good: String = str(PlayerProfileCodec.encode_profile(
		PlayerProfile.create_default().with_player_name("Good")
	).get("text", ""))
	var good2: String = str(PlayerProfileCodec.encode_profile(
		PlayerProfile.create_default().with_player_name("Good2")
	).get("text", ""))

	var c1: String = _unique_case("sf_first")
	var p1: String = c1.path_join("player_profile.json")
	var snap1: Dictionary = SaveFileStore.capture_artifact_snapshot(p1)
	SaveFileStore.set_test_write_failure_step("primary_write")
	var s1: Dictionary = SaveFileStore.save_text(p1, good, validator)
	SaveFileStore.clear_test_write_failure_step()
	_assert_true("sf_first_fail", bool(s1.get("ok", true)) == false)
	_assert_true("sf_first_restore_attempted", bool(s1.get("restore_attempted", false)))
	_assert_true("sf_first_restore_ok", bool(s1.get("restore_ok", false)))
	_assert_true("sf_first_match", SaveFileStore.artifact_snapshot_matches(p1, snap1))
	_assert_true("sf_first_no_tmp", FileAccess.file_exists(p1 + ".tmp") == false)

	var c2: String = _unique_case("sf_exist")
	var p2: String = c2.path_join("player_profile.json")
	SaveFileStore.save_text(p2, good, validator)
	SaveFileStore.save_text(p2, good2, validator)
	var snap2: Dictionary = SaveFileStore.capture_artifact_snapshot(p2)
	SaveFileStore.set_test_write_failure_step("primary_write")
	var s2: Dictionary = SaveFileStore.save_text(p2, good, validator)
	SaveFileStore.clear_test_write_failure_step()
	_assert_true("sf_exist_fail", bool(s2.get("ok", true)) == false)
	_assert_true("sf_exist_restore_ok", bool(s2.get("restore_ok", false)))
	_assert_true("sf_exist_match", SaveFileStore.artifact_snapshot_matches(p2, snap2))

	var c3: String = _unique_case("sf_bak")
	var p3: String = c3.path_join("player_profile.json")
	SaveFileStore.save_text(p3, good, validator)
	var snap3: Dictionary = SaveFileStore.capture_artifact_snapshot(p3)
	SaveFileStore.set_test_write_failure_step("backup_write")
	var s3: Dictionary = SaveFileStore.save_text(p3, good2, validator)
	SaveFileStore.clear_test_write_failure_step()
	_assert_true("sf_bak_fail", bool(s3.get("ok", true)) == false)
	_assert_true("sf_bak_restore_ok", bool(s3.get("restore_ok", false)))
	_assert_true("sf_bak_match", SaveFileStore.artifact_snapshot_matches(p3, snap3))
	_assert_true("sf_bak_no_tmp", FileAccess.file_exists(p3 + ".tmp") == false)

	var wrong: Dictionary = SaveFileStore.restore_artifact_snapshot(p3, snap2)
	_assert_true("sf_wrong_path_reject", bool(wrong.get("ok", true)) == false)

	SaveFileStore.remove_test_artifacts(p1)
	SaveFileStore.remove_test_artifacts(p2)
	SaveFileStore.remove_test_artifacts(p3)
	print("[INFO] save_text failure artifact restoration passed")


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
