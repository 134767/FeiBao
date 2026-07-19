## Pattern-scope assertion integrity scanner (GROK-038 / GROK-041).
## Does NOT scan this file. Scans listed suite sources with literal/regex needles only.
## Cannot prove all logic is correct — only that listed weakened patterns are absent.
extends RefCounted

var passed: int = 0
var failed: int = 0
var results: PackedStringArray = PackedStringArray()
var _tree: SceneTree


func setup(tree: SceneTree) -> void:
	_tree = tree


func run_all() -> void:
	var targets: Array[String] = [
		"res://tests/battle_encounter_combatant_smoke_test.gd",
		"res://tests/player_attack_damage_smoke_test.gd",
		"res://core/battle/battle_combat_event.gd",
	]
	for path in targets:
		_scan_file(path)
	print("[INFO] assertion integrity scanner complete (pattern-scope only)")


func _scan_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	_assert_true("ais_open_%s" % path.get_file(), f != null)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var tag: String = path.get_file().get_basename()

	# Split-string evasion fragments previously used inside suite scanners.
	_assert_true("ais_%s_no_split_if_accepted" % tag, text.find("\"if \" + \"accepted\"") < 0)
	_assert_true("ais_%s_no_concat_accepted" % tag, text.find("+ \"accepted\"") < 0)
	_assert_true("ais_%s_no_cmin_concat" % tag, text.find("\"custom_minimum_size\" +") < 0)
	_assert_true("ais_%s_no_combined_concat" % tag, text.find("\"get_combined_minimum_size\" +") < 0)
	_assert_true("ais_%s_no_size_or_concat" % tag, text.find("size.x >= 48.0 \" + \"or") < 0)
	_assert_true("ais_%s_no_hp_or_concat" % tag, text.find("HP %d\" + \" / \"") < 0)

	# Fixed / tautological assertions.
	var re_fixed := RegEx.new()
	re_fixed.compile("_assert_true\\(\\s*\"[^\"]+\"\\s*,\\s*true\\s*\\)")
	_assert_true("ais_%s_no_assert_true_lit" % tag, re_fixed.search(text) == null)
	_assert_true("ais_%s_no_assert_true_call" % tag, text.find("assert(true)") < 0)

	# Conditional accepted-turn evidence.
	_assert_true("ais_%s_no_if_accepted" % tag, text.find("if accepted:") < 0)

	# Standalone pass statements (tab-indented line).
	var re_pass := RegEx.new()
	re_pass.compile("(?m)^\\tpass\\s*$")
	_assert_true("ais_%s_no_standalone_pass" % tag, re_pass.search(text) == null)

	# Size / HP / reachability weakened OR forms.
	_assert_true("ais_%s_no_size_x_or" % tag, text.find("size.x >= 48.0 or") < 0)
	_assert_true("ais_%s_no_size_y_or" % tag, text.find("size.y >= 48.0 or") < 0)
	_assert_true("ais_%s_no_bar_or" % tag, text.find("size.y >= 16.0 or") < 0)
	_assert_true("ais_%s_no_cmin_as_actual" % tag, text.find("custom_minimum_size.y >= 16") < 0)
	_assert_true("ais_%s_no_cmin_as_actual48" % tag, text.find("custom_minimum_size.y >= 48") < 0)
	_assert_true("ais_%s_no_combined_as_actual" % tag, text.find("get_combined_minimum_size()") < 0)
	_assert_true("ais_%s_no_hp_space_or_format" % tag, text.find("HP %d / %d") < 0)

	# GROK-041 weakened keyboard / row / tautology patterns.
	_assert_true("ais_%s_no_or_true" % tag, text.find("or true") < 0)
	_assert_true("ais_%s_no_length_gt0_row" % tag, text.find(".length() > 0") < 0)
	_assert_true("ais_%s_no_has_focus_or" % tag, text.find("has_focus() or") < 0)

	# Actual-size assertions must not OR custom_minimum_size.
	var re_size_or_cmin := RegEx.new()
	re_size_or_cmin.compile("size\\.(x|y)\\s*>=\\s*[0-9.]+\\s*-\\s*0\\.5\\s*or\\s*.*custom_minimum_size")
	_assert_true("ais_%s_no_size_or_cmin" % tag, re_size_or_cmin.search(text) == null)

	# Suite-specific positive anchors.
	if tag == "battle_encounter_combatant_smoke_test":
		_assert_true("ais_%s_has_forced_swap" % tag, text.find("try_swap_cells(Vector2i(2, 0), Vector2i(3, 0))") >= 0)
		_assert_true("ais_%s_has_subviewport" % tag, text.find("SubViewport") >= 0)
		_assert_true("ais_%s_has_rect_helper" % tag, text.find("_rect_fully_within") >= 0)
		_assert_true("ais_%s_has_space_selection" % tag, text.find("kb_space_sel") >= 0)
		_assert_true("ais_%s_has_missing_enc_screen" % tag, text.find("me_screen_runtime_ok") >= 0)
		_assert_true("ais_%s_has_space_xy" % tag, text.find("kb_space_xy") >= 0)
	elif tag == "player_attack_damage_smoke_test":
		_assert_true("ais_%s_has_row_exact" % tag, text.find("k11_row_exact") >= 0)
		_assert_true("ais_%s_has_sum_exact" % tag, text.find("k11_sum_exact") >= 0)
		_assert_true("ais_%s_has_hscroll_range" % tag, text.find("hscroll_range") >= 0)
		_assert_true("ais_%s_has_vscroll_count" % tag, text.find("vscroll_count") >= 0)
		_assert_true("ais_%s_has_gui_focus" % tag, text.find("gui_get_focus_owner") >= 0)
		_assert_true("ais_%s_has_e4" % tag, text.find("e4_miss_second") >= 0)
		_assert_true("ais_%s_has_under" % tag, text.find("k2_under") >= 0)
	elif tag == "battle_combat_event":
		_assert_true("ais_%s_has_min_actual" % tag, text.find("min(calculated_damage, hp_before)") >= 0)
		_assert_true("ais_%s_has_zero_hp_eq" % tag, text.find("zero attack requires target_hp_before == target_hp_after") >= 0)


func _assert_true(name: String, cond: bool) -> void:
	if cond:
		passed += 1
		print("[PASS] %s" % name)
	else:
		failed += 1
		print("[FAIL] %s" % name)
		results.append(name)
