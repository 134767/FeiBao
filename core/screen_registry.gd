## Central screen id → scene path + module metadata. Static only.
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

const PATH_MODULE_SCREEN: String = "res://scenes/screens/module/module_screen.tscn"

const _PATHS: Dictionary = {
	SCREEN_BOOT: "res://scenes/screens/boot/boot_screen.tscn",
	SCREEN_LOGIN: "res://scenes/screens/login/login_screen.tscn",
	SCREEN_LOBBY: "res://scenes/screens/lobby/lobby_screen.tscn",
	SCREEN_ADVENTURE: PATH_MODULE_SCREEN,
	SCREEN_CHARACTER: PATH_MODULE_SCREEN,
	SCREEN_PARTY: PATH_MODULE_SCREEN,
	SCREEN_INVENTORY: PATH_MODULE_SCREEN,
	SCREEN_FARM: PATH_MODULE_SCREEN,
	SCREEN_SETTINGS: PATH_MODULE_SCREEN,
}

## Display metadata only — no gameplay data.
const _META: Dictionary = {
	SCREEN_ADVENTURE: {
		"title": "冒險",
		"description": "冒險模組入口。正式關卡與戰鬥內容尚未實作。",
		"is_module": true,
	},
	SCREEN_CHARACTER: {
		"title": "角色",
		"description": "角色模組入口。角色資料與養成尚未實作。",
		"is_module": true,
	},
	SCREEN_PARTY: {
		"title": "隊伍",
		"description": "隊伍模組入口。編隊系統尚未實作。",
		"is_module": true,
	},
	SCREEN_INVENTORY: {
		"title": "背包",
		"description": "背包模組入口。物品與裝備尚未實作。",
		"is_module": true,
	},
	SCREEN_FARM: {
		"title": "農場",
		"description": "農場模組入口。種植與生產尚未實作。",
		"is_module": true,
	},
	SCREEN_SETTINGS: {
		"title": "設定",
		"description": "設定模組入口。選項與帳戶設定尚未實作。",
		"is_module": true,
	},
}


static func has_screen(screen_id: StringName) -> bool:
	if String(screen_id).is_empty():
		return false
	return _PATHS.has(screen_id)


static func get_scene_path(screen_id: StringName) -> String:
	if not has_screen(screen_id):
		return ""
	return str(_PATHS[screen_id])


static func get_registered_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in _PATHS.keys():
		ids.append(key as StringName)
	return ids


static func get_module_ids() -> Array[StringName]:
	var ids: Array[StringName] = [
		SCREEN_ADVENTURE,
		SCREEN_CHARACTER,
		SCREEN_PARTY,
		SCREEN_INVENTORY,
		SCREEN_FARM,
		SCREEN_SETTINGS,
	]
	return ids


static func is_module_screen(screen_id: StringName) -> bool:
	if not _META.has(screen_id):
		return false
	var meta: Dictionary = _META[screen_id] as Dictionary
	return bool(meta.get("is_module", false))


static func get_metadata(screen_id: StringName) -> Dictionary:
	if not _META.has(screen_id):
		return {}
	return (_META[screen_id] as Dictionary).duplicate(true)


static func get_title(screen_id: StringName) -> String:
	var meta: Dictionary = get_metadata(screen_id)
	if meta.has("title"):
		return str(meta["title"])
	return str(screen_id)


static func get_description(screen_id: StringName) -> String:
	var meta: Dictionary = get_metadata(screen_id)
	if meta.has("description"):
		return str(meta["description"])
	return ""


static func validate_resources() -> bool:
	for key in _PATHS.keys():
		var path: String = str(_PATHS[key])
		if path.is_empty() or not ResourceLoader.exists(path):
			push_error("ScreenRegistry: missing scene for '%s' at %s" % [str(key), path])
			return false
	for module_id in get_module_ids():
		if not has_screen(module_id):
			push_error("ScreenRegistry: module id not registered: %s" % str(module_id))
			return false
		if not is_module_screen(module_id):
			push_error("ScreenRegistry: module metadata missing: %s" % str(module_id))
			return false
	return true
