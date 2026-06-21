class_name BTEditor
extends VBoxContainer

signal behaviour_tree_changed(root: BTNode)

var graph_edit: GraphEdit = null
var node_panel: BTNodePanel = null
var toolbar: HBoxContainer = null
var _nodes: Dictionary = {}
var _connections: Dictionary = {}
var ai_controller: AIController = null
var _debug_active_nodes: Array[BTNode] = []
var _auto_layout_btn: Button = null
var _save_btn: Button = null
var _load_btn: Button = null
var _clear_btn: Button = null
var _apply_btn: Button = null
var _debug_enabled: bool = true
var _task_debug_panel: TaskDebugPanel = null
var _show_task_panel: bool = true

func _ready():
	_build_ui()

func _build_ui():
	toolbar = HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 36)
	add_child(toolbar)
	_auto_layout_btn = Button.new()
	_auto_layout_btn.text = "自动布局"
	_auto_layout_btn.pressed.connect(_on_auto_layout)
	toolbar.add_child(_auto_layout_btn)
	_save_btn = Button.new()
	_save_btn.text = "保存"
	_save_btn.pressed.connect(_on_save)
	toolbar.add_child(_save_btn)
	_load_btn = Button.new()
	_load_btn.text = "加载"
	_load_btn.pressed.connect(_on_load)
	toolbar.add_child(_load_btn)
	_clear_btn = Button.new()
	_clear_btn.text = "清空"
	_clear_btn.pressed.connect(_on_clear)
	toolbar.add_child(_clear_btn)
	_apply_btn = Button.new()
	_apply_btn.text = "应用到AI"
	_apply_btn.pressed.connect(_on_apply)
	_apply_btn.add_theme_color_override("font_color", Color(0, 1, 0))
	toolbar.add_child(_apply_btn)
	var debug_check = CheckBox.new()
	debug_check.text = "实时调试"
	debug_check.button_pressed = true
	debug_check.toggled.connect(_on_debug_toggled)
	toolbar.add_child(debug_check)
	var task_panel_btn = Button.new()
	task_panel_btn.text = "任务面板"
	task_panel_btn.toggle_mode = true
	task_panel_btn.button_pressed = true
	task_panel_btn.toggled.connect(_on_task_panel_toggled)
	toolbar.add_child(task_panel_btn)
	var main_hb = HBoxContainer.new()
	add_child(main_hb)
	node_panel = BTNodePanel.new()
	node_panel.node_dragged.connect(_on_node_dragged)
	main_hb.add_child(node_panel)
	graph_edit = GraphEdit.new()
	graph_edit.add_theme_color_override("bg_color", Color(0.15, 0.15, 0.2))
	graph_edit.add_theme_color_override("grid_minor", Color(0.2, 0.2, 0.25))
	graph_edit.add_theme_color_override("grid_major", Color(0.25, 0.25, 0.3))
	graph_edit.custom_minimum_size = Vector2(550, 500)
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.connection_to_empty.connect(_on_connection_to_empty)
	graph_edit.connection_from_empty.connect(_on_connection_from_empty)
	graph_edit.drop_point_rgba = Color(0.2, 0.6, 1.0, 0.5)
	graph_edit.gui_input.connect(_on_graph_input)
	graph_edit.snap_distance = 20
	graph_edit.use_snap = true
	main_hb.add_child(graph_edit)
	_task_debug_panel = TaskDebugPanel.new()
	_task_debug_panel.visible = _show_task_panel
	main_hb.add_child(_task_debug_panel)

func set_ai_controller(ai: AIController):
	ai_controller = ai
	if ai and ai.behaviour_tree:
		_load_tree(ai.behaviour_tree.root)
		ai.behaviour_tree.node_executed.connect(_on_node_executed)
	if _task_debug_panel:
		_task_debug_panel.set_ai_controller(ai)

func _on_debug_toggled(value: bool):
	_debug_enabled = value
	if not _debug_enabled:
		_clear_debug_highlights()

func _on_task_panel_toggled(value: bool):
	_show_task_panel = value
	if _task_debug_panel:
		_task_debug_panel.visible = value

func _on_node_executed(node: BTNode, status: int):
	if not _debug_enabled:
		return
	call_deferred("_highlight_executed_node", node, status)

func _highlight_executed_node(node: BTNode, status: int):
	_clear_debug_highlights()
	var graph_node = _nodes.get(node.guid, null)
	if graph_node and is_instance_valid(graph_node):
		graph_node.set_running(true, status)
		_debug_active_nodes.append(node)
		var parent = node.get_parent()
		while parent:
			var p_node = _nodes.get(parent.guid, null)
			if p_node and is_instance_valid(p_node):
				p_node.set_running(true, BTNode.Status.RUNNING)
			parent = parent.get_parent()

func _clear_debug_highlights():
	for guid in _nodes.keys():
		var gn = _nodes[guid]
		if gn and is_instance_valid(gn):
			gn.set_running(false)
	_debug_active_nodes.clear()

func _on_node_dragged(node_type: String):
	pass

func _on_graph_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_show_context_menu(event.position)
	if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		var drag_data = graph_edit.get_drag_data()
		if drag_data and drag_data is Dictionary and drag_data.has("type"):
			_add_node(drag_data.type, graph_edit.get_scroll_ofs() + event.position / graph_edit.zoom)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var drag_data = graph_edit.get_drag_data()
		if drag_data and drag_data is Dictionary and drag_data.has("type"):
			var drop_pos = graph_edit.get_scroll_ofs() + event.position / graph_edit.zoom
			_add_node(drag_data.type, drop_pos)

func _show_context_menu(position: Vector2):
	var menu = PopupMenu.new()
	menu.add_item("添加 Sequence", 1)
	menu.add_item("添加 Selector", 2)
	menu.add_item("添加 Parallel", 3)
	menu.add_separator()
	menu.add_item("添加 Inverter", 4)
	menu.add_item("添加 Repeat", 5)
	menu.add_item("添加 Wait", 6)
	menu.add_separator()
	menu.add_item("添加 Has Resources?", 10)
	menu.add_item("添加 Enemy Nearby?", 11)
	menu.add_item("添加 Can Expand?", 12)
	menu.add_separator()
	menu.add_item("添加 Expand", 20)
	menu.add_item("添加 Attack", 21)
	menu.add_item("添加 Defend", 22)
	menu.add_item("添加 Harvest", 23)
	menu.add_separator()
	menu.add_item("添加自定义 Condition", 30)
	menu.add_item("添加自定义 Action", 31)
	menu.index_pressed.connect(_on_menu_item_selected.bind(graph_edit.get_scroll_ofs() + position / graph_edit.zoom))
	add_child(menu)
	menu.position = graph_edit.get_global_position() + position
	menu.popup()

func _on_menu_item_selected(index, position):
	var type_map = {
		1: "BTSequence", 2: "BTSelector", 3: "BTParallel",
		4: "BTInverter", 5: "BTRepeat", 6: "BTWait",
		10: "BTConditionHasResources", 11: "BTConditionEnemyNearby", 12: "BTConditionCanExpand",
		20: "BTActionExpand", 21: "BTActionAttack", 22: "BTActionDefend", 23: "BTActionHarvest",
		30: "BTCondition", 31: "BTAction"
	}
	var node_type = type_map.get(index, "")
	if node_type:
		_add_node(node_type, position)

func _add_node(node_type: String, position: Vector2):
	var bt_node = BTNode.create_node_from_type(node_type, "New Node")
	if not bt_node:
		return
	bt_node.position = position
	_add_bt_node_to_graph(bt_node)

func _add_bt_node_to_graph(bt_node: BTNode):
	var graph_node = BTGraphNode.new(bt_node)
	graph_node.node_selected.connect(_on_node_selected)
	graph_node.node_deleted.connect(_on_node_deleted)
	graph_edit.add_child(graph_node)
	_nodes[bt_node.guid] = graph_node
	for child in bt_node.get_children():
		_add_bt_node_to_graph(child)

func _on_node_selected(node: BTGraphNode):
	pass

func _on_node_deleted(node: BTGraphNode):
	if node.bt_node and node.bt_node.get_parent():
		node.bt_node.get_parent().remove_child(node.bt_node)
	_nodes.erase(node.bt_node.guid)
	_connections.erase(node.bt_node.guid)

func _on_connection_request(from: String, from_slot: int, to: String, to_slot: int):
	if from == to:
		return
	var from_node = _get_node_by_name(from)
	var to_node = _get_node_by_name(to)
	if not from_node or not to_node:
		return
	if to_node.bt_node.get_parent():
		to_node.bt_node.get_parent().remove_child(to_node.bt_node)
	from_node.bt_node.add_child(to_node.bt_node)
	graph_edit.connect_node(from, from_slot, to, to_slot)
	_connections[to_node.bt_node.guid] = from_node.bt_node.guid

func _on_disconnection_request(from: String, from_slot: int, to: String, to_slot: int):
	var from_node = _get_node_by_name(from)
	var to_node = _get_node_by_name(to)
	if from_node and to_node:
		from_node.bt_node.remove_child(to_node.bt_node)
	graph_edit.disconnect_node(from, from_slot, to, to_slot)
	_connections.erase(to_node.bt_node.guid)

func _on_connection_to_empty(from: String, from_slot: int, release_pos: Vector2):
	pass

func _on_connection_from_empty(to: String, to_slot: int, release_pos: Vector2):
	pass

func _get_node_by_name(name: String) -> BTGraphNode:
	for guid in _nodes.keys():
		var node = _nodes[guid]
		if node and is_instance_valid(node) and node.name == name:
			return node
	return null

func _load_tree(root: BTNode):
	_clear_all()
	if root:
		_add_bt_node_to_graph(root)
		_reconnect_nodes(root)
		_auto_layout_tree(root, Vector2(50, 50))

func _reconnect_nodes(parent: BTNode):
	if not parent:
		return
	var parent_graph = _nodes.get(parent.guid, null)
	if not parent_graph:
		return
	for child in parent.get_children():
		var child_graph = _nodes.get(child.guid, null)
		if child_graph:
			graph_edit.connect_node(parent_graph.name, 0, child_graph.name, 0)
			_connections[child.guid] = parent.guid
		_reconnect_nodes(child)

func _on_auto_layout():
	var root = _find_root()
	if root:
		_auto_layout_tree(root.bt_node, Vector2(50, 50))

func _auto_layout_tree(node: BTNode, pos: Vector2) -> Vector2:
	var graph_node = _nodes.get(node.guid, null)
	if graph_node:
		graph_node.offset = pos
	var children = node.get_children()
	if children.size() == 0:
		return Vector2(pos.x, pos.y + 80)
	var next_y = pos.y
	for i in range(children.size()):
		var child = children[i]
		var child_width = _calculate_subtree_width(child)
		var child_pos = Vector2(pos.x + 220, next_y)
		next_y = _auto_layout_tree(child, child_pos).y
	return Vector2(pos.x, next_y)

func _calculate_subtree_width(node: BTNode) -> int:
	var children = node.get_children()
	if children.size() == 0:
		return 180
	var total = 0
	for child in children:
		total += _calculate_subtree_width(child)
	return max(180, total)

func _find_root() -> BTGraphNode:
	for guid in _nodes.keys():
		var node = _nodes[guid]
		if node and is_instance_valid(node) and not node.bt_node.get_parent():
			return node
	return null

func _on_save():
	var root = _find_root()
	if not root:
		return
	var data = root.bt_node.to_dict()
	var json = JSON.stringify(data)
	Clipboard.set("bt_tree:" + json)
	var dialog = AcceptDialog.new()
	dialog.title = "保存成功"
	dialog.dialog_text = "行为树已复制到剪贴板\n也保存到 user://bt_save.json"
	add_child(dialog)
	dialog.popup_centered()
	var file = FileAccess.open("user://bt_save.json", FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()

func _on_load():
	var file = FileAccess.open("user://bt_save.json", FileAccess.READ)
	if not file:
		var dialog = AcceptDialog.new()
		dialog.title = "加载失败"
		dialog.dialog_text = "没有找到保存文件"
		add_child(dialog)
		dialog.popup_centered()
		return
	var json = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json)
	if data is Dictionary:
		_clear_all()
		var root = BTNode.from_dict(data)
		if root:
			_load_tree(root)

func _on_clear():
	var confirm = ConfirmationDialog.new()
	confirm.title = "确认清空"
	confirm.dialog_text = "确定要清空所有节点吗？"
	confirm.confirmed.connect(_clear_all)
	add_child(confirm)
	confirm.popup_centered()

func _clear_all():
	for guid in _nodes.keys():
		var node = _nodes[guid]
		if node and is_instance_valid(node):
			node.queue_free()
	_nodes.clear()
	_connections.clear()
	_debug_active_nodes.clear()

func _on_apply():
	var root = _find_root()
	if not root:
		var dialog = AcceptDialog.new()
		dialog.title = "应用失败"
		dialog.dialog_text = "请先创建一个根节点"
		add_child(dialog)
		dialog.popup_centered()
		return
	if ai_controller:
		ai_controller.set_behaviour_tree_root(root.bt_node)
		var dialog = AcceptDialog.new()
		dialog.title = "应用成功"
		dialog.dialog_text = "行为树已应用到AI控制器"
		add_child(dialog)
		dialog.popup_centered()

func can_drop_data(position: Vector2, data) -> bool:
	if data and data is Dictionary and data.has("type"):
		return true
	return false

func drop_data(position: Vector2, data):
	if data and data is Dictionary and data.has("type"):
		var drop_pos = graph_edit.get_scroll_ofs() + position / graph_edit.zoom
		_add_node(data.type, drop_pos)
		return true
	return false

func get_drag_data(position: Vector2):
	return null
