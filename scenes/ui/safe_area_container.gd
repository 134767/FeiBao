## Margin container that applies DisplayServer safe-area insets.
## Desktop / environments without safe-area data fall back to zero margins.
class_name SafeAreaContainer
extends MarginContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_safe_area()
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


## Runtime entry: reads DisplayServer, then delegates to pure calculator.
func compute_safe_area_margins() -> Dictionary:
	var window_size: Vector2i = DisplayServer.window_get_size()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var viewport_size: Vector2 = Vector2.ZERO
	if is_inside_tree() and get_viewport() != null:
		viewport_size = get_viewport().get_visible_rect().size
	return compute_margins_from_rects(window_size, safe, viewport_size)


## Pure margin calculation — unit-testable without DisplayServer.
static func compute_margins_from_rects(
	window_size: Vector2i,
	safe_rect: Rect2i,
	viewport_size: Vector2
) -> Dictionary:
	var zero: Dictionary = {"left": 0, "top": 0, "right": 0, "bottom": 0}

	if window_size.x <= 0 or window_size.y <= 0:
		return zero.duplicate()

	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return zero.duplicate()

	# Full-window safe area (desktop) → zero insets.
	if safe_rect.position == Vector2i.ZERO and safe_rect.size == window_size:
		return zero.duplicate()

	var left_px: int = maxi(safe_rect.position.x, 0)
	var top_px: int = maxi(safe_rect.position.y, 0)
	var right_px: int = maxi(window_size.x - safe_rect.position.x - safe_rect.size.x, 0)
	var bottom_px: int = maxi(window_size.y - safe_rect.position.y - safe_rect.size.y, 0)

	if left_px == 0 and top_px == 0 and right_px == 0 and bottom_px == 0:
		return zero.duplicate()

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return zero.duplicate()

	var scale_x: float = viewport_size.x / float(window_size.x)
	var scale_y: float = viewport_size.y / float(window_size.y)

	return {
		"left": int(round(float(left_px) * scale_x)),
		"top": int(round(float(top_px) * scale_y)),
		"right": int(round(float(right_px) * scale_x)),
		"bottom": int(round(float(bottom_px) * scale_y)),
	}
