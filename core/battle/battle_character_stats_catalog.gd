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

	var schema_res: Dictionary = _parse_strict_int(root["schema_version"], "schema_version")
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

	var hp: Dictionary = _parse_strict_int(raw["max_hp"], "stats[%d].max_hp" % index)
	if not bool(hp.get("ok", false)):
		return hp
	var hpv: int = int(hp["value"])
	if hpv < 1 or hpv > MAX_HP_MAX:
		return {"ok": false, "error": "stats[%d].max_hp out of bounds" % index}

	var atk: Dictionary = _parse_strict_int(raw["attack"], "stats[%d].attack" % index)
	if not bool(atk.get("ok", false)):
		return atk
	var atkv: int = int(atk["value"])
	if atkv < 0 or atkv > ATK_DEF_MAX:
		return {"ok": false, "error": "stats[%d].attack out of bounds" % index}

	var defense: Dictionary = _parse_strict_int(raw["defense"], "stats[%d].defense" % index)
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


## Exact integer only. Godot JSON yields float; accept floor-equal floats, reject bool/string/null/fraction.
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
	return {"ok": false, "stats": [], "error": message}
