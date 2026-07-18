## Pure JSON codec for PlayerProfile (no FileAccess, autoload, or UI).
class_name PlayerProfileCodec
extends RefCounted

const EXPECTED_SCHEMA_VERSION: int = 1
const EXPECTED_PROFILE_KIND: String = "local_player"
const _ID_PATTERN: String = "^[a-z0-9_]+$"
const _ALLOWED_KEYS: Array[String] = [
	"schema_version",
	"profile_kind",
	"player_name",
	"owned_character_ids",
	"selected_character_id",
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
	for key in data.keys():
		var key_str: String = str(key)
		if key_str not in _ALLOWED_KEYS:
			return _fail("unexpected field '%s' (schema migration required)" % key_str)

	for required in _ALLOWED_KEYS:
		if not data.has(required):
			return _fail("missing field '%s'" % required)

	var schema_res: Dictionary = _parse_exact_integer(data["schema_version"], "schema_version")
	if not bool(schema_res.get("ok", false)):
		return _fail(str(schema_res.get("error", "schema_version must be an exact integer")))
	var schema_version: int = int(schema_res["value"])
	if schema_version != EXPECTED_SCHEMA_VERSION:
		return _fail("schema_version must be %d" % EXPECTED_SCHEMA_VERSION)

	if typeof(data["profile_kind"]) != TYPE_STRING:
		return _fail("profile_kind must be String")
	if str(data["profile_kind"]) != EXPECTED_PROFILE_KIND:
		return _fail("profile_kind must be local_player")

	if typeof(data["player_name"]) != TYPE_STRING:
		return _fail("player_name must be String")
	var player_name: String = str(data["player_name"])
	if player_name != player_name.strip_edges():
		return _fail("player_name must already be trimmed")
	if player_name.length() > PlayerProfile.PLAYER_NAME_MAX_LENGTH:
		return _fail("player_name exceeds max length")

	if typeof(data["owned_character_ids"]) != TYPE_ARRAY:
		return _fail("owned_character_ids must be Array")
	var owned_raw: Array = data["owned_character_ids"] as Array
	if owned_raw.is_empty():
		return _fail("owned_character_ids must be non-empty")
	var owned: Array[StringName] = []
	var seen: Dictionary = {}
	var id_regex := RegEx.new()
	id_regex.compile(_ID_PATTERN)
	for i in owned_raw.size():
		var item: Variant = owned_raw[i]
		if typeof(item) != TYPE_STRING:
			return _fail("owned_character_ids[%d] must be String" % i)
		var id_str: String = str(item)
		if id_str.is_empty():
			return _fail("owned_character_ids[%d] must be non-empty" % i)
		if id_regex.search(id_str) == null:
			return _fail("owned_character_ids[%d] has invalid syntax" % i)
		if seen.has(id_str):
			return _fail("duplicate owned character id: %s" % id_str)
		seen[id_str] = true
		owned.append(StringName(id_str))

	if typeof(data["selected_character_id"]) != TYPE_STRING:
		return _fail("selected_character_id must be String")
	var selected_str: String = str(data["selected_character_id"])
	if selected_str.is_empty():
		return _fail("selected_character_id must be non-empty")
	if id_regex.search(selected_str) == null:
		return _fail("selected_character_id has invalid syntax")
	var selected: StringName = StringName(selected_str)
	if not seen.has(selected_str):
		return _fail("selected_character_id must be in owned_character_ids")

	var rev_res: Dictionary = _parse_exact_integer(data["revision"], "revision")
	if not bool(rev_res.get("ok", false)):
		return _fail(str(rev_res.get("error", "revision must be an exact integer")))
	var revision: int = int(rev_res["value"])
	if revision < 0:
		return _fail("revision must be non-negative")

	var profile := PlayerProfile.new(
		player_name,
		owned,
		selected,
		revision,
		schema_version,
		EXPECTED_PROFILE_KIND
	)
	return {
		"ok": true,
		"profile": profile,
		"error": "",
	}


static func encode_profile(profile: PlayerProfile) -> Dictionary:
	if profile == null:
		return {"ok": false, "text": "", "error": "profile is null"}
	var dict: Dictionary = profile.to_dictionary()
	# Re-validate encode payload through parse path for safety.
	var check: Dictionary = parse_dictionary(dict)
	if not bool(check.get("ok", false)):
		return {
			"ok": false,
			"text": "",
			"error": "encode validation failed: %s" % str(check.get("error", "")),
		}
	var text: String = JSON.stringify(dict, "\t")
	if text.is_empty():
		return {"ok": false, "text": "", "error": "JSON encode failed"}
	if not text.ends_with("\n"):
		text += "\n"
	return {
		"ok": true,
		"text": text,
		"error": "",
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
	}
