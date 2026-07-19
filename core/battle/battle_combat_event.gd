## Pure data combat events for player attack / enemy HP changes (no Node / UI).
## Strict scalar schema: StringName type/ids/affinity, TYPE_INT numbers, TYPE_BOOL defeated.
class_name BattleCombatEvent
extends RefCounted

const TYPE_PLAYER_DAMAGE: StringName = &"player_damage"
const TYPE_PLAYER_COMBAT_COMPLETED: StringName = &"player_combat_completed"

const KNOWN_TYPES: Array[StringName] = [
	TYPE_PLAYER_DAMAGE,
	TYPE_PLAYER_COMBAT_COMPLETED,
]

const KEYS_PLAYER_DAMAGE: Array[String] = [
	"type",
	"turn_count",
	"attacker_id",
	"target_id",
	"affinity",
	"cleared_orb_count",
	"attacker_attack",
	"target_defense",
	"calculated_damage",
	"actual_damage",
	"hp_before",
	"hp_after",
]

const KEYS_PLAYER_COMBAT_COMPLETED: Array[String] = [
	"type",
	"turn_count",
	"attack_count",
	"total_damage",
	"target_id",
	"target_hp_before",
	"target_hp_after",
	"target_defeated",
]


static func make_player_damage(
	turn_count: int,
	attacker_id: StringName,
	target_id: StringName,
	affinity: StringName,
	cleared_orb_count: int,
	attacker_attack: int,
	target_defense: int,
	calculated_damage: int,
	actual_damage: int,
	hp_before: int,
	hp_after: int
) -> Dictionary:
	return {
		"type": TYPE_PLAYER_DAMAGE,
		"turn_count": turn_count,
		"attacker_id": attacker_id,
		"target_id": target_id,
		"affinity": affinity,
		"cleared_orb_count": cleared_orb_count,
		"attacker_attack": attacker_attack,
		"target_defense": target_defense,
		"calculated_damage": calculated_damage,
		"actual_damage": actual_damage,
		"hp_before": hp_before,
		"hp_after": hp_after,
	}


static func make_player_combat_completed(
	turn_count: int,
	attack_count: int,
	total_damage: int,
	target_id: StringName,
	target_hp_before: int,
	target_hp_after: int,
	target_defeated: bool
) -> Dictionary:
	return {
		"type": TYPE_PLAYER_COMBAT_COMPLETED,
		"turn_count": turn_count,
		"attack_count": attack_count,
		"total_damage": total_damage,
		"target_id": target_id,
		"target_hp_before": target_hp_before,
		"target_hp_after": target_hp_after,
		"target_defeated": target_defeated,
	}


static func duplicate_events(events: Array) -> Array:
	var out: Array = []
	for e in events:
		if e is Dictionary:
			out.append((e as Dictionary).duplicate(true))
	return out


static func validate_event(event: Variant) -> Dictionary:
	if not (event is Dictionary):
		return {"ok": false, "error": "event is not Dictionary"}
	var d: Dictionary = event as Dictionary
	if not d.has("type"):
		return {"ok": false, "error": "missing type"}
	for k in d.keys():
		var v: Variant = d[k]
		if v is Object or v is Callable:
			return {"ok": false, "error": "forbidden reference payload"}
	var type_v: Variant = d.get("type")
	if typeof(type_v) != TYPE_STRING_NAME:
		return {"ok": false, "error": "type must be StringName"}
	var t: StringName = type_v as StringName
	if not KNOWN_TYPES.has(t):
		return {"ok": false, "error": "unknown event type"}
	match t:
		TYPE_PLAYER_DAMAGE:
			return _validate_player_damage(d)
		TYPE_PLAYER_COMBAT_COMPLETED:
			return _validate_player_combat_completed(d)
		_:
			return {"ok": false, "error": "unknown event type"}


static func validate_events(events: Variant) -> Dictionary:
	if events == null:
		return {"ok": false, "error": "events must be Array", "events": []}
	if not (events is Array):
		return {"ok": false, "error": "events must be Array", "events": []}
	var arr: Array = events as Array
	if arr.is_empty():
		return {"ok": true, "error": "", "events": []}
	if arr.size() > 4:
		return {"ok": false, "error": "too many combat events", "events": []}
	var normalized: Array = []
	for i in arr.size():
		var item: Variant = arr[i]
		if not (item is Dictionary):
			return {"ok": false, "error": "event[%d]: not Dictionary" % i, "events": []}
		var one: Dictionary = validate_event(item)
		if not bool(one.get("ok", false)):
			return {
				"ok": false,
				"error": "event[%d]: %s" % [i, str(one.get("error", "invalid"))],
				"events": [],
			}
		normalized.append((item as Dictionary).duplicate(true))
	var seq: Dictionary = _validate_sequence(normalized)
	if not bool(seq.get("ok", false)):
		return {"ok": false, "error": str(seq.get("error", "invalid sequence")), "events": []}
	return {"ok": true, "error": "", "events": normalized}


static func events_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not event_equal(a[i], b[i]):
			return false
	return true


static func event_equal(a: Variant, b: Variant) -> bool:
	var va: Dictionary = validate_event(a)
	var vb: Dictionary = validate_event(b)
	if not bool(va.get("ok", false)) or not bool(vb.get("ok", false)):
		return false
	var da: Dictionary = a as Dictionary
	var db: Dictionary = b as Dictionary
	var ta: StringName = da.get("type") as StringName
	var tb: StringName = db.get("type") as StringName
	if ta != tb:
		return false
	match ta:
		TYPE_PLAYER_DAMAGE:
			for k in KEYS_PLAYER_DAMAGE:
				if k == "type":
					continue
				if da.get(k) != db.get(k):
					return false
			return true
		TYPE_PLAYER_COMBAT_COMPLETED:
			for k in KEYS_PLAYER_COMBAT_COMPLETED:
				if k == "type":
					continue
				if da.get(k) != db.get(k):
					return false
			return true
		_:
			return false


static func _validate_player_damage(d: Dictionary) -> Dictionary:
	var keys_err: String = _exact_keys(d, KEYS_PLAYER_DAMAGE)
	if not keys_err.is_empty():
		return {"ok": false, "error": keys_err}
	if typeof(d.get("attacker_id")) != TYPE_STRING_NAME:
		return {"ok": false, "error": "attacker_id must be StringName"}
	if typeof(d.get("target_id")) != TYPE_STRING_NAME:
		return {"ok": false, "error": "target_id must be StringName"}
	if String(d.get("attacker_id") as StringName).is_empty():
		return {"ok": false, "error": "attacker_id empty"}
	if String(d.get("target_id") as StringName).is_empty():
		return {"ok": false, "error": "target_id empty"}
	if typeof(d.get("affinity")) != TYPE_STRING_NAME or not BattleAffinity.is_valid(d.get("affinity")):
		return {"ok": false, "error": "invalid affinity"}
	for field in [
		"turn_count",
		"cleared_orb_count",
		"attacker_attack",
		"target_defense",
		"calculated_damage",
		"actual_damage",
		"hp_before",
		"hp_after",
	]:
		if typeof(d.get(field)) != TYPE_INT:
			return {"ok": false, "error": "%s must be TYPE_INT" % field}
	var turn_count: int = d.get("turn_count") as int
	var cleared: int = d.get("cleared_orb_count") as int
	var atk: int = d.get("attacker_attack") as int
	var defense: int = d.get("target_defense") as int
	var calc: int = d.get("calculated_damage") as int
	var actual: int = d.get("actual_damage") as int
	var hp_before: int = d.get("hp_before") as int
	var hp_after: int = d.get("hp_after") as int
	if turn_count < 1:
		return {"ok": false, "error": "turn_count must be >= 1"}
	if cleared < 3:
		return {"ok": false, "error": "cleared_orb_count must be >= 3"}
	if atk < 0 or defense < 0:
		return {"ok": false, "error": "attack/defense negative"}
	if calc < 1:
		return {"ok": false, "error": "calculated_damage must be >= 1"}
	if actual < 0:
		return {"ok": false, "error": "actual_damage negative"}
	if hp_before < 1:
		return {"ok": false, "error": "player_damage requires hp_before > 0"}
	if hp_after < 0:
		return {"ok": false, "error": "hp negative"}
	if hp_after > hp_before:
		return {"ok": false, "error": "hp_after > hp_before"}
	if actual != hp_before - hp_after:
		return {"ok": false, "error": "actual_damage != hp_before - hp_after"}
	# Must apply exact min(calculated, hp_before) — no under-damage.
	var expected_actual: int = mini(calc, hp_before)
	if actual != expected_actual:
		return {"ok": false, "error": "actual_damage != min(calculated_damage, hp_before)"}
	return {"ok": true, "error": ""}


static func _validate_player_combat_completed(d: Dictionary) -> Dictionary:
	var keys_err: String = _exact_keys(d, KEYS_PLAYER_COMBAT_COMPLETED)
	if not keys_err.is_empty():
		return {"ok": false, "error": keys_err}
	if typeof(d.get("target_id")) != TYPE_STRING_NAME:
		return {"ok": false, "error": "target_id must be StringName"}
	if String(d.get("target_id") as StringName).is_empty():
		return {"ok": false, "error": "target_id empty"}
	for field in [
		"turn_count",
		"attack_count",
		"total_damage",
		"target_hp_before",
		"target_hp_after",
	]:
		if typeof(d.get(field)) != TYPE_INT:
			return {"ok": false, "error": "%s must be TYPE_INT" % field}
	if typeof(d.get("target_defeated")) != TYPE_BOOL:
		return {"ok": false, "error": "target_defeated must be TYPE_BOOL"}
	var turn_count: int = d.get("turn_count") as int
	var attack_count: int = d.get("attack_count") as int
	var total_damage: int = d.get("total_damage") as int
	var hp_before: int = d.get("target_hp_before") as int
	var hp_after: int = d.get("target_hp_after") as int
	var defeated: bool = d.get("target_defeated") as bool
	if turn_count < 1:
		return {"ok": false, "error": "turn_count must be >= 1"}
	if attack_count < 0:
		return {"ok": false, "error": "attack_count negative"}
	if total_damage < 0:
		return {"ok": false, "error": "total_damage negative"}
	if hp_before < 0 or hp_after < 0:
		return {"ok": false, "error": "target hp negative"}
	if hp_after > hp_before:
		return {"ok": false, "error": "target_hp_after > target_hp_before"}
	if defeated != (hp_after == 0):
		return {"ok": false, "error": "target_defeated mismatch"}
	# Summary total must equal HP delta for all cases.
	if total_damage != hp_before - hp_after:
		return {"ok": false, "error": "total_damage != target_hp_before - target_hp_after"}
	return {"ok": true, "error": ""}


static func _validate_sequence(events: Array) -> Dictionary:
	if events.is_empty():
		return {"ok": true, "error": ""}
	var last: Dictionary = events[events.size() - 1] as Dictionary
	if (last.get("type") as StringName) != TYPE_PLAYER_COMBAT_COMPLETED:
		return {"ok": false, "error": "sequence must end with player_combat_completed"}
	var damage_count: int = 0
	var total_actual: int = 0
	var turn_count: int = last.get("turn_count") as int
	var target_id: StringName = last.get("target_id") as StringName
	var chain_hp: int = -1
	var first_hp_before: int = last.get("target_hp_before") as int
	for i in events.size() - 1:
		var e: Dictionary = events[i] as Dictionary
		if (e.get("type") as StringName) != TYPE_PLAYER_DAMAGE:
			return {"ok": false, "error": "only player_damage allowed before summary"}
		if (e.get("turn_count") as int) != turn_count:
			return {"ok": false, "error": "turn_count mismatch in sequence"}
		if (e.get("target_id") as StringName) != target_id:
			return {"ok": false, "error": "target_id mismatch in sequence"}
		var hp_b: int = e.get("hp_before") as int
		var hp_a: int = e.get("hp_after") as int
		if damage_count == 0:
			if hp_b != first_hp_before:
				return {"ok": false, "error": "first hp_before != summary target_hp_before"}
		else:
			if hp_b != chain_hp:
				return {"ok": false, "error": "HP chain discontinuous"}
		chain_hp = hp_a
		total_actual += e.get("actual_damage") as int
		damage_count += 1
	if damage_count > 3:
		return {"ok": false, "error": "more than 3 player_damage events"}
	var sum_attack: int = last.get("attack_count") as int
	var sum_total: int = last.get("total_damage") as int
	var sum_before: int = last.get("target_hp_before") as int
	var sum_after: int = last.get("target_hp_after") as int
	if sum_attack != damage_count:
		return {"ok": false, "error": "summary attack_count mismatch"}
	if sum_total != total_actual:
		return {"ok": false, "error": "summary total_damage mismatch"}
	if sum_total != sum_before - sum_after:
		return {"ok": false, "error": "summary total_damage != HP delta"}
	if damage_count == 0:
		if sum_total != 0:
			return {"ok": false, "error": "zero attack total_damage must be 0"}
		if sum_before != sum_after:
			return {"ok": false, "error": "zero attack requires target_hp_before == target_hp_after"}
		if bool(last.get("target_defeated")) != (sum_after == 0):
			return {"ok": false, "error": "zero attack target_defeated mismatch"}
	else:
		if sum_before <= sum_after:
			return {"ok": false, "error": "attack sequence requires HP decrease"}
		if sum_total < 1:
			return {"ok": false, "error": "attack sequence total_damage must be > 0"}
		if chain_hp != sum_after:
			return {"ok": false, "error": "summary target_hp_after != chain end"}
		if first_hp_before != sum_before:
			return {"ok": false, "error": "summary target_hp_before mismatch"}
	return {"ok": true, "error": ""}


static func _exact_keys(d: Dictionary, required: Array[String]) -> String:
	if d.size() != required.size():
		return "unexpected key set size"
	for k in required:
		if not d.has(k):
			return "missing key %s" % k
	for k in d.keys():
		var ks: String = k as String if typeof(k) == TYPE_STRING else String(k)
		if not required.has(ks):
			return "unexpected key %s" % ks
	return ""
