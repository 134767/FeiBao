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

const KNOWN_TYPES: Array[StringName] = [
	TYPE_SWAP,
	TYPE_SWAP_REJECTED,
	TYPE_MATCH_FOUND,
	TYPE_CELLS_CLEARED,
	TYPE_GRAVITY_APPLIED,
	TYPE_CELLS_REFILLED,
	TYPE_CASCADE_COMPLETED,
	TYPE_TURN_COMPLETED,
]


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


## Strict schema validation for snapshot restore. Fail closed on any illegal event.
static func validate_events(events: Variant) -> Dictionary:
	if events == null:
		return {"ok": true, "error": ""}
	if not (events is Array):
		return {"ok": false, "error": "events must be Array"}
	var arr: Array = events as Array
	for i in arr.size():
		var one: Dictionary = validate_event(arr[i])
		if not bool(one.get("ok", false)):
			return {
				"ok": false,
				"error": "event[%d]: %s" % [i, str(one.get("error", "invalid"))],
			}
	return {"ok": true, "error": ""}


static func validate_event(event: Variant) -> Dictionary:
	if not (event is Dictionary):
		return {"ok": false, "error": "event is not Dictionary"}
	var d: Dictionary = event as Dictionary
	if not d.has("type"):
		return {"ok": false, "error": "missing type"}
	var t: StringName = d.get("type", &"") as StringName
	if not KNOWN_TYPES.has(t):
		return {"ok": false, "error": "unknown event type"}
	match t:
		TYPE_SWAP:
			return _require_xy_pair(d, false)
		TYPE_SWAP_REJECTED:
			var base: Dictionary = _require_xy_pair(d, false)
			if not bool(base.get("ok", false)):
				return base
			if not d.has("reason") or typeof(d.get("reason")) != TYPE_STRING:
				return {"ok": false, "error": "swap_rejected requires string reason"}
			return {"ok": true, "error": ""}
		TYPE_MATCH_FOUND:
			if not d.has("cascade_index") or int(d.get("cascade_index", -1)) < 1:
				return {"ok": false, "error": "match_found requires cascade_index >= 1"}
			return _require_xy_list(d.get("matched_cells", null), "matched_cells")
		TYPE_CELLS_CLEARED:
			if not d.has("cascade_index") or int(d.get("cascade_index", -1)) < 1:
				return {"ok": false, "error": "cells_cleared requires cascade_index >= 1"}
			var cells_ok: Dictionary = _require_xy_list(d.get("cells", null), "cells")
			if not bool(cells_ok.get("ok", false)):
				return cells_ok
			return _require_kind_list(d.get("orb_kinds", null), "orb_kinds", true)
		TYPE_GRAVITY_APPLIED:
			return _require_movements(d.get("movements", null))
		TYPE_CELLS_REFILLED:
			var pos_ok: Dictionary = _require_xy_list(d.get("positions", null), "positions")
			if not bool(pos_ok.get("ok", false)):
				return pos_ok
			return _require_kind_list(d.get("kinds", null), "kinds", true)
		TYPE_CASCADE_COMPLETED:
			if int(d.get("cascade_index", -1)) < 1:
				return {"ok": false, "error": "cascade_completed requires cascade_index >= 1"}
			if int(d.get("cleared_cell_count", -1)) < 0:
				return {"ok": false, "error": "cascade_completed requires non-negative cleared_cell_count"}
			return {"ok": true, "error": ""}
		TYPE_TURN_COMPLETED:
			if int(d.get("turn_count", -1)) < 0:
				return {"ok": false, "error": "turn_completed requires non-negative turn_count"}
			if int(d.get("cascade_count", -1)) < 0:
				return {"ok": false, "error": "turn_completed requires non-negative cascade_count"}
			if int(d.get("cleared_cell_count", -1)) < 0:
				return {"ok": false, "error": "turn_completed requires non-negative cleared_cell_count"}
			return {"ok": true, "error": ""}
		_:
			return {"ok": false, "error": "unknown event type"}


## Deterministic deep equality — no Dictionary string conversion; unknown types never equal.
static func events_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not event_equal(a[i], b[i]):
			return false
	return true


static func event_equal(a: Variant, b: Variant) -> bool:
	# Both must pass schema and match field-by-field.
	var va: Dictionary = validate_event(a)
	var vb: Dictionary = validate_event(b)
	if not bool(va.get("ok", false)) or not bool(vb.get("ok", false)):
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
			# No unknown-type string fallback — unknown never equal.
			return false


static func _require_xy_pair(d: Dictionary, _unused: bool) -> Dictionary:
	if not d.has("from") or not d.has("to"):
		return {"ok": false, "error": "missing from/to"}
	if not _is_xy_dict(d.get("from")):
		return {"ok": false, "error": "invalid from coordinate"}
	if not _is_xy_dict(d.get("to")):
		return {"ok": false, "error": "invalid to coordinate"}
	return {"ok": true, "error": ""}


static func _require_xy_list(raw: Variant, field: String) -> Dictionary:
	if not (raw is Array):
		return {"ok": false, "error": "%s must be Array" % field}
	var arr: Array = raw as Array
	for item in arr:
		if not _is_xy_dict(item):
			return {"ok": false, "error": "%s contains invalid coordinate" % field}
	return {"ok": true, "error": ""}


static func _require_kind_list(raw: Variant, field: String, allow_empty_list: bool) -> Dictionary:
	if not (raw is Array):
		return {"ok": false, "error": "%s must be Array" % field}
	var arr: Array = raw as Array
	if not allow_empty_list and arr.is_empty():
		return {"ok": false, "error": "%s must not be empty" % field}
	for item in arr:
		var k: StringName = item as StringName
		if not BattleOrbKind.is_valid(k):
			return {"ok": false, "error": "%s contains invalid orb kind" % field}
	return {"ok": true, "error": ""}


static func _require_movements(raw: Variant) -> Dictionary:
	if not (raw is Array):
		return {"ok": false, "error": "movements must be Array"}
	var arr: Array = raw as Array
	for item in arr:
		if not (item is Dictionary):
			return {"ok": false, "error": "movement entry not Dictionary"}
		var d: Dictionary = item as Dictionary
		if not _is_xy_dict(d.get("from")) or not _is_xy_dict(d.get("to")):
			return {"ok": false, "error": "movement from/to invalid"}
	return {"ok": true, "error": ""}


static func _is_xy_dict(v: Variant) -> bool:
	if not (v is Dictionary):
		return false
	var d: Dictionary = v as Dictionary
	if not d.has("x") or not d.has("y"):
		return false
	# Must be integral coordinates (reject fractional strings silently coerced).
	var x: Variant = d.get("x")
	var y: Variant = d.get("y")
	if typeof(x) != TYPE_INT and typeof(x) != TYPE_FLOAT:
		return false
	if typeof(y) != TYPE_INT and typeof(y) != TYPE_FLOAT:
		return false
	if typeof(x) == TYPE_FLOAT and float(x) != floor(float(x)):
		return false
	if typeof(y) == TYPE_FLOAT and float(y) != floor(float(y)):
		return false
	return true


static func _xy_dict_eq(a: Variant, b: Variant) -> bool:
	if not _is_xy_dict(a) or not _is_xy_dict(b):
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
