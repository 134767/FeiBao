## Pure data resolution events for battle board moves (no Node / timestamps).
class_name BattleResolutionEvent
extends RefCounted

const TYPE_SWAP: StringName = &"swap"
const TYPE_MATCH_FOUND: StringName = &"match_found"
const TYPE_CELLS_CLEARED: StringName = &"cells_cleared"
const TYPE_GRAVITY_APPLIED: StringName = &"gravity_applied"
const TYPE_CELLS_REFILLED: StringName = &"cells_refilled"
const TYPE_CASCADE_COMPLETED: StringName = &"cascade_completed"
const TYPE_TURN_COMPLETED: StringName = &"turn_completed"
const TYPE_SWAP_REJECTED: StringName = &"swap_rejected"


static func make_swap(from_xy: Vector2i, to_xy: Vector2i) -> Dictionary:
	return {
		"type": TYPE_SWAP,
		"from": {"x": from_xy.x, "y": from_xy.y},
		"to": {"x": to_xy.x, "y": to_xy.y},
	}


static func make_swap_rejected(from_xy: Vector2i, to_xy: Vector2i, reason: String) -> Dictionary:
	return {
		"type": TYPE_SWAP_REJECTED,
		"from": {"x": from_xy.x, "y": from_xy.y},
		"to": {"x": to_xy.x, "y": to_xy.y},
		"reason": reason,
	}


static func make_match_found(cascade_index: int, matched_cells: Array) -> Dictionary:
	return {
		"type": TYPE_MATCH_FOUND,
		"cascade_index": cascade_index,
		"matched_cells": _copy_xy_list(matched_cells),
	}


static func make_cells_cleared(cascade_index: int, cells: Array, kinds: Array) -> Dictionary:
	return {
		"type": TYPE_CELLS_CLEARED,
		"cascade_index": cascade_index,
		"cells": _copy_xy_list(cells),
		"orb_kinds": kinds.duplicate(),
	}


static func make_gravity_applied(movements: Array) -> Dictionary:
	var moves: Array = []
	for m in movements:
		if m is Dictionary:
			var d: Dictionary = m as Dictionary
			moves.append({
				"from": {"x": int(d.get("from_x", 0)), "y": int(d.get("from_y", 0))},
				"to": {"x": int(d.get("to_x", 0)), "y": int(d.get("to_y", 0))},
			})
	return {
		"type": TYPE_GRAVITY_APPLIED,
		"movements": moves,
	}


static func make_cells_refilled(positions: Array, kinds: Array) -> Dictionary:
	return {
		"type": TYPE_CELLS_REFILLED,
		"positions": _copy_xy_list(positions),
		"kinds": kinds.duplicate(),
	}


static func make_cascade_completed(cascade_index: int, cleared_count: int) -> Dictionary:
	return {
		"type": TYPE_CASCADE_COMPLETED,
		"cascade_index": cascade_index,
		"cleared_cell_count": cleared_count,
	}


static func make_turn_completed(turn_count: int, cascade_count: int, cleared_cell_count: int) -> Dictionary:
	return {
		"type": TYPE_TURN_COMPLETED,
		"turn_count": turn_count,
		"cascade_count": cascade_count,
		"cleared_cell_count": cleared_cell_count,
	}


static func duplicate_events(events: Array) -> Array:
	var out: Array = []
	for e in events:
		if e is Dictionary:
			out.append((e as Dictionary).duplicate(true))
	return out


static func _copy_xy_list(items: Array) -> Array:
	var out: Array = []
	for item in items:
		if item is Dictionary:
			var d: Dictionary = item as Dictionary
			out.append({"x": int(d.get("x", 0)), "y": int(d.get("y", 0))})
		elif item is Vector2i:
			var v: Vector2i = item as Vector2i
			out.append({"x": v.x, "y": v.y})
	return out
