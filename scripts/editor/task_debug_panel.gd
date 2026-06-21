class_name TaskDebugPanel
extends VBoxContainer

var ai_controller: AIController = null
var _stats_label: Label = null
var _pending_tasks_list: VBoxContainer = null
var _active_tasks_list: VBoxContainer = null
var _history_list: VBoxContainer = null
var _cool_downs_list: VBoxContainer = null

func _ready():
	_build_ui()

func _build_ui():
	var title = Label.new()
	title.text = "=== 任务调度调试面板 ==="
	title.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	title.add_theme_font_size_override("font_size", 13)
	add_child(title)
	_stats_label = Label.new()
	_stats_label.text = "统计: 等待 0 | 执行 0 | 冷却 0"
	_stats_label.add_theme_color_override("font_color", Color.WHITE)
	_stats_label.add_theme_font_size_override("font_size", 11)
	add_child(_stats_label)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 450)
	add_child(scroll)
	var content = VBoxContainer.new()
	scroll.add_child(content)
	var pending_title = Label.new()
	pending_title.text = "【待执行任务】"
	pending_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	pending_title.add_theme_font_size_override("font_size", 11)
	content.add_child(pending_title)
	_pending_tasks_list = VBoxContainer.new()
	content.add_child(_pending_tasks_list)
	var sep1 = HSeparator.new()
	content.add_child(sep1)
	var active_title = Label.new()
	active_title.text = "【执行中任务】"
	active_title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	active_title.add_theme_font_size_override("font_size", 11)
	content.add_child(active_title)
	_active_tasks_list = VBoxContainer.new()
	content.add_child(_active_tasks_list)
	var sep2 = HSeparator.new()
	content.add_child(sep2)
	var history_title = Label.new()
	history_title.text = "【最近完成任务】"
	history_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	history_title.add_theme_font_size_override("font_size", 11)
	content.add_child(history_title)
	_history_list = VBoxContainer.new()
	content.add_child(_history_list)
	var sep3 = HSeparator.new()
	content.add_child(sep3)
	var cd_title = Label.new()
	cd_title.text = "【冷却中】"
	cd_title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	cd_title.add_theme_font_size_override("font_size", 11)
	content.add_child(cd_title)
	_cool_downs_list = VBoxContainer.new()
	content.add_child(_cool_downs_list)

func set_ai_controller(ai: AIController):
	ai_controller = ai
	if ai and ai.task_scheduler:
		ai.task_scheduler.scheduler_updated.connect(_update_panel)

func _process(delta):
	if ai_controller and ai_controller.task_scheduler:
		_update_panel()

func _update_panel():
	if not ai_controller or not ai_controller.task_scheduler:
		return
	var stats = ai_controller.task_scheduler.get_stats()
	_stats_label.text = "统计: 等待 %d | 执行 %d | 冷却 %d" % [stats.pending, stats.running, stats.cool_downs]
	_refresh_task_list(_pending_tasks_list, ai_controller.task_scheduler.get_pending_tasks(), false)
	_refresh_task_list(_active_tasks_list, ai_controller.task_scheduler.get_active_tasks(), true)
	var history = ai_controller.task_scheduler.get_task_history()
	history.invert()
	_refresh_task_list(_history_list, history.slice(0, 5), false, true)
	_refresh_cool_downs()

func _refresh_task_list(container: VBoxContainer, tasks: Array[AITask], show_progress: bool = false, show_history: bool = false):
	for child in container.get_children():
		child.queue_free()
	if tasks.size() == 0:
		var empty = Label.new()
		empty.text = "  (无)"
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty.add_theme_font_size_override("font_size", 9)
		container.add_child(empty)
		return
	for task in tasks:
		var task_panel = PanelContainer.new()
		task_panel.custom_minimum_size = Vector2(250, 0)
		container.add_child(task_panel)
		var vb = VBoxContainer.new()
		vb.add_theme_constant_override("margin", 4)
		task_panel.add_child(vb)
		var header = HBoxContainer.new()
		vb.add_child(header)
		var type_lbl = Label.new()
		type_lbl.text = "[%s] %s" % [task.get_priority_name(), task.get_type_name()]
		type_lbl.add_theme_color_override("font_color", _get_priority_color(task.priority))
		type_lbl.add_theme_font_size_override("font_size", 10)
		header.add_child(type_lbl)
		var status_lbl = Label.new()
		status_lbl.text = task.get_status_name()
		status_lbl.add_theme_color_override("font_color", _get_status_color(task.status))
		status_lbl.add_theme_font_size_override("font_size", 9)
		status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(status_lbl)
		if task.description:
			var desc_lbl = Label.new()
			desc_lbl.text = task.description
			desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			desc_lbl.add_theme_font_size_override("font_size", 9)
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			vb.add_child(desc_lbl)
		if show_progress and task.status == AITask.TaskStatus.EXECUTING:
			var progress = ProgressBar.new()
			progress.max_value = task.max_duration
			progress.value = task.get_elapsed_time()
			progress.custom_minimum_size = Vector2(0, 8)
			vb.add_child(progress)
			var time_lbl = Label.new()
			time_lbl.text = "已执行: %.1fs / %.1fs" % [task.get_elapsed_time(), task.max_duration]
			time_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			time_lbl.add_theme_font_size_override("font_size", 8)
			vb.add_child(time_lbl)
		if show_history and task.completed_time > 0:
			var result = "成功" if task.status == AITask.TaskStatus.COMPLETED else "失败"
			var result_color = Color(0.3, 1.0, 0.5) if task.status == AITask.TaskStatus.COMPLETED else Color(1.0, 0.3, 0.3)
			var result_lbl = Label.new()
			result_lbl.text = "结果: %s | 冷却: %.1fs" % [result, task.get_cool_down()]
			result_lbl.add_theme_color_override("font_color", result_color)
			result_lbl.add_theme_font_size_override("font_size", 8)
			vb.add_child(result_lbl)

func _refresh_cool_downs():
	for child in _cool_downs_list.get_children():
		child.queue_free()
	if not ai_controller or not ai_controller.task_scheduler:
		return
	var cds = ai_controller.task_scheduler._cool_downs
	if cds.size() == 0:
		var empty = Label.new()
		empty.text = "  (无)"
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty.add_theme_font_size_override("font_size", 9)
		_cool_downs_list.add_child(empty)
		return
	for key in cds.keys():
		var cd_lbl = Label.new()
		var task_type = key.replace("cd_", "").split("_")[0]
		cd_lbl.text = "  %s: %.1fs" % [task_type, cds[key]]
		cd_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
		cd_lbl.add_theme_font_size_override("font_size", 9)
		_cool_downs_list.add_child(cd_lbl)

func _get_priority_color(priority: int) -> Color:
	match priority:
		AITask.Priority.LOW:
			return Color(0.5, 0.8, 1.0)
		AITask.Priority.MEDIUM:
			return Color(1.0, 1.0, 0.3)
		AITask.Priority.HIGH:
			return Color(1.0, 0.6, 0.2)
		AITask.Priority.CRITICAL:
			return Color(1.0, 0.3, 0.3)
		AITask.Priority.EMERGENCY:
			return Color(1.0, 0.1, 0.8)
		_:
			return Color.WHITE

func _get_status_color(status: int) -> Color:
	match status:
		AITask.TaskStatus.PENDING:
			return Color(0.8, 0.8, 0.3)
		AITask.TaskStatus.EXECUTING:
			return Color(0.3, 1.0, 0.5)
		AITask.TaskStatus.COMPLETED:
			return Color(0.2, 0.8, 1.0)
		AITask.TaskStatus.FAILED:
			return Color(1.0, 0.3, 0.3)
		AITask.TaskStatus.CANCELLED:
			return Color(0.7, 0.5, 0.2)
		_:
			return Color.WHITE
