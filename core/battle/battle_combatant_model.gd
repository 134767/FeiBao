## Pure combatant domain model (player or enemy). No damage/heal API in 1.1.0.
class_name BattleCombatantModel
extends RefCounted

const KIND_PLAYER: StringName = &"player"
const KIND_ENEMY: StringName = &"enemy"

const SNAP_KEYS: Array[String] = [
	"combatant_kind",
	"source_id",
	"display_name",
	"affinity",
	"slot_index",
	"max_hp",
	"current_hp",
	"attack",
	"defense",
]

var _combatant_kind: StringName = KIND_PLAYER
var _source_id: StringName = &""
var _display_name: String = ""
var _affinity: StringName = &""
var _slot_index: int = 0
var _max_hp: int = 1
var _current_hp: int = 1
var _attack: int = 0
var _defense: int = 0


static func create_player(
	source_id: StringName,
	display_name: String,
	affinity: StringName,
	slot_index: int,
	max_hp: int,
	attack: int,
	defense: int
) -> Dictionary:
	return _create(KIND_PLAYER, source_id, display_name, affinity, slot_index, max_hp, max_hp, attack, defense)


static func create_enemy(
	source_id: StringName,
	display_name: String,
	affinity: StringName,
	slot_index: int,
	max_hp: int,
	attack: int,
	defense: int
) -> Dictionary:
	return _create(KIND_ENEMY, source_id, display_name, affinity, slot_index, max_hp, max_hp, attack, defense)


static func _create(
	kind: StringName,
	source_id: StringName,
	display_name: String,
	affinity: StringName,
	slot_index: int,
	max_hp: int,
	current_hp: int,
	attack: int,
	defense: int
) -> Dictionary:
	var m := BattleCombatantModel.new()
	m._combatant_kind = kind
	m._source_id = source_id
	m._display_name = display_name
	m._affinity = affinity
	m._slot_index = slot_index
	m._max_hp = max_hp
	m._current_hp = current_hp
	m._attack = attack
	m._defense = defense
	var err: String = m._validate_self()
	if not err.is_empty():
		return {"ok": false, "error": err, "combatant": null}
	return {"ok": true, "error": "", "combatant": m}


func get_combatant_kind() -> StringName:
	return _combatant_kind


func get_source_id() -> StringName:
	return _source_id


func get_display_name() -> String:
	return _display_name


func get_affinity() -> StringName:
	return _affinity


func get_slot_index() -> int:
	return _slot_index


func get_max_hp() -> int:
	return _max_hp


func get_current_hp() -> int:
	return _current_hp


func get_attack() -> int:
	return _attack


func get_defense() -> int:
	return _defense


func is_alive() -> bool:
	return _current_hp > 0


func duplicate_model() -> BattleCombatantModel:
	var m := BattleCombatantModel.new()
	m._combatant_kind = _combatant_kind
	m._source_id = _source_id
	m._display_name = _display_name
	m._affinity = _affinity
	m._slot_index = _slot_index
	m._max_hp = _max_hp
	m._current_hp = _current_hp
	m._attack = _attack
	m._defense = _defense
	return m


func capture_snapshot() -> Dictionary:
	return {
		"combatant_kind": _combatant_kind,
		"source_id": _source_id,
		"display_name": _display_name,
		"affinity": _affinity,
		"slot_index": _slot_index,
		"max_hp": _max_hp,
		"current_hp": _current_hp,
		"attack": _attack,
		"defense": _defense,
	}


static func validate_snapshot(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {"ok": false, "error": "combatant not Dictionary"}
	var d: Dictionary = raw as Dictionary
	if d.size() != SNAP_KEYS.size():
		return {"ok": false, "error": "combatant unexpected key set"}
	for k in SNAP_KEYS:
		if not d.has(k):
			return {"ok": false, "error": "combatant missing %s" % k}
	for k in d.keys():
		var v: Variant = d[k]
		if v is Object or v is Callable:
			return {"ok": false, "error": "forbidden reference payload"}

	var kind_v: Variant = d.get("combatant_kind")
	if typeof(kind_v) != TYPE_STRING_NAME:
		return {"ok": false, "error": "combatant_kind must be StringName"}
	var kind: StringName = kind_v as StringName
	if kind != KIND_PLAYER and kind != KIND_ENEMY:
		return {"ok": false, "error": "unknown combatant_kind"}

	var sid_v: Variant = d.get("source_id")
	if typeof(sid_v) != TYPE_STRING_NAME:
		return {"ok": false, "error": "source_id must be StringName"}
	var sid: StringName = sid_v as StringName
	if String(sid).is_empty():
		return {"ok": false, "error": "source_id empty"}

	if typeof(d.get("display_name")) != TYPE_STRING or str(d.get("display_name")).strip_edges().is_empty():
		return {"ok": false, "error": "display_name invalid"}

	var aff_v: Variant = d.get("affinity")
	if typeof(aff_v) != TYPE_STRING_NAME or not BattleAffinity.is_valid(aff_v):
		return {"ok": false, "error": "affinity invalid"}

	for field in ["slot_index", "max_hp", "current_hp", "attack", "defense"]:
		if typeof(d.get(field)) != TYPE_INT:
			return {"ok": false, "error": "%s must be TYPE_INT" % field}
	var slot: int = d.get("slot_index") as int
	var max_hp: int = d.get("max_hp") as int
	var cur: int = d.get("current_hp") as int
	var atk: int = d.get("attack") as int
	var defense: int = d.get("defense") as int
	if slot < 0:
		return {"ok": false, "error": "slot_index negative"}
	if max_hp < 1:
		return {"ok": false, "error": "max_hp must be > 0"}
	if cur < 0 or cur > max_hp:
		return {"ok": false, "error": "current_hp out of range"}
	if atk < 0 or defense < 0:
		return {"ok": false, "error": "attack/defense negative"}

	# Catalog immutable stats + identity checks
	if kind == KIND_PLAYER:
		var stats: Dictionary = BattleCharacterStatsCatalog.find_stats(sid)
		if not bool(stats.get("ok", false)):
			return {"ok": false, "error": "unknown player source_id"}
		var s: Dictionary = stats.get("stats", {}) as Dictionary
		if (s.get("affinity") as StringName) != (aff_v as StringName):
			return {"ok": false, "error": "player affinity mismatch"}
		if int(s.get("max_hp", -1)) != max_hp or int(s.get("attack", -1)) != atk or int(s.get("defense", -1)) != defense:
			return {"ok": false, "error": "player immutable stats mismatch"}
		var chars: Dictionary = CharacterCatalog.load_default()
		if not bool(chars.get("ok", false)):
			return {"ok": false, "error": "CharacterCatalog unavailable"}
		var found: bool = false
		for c in chars.get("characters", []):
			if c is CharacterDefinition and (c as CharacterDefinition).get_id() == sid:
				found = true
				if str(d.get("display_name")) != (c as CharacterDefinition).get_display_name():
					return {"ok": false, "error": "player display_name mismatch"}
				break
		if not found:
			return {"ok": false, "error": "player not in CharacterCatalog"}
	else:
		var eres: Dictionary = EnemyCatalog.find_enemy(sid)
		if not bool(eres.get("ok", false)):
			return {"ok": false, "error": "unknown enemy source_id"}
		var e: Dictionary = eres.get("enemy", {}) as Dictionary
		if (e.get("affinity") as StringName) != (aff_v as StringName):
			return {"ok": false, "error": "enemy affinity mismatch"}
		if int(e.get("max_hp", -1)) != max_hp or int(e.get("attack", -1)) != atk or int(e.get("defense", -1)) != defense:
			return {"ok": false, "error": "enemy immutable stats mismatch"}
		if str(d.get("display_name")) != str(e.get("display_name", "")):
			return {"ok": false, "error": "enemy display_name mismatch"}

	return {"ok": true, "error": ""}


static func restore_snapshot(raw: Variant) -> Dictionary:
	var v: Dictionary = validate_snapshot(raw)
	if not bool(v.get("ok", false)):
		return {"ok": false, "error": str(v.get("error", "")), "combatant": null}
	var d: Dictionary = raw as Dictionary
	var m := BattleCombatantModel.new()
	m._combatant_kind = d.get("combatant_kind") as StringName
	m._source_id = d.get("source_id") as StringName
	m._display_name = str(d.get("display_name"))
	m._affinity = d.get("affinity") as StringName
	m._slot_index = d.get("slot_index") as int
	m._max_hp = d.get("max_hp") as int
	m._current_hp = d.get("current_hp") as int
	m._attack = d.get("attack") as int
	m._defense = d.get("defense") as int
	return {"ok": true, "error": "", "combatant": m}


## Test-only seam — not used by production Runtime/UI.
func set_current_hp_for_tests(hp: int) -> bool:
	if typeof(hp) != TYPE_INT:
		return false
	if hp < 0 or hp > _max_hp:
		return false
	_current_hp = hp
	return true


func _validate_self() -> String:
	if _combatant_kind != KIND_PLAYER and _combatant_kind != KIND_ENEMY:
		return "invalid kind"
	if String(_source_id).is_empty():
		return "empty source_id"
	if _display_name.strip_edges().is_empty():
		return "empty display_name"
	if not BattleAffinity.is_valid(_affinity):
		return "invalid affinity"
	if _slot_index < 0:
		return "negative slot"
	if _max_hp < 1:
		return "max_hp"
	if _current_hp < 0 or _current_hp > _max_hp:
		return "current_hp"
	if _attack < 0 or _defense < 0:
		return "atk/def"
	return ""


static func equals(a: BattleCombatantModel, b: BattleCombatantModel) -> bool:
	if a == null or b == null:
		return false
	return (
		a.get_combatant_kind() == b.get_combatant_kind()
		and a.get_source_id() == b.get_source_id()
		and a.get_display_name() == b.get_display_name()
		and a.get_affinity() == b.get_affinity()
		and a.get_slot_index() == b.get_slot_index()
		and a.get_max_hp() == b.get_max_hp()
		and a.get_current_hp() == b.get_current_hp()
		and a.get_attack() == b.get_attack()
		and a.get_defense() == b.get_defense()
	)
