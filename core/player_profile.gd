## Immutable-ish local player profile snapshot (session file contract, not UI).
## Owns character id references only — never CharacterDefinition bodies.
class_name PlayerProfile
extends RefCounted

const SCHEMA_VERSION: int = 1
const PROFILE_KIND: String = "local_player"
const DEFAULT_CHARACTER_ID: StringName = &"feibao_dev"
const PLAYER_NAME_MAX_LENGTH: int = 12
const _ID_PATTERN: String = "^[a-z0-9_]+$"

var _schema_version: int = SCHEMA_VERSION
var _profile_kind: String = PROFILE_KIND
var _player_name: String = ""
var _owned_character_ids: Array[StringName] = []
var _selected_character_id: StringName = DEFAULT_CHARACTER_ID
var _revision: int = 0


func _init(
	p_player_name: String = "",
	p_owned: Array[StringName] = [],
	p_selected: StringName = DEFAULT_CHARACTER_ID,
	p_revision: int = 0,
	p_schema_version: int = SCHEMA_VERSION,
	p_profile_kind: String = PROFILE_KIND
) -> void:
	_schema_version = p_schema_version
	_profile_kind = p_profile_kind
	_player_name = p_player_name
	if p_owned.is_empty():
		_owned_character_ids = [DEFAULT_CHARACTER_ID]
	else:
		_owned_character_ids = p_owned.duplicate()
	_selected_character_id = p_selected
	_revision = maxi(0, p_revision)


static func create_default() -> PlayerProfile:
	return PlayerProfile.new("", [DEFAULT_CHARACTER_ID], DEFAULT_CHARACTER_ID, 0)


func duplicate_profile() -> PlayerProfile:
	return PlayerProfile.new(
		_player_name,
		_owned_character_ids.duplicate(),
		_selected_character_id,
		_revision,
		_schema_version,
		_profile_kind
	)


func get_schema_version() -> int:
	return _schema_version


func get_profile_kind() -> String:
	return _profile_kind


func get_player_name() -> String:
	return _player_name


func get_owned_character_ids() -> Array[StringName]:
	return _owned_character_ids.duplicate()


func get_selected_character_id() -> StringName:
	return _selected_character_id


func get_revision() -> int:
	return _revision


func owns_character(character_id: StringName) -> bool:
	if String(character_id).is_empty():
		return false
	for id in _owned_character_ids:
		if id == character_id:
			return true
	return false


## Returns a new snapshot. Actual name change increments revision; same name does not.
func with_player_name(value: String) -> PlayerProfile:
	var trimmed: String = value.strip_edges()
	if trimmed == _player_name:
		return duplicate_profile()
	var next_revision: int = _revision + 1
	return PlayerProfile.new(
		trimmed,
		_owned_character_ids.duplicate(),
		_selected_character_id,
		next_revision,
		_schema_version,
		_profile_kind
	)


## Immutable grant. Catalog existence is validated by PlayerData, not here.
## Returns { ok, changed, profile, error }.
func with_character_granted(character_id: StringName) -> Dictionary:
	var id_check: Dictionary = _validate_character_id(character_id)
	if not bool(id_check.get("ok", false)):
		return _mutation_fail(str(id_check.get("error", "invalid character id")))
	if owns_character(character_id):
		return {
			"ok": true,
			"changed": false,
			"profile": duplicate_profile(),
			"error": "",
		}
	var next_owned: Array[StringName] = _owned_character_ids.duplicate()
	next_owned.append(character_id)
	var next: PlayerProfile = PlayerProfile.new(
		_player_name,
		next_owned,
		_selected_character_id,
		_revision + 1,
		_schema_version,
		_profile_kind
	)
	return {
		"ok": true,
		"changed": true,
		"profile": next,
		"error": "",
	}


## Immutable select representative. character_id must already be owned.
## Returns { ok, changed, profile, error }.
func with_selected_character(character_id: StringName) -> Dictionary:
	var id_check: Dictionary = _validate_character_id(character_id)
	if not bool(id_check.get("ok", false)):
		return _mutation_fail(str(id_check.get("error", "invalid character id")))
	if not owns_character(character_id):
		return _mutation_fail("character is not owned")
	if _selected_character_id == character_id:
		return {
			"ok": true,
			"changed": false,
			"profile": duplicate_profile(),
			"error": "",
		}
	var next: PlayerProfile = PlayerProfile.new(
		_player_name,
		_owned_character_ids.duplicate(),
		character_id,
		_revision + 1,
		_schema_version,
		_profile_kind
	)
	return {
		"ok": true,
		"changed": true,
		"profile": next,
		"error": "",
	}


func _validate_character_id(character_id: StringName) -> Dictionary:
	var id_str: String = String(character_id)
	if id_str.is_empty():
		return {"ok": false, "error": "character id is empty"}
	var regex := RegEx.new()
	regex.compile(_ID_PATTERN)
	if regex.search(id_str) == null:
		return {"ok": false, "error": "character id has invalid syntax"}
	return {"ok": true, "error": ""}


func _mutation_fail(error: String) -> Dictionary:
	return {
		"ok": false,
		"changed": false,
		"profile": duplicate_profile(),
		"error": error,
	}


func to_dictionary() -> Dictionary:
	var owned: Array = []
	for id in _owned_character_ids:
		owned.append(str(id))
	return {
		"schema_version": _schema_version,
		"profile_kind": _profile_kind,
		"player_name": _player_name,
		"owned_character_ids": owned,
		"selected_character_id": str(_selected_character_id),
		"revision": _revision,
	}
