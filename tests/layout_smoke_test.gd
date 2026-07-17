## Layout probes at 360x640, 390x844, 720x1280 with real Control rects after layout frames.
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
		await _probe_size(size)
	_probe_safe_area_pure()


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
		and not is_inf(r.size.y)
		and not is_nan(r.position.x)
		and not is_nan(r.size.x)
	)


func _probe_size(size: Vector2i) -> void:
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
	sv.handle_input_locally = true
	host.add_child(sv)

	var packed: PackedScene = load("res://scenes/shell/game_shell.tscn") as PackedScene
	var shell: Control = packed.instantiate() as Control
	sv.add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var nav: Node = _tree.root.get_node("NavigationState")
	nav.call("reset", &"boot")
	nav.call("replace_with", &"login")

	# Wait for container layout / anchor resolution (no multi-second timers).
	await _tree.process_frame
	await _tree.process_frame

	# --- GameShell ---
	var shell_size: Vector2 = shell.size
	print(
		"[INFO] layout_%s_shell_size=%.1fx%.1f global=%s"
		% [tag, shell_size.x, shell_size.y, str(shell.get_global_rect())]
	)
	_assert_true("layout_%s_shell_size_x_positive" % tag, shell_size.x > 0.0)
	_assert_true("layout_%s_shell_size_y_positive" % tag, shell_size.y > 0.0)
	_assert_true("layout_%s_shell_finite" % tag, is_finite(shell_size.x) and is_finite(shell_size.y))
	var shell_rect: Rect2 = shell.get_global_rect()
	_assert_true("layout_%s_shell_rect_finite" % tag, _is_finite_rect(shell_rect))
	_assert_true(
		"layout_%s_shell_inside_viewport" % tag,
		_rect_is_inside(shell_rect, viewport_rect, 2.0)
	)
	_assert_eq("layout_%s_screen_host_child_count" % tag, int(shell.call("get_screen_host_child_count")), 1)

	# --- Login ---
	var login: Control = shell.call("get_active_screen") as Control
	_assert_true("layout_%s_login_present" % tag, login != null)
	if login != null:
		var login_rect: Rect2 = login.get_global_rect()
		print("[INFO] layout_%s_login_rect=%s" % [tag, str(login_rect)])
		_assert_true("layout_%s_login_rect_finite" % tag, _is_finite_rect(login_rect))
		_assert_true("layout_%s_login_size_positive" % tag, login_rect.size.x > 0.0 and login_rect.size.y > 0.0)
		_assert_true(
			"layout_%s_login_inside_shell" % tag,
			_rect_is_inside(login_rect, shell_rect, 2.0)
		)

		var line: LineEdit = login.call("get_name_input") as LineEdit
		var btn: Button = login.call("get_start_button") as Button
		_assert_true("layout_%s_login_lineedit_present" % tag, line != null)
		_assert_true("layout_%s_login_button_present" % tag, btn != null)
		if line != null:
			var line_rect: Rect2 = line.get_global_rect()
			print("[INFO] layout_%s_lineedit_rect=%s" % [tag, str(line_rect)])
			_assert_true("layout_%s_lineedit_rect_finite" % tag, _is_finite_rect(line_rect))
			_assert_true("layout_%s_lineedit_size_positive" % tag, line_rect.size.x > 0.0 and line_rect.size.y > 0.0)
			_assert_true("layout_%s_lineedit_min_height" % tag, line.custom_minimum_size.y >= 48.0)
			_assert_true(
				"layout_%s_lineedit_inside_login" % tag,
				_rect_is_inside(line_rect, login_rect, 2.0)
			)
			_assert_true(
				"layout_%s_lineedit_no_h_overflow" % tag,
				line_rect.end.x <= login_rect.end.x + 2.0 and line_rect.position.x >= login_rect.position.x - 2.0
			)
		if btn != null:
			var btn_rect: Rect2 = btn.get_global_rect()
			print("[INFO] layout_%s_start_button_rect=%s" % [tag, str(btn_rect)])
			_assert_true("layout_%s_button_rect_finite" % tag, _is_finite_rect(btn_rect))
			_assert_true("layout_%s_button_size_positive" % tag, btn_rect.size.x > 0.0 and btn_rect.size.y > 0.0)
			_assert_true("layout_%s_button_min_height" % tag, btn.custom_minimum_size.y >= 48.0)
			_assert_true(
				"layout_%s_button_inside_login" % tag,
				_rect_is_inside(btn_rect, login_rect, 2.0)
			)
			_assert_true(
				"layout_%s_button_no_h_overflow" % tag,
				btn_rect.end.x <= login_rect.end.x + 2.0 and btn_rect.position.x >= login_rect.position.x - 2.0
			)

		var validation: Label = login.find_child("ValidationLabel", true, false) as Label
		if validation != null:
			var v_rect: Rect2 = validation.get_global_rect()
			print("[INFO] layout_%s_validation_rect=%s" % [tag, str(v_rect)])
			_assert_true("layout_%s_validation_rect_finite" % tag, _is_finite_rect(v_rect))
			_assert_true(
				"layout_%s_validation_no_h_overflow" % tag,
				v_rect.end.x <= login_rect.end.x + 2.0 and v_rect.position.x >= login_rect.position.x - 2.0
			)

	# --- Lobby ---
	_tree.root.get_node("AppState").call("set_player_name", "LayoutUser")
	nav.call("navigate_to", &"lobby", true)
	await _tree.process_frame
	await _tree.process_frame

	var lobby: Control = shell.call("get_active_screen") as Control
	_assert_true("layout_%s_lobby_present" % tag, lobby != null)
	_assert_eq("layout_%s_host_child_count_lobby" % tag, int(shell.call("get_screen_host_child_count")), 1)
	if lobby != null:
		var lobby_rect: Rect2 = lobby.get_global_rect()
		print("[INFO] layout_%s_lobby_rect=%s" % [tag, str(lobby_rect)])
		_assert_true("layout_%s_lobby_rect_finite" % tag, _is_finite_rect(lobby_rect))
		_assert_true("layout_%s_lobby_size_positive" % tag, lobby_rect.size.x > 0.0 and lobby_rect.size.y > 0.0)
		_assert_true(
			"layout_%s_lobby_inside_shell" % tag,
			_rect_is_inside(lobby_rect, shell_rect, 2.0)
		)
		_assert_true(
			"layout_%s_lobby_no_h_overflow" % tag,
			lobby_rect.end.x <= shell_rect.end.x + 2.0
		)

		var greeting: Label = lobby.find_child("GreetingLabel", true, false) as Label
		var grid: GridContainer = lobby.find_child("ModuleGrid", true, false) as GridContainer
		var status: Label = lobby.find_child("StatusLabel", true, false) as Label
		_assert_true("layout_%s_greeting_present" % tag, greeting != null)
		_assert_true("layout_%s_grid_present" % tag, grid != null)
		_assert_true("layout_%s_status_present" % tag, status != null)

		if greeting != null:
			var g_rect: Rect2 = greeting.get_global_rect()
			print("[INFO] layout_%s_greeting_rect=%s" % [tag, str(g_rect)])
			_assert_true("layout_%s_greeting_finite" % tag, _is_finite_rect(g_rect))
			_assert_true(
				"layout_%s_greeting_inside_lobby" % tag,
				_rect_is_inside(g_rect, lobby_rect, 2.0)
			)
		if grid != null:
			var grid_rect: Rect2 = grid.get_global_rect()
			print("[INFO] layout_%s_grid_rect=%s" % [tag, str(grid_rect)])
			_assert_true("layout_%s_grid_finite" % tag, _is_finite_rect(grid_rect))
			_assert_true(
				"layout_%s_grid_inside_lobby" % tag,
				_rect_is_inside(grid_rect, lobby_rect, 2.0)
			)
			_assert_true(
				"layout_%s_grid_no_h_overflow" % tag,
				grid_rect.end.x <= lobby_rect.end.x + 2.0
			)
			var button_count: int = 0
			for child in grid.get_children():
				if child is Button:
					button_count += 1
					var b: Button = child as Button
					var b_rect: Rect2 = b.get_global_rect()
					_assert_true(
						"layout_%s_grid_btn_%s_finite" % [tag, b.name],
						_is_finite_rect(b_rect)
					)
					_assert_true(
						"layout_%s_grid_btn_%s_size_positive" % [tag, b.name],
						b_rect.size.x > 0.0 and b_rect.size.y > 0.0
					)
					_assert_true(
						"layout_%s_grid_btn_%s_inside_grid" % [tag, b.name],
						_rect_is_inside(b_rect, grid_rect, 3.0)
					)
					_assert_true(
						"layout_%s_grid_btn_%s_inside_lobby" % [tag, b.name],
						_rect_is_inside(b_rect, lobby_rect, 3.0)
					)
			_assert_eq("layout_%s_grid_button_count" % tag, button_count, 6)
		if status != null:
			var s_rect: Rect2 = status.get_global_rect()
			print("[INFO] layout_%s_status_rect=%s" % [tag, str(s_rect)])
			_assert_true("layout_%s_status_finite" % tag, _is_finite_rect(s_rect))
			_assert_true(
				"layout_%s_status_inside_lobby" % tag,
				_rect_is_inside(s_rect, lobby_rect, 2.0)
			)

	# --- Module screen ---
	nav.call("navigate_to", &"adventure", true)
	await _tree.process_frame
	await _tree.process_frame
	var module: Control = shell.call("get_active_screen") as Control
	_assert_true("layout_%s_module_present" % tag, module != null)
	if module != null:
		var module_rect: Rect2 = module.get_global_rect()
		print("[INFO] layout_%s_module_rect=%s" % [tag, str(module_rect)])
		_assert_true("layout_%s_module_finite" % tag, _is_finite_rect(module_rect))
		_assert_true("layout_%s_module_size_positive" % tag, module_rect.size.x > 0.0 and module_rect.size.y > 0.0)
		_assert_true(
			"layout_%s_module_inside_shell" % tag,
			_rect_is_inside(module_rect, shell_rect, 2.0)
		)

		var header: HBoxContainer = module.find_child("HeaderRow", true, false) as HBoxContainer
		_assert_true("layout_%s_header_present" % tag, header != null)
		var header_rect := Rect2()
		if header != null:
			header_rect = header.get_global_rect()
			print("[INFO] layout_%s_header_rect=%s" % [tag, str(header_rect)])
			_assert_true("layout_%s_header_finite" % tag, _is_finite_rect(header_rect))
			_assert_true("layout_%s_header_size_positive" % tag, header_rect.size.x > 0.0 and header_rect.size.y > 0.0)
			_assert_true("layout_%s_header_inside_module" % tag, _rect_is_inside(header_rect, module_rect, 2.0))
			_assert_true(
				"layout_%s_header_no_h_overflow" % tag,
				header_rect.end.x <= module_rect.end.x + 2.0 and header_rect.position.x >= module_rect.position.x - 2.0
			)

		var back_btn: Button = module.call("get_back_button") as Button
		if back_btn != null:
			var back_rect: Rect2 = back_btn.get_global_rect()
			_assert_true("layout_%s_module_back_finite" % tag, _is_finite_rect(back_rect))
			_assert_true("layout_%s_module_back_size_positive" % tag, back_rect.size.x > 0.0 and back_rect.size.y > 0.0)
			_assert_true("layout_%s_module_back_min_height" % tag, back_btn.custom_minimum_size.y >= 48.0)
			_assert_true("layout_%s_module_back_inside" % tag, _rect_is_inside(back_rect, module_rect, 2.0))
			if header != null:
				_assert_true("layout_%s_module_back_inside_header" % tag, _rect_is_inside(back_rect, header_rect, 2.0))

		var title: Label = module.find_child("TitleLabel", true, false) as Label
		if title != null:
			var t_rect: Rect2 = title.get_global_rect()
			_assert_true("layout_%s_module_title_finite" % tag, _is_finite_rect(t_rect))
			_assert_true("layout_%s_module_title_inside" % tag, _rect_is_inside(t_rect, module_rect, 2.0))
			if header != null:
				_assert_true("layout_%s_module_title_inside_header" % tag, _rect_is_inside(t_rect, header_rect, 2.0))
			_assert_true(
				"layout_%s_module_title_no_h_overflow" % tag,
				t_rect.end.x <= module_rect.end.x + 2.0
			)

		var body: Label = module.find_child("BodyLabel", true, false) as Label
		var body_panel: Control = module.find_child("BodyPanel", true, false) as Control
		_assert_true("layout_%s_body_present" % tag, body != null)
		if body != null:
			var b_rect: Rect2 = body.get_global_rect()
			print("[INFO] layout_%s_body_rect=%s text=%s" % [tag, str(b_rect), body.text])
			_assert_true("layout_%s_body_finite" % tag, _is_finite_rect(b_rect))
			_assert_true("layout_%s_body_size_positive" % tag, b_rect.size.x > 0.0 and b_rect.size.y > 0.0)
			_assert_true("layout_%s_body_inside_module" % tag, _rect_is_inside(b_rect, module_rect, 2.0))
			if body_panel != null:
				var panel_rect: Rect2 = body_panel.get_global_rect()
				_assert_true("layout_%s_body_inside_panel" % tag, _rect_is_inside(b_rect, panel_rect, 2.0))
			_assert_true(
				"layout_%s_body_no_h_overflow" % tag,
				b_rect.end.x <= module_rect.end.x + 2.0 and b_rect.position.x >= module_rect.position.x - 2.0
			)
			_assert_eq("layout_%s_body_autowrap" % tag, int(body.autowrap_mode), 3)
			_assert_eq("layout_%s_module_status" % tag, body.text, "此功能將於後續版本開放")

		_assert_eq("layout_%s_host_child_module" % tag, int(shell.call("get_screen_host_child_count")), 1)
		# Return lobby and verify lobby layout still ok
		module.call("request_back")
		await _tree.process_frame
		await _tree.process_frame
		var lobby_after: Control = shell.call("get_active_screen") as Control
		_assert_true("layout_%s_back_to_lobby" % tag, lobby_after != null and str(shell.call("get_active_screen_id")) == "lobby")
		if lobby_after != null:
			var lr: Rect2 = lobby_after.get_global_rect()
			_assert_true("layout_%s_lobby_after_finite" % tag, _is_finite_rect(lr))
			_assert_true("layout_%s_lobby_after_inside" % tag, _rect_is_inside(lr, shell_rect, 2.0))

	host.queue_free()
	await _tree.process_frame


func _probe_safe_area_pure() -> void:
	# Full window → zeros
	var full: Dictionary = SafeAreaContainer.compute_margins_from_rects(
		Vector2i(1080, 1920),
		Rect2i(0, 0, 1080, 1920),
		Vector2(720, 1280)
	)
	_assert_eq("safe_area_full_window_left", int(full["left"]), 0)
	_assert_eq("safe_area_full_window_top", int(full["top"]), 0)
	_assert_eq("safe_area_full_window_right", int(full["right"]), 0)
	_assert_eq("safe_area_full_window_bottom", int(full["bottom"]), 0)
	print("[INFO] safe_area_full_window=%s" % str(full))

	# Top inset 96px on 1080x1920 → scale to 720x1280: top = round(96 * 1280/1920) = 64
	var top_case: Dictionary = SafeAreaContainer.compute_margins_from_rects(
		Vector2i(1080, 1920),
		Rect2i(0, 96, 1080, 1824),
		Vector2(720, 1280)
	)
	_assert_eq("safe_area_top_inset", int(top_case["top"]), 64)
	_assert_eq("safe_area_top_left_zero", int(top_case["left"]), 0)
	print("[INFO] safe_area_top_inset=%s" % str(top_case))

	# Left 54 / right 54 on 1080 → scale x = 720/1080 = 2/3 → 36
	var side_case: Dictionary = SafeAreaContainer.compute_margins_from_rects(
		Vector2i(1080, 1920),
		Rect2i(54, 0, 972, 1920),
		Vector2(720, 1280)
	)
	_assert_eq("safe_area_left_inset", int(side_case["left"]), 36)
	_assert_eq("safe_area_right_inset", int(side_case["right"]), 36)
	print("[INFO] safe_area_side_inset=%s" % str(side_case))

	# Invalid window size
	var inv_win: Dictionary = SafeAreaContainer.compute_margins_from_rects(
		Vector2i(0, 100),
		Rect2i(0, 0, 50, 50),
		Vector2(720, 1280)
	)
	_assert_eq("safe_area_invalid_window_left", int(inv_win["left"]), 0)
	_assert_eq("safe_area_invalid_window_top", int(inv_win["top"]), 0)
	_assert_eq("safe_area_invalid_window_right", int(inv_win["right"]), 0)
	_assert_eq("safe_area_invalid_window_bottom", int(inv_win["bottom"]), 0)
	print("[INFO] safe_area_invalid_window=%s" % str(inv_win))

	# Invalid safe rect
	var inv_safe: Dictionary = SafeAreaContainer.compute_margins_from_rects(
		Vector2i(1080, 1920),
		Rect2i(0, 0, 0, 0),
		Vector2(720, 1280)
	)
	_assert_eq("safe_area_invalid_safe_left", int(inv_safe["left"]), 0)
	_assert_eq("safe_area_invalid_safe_top", int(inv_safe["top"]), 0)
	_assert_eq("safe_area_invalid_safe_right", int(inv_safe["right"]), 0)
	_assert_eq("safe_area_invalid_safe_bottom", int(inv_safe["bottom"]), 0)
	print("[INFO] safe_area_invalid_safe=%s" % str(inv_safe))

	# Non-negative on mixed inset
	var mixed: Dictionary = SafeAreaContainer.compute_margins_from_rects(
		Vector2i(1080, 1920),
		Rect2i(20, 40, 1000, 1800),
		Vector2(720, 1280)
	)
	_assert_true("safe_area_mixed_non_negative", (
		int(mixed["left"]) >= 0
		and int(mixed["top"]) >= 0
		and int(mixed["right"]) >= 0
		and int(mixed["bottom"]) >= 0
	))
	_assert_true("safe_area_mixed_keys", (
		mixed.has("left") and mixed.has("top") and mixed.has("right") and mixed.has("bottom")
	))
	_assert_true("safe_area_mixed_finite", (
		is_finite(float(mixed["left"]))
		and is_finite(float(mixed["top"]))
		and is_finite(float(mixed["right"]))
		and is_finite(float(mixed["bottom"]))
	))
	print("[INFO] safe_area_mixed=%s" % str(mixed))


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
