## Headless-native suite runner (no external addons).
## Usage: godot --headless --path . --script res://tests/test_runner.gd
extends SceneTree


func _initialize() -> void:
	# Defer until after autoload _ready().
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("=== FeiBao Test Runner (1.1.0) ===")
	var total_passed: int = 0
	var total_failed: int = 0

	# Isolate suite from production user://feibao saves.
	var suite_path: String = "user://feibao_tests/suite_main"
	var player_data: Node = root.get_node_or_null("PlayerData")
	var prod_before: Dictionary = _snapshot_production_artifacts()
	if player_data != null:
		player_data.call("configure_test_storage_path", suite_path)
		player_data.call("reset_runtime_state_for_tests")
		player_data.call("cleanup_test_artifacts")

	var suites: PackedStringArray = PackedStringArray([
		"res://tests/architecture_smoke_test.gd",
		"res://tests/game_shell_smoke_test.gd",
		"res://tests/module_navigation_smoke_test.gd",
		"res://tests/character_catalog_smoke_test.gd",
		"res://tests/player_profile_save_smoke_test.gd",
		"res://tests/character_ownership_smoke_test.gd",
		"res://tests/active_party_smoke_test.gd",
		"res://tests/adventure_stage_smoke_test.gd",
		"res://tests/battle_session_smoke_test.gd",
		"res://tests/battle_board_turn_loop_smoke_test.gd",
		"res://tests/battle_encounter_combatant_smoke_test.gd",
		"res://tests/layout_smoke_test.gd",
	])

	var adventure_state: Node = root.get_node_or_null("AdventureState")
	var battle_state: Node = root.get_node_or_null("BattleState")
	var battle_runtime: Node = root.get_node_or_null("BattleRuntime")
	if adventure_state != null and adventure_state.has_method("reset_runtime_state_for_tests"):
		adventure_state.call("reset_runtime_state_for_tests")
	if battle_state != null and battle_state.has_method("reset_runtime_state_for_tests"):
		battle_state.call("reset_runtime_state_for_tests")
	if battle_runtime != null and battle_runtime.has_method("reset_runtime_state_for_tests"):
		battle_runtime.call("reset_runtime_state_for_tests")

	for path in suites:
		print("--- Suite: %s ---" % path)
		if adventure_state != null and adventure_state.has_method("reset_runtime_state_for_tests"):
			adventure_state.call("reset_runtime_state_for_tests")
		if battle_state != null and battle_state.has_method("reset_runtime_state_for_tests"):
			battle_state.call("reset_runtime_state_for_tests")
		if battle_runtime != null and battle_runtime.has_method("reset_runtime_state_for_tests"):
			battle_runtime.call("reset_runtime_state_for_tests")
		var script: GDScript = load(path) as GDScript
		if script == null:
			print("[FAIL] load_suite: %s" % path)
			total_failed += 1
			continue
		var suite: RefCounted = script.new() as RefCounted
		if suite == null:
			print("[FAIL] instantiate_suite: %s" % path)
			total_failed += 1
			continue
		suite.call("setup", self)
		# Await so suites that use process_frame can complete layout.
		await suite.run_all()
		total_passed += int(suite.get("passed"))
		total_failed += int(suite.get("failed"))

	# Restore PlayerData away from production and clean suite artifacts.
	if player_data != null:
		player_data.call("configure_test_storage_path", suite_path)
		player_data.call("cleanup_test_artifacts")
		player_data.call("clear_test_storage_path")
		player_data.call("reset_runtime_state_for_tests")
	if adventure_state != null and adventure_state.has_method("reset_runtime_state_for_tests"):
		adventure_state.call("reset_runtime_state_for_tests")
	if battle_state != null and battle_state.has_method("reset_runtime_state_for_tests"):
		battle_state.call("reset_runtime_state_for_tests")
	if battle_runtime != null and battle_runtime.has_method("reset_runtime_state_for_tests"):
		battle_runtime.call("reset_runtime_state_for_tests")

	var prod_after: Dictionary = _snapshot_production_artifacts()
	if not _production_fingerprints_match(prod_before, prod_after):
		print("[FAIL] production_save_fingerprints_changed")
		total_failed += 1
	else:
		print("[PASS] production_save_fingerprints_unchanged")
		total_passed += 1

	var summary: String = "TEST SUMMARY: %d passed, %d failed" % [total_passed, total_failed]
	print(summary)

	if total_failed > 0:
		quit(1)
	else:
		quit(0)


func _prod_paths() -> PackedStringArray:
	return PackedStringArray([
		"user://feibao/player_profile.json",
		"user://feibao/player_profile.json.tmp",
		"user://feibao/player_profile.json.bak",
	])


func _snapshot_production_artifacts() -> Dictionary:
	var snap: Dictionary = {}
	for path in _prod_paths():
		snap[path] = _file_fingerprint(path)
	return snap


func _file_fingerprint(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "sha256": "", "length": -1}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"exists": true, "sha256": "UNREADABLE", "length": -1}
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return {
		"exists": true,
		"sha256": ctx.finish().hex_encode(),
		"length": bytes.size(),
	}


func _production_fingerprints_match(before: Dictionary, after: Dictionary) -> bool:
	for path in _prod_paths():
		var b: Dictionary = before.get(path, {}) as Dictionary
		var a: Dictionary = after.get(path, {}) as Dictionary
		if bool(b.get("exists", false)) != bool(a.get("exists", false)):
			return false
		if str(b.get("sha256", "")) != str(a.get("sha256", "")):
			return false
		if int(b.get("length", -2)) != int(a.get("length", -3)):
			return false
	return true
