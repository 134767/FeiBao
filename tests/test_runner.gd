## Headless-native suite runner (no external addons).
## Usage: godot --headless --path . --script res://tests/test_runner.gd
extends SceneTree


func _initialize() -> void:
	# Defer until after autoload _ready().
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("=== FeiBao Test Runner (0.5.0) ===")
	var total_passed: int = 0
	var total_failed: int = 0

	# Isolate suite from production user://feibao saves.
	var suite_path: String = "user://feibao_tests/suite_main"
	var player_data: Node = root.get_node_or_null("PlayerData")
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
		"res://tests/layout_smoke_test.gd",
	])

	for path in suites:
		print("--- Suite: %s ---" % path)
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

	var summary: String = "TEST SUMMARY: %d passed, %d failed" % [total_passed, total_failed]
	print(summary)

	if total_failed > 0:
		quit(1)
	else:
		quit(0)
