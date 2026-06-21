class_name ParamSet
extends RefCounted

var params: Dictionary = {}
var score: float = 0.0
var games_played: int = 0
var wins: int = 0
var average_reward: float = 0.0
var id: String = ""
var generation: int = 0
var is_elite: bool = false

func _init():
	id = "params_%s_%d" % [Time.get_unix_time_from_system(), randi()]
	_init_default_params()

func _init_default_params():
	var p = preload("res://scripts/learning/learnable_params.gd")
	var p_attack_res = p.new(
		"attack_resource_threshold",
		"进攻资源阈值",
		"资源大于多少才触发进攻",
		80, 20, 200, 5, p.ParamType.INT
	)
	params["attack_resource_threshold"] = p_attack_res
	var p_enemy_range = p.new(
		"enemy_detection_range",
		"敌人检测范围",
		"多远的敌人算威胁（格）",
		8.0, 3.0, 20.0, 1.0, p.ParamType.FLOAT
	)
	params["enemy_detection_range"] = p_enemy_range
	var p_expand_res = p.new(
		"expand_resource_threshold",
		"扩张资源阈值",
		"资源大于多少才扩张训练农民",
		30, 10, 150, 5, p.ParamType.INT
	)
	params["expand_resource_threshold"] = p_expand_res
	var p_max_farmers = p.new(
		"max_farmers_for_expand",
		"扩张最大农民数",
		"农民少于多少才扩张",
		5, 1, 15, 1, p.ParamType.INT
	)
	params["max_farmers_for_expand"] = p_max_farmers
	var p_farmer_cost = p.new(
		"training_farmer_cost",
		"训练农民成本",
		"训练农民消耗资源",
		30, 10, 100, 5, p.ParamType.INT
	)
	params["training_farmer_cost"] = p_farmer_cost
	var p_warrior_cost = p.new(
		"training_warrior_cost",
		"训练战士成本",
		"训练战士消耗资源",
		50, 20, 150, 5, p.ParamType.INT
	)
	params["training_warrior_cost"] = p_warrior_cost
	var p_tick_interval = p.new(
		"ai_tick_interval",
		"AI决策间隔",
		"行为树每几秒决策一次",
		2.0, 0.5, 5.0, 0.25, p.ParamType.FLOAT
	)
	params["ai_tick_interval"] = p_tick_interval
	var p_harvest_priority = p.new(
		"harvest_priority_boost",
		"采集优先级加成",
		"采集任务额外优先级加成",
		0, -20, 40, 5, p.ParamType.INT
	)
	params["harvest_priority_boost"] = p_harvest_priority
	var p_attack_priority = p.new(
		"attack_priority_boost",
		"进攻优先级加成",
		"进攻任务额外优先级加成",
		0, -30, 30, 5, p.ParamType.INT
	)
	params["attack_priority_boost"] = p_attack_priority
	var p_defend_priority = p.new(
		"defend_priority_boost",
		"防守优先级加成",
		"防守任务额外优先级加成",
		10, -20, 40, 5, p.ParamType.INT
	)
	params["defend_priority_boost"] = p_defend_priority
	var p_attack_cooldown = p.new(
		"attack_cool_down",
		"进攻冷却时间",
		"进攻失败后冷却秒数",
		8.0, 2.0, 30.0, 1.0, p.ParamType.FLOAT
	)
	params["attack_cool_down"] = p_attack_cooldown
	var p_defend_cooldown = p.new(
		"defend_cool_down",
		"防守冷却时间",
		"防守任务冷却秒数",
		5.0, 1.0, 20.0, 1.0, p.ParamType.FLOAT
	)
	params["defend_cool_down"] = p_defend_cooldown
	var p_warrior_per_attack = p.new(
		"warriors_per_attack",
		"每次进攻战士数",
		"至少多少战士才进攻",
		1, 1, 10, 1, p.ParamType.INT
	)
	params["warriors_per_attack"] = p_warrior_per_attack
	var p_rush_threshold = p.new(
		"rush_time_threshold",
		"速攻时间阈值",
		"开局多少秒内倾向扩张(0=不速攻)",
		60.0, 0.0, 180.0, 10.0, p.ParamType.FLOAT
	)
	params["rush_time_threshold"] = p_rush_threshold

func get_param(id: String) -> LearnableParam:
	return params.get(id, null)

func get_value(id: String, default_val: Variant = null) -> Variant:
	var p = params.get(id, null)
	if p:
		return p.get_value()
	return default_val

func get_int(id: String, default_val: int = 0) -> int:
	var p = params.get(id, null)
	if p:
		return p.get_int_value()
	return default_val

func get_float(id: String, default_val: float = 0.0) -> float:
	var p = params.get(id, null)
	if p:
		return p.get_float_value()
	return default_val

func set_value(id: String, value: Variant) -> bool:
	var p = params.get(id, null)
	if p:
		return p.set_value(value)
	return false

func mutate(mutation_strength: float = 1.0, rng: RandomNumberGenerator = null) -> ParamSet:
	var result = clone()
	result.id = "params_%s_%d" % [Time.get_unix_time_from_system(), randi()]
	result.generation += 1
	result.score = 0.0
	result.games_played = 0
	result.wins = 0
	result.average_reward = 0.0
	for key in result.params.keys():
		result.params[key] = result.params[key].clone()
		result.params[key].mutate(mutation_strength, rng)
	return result

func crossover(other: ParamSet, blend: float = 0.5, rng: RandomNumberGenerator = null) -> ParamSet:
	var result = clone()
	result.id = "params_%s_%d" % [Time.get_unix_time_from_system(), randi()]
	result.generation = max(generation, other.generation) + 1
	result.score = 0.0
	result.games_played = 0
	result.wins = 0
	result.average_reward = 0.0
	var rg = rng if rng else RandomNumberGenerator.new()
	for key in result.params.keys():
		result.params[key] = result.params[key].clone()
		if rg.randf() < blend:
			var other_p = other.get_param(key)
			if other_p:
				result.params[key].interpolate_to(other_p.get_value(), 0.5 + rg.randf() * 0.3)
	return result

func clone() -> ParamSet:
	var c = ParamSet.new()
	c.id = id
	c.generation = generation
	c.score = score
	c.games_played = games_played
	c.wins = wins
	c.average_reward = average_reward
	c.is_elite = is_elite
	for key in params.keys():
		c.params[key] = params[key].clone()
	return c

func apply_to_ai(ai: AIController):
	if not ai:
		return
	ai.training_farmer_cost = get_int("training_farmer_cost", 30)
	ai.training_warrior_cost = get_int("training_warrior_cost", 50)
	ai.tick_interval = get_float("ai_tick_interval", 2.0)
	if ai.behaviour_tree and ai.behaviour_tree.root:
		_apply_params_to_node(ai.behaviour_tree.root)

func _apply_params_to_node(node: BTNode):
	var condition_script = preload("res://scripts/behaviour_tree/bt_condition.gd")
	if node is condition_script.BTConditionHasResources:
		node.required_amount = get_int("attack_resource_threshold", 80)
	elif node is condition_script.BTConditionEnemyNearby:
		node.detection_range = get_float("enemy_detection_range", 8.0)
	elif node is condition_script.BTConditionCanExpand:
		node.required_amount = get_int("expand_resource_threshold", 30)
	for child in node.get_children():
		_apply_params_to_node(child)

func to_dict() -> Dictionary:
	var param_data: Dictionary = {}
	for key in params.keys():
		param_data[key] = params[key].to_dict()
	return {
		"id": id,
		"generation": generation,
		"score": score,
		"games_played": games_played,
		"wins": wins,
		"win_rate": float(wins) / max(1, games_played),
		"average_reward": average_reward,
		"is_elite": is_elite,
		"params": param_data
	}

static func from_dict(data: Dictionary) -> ParamSet:
	var ps = ParamSet.new()
	ps.id = data.get("id", ps.id)
	ps.generation = data.get("generation", 0)
	ps.score = data.get("score", 0.0)
	ps.games_played = data.get("games_played", 0)
	ps.wins = data.get("wins", 0)
	ps.average_reward = data.get("average_reward", 0.0)
	ps.is_elite = data.get("is_elite", false)
	var param_data = data.get("params", {})
	var p_script = preload("res://scripts/learning/learnable_params.gd")
	for key in param_data.keys():
		if ps.params.has(key):
			ps.params[key] = p_script.LearnableParam.from_dict(param_data[key])
		else:
			ps.params[key] = p_script.LearnableParam.from_dict(param_data[key])
	return ps

func get_summary() -> String:
	var lines: Array = []
	lines.append("参数集ID: %s" % id)
	lines.append("代数: %d" % generation)
	lines.append("得分: %.1f" % score)
	lines.append("战绩: %d战 %d胜 (%.1f%%)" % [games_played, wins, float(wins) / max(1, games_played) * 100.0])
	lines.append("")
	for key in params.keys():
		var p = params[key]
		lines.append("  %s = %s" % [p.param_name, str(p.get_value())])
	return "\n".join(lines)
