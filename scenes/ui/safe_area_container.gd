## Margin container that applies DisplayServer safe-area insets.
## Desktop / environments without safe-area data fall back to zero margins.
class_name SafeAreaContainer
extends MarginContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_safe_area()
	# Re-apply when window size changes (desktop resize / rotation).
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	_apply_safe_area()


func _apply_safe_area() -> void:
	var margins: Dictionary = compute_safe_area_margins()
	add_theme_constant_override("margin_left", int(margins["left"]))
	add_theme_constant_override("margin_top", int(margins["top"]))
	add_theme_constant_override("margin_right", int(margins["right"]))
	add_theme_constant_override("margin_bottom", int(margins["bottom"]))


## Compute safe-area margins in viewport coordinates.
## Returns zero margins when safe-area data is unavailable (typical desktop).
func compute_safe_area_margins() -> Dictionary:
	var zero: Dictionary = {"left": 0, "top": 0, "right": 0, "bottom": 0}

	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return zero

	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return zero

	# Full-window safe area (desktop) → zero insets.
	if safe.position == Vector2i.ZERO and safe.size == window_size:
		return zero

	var left_px: int = maxi(safe.position.x, 0)
	var top_px: int = maxi(safe.position.y, 0)
	var right_px: int = maxi(window_size.x - safe.position.x - safe.size.x, 0)
	var bottom_px: int = maxi(window_size.y - safe.position.y - safe.size.y, 0)

	# If all insets are zero, nothing to apply.
	if left_px == 0 and top_px == 0 and right_px == 0 and bottom_px == 0:
		return zero

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return zero

	var scale_x: float = viewport_size.x / float(window_size.x)
	var scale_y: float = viewport_size.y / float(window_size.y)

	return {
		"left": int(round(float(left_px) * scale_x)),
		"top": int(round(float(top_px) * scale_y)),
		"right": int(round(float(right_px) * scale_x)),
		"bottom": int(round(float(bottom_px) * scale_y)),
	}
