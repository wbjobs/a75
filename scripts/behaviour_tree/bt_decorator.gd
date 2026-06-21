class_name BTInverter
extends BTNode

func _init(name: String = "Inverter"):
	node_name = name
	category = "Decorator"
	description = "取反子节点结果"

func execute() -> int:
	if _children.size() == 0:
		return Status.FAILURE
	var status = _children[0].tick()
	match status:
		Status.SUCCESS:
			return Status.FAILURE
		Status.FAILURE:
			return Status.SUCCESS
	return Status.RUNNING

class BTRepeat extends BTNode:
	var repeat_count: int = -1
	var _current_count: int = 0

	func _init(name: String = "Repeat"):
		node_name = name
		category = "Decorator"
		description = "重复执行子节点"

	func reset():
		_current_count = 0
		super.reset()

	func execute() -> int:
		if _children.size() == 0:
			return Status.SUCCESS
		var status = _children[0].tick()
		if status == Status.RUNNING:
			return Status.RUNNING
		_current_count += 1
		if repeat_count < 0 or _current_count < repeat_count:
			_children[0].reset()
			return Status.RUNNING
		return Status.SUCCESS

class BTWait extends BTNode:
	var wait_time: float = 1.0
	var _elapsed: float = 0.0

	func _init(name: String = "Wait"):
		node_name = name
		category = "Decorator"
		description = "等待指定时间后返回成功"

	func reset():
		_elapsed = 0.0
		super.reset()

	func execute() -> int:
		_elapsed += get_context().get("delta", 0.016)
		if _elapsed >= wait_time:
			_elapsed = 0.0
			return Status.SUCCESS
		return Status.RUNNING
