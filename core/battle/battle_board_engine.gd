## Pure board engine: generation, match, gravity, refill, swap resolution.
## No SceneTree, UI, FileAccess, PlayerData, NavigationState, or global RNG.
class_name BattleBoardEngine
extends RefCounted

const GENERATION_MAX_ATTEMPTS: int = 64
const CASCADE_HARD_CAP: int = 64
const MATCH_MIN_RUN: int = 3

## Dedicated xorshift32 RNG state (uint32 as signed int; mask applied).
var _rng_state: int = 1
## Test-only: force refill kind when non-empty.
var _refill_kind_override_for_tests: StringName = &""
## Test-only: override cascade hard cap when > 0.
var _cascade_hard_cap_override_for_tests: int = 0


func get_rng_state() -> int:
	return _rng_state


func set_rng_state(state: int) -> void:
	_rng_state = _normalize_state(state)


func set_refill_kind_override_for_tests(kind: StringName) -> void:
	_refill_kind_override_for_tests = kind


func clear_refill_kind_override_for_tests() -> void:
	_refill_kind_override_for_tests = &""


func set_cascade_hard_cap_override_for_tests(cap: int) -> void:
	_cascade_hard_cap_override_for_tests = maxi(0, cap)


func clear_cascade_hard_cap_override_for_tests() -> void:
	_cascade_hard_cap_override_for_tests = 0


## Stable FNV-1a 32-bit hash over fixed field order (no Dictionary iteration).
static func derive_seed_from_session(
	area_id: StringName,
	stage_id: StringName,
	party_ids: Array[StringName],
	leader_id: StringName
) -> int:
	var h: int = 2166136261
	h = _fnv1a_mix(h, str(area_id))
	h = _fnv1a_mix(h, "|")
	h = _fnv1a_mix(h, str(stage_id))
	h = _fnv1a_mix(h, "|")
	h = _fnv1a_mix(h, str(leader_id))
	h = _fnv1a_mix(h, "|")
	for i in party_ids.size():
		h = _fnv1a_mix(h, str(party_ids[i]))
		h = _fnv1a_mix(h, ",")
	if h == 0:
		return 1
	return h & 0x7fffffff


static func _fnv1a_mix(h: int, s: String) -> int:
	var out: int = h
	var bytes: PackedByteArray = s.to_utf8_buffer()
	for b in bytes:
		out = int((out ^ int(b)) * 16777619) & 0xffffffff
		if out > 0x7fffffff:
			out = out - 0x100000000
	return out & 0xffffffff


func _normalize_state(state: int) -> int:
	var s: int = state & 0xffffffff
	if s == 0:
		return 1
	return s


func next_u32() -> int:
	# xorshift32
	var x: int = _normalize_state(_rng_state)
	x ^= (x << 13) & 0xffffffff
	x ^= (x >> 17) & 0xffffffff
	x ^= (x << 5) & 0xffffffff
	x = x & 0xffffffff
	if x == 0:
		x = 1
	_rng_state = x
	return x


func next_kind() -> StringName:
	if not String(_refill_kind_override_for_tests).is_empty() and BattleOrbKind.is_valid(_refill_kind_override_for_tests):
		return _refill_kind_override_for_tests
	var kinds: Array[StringName] = BattleOrbKind.all_kinds()
	var idx: int = next_u32() % kinds.size()
	return kinds[idx]


## Generate a legal initial board (no matches, at least one legal swap). Bounded retries.
func generate_initial_board(seed: int) -> Dictionary:
	var base: int = _normalize_state(seed)
	for attempt in GENERATION_MAX_ATTEMPTS:
		# Reproducible per-attempt seed: base + attempt (stable).
		_rng_state = _normalize_state(base + attempt * 9973 + 1)
		var board := BattleBoardModel.new()
		var ok_fill: bool = _fill_board_no_immediate_match(board)
		if not ok_fill:
			continue
		if has_any_match(board.get_cells()):
			continue
		if not has_legal_swap(board.get_cells()):
			continue
		return {
			"ok": true,
			"error": "",
			"cells": board.get_cells(),
			"rng_state": _rng_state,
			"attempts": attempt + 1,
		}
	return {
		"ok": false,
		"error": "board generation failed within attempt budget",
		"cells": [],
		"rng_state": _rng_state,
		"attempts": GENERATION_MAX_ATTEMPTS,
	}


func _fill_board_no_immediate_match(board: BattleBoardModel) -> bool:
	var kinds: Array[StringName] = BattleOrbKind.all_kinds()
	for y in BattleBoardModel.HEIGHT:
		for x in BattleBoardModel.WIDTH:
			var forbidden: Dictionary = {}
			# Avoid horizontal run of 3 ending at (x,y)
			if x >= 2:
				var a: StringName = board.get_cell(x - 1, y)
				var b: StringName = board.get_cell(x - 2, y)
				if a == b and BattleOrbKind.is_valid(a):
					forbidden[a] = true
			# Avoid vertical run of 3 ending at (x,y)
			if y >= 2:
				var c: StringName = board.get_cell(x, y - 1)
				var d: StringName = board.get_cell(x, y - 2)
				if c == d and BattleOrbKind.is_valid(c):
					forbidden[c] = true
			var choices: Array[StringName] = []
			for k in kinds:
				if not forbidden.has(k):
					choices.append(k)
			if choices.is_empty():
				return false
			var pick: StringName = choices[next_u32() % choices.size()]
			board.set_cell(x, y, pick)
	return true


## Returns matched cells as Array of {"x","y"} in row-major stable order, deduplicated.
static func find_matches(cells: Array) -> Array:
	if cells.size() != BattleBoardModel.CELL_COUNT:
		return []
	var marked: PackedByteArray = PackedByteArray()
	marked.resize(BattleBoardModel.CELL_COUNT)
	for i in BattleBoardModel.CELL_COUNT:
		marked[i] = 0

	# Horizontal runs
	for y in BattleBoardModel.HEIGHT:
		var x: int = 0
		while x < BattleBoardModel.WIDTH:
			var kind: StringName = cells[BattleBoardModel.index_of(x, y)] as StringName
			if not BattleOrbKind.is_valid(kind):
				x += 1
				continue
			var run: int = 1
			while x + run < BattleBoardModel.WIDTH and (cells[BattleBoardModel.index_of(x + run, y)] as StringName) == kind:
				run += 1
			if run >= MATCH_MIN_RUN:
				for dx in run:
					marked[BattleBoardModel.index_of(x + dx, y)] = 1
			x += run

	# Vertical runs
	for x in BattleBoardModel.WIDTH:
		var y: int = 0
		while y < BattleBoardModel.HEIGHT:
			var kind: StringName = cells[BattleBoardModel.index_of(x, y)] as StringName
			if not BattleOrbKind.is_valid(kind):
				y += 1
				continue
			var run: int = 1
			while y + run < BattleBoardModel.HEIGHT and (cells[BattleBoardModel.index_of(x, y + run)] as StringName) == kind:
				run += 1
			if run >= MATCH_MIN_RUN:
				for dy in run:
					marked[BattleBoardModel.index_of(x, y + dy)] = 1
			y += run

	var out: Array = []
	for y in BattleBoardModel.HEIGHT:
		for x in BattleBoardModel.WIDTH:
			var idx: int = BattleBoardModel.index_of(x, y)
			if marked[idx] == 1:
				out.append({"x": x, "y": y})
	return out


static func has_any_match(cells: Array) -> bool:
	return not find_matches(cells).is_empty()


static func are_adjacent(ax: int, ay: int, bx: int, by: int) -> bool:
	if not BattleBoardModel.in_bounds(ax, ay) or not BattleBoardModel.in_bounds(bx, by):
		return false
	return absi(ax - bx) + absi(ay - by) == 1


static func has_legal_swap(cells: Array) -> bool:
	if cells.size() != BattleBoardModel.CELL_COUNT:
		return false
	var board := BattleBoardModel.new(cells)
	# Try every adjacent pair once (right and down only to avoid duplicates).
	for y in BattleBoardModel.HEIGHT:
		for x in BattleBoardModel.WIDTH:
			if x + 1 < BattleBoardModel.WIDTH:
				board.swap_cells(x, y, x + 1, y)
				if has_any_match(board.get_cells()):
					return true
				board.swap_cells(x, y, x + 1, y)
			if y + 1 < BattleBoardModel.HEIGHT:
				board.swap_cells(x, y, x, y + 1)
				if has_any_match(board.get_cells()):
					return true
				board.swap_cells(x, y, x, y + 1)
	return false


## Apply gravity per column: non-empty cells sink, relative order kept. Returns movements.
static func apply_gravity(board: BattleBoardModel) -> Array:
	var movements: Array = []
	for x in BattleBoardModel.WIDTH:
		var stack: Array[StringName] = []
		var sources: Array[int] = []
		for y in range(BattleBoardModel.HEIGHT - 1, -1, -1):
			var k: StringName = board.get_cell(x, y)
			if BattleOrbKind.is_valid(k):
				stack.append(k)
				sources.append(y)
		# Clear column
		for y in BattleBoardModel.HEIGHT:
			board.set_cell(x, y, BattleOrbKind.EMPTY)
		# Place from bottom
		var write_y: int = BattleBoardModel.HEIGHT - 1
		for i in stack.size():
			var from_y: int = sources[i]
			var kind: StringName = stack[i]
			board.set_cell(x, write_y, kind)
			if from_y != write_y:
				movements.append({
					"from_x": x,
					"from_y": from_y,
					"to_x": x,
					"to_y": write_y,
				})
			write_y -= 1
	return movements


## Refill empty cells row-major (left→right, top→bottom). Mutates board + RNG.
func refill_empty(board: BattleBoardModel) -> Dictionary:
	var positions: Array = []
	var kinds: Array = []
	for y in BattleBoardModel.HEIGHT:
		for x in BattleBoardModel.WIDTH:
			if BattleOrbKind.is_empty(board.get_cell(x, y)):
				var k: StringName = next_kind()
				board.set_cell(x, y, k)
				positions.append({"x": x, "y": y})
				kinds.append(k)
	return {"positions": positions, "kinds": kinds}


func _cascade_cap() -> int:
	if _cascade_hard_cap_override_for_tests > 0:
		return _cascade_hard_cap_override_for_tests
	return CASCADE_HARD_CAP


## Full move resolution after a tentative swap already applied on board.
## On cascade hard-cap exceed: returns ok=false (caller restores).
func resolve_after_valid_swap(
	board: BattleBoardModel,
	from_xy: Vector2i,
	to_xy: Vector2i,
	next_turn_count: int
) -> Dictionary:
	var events: Array = []
	events.append(BattleResolutionEvent.make_swap(from_xy, to_xy))
	var total_cleared: int = 0
	var cascade_index: int = 0
	var cap: int = _cascade_cap()

	while true:
		var matches: Array = find_matches(board.get_cells())
		if matches.is_empty():
			break
		cascade_index += 1
		if cascade_index > cap:
			return {
				"ok": false,
				"error": "cascade hard cap exceeded",
				"events": [],
				"cleared_cell_count": 0,
				"cascade_count": 0,
			}
		events.append(BattleResolutionEvent.make_match_found(cascade_index, matches))
		var cleared_kinds: Array = []
		for m in matches:
			var mx: int = int((m as Dictionary).get("x", 0))
			var my: int = int((m as Dictionary).get("y", 0))
			cleared_kinds.append(board.get_cell(mx, my))
			board.set_cell(mx, my, BattleOrbKind.EMPTY)
		events.append(BattleResolutionEvent.make_cells_cleared(cascade_index, matches, cleared_kinds))
		total_cleared += matches.size()
		var movements: Array = apply_gravity(board)
		events.append(BattleResolutionEvent.make_gravity_applied(movements))
		var refill: Dictionary = refill_empty(board)
		events.append(BattleResolutionEvent.make_cells_refilled(
			refill.get("positions", []) as Array,
			refill.get("kinds", []) as Array
		))
		events.append(BattleResolutionEvent.make_cascade_completed(cascade_index, matches.size()))

	events.append(BattleResolutionEvent.make_turn_completed(next_turn_count, cascade_index, total_cleared))
	return {
		"ok": true,
		"error": "",
		"events": events,
		"cleared_cell_count": total_cleared,
		"cascade_count": cascade_index,
	}


## Try swap on a cell array copy. Returns full result without mutating caller's board on reject.
func try_swap(
	cells: Array,
	ax: int,
	ay: int,
	bx: int,
	by: int,
	current_turn: int
) -> Dictionary:
	if not BattleBoardModel.in_bounds(ax, ay) or not BattleBoardModel.in_bounds(bx, by):
		return _reject("out of bounds", cells)
	if ax == bx and ay == by:
		return _reject("same cell", cells)
	if not are_adjacent(ax, ay, bx, by):
		return _reject("not adjacent", cells)

	var board := BattleBoardModel.new(cells)
	var rng_before: int = _rng_state
	board.swap_cells(ax, ay, bx, by)
	if not has_any_match(board.get_cells()):
		# Swap back already by discarding board; RNG unchanged.
		_rng_state = rng_before
		return {
			"ok": true,
			"accepted": false,
			"error": "",
			"reason": "no match",
			"cells": cells.duplicate() if cells is Array else [],
			"events": [BattleResolutionEvent.make_swap_rejected(Vector2i(ax, ay), Vector2i(bx, by), "no match")],
			"cleared_cell_count": 0,
			"cascade_count": 0,
			"turn_count": current_turn,
			"rng_state": _rng_state,
		}

	var resolved: Dictionary = resolve_after_valid_swap(
		board,
		Vector2i(ax, ay),
		Vector2i(bx, by),
		current_turn + 1
	)
	if not bool(resolved.get("ok", false)):
		_rng_state = rng_before
		return {
			"ok": false,
			"accepted": false,
			"error": str(resolved.get("error", "resolve failed")),
			"reason": str(resolved.get("error", "")),
			"cells": cells.duplicate() if cells is Array else [],
			"events": [],
			"cleared_cell_count": 0,
			"cascade_count": 0,
			"turn_count": current_turn,
			"rng_state": _rng_state,
		}

	return {
		"ok": true,
		"accepted": true,
		"error": "",
		"reason": "",
		"cells": board.get_cells(),
		"events": resolved.get("events", []),
		"cleared_cell_count": int(resolved.get("cleared_cell_count", 0)),
		"cascade_count": int(resolved.get("cascade_count", 0)),
		"turn_count": current_turn + 1,
		"rng_state": _rng_state,
	}


func _reject(reason: String, cells: Array) -> Dictionary:
	return {
		"ok": false,
		"accepted": false,
		"error": reason,
		"reason": reason,
		"cells": cells.duplicate() if cells is Array else [],
		"events": [],
		"cleared_cell_count": 0,
		"cascade_count": 0,
		"turn_count": -1,
		"rng_state": _rng_state,
	}
