## Immutable character combat stat blueprint (catalog only; no runtime HP).
class_name CharacterCombatStatsDefinition
extends RefCounted

var _character_id: StringName = &""
var _max_hp: int = 1
var _attack: int = 0
var _defense: int = 0
var _is_development_seed: bool = true


func _init(
	p_character_id: StringName = &"",
	p_max_hp: int = 1,
	p_attack: int = 0,
	p_defense: int = 0,
	p_is_development_seed: bool = true
) -> void:
	_character_id = p_character_id
	_max_hp = p_max_hp
	_attack = p_attack
	_defense = p_defense
	_is_development_seed = p_is_development_seed


func get_character_id() -> StringName:
	return _character_id


func get_max_hp() -> int:
	return _max_hp


func get_attack() -> int:
	return _attack


func get_defense() -> int:
	return _defense


func is_development_seed() -> bool:
	return _is_development_seed


func duplicate_definition() -> CharacterCombatStatsDefinition:
	return CharacterCombatStatsDefinition.new(
		_character_id, _max_hp, _attack, _defense, _is_development_seed
	)
