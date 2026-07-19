## Pure parse/validate loader for stage→enemy encounter linkage JSON.
class_name StageEncounterCatalog
extends RefCounted

const DEFAULT_PATH: String = "res://data/stage_encounters.json"
const EXPECTED_SCHEMA_VERSION: int = 1
const EXPECTED_CATALOG_KIND: String = "development_seed"
const _ID_PATTERN: String = "^[a-z0-9_]+$"
const _ENTRY_KEYS: Array[String] = ["stage_id", "enemy_ids", "is_development_seed"]
const MIN_ENEMIES: int = 1
const MAX_ENEMIES: int = 3


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


static func find_encounter(stage_id: StringName) -> Dictionary:
	var loaded: Dictionary = load_default()
	if not bool(loaded.get("ok", false)):
		return {"ok": false, "encounter": null, "error": str(loaded.get("error", ""))}
	for item in loaded.get("encounters", []):
		if item is StageEncounterDefinition:
			var e: StageEncounterDefinition = item as StageEncounterDefinition
			if e.get_stage_id() == stage_id:
				return {"ok": true, "encounter": e.duplicate_definition(), "error": ""}
	return {"ok": false, "encounter": null, "error": "encounter not found for stage"}


static func _validate_and_build(root: Dictionary) -> Dictionary:
	var root_keys: Array[String] = ["schema_version", "catalog_kind", "encounters"]
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

	if typeof(root["encounters"]) != TYPE_ARRAY:
		return _fail("encounters must be Array")
	var raw_list: Array = root["encounters"] as Array
	if raw_list.is_empty():
		return _fail("encounters must be non-empty")

	var seen_stages: Dictionary = {}
	var parsed: Array[StageEncounterDefinition] = []
	for i in raw_list.size():
		var item: Variant = raw_list[i]
		if typeof(item) != TYPE_DICTIONARY:
			return _fail("encounters[%d] must be Dictionary" % i)
		var one: Dictionary = _parse_entry(item as Dictionary, i)
		if not bool(one.get("ok", false)):
			return _fail(str(one.get("error", "invalid encounter")))
		var def: StageEncounterDefinition = one["encounter"] as StageEncounterDefinition
		var key: String = str(def.get_stage_id())
		if seen_stages.has(key):
			return _fail("duplicate stage_id: %s" % key)
		seen_stages[key] = true
		parsed.append(def)

	var out: Array = []
	for d in parsed:
		out.append(d.duplicate_definition())
	return {"ok": true, "encounters": out, "error": ""}


static func _parse_entry(raw: Dictionary, index: int) -> Dictionary:
	for key in raw.keys():
		if str(key) not in _ENTRY_KEYS:
			return {"ok": false, "error": "encounters[%d] unexpected field '%s'" % [index, str(key)]}
	for required in _ENTRY_KEYS:
		if not raw.has(required):
			return {"ok": false, "error": "encounters[%d] missing field '%s'" % [index, required]}

	if typeof(raw["stage_id"]) != TYPE_STRING:
		return {"ok": false, "error": "encounters[%d].stage_id must be String" % index}
	var stage_str: String = str(raw["stage_id"])
	var id_check: Dictionary = _validate_id(stage_str, "encounters[%d].stage_id" % index)
	if not bool(id_check.get("ok", false)):
		return id_check

	if typeof(raw["enemy_ids"]) != TYPE_ARRAY:
		return {"ok": false, "error": "encounters[%d].enemy_ids must be Array" % index}
	var enemy_raw: Array = raw["enemy_ids"] as Array
	if enemy_raw.size() < MIN_ENEMIES or enemy_raw.size() > MAX_ENEMIES:
		return {
			"ok": false,
			"error": "encounters[%d].enemy_ids size must be %d..%d" % [index, MIN_ENEMIES, MAX_ENEMIES],
		}

	var enemy_ids: Array[StringName] = []
	for j in enemy_raw.size():
		var eitem: Variant = enemy_raw[j]
		if typeof(eitem) != TYPE_STRING:
			return {"ok": false, "error": "encounters[%d].enemy_ids[%d] must be String" % [index, j]}
		var eid: String = str(eitem)
		var echeck: Dictionary = _validate_id(eid, "encounters[%d].enemy_ids[%d]" % [index, j])
		if not bool(echeck.get("ok", false)):
			return echeck
		enemy_ids.append(StringName(eid))

	if typeof(raw["is_development_seed"]) != TYPE_BOOL:
		return {"ok": false, "error": "encounters[%d].is_development_seed must be bool" % index}
	if not bool(raw["is_development_seed"]):
		return {"ok": false, "error": "encounters[%d].is_development_seed must be true" % index}

	var enc := StageEncounterDefinition.new(StringName(stage_str), enemy_ids, true)
	return {"ok": true, "encounter": enc, "error": ""}


static func _validate_id(id_str: String, field_name: String) -> Dictionary:
	if id_str.is_empty():
		return {"ok": false, "error": "%s must be non-empty" % field_name}
	var regex := RegEx.new()
	regex.compile(_ID_PATTERN)
	if regex.search(id_str) == null:
		return {"ok": false, "error": "%s has invalid syntax" % field_name}
	return {"ok": true, "error": ""}


static func _parse_exact_integer(value: Variant, field_name: String) -> Dictionary:
	var value_type: int = typeof(value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return {"ok": false, "error": "%s must be an exact integer" % field_name, "value": 0}
	var as_float: float = float(value)
	if not is_finite(as_float) or as_float != floor(as_float):
		return {"ok": false, "error": "%s must be an exact integer" % field_name, "value": 0}
	return {"ok": true, "value": int(as_float), "error": ""}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "encounters": [], "error": message}
