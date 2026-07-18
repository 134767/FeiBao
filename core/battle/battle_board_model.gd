## Pure 6×5 board model. No SceneTree / UI / I/O.
class_name BattleBoardModel
extends RefCounted

const WIDTH: int = 6
const HEIGHT: int = 5
const CELL_COUNT: int = WIDTH * HEIGHT

var _cells: Array[StringName] = []


func _init(cells: Array = []) -> void:
	if cells.is_empty():
		_cells.resize(CELL_COUNT)
		for i in CELL_COUNT:
			_cells[i] = BattleOrbKind.EMPTY
	else:
		set_cells(cells)


static func index_of(x: int, y: int) -> int:
	return y * WIDTH + x


static func xy_of(index: int) -> Vector2i:
	return Vector2i(index % WIDTH, int(index / float(WIDTH)))


static func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT


static func index_in_bounds(index: int) -> bool:
	return index >= 0 and index < CELL_COUNT


func get_width() -> int:
	return WIDTH


func get_height() -> int:
	return HEIGHT


func get_cell_count() -> int:
	return CELL_COUNT


func get_cells() -> Array[StringName]:
	return _cells.duplicate()


func set_cells(cells: Array) -> bool:
	if cells.size() != CELL_COUNT:
		return false
	var next: Array[StringName] = []
	next.resize(CELL_COUNT)
	for i in CELL_COUNT:
		var k: StringName = cells[i] as StringName
		if not BattleOrbKind.is_empty(k) and not BattleOrbKind.is_valid(k):
			return false
		next[i] = k
	_cells = next
	return true


func get_cell(x: int, y: int) -> StringName:
	if not in_bounds(x, y):
		return BattleOrbKind.EMPTY
	return _cells[index_of(x, y)]


func set_cell(x: int, y: int, kind: StringName) -> bool:
	if not in_bounds(x, y):
		return false
	if not BattleOrbKind.is_empty(kind) and not BattleOrbKind.is_valid(kind):
		return false
	_cells[index_of(x, y)] = kind
	return true


func get_cell_by_index(index: int) -> StringName:
	if not index_in_bounds(index):
		return BattleOrbKind.EMPTY
	return _cells[index]


func swap_cells(ax: int, ay: int, bx: int, by: int) -> bool:
	if not in_bounds(ax, ay) or not in_bounds(bx, by):
		return false
	var ia: int = index_of(ax, ay)
	var ib: int = index_of(bx, by)
	var tmp: StringName = _cells[ia]
	_cells[ia] = _cells[ib]
	_cells[ib] = tmp
	return true


func clear_all() -> void:
	for i in CELL_COUNT:
		_cells[i] = BattleOrbKind.EMPTY


func duplicate_model() -> BattleBoardModel:
	return BattleBoardModel.new(get_cells())


func equals_cells(other: Array) -> bool:
	if other.size() != CELL_COUNT:
		return false
	for i in CELL_COUNT:
		if _cells[i] != (other[i] as StringName):
			return false
	return true
