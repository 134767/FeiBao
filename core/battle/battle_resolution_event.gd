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

const KEYS_SWAP: Array[String] = ["type", "from", "to"]
const KEYS_SWAP_REJECTED: Array[String] = ["type", "from", "to", "reason"]
const KEYS_MATCH_FOUND: Array[String] = ["type", "cascade_index", "matched_cells"]
const KEYS_CELLS_CLEARED: Array[String] = ["type", "cascade_index", "cells", "orb_kinds"]
const KEYS_GRAVITY: Array[String] = ["type", "movements"]
const KEYS_REFILL: Array[String] = ["type", "positions", "kinds"]
const KEYS_CASCADE: Array[String] = ["type", "cascade_index", "cleared_cell_count"]
const KEYS_TURN: Array[String] = ["type", "turn_count", "cascade_count", "cleared_cell_count"]


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


## Strict schema + sequence validation. Returns {ok, error, events} with defensive copy on success.
static func validate_events(events: Variant) -> Dictionary:
	if events == null:
		return {"ok": true, "error": "", "events": []}
	if not (events is Array):
		return {"ok": false, "error": "events must be Array", "events": []}
	var arr: Array = events as Array
	var normalized: Array = []
	for i in arr.size():
		var item: Variant = arr[i]
		if not (item is Dictionary):
			return {"ok": false, "error": "event[%d]: not Dictionary" % i, "events": []}
		var one: Dictionary = validate_event(item)
		if not bool(one.get("ok", false)):
			return {
				"ok": false,
				"error": "event[%d]: %s" % [i, str(one.get("error", "invalid"))],
				"events": [],
			}
		normalized.append((item as Dictionary).duplicate(true))
	var seq: Dictionary = validate_sequence(normalized)
	if not bool(seq.get("ok", false)):
		return {"ok": false, "error": str(seq.get("error", "invalid sequence")), "events": []}
	return {"ok": true, "error": "", "events": normalized}


## Validate events against Runtime last_match_count / last_cascade_count.
static func validate_events_with_counts(events: Variant, last_match: int, last_cascade: int) -> Dictionary:
	var base: Dictionary = validate_events(events)
	if not bool(base.get("ok", false)):
		return base
	var arr: Array = base.get("events", []) as Array
	if arr.is_empty():
		if last_match != 0 or last_cascade != 0:
			return {"ok": false, "error": "empty events require zero counts", "events": []}
		return base
	var first_type: StringName = (arr[0] as Dictionary).get("type", &"") as StringName
	if first_type == TYPE_SWAP_REJECTED:
		if arr.size() != 1:
			return {"ok": false, "error": "swap_rejected must be sole event", "events": []}
		if last_match != 0 or last_cascade != 0:
			return {"ok": false, "error": "swap_rejected requires zero counts", "events": []}
		return base
	# Completed turn sequence
	var last: Dictionary = arr[arr.size() - 1] as Dictionary
	if (last.get("type", &"") as StringName) != TYPE_TURN_COMPLETED:
		return {"ok": false, "error": "non-empty move sequence must end with turn_completed", "events": []}
	if int(last.get("cleared_cell_count", -1)) != last_match:
		return {"ok": false, "error": "last_match_count mismatches turn_completed", "events": []}
	if int(last.get("cascade_count", -1)) != last_cascade:
		return {"ok": false, "error": "last_cascade_count mismatches turn_completed", "events": []}
	return base


static func validate_sequence(events: Array) -> Dictionary:
	if events.is_empty():
		return {"ok": true, "error": ""}
	var first: Dictionary = events[0] as Dictionary
	var ft: StringName = first.get("type", &"") as StringName
	if ft == TYPE_SWAP_REJECTED:
		if events.size() != 1:
			return {"ok": false, "error": "swap_rejected sequence must be length 1"}
		return {"ok": true, "error": ""}
	if ft != TYPE_SWAP:
		return {"ok": false, "error": "valid move sequence must start with swap"}
	var last: Dictionary = events[events.size() - 1] as Dictionary
	if (last.get("type", &"") as StringName) != TYPE_TURN_COMPLETED:
		return {"ok": false, "error": "valid move sequence must end with turn_completed"}
	# Walk cascades after swap.
	var i: int = 1
	var expected_cascade: int = 1
	var total_cleared: int = 0
	var cascade_count: int = 0
	while i < events.size() - 1:
		var e: Dictionary = events[i] as Dictionary
		var t: StringName = e.get("type", &"") as StringName
		if t != TYPE_MATCH_FOUND:
			return {"ok": false, "error": "cascade expected match_found at index %d" % i}
		if int(e.get("cascade_index", -1)) != expected_cascade:
			return {"ok": false, "error": "cascade_index not contiguous"}
		var matched: Array = e.get("matched_cells", []) as Array
		i += 1
		if i >= events.size() - 1:
			return {"ok": false, "error": "incomplete cascade after match_found"}
		e = events[i] as Dictionary
		if (e.get("type", &"") as StringName) != TYPE_CELLS_CLEARED:
			return {"ok": false, "error": "cascade expected cells_cleared"}
		if int(e.get("cascade_index", -1)) != expected_cascade:
			return {"ok": false, "error": "cells_cleared cascade_index mismatch"}
		var cells: Array = e.get("cells", []) as Array
		if not _xy_list_eq(matched, cells):
			return {"ok": false, "error": "match_found cells != cells_cleared cells"}
		total_cleared += cells.size()
		i += 1
		if i >= events.size() - 1:
			return {"ok": false, "error": "incomplete cascade after cells_cleared"}
		e = events[i] as Dictionary
		if (e.get("type", &"") as StringName) != TYPE_GRAVITY_APPLIED:
			return {"ok": false, "error": "cascade expected gravity_applied"}
		i += 1
		if i >= events.size() - 1:
			return {"ok": false, "error": "incomplete cascade after gravity"}
		e = events[i] as Dictionary
		if (e.get("type", &"") as StringName) != TYPE_CELLS_REFILLED:
			return {"ok": false, "error": "cascade expected cells_refilled"}
		i += 1
		if i >= events.size() - 1:
			return {"ok": false, "error": "incomplete cascade after refill"}
		e = events[i] as Dictionary
		if (e.get("type", &"") as StringName) != TYPE_CASCADE_COMPLETED:
			return {"ok": false, "error": "cascade expected cascade_completed"}
		if int(e.get("cascade_index", -1)) != expected_cascade:
			return {"ok": false, "error": "cascade_completed index mismatch"}
		if int(e.get("cleared_cell_count", -1)) != matched.size():
			return {"ok": false, "error": "cascade_completed cleared count mismatch"}
		cascade_count += 1
		expected_cascade += 1
		i += 1
	if cascade_count < 1:
		return {"ok": false, "error": "valid move requires at least one cascade"}
	if int(last.get("cascade_count", -1)) != cascade_count:
		return {"ok": false, "error": "turn_completed.cascade_count mismatch"}
	if int(last.get("cleared_cell_count", -1)) != total_cleared:
		return {"ok": false, "error": "turn_completed.cleared_cell_count mismatch"}
	return {"ok": true, "error": ""}


static func validate_event(event: Variant) -> Dictionary:
	if not (event is Dictionary):
		return {"ok": false, "error": "event is not Dictionary"}
	var d: Dictionary = event as Dictionary
	if not d.has("type"):
		return {"ok": false, "error": "missing type"}
	# Reject forbidden payload types in values (shallow).
	for k in d.keys():
		var v: Variant = d[k]
		if v is Object or v is Callable or v is Object:
			return {"ok": false, "error": "forbidden reference payload"}
	var t: StringName = d.get("type", &"") as StringName
	if not KNOWN_TYPES.has(t):
		return {"ok": false, "error": "unknown event type"}
	match t:
		TYPE_SWAP:
			var keys_err: String = _exact_keys(d, KEYS_SWAP)
			if not keys_err.is_empty():
				return {"ok": false, "error": keys_err}
			return _validate_adjacent_pair(d.get("from"), d.get("to"), true)
		TYPE_SWAP_REJECTED:
			var keys_err2: String = _exact_keys(d, KEYS_SWAP_REJECTED)
			if not keys_err2.is_empty():
				return {"ok": false, "error": keys_err2}
			var pair: Dictionary = _validate_xy_pair_in_bounds(d.get("from"), d.get("to"))
			if not bool(pair.get("ok", false)):
				return pair
			if typeof(d.get("reason")) != TYPE_STRING or str(d.get("reason")).is_empty():
				return {"ok": false, "error": "reason must be non-empty string"}
			return {"ok": true, "error": ""}
		TYPE_MATCH_FOUND:
			var keys_err3: String = _exact_keys(d, KEYS_MATCH_FOUND)
			if not keys_err3.is_empty():
				return {"ok": false, "error": keys_err3}
			if int(d.get("cascade_index", -1)) < 1:
				return {"ok": false, "error": "cascade_index >= 1 required"}
			return _require_xy_list(d.get("matched_cells"), "matched_cells", 3, true)
		TYPE_CELLS_CLEARED:
			var keys_err4: String = _exact_keys(d, KEYS_CELLS_CLEARED)
			if not keys_err4.is_empty():
				return {"ok": false, "error": keys_err4}
			if int(d.get("cascade_index", -1)) < 1:
				return {"ok": false, "error": "cascade_index >= 1 required"}
			var cells_ok: Dictionary = _require_xy_list(d.get("cells"), "cells", 3, true)
			if not bool(cells_ok.get("ok", false)):
				return cells_ok
			var kinds_ok: Dictionary = _require_kind_list(d.get("orb_kinds"), "orb_kinds", false)
			if not bool(kinds_ok.get("ok", false)):
				return kinds_ok
			if (d.get("cells") as Array).size() != (d.get("orb_kinds") as Array).size():
				return {"ok": false, "error": "cells/orb_kinds length mismatch"}
			return {"ok": true, "error": ""}
		TYPE_GRAVITY_APPLIED:
			var keys_err5: String = _exact_keys(d, KEYS_GRAVITY)
			if not keys_err5.is_empty():
				return {"ok": false, "error": keys_err5}
			return _require_movements(d.get("movements"))
		TYPE_CELLS_REFILLED:
			var keys_err6: String = _exact_keys(d, KEYS_REFILL)
			if not keys_err6.is_empty():
				return {"ok": false, "error": keys_err6}
			var pos_ok: Dictionary = _require_xy_list(d.get("positions"), "positions", 0, true)
			if not bool(pos_ok.get("ok", false)):
				return pos_ok
			var k_ok: Dictionary = _require_kind_list(d.get("kinds"), "kinds", true)
			if not bool(k_ok.get("ok", false)):
				return k_ok
			if (d.get("positions") as Array).size() != (d.get("kinds") as Array).size():
				return {"ok": false, "error": "positions/kinds length mismatch"}
			return {"ok": true, "error": ""}
		TYPE_CASCADE_COMPLETED:
			var keys_err7: String = _exact_keys(d, KEYS_CASCADE)
			if not keys_err7.is_empty():
				return {"ok": false, "error": keys_err7}
			if int(d.get("cascade_index", -1)) < 1:
				return {"ok": false, "error": "cascade_index >= 1 required"}
			if int(d.get("cleared_cell_count", -1)) < 3:
				return {"ok": false, "error": "cleared_cell_count >= 3 required"}
			return {"ok": true, "error": ""}
		TYPE_TURN_COMPLETED:
			var keys_err8: String = _exact_keys(d, KEYS_TURN)
			if not keys_err8.is_empty():
				return {"ok": false, "error": keys_err8}
			if int(d.get("turn_count", -1)) < 1:
				return {"ok": false, "error": "turn_count >= 1 required"}
			if int(d.get("cascade_count", -1)) < 1:
				return {"ok": false, "error": "cascade_count >= 1 required"}
			if int(d.get("cleared_cell_count", -1)) < 3:
				return {"ok": false, "error": "cleared_cell_count >= 3 required"}
			return {"ok": true, "error": ""}
		_:
			return {"ok": false, "error": "unknown event type"}


static func events_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not event_equal(a[i], b[i]):
			return false
	return true


static func event_equal(a: Variant, b: Variant) -> bool:
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
			return false


static func _exact_keys(d: Dictionary, required: Array[String]) -> String:
	if d.size() != required.size():
		return "unexpected key set size"
	for k in required:
		if not d.has(k):
			return "missing key %s" % k
	for k in d.keys():
		if not required.has(str(k)):
			return "unexpected key %s" % str(k)
	return ""


static func _validate_adjacent_pair(from_v: Variant, to_v: Variant, require_adjacent: bool) -> Dictionary:
	var base: Dictionary = _validate_xy_pair_in_bounds(from_v, to_v)
	if not bool(base.get("ok", false)):
		return base
	var f: Dictionary = from_v as Dictionary
	var t: Dictionary = to_v as Dictionary
	var fx: int = int(f.get("x"))
	var fy: int = int(f.get("y"))
	var tx: int = int(t.get("x"))
	var ty: int = int(t.get("y"))
	if fx == tx and fy == ty:
		return {"ok": false, "error": "from == to"}
	if require_adjacent:
		var dist: int = absi(fx - tx) + absi(fy - ty)
		if dist != 1:
			return {"ok": false, "error": "swap not adjacent"}
	return {"ok": true, "error": ""}


static func _validate_xy_pair_in_bounds(from_v: Variant, to_v: Variant) -> Dictionary:
	if not _is_xy_dict_in_bounds(from_v):
		return {"ok": false, "error": "invalid from coordinate"}
	if not _is_xy_dict_in_bounds(to_v):
		return {"ok": false, "error": "invalid to coordinate"}
	return {"ok": true, "error": ""}


static func _require_xy_list(raw: Variant, field: String, min_size: int, unique: bool) -> Dictionary:
	if not (raw is Array):
		return {"ok": false, "error": "%s must be Array" % field}
	var arr: Array = raw as Array
	if arr.size() < min_size:
		return {"ok": false, "error": "%s size < %d" % [field, min_size]}
	var seen: Dictionary = {}
	for item in arr:
		if not _is_xy_dict_in_bounds(item):
			return {"ok": false, "error": "%s contains invalid/out-of-bounds coordinate" % field}
		var d: Dictionary = item as Dictionary
		var key: String = "%d,%d" % [int(d.get("x")), int(d.get("y"))]
		if unique and seen.has(key):
			return {"ok": false, "error": "%s has duplicate coordinates" % field}
		seen[key] = true
	return {"ok": true, "error": ""}


static func _require_kind_list(raw: Variant, field: String, allow_empty: bool) -> Dictionary:
	if not (raw is Array):
		return {"ok": false, "error": "%s must be Array" % field}
	var arr: Array = raw as Array
	if not allow_empty and arr.is_empty():
		return {"ok": false, "error": "%s must not be empty" % field}
	for item in arr:
		if not BattleOrbKind.is_valid(item as StringName):
			return {"ok": false, "error": "%s contains invalid orb kind" % field}
	return {"ok": true, "error": ""}


static func _require_movements(raw: Variant) -> Dictionary:
	if not (raw is Array):
		return {"ok": false, "error": "movements must be Array"}
	var arr: Array = raw as Array
	for item in arr:
		if not (item is Dictionary):
			return {"ok": false, "error": "movement not Dictionary"}
		var d: Dictionary = item as Dictionary
		if d.size() != 2 or not d.has("from") or not d.has("to"):
			return {"ok": false, "error": "movement keys must be from,to"}
		if not _is_xy_dict_in_bounds(d.get("from")) or not _is_xy_dict_in_bounds(d.get("to")):
			return {"ok": false, "error": "movement coordinate invalid"}
		var f: Dictionary = d.get("from") as Dictionary
		var t: Dictionary = d.get("to") as Dictionary
		var fx: int = int(f.get("x"))
		var fy: int = int(f.get("y"))
		var tx: int = int(t.get("x"))
		var ty: int = int(t.get("y"))
		if fx != tx:
			return {"ok": false, "error": "movement must stay in same column"}
		if ty < fy:
			return {"ok": false, "error": "movement cannot move upward"}
		if fx == tx and fy == ty:
			return {"ok": false, "error": "movement from == to"}
	return {"ok": true, "error": ""}


static func _is_xy_dict_in_bounds(v: Variant) -> bool:
	if not (v is Dictionary):
		return false
	var d: Dictionary = v as Dictionary
	if d.size() != 2 or not d.has("x") or not d.has("y"):
		return false
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
	var xi: int = int(x)
	var yi: int = int(y)
	return BattleBoardModel.in_bounds(xi, yi)


static func _xy_dict_eq(a: Variant, b: Variant) -> bool:
	if not _is_xy_dict_in_bounds(a) or not _is_xy_dict_in_bounds(b):
		return false
	var da: Dictionary = a as Dictionary
	var db: Dictionary = b as Dictionary
	return int(da.get("x")) == int(db.get("x")) and int(da.get("y")) == int(db.get("y"))


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
