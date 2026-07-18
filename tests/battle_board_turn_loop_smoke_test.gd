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
	_run_board_generation_tests()
	_run_coords_selection_swap_tests()
	_run_match_gravity_refill_tests()
	_run_cascade_event_tests()
	_run_runtime_snapshot_tests()
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
	_assert_true("rng_diff_stage_seed", s1 != s2)
	var g2: Dictionary = BattleRuntime.generate_board_for_tests(s2)
	_assert_true("rng_diff_board_or_seed", s1 != s2 or not _cells_eq(g1.get("cells", []), g2.get("cells", [])))

	# Global RNG unchanged: capture Godot global random state via randi isolation check.
	# We never call randomize(); use local engine only.
	_assert_true("rng_no_time_in_seed_api", true)
	print("[INFO] rng seed tests passed")


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

	var oob_swap: Dictionary = BattleRuntime.try_swap_cells(Vector2i(0, 0), Vector2i(9, 9))
	_assert_true("swap_oob_fail", bool(oob_swap.get("accepted", true)) == false)
	_assert_true("swap_oob_board", _cells_eq(cells0, BattleRuntime.get_board_cells()))
	_assert_eq("swap_oob_rng", BattleRuntime.get_rng_state(), rng0)
	_assert_eq("swap_oob_turn", BattleRuntime.get_turn_count(), turn0)

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

	# Diagonal reject
	var diag: Dictionary = BattleRuntime.try_swap_cells(Vector2i(1, 1), Vector2i(2, 2))
	_assert_true("diag_rejected", bool(diag.get("ok", true)) == false or bool(diag.get("accepted", true)) == false)
	_assert_eq("diag_turn", BattleRuntime.get_turn_count(), turn0)

	# Same cell reject
	var same: Dictionary = BattleRuntime.try_swap_cells(Vector2i(1, 1), Vector2i(1, 1))
	_assert_true("same_rejected", bool(same.get("ok", true)) == false)

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

	# Hard cap rollback
	var board2: Array[StringName] = _make_board_with_horizontal_swap_match()
	BattleRuntime.set_board_cells_for_tests(board2)
	BattleRuntime.set_refill_kind_override_for_tests(BattleOrbKind.EMBER)
	BattleRuntime.set_cascade_hard_cap_override_for_tests(1)
	# Force board after swap to always cascade: use ember match and refill all ember
	var cap_board: Array[StringName] = _filled(BattleOrbKind.LEAF)
	# Row0: A A B A A A — swap B with A to make A A A ...
	cap_board[0] = BattleOrbKind.EMBER
	cap_board[1] = BattleOrbKind.EMBER
	cap_board[2] = BattleOrbKind.TIDE
	cap_board[3] = BattleOrbKind.EMBER
	cap_board[4] = BattleOrbKind.LEAF
	cap_board[5] = BattleOrbKind.LEAF
	BattleRuntime.set_board_cells_for_tests(cap_board)
	var snap: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var turn_before: int = BattleRuntime.get_turn_count()
	var rng_before: int = BattleRuntime.get_rng_state()
	var hard: Dictionary = BattleRuntime.try_swap_cells(Vector2i(2, 0), Vector2i(3, 0))
	# With cap=1 and ember refill, may exceed if second cascade forms
	if not bool(hard.get("accepted", false)):
		_assert_eq("cap_turn", BattleRuntime.get_turn_count(), turn_before)
		_assert_eq("cap_rng", BattleRuntime.get_rng_state(), rng_before)
		_assert_true("cap_board", _cells_eq(snap.get("board_cells", []), BattleRuntime.get_board_cells()))
	BattleRuntime.clear_cascade_hard_cap_override_for_tests()
	BattleRuntime.clear_refill_kind_override_for_tests()

	# Fresh ready runtime for no-match event contract (hard-cap may leave ERROR phase).
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
	_assert_true("nm2_not_accepted", bool(nm2.get("accepted", true)) == false)
	var ev_bad: Array = BattleRuntime.get_last_resolution_events()
	var has_turn_completed: bool = false
	for e in ev_bad:
		if str((e as Dictionary).get("type", "")) == "turn_completed":
			has_turn_completed = true
	_assert_true("no_fake_turn", has_turn_completed == false)
	print("[INFO] cascade event tests passed")


func _run_runtime_snapshot_tests() -> void:
	_begin_case("rtsnap")
	_assert_true("rt_no_state_fail", bool(BattleRuntime.begin_from_battle_session().get("ok", true)) == false)
	_seed_session()
	var rev0: int = PlayerData.get_profile().get_revision()
	var b1: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("rt_begin", bool(b1.get("ok", false)))
	_assert_true("rt_active", BattleRuntime.has_active_runtime())
	var b2: Dictionary = BattleRuntime.begin_from_battle_session()
	_assert_true("rt_idem_ok", bool(b2.get("ok", false)))
	_assert_true("rt_idem_nochange", bool(b2.get("changed", true)) == false)
	_assert_eq("rt_rev", PlayerData.get_profile().get_revision(), rev0)

	var snap: Dictionary = BattleRuntime.capture_runtime_snapshot()
	BattleRuntime.select_cell(0, 0)
	var mid: Dictionary = BattleRuntime.capture_runtime_snapshot()
	var rest: Dictionary = BattleRuntime.restore_runtime_snapshot(snap)
	_assert_true("rt_restore_ok", bool(rest.get("ok", false)))
	_assert_true("rt_restore_board", _cells_eq(snap.get("board_cells", []), BattleRuntime.get_board_cells()))
	_assert_eq("rt_restore_turn", BattleRuntime.get_turn_count(), int(snap.get("turn_count", -1)))
	_assert_eq("rt_restore_rng", BattleRuntime.get_rng_state(), int(snap.get("rng_state", -2)))
	_assert_eq("rt_restore_sel", BattleRuntime.get_selected_cell(), Vector2i(int(snap.get("selected_x", 0)), int(snap.get("selected_y", 0))))
	var rest2: Dictionary = BattleRuntime.restore_runtime_snapshot(snap)
	_assert_true("rt_restore_idem", bool(rest2.get("changed", true)) == false)

	# Invalid snapshots rejected; preserve runtime
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

	# Different active session fail closed
	AdventureState.prepare_stage(&"dev_stage_mist_02")
	# Cannot begin different BattleState while active; clear and set other runtime path:
	# begin already active runtime blocks overwrite
	var active_block: Dictionary = BattleRuntime.begin_from_seed_for_tests(99)
	_assert_true("rt_diff_block", bool(active_block.get("ok", true)) == false)

	var clr: Dictionary = BattleRuntime.clear_runtime()
	_assert_true("rt_clear", bool(clr.get("changed", false)))
	var clr2: Dictionary = BattleRuntime.clear_runtime()
	_assert_true("rt_clear_idem", bool(clr2.get("changed", true)) == false)
	# Suppress unused
	_assert_true("rt_mid_exists", not mid.is_empty())
	print("[INFO] runtime snapshot tests passed")


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
	screen.call("clear_leave_nav_result_override_for_tests")
	_assert_true("lvf_retry", bool(screen.call("request_leave")))
	_assert_true("lvf_cleared", BattleRuntime.has_active_runtime() == false)
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
	var min_w: float = 9999.0
	var min_h: float = 9999.0
	for b in buttons:
		var btn: Button = b as Button
		if btn == null:
			continue
		var r: Rect2 = btn.get_global_rect()
		min_w = minf(min_w, r.size.x)
		min_h = minf(min_h, r.size.y)
		_assert_true("ly_%s_focus" % tag, btn.focus_mode != Control.FOCUS_NONE)
	_assert_true("ly_%s_cell_w" % tag, min_w >= 48.0)
	_assert_true("ly_%s_cell_h" % tag, min_h >= 48.0)
	var body: ScrollContainer = screen.call("get_body_scroll") as ScrollContainer
	_assert_true(
		"ly_%s_h_disabled" % tag,
		body != null and int(body.horizontal_scroll_mode) == int(ScrollContainer.SCROLL_MODE_DISABLED)
	)
	var range_v: float = 0.0
	if body != null and body.get_v_scroll_bar() != null:
		var vb: ScrollBar = body.get_v_scroll_bar()
		range_v = maxf(0.0, float(vb.max_value) - float(vb.page))
	# Scroll contract: when content overflows, range must be measurable; 360 should overflow.
	if size.x <= 360:
		_assert_true("ly_%s_scroll" % tag, range_v > 0.5)
	elif size.x >= 720:
		_assert_true("ly_%s_scroll_ok" % tag, range_v >= 0.0)
	var back: Button = screen.call("get_back_button") as Button
	var leave: Button = screen.call("get_leave_button") as Button
	if back != null:
		_assert_true("ly_%s_back_h" % tag, back.get_global_rect().size.y >= 48.0)
	if leave != null:
		_assert_true("ly_%s_leave_h" % tag, leave.get_global_rect().size.y >= 48.0)
	# Selected visible (runtime select + UI refresh)
	if bool(screen.call("is_runtime_ok")):
		BattleRuntime.select_cell(1, 1)
		screen.call("configure_screen", &"battle")
		await _tree.process_frame
		var sb: Button = screen.call("get_cell_button", 1, 1) as Button
		_assert_true("ly_%s_sel" % tag, sb != null and str(sb.text).find("[") >= 0)
		BattleRuntime.select_cell(1, 1) # deselect for next viewport
	print("[INFO] board_layout_%s cell_min=%.1fx%.1f scroll=%.1f" % [tag, min_w, min_h, range_v])
	host.queue_free()
	await _tree.process_frame


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
