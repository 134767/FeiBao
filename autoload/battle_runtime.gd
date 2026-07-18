## In-memory battle board runtime (1.0.0). No disk, navigation, or profile mutation.
extends Node

signal runtime_changed(active: bool)
signal board_changed
signal phase_changed(phase: StringName)

const PHASE_INACTIVE: StringName = &"inactive"
const PHASE_READY: StringName = &"ready"
const PHASE_SELECTED: StringName = &"selected"
const PHASE_RESOLVING: StringName = &"resolving"
const PHASE_ERROR: StringName = &"error"

const VALID_PHASES: Array[StringName] = [
	PHASE_INACTIVE,
	PHASE_READY,
	PHASE_SELECTED,
	PHASE_RESOLVING,
	PHASE_ERROR,
]

var _active: bool = false
var _session_area_id: StringName = &""
var _session_stage_id: StringName = &""
var _board: BattleBoardModel = BattleBoardModel.new()
var _engine: BattleBoardEngine = BattleBoardEngine.new()
var _turn_count: int = 0
var _last_match_count: int = 0
var _last_cascade_count: int = 0
var _phase: StringName = PHASE_INACTIVE
var _selected: Vector2i = Vector2i(-1, -1)
var _last_events: Array = []
var _last_message: String = ""


func reset_runtime_state_for_tests() -> void:
	_clear_fields(false)
	_engine.clear_refill_kind_override_for_tests()
	_engine.clear_cascade_hard_cap_override_for_tests()


func has_active_runtime() -> bool:
	return _active and _phase != PHASE_INACTIVE


func get_phase() -> StringName:
	return _phase


func get_turn_count() -> int:
	return _turn_count


func get_last_match_count() -> int:
	return _last_match_count


func get_last_cascade_count() -> int:
	return _last_cascade_count


func get_session_area_id() -> StringName:
	return _session_area_id


func get_session_stage_id() -> StringName:
	return _session_stage_id


func get_board_width() -> int:
	return BattleBoardModel.WIDTH


func get_board_height() -> int:
	return BattleBoardModel.HEIGHT


func get_board_cells() -> Array[StringName]:
	return _board.get_cells()


func get_cell(x: int, y: int) -> StringName:
	return _board.get_cell(x, y)


func get_selected_cell() -> Vector2i:
	return _selected


func has_selection() -> bool:
	return _selected.x >= 0 and _selected.y >= 0


func get_last_resolution_events() -> Array:
	return BattleResolutionEvent.duplicate_events(_last_events)


func get_last_message() -> String:
	return _last_message


func get_rng_state() -> int:
	return _engine.get_rng_state()


## Begin runtime from active BattleState session. Deterministic seed from session fields.
func begin_from_battle_session() -> Dictionary:
	if not is_instance_valid(BattleState) or not BattleState.has_active_session():
		return _result(false, false, "no active BattleState session")

	var area_id: StringName = BattleState.get_area_id()
	var stage_id: StringName = BattleState.get_stage_id()
	var party: Array[StringName] = BattleState.get_party_character_ids()
	var leader: StringName = BattleState.get_leader_character_id()
	if String(area_id).is_empty() or String(stage_id).is_empty():
		return _result(false, false, "session ids empty")
	if party.is_empty() or party.size() > 3:
		return _result(false, false, "invalid party size")
	if party[0] != leader:
		return _result(false, false, "leader must be party index 0")

	# Same session already active → idempotent.
	if (
		has_active_runtime()
		and _session_area_id == area_id
		and _session_stage_id == stage_id
	):
		return _result(true, false, "")

	# Different active runtime must not be overwritten.
	if has_active_runtime():
		return _result(false, false, "active runtime already exists")

	var seed: int = BattleBoardEngine.derive_seed_from_session(area_id, stage_id, party, leader)
	var gen: Dictionary = _engine.generate_initial_board(seed)
	if not bool(gen.get("ok", false)):
		return _result(false, false, str(gen.get("error", "board generation failed")))

	_active = true
	_session_area_id = area_id
	_session_stage_id = stage_id
	_board.set_cells(gen.get("cells", []) as Array)
	_engine.set_rng_state(int(gen.get("rng_state", 1)))
	_turn_count = 0
	_last_match_count = 0
	_last_cascade_count = 0
	_last_events.clear()
	_last_message = ""
	_selected = Vector2i(-1, -1)
	_set_phase(PHASE_READY)
	runtime_changed.emit(true)
	board_changed.emit()
	return _result(true, true, "")


## Test seam: begin from explicit seed while requiring active BattleState binding.
func begin_from_seed_for_tests(seed: int) -> Dictionary:
	if not is_instance_valid(BattleState) or not BattleState.has_active_session():
		return _result(false, false, "no active BattleState session")
	if has_active_runtime():
		return _result(false, false, "active runtime already exists")
	var gen: Dictionary = _engine.generate_initial_board(seed)
	if not bool(gen.get("ok", false)):
		return _result(false, false, str(gen.get("error", "board generation failed")))
	_active = true
	_session_area_id = BattleState.get_area_id()
	_session_stage_id = BattleState.get_stage_id()
	_board.set_cells(gen.get("cells", []) as Array)
	_engine.set_rng_state(int(gen.get("rng_state", 1)))
	_turn_count = 0
	_last_match_count = 0
	_last_cascade_count = 0
	_last_events.clear()
	_last_message = ""
	_selected = Vector2i(-1, -1)
	_set_phase(PHASE_READY)
	runtime_changed.emit(true)
	board_changed.emit()
	return _result(true, true, "")


func clear_runtime() -> Dictionary:
	if not has_active_runtime() and _phase == PHASE_INACTIVE and not _active:
		return _result(true, false, "")
	var was_active: bool = _active
	_clear_fields(true)
	if was_active:
		runtime_changed.emit(false)
		board_changed.emit()
	return _result(true, was_active, "")


func capture_runtime_snapshot() -> Dictionary:
	return {
		"active": _active,
		"session_area_id": _session_area_id,
		"session_stage_id": _session_stage_id,
		"width": BattleBoardModel.WIDTH,
		"height": BattleBoardModel.HEIGHT,
		"board_cells": _board.get_cells(),
		"rng_state": _engine.get_rng_state(),
		"turn_count": _turn_count,
		"phase": _phase,
		"selected_x": _selected.x,
		"selected_y": _selected.y,
		"last_match_count": _last_match_count,
		"last_cascade_count": _last_cascade_count,
		"last_resolution_events": BattleResolutionEvent.duplicate_events(_last_events),
		"last_message": _last_message,
	}


func restore_runtime_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty() or not snapshot.has("active"):
		return _result(false, false, "invalid snapshot")

	var next_active: bool = bool(snapshot.get("active", false))
	var next_area: StringName = snapshot.get("session_area_id", &"") as StringName
	var next_stage: StringName = snapshot.get("session_stage_id", &"") as StringName
	var next_w: int = int(snapshot.get("width", 0))
	var next_h: int = int(snapshot.get("height", 0))
	var next_cells_raw: Variant = snapshot.get("board_cells", [])
	var next_rng: int = int(snapshot.get("rng_state", 0))
	var next_turn: int = int(snapshot.get("turn_count", -1))
	var next_phase: StringName = snapshot.get("phase", PHASE_INACTIVE) as StringName
	var next_sx: int = int(snapshot.get("selected_x", -1))
	var next_sy: int = int(snapshot.get("selected_y", -1))
	var next_match: int = int(snapshot.get("last_match_count", 0))
	var next_cascade: int = int(snapshot.get("last_cascade_count", 0))
	var next_events: Array = []
	var raw_events: Variant = snapshot.get("last_resolution_events", [])
	if raw_events is Array:
		next_events = BattleResolutionEvent.duplicate_events(raw_events as Array)
	var next_msg: String = str(snapshot.get("last_message", ""))

	if next_w != BattleBoardModel.WIDTH or next_h != BattleBoardModel.HEIGHT:
		return _result(false, false, "invalid board dimensions")
	if not (next_cells_raw is Array) or (next_cells_raw as Array).size() != BattleBoardModel.CELL_COUNT:
		return _result(false, false, "invalid board length")
	var next_cells: Array[StringName] = []
	for item in next_cells_raw as Array:
		var k: StringName = item as StringName
		if next_active and not BattleOrbKind.is_empty(k) and not BattleOrbKind.is_valid(k):
			return _result(false, false, "invalid orb kind")
		if not next_active and not BattleOrbKind.is_empty(k) and not BattleOrbKind.is_valid(k):
			return _result(false, false, "invalid orb kind")
		next_cells.append(k)
	if next_active:
		for k in next_cells:
			if not BattleOrbKind.is_valid(k):
				return _result(false, false, "active board requires filled valid cells")
	if not VALID_PHASES.has(next_phase):
		return _result(false, false, "invalid phase")
	if next_turn < 0:
		return _result(false, false, "invalid turn_count")
	if next_match < 0 or next_cascade < 0:
		return _result(false, false, "invalid counters")
	if next_sx != -1 or next_sy != -1:
		if not BattleBoardModel.in_bounds(next_sx, next_sy):
			return _result(false, false, "selected cell out of bounds")
	if next_active:
		if String(next_area).is_empty() or String(next_stage).is_empty():
			return _result(false, false, "active snapshot missing session ids")
		# Binding check: when BattleState active, session must match.
		if is_instance_valid(BattleState) and BattleState.has_active_session():
			if BattleState.get_area_id() != next_area or BattleState.get_stage_id() != next_stage:
				return _result(false, false, "mismatched BattleState session")
	if next_phase == PHASE_INACTIVE and next_active:
		return _result(false, false, "phase inactive with active flag")

	# Idempotent identical restore.
	if (
		_active == next_active
		and _session_area_id == next_area
		and _session_stage_id == next_stage
		and _engine.get_rng_state() == next_rng
		and _turn_count == next_turn
		and _phase == next_phase
		and _selected.x == next_sx
		and _selected.y == next_sy
		and _last_match_count == next_match
		and _last_cascade_count == next_cascade
		and _last_message == next_msg
		and _board.equals_cells(next_cells)
		and _events_equal(_last_events, next_events)
	):
		return _result(true, false, "")

	_active = next_active
	_session_area_id = next_area
	_session_stage_id = next_stage
	_board.set_cells(next_cells)
	_engine.set_rng_state(next_rng)
	_turn_count = next_turn
	_selected = Vector2i(next_sx, next_sy)
	_last_match_count = next_match
	_last_cascade_count = next_cascade
	_last_events = next_events
	_last_message = next_msg
	_set_phase(next_phase)
	runtime_changed.emit(_active)
	board_changed.emit()
	return _result(true, true, "")


## Select / deselect / retarget / attempt swap via cell press.
func select_cell(x: int, y: int) -> Dictionary:
	if not has_active_runtime():
		return {"ok": false, "error": "inactive", "accepted": false}
	if _phase == PHASE_RESOLVING:
		return {"ok": false, "error": "resolving", "accepted": false}
	if _phase == PHASE_ERROR:
		return {"ok": false, "error": "error phase", "accepted": false}
	if not BattleBoardModel.in_bounds(x, y):
		return {"ok": false, "error": "out of bounds", "accepted": false}

	if has_selection() and _selected.x == x and _selected.y == y:
		_selected = Vector2i(-1, -1)
		_set_phase(PHASE_READY)
		_last_message = ""
		board_changed.emit()
		return {"ok": true, "error": "", "accepted": true, "action": "deselect"}

	if has_selection() and BattleBoardEngine.are_adjacent(_selected.x, _selected.y, x, y):
		return try_swap_cells(_selected, Vector2i(x, y))

	_selected = Vector2i(x, y)
	_set_phase(PHASE_SELECTED)
	_last_message = ""
	board_changed.emit()
	return {"ok": true, "error": "", "accepted": true, "action": "select"}


func try_swap_selected_with(x: int, y: int) -> Dictionary:
	if not has_selection():
		return {"ok": false, "error": "no selection", "accepted": false}
	return try_swap_cells(_selected, Vector2i(x, y))


func try_swap_cells(a: Vector2i, b: Vector2i) -> Dictionary:
	if not has_active_runtime():
		return {"ok": false, "error": "inactive", "accepted": false}
	if _phase == PHASE_RESOLVING or _phase == PHASE_INACTIVE:
		return {"ok": false, "error": "invalid phase", "accepted": false}
	if _phase == PHASE_ERROR:
		return {"ok": false, "error": "error phase", "accepted": false}

	var prior: Dictionary = capture_runtime_snapshot()
	_set_phase(PHASE_RESOLVING)
	var result: Dictionary = _engine.try_swap(
		_board.get_cells(),
		a.x,
		a.y,
		b.x,
		b.y,
		_turn_count
	)

	if not bool(result.get("ok", false)):
		# Hard fail (bounds/cascade): restore exact prior.
		restore_runtime_snapshot(prior)
		_last_message = str(result.get("error", "swap failed"))
		if str(result.get("error", "")).find("cascade") >= 0:
			_set_phase(PHASE_ERROR)
			_last_message = "連鎖超過上限，已還原"
		else:
			_set_phase(PHASE_READY if not has_selection() else PHASE_SELECTED)
		return {
			"ok": false,
			"accepted": false,
			"error": str(result.get("error", "")),
		}

	if not bool(result.get("accepted", false)):
		# No match: board/rng/turn unchanged; clear selection.
		_selected = Vector2i(-1, -1)
		_last_events = result.get("events", []) as Array
		_last_match_count = 0
		_last_cascade_count = 0
		_last_message = "此交換沒有形成消除"
		_set_phase(PHASE_READY)
		board_changed.emit()
		return {
			"ok": true,
			"accepted": false,
			"error": "",
			"reason": "no match",
		}

	# Accepted move.
	_board.set_cells(result.get("cells", []) as Array)
	_engine.set_rng_state(int(result.get("rng_state", _engine.get_rng_state())))
	_turn_count = int(result.get("turn_count", _turn_count))
	_last_match_count = int(result.get("cleared_cell_count", 0))
	_last_cascade_count = int(result.get("cascade_count", 0))
	_last_events = result.get("events", []) as Array
	_selected = Vector2i(-1, -1)
	_last_message = "回合完成 · 消除 %d · 連鎖 %d" % [_last_match_count, _last_cascade_count]
	_set_phase(PHASE_READY)
	board_changed.emit()
	return {
		"ok": true,
		"accepted": true,
		"error": "",
		"cleared_cell_count": _last_match_count,
		"cascade_count": _last_cascade_count,
		"turn_count": _turn_count,
	}


func set_board_cells_for_tests(cells: Array) -> bool:
	if not has_active_runtime():
		return false
	return _board.set_cells(cells)


func set_refill_kind_override_for_tests(kind: StringName) -> void:
	_engine.set_refill_kind_override_for_tests(kind)


func clear_refill_kind_override_for_tests() -> void:
	_engine.clear_refill_kind_override_for_tests()


func set_cascade_hard_cap_override_for_tests(cap: int) -> void:
	_engine.set_cascade_hard_cap_override_for_tests(cap)


func clear_cascade_hard_cap_override_for_tests() -> void:
	_engine.clear_cascade_hard_cap_override_for_tests()


func set_rng_state_for_tests(state: int) -> void:
	_engine.set_rng_state(state)


func derive_seed_for_tests(
	area_id: StringName,
	stage_id: StringName,
	party: Array[StringName],
	leader: StringName
) -> int:
	return BattleBoardEngine.derive_seed_from_session(area_id, stage_id, party, leader)


func find_matches_for_tests(cells: Array) -> Array:
	return BattleBoardEngine.find_matches(cells)


func apply_gravity_for_tests(cells: Array) -> Dictionary:
	var board := BattleBoardModel.new(cells)
	var moves: Array = BattleBoardEngine.apply_gravity(board)
	return {"cells": board.get_cells(), "movements": moves}


func refill_for_tests(cells: Array) -> Dictionary:
	var board := BattleBoardModel.new(cells)
	var r: Dictionary = _engine.refill_empty(board)
	return {
		"cells": board.get_cells(),
		"positions": r.get("positions", []),
		"kinds": r.get("kinds", []),
		"rng_state": _engine.get_rng_state(),
	}


func generate_board_for_tests(seed: int) -> Dictionary:
	return _engine.generate_initial_board(seed)


func _set_phase(phase: StringName) -> void:
	if _phase == phase:
		return
	_phase = phase
	phase_changed.emit(_phase)


func _clear_fields(emit_phase: bool) -> void:
	_active = false
	_session_area_id = &""
	_session_stage_id = &""
	_board.clear_all()
	_engine.set_rng_state(1)
	_turn_count = 0
	_last_match_count = 0
	_last_cascade_count = 0
	_selected = Vector2i(-1, -1)
	_last_events.clear()
	_last_message = ""
	if emit_phase:
		_set_phase(PHASE_INACTIVE)
	else:
		_phase = PHASE_INACTIVE


func _result(ok: bool, changed: bool, error: String) -> Dictionary:
	return {
		"ok": ok,
		"changed": changed,
		"error": error,
		"active": has_active_runtime(),
		"phase": _phase,
	}


func _events_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if str(a[i]) != str(b[i]):
			return false
	return true
