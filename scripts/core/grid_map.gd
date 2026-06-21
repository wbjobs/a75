class_name GridMap
extends Node2D

signal cell_clicked(grid_pos: Vector2i, world_pos: Vector2)

enum CellType {
	EMPTY,
	GRASS,
	ROCK,
	RESOURCE,
	BUILDING,
	UNIT
}

var grid_size: Vector2i = Vector2i(32, 20)
var cell_size: int = 32

var _cells: Array = []
var _buildings: Dictionary = {}
var _units: Dictionary = {}
var _resources: Dictionary = {}

func _ready():
	_generate_grid()
	_add_resources()

func _generate_grid():
	_cells.clear()
	for y in range(grid_size.y):
		var row: Array = []
		for x in range(grid_size.x):
			row.append(CellType.GRASS)
		_cells.append(row)

func _add_resources():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(15):
		var gx = rng.randi_range(2, grid_size.x - 3)
		var gy = rng.randi_range(2, grid_size.y - 3)
		if _cells[gy][gx] == CellType.GRASS:
			_cells[gy][gx] = CellType.RESOURCE
			_resources[Vector2i(gx, gy)] = rng.randi_range(50, 100)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * cell_size + cell_size / 2.0,
		grid_pos.y * cell_size + cell_size / 2.0
	)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / cell_size),
		int(world_pos.y / cell_size)
	)

func is_valid_grid_pos(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_size.x and grid_pos.y >= 0 and grid_pos.y < grid_size.y

func is_walkable(grid_pos: Vector2i) -> bool:
	if not is_valid_grid_pos(grid_pos):
		return false
	var cell_type = _cells[grid_pos.y][grid_pos.x]
	return cell_type == CellType.GRASS or cell_type == CellType.RESOURCE

func get_cell_type(grid_pos: Vector2i) -> int:
	if not is_valid_grid_pos(grid_pos):
		return CellType.EMPTY
	return _cells[grid_pos.y][grid_pos.x]

func place_building(grid_pos: Vector2i, building: Node) -> bool:
	if not is_walkable(grid_pos):
		return false
	_cells[grid_pos.y][grid_pos.x] = CellType.BUILDING
	_buildings[grid_pos] = building
	return true

func place_unit(grid_pos: Vector2i, unit: Node) -> bool:
	_units[grid_pos] = unit
	return true

func move_unit(from_pos: Vector2i, to_pos: Vector2i, unit: Node):
	_units.erase(from_pos)
	_units[to_pos] = unit

func get_resource_amount(grid_pos: Vector2i) -> int:
	return _resources.get(grid_pos, 0)

func harvest_resource(grid_pos: Vector2i, amount: int) -> int:
	if not _resources.has(grid_pos):
		return 0
	var current = _resources[grid_pos]
	var harvested = min(amount, current)
	current -= harvested
	if current <= 0:
		_resources.erase(grid_pos)
		_cells[grid_pos.y][grid_pos.x] = CellType.GRASS
	else:
		_resources[grid_pos] = current
	return harvested

func find_nearest_resource(from_pos: Vector2i) -> Vector2i:
	var best_pos = Vector2i(-1, -1)
	var best_dist = 99999
	for res_pos in _resources.keys():
		var dist = res_pos.distance_to(from_pos)
		if dist < best_dist:
			best_dist = dist
			best_pos = res_pos
	return best_pos

func find_empty_near(pos: Vector2i, radius: int = 3) -> Vector2i:
	for r in range(1, radius + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var check_pos = pos + Vector2i(dx, dy)
				if is_walkable(check_pos) and not _units.has(check_pos):
					return check_pos
	return pos

func _draw():
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell_type = _cells[y][x]
			var rect = Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
			match cell_type:
				CellType.GRASS:
					draw_rect(rect, Color(0.3, 0.5, 0.2))
				CellType.RESOURCE:
					draw_rect(rect, Color(0.6, 0.4, 0.2))
					var amount = get_resource_amount(Vector2i(x, y))
					draw_string(
						ThemeDB.fallback_font,
						rect.position + Vector2(4, 14),
						str(amount),
						HORIZONTAL_ALIGNMENT_LEFT,
						-1,
						10,
						Color.WHITE
					)
				CellType.BUILDING:
					draw_rect(rect, Color(0.4, 0.4, 0.6))
			draw_rect(rect, Color(0.1, 0.2, 0.1), false, 1.0)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var grid_pos = world_to_grid(event.position)
		if is_valid_grid_pos(grid_pos):
			cell_clicked.emit(grid_pos, event.position)
