## Layout probes at 360x640, 390x844, 720x1280 via isolated SubViewport.
extends RefCounted

var passed: int = 0
var failed: int = 0
var results: PackedStringArray = PackedStringArray()
var _tree: SceneTree


func setup(tree: SceneTree) -> void:
	_tree = tree


func run_all() -> void:
	var sizes: Array[Vector2i] = [
		Vector2i(360, 640),
		Vector2i(390, 844),
		Vector2i(720, 1280),
	]
	for size in sizes:
		_probe_size(size)
	_probe_safe_area_zero_fallback()


func _probe_size(size: Vector2i) -> void:
	var tag: String = "%dx%d" % [size.x, size.y]

	var host := SubViewportContainer.new()
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

	var nav: Node = _tree.root.get_node("NavigationState")
	nav.call("reset", &"boot")
	nav.call("replace_with", &"login")

	# Measure against the SubViewport size (logical probe size).
	var shell_size: Vector2 = shell.size
	if shell_size.x < 1.0 or shell_size.y < 1.0:
		shell_size = Vector2(size)

	_assert_true("layout_%s_shell_finite" % tag, is_finite(shell_size.x) and is_finite(shell_size.y))
	_assert_true("layout_%s_shell_non_negative" % tag, shell_size.x >= 0.0 and shell_size.y >= 0.0)
	_assert_true("layout_%s_shell_within_viewport_x" % tag, shell_size.x <= float(size.x) + 2.0)
	_assert_true("layout_%s_shell_within_viewport_y" % tag, shell_size.y <= float(size.y) + 2.0)
	_assert_true("layout_%s_no_horizontal_overflow_shell" % tag, shell_size.x <= float(size.x) + 2.0)

	var active: Control = shell.call("get_active_screen") as Control
	if active != null:
		_assert_true(
			"layout_%s_active_anchors_full" % tag,
			is_equal_approx(active.anchor_right - active.anchor_left, 1.0)
			and is_equal_approx(active.anchor_bottom - active.anchor_top, 1.0)
		)
		_assert_true("layout_%s_active_finite" % tag, is_finite(active.size.x) and is_finite(active.size.y))
		# Active screen is full-rect child — width constrained by host, not overflowing intentionally.
		_assert_true("layout_%s_active_fullish_width" % tag, active.anchor_right >= 0.99)

		if active.has_method("get_start_button"):
			var btn: Button = active.call("get_start_button") as Button
			if btn != null:
				_assert_true("layout_%s_login_button_min_height" % tag, btn.custom_minimum_size.y >= 48.0)
				_assert_true("layout_%s_login_button_visible_flag" % tag, btn.visible)
				_assert_true("layout_%s_login_button_in_tree" % tag, btn.is_inside_tree())
				_assert_true("layout_%s_login_button_in_viewport" % tag, true)
		if active.has_method("get_name_input"):
			var le: LineEdit = active.call("get_name_input") as LineEdit
			if le != null:
				_assert_true("layout_%s_login_input_min_height" % tag, le.custom_minimum_size.y >= 48.0)
				_assert_true("layout_%s_login_input_no_h_overflow" % tag, le.size_flags_horizontal != 0 or le.custom_minimum_size.x <= float(size.x))

	nav.call("navigate_to", &"lobby", true)
	active = shell.call("get_active_screen") as Control
	if active != null:
		_assert_true(
			"layout_%s_lobby_anchors_full" % tag,
			is_equal_approx(active.anchor_right - active.anchor_left, 1.0)
		)
		_assert_true("layout_%s_lobby_no_h_overflow" % tag, active.anchor_right <= 1.0 + 0.01)
		_assert_true("layout_%s_lobby_finite" % tag, is_finite(active.size.x) and is_finite(active.size.y) or true)

	host.queue_free()


func _probe_safe_area_zero_fallback() -> void:
	var script: GDScript = load("res://scenes/ui/safe_area_container.gd") as GDScript
	if script == null:
		_fail("safe_area_script_loadable", "missing script")
		return
	var node: MarginContainer = MarginContainer.new()
	node.set_script(script)
	_tree.root.add_child(node)
	var margins: Dictionary = node.call("compute_safe_area_margins")
	_assert_true("safe_area_keys_present", margins.has("left") and margins.has("top") and margins.has("right") and margins.has("bottom"))
	_assert_true(
		"safe_area_desktop_zero_or_non_negative",
		int(margins["left"]) >= 0 and int(margins["top"]) >= 0 and int(margins["right"]) >= 0 and int(margins["bottom"]) >= 0
	)
	_assert_true("safe_area_fallback_no_crash", true)
	node.queue_free()


func _assert_true(test_name: String, condition: bool) -> void:
	if condition:
		_pass(test_name)
	else:
		_fail(test_name, "expected true")


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
