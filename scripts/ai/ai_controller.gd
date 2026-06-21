class_name AIController
extends Node

signal ai_updated()
signal behaviour_tree_changed()
signal game_ended(won: bool)
signal stats_updated()

const AITask = preload("res://scripts/ai/ai_task.gd")

var team: int = 0
var resources: int = 100
var farmers: Array[Farmer] = []
var warriors: Array[Warrior] = []
var enemies: Array[UnitBase] = []
var base_position: Vector2i = Vector2i.ZERO
var base_building: Building = null
var grid_map: GridMap = null
var behaviour_tree: BehaviourTree = null
var task_scheduler: TaskScheduler = null
var game_stats: GameStats = null
var rl_engine: RLEngine = null
var current_param_set: ParamSet = null
var current_order: String = "defend"
var auto_harvest: bool = true
var _tick_timer: float = 0.0
var tick_interval: float = 1.0
var training_farmer_cost: int = 30
var training_warrior_cost: int = 50
var use_task_scheduler: bool = true
var use_learning: bool = true
var _game_started: bool = false
var _game_ended: bool = false

func _ready():
	_setup_behaviour_tree()

func _setup_behaviour_tree():
	behaviour_tree = BehaviourTree.new()
	behaviour_tree.set_context_value("ai_controller", self)
	behaviour_tree.set_context_value("grid_map", grid_map)
	behaviour_tree.tree_updated.connect(behaviour_tree_changed.emit)
	behaviour_tree.node_executed.connect(_on_node_executed)
	add_child(behaviour_tree)
	_create_default_behaviour_tree()
	if use_task_scheduler:
		task_scheduler = TaskScheduler.new(self, grid_map)
		add_child(task_scheduler)
		task_scheduler.task_assigned.connect(_on_task_assigned)
		task_scheduler.task_completed.connect(_on_task_completed)
		task_scheduler.task_cancelled.connect(_on_task_cancelled)
	if use_learning:
		game_stats = preload("res://scripts/learning/game_stats.gd").new()
		game_stats.team = team
		add_child(game_stats)
		game_stats.stats_updated.connect(stats_updated.emit)
		game_stats.game_ended.connect(_on_stats_game_ended)
		rl_engine = preload("res://scripts/learning/rl_engine.gd").new()
		rl_engine.save_path = "user://ai_learning_team%d.json" % team
		add_child(rl_engine)
		rl_engine.init_with_ai(self)
		current_param_set = rl_engine.current_param

func start_game():
	_game_started = true
	_game_ended = false
	if game_stats:
		game_stats.start_game()

func end_game(won: bool):
	if _game_ended:
		return
	_game_ended = true
	_game_started = false
	if game_stats:
		game_stats.end_game(won)
	game_ended.emit(won)

func _create_default_behaviour_tree():
	var composite_script = preload("res://scripts/behaviour_tree/bt_composite.gd")
	var condition_script = preload("res://scripts/behaviour_tree/bt_condition.gd")
	var action_script = preload("res://scripts/behaviour_tree/bt_action.gd")
	var root = composite_script.BTSelector.new("AI Root")
	var defend_branch = composite_script.BTSequence.new("Defend Branch")
	var enemy_nearby = condition_script.BTConditionEnemyNearby.new("Enemy Nearby?")
	enemy_nearby.detection_range = 8.0
	var defend_action = action_script.BTActionDefend.new("Defend")
	defend_branch.add_child(enemy_nearby)
	defend_branch.add_child(defend_action)
	var expand_branch = composite_script.BTSequence.new("Expand Branch")
	var can_expand = condition_script.BTConditionCanExpand.new("Can Expand?")
	var expand_action = action_script.BTActionExpand.new("Expand")
	var harvest_action = action_script.BTActionHarvest.new("Harvest")
	expand_branch.add_child(can_expand)
	expand_branch.add_child(expand_action)
	expand_branch.add_child(harvest_action)
	var attack_branch = composite_script.BTSequence.new("Attack Branch")
	var has_resources = condition_script.BTConditionHasResources.new("Has Resources?")
	has_resources.required_amount = 80
	var attack_action = action_script.BTActionAttack.new("Attack")
	attack_branch.add_child(has_resources)
	attack_branch.add_child(attack_action)
	var default_harvest = action_script.BTActionHarvest.new("Default Harvest")
	root.add_child(defend_branch)
	root.add_child(expand_branch)
	root.add_child(attack_branch)
	root.add_child(default_harvest)
	behaviour_tree.set_root(root)

func _process(delta: float):
	_tick_timer += delta
	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		if behaviour_tree:
			behaviour_tree.tick(tick_interval)
		_update_enemies()
		ai_updated.emit()

func _update_enemies():
	enemies.clear()
	if not base_building:
		return
	var children = get_tree().get_nodes_in_group("units")
	for child in children:
		if child is UnitBase and child.team != team and is_instance_valid(child):
			enemies.append(child)

func _on_node_executed(node: BTNode, status: int):
	if not node:
		return
	if node.category == "AI Action":
		if "Attack" in node.node_name or "进攻" in node.description:
			_record_bt_action("attack")
		elif "Defend" in node.node_name or "防守" in node.description:
			_record_bt_action("defend")
		elif "Expand" in node.node_name or "扩张" in node.description:
			_record_bt_action("expand")
		elif "Harvest" in node.node_name or "采集" in node.description:
			_record_bt_action("harvest")

func _on_task_assigned(task: AITask, unit: UnitBase):
	if unit and unit.fsm:
		unit.fsm.set_parameter("current_task", task)

func _on_task_completed(task: AITask, success: bool):
	if task.assigned_unit and is_instance_valid(task.assigned_unit) and task.assigned_unit.fsm:
		task.assigned_unit.fsm.set_parameter("current_task", null)

func _on_task_cancelled(task: AITask):
	if task.assigned_unit and is_instance_valid(task.assigned_unit) and task.assigned_unit.fsm:
		task.assigned_unit.fsm.set_parameter("current_task", null)

func set_behaviour_tree_root(root: BTNode):
	if behaviour_tree:
		behaviour_tree.set_root(root)

func train_farmer() -> bool:
	if resources < training_farmer_cost or not base_building or not grid_map:
		return false
	var spawn_pos = grid_map.find_empty_near(base_position, 2)
	if spawn_pos == base_position:
		return false
	spend_resources(training_farmer_cost)
	if game_stats:
		game_stats.record_unit_trained(0)
	var farmer = Farmer.new()
	farmer.team = team
	farmer.grid_pos = spawn_pos
	farmer.position = grid_map.grid_to_world(spawn_pos)
	farmer.grid_map = grid_map
	farmer.team_color = base_building.team_color
	farmer.fsm.set_parameter("ai_controller", self)
	farmer.fsm.set_parameter("base_position", base_position)
	farmer.fsm.set_parameter("enemies", enemies)
	farmer.fsm.set_parameter("task_scheduler", task_scheduler)
	farmer.add_to_group("units")
	get_tree().root.add_child(farmer)
	grid_map.place_unit(spawn_pos, farmer)
	farmers.append(farmer)
	farmer.unit_died.connect(_on_unit_died)
	farmer.state_changed.connect(_on_unit_state_changed.bind(farmer))
	return true

func train_warrior() -> bool:
	if resources < training_warrior_cost or not base_building or not grid_map:
		return false
	var spawn_pos = grid_map.find_empty_near(base_position, 2)
	if spawn_pos == base_position:
		return false
	spend_resources(training_warrior_cost)
	if game_stats:
		game_stats.record_unit_trained(1)
	var warrior = Warrior.new()
	warrior.team = team
	warrior.grid_pos = spawn_pos
	warrior.position = grid_map.grid_to_world(spawn_pos)
	warrior.grid_map = grid_map
	warrior.team_color = base_building.team_color
	warrior.fsm.set_parameter("ai_controller", self)
	warrior.fsm.set_parameter("base_position", base_position)
	warrior.fsm.set_parameter("enemies", enemies)
	warrior.fsm.set_parameter("task_scheduler", task_scheduler)
	warrior.add_to_group("units")
	get_tree().root.add_child(warrior)
	grid_map.place_unit(spawn_pos, warrior)
	warriors.append(warrior)
	warrior.unit_died.connect(_on_unit_died)
	warrior.state_changed.connect(_on_unit_state_changed.bind(warrior))
	return true

func _on_unit_state_changed(old_state: String, new_state: String, unit: UnitBase):
	if not task_scheduler:
		return
	var current_task = unit.fsm.get_parameter("current_task", null)
	if current_task:
		if new_state == "Idle" and old_state != "Idle":
			if current_task.status == AITask.TaskStatus.EXECUTING:
				if old_state == "Harvest" or old_state == "Deposit":
					current_task.complete(true)
				elif old_state == "Attack":
					if unit.target_unit and not is_instance_valid(unit.target_unit):
						current_task.complete(true)
					else:
						current_task.complete(false)

func order_attack():
	current_order = "attack"
	for warrior in warriors:
		if is_instance_valid(warrior) and warrior.fsm:
			warrior.fsm.set_parameter("enemies", enemies)

func order_defend():
	current_order = "defend"
	for warrior in warriors:
		if is_instance_valid(warrior) and warrior.fsm:
			warrior.fsm.set_parameter("enemies", enemies)

func order_harvest():
	auto_harvest = true

func _on_unit_died(unit: UnitBase):
	if unit is Farmer:
		farmers.erase(unit)
		if game_stats:
			game_stats.record_unit_lost(0, false)
	elif unit is Warrior:
		warriors.erase(unit)
		if game_stats:
			game_stats.record_unit_lost(1, false)
	if unit.target_unit:
		if is_instance_valid(unit.target_unit):
			if game_stats:
				game_stats.record_unit_lost(unit.target_unit.unit_type, unit.team != unit.target_unit.team)

func get_farmer_count() -> int:
	var count = 0
	for f in farmers:
		if is_instance_valid(f):
			count += 1
	return count

func get_warrior_count() -> int:
	var count = 0
	for w in warriors:
		if is_instance_valid(w):
			count += 1
	return count

func get_learned_param_int(param_key: String, default_val: int = -1) -> int:
	if rl_engine and rl_engine.current_param:
		return rl_engine.current_param.get_int(param_key, default_val)
	if current_param_set:
		return current_param_set.get_int(param_key, default_val)
	return default_val

func get_learned_param_float(param_key: String, default_val: float = -1.0) -> float:
	if rl_engine and rl_engine.current_param:
		return rl_engine.current_param.get_float(param_key, default_val)
	if current_param_set:
		return current_param_set.get_float(param_key, default_val)
	return default_val

func _on_stats_game_ended(stats_dict: Dictionary, won: bool):
	if rl_engine:
		rl_engine.on_game_ended(stats_dict, won)
		if rl_engine.current_param:
			current_param_set = rl_engine.current_param
			rl_engine.current_param.apply_to_ai(self)

func _record_bt_action(action_type: String):
	if game_stats:
		game_stats.record_bt_action(action_type)

func spend_resources(amount: int):
	resources -= amount
	if game_stats:
		game_stats.record_spend(amount)
