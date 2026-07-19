## Memory-only encounter: player + enemy combatants + active enemy index.
class_name BattleEncounterModel
extends RefCounted

const INACTIVE_ACTIVE_INDEX: int = -1

var _player_combatants: Array[BattleCombatantModel] = []
var _enemy_combatants: Array[BattleCombatantModel] = []
var _active_enemy_index: int = INACTIVE_ACTIVE_INDEX
var _built: bool = false


func is_valid() -> bool:
	return _built and not _player_combatants.is_empty() and not _enemy_combatants.is_empty()


func clear() -> void:
	_player_combatants.clear()
	_enemy_combatants.clear()
	_active_enemy_index = INACTIVE_ACTIVE_INDEX
	_built = false


func get_player_combatants() -> Array[BattleCombatantModel]:
	var out: Array[BattleCombatantModel] = []
	for c in _player_combatants:
		out.append(c.duplicate_model())
	return out


func get_enemy_combatants() -> Array[BattleCombatantModel]:
	var out: Array[BattleCombatantModel] = []
	for c in _enemy_combatants:
		out.append(c.duplicate_model())
	return out


func get_active_enemy_index() -> int:
	return _active_enemy_index


func get_active_enemy() -> BattleCombatantModel:
	if _active_enemy_index < 0 or _active_enemy_index >= _enemy_combatants.size():
		return null
	return _enemy_combatants[_active_enemy_index].duplicate_model()


## Domain-only: apply damage to the active enemy combatant (mutates self).
func apply_damage_to_active_enemy(amount: Variant) -> Dictionary:
	if not _built or _active_enemy_index < 0 or _active_enemy_index >= _enemy_combatants.size():
		return {
			"ok": false,
			"changed": false,
			"error": "no active enemy",
			"requested_damage": 0,
			"actual_damage": 0,
			"hp_before": 0,
			"hp_after": 0,
			"defeated": true,
		}
	return _enemy_combatants[_active_enemy_index].apply_damage(amount)


## Build from stage + party IDs. Fail closed without mutating self.
static func build_from_session(stage_id: StringName, party_ids: Array[StringName]) -> Dictionary:
	if String(stage_id).is_empty():
		return {"ok": false, "error": "empty stage_id", "encounter": null}
	if party_ids.is_empty() or party_ids.size() > 3:
		return {"ok": false, "error": "invalid party size", "encounter": null}

	var stage_res: Dictionary = StageCatalog.find_stage(stage_id)
	if not bool(stage_res.get("ok", false)):
		return {"ok": false, "error": "stage not found", "encounter": null}

	var link_res: Dictionary = StageEncounterCatalog.find_encounter(stage_id)
	if not bool(link_res.get("ok", false)):
		return {"ok": false, "error": "stage encounter missing", "encounter": null}
	var link: Dictionary = link_res.get("encounter", {}) as Dictionary
	var enemy_ids: Array = link.get("enemy_ids", []) as Array

	var chars: Dictionary = CharacterCatalog.load_default()
	if not bool(chars.get("ok", false)):
		return {"ok": false, "error": "character catalog failed", "encounter": null}
	var char_by_id: Dictionary = {}
	for c in chars.get("characters", []):
		if c is CharacterDefinition:
			char_by_id[(c as CharacterDefinition).get_id()] = c

	var players: Array[BattleCombatantModel] = []
	var seen_p: Dictionary = {}
	for i in party_ids.size():
		var pid: StringName = party_ids[i]
		if seen_p.has(str(pid)):
			return {"ok": false, "error": "duplicate party id", "encounter": null}
		seen_p[str(pid)] = true
		if not char_by_id.has(pid):
			return {"ok": false, "error": "party character missing", "encounter": null}
		var stats_res: Dictionary = BattleCharacterStatsCatalog.find_stats(pid)
		if not bool(stats_res.get("ok", false)):
			return {"ok": false, "error": "battle stats missing: %s" % str(pid), "encounter": null}
		var st: Dictionary = stats_res.get("stats", {}) as Dictionary
		var cdef: CharacterDefinition = char_by_id[pid] as CharacterDefinition
		var cres: Dictionary = BattleCombatantModel.create_player(
			pid,
			cdef.get_display_name(),
			st.get("affinity") as StringName,
			i,
			int(st.get("max_hp", 0)),
			int(st.get("attack", 0)),
			int(st.get("defense", 0))
		)
		if not bool(cres.get("ok", false)):
			return {"ok": false, "error": str(cres.get("error", "player create failed")), "encounter": null}
		players.append(cres.get("combatant") as BattleCombatantModel)

	var enemies: Array[BattleCombatantModel] = []
	var seen_e: Dictionary = {}
	for i in enemy_ids.size():
		var eid: StringName = enemy_ids[i] as StringName
		if seen_e.has(str(eid)):
			return {"ok": false, "error": "duplicate enemy id", "encounter": null}
		seen_e[str(eid)] = true
		var eres: Dictionary = EnemyCatalog.find_enemy(eid)
		if not bool(eres.get("ok", false)):
			return {"ok": false, "error": "enemy missing: %s" % str(eid), "encounter": null}
		var ed: Dictionary = eres.get("enemy", {}) as Dictionary
		var eres2: Dictionary = BattleCombatantModel.create_enemy(
			eid,
			str(ed.get("display_name", "")),
			ed.get("affinity") as StringName,
			i,
			int(ed.get("max_hp", 0)),
			int(ed.get("attack", 0)),
			int(ed.get("defense", 0))
		)
		if not bool(eres2.get("ok", false)):
			return {"ok": false, "error": str(eres2.get("error", "enemy create failed")), "encounter": null}
		enemies.append(eres2.get("combatant") as BattleCombatantModel)

	var model := BattleEncounterModel.new()
	model._player_combatants = players
	model._enemy_combatants = enemies
	model._active_enemy_index = 0
	model._built = true
	if not model.is_valid():
		return {"ok": false, "error": "built encounter invalid", "encounter": null}
	return {"ok": true, "error": "", "encounter": model}


func capture_snapshot() -> Dictionary:
	if not _built:
		return {
			"player_combatants": [],
			"enemy_combatants": [],
			"active_enemy_index": INACTIVE_ACTIVE_INDEX,
		}
	var p: Array = []
	for c in _player_combatants:
		p.append(c.capture_snapshot())
	var e: Array = []
	for c in _enemy_combatants:
		e.append(c.capture_snapshot())
	return {
		"player_combatants": p,
		"enemy_combatants": e,
		"active_enemy_index": _active_enemy_index,
	}


static func restore_snapshot(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {"ok": false, "error": "encounter not Dictionary", "encounter": null}
	var d: Dictionary = raw as Dictionary
	var keys: Array[String] = ["player_combatants", "enemy_combatants", "active_enemy_index"]
	if d.size() != keys.size():
		return {"ok": false, "error": "encounter unexpected key set", "encounter": null}
	for k in keys:
		if not d.has(k):
			return {"ok": false, "error": "encounter missing %s" % k}

	if typeof(d.get("active_enemy_index")) != TYPE_INT:
		return {"ok": false, "error": "active_enemy_index must be TYPE_INT", "encounter": null}
	var aei: int = d.get("active_enemy_index") as int

	if not (d.get("player_combatants") is Array) or not (d.get("enemy_combatants") is Array):
		return {"ok": false, "error": "combatant lists must be Array", "encounter": null}
	var praw: Array = d.get("player_combatants") as Array
	var eraw: Array = d.get("enemy_combatants") as Array

	# Canonical inactive
	if praw.is_empty() and eraw.is_empty():
		if aei != INACTIVE_ACTIVE_INDEX:
			return {"ok": false, "error": "inactive active_enemy_index must be -1", "encounter": null}
		var empty := BattleEncounterModel.new()
		empty.clear()
		return {"ok": true, "error": "", "encounter": empty}

	if praw.is_empty() or praw.size() > 3:
		return {"ok": false, "error": "invalid player count", "encounter": null}
	if eraw.is_empty() or eraw.size() > 3:
		return {"ok": false, "error": "invalid enemy count", "encounter": null}
	if aei < 0 or aei >= eraw.size():
		return {"ok": false, "error": "active_enemy_index out of range", "encounter": null}

	var players: Array[BattleCombatantModel] = []
	var seen_p: Dictionary = {}
	for i in praw.size():
		var r: Dictionary = BattleCombatantModel.restore_snapshot(praw[i])
		if not bool(r.get("ok", false)):
			return {"ok": false, "error": "player[%d]: %s" % [i, str(r.get("error", ""))], "encounter": null}
		var c: BattleCombatantModel = r.get("combatant") as BattleCombatantModel
		if c.get_combatant_kind() != BattleCombatantModel.KIND_PLAYER:
			return {"ok": false, "error": "player[%d] wrong kind" % i, "encounter": null}
		if c.get_slot_index() != i:
			return {"ok": false, "error": "player[%d] slot not contiguous" % i, "encounter": null}
		if seen_p.has(str(c.get_source_id())):
			return {"ok": false, "error": "duplicate player source", "encounter": null}
		seen_p[str(c.get_source_id())] = true
		players.append(c)

	var enemies: Array[BattleCombatantModel] = []
	var seen_e: Dictionary = {}
	for i in eraw.size():
		var r2: Dictionary = BattleCombatantModel.restore_snapshot(eraw[i])
		if not bool(r2.get("ok", false)):
			return {"ok": false, "error": "enemy[%d]: %s" % [i, str(r2.get("error", ""))], "encounter": null}
		var e: BattleCombatantModel = r2.get("combatant") as BattleCombatantModel
		if e.get_combatant_kind() != BattleCombatantModel.KIND_ENEMY:
			return {"ok": false, "error": "enemy[%d] wrong kind" % i, "encounter": null}
		if e.get_slot_index() != i:
			return {"ok": false, "error": "enemy[%d] slot not contiguous" % i, "encounter": null}
		if seen_e.has(str(e.get_source_id())):
			return {"ok": false, "error": "duplicate enemy source", "encounter": null}
		seen_e[str(e.get_source_id())] = true
		enemies.append(e)

	var model := BattleEncounterModel.new()
	model._player_combatants = players
	model._enemy_combatants = enemies
	model._active_enemy_index = aei
	model._built = true
	return {"ok": true, "error": "", "encounter": model}


static func equals(a: BattleEncounterModel, b: BattleEncounterModel) -> bool:
	if a == null or b == null:
		return false
	if a.get_active_enemy_index() != b.get_active_enemy_index():
		return false
	var ap: Array[BattleCombatantModel] = a.get_player_combatants()
	var bp: Array[BattleCombatantModel] = b.get_player_combatants()
	if ap.size() != bp.size():
		return false
	for i in ap.size():
		if not BattleCombatantModel.equals(ap[i], bp[i]):
			return false
	var ae: Array[BattleCombatantModel] = a.get_enemy_combatants()
	var be: Array[BattleCombatantModel] = b.get_enemy_combatants()
	if ae.size() != be.size():
		return false
	for i in ae.size():
		if not BattleCombatantModel.equals(ae[i], be[i]):
			return false
	return true


func assign_from(other: BattleEncounterModel) -> void:
	clear()
	if other == null:
		return
	for c in other.get_player_combatants():
		_player_combatants.append(c)
	for c in other.get_enemy_combatants():
		_enemy_combatants.append(c)
	_active_enemy_index = other.get_active_enemy_index()
	_built = other.is_valid() or (
		_player_combatants.is_empty() and _enemy_combatants.is_empty() and _active_enemy_index == INACTIVE_ACTIVE_INDEX
	)
	if _player_combatants.is_empty() and _enemy_combatants.is_empty():
		_built = false
	else:
		_built = true
