## Immutable stage→enemy encounter blueprint (catalog only).
class_name StageEncounterDefinition
extends RefCounted

var _stage_id: StringName = &""
var _enemy_ids: Array[StringName] = []
var _is_development_seed: bool = true


func _init(
	p_stage_id: StringName = &"",
	p_enemy_ids: Array[StringName] = [],
	p_is_development_seed: bool = true
) -> void:
	_stage_id = p_stage_id
	_enemy_ids = p_enemy_ids.duplicate()
	_is_development_seed = p_is_development_seed


func get_stage_id() -> StringName:
	return _stage_id


func get_enemy_ids() -> Array[StringName]:
	return _enemy_ids.duplicate()


func is_development_seed() -> bool:
	return _is_development_seed


func duplicate_definition() -> StageEncounterDefinition:
	return StageEncounterDefinition.new(_stage_id, _enemy_ids, _is_development_seed)
