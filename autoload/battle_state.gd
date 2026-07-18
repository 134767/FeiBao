## In-memory battle session shell (0.9.0).
## No disk I/O, no navigation, no PlayerProfile / party / AdventureState mutation.
extends Node

signal session_changed(stage_id: StringName, active: bool)

const PARTY_MIN: int = 1
const PARTY_MAX: int = 3

var _active: bool = false
var _stage_id: StringName = &""
var _area_id: StringName = &""
var _stage_display_name: String = ""
var _stage_summary: String = ""
var _stage_number: int = 0
var _area_display_name: String = ""
var _party_character_ids: Array[StringName] = []
var _leader_character_id: StringName = &""
## Test seam only (null = production).
var _player_data_available_override_for_tests: Variant = null


func reset_runtime_state_for_tests() -> void:
	_clear_fields()
	_player_data_available_override_for_tests = null


func has_active_session() -> bool:
	return _active and not String(_stage_id).is_empty()


func get_area_id() -> StringName:
	return _area_id


func get_stage_id() -> StringName:
	return _stage_id


func get_party_character_ids() -> Array[StringName]:
	return _party_character_ids.duplicate()


func get_leader_character_id() -> StringName:
	return _leader_character_id


func get_stage_display_name() -> String:
	return _stage_display_name


func get_stage_summary() -> String:
	return _stage_summary


func get_stage_number() -> int:
	return _stage_number


func get_area_display_name() -> String:
	return _area_display_name


## Immutable snapshot of the current session (or empty inactive snapshot).
func capture_session_snapshot() -> Dictionary:
	return {
		"active": _active,
		"area_id": _area_id,
		"stage_id": _stage_id,
		"stage_display_name": _stage_display_name,
		"stage_summary": _stage_summary,
		"stage_number": _stage_number,
		"area_display_name": _area_display_name,
		"party_character_ids": _party_character_ids.duplicate(),
		"leader_character_id": _leader_character_id,
	}


## Restore a snapshot captured via capture_session_snapshot(). Emits only if state changes.
func restore_session_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty() or not snapshot.has("active"):
		return _result(false, false, "invalid snapshot")

	var next_active: bool = bool(snapshot.get("active", false))
	var next_stage: StringName = snapshot.get("stage_id", &"") as StringName
	var next_area: StringName = snapshot.get("area_id", &"") as StringName
	var next_party: Array[StringName] = _coerce_party_ids(snapshot.get("party_character_ids", []))
	var next_leader: StringName = snapshot.get("leader_character_id", &"") as StringName
	var next_stage_name: String = str(snapshot.get("stage_display_name", ""))
	var next_stage_summary: String = str(snapshot.get("stage_summary", ""))
	var next_stage_number: int = int(snapshot.get("stage_number", 0))
	var next_area_name: String = str(snapshot.get("area_display_name", ""))

	if (
		_active == next_active
		and _stage_id == next_stage
		and _area_id == next_area
		and _leader_character_id == next_leader
		and _stage_display_name == next_stage_name
		and _stage_summary == next_stage_summary
		and _stage_number == next_stage_number
		and _area_display_name == next_area_name
		and _party_ids_equal(_party_character_ids, next_party)
	):
		return _result(true, false, "")

	_active = next_active
	_stage_id = next_stage
	_area_id = next_area
	_stage_display_name = next_stage_name
	_stage_summary = next_stage_summary
	_stage_number = next_stage_number
	_area_display_name = next_area_name
	_party_character_ids = next_party.duplicate()
	_leader_character_id = next_leader
	session_changed.emit(_stage_id if _active else &"", _active)
	return _result(true, true, "")


## Begin session from AdventureState prepared stage + validated PlayerData party.
func begin_from_prepared_stage() -> Dictionary:
	if not is_instance_valid(AdventureState) or not AdventureState.has_prepared_stage():
		return _result(false, false, "no prepared stage")

	var stage: StageDefinition = AdventureState.get_prepared_stage()
	var area: StageAreaDefinition = AdventureState.get_prepared_area()
	if stage == null:
		return _result(false, false, "prepared stage missing")

	if not _is_player_data_available():
		return _result(false, false, "PlayerData unavailable")
	if not PlayerData.is_initialized():
		PlayerData.initialize()

	var party: Array[StringName] = PlayerData.get_active_party_character_ids()
	var leader_id: StringName = PlayerData.get_party_leader_character_id()
	var party_check: Dictionary = _validate_party(party, leader_id)
	if not bool(party_check.get("ok", false)):
		return _result(false, false, str(party_check.get("error", "invalid party")))

	var stage_id: StringName = stage.get_id()
	var area_id: StringName = stage.get_area_id()
	if area != null:
		area_id = area.get_id()

	# Same session already active → idempotent success, no signal.
	if (
		has_active_session()
		and _stage_id == stage_id
		and _area_id == area_id
		and _leader_character_id == leader_id
		and _party_ids_equal(_party_character_ids, party)
	):
		return _result(true, false, "")

	# Different active session must not be overwritten.
	if has_active_session():
		return _result(false, false, "active session already exists")

	_active = true
	_stage_id = stage_id
	_area_id = area_id
	_stage_display_name = stage.get_display_name()
	_stage_summary = stage.get_summary()
	_stage_number = stage.get_stage_number()
	_area_display_name = area.get_display_name() if area != null else ""
	_party_character_ids = party.duplicate()
	_leader_character_id = leader_id
	session_changed.emit(_stage_id, true)
	return _result(true, true, "")


func clear_session() -> Dictionary:
	if not has_active_session():
		return _result(true, false, "")
	_clear_fields()
	session_changed.emit(&"", false)
	return _result(true, true, "")


func _clear_fields() -> void:
	_active = false
	_stage_id = &""
	_area_id = &""
	_stage_display_name = ""
	_stage_summary = ""
	_stage_number = 0
	_area_display_name = ""
	_party_character_ids.clear()
	_leader_character_id = &""


func _result(ok: bool, changed: bool, error: String) -> Dictionary:
	return {
		"ok": ok,
		"changed": changed,
		"error": error,
		"area_id": _area_id,
		"stage_id": _stage_id,
		"active": has_active_session(),
	}


func _validate_party(party: Array[StringName], leader_id: StringName) -> Dictionary:
	if party.size() < PARTY_MIN:
		return {"ok": false, "error": "active party is empty"}
	if party.size() > PARTY_MAX:
		return {"ok": false, "error": "active party exceeds max size"}
	if String(leader_id).is_empty():
		return {"ok": false, "error": "leader is empty"}
	if party[0] != leader_id:
		return {"ok": false, "error": "leader must be active party index 0"}

	var seen: Dictionary = {}
	var cat: Dictionary = CharacterCatalog.load_default()
	if not bool(cat.get("ok", false)):
		return {"ok": false, "error": "character catalog unavailable"}
	var known: Dictionary = {}
	for item in cat.get("characters", []):
		if item is CharacterDefinition:
			known[(item as CharacterDefinition).get_id()] = true

	for id in party:
		if String(id).is_empty():
			return {"ok": false, "error": "party contains empty character id"}
		if seen.has(id):
			return {"ok": false, "error": "party contains duplicate character id"}
		seen[id] = true
		if not known.has(id):
			return {"ok": false, "error": "unknown character id: %s" % str(id)}
		if not PlayerData.owns_character(id):
			return {"ok": false, "error": "unowned character id: %s" % str(id)}
	return {"ok": true, "error": ""}


func _party_ids_equal(a: Array[StringName], b: Array[StringName]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


func _coerce_party_ids(raw: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if raw is Array:
		for item in raw as Array:
			out.append(item as StringName)
	return out


func _is_player_data_available() -> bool:
	if _player_data_available_override_for_tests != null:
		return bool(_player_data_available_override_for_tests)
	return is_instance_valid(PlayerData)


func set_player_data_available_override_for_tests(available: bool) -> void:
	_player_data_available_override_for_tests = available


func clear_player_data_available_override_for_tests() -> void:
	_player_data_available_override_for_tests = null


## Test seam: party contract validation without mutating session.
func evaluate_party_contract_for_tests(party: Array[StringName], leader_id: StringName) -> Dictionary:
	return _validate_party(party, leader_id)
