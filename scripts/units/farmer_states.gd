extends FSMState

const AITask = preload("res://scripts/ai/ai_task.gd")

class FarmerIdle extends FSMState:
	func enter():
		owner.fsm.set_parameter("target_resource", null)
		owner.fsm.set_parameter("returning", false)

	func update(delta: float):
		if _check_task_cancelled():
			return
		var current_task = owner.fsm.get_parameter("current_task", null)
		if current_task:
			if current_task.task_type == AITask.TaskType.HARVEST and current_task.target_resource != Vector2i.ZERO:
				owner.fsm.set_parameter("target_resource", current_task.target_resource)
				owner.fsm.change_state("Move")
				return
		var ai = owner.fsm.get_parameter("ai_controller", null)
		if ai and ai.auto_harvest and not current_task:
			var grid = owner.grid_map
			if grid:
				var nearest = grid.find_nearest_resource(owner.grid_pos)
				if nearest.x >= 0:
					owner.fsm.set_parameter("target_resource", nearest)
					owner.fsm.change_state("Move")

class FarmerMove extends FSMState:
	func enter():
		if _check_task_cancelled():
			return
		var current_task = owner.fsm.get_parameter("current_task", null)
		var target: Vector2i
		if current_task and current_task.target_resource != Vector2i.ZERO:
			target = current_task.target_resource
		else:
			target = owner.fsm.get_parameter("target_resource", null)
		if target:
			owner.move_to(target)

	func update(delta: float):
		if _check_task_cancelled():
			return
		if owner.update_position(delta):
			var current_task = owner.fsm.get_parameter("current_task", null)
			var target = owner.fsm.get_parameter("target_resource", null)
			var returning = owner.fsm.get_parameter("returning", false)
			if returning:
				owner.fsm.change_state("Deposit")
			elif (current_task and owner.grid_pos == current_task.target_resource) or (target and owner.grid_pos == target):
				owner.fsm.change_state("Harvest")
			else:
				if current_task:
					current_task.complete(false)
				owner.fsm.change_state("Idle")

class FarmerHarvest extends FSMState:
	var _harvest_timer: float = 0.0
	var harvest_interval: float = 0.5
	var harvest_amount: int = 5

	func enter():
		_harvest_timer = 0.0

	func update(delta: float):
		if _check_task_cancelled():
			return
		_harvest_timer += delta
		if _harvest_timer >= harvest_interval:
			_harvest_timer = 0.0
			var current_task = owner.fsm.get_parameter("current_task", null)
			var target: Vector2i
			if current_task and current_task.target_resource != Vector2i.ZERO:
				target = current_task.target_resource
			else:
				target = owner.fsm.get_parameter("target_resource", null)
			if target and owner.grid_map:
				var harvested = owner.grid_map.harvest_resource(target, harvest_amount)
				owner.carry_resource += harvested
				if owner.carry_resource >= owner.max_carry or harvested == 0:
					owner.fsm.set_parameter("returning", true)
					var base_pos = owner.fsm.get_parameter("base_position", owner.grid_pos)
					owner.fsm.set_parameter("target_resource", base_pos)
					if current_task:
						current_task.target_resource = base_pos
					owner.fsm.change_state("Move")

class FarmerDeposit extends FSMState:
	var _deposit_timer: float = 0.0
	var deposit_time: float = 0.5

	func enter():
		_deposit_timer = 0.0

	func update(delta: float):
		if _check_task_cancelled():
			return
		_deposit_timer += delta
		if _deposit_timer >= deposit_time:
			var ai = owner.fsm.get_parameter("ai_controller", null)
			var current_task = owner.fsm.get_parameter("current_task", null)
			if ai:
				ai.resources += owner.carry_resource
			owner.carry_resource = 0
			owner.fsm.set_parameter("returning", false)
			if current_task and current_task.task_type == AITask.TaskType.HARVEST:
				current_task.complete(true)
			owner.fsm.change_state("Idle")

func _check_task_cancelled() -> bool:
	var current_task = owner.fsm.get_parameter("current_task", null)
	if not current_task:
		return false
	if current_task.status == AITask.TaskStatus.CANCELLED:
		owner.fsm.set_parameter("current_task", null)
		owner.fsm.change_state("Idle")
		return true
	return false
