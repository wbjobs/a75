class_name BTAction
extends BTNode

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
		description = "扩张策略：训练农民"

	func execute() -> int:
		var ai = _context.get("ai_controller", null)
		if not ai:
			return Status.FAILURE
		if ai.train_farmer():
			return Status.SUCCESS
		return Status.FAILURE

class BTActionAttack extends BTAction:
	func _init(name: String = "Attack"):
		node_name = name
		category = "AI Action"
		description = "进攻策略：命令战士攻击"

	func execute() -> int:
		var ai = _context.get("ai_controller", null)
		if not ai:
			return Status.FAILURE
		ai.order_attack()
		return Status.SUCCESS

class BTActionDefend extends BTAction:
	func _init(name: String = "Defend"):
		node_name = name
		category = "AI Action"
		description = "防守策略：命令战士防守"

	func execute() -> int:
		var ai = _context.get("ai_controller", null)
		if not ai:
			return Status.FAILURE
		ai.order_defend()
		return Status.SUCCESS

class BTActionHarvest extends BTAction:
	func _init(name: String = "Harvest"):
		node_name = name
		category = "AI Action"
		description = "采集策略：命令农民采集"

	func execute() -> int:
		var ai = _context.get("ai_controller", null)
		if not ai:
			return Status.FAILURE
		ai.order_harvest()
		return Status.SUCCESS
