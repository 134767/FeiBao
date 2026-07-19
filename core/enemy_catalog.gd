## Pure parse/validate loader for enemy catalog JSON.
class_name EnemyCatalog
extends RefCounted

const DEFAULT_PATH: String = "res://data/enemy_catalog.json"
const EXPECTED_SCHEMA_VERSION: int = 1
const EXPECTED_CATALOG_KIND: String = "development_seed"
const _ID_PATTERN: String = "^[a-z0-9_]+$"
const _ENEMY_KEYS: Array[String] = [
	"id",
	"display_name",
	"summary",
	"max_hp",
	"attack",
	"defense",
	"sort_order",
	"is_development_seed",
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


static func find_enemy(enemy_id: StringName) -> Dictionary:
	var loaded: Dictionary = load_default()
	if not bool(loaded.get("ok", false)):
		return {"ok": false, "enemy": null, "error": str(loaded.get("error", ""))}
	for item in loaded.get("enemies", []):
		if item is EnemyDefinition:
			var e: EnemyDefinition = item as EnemyDefinition
			if e.get_id() == enemy_id:
				return {"ok": true, "enemy": e.duplicate_definition(), "error": ""}
	return {"ok": false, "enemy": null, "error": "enemy not found"}


static func _validate_and_build(root: Dictionary) -> Dictionary:
	var root_keys: Array[String] = ["schema_version", "catalog_kind", "enemies"]
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

	if typeof(root["enemies"]) != TYPE_ARRAY:
		return _fail("enemies must be Array")
	var raw_list: Array = root["enemies"] as Array
	if raw_list.is_empty():
		return _fail("enemies must be non-empty")

	var seen: Dictionary = {}
	var parsed: Array[EnemyDefinition] = []
	for i in raw_list.size():
		var item: Variant = raw_list[i]
		if typeof(item) != TYPE_DICTIONARY:
			return _fail("enemies[%d] must be Dictionary" % i)
		var one: Dictionary = _parse_enemy(item as Dictionary, i)
		if not bool(one.get("ok", false)):
			return _fail(str(one.get("error", "invalid enemy")))
		var def: EnemyDefinition = one["enemy"] as EnemyDefinition
		var key: String = str(def.get_id())
		if seen.has(key):
			return _fail("duplicate enemy id: %s" % key)
		seen[key] = true
		parsed.append(def)

	parsed.sort_custom(_compare)
	var out: Array = []
	for d in parsed:
		out.append(d.duplicate_definition())
	return {"ok": true, "enemies": out, "error": ""}


static func _parse_enemy(raw: Dictionary, index: int) -> Dictionary:
	for key in raw.keys():
		if str(key) not in _ENEMY_KEYS:
			return {"ok": false, "error": "enemies[%d] unexpected field '%s'" % [index, str(key)]}
	for required in _ENEMY_KEYS:
		if not raw.has(required):
			return {"ok": false, "error": "enemies[%d] missing field '%s'" % [index, required]}

	if typeof(raw["id"]) != TYPE_STRING:
		return {"ok": false, "error": "enemies[%d].id must be String" % index}
	var id_str: String = str(raw["id"])
	var id_check: Dictionary = _validate_id(id_str, "enemies[%d].id" % index)
	if not bool(id_check.get("ok", false)):
		return id_check

	if typeof(raw["display_name"]) != TYPE_STRING or str(raw["display_name"]).strip_edges().is_empty():
		return {"ok": false, "error": "enemies[%d].display_name must be non-empty String" % index}
	if typeof(raw["summary"]) != TYPE_STRING or str(raw["summary"]).strip_edges().is_empty():
		return {"ok": false, "error": "enemies[%d].summary must be non-empty String" % index}

	var max_hp_res: Dictionary = _parse_positive_int(raw["max_hp"], "enemies[%d].max_hp" % index)
	if not bool(max_hp_res.get("ok", false)):
		return max_hp_res
	var atk_res: Dictionary = _parse_nonneg_int(raw["attack"], "enemies[%d].attack" % index)
	if not bool(atk_res.get("ok", false)):
		return atk_res
	var def_res: Dictionary = _parse_nonneg_int(raw["defense"], "enemies[%d].defense" % index)
	if not bool(def_res.get("ok", false)):
		return def_res
	var sort_res: Dictionary = _parse_nonneg_int(raw["sort_order"], "enemies[%d].sort_order" % index)
	if not bool(sort_res.get("ok", false)):
		return sort_res

	if typeof(raw["is_development_seed"]) != TYPE_BOOL:
		return {"ok": false, "error": "enemies[%d].is_development_seed must be bool" % index}
	if not bool(raw["is_development_seed"]):
		return {"ok": false, "error": "enemies[%d].is_development_seed must be true" % index}

	var enemy := EnemyDefinition.new(
		StringName(id_str),
		str(raw["display_name"]).strip_edges(),
		str(raw["summary"]).strip_edges(),
		int(max_hp_res["value"]),
		int(atk_res["value"]),
		int(def_res["value"]),
		int(sort_res["value"]),
		true
	)
	return {"ok": true, "enemy": enemy, "error": ""}


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


static func _compare(a: EnemyDefinition, b: EnemyDefinition) -> bool:
	if a.get_sort_order() != b.get_sort_order():
		return a.get_sort_order() < b.get_sort_order()
	return str(a.get_id()) < str(b.get_id())


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "enemies": [], "error": message}
