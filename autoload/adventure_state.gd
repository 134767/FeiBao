## In-memory stage preparation context for upcoming battle systems.
## Does not persist, navigate, or mutate PlayerProfile / party.
extends Node

signal prepared_stage_changed(area_id: StringName, stage_id: StringName)

var _selected_area_id: StringName = &""
var _selected_stage_id: StringName = &""
var _prepared_stage: StageDefinition = null
var _prepared_area: StageAreaDefinition = null


func reset_runtime_state_for_tests() -> void:
	_selected_area_id = &""
	_selected_stage_id = &""
	_prepared_stage = null
	_prepared_area = null


func has_prepared_stage() -> bool:
	return not String(_selected_stage_id).is_empty() and _prepared_stage != null


func get_selected_area_id() -> StringName:
	return _selected_area_id


func get_selected_stage_id() -> StringName:
	return _selected_stage_id


func get_prepared_stage() -> StageDefinition:
	if _prepared_stage == null:
		return null
	return _prepared_stage.duplicate_definition()


func get_prepared_area() -> StageAreaDefinition:
	if _prepared_area == null:
		return null
	return _prepared_area.duplicate_definition()


## Validate stage via StageCatalog and publish in-memory preparation only.
func prepare_stage(stage_id: StringName) -> Dictionary:
	var empty: Dictionary = {
		"ok": false,
		"changed": false,
		"error": "",
		"area_id": _selected_area_id,
		"stage_id": _selected_stage_id,
	}
	if String(stage_id).is_empty():
		empty["error"] = "stage id is empty"
		return empty

	if stage_id == _selected_stage_id and has_prepared_stage():
		return {
			"ok": true,
			"changed": false,
			"error": "",
			"area_id": _selected_area_id,
			"stage_id": _selected_stage_id,
		}

	var found: Dictionary = StageCatalog.find_stage(stage_id)
	if not bool(found.get("ok", false)):
		empty["error"] = str(found.get("error", "stage not found"))
		return empty

	var stage: StageDefinition = found["stage"] as StageDefinition
	var area: StageAreaDefinition = found["area"] as StageAreaDefinition
	if stage == null or area == null:
		empty["error"] = "stage lookup incomplete"
		return empty

	_selected_stage_id = stage.get_id()
	_selected_area_id = area.get_id()
	_prepared_stage = stage.duplicate_definition()
	_prepared_area = area.duplicate_definition()
	prepared_stage_changed.emit(_selected_area_id, _selected_stage_id)
	return {
		"ok": true,
		"changed": true,
		"error": "",
		"area_id": _selected_area_id,
		"stage_id": _selected_stage_id,
	}


func clear_prepared_stage() -> Dictionary:
	if not has_prepared_stage():
		return {
			"ok": true,
			"changed": false,
			"error": "",
			"area_id": &"",
			"stage_id": &"",
		}
	_selected_area_id = &""
	_selected_stage_id = &""
	_prepared_stage = null
	_prepared_area = null
	prepared_stage_changed.emit(&"", &"")
	return {
		"ok": true,
		"changed": true,
		"error": "",
		"area_id": &"",
		"stage_id": &"",
	}
