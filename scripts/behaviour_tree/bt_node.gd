class_name BTNode
extends RefCounted

enum Status {
	SUCCESS,
	FAILURE,
	RUNNING
}

signal node_executed(node: BTNode, status: int)

const BTCompositeScript = preload("res://scripts/behaviour_tree/bt_composite.gd")
const BTDecoratorScript = preload("res://scripts/behaviour_tree/bt_decorator.gd")
const BTConditionScript = preload("res://scripts/behaviour_tree/bt_condition.gd")
const BTActionScript = preload("res://scripts/behaviour_tree/bt_action.gd")

var guid: String = ""
var node_name: String = "BTNode"
var category: String = "Base"
var description: String = ""
var position: Vector2 = Vector2.ZERO
var _children: Array[BTNode] = []
var _parent: BTNode = null
var _context: Dictionary = {}
var _last_status: int = Status.FAILURE
var _debug_enabled: bool = true
var _is_current: bool = false

func _init(name: String = "BTNode"):
	node_name = name
	guid = generate_guid()

func generate_guid() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	return "bt_%s_%s" % [Time.get_unix_time_from_system(), rng.randi()]

func add_child(child: BTNode):
	_children.append(child)
	child._parent = self

func remove_child(child: BTNode):
	_children.erase(child)
	child._parent = null

func get_children() -> Array[BTNode]:
	return _children.duplicate()

func get_parent() -> BTNode:
	return _parent

func set_context(context: Dictionary):
	_context = context

func get_context() -> Dictionary:
	return _context

func set_current(value: bool):
	_is_current = value

func is_current() -> bool:
	return _is_current

func tick() -> int:
	_is_current = true
	var result = execute()
	_last_status = result
	if _debug_enabled:
		node_executed.emit(self, result)
	return result

func execute() -> int:
	return Status.SUCCESS

func reset():
	_last_status = Status.FAILURE
	_is_current = false
	for child in _children:
		child.reset()

func get_last_status() -> int:
	return _last_status

func to_dict() -> Dictionary:
	var data: Dictionary = {
		"guid": guid,
		"node_name": node_name,
		"category": category,
		"description": description,
		"position": { "x": position.x, "y": position.y },
		"type": get_class_static(),
		"children": []
	}
	for child in _children:
		data["children"].append(child.to_dict())
	return data

static func from_dict(data: Dictionary) -> BTNode:
	var type_str = data.get("type", "BTNode")
	var node: BTNode = create_node_from_type(type_str, data.get("node_name", "Node"))
	if node:
		node.guid = data.get("guid", node.guid)
		node.category = data.get("category", node.category)
		node.description = data.get("description", node.description)
		var pos = data.get("position", { "x": 0, "y": 0 })
		node.position = Vector2(pos.get("x", 0), pos.get("y", 0))
		for child_data in data.get("children", []):
			var child = from_dict(child_data)
			if child:
				node.add_child(child)
	return node

static func create_node_from_type(type_str: String, name: String) -> BTNode:
	var composite_script = preload("res://scripts/behaviour_tree/bt_composite.gd")
	var decorator_script = preload("res://scripts/behaviour_tree/bt_decorator.gd")
	var condition_script = preload("res://scripts/behaviour_tree/bt_condition.gd")
	var action_script = preload("res://scripts/behaviour_tree/bt_action.gd")
	match type_str:
		"BTSequence":
			return composite_script.BTSequence.new(name)
		"BTSelector":
			return composite_script.BTSelector.new(name)
		"BTParallel":
			return composite_script.BTParallel.new(name)
		"BTInverter":
			return decorator_script.BTInverter.new(name)
		"BTRepeat":
			return decorator_script.BTRepeat.new(name)
		"BTWait":
			return decorator_script.BTWait.new(name)
		"BTCondition":
			return condition_script.BTCondition.new(name)
		"BTAction":
			return action_script.BTAction.new(name)
		"BTActionExpand":
			return action_script.BTActionExpand.new(name)
		"BTActionAttack":
			return action_script.BTActionAttack.new(name)
		"BTActionDefend":
			return action_script.BTActionDefend.new(name)
		"BTActionHarvest":
			return action_script.BTActionHarvest.new(name)
		"BTConditionHasResources":
			return condition_script.BTConditionHasResources.new(name)
		"BTConditionEnemyNearby":
			return condition_script.BTConditionEnemyNearby.new(name)
		"BTConditionCanExpand":
			return condition_script.BTConditionCanExpand.new(name)
		_:
			return BTNode.new(name)
