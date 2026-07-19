## Immutable enemy definition for development encounters (no AI / skills).
class_name EnemyDefinition
extends RefCounted

var _id: StringName = &""
var _display_name: String = ""
var _summary: String = ""
var _max_hp: int = 1
var _attack: int = 0
var _defense: int = 0
var _sort_order: int = 0
var _is_development_seed: bool = true


func _init(
	p_id: StringName = &"",
	p_display_name: String = "",
	p_summary: String = "",
	p_max_hp: int = 1,
	p_attack: int = 0,
	p_defense: int = 0,
	p_sort_order: int = 0,
	p_is_development_seed: bool = true
) -> void:
	_id = p_id
	_display_name = p_display_name
	_summary = p_summary
	_max_hp = p_max_hp
	_attack = p_attack
	_defense = p_defense
	_sort_order = p_sort_order
	_is_development_seed = p_is_development_seed


func get_id() -> StringName:
	return _id


func get_display_name() -> String:
	return _display_name


func get_summary() -> String:
	return _summary


func get_max_hp() -> int:
	return _max_hp


func get_attack() -> int:
	return _attack


func get_defense() -> int:
	return _defense


func get_sort_order() -> int:
	return _sort_order


func is_development_seed() -> bool:
	return _is_development_seed


func get_placeholder_glyph() -> String:
	var n: String = _display_name.strip_edges()
	if n.is_empty():
		return "?"
	return n.substr(0, 1)


func duplicate_definition() -> EnemyDefinition:
	return EnemyDefinition.new(
		_id, _display_name, _summary, _max_hp, _attack, _defense, _sort_order, _is_development_seed
	)
