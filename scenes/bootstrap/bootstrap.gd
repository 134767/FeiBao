## Application entry scene. Loads FoundationScreen once on startup.
extends Node

const FOUNDATION_SCENE: String = "res://scenes/ui/foundation_screen.tscn"


func _ready() -> void:
	AppState.set_phase(AppState.Phase.BOOTSTRAP)
	_load_foundation_screen()


func _load_foundation_screen() -> void:
	if not ResourceLoader.exists(FOUNDATION_SCENE):
		push_error("Bootstrap: foundation scene missing: %s" % FOUNDATION_SCENE)
		return

	var packed: PackedScene = load(FOUNDATION_SCENE) as PackedScene
	if packed == null:
		push_error("Bootstrap: failed to load foundation scene resource: %s" % FOUNDATION_SCENE)
		return

	var screen: Node = packed.instantiate()
	if screen == null:
		push_error("Bootstrap: failed to instantiate foundation scene: %s" % FOUNDATION_SCENE)
		return

	add_child(screen)
	AppState.set_phase(AppState.Phase.FOUNDATION)
