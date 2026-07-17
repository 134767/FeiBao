## Central screen id → scene path map. Static only; no autoload required.
class_name ScreenRegistry
extends RefCounted

const SCREEN_BOOT: StringName = &"boot"
const SCREEN_LOGIN: StringName = &"login"
const SCREEN_LOBBY: StringName = &"lobby"

const _PATHS: Dictionary = {
	SCREEN_BOOT: "res://scenes/screens/boot/boot_screen.tscn",
	SCREEN_LOGIN: "res://scenes/screens/login/login_screen.tscn",
	SCREEN_LOBBY: "res://scenes/screens/lobby/lobby_screen.tscn",
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


static func validate_resources() -> bool:
	for key in _PATHS.keys():
		var path: String = str(_PATHS[key])
		if path.is_empty() or not ResourceLoader.exists(path):
			push_error("ScreenRegistry: missing scene for '%s' at %s" % [str(key), path])
			return false
	return true
