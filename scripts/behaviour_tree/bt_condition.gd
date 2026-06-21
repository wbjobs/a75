class_name BTCondition
extends BTNode

var condition_func: Callable = Callable(self, "_default_condition")

func _init(name: String = "Condition"):
	node_name = name
	category = "Condition"
	description = "条件判断节点"

func _default_condition(context: Dictionary) -> bool:
	return true

func execute() -> int:
	if condition_func.call(_context):
		return Status.SUCCESS
	return Status.FAILURE

class BTConditionHasResources extends BTCondition:
	var required_amount: int = 50

	func _init(name: String = "Has Resources?"):
		node_name = name
		category = "AI Condition"
		description = "检查资源是否足够"

	func execute() -> int:
		var ai = _context.get("ai_controller", null)
		if not ai:
			return Status.FAILURE
		if ai.resources >= required_amount:
			return Status.SUCCESS
		return Status.FAILURE

class BTConditionEnemyNearby extends BTCondition:
	var detection_range: float = 5.0

	func _init(name: String = "Enemy Nearby?"):
		node_name = name
		category = "AI Condition"
		description = "检查附近是否有敌人"

	func execute() -> int:
		var ai = _context.get("ai_controller", null)
		var grid = _context.get("grid_map", null)
		if not ai or not grid:
			return Status.FAILURE
		for enemy in ai.enemies:
			if enemy and is_instance_valid(enemy):
				var dist = enemy.grid_pos.distance_to(ai.base_position)
				if dist <= detection_range:
					return Status.SUCCESS
		return Status.FAILURE

class BTConditionCanExpand extends BTCondition:
	func _init(name: String = "Can Expand?"):
		node_name = name
		category = "AI Condition"
		description = "检查是否可以扩张"

	func execute() -> int:
		var ai = _context.get("ai_controller", null)
		if not ai:
			return Status.FAILURE
		if ai.farmers.size() < 5 and ai.resources >= 30:
			return Status.SUCCESS
		return Status.FAILURE
