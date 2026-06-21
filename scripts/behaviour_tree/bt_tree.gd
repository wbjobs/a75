class_name BehaviourTree
extends Node

signal tree_updated()
signal node_executed(node: BTNode, status: int)

var root: BTNode = null
var context: Dictionary = {}
var _active_nodes: Array[BTNode] = []
var _last_active_nodes: Array[BTNode] = []

func set_root(new_root: BTNode):
	if root:
		root.node_executed.disconnect(_on_node_executed)
	root = new_root
	if root:
		root.node_executed.connect(_on_node_executed)
	tree_updated.emit()

func set_context_value(key: String, value):
	context[key] = value

func tick(delta: float):
	if not root:
		return
	context["delta"] = delta
	context["time"] = Time.get_ticks_msec() / 1000.0
	_last_active_nodes.clear()
	root.reset()
	root.set_context(context)
	root.tick()

func _on_node_executed(node: BTNode, status: int):
	_last_active_nodes.append(node)
	node_executed.emit(node, status)

func get_last_active_nodes() -> Array[BTNode]:
	return _last_active_nodes.duplicate()

func to_dict() -> Dictionary:
	if root:
		return root.to_dict()
	return {}

func load_from_dict(data: Dictionary):
	set_root(BTNode.from_dict(data))

func save_to_file(file_path: String):
	var data = to_dict()
	var json_string = JSON.stringify(data)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()

func load_from_file(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var data = JSON.parse_string(json_string)
		if data is Dictionary:
			load_from_dict(data)
