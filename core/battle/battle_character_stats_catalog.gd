## Read-only player combat stat blueprints (pure data — no SceneTree / PlayerData).
class_name BattleCharacterStatsCatalog
extends RefCounted

const DEFAULT_PATH: String = "res://data/battle_character_stats.json"
const EXPECTED_SCHEMA_VERSION: int = 1
const EXPECTED_CATALOG_KIND: String = "development_seed"
const _ID_PATTERN: String = "^[a-z0-9_]+$"
const _ENTRY_KEYS: Array[String] = ["character_id", "affinity", "max_hp", "attack", "defense"]
const MAX_HP_MAX: int = 1000000
const ATK_DEF_MAX: int = 100000

## Test-only path override. Empty = production default. Not persisted.
static var _path_override_for_tests: String = ""


static func set_default_path_override_for_tests(path: String) -> void:
	if path.is_empty():
		_path_override_for_tests = ""
		return
	if not _is_allowed_test_path(path):
		push_error("BattleCharacterStatsCatalog: override path not allowed: %s" % path)
		return
	_path_override_for_tests = path


static func clear_default_path_override_for_tests() -> void:
	_path_override_for_tests = ""


static func _is_allowed_test_path(path: String) -> bool:
	return path.begins_with("user://feibao_tests/") or path.begins_with("res://tests/fixtures/")


static func load_default() -> Dictionary:
	var path: String = DEFAULT_PATH
	if not _path_override_for_tests.is_empty():
		path = _path_override_for_tests
	return load_from_path(path)


static func load_from_path(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return _fail("catalog file not found: %s" % path)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("cannot open catalog file: %s" % path)
	var text: String = file.get_as_text()
	file.close()
	return parse_json_text(text)


static func parse_json_text(text: String) -> Dictionary:
	if text.is_empty():
		return _fail("catalog text is empty")
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail("invalid JSON: %s" % json.get_error_message())
	if typeof(json.data) != TYPE_DICTIONARY:
		return _fail("catalog root must be a Dictionary")
	return _validate_and_build(json.data as Dictionary)


static func find_stats(character_id: StringName) -> Dictionary:
	var loaded: Dictionary = load_default()
	if not bool(loaded.get("ok", false)):
		return {"ok": false, "stats": {}, "error": str(loaded.get("error", ""))}
	for item in loaded.get("stats", []) as Array:
		if item is Dictionary and StringName(str((item as Dictionary).get("character_id", ""))) == character_id:
			return {"ok": true, "stats": (item as Dictionary).duplicate(true), "error": ""}
	return {"ok": false, "stats": {}, "error": "battle stats not found"}


static func _validate_and_build(root: Dictionary) -> Dictionary:
	var root_keys: Array[String] = ["schema_version", "catalog_kind", "stats"]
	for key in root.keys():
		if str(key) not in root_keys:
			return _fail("unexpected field '%s'" % str(key))
	for required in root_keys:
		if not root.has(required):
			return _fail("missing field '%s'" % required)

	var schema_res: Dictionary = _parse_whole_json_number(root["schema_version"], "schema_version")
	if not bool(schema_res.get("ok", false)):
		return _fail(str(schema_res.get("error", "")))
	if int(schema_res["value"]) != EXPECTED_SCHEMA_VERSION:
		return _fail("schema_version must be %d" % EXPECTED_SCHEMA_VERSION)
	if typeof(root["catalog_kind"]) != TYPE_STRING or str(root["catalog_kind"]) != EXPECTED_CATALOG_KIND:
		return _fail("catalog_kind must be development_seed")
	if typeof(root["stats"]) != TYPE_ARRAY:
		return _fail("stats must be Array")
	var raw: Array = root["stats"] as Array
	if raw.is_empty():
		return _fail("stats must be non-empty")

	var char_cat: Dictionary = CharacterCatalog.load_default()
	if not bool(char_cat.get("ok", false)):
		return _fail("CharacterCatalog unavailable for validation")
	var known_chars: Dictionary = {}
	for c in char_cat.get("characters", []):
		if c is CharacterDefinition:
			known_chars[(c as CharacterDefinition).get_id()] = true

	var seen: Dictionary = {}
	var out: Array = []
	for i in raw.size():
		var item: Variant = raw[i]
		if typeof(item) != TYPE_DICTIONARY:
			return _fail("stats[%d] must be Dictionary" % i)
		var one: Dictionary = _parse_entry(item as Dictionary, i, known_chars, seen)
		if not bool(one.get("ok", false)):
			return _fail(str(one.get("error", "")))
		out.append((one["stats"] as Dictionary).duplicate(true))
	return {"ok": true, "stats": out, "error": ""}


static func _parse_entry(raw: Dictionary, index: int, known_chars: Dictionary, seen: Dictionary) -> Dictionary:
	for key in raw.keys():
		if str(key) not in _ENTRY_KEYS:
			return {"ok": false, "error": "stats[%d] unexpected field '%s'" % [index, str(key)]}
	for required in _ENTRY_KEYS:
		if not raw.has(required):
			return {"ok": false, "error": "stats[%d] missing field '%s'" % [index, required]}

	if typeof(raw["character_id"]) != TYPE_STRING:
		return {"ok": false, "error": "stats[%d].character_id must be String" % index}
	var cid: String = str(raw["character_id"])
	if cid.is_empty() or not _id_ok(cid):
		return {"ok": false, "error": "stats[%d].character_id invalid" % index}
	var cid_sn := StringName(cid)
	if not known_chars.has(cid_sn):
		return {"ok": false, "error": "stats[%d].character_id not in CharacterCatalog" % index}
	if seen.has(cid):
		return {"ok": false, "error": "duplicate character_id: %s" % cid}
	seen[cid] = true

	if typeof(raw["affinity"]) != TYPE_STRING:
		return {"ok": false, "error": "stats[%d].affinity must be String" % index}
	var aff := StringName(str(raw["affinity"]))
	if not BattleAffinity.is_valid(aff):
		return {"ok": false, "error": "stats[%d].affinity invalid" % index}

	var hp: Dictionary = _parse_whole_json_number(raw["max_hp"], "stats[%d].max_hp" % index)
	if not bool(hp.get("ok", false)):
		return hp
	var hpv: int = int(hp["value"])
	if hpv < 1 or hpv > MAX_HP_MAX:
		return {"ok": false, "error": "stats[%d].max_hp out of bounds" % index}

	var atk: Dictionary = _parse_whole_json_number(raw["attack"], "stats[%d].attack" % index)
	if not bool(atk.get("ok", false)):
		return atk
	var atkv: int = int(atk["value"])
	if atkv < 0 or atkv > ATK_DEF_MAX:
		return {"ok": false, "error": "stats[%d].attack out of bounds" % index}

	var defense: Dictionary = _parse_whole_json_number(raw["defense"], "stats[%d].defense" % index)
	if not bool(defense.get("ok", false)):
		return defense
	var defv: int = int(defense["value"])
	if defv < 0 or defv > ATK_DEF_MAX:
		return {"ok": false, "error": "stats[%d].defense out of bounds" % index}

	return {
		"ok": true,
		"stats": {
			"character_id": cid_sn,
			"affinity": aff,
			"max_hp": hpv,
			"attack": atkv,
			"defense": defv,
		},
		"error": "",
	}


static func _id_ok(id_str: String) -> bool:
	var regex := RegEx.new()
	regex.compile(_ID_PATTERN)
	return regex.search(id_str) != null


## WHOLE_JSON_NUMBER: finite whole number (JSON 10 / 10.0 ok); normalize to int.
## Reject fractional, bool, String, null, Array, Object, Callable.
static func _parse_whole_json_number(value: Variant, field_name: String) -> Dictionary:
	var t: int = typeof(value)
	if t == TYPE_BOOL or t == TYPE_STRING or value == null:
		return {"ok": false, "error": "%s must be whole JSON number" % field_name, "value": 0}
	if t == TYPE_ARRAY or t == TYPE_DICTIONARY or value is Object or value is Callable:
		return {"ok": false, "error": "%s must be whole JSON number" % field_name, "value": 0}
	if t != TYPE_INT and t != TYPE_FLOAT:
		return {"ok": false, "error": "%s must be whole JSON number" % field_name, "value": 0}
	var f: float = float(value)
	if not is_finite(f) or f != floor(f):
		return {"ok": false, "error": "%s must be whole JSON number" % field_name, "value": 0}
	return {"ok": true, "value": int(f), "error": ""}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "stats": [], "error": message}
