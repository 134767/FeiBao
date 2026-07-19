## FeiBao original affinity kinds (pure domain — no UI dependency).
class_name BattleAffinity
extends RefCounted

const EMBER: StringName = &"ember"
const TIDE: StringName = &"tide"
const LEAF: StringName = &"leaf"
const LIGHT: StringName = &"light"
const SHADOW: StringName = &"shadow"

const ALL: Array[StringName] = [EMBER, TIDE, LEAF, LIGHT, SHADOW]

const DISPLAY_NAMES: Dictionary = {
	EMBER: "炎",
	TIDE: "潮",
	LEAF: "葉",
	LIGHT: "光",
	SHADOW: "影",
}

## Geometric Unicode placeholders — distinguishable without color.
const SYMBOLS: Dictionary = {
	EMBER: "▲",
	TIDE: "●",
	LEAF: "◆",
	LIGHT: "✦",
	SHADOW: "■",
}


static func all() -> Array[StringName]:
	return ALL.duplicate()


static func is_valid(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING_NAME:
		return false
	var v: StringName = value as StringName
	return v == EMBER or v == TIDE or v == LEAF or v == LIGHT or v == SHADOW


static func display_name(value: Variant) -> String:
	if not is_valid(value):
		return ""
	return str(DISPLAY_NAMES.get(value as StringName, ""))


static func symbol(value: Variant) -> String:
	if not is_valid(value):
		return ""
	return str(SYMBOLS.get(value as StringName, ""))
