## Battle board + turn loop foundation (1.0.0).
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
	_run_rng_seed_tests()
	_run_source_token_scan()
	_run_board_generation_tests()
	_run_coords_selection_swap_tests()
	_run_match_gravity_refill_tests()
	_run_cascade_event_tests()
	_run_event_equality_tests()
	_run_runtime_snapshot_tests()
	_run_binding_party_leader_tests()
	await _run_enter_leave_screen_tests()
	await _run_responsive_keyboard_tests()
	_cleanup_cases()
	_reset_domain()
	PlayerData.configure_test_storage_path("user://feibao_tests/suite_main")
	PlayerData.reset_runtime_state_for_tests()
	var prod_after: Dictionary = _snapshot_production()
	_assert_production(prod_before, prod_after)
	print("[INFO] battle board turn loop suite complete")


func _nav() -> Node:
	return _tree.root.get_node("NavigationState")


func _reset_domain() -> void:
	if is_instance_valid(AdventureState):
		AdventureState.reset_runtime_state_for_tests()
	if is_instance_valid(BattleRuntime):
		BattleRuntime.reset_runtime_state_for_tests()
	if is_instance_valid(BattleState):
		BattleState.reset_runtime_state_for_tests()


func _begin_case(tag: String) -> void:
	var path: String = "user://feibao_tests/bb_%s_%d" % [tag, Time.get_ticks_usec()]
	_case_paths.append(path)
	PlayerData.clear_save_override_for_tests()
	PlayerData.configure_test_storage_path(path)
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.cleanup_test_artifacts()
	_reset_domain()


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
		_assert_eq("bb_prod_sha_%s" % str(k).get_file(), str(x.get("sha")), str(y.get("sha")))
		_assert_eq("bb_prod_len_%s" % str(k).get_file(), int(x.get("len")), int(y.get("len")))


func _seed_session(stage_id: StringName = &"dev_stage_beginner_01") -> void:
	PlayerData.initialize()
	_reset_domain()
	AdventureState.prepare_stage(stage_id)
	var begin: Dictionary = BattleState.begin_from_prepared_stage()
	_assert_true("seed_session_ok", bool(begin.get("ok", false)))


func _run_rng_seed_tests() -> void:
	_begin_case("rng")
	_seed_session(&"dev_stage_beginner_01")
	var party: Array[StringName] = BattleState.get_party_character_ids()
	var s1: int = BattleRuntime.derive_seed_for_tests(
		BattleState.get_area_id(), BattleState.get_stage_id(), party, BattleState.get_leader_character_id()
	)
	var s1b: int = BattleRuntime.derive_seed_for_tests(
		BattleState.get_area_id(), BattleState.get_stage_id(), party, BattleState.get_leader_character_id()
	)
	_assert_eq("rng_same_session_seed", s1, s1b)
	_assert_true("rng_seed_nonzero", s1 != 0)

	var g1: Dictionary = BattleRuntime.generate_board_for_tests(s1)
	var g1b: Dictionary = BattleRuntime.generate_board_for_tests(s1)
	_assert_true("rng_gen_ok", bool(g1.get("ok", false)))
	_assert_true("rng_same_board", _cells_eq(g1.get("cells", []), g1b.get("cells", [])))
	_assert_eq("rng_same_state", int(g1.get("rng_state", 0)), int(g1b.get("rng_state", -1)))

	_reset_domain()
	_seed_session(&"dev_stage_mist_01")
	var party2: Array[StringName] = BattleState.get_party_character_ids()
	var s2: int = BattleRuntime.derive_seed_for_tests(
		BattleState.get_area_id(), BattleState.get_stage_id(), party2, BattleState.get_leader_character_id()
	)
	# Exact: different stage_id must yield different seed (not OR with board).
	_assert_true("rng_diff_stage_seed", s1 != s2)

	# Global RNG isolation: board path must not consume Godot global RNG.
	seed(424242)
	var expect1: int = randi()
	var expect2: int = randi()
	seed(424242)
	var got1: int = randi()
	_assert_eq("rng_global_first", got1, expect1)
	_seed_session(&"dev_stage_beginner_01")
	var p: Array[StringName] = BattleState.get_party_character_ids()
	var dseed: int = BattleRuntime.derive_seed_for_tests(
		BattleState.get_area_id(), BattleState.get_stage_id(), p, BattleState.get_leader_character_id()
	)
	var gen: Dictionary = BattleRuntime.generate_board_for_tests(dseed)
	_assert_true("rng_iso_gen", bool(gen.get("ok", false)))
	BattleRuntime.begin_from_battle_session()
	var emptyish: Array[StringName] = BattleRuntime.get_board_cells()
	emptyish[0] = BattleOrbKind.EMPTY
	BattleRuntime.refill_for_tests(emptyish)
	var match_board: Array[StringName] = _make_board_with_horizontal_swap_match()
	BattleRuntime.set_board_cells_for_tests(match_board)
	BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0))
	var got2: int = randi()
	_assert_eq("rng_global_second", got2, expect2)
	print("[INFO] rng seed tests passed")


func _run_source_token_scan() -> void:
	_begin_case("tokens")
	var paths: PackedStringArray = PackedStringArray([
		"res://autoload/battle_runtime.gd",
		"res://core/battle/battle_board_engine.gd",
		"res://core/battle/battle_board_model.gd",
		"res://core/battle/battle_resolution_event.gd",
		"res://core/battle/battle_orb_kind.gd",
	])
	var forbidden: PackedStringArray = PackedStringArray([
		"randomize(",
		"randi(",
		"randf(",
		"rand_from_seed",
		"Time.get_ticks",
		"Time.get_unix",
		"Time.get_datetime",
		"OS.get_unique_id",
	])
	var hits: int = 0
	for path in paths:
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		_assert_true("token_open_%s" % path.get_file(), f != null)
		if f == null:
			continue
		var text: String = f.get_as_text()
		f.close()
		for tok in forbidden:
			if text.find(tok) >= 0:
				hits += 1
				print("[FAIL] forbidden_token %s in %s" % [tok, path])
	_assert_eq("token_forbidden_hits", hits, 0)
	print("[INFO] source token scan passed")


func _run_board_generation_tests() -> void:
	_begin_case("gen")
	for seed in [1, 42, 99991, 1234567, 0x1a2b3c4d]:
		var gen: Dictionary = BattleRuntime.generate_board_for_tests(seed)
		_assert_true("gen_ok_%d" % seed, bool(gen.get("ok", false)))
		var cells: Array = gen.get("cells", []) as Array
		_assert_eq("gen_cells_%d" % seed, cells.size(), 30)
		_assert_true("gen_no_match_%d" % seed, BattleBoardEngine.find_matches(cells).is_empty())
		_assert_true("gen_legal_swap_%d" % seed, BattleBoardEngine.has_legal_swap(cells))
		for c in cells:
			_assert_true("gen_kind_%d" % seed, BattleOrbKind.is_valid(c as StringName))
		_assert_true("gen_attempts_bounded_%d" % seed, int(gen.get("attempts", 99)) <= 64)

	# Defensive copy: mutate returned cells does not affect next generate identity.
	var g: Dictionary = BattleRuntime.generate_board_for_tests(7)
	var cells_a: Array = g.get("cells", []) as Array
	if cells_a.size() > 0:
		cells_a[0] = BattleOrbKind.EMBER
	var g2: Dictionary = BattleRuntime.generate_board_for_tests(7)
	_assert_true("gen_defensive", not _cells_eq(cells_a, g2.get("cells", [])))
	print("[INFO] board generation tests passed")


func _run_coords_selection_swap_tests() -> void:
	_begin_case("coords")
	_seed_session()
	var begin: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("sel_begin", bool(begin.get("ok", false)))
	_assert_eq("sel_w", BattleRuntime.get_board_width(), 6)
	_assert_eq("sel_h", BattleRuntime.get_board_height(), 5)
	_assert_eq("sel_idx00", BattleBoardModel.index_of(0, 0), 0)
	_assert_eq("sel_idx50", BattleBoardModel.index_of(5, 0), 5)
	_assert_eq("sel_idx04", BattleBoardModel.index_of(0, 4), 24)
	_assert_eq("sel_idx54", BattleBoardModel.index_of(5, 4), 29)

	var cells0: Array[StringName] = BattleRuntime.get_board_cells()
	var rng0: int = BattleRuntime.get_rng_state()
	var turn0: int = BattleRuntime.get_turn_count()
	_assert_eq("sel_oob_get", str(BattleRuntime.get_cell(-1, 0)), str(BattleOrbKind.EMPTY))
	var oob_sel: Dictionary = BattleRuntime.select_cell(-1, 0)
	_assert_true("sel_oob_fail", bool(oob_sel.get("ok", true)) == false)
	_assert_eq("sel_oob_turn", BattleRuntime.get_turn_count(), turn0)
	_assert_eq("sel_oob_rng", BattleRuntime.get_rng_state(), rng0)

	var phase0: StringName = BattleRuntime.get_phase()
	var sel0: Vector2i = BattleRuntime.get_selected_cell()
	var oob_swap: Dictionary = BattleRuntime.try_swap_cells(Vector2i(0, 0), Vector2i(9, 9))
	_assert_true("swap_oob_ok_false", bool(oob_swap.get("ok", true)) == false)
	_assert_true("swap_oob_accepted_false", bool(oob_swap.get("accepted", true)) == false)
	_assert_true("swap_oob_board", _cells_eq(cells0, BattleRuntime.get_board_cells()))
	_assert_eq("swap_oob_rng", BattleRuntime.get_rng_state(), rng0)
	_assert_eq("swap_oob_turn", BattleRuntime.get_turn_count(), turn0)
	_assert_eq("swap_oob_phase", str(BattleRuntime.get_phase()), str(phase0))
	_assert_eq("swap_oob_sel", BattleRuntime.get_selected_cell(), sel0)

	# Selection rules
	var s1: Dictionary = BattleRuntime.select_cell(1, 1)
	_assert_true("sel_first", bool(s1.get("ok", false)))
	_assert_eq("sel_phase", str(BattleRuntime.get_phase()), "selected")
	_assert_eq("sel_xy", BattleRuntime.get_selected_cell(), Vector2i(1, 1))
	var s_same: Dictionary = BattleRuntime.select_cell(1, 1)
	_assert_eq("sel_deselect_action", str(s_same.get("action", "")), "deselect")
	_assert_true("sel_no_selection", BattleRuntime.has_selection() == false)

	BattleRuntime.select_cell(0, 0)
	var non_adj: Dictionary = BattleRuntime.select_cell(2, 2)
	_assert_eq("sel_nonadj_action", str(non_adj.get("action", "")), "select")
	_assert_eq("sel_moved", BattleRuntime.get_selected_cell(), Vector2i(2, 2))

	# Diagonal reject — exact contract
	var cells_d: Array[StringName] = BattleRuntime.get_board_cells()
	var rng_d: int = BattleRuntime.get_rng_state()
	var turn_d: int = BattleRuntime.get_turn_count()
	var phase_d: StringName = BattleRuntime.get_phase()
	var sel_d: Vector2i = BattleRuntime.get_selected_cell()
	var diag: Dictionary = BattleRuntime.try_swap_cells(Vector2i(1, 1), Vector2i(2, 2))
	_assert_true("diag_ok_false", bool(diag.get("ok", true)) == false)
	_assert_true("diag_accepted_false", bool(diag.get("accepted", true)) == false)
	_assert_true("diag_board", _cells_eq(cells_d, BattleRuntime.get_board_cells()))
	_assert_eq("diag_rng", BattleRuntime.get_rng_state(), rng_d)
	_assert_eq("diag_turn", BattleRuntime.get_turn_count(), turn_d)
	_assert_eq("diag_phase", str(BattleRuntime.get_phase()), str(phase_d))
	_assert_eq("diag_sel", BattleRuntime.get_selected_cell(), sel_d)

	# Same cell reject
	var same: Dictionary = BattleRuntime.try_swap_cells(Vector2i(1, 1), Vector2i(1, 1))
	_assert_true("same_ok_false", bool(same.get("ok", true)) == false)
	_assert_true("same_accepted_false", bool(same.get("accepted", true)) == false)
	_assert_eq("same_turn", BattleRuntime.get_turn_count(), turn_d)

	# Distant reject
	var far: Dictionary = BattleRuntime.try_swap_cells(Vector2i(0, 0), Vector2i(3, 0))
	_assert_true("far_ok_false", bool(far.get("ok", true)) == false)
	_assert_true("far_accepted_false", bool(far.get("accepted", true)) == false)
	_assert_eq("far_turn", BattleRuntime.get_turn_count(), turn_d)

	# Craft no-match adjacent swap rollback
	var flat: Array[StringName] = _make_no_match_board()
	_assert_true("craft_set", BattleRuntime.set_board_cells_for_tests(flat))
	var rng_b: int = BattleRuntime.get_rng_state()
	var turn_b: int = BattleRuntime.get_turn_count()
	# Swap two different non-matching-creating cells (1,0) and (2,0) on crafted board
	var nm: Dictionary = BattleRuntime.try_swap_cells(Vector2i(0, 0), Vector2i(1, 0))
	_assert_true("nm_ok_flag", bool(nm.get("ok", false)))
	_assert_true("nm_not_accepted", bool(nm.get("accepted", true)) == false)
	_assert_true("nm_board_exact", _cells_eq(flat, BattleRuntime.get_board_cells()))
	_assert_eq("nm_rng", BattleRuntime.get_rng_state(), rng_b)
	_assert_eq("nm_turn", BattleRuntime.get_turn_count(), turn_b)
	_assert_true("nm_msg", BattleRuntime.get_last_message().find("沒有形成消除") >= 0)

	# Valid horizontal match swap
	var match_board: Array[StringName] = _make_board_with_horizontal_swap_match()
	BattleRuntime.set_board_cells_for_tests(match_board)
	var before_turn: int = BattleRuntime.get_turn_count()
	var ok_swap: Dictionary = BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0))
	_assert_true("vs_accepted", bool(ok_swap.get("accepted", false)))
	_assert_eq("vs_turn", BattleRuntime.get_turn_count(), before_turn + 1)
	_assert_true("vs_cleared_gt0", BattleRuntime.get_last_match_count() > 0)
	_assert_true("vs_cascade_ge1", BattleRuntime.get_last_cascade_count() >= 1)
	_assert_true("vs_stable", BattleBoardEngine.find_matches(BattleRuntime.get_board_cells()).is_empty())
	_assert_eq("vs_phase_ready", str(BattleRuntime.get_phase()), "ready")
	_assert_true("vs_sel_cleared", BattleRuntime.has_selection() == false)

	# INACTIVE rejects
	BattleRuntime.clear_runtime()
	var inactive: Dictionary = BattleRuntime.select_cell(0, 0)
	_assert_true("inactive_reject", bool(inactive.get("ok", true)) == false)
	print("[INFO] coords selection swap tests passed")


func _run_match_gravity_refill_tests() -> void:
	_begin_case("match")
	# Safe base: no three consecutive same kind.
	var h3: Array = _safe_base_board()
	h3[0] = BattleOrbKind.EMBER
	h3[1] = BattleOrbKind.EMBER
	h3[2] = BattleOrbKind.EMBER
	var m3: Array = BattleBoardEngine.find_matches(h3)
	_assert_eq("m_h3_count", m3.size(), 3)

	var h4: Array = _safe_base_board()
	for i in 4:
		h4[i] = BattleOrbKind.TIDE
	_assert_eq("m_h4", BattleBoardEngine.find_matches(h4).size(), 4)

	var h5: Array = _safe_base_board()
	for i in 5:
		h5[i] = BattleOrbKind.LIGHT
	_assert_eq("m_h5", BattleBoardEngine.find_matches(h5).size(), 5)

	var v3: Array = _safe_base_board()
	v3[BattleBoardModel.index_of(0, 0)] = BattleOrbKind.SHADOW
	v3[BattleBoardModel.index_of(0, 1)] = BattleOrbKind.SHADOW
	v3[BattleBoardModel.index_of(0, 2)] = BattleOrbKind.SHADOW
	_assert_eq("m_v3", BattleBoardEngine.find_matches(v3).size(), 3)

	var v5: Array = _safe_base_board()
	for y in 5:
		v5[BattleBoardModel.index_of(1, y)] = BattleOrbKind.EMBER
	_assert_eq("m_v5", BattleBoardEngine.find_matches(v5).size(), 5)

	# Cross on checkerboard base (no 3-runs), paint + of EMBER = 9 unique cells.
	var cross: Array = []
	cross.resize(30)
	for y in 5:
		for x in 6:
			cross[BattleBoardModel.index_of(x, y)] = (
				BattleOrbKind.LEAF if ((x + y) % 2) == 0 else BattleOrbKind.TIDE
			)
	for x in 5:
		cross[BattleBoardModel.index_of(x, 2)] = BattleOrbKind.EMBER
	for y in 5:
		cross[BattleBoardModel.index_of(2, y)] = BattleOrbKind.EMBER
	var cm: Array = BattleBoardEngine.find_matches(cross)
	_assert_eq("m_cross_dedup", cm.size(), 9)
	_assert_true("m_order_stable", str(cm) == str(BattleBoardEngine.find_matches(cross)))

	var sep: Array = _safe_base_board()
	sep[0] = BattleOrbKind.EMBER
	sep[1] = BattleOrbKind.EMBER
	sep[2] = BattleOrbKind.EMBER
	sep[BattleBoardModel.index_of(5, 4)] = BattleOrbKind.TIDE
	sep[BattleBoardModel.index_of(5, 3)] = BattleOrbKind.TIDE
	sep[BattleBoardModel.index_of(5, 2)] = BattleOrbKind.TIDE
	_assert_eq("m_sep", BattleBoardEngine.find_matches(sep).size(), 6)

	var none: Array = _safe_base_board()
	_assert_true("m_none", BattleBoardEngine.find_matches(none).is_empty())

	# Gravity relative order
	var grav_cells: Array[StringName] = []
	grav_cells.resize(30)
	for i in 30:
		grav_cells[i] = BattleOrbKind.EMPTY
	grav_cells[BattleBoardModel.index_of(0, 0)] = BattleOrbKind.EMBER
	grav_cells[BattleBoardModel.index_of(0, 2)] = BattleOrbKind.TIDE
	var gr: Dictionary = BattleRuntime.apply_gravity_for_tests(grav_cells)
	var after: Array = gr.get("cells", []) as Array
	_assert_eq("grav_bottom", str(after[BattleBoardModel.index_of(0, 4)]), str(BattleOrbKind.TIDE))
	_assert_eq("grav_above", str(after[BattleBoardModel.index_of(0, 3)]), str(BattleOrbKind.EMBER))
	_assert_true("grav_top_empty", BattleOrbKind.is_empty(after[BattleBoardModel.index_of(0, 0)] as StringName))

	# Multi-column gravity no cross
	var mc: Array[StringName] = []
	mc.resize(30)
	for i in 30:
		mc[i] = BattleOrbKind.EMPTY
	mc[BattleBoardModel.index_of(1, 1)] = BattleOrbKind.LEAF
	mc[BattleBoardModel.index_of(2, 0)] = BattleOrbKind.LIGHT
	var mc_g: Dictionary = BattleRuntime.apply_gravity_for_tests(mc)
	var mc_a: Array = mc_g.get("cells", []) as Array
	_assert_eq("grav_col1", str(mc_a[BattleBoardModel.index_of(1, 4)]), str(BattleOrbKind.LEAF))
	_assert_eq("grav_col2", str(mc_a[BattleBoardModel.index_of(2, 4)]), str(BattleOrbKind.LIGHT))

	# Refill only empty, deterministic
	_seed_session()
	BattleRuntime.begin_from_battle_session()
	var emptyish: Array[StringName] = BattleRuntime.get_board_cells()
	emptyish[0] = BattleOrbKind.EMPTY
	emptyish[1] = BattleOrbKind.EMPTY
	BattleRuntime.set_rng_state_for_tests(12345)
	var r1: Dictionary = BattleRuntime.refill_for_tests(emptyish)
	BattleRuntime.set_rng_state_for_tests(12345)
	var r2: Dictionary = BattleRuntime.refill_for_tests(emptyish)
	_assert_true("refill_det", _cells_eq(r1.get("cells", []), r2.get("cells", [])))
	_assert_eq("refill_rng", int(r1.get("rng_state", 0)), int(r2.get("rng_state", -1)))
	var filled: Array = r1.get("cells", []) as Array
	for c in filled:
		_assert_true("refill_kind", BattleOrbKind.is_valid(c as StringName))
	print("[INFO] match gravity refill tests passed")


func _run_cascade_event_tests() -> void:
	_begin_case("cascade")
	_seed_session()
	BattleRuntime.begin_from_battle_session()
	var board: Array[StringName] = _make_board_with_horizontal_swap_match()
	BattleRuntime.set_board_cells_for_tests(board)
	var res: Dictionary = BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0))
	_assert_true("cas_accept", bool(res.get("accepted", false)))
	var events: Array = BattleRuntime.get_last_resolution_events()
	_assert_true("ev_nonempty", events.size() > 0)
	_assert_eq("ev_first_swap", str((events[0] as Dictionary).get("type", "")), "swap")
	_assert_eq("ev_last_turn", str((events[events.size() - 1] as Dictionary).get("type", "")), "turn_completed")
	var types: PackedStringArray = PackedStringArray()
	for e in events:
		types.append(str((e as Dictionary).get("type", "")))
	_assert_true("ev_has_match", types.has("match_found"))
	_assert_true("ev_has_clear", types.has("cells_cleared"))
	_assert_true("ev_has_grav", types.has("gravity_applied"))
	_assert_true("ev_has_refill", types.has("cells_refilled"))
	_assert_true("ev_has_cascade", types.has("cascade_completed"))
	# Defensive copy
	events[0] = {"type": "mutated"}
	var events2: Array = BattleRuntime.get_last_resolution_events()
	_assert_eq("ev_defensive", str((events2[0] as Dictionary).get("type", "")), "swap")

	# Hard-cap forced fixture: cascade 1 then cascade 2 must exceed cap=1.
	BattleRuntime.clear_runtime()
	_seed_session()
	BattleRuntime.begin_from_battle_session()
	var rev_cap: int = PlayerData.get_profile().get_revision()
	var cap_board: Array[StringName] = _make_hard_cap_force_board()
	BattleRuntime.set_board_cells_for_tests(cap_board)
	BattleRuntime.set_refill_kind_override_for_tests(BattleOrbKind.EMBER)
	BattleRuntime.set_cascade_hard_cap_override_for_tests(1)
	var snap: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var hard: Dictionary = BattleRuntime.try_swap_cells(Vector2i(1, 2), Vector2i(1, 3))
	_assert_true("cap_ok_false", bool(hard.get("ok", true)) == false)
	_assert_true("cap_accepted_false", bool(hard.get("accepted", true)) == false)
	_assert_true("cap_err_cascade", str(hard.get("error", "")).find("cascade") >= 0)
	_assert_eq("cap_turn", BattleRuntime.get_turn_count(), int(snap.get("turn_count", -1)))
	_assert_eq("cap_rng", BattleRuntime.get_rng_state(), int(snap.get("rng_state", -2)))
	_assert_true("cap_board", _cells_eq(snap.get("board_cells", []), BattleRuntime.get_board_cells()))
	_assert_eq("cap_sel", BattleRuntime.get_selected_cell(), Vector2i(int(snap.get("selected_x", -3)), int(snap.get("selected_y", -3))))
	_assert_eq("cap_match_count", BattleRuntime.get_last_match_count(), int(snap.get("last_match_count", -1)))
	_assert_eq("cap_cascade_count", BattleRuntime.get_last_cascade_count(), int(snap.get("last_cascade_count", -1)))
	_assert_true(
		"cap_events",
		BattleResolutionEvent.events_equal(
			snap.get("last_resolution_events", []) as Array,
			BattleRuntime.get_last_resolution_events()
		)
	)
	_assert_eq("cap_area", str(BattleRuntime.get_session_area_id()), str(snap.get("session_area_id", &"")))
	_assert_eq("cap_stage", str(BattleRuntime.get_session_stage_id()), str(snap.get("session_stage_id", &"")))
	_assert_true(
		"cap_party",
		_party_eq(snap.get("session_party_character_ids", []), BattleRuntime.get_session_party_character_ids())
	)
	_assert_eq("cap_leader", str(BattleRuntime.get_session_leader_character_id()), str(snap.get("session_leader_character_id", &"")))
	_assert_eq("cap_phase_error", str(BattleRuntime.get_phase()), "error")
	_assert_true("cap_msg", BattleRuntime.get_last_message().find("還原") >= 0)
	_assert_eq("cap_rev", PlayerData.get_profile().get_revision(), rev_cap)
	BattleRuntime.clear_cascade_hard_cap_override_for_tests()
	BattleRuntime.clear_refill_kind_override_for_tests()

	# Fresh ready runtime for no-match event contract.
	BattleRuntime.clear_runtime()
	BattleState.clear_session()
	_seed_session()
	BattleRuntime.begin_from_battle_session()
	var flat2: Array[StringName] = []
	flat2.resize(30)
	for y in 5:
		for x in 6:
			flat2[BattleBoardModel.index_of(x, y)] = (
				BattleOrbKind.EMBER if ((x + y) % 2) == 0 else BattleOrbKind.TIDE
			)
	BattleRuntime.set_board_cells_for_tests(flat2)
	var nm2: Dictionary = BattleRuntime.try_swap_cells(Vector2i(0, 0), Vector2i(1, 0))
	_assert_true("nm2_ok", bool(nm2.get("ok", false)))
	_assert_true("nm2_not_accepted", bool(nm2.get("accepted", true)) == false)
	var ev_bad: Array = BattleRuntime.get_last_resolution_events()
	var has_turn_completed: bool = false
	for e in ev_bad:
		if str((e as Dictionary).get("type", "")) == "turn_completed":
			has_turn_completed = true
	_assert_true("no_fake_turn", has_turn_completed == false)
	print("[INFO] cascade event tests passed")


func _run_event_equality_tests() -> void:
	_begin_case("eveq")
	# Minimal valid completed sequence (one cascade).
	var cells3: Array = [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}]
	var a: Array = [
		BattleResolutionEvent.make_swap(Vector2i(0, 0), Vector2i(1, 0)),
		BattleResolutionEvent.make_match_found(1, cells3),
		BattleResolutionEvent.make_cells_cleared(1, cells3, [BattleOrbKind.EMBER, BattleOrbKind.EMBER, BattleOrbKind.EMBER]),
		BattleResolutionEvent.make_gravity_applied([{"from_x": 0, "from_y": 1, "to_x": 0, "to_y": 4}]),
		BattleResolutionEvent.make_cells_refilled([{"x": 0, "y": 0}], [BattleOrbKind.TIDE]),
		BattleResolutionEvent.make_cascade_completed(1, 3),
		BattleResolutionEvent.make_turn_completed(1, 1, 3),
	]
	var b: Array = BattleResolutionEvent.duplicate_events(a)
	_assert_true("eveq_valid", bool(BattleResolutionEvent.validate_events(a).get("ok", false)))
	_assert_true("eveq_same", BattleResolutionEvent.events_equal(a, b))
	var mut_xy: Array = BattleResolutionEvent.duplicate_events(a)
	(mut_xy[1] as Dictionary)["matched_cells"] = [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 3, "y": 0}]
	_assert_true("eveq_xy_diff", BattleResolutionEvent.events_equal(a, mut_xy) == false)
	var mut_kind: Array = BattleResolutionEvent.duplicate_events(a)
	(mut_kind[2] as Dictionary)["orb_kinds"] = [BattleOrbKind.TIDE, BattleOrbKind.TIDE, BattleOrbKind.TIDE]
	_assert_true("eveq_kind_diff", BattleResolutionEvent.events_equal(a, mut_kind) == false)
	var mut_move: Array = BattleResolutionEvent.duplicate_events(a)
	(mut_move[3] as Dictionary)["movements"] = [
		{"from": {"x": 0, "y": 4}, "to": {"x": 0, "y": 1}},
	]
	_assert_true("eveq_move_diff", BattleResolutionEvent.events_equal(a, mut_move) == false)
	var unk: Array = [{"type": &"not_a_real_event", "payload": 1}]
	_assert_true("eveq_unk_invalid", bool(BattleResolutionEvent.validate_events(unk).get("ok", true)) == false)
	_assert_true("eveq_unk_not_equal", BattleResolutionEvent.events_equal(a, unk) == false)
	_assert_true("eveq_unk_self", BattleResolutionEvent.events_equal(unk, unk) == false)
	# G1–G15 structural rejects
	_assert_true("g1_nonarray", bool(BattleResolutionEvent.validate_events("invalid").get("ok", true)) == false)
	_assert_true("g2_nondict", bool(BattleResolutionEvent.validate_events([123]).get("ok", true)) == false)
	_assert_true("g3_unknown", bool(BattleResolutionEvent.validate_events([{"type": &"unknown_event"}]).get("ok", true)) == false)
	_assert_true(
		"g4_missing_key",
		bool(BattleResolutionEvent.validate_event({"type": &"swap", "to": {"x": 0, "y": 0}}).get("ok", true)) == false
	)
	_assert_true(
		"g5_oob",
		bool(BattleResolutionEvent.validate_event(BattleResolutionEvent.make_swap(Vector2i(0, 0), Vector2i(9, 0))).get("ok", true))
		== false
	)
	_assert_true(
		"g6_nonadj",
		bool(BattleResolutionEvent.validate_event(BattleResolutionEvent.make_swap(Vector2i(0, 0), Vector2i(3, 0))).get("ok", true))
		== false
	)
	_assert_true(
		"g7_len_mismatch",
		bool(
			BattleResolutionEvent.validate_event(
				BattleResolutionEvent.make_cells_cleared(1, cells3, [BattleOrbKind.EMBER])
			).get("ok", true)
		)
		== false
	)
	_assert_true(
		"g8_bad_kind",
		bool(
			BattleResolutionEvent.validate_event(
				BattleResolutionEvent.make_cells_cleared(1, cells3, [&"bogus", &"bogus", &"bogus"])
			).get("ok", true)
		)
		== false
	)
	_assert_true(
		"g9_dup_cells",
		bool(
			BattleResolutionEvent.validate_event(
				BattleResolutionEvent.make_match_found(1, [{"x": 0, "y": 0}, {"x": 0, "y": 0}, {"x": 1, "y": 0}])
			).get("ok", true)
		)
		== false
	)
	_assert_true(
		"g10_cross_col",
		bool(
			BattleResolutionEvent.validate_event(
				{"type": &"gravity_applied", "movements": [{"from": {"x": 0, "y": 1}, "to": {"x": 1, "y": 4}}]}
			).get("ok", true)
		)
		== false
	)
	_assert_true(
		"g10_upward",
		bool(
			BattleResolutionEvent.validate_event(
				{"type": &"gravity_applied", "movements": [{"from": {"x": 0, "y": 4}, "to": {"x": 0, "y": 1}}]}
			).get("ok", true)
		)
		== false
	)
	_assert_true(
		"g10_same",
		bool(
			BattleResolutionEvent.validate_event(
				{"type": &"gravity_applied", "movements": [{"from": {"x": 0, "y": 1}, "to": {"x": 0, "y": 1}}]}
			).get("ok", true)
		)
		== false
	)
	_assert_true(
		"g11_cascade0",
		bool(BattleResolutionEvent.validate_event(BattleResolutionEvent.make_cascade_completed(0, 3)).get("ok", true))
		== false
	)
	_assert_true(
		"g11_neg_count",
		bool(BattleResolutionEvent.validate_event(BattleResolutionEvent.make_turn_completed(1, 1, -1)).get("ok", true))
		== false
	)
	var bad_order: Array = [
		BattleResolutionEvent.make_swap(Vector2i(0, 0), Vector2i(1, 0)),
		BattleResolutionEvent.make_cells_cleared(1, cells3, [BattleOrbKind.EMBER, BattleOrbKind.EMBER, BattleOrbKind.EMBER]),
		BattleResolutionEvent.make_match_found(1, cells3),
		BattleResolutionEvent.make_turn_completed(1, 1, 3),
	]
	_assert_true("g12_order", bool(BattleResolutionEvent.validate_events(bad_order).get("ok", true)) == false)
	var not_last: Array = [
		BattleResolutionEvent.make_swap(Vector2i(0, 0), Vector2i(1, 0)),
		BattleResolutionEvent.make_turn_completed(1, 1, 3),
		BattleResolutionEvent.make_match_found(1, cells3),
	]
	_assert_true("g13_turn_not_last", bool(BattleResolutionEvent.validate_events(not_last).get("ok", true)) == false)
	var bad_cc: Array = BattleResolutionEvent.duplicate_events(a)
	(bad_cc[bad_cc.size() - 1] as Dictionary)["cascade_count"] = 9
	_assert_true("g14_cascade_mismatch", bool(BattleResolutionEvent.validate_events(bad_cc).get("ok", true)) == false)
	_assert_true(
		"g15_counts",
		bool(BattleResolutionEvent.validate_events_with_counts(a, 99, 1).get("ok", true)) == false
	)
	print("[INFO] event equality tests passed")


func _run_runtime_snapshot_tests() -> void:
	_begin_case("rtsnap")
	_assert_true("rt_no_state_fail", bool(BattleRuntime.begin_from_battle_session().get("ok", true)) == false)
	_seed_session()
	var rev0: int = PlayerData.get_profile().get_revision()
	var b1: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("rt_begin", bool(b1.get("ok", false)))
	_assert_true("rt_active", BattleRuntime.has_active_runtime())
	_assert_true(
		"rt_party_bind",
		_party_eq(BattleState.get_party_character_ids(), BattleRuntime.get_session_party_character_ids())
	)
	_assert_eq(
		"rt_leader_bind",
		str(BattleRuntime.get_session_leader_character_id()),
		str(BattleState.get_leader_character_id())
	)
	var party_copy: Array[StringName] = BattleRuntime.get_session_party_character_ids()
	if party_copy.size() > 0:
		party_copy[0] = &"mutated"
	_assert_true(
		"rt_party_defensive",
		_party_eq(BattleState.get_party_character_ids(), BattleRuntime.get_session_party_character_ids())
	)
	var b2: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("rt_idem_ok", bool(b2.get("ok", false)))
	_assert_true("rt_idem_nochange", bool(b2.get("changed", true)) == false)
	_assert_eq("rt_rev", PlayerData.get_profile().get_revision(), rev0)

	var snap: Dictionary = BattleRuntime.capture_runtime_snapshot()
	_assert_true("snap_has_party", snap.has("session_party_character_ids"))
	_assert_true("snap_has_leader", snap.has("session_leader_character_id"))
	BattleRuntime.select_cell(0, 0)
	var sig: Array = [0]
	var on_rt := func(_a: bool) -> void:
		sig[0] = int(sig[0]) + 1
	BattleRuntime.runtime_changed.connect(on_rt)
	var rest: Dictionary = BattleRuntime.restore_runtime_snapshot(snap)
	_assert_true("rt_restore_ok", bool(rest.get("ok", false)))
	_assert_true("rt_restore_board", _cells_eq(snap.get("board_cells", []), BattleRuntime.get_board_cells()))
	_assert_eq("rt_restore_turn", BattleRuntime.get_turn_count(), int(snap.get("turn_count", -1)))
	_assert_eq("rt_restore_rng", BattleRuntime.get_rng_state(), int(snap.get("rng_state", -2)))
	_assert_eq("rt_restore_sel", BattleRuntime.get_selected_cell(), Vector2i(int(snap.get("selected_x", 0)), int(snap.get("selected_y", 0))))
	var rest2: Dictionary = BattleRuntime.restore_runtime_snapshot(snap)
	_assert_true("rt_restore_idem_ok", bool(rest2.get("ok", false)))
	_assert_true("rt_restore_idem_nochange", bool(rest2.get("changed", true)) == false)
	# Identical restore after already restored should not re-emit (changed=false path).
	var sig_before_idem: int = int(sig[0])
	BattleRuntime.restore_runtime_snapshot(snap)
	_assert_eq("rt_idem_no_extra_sig", int(sig[0]), sig_before_idem)
	if BattleRuntime.runtime_changed.is_connected(on_rt):
		BattleRuntime.runtime_changed.disconnect(on_rt)

	var before: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var bad_len: Dictionary = before.duplicate(true)
	bad_len["board_cells"] = [BattleOrbKind.EMBER]
	_assert_true("rt_bad_len", bool(BattleRuntime.restore_runtime_snapshot(bad_len).get("ok", true)) == false)
	_assert_true("rt_preserved_len", _cells_eq(before.get("board_cells", []), BattleRuntime.get_board_cells()))

	var bad_kind: Dictionary = before.duplicate(true)
	var cells_bad: Array = (before.get("board_cells", []) as Array).duplicate()
	cells_bad[0] = &"not_a_kind"
	bad_kind["board_cells"] = cells_bad
	_assert_true("rt_bad_kind", bool(BattleRuntime.restore_runtime_snapshot(bad_kind).get("ok", true)) == false)

	var bad_phase: Dictionary = before.duplicate(true)
	bad_phase["phase"] = &"flying"
	_assert_true("rt_bad_phase", bool(BattleRuntime.restore_runtime_snapshot(bad_phase).get("ok", true)) == false)

	var bad_sess: Dictionary = before.duplicate(true)
	bad_sess["session_stage_id"] = &"other_stage"
	_assert_true("rt_bad_sess", bool(BattleRuntime.restore_runtime_snapshot(bad_sess).get("ok", true)) == false)

	var ready_sel: Dictionary = before.duplicate(true)
	ready_sel["phase"] = BattleRuntime.PHASE_READY
	ready_sel["selected_x"] = 1
	ready_sel["selected_y"] = 1
	_assert_true("rt_ready_sel_reject", bool(BattleRuntime.restore_runtime_snapshot(ready_sel).get("ok", true)) == false)

	var sel_none: Dictionary = before.duplicate(true)
	sel_none["phase"] = BattleRuntime.PHASE_SELECTED
	sel_none["selected_x"] = -1
	sel_none["selected_y"] = -1
	_assert_true("rt_sel_none_reject", bool(BattleRuntime.restore_runtime_snapshot(sel_none).get("ok", true)) == false)

	var resolving: Dictionary = before.duplicate(true)
	resolving["phase"] = BattleRuntime.PHASE_RESOLVING
	_assert_true("rt_resolving_reject", bool(BattleRuntime.restore_runtime_snapshot(resolving).get("ok", true)) == false)

	var bad_rng: Dictionary = before.duplicate(true)
	bad_rng["rng_state"] = 0
	_assert_true("rt_bad_rng", bool(BattleRuntime.restore_runtime_snapshot(bad_rng).get("ok", true)) == false)

	# Illegal event snapshot fail closed — preserve runtime domain exact + no signals.
	var before_ev: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var sig_rt: Array = [0]
	var sig_bd: Array = [0]
	var sig_ph: Array = [0]
	var on_rt2 := func(_a: bool) -> void:
		sig_rt[0] = int(sig_rt[0]) + 1
	var on_bd := func() -> void:
		sig_bd[0] = int(sig_bd[0]) + 1
	var on_ph := func(_p: StringName) -> void:
		sig_ph[0] = int(sig_ph[0]) + 1
	BattleRuntime.runtime_changed.connect(on_rt2)
	BattleRuntime.board_changed.connect(on_bd)
	BattleRuntime.phase_changed.connect(on_ph)
	var bad_ev: Dictionary = before_ev.duplicate(true)
	bad_ev["last_resolution_events"] = "invalid"
	_assert_true("rt_g1_nonarray", bool(BattleRuntime.restore_runtime_snapshot(bad_ev).get("ok", true)) == false)
	_assert_true("rt_g1_exact", _runtime_exact(before_ev))
	_assert_eq("rt_g1_sig_rt", int(sig_rt[0]), 0)
	_assert_eq("rt_g1_sig_bd", int(sig_bd[0]), 0)
	_assert_eq("rt_g1_sig_ph", int(sig_ph[0]), 0)
	bad_ev["last_resolution_events"] = [123]
	_assert_true("rt_g2_nondict", bool(BattleRuntime.restore_runtime_snapshot(bad_ev).get("ok", true)) == false)
	_assert_true("rt_g2_exact", _runtime_exact(before_ev))
	bad_ev["last_resolution_events"] = [{"type": &"unknown_type"}]
	_assert_true("rt_g3_unknown", bool(BattleRuntime.restore_runtime_snapshot(bad_ev).get("ok", true)) == false)
	_assert_true("rt_g3_exact", _runtime_exact(before_ev))
	bad_ev["last_resolution_events"] = [{"type": &"swap", "to": {"x": 0, "y": 0}}]
	_assert_true("rt_g4_missing", bool(BattleRuntime.restore_runtime_snapshot(bad_ev).get("ok", true)) == false)
	_assert_true("rt_g4_exact", _runtime_exact(before_ev))
	if BattleRuntime.runtime_changed.is_connected(on_rt2):
		BattleRuntime.runtime_changed.disconnect(on_rt2)
	if BattleRuntime.board_changed.is_connected(on_bd):
		BattleRuntime.board_changed.disconnect(on_bd)
	if BattleRuntime.phase_changed.is_connected(on_ph):
		BattleRuntime.phase_changed.disconnect(on_ph)

	# Canonical inactive restore after clear
	var clr: Dictionary = BattleRuntime.clear_runtime()
	_assert_true("rt_clear", bool(clr.get("changed", false)))
	var inactive: Dictionary = BattleRuntime.capture_runtime_snapshot()
	_assert_true("inact_active_false", bool(inactive.get("active", true)) == false)
	_assert_eq("inact_phase", str(inactive.get("phase", "")), "inactive")
	_assert_eq("inact_rng", int(inactive.get("rng_state", 0)), 1)
	var inact_ready: Dictionary = inactive.duplicate(true)
	inact_ready["phase"] = BattleRuntime.PHASE_READY
	_assert_true("inact_ready_reject", bool(BattleRuntime.restore_runtime_snapshot(inact_ready).get("ok", true)) == false)
	var inact_fill: Dictionary = inactive.duplicate(true)
	var filled: Array = []
	for _i in 30:
		filled.append(BattleOrbKind.EMBER)
	inact_fill["board_cells"] = filled
	_assert_true("inact_fill_reject", bool(BattleRuntime.restore_runtime_snapshot(inact_fill).get("ok", true)) == false)
	var rest_in: Dictionary = BattleRuntime.restore_runtime_snapshot(inactive)
	_assert_true("inact_restore_ok", bool(rest_in.get("ok", false)))
	_assert_true("inact_restore_idem", bool(BattleRuntime.restore_runtime_snapshot(inactive).get("changed", true)) == false)

	var clr2: Dictionary = BattleRuntime.clear_runtime()
	_assert_true("rt_clear_idem", bool(clr2.get("changed", true)) == false)
	print("[INFO] runtime snapshot tests passed")


func _run_binding_party_leader_tests() -> void:
	_begin_case("bind")
	PlayerData.initialize()
	_reset_domain()
	# Session A: default party
	AdventureState.prepare_stage(&"dev_stage_beginner_01")
	BattleState.begin_from_prepared_stage()
	var r1: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("bind_begin_a", bool(r1.get("ok", false)))
	var board_a: Array[StringName] = BattleRuntime.get_board_cells()
	var rng_a: int = BattleRuntime.get_rng_state()
	var turn_a: int = BattleRuntime.get_turn_count()
	# Rebuild BattleState with same stage but different party while runtime active.
	PlayerData.grant_character(&"partner_a")
	PlayerData.add_party_member(&"partner_a")
	BattleState.clear_session()
	AdventureState.prepare_stage(&"dev_stage_beginner_01")
	var begin_b: Dictionary = BattleState.begin_from_prepared_stage()
	_assert_true("bind_state_b", bool(begin_b.get("ok", false)))
	_assert_eq("bind_party_size_b", BattleState.get_party_character_ids().size(), 2)
	_assert_true(
		"bind_party_differs_from_runtime",
		_party_eq(BattleState.get_party_character_ids(), BattleRuntime.get_session_party_character_ids()) == false
	)
	var r2: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("bind_diff_party_reject", bool(r2.get("ok", true)) == false)
	_assert_true("bind_board_kept", _cells_eq(board_a, BattleRuntime.get_board_cells()))
	_assert_eq("bind_rng_kept", BattleRuntime.get_rng_state(), rng_a)
	_assert_eq("bind_turn_kept", BattleRuntime.get_turn_count(), turn_a)
	# Same area/stage, alternate leader: move partner_a to index 0 while runtime stays active.
	BattleRuntime.clear_runtime()
	BattleState.clear_session()
	PlayerData.initialize()
	_reset_domain()
	PlayerData.grant_character(&"partner_a")
	PlayerData.add_party_member(&"partner_a")
	AdventureState.prepare_stage(&"dev_stage_beginner_01")
	BattleState.begin_from_prepared_stage()
	var r_lead: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("bind_leader_begin", bool(r_lead.get("ok", false)))
	var leader_a: StringName = BattleRuntime.get_session_leader_character_id()
	var party_a: Array[StringName] = BattleRuntime.get_session_party_character_ids()
	_assert_eq("bind_leader_a_is_index0", str(leader_a), str(party_a[0]))
	var board_lead: Array[StringName] = BattleRuntime.get_board_cells()
	var rng_lead: int = BattleRuntime.get_rng_state()
	var turn_lead: int = BattleRuntime.get_turn_count()
	var area_lead: StringName = BattleRuntime.get_session_area_id()
	var stage_lead: StringName = BattleRuntime.get_session_stage_id()
	# Rebuild BattleState with same area/stage but partner_a as leader (index 0).
	BattleState.clear_session()
	var move: Dictionary = PlayerData.move_party_member(&"partner_a", 0)
	_assert_true("bind_move_partner_ok", bool(move.get("ok", false)))
	_assert_eq("bind_new_leader", str(PlayerData.get_party_leader_character_id()), "partner_a")
	_assert_true(
		"bind_leader_differs",
		str(PlayerData.get_party_leader_character_id()) != str(leader_a)
	)
	AdventureState.prepare_stage(&"dev_stage_beginner_01")
	var begin_lead: Dictionary = BattleState.begin_from_prepared_stage()
	_assert_true("bind_state_alt_leader", bool(begin_lead.get("ok", false)))
	_assert_eq("bind_state_same_stage", str(BattleState.get_stage_id()), str(stage_lead))
	_assert_eq("bind_state_same_area", str(BattleState.get_area_id()), str(area_lead))
	_assert_eq("bind_state_leader_partner", str(BattleState.get_leader_character_id()), "partner_a")
	var r_alt: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("bind_alt_leader_reject", bool(r_alt.get("ok", true)) == false)
	_assert_true("bind_alt_board_kept", _cells_eq(board_lead, BattleRuntime.get_board_cells()))
	_assert_eq("bind_alt_rng_kept", BattleRuntime.get_rng_state(), rng_lead)
	_assert_eq("bind_alt_turn_kept", BattleRuntime.get_turn_count(), turn_lead)
	_assert_eq("bind_alt_runtime_leader_unchanged", str(BattleRuntime.get_session_leader_character_id()), str(leader_a))
	_assert_true(
		"bind_alt_runtime_party_unchanged",
		_party_eq(party_a, BattleRuntime.get_session_party_character_ids())
	)
	print("[INFO] binding party leader tests passed")


func _run_enter_leave_screen_tests() -> void:
	_begin_case("tx")
	PlayerData.initialize()
	_reset_domain()
	_nav().call("reset", &"lobby")
	_nav().call("navigate_to", &"adventure", true)
	var packed_adv: PackedScene = load("res://scenes/screens/adventure/adventure_screen.tscn") as PackedScene
	var adv: Control = packed_adv.instantiate() as Control
	_tree.root.add_child(adv)
	adv.call("configure_screen", &"adventure")
	await _tree.process_frame
	adv.call("select_area_for_test", &"dev_area_beginner_path")
	adv.call("select_stage_for_test", &"dev_stage_beginner_01")
	adv.call("press_prepare_for_test")
	await _tree.process_frame
	adv.call("press_enter_battle_for_test")
	await _tree.process_frame
	_assert_true("tx_state", BattleState.has_active_session())
	_assert_true("tx_runtime", BattleRuntime.has_active_runtime())
	_assert_eq("tx_nav", str(_nav().call("get_current_screen")), "battle")
	_assert_eq("tx_board_cells", BattleRuntime.get_board_cells().size(), 30)
	_assert_eq("tx_bind_area", str(BattleRuntime.get_session_area_id()), str(BattleState.get_area_id()))
	_assert_eq("tx_bind_stage", str(BattleRuntime.get_session_stage_id()), str(BattleState.get_stage_id()))
	_assert_true(
		"tx_bind_party",
		_party_eq(BattleRuntime.get_session_party_character_ids(), BattleState.get_party_character_ids())
	)
	_assert_eq(
		"tx_bind_leader",
		str(BattleRuntime.get_session_leader_character_id()),
		str(BattleState.get_leader_character_id())
	)
	adv.queue_free()
	await _tree.process_frame

	# BattleScreen renders board
	var packed_bat: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	var screen: Control = packed_bat.instantiate() as Control
	_tree.root.add_child(screen)
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	await _tree.process_frame
	_assert_true("ui_session_ok", bool(screen.call("is_session_ok")))
	_assert_true("ui_runtime_ok", bool(screen.call("is_runtime_ok")))
	var buttons: Array = screen.call("get_cell_buttons") as Array
	_assert_eq("ui_cells", buttons.size(), 30)
	_assert_true("ui_turn", str(screen.call("get_turn_text")).find("0") >= 0)
	_assert_true("ui_shell", str(screen.call("get_shell_status_text")).find("盤面") >= 0)

	# Selection visible via press
	screen.call("press_cell_for_test", 0, 0)
	await _tree.process_frame
	_assert_eq("ui_sel", BattleRuntime.get_selected_cell(), Vector2i(0, 0))
	var btn0: Button = screen.call("get_cell_button", 0, 0) as Button
	_assert_true("ui_sel_text", btn0 != null and btn0.text.find("[") >= 0)
	screen.call("press_cell_for_test", 0, 0)
	await _tree.process_frame
	_assert_true("ui_desel", BattleRuntime.has_selection() == false)

	# Leave re-entrancy + runtime clear
	_nav().call("reset", &"adventure")
	_nav().call("navigate_to", &"battle", true)
	var leave_n: Array = [0]
	var back_n: Array = [0]
	screen.leave_requested.connect(func() -> void: leave_n[0] = int(leave_n[0]) + 1)
	screen.back_requested.connect(func() -> void: back_n[0] = int(back_n[0]) + 1)
	var first: bool = bool(screen.call("request_leave"))
	var second: bool = bool(screen.call("request_leave"))
	_assert_true("lv_first", first)
	_assert_true("lv_second", second == false)
	_assert_eq("lv_leave_sig", int(leave_n[0]), 1)
	_assert_eq("lv_back_sig", int(back_n[0]), 1)
	_assert_true("lv_state_clear", BattleState.has_active_session() == false)
	_assert_true("lv_runtime_clear", BattleRuntime.has_active_runtime() == false)
	_assert_eq("lv_nav", str(_nav().call("get_current_screen")), "adventure")
	screen.queue_free()
	await _tree.process_frame

	# Leave nav failure restores runtime board exact
	_seed_session()
	BattleRuntime.begin_from_battle_session()
	BattleRuntime.select_cell(2, 2)
	var prior_rt: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var prior_st: Dictionary = BattleState.capture_session_snapshot()
	screen = packed_bat.instantiate() as Control
	_tree.root.add_child(screen)
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	_nav().call("reset", &"adventure")
	_nav().call("navigate_to", &"battle", true)
	screen.call("set_leave_nav_result_override_for_tests", false)
	var fail: bool = bool(screen.call("request_leave"))
	_assert_true("lvf_false", fail == false)
	_assert_true("lvf_state", BattleState.has_active_session())
	_assert_true("lvf_runtime", BattleRuntime.has_active_runtime())
	_assert_true("lvf_board", _cells_eq(prior_rt.get("board_cells", []), BattleRuntime.get_board_cells()))
	_assert_eq("lvf_rng", BattleRuntime.get_rng_state(), int(prior_rt.get("rng_state", -1)))
	_assert_eq("lvf_turn", BattleRuntime.get_turn_count(), int(prior_rt.get("turn_count", -1)))
	_assert_eq("lvf_sel", BattleRuntime.get_selected_cell(), Vector2i(int(prior_rt.get("selected_x", -2)), int(prior_rt.get("selected_y", -2))))
	_assert_eq("lvf_stage", str(BattleState.get_stage_id()), str(prior_st.get("stage_id", &"")))
	_assert_true(
		"lvf_party",
		_party_eq(prior_rt.get("session_party_character_ids", []), BattleRuntime.get_session_party_character_ids())
	)
	_assert_eq(
		"lvf_leader",
		str(BattleRuntime.get_session_leader_character_id()),
		str(prior_rt.get("session_leader_character_id", &""))
	)
	screen.call("clear_leave_nav_result_override_for_tests")
	_assert_true("lvf_retry", bool(screen.call("request_leave")))
	_assert_true("lvf_cleared", BattleRuntime.has_active_runtime() == false)
	var inactive_after: Dictionary = BattleRuntime.capture_runtime_snapshot()
	_assert_true("lvf_inactive_canonical", bool(inactive_after.get("active", true)) == false)
	_assert_eq("lvf_inactive_phase", str(inactive_after.get("phase", "")), "inactive")
	screen.queue_free()
	await _tree.process_frame

	# Missing runtime fail closed on screen
	_seed_session()
	# no runtime begin
	screen = packed_bat.instantiate() as Control
	_tree.root.add_child(screen)
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	_assert_true("ui_no_rt_err", bool(screen.call("is_error_state_visible")))
	_assert_true("ui_leave_ok", screen.call("get_leave_button") != null)
	_assert_true("ui_leave_enabled_err", (screen.call("get_leave_button") as Button).disabled == false)
	screen.queue_free()
	await _tree.process_frame
	print("[INFO] enter leave screen tests passed")


func _run_responsive_keyboard_tests() -> void:
	_begin_case("layout")
	PlayerData.initialize()
	_reset_domain()
	_seed_session()
	BattleRuntime.begin_from_battle_session()
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		await _probe_board_layout(size)
	await _probe_keyboard_input()
	print("[INFO] responsive keyboard tests passed")


func _probe_board_layout(size: Vector2i) -> void:
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
	for _i in 6:
		await _tree.process_frame
	var grid: GridContainer = screen.call("get_board_grid") as GridContainer
	_assert_true("ly_%s_grid" % tag, grid != null)
	_assert_eq("ly_%s_cols" % tag, grid.columns if grid else 0, 6)
	var buttons: Array = screen.call("get_cell_buttons") as Array
	_assert_eq("ly_%s_cells" % tag, buttons.size(), 30)
	var screen_rect: Rect2 = screen.get_global_rect()
	var grid_rect: Rect2 = grid.get_global_rect() if grid != null else Rect2()
	var min_w: float = 9999.0
	var min_h: float = 9999.0
	var tol: float = 2.0
	for b in buttons:
		var btn: Button = b as Button
		if btn == null:
			continue
		var r: Rect2 = btn.get_global_rect()
		min_w = minf(min_w, r.size.x)
		min_h = minf(min_h, r.size.y)
		_assert_true("ly_%s_cell_focus_mode" % tag, btn.focus_mode != Control.FOCUS_NONE)
		_assert_true("ly_%s_cell_left" % tag, r.position.x >= screen_rect.position.x - tol)
		_assert_true("ly_%s_cell_right" % tag, r.end.x <= screen_rect.end.x + tol)
	_assert_true("ly_%s_cell_w" % tag, min_w >= 48.0)
	_assert_true("ly_%s_cell_h" % tag, min_h >= 48.0)
	_assert_true("ly_%s_grid_left" % tag, grid_rect.position.x >= screen_rect.position.x - tol)
	_assert_true("ly_%s_grid_right" % tag, grid_rect.end.x <= screen_rect.end.x + tol)
	var body: ScrollContainer = screen.call("get_body_scroll") as ScrollContainer
	_assert_true(
		"ly_%s_h_disabled" % tag,
		body != null and int(body.horizontal_scroll_mode) == int(ScrollContainer.SCROLL_MODE_DISABLED)
	)
	var range_v: float = 0.0
	var page_h: float = 0.0
	var content_h: float = 0.0
	if body != null and body.get_v_scroll_bar() != null:
		var vb: ScrollBar = body.get_v_scroll_bar()
		range_v = maxf(0.0, float(vb.max_value) - float(vb.page))
		page_h = float(vb.page)
	if body != null and body.get_child_count() > 0:
		var content: Control = body.get_child(0) as Control
		if content != null:
			content_h = content.get_combined_minimum_size().y
			if content_h <= 0.0:
				content_h = content.size.y
	# Explicit scroll contract per viewport (no OR).
	if size.x <= 360:
		_assert_true("ly_%s_scroll_gt" % tag, range_v > 0.5)
	elif size.x >= 720:
		_assert_true("ly_%s_scroll_fit" % tag, range_v <= 0.5)
	else:
		# 390: branch on content vs page.
		if content_h > page_h + 0.5:
			_assert_true("ly_%s_scroll_overflow" % tag, range_v > 0.5)
		else:
			_assert_true("ly_%s_scroll_fit390" % tag, range_v <= 0.5)
	var back: Button = screen.call("get_back_button") as Button
	var leave: Button = screen.call("get_leave_button") as Button
	_assert_true("ly_%s_back_h" % tag, back != null and back.get_global_rect().size.y >= 48.0)
	_assert_true("ly_%s_leave_h" % tag, leave != null and leave.get_global_rect().size.y >= 48.0)
	# Reachability: full-within BodyScroll viewport (cells) / screen (header) — no OR.
	var first: Button = screen.call("get_cell_button", 0, 0) as Button
	var last: Button = screen.call("get_cell_button", 5, 4) as Button
	_assert_true("ly_%s_first_present" % tag, first != null)
	_assert_true("ly_%s_last_present" % tag, last != null)
	_assert_true("ly_%s_leave_present" % tag, leave != null)
	var body_rect: Rect2 = body.get_global_rect() if body != null else screen_rect
	screen.call("ensure_control_visible_for_test", first)
	await _tree.process_frame
	_assert_true("ly_%s_first_full" % tag, _rect_fully_within(first.get_global_rect(), body_rect, 2.0))
	screen.call("ensure_control_visible_for_test", last)
	await _tree.process_frame
	_assert_true("ly_%s_last_full" % tag, _rect_fully_within(last.get_global_rect(), body_rect, 2.0))
	_assert_true("ly_%s_back_full" % tag, _rect_fully_within(back.get_global_rect(), screen_rect, 2.0))
	_assert_true("ly_%s_leave_full" % tag, _rect_fully_within(leave.get_global_rect(), screen_rect, 2.0))
	# Selected visible + fully within
	BattleRuntime.select_cell(1, 1)
	screen.call("configure_screen", &"battle")
	await _tree.process_frame
	var sb: Button = screen.call("get_cell_button", 1, 1) as Button
	_assert_true("ly_%s_sel" % tag, sb != null and str(sb.text).find("[") >= 0)
	screen.call("ensure_control_visible_for_test", sb)
	await _tree.process_frame
	_assert_true("ly_%s_sel_full" % tag, _rect_fully_within(sb.get_global_rect(), body_rect, 2.0))
	BattleRuntime.select_cell(1, 1)
	print(
		"[INFO] board_layout_%s cell_min=%.1fx%.1f grid=%s screen=%s scroll=%.1f content_h=%.1f page_h=%.1f"
		% [tag, min_w, min_h, str(grid_rect), str(screen_rect), range_v, content_h, page_h]
	)
	host.queue_free()
	await _tree.process_frame


func _probe_keyboard_input() -> void:
	var host := SubViewportContainer.new()
	host.custom_minimum_size = Vector2(720, 1280)
	host.size = Vector2(720, 1280)
	host.stretch = true
	_tree.root.add_child(host)
	var sv := SubViewport.new()
	sv.size = Vector2i(720, 1280)
	sv.handle_input_locally = true
	sv.gui_disable_input = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(sv)
	var packed: PackedScene = load("res://scenes/screens/battle/battle_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	sv.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.call("configure_screen", &"battle")
	for _i in 6:
		await _tree.process_frame
	var c00: Button = screen.call("get_cell_button", 0, 0) as Button
	var c10: Button = screen.call("get_cell_button", 1, 0) as Button
	var c11: Button = screen.call("get_cell_button", 1, 1) as Button
	var c01: Button = screen.call("get_cell_button", 0, 1) as Button
	_assert_true("kb_cells", c00 != null and c10 != null and c11 != null and c01 != null)
	var press_c00: Array = [0]
	var press_c11: Array = [0]
	c00.pressed.connect(func() -> void:
		press_c00[0] = int(press_c00[0]) + 1
	)
	c11.pressed.connect(func() -> void:
		press_c11[0] = int(press_c11[0]) + 1
	)
	c00.grab_focus()
	await _tree.process_frame
	_assert_true("kb_focus00", c00.has_focus())
	_assert_true("kb_focus_mode00", c00.focus_mode != Control.FOCUS_NONE)
	var focus_sb: Variant = c00.get_theme_stylebox("focus")
	_assert_true("kb_focus_style", focus_sb != null)

	_send_ui_action(sv, "ui_right")
	await _tree.process_frame
	_assert_true("kb_right_owner", sv.gui_get_focus_owner() == c10)
	_assert_true("kb_right_vis", c10.visible and not c10.disabled and c10.is_inside_tree())
	_send_ui_action(sv, "ui_down")
	await _tree.process_frame
	_assert_true("kb_down_owner", sv.gui_get_focus_owner() == c11)
	_send_ui_action(sv, "ui_left")
	await _tree.process_frame
	_assert_true("kb_left_owner", sv.gui_get_focus_owner() == c01)
	_send_ui_action(sv, "ui_up")
	await _tree.process_frame
	_assert_true("kb_up_owner", sv.gui_get_focus_owner() == c00)

	# Clear selection via domain only before keyboard activation evidence (not part of key path).
	while BattleRuntime.has_selection():
		var s: Vector2i = BattleRuntime.get_selected_cell()
		BattleRuntime.select_cell(s.x, s.y)
	c00.grab_focus()
	await _tree.process_frame
	_assert_true("kb_enter_focus", c00.has_focus())
	_assert_eq("kb_enter_press_base", int(press_c00[0]), 0)
	_send_key(sv, KEY_ENTER)
	await _tree.process_frame
	await _tree.process_frame
	_assert_eq("kb_enter_callback", int(press_c00[0]), 1)
	_assert_eq("kb_enter_select", BattleRuntime.get_selected_cell(), Vector2i(0, 0))
	_send_key(sv, KEY_ENTER)
	await _tree.process_frame
	await _tree.process_frame
	_assert_eq("kb_enter_callback2", int(press_c00[0]), 2)
	_assert_true("kb_enter_deselect", BattleRuntime.has_selection() == false)

	c11.grab_focus()
	await _tree.process_frame
	_assert_true("kb_space_focus", c11.has_focus())
	_assert_eq("kb_space_press_base", int(press_c11[0]), 0)
	_send_key(sv, KEY_SPACE)
	await _tree.process_frame
	await _tree.process_frame
	_assert_eq("kb_space_callback", int(press_c11[0]), 1)
	_assert_eq("kb_space_select", BattleRuntime.get_selected_cell(), Vector2i(1, 1))

	var all_focusable: bool = true
	for y in 5:
		for x in 6:
			var b: Button = screen.call("get_cell_button", x, y) as Button
			if b == null or b.focus_mode == Control.FOCUS_NONE or not b.visible or b.disabled:
				all_focusable = false
			if b != null and b.get_theme_stylebox("focus") == null:
				all_focusable = false
	_assert_true("kb_all_focusable", all_focusable)
	var back: Button = screen.call("get_back_button") as Button
	var leave: Button = screen.call("get_leave_button") as Button
	_assert_true("kb_back_focusable", back != null and back.focus_mode != Control.FOCUS_NONE)
	_assert_true("kb_leave_focusable", leave != null and leave.focus_mode != Control.FOCUS_NONE)
	# Focus escape: from top cell ui_up → Back
	c00.grab_focus()
	await _tree.process_frame
	_send_ui_action(sv, "ui_up")
	await _tree.process_frame
	_assert_true("kb_escape_up_back", sv.gui_get_focus_owner() == back)
	_assert_true("kb_back_has_focus", back.has_focus() and back.visible and not back.disabled)
	# From bottom cell ui_down → Leave
	var c54: Button = screen.call("get_cell_button", 5, 4) as Button
	c54.grab_focus()
	await _tree.process_frame
	_send_ui_action(sv, "ui_down")
	await _tree.process_frame
	_assert_true("kb_escape_down_leave", sv.gui_get_focus_owner() == leave)
	_assert_true("kb_leave_has_focus", leave.has_focus() and leave.visible and not leave.disabled)
	_assert_true("kb_no_trap", leave.has_focus() and leave.visible and not leave.disabled)
	host.queue_free()
	await _tree.process_frame


func _send_ui_action(sv: SubViewport, action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	sv.push_input(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	sv.push_input(release)


## Real physical key press/release into SubViewport (Enter / Space activation path).
func _send_key(sv: SubViewport, keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	press.echo = false
	sv.push_input(press, true)
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	release.echo = false
	sv.push_input(release, true)


func _rect_fully_within(inner: Rect2, outer: Rect2, tolerance: float) -> bool:
	return (
		inner.position.x >= outer.position.x - tolerance
		and inner.position.y >= outer.position.y - tolerance
		and inner.end.x <= outer.end.x + tolerance
		and inner.end.y <= outer.end.y + tolerance
	)


func _runtime_exact(snap: Dictionary) -> bool:
	if not _cells_eq(snap.get("board_cells", []), BattleRuntime.get_board_cells()):
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
	if str(BattleRuntime.get_session_area_id()) != str(snap.get("session_area_id", &"")):
		return false
	if str(BattleRuntime.get_session_stage_id()) != str(snap.get("session_stage_id", &"")):
		return false
	if str(BattleRuntime.get_session_leader_character_id()) != str(snap.get("session_leader_character_id", &"")):
		return false
	if not _party_eq(snap.get("session_party_character_ids", []), BattleRuntime.get_session_party_character_ids()):
		return false
	if str(BattleRuntime.get_last_message()) != str(snap.get("last_message", "")):
		return false
	return BattleResolutionEvent.events_equal(
		snap.get("last_resolution_events", []) as Array,
		BattleRuntime.get_last_resolution_events()
	)


func _make_no_match_board() -> Array[StringName]:
	# Alternating pattern with no 3-run
	var out: Array[StringName] = []
	out.resize(30)
	var kinds: Array[StringName] = [BattleOrbKind.EMBER, BattleOrbKind.TIDE, BattleOrbKind.LEAF, BattleOrbKind.LIGHT, BattleOrbKind.SHADOW]
	for y in 5:
		for x in 6:
			out[BattleBoardModel.index_of(x, y)] = kinds[(x + y * 2) % kinds.size()]
	# Ensure no accidental match
	if not BattleBoardEngine.find_matches(out).is_empty():
		return _filled_checker()
	return out


func _make_board_with_horizontal_swap_match() -> Array[StringName]:
	# Row 0: E E T E L S — swap (2,0)=T with (3,0)=E → E E E ...
	var out: Array[StringName] = _filled(BattleOrbKind.LEAF)
	out[0] = BattleOrbKind.EMBER
	out[1] = BattleOrbKind.EMBER
	out[2] = BattleOrbKind.TIDE
	out[3] = BattleOrbKind.EMBER
	out[4] = BattleOrbKind.LIGHT
	out[5] = BattleOrbKind.SHADOW
	# Avoid vertical matches under swap
	for y in range(1, 5):
		out[BattleBoardModel.index_of(0, y)] = BattleOrbKind.TIDE if y % 2 == 0 else BattleOrbKind.LEAF
		out[BattleBoardModel.index_of(1, y)] = BattleOrbKind.LIGHT if y % 2 == 0 else BattleOrbKind.SHADOW
		out[BattleBoardModel.index_of(2, y)] = BattleOrbKind.SHADOW if y % 2 == 0 else BattleOrbKind.LIGHT
		out[BattleBoardModel.index_of(3, y)] = BattleOrbKind.LEAF if y % 2 == 0 else BattleOrbKind.TIDE
	return out


## Column 1: E E T E L — swap (1,2)-(1,3) → E E E E L; clear 4 E; refill E → cascade 2.
func _make_hard_cap_force_board() -> Array[StringName]:
	var out: Array[StringName] = []
	out.resize(30)
	for y in 5:
		for x in 6:
			out[BattleBoardModel.index_of(x, y)] = (
				BattleOrbKind.LEAF if ((x + y) % 2) == 0 else BattleOrbKind.TIDE
			)
	out[BattleBoardModel.index_of(1, 0)] = BattleOrbKind.EMBER
	out[BattleBoardModel.index_of(1, 1)] = BattleOrbKind.EMBER
	out[BattleBoardModel.index_of(1, 2)] = BattleOrbKind.TIDE
	out[BattleBoardModel.index_of(1, 3)] = BattleOrbKind.EMBER
	out[BattleBoardModel.index_of(1, 4)] = BattleOrbKind.LEAF
	# Isolate neighbors of column 1 from accidental ember matches.
	for y in 5:
		out[BattleBoardModel.index_of(0, y)] = BattleOrbKind.LIGHT
		out[BattleBoardModel.index_of(2, y)] = BattleOrbKind.SHADOW
	return out


func _party_eq(a: Variant, b: Variant) -> bool:
	if not (a is Array) or not (b is Array):
		return false
	var aa: Array = a as Array
	var bb: Array = b as Array
	if aa.size() != bb.size():
		return false
	for i in aa.size():
		if str(aa[i]) != str(bb[i]):
			return false
	return true


func _filled(kind: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	out.resize(30)
	for i in 30:
		out[i] = kind
	return out


func _filled_checker() -> Array[StringName]:
	return _safe_base_board()


## 5-kind cycling base with no 3-in-a-row horizontally or vertically.
func _safe_base_board() -> Array[StringName]:
	var out: Array[StringName] = []
	out.resize(30)
	var kinds: Array[StringName] = [
		BattleOrbKind.EMBER, BattleOrbKind.TIDE, BattleOrbKind.LEAF, BattleOrbKind.LIGHT, BattleOrbKind.SHADOW
	]
	for y in 5:
		for x in 6:
			out[BattleBoardModel.index_of(x, y)] = kinds[(x + y * 2) % kinds.size()]
	# Verify contract for fixtures.
	if not BattleBoardEngine.find_matches(out).is_empty():
		# Fallback strict checker of 2 kinds (no 3-run).
		for y in 5:
			for x in 6:
				out[BattleBoardModel.index_of(x, y)] = (
					BattleOrbKind.EMBER if ((x + y) % 2) == 0 else BattleOrbKind.TIDE
				)
	return out


func _cells_eq(a: Variant, b: Variant) -> bool:
	if not (a is Array) or not (b is Array):
		return false
	var aa: Array = a as Array
	var bb: Array = b as Array
	if aa.size() != bb.size():
		return false
	for i in aa.size():
		if str(aa[i]) != str(bb[i]):
			return false
	return true


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
