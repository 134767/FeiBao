## Shared project constants for FeiBao.
class_name FeiBaoConstants
extends RefCounted

const APP_NAME: String = "FeiBao"
const APP_VERSION: String = "0.3.0"
const DESIGN_WIDTH: int = 720
const DESIGN_HEIGHT: int = 1280
const ORIENTATION: String = "portrait"
const DATA_VERSION: int = 1

const PATH_BOOTSTRAP: String = "res://scenes/bootstrap/bootstrap.tscn"
const PATH_GAME_SHELL: String = "res://scenes/shell/game_shell.tscn"
const PATH_GAME_CONFIG: String = "res://data/game_config.json"
const PATH_THEME: String = "res://ui/themes/feibao_theme.tres"
const PATH_MODULE_SCREEN: String = "res://scenes/screens/module/module_screen.tscn"

const PLAYER_NAME_MIN_LENGTH: int = 1
const PLAYER_NAME_MAX_LENGTH: int = 12
