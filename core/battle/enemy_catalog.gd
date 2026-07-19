## Read-only enemy catalog (pure data — no SceneTree).
class_name EnemyCatalog
extends RefCounted

const DEFAULT_PATH: String = "res://data/enemies.json"
const EXPECTED_SCHEMA_VERSION: int = 1
const EXPECTED_CATALOG_KIND: String = "development_seed"
const _ID_PATTERN: String = "^[a-z0-9_]+$"
const _ENTRY_KEYS: Array[String] = [
	"enemy_id", "display_name", "affinity", "max_hp", "attack", "defense", "visual_symbol"
]
const MAX_HP_MAX: int = 1000000
const ATK_DEF_MAX: int = 100000


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


static func find_enemy(enemy_id: StringName) -> Dictionary:
	var loaded: Dictionary = load_default()
	if not bool(loaded.get("ok", false)):
		return {"ok": false, "enemy": {}, "error": str(loaded.get("error", ""))}
	for item in loaded.get("enemies", []) as Array:
		if item is Dictionary and StringName(str((item as Dictionary).get("enemy_id", ""))) == enemy_id:
			return {"ok": true, "enemy": (item as Dictionary).duplicate(true), "error": ""}
	return {"ok": false, "enemy": {}, "error": "enemy not found"}


static func _validate_and_build(root: Dictionary) -> Dictionary:
	var root_keys: Array[String] = ["schema_version", "catalog_kind", "enemies"]
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
	if typeof(root["enemies"]) != TYPE_ARRAY:
		return _fail("enemies must be Array")
	var raw: Array = root["enemies"] as Array
	if raw.is_empty():
		return _fail("enemies must be non-empty")

	var seen: Dictionary = {}
	var out: Array = []
	for i in raw.size():
		if typeof(raw[i]) != TYPE_DICTIONARY:
			return _fail("enemies[%d] must be Dictionary" % i)
		var one: Dictionary = _parse_entry(raw[i] as Dictionary, i, seen)
		if not bool(one.get("ok", false)):
			return _fail(str(one.get("error", "")))
		out.append((one["enemy"] as Dictionary).duplicate(true))
	return {"ok": true, "enemies": out, "error": ""}


static func _parse_entry(raw: Dictionary, index: int, seen: Dictionary) -> Dictionary:
	for key in raw.keys():
		if str(key) not in _ENTRY_KEYS:
			return {"ok": false, "error": "enemies[%d] unexpected field '%s'" % [index, str(key)]}
	for required in _ENTRY_KEYS:
		if not raw.has(required):
			return {"ok": false, "error": "enemies[%d] missing field '%s'" % [index, required]}

	if typeof(raw["enemy_id"]) != TYPE_STRING:
		return {"ok": false, "error": "enemies[%d].enemy_id must be String" % index}
	var eid: String = str(raw["enemy_id"])
	if eid.is_empty() or not _id_ok(eid):
		return {"ok": false, "error": "enemies[%d].enemy_id invalid" % index}
	if seen.has(eid):
		return {"ok": false, "error": "duplicate enemy_id: %s" % eid}
	seen[eid] = true

	if typeof(raw["display_name"]) != TYPE_STRING or str(raw["display_name"]).strip_edges().is_empty():
		return {"ok": false, "error": "enemies[%d].display_name must be non-empty String" % index}
	if typeof(raw["affinity"]) != TYPE_STRING:
		return {"ok": false, "error": "enemies[%d].affinity must be String" % index}
	var aff := StringName(str(raw["affinity"]))
	if not BattleAffinity.is_valid(aff):
		return {"ok": false, "error": "enemies[%d].affinity invalid" % index}

	var hp: Dictionary = _parse_strict_int(raw["max_hp"], "enemies[%d].max_hp" % index)
	if not bool(hp.get("ok", false)):
		return hp
	var hpv: int = int(hp["value"])
	if hpv < 1 or hpv > MAX_HP_MAX:
		return {"ok": false, "error": "enemies[%d].max_hp out of bounds" % index}
	var atk: Dictionary = _parse_strict_int(raw["attack"], "enemies[%d].attack" % index)
	if not bool(atk.get("ok", false)):
		return atk
	var atkv: int = int(atk["value"])
	if atkv < 0 or atkv > ATK_DEF_MAX:
		return {"ok": false, "error": "enemies[%d].attack out of bounds" % index}
	var defense: Dictionary = _parse_strict_int(raw["defense"], "enemies[%d].defense" % index)
	if not bool(defense.get("ok", false)):
		return defense
	var defv: int = int(defense["value"])
	if defv < 0 or defv > ATK_DEF_MAX:
		return {"ok": false, "error": "enemies[%d].defense out of bounds" % index}

	if typeof(raw["visual_symbol"]) != TYPE_STRING or str(raw["visual_symbol"]).is_empty():
		return {"ok": false, "error": "enemies[%d].visual_symbol must be non-empty String" % index}

	return {
		"ok": true,
		"enemy": {
			"enemy_id": StringName(eid),
			"display_name": str(raw["display_name"]).strip_edges(),
			"affinity": aff,
			"max_hp": hpv,
			"attack": atkv,
			"defense": defv,
			"visual_symbol": str(raw["visual_symbol"]),
		},
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
	return {"ok": false, "enemies": [], "error": message}
