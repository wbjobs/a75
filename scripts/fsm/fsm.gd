class_name FSM
extends Node

signal state_changed(old_state: String, new_state: String)

var _states: Dictionary = {}
var _current_state: String = ""
var _current_state_obj: FSMState = null
var _owner: Node = null
var _parameters: Dictionary = {}

func _init(owner: Node):
	_owner = owner

func add_state(state_name: String, state: FSMState):
	_states[state_name] = state
	state.fsm = self
	state.owner = _owner

func set_parameter(name: String, value):
	_parameters[name] = value

func get_parameter(name: String, default = null):
	return _parameters.get(name, default)

func change_state(new_state: String):
	if new_state == _current_state:
		return
	if not _states.has(new_state):
		push_error("FSM: State '%s' not found" % new_state)
		return
	var old_state = _current_state
	if _current_state_obj:
		_current_state_obj.exit()
	_current_state = new_state
	_current_state_obj = _states[new_state]
	_current_state_obj.enter()
	state_changed.emit(old_state, new_state)

func update(delta: float):
	if _current_state_obj:
		_current_state_obj.update(delta)

func get_current_state() -> String:
	return _current_state
