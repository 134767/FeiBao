## Adventure stage catalog + AdventureState + AdventureScreen tests (0.8.0).
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
	if is_instance_valid(AdventureState):
		AdventureState.reset_runtime_state_for_tests()
	if is_instance_valid(BattleState):
		BattleState.reset_runtime_state_for_tests()
	_run_catalog_tests()
	_run_adventure_state_tests()
	_run_registry_tests()
	await _run_screen_tests()
	await _run_layout_tests()
	_cleanup_cases()
	if is_instance_valid(AdventureState):
		AdventureState.reset_runtime_state_for_tests()
	if is_instance_valid(BattleState):
		BattleState.reset_runtime_state_for_tests()
	PlayerData.configure_test_storage_path("user://feibao_tests/suite_main")
	PlayerData.reset_runtime_state_for_tests()
	var prod_after: Dictionary = _snapshot_production()
	_assert_production(prod_before, prod_after)
	print("[INFO] adventure stage suite complete")


func _nav() -> Node:
	return _tree.root.get_node("NavigationState")


func _app() -> Node:
	return _tree.root.get_node("AppState")


func _begin_case(tag: String) -> String:
	var path: String = "user://feibao_tests/adv_%s_%d" % [tag, Time.get_ticks_usec()]
	_case_paths.append(path)
	PlayerData.clear_save_override_for_tests()
	PlayerData.configure_test_storage_path(path)
	PlayerData.reset_runtime_state_for_tests()
	PlayerData.cleanup_test_artifacts()
	if is_instance_valid(AdventureState):
		AdventureState.reset_runtime_state_for_tests()
	if is_instance_valid(BattleState):
		BattleState.reset_runtime_state_for_tests()
	return path


func _cleanup_cases() -> void:
	for path in _case_paths:
		PlayerData.configure_test_storage_path(path)
		PlayerData.cleanup_test_artifacts()
	_case_paths.clear()
	PlayerData.clear_save_override_for_tests()
	PlayerData.clear_test_storage_path()
	PlayerData.reset_runtime_state_for_tests()


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
		_assert_eq("adv_prod_sha_%s" % str(k).get_file(), str(x.get("sha")), str(y.get("sha")))
		_assert_eq("adv_prod_len_%s" % str(k).get_file(), int(x.get("len")), int(y.get("len")))


func _run_catalog_tests() -> void:
	var ok: Dictionary = StageCatalog.load_default()
	_assert_true("sc_default_ok", bool(ok.get("ok", false)))
	var areas: Array = ok.get("areas", [])
	_assert_eq("sc_area_count", areas.size(), 2)
	var stages: Array = ok.get("stages", [])
	_assert_eq("sc_stage_count", stages.size(), 6)
	var a0: StageAreaDefinition = areas[0] as StageAreaDefinition
	_assert_eq("sc_first_area", str(a0.get_id()), "dev_area_beginner_path")
	_assert_eq("sc_first_area_stages", a0.get_stage_count(), 3)
	_assert_true("sc_story_has_seed", a0.get_story_intro().find("開發樣本") >= 0)

	# Mutating returned arrays must not affect authority.
	var stages_copy: Array = ok.get("stages", [])
	if stages_copy.size() > 0:
		stages_copy.clear()
	var ok2: Dictionary = StageCatalog.load_default()
	_assert_eq("sc_authority_stable", (ok2.get("stages", []) as Array).size(), 6)

	_assert_true("sc_schema_1", bool(StageCatalog.parse_json_text(_min_catalog(1)).get("ok", false)))
	_assert_true(
		"sc_schema_1_0",
		bool(StageCatalog.parse_json_text(_min_catalog(1.0)).get("ok", false))
	)
	_assert_true("sc_schema_1_5_fail", bool(StageCatalog.parse_json_text(_min_catalog(1.5)).get("ok", true)) == false)
	_assert_true(
		"sc_unknown_field_fail",
		bool(StageCatalog.parse_json_text(
			'{"schema_version":1,"catalog_kind":"development_seed","areas":[],"token":1}'
		).get("ok", true)) == false
	)
	_assert_true(
		"sc_empty_areas_fail",
		bool(StageCatalog.parse_json_text(
			'{"schema_version":1,"catalog_kind":"development_seed","areas":[]}'
		).get("ok", true)) == false
	)
	_assert_true("sc_dup_area_fail", bool(StageCatalog.parse_json_text(_dup_area_catalog()).get("ok", true)) == false)
	_assert_true("sc_dup_stage_fail", bool(StageCatalog.parse_json_text(_dup_stage_catalog()).get("ok", true)) == false)
	_assert_true("sc_bad_id_fail", bool(StageCatalog.parse_json_text(_bad_id_catalog()).get("ok", true)) == false)
	_assert_true("sc_false_seed_fail", bool(StageCatalog.parse_json_text(_false_seed_catalog()).get("ok", true)) == false)
	_assert_true("sc_frac_sort_fail", bool(StageCatalog.parse_json_text(_frac_sort_catalog()).get("ok", true)) == false)
	_assert_true("sc_noncontig_fail", bool(StageCatalog.parse_json_text(_noncontig_catalog()).get("ok", true)) == false)
	_assert_true("sc_empty_stages_fail", bool(StageCatalog.parse_json_text(_empty_stages_catalog()).get("ok", true)) == false)
	_assert_true("sc_frac_stage_num_fail", bool(StageCatalog.parse_json_text(_frac_stage_num_catalog()).get("ok", true)) == false)
	_assert_true("sc_missing_story_fail", bool(StageCatalog.parse_json_text(_missing_story_catalog()).get("ok", true)) == false)
	_assert_true("sc_stage_false_seed_fail", bool(StageCatalog.parse_json_text(_stage_false_seed_catalog()).get("ok", true)) == false)
	_assert_true("sc_wrong_kind_fail", bool(StageCatalog.parse_json_text(
		'{"schema_version":1,"catalog_kind":"production","areas":[]}'
	).get("ok", true)) == false)
	_assert_true("sc_schema0_fail", bool(StageCatalog.parse_json_text(_min_catalog(0)).get("ok", true)) == false)
	_assert_true("sc_schema2_fail", bool(StageCatalog.parse_json_text(_min_catalog(2)).get("ok", true)) == false)
	var fail: Dictionary = StageCatalog.parse_json_text("{not json")
	_assert_true("sc_fail_empty_areas", (fail.get("areas", ["x"]) as Array).is_empty())
	_assert_true("sc_fail_nullish", fail.get("ok", true) == false)
	# Sorting: reverse sort_order areas still load ordered
	var sort_check: Dictionary = StageCatalog.parse_json_text(_reverse_sort_catalog())
	_assert_true("sc_sort_ok", bool(sort_check.get("ok", false)))
	if bool(sort_check.get("ok", false)):
		var sa: Array = sort_check.get("areas", [])
		_assert_eq("sc_sort_area0", str((sa[0] as StageAreaDefinition).get_id()), "a_first")
		_assert_eq("sc_sort_area1", str((sa[1] as StageAreaDefinition).get_id()), "a_second")
	var found: Dictionary = StageCatalog.find_stage(&"dev_stage_mist_03")
	_assert_true("sc_find_ok", bool(found.get("ok", false)))
	_assert_eq("sc_find_area", str((found.get("area") as StageAreaDefinition).get_id()), "dev_area_mist_ridge")
	var found_miss: Dictionary = StageCatalog.find_stage(&"missing")
	_assert_true("sc_find_miss", bool(found_miss.get("ok", true)) == false)
	# Seed area/stage name contracts
	for i in areas.size():
		var ar: StageAreaDefinition = areas[i] as StageAreaDefinition
		_assert_true("sc_area_name_seed_%d" % i, ar.get_display_name().find("開發樣本") >= 0)
		_assert_true("sc_area_seed_flag_%d" % i, ar.is_development_seed())
		var stgs: Array[StageDefinition] = ar.get_stages()
		_assert_eq("sc_area_stage_count_%d" % i, stgs.size(), 3)
		for j in stgs.size():
			_assert_eq("sc_stage_num_%d_%d" % [i, j], stgs[j].get_stage_number(), j + 1)
			_assert_true("sc_stage_name_seed_%d_%d" % [i, j], stgs[j].get_display_name().find("開發樣本") >= 0)
			_assert_true("sc_stage_seed_flag_%d_%d" % [i, j], stgs[j].is_development_seed())
			_assert_eq("sc_stage_area_link_%d_%d" % [i, j], str(stgs[j].get_area_id()), str(ar.get_id()))
	# Duplicate returned stages clear does not clear second load stages
	var st2: Array = StageCatalog.load_default().get("stages", [])
	_assert_eq("sc_stage_count2", st2.size(), 6)
	if st2.size() > 0 and st2[0] is StageDefinition:
		var g: String = (st2[0] as StageDefinition).get_placeholder_glyph()
		_assert_true("sc_glyph_nonempty", not g.is_empty())

	# Additional fail-closed contracts
	_assert_true(
		"sc_schema_string_fail",
		bool(StageCatalog.parse_json_text(_min_catalog('"1"')).get("ok", true)) == false
	)
	_assert_true("sc_empty_text_fail", bool(StageCatalog.parse_json_text("").get("ok", true)) == false)
	_assert_true(
		"sc_stage_unknown_field_fail",
		bool(StageCatalog.parse_json_text(_stage_unknown_field_catalog()).get("ok", true)) == false
	)
	_assert_true(
		"sc_stage_num_zero_fail",
		bool(StageCatalog.parse_json_text(_stage_num_zero_catalog()).get("ok", true)) == false
	)
	_assert_true(
		"sc_neg_sort_fail",
		bool(StageCatalog.parse_json_text(_neg_sort_catalog()).get("ok", true)) == false
	)
	_assert_true(
		"sc_missing_area_name_fail",
		bool(StageCatalog.parse_json_text(_missing_area_name_catalog()).get("ok", true)) == false
	)
	# Stage sort within area: reverse sort_order still orders by sort then stage_number then id
	var stage_sort: Dictionary = StageCatalog.parse_json_text(_stage_sort_catalog())
	_assert_true("sc_stage_sort_ok", bool(stage_sort.get("ok", false)))
	if bool(stage_sort.get("ok", false)):
		var sa_areas: Array = stage_sort.get("areas", [])
		if not sa_areas.is_empty():
			var sorted_stages: Array[StageDefinition] = (sa_areas[0] as StageAreaDefinition).get_stages()
			_assert_eq("sc_stage_sort0", str(sorted_stages[0].get_id()), "s_low")
			_assert_eq("sc_stage_sort1", str(sorted_stages[1].get_id()), "s_mid")
			_assert_eq("sc_stage_sort2", str(sorted_stages[2].get_id()), "s_high")
	# get_stages returns safe copies: clearing caller array does not empty area authority
	var areas_auth: Array = StageCatalog.load_default().get("areas", [])
	if not areas_auth.is_empty():
		var area_auth: StageAreaDefinition = areas_auth[0] as StageAreaDefinition
		var stages_mut: Array[StageDefinition] = area_auth.get_stages()
		var before_count: int = stages_mut.size()
		stages_mut.clear()
		_assert_eq("sc_area_stages_copy_safe", area_auth.get_stage_count(), before_count)
		_assert_eq("sc_area_stages_reload", area_auth.get_stages().size(), before_count)
	# Catalog constants / kind
	_assert_eq("sc_expected_schema", StageCatalog.EXPECTED_SCHEMA_VERSION, 1)
	_assert_eq("sc_expected_kind", StageCatalog.EXPECTED_CATALOG_KIND, "development_seed")
	_assert_eq("sc_default_path", StageCatalog.DEFAULT_PATH, "res://data/stage_catalog.json")
	# Profile schema must remain 2 (adventure must not bump it)
	_assert_eq("sc_profile_schema_const", int(PlayerProfile.SCHEMA_VERSION), 2)
	print("[INFO] stage catalog tests passed")


func _min_catalog(schema: Variant) -> String:
	return (
		'{"schema_version":%s,"catalog_kind":"development_seed","areas":[{'
		% str(schema)
		+ '"id":"a1","display_name":"A","summary":"S","story_intro":"Story seed",'
		+ '"sort_order":1,"is_development_seed":true,"stages":[{'
		+ '"id":"s1","display_name":"S1","summary":"ss","stage_number":1,"sort_order":1,"is_development_seed":true}]}]}'
	)


func _dup_area_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":['
		+ '{"id":"a1","display_name":"A","summary":"S","story_intro":"T","sort_order":1,"is_development_seed":true,'
		+ '"stages":[{"id":"s1","display_name":"S","summary":"s","stage_number":1,"sort_order":1,"is_development_seed":true}]},'
		+ '{"id":"a1","display_name":"B","summary":"S","story_intro":"T","sort_order":2,"is_development_seed":true,'
		+ '"stages":[{"id":"s2","display_name":"S","summary":"s","stage_number":1,"sort_order":1,"is_development_seed":true}]}]}'
	)


func _dup_stage_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":['
		+ '{"id":"a1","display_name":"A","summary":"S","story_intro":"T","sort_order":1,"is_development_seed":true,'
		+ '"stages":[{"id":"same","display_name":"S","summary":"s","stage_number":1,"sort_order":1,"is_development_seed":true}]},'
		+ '{"id":"a2","display_name":"B","summary":"S","story_intro":"T","sort_order":2,"is_development_seed":true,'
		+ '"stages":[{"id":"same","display_name":"S","summary":"s","stage_number":1,"sort_order":1,"is_development_seed":true}]}]}'
	)


func _bad_id_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":[{'
		+ '"id":"Bad-ID","display_name":"A","summary":"S","story_intro":"T","sort_order":1,"is_development_seed":true,'
		+ '"stages":[{"id":"s1","display_name":"S","summary":"s","stage_number":1,"sort_order":1,"is_development_seed":true}]}]}'
	)


func _false_seed_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":[{'
		+ '"id":"a1","display_name":"A","summary":"S","story_intro":"T","sort_order":1,"is_development_seed":false,'
		+ '"stages":[{"id":"s1","display_name":"S","summary":"s","stage_number":1,"sort_order":1,"is_development_seed":true}]}]}'
	)


func _frac_sort_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":[{'
		+ '"id":"a1","display_name":"A","summary":"S","story_intro":"T","sort_order":1.5,"is_development_seed":true,'
		+ '"stages":[{"id":"s1","display_name":"S","summary":"s","stage_number":1,"sort_order":1,"is_development_seed":true}]}]}'
	)


func _noncontig_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":[{'
		+ '"id":"a1","display_name":"A","summary":"S","story_intro":"T","sort_order":1,"is_development_seed":true,'
		+ '"stages":['
		+ '{"id":"s1","display_name":"S","summary":"s","stage_number":1,"sort_order":1,"is_development_seed":true},'
		+ '{"id":"s2","display_name":"S","summary":"s","stage_number":3,"sort_order":2,"is_development_seed":true}'
		+ "]}]}"
	)


func _empty_stages_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":[{'
		+ '"id":"a1","display_name":"A","summary":"S","story_intro":"T","sort_order":1,"is_development_seed":true,'
		+ '"stages":[]}]}'
	)


func _frac_stage_num_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":[{'
		+ '"id":"a1","display_name":"A","summary":"S","story_intro":"T","sort_order":1,"is_development_seed":true,'
		+ '"stages":[{"id":"s1","display_name":"S","summary":"s","stage_number":1.5,"sort_order":1,"is_development_seed":true}]}]}'
	)


func _missing_story_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":[{'
		+ '"id":"a1","display_name":"A","summary":"S","sort_order":1,"is_development_seed":true,'
		+ '"stages":[{"id":"s1","display_name":"S","summary":"s","stage_number":1,"sort_order":1,"is_development_seed":true}]}]}'
	)


func _stage_false_seed_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":[{'
		+ '"id":"a1","display_name":"A","summary":"S","story_intro":"T","sort_order":1,"is_development_seed":true,'
		+ '"stages":[{"id":"s1","display_name":"S","summary":"s","stage_number":1,"sort_order":1,"is_development_seed":false}]}]}'
	)


func _reverse_sort_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":['
		+ '{"id":"a_second","display_name":"B","summary":"S","story_intro":"T","sort_order":20,"is_development_seed":true,'
		+ '"stages":[{"id":"sb1","display_name":"S","summary":"s","stage_number":1,"sort_order":1,"is_development_seed":true}]},'
		+ '{"id":"a_first","display_name":"A","summary":"S","story_intro":"T","sort_order":10,"is_development_seed":true,'
		+ '"stages":[{"id":"sa1","display_name":"S","summary":"s","stage_number":1,"sort_order":1,"is_development_seed":true}]}]}'
	)


func _stage_unknown_field_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":[{'
		+ '"id":"a1","display_name":"A","summary":"S","story_intro":"T","sort_order":1,"is_development_seed":true,'
		+ '"stages":[{"id":"s1","display_name":"S","summary":"s","stage_number":1,"sort_order":1,'
		+ '"is_development_seed":true,"enemy_table":[]}]}]}'
	)


func _stage_num_zero_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":[{'
		+ '"id":"a1","display_name":"A","summary":"S","story_intro":"T","sort_order":1,"is_development_seed":true,'
		+ '"stages":[{"id":"s1","display_name":"S","summary":"s","stage_number":0,"sort_order":1,"is_development_seed":true}]}]}'
	)


func _neg_sort_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":[{'
		+ '"id":"a1","display_name":"A","summary":"S","story_intro":"T","sort_order":-1,"is_development_seed":true,'
		+ '"stages":[{"id":"s1","display_name":"S","summary":"s","stage_number":1,"sort_order":1,"is_development_seed":true}]}]}'
	)


func _missing_area_name_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":[{'
		+ '"id":"a1","summary":"S","story_intro":"T","sort_order":1,"is_development_seed":true,'
		+ '"stages":[{"id":"s1","display_name":"S","summary":"s","stage_number":1,"sort_order":1,"is_development_seed":true}]}]}'
	)


func _stage_sort_catalog() -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","areas":[{'
		+ '"id":"a1","display_name":"A","summary":"S","story_intro":"T","sort_order":1,"is_development_seed":true,'
		+ '"stages":['
		+ '{"id":"s_high","display_name":"H","summary":"s","stage_number":3,"sort_order":30,"is_development_seed":true},'
		+ '{"id":"s_mid","display_name":"M","summary":"s","stage_number":2,"sort_order":20,"is_development_seed":true},'
		+ '{"id":"s_low","display_name":"L","summary":"s","stage_number":1,"sort_order":10,"is_development_seed":true}'
		+ "]}]}"
	)


func _run_adventure_state_tests() -> void:
	_begin_case("state")
	PlayerData.initialize()
	var party_before: int = PlayerData.get_active_party_character_ids().size()
	var rev_before: int = PlayerData.get_profile().get_revision()
	AdventureState.reset_runtime_state_for_tests()
	_assert_true("as_default_empty", AdventureState.has_prepared_stage() == false)

	var sig: Array = [0]
	var on_sig := func(_a: StringName, _s: StringName) -> void:
		sig[0] = int(sig[0]) + 1
	AdventureState.prepared_stage_changed.connect(on_sig)

	var bad: Dictionary = AdventureState.prepare_stage(&"no_such_stage")
	_assert_true("as_invalid_fail", bool(bad.get("ok", true)) == false)
	_assert_true("as_invalid_unchanged", AdventureState.has_prepared_stage() == false)
	_assert_eq("as_invalid_sig", int(sig[0]), 0)

	var ok: Dictionary = AdventureState.prepare_stage(&"dev_stage_beginner_01")
	_assert_true("as_valid_ok", bool(ok.get("ok", false)))
	_assert_true("as_valid_changed", bool(ok.get("changed", false)))
	_assert_eq("as_sig1", int(sig[0]), 1)
	_assert_eq("as_stage", str(AdventureState.get_selected_stage_id()), "dev_stage_beginner_01")
	_assert_eq("as_area", str(AdventureState.get_selected_area_id()), "dev_area_beginner_path")
	var prep: StageDefinition = AdventureState.get_prepared_stage()
	_assert_true("as_prep_def", prep != null and str(prep.get_id()) == "dev_stage_beginner_01")

	var same: Dictionary = AdventureState.prepare_stage(&"dev_stage_beginner_01")
	_assert_true("as_same_ok", bool(same.get("ok", false)))
	_assert_true("as_same_no_change", bool(same.get("changed", true)) == false)
	_assert_eq("as_same_sig", int(sig[0]), 1)

	var other: Dictionary = AdventureState.prepare_stage(&"dev_stage_mist_02")
	_assert_true("as_other_changed", bool(other.get("changed", false)))
	_assert_eq("as_other_sig", int(sig[0]), 2)
	_assert_eq("as_other_stage", str(AdventureState.get_selected_stage_id()), "dev_stage_mist_02")

	var clr: Dictionary = AdventureState.clear_prepared_stage()
	_assert_true("as_clear_changed", bool(clr.get("changed", false)))
	_assert_eq("as_clear_sig", int(sig[0]), 3)
	_assert_true("as_cleared", AdventureState.has_prepared_stage() == false)
	var clr2: Dictionary = AdventureState.clear_prepared_stage()
	_assert_true("as_clear_noop", bool(clr2.get("changed", true)) == false)
	_assert_eq("as_clear_noop_sig", int(sig[0]), 3)

	_assert_eq("as_party_unchanged", PlayerData.get_active_party_character_ids().size(), party_before)
	_assert_eq("as_rev_unchanged", PlayerData.get_profile().get_revision(), rev_before)
	_assert_true("as_no_disk", PlayerData.did_last_save_write_disk() == false)
	_assert_eq("as_profile_schema", int(PlayerData.get_profile().get_schema_version()), 2)

	# Empty stage id and prepared area/copy isolation
	AdventureState.reset_runtime_state_for_tests()
	var empty_prep: Dictionary = AdventureState.prepare_stage(&"")
	_assert_true("as_empty_id_fail", bool(empty_prep.get("ok", true)) == false)
	_assert_true("as_empty_id_no_change", bool(empty_prep.get("changed", true)) == false)
	_assert_true("as_empty_still_empty", AdventureState.has_prepared_stage() == false)

	var ok_area: Dictionary = AdventureState.prepare_stage(&"dev_stage_beginner_03")
	_assert_true("as_area_ok", bool(ok_area.get("ok", false)))
	var prep_area: StageAreaDefinition = AdventureState.get_prepared_area()
	_assert_true("as_prep_area", prep_area != null and str(prep_area.get_id()) == "dev_area_beginner_path")
	var prep_a: StageDefinition = AdventureState.get_prepared_stage()
	var prep_b: StageDefinition = AdventureState.get_prepared_stage()
	_assert_true("as_prep_copy_a", prep_a != null)
	_assert_true("as_prep_copy_b", prep_b != null)
	_assert_true("as_prep_not_same_instance", prep_a != prep_b)
	_assert_eq("as_prep_copy_id", str(prep_a.get_id()), str(prep_b.get_id()))
	_assert_eq("as_app_version", FeiBaoConstants.APP_VERSION, "1.0.0")
	_assert_eq(
		"as_path_adventure",
		FeiBaoConstants.PATH_ADVENTURE_SCREEN,
		"res://scenes/screens/adventure/adventure_screen.tscn"
	)
	_assert_eq(
		"as_path_battle",
		FeiBaoConstants.PATH_BATTLE_SCREEN,
		"res://scenes/screens/battle/battle_screen.tscn"
	)

	if AdventureState.prepared_stage_changed.is_connected(on_sig):
		AdventureState.prepared_stage_changed.disconnect(on_sig)
	print("[INFO] adventure state tests passed")


func _run_registry_tests() -> void:
	_assert_eq(
		"reg_adv_path",
		ScreenRegistry.get_scene_path(&"adventure"),
		"res://scenes/screens/adventure/adventure_screen.tscn"
	)
	_assert_eq(
		"reg_char_path",
		ScreenRegistry.get_scene_path(&"character"),
		"res://scenes/screens/character/character_screen.tscn"
	)
	_assert_eq(
		"reg_party_path",
		ScreenRegistry.get_scene_path(&"party"),
		"res://scenes/screens/party/party_screen.tscn"
	)
	_assert_eq(
		"reg_inv_path",
		ScreenRegistry.get_scene_path(&"inventory"),
		"res://scenes/screens/module/module_screen.tscn"
	)
	var modules: Array[StringName] = ScreenRegistry.get_module_ids()
	_assert_eq("reg_order0", str(modules[0]), "adventure")
	_assert_eq("reg_order1", str(modules[1]), "character")
	_assert_eq("reg_order2", str(modules[2]), "party")
	_assert_eq("reg_fallback", str(ScreenRegistry.get_back_fallback(&"adventure")), "lobby")
	_assert_true("reg_validate", ScreenRegistry.validate_metadata())
	_assert_true("reg_resources", ScreenRegistry.validate_resources())
	_assert_eq("reg_order3", str(modules[3]), "inventory")
	_assert_eq("reg_order4", str(modules[4]), "farm")
	_assert_eq("reg_order5", str(modules[5]), "settings")
	_assert_eq(
		"reg_farm_path",
		ScreenRegistry.get_scene_path(&"farm"),
		"res://scenes/screens/module/module_screen.tscn"
	)
	_assert_eq(
		"reg_settings_path",
		ScreenRegistry.get_scene_path(&"settings"),
		"res://scenes/screens/module/module_screen.tscn"
	)
	_assert_eq("reg_module_count", modules.size(), 6)


func _run_screen_tests() -> void:
	_begin_case("screen")
	PlayerData.initialize()
	AdventureState.reset_runtime_state_for_tests()
	_nav().call("reset", &"login")
	var packed: PackedScene = load("res://scenes/screens/adventure/adventure_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	_assert_true("adv_cfg", bool(screen.call("configure_screen", &"adventure")))
	_assert_true("adv_reject_party", bool(screen.call("configure_screen", &"party")) == false)
	await _tree.process_frame
	await _tree.process_frame
	_assert_true("adv_load_ok", bool(screen.call("is_load_ok")))
	_assert_eq("adv_init_area", str(screen.call("get_selected_area_id")), "dev_area_beginner_path")
	_assert_eq("adv_init_stage", str(screen.call("get_selected_stage_id")), "dev_stage_beginner_01")
	_assert_eq("adv_vis_area", str(screen.call("get_visible_selected_area_id")), "dev_area_beginner_path")
	_assert_eq("adv_vis_stage", str(screen.call("get_visible_selected_stage_id")), "dev_stage_beginner_01")
	_assert_eq("adv_detail_stage", str(screen.call("get_detail_stage_id")), "dev_stage_beginner_01")
	# Initial selection: internal = visible card = detail (independent storage)
	_assert_true(
		"adv_init_cons",
		_assert_selection_consistent(screen, "dev_stage_beginner_01")
	)
	var init_stage_def: StageDefinition = _find_stage_def(&"dev_stage_beginner_01")
	_assert_true("adv_init_stage_def", init_stage_def != null)
	if init_stage_def != null:
		_assert_eq(
			"adv_detail_display_name_exact",
			str(screen.call("get_detail_name_text")),
			init_stage_def.get_display_name()
		)
	_assert_true("adv_story", str(screen.call("get_story_intro_text")).find("開發樣本") >= 0)
	_assert_eq("adv_cards", int(screen.call("get_stage_card_count")), 3)
	_assert_true("adv_party_sum", str(screen.call("get_party_summary_text")).find("領隊") >= 0)
	_assert_true("adv_party_not_rep_word", str(screen.call("get_party_summary_text")).find("代表") < 0)
	_assert_eq("adv_screen_id", str(screen.call("get_screen_id")), "adventure")
	_assert_true("adv_area_name_seed", str(screen.call("get_area_name_text")).find("開發樣本") >= 0)
	_assert_true("adv_detail_name_seed", str(screen.call("get_detail_name_text")).find("開發樣本") >= 0)
	_assert_true("adv_detail_viewing_mark", _detail_status_has(screen, "檢視中"))
	_assert_true("adv_detail_seed_mark", _detail_status_has(screen, "開發樣本"))
	_assert_true("adv_party_count_digit", str(screen.call("get_party_summary_text")).find("目前隊伍") >= 0)
	# Initial card selection flags
	_assert_true("adv_card_viewing_init", _card_is_viewing(screen, "dev_stage_beginner_01"))
	_assert_true("adv_card_not_prepared_init", _card_is_prepared(screen, "dev_stage_beginner_01") == false)

	_assert_true("adv_switch_area", bool(screen.call("select_area_for_test", &"dev_area_mist_ridge")))
	_assert_eq("adv_area2", str(screen.call("get_selected_area_id")), "dev_area_mist_ridge")
	_assert_eq("adv_stage_first_of_area", str(screen.call("get_selected_stage_id")), "dev_stage_mist_01")
	_assert_true("adv_story2", str(screen.call("get_story_intro_text")).find("霧嶺") >= 0)
	_assert_true(
		"adv_area_switch_cons",
		_assert_selection_consistent(screen, "dev_stage_mist_01")
	)
	_assert_true("adv_select_stage", bool(screen.call("select_stage_for_test", &"dev_stage_mist_02")))
	_assert_eq("adv_stage2", str(screen.call("get_selected_stage_id")), "dev_stage_mist_02")
	_assert_eq("adv_vis_stage2", str(screen.call("get_visible_selected_stage_id")), "dev_stage_mist_02")
	_assert_eq("adv_detail2", str(screen.call("get_detail_stage_id")), "dev_stage_mist_02")
	_assert_true(
		"adv_stage_switch_cons",
		_assert_selection_consistent(screen, "dev_stage_mist_02")
	)
	var mist02_def: StageDefinition = _find_stage_def(&"dev_stage_mist_02")
	if mist02_def != null:
		_assert_eq(
			"adv_detail_name_after_switch",
			str(screen.call("get_detail_name_text")),
			mist02_def.get_display_name()
		)

	screen.call("reset_prepare_refresh_count_for_tests")
	var sig: Array = [0]
	AdventureState.prepared_stage_changed.connect(func(_a: StringName, _s: StringName) -> void:
		sig[0] = int(sig[0]) + 1
	)
	screen.call("press_prepare_for_test")
	await _tree.process_frame
	_assert_eq("adv_prep_state", str(AdventureState.get_selected_stage_id()), "dev_stage_mist_02")
	_assert_eq("adv_prep_sig", int(sig[0]), 1)
	_assert_eq("adv_prep_ui_refresh", int(screen.call("get_prepare_refresh_count_for_tests")), 1)
	_assert_true("adv_prep_msg", str(screen.call("get_mutation_message")).find("關卡準備完成") >= 0)
	_assert_true("adv_detail_prepared_mark", _detail_status_has(screen, "已準備"))
	_assert_true("adv_card_prepared", _card_is_prepared(screen, "dev_stage_mist_02"))
	_assert_true("adv_card_viewing_prep", _card_is_viewing(screen, "dev_stage_mist_02"))
	_assert_true("adv_card_other_not_viewing", _card_is_viewing(screen, "dev_stage_mist_01") == false)
	_assert_true(
		"adv_prepare_cons",
		_assert_selection_consistent(screen, "dev_stage_mist_02")
	)
	_assert_eq("adv_prepare_cons_state", str(AdventureState.get_selected_stage_id()), "dev_stage_mist_02")

	screen.call("reset_prepare_refresh_count_for_tests")
	var sig_before: int = int(sig[0])
	screen.call("press_prepare_for_test")
	_assert_eq("adv_prep_same_sig", int(sig[0]), sig_before)
	_assert_eq("adv_prep_same_refresh", int(screen.call("get_prepare_refresh_count_for_tests")), 0)

	_assert_true("adv_reconfig", bool(screen.call("configure_screen", &"adventure")))
	await _tree.process_frame
	_assert_eq("adv_reconfig_keep_stage", str(screen.call("get_selected_stage_id")), "dev_stage_mist_02")

	# True leader ≠ representative: party leader stays feibao_dev while rep is partner_a.
	var leader_before: StringName = PlayerData.get_party_leader_character_id()
	_assert_eq("adv_leader_before", str(leader_before), "feibao_dev")
	PlayerData.grant_character(&"partner_a")
	var sel_res: Dictionary = PlayerData.select_character(&"partner_a")
	_assert_true("adv_rep_select_ok", bool(sel_res.get("ok", false)))
	_assert_eq("adv_rep_id", str(PlayerData.get_selected_character_id()), "partner_a")
	_assert_eq("adv_leader_id", str(PlayerData.get_party_leader_character_id()), "feibao_dev")
	_assert_true(
		"adv_leader_rep_diff",
		str(PlayerData.get_selected_character_id()) != str(PlayerData.get_party_leader_character_id())
	)
	var prepared_before_party: String = str(AdventureState.get_selected_stage_id())
	var stage_before_party: String = str(screen.call("get_selected_stage_id"))
	screen.call("reset_party_summary_refresh_count_for_tests")
	# profile_changed already fired on select; force one explicit summary path via reconfigure profile signal
	# Trigger a single grant-noop-free profile touch: re-select same rep is no-op; use grant of already-owned is no-op.
	# Refresh count is measured against a deliberate profile_changed after reset:
	PlayerData.grant_character(&"partner_b")
	await _tree.process_frame
	_assert_eq("adv_party_refresh", int(screen.call("get_party_summary_refresh_count_for_tests")), 1)
	var leader_display: String = _character_display_name(&"feibao_dev")
	var rep_display: String = _character_display_name(&"partner_a")
	var party_text: String = str(screen.call("get_party_summary_text"))
	var party_size: int = PlayerData.get_active_party_character_ids().size()
	_assert_true("adv_party_shows_leader_name", party_text.find(leader_display) >= 0)
	_assert_true("adv_party_not_rep_as_leader", party_text.find(rep_display) < 0)
	_assert_true("adv_party_size_fmt", party_text.find("目前隊伍 %d 人" % party_size) >= 0)
	_assert_eq("adv_stage_stable", str(screen.call("get_selected_stage_id")), stage_before_party)
	_assert_eq("adv_prepared_stable", str(AdventureState.get_selected_stage_id()), prepared_before_party)

	var back: Button = screen.call("get_back_button") as Button
	_assert_true("adv_back_h", back != null and back.custom_minimum_size.y >= 48.0)
	var prep: Button = screen.call("get_prepare_button") as Button
	_assert_true("adv_prep_h", prep != null and prep.custom_minimum_size.y >= 48.0)

	# Consistency after prepare: internal = visible = detail = prepared
	_assert_eq("adv_cons_int", str(screen.call("get_selected_stage_id")), "dev_stage_mist_02")
	_assert_eq("adv_cons_vis", str(screen.call("get_visible_selected_stage_id")), "dev_stage_mist_02")
	_assert_eq("adv_cons_detail", str(screen.call("get_detail_stage_id")), "dev_stage_mist_02")
	_assert_eq("adv_cons_prepared", str(AdventureState.get_selected_stage_id()), "dev_stage_mist_02")
	_assert_eq("adv_cards_mist", int(screen.call("get_stage_card_count")), 3)

	# A. Real AdventureScreen back with history (no NavigationState bypass).
	_nav().call("reset", &"lobby")
	_nav().call("navigate_to", &"adventure", true)
	_assert_eq("adv_hist_setup_cur", str(_nav().call("get_current_screen")), "adventure")
	_assert_eq("adv_hist_setup_size", int(_nav().call("get_history_size")), 1)
	var hist_sig: Array = [0]
	var hist_cb := func() -> void:
		hist_sig[0] = int(hist_sig[0]) + 1
	screen.back_requested.connect(hist_cb)
	var back_btn: Button = screen.call("get_back_button") as Button
	_assert_true("adv_hist_back_btn", back_btn != null)
	if back_btn != null:
		back_btn.pressed.emit()
	else:
		screen.call("request_back")
	await _tree.process_frame
	_assert_eq("adv_hist_final_screen", str(_nav().call("get_current_screen")), "lobby")
	_assert_eq("adv_hist_size_after", int(_nav().call("get_history_size")), 0)
	_assert_eq("adv_hist_sig", int(hist_sig[0]), 1)
	# No duplicate signal on second emit without new press path setup
	if screen.back_requested.is_connected(hist_cb):
		screen.back_requested.disconnect(hist_cb)

	# B. Empty history fallback via AdventureScreen API (ScreenRegistry back_fallback).
	_nav().call("reset", &"adventure")
	_assert_eq("adv_fb_setup_cur", str(_nav().call("get_current_screen")), "adventure")
	_assert_eq("adv_fb_setup_hist", int(_nav().call("get_history_size")), 0)
	_assert_eq("adv_fb_registry", str(ScreenRegistry.get_back_fallback(&"adventure")), "lobby")
	var fb_sig: Array = [0]
	var fb_cb := func() -> void:
		fb_sig[0] = int(fb_sig[0]) + 1
	screen.back_requested.connect(fb_cb)
	var phase_before: int = int(_app().call("get_phase")) if _app().has_method("get_phase") else -1
	_assert_true("adv_fb_request_ok", bool(screen.call("request_back")))
	await _tree.process_frame
	_assert_eq("adv_fb_final_screen", str(_nav().call("get_current_screen")), "lobby")
	_assert_eq("adv_fb_hist_still_0", int(_nav().call("get_history_size")), 0)
	_assert_eq("adv_fb_sig", int(fb_sig[0]), 1)
	_assert_true("adv_fb_no_quit", _tree != null and is_instance_valid(_tree.root))
	if phase_before >= 0 and _app().has_method("get_phase"):
		_assert_true("adv_fb_phase_alive", int(_app().call("get_phase")) >= 0)
	if screen.back_requested.is_connected(fb_cb):
		screen.back_requested.disconnect(fb_cb)

	# Double configure then prepare once → signal effect 1
	var screen2: Control = packed.instantiate() as Control
	_tree.root.add_child(screen2)
	screen2.call("configure_screen", &"adventure")
	screen2.call("configure_screen", &"adventure")
	await _tree.process_frame
	AdventureState.reset_runtime_state_for_tests()
	screen2.call("select_stage_for_test", &"dev_stage_beginner_02")
	screen2.call("reset_prepare_refresh_count_for_tests")
	var sig2: Array = [0]
	var cb2 := func(_a: StringName, _s: StringName) -> void:
		sig2[0] = int(sig2[0]) + 1
	AdventureState.prepared_stage_changed.connect(cb2)
	screen2.call("press_prepare_for_test")
	await _tree.process_frame
	_assert_eq("adv_dbl_cfg_sig", int(sig2[0]), 1)
	_assert_eq("adv_dbl_cfg_refresh", int(screen2.call("get_prepare_refresh_count_for_tests")), 1)
	if AdventureState.prepared_stage_changed.is_connected(cb2):
		AdventureState.prepared_stage_changed.disconnect(cb2)

	# Invalid prepare keeps selection
	var keep_stage: String = str(screen2.call("get_selected_stage_id"))
	var inv: Dictionary = AdventureState.prepare_stage(&"totally_invalid")
	_assert_true("adv_inv_prep_fail", bool(inv.get("ok", true)) == false)
	_assert_eq("adv_inv_sel_keep", str(screen2.call("get_selected_stage_id")), keep_stage)
	_assert_eq("adv_inv_prepared_keep", str(AdventureState.get_selected_stage_id()), "dev_stage_beginner_02")

	screen.queue_free()
	screen2.queue_free()
	await _tree.process_frame

	# Failure probes (fixture override seams; production catalog/PlayerData untouched).
	await _run_catalog_failure_probe(packed)
	await _run_player_data_unavailable_probe(packed)
	print("[INFO] adventure screen tests passed")


func _run_layout_tests() -> void:
	_begin_case("layout")
	PlayerData.initialize()
	AdventureState.reset_runtime_state_for_tests()
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280)]:
		await _probe_layout(size)


func _probe_layout(size: Vector2i) -> void:
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
	var packed: PackedScene = load("res://scenes/screens/adventure/adventure_screen.tscn") as PackedScene
	var screen: Control = packed.instantiate() as Control
	sv.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.call("configure_screen", &"adventure")
	for _i in 5:
		await _tree.process_frame
	var cols: int = int(screen.call("get_grid_columns"))
	if size.x <= 400:
		_assert_eq("al_%s_cols" % tag, cols, 2)
	if size.x >= 700:
		_assert_eq("al_%s_cols" % tag, cols, 4)
	var body: ScrollContainer = screen.call("get_body_scroll") as ScrollContainer
	_assert_true("al_%s_body" % tag, body != null)
	_assert_true(
		"al_%s_h_disabled" % tag,
		body != null and int(body.horizontal_scroll_mode) == int(ScrollContainer.SCROLL_MODE_DISABLED)
	)
	var range_v: float = 0.0
	var vmax: float = 0.0
	var vpage: float = 0.0
	if body != null and body.get_v_scroll_bar() != null:
		var vb: ScrollBar = body.get_v_scroll_bar()
		vmax = float(vb.max_value)
		vpage = float(vb.page)
		range_v = maxf(0.0, vmax - vpage)
		print(
			"[INFO] adv_scroll_%s vmax=%.1f page=%.1f range=%.1f"
			% [tag, vmax, vpage, range_v]
		)
	if size.x <= 400:
		_assert_true("al_%s_range" % tag, range_v > 0.5)
	var screen_rect: Rect2 = screen.get_global_rect()
	var prep: Button = screen.call("get_prepare_button") as Button
	if prep != null:
		screen.call("ensure_control_visible_for_test", prep)
		await _tree.process_frame
		var pr: Rect2 = prep.get_global_rect()
		_assert_true("al_%s_prep_h" % tag, pr.size.y >= 48.0)
		_assert_true("al_%s_prep_min" % tag, prep.custom_minimum_size.y >= 48.0)
		_assert_true("al_%s_prep_no_h_overflow" % tag, pr.end.x <= screen_rect.end.x + 2.0)
		if body != null:
			var br: Rect2 = body.get_global_rect()
			_assert_true("al_%s_prep_visible" % tag, pr.intersects(br) and pr.end.y <= br.end.y + 4.0)
	var grid: GridContainer = screen.call("get_stage_grid") as GridContainer
	_assert_true("al_%s_grid" % tag, grid != null)
	if grid != null:
		_assert_true("al_%s_card_count" % tag, grid.get_child_count() >= 3)
		for ci in mini(3, grid.get_child_count()):
			var card: Control = grid.get_child(ci) as Control
			if card == null:
				continue
			screen.call("ensure_control_visible_for_test", card)
			await _tree.process_frame
			var cr: Rect2 = card.get_global_rect()
			_assert_true("al_%s_card%d_min" % [tag, ci], card.custom_minimum_size.y >= 88.0)
			_assert_true("al_%s_card%d_h" % [tag, ci], cr.size.y >= 88.0)
			_assert_true("al_%s_card%d_no_h_overflow" % [tag, ci], cr.end.x <= screen_rect.end.x + 2.0)
	var back: Button = screen.call("get_back_button") as Button
	if back != null:
		var bkr: Rect2 = back.get_global_rect()
		_assert_true("al_%s_back_min" % tag, back.custom_minimum_size.y >= 48.0)
		_assert_true("al_%s_back_h" % tag, bkr.size.y >= 48.0)
	# Area selector: min height AND actual rect height must both pass (no OR fallback).
	var area_row: Node = screen.find_child("AreaButtonsRow", true, false)
	_assert_true("al_%s_area_row" % tag, area_row != null)
	if area_row != null and area_row.get_child_count() > 0:
		for ai in area_row.get_child_count():
			var ab: Control = area_row.get_child(ai) as Control
			if ab == null:
				continue
			screen.call("ensure_control_visible_for_test", ab)
			await _tree.process_frame
			var abr: Rect2 = ab.get_global_rect()
			_assert_true("al_%s_area%d_min" % [tag, ai], ab.custom_minimum_size.y >= 48.0)
			_assert_true("al_%s_area%d_h" % [tag, ai], abr.size.y >= 48.0)
			_assert_true("al_%s_area%d_no_h_overflow_l" % [tag, ai], abr.position.x >= screen_rect.position.x - 2.0)
			_assert_true("al_%s_area%d_no_h_overflow_r" % [tag, ai], abr.end.x <= screen_rect.end.x + 2.0)
			if ab is Button:
				var abtn: Button = ab as Button
				_assert_true("al_%s_area%d_text" % [tag, ai], not abtn.text.is_empty())
				_assert_true("al_%s_area%d_no_clip" % [tag, ai], abtn.clip_text == false)
				_assert_true(
					"al_%s_area%d_readable" % [tag, ai],
					abr.size.y >= 48.0 and abtn.get_combined_minimum_size().y <= abr.size.y + 1.0
				)
	# No nested vertical ScrollContainer under BodyScroll content
	var nested_v: int = 0
	if body != null:
		for n in body.find_children("*", "ScrollContainer", true, false):
			if n != body:
				nested_v += 1
	_assert_eq("al_%s_no_nested_scroll" % tag, nested_v, 0)
	# Body itself must not enable horizontal scroll / overflow
	if body != null:
		var hb: ScrollBar = body.get_h_scroll_bar()
		var h_range: float = 0.0
		if hb != null:
			h_range = maxf(0.0, float(hb.max_value) - float(hb.page))
		_assert_true("al_%s_h_range_zero" % tag, h_range <= 0.5)
	# Selection consistency on layout instance (detail uses independent storage)
	_assert_eq("al_%s_sel_area" % tag, str(screen.call("get_selected_area_id")), str(screen.call("get_visible_selected_area_id")))
	_assert_eq("al_%s_sel_stage" % tag, str(screen.call("get_selected_stage_id")), str(screen.call("get_visible_selected_stage_id")))
	_assert_eq("al_%s_detail_stage" % tag, str(screen.call("get_detail_stage_id")), str(screen.call("get_selected_stage_id")))
	_assert_true("al_%s_story" % tag, str(screen.call("get_story_intro_text")).find("開發樣本") >= 0)
	var seed_hint: Node = screen.find_child("SeedHintLabel", true, false)
	_assert_true(
		"al_%s_seed_hint" % tag,
		seed_hint != null and str(seed_hint.get("text")).find("開發樣本") >= 0
	)
	print("[INFO] adv_layout_%s cols=%d range=%.1f" % [tag, cols, range_v])
	host.queue_free()
	await _tree.process_frame


func _detail_status_has(screen: Control, token: String) -> bool:
	var node: Node = screen.find_child("DetailStatusLabel", true, false)
	if node == null:
		return false
	return str(node.get("text")).find(token) >= 0


func _card_is_viewing(screen: Control, stage_id: String) -> bool:
	var card: Object = _find_stage_card(screen, stage_id)
	if card == null:
		return false
	return bool(card.call("is_viewing"))


func _card_is_prepared(screen: Control, stage_id: String) -> bool:
	var card: Object = _find_stage_card(screen, stage_id)
	if card == null:
		return false
	return bool(card.call("is_prepared"))


func _find_stage_card(screen: Control, stage_id: String) -> Object:
	var grid: GridContainer = screen.call("get_stage_grid") as GridContainer
	if grid == null:
		return null
	for child in grid.get_children():
		if child != null and child.has_method("get_stage_id") and str(child.call("get_stage_id")) == stage_id:
			return child
	return null


func _assert_selection_consistent(screen: Control, expected_stage: String) -> bool:
	var internal_id: String = str(screen.call("get_selected_stage_id"))
	var visible_id: String = str(screen.call("get_visible_selected_stage_id"))
	var detail_id: String = str(screen.call("get_detail_stage_id"))
	return (
		internal_id == expected_stage
		and visible_id == expected_stage
		and detail_id == expected_stage
	)


func _character_display_name(character_id: StringName) -> String:
	var cat: Dictionary = CharacterCatalog.load_default()
	if bool(cat.get("ok", false)):
		for item in cat.get("characters", []):
			if item is CharacterDefinition and (item as CharacterDefinition).get_id() == character_id:
				return (item as CharacterDefinition).get_display_name()
	return str(character_id)


func _find_stage_def(stage_id: StringName) -> StageDefinition:
	var found: Dictionary = StageCatalog.find_stage(stage_id)
	if not bool(found.get("ok", false)):
		return null
	return found.get("stage") as StageDefinition


func _run_catalog_failure_probe(packed: PackedScene) -> void:
	_begin_case("catalog_fail")
	PlayerData.initialize()
	var rev_before: int = PlayerData.get_profile().get_revision()
	var party_before: int = PlayerData.get_active_party_character_ids().size()
	AdventureState.reset_runtime_state_for_tests()
	AdventureState.prepare_stage(&"dev_stage_beginner_01")
	var prepared_before: String = str(AdventureState.get_selected_stage_id())
	var disk_before: bool = PlayerData.did_last_save_write_disk()
	_nav().call("reset", &"adventure")

	var screen: Control = packed.instantiate() as Control
	# Override before enter_tree so auto-configure (if any) uses the fail-closed seam.
	screen.call(
		"set_stage_catalog_override_for_tests",
		{"ok": false, "error": "test forced catalog failure", "areas": [], "stages": []}
	)
	_tree.root.add_child(screen)
	_assert_true("adv_cf_cfg", bool(screen.call("configure_screen", &"adventure")))
	await _tree.process_frame
	await _tree.process_frame

	_assert_true("adv_cf_load_ok_false", bool(screen.call("is_load_ok")) == false)
	_assert_eq("adv_cf_area_empty", str(screen.call("get_selected_area_id")), "")
	_assert_eq("adv_cf_stage_empty", str(screen.call("get_selected_stage_id")), "")
	_assert_eq("adv_cf_vis_area_empty", str(screen.call("get_visible_selected_area_id")), "")
	_assert_eq("adv_cf_vis_stage_empty", str(screen.call("get_visible_selected_stage_id")), "")
	_assert_eq("adv_cf_detail_empty", str(screen.call("get_detail_stage_id")), "")
	_assert_true("adv_cf_error_visible", bool(screen.call("is_error_state_visible")))
	var err_text: String = str(screen.call("get_error_text"))
	_assert_true("adv_cf_error_msg", not err_text.is_empty())
	_assert_true(
		"adv_cf_error_readable",
		err_text.find("失敗") >= 0 or err_text.find("catalog") >= 0 or err_text.find("failure") >= 0
	)
	var prep: Button = screen.call("get_prepare_button") as Button
	_assert_true("adv_cf_prep_disabled", prep != null and prep.disabled)
	_assert_eq("adv_cf_state_unchanged", str(AdventureState.get_selected_stage_id()), prepared_before)
	_assert_eq("adv_cf_rev_unchanged", PlayerData.get_profile().get_revision(), rev_before)
	_assert_eq("adv_cf_party_unchanged", PlayerData.get_active_party_character_ids().size(), party_before)
	_assert_eq("adv_cf_disk_flag", PlayerData.did_last_save_write_disk(), disk_before)
	_assert_eq("adv_cf_nav_still_adv", str(_nav().call("get_current_screen")), "adventure")
	screen.call("clear_stage_catalog_override_for_tests")
	screen.queue_free()
	await _tree.process_frame


func _run_player_data_unavailable_probe(packed: PackedScene) -> void:
	_begin_case("player_data_fail")
	PlayerData.initialize()
	AdventureState.reset_runtime_state_for_tests()
	var prepared_seed: Dictionary = AdventureState.prepare_stage(&"dev_stage_beginner_02")
	_assert_true("adv_pd_seed_ok", bool(prepared_seed.get("ok", false)))
	var prepared_before: String = str(AdventureState.get_selected_stage_id())
	var rev_before: int = PlayerData.get_profile().get_revision()
	_nav().call("reset", &"adventure")

	var screen: Control = packed.instantiate() as Control
	_tree.root.add_child(screen)
	_assert_true("adv_pd_cfg", bool(screen.call("configure_screen", &"adventure")))
	await _tree.process_frame
	# Override after load so catalog still works; party/prepare paths use the seam.
	screen.call("set_player_data_available_override_for_tests", false)
	# Force UI paths that depend on PlayerData seam.
	screen.call("configure_screen", &"adventure")
	await _tree.process_frame
	await _tree.process_frame

	var party_text: String = str(screen.call("get_party_summary_text"))
	_assert_true("adv_pd_msg", party_text.find("無法讀取隊伍資料") >= 0)
	var prep: Button = screen.call("get_prepare_button") as Button
	_assert_true("adv_pd_prep_disabled", prep != null and prep.disabled)
	# Direct handler call must also fail-safe (not only Button.disabled).
	screen.call("press_prepare_for_test")
	await _tree.process_frame
	_assert_eq("adv_pd_state_unchanged", str(AdventureState.get_selected_stage_id()), prepared_before)
	_assert_true(
		"adv_pd_handler_msg",
		str(screen.call("get_mutation_message")).find("無法讀取隊伍資料") >= 0
	)
	_assert_eq("adv_pd_rev_unchanged", PlayerData.get_profile().get_revision(), rev_before)
	_assert_eq("adv_pd_nav_still", str(_nav().call("get_current_screen")), "adventure")
	_assert_true("adv_pd_no_quit", is_instance_valid(_tree.root))
	screen.call("clear_player_data_available_override_for_tests")
	screen.queue_free()
	await _tree.process_frame


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
