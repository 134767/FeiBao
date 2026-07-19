## Memory-only combat participant state (party or enemy). No skills/AI/damage apply.
class_name BattleCombatant
extends RefCounted

const SIDE_PARTY: StringName = &"party"
const SIDE_ENEMY: StringName = &"enemy"

var _side: StringName = SIDE_PARTY
var _definition_id: StringName = &""
var _display_name: String = ""
var _slot_index: int = 0
var _max_hp: int = 1
var _current_hp: int = 1
var _attack: int = 0
var _defense: int = 0
var _is_leader: bool = false


func _init(
	p_side: StringName = SIDE_PARTY,
	p_definition_id: StringName = &"",
	p_display_name: String = "",
	p_slot_index: int = 0,
	p_max_hp: int = 1,
	p_current_hp: int = 1,
	p_attack: int = 0,
	p_defense: int = 0,
	p_is_leader: bool = false
) -> void:
	_side = p_side
	_definition_id = p_definition_id
	_display_name = p_display_name
	_slot_index = p_slot_index
	_max_hp = p_max_hp
	_current_hp = p_current_hp
	_attack = p_attack
	_defense = p_defense
	_is_leader = p_is_leader


func get_side() -> StringName:
	return _side


func get_definition_id() -> StringName:
	return _definition_id


func get_display_name() -> String:
	return _display_name


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


func is_leader() -> bool:
	return _is_leader


func is_defeated() -> bool:
	return _current_hp <= 0


func duplicate_combatant() -> BattleCombatant:
	return BattleCombatant.new(
		_side,
		_definition_id,
		_display_name,
		_slot_index,
		_max_hp,
		_current_hp,
		_attack,
		_defense,
		_is_leader
	)


func to_snapshot_dict() -> Dictionary:
	return {
		"side": _side,
		"definition_id": _definition_id,
		"display_name": _display_name,
		"slot_index": _slot_index,
		"max_hp": _max_hp,
		"current_hp": _current_hp,
		"attack": _attack,
		"defense": _defense,
		"is_leader": _is_leader,
	}


static func from_snapshot_dict(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {"ok": false, "combatant": null, "error": "combatant not Dictionary"}
	var d: Dictionary = raw as Dictionary
	var keys: Array[String] = [
		"side",
		"definition_id",
		"display_name",
		"slot_index",
		"max_hp",
		"current_hp",
		"attack",
		"defense",
		"is_leader",
	]
	if d.size() != keys.size():
		return {"ok": false, "combatant": null, "error": "combatant unexpected key set"}
	for k in keys:
		if not d.has(k):
			return {"ok": false, "combatant": null, "error": "combatant missing %s" % k}

	var side_v: Variant = d.get("side")
	if typeof(side_v) != TYPE_STRING_NAME:
		return {"ok": false, "combatant": null, "error": "side must be StringName"}
	var side: StringName = side_v as StringName
	if side != SIDE_PARTY and side != SIDE_ENEMY:
		return {"ok": false, "combatant": null, "error": "invalid side"}

	var id_v: Variant = d.get("definition_id")
	if typeof(id_v) != TYPE_STRING_NAME:
		return {"ok": false, "combatant": null, "error": "definition_id must be StringName"}
	var def_id: StringName = id_v as StringName
	if String(def_id).is_empty():
		return {"ok": false, "combatant": null, "error": "definition_id empty"}

	if typeof(d.get("display_name")) != TYPE_STRING:
		return {"ok": false, "combatant": null, "error": "display_name must be String"}
	var display_name: String = str(d.get("display_name"))
	if display_name.strip_edges().is_empty():
		return {"ok": false, "combatant": null, "error": "display_name empty"}

	if typeof(d.get("slot_index")) != TYPE_INT:
		return {"ok": false, "combatant": null, "error": "slot_index must be TYPE_INT"}
	var slot: int = d.get("slot_index") as int
	if slot < 0:
		return {"ok": false, "combatant": null, "error": "slot_index negative"}

	for field in ["max_hp", "current_hp", "attack", "defense"]:
		if typeof(d.get(field)) != TYPE_INT:
			return {"ok": false, "combatant": null, "error": "%s must be TYPE_INT" % field}
	var max_hp: int = d.get("max_hp") as int
	var cur_hp: int = d.get("current_hp") as int
	var attack: int = d.get("attack") as int
	var defense: int = d.get("defense") as int
	if max_hp < 1:
		return {"ok": false, "combatant": null, "error": "max_hp must be >= 1"}
	if cur_hp < 0 or cur_hp > max_hp:
		return {"ok": false, "combatant": null, "error": "current_hp out of range"}
	if attack < 0 or defense < 0:
		return {"ok": false, "combatant": null, "error": "attack/defense negative"}

	if typeof(d.get("is_leader")) != TYPE_BOOL:
		return {"ok": false, "combatant": null, "error": "is_leader must be bool"}
	var is_leader: bool = bool(d.get("is_leader"))
	if side == SIDE_ENEMY and is_leader:
		return {"ok": false, "combatant": null, "error": "enemy cannot be leader"}
	if side == SIDE_PARTY and slot == 0 and not is_leader:
		return {"ok": false, "combatant": null, "error": "party slot 0 must be leader"}
	if side == SIDE_PARTY and slot != 0 and is_leader:
		return {"ok": false, "combatant": null, "error": "only slot 0 may be leader"}

	var c := BattleCombatant.new(
		side, def_id, display_name, slot, max_hp, cur_hp, attack, defense, is_leader
	)
	return {"ok": true, "combatant": c, "error": ""}


static func equals(a: BattleCombatant, b: BattleCombatant) -> bool:
	if a == null or b == null:
		return false
	return (
		a.get_side() == b.get_side()
		and a.get_definition_id() == b.get_definition_id()
		and a.get_display_name() == b.get_display_name()
		and a.get_slot_index() == b.get_slot_index()
		and a.get_max_hp() == b.get_max_hp()
		and a.get_current_hp() == b.get_current_hp()
		and a.get_attack() == b.get_attack()
		and a.get_defense() == b.get_defense()
		and a.is_leader() == b.is_leader()
	)
