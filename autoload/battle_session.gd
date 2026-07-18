## In-memory battle session shell for 0.9.0.
## Snapshots prepared stage + active party; no combat, no disk, no profile mutation.
extends Node

signal session_changed(stage_id: StringName, active: bool)

var _active: bool = false
var _stage_id: StringName = &""
var _area_id: StringName = &""
var _stage_display_name: String = ""
var _stage_summary: String = ""
var _stage_number: int = 0
var _area_display_name: String = ""
var _party_character_ids: Array[StringName] = []
var _leader_character_id: StringName = &""
var _party_display_names: Array[String] = []
var _leader_display_name: String = ""


func reset_runtime_state_for_tests() -> void:
	_active = false
	_stage_id = &""
	_area_id = &""
	_stage_display_name = ""
	_stage_summary = ""
	_stage_number = 0
	_area_display_name = ""
	_party_character_ids.clear()
	_leader_character_id = &""
	_party_display_names.clear()
	_leader_display_name = ""


func has_active_session() -> bool:
	return _active and not String(_stage_id).is_empty()


func get_stage_id() -> StringName:
	return _stage_id


func get_area_id() -> StringName:
	return _area_id


func get_stage_display_name() -> String:
	return _stage_display_name


func get_stage_summary() -> String:
	return _stage_summary


func get_stage_number() -> int:
	return _stage_number


func get_area_display_name() -> String:
	return _area_display_name


func get_party_character_ids() -> Array[StringName]:
	return _party_character_ids.duplicate()


func get_leader_character_id() -> StringName:
	return _leader_character_id


func get_party_display_names() -> Array[String]:
	return _party_display_names.duplicate()


func get_leader_display_name() -> String:
	return _leader_display_name


## Create session from AdventureState prepared stage + PlayerData party snapshot.
func begin_from_prepared() -> Dictionary:
	var empty: Dictionary = _result(false, false, "no prepared stage", &"", &"")
	if not is_instance_valid(AdventureState) or not AdventureState.has_prepared_stage():
		empty["error"] = "no prepared stage"
		return empty

	var stage: StageDefinition = AdventureState.get_prepared_stage()
	var area: StageAreaDefinition = AdventureState.get_prepared_area()
	if stage == null:
		empty["error"] = "prepared stage missing"
		return empty

	if not is_instance_valid(PlayerData):
		empty["error"] = "PlayerData unavailable"
		return empty
	if not PlayerData.is_initialized():
		PlayerData.initialize()

	var party: Array[StringName] = PlayerData.get_active_party_character_ids()
	if party.is_empty():
		empty["error"] = "active party is empty"
		return empty

	var leader_id: StringName = PlayerData.get_party_leader_character_id()
	if String(leader_id).is_empty():
		leader_id = party[0]

	var stage_id: StringName = stage.get_id()
	var area_id: StringName = stage.get_area_id()
	if area != null:
		area_id = area.get_id()

	var names: Array[String] = _resolve_display_names(party)
	var leader_name: String = _resolve_one_name(leader_id)
	if leader_name.is_empty() and not names.is_empty():
		leader_name = names[0]

	if (
		_active
		and _stage_id == stage_id
		and _area_id == area_id
		and _leader_character_id == leader_id
		and _party_ids_equal(_party_character_ids, party)
	):
		return _result(true, false, "", _area_id, _stage_id)

	_active = true
	_stage_id = stage_id
	_area_id = area_id
	_stage_display_name = stage.get_display_name()
	_stage_summary = stage.get_summary()
	_stage_number = stage.get_stage_number()
	_area_display_name = area.get_display_name() if area != null else ""
	_party_character_ids = party.duplicate()
	_leader_character_id = leader_id
	_party_display_names = names
	_leader_display_name = leader_name
	session_changed.emit(_stage_id, true)
	return _result(true, true, "", _area_id, _stage_id)


func clear_session() -> Dictionary:
	if not has_active_session():
		return _result(true, false, "", &"", &"")
	_active = false
	_stage_id = &""
	_area_id = &""
	_stage_display_name = ""
	_stage_summary = ""
	_stage_number = 0
	_area_display_name = ""
	_party_character_ids.clear()
	_leader_character_id = &""
	_party_display_names.clear()
	_leader_display_name = ""
	session_changed.emit(&"", false)
	return _result(true, true, "", &"", &"")


func _result(
	ok: bool,
	changed: bool,
	error: String,
	area_id: StringName,
	stage_id: StringName
) -> Dictionary:
	return {
		"ok": ok,
		"changed": changed,
		"error": error,
		"area_id": area_id,
		"stage_id": stage_id,
		"active": _active,
	}


func _party_ids_equal(a: Array[StringName], b: Array[StringName]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


func _resolve_display_names(party: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	var cat: Dictionary = CharacterCatalog.load_default()
	var by_id: Dictionary = {}
	if bool(cat.get("ok", false)):
		for item in cat.get("characters", []):
			if item is CharacterDefinition:
				var d: CharacterDefinition = item as CharacterDefinition
				by_id[d.get_id()] = d.get_display_name()
	for id in party:
		if by_id.has(id):
			out.append(str(by_id[id]))
		else:
			out.append(str(id))
	return out


func _resolve_one_name(character_id: StringName) -> String:
	if String(character_id).is_empty():
		return ""
	var cat: Dictionary = CharacterCatalog.load_default()
	if not bool(cat.get("ok", false)):
		return str(character_id)
	for item in cat.get("characters", []):
		if item is CharacterDefinition and (item as CharacterDefinition).get_id() == character_id:
			return (item as CharacterDefinition).get_display_name()
	return str(character_id)
