class_name LearningPanel
extends VBoxContainer

var rl_engine: RLEngine = null
var ai_controller: AIController = null
var _state_label: Label = null
var _stats_grid: GridContainer = null
var _params_container: VBoxContainer = null
var _history_container: VBoxContainer = null
var _last_results_container: HBoxContainer = null
var _save_path_label: Label = null
var _exploit_btn: Button = null
var _save_btn: Button = null
var _reset_btn: Button = null
var _export_btn: Button = null
var _param_sliders: Dictionary = {}
var _best_indicator: Control = null
var _learning_curve_panel: PanelContainer = null

func _ready():
	_build_ui()
	_process(delta)

func set_rl_engine(engine: RLEngine, ai: AIController):
	rl_engine = engine
	ai_controller = ai
	if rl_engine:
		rl_engine.learning_state_changed.connect(_on_state_changed)
		rl_engine.learning_step_completed.connect(_on_step_completed)
		rl_engine.best_params_changed.connect(_on_best_changed)
	_on_state_changed({})

func _build_ui():
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.custom_minimum_size = Vector2(680, 0)
	scroll.add_child(content)
	var title = Label.new()
	title.text = "🤖 AI 强化学习面板"
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.7))
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)
	var state_box = PanelContainer.new()
	content.add_child(state_box)
	var state_vb = VBoxContainer.new()
	state_vb.add_theme_constant_override("margin", 8)
	state_box.add_child(state_vb)
	_state_label = Label.new()
	_state_label.text = "等待初始化..."
	_state_label.add_theme_font_size_override("font_size", 12)
	state_vb.add_child(_state_label)
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 4
	state_vb.add_child(_stats_grid)
	_save_path_label = Label.new()
	_save_path_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_save_path_label.add_theme_font_size_override("font_size", 9)
	state_vb.add_child(_save_path_label)
	var btn_row = HBoxContainer.new()
	content.add_child(btn_row)
	_exploit_btn = Button.new()
	_exploit_btn.text = "📌 强制使用最优参数"
	_exploit_btn.pressed.connect(_on_force_best)
	btn_row.add_child(_exploit_btn)
	_save_btn = Button.new()
	_save_btn.text = "💾 立即保存"
	_save_btn.pressed.connect(_on_save)
	btn_row.add_child(_save_btn)
	_export_btn = Button.new()
	_export_btn.text = "📋 导出JSON到剪贴板"
	_export_btn.pressed.connect(_on_export)
	btn_row.add_child(_export_btn)
	_reset_btn = Button.new()
	_reset_btn.text = "🔄 重置学习"
	_reset_btn.pressed.connect(_on_reset_confirm)
	_reset_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	btn_row.add_child(_reset_btn)
	var sep1 = HSeparator.new()
	content.add_child(sep1)
	var params_title = Label.new()
	params_title.text = "⚙️ 当前参数（可手动调整）"
	params_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	params_title.add_theme_font_size_override("font_size", 14)
	content.add_child(params_title)
	_params_container = VBoxContainer.new()
	_params_container.add_theme_constant_override("separation", 4)
	content.add_child(_params_container)
	var sep2 = HSeparator.new()
	content.add_child(sep2)
	var history_title = Label.new()
	history_title.text = "📈 最近10局结果"
	history_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	history_title.add_theme_font_size_override("font_size", 14)
	content.add_child(history_title)
	_last_results_container = HBoxContainer.new()
	_last_results_container.custom_minimum_size = Vector2(0, 40)
	content.add_child(_last_results_container)
	_history_container = VBoxContainer.new()
	_history_container.add_theme_constant_override("separation", 2)
	content.add_child(_history_container)
	var sep3 = HSeparator.new()
	content.add_child(sep3)
	var info_title = Label.new()
	info_title.text = "📖 学习机制说明"
	info_title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	info_title.add_theme_font_size_override("font_size", 14)
	content.add_child(info_title)
	var info_text = Label.new()
	info_text.text = (
		"🎯 每局游戏结束后，AI会根据胜负和KPI自动进化：\n"
		"  • 遗传算法：每局结束保留得分Top的参数集作为精英\n"
		"  • 突变：在最优参数基础上微调，探索新阈值组合\n"
		"  • 交叉：两个优质参数集交叉混合\n"
		"  • ε-Greedy：30%概率探索新参数，70%使用最优\n"
		"  • 信心加权：尝试过少的参数集会有惩罚，避免假阳性\n\n"
		"🎁 奖励信号构成：\n"
		"  • 胜负 (+1000/-200)  • 击杀敌方单位  • 资源采集效率\n"
		"  • 战斗胜率  • 伤害交换比  • 时间惩罚(速战速决)\n\n"
		"⏱️ 默认每局最长4分钟，基地被摧毁或时间到时判胜负"
	)
	info_text.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_text.add_theme_font_size_override("font_size", 10)
	info_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(info_text)

func _process(delta):
	_update_state_display()
	_update_params_display()
	_update_history()

func _update_state_display():
	if not rl_engine:
		_state_label.text = "未连接强化学习引擎"
		return
	var state = rl_engine.get_state()
	_state_label.text = (
		"局数: %d   胜: %d   胜率: %.1f%%   探索率: %.1f%%   模式: %s\n"
		"当前代数: %d   最优得分: %.1f   距上次最优: %d局"
	) % [
		state.get("total_games", 0),
		state.get("total_wins", 0),
		state.get("win_rate", 0) * 100,
		state.get("exploration_rate", 0) * 100,
		state.get("last_mode", "?"),
		state.get("current_generation", 0),
		state.get("best_score", 0.0),
		state.get("games_since_best", 0)
	]
	_save_path_label.text = "💾 保存位置: " + ProjectSettings.globalize_path(state.get("save_path", ""))
	_stats_grid.clear_children()
	var items = [
		["总奖励(EMA)", "%.2f" % state.get("reward_ema", 0.0), Color(1, 0.9, 0.4)],
		["参数池大小", str(state.get("population_size", 0)), Color(0.7, 0.9, 1.0)],
		["当前参数ID", str(state.get("current_param_id", ""))[-8:], Color(0.8, 0.8, 0.8)],
		["最优代数", str(state.get("best_param_generation", 0)), Color(0.3, 1.0, 0.5)],
	]
	for item in items:
		var lbl1 = Label.new()
		lbl1.text = item[0]
		lbl1.add_theme_font_size_override("font_size", 10)
		lbl1.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_stats_grid.add_child(lbl1)
		var lbl2 = Label.new()
		lbl2.text = str(item[1])
		lbl2.add_theme_font_size_override("font_size", 11)
		lbl2.add_theme_color_override("font_color", item[2])
		_stats_grid.add_child(lbl2)

func _update_params_display():
	if not rl_engine or not rl_engine.current_param:
		return
	var ps = rl_engine.current_param
	var all_params = ps.params
	var needs_rebuild = _param_sliders.size() != all_params.size()
	if not needs_rebuild:
		for key in all_params.keys():
			if not _param_sliders.has(key):
				needs_rebuild = true
				break
	if needs_rebuild:
		_rebuild_param_sliders(ps)
	else:
		for key in all_params.keys():
			var slider = _param_sliders.get(key, null)
			if slider and slider["spin"] and is_instance_valid(slider["spin"]):
				var expected = all_params[key].get_value()
				if typeof(expected) == TYPE_INT:
					if slider["spin"].value != expected:
						slider["spin"].value = expected
				else:
					if abs(float(slider["spin"].value) - float(expected)) > 0.001:
						slider["spin"].value = expected

func _rebuild_param_sliders(ps: ParamSet):
	for child in _params_container.get_children():
		child.queue_free()
	_param_sliders.clear()
	var best_ps = rl_engine.best_param
	for key in ps.params.keys():
		var p = ps.params[key]
		var row = HBoxContainer.new()
		_params_container.add_child(row)
		var name_lbl = Label.new()
		name_lbl.text = p.param_name
		name_lbl.custom_minimum_size = Vector2(110, 0)
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		row.add_child(name_lbl)
		var spin = SpinBox.new()
		spin.custom_minimum_size = Vector2(90, 0)
		spin.min_value = p.min_value
		spin.max_value = p.max_value
		spin.step = p.step
		spin.value = p.get_value()
		if p.param_type == preload("res://scripts/learning/learnable_params.gd").LearnableParam.ParamType.INT or p.param_type == 2:
			spin.prefix = ""
		spin.add_theme_font_size_override("font_size", 10)
		spin.value_changed.connect(_on_param_changed.bind(key, spin))
		row.add_child(spin)
		var range_lbl = Label.new()
		range_lbl.text = "[%s ~ %s]" % [str(p.min_value), str(p.max_value)]
		range_lbl.custom_minimum_size = Vector2(100, 0)
		range_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		range_lbl.add_theme_font_size_override("font_size", 9)
		row.add_child(range_lbl)
		if best_ps and best_ps.params.has(key):
			var best_val = best_ps.params[key].get_value()
			var best_lbl = Label.new()
			var is_best_val = (typeof(best_val) == TYPE_INT and int(spin.value) == int(best_val)) or (abs(float(spin.value) - float(best_val)) < 0.01)
			if is_best_val:
				best_lbl.text = "🏆 " + str(best_val)
				best_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			else:
				best_lbl.text = "  最优:" + str(best_val)
				best_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			best_lbl.add_theme_font_size_override("font_size", 9)
			row.add_child(best_lbl)
		var desc_lbl = Label.new()
		desc_lbl.text = p.description
		desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		desc_lbl.add_theme_font_size_override("font_size", 8)
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc_lbl)
		_param_sliders[key] = {"spin": spin}

func _on_param_changed(value, key: String, spin: SpinBox):
	if not rl_engine:
		return
	var final_val = value
	if rl_engine.current_param and rl_engine.current_param.params.has(key):
		var p = rl_engine.current_param.params[key]
		var ptype = p.param_type
		if ptype == 0 or ptype == 2:
			final_val = int(value)
	rl_engine.set_param_directly(key, final_val)

func _update_history():
	if not rl_engine:
		return
	var recent = rl_engine.get_recent_games_summary(10)
	for child in _last_results_container.get_children():
		child.queue_free()
	for r in recent:
		var result_lbl = Label.new()
		result_lbl.custom_minimum_size = Vector2(24, 24)
		if r.get("won", false):
			result_lbl.text = "✓"
			result_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		else:
			result_lbl.text = "✗"
			result_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		result_lbl.add_theme_font_size_override("font_size", 16)
		result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result_lbl.tooltip_text = "第%d局 | %s | 得分%.1f | 奖励%.2f" % [
			r.get("game", 0), r.get("mode", "?"), r.get("score", 0), r.get("reward", 0)]
		_last_results_container.add_child(result_lbl)
	for child in _history_container.get_children():
		child.queue_free()
	recent = rl_engine.get_recent_games_summary(5)
	for r in recent:
		var row = HBoxContainer.new()
		_history_container.add_child(row)
		var game_id = Label.new()
		game_id.text = "#%d" % r.get("game", 0)
		game_id.custom_minimum_size = Vector2(35, 0)
		game_id.add_theme_font_size_override("font_size", 10)
		game_id.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		row.add_child(game_id)
		var win_lbl = Label.new()
		if r.get("won", false):
			win_lbl.text = "胜利"
			win_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		else:
			win_lbl.text = "失败"
			win_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		win_lbl.custom_minimum_size = Vector2(40, 0)
		win_lbl.add_theme_font_size_override("font_size", 10)
		row.add_child(win_lbl)
		var mode_lbl = Label.new()
		mode_lbl.text = r.get("mode", "?")
		mode_lbl.custom_minimum_size = Vector2(40, 0)
		mode_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		mode_lbl.add_theme_font_size_override("font_size", 10)
		row.add_child(mode_lbl)
		var score_lbl = Label.new()
		score_lbl.text = "S:%.0f" % r.get("score", 0)
		score_lbl.custom_minimum_size = Vector2(55, 0)
		score_lbl.add_theme_font_size_override("font_size", 10)
		row.add_child(score_lbl)
		var reward_lbl = Label.new()
		reward_lbl.text = "R:%.2f" % r.get("reward", 0)
		reward_lbl.custom_minimum_size = Vector2(55, 0)
		reward_lbl.add_theme_font_size_override("font_size", 10)
		row.add_child(reward_lbl)
		var summary = r.get("stats_summary", {})
		var stats_lbl = Label.new()
		stats_lbl.text = "%ds | 农:%d战:%d | 杀:%d" % [
			int(summary.get("duration", 0)),
			int(summary.get("farmers", 0)),
			int(summary.get("warriors", 0)),
			int(summary.get("kills", 0))
		]
		stats_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		stats_lbl.add_theme_font_size_override("font_size", 9)
		stats_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(stats_lbl)

func _on_state_changed(state: Dictionary):
	pass

func _on_step_completed(stats: Dictionary):
	if stats.get("was_best", false):
		var flash = AcceptDialog.new()
		flash.title = "🏆 新最优参数！"
		flash.dialog_text = "找到新的最优参数组合！\n本局%s - 奖励: %.2f\n已自动更新最佳参数" % [
			"胜利" if stats.get("won", false) else "表现优异", stats.get("reward", 0)]
		add_child(flash)
		flash.popup_centered()

func _on_best_changed(new_best: ParamSet):
	pass

func _on_force_best():
	if not rl_engine:
		return
	rl_engine.force_use_best()
	var confirm = AcceptDialog.new()
	confirm.title = "已应用最优"
	confirm.dialog_text = "下一局将使用历史最优参数\n(但仍有小概率突变以继续探索)"
	add_child(confirm)
	confirm.popup_centered()

func _on_save():
	if not rl_engine:
		return
	rl_engine.save_to_file()
	var confirm = AcceptDialog.new()
	confirm.title = "保存成功"
	confirm.dialog_text = "学习数据已保存到: " + ProjectSettings.globalize_path(rl_engine.save_path)
	add_child(confirm)
	confirm.popup_centered()

func _on_export():
	if not rl_engine:
		return
	rl_engine.save_to_file()
	var file = FileAccess.open(rl_engine.save_path, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	file.close()
	Clipboard.set(content)
	var confirm = AcceptDialog.new()
	confirm.title = "已复制到剪贴板"
	confirm.dialog_text = "学习数据JSON (%d字符)已复制到剪贴板" % content.length()
	add_child(confirm)
	confirm.popup_centered()

func _on_reset_confirm():
	var dlg = ConfirmationDialog.new()
	dlg.title = "⚠️ 确认重置学习？"
	dlg.dialog_text = "这会清除所有学习进度、最优参数和历史数据！\n确定要从头开始吗？"
	dlg.confirmed.connect(_on_reset_confirmed)
	add_child(dlg)
	dlg.popup_centered()

func _on_reset_confirmed():
	if rl_engine:
		rl_engine.reset_learning()
		var confirm = AcceptDialog.new()
		confirm.title = "已重置"
		confirm.dialog_text = "学习数据已清空，参数恢复默认"
		add_child(confirm)
		confirm.popup_centered()
