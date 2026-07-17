## Headless-native smoke test runner (no external addons).
## Usage: godot --headless --path . --script res://tests/test_runner.gd
extends SceneTree


func _initialize() -> void:
	# Defer until after autoload _ready() so GameConfig has loaded JSON.
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("=== FeiBao Architecture Smoke Tests ===")
	var script: GDScript = load("res://tests/architecture_smoke_test.gd") as GDScript
	if script == null:
		print("[FAIL] load_architecture_smoke_test: could not load script")
		print("TEST SUMMARY: 0 passed, 1 failed")
		quit(1)
		return

	var suite: RefCounted = script.new() as RefCounted
	if suite == null:
		print("[FAIL] instantiate_architecture_smoke_test: new() failed")
		print("TEST SUMMARY: 0 passed, 1 failed")
		quit(1)
		return

	suite.call("setup", self)
	suite.call("run_all")

	var passed: int = int(suite.get("passed"))
	var failed: int = int(suite.get("failed"))
	var summary: String = "TEST SUMMARY: %d passed, %d failed" % [passed, failed]
	print(summary)

	if failed > 0:
		quit(1)
	else:
		quit(0)
