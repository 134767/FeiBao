## Immutable-ish stage area definition with ordered stage list (defensive copies).
class_name StageAreaDefinition
extends RefCounted

var _id: StringName = &""
var _display_name: String = ""
var _summary: String = ""
var _story_intro: String = ""
var _sort_order: int = 0
var _is_development_seed: bool = true
var _stages: Array[StageDefinition] = []


func _init(
	p_id: StringName = &"",
	p_display_name: String = "",
	p_summary: String = "",
	p_story_intro: String = "",
	p_sort_order: int = 0,
	p_is_development_seed: bool = true,
	p_stages: Array[StageDefinition] = []
) -> void:
	_id = p_id
	_display_name = p_display_name
	_summary = p_summary
	_story_intro = p_story_intro
	_sort_order = p_sort_order
	_is_development_seed = p_is_development_seed
	_stages = []
	for s in p_stages:
		if s is StageDefinition:
			_stages.append((s as StageDefinition).duplicate_definition())


func get_id() -> StringName:
	return _id


func get_display_name() -> String:
	return _display_name


func get_summary() -> String:
	return _summary


func get_story_intro() -> String:
	return _story_intro


func get_sort_order() -> int:
	return _sort_order


func is_development_seed() -> bool:
	return _is_development_seed


func get_stages() -> Array[StageDefinition]:
	var out: Array[StageDefinition] = []
	for s in _stages:
		out.append(s.duplicate_definition())
	return out


func get_stage_count() -> int:
	return _stages.size()


func find_stage(stage_id: StringName) -> StageDefinition:
	for s in _stages:
		if s.get_id() == stage_id:
			return s.duplicate_definition()
	return null


func duplicate_definition() -> StageAreaDefinition:
	return StageAreaDefinition.new(
		_id,
		_display_name,
		_summary,
		_story_intro,
		_sort_order,
		_is_development_seed,
		get_stages()
	)
