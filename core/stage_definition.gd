## Immutable-ish stage definition (catalog only; no combat / drop / completion fields).
class_name StageDefinition
extends RefCounted

var _id: StringName = &""
var _area_id: StringName = &""
var _display_name: String = ""
var _summary: String = ""
var _stage_number: int = 1
var _sort_order: int = 0
var _is_development_seed: bool = true


func _init(
	p_id: StringName = &"",
	p_area_id: StringName = &"",
	p_display_name: String = "",
	p_summary: String = "",
	p_stage_number: int = 1,
	p_sort_order: int = 0,
	p_is_development_seed: bool = true
) -> void:
	_id = p_id
	_area_id = p_area_id
	_display_name = p_display_name
	_summary = p_summary
	_stage_number = p_stage_number
	_sort_order = p_sort_order
	_is_development_seed = p_is_development_seed


func get_id() -> StringName:
	return _id


func get_area_id() -> StringName:
	return _area_id


func get_display_name() -> String:
	return _display_name


func get_summary() -> String:
	return _summary


func get_stage_number() -> int:
	return _stage_number


func get_sort_order() -> int:
	return _sort_order


func is_development_seed() -> bool:
	return _is_development_seed


func get_placeholder_glyph() -> String:
	var n: String = _display_name.strip_edges()
	if n.is_empty():
		return "?"
	return n.substr(0, 1)


func duplicate_definition() -> StageDefinition:
	return StageDefinition.new(
		_id,
		_area_id,
		_display_name,
		_summary,
		_stage_number,
		_sort_order,
		_is_development_seed
	)
