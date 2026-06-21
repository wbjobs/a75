class_name AIController
extends Node

signal ai_updated()
signal behaviour_tree_changed()

var team: int = 0
var resources: int = 100
var farmers: Array[Farmer] = []
var warriors: Array[Warrior] = []
var enemies: Array[UnitBase] = []
var base_position: Vector2i = Vector2i.ZERO
var base_building: Building = null
var grid_map: GridMap = null
var behaviour_tree: BehaviourTree = null
var current_order: String = "defend"
var auto_harvest: bool = true
var _tick_timer: float = 0.0
var tick_interval: float = 1.0
var training_farmer_cost: int = 30
var training_warrior_cost: int = 50

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
	pass

func set_behaviour_tree_root(root: BTNode):
	if behaviour_tree:
		behaviour_tree.set_root(root)

func train_farmer() -> bool:
	if resources < training_farmer_cost or not base_building or not grid_map:
		return false
	var spawn_pos = grid_map.find_empty_near(base_position, 2)
	if spawn_pos == base_position:
		return false
	resources -= training_farmer_cost
	var farmer = Farmer.new()
	farmer.team = team
	farmer.grid_pos = spawn_pos
	farmer.position = grid_map.grid_to_world(spawn_pos)
	farmer.grid_map = grid_map
	farmer.team_color = base_building.team_color
	farmer.fsm.set_parameter("ai_controller", self)
	farmer.fsm.set_parameter("base_position", base_position)
	farmer.fsm.set_parameter("enemies", enemies)
	farmer.add_to_group("units")
	get_tree().root.add_child(farmer)
	grid_map.place_unit(spawn_pos, farmer)
	farmers.append(farmer)
	farmer.unit_died.connect(_on_unit_died)
	return true

func train_warrior() -> bool:
	if resources < training_warrior_cost or not base_building or not grid_map:
		return false
	var spawn_pos = grid_map.find_empty_near(base_position, 2)
	if spawn_pos == base_position:
		return false
	resources -= training_warrior_cost
	var warrior = Warrior.new()
	warrior.team = team
	warrior.grid_pos = spawn_pos
	warrior.position = grid_map.grid_to_world(spawn_pos)
	warrior.grid_map = grid_map
	warrior.team_color = base_building.team_color
	warrior.fsm.set_parameter("ai_controller", self)
	warrior.fsm.set_parameter("base_position", base_position)
	warrior.fsm.set_parameter("enemies", enemies)
	warrior.add_to_group("units")
	get_tree().root.add_child(warrior)
	grid_map.place_unit(spawn_pos, warrior)
	warriors.append(warrior)
	warrior.unit_died.connect(_on_unit_died)
	return true

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
	elif unit is Warrior:
		warriors.erase(unit)

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
