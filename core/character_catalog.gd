## Pure parse/validate loader for character catalog JSON (no SceneTree / UI).
class_name CharacterCatalog
extends RefCounted

const DEFAULT_PATH: String = "res://data/character_catalog.json"
const EXPECTED_SCHEMA_VERSION: int = 1
const EXPECTED_CATALOG_KIND: String = "development_seed"
const _ID_PATTERN: String = "^[a-z0-9_]+$"


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


static func _validate_and_build(root: Dictionary) -> Dictionary:
	if not root.has("schema_version"):
		return _fail("missing schema_version")
	var schema_int_result: Dictionary = _parse_exact_integer(root["schema_version"], "schema_version")
	if not bool(schema_int_result.get("ok", false)):
		return _fail(str(schema_int_result.get("error", "schema_version must be an exact integer")))
	var schema_version: int = int(schema_int_result["value"])
	if schema_version != EXPECTED_SCHEMA_VERSION:
		return _fail("schema_version must be %d" % EXPECTED_SCHEMA_VERSION)

	if not root.has("catalog_kind"):
		return _fail("missing catalog_kind")
	if typeof(root["catalog_kind"]) != TYPE_STRING:
		return _fail("catalog_kind must be String")
	if str(root["catalog_kind"]) != EXPECTED_CATALOG_KIND:
		return _fail("catalog_kind must be development_seed")

	if not root.has("characters"):
		return _fail("missing characters")
	if typeof(root["characters"]) != TYPE_ARRAY:
		return _fail("characters must be Array")

	var raw_list: Array = root["characters"] as Array
	var seen_ids: Dictionary = {}
	var parsed: Array[CharacterDefinition] = []

	for i in raw_list.size():
		var item: Variant = raw_list[i]
		if typeof(item) != TYPE_DICTIONARY:
			return _fail("characters[%d] must be Dictionary" % i)
		var def_result: Dictionary = _parse_character(item as Dictionary, i)
		if not bool(def_result.get("ok", false)):
			return _fail(str(def_result.get("error", "invalid character")))
		var def: CharacterDefinition = def_result["definition"] as CharacterDefinition
		var id_key: String = str(def.get_id())
		if seen_ids.has(id_key):
			return _fail("duplicate character id: %s" % id_key)
		seen_ids[id_key] = true
		parsed.append(def)

	parsed.sort_custom(_compare_definitions)
	var out: Array = []
	for d in parsed:
		out.append(d)
	return {
		"ok": true,
		"characters": out,
		"error": "",
	}


static func _parse_character(raw: Dictionary, index: int) -> Dictionary:
	var required: PackedStringArray = PackedStringArray([
		"id",
		"display_name",
		"species",
		"summary",
		"description",
		"tags",
		"sort_order",
		"portrait_path",
		"is_development_seed",
	])
	for key in required:
		if not raw.has(key):
			return _fail_char("characters[%d] missing field '%s'" % [index, key])

	if typeof(raw["id"]) != TYPE_STRING:
		return _fail_char("characters[%d].id must be String" % index)
	var id_str: String = str(raw["id"]).strip_edges()
	if id_str.is_empty():
		return _fail_char("characters[%d].id must be non-empty" % index)
	var id_regex := RegEx.new()
	id_regex.compile(_ID_PATTERN)
	if id_regex.search(id_str) == null:
		return _fail_char("characters[%d].id has invalid syntax: %s" % [index, id_str])

	if typeof(raw["display_name"]) != TYPE_STRING or str(raw["display_name"]).strip_edges().is_empty():
		return _fail_char("characters[%d].display_name must be non-empty String" % index)
	if typeof(raw["species"]) != TYPE_STRING or str(raw["species"]).strip_edges().is_empty():
		return _fail_char("characters[%d].species must be non-empty String" % index)
	if typeof(raw["summary"]) != TYPE_STRING or str(raw["summary"]).strip_edges().is_empty():
		return _fail_char("characters[%d].summary must be non-empty String" % index)
	if typeof(raw["description"]) != TYPE_STRING or str(raw["description"]).strip_edges().is_empty():
		return _fail_char("characters[%d].description must be non-empty String" % index)

	if typeof(raw["tags"]) != TYPE_ARRAY:
		return _fail_char("characters[%d].tags must be Array" % index)
	var tags_raw: Array = raw["tags"] as Array
	if tags_raw.is_empty():
		return _fail_char("characters[%d].tags must be non-empty" % index)
	var tags: Array[String] = []
	for t in tags_raw:
		if typeof(t) != TYPE_STRING or str(t).strip_edges().is_empty():
			return _fail_char("characters[%d].tags must contain non-empty strings" % index)
		tags.append(str(t).strip_edges())

	var sort_field: String = "characters[%d].sort_order" % index
	var sort_int_result: Dictionary = _parse_exact_integer(raw["sort_order"], sort_field)
	if not bool(sort_int_result.get("ok", false)):
		return _fail_char(str(sort_int_result.get("error", "%s must be an exact integer" % sort_field)))
	var sort_order: int = int(sort_int_result["value"])
	if sort_order < 0:
		return _fail_char("%s must be non-negative" % sort_field)

	if typeof(raw["portrait_path"]) != TYPE_STRING:
		return _fail_char("characters[%d].portrait_path must be String" % index)

	if typeof(raw["is_development_seed"]) != TYPE_BOOL:
		return _fail_char("characters[%d].is_development_seed must be bool" % index)
	# development_seed catalogs require every record to be an explicit development seed.
	if raw["is_development_seed"] != true:
		return _fail_char(
			"characters[%d].is_development_seed must be true for development_seed catalog" % index
		)

	var def := CharacterDefinition.new(
		StringName(id_str),
		str(raw["display_name"]).strip_edges(),
		str(raw["species"]).strip_edges(),
		str(raw["summary"]).strip_edges(),
		str(raw["description"]).strip_edges(),
		tags,
		sort_order,
		str(raw["portrait_path"]),
		true
	)
	return {"ok": true, "definition": def, "error": ""}


## Accept TYPE_INT or TYPE_FLOAT only when the value is a finite exact integer (e.g. 1, 1.0).
## Rejects fractional values (1.5), non-finite numbers, strings, bools, and null.
## Does not judge validity via int(value) truncation.
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
	# Reject any fractional component; do not accept int(1.5) == 1 as proof of validity.
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


static func _compare_definitions(a: CharacterDefinition, b: CharacterDefinition) -> bool:
	if a.get_sort_order() != b.get_sort_order():
		return a.get_sort_order() < b.get_sort_order()
	return str(a.get_id()) < str(b.get_id())


static func _fail(message: String) -> Dictionary:
	return {
		"ok": false,
		"characters": [],
		"error": message,
	}


static func _fail_char(message: String) -> Dictionary:
	return {
		"ok": false,
		"definition": null,
		"error": message,
	}
