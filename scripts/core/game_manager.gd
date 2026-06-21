class_name GameManager
extends Node2D

signal game_started()
signal game_restarted()
signal game_ended(player_won: bool)
signal editor_toggled(visible: bool)

var grid_map: GridMap = null
var player_ai: AIController = null
var enemy_ai: AIController = null
var hud: GameHUD = null
var bt_editor_window: Window = null
var bt_editor: BTEditor = null
var learning_panel_window: Window = null
var learning_panel: Control = null
var _editor_visible: bool = false
var _game_active: bool = true
var _max_game_duration: float = 240.0
var _game_timer: float = 0.0
var _game_count: int = 0
var _restart_btn: Button = null
var _game_timer_label: Label = null
var _game_count_label: Label = null

func _ready():
	add_to_group("game_manager")
	_setup_grid()
	_setup_ai()
	_setup_hud()
	_setup_editor_window()
	_setup_learning_panel()
	_setup_game_end_listeners()
	_start_game()

func _setup_grid():
	grid_map = GridMap.new()
	add_child(grid_map)

func _setup_ai():
	player_ai = AIController.new()
	player_ai.team = 0
	player_ai.grid_map = grid_map
	player_ai.base_position = Vector2i(5, 10)
	player_ai.tick_interval = 2.0
	add_child(player_ai)
	var player_base = Building.new()
	player_base.team = 0
	player_base.grid_pos = player_ai.base_position
	player_base.position = grid_map.grid_to_world(player_ai.base_position)
	player_base.team_color = Color(0.2, 0.6, 1.0)
	player_ai.base_building = player_base
	add_child(player_base)
	grid_map.place_building(player_ai.base_position, player_base)
	player_base.building_destroyed.connect(_on_base_destroyed.bind(player_ai))
	enemy_ai = AIController.new()
	enemy_ai.team = 1
	enemy_ai.grid_map = grid_map
	enemy_ai.base_position = Vector2i(26, 10)
	enemy_ai.tick_interval = 2.0
	add_child(enemy_ai)
	var enemy_base = Building.new()
	enemy_base.team = 1
	enemy_base.grid_pos = enemy_ai.base_position
	enemy_base.position = grid_map.grid_to_world(enemy_ai.base_position)
	enemy_base.team_color = Color(1.0, 0.3, 0.3)
	enemy_ai.base_building = enemy_base
	add_child(enemy_base)
	grid_map.place_building(enemy_ai.base_position, enemy_base)
	enemy_base.building_destroyed.connect(_on_base_destroyed.bind(enemy_ai))

func _setup_hud():
	hud = GameHUD.new()
	hud.set_player_ai(player_ai)
	hud.set_enemy_ai(enemy_ai)
	add_child(hud)
	var top_hb = HBoxContainer.new()
	top_hb.custom_minimum_size = Vector2(0, 30)
	top_hb.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	top_hb.offset_top = 10
	top_hb.offset_left = 10
	add_child(top_hb)
	_game_count_label = Label.new()
	_game_count_label.text = "局数: 0"
	_game_count_label.add_theme_color_override("font_color", Color.WHITE)
	_game_count_label.add_theme_font_size_override("font_size", 12)
	top_hb.add_child(_game_count_label)
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(15, 0)
	top_hb.add_child(spacer1)
	_game_timer_label = Label.new()
	_game_timer_label.text = "时间: 0s / 240s"
	_game_timer_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	_game_timer_label.add_theme_font_size_override("font_size", 12)
	top_hb.add_child(_game_timer_label)
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(15, 0)
	top_hb.add_child(spacer2)
	_restart_btn = Button.new()
	_restart_btn.text = "重开下一局"
	_restart_btn.pressed.connect(trigger_game_restart)
	top_hb.add_child(_restart_btn)
	var show_learning_btn = Button.new()
	show_learning_btn.text = "学习面板"
	show_learning_btn.pressed.connect(toggle_learning_panel)
	show_learning_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	top_hb.add_child(show_learning_btn)

func _setup_editor_window():
	bt_editor_window = Window.new()
	bt_editor_window.title = "行为树编辑器 - 实时调试中"
	bt_editor_window.unresizable = false
	bt_editor_window.size = Vector2i(1000, 700)
	bt_editor_window.visible = false
	bt_editor_window.close_requested.connect(_on_editor_close)
	get_tree().root.add_child(bt_editor_window)
	bt_editor = BTEditor.new()
	bt_editor.set_ai_controller(player_ai)
	bt_editor_window.add_child(bt_editor)

func _setup_learning_panel():
	learning_panel_window = Window.new()
	learning_panel_window.title = "AI强化学习面板"
	learning_panel_window.unresizable = false
	learning_panel_window.size = Vector2i(700, 800)
	learning_panel_window.visible = false
	learning_panel_window.close_requested.connect(_on_learning_panel_close)
	get_tree().root.add_child(learning_panel_window)
	learning_panel = preload("res://scripts/ui/learning_panel.gd").new()
	learning_panel.set_rl_engine(player_ai.rl_engine, player_ai)
	learning_panel_window.add_child(learning_panel)

func _setup_game_end_listeners():
	if player_ai:
		player_ai.game_ended.connect(_on_ai_game_ended.bind(0))
	if enemy_ai:
		enemy_ai.game_ended.connect(_on_ai_game_ended.bind(1))

func _on_base_destroyed(building: Building, losing_ai: AIController):
	if not _game_active:
		return
	var player_won = (losing_ai.team == 1)
	_end_game(player_won)

func _on_ai_game_ended(won: bool, team: int):
	pass

func _start_game():
	_game_active = true
	_game_timer = 0.0
	_game_count += 1
	if player_ai:
		player_ai.start_game()
	if enemy_ai:
		enemy_ai.start_game()
	for i in range(2):
		player_ai.train_farmer()
		enemy_ai.train_farmer()
	player_ai.train_warrior()
	enemy_ai.train_warrior()
	game_started.emit()
	game_restarted.emit()

func trigger_game_restart():
	_end_game(false, true)

func _end_game(player_won: bool, is_forced: bool = false):
	if not _game_active:
		return
	_game_active = false
	if player_ai:
		player_ai.end_game(player_won)
	if enemy_ai:
		enemy_ai.end_game(not player_won)
	game_ended.emit(player_won)
	_game_count_label.text = "局数: %d" % _game_count
	_timer = get_tree().create_timer(3.0)
	_timer.timeout.connect(_restart_game)

func _restart_game():
	for child in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(child):
			child.queue_free()
	if grid_map:
		grid_map.queue_free()
	_remove_children_safely([player_ai, enemy_ai])
	call_deferred("_reinit_game")

func _remove_children_safely(nodes: Array):
	for n in nodes:
		if n and is_instance_valid(n):
			n.queue_free()

func _reinit_game():
	_setup_grid()
	_setup_ai()
	_setup_game_end_listeners()
	if hud:
		hud.set_player_ai(player_ai)
		hud.set_enemy_ai(enemy_ai)
	if bt_editor:
		bt_editor.set_ai_controller(player_ai)
	if learning_panel:
		learning_panel.set_rl_engine(player_ai.rl_engine, player_ai)
	_start_game()

func toggle_editor():
	_editor_visible = not _editor_visible
	bt_editor_window.visible = _editor_visible
	editor_toggled.emit(_editor_visible)

func toggle_learning_panel():
	learning_panel_window.visible = not learning_panel_window.visible

func _on_editor_close():
	_editor_visible = false
	bt_editor_window.visible = false
	editor_toggled.emit(false)

func _on_learning_panel_close():
	learning_panel_window.visible = false

func _process(delta):
	if _game_active:
		_game_timer += delta
		var time_str = "时间: %ds / %ds" % [int(_game_timer), int(_max_game_duration)]
		_game_timer_label.text = time_str
		if _game_timer >= _max_game_duration:
			var player_score = 500
			var enemy_score = 500
			if player_ai and player_ai.base_building:
				player_score += player_ai.base_building.health
			if enemy_ai and enemy_ai.base_building:
				enemy_score += enemy_ai.base_building.health
			if player_ai:
				player_score += player_ai.get_warrior_count() * 50 + player_ai.get_farmer_count() * 20
			if enemy_ai:
				enemy_score += enemy_ai.get_warrior_count() * 50 + enemy_ai.get_farmer_count() * 20
			_end_game(player_score > enemy_score)
	if bt_editor and bt_editor.graph_edit:
		bt_editor.graph_edit.queue_redraw()
