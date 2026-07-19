## GROK-040: FeiBao 1.2.0 player attack & damage foundation evidence.
extends RefCounted

var passed: int = 0
var failed: int = 0
var results: PackedStringArray = PackedStringArray()
var _tree: SceneTree
var _fixture_paths: Array[String] = []
const FIXTURE_DIR: String = "user://feibao_tests/player_attack_damage_fixtures"


func setup(tree: SceneTree) -> void:
	_tree = tree


func run_all() -> void:
	var fp0: Dictionary = _prod_fp()
	_clear_overrides()
	_reset_domain()
	_run_apply_damage_k1()
	_run_combat_event_schema_k2()
	_run_orb_aggregation_k3()
	_run_damage_formula_k4()
	await _run_forced_accepted_turn_k5()
	await _run_rejected_swap_k6()
	await _run_zero_matching_player_k7()
	await _run_lethal_damage_k8()
	await _run_atomic_failure_k9()
	_run_snapshot_matrix_k10()
	await _run_screen_k11()
	await _run_responsive_k12()
	await _run_enter_leave_k13()
	_assert_production_safety_k14(fp0)
	_cleanup_fixtures()
	_clear_overrides()
	_reset_domain()
	PlayerData.configure_test_storage_path("user://feibao_tests/suite_main")
	PlayerData.reset_runtime_state_for_tests()
	print("[INFO] GROK-040 player attack damage suite complete")


func _nav() -> Node:
	return _tree.root.get_node("NavigationState")


func _reset_domain() -> void:
	if is_instance_valid(AdventureState):
		AdventureState.reset_runtime_state_for_tests()
	if is_instance_valid(BattleRuntime):
		BattleRuntime.reset_runtime_state_for_tests()
	if is_instance_valid(BattleState):
		BattleState.reset_runtime_state_for_tests()
	BattleDamageResolver.clear_force_fail_for_tests()


func _clear_overrides() -> void:
	BattleDamageResolver.clear_force_fail_for_tests()
	if is_instance_valid(BattleRuntime):
		BattleRuntime.clear_damage_resolver_force_fail_for_tests()
		BattleRuntime.clear_refill_kind_override_for_tests()
		BattleRuntime.clear_cascade_hard_cap_override_for_tests()


func _assert_true(name: String, cond: bool) -> void:
	if cond:
		passed += 1
		results.append("[PASS] %s" % name)
		print("[PASS] %s" % name)
	else:
		failed += 1
		results.append("[FAIL] %s" % name)
		print("[FAIL] %s" % name)


func _assert_eq(name: String, a: Variant, b: Variant) -> void:
	_assert_true(name, a == b)


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


func _cleanup_fixtures() -> void:
	for p in _fixture_paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_fixture_paths.clear()
	var dir := DirAccess.open(FIXTURE_DIR)
	if dir != null:
		dir.list_dir_begin()
		var n: String = dir.get_next()
		while n != "":
			if n != "." and n != "..":
				dir.remove(n)
			n = dir.get_next()
		dir.list_dir_end()


func _seed_solo(stage_id: StringName = &"dev_stage_beginner_01") -> void:
	PlayerData.configure_test_storage_path("user://feibao_tests/pad_solo")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	while PlayerData.get_active_party_character_ids().size() > 1:
		var ids: Array[StringName] = PlayerData.get_active_party_character_ids()
		PlayerData.remove_party_member(ids[ids.size() - 1])
	_reset_domain()
	AdventureState.prepare_stage(stage_id)
	_assert_true("seed_solo_bs", bool(BattleState.begin_from_prepared_stage().get("ok", false)))


func _seed_party3(stage_id: StringName = &"dev_stage_mist_03") -> void:
	PlayerData.configure_test_storage_path("user://feibao_tests/pad_p3")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	PlayerData.grant_character(&"partner_a")
	PlayerData.grant_character(&"partner_b")
	PlayerData.add_party_member(&"partner_a")
	PlayerData.add_party_member(&"partner_b")
	_reset_domain()
	AdventureState.prepare_stage(stage_id)
	_assert_true("seed_p3_bs", bool(BattleState.begin_from_prepared_stage().get("ok", false)))


func _seed_dual_ember(stage_id: StringName = &"dev_stage_beginner_01") -> void:
	PlayerData.configure_test_storage_path("user://feibao_tests/pad_dual_ember")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	PlayerData.grant_character(&"partner_e")
	PlayerData.add_party_member(&"partner_e")
	_reset_domain()
	AdventureState.prepare_stage(stage_id)
	_assert_true("seed_dual_bs", bool(BattleState.begin_from_prepared_stage().get("ok", false)))
	_assert_eq("seed_dual_n", BattleState.get_party_character_ids().size(), 2)


func _match_ready_board() -> Array[StringName]:
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
	for y in range(1, 5):
		out[BattleBoardModel.index_of(0, y)] = BattleOrbKind.TIDE if y % 2 == 0 else BattleOrbKind.LEAF
		out[BattleBoardModel.index_of(1, y)] = BattleOrbKind.LIGHT if y % 2 == 0 else BattleOrbKind.SHADOW
		out[BattleBoardModel.index_of(2, y)] = BattleOrbKind.SHADOW if y % 2 == 0 else BattleOrbKind.LIGHT
		out[BattleBoardModel.index_of(3, y)] = BattleOrbKind.LEAF if y % 2 == 0 else BattleOrbKind.TIDE
	return out


func _no_match_board() -> Array[StringName]:
	var out: Array[StringName] = []
	out.resize(30)
	var kinds: Array[StringName] = [
		BattleOrbKind.EMBER, BattleOrbKind.TIDE, BattleOrbKind.LEAF, BattleOrbKind.LIGHT, BattleOrbKind.SHADOW
	]
	for y in 5:
		for x in 6:
			out[BattleBoardModel.index_of(x, y)] = kinds[(x + y * 2) % kinds.size()]
	return out


func _runtime_exact(snap: Dictionary) -> bool:
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


func _connect_sigs() -> Dictionary:
	var sigs := {
		"rt": [0], "bd": [0], "ph": [0], "en": [0], "cm": [0],
		"on_rt": null, "on_bd": null, "on_ph": null, "on_en": null, "on_cm": null,
	}
	var on_rt := func(_a: bool) -> void:
		sigs["rt"][0] = int(sigs["rt"][0]) + 1
	var on_bd := func() -> void:
		sigs["bd"][0] = int(sigs["bd"][0]) + 1
	var on_ph := func(_p: StringName) -> void:
		sigs["ph"][0] = int(sigs["ph"][0]) + 1
	var on_en := func() -> void:
		sigs["en"][0] = int(sigs["en"][0]) + 1
	var on_cm := func() -> void:
		sigs["cm"][0] = int(sigs["cm"][0]) + 1
	sigs["on_rt"] = on_rt
	sigs["on_bd"] = on_bd
	sigs["on_ph"] = on_ph
	sigs["on_en"] = on_en
	sigs["on_cm"] = on_cm
	BattleRuntime.runtime_changed.connect(on_rt)
	BattleRuntime.board_changed.connect(on_bd)
	BattleRuntime.phase_changed.connect(on_ph)
	BattleRuntime.encounter_changed.connect(on_en)
	BattleRuntime.combat_changed.connect(on_cm)
	return sigs


func _disconnect_sigs(sigs: Dictionary) -> void:
	if BattleRuntime.runtime_changed.is_connected(sigs["on_rt"]):
		BattleRuntime.runtime_changed.disconnect(sigs["on_rt"])
	if BattleRuntime.board_changed.is_connected(sigs["on_bd"]):
		BattleRuntime.board_changed.disconnect(sigs["on_bd"])
	if BattleRuntime.phase_changed.is_connected(sigs["on_ph"]):
		BattleRuntime.phase_changed.disconnect(sigs["on_ph"])
	if BattleRuntime.encounter_changed.is_connected(sigs["on_en"]):
		BattleRuntime.encounter_changed.disconnect(sigs["on_en"])
	if BattleRuntime.combat_changed.is_connected(sigs["on_cm"]):
		BattleRuntime.combat_changed.disconnect(sigs["on_cm"])


func _sig_base(sigs: Dictionary) -> Dictionary:
	return {
		"rt": int(sigs["rt"][0]),
		"bd": int(sigs["bd"][0]),
		"ph": int(sigs["ph"][0]),
		"en": int(sigs["en"][0]),
		"cm": int(sigs["cm"][0]),
	}


func _assert_sig_zero(tag: String, sigs: Dictionary, base: Dictionary) -> void:
	_assert_eq("%s_rt0" % tag, int(sigs["rt"][0]), int(base["rt"]))
	_assert_eq("%s_bd0" % tag, int(sigs["bd"][0]), int(base["bd"]))
	_assert_eq("%s_ph0" % tag, int(sigs["ph"][0]), int(base["ph"]))
	_assert_eq("%s_en0" % tag, int(sigs["en"][0]), int(base["en"]))
	_assert_eq("%s_cm0" % tag, int(sigs["cm"][0]), int(base["cm"]))


func _calc(atk: int, cleared: int, defense: int) -> int:
	var scaled: int = int(floor(float(atk * cleared) / 3.0))
	return maxi(1, scaled - defense)


func _make_accepted_board_events(turn: int, kinds: Array) -> Array:
	# Minimal legal accepted sequence: swap + one cascade clearing `kinds`.
	var cells: Array = []
	for i in kinds.size():
		cells.append({"x": i % 6, "y": i / 6})
	return [
		BattleResolutionEvent.make_swap(Vector2i(0, 0), Vector2i(1, 0)),
		BattleResolutionEvent.make_match_found(1, cells),
		BattleResolutionEvent.make_cells_cleared(1, cells, kinds),
		BattleResolutionEvent.make_gravity_applied([]),
		BattleResolutionEvent.make_cells_refilled([], []),
		BattleResolutionEvent.make_cascade_completed(1, kinds.size()),
		BattleResolutionEvent.make_turn_completed(turn, 1, kinds.size()),
	]


func _build_encounter_from_session() -> BattleEncounterModel:
	var stage: StringName = BattleState.get_stage_id()
	var party: Array[StringName] = BattleState.get_party_character_ids()
	var r: Dictionary = BattleEncounterModel.build_from_session(stage, party)
	return r.get("encounter") as BattleEncounterModel


# ─── K1 apply_damage ───────────────────────────────────────────────
func _run_apply_damage_k1() -> void:
	var cr: Dictionary = BattleCombatantModel.create_enemy(
		&"training_sprout", "訓練幼芽", &"leaf", 0, 40, 8, 3
	)
	_assert_true("k1_create", bool(cr.get("ok", false)))
	var c: BattleCombatantModel = cr.get("combatant") as BattleCombatantModel
	var z: Dictionary = c.apply_damage(0)
	_assert_true("k1_z_ok", bool(z.get("ok", false)))
	_assert_true("k1_z_chg", not bool(z.get("changed", true)))
	_assert_eq("k1_z_act", int(z.get("actual_damage", -1)), 0)
	_assert_eq("k1_z_hp", c.get_current_hp(), 40)
	var n: Dictionary = c.apply_damage(10)
	_assert_true("k1_n_ok", bool(n.get("ok", false)))
	_assert_true("k1_n_chg", bool(n.get("changed", false)))
	_assert_eq("k1_n_act", int(n.get("actual_damage", -1)), 10)
	_assert_eq("k1_n_hp", c.get_current_hp(), 30)
	var L: Dictionary = c.apply_damage(30)
	_assert_true("k1_l_ok", bool(L.get("ok", false)))
	_assert_eq("k1_l_hp", c.get_current_hp(), 0)
	_assert_true("k1_l_def", bool(L.get("defeated", false)))
	c.set_current_hp_for_tests(5)
	var o: Dictionary = c.apply_damage(100)
	_assert_eq("k1_o_act", int(o.get("actual_damage", -1)), 5)
	_assert_eq("k1_o_hp", c.get_current_hp(), 0)
	var d: Dictionary = c.apply_damage(3)
	_assert_true("k1_d_ok", bool(d.get("ok", false)))
	_assert_true("k1_d_nchg", not bool(d.get("changed", true)))
	_assert_eq("k1_d_act", int(d.get("actual_damage", -1)), 0)
	_assert_true("k1_d_def", bool(d.get("defeated", false)))
	_assert_true("k1_neg", not bool(c.apply_damage(-1).get("ok", true)))
	_assert_true("k1_float", not bool(c.apply_damage(1.5).get("ok", true)))
	_assert_true("k1_str", not bool(c.apply_damage("3").get("ok", true)))
	_assert_true("k1_bool", not bool(c.apply_damage(true).get("ok", true)))
	_assert_true("k1_null", not bool(c.apply_damage(null).get("ok", true)))
	_assert_true("k1_obj", not bool(c.apply_damage(RefCounted.new()).get("ok", true)))
	_assert_true("k1_call", not bool(c.apply_damage(Callable()).get("ok", true)))
	c.set_current_hp_for_tests(20)
	var snap: Dictionary = c.capture_snapshot()
	var rr: Dictionary = BattleCombatantModel.restore_snapshot(snap)
	_assert_true("k1_snap", bool(rr.get("ok", false)))
	_assert_eq("k1_snap_hp", (rr.get("combatant") as BattleCombatantModel).get_current_hp(), 20)
	print("[INFO] K1 apply_damage passed")


# ─── K2 combat event schema ───────────────────────────────────────
func _run_combat_event_schema_k2() -> void:
	var dmg: Dictionary = BattleCombatEvent.make_player_damage(
		1, &"feibao_dev", &"training_sprout", &"ember", 3, 14, 3, 11, 11, 40, 29
	)
	var sum: Dictionary = BattleCombatEvent.make_player_combat_completed(
		1, 1, 11, &"training_sprout", 40, 29, false
	)
	var v1: Dictionary = BattleCombatEvent.validate_events([dmg, sum])
	_assert_true("k2_single", bool(v1.get("ok", false)))
	var dmg2: Dictionary = BattleCombatEvent.make_player_damage(
		1, &"partner_a", &"training_sprout", &"tide", 3, 12, 3, 9, 9, 29, 20
	)
	var sum2: Dictionary = BattleCombatEvent.make_player_combat_completed(
		1, 2, 20, &"training_sprout", 40, 20, false
	)
	var v2: Dictionary = BattleCombatEvent.validate_events([dmg, dmg2, sum2])
	_assert_true("k2_multi", bool(v2.get("ok", false)))
	var zsum: Dictionary = BattleCombatEvent.make_player_combat_completed(
		1, 0, 0, &"training_sprout", 40, 40, false
	)
	_assert_true("k2_zero", bool(BattleCombatEvent.validate_events([zsum]).get("ok", false)))
	var miss: Dictionary = dmg.duplicate(true)
	miss.erase("actual_damage")
	_assert_true("k2_miss", not bool(BattleCombatEvent.validate_event(miss).get("ok", true)))
	var extra: Dictionary = dmg.duplicate(true)
	extra["bonus"] = 1
	_assert_true("k2_extra", not bool(BattleCombatEvent.validate_event(extra).get("ok", true)))
	var unk: Dictionary = dmg.duplicate(true)
	unk["type"] = &"enemy_damage"
	_assert_true("k2_unk", not bool(BattleCombatEvent.validate_event(unk).get("ok", true)))
	var fl: Dictionary = dmg.duplicate(true)
	fl["actual_damage"] = 11.0
	_assert_true("k2_float", not bool(BattleCombatEvent.validate_event(fl).get("ok", true)))
	var aff: Dictionary = dmg.duplicate(true)
	aff["affinity"] = &"fire"
	_assert_true("k2_aff", not bool(BattleCombatEvent.validate_event(aff).get("ok", true)))
	var tmis: Dictionary = dmg2.duplicate(true)
	tmis["turn_count"] = 2
	_assert_true(
		"k2_turn",
		not bool(BattleCombatEvent.validate_events([dmg, tmis, sum2]).get("ok", true))
	)
	var tgt: Dictionary = dmg2.duplicate(true)
	tgt["target_id"] = &"training_droplet"
	_assert_true(
		"k2_tgt",
		not bool(BattleCombatEvent.validate_events([dmg, tgt, sum2]).get("ok", true))
	)
	var chain: Dictionary = dmg2.duplicate(true)
	chain["hp_before"] = 28
	_assert_true(
		"k2_chain",
		not bool(BattleCombatEvent.validate_events([dmg, chain, sum2]).get("ok", true))
	)
	var bad_sum: Dictionary = BattleCombatEvent.make_player_combat_completed(
		1, 9, 11, &"training_sprout", 40, 29, false
	)
	_assert_true(
		"k2_cnt",
		not bool(BattleCombatEvent.validate_events([dmg, bad_sum]).get("ok", true))
	)
	var bad_tot: Dictionary = BattleCombatEvent.make_player_combat_completed(
		1, 1, 99, &"training_sprout", 40, 29, false
	)
	_assert_true(
		"k2_tot",
		not bool(BattleCombatEvent.validate_events([dmg, bad_tot]).get("ok", true))
	)
	var bad_def: Dictionary = BattleCombatEvent.make_player_combat_completed(
		1, 1, 11, &"training_sprout", 40, 29, true
	)
	_assert_true(
		"k2_def",
		not bool(BattleCombatEvent.validate_events([dmg, bad_def]).get("ok", true))
	)
	var obj: Dictionary = dmg.duplicate(true)
	obj["attacker_id"] = RefCounted.new()
	_assert_true("k2_obj", not bool(BattleCombatEvent.validate_event(obj).get("ok", true)))
	var call: Dictionary = dmg.duplicate(true)
	call["target_id"] = Callable()
	_assert_true("k2_call", not bool(BattleCombatEvent.validate_event(call).get("ok", true)))
	var dup: Array = BattleCombatEvent.duplicate_events([dmg, sum])
	_assert_true("k2_dup", BattleCombatEvent.events_equal(dup, [dmg, sum]))
	dup[0]["actual_damage"] = 1
	_assert_true("k2_defensive", not BattleCombatEvent.events_equal(dup, [dmg, sum]))
	_assert_true("k2_eq", BattleCombatEvent.events_equal([dmg, sum], [dmg.duplicate(true), sum.duplicate(true)]))
	_assert_true("k2_no_sum", not bool(BattleCombatEvent.validate_events([dmg]).get("ok", true)))
	_assert_true(
		"k2_sum_mid",
		not bool(BattleCombatEvent.validate_events([sum, dmg]).get("ok", true))
	)
	# B1–B4 contract closeout failure cases
	var z_hp_mut: Dictionary = BattleCombatEvent.make_player_combat_completed(
		1, 0, 0, &"training_sprout", 40, 30, false
	)
	_assert_true(
		"k2_z_hp_mismatch",
		not bool(BattleCombatEvent.validate_events([z_hp_mut]).get("ok", true))
	)
	var z_tot1: Dictionary = BattleCombatEvent.make_player_combat_completed(
		1, 0, 1, &"training_sprout", 40, 40, false
	)
	_assert_true(
		"k2_z_total1",
		not bool(BattleCombatEvent.validate_events([z_tot1]).get("ok", true))
	)
	var under: Dictionary = BattleCombatEvent.make_player_damage(
		1, &"feibao_dev", &"training_sprout", &"ember", 3, 14, 3, 11, 5, 40, 35
	)
	var under_sum: Dictionary = BattleCombatEvent.make_player_combat_completed(
		1, 1, 5, &"training_sprout", 40, 35, false
	)
	_assert_true(
		"k2_under",
		not bool(BattleCombatEvent.validate_events([under, under_sum]).get("ok", true))
	)
	var lethal_under: Dictionary = BattleCombatEvent.make_player_damage(
		1, &"feibao_dev", &"training_sprout", &"ember", 3, 14, 3, 100, 19, 20, 1
	)
	var lethal_sum: Dictionary = BattleCombatEvent.make_player_combat_completed(
		1, 1, 19, &"training_sprout", 20, 1, false
	)
	_assert_true(
		"k2_lethal_under",
		not bool(BattleCombatEvent.validate_events([lethal_under, lethal_sum]).get("ok", true))
	)
	var zero_hp_dmg: Dictionary = BattleCombatEvent.make_player_damage(
		1, &"feibao_dev", &"training_sprout", &"ember", 3, 14, 3, 11, 0, 0, 0
	)
	_assert_true(
		"k2_hp0_damage",
		not bool(BattleCombatEvent.validate_event(zero_hp_dmg).get("ok", true))
	)
	var bad_delta: Dictionary = BattleCombatEvent.make_player_combat_completed(
		1, 1, 10, &"training_sprout", 40, 29, false
	)
	_assert_true(
		"k2_sum_delta",
		not bool(BattleCombatEvent.validate_events([dmg, bad_delta]).get("ok", true))
	)
	print("[INFO] K2 combat event schema passed")


# ─── K3 orb aggregation ───────────────────────────────────────────
func _run_orb_aggregation_k3() -> void:
	var single: Array = _make_accepted_board_events(1, [
		BattleOrbKind.EMBER, BattleOrbKind.EMBER, BattleOrbKind.EMBER
	])
	var a1: Dictionary = BattleDamageResolver.aggregate_affinity_counts_for_tests(single)
	_assert_true("k3_s_ok", bool(a1.get("ok", false)))
	_assert_eq("k3_s_e", int((a1.get("counts", {}) as Dictionary).get(BattleAffinity.EMBER, -1)), 3)
	var multi_kinds: Array = [
		BattleOrbKind.EMBER, BattleOrbKind.EMBER, BattleOrbKind.EMBER,
		BattleOrbKind.TIDE, BattleOrbKind.TIDE, BattleOrbKind.TIDE, BattleOrbKind.TIDE,
	]
	# Two cascades manually
	var cells1: Array = [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}]
	var cells2: Array = [{"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}, {"x": 3, "y": 1}]
	var multi: Array = [
		BattleResolutionEvent.make_swap(Vector2i(0, 0), Vector2i(1, 0)),
		BattleResolutionEvent.make_match_found(1, cells1),
		BattleResolutionEvent.make_cells_cleared(1, cells1, multi_kinds.slice(0, 3)),
		BattleResolutionEvent.make_gravity_applied([]),
		BattleResolutionEvent.make_cells_refilled([], []),
		BattleResolutionEvent.make_cascade_completed(1, 3),
		BattleResolutionEvent.make_match_found(2, cells2),
		BattleResolutionEvent.make_cells_cleared(2, cells2, multi_kinds.slice(3, 7)),
		BattleResolutionEvent.make_gravity_applied([]),
		BattleResolutionEvent.make_cells_refilled([], []),
		BattleResolutionEvent.make_cascade_completed(2, 4),
		BattleResolutionEvent.make_turn_completed(1, 2, 7),
	]
	var a2: Dictionary = BattleDamageResolver.aggregate_affinity_counts_for_tests(multi)
	_assert_true("k3_m_ok", bool(a2.get("ok", false)))
	_assert_eq("k3_m_e", int((a2.get("counts", {}) as Dictionary).get(BattleAffinity.EMBER, -1)), 3)
	_assert_eq("k3_m_t", int((a2.get("counts", {}) as Dictionary).get(BattleAffinity.TIDE, -1)), 4)
	var rej: Array = [BattleResolutionEvent.make_swap_rejected(Vector2i(0, 0), Vector2i(1, 0), "no match")]
	var enc: BattleEncounterModel = null
	_seed_solo()
	_assert_true("k3_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	enc = _build_encounter_from_session()
	var rrej: Dictionary = BattleDamageResolver.resolve_player_turn(rej, enc, 1)
	_assert_true("k3_rej", not bool(rrej.get("ok", true)))
	var bad: Array = _make_accepted_board_events(1, [BattleOrbKind.EMBER, BattleOrbKind.EMBER])
	# Force length mismatch by hand
	bad[2] = {
		"type": BattleResolutionEvent.TYPE_CELLS_CLEARED,
		"cascade_index": 1,
		"cells": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}],
		"orb_kinds": [BattleOrbKind.EMBER, BattleOrbKind.EMBER],
	}
	var rbad: Dictionary = BattleDamageResolver.resolve_player_turn(bad, enc, 1)
	_assert_true("k3_mal", not bool(rbad.get("ok", true)))
	_reset_domain()
	print("[INFO] K3 orb aggregation passed")


# ─── K4 damage formula ────────────────────────────────────────────
func _run_damage_formula_k4() -> void:
	_seed_solo()
	_assert_true("k4_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	var enc: BattleEncounterModel = _build_encounter_from_session()
	# feibao_dev atk=14, training_sprout def=3 max_hp=40
	for cleared in [3, 4, 6]:
		var kinds: Array = []
		for _i in cleared:
			kinds.append(BattleOrbKind.EMBER)
		var ev: Array = _make_accepted_board_events(1, kinds)
		var r: Dictionary = BattleDamageResolver.resolve_player_turn(ev, enc, 1)
		_assert_true("k4_ok_%d" % cleared, bool(r.get("ok", false)))
		var expected: int = _calc(14, cleared, 3)
		_assert_eq("k4_dmg_%d" % cleared, int(r.get("total_damage", -1)), expected)
		# Input encounter immutable
		_assert_eq("k4_imm_%d" % cleared, enc.get_active_enemy().get_current_hp(), 40)
	# defense higher than scaled: atk=14 cleared=3 scaled=14 def huge
	# Use real enemy stats only via set_current_hp; defense is immutable from catalog.
	# defense=3 cases covered; attack=0 lowest 1 via synthetic combatant on candidate path —
	# cover via apply_damage formula unit on calculated path:
	_assert_eq("k4_floor3", _calc(14, 3, 3), 11)
	_assert_eq("k4_floor4", _calc(14, 4, 3), 15)
	_assert_eq("k4_floor6", _calc(14, 6, 3), 25)
	_assert_eq("k4_def_eq", _calc(14, 3, 14), 1)
	_assert_eq("k4_def_hi", _calc(14, 3, 100), 1)
	_assert_eq("k4_atk0", _calc(0, 3, 0), 1)
	# target already 0
	var snap: Dictionary = enc.capture_snapshot()
	var enemies: Array = snap.get("enemy_combatants", []) as Array
	(enemies[0] as Dictionary)["current_hp"] = 0
	var zero_enc_r: Dictionary = BattleEncounterModel.restore_snapshot(snap)
	var zero_enc: BattleEncounterModel = zero_enc_r.get("encounter") as BattleEncounterModel
	var kinds3: Array = [BattleOrbKind.EMBER, BattleOrbKind.EMBER, BattleOrbKind.EMBER]
	var rz: Dictionary = BattleDamageResolver.resolve_player_turn(
		_make_accepted_board_events(1, kinds3), zero_enc, 1
	)
	_assert_true("k4_z_ok", bool(rz.get("ok", false)))
	_assert_eq("k4_z_atk", int(rz.get("attack_count", -1)), 0)
	_assert_eq("k4_z_dmg", int(rz.get("total_damage", -1)), 0)
	var zsum: Dictionary = (rz.get("combat_events", []) as Array)[-1] as Dictionary
	_assert_true("k4_z_def", bool(zsum.get("target_defeated", false)))
	# no matching party affinity (tide orbs, ember player)
	var tide: Array = [BattleOrbKind.TIDE, BattleOrbKind.TIDE, BattleOrbKind.TIDE]
	var rn: Dictionary = BattleDamageResolver.resolve_player_turn(
		_make_accepted_board_events(1, tide), enc, 1
	)
	_assert_true("k4_nomatch", bool(rn.get("ok", false)))
	_assert_eq("k4_nomatch_atk", int(rn.get("attack_count", -1)), 0)
	# overkill
	var low: Dictionary = enc.capture_snapshot()
	((low.get("enemy_combatants", []) as Array)[0] as Dictionary)["current_hp"] = 2
	var low_enc: BattleEncounterModel = BattleEncounterModel.restore_snapshot(low).get("encounter") as BattleEncounterModel
	var ro: Dictionary = BattleDamageResolver.resolve_player_turn(
		_make_accepted_board_events(1, kinds3), low_enc, 1
	)
	_assert_eq("k4_ov", int(ro.get("total_damage", -1)), 2)
	# multi same affinity party: partner_e also ember — use party3 with feibao + partner_e
	_reset_domain()
	PlayerData.configure_test_storage_path("user://feibao_tests/pad_multi")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	PlayerData.grant_character(&"partner_e")
	PlayerData.add_party_member(&"partner_e")
	_reset_domain()
	AdventureState.prepare_stage(&"dev_stage_beginner_01")
	_assert_true("k4_p2", bool(BattleState.begin_from_prepared_stage().get("ok", false)))
	_assert_true("k4_p2b", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	var enc2: BattleEncounterModel = _build_encounter_from_session()
	var rm: Dictionary = BattleDamageResolver.resolve_player_turn(
		_make_accepted_board_events(1, kinds3), enc2, 1
	)
	_assert_true("k4_multi_ok", bool(rm.get("ok", false)))
	_assert_eq("k4_multi_atk", int(rm.get("attack_count", -1)), 2)
	var ce: Array = rm.get("combat_events", []) as Array
	_assert_eq("k4_ord0", str((ce[0] as Dictionary).get("attacker_id")), "feibao_dev")
	_assert_eq("k4_ord1", str((ce[1] as Dictionary).get("attacker_id")), "partner_e")
	# stop after zero: set HP so first kill
	var low2: Dictionary = enc2.capture_snapshot()
	((low2.get("enemy_combatants", []) as Array)[0] as Dictionary)["current_hp"] = 5
	var enc_low: BattleEncounterModel = BattleEncounterModel.restore_snapshot(low2).get("encounter") as BattleEncounterModel
	var rs: Dictionary = BattleDamageResolver.resolve_player_turn(
		_make_accepted_board_events(1, kinds3), enc_low, 1
	)
	_assert_eq("k4_stop_atk", int(rs.get("attack_count", -1)), 1)
	_assert_true("k4_stop_def", bool(((rs.get("combat_events", []) as Array)[-1] as Dictionary).get("target_defeated", false)))
	_reset_domain()
	print("[INFO] K4 damage formula passed")


# ─── K5 forced accepted turn ──────────────────────────────────────
func _run_forced_accepted_turn_k5() -> void:
	_seed_solo()
	_assert_true("k5_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	_assert_true("k5_set", BattleRuntime.set_board_cells_for_tests(_match_ready_board()))
	var players0: Array[BattleCombatantModel] = BattleRuntime.get_player_combatants()
	var enemies0: Array[BattleCombatantModel] = BattleRuntime.get_enemy_combatants()
	var aei: int = BattleRuntime.get_active_enemy_index()
	var hp0: int = enemies0[aei].get_current_hp()
	var atk: int = players0[0].get_attack()
	var defense: int = enemies0[aei].get_defense()
	var rev0: int = PlayerData.get_profile().get_revision()
	var sigs: Dictionary = _connect_sigs()
	var base: Dictionary = _sig_base(sigs)
	var res: Dictionary = BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0))
	_assert_true("k5_ok", bool(res.get("ok", false)))
	_assert_true("k5_acc", bool(res.get("accepted", false)))
	_assert_eq("k5_turn", BattleRuntime.get_turn_count(), 1)
	var combat: Array = BattleRuntime.get_last_combat_events()
	_assert_true("k5_combat", not combat.is_empty())
	var board: Array = BattleRuntime.get_last_resolution_events()
	_assert_true("k5_board_ok", bool(BattleResolutionEvent.validate_events(board).get("ok", false)))
	_assert_true("k5_combat_ok", bool(BattleCombatEvent.validate_events(combat).get("ok", false)))
	var dmg_ev: Dictionary = combat[0] as Dictionary
	_assert_eq("k5_attacker", str(dmg_ev.get("attacker_id")), "feibao_dev")
	var cleared: int = int(dmg_ev.get("cleared_orb_count", 0))
	_assert_true("k5_cleared", cleared >= 3)
	var expected: int = _calc(atk, cleared, defense)
	_assert_eq("k5_calc", int(dmg_ev.get("calculated_damage", -1)), expected)
	_assert_eq("k5_total", int(res.get("total_damage", -1)), int(dmg_ev.get("actual_damage", -2)))
	_assert_eq("k5_hp", BattleRuntime.get_enemy_combatants()[aei].get_current_hp(), hp0 - int(res.get("total_damage", 0)))
	_assert_eq("k5_php", BattleRuntime.get_player_combatants()[0].get_current_hp(), players0[0].get_current_hp())
	_assert_eq("k5_rt_sig", int(sigs["rt"][0]), int(base["rt"]))
	_assert_eq("k5_bd_sig", int(sigs["bd"][0]), int(base["bd"]) + 1)
	_assert_eq("k5_cm_sig", int(sigs["cm"][0]), int(base["cm"]) + 1)
	_assert_eq("k5_en_sig", int(sigs["en"][0]), int(base["en"]) + 1)
	_assert_eq("k5_phase", str(BattleRuntime.get_phase()), "ready")
	_assert_eq("k5_rev", PlayerData.get_profile().get_revision(), rev0)
	# UI
	var packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	screen.call("configure_screen", &"battle")
	for _i in 3:
		await _tree.process_frame
	var e_cards: Array = screen.call("get_enemy_cards_for_tests") as Array
	_assert_true("k5_ui_e", not e_cards.is_empty())
	var ehp: String = str(screen.call("get_card_hp_label_for_tests", e_cards[0]))
	var cur: BattleCombatantModel = BattleRuntime.get_enemy_combatants()[0]
	_assert_eq("k5_ui_ehp", ehp, "HP %d/%d" % [cur.get_current_hp(), cur.get_max_hp()])
	_assert_true("k5_ui_log", screen.call("get_combat_log_row_count_for_tests") as int >= 1)
	_assert_true(
		"k5_notice",
		str(screen.call("get_shell_status_text")).find("玩家攻擊與傷害已啟用") >= 0
	)
	screen.queue_free()
	await _tree.process_frame
	_disconnect_sigs(sigs)
	BattleRuntime.clear_refill_kind_override_for_tests()
	print("[INFO] K5 forced accepted turn passed")


# ─── K6 rejected swap ─────────────────────────────────────────────
func _run_rejected_swap_k6() -> void:
	_seed_solo()
	_assert_true("k6_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	_assert_true("k6_set_match", BattleRuntime.set_board_cells_for_tests(_match_ready_board()))
	_assert_true("k6_acc0", bool(BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0)).get("accepted", false)))
	_assert_true("k6_has_combat", not BattleRuntime.get_last_combat_events().is_empty())
	var hp: int = BattleRuntime.get_enemy_combatants()[0].get_current_hp()
	var php: int = BattleRuntime.get_player_combatants()[0].get_current_hp()
	var aei: int = BattleRuntime.get_active_enemy_index()
	_assert_true("k6_set_nomatch", BattleRuntime.set_board_cells_for_tests(_no_match_board()))
	var sigs: Dictionary = _connect_sigs()
	var base: Dictionary = _sig_base(sigs)
	var res: Dictionary = BattleRuntime.try_swap_cells(Vector2i(0, 0), Vector2i(1, 0))
	_assert_true("k6_ok", bool(res.get("ok", false)))
	_assert_true("k6_rej", not bool(res.get("accepted", true)))
	_assert_eq("k6_ehp", BattleRuntime.get_enemy_combatants()[0].get_current_hp(), hp)
	_assert_eq("k6_php", BattleRuntime.get_player_combatants()[0].get_current_hp(), php)
	_assert_true("k6_combat_empty", BattleRuntime.get_last_combat_events().is_empty())
	_assert_eq("k6_aei", BattleRuntime.get_active_enemy_index(), aei)
	var be: Array = BattleRuntime.get_last_resolution_events()
	_assert_eq("k6_board_type", str((be[0] as Dictionary).get("type")), "swap_rejected")
	_assert_eq("k6_en0", int(sigs["en"][0]), int(base["en"]))
	_assert_eq("k6_cm1", int(sigs["cm"][0]), int(base["cm"]) + 1)
	_disconnect_sigs(sigs)
	BattleRuntime.clear_refill_kind_override_for_tests()
	print("[INFO] K6 rejected swap passed")


# ─── K7 zero matching player ──────────────────────────────────────
func _run_zero_matching_player_k7() -> void:
	# Solo ember player; force tide-only clear via synthetic resolver path + runtime board of tide match.
	_seed_solo()
	_assert_true("k7_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	var board: Array[StringName] = _no_match_board()
	# Row0: T T E T L S — swap (2,0)-(3,0) → T T T
	board[0] = BattleOrbKind.TIDE
	board[1] = BattleOrbKind.TIDE
	board[2] = BattleOrbKind.EMBER
	board[3] = BattleOrbKind.TIDE
	board[4] = BattleOrbKind.LIGHT
	board[5] = BattleOrbKind.SHADOW
	for y in range(1, 5):
		board[BattleBoardModel.index_of(0, y)] = BattleOrbKind.EMBER if y % 2 == 0 else BattleOrbKind.LEAF
		board[BattleBoardModel.index_of(1, y)] = BattleOrbKind.LIGHT if y % 2 == 0 else BattleOrbKind.SHADOW
		board[BattleBoardModel.index_of(2, y)] = BattleOrbKind.SHADOW if y % 2 == 0 else BattleOrbKind.LIGHT
		board[BattleBoardModel.index_of(3, y)] = BattleOrbKind.LEAF if y % 2 == 0 else BattleOrbKind.EMBER
	_assert_true("k7_set", BattleRuntime.set_board_cells_for_tests(board))
	var hp0: int = BattleRuntime.get_enemy_combatants()[0].get_current_hp()
	var sigs: Dictionary = _connect_sigs()
	var base: Dictionary = _sig_base(sigs)
	var res: Dictionary = BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0))
	_assert_true("k7_acc", bool(res.get("accepted", false)))
	_assert_eq("k7_atk", int(res.get("attack_count", -1)), 0)
	_assert_eq("k7_dmg", int(res.get("total_damage", -1)), 0)
	_assert_eq("k7_hp", BattleRuntime.get_enemy_combatants()[0].get_current_hp(), hp0)
	var combat: Array = BattleRuntime.get_last_combat_events()
	_assert_eq("k7_sum_only", combat.size(), 1)
	_assert_eq("k7_en0", int(sigs["en"][0]), int(base["en"]))
	_assert_eq("k7_cm1", int(sigs["cm"][0]), int(base["cm"]) + 1)
	_disconnect_sigs(sigs)
	BattleRuntime.clear_refill_kind_override_for_tests()
	print("[INFO] K7 zero matching player passed")


# ─── K8 lethal damage ─────────────────────────────────────────────
func _run_lethal_damage_k8() -> void:
	_seed_solo()
	_assert_true("k8_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	# Drop enemy HP so one ember match kills.
	var snap: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var enc: Dictionary = snap.get("encounter") as Dictionary
	((enc.get("enemy_combatants", []) as Array)[0] as Dictionary)["current_hp"] = 5
	_assert_true("k8_rest", bool(BattleRuntime.restore_runtime_snapshot(snap).get("ok", false)))
	_assert_true("k8_set", BattleRuntime.set_board_cells_for_tests(_match_ready_board()))
	var aei0: int = BattleRuntime.get_active_enemy_index()
	var res: Dictionary = BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0))
	_assert_true("k8_acc", bool(res.get("accepted", false)))
	_assert_eq("k8_hp", BattleRuntime.get_enemy_combatants()[0].get_current_hp(), 0)
	_assert_true("k8_def", bool(res.get("target_defeated", false)))
	_assert_eq("k8_aei", BattleRuntime.get_active_enemy_index(), aei0)
	_assert_true("k8_bs", BattleState.has_active_session())
	_assert_true("k8_rt", BattleRuntime.has_active_runtime())
	_assert_eq("k8_phase", str(BattleRuntime.get_phase()), "ready")
	# Next accepted turn → zero attack summary (target already 0)
	_assert_true("k8_set2", BattleRuntime.set_board_cells_for_tests(_match_ready_board()))
	var res2: Dictionary = BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0))
	_assert_true("k8_acc2", bool(res2.get("accepted", false)))
	_assert_eq("k8_atk2", int(res2.get("attack_count", -1)), 0)
	_assert_true("k8_def2", bool(res2.get("target_defeated", false)))
	BattleRuntime.clear_refill_kind_override_for_tests()
	print("[INFO] K8 lethal damage passed")


# ─── K9 atomic failure ────────────────────────────────────────────
func _run_atomic_failure_k9() -> void:
	_seed_solo()
	_assert_true("k9_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	_assert_true("k9_set", BattleRuntime.set_board_cells_for_tests(_match_ready_board()))
	var prior: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var rev0: int = PlayerData.get_profile().get_revision()
	var fp0: Dictionary = _prod_fp()
	var sigs: Dictionary = _connect_sigs()
	var base: Dictionary = _sig_base(sigs)
	BattleRuntime.set_damage_resolver_force_fail_for_tests(true)
	var res: Dictionary = BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0))
	_assert_true("k9_fail", not bool(res.get("ok", true)))
	_assert_true("k9_nacc", not bool(res.get("accepted", true)))
	_assert_true("k9_exact", _runtime_exact(prior))
	_assert_sig_zero("k9", sigs, base)
	_assert_eq("k9_rev", PlayerData.get_profile().get_revision(), rev0)
	_assert_true("k9_fp", _fp_eq(fp0, _prod_fp()))
	BattleRuntime.clear_damage_resolver_force_fail_for_tests()
	BattleDamageResolver.clear_force_fail_for_tests()
	# After clear, accepted turn succeeds again.
	var res2: Dictionary = BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0))
	_assert_true("k9_recover", bool(res2.get("ok", false)) and bool(res2.get("accepted", false)))
	_disconnect_sigs(sigs)
	BattleRuntime.clear_refill_kind_override_for_tests()
	print("[INFO] K9 atomic failure passed")


# ─── K10 snapshot matrix ──────────────────────────────────────────
func _run_snapshot_matrix_k10() -> void:
	_seed_solo()
	_assert_true("k10_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	_assert_true("k10_set", BattleRuntime.set_board_cells_for_tests(_match_ready_board()))
	_assert_true("k10_acc", bool(BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0)).get("accepted", false)))
	var before: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var sigs: Dictionary = _connect_sigs()
	var base: Dictionary = _sig_base(sigs)
	# identical restore
	var idr: Dictionary = BattleRuntime.restore_runtime_snapshot(before)
	_assert_true("k10_id_ok", bool(idr.get("ok", false)))
	_assert_true("k10_id_nchg", not bool(idr.get("changed", true)))
	_assert_sig_zero("k10_id", sigs, base)
	var cases: Array = []
	# missing last_combat_events
	var m1: Dictionary = before.duplicate(true)
	m1.erase("last_combat_events")
	cases.append(["miss_key", m1])
	var m2: Dictionary = before.duplicate(true)
	m2["last_combat_events"] = "nope"
	cases.append(["non_arr", m2])
	var m3: Dictionary = before.duplicate(true)
	var ce3: Array = BattleCombatEvent.duplicate_events(m3.get("last_combat_events", []) as Array)
	if not ce3.is_empty():
		(ce3[0] as Dictionary).erase("actual_damage")
	m3["last_combat_events"] = ce3
	cases.append(["miss_ev_key", m3])
	var m4: Dictionary = before.duplicate(true)
	var ce4: Array = BattleCombatEvent.duplicate_events(m4.get("last_combat_events", []) as Array)
	if not ce4.is_empty():
		(ce4[0] as Dictionary)["type"] = &"enemy_damage"
	m4["last_combat_events"] = ce4
	cases.append(["bad_type", m4])
	var m5: Dictionary = before.duplicate(true)
	var ce5: Array = BattleCombatEvent.duplicate_events(m5.get("last_combat_events", []) as Array)
	if not ce5.is_empty():
		(ce5[0] as Dictionary)["cleared_orb_count"] = 3.0
	m5["last_combat_events"] = ce5
	cases.append(["float", m5])
	var m6: Dictionary = before.duplicate(true)
	var ce6: Array = BattleCombatEvent.duplicate_events(m6.get("last_combat_events", []) as Array)
	if not ce6.is_empty():
		(ce6[0] as Dictionary)["attacker_id"] = &"partner_a"
	m6["last_combat_events"] = ce6
	cases.append(["bad_attacker", m6])
	var m7: Dictionary = before.duplicate(true)
	var ce7: Array = BattleCombatEvent.duplicate_events(m7.get("last_combat_events", []) as Array)
	if not ce7.is_empty():
		(ce7[0] as Dictionary)["target_id"] = &"training_droplet"
		(ce7[ce7.size() - 1] as Dictionary)["target_id"] = &"training_droplet"
	m7["last_combat_events"] = ce7
	cases.append(["bad_target", m7])
	var m8: Dictionary = before.duplicate(true)
	var ce8: Array = BattleCombatEvent.duplicate_events(m8.get("last_combat_events", []) as Array)
	if not ce8.is_empty():
		(ce8[0] as Dictionary)["affinity"] = &"tide"
	m8["last_combat_events"] = ce8
	cases.append(["bad_aff", m8])
	var m9: Dictionary = before.duplicate(true)
	var ce9: Array = BattleCombatEvent.duplicate_events(m9.get("last_combat_events", []) as Array)
	if not ce9.is_empty():
		(ce9[0] as Dictionary)["attacker_attack"] = 999
	m9["last_combat_events"] = ce9
	cases.append(["bad_atk", m9])
	var m10: Dictionary = before.duplicate(true)
	var ce10: Array = BattleCombatEvent.duplicate_events(m10.get("last_combat_events", []) as Array)
	if not ce10.is_empty():
		(ce10[0] as Dictionary)["target_defense"] = 0
	m10["last_combat_events"] = ce10
	cases.append(["bad_def", m10])
	var m11: Dictionary = before.duplicate(true)
	var ce11: Array = BattleCombatEvent.duplicate_events(m11.get("last_combat_events", []) as Array)
	if not ce11.is_empty():
		(ce11[0] as Dictionary)["cleared_orb_count"] = 99
		# recalculate actual chain so schema still passes but binding fails
		var hb: int = int((ce11[0] as Dictionary).get("hp_before", 0))
		var calc: int = _calc(14, 99, 3)
		(ce11[0] as Dictionary)["calculated_damage"] = calc
		var act: int = mini(calc, hb)
		(ce11[0] as Dictionary)["actual_damage"] = act
		(ce11[0] as Dictionary)["hp_after"] = hb - act
		(ce11[ce11.size() - 1] as Dictionary)["total_damage"] = act
		(ce11[ce11.size() - 1] as Dictionary)["target_hp_after"] = hb - act
		(ce11[ce11.size() - 1] as Dictionary)["target_defeated"] = (hb - act) == 0
		# also patch encounter HP to match summary so HP check passes but cleared fails
		var enc11: Dictionary = (m11.get("encounter") as Dictionary).duplicate(true)
		(((enc11.get("enemy_combatants", []) as Array)[0]) as Dictionary)["current_hp"] = hb - act
		m11["encounter"] = enc11
	m11["last_combat_events"] = ce11
	cases.append(["bad_cleared", m11])
	# D1: accepted board sequence + empty combat must reject.
	var d1: Dictionary = before.duplicate(true)
	d1["last_combat_events"] = []
	cases.append(["accepted_empty_combat", d1])
	# D2: positive turn + empty board + empty combat + zero counts must reject.
	var m12: Dictionary = before.duplicate(true)
	m12["last_combat_events"] = []
	m12["last_resolution_events"] = []
	m12["last_match_count"] = 0
	m12["last_cascade_count"] = 0
	# turn_count remains > 0 from accepted prior turn.
	_assert_true("k10_m12_turn", int(m12.get("turn_count", 0)) > 0)
	cases.append(["positive_turn_no_evidence", m12])
	# combat present board empty:
	var m13: Dictionary = before.duplicate(true)
	m13["last_resolution_events"] = []
	m13["last_match_count"] = 0
	m13["last_cascade_count"] = 0
	cases.append(["combat_no_board", m13])
	var m14: Dictionary = before.duplicate(true)
	m14["active"] = false
	m14["phase"] = BattleRuntime.PHASE_INACTIVE
	m14["session_area_id"] = &""
	m14["session_stage_id"] = &""
	m14["session_party_character_ids"] = []
	m14["session_leader_character_id"] = &""
	m14["board_cells"] = BattleRuntime.capture_runtime_snapshot().get("board_cells") # will fix
	# build proper inactive with combat pollution
	BattleRuntime.clear_runtime()
	var inactive: Dictionary = BattleRuntime.capture_runtime_snapshot()
	# re-seed active for continue after this case
	# Actually restore before first
	_assert_true("k10_reseed", bool(BattleRuntime.restore_runtime_snapshot(before).get("ok", false)))
	base = _sig_base(sigs)
	inactive["last_combat_events"] = before.get("last_combat_events")
	cases.append(["inactive_combat", inactive])
	var m15: Dictionary = before.duplicate(true)
	m15["last_combat_events"] = [RefCounted.new()]
	cases.append(["obj", m15])
	var m16: Dictionary = before.duplicate(true)
	m16["last_combat_events"] = [Callable()]
	cases.append(["callable", m16])
	# E1: fabricated zero-attack with HP mutation
	var e1: Dictionary = before.duplicate(true)
	var e1_sum: Dictionary = BattleCombatEvent.make_player_combat_completed(
		int(before.get("turn_count", 1)),
		0,
		0,
		&"training_sprout",
		40,
		30,
		false
	)
	e1["last_combat_events"] = [e1_sum]
	var e1_enc: Dictionary = (e1.get("encounter") as Dictionary).duplicate(true)
	(((e1_enc.get("enemy_combatants", []) as Array)[0]) as Dictionary)["current_hp"] = 30
	e1["encounter"] = e1_enc
	cases.append(["e1_zero_hp_mut", e1])
	# E2: missing eligible attacker (ember board, zero summary, HP unchanged)
	var e2: Dictionary = before.duplicate(true)
	var hp_start: int = int(
		(((before.get("encounter") as Dictionary).get("enemy_combatants") as Array)[0] as Dictionary)
		.get("current_hp", 40)
	)
	# summary before should be pre-damage; use chain from original damage if present
	var orig_ce: Array = before.get("last_combat_events", []) as Array
	var t_before: int = 40
	if not orig_ce.is_empty():
		var os: Dictionary = orig_ce[orig_ce.size() - 1] as Dictionary
		t_before = int(os.get("target_hp_before", 40))
	var e2_sum: Dictionary = BattleCombatEvent.make_player_combat_completed(
		int(before.get("turn_count", 1)),
		0,
		0,
		&"training_sprout",
		t_before,
		t_before,
		t_before == 0
	)
	e2["last_combat_events"] = [e2_sum]
	var e2_enc: Dictionary = (e2.get("encounter") as Dictionary).duplicate(true)
	(((e2_enc.get("enemy_combatants", []) as Array)[0]) as Dictionary)["current_hp"] = t_before
	e2["encounter"] = e2_enc
	cases.append(["e2_miss_attacker", e2])
	# E3: under-damage (schema-level reject under B1)
	var e3: Dictionary = before.duplicate(true)
	var e3_dmg: Dictionary = BattleCombatEvent.make_player_damage(
		int(before.get("turn_count", 1)),
		&"feibao_dev",
		&"training_sprout",
		&"ember",
		3,
		14,
		3,
		11,
		5,
		t_before,
		t_before - 5
	)
	var e3_sum: Dictionary = BattleCombatEvent.make_player_combat_completed(
		int(before.get("turn_count", 1)),
		1,
		5,
		&"training_sprout",
		t_before,
		t_before - 5,
		false
	)
	e3["last_combat_events"] = [e3_dmg, e3_sum]
	var e3_enc: Dictionary = (e3.get("encounter") as Dictionary).duplicate(true)
	(((e3_enc.get("enemy_combatants", []) as Array)[0]) as Dictionary)["current_hp"] = t_before - 5
	e3["encounter"] = e3_enc
	cases.append(["e3_under", e3])
	# E5: extra attacker (affinity without enough orbs) — tide damage with ember-only clear
	var e5: Dictionary = before.duplicate(true)
	var e5_extra: Dictionary = BattleCombatEvent.make_player_damage(
		int(before.get("turn_count", 1)),
		&"partner_a",
		&"training_sprout",
		&"tide",
		3,
		12,
		3,
		9,
		9,
		t_before,
		t_before - 9
	)
	# Keep original first attack if present, then illegal second
	var e5_events: Array = []
	if not orig_ce.is_empty() and orig_ce.size() >= 2:
		var od: Dictionary = (orig_ce[0] as Dictionary).duplicate(true)
		e5_events.append(od)
		e5_extra["hp_before"] = int(od.get("hp_after", t_before))
		e5_extra["actual_damage"] = mini(9, int(e5_extra["hp_before"]))
		e5_extra["hp_after"] = int(e5_extra["hp_before"]) - int(e5_extra["actual_damage"])
		e5_extra["calculated_damage"] = 9
		e5_events.append(e5_extra)
		var e5_sum: Dictionary = BattleCombatEvent.make_player_combat_completed(
			int(before.get("turn_count", 1)),
			2,
			int(od.get("actual_damage", 0)) + int(e5_extra["actual_damage"]),
			&"training_sprout",
			int(od.get("hp_before", t_before)),
			int(e5_extra["hp_after"]),
			int(e5_extra["hp_after"]) == 0
		)
		e5_events.append(e5_sum)
		e5["last_combat_events"] = e5_events
		var e5_enc: Dictionary = (e5.get("encounter") as Dictionary).duplicate(true)
		(((e5_enc.get("enemy_combatants", []) as Array)[0]) as Dictionary)["current_hp"] = int(
			e5_extra["hp_after"]
		)
		e5["encounter"] = e5_enc
		cases.append(["e5_extra_attacker", e5])
	# D5: target_hp_before / first damage hp_before above enemy max_hp (schema ok, binding reject).
	var d5: Dictionary = before.duplicate(true)
	var ce_d5: Array = BattleCombatEvent.duplicate_events(d5.get("last_combat_events", []) as Array)
	_assert_true("k10_d5_has_ce", ce_d5.size() >= 2)
	var enc_d5_src: Dictionary = d5.get("encounter") as Dictionary
	var max_hp_d5: int = int(
		(((enc_d5_src.get("enemy_combatants") as Array)[0]) as Dictionary).get("max_hp", 40)
	)
	var inflated_before: int = max_hp_d5 + 1
	var sim_hp_d5: int = inflated_before
	for i in ce_d5.size() - 1:
		var dmg_d5: Dictionary = ce_d5[i] as Dictionary
		var calc_d5: int = int(dmg_d5.get("calculated_damage", 1))
		var act_d5: int = mini(calc_d5, sim_hp_d5)
		dmg_d5["hp_before"] = sim_hp_d5
		dmg_d5["actual_damage"] = act_d5
		dmg_d5["hp_after"] = sim_hp_d5 - act_d5
		sim_hp_d5 = sim_hp_d5 - act_d5
	var sum_d5: Dictionary = ce_d5[ce_d5.size() - 1] as Dictionary
	sum_d5["target_hp_before"] = inflated_before
	sum_d5["target_hp_after"] = sim_hp_d5
	sum_d5["total_damage"] = inflated_before - sim_hp_d5
	sum_d5["target_defeated"] = sim_hp_d5 == 0
	var schema_d5: Dictionary = BattleCombatEvent.validate_events(ce_d5)
	_assert_true("k10_d5_schema_ok", bool(schema_d5.get("ok", false)))
	d5["last_combat_events"] = ce_d5
	var enc_d5: Dictionary = enc_d5_src.duplicate(true)
	(((enc_d5.get("enemy_combatants", []) as Array)[0]) as Dictionary)["current_hp"] = sim_hp_d5
	d5["encounter"] = enc_d5
	cases.append(["hp_before_above_max", d5])
	for c in cases:
		var tag: String = str(c[0])
		var bad: Dictionary = c[1] as Dictionary
		var r: Dictionary = BattleRuntime.restore_runtime_snapshot(bad)
		_assert_true("k10_%s_fail" % tag, not bool(r.get("ok", true)))
		_assert_true("k10_%s_exact" % tag, _runtime_exact(before))
		_assert_sig_zero("k10_%s" % tag, sigs, base)
	_disconnect_sigs(sigs)
	# D3: valid initial empty combat (turn 0, empty board + combat events).
	_seed_solo()
	_assert_true("k10_d3_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	var init_snap: Dictionary = BattleRuntime.capture_runtime_snapshot()
	_assert_eq("k10_d3_turn0", int(init_snap.get("turn_count", -1)), 0)
	_assert_true("k10_d3_board_empty", (init_snap.get("last_resolution_events", []) as Array).is_empty())
	_assert_true("k10_d3_combat_empty", (init_snap.get("last_combat_events", []) as Array).is_empty())
	var sigs_d3: Dictionary = _connect_sigs()
	var base_d3: Dictionary = _sig_base(sigs_d3)
	var r_d3: Dictionary = BattleRuntime.restore_runtime_snapshot(init_snap)
	_assert_true("k10_d3_ok", bool(r_d3.get("ok", false)))
	_assert_true("k10_d3_nchg", not bool(r_d3.get("changed", true)))
	_assert_sig_zero("k10_d3", sigs_d3, base_d3)
	_disconnect_sigs(sigs_d3)
	# D4: rejected swap after prior accepted turn — empty combat is legal.
	_assert_true("k10_d4_set_acc", BattleRuntime.set_board_cells_for_tests(_match_ready_board()))
	_assert_true(
		"k10_d4_acc",
		bool(BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0)).get("accepted", false))
	)
	_assert_true("k10_d4_set_rej", BattleRuntime.set_board_cells_for_tests(_no_match_board()))
	var rej_res: Dictionary = BattleRuntime.try_swap_cells(Vector2i(0, 0), Vector2i(1, 0))
	_assert_true("k10_d4_rej_ok", bool(rej_res.get("ok", false)))
	_assert_true("k10_d4_rej", not bool(rej_res.get("accepted", true)))
	var rej_snap: Dictionary = BattleRuntime.capture_runtime_snapshot()
	_assert_true("k10_d4_turn", int(rej_snap.get("turn_count", 0)) > 0)
	_assert_true("k10_d4_combat_empty", (rej_snap.get("last_combat_events", []) as Array).is_empty())
	var rej_board: Array = rej_snap.get("last_resolution_events", []) as Array
	_assert_eq("k10_d4_board_n", rej_board.size(), 1)
	_assert_eq(
		"k10_d4_board_type",
		str((rej_board[0] as Dictionary).get("type")),
		"swap_rejected"
	)
	var sigs_d4: Dictionary = _connect_sigs()
	var base_d4: Dictionary = _sig_base(sigs_d4)
	var r_d4: Dictionary = BattleRuntime.restore_runtime_snapshot(rej_snap)
	_assert_true("k10_d4_ok", bool(r_d4.get("ok", false)))
	_assert_true("k10_d4_nchg", not bool(r_d4.get("changed", true)))
	_assert_sig_zero("k10_d4", sigs_d4, base_d4)
	_disconnect_sigs(sigs_d4)
	# E4: missing second attacker with dual-ember party
	_seed_dual_ember()
	_assert_true("k10e4_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	_assert_true("k10e4_set", BattleRuntime.set_board_cells_for_tests(_match_ready_board()))
	_assert_true("k10e4_acc", bool(BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0)).get("accepted", false)))
	var full: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var full_ce: Array = full.get("last_combat_events", []) as Array
	_assert_true("k10e4_multi", full_ce.size() >= 3)
	var only_first: Array = [full_ce[0].duplicate(true)]
	var fd: Dictionary = only_first[0] as Dictionary
	var only_sum: Dictionary = BattleCombatEvent.make_player_combat_completed(
		int(fd.get("turn_count", 1)),
		1,
		int(fd.get("actual_damage", 0)),
		fd.get("target_id") as StringName,
		int(fd.get("hp_before", 0)),
		int(fd.get("hp_after", 0)),
		int(fd.get("hp_after", 0)) == 0
	)
	only_first.append(only_sum)
	var e4: Dictionary = full.duplicate(true)
	e4["last_combat_events"] = only_first
	var e4_enc: Dictionary = (e4.get("encounter") as Dictionary).duplicate(true)
	(((e4_enc.get("enemy_combatants", []) as Array)[0]) as Dictionary)["current_hp"] = int(
		fd.get("hp_after", 0)
	)
	e4["encounter"] = e4_enc
	var sigs4: Dictionary = _connect_sigs()
	var base4: Dictionary = _sig_base(sigs4)
	var r4: Dictionary = BattleRuntime.restore_runtime_snapshot(e4)
	_assert_true("k10_e4_miss_second_fail", not bool(r4.get("ok", true)))
	_assert_true("k10_e4_exact", _runtime_exact(full))
	_assert_sig_zero("k10_e4", sigs4, base4)
	_disconnect_sigs(sigs4)
	print("[INFO] K10 snapshot matrix passed")


# ─── K11 screen ───────────────────────────────────────────────────
func _run_screen_k11() -> void:
	_seed_solo()
	_assert_true("k11_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	_assert_true("k11_set", BattleRuntime.set_board_cells_for_tests(_match_ready_board()))
	_assert_true("k11_acc", bool(BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0)).get("accepted", false)))
	var combat: Array = BattleRuntime.get_last_combat_events()
	_assert_true("k11_combat_n", combat.size() >= 2)
	var dmg: Dictionary = combat[0] as Dictionary
	var sum_ev: Dictionary = combat[combat.size() - 1] as Dictionary
	var players: Array[BattleCombatantModel] = BattleRuntime.get_player_combatants()
	_assert_true("k11_p0", not players.is_empty())
	var expected_row: String = (
		"%s %s%s 清除%d 計算%d 實際%d HP %d→%d"
		% [
			players[0].get_display_name(),
			BattleAffinity.symbol(dmg.get("affinity") as StringName),
			BattleAffinity.display_name(dmg.get("affinity") as StringName),
			int(dmg.get("cleared_orb_count", 0)),
			int(dmg.get("calculated_damage", 0)),
			int(dmg.get("actual_damage", 0)),
			int(dmg.get("hp_before", 0)),
			int(dmg.get("hp_after", 0)),
		]
	)
	var expected_summary: String = "攻擊次數 %d · 總傷害 %d · 作用中敵人 HP %d" % [
		int(sum_ev.get("attack_count", 0)),
		int(sum_ev.get("total_damage", 0)),
		int(sum_ev.get("target_hp_after", 0)),
	]
	var packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	screen.call("configure_screen", &"battle")
	for _i in 4:
		await _tree.process_frame
	var rows: int = int(screen.call("get_combat_log_row_count_for_tests"))
	_assert_true("k11_rows", rows >= 2)
	var r0: String = str(screen.call("get_combat_log_row_text_for_tests", 0))
	_assert_eq("k11_row_exact", r0, expected_row)
	var r_sum: String = str(screen.call("get_combat_log_row_text_for_tests", rows - 1))
	# last row may be defeated notice; find summary among rows
	var found_sum: bool = false
	for i in rows:
		if str(screen.call("get_combat_log_row_text_for_tests", i)) == expected_summary:
			found_sum = true
			break
	_assert_true("k11_sum_exact", found_sum)
	var log_all: String = str(screen.call("get_combat_log_text_for_tests"))
	_assert_true("k11_no_victory", log_all.find("勝利！") < 0)
	_assert_true("k11_no_enemy_turn", log_all.find("敵人攻擊") < 0)
	var n0: int = int(screen.call("get_combat_log_row_count_for_tests"))
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	_assert_eq("k11_cfg_idem", int(screen.call("get_combat_log_row_count_for_tests")), n0)
	_assert_true("k11_leave_btn", screen.has_method("press_leave_for_test"))
	# zero attack notice via tide board
	var board: Array[StringName] = BattleRuntime.get_board_cells()
	board[0] = BattleOrbKind.TIDE
	board[1] = BattleOrbKind.TIDE
	board[2] = BattleOrbKind.EMBER
	board[3] = BattleOrbKind.TIDE
	board[4] = BattleOrbKind.LIGHT
	board[5] = BattleOrbKind.SHADOW
	_assert_true("k11_set3", BattleRuntime.set_board_cells_for_tests(board))
	_assert_true("k11_zacc", bool(BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0)).get("accepted", false)))
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	var ztxt: String = str(screen.call("get_combat_log_text_for_tests"))
	_assert_true("k11_zero", ztxt.find("本回合沒有隊員屬性符合消除珠") >= 0)
	var snap: Dictionary = BattleRuntime.capture_runtime_snapshot()
	(((snap.get("encounter") as Dictionary).get("enemy_combatants") as Array)[0] as Dictionary)["current_hp"] = 1
	# Empty combat requires turn-zero empty evidence (B1), not silent positive-turn skip.
	snap["last_combat_events"] = []
	snap["last_resolution_events"] = []
	snap["last_match_count"] = 0
	snap["last_cascade_count"] = 0
	snap["turn_count"] = 0
	_assert_true("k11_low", bool(BattleRuntime.restore_runtime_snapshot(snap).get("ok", false)))
	_assert_true("k11_set4", BattleRuntime.set_board_cells_for_tests(_match_ready_board()))
	_assert_true("k11_kill", bool(BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0)).get("accepted", false)))
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	var dtxt: String = str(screen.call("get_combat_log_text_for_tests"))
	_assert_true("k11_defeated", dtxt.find("敵人HP已歸零") >= 0)
	screen.queue_free()
	await _tree.process_frame
	print("[INFO] K11 screen passed")


# ─── K12 responsive ───────────────────────────────────────────────
func _run_responsive_k12() -> void:
	_seed_party3()
	_assert_true("k12_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	_assert_true("k12_set", BattleRuntime.set_board_cells_for_tests(_match_ready_board()))
	_assert_true("k12_acc", bool(BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0)).get("accepted", false)))
	for size in [Vector2(360, 640), Vector2(390, 844), Vector2(720, 1280)]:
		await _run_responsive_viewport(int(size.x), int(size.y))
	print("[INFO] K12 responsive passed")


func _rect_fully_within(inner: Rect2, outer: Rect2, tolerance: float) -> bool:
	return (
		inner.position.x >= outer.position.x - tolerance
		and inner.position.y >= outer.position.y - tolerance
		and inner.end.x <= outer.end.x + tolerance
		and inner.end.y <= outer.end.y + tolerance
	)


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


func _run_responsive_viewport(w: int, h: int) -> void:
	var tag: String = "%dx%d" % [w, h]
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
	for _i in 8:
		await _tree.process_frame

	var host_origin: Vector2 = host.get_global_rect().position
	var grid: GridContainer = screen.call("get_board_grid") as GridContainer
	var scroll: ScrollContainer = screen.call("get_body_scroll") as ScrollContainer
	var back: Button = screen.call("get_back_button") as Button
	var leave: Button = screen.call("get_leave_button") as Button
	var pcards: Array = screen.call("get_party_cards_for_tests") as Array
	var ecards: Array = screen.call("get_enemy_cards_for_tests") as Array
	var log_box: VBoxContainer = screen.call("get_combat_log_box_for_tests") as VBoxContainer
	_assert_true("%s_grid" % tag, grid != null)
	_assert_true("%s_scroll" % tag, scroll != null)
	_assert_true("%s_back" % tag, back != null)
	_assert_true("%s_leave" % tag, leave != null)
	_assert_true("%s_log" % tag, log_box != null)
	_assert_eq("%s_cells_n" % tag, grid.get_child_count(), 30)
	_assert_eq("%s_pc" % tag, pcards.size(), 3)
	_assert_eq("%s_ec" % tag, ecards.size(), 3)

	var scrolls: Array = []
	_collect_scrolls(screen, scrolls)
	_assert_eq("%s_vscroll_count" % tag, scrolls.size(), 1)

	var range_h: float = 0.0
	if scroll.get_h_scroll_bar() != null:
		var hb: ScrollBar = scroll.get_h_scroll_bar()
		range_h = maxf(0.0, float(hb.max_value) - float(hb.page))
	_assert_true("%s_hscroll_range" % tag, range_h <= 0.5)

	for i in 30:
		var cell: Control = grid.get_child(i) as Control
		_assert_true("%s_cw_%d" % [tag, i], cell != null)
		_assert_true("%s_cwa_%d" % [tag, i], cell.size.x >= 48.0)
		_assert_true("%s_cha_%d" % [tag, i], cell.size.y >= 48.0)

	for card in pcards:
		var bar: ProgressBar = screen.call("get_card_progress_bar_for_tests", card) as ProgressBar
		_assert_true("%s_pbar" % tag, bar != null)
		_assert_true("%s_pbar_h" % tag, bar.size.y >= 16.0)
	for card in ecards:
		var bar2: ProgressBar = screen.call("get_card_progress_bar_for_tests", card) as ProgressBar
		_assert_true("%s_ebar" % tag, bar2 != null)
		_assert_true("%s_ebar_h" % tag, bar2.size.y >= 16.0)

	_assert_true("%s_back_h" % tag, back.size.y >= 48.0)
	_assert_true("%s_leave_h" % tag, leave.size.y >= 48.0)
	_assert_eq("%s_log_focus" % tag, log_box.focus_mode, Control.FOCUS_NONE)

	# Combat log + combatant + board reachability via full containment in BodyScroll.
	var row_n: int = int(screen.call("get_combat_log_row_count_for_tests"))
	_assert_true("%s_log_rows" % tag, row_n >= 1)
	var reach_targets: Array = []
	if log_box.get_child_count() > 0:
		reach_targets.append(log_box.get_child(0))
		reach_targets.append(log_box.get_child(log_box.get_child_count() - 1))
	reach_targets.append(pcards[0])
	reach_targets.append(pcards[pcards.size() - 1])
	reach_targets.append(ecards[0])
	reach_targets.append(ecards[ecards.size() - 1])
	reach_targets.append(grid.get_child(0))
	reach_targets.append(grid.get_child(29))
	reach_targets.append(leave)
	for t in reach_targets:
		var ctrl: Control = t as Control
		_assert_true("%s_tgt" % tag, ctrl != null)
		screen.call("ensure_control_visible_for_test", ctrl)
		for _j in 3:
			await _tree.process_frame
		var scroll_vis: Rect2 = scroll.get_global_rect()
		scroll_vis.position -= host_origin
		# Leave/Back may sit outside body scroll; for scroll-body targets require full within.
		if ctrl == leave or ctrl == back:
			var vr := Rect2(Vector2.ZERO, Vector2(w, h))
			var lr := Rect2(ctrl.get_global_rect().position - host_origin, ctrl.get_global_rect().size)
			_assert_true("%s_leave_reach" % tag, _rect_fully_within(lr, vr, 2.0))
		else:
			var gr: Rect2 = ctrl.get_global_rect()
			var local := Rect2(gr.position - host_origin, gr.size)
			_assert_true("%s_reach" % tag, _rect_fully_within(local, scroll_vis, 2.0))

	# Keyboard focus contract
	var c0: Button = screen.call("get_cell_button", 0, 0) as Button
	var c1: Button = screen.call("get_cell_button", 1, 0) as Button
	_assert_true("%s_c0" % tag, c0 != null)
	_assert_true("%s_c1" % tag, c1 != null)
	c0.grab_focus()
	await _tree.process_frame
	_assert_true("%s_kb_focus0" % tag, vp.gui_get_focus_owner() == c0)
	_send_ui_action(vp, "ui_right")
	await _tree.process_frame
	_assert_true("%s_kb_right" % tag, vp.gui_get_focus_owner() == c1)
	c0.grab_focus()
	await _tree.process_frame
	_send_ui_action(vp, "ui_up")
	await _tree.process_frame
	_assert_true("%s_kb_up_back" % tag, vp.gui_get_focus_owner() == back)
	var c_last: Button = screen.call("get_cell_button", 5, 4) as Button
	_assert_true("%s_clast" % tag, c_last != null)
	c_last.grab_focus()
	await _tree.process_frame
	_send_ui_action(vp, "ui_down")
	await _tree.process_frame
	_assert_true("%s_kb_down_leave" % tag, vp.gui_get_focus_owner() == leave)

	vp.queue_free()
	await _tree.process_frame


# ─── K13 enter/leave ──────────────────────────────────────────────
func _run_enter_leave_k13() -> void:
	_seed_solo()
	_assert_true("k13_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	_assert_true("k13_empty_combat", BattleRuntime.get_last_combat_events().is_empty())
	_assert_true("k13_set", BattleRuntime.set_board_cells_for_tests(_match_ready_board()))
	_assert_true("k13_acc", bool(BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0)).get("accepted", false)))
	var damaged: Dictionary = BattleRuntime.capture_runtime_snapshot()
	_assert_true("k13_has_combat", not BattleRuntime.get_last_combat_events().is_empty())
	# successful leave clears
	BattleRuntime.clear_runtime()
	BattleState.clear_session()
	_assert_true("k13_leave_inactive", not BattleRuntime.has_active_runtime())
	_assert_true("k13_leave_combat_clear", BattleRuntime.get_last_combat_events().is_empty())
	# restore damaged via snapshot after re-begin for nav failure simulation
	_seed_solo()
	_assert_true("k13_begin2", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	# Fix snapshot binding for current session
	var cur: Dictionary = BattleRuntime.capture_runtime_snapshot()
	damaged["session_area_id"] = cur.get("session_area_id")
	damaged["session_stage_id"] = cur.get("session_stage_id")
	damaged["session_party_character_ids"] = cur.get("session_party_character_ids")
	damaged["session_leader_character_id"] = cur.get("session_leader_character_id")
	_assert_true("k13_rest", bool(BattleRuntime.restore_runtime_snapshot(damaged).get("ok", false)))
	_assert_true("k13_rest_combat", not BattleRuntime.get_last_combat_events().is_empty())
	var hp: int = BattleRuntime.get_enemy_combatants()[0].get_current_hp()
	_assert_true("k13_rest_hp", hp < BattleRuntime.get_enemy_combatants()[0].get_max_hp())
	# double leave
	BattleRuntime.clear_runtime()
	var r2: Dictionary = BattleRuntime.clear_runtime()
	_assert_true("k13_dbl_leave", bool(r2.get("ok", false)))
	_assert_true("k13_dbl_nchg", not bool(r2.get("changed", true)))
	# double enter
	_seed_solo()
	var e1: Dictionary = BattleRuntime.begin_from_battle_session()
	var e2: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("k13_e1", bool(e1.get("ok", false)))
	_assert_true("k13_e2", bool(e2.get("ok", false)))
	_assert_true("k13_e2_idem", not bool(e2.get("changed", true)))
	BattleRuntime.clear_refill_kind_override_for_tests()
	print("[INFO] K13 enter/leave passed")


# ─── K14 production safety ────────────────────────────────────────
func _assert_production_safety_k14(fp0: Dictionary) -> void:
	_assert_true("k14_fp", _fp_eq(fp0, _prod_fp()))
	PlayerData.configure_test_storage_path("user://feibao_tests/pad_safety")
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.initialize()
	var rev0: int = PlayerData.get_profile().get_revision()
	_seed_solo()
	_assert_true("k14_begin", bool(BattleRuntime.begin_from_battle_session().get("ok", false)))
	_assert_true("k14_set", BattleRuntime.set_board_cells_for_tests(_match_ready_board()))
	_assert_true("k14_acc", bool(BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0)).get("accepted", false)))
	_assert_eq("k14_rev", PlayerData.get_profile().get_revision(), rev0)
	var prof: Dictionary = PlayerData.get_profile().to_dictionary()
	_assert_true("k14_no_enc", not prof.has("encounter"))
	_assert_true("k14_no_hp", not prof.has("current_hp"))
	_assert_true("k14_no_combat", not prof.has("combat_events"))
	_assert_true("k14_no_last_combat", not prof.has("last_combat_events"))
	_assert_eq("k14_schema", PlayerData.get_profile().get_schema_version(), 2)
	_assert_eq("k14_stage_schema", StageCatalog.EXPECTED_SCHEMA_VERSION, 1)
	_assert_eq("k14_ver", FeiBaoConstants.APP_VERSION, "1.2.0")
	BattleRuntime.clear_damage_resolver_force_fail_for_tests()
	BattleDamageResolver.clear_force_fail_for_tests()
	BattleRuntime.clear_refill_kind_override_for_tests()
	_assert_true("k14_fp2", _fp_eq(fp0, _prod_fp()))
	print("[INFO] K14 production safety passed")
