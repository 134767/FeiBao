## Memory-only battle encounter: party + enemy combatants. No damage/AI/victory.
class_name BattleEncounterModel
extends RefCounted

var _active: bool = false
var _stage_id: StringName = &""
var _area_id: StringName = &""
var _party: Array[BattleCombatant] = []
var _enemies: Array[BattleCombatant] = []


func is_active() -> bool:
	return _active


func get_stage_id() -> StringName:
	return _stage_id


func get_area_id() -> StringName:
	return _area_id


func get_party_combatants() -> Array[BattleCombatant]:
	var out: Array[BattleCombatant] = []
	for c in _party:
		out.append(c.duplicate_combatant())
	return out


func get_enemy_combatants() -> Array[BattleCombatant]:
	var out: Array[BattleCombatant] = []
	for c in _enemies:
		out.append(c.duplicate_combatant())
	return out


func get_party_count() -> int:
	return _party.size()


func get_enemy_count() -> int:
	return _enemies.size()


func clear() -> void:
	_active = false
	_stage_id = &""
	_area_id = &""
	_party.clear()
	_enemies.clear()


## Build full encounter from stage + party IDs. Fail closed; does not mutate self on failure.
static func build_from_session(
	area_id: StringName,
	stage_id: StringName,
	party_ids: Array[StringName],
	leader_id: StringName
) -> Dictionary:
	if String(area_id).is_empty() or String(stage_id).is_empty():
		return {"ok": false, "error": "empty session ids", "encounter": null}
	if party_ids.is_empty() or party_ids.size() > 3:
		return {"ok": false, "error": "invalid party size", "encounter": null}
	if party_ids[0] != leader_id:
		return {"ok": false, "error": "leader must be party index 0", "encounter": null}

	var stage_check: Dictionary = StageCatalog.find_stage(stage_id)
	if not bool(stage_check.get("ok", false)):
		return {"ok": false, "error": "stage not found", "encounter": null}
	var area_def: StageAreaDefinition = stage_check.get("area") as StageAreaDefinition
	if area_def == null or area_def.get_id() != area_id:
		return {"ok": false, "error": "stage/area mismatch", "encounter": null}

	var enc_link: Dictionary = StageEncounterCatalog.find_encounter(stage_id)
	if not bool(enc_link.get("ok", false)):
		return {"ok": false, "error": "stage encounter missing", "encounter": null}
	var link: StageEncounterDefinition = enc_link.get("encounter") as StageEncounterDefinition
	if link == null:
		return {"ok": false, "error": "stage encounter null", "encounter": null}

	var char_cat: Dictionary = CharacterCatalog.load_default()
	if not bool(char_cat.get("ok", false)):
		return {"ok": false, "error": "character catalog failed", "encounter": null}
	var char_by_id: Dictionary = {}
	for item in char_cat.get("characters", []):
		if item is CharacterDefinition:
			var cd: CharacterDefinition = item as CharacterDefinition
			char_by_id[cd.get_id()] = cd

	var party: Array[BattleCombatant] = []
	for i in party_ids.size():
		var cid: StringName = party_ids[i]
		if not char_by_id.has(cid):
			return {"ok": false, "error": "party character missing: %s" % str(cid), "encounter": null}
		var stats_res: Dictionary = CharacterCombatStatsCatalog.find_stats(cid)
		if not bool(stats_res.get("ok", false)):
			return {"ok": false, "error": "party combat stats missing: %s" % str(cid), "encounter": null}
		var stats: CharacterCombatStatsDefinition = stats_res.get("stats") as CharacterCombatStatsDefinition
		var cdef: CharacterDefinition = char_by_id[cid] as CharacterDefinition
		var is_leader: bool = i == 0
		party.append(
			BattleCombatant.new(
				BattleCombatant.SIDE_PARTY,
				cid,
				cdef.get_display_name(),
				i,
				stats.get_max_hp(),
				stats.get_max_hp(),
				stats.get_attack(),
				stats.get_defense(),
				is_leader
			)
		)

	var enemies: Array[BattleCombatant] = []
	var enemy_ids: Array[StringName] = link.get_enemy_ids()
	for i in enemy_ids.size():
		var eid: StringName = enemy_ids[i]
		var eres: Dictionary = EnemyCatalog.find_enemy(eid)
		if not bool(eres.get("ok", false)):
			return {"ok": false, "error": "enemy missing: %s" % str(eid), "encounter": null}
		var edef: EnemyDefinition = eres.get("enemy") as EnemyDefinition
		enemies.append(
			BattleCombatant.new(
				BattleCombatant.SIDE_ENEMY,
				eid,
				edef.get_display_name(),
				i,
				edef.get_max_hp(),
				edef.get_max_hp(),
				edef.get_attack(),
				edef.get_defense(),
				false
			)
		)

	var model := BattleEncounterModel.new()
	model._active = true
	model._stage_id = stage_id
	model._area_id = area_id
	model._party = party
	model._enemies = enemies
	return {"ok": true, "error": "", "encounter": model}


func capture_snapshot() -> Dictionary:
	var party_snaps: Array = []
	for c in _party:
		party_snaps.append(c.to_snapshot_dict())
	var enemy_snaps: Array = []
	for c in _enemies:
		enemy_snaps.append(c.to_snapshot_dict())
	return {
		"active": _active,
		"stage_id": _stage_id,
		"area_id": _area_id,
		"party": party_snaps,
		"enemies": enemy_snaps,
	}


static func validate_and_restore_snapshot(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {"ok": false, "error": "encounter snapshot not Dictionary", "encounter": null}
	var d: Dictionary = raw as Dictionary
	var keys: Array[String] = ["active", "stage_id", "area_id", "party", "enemies"]
	if d.size() != keys.size():
		return {"ok": false, "error": "encounter unexpected key set", "encounter": null}
	for k in keys:
		if not d.has(k):
			return {"ok": false, "error": "encounter missing %s" % k, "encounter": null}

	if typeof(d.get("active")) != TYPE_BOOL:
		return {"ok": false, "error": "encounter.active must be bool", "encounter": null}
	var active: bool = bool(d.get("active"))

	var stage_v: Variant = d.get("stage_id")
	var area_v: Variant = d.get("area_id")
	if typeof(stage_v) != TYPE_STRING_NAME or typeof(area_v) != TYPE_STRING_NAME:
		return {"ok": false, "error": "encounter stage/area must be StringName", "encounter": null}
	var stage_id: StringName = stage_v as StringName
	var area_id: StringName = area_v as StringName

	if not (d.get("party") is Array) or not (d.get("enemies") is Array):
		return {"ok": false, "error": "encounter party/enemies must be Array", "encounter": null}
	var party_raw: Array = d.get("party") as Array
	var enemy_raw: Array = d.get("enemies") as Array

	if not active:
		if not String(stage_id).is_empty() or not String(area_id).is_empty():
			return {"ok": false, "error": "inactive encounter requires empty ids", "encounter": null}
		if not party_raw.is_empty() or not enemy_raw.is_empty():
			return {"ok": false, "error": "inactive encounter requires empty combatants", "encounter": null}
		var empty := BattleEncounterModel.new()
		empty.clear()
		return {"ok": true, "error": "", "encounter": empty}

	if String(stage_id).is_empty() or String(area_id).is_empty():
		return {"ok": false, "error": "active encounter requires ids", "encounter": null}
	if party_raw.is_empty() or party_raw.size() > 3:
		return {"ok": false, "error": "active encounter invalid party size", "encounter": null}
	if enemy_raw.is_empty() or enemy_raw.size() > 3:
		return {"ok": false, "error": "active encounter invalid enemy size", "encounter": null}

	var party: Array[BattleCombatant] = []
	for i in party_raw.size():
		var cres: Dictionary = BattleCombatant.from_snapshot_dict(party_raw[i])
		if not bool(cres.get("ok", false)):
			return {"ok": false, "error": "party[%d]: %s" % [i, str(cres.get("error", ""))], "encounter": null}
		var c: BattleCombatant = cres.get("combatant") as BattleCombatant
		if c.get_side() != BattleCombatant.SIDE_PARTY:
			return {"ok": false, "error": "party[%d] wrong side" % i, "encounter": null}
		if c.get_slot_index() != i:
			return {"ok": false, "error": "party[%d] slot mismatch" % i, "encounter": null}
		party.append(c)
	if not party[0].is_leader():
		return {"ok": false, "error": "party leader required at slot 0", "encounter": null}

	var enemies: Array[BattleCombatant] = []
	for i in enemy_raw.size():
		var eres: Dictionary = BattleCombatant.from_snapshot_dict(enemy_raw[i])
		if not bool(eres.get("ok", false)):
			return {"ok": false, "error": "enemies[%d]: %s" % [i, str(eres.get("error", ""))], "encounter": null}
		var e: BattleCombatant = eres.get("combatant") as BattleCombatant
		if e.get_side() != BattleCombatant.SIDE_ENEMY:
			return {"ok": false, "error": "enemies[%d] wrong side" % i, "encounter": null}
		if e.get_slot_index() != i:
			return {"ok": false, "error": "enemies[%d] slot mismatch" % i, "encounter": null}
		enemies.append(e)

	var model := BattleEncounterModel.new()
	model._active = true
	model._stage_id = stage_id
	model._area_id = area_id
	model._party = party
	model._enemies = enemies
	return {"ok": true, "error": "", "encounter": model}


static func equals(a: BattleEncounterModel, b: BattleEncounterModel) -> bool:
	if a == null or b == null:
		return false
	if a.is_active() != b.is_active():
		return false
	if a.get_stage_id() != b.get_stage_id() or a.get_area_id() != b.get_area_id():
		return false
	var ap: Array[BattleCombatant] = a.get_party_combatants()
	var bp: Array[BattleCombatant] = b.get_party_combatants()
	if ap.size() != bp.size():
		return false
	for i in ap.size():
		if not BattleCombatant.equals(ap[i], bp[i]):
			return false
	var ae: Array[BattleCombatant] = a.get_enemy_combatants()
	var be: Array[BattleCombatant] = b.get_enemy_combatants()
	if ae.size() != be.size():
		return false
	for i in ae.size():
		if not BattleCombatant.equals(ae[i], be[i]):
			return false
	return true


func assign_from(other: BattleEncounterModel) -> void:
	clear()
	if other == null:
		return
	_active = other.is_active()
	_stage_id = other.get_stage_id()
	_area_id = other.get_area_id()
	for c in other.get_party_combatants():
		_party.append(c)
	for c in other.get_enemy_combatants():
		_enemies.append(c)
