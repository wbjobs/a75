class_name TaskScheduler
extends Node

signal task_assigned(task: AITask, unit: UnitBase)
signal task_completed(task: AITask, success: bool)
signal task_cancelled(task: AITask)
signal scheduler_updated()

var ai_controller: AIController = null
var grid_map: GridMap = null
var _pending_tasks: Array[AITask] = []
var _unit_tasks: Dictionary = {}
var _cool_downs: Dictionary = {}
var _task_history: Array[AITask] = []
var max_history: int = 50
var min_priority_to_interrupt: int = 0

func _init(ai: AIController, grid: GridMap):
	ai_controller = ai
	grid_map = grid

func _process(delta: float):
	_update_cool_downs(delta)
	_process_pending_tasks()
	_check_running_tasks()
	scheduler_updated.emit()

func _update_cool_downs(delta: float):
	var to_remove: Array = []
	for key in _cool_downs.keys():
		_cool_downs[key] -= delta
		if _cool_downs[key] <= 0:
			to_remove.append(key)
	for key in to_remove:
		_cool_downs.erase(key)

func _process_pending_tasks():
	_pending_tasks.sort_custom(func(a: AITask, b: AITask) -> bool:
		return a.priority > b.priority
	)
	var i = 0
	while i < _pending_tasks.size():
		var task = _pending_tasks[i]
		if not task.is_active():
			_pending_tasks.remove_at(i)
			continue
		if _is_in_cool_down(task):
			task.cancel()
			_pending_tasks.remove_at(i)
			continue
		var assigned = _try_assign_task(task)
		if assigned:
			_pending_tasks.remove_at(i)
		else:
			i += 1

func _try_assign_task(task: AITask) -> bool:
	var unit = _find_best_unit(task)
	if not unit:
		return false
	var current_task = _get_current_task(unit)
	if current_task:
		if task.priority <= current_task.priority:
			return false
		_interrupt_task(current_task)
	task.assigned_unit = unit
	task.start()
	_assign_task_to_unit(task, unit)
	_add_to_history(task)
	task_assigned.emit(task, unit)
	return true

func _find_best_unit(task: AITask) -> UnitBase:
	var candidates: Array[UnitBase] = []
	match task.task_type:
		AITask.TaskType.HARVEST:
			candidates = _get_available_farmers()
		AITask.TaskType.ATTACK:
			candidates = _get_available_warriors()
		AITask.TaskType.DEFEND:
			candidates = _get_available_warriors()
		AITask.TaskType.MOVE:
			candidates = _get_all_idle_units()
		_:
			candidates = _get_all_idle_units()
	if candidates.size() == 0:
		return null
	if task.target_position != Vector2i.ZERO:
		var best: UnitBase = null
		var best_dist = 99999.0
		for unit in candidates:
			var dist = unit.grid_pos.distance_to(task.target_position)
			if dist < best_dist:
				best_dist = dist
				best = unit
		return best
	return candidates[0]

func _get_available_farmers() -> Array[UnitBase]:
	var result: Array[UnitBase] = []
	for farmer in ai_controller.farmers:
		if is_instance_valid(farmer):
			var current = _get_current_task(farmer)
			if not current or current.priority < AITask.Priority.HIGH:
				result.append(farmer)
	return result

func _get_available_warriors() -> Array[UnitBase]:
	var result: Array[UnitBase] = []
	for warrior in ai_controller.warriors:
		if is_instance_valid(warrior):
			var current = _get_current_task(warrior)
			if not current or current.priority < AITask.Priority.HIGH:
				result.append(warrior)
	return result

func _get_all_idle_units() -> Array[UnitBase]:
	var result: Array[UnitBase] = []
	for farmer in ai_controller.farmers:
		if is_instance_valid(farmer) and not _get_current_task(farmer):
			result.append(farmer)
	for warrior in ai_controller.warriors:
		if is_instance_valid(warrior) and not _get_current_task(warrior):
			result.append(warrior)
	return result

func get_current_task(unit: UnitBase) -> AITask:
	return _get_current_task(unit)

func _assign_task_to_unit(task: AITask, unit: UnitBase):
	var unit_id = unit.get_instance_id()
	if not _unit_tasks.has(unit_id):
		_unit_tasks[unit_id] = []
	_unit_tasks[unit_id].append(task)
	_notify_unit_of_task(unit, task)

func _notify_unit_of_task(unit: UnitBase, task: AITask):
	if is_instance_valid(unit) and unit.fsm:
		unit.fsm.set_parameter("current_task", task)
		match task.task_type:
			AITask.TaskType.HARVEST:
				if task.target_resource != Vector2i.ZERO:
					unit.fsm.set_parameter("target_resource", task.target_resource)
				unit.fsm.change_state("Idle")
			AITask.TaskType.ATTACK:
				if task.target_unit:
					unit.fsm.set_parameter("enemies", [task.target_unit])
					unit.fsm.set_parameter("target_pos", task.target_unit.grid_pos)
				unit.fsm.change_state("Idle")
			AITask.TaskType.DEFEND:
				unit.fsm.set_parameter("target_pos", ai_controller.base_position)
				unit.fsm.change_state("Idle")
			AITask.TaskType.MOVE:
				unit.fsm.set_parameter("target_resource", task.target_position)
				unit.fsm.change_state("Idle")

func _interrupt_task(task: AITask):
	if not task or task.status != AITask.TaskStatus.EXECUTING:
		return
	task.cancel()
	task_cancelled.emit(task)
	if task.assigned_unit and is_instance_valid(task.assigned_unit):
		_notify_unit_task_cancelled(task.assigned_unit)

func _notify_unit_task_cancelled(unit: UnitBase):
	if is_instance_valid(unit) and unit.fsm:
		unit.fsm.set_parameter("current_task", null)
		unit.fsm.change_state("Idle")

func _check_running_tasks():
	for unit_id in _unit_tasks.keys():
		var queue = _unit_tasks[unit_id]
		var to_remove: Array = []
		for task in queue:
			if task.is_finished():
				_set_cool_down(task)
				task_completed.emit(task, task.status == AITask.TaskStatus.COMPLETED)
				if task.assigned_unit and is_instance_valid(task.assigned_unit):
					_notify_unit_task_completed(task.assigned_unit, task)
				to_remove.append(task)
			elif task.has_timed_out():
				task.complete(false)
				_set_cool_down(task)
				task_completed.emit(task, false)
				if task.assigned_unit and is_instance_valid(task.assigned_unit):
					_notify_unit_task_completed(task.assigned_unit, task)
				to_remove.append(task)
		for task in to_remove:
			queue.erase(task)

func _notify_unit_task_completed(unit: UnitBase, task: AITask):
	if is_instance_valid(unit) and unit.fsm:
		unit.fsm.set_parameter("current_task", null)

func _is_in_cool_down(task: AITask) -> bool:
	var key = _get_cool_down_key(task)
	return _cool_downs.has(key) and _cool_downs[key] > 0

func _set_cool_down(task: AITask):
	var key = _get_cool_down_key(task)
	_cool_downs[key] = task.get_cool_down()

func _get_cool_down_key(task: AITask) -> String:
	return "cd_%s_%s" % [task.task_type, task.description]

func _add_to_history(task: AITask):
	_task_history.append(task)
	if _task_history.size() > max_history:
		_task_history.remove_at(0)

func propose_task(task: AITask) -> bool:
	if _is_in_cool_down(task):
		return false
	_pending_tasks.append(task)
	return true

func get_pending_tasks() -> Array[AITask]:
	return _pending_tasks.duplicate()

func get_unit_task_queue(unit: UnitBase) -> Array[AITask]:
	if not unit:
		return []
	var unit_id = unit.get_instance_id()
	if not _unit_tasks.has(unit_id):
		return []
	return _unit_tasks[unit_id].duplicate()

func get_active_tasks() -> Array[AITask]:
	var result: Array[AITask] = []
	for unit_id in _unit_tasks.keys():
		var queue = _unit_tasks[unit_id]
		for task in queue:
			if task.is_active():
				result.append(task)
	return result

func get_task_history() -> Array[AITask]:
	return _task_history.duplicate()

func cancel_all_tasks():
	for task in _pending_tasks:
		task.cancel()
	_pending_tasks.clear()
	for unit_id in _unit_tasks.keys():
		var queue = _unit_tasks[unit_id]
		for task in queue:
			if task.is_active():
				task.cancel()
				task_cancelled.emit(task)

func get_stats() -> Dictionary:
	var pending = _pending_tasks.size()
	var running = 0
	for unit_id in _unit_tasks.keys():
		var queue = _unit_tasks[unit_id]
		for task in queue:
			if task.status == AITask.TaskStatus.EXECUTING:
				running += 1
	return {
		"pending": pending,
		"running": running,
		"cool_downs": _cool_downs.size()
	}
