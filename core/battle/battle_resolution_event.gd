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


## Deterministic deep equality — no Dictionary string conversion.
static func events_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not event_equal(a[i], b[i]):
			return false
	return true


static func event_equal(a: Variant, b: Variant) -> bool:
	if not (a is Dictionary) or not (b is Dictionary):
		return false
	var da: Dictionary = a as Dictionary
	var db: Dictionary = b as Dictionary
	var ta: StringName = da.get("type", &"") as StringName
	var tb: StringName = db.get("type", &"") as StringName
	if ta != tb:
		return false
	match ta:
		TYPE_SWAP, TYPE_SWAP_REJECTED:
			if not _xy_dict_eq(da.get("from", {}), db.get("from", {})):
				return false
			if not _xy_dict_eq(da.get("to", {}), db.get("to", {})):
				return false
			if ta == TYPE_SWAP_REJECTED and str(da.get("reason", "")) != str(db.get("reason", "")):
				return false
			return true
		TYPE_MATCH_FOUND:
			if int(da.get("cascade_index", -1)) != int(db.get("cascade_index", -2)):
				return false
			return _xy_list_eq(da.get("matched_cells", []), db.get("matched_cells", []))
		TYPE_CELLS_CLEARED:
			if int(da.get("cascade_index", -1)) != int(db.get("cascade_index", -2)):
				return false
			if not _xy_list_eq(da.get("cells", []), db.get("cells", [])):
				return false
			return _scalar_list_eq(da.get("orb_kinds", []), db.get("orb_kinds", []))
		TYPE_GRAVITY_APPLIED:
			return _movements_eq(da.get("movements", []), db.get("movements", []))
		TYPE_CELLS_REFILLED:
			if not _xy_list_eq(da.get("positions", []), db.get("positions", [])):
				return false
			return _scalar_list_eq(da.get("kinds", []), db.get("kinds", []))
		TYPE_CASCADE_COMPLETED:
			return (
				int(da.get("cascade_index", -1)) == int(db.get("cascade_index", -2))
				and int(da.get("cleared_cell_count", -1)) == int(db.get("cleared_cell_count", -2))
			)
		TYPE_TURN_COMPLETED:
			return (
				int(da.get("turn_count", -1)) == int(db.get("turn_count", -2))
				and int(da.get("cascade_count", -1)) == int(db.get("cascade_count", -2))
				and int(da.get("cleared_cell_count", -1)) == int(db.get("cleared_cell_count", -2))
			)
		_:
			# Unknown type: compare fixed key set without stringification of whole dict.
			var keys_a: Array = da.keys()
			var keys_b: Array = db.keys()
			keys_a.sort()
			keys_b.sort()
			if keys_a.size() != keys_b.size():
				return false
			for i in keys_a.size():
				if str(keys_a[i]) != str(keys_b[i]):
					return false
				if str(da[keys_a[i]]) != str(db[keys_b[i]]):
					return false
			return true


static func _xy_dict_eq(a: Variant, b: Variant) -> bool:
	if not (a is Dictionary) or not (b is Dictionary):
		return false
	var da: Dictionary = a as Dictionary
	var db: Dictionary = b as Dictionary
	return int(da.get("x", -99)) == int(db.get("x", -98)) and int(da.get("y", -99)) == int(db.get("y", -98))


static func _xy_list_eq(a: Variant, b: Variant) -> bool:
	if not (a is Array) or not (b is Array):
		return false
	var aa: Array = a as Array
	var bb: Array = b as Array
	if aa.size() != bb.size():
		return false
	for i in aa.size():
		if not _xy_dict_eq(aa[i], bb[i]):
			return false
	return true


static func _scalar_list_eq(a: Variant, b: Variant) -> bool:
	if not (a is Array) or not (b is Array):
		return false
	var aa: Array = a as Array
	var bb: Array = b as Array
	if aa.size() != bb.size():
		return false
	for i in aa.size():
		if str(aa[i]) != str(bb[i]):
			return false
	return true


static func _movements_eq(a: Variant, b: Variant) -> bool:
	if not (a is Array) or not (b is Array):
		return false
	var aa: Array = a as Array
	var bb: Array = b as Array
	if aa.size() != bb.size():
		return false
	for i in aa.size():
		if not (aa[i] is Dictionary) or not (bb[i] is Dictionary):
			return false
		var da: Dictionary = aa[i] as Dictionary
		var db: Dictionary = bb[i] as Dictionary
		if not _xy_dict_eq(da.get("from", {}), db.get("from", {})):
			return false
		if not _xy_dict_eq(da.get("to", {}), db.get("to", {})):
			return false
	return true


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
