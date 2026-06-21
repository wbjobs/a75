class_name AITask
extends RefCounted

enum TaskType {
	IDLE,
	HARVEST,
	ATTACK,
	DEFEND,
	EXPAND,
	MOVE,
	DEPOSIT
}

enum TaskStatus {
	PENDING,
	EXECUTING,
	COMPLETED,
	FAILED,
	CANCELLED
}

enum Priority {
	LOW = 10,
	MEDIUM = 30,
	HIGH = 60,
	CRITICAL = 90,
	EMERGENCY = 100
}

var task_type: int = TaskType.IDLE
var priority: int = Priority.LOW
var status: int = TaskStatus.PENDING
var target_unit: UnitBase = null
var target_position: Vector2i = Vector2i.ZERO
var target_resource: Vector2i = Vector2i.ZERO
var assigned_unit: UnitBase = null
var created_time: float = 0.0
var started_time: float = 0.0
var completed_time: float = 0.0
var max_duration: float = 30.0
var cool_down_time: float = 2.0
var failure_cool_down: float = 5.0
var task_id: String = ""
var description: String = ""

func _init(type: int = TaskType.IDLE, prio: int = Priority.LOW, desc: String = ""):
	task_type = type
	priority = prio
	description = desc
	created_time = Time.get_ticks_msec() / 1000.0
	task_id = "task_%s_%d" % [Time.get_unix_time_from_system(), randi()]

func start() -> bool:
	if status != TaskStatus.PENDING:
		return false
	status = TaskStatus.EXECUTING
	started_time = Time.get_ticks_msec() / 1000.0
	return true

func complete(success: bool = true):
	if success:
		status = TaskStatus.COMPLETED
	else:
		status = TaskStatus.FAILED
	completed_time = Time.get_ticks_msec() / 1000.0

func cancel():
	status = TaskStatus.CANCELLED
	completed_time = Time.get_ticks_msec() / 1000.0

func is_active() -> bool:
	return status == TaskStatus.PENDING or status == TaskStatus.EXECUTING

func is_finished() -> bool:
	return status == TaskStatus.COMPLETED or status == TaskStatus.FAILED or status == TaskStatus.CANCELLED

func get_elapsed_time() -> float:
	if started_time == 0.0:
		return 0.0
	return Time.get_ticks_msec() / 1000.0 - started_time

func has_timed_out() -> bool:
	if status != TaskStatus.EXECUTING:
		return false
	return get_elapsed_time() > max_duration

func get_cool_down() -> float:
	if status == TaskStatus.FAILED:
		return failure_cool_down
	return cool_down_time

func get_priority_name() -> String:
	match priority:
		Priority.LOW:
			return "低"
		Priority.MEDIUM:
			return "中"
		Priority.HIGH:
			return "高"
		Priority.CRITICAL:
			return "紧急"
		Priority.EMERGENCY:
			return "危急"
		_:
			return str(priority)

func get_type_name() -> String:
	match task_type:
		TaskType.IDLE:
			return "闲置"
		TaskType.HARVEST:
			return "采集"
		TaskType.ATTACK:
			return "进攻"
		TaskType.DEFEND:
			return "防守"
		TaskType.EXPAND:
			return "扩张"
		TaskType.MOVE:
			return "移动"
		TaskType.DEPOSIT:
			return "存资源"
		_:
			return "未知"

func get_status_name() -> String:
	match status:
		TaskStatus.PENDING:
			return "等待中"
		TaskStatus.EXECUTING:
			return "执行中"
		TaskStatus.COMPLETED:
			return "已完成"
		TaskStatus.FAILED:
			return "失败"
		TaskStatus.CANCELLED:
			return "已取消"
		_:
			return "未知"
