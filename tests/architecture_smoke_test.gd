## Architecture smoke assertions (0.2.0). Replaces FoundationScreen checks with GameShell equivalents.
extends RefCounted

var passed: int = 0
var failed: int = 0
var results: PackedStringArray = PackedStringArray()
var _tree: SceneTree


func setup(tree: SceneTree) -> void:
	_tree = tree


func run_all() -> void:
	_assert_true("project_godot_parsable", _project_godot_exists())
	_assert_true("main_scene_exists", _main_scene_exists())
	_assert_true("bootstrap_scene_loadable", _bootstrap_scene_loadable())
	_assert_true("game_shell_instantiable", _game_shell_instantiable())
	_assert_true("autoload_app_state_exists", ResourceLoader.exists("res://autoload/app_state.gd"))
	_assert_true("autoload_scene_router_exists", ResourceLoader.exists("res://autoload/scene_router.gd"))
	_assert_true("autoload_game_config_exists", ResourceLoader.exists("res://autoload/game_config.gd"))
	_assert_true("autoload_scripts_parsable", _autoload_scripts_parsable())
	_assert_true("game_config_json_loadable", _game_config_json_loadable())
	_assert_eq("app_name_equals_FeiBao", str(_game_config().call("get_app_name")), "FeiBao")
	_assert_eq("app_version_equals_0_4_0", str(_game_config().call("get_app_version")), "0.4.0")
	_assert_eq("design_width_equals_720", int(_game_config().call("get_design_width")), 720)
	_assert_eq("design_height_equals_1280", int(_game_config().call("get_design_height")), 1280)
	_assert_eq("orientation_equals_portrait", str(_game_config().call("get_orientation")), "portrait")
	_assert_true("scene_router_missing_scene_fails_safely", _scene_router_missing_fails_safely())
	_assert_true("app_state_reset_to_bootstrap", _app_state_reset_works())


func _app_state() -> Node:
	return _tree.root.get_node("AppState")


func _scene_router() -> Node:
	return _tree.root.get_node("SceneRouter")


func _game_config() -> Node:
	return _tree.root.get_node("GameConfig")


func _project_godot_exists() -> bool:
	return FileAccess.file_exists("res://project.godot")


func _main_scene_exists() -> bool:
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene.is_empty():
		return false
	return ResourceLoader.exists(main_scene)


func _bootstrap_scene_loadable() -> bool:
	var path: String = "res://scenes/bootstrap/bootstrap.tscn"
	if not ResourceLoader.exists(path):
		return false
	var packed: PackedScene = load(path) as PackedScene
	return packed != null


func _game_shell_instantiable() -> bool:
	var path: String = "res://scenes/shell/game_shell.tscn"
	if not ResourceLoader.exists(path):
		return false
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return false
	var instance: Node = packed.instantiate()
	if instance == null:
		return false
	instance.free()
	return true


func _autoload_scripts_parsable() -> bool:
	var paths: PackedStringArray = PackedStringArray([
		"res://autoload/app_state.gd",
		"res://autoload/scene_router.gd",
		"res://autoload/game_config.gd",
		"res://autoload/navigation_state.gd",
	])
	for path in paths:
		var script: Script = load(path) as Script
		if script == null:
			return false
	return true


func _game_config_json_loadable() -> bool:
	if not FileAccess.file_exists("res://data/game_config.json"):
		return false
	var gc: Node = _game_config()
	if gc == null:
		return false
	return bool(gc.call("did_load_succeed"))


func _scene_router_missing_fails_safely() -> bool:
	var router: Node = _scene_router()
	if router == null:
		return false
	var result: Variant = router.call("change_scene", "res://scenes/does_not_exist_xyz.tscn")
	return result == false


func _app_state_reset_works() -> bool:
	var state: Node = _app_state()
	if state == null:
		return false
	# Phase enum: BOOTSTRAP=0, BOOT=1, LOGIN=2, LOBBY=3
	state.call("set_phase", 2)
	if int(state.call("get_phase")) != 2:
		return false
	state.call("set_player_name", "Temp")
	state.call("reset")
	return int(state.call("get_phase")) == 0 and str(state.call("get_player_name")) == ""


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
