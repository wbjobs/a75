class_name UnitBase
extends CharacterBody2D

signal unit_died(unit: UnitBase)
signal state_changed(old_state: String, new_state: String)

enum UnitType {
	FARMER,
	WARRIOR
}

var unit_type: int = UnitType.FARMER
var team: int = 0
var grid_pos: Vector2i = Vector2i.ZERO
var target_grid_pos: Vector2i = Vector2i.ZERO
var health: int = 100
var max_health: int = 100
var speed: float = 60.0
var damage: int = 10
var attack_range: float = 40.0
var attack_cooldown: float = 1.0
var _attack_timer: float = 0.0
var fsm: FSM = null
var grid_map: GridMap = null
var target_unit: UnitBase = null
var carry_resource: int = 0
var max_carry: int = 20
var is_selected: bool = false
var team_color: Color = Color(0.2, 0.6, 1.0)
var _move_path: Array[Vector2i] = []
var _current_path_index: int = 0

func _ready():
	fsm = FSM.new(self)
	_setup_fsm()

func _setup_fsm():
	pass

func _process(delta: float):
	if fsm:
		fsm.update(delta)
	if _attack_timer > 0:
		_attack_timer -= delta
	queue_redraw()

func move_to(target: Vector2i):
	if not grid_map:
		return
	target_grid_pos = target
	_move_path = _find_path(grid_pos, target)
	_current_path_index = 0
	if fsm:
		fsm.change_state("Move")

func _find_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current = start
	while current != end:
		var next_step = current
		if current.x < end.x and grid_map.is_walkable(current + Vector2i.RIGHT):
			next_step.x += 1
		elif current.x > end.x and grid_map.is_walkable(current + Vector2i.LEFT):
			next_step.x -= 1
		elif current.y < end.y and grid_map.is_walkable(current + Vector2i.DOWN):
			next_step.y += 1
		elif current.y > end.y and grid_map.is_walkable(current + Vector2i.UP):
			next_step.y -= 1
		if next_step == current:
			break
		path.append(next_step)
		current = next_step
	return path

func update_position(delta: float):
	if _move_path.size() == 0 or _current_path_index >= _move_path.size():
		return true
	var next_grid = _move_path[_current_path_index]
	var target_world = grid_map.grid_to_world(next_grid)
	var direction = (target_world - position).normalized()
	var move_amount = direction * speed * delta
	if position.distance_to(target_world) < move_amount.length():
		position = target_world
		if grid_map:
			grid_map.move_unit(grid_pos, next_grid, self)
		grid_pos = next_grid
		_current_path_index += 1
	else:
		position += move_amount
	return false

func take_damage(amount: int, attacker: UnitBase):
	health -= amount
	if health <= 0:
		health = 0
		unit_died.emit(self)
		queue_free()

func can_attack() -> bool:
	return _attack_timer <= 0 and target_unit and target_unit.is_inside_tree()

func attack_target():
	if not can_attack():
		return
	_attack_timer = attack_cooldown
	if target_unit:
		target_unit.take_damage(damage, self)

func _draw():
	var size = Vector2(24, 24)
	var rect = Rect2(-size / 2, size)
	var body_color = team_color if team == 0 else Color(1.0, 0.3, 0.3)
	if is_selected:
		draw_rect(rect.grow(3), Color.WHITE, false, 2.0)
	draw_rect(rect, body_color)
	var type_icon = "F" if unit_type == UnitType.FARMER else "W"
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-6, 5),
		type_icon,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color.WHITE
	)
	var health_bar_width = 28
	var health_percent = float(health) / max_health
	draw_rect(Rect2(-health_bar_width / 2, -18, health_bar_width, 4), Color(0.3, 0.3, 0.3))
	draw_rect(Rect2(-health_bar_width / 2, -18, health_bar_width * health_percent, 4), Color(0.2, 0.8, 0.2))
	if unit_type == UnitType.FARMER and carry_resource > 0:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-10, 20),
			"+%d" % carry_resource,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color(1.0, 0.8, 0.3)
		)
