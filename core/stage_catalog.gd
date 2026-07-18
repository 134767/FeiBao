## Pure parse/validate loader for stage catalog JSON (no SceneTree / PlayerData / UI).
class_name StageCatalog
extends RefCounted

const DEFAULT_PATH: String = "res://data/stage_catalog.json"
const EXPECTED_SCHEMA_VERSION: int = 1
const EXPECTED_CATALOG_KIND: String = "development_seed"
const _ID_PATTERN: String = "^[a-z0-9_]+$"

const _AREA_KEYS: Array[String] = [
	"id",
	"display_name",
	"summary",
	"story_intro",
	"sort_order",
	"is_development_seed",
	"stages",
]

const _STAGE_KEYS: Array[String] = [
	"id",
	"display_name",
	"summary",
	"stage_number",
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


static func _validate_and_build(root: Dictionary) -> Dictionary:
	var root_keys: Array[String] = ["schema_version", "catalog_kind", "areas"]
	for key in root.keys():
		if str(key) not in root_keys:
			return _fail("unexpected field '%s'" % str(key))
	for required in root_keys:
		if not root.has(required):
			return _fail("missing field '%s'" % required)

	var schema_res: Dictionary = _parse_exact_integer(root["schema_version"], "schema_version")
	if not bool(schema_res.get("ok", false)):
		return _fail(str(schema_res.get("error", "schema_version must be an exact integer")))
	var schema_version: int = int(schema_res["value"])
	if schema_version != EXPECTED_SCHEMA_VERSION:
		return _fail("schema_version must be %d" % EXPECTED_SCHEMA_VERSION)

	if typeof(root["catalog_kind"]) != TYPE_STRING:
		return _fail("catalog_kind must be String")
	if str(root["catalog_kind"]) != EXPECTED_CATALOG_KIND:
		return _fail("catalog_kind must be development_seed")

	if typeof(root["areas"]) != TYPE_ARRAY:
		return _fail("areas must be Array")
	var areas_raw: Array = root["areas"] as Array
	if areas_raw.is_empty():
		return _fail("areas must be non-empty")

	var seen_area_ids: Dictionary = {}
	var seen_stage_ids: Dictionary = {}
	var areas: Array[StageAreaDefinition] = []

	for i in areas_raw.size():
		var item: Variant = areas_raw[i]
		if typeof(item) != TYPE_DICTIONARY:
			return _fail("areas[%d] must be Dictionary" % i)
		var area_res: Dictionary = _parse_area(item as Dictionary, i, seen_stage_ids)
		if not bool(area_res.get("ok", false)):
			return _fail(str(area_res.get("error", "invalid area")))
		var area: StageAreaDefinition = area_res["area"] as StageAreaDefinition
		var aid: String = str(area.get_id())
		if seen_area_ids.has(aid):
			return _fail("duplicate area id: %s" % aid)
		seen_area_ids[aid] = true
		areas.append(area)

	areas.sort_custom(_compare_areas)
	var out_areas: Array = []
	var all_stages: Array = []
	for a in areas:
		out_areas.append(a.duplicate_definition())
		for s in a.get_stages():
			all_stages.append(s)

	return {
		"ok": true,
		"areas": out_areas,
		"stages": all_stages,
		"error": "",
	}


static func _parse_area(raw: Dictionary, index: int, seen_stage_ids: Dictionary) -> Dictionary:
	for key in raw.keys():
		if str(key) not in _AREA_KEYS:
			return {"ok": false, "error": "areas[%d] unexpected field '%s'" % [index, str(key)]}
	for required in _AREA_KEYS:
		if not raw.has(required):
			return {"ok": false, "error": "areas[%d] missing field '%s'" % [index, required]}

	if typeof(raw["id"]) != TYPE_STRING:
		return {"ok": false, "error": "areas[%d].id must be String" % index}
	var id_str: String = str(raw["id"])
	var id_check: Dictionary = _validate_id(id_str, "areas[%d].id" % index)
	if not bool(id_check.get("ok", false)):
		return id_check

	if typeof(raw["display_name"]) != TYPE_STRING or str(raw["display_name"]).strip_edges().is_empty():
		return {"ok": false, "error": "areas[%d].display_name must be non-empty String" % index}
	if typeof(raw["summary"]) != TYPE_STRING or str(raw["summary"]).strip_edges().is_empty():
		return {"ok": false, "error": "areas[%d].summary must be non-empty String" % index}
	if typeof(raw["story_intro"]) != TYPE_STRING or str(raw["story_intro"]).strip_edges().is_empty():
		return {"ok": false, "error": "areas[%d].story_intro must be non-empty String" % index}

	var sort_res: Dictionary = _parse_exact_integer(raw["sort_order"], "areas[%d].sort_order" % index)
	if not bool(sort_res.get("ok", false)):
		return sort_res
	var sort_order: int = int(sort_res["value"])
	if sort_order < 0:
		return {"ok": false, "error": "areas[%d].sort_order must be non-negative" % index}

	if typeof(raw["is_development_seed"]) != TYPE_BOOL:
		return {"ok": false, "error": "areas[%d].is_development_seed must be bool" % index}
	if not bool(raw["is_development_seed"]):
		return {"ok": false, "error": "areas[%d].is_development_seed must be true for development_seed catalog" % index}

	if typeof(raw["stages"]) != TYPE_ARRAY:
		return {"ok": false, "error": "areas[%d].stages must be Array" % index}
	var stages_raw: Array = raw["stages"] as Array
	if stages_raw.is_empty():
		return {"ok": false, "error": "areas[%d].stages must be non-empty" % index}

	var stages: Array[StageDefinition] = []
	var numbers: Array[int] = []
	for j in stages_raw.size():
		var sitem: Variant = stages_raw[j]
		if typeof(sitem) != TYPE_DICTIONARY:
			return {"ok": false, "error": "areas[%d].stages[%d] must be Dictionary" % [index, j]}
		var sres: Dictionary = _parse_stage(sitem as Dictionary, index, j, StringName(id_str), seen_stage_ids)
		if not bool(sres.get("ok", false)):
			return sres
		var stage: StageDefinition = sres["stage"] as StageDefinition
		stages.append(stage)
		numbers.append(stage.get_stage_number())

	stages.sort_custom(_compare_stages)
	# Contiguous stage_number from 1 after sort by stage_number.
	numbers.sort()
	for n in numbers.size():
		if numbers[n] != n + 1:
			return {
				"ok": false,
				"error": "areas[%d] stage_number must be contiguous from 1 (got %d at position %d)"
				% [index, numbers[n], n + 1],
			}

	var area := StageAreaDefinition.new(
		StringName(id_str),
		str(raw["display_name"]).strip_edges(),
		str(raw["summary"]).strip_edges(),
		str(raw["story_intro"]).strip_edges(),
		sort_order,
		true,
		stages
	)
	return {"ok": true, "area": area, "error": ""}


static func _parse_stage(
	raw: Dictionary,
	area_index: int,
	stage_index: int,
	area_id: StringName,
	seen_stage_ids: Dictionary
) -> Dictionary:
	var prefix: String = "areas[%d].stages[%d]" % [area_index, stage_index]
	for key in raw.keys():
		if str(key) not in _STAGE_KEYS:
			return {"ok": false, "error": "%s unexpected field '%s'" % [prefix, str(key)]}
	for required in _STAGE_KEYS:
		if not raw.has(required):
			return {"ok": false, "error": "%s missing field '%s'" % [prefix, required]}

	if typeof(raw["id"]) != TYPE_STRING:
		return {"ok": false, "error": "%s.id must be String" % prefix}
	var id_str: String = str(raw["id"])
	var id_check: Dictionary = _validate_id(id_str, "%s.id" % prefix)
	if not bool(id_check.get("ok", false)):
		return id_check
	if seen_stage_ids.has(id_str):
		return {"ok": false, "error": "duplicate stage id: %s" % id_str}
	seen_stage_ids[id_str] = true

	if typeof(raw["display_name"]) != TYPE_STRING or str(raw["display_name"]).strip_edges().is_empty():
		return {"ok": false, "error": "%s.display_name must be non-empty String" % prefix}
	if typeof(raw["summary"]) != TYPE_STRING or str(raw["summary"]).strip_edges().is_empty():
		return {"ok": false, "error": "%s.summary must be non-empty String" % prefix}

	var num_res: Dictionary = _parse_exact_integer(raw["stage_number"], "%s.stage_number" % prefix)
	if not bool(num_res.get("ok", false)):
		return num_res
	var stage_number: int = int(num_res["value"])
	if stage_number < 1:
		return {"ok": false, "error": "%s.stage_number must be positive" % prefix}

	var sort_res: Dictionary = _parse_exact_integer(raw["sort_order"], "%s.sort_order" % prefix)
	if not bool(sort_res.get("ok", false)):
		return sort_res
	var sort_order: int = int(sort_res["value"])
	if sort_order < 0:
		return {"ok": false, "error": "%s.sort_order must be non-negative" % prefix}

	if typeof(raw["is_development_seed"]) != TYPE_BOOL:
		return {"ok": false, "error": "%s.is_development_seed must be bool" % prefix}
	if not bool(raw["is_development_seed"]):
		return {"ok": false, "error": "%s.is_development_seed must be true for development_seed catalog" % prefix}

	var stage := StageDefinition.new(
		StringName(id_str),
		area_id,
		str(raw["display_name"]).strip_edges(),
		str(raw["summary"]).strip_edges(),
		stage_number,
		sort_order,
		true
	)
	return {"ok": true, "stage": stage, "error": ""}


static func find_stage(stage_id: StringName) -> Dictionary:
	var loaded: Dictionary = load_default()
	if not bool(loaded.get("ok", false)):
		return {"ok": false, "stage": null, "area": null, "error": str(loaded.get("error", ""))}
	for area_item in loaded.get("areas", []):
		if not area_item is StageAreaDefinition:
			continue
		var area: StageAreaDefinition = area_item as StageAreaDefinition
		var stage: StageDefinition = area.find_stage(stage_id)
		if stage != null:
			return {
				"ok": true,
				"stage": stage,
				"area": area.duplicate_definition(),
				"error": "",
			}
	return {"ok": false, "stage": null, "area": null, "error": "stage not found"}


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
	if not is_finite(as_float):
		return {"ok": false, "error": "%s must be an exact integer" % field_name, "value": 0}
	if as_float != floor(as_float):
		return {"ok": false, "error": "%s must be an exact integer" % field_name, "value": 0}
	return {"ok": true, "value": int(as_float), "error": ""}


static func _compare_areas(a: StageAreaDefinition, b: StageAreaDefinition) -> bool:
	if a.get_sort_order() != b.get_sort_order():
		return a.get_sort_order() < b.get_sort_order()
	return str(a.get_id()) < str(b.get_id())


static func _compare_stages(a: StageDefinition, b: StageDefinition) -> bool:
	if a.get_sort_order() != b.get_sort_order():
		return a.get_sort_order() < b.get_sort_order()
	if a.get_stage_number() != b.get_stage_number():
		return a.get_stage_number() < b.get_stage_number()
	return str(a.get_id()) < str(b.get_id())


static func _fail(message: String) -> Dictionary:
	return {
		"ok": false,
		"areas": [],
		"stages": [],
		"error": message,
	}
