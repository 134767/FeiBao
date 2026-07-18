## Pure JSON codec for PlayerProfile (no FileAccess, autoload, or UI).
## Supports strict schema 1 (legacy) and schema 2 (current) with pure in-memory migration.
class_name PlayerProfileCodec
extends RefCounted

const CURRENT_SCHEMA_VERSION: int = 2
const LEGACY_SCHEMA_VERSION: int = 1
const EXPECTED_PROFILE_KIND: String = "local_player"
const _ID_PATTERN: String = "^[a-z0-9_]+$"

const _SCHEMA_1_KEYS: Array[String] = [
	"schema_version",
	"profile_kind",
	"player_name",
	"owned_character_ids",
	"selected_character_id",
	"revision",
]

const _SCHEMA_2_KEYS: Array[String] = [
	"schema_version",
	"profile_kind",
	"player_name",
	"owned_character_ids",
	"selected_character_id",
	"active_party_character_ids",
	"revision",
]


static func parse_json_text(text: String) -> Dictionary:
	if text.is_empty():
		return _fail("profile text is empty")
	var json := JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		return _fail("invalid JSON: %s" % json.get_error_message())
	var root: Variant = json.data
	if typeof(root) != TYPE_DICTIONARY:
		return _fail("profile root must be a Dictionary")
	return parse_dictionary(root as Dictionary)


static func parse_dictionary(data: Dictionary) -> Dictionary:
	if not data.has("schema_version"):
		return _fail("missing field 'schema_version'")
	var schema_res: Dictionary = _parse_exact_integer(data["schema_version"], "schema_version")
	if not bool(schema_res.get("ok", false)):
		return _fail(str(schema_res.get("error", "schema_version must be an exact integer")))
	var schema_version: int = int(schema_res["value"])

	if schema_version == LEGACY_SCHEMA_VERSION:
		return _parse_schema_1(data)
	if schema_version == CURRENT_SCHEMA_VERSION:
		return _parse_schema_2(data)
	return _fail("schema_version must be %d or %d" % [LEGACY_SCHEMA_VERSION, CURRENT_SCHEMA_VERSION])


static func _parse_schema_1(data: Dictionary) -> Dictionary:
	var key_check: Dictionary = _validate_keys(data, _SCHEMA_1_KEYS)
	if not bool(key_check.get("ok", false)):
		return _fail(str(key_check.get("error", "invalid schema 1 keys")))

	var base: Dictionary = _parse_common_fields(data)
	if not bool(base.get("ok", false)):
		return _fail(str(base.get("error", "invalid schema 1 fields")))

	var owned: Array[StringName] = base["owned"] as Array[StringName]
	var selected: StringName = base["selected"] as StringName
	var player_name: String = str(base["player_name"])
	var revision: int = int(base["revision"])

	# Migrate pure data → schema 2 in memory. Revision unchanged. Party = [selected].
	var party: Array[StringName] = [selected]
	var profile := PlayerProfile.new(
		player_name,
		owned,
		selected,
		revision,
		PlayerProfile.SCHEMA_VERSION,
		EXPECTED_PROFILE_KIND,
		party
	)
	return {
		"ok": true,
		"profile": profile,
		"error": "",
		"source_schema_version": LEGACY_SCHEMA_VERSION,
		"migration_required": true,
	}


static func _parse_schema_2(data: Dictionary) -> Dictionary:
	var key_check: Dictionary = _validate_keys(data, _SCHEMA_2_KEYS)
	if not bool(key_check.get("ok", false)):
		return _fail(str(key_check.get("error", "invalid schema 2 keys")))

	var base: Dictionary = _parse_common_fields(data)
	if not bool(base.get("ok", false)):
		return _fail(str(base.get("error", "invalid schema 2 fields")))

	var owned: Array[StringName] = base["owned"] as Array[StringName]
	var owned_seen: Dictionary = base["owned_seen"] as Dictionary
	var selected: StringName = base["selected"] as StringName
	var player_name: String = str(base["player_name"])
	var revision: int = int(base["revision"])

	if typeof(data["active_party_character_ids"]) != TYPE_ARRAY:
		return _fail("active_party_character_ids must be Array")
	var party_raw: Array = data["active_party_character_ids"] as Array
	if party_raw.is_empty():
		return _fail("active_party_character_ids must be non-empty")
	if party_raw.size() > PlayerProfile.PARTY_MAX_SIZE:
		return _fail("active_party_character_ids exceeds max size")

	var party: Array[StringName] = []
	var party_seen: Dictionary = {}
	var id_regex := RegEx.new()
	id_regex.compile(_ID_PATTERN)
	for i in party_raw.size():
		var item: Variant = party_raw[i]
		if typeof(item) != TYPE_STRING:
			return _fail("active_party_character_ids[%d] must be String" % i)
		var id_str: String = str(item)
		if id_str.is_empty():
			return _fail("active_party_character_ids[%d] must be non-empty" % i)
		if id_regex.search(id_str) == null:
			return _fail("active_party_character_ids[%d] has invalid syntax" % i)
		if party_seen.has(id_str):
			return _fail("duplicate active party character id: %s" % id_str)
		if not owned_seen.has(id_str):
			return _fail("active party member must be in owned_character_ids: %s" % id_str)
		party_seen[id_str] = true
		party.append(StringName(id_str))

	# selected may be outside party (representative ≠ leader).
	var profile := PlayerProfile.new(
		player_name,
		owned,
		selected,
		revision,
		PlayerProfile.SCHEMA_VERSION,
		EXPECTED_PROFILE_KIND,
		party
	)
	return {
		"ok": true,
		"profile": profile,
		"error": "",
		"source_schema_version": CURRENT_SCHEMA_VERSION,
		"migration_required": false,
	}


static func _parse_common_fields(data: Dictionary) -> Dictionary:
	if typeof(data["profile_kind"]) != TYPE_STRING:
		return {"ok": false, "error": "profile_kind must be String"}
	if str(data["profile_kind"]) != EXPECTED_PROFILE_KIND:
		return {"ok": false, "error": "profile_kind must be local_player"}

	if typeof(data["player_name"]) != TYPE_STRING:
		return {"ok": false, "error": "player_name must be String"}
	var player_name: String = str(data["player_name"])
	if player_name != player_name.strip_edges():
		return {"ok": false, "error": "player_name must already be trimmed"}
	if player_name.length() > PlayerProfile.PLAYER_NAME_MAX_LENGTH:
		return {"ok": false, "error": "player_name exceeds max length"}

	if typeof(data["owned_character_ids"]) != TYPE_ARRAY:
		return {"ok": false, "error": "owned_character_ids must be Array"}
	var owned_raw: Array = data["owned_character_ids"] as Array
	if owned_raw.is_empty():
		return {"ok": false, "error": "owned_character_ids must be non-empty"}
	var owned: Array[StringName] = []
	var seen: Dictionary = {}
	var id_regex := RegEx.new()
	id_regex.compile(_ID_PATTERN)
	for i in owned_raw.size():
		var item: Variant = owned_raw[i]
		if typeof(item) != TYPE_STRING:
			return {"ok": false, "error": "owned_character_ids[%d] must be String" % i}
		var id_str: String = str(item)
		if id_str.is_empty():
			return {"ok": false, "error": "owned_character_ids[%d] must be non-empty" % i}
		if id_regex.search(id_str) == null:
			return {"ok": false, "error": "owned_character_ids[%d] has invalid syntax" % i}
		if seen.has(id_str):
			return {"ok": false, "error": "duplicate owned character id: %s" % id_str}
		seen[id_str] = true
		owned.append(StringName(id_str))

	if typeof(data["selected_character_id"]) != TYPE_STRING:
		return {"ok": false, "error": "selected_character_id must be String"}
	var selected_str: String = str(data["selected_character_id"])
	if selected_str.is_empty():
		return {"ok": false, "error": "selected_character_id must be non-empty"}
	if id_regex.search(selected_str) == null:
		return {"ok": false, "error": "selected_character_id has invalid syntax"}
	if not seen.has(selected_str):
		return {"ok": false, "error": "selected_character_id must be in owned_character_ids"}
	var selected: StringName = StringName(selected_str)

	var rev_res: Dictionary = _parse_exact_integer(data["revision"], "revision")
	if not bool(rev_res.get("ok", false)):
		return {"ok": false, "error": str(rev_res.get("error", "revision must be an exact integer"))}
	var revision: int = int(rev_res["value"])
	if revision < 0:
		return {"ok": false, "error": "revision must be non-negative"}

	return {
		"ok": true,
		"player_name": player_name,
		"owned": owned,
		"owned_seen": seen,
		"selected": selected,
		"revision": revision,
		"error": "",
	}


static func _validate_keys(data: Dictionary, allowed: Array[String]) -> Dictionary:
	for key in data.keys():
		var key_str: String = str(key)
		if key_str not in allowed:
			return {"ok": false, "error": "unexpected field '%s' (schema migration required)" % key_str}
	for required in allowed:
		if not data.has(required):
			return {"ok": false, "error": "missing field '%s'" % required}
	return {"ok": true, "error": ""}


static func encode_profile(profile: PlayerProfile) -> Dictionary:
	if profile == null:
		return {"ok": false, "text": "", "error": "profile is null", "schema_version": -1}
	var dict: Dictionary = profile.to_dictionary()
	# Always emit schema 2 (current). Re-validate through schema 2 path.
	dict["schema_version"] = CURRENT_SCHEMA_VERSION
	var check: Dictionary = parse_dictionary(dict)
	if not bool(check.get("ok", false)):
		return {
			"ok": false,
			"text": "",
			"error": "encode validation failed: %s" % str(check.get("error", "")),
			"schema_version": -1,
		}
	var text: String = JSON.stringify(dict, "\t")
	if text.is_empty():
		return {"ok": false, "text": "", "error": "JSON encode failed", "schema_version": -1}
	if not text.ends_with("\n"):
		text += "\n"
	return {
		"ok": true,
		"text": text,
		"error": "",
		"schema_version": CURRENT_SCHEMA_VERSION,
	}


static func _parse_exact_integer(value: Variant, field_name: String) -> Dictionary:
	var value_type: int = typeof(value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return {
			"ok": false,
			"value": 0,
			"error": "%s must be an exact integer" % field_name,
		}
	var as_float: float = float(value)
	if not is_finite(as_float):
		return {
			"ok": false,
			"value": 0,
			"error": "%s must be an exact integer" % field_name,
		}
	if as_float != floor(as_float):
		return {
			"ok": false,
			"value": 0,
			"error": "%s must be an exact integer" % field_name,
		}
	return {
		"ok": true,
		"value": int(as_float),
		"error": "",
	}


static func _fail(message: String) -> Dictionary:
	return {
		"ok": false,
		"profile": null,
		"error": message,
		"source_schema_version": -1,
		"migration_required": false,
	}
