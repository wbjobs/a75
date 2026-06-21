class_name Warrior
extends UnitBase

func _init():
	unit_type = UnitType.WARRIOR
	health = 120
	max_health = 120
	speed = 65.0
	damage = 20
	attack_range = 40.0
	attack_cooldown = 0.8

func _setup_fsm():
	fsm.add_state("Idle", preload("res://scripts/units/warrior_states.gd").WarriorIdle.new())
	fsm.add_state("Move", preload("res://scripts/units/warrior_states.gd").WarriorMove.new())
	fsm.add_state("Attack", preload("res://scripts/units/warrior_states.gd").WarriorAttack.new())
	fsm.state_changed.connect(_on_state_changed)
	fsm.change_state("Idle")

func _on_state_changed(old: String, new: String):
	state_changed.emit(old, new)
