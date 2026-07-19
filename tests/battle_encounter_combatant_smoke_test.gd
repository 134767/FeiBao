## GROK-038 final evidence: snapshot 3×3 matrix, exact cards, Space outcome, cleanup.
extends RefCounted

var passed: int = 0
var failed: int = 0
var results: PackedStringArray = PackedStringArray()
var _tree: SceneTree
var _fixture_paths: Array[String] = []
const FIXTURE_DIR: String = "user://feibao_tests/encounter_catalog_fixtures"


func setup(tree: SceneTree) -> void:
	_tree = tree


func run_all() -> void:
	var fp0: Dictionary = _prod_fp()
	var rev0: int = -1
	_clear_overrides()
	_reset_domain()
	_run_catalog_and_combatant_closeout()
	await _run_forced_accepted_turn()
	_run_snapshot_matrix_closeout()
	await _run_adventure_three_failures()
	await _run_double_enter_leave()
	await _run_missing_encounter_screen()
	await _run_max_content_cards_and_subviewport()
	_cleanup_fixtures()
	_clear_overrides()
	_assert_production_cleanup(fp0, rev0)
	_reset_domain()
	PlayerData.configure_test_storage_path("user://feibao_tests/suite_main")
	PlayerData.reset_runtime_state_for_tests()
	print("[INFO] GROK-038 encounter evidence suite complete")


func _nav() -> Node:
	return _tree.root.get_node("NavigationState")


func _reset_domain() -> void:
	if is_instance_valid(AdventureState):
		AdventureState.reset_runtime_state_for_tests()
	if is_instance_valid(BattleRuntime):
		BattleRuntime.reset_runtime_state_for_tests()
	if is_instance_valid(BattleState):
		BattleState.reset_runtime_state_for_tests()


func _clear_overrides() -> void:
	BattleCharacterStatsCatalog.clear_default_path_override_for_tests()
	EnemyCatalog.clear_default_path_override_for_tests()
	StageEncounterCatalog.clear_default_path_override_for_tests()


func _cleanup_fixtures() -> void:
	for p in _fixture_paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_fixture_paths.clear()


func _write_fixture(name: String, text: String) -> String:
	DirAccess.make_dir_recursive_absolute(FIXTURE_DIR)
	var path := "%s/%s" % [FIXTURE_DIR, name]
	var f := FileAccess.open(path, FileAccess.WRITE)
	_assert_true("fx_%s" % name, f != null)
	if f != null:
		f.store_string(text)
		f.close()
		_fixture_paths.append(path)
	return path


func _battle_state_exact(snap: Dictionary) -> bool:
	if bool(snap.get("active", false)) != BattleState.has_active_session():
		return false
	if str(BattleState.get_area_id()) != str(snap.get("area_id", &"")):
		return false
	if str(BattleState.get_stage_id()) != str(snap.get("stage_id", &"")):
		return false
	if str(BattleState.get_leader_character_id()) != str(snap.get("leader_character_id", &"")):
		return false
	if str(BattleState.get_stage_display_name()) != str(snap.get("stage_display_name", "")):
		return false
	if str(BattleState.get_stage_summary()) != str(snap.get("stage_summary", "")):
		return false
	if int(BattleState.get_stage_number()) != int(snap.get("stage_number", 0)):
		return false
	if str(BattleState.get_area_display_name()) != str(snap.get("area_display_name", "")):
		return false
	var exp_p: Array = snap.get("party_character_ids", []) as Array
	var act_p: Array[StringName] = BattleState.get_party_character_ids()
	if exp_p.size() != act_p.size():
		return false
	for i in exp_p.size():
		if str(exp_p[i]) != str(act_p[i]):
			return false
	return true


func _adventure_prepared_exact(snap: Dictionary) -> bool:
	if bool(snap.get("prepared", false)) != AdventureState.has_prepared_stage():
		return false
	if str(AdventureState.get_selected_area_id()) != str(snap.get("area_id", &"")):
		return false
	if str(AdventureState.get_selected_stage_id()) != str(snap.get("stage_id", &"")):
		return false
	if not AdventureState.has_prepared_stage():
		return true
	var st: StageDefinition = AdventureState.get_prepared_stage()
	var ar: StageAreaDefinition = AdventureState.get_prepared_area()
	if st == null or ar == null:
		return false
	if int(st.get_stage_number()) != int(snap.get("stage_number", -1)):
		return false
	if str(st.get_display_name()) != str(snap.get("display_name", "")):
		return false
	if str(st.get_summary()) != str(snap.get("summary", "")):
		return false
	return true


func _capture_adventure_prepared() -> Dictionary:
	var out := {
		"prepared": AdventureState.has_prepared_stage(),
		"area_id": AdventureState.get_selected_area_id(),
		"stage_id": AdventureState.get_selected_stage_id(),
		"stage_number": 0,
		"display_name": "",
		"summary": "",
	}
	if AdventureState.has_prepared_stage():
		var st: StageDefinition = AdventureState.get_prepared_stage()
		if st != null:
			out["stage_number"] = st.get_stage_number()
			out["display_name"] = st.get_display_name()
			out["summary"] = st.get_summary()
	return out


func _empty_board_cells() -> Array[StringName]:
	var cells: Array[StringName] = []
	cells.resize(BattleBoardModel.CELL_COUNT)
	for i in BattleBoardModel.CELL_COUNT:
		cells[i] = BattleOrbKind.EMPTY
	return cells


func _canonical_inactive_runtime_with_encounter(active_enc: Dictionary) -> Dictionary:
	return {
		"active": false,
		"session_area_id": &"",
		"session_stage_id": &"",
		"session_party_character_ids": [],
		"session_leader_character_id": &"",
		"width": BattleBoardModel.WIDTH,
		"height": BattleBoardModel.HEIGHT,
		"board_cells": _empty_board_cells(),
		"rng_state": BattleRuntime.CANONICAL_INACTIVE_RNG,
		"turn_count": 0,
		"phase": BattleRuntime.PHASE_INACTIVE,
		"selected_x": -1,
		"selected_y": -1,
		"last_match_count": 0,
		"last_cascade_count": 0,
		"last_resolution_events": [],
		"last_combat_events": [],
		"last_message": "",
		"encounter": active_enc,
	}


func _signal_connection_count(sig: Signal) -> int:
	return sig.get_connections().size()


func _assert_production_cleanup(fp0: Dictionary, rev0: int) -> void:
	_assert_eq("cl_fx_paths_empty", _fixture_paths.size(), 0)
	var dir := DirAccess.open(FIXTURE_DIR)
	if dir != null:
		dir.list_dir_begin()
		var n: String = dir.get_next()
		var leftover: int = 0
		while n != "":
			if n != "." and n != "..":
				leftover += 1
			n = dir.get_next()
		dir.list_dir_end()
		_assert_eq("cl_fx_dir_empty", leftover, 0)
	# Overrides return production paths (load_default equals DEFAULT_PATH load).
	var st_def: Dictionary = StageEncounterCatalog.load_from_path(StageEncounterCatalog.DEFAULT_PATH)
	var st_cur: Dictionary = StageEncounterCatalog.load_default()
	_assert_true("cl_se_override_off", bool(st_def.get("ok", false)) and bool(st_cur.get("ok", false)))
	_assert_eq(
		"cl_se_enc_count",
		(st_def.get("encounters", []) as Array).size(),
		(st_cur.get("encounters", []) as Array).size()
	)
	var en_def: Dictionary = EnemyCatalog.load_from_path(EnemyCatalog.DEFAULT_PATH)
	var en_cur: Dictionary = EnemyCatalog.load_default()
	_assert_eq(
		"cl_en_count",
		(en_def.get("enemies", []) as Array).size(),
		(en_cur.get("enemies", []) as Array).size()
	)
	var ch_def: Dictionary = BattleCharacterStatsCatalog.load_from_path(BattleCharacterStatsCatalog.DEFAULT_PATH)
	var ch_cur: Dictionary = BattleCharacterStatsCatalog.load_default()
	_assert_eq(
		"cl_ch_count",
		(ch_def.get("stats", []) as Array).size(),
		(ch_cur.get("stats", []) as Array).size()
	)
	_assert_true("cl_fp", _fp_eq(fp0, _prod_fp()))
	PlayerData.configure_test_storage_path("user://feibao_tests/enc_g038_cleanup")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	var prof = PlayerData.get_profile()
	_assert_eq("cl_schema", prof.get_schema_version(), 2)
	var prof_snap: Dictionary = prof.to_dictionary()
	_assert_true("cl_no_encounter_key", not prof_snap.has("encounter"))
	_assert_true("cl_no_current_hp_key", not prof_snap.has("current_hp"))
	var stages: Dictionary = StageCatalog.load_default()
	_assert_true("cl_stage_ok", bool(stages.get("ok", false)))
	_assert_eq("cl_stage_schema", StageCatalog.EXPECTED_SCHEMA_VERSION, 1)


func _prod_fp() -> Dictionary:
	var snap: Dictionary = {}
	for path in [
		"user://feibao/player_profile.json",
		"user://feibao/player_profile.json.tmp",
		"user://feibao/player_profile.json.bak",
	]:
		if not FileAccess.file_exists(path):
			snap[path] = {"exists": false, "sha": "", "len": -1}
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		var b: PackedByteArray = f.get_buffer(f.get_length())
		f.close()
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(b)
		snap[path] = {"exists": true, "sha": ctx.finish().hex_encode(), "len": b.size()}
	return snap


func _fp_eq(a: Dictionary, b: Dictionary) -> bool:
	for k in a.keys():
		var x: Dictionary = a[k]
		var y: Dictionary = b.get(k, {}) as Dictionary
		if bool(x.get("exists")) != bool(y.get("exists")):
			return false
		if str(x.get("sha")) != str(y.get("sha")):
			return false
		if int(x.get("len")) != int(y.get("len")):
			return false
	return true


func _seed_party3_session(stage_id: StringName = &"dev_stage_mist_03") -> void:
	PlayerData.configure_test_storage_path("user://feibao_tests/enc_g037")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	PlayerData.grant_character(&"partner_a")
	PlayerData.grant_character(&"partner_b")
	PlayerData.add_party_member(&"partner_a")
	PlayerData.add_party_member(&"partner_b")
	_assert_eq("seed_party3", PlayerData.get_active_party_character_ids().size(), 3)
	_reset_domain()
	AdventureState.prepare_stage(stage_id)
	_assert_true("seed_bs", bool(BattleState.begin_from_prepared_stage().get("ok", false)))
	_assert_eq("seed_party_bind", BattleState.get_party_character_ids().size(), 3)


func _seed_solo(stage_id: StringName = &"dev_stage_beginner_01") -> void:
	PlayerData.configure_test_storage_path("user://feibao_tests/enc_g037_solo")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	# Ensure canonical solo party (feibao_dev only).
	while PlayerData.get_active_party_character_ids().size() > 1:
		var ids: Array[StringName] = PlayerData.get_active_party_character_ids()
		var tail: StringName = ids[ids.size() - 1]
		PlayerData.remove_party_member(tail)
	_assert_eq("seed_solo_party", PlayerData.get_active_party_character_ids().size(), 1)
	_reset_domain()
	AdventureState.prepare_stage(stage_id)
	_assert_true("seed_solo_bs", bool(BattleState.begin_from_prepared_stage().get("ok", false)))
	_assert_eq("seed_solo_bs_party", BattleState.get_party_character_ids().size(), 1)


func _match_ready_board() -> Array[StringName]:
	# Alternating base (no 3-run), then row0: E E T E L S — swap (2,0)-(3,0) → E E E.
	var out: Array[StringName] = []
	out.resize(30)
	var kinds: Array[StringName] = [
		BattleOrbKind.EMBER, BattleOrbKind.TIDE, BattleOrbKind.LEAF, BattleOrbKind.LIGHT, BattleOrbKind.SHADOW
	]
	for y in 5:
		for x in 6:
			out[BattleBoardModel.index_of(x, y)] = kinds[(x + y * 2) % kinds.size()]
	out[0] = BattleOrbKind.EMBER
	out[1] = BattleOrbKind.EMBER
	out[2] = BattleOrbKind.TIDE
	out[3] = BattleOrbKind.EMBER
	out[4] = BattleOrbKind.LIGHT
	out[5] = BattleOrbKind.SHADOW
	# Isolate vertical under swap columns
	for y in range(1, 5):
		out[BattleBoardModel.index_of(0, y)] = BattleOrbKind.TIDE if y % 2 == 0 else BattleOrbKind.LEAF
		out[BattleBoardModel.index_of(1, y)] = BattleOrbKind.LIGHT if y % 2 == 0 else BattleOrbKind.SHADOW
		out[BattleBoardModel.index_of(2, y)] = BattleOrbKind.SHADOW if y % 2 == 0 else BattleOrbKind.LIGHT
		out[BattleBoardModel.index_of(3, y)] = BattleOrbKind.LEAF if y % 2 == 0 else BattleOrbKind.TIDE
	return out


func _runtime_exact_1_1(snap: Dictionary) -> bool:
	if bool(snap.get("active", false)) != BattleRuntime.has_active_runtime():
		return false
	if str(BattleRuntime.get_session_area_id()) != str(snap.get("session_area_id", &"")):
		return false
	if str(BattleRuntime.get_session_stage_id()) != str(snap.get("session_stage_id", &"")):
		return false
	if str(BattleRuntime.get_session_leader_character_id()) != str(snap.get("session_leader_character_id", &"")):
		return false
	var sp: Array = snap.get("session_party_character_ids", []) as Array
	var ap: Array[StringName] = BattleRuntime.get_session_party_character_ids()
	if sp.size() != ap.size():
		return false
	for i in sp.size():
		if str(sp[i]) != str(ap[i]):
			return false
	var bc: Array = snap.get("board_cells", []) as Array
	var ac: Array[StringName] = BattleRuntime.get_board_cells()
	if bc.size() != ac.size():
		return false
	for i in bc.size():
		if str(bc[i]) != str(ac[i]):
			return false
	if BattleRuntime.get_rng_state() != int(snap.get("rng_state", -1)):
		return false
	if BattleRuntime.get_turn_count() != int(snap.get("turn_count", -1)):
		return false
	if str(BattleRuntime.get_phase()) != str(snap.get("phase", &"")):
		return false
	if BattleRuntime.get_selected_cell() != Vector2i(int(snap.get("selected_x", -9)), int(snap.get("selected_y", -9))):
		return false
	if BattleRuntime.get_last_match_count() != int(snap.get("last_match_count", -1)):
		return false
	if BattleRuntime.get_last_cascade_count() != int(snap.get("last_cascade_count", -1)):
		return false
	if str(BattleRuntime.get_last_message()) != str(snap.get("last_message", "")):
		return false
	if not BattleResolutionEvent.events_equal(
		snap.get("last_resolution_events", []) as Array, BattleRuntime.get_last_resolution_events()
	):
		return false
	if not BattleCombatEvent.events_equal(
		snap.get("last_combat_events", []) as Array, BattleRuntime.get_last_combat_events()
	):
		return false
	var exp_enc: Dictionary = {"player_combatants": [], "enemy_combatants": [], "active_enemy_index": -1}
	if snap.has("encounter") and snap.get("encounter") is Dictionary:
		exp_enc = snap.get("encounter") as Dictionary
	var er: Dictionary = BattleEncounterModel.restore_snapshot(exp_enc)
	var ar: Dictionary = BattleEncounterModel.restore_snapshot(BattleRuntime.get_encounter_snapshot())
	if not bool(er.get("ok", false)) or not bool(ar.get("ok", false)):
		return false
	return BattleEncounterModel.equals(
		er.get("encounter") as BattleEncounterModel, ar.get("encounter") as BattleEncounterModel
	)


func _combatants_exact(a: Array[BattleCombatantModel], b: Array[BattleCombatantModel]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not BattleCombatantModel.equals(a[i], b[i]):
			return false
	return true


func _connect_sigs() -> Dictionary:
	var sigs := {"rt": [0], "bd": [0], "ph": [0], "en": [0], "on_rt": null, "on_bd": null, "on_ph": null, "on_en": null}
	var on_rt := func(_a: bool) -> void:
		sigs["rt"][0] = int(sigs["rt"][0]) + 1
	var on_bd := func() -> void:
		sigs["bd"][0] = int(sigs["bd"][0]) + 1
	var on_ph := func(_p: StringName) -> void:
		sigs["ph"][0] = int(sigs["ph"][0]) + 1
	var on_en := func() -> void:
		sigs["en"][0] = int(sigs["en"][0]) + 1
	sigs["on_rt"] = on_rt
	sigs["on_bd"] = on_bd
	sigs["on_ph"] = on_ph
	sigs["on_en"] = on_en
	BattleRuntime.runtime_changed.connect(on_rt)
	BattleRuntime.board_changed.connect(on_bd)
	BattleRuntime.phase_changed.connect(on_ph)
	BattleRuntime.encounter_changed.connect(on_en)
	return sigs


func _disconnect_sigs(sigs: Dictionary) -> void:
	var on_rt: Callable = sigs["on_rt"] as Callable
	var on_bd: Callable = sigs["on_bd"] as Callable
	var on_ph: Callable = sigs["on_ph"] as Callable
	var on_en: Callable = sigs["on_en"] as Callable
	if BattleRuntime.runtime_changed.is_connected(on_rt):
		BattleRuntime.runtime_changed.disconnect(on_rt)
	if BattleRuntime.board_changed.is_connected(on_bd):
		BattleRuntime.board_changed.disconnect(on_bd)
	if BattleRuntime.phase_changed.is_connected(on_ph):
		BattleRuntime.phase_changed.disconnect(on_ph)
	if BattleRuntime.encounter_changed.is_connected(on_en):
		BattleRuntime.encounter_changed.disconnect(on_en)


func _sig_base(sigs: Dictionary) -> Dictionary:
	return {"rt": int(sigs["rt"][0]), "bd": int(sigs["bd"][0]), "ph": int(sigs["ph"][0]), "en": int(sigs["en"][0])}


func _assert_sig_zero(tag: String, sigs: Dictionary, base: Dictionary) -> void:
	_assert_eq("%s_sig_rt" % tag, int(sigs["rt"][0]), int(base["rt"]))
	_assert_eq("%s_sig_bd" % tag, int(sigs["bd"][0]), int(base["bd"]))
	_assert_eq("%s_sig_ph" % tag, int(sigs["ph"][0]), int(base["ph"]))
	_assert_eq("%s_sig_en" % tag, int(sigs["en"][0]), int(base["en"]))


func _rect_fully_within(inner: Rect2, outer: Rect2, tolerance: float) -> bool:
	return (
		inner.position.x >= outer.position.x - tolerance
		and inner.position.y >= outer.position.y - tolerance
		and inner.end.x <= outer.end.x + tolerance
		and inner.end.y <= outer.end.y + tolerance
	)


func _assert_parse_fail(tag: String, ok_flag: Variant) -> void:
	_assert_true(tag, bool(ok_flag) == false)


func _run_catalog_and_combatant_closeout() -> void:
	var base_stats := (
		'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":10,"attack":1,"defense":1}]}'
	)
	_assert_parse_fail(
		"cat_dup_char",
		BattleCharacterStatsCatalog.parse_json_text(
			'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":10,"attack":1,"defense":1},{"character_id":"feibao_dev","affinity":"ember","max_hp":10,"attack":1,"defense":1}]}'
		).get("ok", true)
	)
	_assert_parse_fail(
		"cat_miss_field",
		BattleCharacterStatsCatalog.parse_json_text(
			'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":10,"attack":1}]}'
		).get("ok", true)
	)
	_assert_parse_fail(
		"cat_bad_aff",
		BattleCharacterStatsCatalog.parse_json_text(
			'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"fire","max_hp":10,"attack":1,"defense":1}]}'
		).get("ok", true)
	)
	_assert_parse_fail(
		"cat_hp0",
		BattleCharacterStatsCatalog.parse_json_text(
			'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":0,"attack":1,"defense":1}]}'
		).get("ok", true)
	)
	_assert_parse_fail(
		"cat_atk_neg",
		BattleCharacterStatsCatalog.parse_json_text(
			'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":10,"attack":-1,"defense":1}]}'
		).get("ok", true)
	)
	_assert_parse_fail(
		"cat_def_neg",
		BattleCharacterStatsCatalog.parse_json_text(
			'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":10,"attack":1,"defense":-1}]}'
		).get("ok", true)
	)
	for field in ["max_hp", "attack", "defense"]:
		for bad_val in ['true', '"10"', "null"]:
			var j: String = base_stats.replace('"max_hp":10', '"%s":%s' % [field, bad_val] if field == "max_hp" else '"max_hp":10')
			if field == "attack":
				j = base_stats.replace('"attack":1', '"attack":%s' % bad_val)
			elif field == "defense":
				j = base_stats.replace('"defense":1', '"defense":%s' % bad_val)
			_assert_parse_fail("cat_%s_%s" % [field, bad_val.replace('"', "")], BattleCharacterStatsCatalog.parse_json_text(j).get("ok", true))
	var ok_float: Dictionary = BattleCharacterStatsCatalog.parse_json_text(
		'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":10.0,"attack":1,"defense":1}]}'
	)
	_assert_true("cat_whole_float_ok", bool(ok_float.get("ok", false)))
	_assert_parse_fail(
		"cat_frac",
		BattleCharacterStatsCatalog.parse_json_text(
			'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":10.5,"attack":1,"defense":1}]}'
		).get("ok", true)
	)

	_assert_parse_fail(
		"en_dup",
		EnemyCatalog.parse_json_text(
			'{"schema_version":1,"catalog_kind":"development_seed","enemies":[{"enemy_id":"training_sprout","display_name":"A","affinity":"leaf","max_hp":1,"attack":0,"defense":0,"visual_symbol":"x"},{"enemy_id":"training_sprout","display_name":"B","affinity":"leaf","max_hp":1,"attack":0,"defense":0,"visual_symbol":"y"}]}'
		).get("ok", true)
	)
	var en_ok: Dictionary = EnemyCatalog.load_default()
	_assert_true("en_load_ok", bool(en_ok.get("ok", false)))
	var en_list: Array = en_ok.get("enemies", []) as Array
	_assert_true("en_load_nonempty", en_list.size() >= 1)
	# Caller mutation must not poison subsequent loads.
	if en_list.size() > 0 and en_list[0] is Dictionary:
		(en_list[0] as Dictionary)["display_name"] = "MUTATED"
	var en_ok2: Dictionary = EnemyCatalog.load_default()
	_assert_true("en_defensive_reload", bool(en_ok2.get("ok", false)))
	if (en_ok2.get("enemies", []) as Array).size() > 0:
		_assert_true(
			"en_defensive_copy",
			str(((en_ok2.get("enemies", []) as Array)[0] as Dictionary).get("display_name", "")) != "MUTATED"
		)

	_assert_parse_fail(
		"se_enemy0",
		StageEncounterCatalog.parse_json_text(
			'{"schema_version":1,"catalog_kind":"development_seed","encounters":[{"stage_id":"dev_stage_beginner_01","enemy_ids":[]}]}'
		).get("ok", true)
	)
	_assert_parse_fail(
		"se_enemy4",
		StageEncounterCatalog.parse_json_text(
			'{"schema_version":1,"catalog_kind":"development_seed","encounters":[{"stage_id":"dev_stage_beginner_01","enemy_ids":["training_sprout","training_droplet","training_emberling","training_sprout"]}]}'
		).get("ok", true)
	)
	_assert_parse_fail(
		"se_dup_stage",
		StageEncounterCatalog.parse_json_text(
			'{"schema_version":1,"catalog_kind":"development_seed","encounters":[{"stage_id":"dev_stage_beginner_01","enemy_ids":["training_sprout"]},{"stage_id":"dev_stage_beginner_01","enemy_ids":["training_droplet"]}]}'
		).get("ok", true)
	)
	_assert_parse_fail(
		"se_unknown_enemy",
		StageEncounterCatalog.parse_json_text(
			'{"schema_version":1,"catalog_kind":"development_seed","encounters":[{"stage_id":"dev_stage_beginner_01","enemy_ids":["no_such_enemy_xyz"]}]}'
		).get("ok", true)
	)
	_assert_parse_fail(
		"se_dup_enemy",
		StageEncounterCatalog.parse_json_text(
			'{"schema_version":1,"catalog_kind":"development_seed","encounters":[{"stage_id":"dev_stage_beginner_01","enemy_ids":["training_sprout","training_sprout"]}]}'
		).get("ok", true)
	)

	var p: Dictionary = BattleCombatantModel.create_player(&"feibao_dev", "飛寶（開發樣本）", &"ember", 0, 120, 14, 8)
	_assert_true("cm_p", bool(p.get("ok", false)))
	var pc: BattleCombatantModel = p.get("combatant") as BattleCombatantModel
	var dup: BattleCombatantModel = pc.duplicate_model()
	dup.set_current_hp_for_tests(1)
	_assert_eq("cm_dup_def", pc.get_current_hp(), 120)
	var snap: Dictionary = pc.capture_snapshot()
	var r: Dictionary = BattleCombatantModel.restore_snapshot(snap)
	_assert_true("cm_round", bool(r.get("ok", false)))
	var bad: Dictionary = snap.duplicate(true)
	bad["attack"] = 999
	_assert_parse_fail("cm_atk_mis", BattleCombatantModel.validate_snapshot(bad).get("ok", true))
	bad = snap.duplicate(true)
	bad["defense"] = 999
	_assert_parse_fail("cm_def_mis", BattleCombatantModel.validate_snapshot(bad).get("ok", true))
	bad = snap.duplicate(true)
	bad["display_name"] = "X"
	_assert_parse_fail("cm_name_mis", BattleCombatantModel.validate_snapshot(bad).get("ok", true))
	bad = snap.duplicate(true)
	bad["affinity"] = &"ember_wrong"
	_assert_parse_fail("cm_aff_mis", BattleCombatantModel.validate_snapshot(bad).get("ok", true))
	bad = snap.duplicate(true)
	bad["max_hp"] = 999
	_assert_parse_fail("cm_max_mis", BattleCombatantModel.validate_snapshot(bad).get("ok", true))
	bad = snap.duplicate(true)
	bad["current_hp"] = int(snap.get("max_hp", 1)) + 1
	_assert_parse_fail("cm_hp_over", BattleCombatantModel.validate_snapshot(bad).get("ok", true))
	bad = snap.duplicate(true)
	bad["extra"] = 1
	_assert_parse_fail("cm_extra", BattleCombatantModel.validate_snapshot(bad).get("ok", true))
	bad = snap.duplicate(true)
	bad.erase("max_hp")
	_assert_parse_fail("cm_miss", BattleCombatantModel.validate_snapshot(bad).get("ok", true))
	for field in ["max_hp", "attack", "defense", "current_hp", "slot_index"]:
		for val in [1.5, "1", true, null]:
			bad = snap.duplicate(true)
			bad[field] = val
			_assert_parse_fail("cm_type_%s_%s" % [field, str(val)], BattleCombatantModel.validate_snapshot(bad).get("ok", true))
	bad = snap.duplicate(true)
	bad["display_name"] = RefCounted.new()
	_assert_parse_fail("cm_obj", BattleCombatantModel.validate_snapshot(bad).get("ok", true))
	bad = snap.duplicate(true)
	bad["display_name"] = Callable()
	_assert_parse_fail("cm_callable", BattleCombatantModel.validate_snapshot(bad).get("ok", true))
	var e: Dictionary = BattleCombatantModel.create_enemy(&"training_sprout", "訓練幼芽", &"leaf", 0, 40, 8, 3)
	_assert_true("cm_e", bool(e.get("ok", false)))
	var es: Dictionary = (e.get("combatant") as BattleCombatantModel).capture_snapshot()
	_assert_true("cm_e_round", bool(BattleCombatantModel.restore_snapshot(es).get("ok", false)))
	print("[INFO] catalog/combatant closeout passed")


func _run_forced_accepted_turn() -> void:
	_seed_solo(&"dev_stage_beginner_01")
	_assert_true("ft_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	var board: Array[StringName] = _match_ready_board()
	_assert_true("ft_no_init_match", BattleBoardEngine.find_matches(board).is_empty())
	_assert_true("ft_adj", BattleBoardEngine.are_adjacent(2, 0, 3, 0))
	# Prove swap creates match without mutating runtime board yet
	var probe: Array[StringName] = board.duplicate()
	var tmp: StringName = probe[2]
	probe[2] = probe[3]
	probe[3] = tmp
	_assert_true("ft_probe_match", BattleBoardEngine.find_matches(probe).size() >= 3)

	_assert_true("ft_set", BattleRuntime.set_board_cells_for_tests(board))
	var players0: Array[BattleCombatantModel] = BattleRuntime.get_player_combatants()
	var enemies0: Array[BattleCombatantModel] = BattleRuntime.get_enemy_combatants()
	var aei0: int = BattleRuntime.get_active_enemy_index()
	var turn0: int = BattleRuntime.get_turn_count()
	var sigs: Dictionary = _connect_sigs()
	var base: Dictionary = _sig_base(sigs)

	var res: Dictionary = BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0))
	_assert_true("ft_ok", bool(res.get("ok", false)))
	_assert_true("ft_accepted", bool(res.get("accepted", false)))
	_assert_eq("ft_turn", BattleRuntime.get_turn_count(), turn0 + 1)
	_assert_true("ft_cleared", int(res.get("cleared_cell_count", 0)) >= 3)
	_assert_true("ft_cascade", int(res.get("cascade_count", 0)) >= 1)
	# Players never take damage in 1.2.0 player-attack foundation.
	_assert_true("ft_players_exact", _combatants_exact(players0, BattleRuntime.get_player_combatants()))
	_assert_eq("ft_aei", BattleRuntime.get_active_enemy_index(), aei0)
	# Active enemy receives deterministic damage from ember match (feibao_dev).
	var after_enemies: Array[BattleCombatantModel] = BattleRuntime.get_enemy_combatants()
	_assert_eq("ft_enemy_count", after_enemies.size(), enemies0.size())
	_assert_true("ft_enemy_hp_down", after_enemies[aei0].get_current_hp() < enemies0[aei0].get_current_hp())
	_assert_true("ft_total_dmg", int(res.get("total_damage", 0)) > 0)
	_assert_eq("ft_en_sig", int(sigs["en"][0]), int(base["en"]) + 1)
	var combat: Array = BattleRuntime.get_last_combat_events()
	_assert_true("ft_combat_nonempty", not combat.is_empty())
	var board_events: Array = BattleRuntime.get_last_resolution_events()
	for e in board_events:
		if e is Dictionary:
			var t: String = str((e as Dictionary).get("type", ""))
			_assert_true(
				"ft_board_no_victory_%s" % t,
				t != "victory" and t != "defeat"
			)

	var after_players: Array[BattleCombatantModel] = BattleRuntime.get_player_combatants()
	var packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	screen.call("configure_screen", &"battle")
	for _i in 3:
		await _tree.process_frame
	var cards: Array = screen.call("get_party_cards_for_tests") as Array
	_assert_eq("ft_ui_cards", cards.size(), 1)
	var hp_text: String = str(screen.call("get_card_hp_label_for_tests", cards[0]))
	_assert_eq(
		"ft_ui_hp",
		hp_text,
		"HP %d/%d" % [after_players[0].get_current_hp(), after_players[0].get_max_hp()]
	)
	var bar: ProgressBar = screen.call("get_card_progress_bar_for_tests", cards[0]) as ProgressBar
	_assert_true("ft_ui_bar", bar != null)
	_assert_eq("ft_ui_bar_val", int(bar.value), after_players[0].get_current_hp())
	# Player HP unchanged vs pre-turn combatants
	_assert_eq("ft_ui_hp_unchanged", after_players[0].get_current_hp(), players0[0].get_current_hp())
	var enemy_cards: Array = screen.call("get_enemy_cards_for_tests") as Array
	if not enemy_cards.is_empty():
		var ehp: String = str(screen.call("get_card_hp_label_for_tests", enemy_cards[0]))
		_assert_eq(
			"ft_ui_enemy_hp",
			ehp,
			"HP %d/%d" % [after_enemies[0].get_current_hp(), after_enemies[0].get_max_hp()]
		)
	screen.queue_free()
	await _tree.process_frame
	_disconnect_sigs(sigs)
	print("[INFO] forced accepted turn passed")


func _assert_restore_fail(tag: String, before: Dictionary, bad: Dictionary, sigs: Dictionary, base: Dictionary) -> void:
	var res: Dictionary = BattleRuntime.restore_runtime_snapshot(bad)
	_assert_true("%s_okf" % tag, bool(res.get("ok", true)) == false)
	_assert_true("%s_exact" % tag, _runtime_exact_1_1(before))
	_assert_sig_zero(tag, sigs, base)


func _run_snapshot_matrix_closeout() -> void:
	# 3x3 fixture so order / duplicate-slot cases are real multi-combatant evidence.
	_seed_party3_session(&"dev_stage_mist_03")
	_assert_true("sm_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	_assert_eq("sm_p3", BattleRuntime.get_player_combatants().size(), 3)
	_assert_eq("sm_e3", BattleRuntime.get_enemy_combatants().size(), 3)
	var before: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var sigs: Dictionary = _connect_sigs()
	var base: Dictionary = _sig_base(sigs)

	var bad: Dictionary
	var enc: Dictionary
	var players: Array
	var enemies: Array
	var p0: Dictionary
	var p1: Dictionary
	var e0: Dictionary
	var e1: Dictionary

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enc["player_combatants"] = "x"
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_p_nonarr", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enc["enemy_combatants"] = 1
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_e_nonarr", before, bad, sigs, base)

	for v in ["x", true, null]:
		enc = (before.get("encounter") as Dictionary).duplicate(true)
		enc["active_enemy_index"] = v
		bad = before.duplicate(true)
		bad["encounter"] = enc
		_assert_restore_fail("sm_aei_%s" % str(v), before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enc["active_enemy_index"] = -1
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_aei_neg1_active", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enc["active_enemy_index"] = 3
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_aei_eqcount", before, bad, sigs, base)

	bad = before.duplicate(true)
	bad["encounter"] = "not_dict"
	_assert_restore_fail("sm_enc_nondict", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enc["player_combatants"] = []
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_pcount0", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	players = (enc.get("player_combatants") as Array).duplicate(true)
	p0 = (players[0] as Dictionary).duplicate(true)
	var p_extra: Array = players.duplicate(true)
	var px4: Dictionary = p0.duplicate(true)
	px4["slot_index"] = 3
	p_extra.append(px4)
	enc["player_combatants"] = p_extra
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_pcount4", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enc["enemy_combatants"] = []
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_ecount0", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enemies = (enc.get("enemy_combatants") as Array).duplicate(true)
	e0 = (enemies[0] as Dictionary).duplicate(true)
	var e_extra: Array = enemies.duplicate(true)
	var ex4: Dictionary = e0.duplicate(true)
	ex4["slot_index"] = 3
	e_extra.append(ex4)
	enc["enemy_combatants"] = e_extra
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_ecount4", before, bad, sigs, base)

	# Wrong player order: swap sources, keep contiguous slots.
	enc = (before.get("encounter") as Dictionary).duplicate(true)
	players = (enc.get("player_combatants") as Array).duplicate(true)
	p0 = (players[0] as Dictionary).duplicate(true)
	p1 = (players[1] as Dictionary).duplicate(true)
	var p0_sw: Dictionary = p1.duplicate(true)
	p0_sw["slot_index"] = 0
	var p1_sw: Dictionary = p0.duplicate(true)
	p1_sw["slot_index"] = 1
	var p2k: Dictionary = (players[2] as Dictionary).duplicate(true)
	p2k["slot_index"] = 2
	enc["player_combatants"] = [p0_sw, p1_sw, p2k]
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_wrong_player_order", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enemies = (enc.get("enemy_combatants") as Array).duplicate(true)
	e0 = (enemies[0] as Dictionary).duplicate(true)
	e1 = (enemies[1] as Dictionary).duplicate(true)
	var e0_sw: Dictionary = e1.duplicate(true)
	e0_sw["slot_index"] = 0
	var e1_sw: Dictionary = e0.duplicate(true)
	e1_sw["slot_index"] = 1
	var e2k: Dictionary = (enemies[2] as Dictionary).duplicate(true)
	e2k["slot_index"] = 2
	enc["enemy_combatants"] = [e0_sw, e1_sw, e2k]
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_wrong_enemy_order", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	players = (enc.get("player_combatants") as Array).duplicate(true)
	p0 = (players[0] as Dictionary).duplicate(true)
	p1 = (players[1] as Dictionary).duplicate(true)
	p1["source_id"] = p0.get("source_id")
	p1["slot_index"] = 1
	enc["player_combatants"] = [p0, p1, players[2]]
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_dup_player_id", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enemies = (enc.get("enemy_combatants") as Array).duplicate(true)
	e0 = (enemies[0] as Dictionary).duplicate(true)
	e1 = (enemies[1] as Dictionary).duplicate(true)
	e1["source_id"] = e0.get("source_id")
	e1["slot_index"] = 1
	enc["enemy_combatants"] = [e0, e1, enemies[2]]
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_dup_enemy_id", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	players = (enc.get("player_combatants") as Array).duplicate(true)
	p0 = (players[0] as Dictionary).duplicate(true)
	p1 = (players[1] as Dictionary).duplicate(true)
	p0["slot_index"] = 0
	p1["slot_index"] = 0
	enc["player_combatants"] = [p0, p1, players[2]]
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_dup_player_slot", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enemies = (enc.get("enemy_combatants") as Array).duplicate(true)
	e0 = (enemies[0] as Dictionary).duplicate(true)
	e1 = (enemies[1] as Dictionary).duplicate(true)
	e0["slot_index"] = 0
	e1["slot_index"] = 0
	enc["enemy_combatants"] = [e0, e1, enemies[2]]
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_dup_enemy_slot", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	players = (enc.get("player_combatants") as Array).duplicate(true)
	p0 = (players[0] as Dictionary).duplicate(true)
	p0["slot_index"] = 2
	enc["player_combatants"] = [p0, players[1], players[2]]
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_p_slot_noncontig", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enemies = (enc.get("enemy_combatants") as Array).duplicate(true)
	e0 = (enemies[0] as Dictionary).duplicate(true)
	e0["slot_index"] = 2
	enc["enemy_combatants"] = [e0, enemies[1], enemies[2]]
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_e_slot_noncontig", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	players = (enc.get("player_combatants") as Array).duplicate(true)
	p0 = (players[0] as Dictionary).duplicate(true)
	p0["source_id"] = &"nope"
	enc["player_combatants"] = [p0, players[1], players[2]]
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_unk_player", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enemies = (enc.get("enemy_combatants") as Array).duplicate(true)
	e0 = (enemies[0] as Dictionary).duplicate(true)
	e0["source_id"] = &"nope_enemy"
	enc["enemy_combatants"] = [e0, enemies[1], enemies[2]]
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_unk_enemy", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	players = (enc.get("player_combatants") as Array).duplicate(true)
	p0 = (players[0] as Dictionary).duplicate(true)
	p0["combatant_kind"] = &"enemy"
	enc["player_combatants"] = [p0, players[1], players[2]]
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_p_kind_enemy", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enemies = (enc.get("enemy_combatants") as Array).duplicate(true)
	e0 = (enemies[0] as Dictionary).duplicate(true)
	e0["combatant_kind"] = &"player"
	enc["enemy_combatants"] = [e0, enemies[1], enemies[2]]
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_e_kind_player", before, bad, sigs, base)

	for side in ["player", "enemy"]:
		for mut_tag in ["neg_hp", "hp_over", "max_mis", "atk_mis", "def_mis", "aff_mis", "name_mis", "obj", "callable", "extra_key", "miss_key"]:
			enc = (before.get("encounter") as Dictionary).duplicate(true)
			players = (enc.get("player_combatants") as Array).duplicate(true)
			enemies = (enc.get("enemy_combatants") as Array).duplicate(true)
			var target: Dictionary
			if side == "player":
				target = (players[0] as Dictionary).duplicate(true)
			else:
				target = (enemies[0] as Dictionary).duplicate(true)
			match mut_tag:
				"neg_hp":
					target["current_hp"] = -1
				"hp_over":
					target["current_hp"] = int(target.get("max_hp", 1)) + 1
				"max_mis":
					target["max_hp"] = int(target.get("max_hp", 1)) + 5
				"atk_mis":
					target["attack"] = 999
				"def_mis":
					target["defense"] = 999
				"aff_mis":
					target["affinity"] = &"not_real"
				"name_mis":
					target["display_name"] = "X"
				"obj":
					target["display_name"] = RefCounted.new()
				"callable":
					target["display_name"] = Callable()
				"extra_key":
					target["extra"] = 1
				"miss_key":
					target.erase("max_hp")
			if side == "player":
				players[0] = target
				enc["player_combatants"] = players
			else:
				enemies[0] = target
				enc["enemy_combatants"] = enemies
			bad = before.duplicate(true)
			bad["encounter"] = enc
			_assert_restore_fail("sm_%s_%s" % [side, mut_tag], before, bad, sigs, base)

	enc = {"player_combatants": [], "enemy_combatants": [], "active_enemy_index": -1}
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_active_inact_enc", before, bad, sigs, base)

	var active_enc: Dictionary = (before.get("encounter") as Dictionary).duplicate(true)
	var inactive_snap: Dictionary = _canonical_inactive_runtime_with_encounter(active_enc)
	_assert_restore_fail("sm_inact_rt_act_enc", before, inactive_snap, sigs, base)

	enc = {"player_combatants": [], "enemy_combatants": [], "active_enemy_index": 0}
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sm_inact_enc_bad_aei", before, bad, sigs, base)

	var cand: Dictionary = before.duplicate(true)
	enc = (cand.get("encounter") as Dictionary).duplicate(true)
	players = (enc.get("player_combatants") as Array).duplicate(true)
	p0 = (players[0] as Dictionary).duplicate(true)
	var max_hp: int = int(p0.get("max_hp", 2))
	p0["current_hp"] = max_hp - 1
	players[0] = p0
	enc["player_combatants"] = players
	cand["encounter"] = enc
	var base2: Dictionary = _sig_base(sigs)
	var ok: Dictionary = BattleRuntime.restore_runtime_snapshot(cand)
	_assert_true("sm_chg_ok", bool(ok.get("ok", false)))
	_assert_true("sm_chg_flag", bool(ok.get("changed", false)))
	_assert_true("sm_chg_exact", _runtime_exact_1_1(cand))
	_assert_eq("sm_chg_rt", int(sigs["rt"][0]), int(base2["rt"]) + 1)
	_assert_eq("sm_chg_en", int(sigs["en"][0]), int(base2["en"]) + 1)
	_assert_eq("sm_chg_bd", int(sigs["bd"][0]), int(base2["bd"]) + 1)
	_assert_eq("sm_chg_ph", int(sigs["ph"][0]), int(base2["ph"]))
	_assert_eq("sm_chg_hp", BattleRuntime.get_player_combatants()[0].get_current_hp(), max_hp - 1)

	var after: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var base3: Dictionary = _sig_base(sigs)
	var idemp: Dictionary = BattleRuntime.restore_runtime_snapshot(after)
	_assert_true("sm_idemp", bool(idemp.get("ok", false)) and bool(idemp.get("changed", true)) == false)
	_assert_sig_zero("sm_idemp", sigs, base3)
	_disconnect_sigs(sigs)
	print("[INFO] snapshot matrix closeout passed")

func _build_adv_screen() -> Control:
	_nav().call("reset", &"lobby")
	_nav().call("navigate_to", &"adventure", true)
	var packed: PackedScene = load("res://scenes/screens/adventure/adventure_screen.tscn") as PackedScene
	var adv: Control = packed.instantiate() as Control
	_tree.root.add_child(adv)
	adv.call("configure_screen", &"adventure")
	return adv


func _prepare_stage(adv: Control, area: StringName, stage: StringName) -> void:
	adv.call("select_area_for_test", area)
	adv.call("select_stage_for_test", stage)
	adv.call("press_prepare_for_test")


func _run_one_enter_failure(tag: String, apply_override: Callable) -> void:
	PlayerData.configure_test_storage_path("user://feibao_tests/enc_g038_enter")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	_reset_domain()
	_clear_overrides()
	var adv: Control = _build_adv_screen()
	await _tree.process_frame
	_prepare_stage(adv, &"dev_area_beginner_path", &"dev_stage_beginner_01")
	await _tree.process_frame
	_assert_true("%s_prep" % tag, AdventureState.has_prepared_stage())
	apply_override.call()
	var rev0: int = PlayerData.get_profile().get_revision()
	var fp0: Dictionary = _prod_fp()
	var hist0: int = int(_nav().call("get_history_size"))
	var rt0: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var st0: Dictionary = BattleState.capture_session_snapshot()
	var prep0: Dictionary = _capture_adventure_prepared()
	var sigs: Dictionary = _connect_sigs()
	var base: Dictionary = _sig_base(sigs)
	adv.call("press_enter_battle_for_test")
	await _tree.process_frame
	_assert_eq("%s_screen" % tag, str(_nav().call("get_current_screen")), "adventure")
	_assert_eq("%s_hist" % tag, int(_nav().call("get_history_size")), hist0)
	_assert_true("%s_st_exact" % tag, _battle_state_exact(st0))
	_assert_true("%s_rt_exact" % tag, _runtime_exact_1_1(rt0))
	_assert_true("%s_prep_exact" % tag, _adventure_prepared_exact(prep0))
	_assert_true("%s_enter_en" % tag, bool(adv.call("is_enter_battle_enabled")))
	_assert_eq("%s_rev" % tag, PlayerData.get_profile().get_revision(), rev0)
	_assert_true("%s_fp" % tag, _fp_eq(fp0, _prod_fp()))
	_assert_sig_zero(tag, sigs, base)
	_disconnect_sigs(sigs)
	_clear_overrides()
	var hist1: int = int(_nav().call("get_history_size"))
	adv.call("press_enter_battle_for_test")
	await _tree.process_frame
	await _tree.process_frame
	_assert_eq("%s_retry_hist" % tag, int(_nav().call("get_history_size")), hist1 + 1)
	_assert_true("%s_retry_st" % tag, BattleState.has_active_session())
	_assert_true("%s_retry_rt" % tag, BattleRuntime.has_active_runtime())
	_assert_true("%s_retry_enc" % tag, BattleRuntime.has_active_encounter())
	_assert_eq("%s_retry_cells" % tag, BattleRuntime.get_board_cells().size(), 30)
	adv.queue_free()
	await _tree.process_frame
	_reset_domain()


func _run_adventure_three_failures() -> void:
	await _run_one_enter_failure(
		"d1_stats",
		func() -> void:
			var arr: Array = []
			for item in BattleCharacterStatsCatalog.load_default().get("stats", []) as Array:
				var d: Dictionary = item as Dictionary
				if str(d.get("character_id", "")) == "feibao_dev":
					continue
				arr.append({
					"character_id": str(d.get("character_id")),
					"affinity": str(d.get("affinity")),
					"max_hp": int(d.get("max_hp")),
					"attack": int(d.get("attack")),
					"defense": int(d.get("defense")),
				})
			var p := _write_fixture("d1_stats.json", JSON.stringify({"schema_version": 1, "catalog_kind": "development_seed", "stats": arr}))
			BattleCharacterStatsCatalog.set_default_path_override_for_tests(p)
	)
	await _run_one_enter_failure(
		"d2_se",
		func() -> void:
			var p := _write_fixture(
				"d2_se.json",
				JSON.stringify({
					"schema_version": 1,
					"catalog_kind": "development_seed",
					"encounters": [{"stage_id": "dev_stage_mist_01", "enemy_ids": ["training_sprout"]}],
				})
			)
			StageEncounterCatalog.set_default_path_override_for_tests(p)
	)
	await _run_one_enter_failure(
		"d3_enemy",
		func() -> void:
			var p := _write_fixture(
				"d3_en.json",
				JSON.stringify({
					"schema_version": 1,
					"catalog_kind": "development_seed",
					"enemies": [
						{"enemy_id": "training_droplet", "display_name": "訓練水滴", "affinity": "tide", "max_hp": 48, "attack": 9, "defense": 4, "visual_symbol": "○"},
					],
				})
			)
			EnemyCatalog.set_default_path_override_for_tests(p)
	)
	print("[INFO] adventure three failures passed")


func _run_double_enter_leave() -> void:
	# Same-frame double enter
	PlayerData.configure_test_storage_path("user://feibao_tests/enc_g037_dbl")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	_reset_domain()
	_clear_overrides()
	var adv: Control = _build_adv_screen()
	await _tree.process_frame
	_prepare_stage(adv, &"dev_area_beginner_path", &"dev_stage_beginner_01")
	await _tree.process_frame
	var hist0: int = int(_nav().call("get_history_size"))
	var sigs: Dictionary = _connect_sigs()
	var base: Dictionary = _sig_base(sigs)
	adv.call("press_enter_battle_for_test")
	adv.call("press_enter_battle_for_test")
	await _tree.process_frame
	await _tree.process_frame
	_assert_eq("de_hist", int(_nav().call("get_history_size")), hist0 + 1)
	_assert_eq("de_rt", int(sigs["rt"][0]), int(base["rt"]) + 1)
	_assert_eq("de_bd", int(sigs["bd"][0]), int(base["bd"]) + 1)
	_assert_eq("de_en", int(sigs["en"][0]), int(base["en"]) + 1)
	_assert_true("de_active", BattleRuntime.has_active_runtime() and BattleRuntime.has_active_encounter())
	_disconnect_sigs(sigs)
	adv.queue_free()
	await _tree.process_frame

	# Same-frame double leave after forced turn + marked HP
	_seed_solo(&"dev_stage_beginner_01")
	_assert_true("dl_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	_assert_true("dl_set", BattleRuntime.set_board_cells_for_tests(_match_ready_board()))
	var sw: Dictionary = BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0))
	_assert_true("dl_turn", bool(sw.get("ok", false)) and bool(sw.get("accepted", false)))
	var snap: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var enc: Dictionary = (snap.get("encounter") as Dictionary).duplicate(true)
	var players: Array = (enc.get("player_combatants") as Array).duplicate(true)
	var p0: Dictionary = (players[0] as Dictionary).duplicate(true)
	p0["current_hp"] = int(p0.get("max_hp", 2)) - 1
	players[0] = p0
	enc["player_combatants"] = players
	snap["encounter"] = enc
	_assert_true("dl_mark", bool(BattleRuntime.restore_runtime_snapshot(snap).get("ok", false)))
	var marked: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var marked_hp: int = BattleRuntime.get_player_combatants()[0].get_current_hp()

	var packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	_nav().call("navigate_to", &"battle", true)
	var leave_n: Array = [0]
	var back_n: Array = [0]
	screen.leave_requested.connect(func() -> void: leave_n[0] = int(leave_n[0]) + 1)
	screen.back_requested.connect(func() -> void: back_n[0] = int(back_n[0]) + 1)
	screen.call("set_leave_nav_result_override_for_tests", false)
	var fail: bool = bool(screen.call("request_leave"))
	_assert_true("dl_fail", fail == false)
	_assert_true("dl_exact", _runtime_exact_1_1(marked))
	_assert_eq("dl_hp", BattleRuntime.get_player_combatants()[0].get_current_hp(), marked_hp)
	_assert_true("dl_controls", screen.call("get_leave_button").disabled == false)
	screen.call("clear_leave_nav_result_override_for_tests")
	var hist_l0: int = int(_nav().call("get_history_size"))
	var leave_n0: int = int(leave_n[0])
	var back_n0: int = int(back_n[0])
	var ok1: bool = bool(screen.call("request_leave"))
	var ok2: bool = bool(screen.call("request_leave"))
	await _tree.process_frame
	_assert_true("dl_ok1", ok1)
	_assert_true("dl_ok2_block", ok2 == false)
	_assert_eq("dl_leave_sig", int(leave_n[0]), leave_n0 + 1)
	_assert_eq("dl_back_sig", int(back_n[0]), back_n0 + 1)
	# go_back_or_fallback reduces history by exactly one transition.
	_assert_eq("dl_hist_delta", int(_nav().call("get_history_size")), hist_l0 - 1)
	_assert_true("dl_st_off", BattleState.has_active_session() == false)
	_assert_true("dl_rt_off", BattleRuntime.has_active_runtime() == false)
	_assert_true("dl_enc_off", BattleRuntime.has_active_encounter() == false)
	_assert_eq("dl_aei_inact", BattleRuntime.get_active_enemy_index(), -1)
	screen.queue_free()
	await _tree.process_frame
	print("[INFO] double enter/leave passed")


func _run_missing_encounter_screen() -> void:
	# BattleState active + Runtime inactive due to encounter catalog failure.
	_seed_solo(&"dev_stage_beginner_01")
	_assert_true("me_state", BattleState.has_active_session())
	var p := _write_fixture(
		"me_se.json",
		JSON.stringify({
			"schema_version": 1,
			"catalog_kind": "development_seed",
			"encounters": [{"stage_id": "dev_stage_mist_01", "enemy_ids": ["training_sprout"]}],
		})
	)
	StageEncounterCatalog.set_default_path_override_for_tests(p)
	var begin: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("me_begin_fail", bool(begin.get("ok", true)) == false)
	_assert_true("me_rt_off", BattleRuntime.has_active_runtime() == false)
	_assert_true("me_st_on", BattleState.has_active_session())

	var packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	screen.call("configure_screen", &"battle")
	for _i in 3:
		await _tree.process_frame
	_assert_true("me_screen_runtime_ok", bool(screen.call("is_runtime_ok")) == false)
	_assert_true("me_screen_err_vis", bool(screen.call("is_error_state_visible")))
	_assert_eq("me_screen_err_text", str(screen.call("get_error_text")), "沒有有效的戰鬥盤面")
	_assert_eq("me_screen_pc", (screen.call("get_party_cards_for_tests") as Array).size(), 0)
	_assert_eq("me_screen_ec", (screen.call("get_enemy_cards_for_tests") as Array).size(), 0)
	var grid: GridContainer = screen.call("get_board_grid") as GridContainer
	_assert_eq("me_screen_cells", grid.get_child_count(), 30)
	for i in grid.get_child_count():
		_assert_true("me_cell_dis_%d" % i, (grid.get_child(i) as Button).disabled)
	_assert_true("me_leave_en", (screen.call("get_leave_button") as Button).disabled == false)
	_assert_true("me_back_en", (screen.call("get_back_button") as Button).disabled == false)
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	_assert_eq("me_reconf_pc", (screen.call("get_party_cards_for_tests") as Array).size(), 0)
	_assert_eq("me_reconf_ec", (screen.call("get_enemy_cards_for_tests") as Array).size(), 0)

	_clear_overrides()
	_assert_true("me_retry_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	screen.call("configure_screen", &"battle")
	for _j in 3:
		await _tree.process_frame
	_assert_true("me_ok_runtime", bool(screen.call("is_runtime_ok")))
	_assert_true("me_ok_err_off", bool(screen.call("is_error_state_visible")) == false)
	_assert_eq("me_ok_pc", (screen.call("get_party_cards_for_tests") as Array).size(), 1)
	_assert_eq("me_ok_ec", (screen.call("get_enemy_cards_for_tests") as Array).size(), 1)
	var cell0: Button = screen.call("get_cell_button", 0, 0) as Button
	_assert_true("me_ok_cell_en", cell0 != null and cell0.disabled == false)
	screen.queue_free()
	await _tree.process_frame
	_cleanup_fixtures()
	_clear_overrides()
	_reset_domain()
	print("[INFO] missing encounter screen fail-closed passed")


func _run_max_content_cards_and_subviewport() -> void:
	_seed_party3_session(&"dev_stage_mist_03")
	_assert_true("mc_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	_assert_eq("mc_players", BattleRuntime.get_player_combatants().size(), 3)
	_assert_eq("mc_enemies", BattleRuntime.get_enemy_combatants().size(), 3)
	_assert_eq("mc_e0", str(BattleRuntime.get_enemy_combatants()[0].get_source_id()), "training_sprout")
	_assert_eq("mc_e1", str(BattleRuntime.get_enemy_combatants()[1].get_source_id()), "training_droplet")
	_assert_eq("mc_e2", str(BattleRuntime.get_enemy_combatants()[2].get_source_id()), "training_emberling")

	var packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.call("configure_screen", &"battle")
	for _i in 4:
		await _tree.process_frame

	var pcards: Array = screen.call("get_party_cards_for_tests") as Array
	var ecards: Array = screen.call("get_enemy_cards_for_tests") as Array
	_assert_eq("mc_pc", pcards.size(), 3)
	_assert_eq("mc_ec", ecards.size(), 3)
	var players: Array[BattleCombatantModel] = BattleRuntime.get_player_combatants()
	for i in 3:
		var card: Control = pcards[i] as Control
		var mark: String = "（領隊）" if i == 0 else ""
		var title_exp: String = "%s%s" % [players[i].get_display_name(), mark]
		_assert_eq("mc_ptitle_%d" % i, str(screen.call("get_card_title_for_tests", card)), title_exp)
		var aff_expect: String = "%s %s" % [
			BattleAffinity.symbol(players[i].get_affinity()),
			BattleAffinity.display_name(players[i].get_affinity()),
		]
		_assert_eq("mc_paff_%d" % i, str(screen.call("get_card_affinity_for_tests", card)), aff_expect)
		_assert_eq(
			"mc_php_%d" % i,
			str(screen.call("get_card_hp_label_for_tests", card)),
			"HP %d/%d" % [players[i].get_current_hp(), players[i].get_max_hp()]
		)
		_assert_eq(
			"mc_pstats_%d" % i,
			str(screen.call("get_card_stats_for_tests", card)),
			"ATK %d · DEF %d" % [players[i].get_attack(), players[i].get_defense()]
		)
		var bar: ProgressBar = screen.call("get_card_progress_bar_for_tests", card) as ProgressBar
		_assert_true("mc_pbar_%d" % i, bar != null)
		_assert_eq("mc_pbar_min_%d" % i, int(bar.min_value), 0)
		_assert_eq("mc_pbar_max_%d" % i, int(bar.max_value), players[i].get_max_hp())
		_assert_eq("mc_pbar_val_%d" % i, int(bar.value), players[i].get_current_hp())
		_assert_eq("mc_pbar_focus_%d" % i, bar.focus_mode, Control.FOCUS_NONE)
		_assert_eq("mc_pbar_mouse_%d" % i, bar.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		_assert_eq("mc_card_focus_%d" % i, card.focus_mode, Control.FOCUS_NONE)
		_assert_eq("mc_card_mouse_%d" % i, card.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		await _tree.process_frame
		_assert_true("mc_pbar_h_%d" % i, bar.size.y >= 16.0)

	var enemies: Array[BattleCombatantModel] = BattleRuntime.get_enemy_combatants()
	var aei: int = BattleRuntime.get_active_enemy_index()
	for i in 3:
		var card: Control = ecards[i] as Control
		var vis: String = str(
			(EnemyCatalog.find_enemy(enemies[i].get_source_id()).get("enemy", {}) as Dictionary).get("visual_symbol", "")
		)
		var amark: String = "（作用中）" if i == aei else ""
		var etitle_exp: String = "%s %s%s" % [vis, enemies[i].get_display_name(), amark]
		_assert_eq("mc_etitle_%d" % i, str(screen.call("get_card_title_for_tests", card)), etitle_exp)
		var eaff: String = "%s %s" % [
			BattleAffinity.symbol(enemies[i].get_affinity()),
			BattleAffinity.display_name(enemies[i].get_affinity()),
		]
		_assert_eq("mc_eaff_%d" % i, str(screen.call("get_card_affinity_for_tests", card)), eaff)
		_assert_eq(
			"mc_ehp_%d" % i,
			str(screen.call("get_card_hp_label_for_tests", card)),
			"HP %d/%d" % [enemies[i].get_current_hp(), enemies[i].get_max_hp()]
		)
		var ebar: ProgressBar = screen.call("get_card_progress_bar_for_tests", card) as ProgressBar
		_assert_true("mc_ebar_%d" % i, ebar != null)
		_assert_eq("mc_ebar_min_%d" % i, int(ebar.min_value), 0)
		_assert_eq("mc_ebar_max_%d" % i, int(ebar.max_value), enemies[i].get_max_hp())
		_assert_eq("mc_ebar_val_%d" % i, int(ebar.value), enemies[i].get_current_hp())
		_assert_eq("mc_ebar_focus_%d" % i, ebar.focus_mode, Control.FOCUS_NONE)
		_assert_eq("mc_ebar_mouse_%d" % i, ebar.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		_assert_eq("mc_ecard_focus_%d" % i, card.focus_mode, Control.FOCUS_NONE)
		_assert_eq("mc_ecard_mouse_%d" % i, card.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		await _tree.process_frame
		_assert_true("mc_ebar_h_%d" % i, ebar.size.y >= 16.0)

	# Summary labels hidden
	var pl: Label = screen.get_node_or_null("%PartyListLabel") as Label
	var el: Label = screen.get_node_or_null("%EnemyListLabel") as Label
	_assert_true("mc_plist_hidden", pl != null and pl.visible == false)
	_assert_true("mc_elist_hidden", el != null and el.visible == false)
	_assert_true("mc_cache_party", str(screen.call("get_party_list_text")).find("HP") >= 0)

	var rt_n0: int = _signal_connection_count(BattleRuntime.runtime_changed)
	var bd_n0: int = _signal_connection_count(BattleRuntime.board_changed)
	var en_n0: int = _signal_connection_count(BattleRuntime.encounter_changed)
	var st_n0: int = _signal_connection_count(BattleState.session_changed)
	var cells0: int = BattleRuntime.get_board_cells().size()
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	_assert_eq("mc_cfg_pc", (screen.call("get_party_cards_for_tests") as Array).size(), 3)
	_assert_eq("mc_cfg_ec", (screen.call("get_enemy_cards_for_tests") as Array).size(), 3)
	_assert_eq("mc_cfg_cells", BattleRuntime.get_board_cells().size(), cells0)
	_assert_eq("mc_cfg_rt_conn", _signal_connection_count(BattleRuntime.runtime_changed), rt_n0)
	_assert_eq("mc_cfg_bd_conn", _signal_connection_count(BattleRuntime.board_changed), bd_n0)
	_assert_eq("mc_cfg_en_conn", _signal_connection_count(BattleRuntime.encounter_changed), en_n0)
	_assert_eq("mc_cfg_st_conn", _signal_connection_count(BattleState.session_changed), st_n0)

	# SubViewport matrix
	await _run_subviewport_case(360, 640, true)
	await _run_subviewport_case(390, 844, false)
	await _run_subviewport_case(720, 1280, false)

	screen.queue_free()
	await _tree.process_frame
	print("[INFO] max content cards + subviewport passed")


func _run_subviewport_case(w: int, h: int, require_scroll: bool) -> void:
	var tag := "%dx%d" % [w, h]
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_tree.root.add_child(vp)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.size = Vector2(w, h)
	vp.add_child(host)
	var packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	host.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.size = Vector2(w, h)
	screen.call("configure_screen", &"battle")
	for _i in 6:
		await _tree.process_frame

	var host_origin: Vector2 = host.get_global_rect().position
	var vp_rect := Rect2(Vector2.ZERO, Vector2(w, h))
	var grid: GridContainer = screen.call("get_board_grid") as GridContainer
	var scroll: ScrollContainer = screen.call("get_body_scroll") as ScrollContainer
	var back: Button = screen.call("get_back_button") as Button
	var leave: Button = screen.call("get_leave_button") as Button
	var pcards: Array = screen.call("get_party_cards_for_tests") as Array
	var ecards: Array = screen.call("get_enemy_cards_for_tests") as Array
	_assert_true("%s_grid" % tag, grid != null)
	_assert_true("%s_scroll" % tag, scroll != null)
	_assert_eq("%s_cells" % tag, grid.get_child_count(), 30)
	_assert_eq("%s_pc" % tag, pcards.size(), 3)
	_assert_eq("%s_ec" % tag, ecards.size(), 3)

	# Exactly one vertical ScrollContainer under screen.
	var scrolls: Array = []
	_collect_scrolls(screen, scrolls)
	_assert_eq("%s_vscroll_count" % tag, scrolls.size(), 1)

	var range_h: float = 0.0
	if scroll.get_h_scroll_bar() != null:
		var hb: ScrollBar = scroll.get_h_scroll_bar()
		range_h = maxf(0.0, float(hb.max_value) - float(hb.page))
	_assert_true("%s_hscroll_range" % tag, range_h <= 0.5)

	var range_v: float = 0.0
	var content_h: float = 0.0
	var page_h: float = float(h)
	if scroll.get_v_scroll_bar() != null:
		var vb: ScrollBar = scroll.get_v_scroll_bar()
		range_v = maxf(0.0, float(vb.max_value) - float(vb.page))
		page_h = float(vb.page)
	if scroll.get_child_count() > 0:
		content_h = (scroll.get_child(0) as Control).size.y
	print("[INFO] subvp_%s range=%.1f content_h=%.1f page_h=%.1f" % [tag, range_v, content_h, page_h])

	if require_scroll:
		_assert_true("%s_range" % tag, range_v > 0.5)
	elif w == 390:
		if content_h > page_h + 0.5:
			_assert_true("%s_range_scroll" % tag, range_v > 0.5)
		else:
			_assert_true("%s_range_fit" % tag, range_v <= 0.5)
	elif w == 720:
		_assert_true("%s_range_fit720" % tag, range_v <= 0.5)

	var scroll_vis: Rect2 = scroll.get_global_rect()
	scroll_vis.position -= host_origin

	# Board + cards + cells horizontal containment in viewport.
	var grid_local := Rect2(grid.get_global_rect().position - host_origin, grid.get_global_rect().size)
	_assert_true("%s_grid_h" % tag, grid_local.position.x >= vp_rect.position.x - 2.0 and grid_local.end.x <= vp_rect.end.x + 2.0)

	for i in 30:
		var cell: Control = grid.get_child(i) as Control
		_assert_true("%s_cw_%d" % [tag, i], cell.size.x >= 48.0)
		_assert_true("%s_ch_%d" % [tag, i], cell.size.y >= 48.0)
		var cr := Rect2(cell.get_global_rect().position - host_origin, cell.get_global_rect().size)
		_assert_true("%s_cell_hcont_%d" % [tag, i], cr.position.x >= vp_rect.position.x - 2.0 and cr.end.x <= vp_rect.end.x + 2.0)

	for card in pcards:
		var bar: ProgressBar = screen.call("get_card_progress_bar_for_tests", card) as ProgressBar
		_assert_true("%s_pbar" % tag, bar != null)
		await _tree.process_frame
		_assert_true("%s_pbar_h" % tag, bar.size.y >= 16.0)
		var card_r := Rect2((card as Control).get_global_rect().position - host_origin, (card as Control).get_global_rect().size)
		_assert_true("%s_pcard_hcont" % tag, card_r.position.x >= vp_rect.position.x - 2.0 and card_r.end.x <= vp_rect.end.x + 2.0)
		for n in ["TitleLabel", "AffinityLabel", "HpLabel", "StatsLabel"]:
			var lab: Node = (card as Control).find_child(n, true, false)
			if lab is Control and (lab as Control).visible:
				var lr := Rect2((lab as Control).get_global_rect().position - host_origin, (lab as Control).get_global_rect().size)
				_assert_true("%s_ptext_hcont" % tag, lr.position.x >= vp_rect.position.x - 2.0 and lr.end.x <= vp_rect.end.x + 2.0)
	for card in ecards:
		var bar2: ProgressBar = screen.call("get_card_progress_bar_for_tests", card) as ProgressBar
		_assert_true("%s_ebar" % tag, bar2 != null)
		await _tree.process_frame
		_assert_true("%s_ebar_h" % tag, bar2.size.y >= 16.0)
		var card_r2 := Rect2((card as Control).get_global_rect().position - host_origin, (card as Control).get_global_rect().size)
		_assert_true("%s_ecard_hcont" % tag, card_r2.position.x >= vp_rect.position.x - 2.0 and card_r2.end.x <= vp_rect.end.x + 2.0)

	_assert_true("%s_back_h" % tag, back.size.y >= 48.0)
	_assert_true("%s_leave_h" % tag, leave.size.y >= 48.0)
	var leave_r := Rect2(leave.get_global_rect().position - host_origin, leave.get_global_rect().size)
	var back_r := Rect2(back.get_global_rect().position - host_origin, back.get_global_rect().size)
	_assert_true("%s_leave_vp" % tag, _rect_fully_within(leave_r, vp_rect, 2.0))
	_assert_true("%s_back_vp" % tag, _rect_fully_within(back_r, vp_rect, 2.0))

	var scroll_targets: Array = [ecards[0], ecards[2], pcards[0], pcards[2], grid.get_child(0), grid.get_child(29)]
	if w == 720:
		# Initial complete fit — do not call ensure_control_visible first.
		for t in scroll_targets:
			var ctrl: Control = t as Control
			var gr: Rect2 = ctrl.get_global_rect()
			var local := Rect2(gr.position - host_origin, gr.size)
			_assert_true("%s_init_fit" % tag, _rect_fully_within(local, scroll_vis, 2.0))
	else:
		for t in scroll_targets:
			var ctrl2: Control = t as Control
			screen.call("ensure_control_visible_for_test", ctrl2)
			for _j in 3:
				await _tree.process_frame
			var gr2: Rect2 = ctrl2.get_global_rect()
			var local2 := Rect2(gr2.position - host_origin, gr2.size)
			var scroll_vis2: Rect2 = scroll.get_global_rect()
			scroll_vis2.position -= host_origin
			_assert_true("%s_scroll_reach" % tag, _rect_fully_within(local2, scroll_vis2, 2.0))

	for card in pcards:
		_assert_eq("%s_pcard_focusmode" % tag, (card as Control).focus_mode, Control.FOCUS_NONE)
	for card in ecards:
		_assert_eq("%s_ecard_focusmode" % tag, (card as Control).focus_mode, Control.FOCUS_NONE)

	if w == 360:
		await _run_keyboard_max_content(vp, screen, pcards, ecards)

	vp.queue_free()
	await _tree.process_frame


func _collect_scrolls(n: Node, out: Array) -> void:
	if n is ScrollContainer:
		out.append(n)
	for c in n.get_children():
		_collect_scrolls(c, out)


func _send_ui_action(sv: SubViewport, action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	sv.push_input(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	sv.push_input(release)


func _send_key(sv: SubViewport, keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	sv.push_input(press)
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	sv.push_input(release)


func _run_keyboard_max_content(sv: SubViewport, screen: Control, pcards: Array, ecards: Array) -> void:
	var c00: Button = screen.call("get_cell_button", 0, 0) as Button
	var c10: Button = screen.call("get_cell_button", 1, 0) as Button
	var c01: Button = screen.call("get_cell_button", 0, 1) as Button
	var c11: Button = screen.call("get_cell_button", 1, 1) as Button
	var back: Button = screen.call("get_back_button") as Button
	var leave: Button = screen.call("get_leave_button") as Button
	_assert_true("kb_cells", c00 != null and c10 != null and c01 != null and c11 != null)

	var press_n: Array = [0]
	var on_press := func() -> void:
		press_n[0] = int(press_n[0]) + 1
	c00.pressed.connect(on_press)
	c11.pressed.connect(on_press)

	c00.grab_focus()
	await _tree.process_frame
	_assert_true("kb_focus0", sv.gui_get_focus_owner() == c00)
	_send_ui_action(sv, "ui_right")
	await _tree.process_frame
	_assert_true("kb_right", sv.gui_get_focus_owner() == c10)
	_send_ui_action(sv, "ui_down")
	await _tree.process_frame
	_assert_true("kb_down", sv.gui_get_focus_owner() == c11)
	_send_ui_action(sv, "ui_left")
	await _tree.process_frame
	_assert_true("kb_left", sv.gui_get_focus_owner() == c01)
	_send_ui_action(sv, "ui_up")
	await _tree.process_frame
	_assert_true("kb_up", sv.gui_get_focus_owner() == c00)

	# Clear any residual selection before enter evidence.
	while BattleRuntime.has_selection():
		BattleRuntime.select_cell(BattleRuntime.get_selected_cell().x, BattleRuntime.get_selected_cell().y)
	c00.grab_focus()
	await _tree.process_frame
	var base_press: int = int(press_n[0])
	_send_key(sv, KEY_ENTER)
	await _tree.process_frame
	_assert_eq("kb_enter_cb", int(press_n[0]), base_press + 1)
	_assert_true("kb_enter_sel", BattleRuntime.has_selection())
	_assert_eq("kb_enter_xy", BattleRuntime.get_selected_cell(), Vector2i(0, 0))

	_send_key(sv, KEY_ENTER)
	await _tree.process_frame
	_assert_eq("kb_enter2_cb", int(press_n[0]), base_press + 2)
	_assert_true("kb_enter2_clear", BattleRuntime.has_selection() == false)

	c11.grab_focus()
	await _tree.process_frame
	var base2: int = int(press_n[0])
	_send_key(sv, KEY_SPACE)
	await _tree.process_frame
	_assert_eq("kb_space_cb", int(press_n[0]), base2 + 1)
	_assert_true("kb_space_sel", BattleRuntime.has_selection())
	_assert_eq("kb_space_xy", BattleRuntime.get_selected_cell(), Vector2i(1, 1))

	c00.grab_focus()
	await _tree.process_frame
	_send_ui_action(sv, "ui_up")
	await _tree.process_frame
	_assert_true("kb_escape_back", sv.gui_get_focus_owner() == back)
	var c54: Button = screen.call("get_cell_button", 5, 4) as Button
	c54.grab_focus()
	await _tree.process_frame
	_send_ui_action(sv, "ui_down")
	await _tree.process_frame
	_assert_true("kb_escape_leave", sv.gui_get_focus_owner() == leave)
	_assert_true("kb_no_trap", leave.has_focus() and leave.visible and not leave.disabled)
	for card in pcards:
		_assert_true("kb_pcard_never_owner", sv.gui_get_focus_owner() != card)
	for card in ecards:
		_assert_true("kb_ecard_never_owner", sv.gui_get_focus_owner() != card)
	var sb: StyleBox = c00.get_theme_stylebox("focus")
	_assert_true("kb_focus_style", sb != null)
	if c00.pressed.is_connected(on_press):
		c00.pressed.disconnect(on_press)
	if c11.pressed.is_connected(on_press):
		c11.pressed.disconnect(on_press)

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
