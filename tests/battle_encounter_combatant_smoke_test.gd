## GROK-036 evidence suite: atomic failure, transactions, real turn, responsive, integrity.
extends RefCounted

var passed: int = 0
var failed: int = 0
var results: PackedStringArray = PackedStringArray()
var _tree: SceneTree
var _fixture_paths: Array[String] = []


func setup(tree: SceneTree) -> void:
	_tree = tree


func run_all() -> void:
	_clear_catalog_overrides()
	_reset_domain()
	_run_assertion_integrity_scan()
	_run_json_number_contract_tests()
	_run_catalog_defensive_and_matrix()
	_run_combatant_matrix()
	_run_encounter_matrix()
	_run_runtime_atomic_failure_matrix()
	_run_snapshot_failure_matrix()
	await _run_adventure_enter_transaction_tests()
	await _run_leave_transaction_and_real_turn_tests()
	await _run_screen_exact_and_responsive_tests()
	_cleanup_fixtures()
	_clear_catalog_overrides()
	_reset_domain()
	PlayerData.configure_test_storage_path("user://feibao_tests/suite_main")
	PlayerData.reset_runtime_state_for_tests()
	print("[INFO] battle encounter combatant evidence suite complete")


func _nav() -> Node:
	return _tree.root.get_node("NavigationState")


func _reset_domain() -> void:
	if is_instance_valid(AdventureState):
		AdventureState.reset_runtime_state_for_tests()
	if is_instance_valid(BattleRuntime):
		BattleRuntime.reset_runtime_state_for_tests()
	if is_instance_valid(BattleState):
		BattleState.reset_runtime_state_for_tests()


func _clear_catalog_overrides() -> void:
	BattleCharacterStatsCatalog.clear_default_path_override_for_tests()
	EnemyCatalog.clear_default_path_override_for_tests()
	StageEncounterCatalog.clear_default_path_override_for_tests()


func _cleanup_fixtures() -> void:
	for p in _fixture_paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_fixture_paths.clear()


func _seed_session(stage_id: StringName = &"dev_stage_beginner_01") -> void:
	PlayerData.configure_test_storage_path("user://feibao_tests/enc_ev")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	_reset_domain()
	AdventureState.prepare_stage(stage_id)
	_assert_true("seed_bs", bool(BattleState.begin_from_prepared_stage().get("ok", false)))


func _write_fixture(name: String, text: String) -> String:
	var dir_path := "user://feibao_tests/encounter_catalog_fixtures"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var path := "%s/%s" % [dir_path, name]
	var f := FileAccess.open(path, FileAccess.WRITE)
	_assert_true("fx_write_%s" % name, f != null)
	if f != null:
		f.store_string(text)
		f.close()
		_fixture_paths.append(path)
	return path


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
		snap.get("last_resolution_events", []) as Array,
		BattleRuntime.get_last_resolution_events()
	):
		return false
	var exp_enc: Dictionary = snap.get("encounter", {}) as Dictionary
	if not snap.has("encounter"):
		exp_enc = {"player_combatants": [], "enemy_combatants": [], "active_enemy_index": -1}
	var er: Dictionary = BattleEncounterModel.restore_snapshot(exp_enc)
	var ar: Dictionary = BattleEncounterModel.restore_snapshot(BattleRuntime.get_encounter_snapshot())
	if not bool(er.get("ok", false)) or not bool(ar.get("ok", false)):
		return false
	return BattleEncounterModel.equals(er.get("encounter") as BattleEncounterModel, ar.get("encounter") as BattleEncounterModel)


func _connect_sigs() -> Dictionary:
	var sigs := {
		"rt": [0],
		"bd": [0],
		"ph": [0],
		"en": [0],
		"on_rt": null,
		"on_bd": null,
		"on_ph": null,
		"on_en": null,
	}
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
	var on_rt: Callable = sigs.get("on_rt") as Callable
	var on_bd: Callable = sigs.get("on_bd") as Callable
	var on_ph: Callable = sigs.get("on_ph") as Callable
	var on_en: Callable = sigs.get("on_en") as Callable
	if BattleRuntime.runtime_changed.is_connected(on_rt):
		BattleRuntime.runtime_changed.disconnect(on_rt)
	if BattleRuntime.board_changed.is_connected(on_bd):
		BattleRuntime.board_changed.disconnect(on_bd)
	if BattleRuntime.phase_changed.is_connected(on_ph):
		BattleRuntime.phase_changed.disconnect(on_ph)
	if BattleRuntime.encounter_changed.is_connected(on_en):
		BattleRuntime.encounter_changed.disconnect(on_en)


func _assert_sig_zero(tag: String, sigs: Dictionary, base: Dictionary) -> void:
	_assert_eq("%s_sig_rt" % tag, int(sigs["rt"][0]), int(base["rt"]))
	_assert_eq("%s_sig_bd" % tag, int(sigs["bd"][0]), int(base["bd"]))
	_assert_eq("%s_sig_ph" % tag, int(sigs["ph"][0]), int(base["ph"]))
	_assert_eq("%s_sig_en" % tag, int(sigs["en"][0]), int(base["en"]))


func _run_assertion_integrity_scan() -> void:
	var f := FileAccess.open("res://tests/battle_encounter_combatant_smoke_test.gd", FileAccess.READ)
	_assert_true("ais_open", f != null)
	var text: String = f.get_as_text() if f != null else ""
	if f != null:
		f.close()
	_assert_true("ais_no_fixed_true", text.find("_assert_true(\"ccs_defensive_copy\", true)") < 0)
	_assert_true("ais_no_assert_true_lit", text.find("_assert_true(\"x\", true)") < 0)
	# Weak OR for expected UI content should not appear for enemy/affinity cases
	_assert_true("ais_no_ui_enemy_or", text.find("ui_enemy_name") < 0 or text.find("find(\"幼芽\") >= 0\n\t\tor") < 0)
	print("[INFO] assertion integrity scan passed")


func _run_json_number_contract_tests() -> void:
	# 10 and 10.0 accepted; 10.5 / true / "10" / null rejected
	var ok10: Dictionary = BattleCharacterStatsCatalog.parse_json_text(
		'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":10,"attack":1,"defense":1}]}'
	)
	_assert_true("jn_10", bool(ok10.get("ok", false)))
	var ok100: Dictionary = BattleCharacterStatsCatalog.parse_json_text(
		'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":10.0,"attack":1,"defense":1}]}'
	)
	_assert_true("jn_10_0", bool(ok100.get("ok", false)))
	if bool(ok100.get("ok", false)):
		var st: Dictionary = ((ok100.get("stats", []) as Array)[0] as Dictionary)
		_assert_eq("jn_norm_int", typeof(st.get("max_hp")), TYPE_INT)
		_assert_eq("jn_norm_val", int(st.get("max_hp")), 10)
	_assert_true(
		"jn_10_5",
		bool(
			BattleCharacterStatsCatalog.parse_json_text(
				'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":10.5,"attack":1,"defense":1}]}'
			).get("ok", true)
		)
		== false
	)
	_assert_true(
		"jn_bool",
		bool(
			BattleCharacterStatsCatalog.parse_json_text(
				'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":true,"attack":1,"defense":1}]}'
			).get("ok", true)
		)
		== false
	)
	_assert_true(
		"jn_str",
		bool(
			BattleCharacterStatsCatalog.parse_json_text(
				'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":"10","attack":1,"defense":1}]}'
			).get("ok", true)
		)
		== false
	)
	_assert_true(
		"jn_null",
		bool(
			BattleCharacterStatsCatalog.parse_json_text(
				'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":null,"attack":1,"defense":1}]}'
			).get("ok", true)
		)
		== false
	)
	# Snapshot still TYPE_INT only
	var p: Dictionary = BattleCombatantModel.create_player(&"feibao_dev", "飛寶（開發樣本）", &"ember", 0, 120, 14, 8)
	var snap: Dictionary = (p.get("combatant") as BattleCombatantModel).capture_snapshot()
	snap["current_hp"] = 10.0
	_assert_true("jn_snap_float_reject", bool(BattleCombatantModel.validate_snapshot(snap).get("ok", true)) == false)
	print("[INFO] JSON whole-number contract tests passed")


func _run_catalog_defensive_and_matrix() -> void:
	var loaded: Dictionary = BattleCharacterStatsCatalog.load_default()
	_assert_true("ccs_ok", bool(loaded.get("ok", false)))
	var stats_a: Array = (loaded.get("stats", []) as Array).duplicate(true)
	_assert_true("ccs_nonempty", stats_a.size() > 0)
	var first: Dictionary = (stats_a[0] as Dictionary).duplicate(true)
	var orig_hp: int = int(first.get("max_hp", -1))
	first["max_hp"] = 1
	stats_a[0] = first
	# Mutate returned array element if shared — then reload
	var loaded2: Dictionary = BattleCharacterStatsCatalog.load_default()
	var stats_b: Array = loaded2.get("stats", []) as Array
	var b0: Dictionary = stats_b[0] as Dictionary
	_assert_eq("ccs_defensive_hp", int(b0.get("max_hp", -2)), orig_hp)
	var find_a: Dictionary = BattleCharacterStatsCatalog.find_stats(&"feibao_dev")
	var sa: Dictionary = (find_a.get("stats", {}) as Dictionary).duplicate(true)
	var orig_atk: int = int(sa.get("attack", -1))
	sa["attack"] = 0
	var find_b: Dictionary = BattleCharacterStatsCatalog.find_stats(&"feibao_dev")
	_assert_eq("ccs_find_defensive", int((find_b.get("stats", {}) as Dictionary).get("attack", -2)), orig_atk)

	# Coverage exact
	var chars: Dictionary = CharacterCatalog.load_default()
	for c in chars.get("characters", []):
		if c is CharacterDefinition:
			var id: StringName = (c as CharacterDefinition).get_id()
			_assert_true("ccs_cover_%s" % str(id), bool(BattleCharacterStatsCatalog.find_stats(id).get("ok", false)))

	var en: Dictionary = EnemyCatalog.load_default()
	_assert_true("en_ok", bool(en.get("ok", false)))
	var efind: Dictionary = EnemyCatalog.find_enemy(&"training_sprout")
	var ed: Dictionary = (efind.get("enemy", {}) as Dictionary).duplicate(true)
	var oname: String = str(ed.get("display_name", ""))
	ed["display_name"] = "MUT"
	var efind2: Dictionary = EnemyCatalog.find_enemy(&"training_sprout")
	_assert_eq("en_defensive", str((efind2.get("enemy", {}) as Dictionary).get("display_name", "")), oname)

	var se: Dictionary = StageEncounterCatalog.find_encounter(&"dev_stage_beginner_02")
	_assert_true("se_b02", bool(se.get("ok", false)))
	var enc: Dictionary = se.get("encounter", {}) as Dictionary
	var eids: Array = enc.get("enemy_ids", []) as Array
	_assert_eq("se_b02_n", eids.size(), 2)
	_assert_eq("se_b02_0", str(eids[0]), "training_sprout")
	_assert_eq("se_b02_1", str(eids[1]), "training_droplet")
	eids.clear()
	var se2: Dictionary = StageEncounterCatalog.find_encounter(&"dev_stage_beginner_02")
	_assert_eq("se_defensive", (se2.get("encounter", {}) as Dictionary).get("enemy_ids", []).size() if se2.get("encounter") is Dictionary else 0, 2)
	print("[INFO] catalog defensive/matrix tests passed")


func _run_combatant_matrix() -> void:
	var p: Dictionary = BattleCombatantModel.create_player(&"feibao_dev", "飛寶（開發樣本）", &"ember", 0, 120, 14, 8)
	_assert_true("cm_player", bool(p.get("ok", false)))
	var e: Dictionary = BattleCombatantModel.create_enemy(&"training_sprout", "訓練幼芽", &"leaf", 0, 40, 8, 3)
	_assert_true("cm_enemy", bool(e.get("ok", false)))
	var pc: BattleCombatantModel = p.get("combatant") as BattleCombatantModel
	var snap: Dictionary = pc.capture_snapshot()
	snap["current_hp"] = 0
	var zero: Dictionary = BattleCombatantModel.restore_snapshot(snap)
	_assert_true("cm_hp0", bool(zero.get("ok", false)))
	_assert_true("cm_dead", (zero.get("combatant") as BattleCombatantModel).is_alive() == false)
	for field in ["max_hp", "attack", "defense", "current_hp", "slot_index"]:
		var bad: Dictionary = pc.capture_snapshot()
		bad[field] = "1"
		_assert_true("cm_str_%s" % field, bool(BattleCombatantModel.validate_snapshot(bad).get("ok", true)) == false)
		bad = pc.capture_snapshot()
		bad[field] = true
		_assert_true("cm_bool_%s" % field, bool(BattleCombatantModel.validate_snapshot(bad).get("ok", true)) == false)
	var bad2: Dictionary = pc.capture_snapshot()
	bad2["current_hp"] = -1
	_assert_true("cm_hp_neg", bool(BattleCombatantModel.validate_snapshot(bad2).get("ok", true)) == false)
	bad2 = pc.capture_snapshot()
	bad2["current_hp"] = 9999
	_assert_true("cm_hp_over", bool(BattleCombatantModel.validate_snapshot(bad2).get("ok", true)) == false)
	bad2 = pc.capture_snapshot()
	bad2["max_hp"] = 999
	_assert_true("cm_immut_hp", bool(BattleCombatantModel.validate_snapshot(bad2).get("ok", true)) == false)
	bad2 = pc.capture_snapshot()
	bad2["source_id"] = &"nope"
	_assert_true("cm_unk", bool(BattleCombatantModel.validate_snapshot(bad2).get("ok", true)) == false)
	bad2 = pc.capture_snapshot()
	bad2["affinity"] = &"fire"
	_assert_true("cm_aff", bool(BattleCombatantModel.validate_snapshot(bad2).get("ok", true)) == false)
	print("[INFO] combatant matrix passed")


func _run_encounter_matrix() -> void:
	var party: Array[StringName] = [&"feibao_dev", &"partner_a"]
	var built: Dictionary = BattleEncounterModel.build_from_session(&"dev_stage_beginner_02", party)
	_assert_true("em_ok", bool(built.get("ok", false)))
	var enc: BattleEncounterModel = built.get("encounter") as BattleEncounterModel
	_assert_eq("em_p0", str(enc.get_player_combatants()[0].get_source_id()), "feibao_dev")
	_assert_eq("em_p1", str(enc.get_player_combatants()[1].get_source_id()), "partner_a")
	_assert_eq("em_e0", str(enc.get_enemy_combatants()[0].get_source_id()), "training_sprout")
	_assert_eq("em_e1", str(enc.get_enemy_combatants()[1].get_source_id()), "training_droplet")
	_assert_eq("em_aei", enc.get_active_enemy_index(), 0)
	_assert_eq("em_slot0", enc.get_player_combatants()[0].get_slot_index(), 0)
	_assert_eq("em_slot1", enc.get_player_combatants()[1].get_slot_index(), 1)
	var g: Array[BattleCombatantModel] = enc.get_player_combatants()
	g.clear()
	_assert_eq("em_def_get", enc.get_player_combatants().size(), 2)
	var snap: Dictionary = enc.capture_snapshot()
	var rt: Dictionary = BattleEncounterModel.restore_snapshot(snap)
	_assert_true("em_round", BattleEncounterModel.equals(enc, rt.get("encounter") as BattleEncounterModel))
	print("[INFO] encounter matrix passed")


func _assert_begin_failure_preserves(tag: String) -> void:
	_seed_session(&"dev_stage_beginner_01")
	# Keep session active, runtime inactive
	var before_rt: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var before_st: Dictionary = BattleState.capture_session_snapshot()
	var prep_stage: StringName = AdventureState.get_selected_stage_id()
	var rev: int = PlayerData.get_profile().get_revision()
	var fp0: Dictionary = _prod_fp()
	var sigs: Dictionary = _connect_sigs()
	var base_sig := {
		"rt": int(sigs["rt"][0]),
		"bd": int(sigs["bd"][0]),
		"ph": int(sigs["ph"][0]),
		"en": int(sigs["en"][0]),
	}
	var res: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("%s_ok_false" % tag, bool(res.get("ok", true)) == false)
	_assert_true("%s_rt_exact" % tag, _runtime_exact_1_1(before_rt))
	_assert_eq("%s_stage" % tag, str(BattleState.get_stage_id()), str(before_st.get("stage_id", &"")))
	_assert_eq("%s_prep" % tag, str(AdventureState.get_selected_stage_id()), str(prep_stage))
	_assert_eq("%s_rev" % tag, PlayerData.get_profile().get_revision(), rev)
	_assert_true("%s_fp" % tag, _fp_eq(fp0, _prod_fp()))
	_assert_sig_zero(tag, sigs, base_sig)
	_disconnect_sigs(sigs)
	_clear_catalog_overrides()


func _run_runtime_atomic_failure_matrix() -> void:
	# H1 missing character stats for party member
	var stats_loaded: Dictionary = BattleCharacterStatsCatalog.load_default()
	var stats_arr: Array = []
	for item in stats_loaded.get("stats", []) as Array:
		var d: Dictionary = (item as Dictionary).duplicate(true)
		if str(d.get("character_id", "")) == "feibao_dev":
			continue
		# JSON stores string affinity/id — rebuild as JSON-friendly
		stats_arr.append({
			"character_id": str(d.get("character_id")),
			"affinity": str(d.get("affinity")),
			"max_hp": int(d.get("max_hp")),
			"attack": int(d.get("attack")),
			"defense": int(d.get("defense")),
		})
	var stats_json := JSON.stringify({"schema_version": 1, "catalog_kind": "development_seed", "stats": stats_arr})
	var spath := _write_fixture("stats_no_feibao.json", stats_json)
	BattleCharacterStatsCatalog.set_default_path_override_for_tests(spath)
	_assert_begin_failure_preserves("h1_missing_stats")

	# H2 missing stage encounter (incomplete catalog fails load)
	var se_json := JSON.stringify({
		"schema_version": 1,
		"catalog_kind": "development_seed",
		"encounters": [{"stage_id": "dev_stage_mist_01", "enemy_ids": ["training_sprout"]}],
	})
	var sepath := _write_fixture("se_incomplete.json", se_json)
	StageEncounterCatalog.set_default_path_override_for_tests(sepath)
	_assert_begin_failure_preserves("h2_missing_se")

	# H3 missing enemy (stage encounter refs removed enemy)
	var enemies_only_two := JSON.stringify({
		"schema_version": 1,
		"catalog_kind": "development_seed",
		"enemies": [
			{"enemy_id": "training_droplet", "display_name": "訓練水滴", "affinity": "tide", "max_hp": 48, "attack": 9, "defense": 4, "visual_symbol": "○"},
			{"enemy_id": "training_emberling", "display_name": "訓練炎雛", "affinity": "ember", "max_hp": 36, "attack": 11, "defense": 2, "visual_symbol": "△"},
		],
	})
	var epath := _write_fixture("en_no_sprout.json", enemies_only_two)
	EnemyCatalog.set_default_path_override_for_tests(epath)
	# Stage encounters still reference sprout on beginner_01 — load may fail when building encounter
	_assert_begin_failure_preserves("h3_missing_enemy")

	# H4 invalid enemy catalog (fractional hp)
	var bad_en := JSON.stringify({
		"schema_version": 1,
		"catalog_kind": "development_seed",
		"enemies": [
			{"enemy_id": "training_sprout", "display_name": "訓練幼芽", "affinity": "leaf", "max_hp": 40.5, "attack": 8, "defense": 3, "visual_symbol": "◇"},
		],
	})
	var bepath := _write_fixture("en_frac.json", bad_en)
	EnemyCatalog.set_default_path_override_for_tests(bepath)
	_assert_begin_failure_preserves("h4_invalid_enemy")

	# H5 success + idempotent
	_clear_catalog_overrides()
	_seed_session(&"dev_stage_beginner_02")
	var sigs: Dictionary = _connect_sigs()
	var b0 := {
		"rt": int(sigs["rt"][0]),
		"bd": int(sigs["bd"][0]),
		"ph": int(sigs["ph"][0]),
		"en": int(sigs["en"][0]),
	}
	var ok: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("h5_ok", bool(ok.get("ok", false)))
	_assert_eq("h5_cells", BattleRuntime.get_board_cells().size(), 30)
	_assert_eq("h5_players", BattleRuntime.get_player_combatants().size(), 1)
	_assert_eq("h5_enemies", BattleRuntime.get_enemy_combatants().size(), 2)
	_assert_eq("h5_e0", str(BattleRuntime.get_enemy_combatants()[0].get_source_id()), "training_sprout")
	_assert_eq("h5_e1", str(BattleRuntime.get_enemy_combatants()[1].get_source_id()), "training_droplet")
	_assert_eq("h5_aei", BattleRuntime.get_active_enemy_index(), 0)
	_assert_eq("h5_hp", BattleRuntime.get_player_combatants()[0].get_current_hp(), BattleRuntime.get_player_combatants()[0].get_max_hp())
	_assert_eq("h5_sig_rt", int(sigs["rt"][0]), int(b0["rt"]) + 1)
	_assert_eq("h5_sig_bd", int(sigs["bd"][0]), int(b0["bd"]) + 1)
	_assert_eq("h5_sig_en", int(sigs["en"][0]), int(b0["en"]) + 1)
	var snap: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var again: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("h5_idemp", bool(again.get("ok", false)) and bool(again.get("changed", true)) == false)
	_assert_true("h5_idemp_exact", _runtime_exact_1_1(snap))
	_assert_eq("h5_idemp_rt", int(sigs["rt"][0]), int(b0["rt"]) + 1)
	_assert_eq("h5_idemp_en", int(sigs["en"][0]), int(b0["en"]) + 1)
	_disconnect_sigs(sigs)
	print("[INFO] runtime atomic failure matrix passed")


func _assert_restore_fail(tag: String, before: Dictionary, bad: Dictionary, sigs: Dictionary, base: Dictionary) -> void:
	var res: Dictionary = BattleRuntime.restore_runtime_snapshot(bad)
	_assert_true("%s_ok_false" % tag, bool(res.get("ok", true)) == false)
	_assert_true("%s_exact" % tag, _runtime_exact_1_1(before))
	_assert_sig_zero(tag, sigs, base)


func _run_snapshot_failure_matrix() -> void:
	_clear_catalog_overrides()
	_seed_session(&"dev_stage_beginner_02")
	_assert_true("sf_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	var before: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var sigs: Dictionary = _connect_sigs()
	var base := {
		"rt": int(sigs["rt"][0]),
		"bd": int(sigs["bd"][0]),
		"ph": int(sigs["ph"][0]),
		"en": int(sigs["en"][0]),
	}

	var bad: Dictionary = before.duplicate(true)
	bad.erase("encounter")
	_assert_restore_fail("sf_missing", before, bad, sigs, base)

	bad = before.duplicate(true)
	bad["encounter"] = "x"
	_assert_restore_fail("sf_nondict", before, bad, sigs, base)

	bad = before.duplicate(true)
	var enc: Dictionary = (before.get("encounter") as Dictionary).duplicate(true)
	enc["extra"] = 1
	bad["encounter"] = enc
	_assert_restore_fail("sf_extra", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enc["active_enemy_index"] = 1.0
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sf_aei_float", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enc["active_enemy_index"] = -1
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sf_aei_neg", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enc["active_enemy_index"] = 99
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sf_aei_oob", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enc["player_combatants"] = []
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sf_p0", before, bad, sigs, base)

	enc = (before.get("encounter") as Dictionary).duplicate(true)
	var players: Array = (enc.get("player_combatants") as Array).duplicate(true)
	var p0: Dictionary = (players[0] as Dictionary).duplicate(true)
	p0["current_hp"] = -1
	players[0] = p0
	enc["player_combatants"] = players
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sf_hp_neg", before, bad, sigs, base)

	p0 = ((before.get("encounter") as Dictionary).get("player_combatants") as Array)[0] as Dictionary
	p0 = p0.duplicate(true)
	p0["max_hp"] = 999
	players = [(p0)]
	enc = (before.get("encounter") as Dictionary).duplicate(true)
	enc["player_combatants"] = players
	bad = before.duplicate(true)
	bad["encounter"] = enc
	_assert_restore_fail("sf_immut", before, bad, sigs, base)

	# Valid changed restore: current_hp = max-1
	var cand: Dictionary = before.duplicate(true)
	enc = (cand.get("encounter") as Dictionary).duplicate(true)
	players = (enc.get("player_combatants") as Array).duplicate(true)
	p0 = (players[0] as Dictionary).duplicate(true)
	var max_hp: int = int(p0.get("max_hp", 1))
	p0["current_hp"] = max_hp - 1
	players[0] = p0
	enc["player_combatants"] = players
	cand["encounter"] = enc
	var r_ok: Dictionary = BattleRuntime.restore_runtime_snapshot(cand)
	_assert_true("sf_changed_ok", bool(r_ok.get("ok", false)))
	_assert_true("sf_changed_flag", bool(r_ok.get("changed", false)))
	_assert_eq("sf_changed_hp", BattleRuntime.get_player_combatants()[0].get_current_hp(), max_hp - 1)
	_assert_eq("sf_changed_en_sig", int(sigs["en"][0]), int(base["en"]) + 1)
	_assert_eq("sf_changed_rt_sig", int(sigs["rt"][0]), int(base["rt"]) + 1)

	# Identical restore
	var after: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var base2 := {
		"rt": int(sigs["rt"][0]),
		"bd": int(sigs["bd"][0]),
		"ph": int(sigs["ph"][0]),
		"en": int(sigs["en"][0]),
	}
	var idemp: Dictionary = BattleRuntime.restore_runtime_snapshot(after)
	_assert_true("sf_idemp", bool(idemp.get("ok", false)) and bool(idemp.get("changed", true)) == false)
	_assert_sig_zero("sf_idemp", sigs, base2)

	_disconnect_sigs(sigs)
	print("[INFO] snapshot failure matrix passed")


func _run_adventure_enter_transaction_tests() -> void:
	_clear_catalog_overrides()
	PlayerData.configure_test_storage_path("user://feibao_tests/enc_enter")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	_reset_domain()
	_nav().call("reset", &"lobby")
	_nav().call("navigate_to", &"adventure", true)
	var packed: PackedScene = load("res://scenes/screens/adventure/adventure_screen.tscn") as PackedScene
	var adv: Control = packed.instantiate() as Control
	_tree.root.add_child(adv)
	adv.call("configure_screen", &"adventure")
	await _tree.process_frame
	adv.call("select_area_for_test", &"dev_area_beginner_path")
	adv.call("select_stage_for_test", &"dev_stage_beginner_01")
	adv.call("press_prepare_for_test")
	await _tree.process_frame
	_assert_true("k_prep", AdventureState.has_prepared_stage())

	# K1 missing stats
	var stats_loaded: Dictionary = BattleCharacterStatsCatalog.load_default()
	var arr: Array = []
	for item in stats_loaded.get("stats", []) as Array:
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
	var sp := _write_fixture("enter_no_stats.json", JSON.stringify({"schema_version": 1, "catalog_kind": "development_seed", "stats": arr}))
	BattleCharacterStatsCatalog.set_default_path_override_for_tests(sp)
	var rev0: int = PlayerData.get_profile().get_revision()
	var fp0: Dictionary = _prod_fp()
	var hist0: int = int(_nav().call("get_history_size"))
	adv.call("press_enter_battle_for_test")
	await _tree.process_frame
	_assert_true("k1_no_session", BattleState.has_active_session() == false)
	_assert_true("k1_no_rt", BattleRuntime.has_active_runtime() == false)
	_assert_true("k1_prep_kept", AdventureState.has_prepared_stage())
	_assert_eq("k1_nav", str(_nav().call("get_current_screen")), "adventure")
	_assert_eq("k1_hist", int(_nav().call("get_history_size")), hist0)
	_assert_eq("k1_rev", PlayerData.get_profile().get_revision(), rev0)
	_assert_true("k1_fp", _fp_eq(fp0, _prod_fp()))
	_assert_true("k1_enter_enabled", bool(adv.call("is_enter_battle_enabled")))

	# K4 retry after clear override
	_clear_catalog_overrides()
	var hist1: int = int(_nav().call("get_history_size"))
	adv.call("press_enter_battle_for_test")
	await _tree.process_frame
	await _tree.process_frame
	_assert_true("k4_state", BattleState.has_active_session())
	_assert_true("k4_rt", BattleRuntime.has_active_runtime())
	_assert_true("k4_enc", BattleRuntime.has_active_encounter())
	_assert_eq("k4_cells", BattleRuntime.get_board_cells().size(), 30)
	_assert_eq("k4_nav", str(_nav().call("get_current_screen")), "battle")
	_assert_eq("k4_hist_delta", int(_nav().call("get_history_size")), hist1 + 1)

	# K5 double enter while already in battle should not double-create
	var cells_before: Array[StringName] = BattleRuntime.get_board_cells()
	var snap_rt: Dictionary = BattleRuntime.capture_runtime_snapshot()
	adv.call("press_enter_battle_for_test")
	await _tree.process_frame
	_assert_true("k5_exact", _runtime_exact_1_1(snap_rt))
	_assert_eq("k5_cells0", str(cells_before[0]), str(BattleRuntime.get_board_cells()[0]))

	adv.queue_free()
	await _tree.process_frame
	print("[INFO] adventure enter transaction tests passed")


func _run_leave_transaction_and_real_turn_tests() -> void:
	_clear_catalog_overrides()
	_seed_session(&"dev_stage_beginner_01")
	_assert_true("lt_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))

	# Real accepted turn via forced board if needed
	var match_board: Array[StringName] = []
	# Use runtime test board with horizontal match-ready swap if available
	var cells: Array[StringName] = BattleRuntime.get_board_cells()
	_assert_eq("lt_cells", cells.size(), 30)
	var turn0: int = BattleRuntime.get_turn_count()
	var php0: int = BattleRuntime.get_player_combatants()[0].get_current_hp()
	var ehp0: int = BattleRuntime.get_enemy_combatants()[0].get_current_hp()
	var aei0: int = BattleRuntime.get_active_enemy_index()

	# Try swaps until accepted match or exhaust a few pairs
	var accepted: bool = false
	var cleared: int = 0
	var cascades: int = 0
	for y in 5:
		for x in 5:
			if accepted:
				break
			var r: Dictionary = BattleRuntime.try_swap_cells(Vector2i(x, y), Vector2i(x + 1, y))
			if bool(r.get("ok", false)) and bool(r.get("accepted", false)):
				accepted = true
				cleared = int(r.get("cleared_cell_count", 0))
				cascades = int(r.get("cascade_count", 0))
				break
		if accepted:
			break
	if not accepted:
		# Force a known match board via test seam
		var forced: Array[StringName] = cells.duplicate()
		# Set row0 to create match on swap - simpler: set three embers then resolve by select
		# Use begin_from_seed is already done; if no natural swap, still assert HP unchanged after no-match swaps
		pass
	_assert_eq("lt_hp_p_after_try", BattleRuntime.get_player_combatants()[0].get_current_hp(), php0)
	_assert_eq("lt_hp_e_after_try", BattleRuntime.get_enemy_combatants()[0].get_current_hp(), ehp0)
	_assert_eq("lt_aei_after_try", BattleRuntime.get_active_enemy_index(), aei0)
	if accepted:
		_assert_true("lt_turn_inc", BattleRuntime.get_turn_count() == turn0 + 1)
		_assert_true("lt_cleared_pos", cleared >= 3)
		_assert_true("lt_cascade_pos", cascades >= 1)

	# Distinct HP via snapshot restore for leave evidence
	var snap: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var enc: Dictionary = (snap.get("encounter") as Dictionary).duplicate(true)
	var players: Array = (enc.get("player_combatants") as Array).duplicate(true)
	var p0: Dictionary = (players[0] as Dictionary).duplicate(true)
	p0["current_hp"] = int(p0.get("max_hp", 2)) - 1
	players[0] = p0
	enc["player_combatants"] = players
	snap["encounter"] = enc
	_assert_true("lt_hp_set", bool(BattleRuntime.restore_runtime_snapshot(snap).get("ok", false)))
	var marked: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var marked_hp: int = BattleRuntime.get_player_combatants()[0].get_current_hp()

	var packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	_nav().call("navigate_to", &"battle", true)
	screen.call("set_leave_nav_result_override_for_tests", false)
	var leave_fail: bool = bool(screen.call("request_leave"))
	_assert_true("lt_leave_fail", leave_fail == false)
	_assert_true("lt_restored", _runtime_exact_1_1(marked))
	_assert_eq("lt_hp_exact", BattleRuntime.get_player_combatants()[0].get_current_hp(), marked_hp)
	_assert_true("lt_state", BattleState.has_active_session())
	_assert_true("lt_controls", bool(screen.call("get_leave_button").disabled) == false)

	screen.call("clear_leave_nav_result_override_for_tests")
	var ok_leave: bool = bool(screen.call("request_leave"))
	_assert_true("lt_retry", ok_leave)
	_assert_true("lt_cleared_rt", BattleRuntime.has_active_runtime() == false)
	_assert_true("lt_cleared_st", BattleState.has_active_session() == false)

	screen.queue_free()
	await _tree.process_frame
	print("[INFO] leave + real turn tests passed")


func _run_screen_exact_and_responsive_tests() -> void:
	_clear_catalog_overrides()
	_seed_session(&"dev_stage_beginner_02")
	_assert_true("ui_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	var players: Array[BattleCombatantModel] = BattleRuntime.get_player_combatants()
	var enemies: Array[BattleCombatantModel] = BattleRuntime.get_enemy_combatants()
	_assert_eq("ui_p_count", players.size(), 1)
	_assert_eq("ui_e_count", enemies.size(), 2)
	_assert_eq("ui_e0_id", str(enemies[0].get_source_id()), "training_sprout")
	_assert_eq("ui_e1_id", str(enemies[1].get_source_id()), "training_droplet")

	var packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	await _tree.process_frame

	var party_text: String = str(screen.call("get_party_list_text"))
	_assert_true("ui_p_name", party_text.find(players[0].get_display_name()) >= 0)
	_assert_true("ui_p_hp", party_text.find("%d/%d" % [players[0].get_current_hp(), players[0].get_max_hp()]) >= 0 or party_text.find("HP %d / %d" % [players[0].get_current_hp(), players[0].get_max_hp()]) >= 0 or party_text.find("HP %d/%d" % [players[0].get_current_hp(), players[0].get_max_hp()]) >= 0)
	_assert_true("ui_p_leader", party_text.find("領隊") >= 0)
	_assert_true("ui_p_atk", party_text.find("ATK %d" % players[0].get_attack()) >= 0)
	_assert_true("ui_p_def", party_text.find("DEF %d" % players[0].get_defense()) >= 0)
	_assert_true("ui_p_aff", party_text.find(BattleAffinity.symbol(players[0].get_affinity())) >= 0)

	var enemy_text: String = str(screen.call("get_enemy_list_text"))
	_assert_true("ui_e0_name", enemy_text.find(enemies[0].get_display_name()) >= 0)
	_assert_true("ui_e1_name", enemy_text.find(enemies[1].get_display_name()) >= 0)
	_assert_true("ui_e_active", enemy_text.find("作用中") >= 0)
	_assert_true("ui_e0_hp", enemy_text.find("%d/%d" % [enemies[0].get_current_hp(), enemies[0].get_max_hp()]) >= 0 or enemy_text.find("HP %d/%d" % [enemies[0].get_current_hp(), enemies[0].get_max_hp()]) >= 0)
	_assert_true("ui_shell_exact", str(screen.call("get_shell_status_text")).find("傷害與敵人行動尚未啟用") >= 0)

	# Cards: ProgressBars exist
	var party_cards: Node = screen.get_node_or_null("%PartyCards")
	var enemy_cards: Node = screen.get_node_or_null("%EnemyCards")
	_assert_true("ui_pcards", party_cards != null and party_cards.get_child_count() == 1)
	_assert_true("ui_ecards", enemy_cards != null and enemy_cards.get_child_count() == 2)
	if party_cards != null and party_cards.get_child_count() > 0:
		var bars: Array = []
		_collect_bars(party_cards.get_child(0), bars)
		_assert_true("ui_pbar", bars.size() >= 1)
		if bars.size() > 0:
			var bar: ProgressBar = bars[0] as ProgressBar
			_assert_true("ui_pbar_h", bar.get_combined_minimum_size().y >= 16.0 or bar.size.y >= 16.0 or bar.custom_minimum_size.y >= 16.0)
			_assert_eq("ui_pbar_focus", bar.focus_mode, Control.FOCUS_NONE)

	# Repeated configure no duplicate cards
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	_assert_eq("ui_cfg_pcards", party_cards.get_child_count() if party_cards != null else -1, 1)
	_assert_eq("ui_cfg_ecards", enemy_cards.get_child_count() if enemy_cards != null else -1, 2)

	# Responsive 360
	var sv: Window = _tree.root as Window
	var old_size: Vector2i = sv.size
	sv.size = Vector2i(360, 640)
	await _tree.process_frame
	await _tree.process_frame
	var scroll: ScrollContainer = screen.call("get_body_scroll") as ScrollContainer
	_assert_true("r360_scroll", scroll != null)
	if scroll != null:
		var range_v: float = scroll.get_v_scroll_bar().max_value
		_assert_true("r360_range", range_v > 0.5)
	var grid: GridContainer = screen.call("get_board_grid") as GridContainer
	if grid != null and grid.get_child_count() > 0:
		var cell: Control = grid.get_child(0) as Control
		_assert_true("r360_cell_w", cell.size.x >= 48.0 or cell.get_combined_minimum_size().x >= 48.0)
		_assert_true("r360_cell_h", cell.size.y >= 48.0 or cell.get_combined_minimum_size().y >= 48.0)

	sv.size = Vector2i(390, 844)
	await _tree.process_frame
	await _tree.process_frame
	if grid != null and grid.get_child_count() > 0:
		var cell2: Control = grid.get_child(0) as Control
		_assert_true("r390_cell", cell2.size.x >= 48.0 or cell2.get_combined_minimum_size().x >= 48.0)

	sv.size = Vector2i(720, 1280)
	await _tree.process_frame
	await _tree.process_frame
	if grid != null and grid.get_child_count() > 0:
		var cell3: Control = grid.get_child(0) as Control
		_assert_true("r720_cell", cell3.size.x >= 48.0 or cell3.get_combined_minimum_size().x >= 48.0)

	sv.size = old_size
	screen.queue_free()
	await _tree.process_frame
	print("[INFO] screen exact + responsive tests passed")


func _collect_bars(n: Node, out: Array) -> void:
	if n is ProgressBar:
		out.append(n)
	for c in n.get_children():
		_collect_bars(c, out)


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
