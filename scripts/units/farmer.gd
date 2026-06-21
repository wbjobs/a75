class_name Farmer
extends UnitBase

func _init():
	unit_type = UnitType.FARMER
	health = 50
	max_health = 50
	speed = 70.0
	damage = 2
	attack_range = 30.0
	attack_cooldown = 1.0

func _setup_fsm():
	fsm.add_state("Idle", preload("res://scripts/units/farmer_states.gd").FarmerIdle.new())
	fsm.add_state("Move", preload("res://scripts/units/farmer_states.gd").FarmerMove.new())
	fsm.add_state("Harvest", preload("res://scripts/units/farmer_states.gd").FarmerHarvest.new())
	fsm.add_state("Deposit", preload("res://scripts/units/farmer_states.gd").FarmerDeposit.new())
	fsm.state_changed.connect(_on_state_changed)
	fsm.change_state("Idle")

func _on_state_changed(old: String, new: String):
	state_changed.emit(old, new)
