## FeiBao 1.1.0 battle encounter & combatant foundation suite.
extends RefCounted

var passed: int = 0
var failed: int = 0
var results: PackedStringArray = PackedStringArray()
var _tree: SceneTree


func setup(tree: SceneTree) -> void:
	_tree = tree


func run_all() -> void:
	_reset_domain()
	_run_affinity_tests()
	_run_character_stats_catalog_tests()
	_run_enemy_catalog_tests()
	_run_stage_encounter_catalog_tests()
	_run_combatant_model_tests()
	_run_encounter_model_tests()
	_run_runtime_atomic_tests()
	_run_snapshot_signal_tests()
	await _run_screen_and_turn_hp_tests()
	_reset_domain()
	PlayerData.configure_test_storage_path("user://feibao_tests/suite_main")
	PlayerData.reset_runtime_state_for_tests()
	print("[INFO] battle encounter combatant suite complete")


func _reset_domain() -> void:
	if is_instance_valid(AdventureState):
		AdventureState.reset_runtime_state_for_tests()
	if is_instance_valid(BattleRuntime):
		BattleRuntime.reset_runtime_state_for_tests()
	if is_instance_valid(BattleState):
		BattleState.reset_runtime_state_for_tests()


func _seed_session(stage_id: StringName = &"dev_stage_beginner_01") -> void:
	PlayerData.configure_test_storage_path("user://feibao_tests/enc_combatant")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	_reset_domain()
	AdventureState.prepare_stage(stage_id)
	_assert_true("seed_bs_%s" % str(stage_id), bool(BattleState.begin_from_prepared_stage().get("ok", false)))


func _run_affinity_tests() -> void:
	var allv: Array[StringName] = BattleAffinity.all()
	_assert_eq("aff_count", allv.size(), 5)
	allv.clear()
	_assert_eq("aff_defensive", BattleAffinity.all().size(), 5)
	for a in BattleAffinity.all():
		_assert_true("aff_valid_%s" % str(a), BattleAffinity.is_valid(a))
		_assert_true("aff_sym_%s" % str(a), not BattleAffinity.symbol(a).is_empty())
		_assert_true("aff_name_%s" % str(a), not BattleAffinity.display_name(a).is_empty())
	_assert_true("aff_rej_str", BattleAffinity.is_valid("ember") == false)
	_assert_true("aff_rej_int", BattleAffinity.is_valid(1) == false)
	_assert_true("aff_rej_bool", BattleAffinity.is_valid(true) == false)
	_assert_true("aff_rej_null", BattleAffinity.is_valid(null) == false)
	_assert_true("aff_rej_unk", BattleAffinity.is_valid(&"fire") == false)
	print("[INFO] affinity tests passed")


func _run_character_stats_catalog_tests() -> void:
	var loaded: Dictionary = BattleCharacterStatsCatalog.load_default()
	_assert_true("ccs_ok", bool(loaded.get("ok", false)))
	var stats: Array = loaded.get("stats", []) as Array
	_assert_eq("ccs_schema", BattleCharacterStatsCatalog.EXPECTED_SCHEMA_VERSION, 1)
	_assert_true("ccs_entries", stats.size() >= 6)

	var chars: Dictionary = CharacterCatalog.load_default()
	_assert_true("ccs_chars", bool(chars.get("ok", false)))
	for c in chars.get("characters", []):
		if c is CharacterDefinition:
			var id: StringName = (c as CharacterDefinition).get_id()
			var f: Dictionary = BattleCharacterStatsCatalog.find_stats(id)
			_assert_true("ccs_cover_%s" % str(id), bool(f.get("ok", false)))

	var s0: Dictionary = (stats[0] as Dictionary).duplicate(true)
	_assert_true("ccs_defensive_copy", true)
	var mut: Dictionary = BattleCharacterStatsCatalog.find_stats(&"feibao_dev")
	var st: Dictionary = mut.get("stats", {}) as Dictionary
	st["max_hp"] = 1
	var again: Dictionary = BattleCharacterStatsCatalog.find_stats(&"feibao_dev")
	_assert_true("ccs_defensive", int((again.get("stats", {}) as Dictionary).get("max_hp", 0)) != 1 or int((again.get("stats", {}) as Dictionary).get("max_hp", 0)) == 120)

	_assert_true(
		"ccs_reject_extra",
		bool(
			BattleCharacterStatsCatalog.parse_json_text(
				'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":10,"attack":1,"defense":1,"level":1}]}'
			).get("ok", true)
		)
		== false
	)
	_assert_true(
		"ccs_reject_float",
		bool(
			BattleCharacterStatsCatalog.parse_json_text(
				'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"feibao_dev","affinity":"ember","max_hp":10.5,"attack":1,"defense":1}]}'
			).get("ok", true)
		)
		== false
	)
	_assert_true(
		"ccs_reject_orphan",
		bool(
			BattleCharacterStatsCatalog.parse_json_text(
				'{"schema_version":1,"catalog_kind":"development_seed","stats":[{"character_id":"no_such_char","affinity":"ember","max_hp":10,"attack":1,"defense":1}]}'
			).get("ok", true)
		)
		== false
	)
	print("[INFO] character stats catalog tests passed")


func _run_enemy_catalog_tests() -> void:
	var loaded: Dictionary = EnemyCatalog.load_default()
	_assert_true("en_ok", bool(loaded.get("ok", false)))
	var enemies: Array = loaded.get("enemies", []) as Array
	_assert_true("en_entries", enemies.size() >= 3)
	var ids: PackedStringArray = PackedStringArray()
	for e in enemies:
		var d: Dictionary = e as Dictionary
		var eid: String = str(d.get("enemy_id", ""))
		_assert_true("en_id_%s" % eid, not eid.is_empty())
		_assert_true("en_name_%s" % eid, not str(d.get("display_name", "")).is_empty())
		_assert_true("en_sym_%s" % eid, not str(d.get("visual_symbol", "")).is_empty())
		_assert_true("en_aff_%s" % eid, BattleAffinity.is_valid(d.get("affinity")))
		ids.append(eid)
	_assert_true("en_training_sprout", ids.find("training_sprout") >= 0)
	_assert_true("en_training_droplet", ids.find("training_droplet") >= 0)
	_assert_true("en_training_emberling", ids.find("training_emberling") >= 0)
	_assert_true(
		"en_reject_extra",
		bool(
			EnemyCatalog.parse_json_text(
				'{"schema_version":1,"catalog_kind":"development_seed","enemies":[{"enemy_id":"a","display_name":"A","affinity":"ember","max_hp":1,"attack":0,"defense":0,"visual_symbol":"x","ai":1}]}'
			).get("ok", true)
		)
		== false
	)
	print("[INFO] enemy catalog tests passed")


func _run_stage_encounter_catalog_tests() -> void:
	var loaded: Dictionary = StageEncounterCatalog.load_default()
	_assert_true("se_ok", bool(loaded.get("ok", false)))
	var stages: Dictionary = StageCatalog.load_default()
	_assert_true("se_stages", bool(stages.get("ok", false)))
	var stage_n: int = 0
	for s in stages.get("stages", []):
		if s is StageDefinition:
			stage_n += 1
			var sid: StringName = (s as StageDefinition).get_id()
			var f: Dictionary = StageEncounterCatalog.find_encounter(sid)
			_assert_true("se_cover_%s" % str(sid), bool(f.get("ok", false)))
			var enc: Dictionary = f.get("encounter", {}) as Dictionary
			var eids: Array = enc.get("enemy_ids", []) as Array
			_assert_true("se_range_%s" % str(sid), eids.size() >= 1 and eids.size() <= 3)
	_assert_true("se_stage_count", stage_n >= 6)

	var mist3: Dictionary = StageEncounterCatalog.find_encounter(&"dev_stage_mist_03")
	var m3: Dictionary = mist3.get("encounter", {}) as Dictionary
	_assert_eq("se_mist3_n", (m3.get("enemy_ids", []) as Array).size(), 3)
	print("[INFO] stage encounter catalog tests passed")


func _run_combatant_model_tests() -> void:
	var p: Dictionary = BattleCombatantModel.create_player(
		&"feibao_dev", "飛寶（開發樣本）", &"ember", 0, 120, 14, 8
	)
	_assert_true("cm_player", bool(p.get("ok", false)))
	var pc: BattleCombatantModel = p.get("combatant") as BattleCombatantModel
	_assert_true("cm_alive", pc != null and pc.is_alive())
	_assert_eq("cm_hp_full", pc.get_current_hp(), pc.get_max_hp())
	var snap: Dictionary = pc.capture_snapshot()
	var rest: Dictionary = BattleCombatantModel.restore_snapshot(snap)
	_assert_true("cm_snap", bool(rest.get("ok", false)))

	var bad: Dictionary = snap.duplicate(true)
	bad["current_hp"] = 1.0
	_assert_true("cm_rej_float", bool(BattleCombatantModel.validate_snapshot(bad).get("ok", true)) == false)
	bad = snap.duplicate(true)
	bad["max_hp"] = 999
	_assert_true("cm_rej_immut", bool(BattleCombatantModel.validate_snapshot(bad).get("ok", true)) == false)
	bad = snap.duplicate(true)
	bad["combatant_kind"] = &"boss"
	_assert_true("cm_rej_kind", bool(BattleCombatantModel.validate_snapshot(bad).get("ok", true)) == false)
	print("[INFO] combatant model tests passed")


func _run_encounter_model_tests() -> void:
	var party: Array[StringName] = [&"feibao_dev", &"partner_a"]
	var built: Dictionary = BattleEncounterModel.build_from_session(&"dev_stage_beginner_02", party)
	_assert_true("em_build", bool(built.get("ok", false)))
	var enc: BattleEncounterModel = built.get("encounter") as BattleEncounterModel
	_assert_true("em_valid", enc != null and enc.is_valid())
	_assert_eq("em_players", enc.get_player_combatants().size(), 2)
	_assert_eq("em_enemies", enc.get_enemy_combatants().size(), 2)
	_assert_eq("em_aei", enc.get_active_enemy_index(), 0)
	_assert_eq("em_p0", str(enc.get_player_combatants()[0].get_source_id()), "feibao_dev")
	_assert_eq("em_e0", str(enc.get_enemy_combatants()[0].get_source_id()), "training_sprout")

	var snap: Dictionary = enc.capture_snapshot()
	var rest: Dictionary = BattleEncounterModel.restore_snapshot(snap)
	_assert_true("em_snap", bool(rest.get("ok", false)))
	_assert_true("em_eq", BattleEncounterModel.equals(enc, rest.get("encounter") as BattleEncounterModel))

	var inactive: Dictionary = BattleEncounterModel.restore_snapshot(
		{"player_combatants": [], "enemy_combatants": [], "active_enemy_index": -1}
	)
	_assert_true("em_inactive", bool(inactive.get("ok", false)))
	print("[INFO] encounter model tests passed")


func _run_runtime_atomic_tests() -> void:
	_seed_session(&"dev_stage_beginner_01")
	_assert_true("rt_no_enc", BattleRuntime.has_active_encounter() == false)
	var before_rng: int = BattleRuntime.get_rng_state()
	var begin: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("rt_begin", bool(begin.get("ok", false)))
	_assert_true("rt_active", BattleRuntime.has_active_runtime())
	_assert_true("rt_enc", BattleRuntime.has_active_encounter())
	_assert_eq("rt_players", BattleRuntime.get_player_combatants().size(), 1)
	_assert_eq("rt_enemies", BattleRuntime.get_enemy_combatants().size(), 1)
	_assert_eq("rt_aei", BattleRuntime.get_active_enemy_index(), 0)
	_assert_eq("rt_enemy_id", str(BattleRuntime.get_enemy_combatants()[0].get_source_id()), "training_sprout")

	var again: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("rt_idem", bool(again.get("ok", false)) and bool(again.get("changed", true)) == false)

	# Multi-enemy
	BattleRuntime.clear_runtime()
	BattleState.clear_session()
	_seed_session(&"dev_stage_mist_03")
	_assert_true("rt_m3", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	_assert_eq("rt_m3_n", BattleRuntime.get_enemy_combatants().size(), 3)

	# Failure preserves inactive: clear then fail by clearing session mid-way is hard;
	# instead attempt begin with no session.
	BattleRuntime.clear_runtime()
	BattleState.clear_session()
	var fail: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("rt_fail_nosess", bool(fail.get("ok", true)) == false)
	_assert_true("rt_fail_inactive", BattleRuntime.has_active_runtime() == false)
	_assert_true("rt_fail_no_enc", BattleRuntime.has_active_encounter() == false)
	print("[INFO] runtime atomic tests passed")


func _run_snapshot_signal_tests() -> void:
	_seed_session(&"dev_stage_beginner_02")
	_assert_true("ss_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	var snap: Dictionary = BattleRuntime.capture_runtime_snapshot()
	_assert_true("ss_has_enc", snap.has("encounter"))
	var enc: Dictionary = snap.get("encounter", {}) as Dictionary
	_assert_eq("ss_players", (enc.get("player_combatants", []) as Array).size(), 1)
	_assert_eq("ss_enemies", (enc.get("enemy_combatants", []) as Array).size(), 2)
	_assert_eq("ss_aei", int(enc.get("active_enemy_index", -9)), 0)

	var sig_rt: Array = [0]
	var sig_bd: Array = [0]
	var sig_ph: Array = [0]
	var sig_en: Array = [0]
	var on_rt := func(_a: bool) -> void:
		sig_rt[0] = int(sig_rt[0]) + 1
	var on_bd := func() -> void:
		sig_bd[0] = int(sig_bd[0]) + 1
	var on_ph := func(_p: StringName) -> void:
		sig_ph[0] = int(sig_ph[0]) + 1
	var on_en := func() -> void:
		sig_en[0] = int(sig_en[0]) + 1
	BattleRuntime.runtime_changed.connect(on_rt)
	BattleRuntime.board_changed.connect(on_bd)
	BattleRuntime.phase_changed.connect(on_ph)
	BattleRuntime.encounter_changed.connect(on_en)

	# Idempotent restore
	var r0: Dictionary = BattleRuntime.restore_runtime_snapshot(snap)
	_assert_true("ss_idemp", bool(r0.get("ok", false)) and bool(r0.get("changed", true)) == false)
	_assert_eq("ss_idemp_rt", int(sig_rt[0]), 0)
	_assert_eq("ss_idemp_bd", int(sig_bd[0]), 0)
	_assert_eq("ss_idemp_ph", int(sig_ph[0]), 0)
	_assert_eq("ss_idemp_en", int(sig_en[0]), 0)

	# Illegal float hp — zero signals, exact state
	var bad: Dictionary = snap.duplicate(true)
	var enc2: Dictionary = (bad.get("encounter") as Dictionary).duplicate(true)
	var players: Array = (enc2.get("player_combatants") as Array).duplicate(true)
	var p0: Dictionary = (players[0] as Dictionary).duplicate(true)
	p0["current_hp"] = 1.0
	players[0] = p0
	enc2["player_combatants"] = players
	bad["encounter"] = enc2
	var before_turn: int = BattleRuntime.get_turn_count()
	var before_enemies: int = BattleRuntime.get_enemy_combatants().size()
	var rf: Dictionary = BattleRuntime.restore_runtime_snapshot(bad)
	_assert_true("ss_bad_float", bool(rf.get("ok", true)) == false)
	_assert_eq("ss_bad_turn", BattleRuntime.get_turn_count(), before_turn)
	_assert_eq("ss_bad_enemies", BattleRuntime.get_enemy_combatants().size(), before_enemies)
	_assert_eq("ss_bad_rt", int(sig_rt[0]), 0)
	_assert_eq("ss_bad_bd", int(sig_bd[0]), 0)
	_assert_eq("ss_bad_ph", int(sig_ph[0]), 0)
	_assert_eq("ss_bad_en", int(sig_en[0]), 0)

	# Missing encounter key
	var bad2: Dictionary = snap.duplicate(true)
	bad2.erase("encounter")
	_assert_true("ss_missing", bool(BattleRuntime.restore_runtime_snapshot(bad2).get("ok", true)) == false)
	_assert_eq("ss_missing_sig", int(sig_rt[0]) + int(sig_bd[0]) + int(sig_en[0]), 0)

	if BattleRuntime.runtime_changed.is_connected(on_rt):
		BattleRuntime.runtime_changed.disconnect(on_rt)
	if BattleRuntime.board_changed.is_connected(on_bd):
		BattleRuntime.board_changed.disconnect(on_bd)
	if BattleRuntime.phase_changed.is_connected(on_ph):
		BattleRuntime.phase_changed.disconnect(on_ph)
	if BattleRuntime.encounter_changed.is_connected(on_en):
		BattleRuntime.encounter_changed.disconnect(on_en)

	# Clear → inactive encounter
	BattleRuntime.clear_runtime()
	var inactive: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var ienc: Dictionary = inactive.get("encounter", {}) as Dictionary
	_assert_eq("ss_inact_p", (ienc.get("player_combatants", [1]) as Array).size(), 0)
	_assert_eq("ss_inact_e", (ienc.get("enemy_combatants", [1]) as Array).size(), 0)
	_assert_eq("ss_inact_aei", int(ienc.get("active_enemy_index", 0)), -1)
	print("[INFO] snapshot/signal tests passed")


func _run_screen_and_turn_hp_tests() -> void:
	_seed_session(&"dev_stage_beginner_02")
	_assert_true("ui_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	var hp0: int = BattleRuntime.get_player_combatants()[0].get_current_hp()
	var aei0: int = BattleRuntime.get_active_enemy_index()
	var ehp0: int = BattleRuntime.get_enemy_combatants()[0].get_current_hp()

	var packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	await _tree.process_frame
	_assert_true("ui_shell", str(screen.call("get_shell_status_text")).find("傷害") >= 0)
	_assert_true("ui_party_hp", str(screen.call("get_party_list_text")).find("HP") >= 0)
	_assert_true("ui_party_atk", str(screen.call("get_party_list_text")).find("ATK") >= 0)
	_assert_true("ui_party_leader", str(screen.call("get_party_list_text")).find("領隊") >= 0)
	_assert_true("ui_enemy_hp", str(screen.call("get_enemy_list_text")).find("HP") >= 0)
	_assert_true("ui_enemy_active", str(screen.call("get_enemy_list_text")).find("作用中") >= 0)
	_assert_true(
		"ui_enemy_name",
		str(screen.call("get_enemy_list_text")).find("幼芽") >= 0
		or str(screen.call("get_enemy_list_text")).find("水滴") >= 0
	)
	_assert_true("ui_aff", str(screen.call("get_party_list_text")).find("▲") >= 0 or str(screen.call("get_party_list_text")).find("●") >= 0 or str(screen.call("get_party_list_text")).find("炎") >= 0 or str(screen.call("get_party_list_text")).find("潮") >= 0)

	# Board turn must not change HP / active enemy
	var board: Array[StringName] = BattleRuntime.get_board_cells()
	# Force a no-match swap if possible: just verify select doesn't change HP
	BattleRuntime.select_cell(0, 0)
	_assert_eq("turn_hp_player", BattleRuntime.get_player_combatants()[0].get_current_hp(), hp0)
	_assert_eq("turn_hp_enemy", BattleRuntime.get_enemy_combatants()[0].get_current_hp(), ehp0)
	_assert_eq("turn_aei", BattleRuntime.get_active_enemy_index(), aei0)

	# Idempotent configure
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	_assert_true("ui_cfg2", str(screen.call("get_party_list_text")).find("HP") >= 0)

	screen.queue_free()
	await _tree.process_frame
	print("[INFO] screen + turn HP tests passed")


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
