class_name GameStats
extends Node

signal stats_updated()
signal game_ended(stats: Dictionary, won: bool)

var team: int = 0
var start_time: float = 0.0
var end_time: float = 0.0
var duration: float = 0.0

var initial_resources: int = 100
var final_resources: int = 0
var peak_resources: int = 0
var total_harvested: int = 0
var total_spent: int = 0

var farmers_trained: int = 0
var warriors_trained: int = 0
var farmers_lost: int = 0
var warriors_lost: int = 0
var enemy_farmers_killed: int = 0
var enemy_warriors_killed: int = 0
var enemy_buildings_destroyed: int = 0

var battles_initiated: int = 0
var battles_won: int = 0
var battles_lost: int = 0
var total_damage_dealt: int = 0
var total_damage_taken: int = 0

var times_attacked: int = 0
var times_defended: int = 0
var times_expanded: int = 0
var times_harvest_ordered: int = 0

var resource_curve: Array = []
var unit_count_curve: Array = []
var battle_count: int = 0
var _sample_interval: float = 5.0
var _sample_timer: float = 0.0
var won: bool = false
var ended: bool = false

func start_game():
	start_time = Time.get_ticks_msec() / 1000.0
	_sample_timer = 0.0
	ended = false
	resource_curve.clear()
	unit_count_curve.clear()
	stats_updated.emit()

func _process(delta: float):
	if ended:
		return
	_sample_timer += delta
	if _sample_timer >= _sample_interval:
		_sample_timer = 0.0
		_sample_stats()
	duration = Time.get_ticks_msec() / 1000.0 - start_time

func _sample_stats():
	var ai = get_parent()
	var res = ai.resources if ai else 0
	var farmer_count = 0
	var warrior_count = 0
	if ai:
		farmer_count = ai.get_farmer_count()
		warrior_count = ai.get_warrior_count()
	resource_curve.append({
		"time": duration,
		"resources": res,
		"farmers": farmer_count,
		"warriors": warrior_count
	})
	unit_count_curve.append({
		"time": duration,
		"total": farmer_count + warrior_count,
		"farmers": farmer_count,
		"warriors": warrior_count
	})
	peak_resources = max(peak_resources, res)
	stats_updated.emit()

func end_game(did_win: bool):
	ended = true
	won = did_win
	end_time = Time.get_ticks_msec() / 1000.0
	duration = end_time - start_time
	_sample_stats()
	var ai = get_parent()
	if ai:
		final_resources = ai.resources
	game_ended.emit(to_dict(), won)

func record_harvest(amount: int):
	total_harvested += amount
	stats_updated.emit()

func record_spend(amount: int):
	total_spent += amount
	stats_updated.emit()

func record_unit_trained(unit_type: int):
	match unit_type:
		0:
			farmers_trained += 1
		1:
			warriors_trained += 1
	stats_updated.emit()

func record_unit_lost(unit_type: int, is_enemy: bool = false):
	if is_enemy:
		match unit_type:
			0:
				enemy_farmers_killed += 1
			1:
				enemy_warriors_killed += 1
	else:
		match unit_type:
			0:
				farmers_lost += 1
			1:
				warriors_lost += 1
	stats_updated.emit()

func record_building_destroyed(is_enemy: bool = true):
	if is_enemy:
		enemy_buildings_destroyed += 1
	stats_updated.emit()

func record_battle(initiated: bool, won_battle: bool):
	battle_count += 1
	if initiated:
		battles_initiated += 1
	if won_battle:
		battles_won += 1
	else:
		battles_lost += 1
	stats_updated.emit()

func record_damage(dealt: int, taken: int):
	total_damage_dealt += dealt
	total_damage_taken += taken
	stats_updated.emit()

func record_bt_action(action_type: String):
	match action_type:
		"attack":
			times_attacked += 1
		"defend":
			times_defended += 1
		"expand":
			times_expanded += 1
		"harvest":
			times_harvest_ordered += 1
	stats_updated.emit()

func compute_score() -> float:
	var score: float = 0.0
	if won:
		score += 1000.0
	else:
		score -= 200.0
	score += enemy_farmers_killed * 10.0
	score += enemy_warriors_killed * 30.0
	score += enemy_buildings_destroyed * 200.0
	score += total_harvested * 0.5
	score -= farmers_lost * 15.0
	score -= warriors_lost * 40.0
	score -= total_damage_taken * 0.1
	score += total_damage_dealt * 0.05
	if duration > 0:
		score -= duration * 0.5
	if battles_initiated > 0:
		score += float(battles_won) / float(battles_initiated) * 200.0
	return score

func compute_reward_vector() -> Dictionary:
	return {
		"win_bonus": 1.0 if won else -0.5,
		"resource_efficiency": clamp(float(total_harvested) / max(1, initial_resources + farmers_trained * 5), 0.0, 3.0) - 1.0,
		"kill_efficiency": clamp(float(enemy_farmers_killed + enemy_warriors_killed) / max(1, farmers_lost + warriors_lost + 1), 0.0, 5.0) - 1.0,
		"battle_win_rate": float(battles_won) / max(1, battles_initiated + 1),
		"army_size_score": clamp(float(warriors_trained) / 8.0, 0.0, 2.0) - 1.0,
		"economy_score": clamp(float(farmers_trained) / 4.0, 0.0, 2.0) - 1.0,
		"damage_efficiency": clamp(float(total_damage_dealt) / max(1, total_damage_taken + 1), 0.0, 5.0) - 1.0,
		"duration_penalty": -clamp(duration / 300.0, 0.0, 2.0)
	}

func to_dict() -> Dictionary:
	return {
		"team": team,
		"won": won,
		"duration": duration,
		"score": compute_score(),
		"resources": {
			"initial": initial_resources,
			"final": final_resources,
			"peak": peak_resources,
			"total_harvested": total_harvested,
			"total_spent": total_spent
		},
		"units": {
			"farmers_trained": farmers_trained,
			"warriors_trained": warriors_trained,
			"farmers_lost": farmers_lost,
			"warriors_lost": warriors_lost,
			"enemy_farmers_killed": enemy_farmers_killed,
			"enemy_warriors_killed": enemy_warriors_killed,
			"enemy_buildings_destroyed": enemy_buildings_destroyed
		},
		"battles": {
			"initiated": battles_initiated,
			"won": battles_won,
			"lost": battles_lost,
			"damage_dealt": total_damage_dealt,
			"damage_taken": total_damage_taken
		},
		"actions": {
			"attacks": times_attacked,
			"defends": times_defended,
			"expands": times_expanded,
			"harvests": times_harvest_ordered
		},
		"rewards": compute_reward_vector()
	}
