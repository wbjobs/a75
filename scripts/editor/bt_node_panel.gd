class_name BTNodePanel
extends VBoxContainer

signal node_dragged(node_type: String)

var node_types: Dictionary = {
	"Composite": [
		{"type": "BTSequence", "name": "Sequence", "desc": "顺序执行"},
		{"type": "BTSelector", "name": "Selector", "desc": "选择执行"},
		{"type": "BTParallel", "name": "Parallel", "desc": "并行执行"}
	],
	"Decorator": [
		{"type": "BTInverter", "name": "Inverter", "desc": "取反结果"},
		{"type": "BTRepeat", "name": "Repeat", "desc": "重复执行"},
		{"type": "BTWait", "name": "Wait", "desc": "等待时间"}
	],
	"AI Condition": [
		{"type": "BTConditionHasResources", "name": "Has Resources?", "desc": "资源足够？"},
		{"type": "BTConditionEnemyNearby", "name": "Enemy Nearby?", "desc": "敌人临近？"},
		{"type": "BTConditionCanExpand", "name": "Can Expand?", "desc": "可扩张？"}
	],
	"AI Action": [
		{"type": "BTActionExpand", "name": "Expand", "desc": "扩张策略"},
		{"type": "BTActionAttack", "name": "Attack", "desc": "进攻策略"},
		{"type": "BTActionDefend", "name": "Defend", "desc": "防守策略"},
		{"type": "BTActionHarvest", "name": "Harvest", "desc": "采集策略"}
	],
	"Base": [
		{"type": "BTCondition", "name": "Condition", "desc": "自定义条件"},
		{"type": "BTAction", "name": "Action", "desc": "自定义动作"}
	]
}

func _ready():
	_build_ui()

func _build_ui():
	var title = Label.new()
	title.text = "行为树节点"
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_font_size_override("font_size", 14)
	add_child(title)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(180, 400)
	add_child(scroll)
	var content = VBoxContainer.new()
	scroll.add_child(content)
	for category in node_types.keys():
		var cat_label = Label.new()
		cat_label.text = category
		cat_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
		cat_label.add_theme_font_size_override("font_size", 11)
		content.add_child(cat_label)
		var items = node_types[category]
		for item in items:
			var btn = Button.new()
			btn.text = item.name
			btn.tooltip_text = item.desc
			btn.custom_minimum_size = Vector2(160, 30)
			btn.add_theme_font_size_override("font_size", 10)
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			content.add_child(btn)
			var drag_data = {"type": item.type, "name": item.name}
			btn.gui_input.connect(_on_btn_input.bind(btn, drag_data))

func get_drag_data(position: Vector2):
	for child in get_children():
		if child is ScrollContainer:
			for content_child in child.get_children():
				if content_child is VBoxContainer:
					for btn in content_child.get_children():
						if btn is Button:
							var btn_rect = btn.get_global_rect()
							if btn_rect.has_point(btn.get_global_mouse_position()):
								var drag_data = null
								for category in node_types.keys():
									for item in node_types[category]:
										if item.name == btn.text:
											drag_data = {"type": item.type, "name": item.name}
											break
									if drag_data:
										break
								if drag_data:
									var drag = Control.new()
									var lbl = Label.new()
									lbl.text = drag_data.name
									lbl.add_theme_color_override("font_color", Color.WHITE)
									drag.add_child(lbl)
									return drag_data
	return null

func _on_btn_input(event, btn, drag_data):
	pass
