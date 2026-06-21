class_name BTSequence
extends BTNode

func _init(name: String = "Sequence"):
	node_name = name
	category = "Composite"
	description = "顺序执行所有子节点，直到一个失败或全部成功"

func execute() -> int:
	for child in _children:
		var status = child.tick()
		if status != Status.SUCCESS:
			return status
	return Status.SUCCESS

class BTSelector extends BTNode:
	func _init(name: String = "Selector"):
		node_name = name
		category = "Composite"
		description = "顺序执行所有子节点，直到一个成功或全部失败"

	func execute() -> int:
		for child in _children:
			var status = child.tick()
			if status != Status.FAILURE:
				return status
		return Status.FAILURE

class BTParallel extends BTNode:
	var success_policy: int = 1
	var failure_policy: int = 1

	func _init(name: String = "Parallel"):
		node_name = name
		category = "Composite"
		description = "并行执行所有子节点"

	func execute() -> int:
		var success_count = 0
		var failure_count = 0
		var running_count = 0
		for child in _children:
			var status = child.tick()
			match status:
				Status.SUCCESS:
					success_count += 1
				Status.FAILURE:
					failure_count += 1
				Status.RUNNING:
					running_count += 1
		if failure_count >= failure_policy:
			return Status.FAILURE
		if success_count >= success_policy:
			return Status.SUCCESS
		return Status.RUNNING
