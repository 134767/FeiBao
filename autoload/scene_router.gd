## Centralized scene switching with safe failure handling.
extends Node

var _is_changing: bool = false


## Change to the scene at [param path]. Returns true on success, false on failure.
func change_scene(path: String) -> bool:
	if path.is_empty():
		push_error("SceneRouter: empty scene path")
		return false

	if _is_changing:
		push_error("SceneRouter: scene change already in progress")
		return false

	if not ResourceLoader.exists(path):
		push_error("SceneRouter: scene does not exist: %s" % path)
		return false

	_is_changing = true
	var err: Error = get_tree().change_scene_to_file(path)
	_is_changing = false

	if err != OK:
		push_error(
			"SceneRouter: failed to change scene '%s' (error %s)" % [path, error_string(err)]
		)
		return false

	return true


## Returns whether a scene change is currently in progress.
func is_changing() -> bool:
	return _is_changing
