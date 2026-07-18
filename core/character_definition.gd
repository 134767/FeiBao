## Immutable-ish character definition for catalog UI (no combat / ownership fields).
class_name CharacterDefinition
extends RefCounted

var _id: StringName = &""
var _display_name: String = ""
var _species: String = ""
var _summary: String = ""
var _description: String = ""
var _tags: Array[String] = []
var _sort_order: int = 0
var _portrait_path: String = ""
var _is_development_seed: bool = true


func _init(
	p_id: StringName = &"",
	p_display_name: String = "",
	p_species: String = "",
	p_summary: String = "",
	p_description: String = "",
	p_tags: Array[String] = [],
	p_sort_order: int = 0,
	p_portrait_path: String = "",
	p_is_development_seed: bool = true
) -> void:
	_id = p_id
	_display_name = p_display_name
	_species = p_species
	_summary = p_summary
	_description = p_description
	_tags = p_tags.duplicate()
	_sort_order = p_sort_order
	_portrait_path = p_portrait_path
	_is_development_seed = p_is_development_seed


func get_id() -> StringName:
	return _id


func get_display_name() -> String:
	return _display_name


func get_species() -> String:
	return _species


func get_summary() -> String:
	return _summary


func get_description() -> String:
	return _description


## Returns a copy so callers cannot mutate catalog source tags.
func get_tags() -> Array[String]:
	return _tags.duplicate()


func get_sort_order() -> int:
	return _sort_order


func get_portrait_path() -> String:
	return _portrait_path


func is_development_seed() -> bool:
	return _is_development_seed


func has_portrait() -> bool:
	return not _portrait_path.is_empty()


## First grapheme-ish unit for placeholder badge (UTF-safe substring).
func get_placeholder_glyph() -> String:
	if _display_name.is_empty():
		return "?"
	return _display_name.substr(0, 1)
