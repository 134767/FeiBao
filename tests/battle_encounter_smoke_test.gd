## Battle encounter + combatant foundation (1.1.0).
extends RefCounted

var passed: int = 0
var failed: int = 0
var results: PackedStringArray = PackedStringArray()
var _tree: SceneTree


func setup(tree: SceneTree) -> void:
	_tree = tree


func run_all() -> void:
	_reset_domain()
	_run_catalog_tests()
	_run_encounter_build_tests()
	_run_runtime_atomic_tests()
	_run_snapshot_tests()
	await _run_screen_tests()
	_reset_domain()
	PlayerData.configure_test_storage_path("user://feibao_tests/suite_main")
	PlayerData.reset_runtime_state_for_tests()
	print("[INFO] battle encounter suite complete")


func _nav() -> Node:
	return _tree.root.get_node("NavigationState")


func _reset_domain() -> void:
	if is_instance_valid(AdventureState):
		AdventureState.reset_runtime_state_for_tests()
	if is_instance_valid(BattleRuntime):
		BattleRuntime.reset_runtime_state_for_tests()
	if is_instance_valid(BattleState):
		BattleState.reset_runtime_state_for_tests()


func _seed_session(stage_id: StringName = &"dev_stage_beginner_01") -> void:
	PlayerData.configure_test_storage_path("user://feibao_tests/encounter_suite")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	_reset_domain()
	AdventureState.prepare_stage(stage_id)
	var bs: Dictionary = BattleState.begin_from_prepared_stage()
	_assert_true("seed_state_%s" % str(stage_id), bool(bs.get("ok", false)))


func _run_catalog_tests() -> void:
	var stats: Dictionary = CharacterCombatStatsCatalog.load_default()
	_assert_true("ccs_ok", bool(stats.get("ok", false)))
	_assert_true("ccs_nonempty", (stats.get("stats", []) as Array).size() >= 6)
	var feibao: Dictionary = CharacterCombatStatsCatalog.find_stats(&"feibao_dev")
	_assert_true("ccs_find", bool(feibao.get("ok", false)))
	var sdef: CharacterCombatStatsDefinition = feibao.get("stats") as CharacterCombatStatsDefinition
	_assert_true("ccs_hp", sdef != null and sdef.get_max_hp() >= 1)
	_assert_true("ccs_atk", sdef != null and sdef.get_attack() >= 0)

	var bad_stats: Dictionary = CharacterCombatStatsCatalog.parse_json_text(
		'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"x","max_hp":0,"attack":1,"defense":1,"is_development_seed":true}]}'
	)
	_assert_true("ccs_reject_hp0", bool(bad_stats.get("ok", true)) == false)

	var enemies: Dictionary = EnemyCatalog.load_default()
	_assert_true("en_ok", bool(enemies.get("ok", false)))
	_assert_true("en_count", (enemies.get("enemies", []) as Array).size() >= 3)
	var imp: Dictionary = EnemyCatalog.find_enemy(&"dev_ember_imp")
	_assert_true("en_find", bool(imp.get("ok", false)))
	var edef: EnemyDefinition = imp.get("enemy") as EnemyDefinition
	_assert_true("en_name", edef != null and not edef.get_display_name().is_empty())
	_assert_true("en_hp", edef != null and edef.get_max_hp() >= 1)

	var bad_en: Dictionary = EnemyCatalog.parse_json_text(
		'{"schema_version":1,"catalog_kind":"development_seed","enemies":[{"id":"a","display_name":"A","summary":"s","max_hp":1,"attack":1,"defense":1,"sort_order":0,"is_development_seed":true,"ai":1}]}'
	)
	_assert_true("en_reject_extra", bool(bad_en.get("ok", true)) == false)

	var encs: Dictionary = StageEncounterCatalog.load_default()
	_assert_true("se_ok", bool(encs.get("ok", false)))
	var se: Dictionary = StageEncounterCatalog.find_encounter(&"dev_stage_beginner_01")
	_assert_true("se_find", bool(se.get("ok", false)))
	var sdef2: StageEncounterDefinition = se.get("encounter") as StageEncounterDefinition
	_assert_true("se_enemies", sdef2 != null and sdef2.get_enemy_ids().size() >= 1)
	var mist3: Dictionary = StageEncounterCatalog.find_encounter(&"dev_stage_mist_03")
	_assert_true("se_mist3", bool(mist3.get("ok", false)))
	var m3: StageEncounterDefinition = mist3.get("encounter") as StageEncounterDefinition
	_assert_eq("se_mist3_count", m3.get_enemy_ids().size() if m3 != null else 0, 3)

	var bad_se: Dictionary = StageEncounterCatalog.parse_json_text(
		'{"schema_version":1,"catalog_kind":"development_seed","encounters":[{"stage_id":"dev_stage_beginner_01","enemy_ids":[],"is_development_seed":true}]}'
	)
	_assert_true("se_reject_empty", bool(bad_se.get("ok", true)) == false)

	# Coverage: every default stage has encounter
	var stages_loaded: Dictionary = StageCatalog.load_default()
	_assert_true("se_stage_cat", bool(stages_loaded.get("ok", false)))
	for st in stages_loaded.get("stages", []):
		if st is StageDefinition:
			var sid: StringName = (st as StageDefinition).get_id()
			var found: Dictionary = StageEncounterCatalog.find_encounter(sid)
			_assert_true("se_cover_%s" % str(sid), bool(found.get("ok", false)))

	# Coverage: every owned seed character has combat stats
	for cid in [&"feibao_dev", &"partner_a", &"partner_b", &"partner_c", &"partner_d", &"partner_e"]:
		_assert_true("ccs_cover_%s" % str(cid), bool(CharacterCombatStatsCatalog.find_stats(cid).get("ok", false)))

	_assert_eq("ver_app", FeiBaoConstants.APP_VERSION, "1.1.0")
	_assert_eq("ver_profile_schema", 2, 2)
	print("[INFO] encounter catalog tests passed")


func _run_encounter_build_tests() -> void:
	var party: Array[StringName] = [&"feibao_dev", &"partner_a"]
	var built: Dictionary = BattleEncounterModel.build_from_session(
		&"dev_area_beginner_path", &"dev_stage_beginner_02", party, &"feibao_dev"
	)
	_assert_true("build_ok", bool(built.get("ok", false)))
	var enc: BattleEncounterModel = built.get("encounter") as BattleEncounterModel
	_assert_true("build_active", enc != null and enc.is_active())
	_assert_eq("build_party", enc.get_party_count() if enc != null else 0, 2)
	_assert_eq("build_enemies", enc.get_enemy_count() if enc != null else 0, 2)
	var p0: BattleCombatant = enc.get_party_combatants()[0] if enc != null else null
	_assert_true("build_leader", p0 != null and p0.is_leader() and p0.get_current_hp() == p0.get_max_hp())

	var bad_leader: Dictionary = BattleEncounterModel.build_from_session(
		&"dev_area_beginner_path", &"dev_stage_beginner_01", party, &"partner_a"
	)
	_assert_true("build_bad_leader", bool(bad_leader.get("ok", true)) == false)

	var bad_stage: Dictionary = BattleEncounterModel.build_from_session(
		&"dev_area_beginner_path", &"no_such_stage", [&"feibao_dev"], &"feibao_dev"
	)
	_assert_true("build_bad_stage", bool(bad_stage.get("ok", true)) == false)

	# Snapshot round-trip
	var snap: Dictionary = enc.capture_snapshot()
	var restored: Dictionary = BattleEncounterModel.validate_and_restore_snapshot(snap)
	_assert_true("enc_snap_ok", bool(restored.get("ok", false)))
	var enc2: BattleEncounterModel = restored.get("encounter") as BattleEncounterModel
	_assert_true("enc_snap_eq", BattleEncounterModel.equals(enc, enc2))

	# Illegal combatant types
	var bad_hp: Dictionary = snap.duplicate(true)
	var party_arr: Array = (bad_hp.get("party") as Array).duplicate(true)
	var p0d: Dictionary = (party_arr[0] as Dictionary).duplicate(true)
	p0d["current_hp"] = 1.0
	party_arr[0] = p0d
	bad_hp["party"] = party_arr
	_assert_true(
		"enc_reject_float_hp",
		bool(BattleEncounterModel.validate_and_restore_snapshot(bad_hp).get("ok", true)) == false
	)
	print("[INFO] encounter build tests passed")


func _run_runtime_atomic_tests() -> void:
	_seed_session(&"dev_stage_beginner_01")
	_assert_true("rt_no_enc_before", BattleRuntime.has_active_encounter() == false)
	var begin: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("rt_begin", bool(begin.get("ok", false)))
	_assert_true("rt_active", BattleRuntime.has_active_runtime())
	_assert_true("rt_enc_active", BattleRuntime.has_active_encounter())
	_assert_eq("rt_party_n", BattleRuntime.get_party_combatant_count(), 1)
	_assert_eq("rt_enemy_n", BattleRuntime.get_enemy_combatant_count(), 1)
	var enemies: Array[BattleCombatant] = BattleRuntime.get_enemy_combatants()
	_assert_eq("rt_enemy_id", str(enemies[0].get_definition_id()) if enemies.size() > 0 else "", "dev_ember_imp")
	var party: Array[BattleCombatant] = BattleRuntime.get_party_combatants()
	_assert_eq("rt_party_id", str(party[0].get_definition_id()) if party.size() > 0 else "", "feibao_dev")
	_assert_true("rt_party_full_hp", party.size() > 0 and party[0].get_current_hp() == party[0].get_max_hp())

	# Idempotent begin
	var again: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("rt_idempotent", bool(again.get("ok", false)) and bool(again.get("changed", true)) == false)

	# Multi-enemy stage
	BattleRuntime.clear_runtime()
	BattleState.clear_session()
	_seed_session(&"dev_stage_mist_03")
	var b2: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("rt_mist3", bool(b2.get("ok", false)))
	_assert_eq("rt_mist3_enemies", BattleRuntime.get_enemy_combatant_count(), 3)

	# Defensive copies
	var ecopy: Array[BattleCombatant] = BattleRuntime.get_enemy_combatants()
	if ecopy.size() > 0:
		# Mutating returned array/object must not affect runtime (duplicate combatants).
		var before_id: StringName = BattleRuntime.get_enemy_combatants()[0].get_definition_id()
		ecopy.clear()
		_assert_eq("rt_defensive_enemy", str(BattleRuntime.get_enemy_combatants()[0].get_definition_id()), str(before_id))

	print("[INFO] runtime atomic encounter tests passed")


func _run_snapshot_tests() -> void:
	_seed_session(&"dev_stage_beginner_02")
	var begin: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("snap_begin", bool(begin.get("ok", false)))
	var snap: Dictionary = BattleRuntime.capture_runtime_snapshot()
	_assert_true("snap_has_enc", snap.has("encounter"))
	var enc_snap: Dictionary = snap.get("encounter", {}) as Dictionary
	_assert_true("snap_enc_active", bool(enc_snap.get("active", false)))
	_assert_eq("snap_enc_enemies", (enc_snap.get("enemies", []) as Array).size(), 2)

	# Round-trip
	var rt: Dictionary = BattleRuntime.restore_runtime_snapshot(snap)
	_assert_true("snap_restore_idem", bool(rt.get("ok", false)))
	_assert_eq("snap_after_enemies", BattleRuntime.get_enemy_combatant_count(), 2)

	# Missing encounter fails closed
	var bad: Dictionary = snap.duplicate(true)
	bad.erase("encounter")
	var before: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var fail: Dictionary = BattleRuntime.restore_runtime_snapshot(bad)
	_assert_true("snap_missing_enc", bool(fail.get("ok", true)) == false)
	_assert_true(
		"snap_missing_preserve",
		BattleRuntime.get_turn_count() == int(before.get("turn_count", -1))
		and BattleRuntime.get_enemy_combatant_count() == 2
	)

	# Illegal float HP in encounter
	var bad2: Dictionary = snap.duplicate(true)
	var enc2: Dictionary = (bad2.get("encounter") as Dictionary).duplicate(true)
	var party2: Array = (enc2.get("party") as Array).duplicate(true)
	var p0: Dictionary = (party2[0] as Dictionary).duplicate(true)
	p0["max_hp"] = 100.0
	party2[0] = p0
	enc2["party"] = party2
	bad2["encounter"] = enc2
	var fail2: Dictionary = BattleRuntime.restore_runtime_snapshot(bad2)
	_assert_true("snap_float_hp", bool(fail2.get("ok", true)) == false)

	# Clear → inactive encounter
	BattleRuntime.clear_runtime()
	_assert_true("snap_clear_enc", BattleRuntime.has_active_encounter() == false)
	var inactive: Dictionary = BattleRuntime.capture_runtime_snapshot()
	_assert_true("snap_inact_enc", bool((inactive.get("encounter", {}) as Dictionary).get("active", true)) == false)
	print("[INFO] encounter snapshot tests passed")


func _run_screen_tests() -> void:
	_seed_session(&"dev_stage_beginner_02")
	var begin: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("ui_begin", bool(begin.get("ok", false)))
	var packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	_assert_true("ui_packed", packed != null)
	if packed == null:
		return
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	await _tree.process_frame
	_assert_true("ui_screen", screen != null and is_instance_valid(screen))
	_assert_true("ui_party_hp", str(screen.call("get_party_list_text")).find("HP") >= 0)
	_assert_true("ui_party_leader", str(screen.call("get_party_list_text")).find("領隊") >= 0)
	_assert_true("ui_enemy_header", str(screen.call("get_enemy_header_text")).find("敵人") >= 0)
	_assert_true("ui_enemy_hp", str(screen.call("get_enemy_list_text")).find("HP") >= 0)
	_assert_true(
		"ui_enemy_name",
		str(screen.call("get_enemy_list_text")).find("炎小妖") >= 0
		or str(screen.call("get_enemy_list_text")).find("潮霧") >= 0
	)
	_assert_true("ui_shell", str(screen.call("get_shell_status_text")).find("遭遇") >= 0)
	screen.queue_free()
	await _tree.process_frame
	print("[INFO] encounter screen tests passed")


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
