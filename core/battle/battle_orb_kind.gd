## Development sample orb kinds for 1.0.0 board (no combat effects).
class_name BattleOrbKind
extends RefCounted

const EMBER: StringName = &"ember"
const TIDE: StringName = &"tide"
const LEAF: StringName = &"leaf"
const LIGHT: StringName = &"light"
const SHADOW: StringName = &"shadow"
const EMPTY: StringName = &""

const ALL: Array[StringName] = [EMBER, TIDE, LEAF, LIGHT, SHADOW]

const DISPLAY_NAMES: Dictionary = {
	EMBER: "炎珠",
	TIDE: "潮珠",
	LEAF: "葉珠",
	LIGHT: "光珠",
	SHADOW: "影珠",
}

const SYMBOLS: Dictionary = {
	EMBER: "炎",
	TIDE: "潮",
	LEAF: "葉",
	LIGHT: "光",
	SHADOW: "影",
}


static func is_valid(kind: StringName) -> bool:
	return kind == EMBER or kind == TIDE or kind == LEAF or kind == LIGHT or kind == SHADOW


static func is_empty(kind: StringName) -> bool:
	return String(kind).is_empty()


static func get_display_name(kind: StringName) -> String:
	if DISPLAY_NAMES.has(kind):
		return str(DISPLAY_NAMES[kind])
	return ""


static func get_symbol(kind: StringName) -> String:
	if SYMBOLS.has(kind):
		return str(SYMBOLS[kind])
	return "?"


static func all_kinds() -> Array[StringName]:
	return ALL.duplicate()
