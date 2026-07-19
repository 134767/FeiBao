## Stage → enemy encounter linkage (pure data — deterministic, no RNG).
class_name StageEncounterCatalog
extends RefCounted

const DEFAULT_PATH: String = "res://data/stage_encounters.json"
const EXPECTED_SCHEMA_VERSION: int = 1
const EXPECTED_CATALOG_KIND: String = "development_seed"
const _ID_PATTERN: String = "^[a-z0-9_]+$"
const _ENTRY_KEYS: Array[String] = ["stage_id", "enemy_ids"]
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
	if json.parse(text) != OK:
		return _fail("invalid JSON: %s" % json.get_error_message())
	if typeof(json.data) != TYPE_DICTIONARY:
		return _fail("catalog root must be a Dictionary")
	return _validate_and_build(json.data as Dictionary)


static func find_encounter(stage_id: StringName) -> Dictionary:
	var loaded: Dictionary = load_default()
	if not bool(loaded.get("ok", false)):
		return {"ok": false, "encounter": {}, "error": str(loaded.get("error", ""))}
	for item in loaded.get("encounters", []) as Array:
		if item is Dictionary and StringName(str((item as Dictionary).get("stage_id", ""))) == stage_id:
			return {"ok": true, "encounter": (item as Dictionary).duplicate(true), "error": ""}
	return {"ok": false, "encounter": {}, "error": "encounter not found for stage"}


static func _validate_and_build(root: Dictionary) -> Dictionary:
	var root_keys: Array[String] = ["schema_version", "catalog_kind", "encounters"]
	for key in root.keys():
		if str(key) not in root_keys:
			return _fail("unexpected field '%s'" % str(key))
	for required in root_keys:
		if not root.has(required):
			return _fail("missing field '%s'" % required)
	var schema_res: Dictionary = _parse_strict_int(root["schema_version"], "schema_version")
	if not bool(schema_res.get("ok", false)):
		return _fail(str(schema_res.get("error", "")))
	if int(schema_res["value"]) != EXPECTED_SCHEMA_VERSION:
		return _fail("schema_version must be %d" % EXPECTED_SCHEMA_VERSION)
	if typeof(root["catalog_kind"]) != TYPE_STRING or str(root["catalog_kind"]) != EXPECTED_CATALOG_KIND:
		return _fail("catalog_kind must be development_seed")
	if typeof(root["encounters"]) != TYPE_ARRAY:
		return _fail("encounters must be Array")
	var raw: Array = root["encounters"] as Array
	if raw.is_empty():
		return _fail("encounters must be non-empty")

	var stages_loaded: Dictionary = StageCatalog.load_default()
	if not bool(stages_loaded.get("ok", false)):
		return _fail("StageCatalog unavailable")
	var known_stages: Dictionary = {}
	for s in stages_loaded.get("stages", []):
		if s is StageDefinition:
			known_stages[(s as StageDefinition).get_id()] = true

	var enemies_loaded: Dictionary = EnemyCatalog.load_default()
	if not bool(enemies_loaded.get("ok", false)):
		return _fail("EnemyCatalog unavailable")
	var known_enemies: Dictionary = {}
	for e in enemies_loaded.get("enemies", []) as Array:
		if e is Dictionary:
			known_enemies[StringName(str((e as Dictionary).get("enemy_id", "")))] = true

	var seen_stages: Dictionary = {}
	var out: Array = []
	for i in raw.size():
		if typeof(raw[i]) != TYPE_DICTIONARY:
			return _fail("encounters[%d] must be Dictionary" % i)
		var one: Dictionary = _parse_entry(raw[i] as Dictionary, i, known_stages, known_enemies, seen_stages)
		if not bool(one.get("ok", false)):
			return _fail(str(one.get("error", "")))
		out.append((one["encounter"] as Dictionary).duplicate(true))

	# Every playable stage must have an encounter; no orphan stages left uncovered.
	for sid in known_stages.keys():
		if not seen_stages.has(str(sid)):
			return _fail("missing encounter for stage: %s" % str(sid))

	return {"ok": true, "encounters": out, "error": ""}


static func _parse_entry(
	raw: Dictionary,
	index: int,
	known_stages: Dictionary,
	known_enemies: Dictionary,
	seen_stages: Dictionary
) -> Dictionary:
	for key in raw.keys():
		if str(key) not in _ENTRY_KEYS:
			return {"ok": false, "error": "encounters[%d] unexpected field '%s'" % [index, str(key)]}
	for required in _ENTRY_KEYS:
		if not raw.has(required):
			return {"ok": false, "error": "encounters[%d] missing field '%s'" % [index, required]}

	if typeof(raw["stage_id"]) != TYPE_STRING:
		return {"ok": false, "error": "encounters[%d].stage_id must be String" % index}
	var sid: String = str(raw["stage_id"])
	if sid.is_empty() or not _id_ok(sid):
		return {"ok": false, "error": "encounters[%d].stage_id invalid" % index}
	var sid_sn := StringName(sid)
	if not known_stages.has(sid_sn):
		return {"ok": false, "error": "encounters[%d].stage_id not in StageCatalog" % index}
	if seen_stages.has(sid):
		return {"ok": false, "error": "duplicate stage_id: %s" % sid}
	seen_stages[sid] = true

	if typeof(raw["enemy_ids"]) != TYPE_ARRAY:
		return {"ok": false, "error": "encounters[%d].enemy_ids must be Array" % index}
	var eraw: Array = raw["enemy_ids"] as Array
	if eraw.size() < MIN_ENEMIES or eraw.size() > MAX_ENEMIES:
		return {"ok": false, "error": "encounters[%d].enemy_ids size must be 1..3" % index}

	var enemy_ids: Array[StringName] = []
	var seen_e: Dictionary = {}
	for j in eraw.size():
		if typeof(eraw[j]) != TYPE_STRING:
			return {"ok": false, "error": "encounters[%d].enemy_ids[%d] must be String" % [index, j]}
		var eid: String = str(eraw[j])
		if eid.is_empty() or not _id_ok(eid):
			return {"ok": false, "error": "encounters[%d].enemy_ids[%d] invalid" % [index, j]}
		var eid_sn := StringName(eid)
		if seen_e.has(eid):
			return {"ok": false, "error": "encounters[%d] duplicate enemy id" % index}
		if not known_enemies.has(eid_sn):
			return {"ok": false, "error": "encounters[%d] unknown enemy: %s" % [index, eid]}
		seen_e[eid] = true
		enemy_ids.append(eid_sn)

	return {
		"ok": true,
		"encounter": {"stage_id": sid_sn, "enemy_ids": enemy_ids.duplicate()},
		"error": "",
	}


static func _id_ok(id_str: String) -> bool:
	var regex := RegEx.new()
	regex.compile(_ID_PATTERN)
	return regex.search(id_str) != null


static func _parse_strict_int(value: Variant, field_name: String) -> Dictionary:
	var t: int = typeof(value)
	if t == TYPE_BOOL or t == TYPE_STRING or value == null:
		return {"ok": false, "error": "%s must be TYPE_INT" % field_name, "value": 0}
	if t != TYPE_INT and t != TYPE_FLOAT:
		return {"ok": false, "error": "%s must be TYPE_INT" % field_name, "value": 0}
	var f: float = float(value)
	if not is_finite(f) or f != floor(f):
		return {"ok": false, "error": "%s must be TYPE_INT" % field_name, "value": 0}
	return {"ok": true, "value": int(f), "error": ""}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "encounters": [], "error": message}
