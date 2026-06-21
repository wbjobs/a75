class_name RLEngine
extends Node

signal learning_step_completed(stats: Dictionary)
signal best_params_changed(new_best: ParamSet)
signal new_params_selected(params: ParamSet)
signal learning_state_changed(state: Dictionary)

enum LearnMode {
	EXPLOIT,
	EXPLORE,
	CROSSOVER,
	RANDOM
}

var ai_controller: AIController = null
var param_population: Array[ParamSet] = []
var best_param: ParamSet = null
var current_param: ParamSet = null
var total_games: int = 0
var total_wins: int = 0
var best_score: float = -999999.0
var exploration_rate: float = 0.3
var min_exploration_rate: float = 0.05
var exploration_decay: float = 0.995
var learning_rate: float = 0.2
var population_size: int = 10
var elite_count: int = 2
var mutation_strength: float = 1.0
var auto_save: bool = true
var auto_save_interval: int = 5
var _games_since_save: int = 0
var recent_history: Array = []
var max_history: int = 100
var last_learn_mode: int = LearnMode.EXPLOIT
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var save_path: String = "user://ai_learning_data.json"
var _reward_ema: float = 0.0
var _best_param_generation: int = 0

func _ready():
	rng.randomize()

func init_with_ai(ai: AIController):
	ai_controller = ai
	_load_or_init_population()
	if current_param:
		current_param.apply_to_ai(ai_controller)
		emit_signal("new_params_selected", current_param)
	learning_state_changed.emit(get_state())

func _load_or_init_population():
	if FileAccess.file_exists(save_path):
		_load_from_file()
	else:
		_init_population()
	_update_best()

func _init_population():
	param_population.clear()
	var base = ParamSet.new()
	base.generation = 0
	param_population.append(base)
	for i in range(population_size - 1):
		var mutant = base.mutate(1.5, rng)
		param_population.append(mutant)
	current_param = base.clone()
	best_param = base.clone()
	best_score = _compute_adjusted_score(best_param)
	best_param.mark_as_best()

func _load_from_file():
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		_init_population()
		return
	var json = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json)
	if not data is Dictionary:
		_init_population()
		return
	var pop_data = data.get("population", [])
	param_population.clear()
	var ps_script = preload("res://scripts/learning/param_set.gd")
	for pd in pop_data:
		param_population.append(ps_script.ParamSet.from_dict(pd))
	if param_population.size() == 0:
		_init_population()
		return
	var current_data = data.get("current_param", {})
	if current_data:
		current_param = ps_script.ParamSet.from_dict(current_data)
	else:
		current_param = param_population[0].clone()
	var best_data = data.get("best_param", {})
	if best_data:
		best_param = ps_script.ParamSet.from_dict(best_data)
		best_score = _compute_adjusted_score(best_param)
	total_games = data.get("total_games", 0)
	total_wins = data.get("total_wins", 0)
	exploration_rate = data.get("exploration_rate", 0.3)
	learning_rate = data.get("learning_rate", 0.2)
	mutation_strength = data.get("mutation_strength", 1.0)
	_reward_ema = data.get("reward_ema", 0.0)
	_best_param_generation = data.get("best_param_generation", 0)
	var hist_data = data.get("history", [])
	recent_history = hist_data.slice(max(0, hist_data.size() - max_history))
	_update_best()

func save_to_file():
	var pop_data: Array = []
	for ps in param_population:
		pop_data.append(ps.to_dict())
	var data: Dictionary = {
		"population": pop_data,
		"current_param": current_param.to_dict() if current_param else {},
		"best_param": best_param.to_dict() if best_param else {},
		"total_games": total_games,
		"total_wins": total_wins,
		"exploration_rate": exploration_rate,
		"learning_rate": learning_rate,
		"mutation_strength": mutation_strength,
		"reward_ema": _reward_ema,
		"best_param_generation": _best_param_generation,
		"history": recent_history,
		"save_time": Time.get_datetime_dict_from_system()
	}
	var dir = save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_absolute(dir)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func on_game_ended(game_stats_dict: Dictionary, won: bool):
	if not current_param:
		return
	total_games += 1
	if won:
		total_wins += 1
	var score = game_stats_dict.get("score", 0.0)
	var rewards = game_stats_dict.get("rewards", {})
	var reward = _compute_total_reward(rewards)
	if _reward_ema == 0.0:
		_reward_ema = reward
	else:
		_reward_ema = _reward_ema * 0.9 + reward * 0.1
	_update_param_results(current_param, score, won, reward)
	var hist_entry = {
		"game": total_games,
		"won": won,
		"score": score,
		"reward": reward,
		"reward_ema": _reward_ema,
		"param_id": current_param.id,
		"mode": _get_mode_name(last_learn_mode),
		"stats_summary": {
			"duration": game_stats_dict.get("duration", 0),
			"farmers": game_stats_dict.get("units", {}).get("farmers_trained", 0),
			"warriors": game_stats_dict.get("units", {}).get("warriors_trained", 0),
			"kills": game_stats_dict.get("units", {}).get("enemy_farmers_killed", 0) + game_stats_dict.get("units", {}).get("enemy_warriors_killed", 0)
		}
	}
	recent_history.append(hist_entry)
	if recent_history.size() > max_history:
		recent_history.pop_front()
	var was_best = _update_best()
	_evolve_population(score, won)
	_select_next_param()
	if exploration_rate > min_exploration_rate:
		exploration_rate *= exploration_decay
	_games_since_save += 1
	if auto_save and _games_since_save >= auto_save_interval:
		save_to_file()
		_games_since_save = 0
	current_param.apply_to_ai(ai_controller)
	emit_signal("learning_step_completed", {
		"won": won,
		"score": score,
		"reward": reward,
		"reward_ema": _reward_ema,
		"was_best": was_best,
		"exploration_rate": exploration_rate,
		"next_mode": _get_mode_name(last_learn_mode)
	})
	learning_state_changed.emit(get_state())
	emit_signal("new_params_selected", current_param)

func _compute_total_reward(rewards: Dictionary) -> float:
	var total: float = 0.0
	for key in rewards.keys():
		total += rewards[key]
	return total

func _update_param_results(ps: ParamSet, score: float, won: bool, reward: float):
	for p in param_population:
		if p.id == ps.id:
			p.games_played += 1
			if won:
				p.wins += 1
			p.average_reward = (p.average_reward * (p.games_played - 1) + reward) / p.games_played
			p.score = p.average_reward * 100.0 + float(p.wins) / max(1, p.games_played) * 50.0
			return
	ps.games_played = 1
	ps.wins = 1 if won else 0
	ps.average_reward = reward
	ps.score = ps.average_reward * 100.0 + float(ps.wins) * 50.0
	param_population.append(ps)

func _update_best() -> bool:
	var was_best = false
	for p in param_population:
		var adj = _compute_adjusted_score(p)
		if adj > best_score:
			best_score = adj
			best_param = p.clone()
			best_param.mark_as_best()
			_best_param_generation = total_games
			was_best = true
			for key in best_param.params.keys():
				if p.params.has(key):
					best_param.params[key].mark_as_best()
			emit_signal("best_params_changed", best_param)
	return was_best

func _compute_adjusted_score(ps: ParamSet) -> float:
	if ps.games_played == 0:
		return ps.score
	var win_rate = float(ps.wins) / ps.games_played
	var confidence = 1.0 - exp(-float(ps.games_played) / 5.0)
	return (ps.average_reward * 100.0 + win_rate * 200.0) * confidence - (1.0 - confidence) * 50.0

func _evolve_population(score: float, won: bool):
	param_population.sort_custom(func(a: ParamSet, b: ParamSet) -> bool:
		return _compute_adjusted_score(a) > _compute_adjusted_score(b)
	)
	while param_population.size() > population_size:
		param_population.pop_back()
	while param_population.size() < population_size:
		var new_p: ParamSet
		var roll = rng.randf()
		if roll < 0.2 and param_population.size() > 1:
			var p1 = param_population[rng.randi_range(0, min(elite_count, param_population.size() - 1))]
			var p2 = param_population[rng.randi_range(0, min(elite_count + 2, param_population.size() - 1))]
			new_p = p1.crossover(p2, 0.5, rng)
		elif roll < 0.8 and best_param:
			var ms = mutation_strength * (1.0 + rng.randf() * 0.5)
			new_p = best_param.mutate(ms, rng)
		else:
			var base_idx = min(elite_count, param_population.size() - 1)
			new_p = param_population[base_idx].mutate(mutation_strength * 2.0, rng)
		param_population.append(new_p)

func _select_next_param():
	var roll = rng.randf()
	if roll < exploration_rate:
		last_learn_mode = LearnMode.EXPLORE
		var explored: Array[ParamSet] = []
		for p in param_population:
			if p.games_played < 3:
				explored.append(p)
		if explored.size() > 0:
			current_param = explored[rng.randi_range(0, explored.size() - 1)].clone()
		else:
			var idx = rng.randi_range(0, min(population_size / 2, param_population.size() - 1))
			current_param = param_population[idx].mutate(mutation_strength * 0.5, rng)
			last_learn_mode = LearnMode.RANDOM
	elif roll < exploration_rate + 0.1 and param_population.size() > 1 and best_param:
		last_learn_mode = LearnMode.CROSSOVER
		var elite = param_population[rng.randi_range(0, min(elite_count, param_population.size() - 1))]
		current_param = elite.crossover(best_param, 0.6, rng)
	else:
		last_learn_mode = LearnMode.EXPLOIT
		if best_param and rng.randf() < 0.7:
			current_param = best_param.clone()
			if rng.randf() < 0.3:
				current_param = current_param.mutate(mutation_strength * 0.3, rng)
		elif param_population.size() > 0:
			current_param = param_population[0].clone()
		else:
			current_param = ParamSet.new()
	if not current_param:
		current_param = ParamSet.new()
	current_param.score = 0.0
	current_param.games_played = 0

func _get_mode_name(mode: int) -> String:
	match mode:
		LearnMode.EXPLOIT:
			return "利用"
		LearnMode.EXPLORE:
			return "探索"
		LearnMode.CROSSOVER:
			return "交叉"
		LearnMode.RANDOM:
			return "随机"
		_:
			return "未知"

func reset_learning():
	param_population.clear()
	recent_history.clear()
	total_games = 0
	total_wins = 0
	exploration_rate = 0.3
	_reward_ema = 0.0
	_best_param_generation = 0
	best_score = -999999.0
	_init_population()
	learning_state_changed.emit(get_state())

func force_use_best():
	if best_param:
		current_param = best_param.clone()
		current_param.apply_to_ai(ai_controller)
		emit_signal("new_params_selected", current_param)
		learning_state_changed.emit(get_state())

func set_param_directly(param_id: String, value: Variant):
	if current_param:
		current_param.set_value(param_id, value)
		current_param.apply_to_ai(ai_controller)
		learning_state_changed.emit(get_state())

func get_state() -> Dictionary:
	return {
		"total_games": total_games,
		"total_wins": total_wins,
		"win_rate": float(total_wins) / max(1, total_games),
		"exploration_rate": exploration_rate,
		"best_score": best_score,
		"reward_ema": _reward_ema,
		"population_size": param_population.size(),
		"current_param_id": current_param.id if current_param else "",
		"current_generation": current_param.generation if current_param else 0,
		"best_param_generation": _best_param_generation,
		"last_mode": _get_mode_name(last_learn_mode),
		"games_since_best": total_games - _best_param_generation,
		"save_path": save_path
	}

func get_current_params_dict() -> Dictionary:
	if not current_param:
		return {}
	return current_param.to_dict().get("params", {})

func get_best_params_dict() -> Dictionary:
	if not best_param:
		return {}
	return best_param.to_dict().get("params", {})

func get_recent_games_summary(count: int = 10) -> Array:
	return recent_history.slice(max(0, recent_history.size() - count))

func _draw_debug_ui(container: Control):
	pass
