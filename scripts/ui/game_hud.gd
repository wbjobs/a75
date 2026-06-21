class_name GameHUD
extends CanvasLayer

var player_ai: AIController = null
var enemy_ai: AIController = null
var _player_res_label: Label = null
var _player_farmer_label: Label = null
var _player_warrior_label: Label = null
var _enemy_res_label: Label = null
var _enemy_farmer_label: Label = null
var _enemy_warrior_label: Label = null
var _current_order_label: Label = null
var _status_label: Label = null
var _train_farmer_btn: Button = null
var _train_warrior_btn: Button = null
var _show_editor_btn: Button = null

func _ready():
	_build_ui()

func _build_ui():
	var main_vb = VBoxContainer.new()
	main_vb.custom_minimum_size = Vector2(260, 0)
	main_vb.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	main_vb.offset_right = -10
	main_vb.offset_top = 10
	add_child(main_vb)
	var title = Label.new()
	title.text = "=== 玩家 (蓝色) ==="
	title.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	title.add_theme_font_size_override("font_size", 13)
	main_vb.add_child(title)
	_player_res_label = Label.new()
	_player_res_label.text = "资源: 0"
	_player_res_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	_player_res_label.add_theme_font_size_override("font_size", 12)
	main_vb.add_child(_player_res_label)
	_player_farmer_label = Label.new()
	_player_farmer_label.text = "农民: 0"
	_player_farmer_label.add_theme_color_override("font_color", Color.WHITE)
	_player_farmer_label.add_theme_font_size_override("font_size", 11)
	main_vb.add_child(_player_farmer_label)
	_player_warrior_label = Label.new()
	_player_warrior_label.text = "战士: 0"
	_player_warrior_label.add_theme_color_override("font_color", Color.WHITE)
	_player_warrior_label.add_theme_font_size_override("font_size", 11)
	main_vb.add_child(_player_warrior_label)
	var sep1 = HSeparator.new()
	main_vb.add_child(sep1)
	var enemy_title = Label.new()
	enemy_title.text = "=== 敌方 (红色) ==="
	enemy_title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	enemy_title.add_theme_font_size_override("font_size", 13)
	main_vb.add_child(enemy_title)
	_enemy_res_label = Label.new()
	_enemy_res_label.text = "资源: 0"
	_enemy_res_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	_enemy_res_label.add_theme_font_size_override("font_size", 12)
	main_vb.add_child(_enemy_res_label)
	_enemy_farmer_label = Label.new()
	_enemy_farmer_label.text = "农民: 0"
	_enemy_farmer_label.add_theme_color_override("font_color", Color.WHITE)
	_enemy_farmer_label.add_theme_font_size_override("font_size", 11)
	main_vb.add_child(_enemy_farmer_label)
	_enemy_warrior_label = Label.new()
	_enemy_warrior_label.text = "战士: 0"
	_enemy_warrior_label.add_theme_color_override("font_color", Color.WHITE)
	_enemy_warrior_label.add_theme_font_size_override("font_size", 11)
	main_vb.add_child(_enemy_warrior_label)
	var sep2 = HSeparator.new()
	main_vb.add_child(sep2)
	var order_title = Label.new()
	order_title.text = "AI 当前策略:"
	order_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	order_title.add_theme_font_size_override("font_size", 11)
	main_vb.add_child(order_title)
	_current_order_label = Label.new()
	_current_order_label.text = "防守"
	_current_order_label.add_theme_color_override("font_color", Color.YELLOW)
	_current_order_label.add_theme_font_size_override("font_size", 13)
	main_vb.add_child(_current_order_label)
	var sep3 = HSeparator.new()
	main_vb.add_child(sep3)
	_train_farmer_btn = Button.new()
	_train_farmer_btn.text = "训练农民 (30)"
	_train_farmer_btn.pressed.connect(_on_train_farmer)
	main_vb.add_child(_train_farmer_btn)
	_train_warrior_btn = Button.new()
	_train_warrior_btn.text = "训练战士 (50)"
	_train_warrior_btn.pressed.connect(_on_train_warrior)
	main_vb.add_child(_train_warrior_btn)
	_show_editor_btn = Button.new()
	_show_editor_btn.text = "打开行为树编辑器"
	_show_editor_btn.pressed.connect(_on_show_editor)
	_show_editor_btn.add_theme_color_override("font_color", Color(0, 1, 0.5))
	main_vb.add_child(_show_editor_btn)
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color.GREEN)
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	main_vb.add_child(_status_label)
	var help = Label.new()
	help.text = "\n操作说明:\n- 右键空白处添加节点\n- 拖拽节点输出口连接到输入口\n- 点击节点X删除\n- '应用到AI'后行为树生效"
	help.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	help.add_theme_font_size_override("font_size", 9)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	main_vb.add_child(help)

func set_player_ai(ai: AIController):
	player_ai = ai
	if ai:
		ai.ai_updated.connect(_update_ui)

func set_enemy_ai(ai: AIController):
	enemy_ai = ai
	if ai:
		ai.ai_updated.connect(_update_ui)

func _update_ui():
	if player_ai:
		_player_res_label.text = "资源: %d" % player_ai.resources
		_player_farmer_label.text = "农民: %d" % player_ai.get_farmer_count()
		_player_warrior_label.text = "战士: %d" % player_ai.get_warrior_count()
		_current_order_label.text = player_ai.current_order
	if enemy_ai:
		_enemy_res_label.text = "资源: %d" % enemy_ai.resources
		_enemy_farmer_label.text = "农民: %d" % enemy_ai.get_farmer_count()
		_enemy_warrior_label.text = "战士: %d" % enemy_ai.get_warrior_count()

func _on_train_farmer():
	if player_ai and player_ai.train_farmer():
		_status_label.text = "训练农民成功！"
		_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		_status_label.text = "资源不足或空间不够"
		_status_label.add_theme_color_override("font_color", Color.RED)

func _on_train_warrior():
	if player_ai and player_ai.train_warrior():
		_status_label.text = "训练战士成功！"
		_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		_status_label.text = "资源不足或空间不够"
		_status_label.add_theme_color_override("font_color", Color.RED)

func _on_show_editor():
	get_tree().call_group("game_manager", "toggle_editor")
