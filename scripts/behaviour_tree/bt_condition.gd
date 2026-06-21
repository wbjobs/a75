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
	var use_learned_params: bool = true
	var param_key: String = "attack_resource_threshold"

	func _init(name: String = "Has Resources?"):
		node_name = name
		category = "AI Condition"
		description = "检查资源是否足够"

	func _get_effective_threshold() -> int:
		if use_learned_params and _context.has("ai_controller"):
			var ai = _context["ai_controller"]
			if ai and ai.has_method("get_learned_param_int"):
				var learned = ai.get_learned_param_int(param_key, -1)
				if learned >= 0:
					return learned
		return required_amount

	func execute() -> int:
		var ai = _context.get("ai_controller", null)
		if not ai:
			return Status.FAILURE
		var threshold = _get_effective_threshold()
		if ai.resources >= threshold:
			return Status.SUCCESS
		return Status.FAILURE

class BTConditionEnemyNearby extends BTCondition:
	var detection_range: float = 5.0
	var use_learned_params: bool = true
	var param_key: String = "enemy_detection_range"

	func _init(name: String = "Enemy Nearby?"):
		node_name = name
		category = "AI Condition"
		description = "检查附近是否有敌人"

	func _get_effective_range() -> float:
		if use_learned_params and _context.has("ai_controller"):
			var ai = _context["ai_controller"]
			if ai and ai.has_method("get_learned_param_float"):
				var learned = ai.get_learned_param_float(param_key, -1.0)
				if learned > 0.0:
					return learned
		return detection_range

	func execute() -> int:
		var ai = _context.get("ai_controller", null)
		var grid = _context.get("grid_map", null)
		if not ai or not grid:
			return Status.FAILURE
		var range = _get_effective_range()
		for enemy in ai.enemies:
			if enemy and is_instance_valid(enemy):
				var dist = enemy.grid_pos.distance_to(ai.base_position)
				if dist <= range:
					return Status.SUCCESS
		return Status.FAILURE

class BTConditionCanExpand extends BTCondition:
	var required_amount: int = 30
	var max_farmers: int = 5
	var use_learned_params: bool = true
	var param_res_key: String = "expand_resource_threshold"
	var param_farmers_key: String = "max_farmers_for_expand"

	func _init(name: String = "Can Expand?"):
		node_name = name
		category = "AI Condition"
		description = "检查是否可以扩张"

	func _get_effective_res() -> int:
		if use_learned_params and _context.has("ai_controller"):
			var ai = _context["ai_controller"]
			if ai and ai.has_method("get_learned_param_int"):
				var learned = ai.get_learned_param_int(param_res_key, -1)
				if learned >= 0:
					return learned
		return required_amount

	func _get_effective_max_farmers() -> int:
		if use_learned_params and _context.has("ai_controller"):
			var ai = _context["ai_controller"]
			if ai and ai.has_method("get_learned_param_int"):
				var learned = ai.get_learned_param_int(param_farmers_key, -1)
				if learned >= 0:
					return learned
		return max_farmers

	func execute() -> int:
		var ai = _context.get("ai_controller", null)
		if not ai:
			return Status.FAILURE
		var res_threshold = _get_effective_res()
		var farmer_limit = _get_effective_max_farmers()
		var farmer_count = 0
		for f in ai.farmers:
			if is_instance_valid(f):
				farmer_count += 1
		if farmer_count < farmer_limit and ai.resources >= res_threshold:
			return Status.SUCCESS
		return Status.FAILURE
