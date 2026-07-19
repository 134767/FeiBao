## Pure parse/validate loader for character combat stats JSON.
class_name CharacterCombatStatsCatalog
extends RefCounted

const DEFAULT_PATH: String = "res://data/character_combat_stats.json"
const EXPECTED_SCHEMA_VERSION: int = 1
const EXPECTED_CATALOG_KIND: String = "development_seed"
const _ID_PATTERN: String = "^[a-z0-9_]+$"
const _ENTRY_KEYS: Array[String] = [
	"character_id", "max_hp", "attack", "defense", "is_development_seed"
]


static func load_default() -> Dictionary:
	return load_from_path(DEFAULT_PATH)


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
	var err: Error = json.parse(text)
	if err != OK:
		return _fail("invalid JSON: %s" % json.get_error_message())
	var root: Variant = json.data
	if typeof(root) != TYPE_DICTIONARY:
		return _fail("catalog root must be a Dictionary")
	return _validate_and_build(root as Dictionary)


static func find_stats(character_id: StringName) -> Dictionary:
	var loaded: Dictionary = load_default()
	if not bool(loaded.get("ok", false)):
		return {"ok": false, "stats": null, "error": str(loaded.get("error", ""))}
	for item in loaded.get("stats", []):
		if item is CharacterCombatStatsDefinition:
			var s: CharacterCombatStatsDefinition = item as CharacterCombatStatsDefinition
			if s.get_character_id() == character_id:
				return {"ok": true, "stats": s.duplicate_definition(), "error": ""}
	return {"ok": false, "stats": null, "error": "combat stats not found"}


static func _validate_and_build(root: Dictionary) -> Dictionary:
	var root_keys: Array[String] = ["schema_version", "catalog_kind", "stats"]
	for key in root.keys():
		if str(key) not in root_keys:
			return _fail("unexpected field '%s'" % str(key))
	for required in root_keys:
		if not root.has(required):
			return _fail("missing field '%s'" % required)

	var schema_res: Dictionary = _parse_exact_integer(root["schema_version"], "schema_version")
	if not bool(schema_res.get("ok", false)):
		return _fail(str(schema_res.get("error", "schema_version must be an exact integer")))
	if int(schema_res["value"]) != EXPECTED_SCHEMA_VERSION:
		return _fail("schema_version must be %d" % EXPECTED_SCHEMA_VERSION)

	if typeof(root["catalog_kind"]) != TYPE_STRING:
		return _fail("catalog_kind must be String")
	if str(root["catalog_kind"]) != EXPECTED_CATALOG_KIND:
		return _fail("catalog_kind must be development_seed")

	if typeof(root["stats"]) != TYPE_ARRAY:
		return _fail("stats must be Array")
	var raw_list: Array = root["stats"] as Array
	if raw_list.is_empty():
		return _fail("stats must be non-empty")

	var seen: Dictionary = {}
	var parsed: Array[CharacterCombatStatsDefinition] = []
	for i in raw_list.size():
		var item: Variant = raw_list[i]
		if typeof(item) != TYPE_DICTIONARY:
			return _fail("stats[%d] must be Dictionary" % i)
		var one: Dictionary = _parse_entry(item as Dictionary, i)
		if not bool(one.get("ok", false)):
			return _fail(str(one.get("error", "invalid stats entry")))
		var def: CharacterCombatStatsDefinition = one["stats"] as CharacterCombatStatsDefinition
		var key: String = str(def.get_character_id())
		if seen.has(key):
			return _fail("duplicate character_id: %s" % key)
		seen[key] = true
		parsed.append(def)

	var out: Array = []
	for d in parsed:
		out.append(d.duplicate_definition())
	return {"ok": true, "stats": out, "error": ""}


static func _parse_entry(raw: Dictionary, index: int) -> Dictionary:
	for key in raw.keys():
		if str(key) not in _ENTRY_KEYS:
			return {"ok": false, "error": "stats[%d] unexpected field '%s'" % [index, str(key)]}
	for required in _ENTRY_KEYS:
		if not raw.has(required):
			return {"ok": false, "error": "stats[%d] missing field '%s'" % [index, required]}

	if typeof(raw["character_id"]) != TYPE_STRING:
		return {"ok": false, "error": "stats[%d].character_id must be String" % index}
	var id_str: String = str(raw["character_id"])
	var id_check: Dictionary = _validate_id(id_str, "stats[%d].character_id" % index)
	if not bool(id_check.get("ok", false)):
		return id_check

	var max_hp_res: Dictionary = _parse_positive_int(raw["max_hp"], "stats[%d].max_hp" % index)
	if not bool(max_hp_res.get("ok", false)):
		return max_hp_res
	var atk_res: Dictionary = _parse_nonneg_int(raw["attack"], "stats[%d].attack" % index)
	if not bool(atk_res.get("ok", false)):
		return atk_res
	var def_res: Dictionary = _parse_nonneg_int(raw["defense"], "stats[%d].defense" % index)
	if not bool(def_res.get("ok", false)):
		return def_res

	if typeof(raw["is_development_seed"]) != TYPE_BOOL:
		return {"ok": false, "error": "stats[%d].is_development_seed must be bool" % index}
	if not bool(raw["is_development_seed"]):
		return {"ok": false, "error": "stats[%d].is_development_seed must be true" % index}

	var stats := CharacterCombatStatsDefinition.new(
		StringName(id_str),
		int(max_hp_res["value"]),
		int(atk_res["value"]),
		int(def_res["value"]),
		true
	)
	return {"ok": true, "stats": stats, "error": ""}


static func _validate_id(id_str: String, field_name: String) -> Dictionary:
	if id_str.is_empty():
		return {"ok": false, "error": "%s must be non-empty" % field_name}
	var regex := RegEx.new()
	regex.compile(_ID_PATTERN)
	if regex.search(id_str) == null:
		return {"ok": false, "error": "%s has invalid syntax" % field_name}
	return {"ok": true, "error": ""}


static func _parse_positive_int(value: Variant, field_name: String) -> Dictionary:
	var base: Dictionary = _parse_exact_integer(value, field_name)
	if not bool(base.get("ok", false)):
		return base
	if int(base["value"]) < 1:
		return {"ok": false, "error": "%s must be >= 1" % field_name, "value": 0}
	return base


static func _parse_nonneg_int(value: Variant, field_name: String) -> Dictionary:
	var base: Dictionary = _parse_exact_integer(value, field_name)
	if not bool(base.get("ok", false)):
		return base
	if int(base["value"]) < 0:
		return {"ok": false, "error": "%s must be non-negative" % field_name, "value": 0}
	return base


static func _parse_exact_integer(value: Variant, field_name: String) -> Dictionary:
	var value_type: int = typeof(value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return {"ok": false, "error": "%s must be an exact integer" % field_name, "value": 0}
	var as_float: float = float(value)
	if not is_finite(as_float) or as_float != floor(as_float):
		return {"ok": false, "error": "%s must be an exact integer" % field_name, "value": 0}
	return {"ok": true, "value": int(as_float), "error": ""}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "stats": [], "error": message}
