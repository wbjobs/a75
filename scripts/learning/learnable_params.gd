class_name LearnableParam
extends RefCounted

enum ParamType {
	INT,
	FLOAT,
	INT_RANGE,
	FLOAT_RANGE,
	DISCRETE
}

var param_id: String = ""
var param_name: String = ""
var description: String = ""
var param_type: int = ParamType.FLOAT
var current_value: Variant = 0.0
var default_value: Variant = 0.0
var min_value: float = 0.0
var max_value: float = 100.0
var step: float = 1.0
var discrete_options: Array = []
var is_locked: bool = false
var last_changed_game: int = 0
var change_count: int = 0
var best_value: Variant = null

func _init(id: String, name: String, desc: String, default_val: Variant, min_val: float, max_val: float, step_val: float = 1.0, p_type: int = ParamType.FLOAT):
	param_id = id
	param_name = name
	description = desc
	default_value = default_val
	current_value = default_val
	min_value = min_val
	max_value = max_val
	step = step_val
	param_type = p_type
	best_value = default_val

func set_discrete_options(options: Array):
	discrete_options = options
	param_type = ParamType.DISCRETE
	if discrete_options.size() > 0 and not discrete_options.has(current_value):
		current_value = discrete_options[0]
		default_value = discrete_options[0]
		best_value = discrete_options[0]

func get_value() -> Variant:
	return current_value

func get_int_value() -> int:
	return int(current_value)

func get_float_value() -> float:
	return float(current_value)

func set_value(value: Variant) -> bool:
	if is_locked:
		return false
	match param_type:
		ParamType.INT, ParamType.INT_RANGE:
			value = int(value)
			value = clamp(float(value), min_value, max_value)
			value = round(float(value) / step) * step
			current_value = int(value)
		ParamType.FLOAT, ParamType.FLOAT_RANGE:
			value = float(value)
			value = clamp(value, min_value, max_value)
			value = round(value / step) * step
			current_value = value
		ParamType.DISCRETE:
			if discrete_options.has(value):
				current_value = value
			else:
				return false
	change_count += 1
	return true

func mutate(mutation_strength: float = 1.0, rng: RandomNumberGenerator = null) -> Variant:
	if is_locked:
		return current_value
	var rg = rng if rng else RandomNumberGenerator.new()
	match param_type:
		ParamType.INT, ParamType.INT_RANGE:
			var range = (max_value - min_value) * mutation_strength * 0.3
			var delta = rg.randf_range(-range, range)
			var new_val = int(clamp(float(current_value) + delta, min_value, max_value))
			new_val = int(round(float(new_val) / step) * step)
			return new_val
		ParamType.FLOAT, ParamType.FLOAT_RANGE:
			var frange = (max_value - min_value) * mutation_strength * 0.3
			var fdelta = rg.randf_range(-frange, frange)
			var fnew = clamp(float(current_value) + fdelta, min_value, max_value)
			fnew = round(fnew / step) * step
			return fnew
		ParamType.DISCRETE:
			if rg.randf() < mutation_strength * 0.3 and discrete_options.size() > 1:
				var idx = discrete_options.find(current_value)
				var new_idx = idx
				while new_idx == idx:
					new_idx = rg.randi_range(0, discrete_options.size() - 1)
				return discrete_options[new_idx]
	return current_value

func reset_to_default():
	current_value = default_value

func reset_to_best():
	if best_value != null:
		current_value = best_value

func mark_as_best():
	best_value = current_value.duplicate() if current_value is Array else current_value

func randomize(rng: RandomNumberGenerator = null):
	if is_locked:
		return
	var rg = rng if rng else RandomNumberGenerator.new()
	match param_type:
		ParamType.INT, ParamType.INT_RANGE:
			var ival = rg.randi_range(int(min_value), int(max_value / step)) * int(step)
			current_value = int(clamp(float(ival), min_value, max_value))
		ParamType.FLOAT, ParamType.FLOAT_RANGE:
			current_value = round(rg.randf_range(min_value, max_value) / step) * step
		ParamType.DISCRETE:
			if discrete_options.size() > 0:
				current_value = discrete_options[rg.randi_range(0, discrete_options.size() - 1)]

func interpolate_to(target_value: Variant, blend: float = 0.5):
	if is_locked:
		return
	blend = clamp(blend, 0.0, 1.0)
	match param_type:
		ParamType.INT, ParamType.INT_RANGE:
			var ival = float(current_value) + (float(target_value) - float(current_value)) * blend
			current_value = int(clamp(round(ival / step) * step, min_value, max_value))
		ParamType.FLOAT, ParamType.FLOAT_RANGE:
			var fval = float(current_value) + (float(target_value) - float(current_value)) * blend
			current_value = clamp(round(fval / step) * step, min_value, max_value)
		_:
			if blend > 0.5:
				current_value = target_value

func to_dict() -> Dictionary:
	return {
		"param_id": param_id,
		"param_name": param_name,
		"description": description,
		"param_type": param_type,
		"current_value": current_value,
		"default_value": default_value,
		"min_value": min_value,
		"max_value": max_value,
		"step": step,
		"discrete_options": discrete_options,
		"is_locked": is_locked,
		"best_value": best_value,
		"change_count": change_count
	}

static func from_dict(data: Dictionary) -> LearnableParam:
	var p = LearnableParam.new(
		data.get("param_id", "p"),
		data.get("param_name", "Param"),
		data.get("description", ""),
		data.get("default_value", 0),
		data.get("min_value", 0.0),
		data.get("max_value", 100.0),
		data.get("step", 1.0),
		data.get("param_type", ParamType.FLOAT)
	)
	p.current_value = data.get("current_value", p.current_value)
	p.discrete_options = data.get("discrete_options", [])
	p.is_locked = data.get("is_locked", false)
	p.best_value = data.get("best_value", p.best_value)
	p.change_count = data.get("change_count", 0)
	return p

func clone() -> LearnableParam:
	var c = LearnableParam.new(param_id, param_name, description, default_value, min_value, max_value, step, param_type)
	c.current_value = current_value
	c.discrete_options = discrete_options.duplicate()
	c.is_locked = is_locked
	c.best_value = best_value
	c.change_count = change_count
	c.last_changed_game = last_changed_game
	return c
