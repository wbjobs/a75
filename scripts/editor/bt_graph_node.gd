class_name BTGraphNode
extends GraphNode

signal node_selected(node: BTGraphNode)
signal node_deleted(node: BTGraphNode)
signal connections_changed()

var bt_node: BTNode = null
var _node_color: Color = Color(0.3, 0.3, 0.35)
var _is_running: bool = false
var _last_status: int = BTNode.Status.FAILURE
var _title_label: Label = null
var _desc_label: Label = null

func _init(bt: BTNode):
	bt_node = bt
	title = bt.node_name
	offset = bt.position
	_set_category_color()
	_build_ui()

func _set_category_color():
	match bt_node.category:
		"Composite":
			_node_color = Color(0.3, 0.5, 0.8)
		"Decorator":
			_node_color = Color(0.5, 0.3, 0.8)
		"Condition", "AI Condition":
			_node_color = Color(0.8, 0.6, 0.2)
		"Action", "AI Action":
			_node_color = Color(0.2, 0.7, 0.4)
		_:
			_node_color = Color(0.4, 0.4, 0.4)

func _build_ui():
	var main_vb = VBoxContainer.new()
	add_child(main_vb)
	_title_label = Label.new()
	_title_label.text = bt_node.node_name
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.add_theme_font_size_override("font_size", 12)
	main_vb.add_child(_title_label)
	_desc_label = Label.new()
	_desc_label.text = bt_node.description
	_desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_desc_label.add_theme_font_size_override("font_size", 9)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.custom_minimum_size = Vector2(140, 0)
	main_vb.add_child(_desc_label)
	var slot_container = HBoxContainer.new()
	main_vb.add_child(slot_container)
	var input_slot = VBoxContainer.new()
	slot_container.add_child(input_slot)
	var input_spacer = Control.new()
	input_spacer.custom_minimum_size = Vector2(20, 10)
	input_slot.add_child(input_spacer)
	var output_slot = VBoxContainer.new()
	output_slot.alignment = BoxContainer.ALIGNMENT_END
	slot_container.add_child(output_slot)
	var output_spacer = Control.new()
	output_spacer.custom_minimum_size = Vector2(20, 10)
	output_slot.add_child(output_spacer)
	set_slot(0, true, 0, Color(1, 1, 1), true, 0, Color(1, 1, 1))
	if bt_node.category == "Composite" or bt_node.category == "Decorator" or bt_node.category == "Base":
		set_slot(1, false, 0, Color(1, 1, 1), true, 0, Color(1, 1, 1))
	else:
		set_slot(1, false, 0, Color(1, 1, 1), false, 0, Color(1, 1, 1))

func _ready():
	offset_changed.connect(_on_offset_changed)
	close_requested.connect(_on_close_requested)
	selected.connect(_on_selected)

func _on_offset_changed():
	if bt_node:
		bt_node.position = offset

func _on_close_requested():
	node_deleted.emit(self)
	queue_free()

func _on_selected():
	node_selected.emit(self)

func set_running(value: bool, status: int = BTNode.Status.RUNNING):
	_is_running = value
	_last_status = status
	queue_redraw()

func _draw():
	if _is_running:
		var status_color = Color(1.0, 0.8, 0.0)
		match _last_status:
			BTNode.Status.SUCCESS:
				status_color = Color(0.0, 1.0, 0.0)
			BTNode.Status.FAILURE:
				status_color = Color(1.0, 0.0, 0.0)
			BTNode.Status.RUNNING:
				status_color = Color(1.0, 0.8, 0.0)
		draw_rect(Rect2(Vector2.ZERO, size), status_color, false, 4.0)
	var bg_rect = Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_rect(bg_rect, _node_color)
	draw_rect(bg_rect, Color(0.1, 0.1, 0.15), false, 2.0)

func update_from_bt_node():
	if bt_node:
		_title_label.text = bt_node.node_name
		_desc_label.text = bt_node.description
		title = bt_node.node_name
