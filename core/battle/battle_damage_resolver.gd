## Pure deterministic player-turn damage resolver (no Runtime mutation, no signals, no PlayerData).
class_name BattleDamageResolver
extends RefCounted

## Test-only failure seam. Production UI must never call.
static var _force_fail_for_tests: bool = false


static func set_force_fail_for_tests(enabled: bool) -> void:
	_force_fail_for_tests = enabled


static func clear_force_fail_for_tests() -> void:
	_force_fail_for_tests = false


static func is_force_fail_for_tests() -> bool:
	return _force_fail_for_tests


static func resolve_player_turn(
	board_events: Array,
	encounter: BattleEncounterModel,
	turn_count: int
) -> Dictionary:
	var fail: Dictionary = {
		"ok": false,
		"error": "",
		"encounter": null,
		"combat_events": [],
		"attack_count": 0,
		"total_damage": 0,
	}
	if _force_fail_for_tests:
		fail["error"] = "forced resolver failure for tests"
		return fail
	if typeof(turn_count) != TYPE_INT or turn_count < 1:
		fail["error"] = "invalid turn_count"
		return fail
	if encounter == null or not encounter.is_valid():
		fail["error"] = "invalid encounter"
		return fail

	var players: Array[BattleCombatantModel] = encounter.get_player_combatants()
	var enemies: Array[BattleCombatantModel] = encounter.get_enemy_combatants()
	if players.is_empty() or players.size() > 3:
		fail["error"] = "invalid player count"
		return fail
	if enemies.is_empty() or enemies.size() > 3:
		fail["error"] = "invalid enemy count"
		return fail
	var aei: int = encounter.get_active_enemy_index()
	if aei < 0 or aei >= enemies.size():
		fail["error"] = "invalid active enemy index"
		return fail

	# Derive match/cascade counts from sequence for full validation.
	var last_match: int = 0
	var last_cascade: int = 0
	if board_events is Array and not (board_events as Array).is_empty():
		var raw_arr: Array = board_events as Array
		var last_ev: Variant = raw_arr[raw_arr.size() - 1]
		if last_ev is Dictionary:
			var ld: Dictionary = last_ev as Dictionary
			if (ld.get("type") as StringName) == BattleResolutionEvent.TYPE_TURN_COMPLETED:
				if typeof(ld.get("cleared_cell_count")) == TYPE_INT:
					last_match = ld.get("cleared_cell_count") as int
				if typeof(ld.get("cascade_count")) == TYPE_INT:
					last_cascade = ld.get("cascade_count") as int
	var board_check: Dictionary = BattleResolutionEvent.validate_events_with_counts(
		board_events, last_match, last_cascade
	)
	if not bool(board_check.get("ok", false)):
		fail["error"] = "invalid board events: %s" % str(board_check.get("error", ""))
		return fail
	var events: Array = board_check.get("events", []) as Array
	if events.is_empty():
		fail["error"] = "board events empty"
		return fail
	var first_type: StringName = (events[0] as Dictionary).get("type") as StringName
	if first_type == BattleResolutionEvent.TYPE_SWAP_REJECTED:
		fail["error"] = "rejected swap sequence not resolvable"
		return fail
	var last: Dictionary = events[events.size() - 1] as Dictionary
	if (last.get("type") as StringName) != BattleResolutionEvent.TYPE_TURN_COMPLETED:
		fail["error"] = "sequence must end with turn_completed"
		return fail
	if (last.get("turn_count") as int) != turn_count:
		fail["error"] = "turn_completed.turn_count mismatch"
		return fail

	var affinity_counts: Dictionary = _aggregate_affinity_counts(events)
	if not bool(affinity_counts.get("ok", false)):
		fail["error"] = str(affinity_counts.get("error", "affinity aggregate failed"))
		return fail
	var counts: Dictionary = affinity_counts.get("counts", {}) as Dictionary

	# Candidate encounter (never mutate input).
	var snap: Dictionary = encounter.capture_snapshot()
	var restored: Dictionary = BattleEncounterModel.restore_snapshot(snap)
	if not bool(restored.get("ok", false)):
		fail["error"] = "candidate encounter restore failed"
		return fail
	var candidate: BattleEncounterModel = restored.get("encounter") as BattleEncounterModel
	if candidate == null or not candidate.is_valid():
		fail["error"] = "candidate encounter invalid"
		return fail

	var target: BattleCombatantModel = candidate.get_active_enemy()
	if target == null:
		fail["error"] = "active enemy missing"
		return fail
	var target_id: StringName = target.get_source_id()
	var target_defense: int = target.get_defense()
	var hp_start: int = target.get_current_hp()
	var combat_events: Array = []
	var attack_count: int = 0
	var total_damage: int = 0

	# Already defeated: no damage events, still emit summary.
	if hp_start <= 0:
		var summary0: Dictionary = BattleCombatEvent.make_player_combat_completed(
			turn_count, 0, 0, target_id, 0, 0, true
		)
		var v0: Dictionary = BattleCombatEvent.validate_events([summary0])
		if not bool(v0.get("ok", false)):
			fail["error"] = "combat event validation failed: %s" % str(v0.get("error", ""))
			return fail
		return {
			"ok": true,
			"error": "",
			"encounter": candidate,
			"combat_events": v0.get("events", []) as Array,
			"attack_count": 0,
			"total_damage": 0,
		}

	var cand_players: Array[BattleCombatantModel] = candidate.get_player_combatants()
	for p in cand_players:
		var cur_target: BattleCombatantModel = candidate.get_active_enemy()
		if cur_target == null or cur_target.get_current_hp() <= 0:
			break
		var aff: StringName = p.get_affinity()
		var cleared: int = int(counts.get(aff, 0))
		if cleared < 3:
			continue
		var atk: int = p.get_attack()
		var scaled: int = int(floor(float(atk * cleared) / 3.0))
		var calculated: int = maxi(1, scaled - target_defense)
		var hp_before: int = cur_target.get_current_hp()
		var apply_res: Dictionary = candidate.apply_damage_to_active_enemy(calculated)
		if not bool(apply_res.get("ok", false)):
			fail["error"] = "apply_damage failed: %s" % str(apply_res.get("error", ""))
			return fail
		var actual: int = int(apply_res.get("actual_damage", 0))
		var hp_after: int = int(apply_res.get("hp_after", hp_before))
		var dmg_ev: Dictionary = BattleCombatEvent.make_player_damage(
			turn_count,
			p.get_source_id(),
			target_id,
			aff,
			cleared,
			atk,
			target_defense,
			calculated,
			actual,
			hp_before,
			hp_after
		)
		combat_events.append(dmg_ev)
		attack_count += 1
		total_damage += actual

	var final_target: BattleCombatantModel = candidate.get_active_enemy()
	var hp_end: int = final_target.get_current_hp() if final_target != null else 0
	var summary: Dictionary = BattleCombatEvent.make_player_combat_completed(
		turn_count,
		attack_count,
		total_damage,
		target_id,
		hp_start,
		hp_end,
		hp_end == 0
	)
	combat_events.append(summary)
	var v: Dictionary = BattleCombatEvent.validate_events(combat_events)
	if not bool(v.get("ok", false)):
		fail["error"] = "combat event validation failed: %s" % str(v.get("error", ""))
		return fail
	return {
		"ok": true,
		"error": "",
		"encounter": candidate,
		"combat_events": v.get("events", []) as Array,
		"attack_count": attack_count,
		"total_damage": total_damage,
	}


## Aggregate cleared orb kinds across the whole accepted turn (no combo/cascade multipliers).
static func aggregate_affinity_counts_for_tests(board_events: Array) -> Dictionary:
	return _aggregate_affinity_counts(board_events)


static func _aggregate_affinity_counts(board_events: Array) -> Dictionary:
	var counts: Dictionary = {}
	for aff in BattleAffinity.ALL:
		counts[aff] = 0
	for e in board_events:
		if not (e is Dictionary):
			continue
		var d: Dictionary = e as Dictionary
		if (d.get("type") as StringName) != BattleResolutionEvent.TYPE_CELLS_CLEARED:
			continue
		var cells: Array = d.get("cells", []) as Array
		var kinds: Array = d.get("orb_kinds", []) as Array
		if cells.size() != kinds.size():
			return {"ok": false, "error": "cells/orb_kinds length mismatch", "counts": {}}
		for k in kinds:
			if typeof(k) != TYPE_STRING_NAME:
				return {"ok": false, "error": "orb_kinds item not StringName", "counts": {}}
			var kind: StringName = k as StringName
			if not BattleOrbKind.is_valid(kind):
				return {"ok": false, "error": "invalid orb kind", "counts": {}}
			# Orb kind == affinity id (ember/tide/leaf/light/shadow).
			if not BattleAffinity.is_valid(kind):
				return {"ok": false, "error": "orb kind not affinity", "counts": {}}
			counts[kind] = int(counts.get(kind, 0)) + 1
	return {"ok": true, "error": "", "counts": counts}
