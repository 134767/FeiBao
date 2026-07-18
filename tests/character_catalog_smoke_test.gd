## Character catalog foundation tests (0.4.0).
extends RefCounted

var passed: int = 0
var failed: int = 0
var results: PackedStringArray = PackedStringArray()
var _tree: SceneTree
var _shell: Control = null


func setup(tree: SceneTree) -> void:
	_tree = tree


func run_all() -> void:
	_run_data_contract_tests()
	_run_registry_tests()
	_run_card_tests()
	_run_screen_tests()
	_run_shell_tests()
	await _run_layout_tests()
	_cleanup_shell()


func _nav() -> Node:
	return _tree.root.get_node("NavigationState")


func _app() -> Node:
	return _tree.root.get_node("AppState")


func _run_data_contract_tests() -> void:
	var default_result: Dictionary = CharacterCatalog.load_default()
	_assert_true("catalog_default_ok", bool(default_result.get("ok", false)))
	_assert_eq("catalog_default_error_empty", str(default_result.get("error", "x")), "")
	var chars: Array = default_result.get("characters", [])
	_assert_eq("catalog_seed_count", chars.size(), 6)

	var all_seed: bool = true
	var ids: Array[String] = []
	var prev_sort: int = -1
	var prev_id: String = ""
	for i in chars.size():
		var def: CharacterDefinition = chars[i] as CharacterDefinition
		_assert_true("catalog_item_is_def_%d" % i, def != null)
		if def == null:
			all_seed = false
			continue
		if not def.is_development_seed():
			all_seed = false
		ids.append(str(def.get_id()))
		_assert_true("catalog_id_nonempty_%d" % i, not str(def.get_id()).is_empty())
		_assert_true("catalog_name_nonempty_%d" % i, not def.get_display_name().is_empty())
		_assert_true("catalog_species_nonempty_%d" % i, not def.get_species().is_empty())
		_assert_true("catalog_summary_nonempty_%d" % i, not def.get_summary().is_empty())
		_assert_true("catalog_desc_nonempty_%d" % i, not def.get_description().is_empty())
		_assert_true("catalog_tags_nonempty_%d" % i, def.get_tags().size() > 0)
		_assert_true("catalog_sort_nonneg_%d" % i, def.get_sort_order() >= 0)
		_assert_eq("catalog_portrait_empty_%d" % i, def.get_portrait_path(), "")
		if i > 0:
			var order_ok: bool = (
				def.get_sort_order() > prev_sort
				or (def.get_sort_order() == prev_sort and str(def.get_id()) >= prev_id)
			)
			_assert_true("catalog_order_%d" % i, order_ok)
		prev_sort = def.get_sort_order()
		prev_id = str(def.get_id())
		# Source tags must not be mutated via returned array.
		var tags_copy: Array[String] = def.get_tags()
		var original_size: int = tags_copy.size()
		tags_copy.append("mutated")
		_assert_eq("catalog_tags_not_mutated_%d" % i, def.get_tags().size(), original_size)

	_assert_true("catalog_all_development_seed", all_seed)
	_assert_eq("catalog_first_id", ids[0] if ids.size() > 0 else "", "feibao_dev")
	_assert_true("catalog_has_partner_a", "partner_a" in ids)

	# schema exact
	var bad_schema: Dictionary = CharacterCatalog.parse_json_text(
		'{"schema_version":2,"catalog_kind":"development_seed","characters":[]}'
	)
	_assert_true("catalog_reject_schema", bool(bad_schema.get("ok", true)) == false)
	_assert_true("catalog_reject_schema_msg", str(bad_schema.get("error", "")).find("schema_version") >= 0)

	var bad_root: Dictionary = CharacterCatalog.parse_json_text("[1,2,3]")
	_assert_true("catalog_reject_root_type", bool(bad_root.get("ok", true)) == false)

	var bad_kind: Dictionary = CharacterCatalog.parse_json_text(
		'{"schema_version":1,"catalog_kind":"production","characters":[]}'
	)
	_assert_true("catalog_reject_kind", bool(bad_kind.get("ok", true)) == false)

	var bad_chars_type: Dictionary = CharacterCatalog.parse_json_text(
		'{"schema_version":1,"catalog_kind":"development_seed","characters":{}}'
	)
	_assert_true("catalog_reject_characters_type", bool(bad_chars_type.get("ok", true)) == false)

	var missing_field: Dictionary = CharacterCatalog.parse_json_text(
		'{"schema_version":1,"catalog_kind":"development_seed","characters":[{"id":"a"}]}'
	)
	_assert_true("catalog_reject_missing_fields", bool(missing_field.get("ok", true)) == false)

	var bad_id: Dictionary = CharacterCatalog.parse_json_text(_one_char_json("Bad-ID", "Name", 0, true))
	_assert_true("catalog_reject_id_syntax", bool(bad_id.get("ok", true)) == false)

	var empty_name: Dictionary = CharacterCatalog.parse_json_text(_one_char_json("ok_id", "", 0, true))
	_assert_true("catalog_reject_empty_name", bool(empty_name.get("ok", true)) == false)

	var bad_tags: Dictionary = CharacterCatalog.parse_json_text(
		'{"schema_version":1,"catalog_kind":"development_seed","characters":[{'
		+ '"id":"ok_id","display_name":"N","species":"S","summary":"U","description":"D",'
		+ '"tags":[""],"sort_order":0,"portrait_path":"","is_development_seed":true}]}'
	)
	_assert_true("catalog_reject_bad_tags", bool(bad_tags.get("ok", true)) == false)

	var neg_sort: Dictionary = CharacterCatalog.parse_json_text(_one_char_json("ok_id", "N", -1, true))
	_assert_true("catalog_reject_neg_sort", bool(neg_sort.get("ok", true)) == false)

	var bad_flag: Dictionary = CharacterCatalog.parse_json_text(
		'{"schema_version":1,"catalog_kind":"development_seed","characters":[{'
		+ '"id":"ok_id","display_name":"N","species":"S","summary":"U","description":"D",'
		+ '"tags":["t"],"sort_order":0,"portrait_path":"","is_development_seed":1}]}'
	)
	_assert_true("catalog_reject_flag_type", bool(bad_flag.get("ok", true)) == false)

	var dup: Dictionary = CharacterCatalog.parse_json_text(
		'{"schema_version":1,"catalog_kind":"development_seed","characters":['
		+ _char_obj("dup_id", "A", 0) + "," + _char_obj("dup_id", "B", 1)
		+ "]}"
	)
	_assert_true("catalog_reject_duplicate_id", bool(dup.get("ok", true)) == false)
	_assert_eq("catalog_dup_returns_empty_list", (dup.get("characters", [1]) as Array).size(), 0)

	var missing_file: Dictionary = CharacterCatalog.load_from_path("res://data/does_not_exist_catalog.json")
	_assert_true("catalog_missing_file_safe", bool(missing_file.get("ok", true)) == false)
	_assert_eq("catalog_missing_file_no_crash_chars", (missing_file.get("characters", [1]) as Array).size(), 0)

	# Deterministic sort: sort_order then id
	var sort_json: String = (
		'{"schema_version":1,"catalog_kind":"development_seed","characters":['
		+ _char_obj("b_id", "B", 1) + ","
		+ _char_obj("a_id", "A", 1) + ","
		+ _char_obj("z_id", "Z", 0)
		+ "]}"
	)
	var sorted_res: Dictionary = CharacterCatalog.parse_json_text(sort_json)
	_assert_true("catalog_sort_ok", bool(sorted_res.get("ok", false)))
	var sorted_chars: Array = sorted_res.get("characters", [])
	_assert_eq("catalog_sort_count", sorted_chars.size(), 3)
	if sorted_chars.size() == 3:
		_assert_eq("catalog_sort_0", str((sorted_chars[0] as CharacterDefinition).get_id()), "z_id")
		_assert_eq("catalog_sort_1", str((sorted_chars[1] as CharacterDefinition).get_id()), "a_id")
		_assert_eq("catalog_sort_2", str((sorted_chars[2] as CharacterDefinition).get_id()), "b_id")

	_run_strict_integer_and_seed_contract_tests()

	print("[INFO] character catalog data contract validations passed")


## Strict exact-integer + development_seed=true contract (GROK-009).
func _run_strict_integer_and_seed_contract_tests() -> void:
	# --- schema_version exact integer ---
	var schema_1_0: Dictionary = CharacterCatalog.parse_json_text(
		'{"schema_version":1.0,"catalog_kind":"development_seed","characters":[]}'
	)
	_assert_true("strict_schema_1_0_accepted", bool(schema_1_0.get("ok", false)))
	_assert_eq("strict_schema_1_0_chars_empty", (schema_1_0.get("characters", [1]) as Array).size(), 0)

	var schema_1_5: Dictionary = CharacterCatalog.parse_json_text(
		'{"schema_version":1.5,"catalog_kind":"development_seed","characters":[]}'
	)
	_assert_true("strict_schema_1_5_rejected", bool(schema_1_5.get("ok", true)) == false)
	_assert_true(
		"strict_schema_1_5_msg_field",
		str(schema_1_5.get("error", "")).find("schema_version") >= 0
	)
	_assert_true(
		"strict_schema_1_5_msg_exact",
		str(schema_1_5.get("error", "")).find("exact integer") >= 0
	)
	_assert_eq("strict_schema_1_5_empty_chars", (schema_1_5.get("characters", [1]) as Array).size(), 0)

	# --- sort_order exact integer ---
	var sort_2_0: Dictionary = CharacterCatalog.parse_json_text(
		_one_char_json_with_sort_literal("ok_id", "N", "2.0", true)
	)
	_assert_true("strict_sort_2_0_accepted", bool(sort_2_0.get("ok", false)))
	var sort_2_0_chars: Array = sort_2_0.get("characters", [])
	_assert_eq("strict_sort_2_0_count", sort_2_0_chars.size(), 1)
	if sort_2_0_chars.size() == 1:
		_assert_eq(
			"strict_sort_2_0_value",
			int((sort_2_0_chars[0] as CharacterDefinition).get_sort_order()),
			2
		)

	var sort_2_7: Dictionary = CharacterCatalog.parse_json_text(
		_one_char_json_with_sort_literal("ok_id", "N", "2.7", true)
	)
	_assert_true("strict_sort_2_7_rejected", bool(sort_2_7.get("ok", true)) == false)
	_assert_true(
		"strict_sort_2_7_msg_field",
		str(sort_2_7.get("error", "")).find("sort_order") >= 0
	)
	_assert_true(
		"strict_sort_2_7_msg_exact",
		str(sort_2_7.get("error", "")).find("exact integer") >= 0
	)
	_assert_eq("strict_sort_2_7_empty_chars", (sort_2_7.get("characters", [1]) as Array).size(), 0)

	var sort_neg_frac: Dictionary = CharacterCatalog.parse_json_text(
		_one_char_json_with_sort_literal("ok_id", "N", "-0.5", true)
	)
	_assert_true("strict_sort_neg_frac_rejected", bool(sort_neg_frac.get("ok", true)) == false)
	_assert_true(
		"strict_sort_neg_frac_msg_field",
		str(sort_neg_frac.get("error", "")).find("sort_order") >= 0
	)
	_assert_eq(
		"strict_sort_neg_frac_empty_chars",
		(sort_neg_frac.get("characters", [1]) as Array).size(),
		0
	)

	# --- is_development_seed must be true for development_seed catalog ---
	var seed_true: Dictionary = CharacterCatalog.parse_json_text(
		_one_char_json("seed_ok", "Seed", 0, true)
	)
	_assert_true("strict_seed_true_accepted", bool(seed_true.get("ok", false)))
	var seed_true_chars: Array = seed_true.get("characters", [])
	_assert_eq("strict_seed_true_count", seed_true_chars.size(), 1)
	if seed_true_chars.size() == 1:
		_assert_true(
			"strict_seed_true_flag",
			bool((seed_true_chars[0] as CharacterDefinition).is_development_seed())
		)

	var seed_false: Dictionary = CharacterCatalog.parse_json_text(
		_one_char_json("seed_bad", "Seed", 0, false)
	)
	_assert_true("strict_seed_false_rejected", bool(seed_false.get("ok", true)) == false)
	_assert_true(
		"strict_seed_false_msg_field",
		str(seed_false.get("error", "")).find("is_development_seed") >= 0
	)
	_assert_true(
		"strict_seed_false_msg_true",
		str(seed_false.get("error", "")).find("must be true") >= 0
	)
	_assert_eq("strict_seed_false_empty_chars", (seed_false.get("characters", [1]) as Array).size(), 0)

	# Default catalog still six true seeds
	var default_again: Dictionary = CharacterCatalog.load_default()
	_assert_true("strict_default_ok", bool(default_again.get("ok", false)))
	var default_chars: Array = default_again.get("characters", [])
	_assert_eq("strict_default_seed_count", default_chars.size(), 6)
	var all_true: bool = true
	for d in default_chars:
		if d is CharacterDefinition and not (d as CharacterDefinition).is_development_seed():
			all_true = false
	_assert_true("strict_default_all_true", all_true)

	# Integrity: deterministic order still holds after strict rules
	var integrity_sort: Dictionary = CharacterCatalog.parse_json_text(
		'{"schema_version":1.0,"catalog_kind":"development_seed","characters":['
		+ _char_obj("b_id", "B", 1) + ","
		+ _char_obj("a_id", "A", 1) + ","
		+ _char_obj("z_id", "Z", 0)
		+ "]}"
	)
	_assert_true("strict_integrity_sort_ok", bool(integrity_sort.get("ok", false)))
	var ic: Array = integrity_sort.get("characters", [])
	_assert_eq("strict_integrity_sort_count", ic.size(), 3)
	if ic.size() == 3:
		_assert_eq("strict_integrity_sort_0", str((ic[0] as CharacterDefinition).get_id()), "z_id")
		_assert_eq("strict_integrity_sort_1", str((ic[1] as CharacterDefinition).get_id()), "a_id")
		_assert_eq("strict_integrity_sort_2", str((ic[2] as CharacterDefinition).get_id()), "b_id")

	# Integrity: duplicate ID still rejected with empty list
	var integrity_dup: Dictionary = CharacterCatalog.parse_json_text(
		'{"schema_version":1,"catalog_kind":"development_seed","characters":['
		+ _char_obj("dup_id", "A", 0) + "," + _char_obj("dup_id", "B", 1)
		+ "]}"
	)
	_assert_true("strict_integrity_dup_rejected", bool(integrity_dup.get("ok", true)) == false)
	_assert_eq("strict_integrity_dup_empty", (integrity_dup.get("characters", [1]) as Array).size(), 0)

	# Integrity: invalid type (string schema) still rejected
	var integrity_type: Dictionary = CharacterCatalog.parse_json_text(
		'{"schema_version":"1","catalog_kind":"development_seed","characters":[]}'
	)
	_assert_true("strict_integrity_type_rejected", bool(integrity_type.get("ok", true)) == false)
	_assert_true(
		"strict_integrity_type_msg",
		str(integrity_type.get("error", "")).find("schema_version") >= 0
	)

	# Integrity: tag mutation protection still holds
	var mut: Dictionary = CharacterCatalog.parse_json_text(_one_char_json("mut_id", "M", 0, true))
	_assert_true("strict_integrity_mut_ok", bool(mut.get("ok", false)))
	var mut_chars: Array = mut.get("characters", [])
	if mut_chars.size() == 1:
		var tags_copy: Array[String] = (mut_chars[0] as CharacterDefinition).get_tags()
		var before: int = tags_copy.size()
		tags_copy.append("mutated")
		_assert_eq(
			"strict_integrity_tags_not_mutated",
			(mut_chars[0] as CharacterDefinition).get_tags().size(),
			before
		)

	print("[INFO] strict integer and development seed contract regressions passed")


func _one_char_json(id: String, display_name: String, sort_order: int, seed_flag: bool) -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","characters":['
		+ '{"id":"%s","display_name":"%s","species":"S","summary":"U","description":"D",'
		% [id, display_name]
		+ '"tags":["t"],"sort_order":%d,"portrait_path":"","is_development_seed":%s}]}'
		% [sort_order, "true" if seed_flag else "false"]
	)


## sort_order_literal is embedded raw (e.g. "2.0", "2.7", "-0.5") to probe JSON float handling.
func _one_char_json_with_sort_literal(
	id: String,
	display_name: String,
	sort_order_literal: String,
	seed_flag: bool
) -> String:
	return (
		'{"schema_version":1,"catalog_kind":"development_seed","characters":['
		+ '{"id":"%s","display_name":"%s","species":"S","summary":"U","description":"D",'
		% [id, display_name]
		+ '"tags":["t"],"sort_order":%s,"portrait_path":"","is_development_seed":%s}]}'
		% [sort_order_literal, "true" if seed_flag else "false"]
	)


func _char_obj(id: String, display_name: String, sort_order: int) -> String:
	return (
		'{"id":"%s","display_name":"%s","species":"S","summary":"U","description":"D",'
		% [id, display_name]
		+ '"tags":["t"],"sort_order":%d,"portrait_path":"","is_development_seed":true}'
		% sort_order
	)


func _run_registry_tests() -> void:
	_assert_eq(
		"reg_character_path",
		ScreenRegistry.get_scene_path(&"character"),
		"res://scenes/screens/character/character_screen.tscn"
	)
	_assert_eq("reg_character_kind", str(ScreenRegistry.get_kind(&"character")), "module")
	_assert_eq("reg_character_title", ScreenRegistry.get_display_title(&"character"), "角色")
	_assert_eq("reg_character_fallback", str(ScreenRegistry.get_back_fallback(&"character")), "lobby")
	_assert_true("reg_character_is_module", ScreenRegistry.is_module(&"character"))
	var modules: Array[StringName] = ScreenRegistry.get_module_ids()
	_assert_eq("reg_module_order_0", str(modules[0]), "adventure")
	_assert_eq("reg_module_order_1", str(modules[1]), "character")
	_assert_eq("reg_module_order_2", str(modules[2]), "party")
	_assert_eq("reg_module_order_3", str(modules[3]), "inventory")
	_assert_eq("reg_module_order_4", str(modules[4]), "farm")
	_assert_eq("reg_module_order_5", str(modules[5]), "settings")
	for mid in [&"inventory", &"farm", &"settings"]:
		_assert_eq(
			"reg_placeholder_path_%s" % str(mid),
			ScreenRegistry.get_scene_path(mid),
			"res://scenes/screens/module/module_screen.tscn"
		)
	_assert_eq(
		"reg_adventure_dedicated_path",
		ScreenRegistry.get_scene_path(&"adventure"),
		"res://scenes/screens/adventure/adventure_screen.tscn"
	)
	_assert_eq(
		"reg_party_dedicated_path",
		ScreenRegistry.get_scene_path(&"party"),
		"res://scenes/screens/party/party_screen.tscn"
	)
	_assert_true("reg_validate_metadata", ScreenRegistry.validate_metadata())
	_assert_true("reg_validate_resources", ScreenRegistry.validate_resources())
	_assert_true(
		"reg_character_resource_exists",
		ResourceLoader.exists("res://scenes/screens/character/character_screen.tscn")
	)
	_assert_true(
		"reg_card_resource_exists",
		ResourceLoader.exists("res://scenes/screens/character/character_card.tscn")
	)
	_assert_true(
		"reg_party_resource_exists",
		ResourceLoader.exists("res://scenes/screens/party/party_screen.tscn")
	)


func _run_card_tests() -> void:
	var packed: PackedScene = load("res://scenes/screens/character/character_card.tscn") as PackedScene
	_assert_true("card_scene_loadable", packed != null)
	var card: Button = packed.instantiate() as Button
	_tree.root.add_child(card)
	var def := CharacterDefinition.new(
		&"test_card",
		"測試卡",
		"樣本種",
		"摘要",
		"描述",
		["alpha", "beta", "gamma"] as Array[String],
		0,
		"",
		true
	)
	card.call("configure", def)
	_assert_eq("card_name", str(card.call("get_name_text")), "測試卡")
	_assert_eq("card_species", str(card.call("get_species_text")), "樣本種")
	_assert_true("card_tags_limited", str(card.call("get_tags_text")).find("gamma") < 0)
	_assert_true("card_tags_has_alpha", str(card.call("get_tags_text")).find("alpha") >= 0)
	_assert_true("card_seed_badge", bool(card.call("get_seed_badge_visible")))
	_assert_eq("card_glyph", str(card.call("get_glyph_text")), "測")
	_assert_true("card_min_height", card.custom_minimum_size.y >= 72.0)
	card.call("set_selected", true)
	_assert_true("card_selected", bool(card.call("is_selected")))
	card.call("set_selected", false)
	_assert_true("card_unselected", bool(card.call("is_selected")) == false)

	var act_count: Array = [0]
	var act_id: Array = [""]
	card.card_activated.connect(func(cid: StringName) -> void:
		act_count[0] = int(act_count[0]) + 1
		act_id[0] = str(cid)
	)
	card.emit_signal("pressed")
	_assert_eq("card_activation_count", int(act_count[0]), 1)
	_assert_eq("card_activation_id", str(act_id[0]), "test_card")
	card.queue_free()


func _run_screen_tests() -> void:
	_nav().call("reset", &"login")
	var packed: PackedScene = load("res://scenes/screens/character/character_screen.tscn") as PackedScene

	# Reject non-character configure
	var reject: Control = packed.instantiate() as Control
	_tree.root.add_child(reject)
	_assert_true("screen_reject_adventure", reject.call("configure_screen", &"adventure") == false)
	_assert_true("screen_reject_lobby", reject.call("configure_screen", &"lobby") == false)
	_assert_eq("screen_reject_id_empty", str(reject.call("get_screen_id")), "")
	reject.queue_free()

	# Pre-tree configure
	var pre: Control = packed.instantiate() as Control
	_assert_true("screen_cfg_before_tree", pre.call("configure_screen", &"character") == true)
	_tree.root.add_child(pre)
	_assert_eq("screen_id_pre", str(pre.call("get_screen_id")), "character")
	_assert_eq("screen_title_pre", str(pre.call("get_title_text")), "角色圖鑑")
	_assert_eq("screen_phase_pre", int(_app().call("get_phase")), 4)
	_assert_true("screen_load_ok_pre", bool(pre.call("is_load_ok")))
	_assert_eq("screen_cards_six", int(pre.call("get_card_count")), 6)
	_assert_eq("screen_result_six", int(pre.call("get_result_count")), 6)
	_assert_eq("screen_initial_selected", str(pre.call("get_selected_id")), "feibao_dev")
	_assert_true(
		"screen_detail_matches_selected",
		str(pre.call("get_detail_name_text")).find("飛寶") >= 0
	)
	_assert_true("screen_status_all", str(pre.call("get_status_text")).find("6") >= 0)
	_assert_true("screen_empty_hidden", bool(pre.call("is_empty_state_visible")) == false)
	_assert_true("screen_error_hidden", bool(pre.call("is_error_state_visible")) == false)

	# Selection updates detail
	_assert_true("screen_select_partner_a", bool(pre.call("select_character_for_test", &"partner_a")))
	_assert_eq("screen_selected_partner_a", str(pre.call("get_selected_id")), "partner_a")
	_assert_true(
		"screen_detail_partner_a",
		str(pre.call("get_detail_name_text")).find("夥伴 A") >= 0
	)
	# Re-select same id is stable
	_assert_true("screen_reselect_same", bool(pre.call("select_character_for_test", &"partner_a")))
	_assert_eq("screen_reselect_stable", str(pre.call("get_selected_id")), "partner_a")

	# Search by name
	pre.call("set_search_text_for_test", "飛寶")
	_assert_eq("screen_search_name_count", int(pre.call("get_result_count")), 1)
	_assert_eq("screen_search_name_selected", str(pre.call("get_selected_id")), "feibao_dev")

	# Search by species
	pre.call("set_search_text_for_test", "樣本物種 C")
	_assert_eq("screen_search_species_count", int(pre.call("get_result_count")), 1)
	_assert_eq("screen_search_species_id", str(pre.call("get_selected_id")), "partner_c")

	# Search by tag (ASCII case-insensitive)
	pre.call("set_search_text_for_test", "SCOUT")
	_assert_eq("screen_search_tag_count", int(pre.call("get_result_count")), 1)
	_assert_eq("screen_search_tag_id", str(pre.call("get_selected_id")), "partner_b")

	# Trim behavior
	pre.call("set_search_text_for_test", "  mascot  ")
	_assert_eq("screen_search_trim_count", int(pre.call("get_result_count")), 1)
	_assert_eq("screen_search_trim_id", str(pre.call("get_selected_id")), "feibao_dev")

	# Clear restores list
	pre.call("set_search_text_for_test", "")
	_assert_eq("screen_clear_count", int(pre.call("get_result_count")), 6)
	var visible_ids: Array = pre.call("get_visible_character_ids")
	_assert_eq("screen_clear_first", str(visible_ids[0]) if visible_ids.size() > 0 else "", "feibao_dev")

	# Selection preservation when still in filter
	pre.call("set_search_text_for_test", "")
	_assert_true("screen_preserve_select_d", bool(pre.call("select_character_for_test", &"partner_d")))
	_assert_eq("screen_preserve_before_filter", str(pre.call("get_selected_id")), "partner_d")
	pre.call("set_search_text_for_test", "development")
	_assert_eq("screen_preserve_count", int(pre.call("get_result_count")), 6)
	_assert_eq("screen_preserve_selected", str(pre.call("get_selected_id")), "partner_d")

	# Filtered selection fallback: select partner_e then filter to only partner_a
	pre.call("set_search_text_for_test", "")
	pre.call("select_character_for_test", &"partner_e")
	pre.call("set_search_text_for_test", "夥伴 A")
	_assert_eq("screen_filter_fallback_count", int(pre.call("get_result_count")), 1)
	_assert_eq("screen_filter_fallback_selected", str(pre.call("get_selected_id")), "partner_a")

	# No results
	pre.call("set_search_text_for_test", "zzzz_no_such_character")
	_assert_eq("screen_no_results_count", int(pre.call("get_result_count")), 0)
	_assert_true("screen_no_results_empty_visible", bool(pre.call("is_empty_state_visible")))
	_assert_eq("screen_no_results_selected", str(pre.call("get_selected_id")), "")
	_assert_true(
		"screen_no_results_detail_cleared",
		str(pre.call("get_detail_name_text")).find("請選擇") >= 0
		or str(pre.call("get_detail_name_text")) == "請選擇角色"
	)

	# Clear after no-results
	pre.call("set_search_text_for_test", "")
	_assert_eq("screen_restore_after_empty", int(pre.call("get_result_count")), 6)
	_assert_true("screen_empty_hidden_after_restore", bool(pre.call("is_empty_state_visible")) == false)

	# Back button min size
	var back: Button = pre.call("get_back_button") as Button
	_assert_true("screen_back_exists", back != null)
	_assert_true("screen_back_min_w", back.custom_minimum_size.x >= 96.0)
	_assert_true("screen_back_min_h", back.custom_minimum_size.y >= 48.0)
	var search: LineEdit = pre.call("get_search_edit") as LineEdit
	_assert_true("screen_search_exists", search != null)
	_assert_true("screen_search_min_h", search.custom_minimum_size.y >= 48.0)

	# Back with history
	_nav().call("reset", &"lobby")
	_nav().call("navigate_to", &"character", true)
	_assert_true("screen_back_history_ok", bool(pre.call("request_back")))
	_assert_eq("screen_back_history_nav", str(_nav().call("get_current_screen")), "lobby")

	# Back fallback when empty history
	_nav().call("reset", &"character")
	_assert_eq("screen_fallback_hist0", int(_nav().call("get_history_size")), 0)
	_assert_true("screen_back_fallback_ok", bool(pre.call("request_back")))
	_assert_eq("screen_back_fallback_lobby", str(_nav().call("get_current_screen")), "lobby")

	pre.queue_free()

	# Post-ready fallback configure via NavigationState
	_nav().call("reset", &"character")
	var post: Control = packed.instantiate() as Control
	_tree.root.add_child(post)
	# _ready should auto-configure from NavigationState
	_assert_eq("screen_post_ready_id", str(post.call("get_screen_id")), "character")
	_assert_true("screen_post_ready_load", bool(post.call("is_load_ok")))
	_assert_eq("screen_post_ready_cards", int(post.call("get_card_count")), 6)
	post.queue_free()

	# Load failure state
	var fail: Control = packed.instantiate() as Control
	fail.call("set_catalog_source_path", "res://data/missing_character_catalog.json")
	_assert_true("screen_fail_cfg", fail.call("configure_screen", &"character") == true)
	_tree.root.add_child(fail)
	# configure before tree with bad path — reload after ready
	fail.call("set_catalog_source_path", "res://data/missing_character_catalog.json")
	_assert_true("screen_fail_not_ok", bool(fail.call("is_load_ok")) == false)
	_assert_true("screen_fail_error_visible", bool(fail.call("is_error_state_visible")))
	_assert_eq("screen_fail_card_count", int(fail.call("get_card_count")), 0)
	fail.queue_free()

	# No duplicate signal bindings (configure twice)
	var twice: Control = packed.instantiate() as Control
	_tree.root.add_child(twice)
	_assert_true("screen_twice_1", twice.call("configure_screen", &"character") == true)
	_assert_true("screen_twice_2", twice.call("configure_screen", &"character") == true)
	var sig_count: Array = [0]
	twice.back_requested.connect(func() -> void:
		sig_count[0] = int(sig_count[0]) + 1
	)
	_nav().call("reset", &"lobby")
	_nav().call("navigate_to", &"character", true)
	twice.call("request_back")
	_assert_eq("screen_no_dup_back_signal", int(sig_count[0]), 1)
	twice.queue_free()

	print("[INFO] character screen configure/search/selection/back passed")


func _run_shell_tests() -> void:
	_cleanup_shell()
	_app().call("reset")
	_nav().call("reset", &"boot")
	var packed: PackedScene = load("res://scenes/shell/game_shell.tscn") as PackedScene
	_shell = packed.instantiate() as Control
	_tree.root.add_child(_shell)

	var boot: Node = _shell.call("get_active_screen")
	if boot != null and boot.has_method("advance_to_login"):
		boot.call("advance_to_login")
	else:
		_nav().call("replace_with", &"login")
	var login: Node = _shell.call("get_active_screen")
	_assert_true("shell_char_login", login.call("submit_player_name", "CatUser") == true)
	_assert_eq("shell_char_lobby", str(_shell.call("get_active_screen_id")), "lobby")

	var lobby: Control = _shell.call("get_active_screen") as Control
	var char_btn: Button = lobby.call("get_module_button", &"character") as Button
	char_btn.emit_signal("pressed")
	_assert_eq("shell_char_active", str(_shell.call("get_active_screen_id")), "character")
	var char_screen: Control = _shell.call("get_active_screen") as Control
	_assert_true("shell_char_script", str(char_screen.get_script().resource_path).ends_with("character_screen.gd"))
	_assert_eq("shell_char_id", str(char_screen.call("get_screen_id")), "character")
	_assert_eq("shell_char_cards", int(char_screen.call("get_card_count")), 6)
	_assert_eq("shell_char_selected", str(char_screen.call("get_selected_id")), "feibao_dev")
	var back: Button = char_screen.call("get_back_button") as Button
	back.emit_signal("pressed")
	_assert_eq("shell_char_back_lobby", str(_shell.call("get_active_screen_id")), "lobby")

	# Other modules remain ModuleScreen
	lobby = _shell.call("get_active_screen") as Control
	var farm_btn: Button = lobby.call("get_module_button", &"farm") as Button
	farm_btn.emit_signal("pressed")
	var farm_screen: Control = _shell.call("get_active_screen") as Control
	_assert_true(
		"shell_farm_still_module",
		str(farm_screen.get_script().resource_path).ends_with("module_screen.gd")
	)
	_assert_eq("shell_farm_status", str(farm_screen.call("get_status_text")), "此功能將於後續版本開放")
	farm_screen.call("get_back_button").emit_signal("pressed")
	print("[INFO] shell character dedicated scene and placeholder modules ok")


func _run_layout_tests() -> void:
	var sizes: Array[Vector2i] = [
		Vector2i(360, 640),
		Vector2i(390, 844),
		Vector2i(720, 1280),
	]
	for size in sizes:
		await _probe_character_layout(size)


func _probe_character_layout(size: Vector2i) -> void:
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

	var packed: PackedScene = load("res://scenes/shell/game_shell.tscn") as PackedScene
	var shell: Control = packed.instantiate() as Control
	sv.add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# BootScreen auto-advances to login on a deferred frame; wait it out first.
	await _tree.process_frame
	await _tree.process_frame
	_nav().call("replace_with", &"lobby")
	_nav().call("navigate_to", &"character", true)
	await _tree.process_frame
	await _tree.process_frame
	await _tree.process_frame

	var screen: Control = shell.call("get_active_screen") as Control
	_assert_true("layout_char_%s_present" % tag, screen != null)
	if screen == null:
		host.queue_free()
		return
	_assert_eq("layout_char_%s_active_id" % tag, str(shell.call("get_active_screen_id")), "character")
	if str(shell.call("get_active_screen_id")) != "character":
		host.queue_free()
		return

	var screen_rect: Rect2 = screen.get_global_rect()
	_assert_true("layout_char_%s_finite" % tag, _is_finite_rect(screen_rect))
	_assert_true(
		"layout_char_%s_inside_viewport" % tag,
		_rect_is_inside(screen_rect, viewport_rect, 2.0)
	)

	var back: Button = screen.call("get_back_button") as Button
	var search: LineEdit = screen.call("get_search_edit") as LineEdit
	_assert_true("layout_char_%s_back" % tag, back != null)
	_assert_true("layout_char_%s_search" % tag, search != null)
	if back != null:
		var br: Rect2 = back.get_global_rect()
		_assert_true("layout_char_%s_back_touch_w" % tag, br.size.x >= 96.0 or back.custom_minimum_size.x >= 96.0)
		_assert_true("layout_char_%s_back_touch_h" % tag, br.size.y >= 48.0 or back.custom_minimum_size.y >= 48.0)
		_assert_true("layout_char_%s_back_inside" % tag, _rect_is_inside(br, screen_rect, 2.0))
		_assert_true("layout_char_%s_back_no_h_overflow" % tag, br.end.x <= screen_rect.end.x + 2.0)
	if search != null:
		var sr: Rect2 = search.get_global_rect()
		_assert_true("layout_char_%s_search_h" % tag, sr.size.y >= 48.0 or search.custom_minimum_size.y >= 48.0)
		_assert_true("layout_char_%s_search_inside" % tag, _rect_is_inside(sr, screen_rect, 2.0))
		_assert_true("layout_char_%s_search_no_h_overflow" % tag, sr.end.x <= screen_rect.end.x + 2.0)

	var cols: int = int(screen.call("get_grid_columns"))
	if size.x <= 400:
		_assert_true("layout_char_%s_cols_ge2" % tag, cols >= 2)
	if size.x >= 700:
		_assert_true("layout_char_%s_cols_ge3" % tag, cols >= 3)

	var grid: GridContainer = screen.call("get_card_grid") as GridContainer
	if grid != null:
		for child in grid.get_children():
			if child is Control:
				var cr: Rect2 = (child as Control).get_global_rect()
				_assert_true(
					"layout_char_%s_card_inside" % tag,
					_rect_is_inside(cr, screen_rect, 3.0)
				)
				_assert_true(
					"layout_char_%s_card_no_h_overflow" % tag,
					cr.end.x <= screen_rect.end.x + 3.0
				)
				_assert_true(
					"layout_char_%s_card_min_h" % tag,
					cr.size.y >= 72.0 or (child as Control).custom_minimum_size.y >= 72.0
				)
				break  # one representative card probe per viewport

	var detail: PanelContainer = screen.call("get_detail_panel") as PanelContainer
	if detail != null:
		var dr: Rect2 = detail.get_global_rect()
		_assert_true("layout_char_%s_detail_inside" % tag, _rect_is_inside(dr, screen_rect, 3.0))
		_assert_true("layout_char_%s_detail_no_h_overflow" % tag, dr.end.x <= screen_rect.end.x + 3.0)

	print("[INFO] layout_char_%s cols=%d cards=%d" % [tag, cols, int(screen.call("get_card_count"))])
	host.queue_free()


func _rect_is_inside(inner: Rect2, outer: Rect2, tolerance: float = 1.0) -> bool:
	return (
		inner.position.x >= outer.position.x - tolerance
		and inner.position.y >= outer.position.y - tolerance
		and inner.end.x <= outer.end.x + tolerance
		and inner.end.y <= outer.end.y + tolerance
	)


func _is_finite_rect(r: Rect2) -> bool:
	return (
		is_finite(r.position.x)
		and is_finite(r.position.y)
		and is_finite(r.size.x)
		and is_finite(r.size.y)
		and not is_inf(r.size.x)
		and not is_nan(r.position.x)
	)


func _cleanup_shell() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.queue_free()
		_shell = null


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
