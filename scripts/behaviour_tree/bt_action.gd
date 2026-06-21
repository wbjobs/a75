class_name BTAction
extends BTNode

const AITask = preload("res://scripts/ai/ai_task.gd")

var action_func: Callable = Callable(self, "_default_action")

func _init(name: String = "Action"):
	node_name = name
	category = "Action"
	description = "动作节点"

func _default_action(context: Dictionary) -> int:
	return Status.SUCCESS

func execute() -> int:
	return action_func.call(_context)

class BTActionExpand extends BTAction:
	func _init(name: String = "Expand"):
		node_name = name
		category = "AI Action"
		description = "扩张策略：训练农民（中优先级）"

	func execute() -> int:
		var ai = _context.get("ai_controller", null)
		if not ai:
			return Status.FAILURE
		if not ai.task_scheduler:
			if ai.train_farmer():
				return Status.SUCCESS
			return Status.FAILURE
		if ai.resources < ai.training_farmer_cost:
			return Status.FAILURE
		var task = AITask.new(AITask.TaskType.EXPAND, AITask.Priority.MEDIUM, "训练农民")
		task.max_duration = 5.0
		task.cool_down_time = 3.0
		task.failure_cool_down = 5.0
		if ai.task_scheduler.propose_task(task):
			if ai.train_farmer():
				task.complete(true)
				return Status.SUCCESS
			else:
				task.complete(false)
				return Status.FAILURE
		return Status.RUNNING

class BTActionAttack extends BTAction:
	func _init(name: String = "Attack"):
		node_name = name
		category = "AI Action"
		description = "进攻策略：命令战士攻击（高优先级）"

	func execute() -> int:
		var ai = _context.get("ai_controller", null)
		var grid = _context.get("grid_map", null)
		if not ai or not grid:
			return Status.FAILURE
		if not ai.task_scheduler:
			ai.order_attack()
			return Status.SUCCESS
		var enemies = ai.enemies
		if enemies.size() == 0:
			return Status.FAILURE
		var target: UnitBase = null
		for enemy in enemies:
			if enemy and is_instance_valid(enemy):
				target = enemy
				break
		if not target:
			return Status.FAILURE
		var task = AITask.new(AITask.TaskType.ATTACK, AITask.Priority.HIGH, "进攻敌方")
		task.target_unit = target
		task.target_position = target.grid_pos
		task.max_duration = 20.0
		task.cool_down_time = 5.0
		task.failure_cool_down = 8.0
		if ai.task_scheduler.propose_task(task):
			ai.current_order = "attack"
			return Status.SUCCESS
		return Status.RUNNING

class BTActionDefend extends BTAction:
	func _init(name: String = "Defend"):
		node_name = name
		category = "AI Action"
		description = "防守策略：命令战士防守（紧急优先级）"

	func execute() -> int:
		var ai = _context.get("ai_controller", null)
		if not ai:
			return Status.FAILURE
		if not ai.task_scheduler:
			ai.order_defend()
			return Status.SUCCESS
		var task = AITask.new(AITask.TaskType.DEFEND, AITask.Priority.CRITICAL, "防守基地")
		task.target_position = ai.base_position
		task.max_duration = 15.0
		task.cool_down_time = 3.0
		task.failure_cool_down = 5.0
		if ai.task_scheduler.propose_task(task):
			ai.current_order = "defend"
			return Status.SUCCESS
		return Status.RUNNING

class BTActionHarvest extends BTAction:
	func _init(name: String = "Harvest"):
		node_name = name
		category = "AI Action"
		description = "采集策略：命令农民采集（低优先级）"

	func execute() -> int:
		var ai = _context.get("ai_controller", null)
		var grid = _context.get("grid_map", null)
		if not ai or not grid:
			return Status.FAILURE
		if not ai.task_scheduler:
			ai.order_harvest()
			return Status.SUCCESS
		var farmer_count = ai.get_farmer_count()
		if farmer_count == 0:
			return Status.FAILURE
		var nearest = grid.find_nearest_resource(ai.base_position)
		if nearest.x < 0:
			return Status.FAILURE
		var task = AITask.new(AITask.TaskType.HARVEST, AITask.Priority.LOW, "采集资源")
		task.target_resource = nearest
		task.target_position = nearest
		task.max_duration = 30.0
		task.cool_down_time = 2.0
		task.failure_cool_down = 4.0
		if ai.task_scheduler.propose_task(task):
			ai.auto_harvest = true
			return Status.SUCCESS
		return Status.RUNNING
