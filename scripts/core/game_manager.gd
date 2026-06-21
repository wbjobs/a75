class_name GameManager
extends Node2D

signal game_started()
signal editor_toggled(visible: bool)

var grid_map: GridMap = null
var player_ai: AIController = null
var enemy_ai: AIController = null
var hud: GameHUD = null
var bt_editor_window: Window = null
var bt_editor: BTEditor = null
var _editor_visible: bool = false

func _ready():
	add_to_group("game_manager")
	_setup_grid()
	_setup_ai()
	_setup_hud()
	_setup_editor_window()
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

func _setup_hud():
	hud = GameHUD.new()
	hud.set_player_ai(player_ai)
	hud.set_enemy_ai(enemy_ai)
	add_child(hud)

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

func _start_game():
	for i in range(2):
		player_ai.train_farmer()
		enemy_ai.train_farmer()
	player_ai.train_warrior()
	enemy_ai.train_warrior()
	game_started.emit()

func toggle_editor():
	_editor_visible = not _editor_visible
	bt_editor_window.visible = _editor_visible
	editor_toggled.emit(_editor_visible)

func _on_editor_close():
	_editor_visible = false
	bt_editor_window.visible = false
	editor_toggled.emit(false)

func _process(delta):
	if bt_editor and bt_editor.graph_edit:
		bt_editor.graph_edit.queue_redraw()
