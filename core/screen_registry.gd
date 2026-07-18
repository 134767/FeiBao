## Central screen registry: path + title + kind + back_fallback.
class_name ScreenRegistry
extends RefCounted

const SCREEN_BOOT: StringName = &"boot"
const SCREEN_LOGIN: StringName = &"login"
const SCREEN_LOBBY: StringName = &"lobby"
const SCREEN_ADVENTURE: StringName = &"adventure"
const SCREEN_CHARACTER: StringName = &"character"
const SCREEN_PARTY: StringName = &"party"
const SCREEN_INVENTORY: StringName = &"inventory"
const SCREEN_FARM: StringName = &"farm"
const SCREEN_SETTINGS: StringName = &"settings"

const KIND_SYSTEM: StringName = &"system"
const KIND_AUTH: StringName = &"auth"
const KIND_HOME: StringName = &"home"
const KIND_MODULE: StringName = &"module"

const PATH_MODULE: String = "res://scenes/screens/module/module_screen.tscn"
const PATH_CHARACTER_SCREEN: String = "res://scenes/screens/character/character_screen.tscn"

## Fixed registration order (not Dictionary key order).
const _ORDERED_IDS: Array[StringName] = [
	SCREEN_BOOT,
	SCREEN_LOGIN,
	SCREEN_LOBBY,
	SCREEN_ADVENTURE,
	SCREEN_CHARACTER,
	SCREEN_PARTY,
	SCREEN_INVENTORY,
	SCREEN_FARM,
	SCREEN_SETTINGS,
]

const _MODULE_ORDER: Array[StringName] = [
	SCREEN_ADVENTURE,
	SCREEN_CHARACTER,
	SCREEN_PARTY,
	SCREEN_INVENTORY,
	SCREEN_FARM,
	SCREEN_SETTINGS,
]

const _SCREENS: Dictionary = {
	SCREEN_BOOT: {
		"path": "res://scenes/screens/boot/boot_screen.tscn",
		"title": "啟動",
		"kind": KIND_SYSTEM,
		"back_fallback": &"",
	},
	SCREEN_LOGIN: {
		"path": "res://scenes/screens/login/login_screen.tscn",
		"title": "登入",
		"kind": KIND_AUTH,
		"back_fallback": &"",
	},
	SCREEN_LOBBY: {
		"path": "res://scenes/screens/lobby/lobby_screen.tscn",
		"title": "大廳",
		"kind": KIND_HOME,
		"back_fallback": &"",
	},
	SCREEN_ADVENTURE: {
		"path": PATH_MODULE,
		"title": "冒險",
		"kind": KIND_MODULE,
		"back_fallback": SCREEN_LOBBY,
	},
	SCREEN_CHARACTER: {
		"path": PATH_CHARACTER_SCREEN,
		"title": "角色",
		"kind": KIND_MODULE,
		"back_fallback": SCREEN_LOBBY,
	},
	SCREEN_PARTY: {
		"path": PATH_MODULE,
		"title": "隊伍",
		"kind": KIND_MODULE,
		"back_fallback": SCREEN_LOBBY,
	},
	SCREEN_INVENTORY: {
		"path": PATH_MODULE,
		"title": "背包",
		"kind": KIND_MODULE,
		"back_fallback": SCREEN_LOBBY,
	},
	SCREEN_FARM: {
		"path": PATH_MODULE,
		"title": "農場",
		"kind": KIND_MODULE,
		"back_fallback": SCREEN_LOBBY,
	},
	SCREEN_SETTINGS: {
		"path": PATH_MODULE,
		"title": "設定",
		"kind": KIND_MODULE,
		"back_fallback": SCREEN_LOBBY,
	},
}


static func has_screen(screen_id: StringName) -> bool:
	if String(screen_id).is_empty():
		return false
	return _SCREENS.has(screen_id)


static func _entry(screen_id: StringName) -> Dictionary:
	if not has_screen(screen_id):
		return {}
	return _SCREENS[screen_id] as Dictionary


static func get_scene_path(screen_id: StringName) -> String:
	var entry: Dictionary = _entry(screen_id)
	if entry.is_empty():
		return ""
	return str(entry.get("path", ""))


static func get_display_title(screen_id: StringName) -> String:
	var entry: Dictionary = _entry(screen_id)
	if entry.is_empty():
		return ""
	return str(entry.get("title", ""))


static func get_kind(screen_id: StringName) -> StringName:
	var entry: Dictionary = _entry(screen_id)
	if entry.is_empty():
		return &""
	return entry.get("kind", &"") as StringName


static func get_back_fallback(screen_id: StringName) -> StringName:
	var entry: Dictionary = _entry(screen_id)
	if entry.is_empty():
		return &""
	return entry.get("back_fallback", &"") as StringName


static func get_registered_ids() -> Array[StringName]:
	return _ORDERED_IDS.duplicate()


static func get_module_ids() -> Array[StringName]:
	return _MODULE_ORDER.duplicate()


static func is_module(screen_id: StringName) -> bool:
	return get_kind(screen_id) == KIND_MODULE


## Compatibility alias used by intermediate code/tests.
static func is_module_screen(screen_id: StringName) -> bool:
	return is_module(screen_id)


static func get_title(screen_id: StringName) -> String:
	return get_display_title(screen_id)


static func validate_metadata() -> bool:
	if _ORDERED_IDS.size() != 9:
		push_error("ScreenRegistry: expected 9 registered screens")
		return false
	if _MODULE_ORDER.size() != 6:
		push_error("ScreenRegistry: expected 6 modules")
		return false

	for screen_id in _ORDERED_IDS:
		if not _SCREENS.has(screen_id):
			push_error("ScreenRegistry: missing entry for %s" % str(screen_id))
			return false
		var entry: Dictionary = _SCREENS[screen_id] as Dictionary
		if not entry.has("path") or str(entry["path"]).is_empty():
			push_error("ScreenRegistry: invalid path for %s" % str(screen_id))
			return false
		if not entry.has("title") or str(entry["title"]).is_empty():
			push_error("ScreenRegistry: invalid title for %s" % str(screen_id))
			return false
		if not entry.has("kind") or String(entry["kind"] as StringName).is_empty():
			push_error("ScreenRegistry: invalid kind for %s" % str(screen_id))
			return false
		if not entry.has("back_fallback"):
			push_error("ScreenRegistry: missing back_fallback for %s" % str(screen_id))
			return false
		var fallback: StringName = entry["back_fallback"] as StringName
		if not String(fallback).is_empty() and not has_screen(fallback):
			push_error("ScreenRegistry: fallback not registered for %s -> %s" % [str(screen_id), str(fallback)])
			return false
		if fallback == screen_id:
			push_error("ScreenRegistry: self fallback forbidden for %s" % str(screen_id))
			return false

	for module_id in _MODULE_ORDER:
		if get_kind(module_id) != KIND_MODULE:
			push_error("ScreenRegistry: module kind mismatch: %s" % str(module_id))
			return false
		if get_back_fallback(module_id) != SCREEN_LOBBY:
			push_error("ScreenRegistry: module fallback must be lobby: %s" % str(module_id))
			return false
		var module_path: String = get_scene_path(module_id)
		if module_path.is_empty():
			push_error("ScreenRegistry: empty module path: %s" % str(module_id))
			return false
		# Character uses a dedicated catalog screen; other modules stay on shared placeholder.
		if module_id == SCREEN_CHARACTER:
			if module_path != PATH_CHARACTER_SCREEN:
				push_error("ScreenRegistry: character must use dedicated path")
				return false
		elif module_path != PATH_MODULE:
			push_error("ScreenRegistry: placeholder module path must be shared ModuleScreen: %s" % str(module_id))
			return false

	if get_kind(SCREEN_BOOT) != KIND_SYSTEM:
		push_error("ScreenRegistry: boot kind must be system")
		return false
	if get_kind(SCREEN_LOGIN) != KIND_AUTH:
		push_error("ScreenRegistry: login kind must be auth")
		return false
	if get_kind(SCREEN_LOBBY) != KIND_HOME:
		push_error("ScreenRegistry: lobby kind must be home")
		return false

	return true


static func validate_resources() -> bool:
	for screen_id in _ORDERED_IDS:
		var path: String = get_scene_path(screen_id)
		if path.is_empty() or not ResourceLoader.exists(path):
			push_error("ScreenRegistry: missing scene for '%s' at %s" % [str(screen_id), path])
			return false
	return true
