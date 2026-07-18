## Immutable-ish local player profile snapshot (session file contract, not UI).
## Owns character id references only — never CharacterDefinition bodies.
## Schema 2 adds active_party_character_ids (1–3 owned IDs). Representative ≠ leader.
class_name PlayerProfile
extends RefCounted

const SCHEMA_VERSION: int = 2
const PROFILE_KIND: String = "local_player"
const DEFAULT_CHARACTER_ID: StringName = &"feibao_dev"
const PLAYER_NAME_MAX_LENGTH: int = 12
const PARTY_MIN_SIZE: int = 1
const PARTY_MAX_SIZE: int = 3
const _ID_PATTERN: String = "^[a-z0-9_]+$"

var _schema_version: int = SCHEMA_VERSION
var _profile_kind: String = PROFILE_KIND
var _player_name: String = ""
var _owned_character_ids: Array[StringName] = []
var _selected_character_id: StringName = DEFAULT_CHARACTER_ID
var _active_party_character_ids: Array[StringName] = []
var _revision: int = 0


func _init(
	p_player_name: String = "",
	p_owned: Array[StringName] = [],
	p_selected: StringName = DEFAULT_CHARACTER_ID,
	p_revision: int = 0,
	p_schema_version: int = SCHEMA_VERSION,
	p_profile_kind: String = PROFILE_KIND,
	p_party: Array[StringName] = []
) -> void:
	_schema_version = p_schema_version
	_profile_kind = p_profile_kind
	_player_name = p_player_name
	if p_owned.is_empty():
		_owned_character_ids = [DEFAULT_CHARACTER_ID]
	else:
		_owned_character_ids = p_owned.duplicate()
	_selected_character_id = p_selected
	if p_party.is_empty():
		_active_party_character_ids = [DEFAULT_CHARACTER_ID]
	else:
		_active_party_character_ids = p_party.duplicate()
	_revision = maxi(0, p_revision)


static func create_default() -> PlayerProfile:
	return PlayerProfile.new(
		"",
		[DEFAULT_CHARACTER_ID],
		DEFAULT_CHARACTER_ID,
		0,
		SCHEMA_VERSION,
		PROFILE_KIND,
		[DEFAULT_CHARACTER_ID]
	)


func duplicate_profile() -> PlayerProfile:
	return PlayerProfile.new(
		_player_name,
		_owned_character_ids.duplicate(),
		_selected_character_id,
		_revision,
		_schema_version,
		_profile_kind,
		_active_party_character_ids.duplicate()
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


func get_active_party_character_ids() -> Array[StringName]:
	return _active_party_character_ids.duplicate()


func get_active_party_size() -> int:
	return _active_party_character_ids.size()


func get_party_leader_character_id() -> StringName:
	if _active_party_character_ids.is_empty():
		return &""
	return _active_party_character_ids[0]


func is_character_in_active_party(character_id: StringName) -> bool:
	if String(character_id).is_empty():
		return false
	for id in _active_party_character_ids:
		if id == character_id:
			return true
	return false


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
	return PlayerProfile.new(
		trimmed,
		_owned_character_ids.duplicate(),
		_selected_character_id,
		_revision + 1,
		_schema_version,
		_profile_kind,
		_active_party_character_ids.duplicate()
	)


## Immutable grant. Catalog existence is validated by PlayerData, not here.
## Returns { ok, changed, profile, error }. Does not alter party or selected.
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
		_profile_kind,
		_active_party_character_ids.duplicate()
	)
	return {
		"ok": true,
		"changed": true,
		"profile": next,
		"error": "",
	}


## Immutable select representative. Does not alter active party.
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
		_profile_kind,
		_active_party_character_ids.duplicate()
	)
	return {
		"ok": true,
		"changed": true,
		"profile": next,
		"error": "",
	}


## Append owned character to party tail. Does not change selected_character_id.
func with_party_member_added(character_id: StringName) -> Dictionary:
	var id_check: Dictionary = _validate_character_id(character_id)
	if not bool(id_check.get("ok", false)):
		return _mutation_fail(str(id_check.get("error", "invalid character id")))
	if not owns_character(character_id):
		return _mutation_fail("character is not owned")
	if is_character_in_active_party(character_id):
		return {
			"ok": true,
			"changed": false,
			"profile": duplicate_profile(),
			"error": "",
		}
	if _active_party_character_ids.size() >= PARTY_MAX_SIZE:
		return _mutation_fail("active party is full")
	var next_party: Array[StringName] = _active_party_character_ids.duplicate()
	next_party.append(character_id)
	var next: PlayerProfile = PlayerProfile.new(
		_player_name,
		_owned_character_ids.duplicate(),
		_selected_character_id,
		_revision + 1,
		_schema_version,
		_profile_kind,
		next_party
	)
	return {
		"ok": true,
		"changed": true,
		"profile": next,
		"error": "",
	}


## Remove member from party. Last member cannot be removed. Does not change selected.
func with_party_member_removed(character_id: StringName) -> Dictionary:
	if String(character_id).is_empty():
		return _mutation_fail("character id is empty")
	if not is_character_in_active_party(character_id):
		return {
			"ok": true,
			"changed": false,
			"profile": duplicate_profile(),
			"error": "",
		}
	if _active_party_character_ids.size() <= PARTY_MIN_SIZE:
		return _mutation_fail("active party cannot be empty")
	var next_party: Array[StringName] = []
	for id in _active_party_character_ids:
		if id != character_id:
			next_party.append(id)
	var next: PlayerProfile = PlayerProfile.new(
		_player_name,
		_owned_character_ids.duplicate(),
		_selected_character_id,
		_revision + 1,
		_schema_version,
		_profile_kind,
		next_party
	)
	return {
		"ok": true,
		"changed": true,
		"profile": next,
		"error": "",
	}


## Move existing party member to target_index (0-based). Leader is index 0 after move.
func with_party_member_moved(character_id: StringName, target_index: int) -> Dictionary:
	if not is_character_in_active_party(character_id):
		return _mutation_fail("character is not in active party")
	var size: int = _active_party_character_ids.size()
	if target_index < 0 or target_index >= size:
		return _mutation_fail("invalid party target index")
	var current_index: int = -1
	for i in size:
		if _active_party_character_ids[i] == character_id:
			current_index = i
			break
	if current_index == target_index:
		return {
			"ok": true,
			"changed": false,
			"profile": duplicate_profile(),
			"error": "",
		}
	var next_party: Array[StringName] = _active_party_character_ids.duplicate()
	next_party.remove_at(current_index)
	next_party.insert(target_index, character_id)
	var next: PlayerProfile = PlayerProfile.new(
		_player_name,
		_owned_character_ids.duplicate(),
		_selected_character_id,
		_revision + 1,
		_schema_version,
		_profile_kind,
		next_party
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
	var party: Array = []
	for id in _active_party_character_ids:
		party.append(str(id))
	return {
		"schema_version": _schema_version,
		"profile_kind": _profile_kind,
		"player_name": _player_name,
		"owned_character_ids": owned,
		"selected_character_id": str(_selected_character_id),
		"active_party_character_ids": party,
		"revision": _revision,
	}
