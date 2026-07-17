## Application entry: loads GameShell once. Does not load Login/Lobby directly.
extends Node

const GAME_SHELL_SCENE: String = "res://scenes/shell/game_shell.tscn"

var _shell: Node = null


func _ready() -> void:
	AppState.set_phase(AppState.Phase.BOOTSTRAP)
	_load_game_shell()


func _load_game_shell() -> void:
	if _shell != null and is_instance_valid(_shell):
		return

	if not ResourceLoader.exists(GAME_SHELL_SCENE):
		push_error("Bootstrap: GameShell scene missing: %s" % GAME_SHELL_SCENE)
		return

	var packed: PackedScene = load(GAME_SHELL_SCENE) as PackedScene
	if packed == null:
		push_error("Bootstrap: failed to load GameShell resource: %s" % GAME_SHELL_SCENE)
		return

	var shell: Node = packed.instantiate()
	if shell == null:
		push_error("Bootstrap: failed to instantiate GameShell: %s" % GAME_SHELL_SCENE)
		return

	add_child(shell)
	_shell = shell


func get_game_shell() -> Node:
	return _shell
