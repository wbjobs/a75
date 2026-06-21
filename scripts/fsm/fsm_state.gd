class_name FSMState
extends RefCounted

var fsm: FSM = null
var owner: Node = null

func enter():
	pass

func update(delta: float):
	pass

func exit():
	pass

func set_param(name: String, value):
	if fsm:
		fsm.set_parameter(name, value)

func get_param(name: String, default = null):
	if fsm:
		return fsm.get_parameter(name, default)
	return default
