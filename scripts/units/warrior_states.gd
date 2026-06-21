extends FSMState

class WarriorIdle extends FSMState:
	func enter():
		owner.target_unit = null

	func update(delta: float):
		var ai = owner.fsm.get_parameter("ai_controller", null)
		if ai:
			if ai.current_order == "attack":
				_find_and_attack()
			elif ai.current_order == "defend":
				_defend_base()

	func _find_and_attack():
		var enemies = owner.fsm.get_parameter("enemies", [])
		var nearest: UnitBase = null
		var nearest_dist = 99999.0
		for enemy in enemies:
			if enemy and is_instance_valid(enemy):
				var dist = owner.grid_pos.distance_to(enemy.grid_pos)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest = enemy
		if nearest:
			owner.target_unit = nearest
			owner.fsm.set_parameter("target_pos", nearest.grid_pos)
			owner.fsm.change_state("Move")

	func _defend_base():
		var base_pos = owner.fsm.get_parameter("base_position", owner.grid_pos)
		var dist_to_base = owner.grid_pos.distance_to(base_pos)
		if dist_to_base > 4:
			owner.fsm.set_parameter("target_pos", base_pos)
			owner.fsm.change_state("Move")
		else:
			_find_and_attack()

class WarriorMove extends FSMState:
	func enter():
		var target_pos = owner.fsm.get_parameter("target_pos", null)
		if target_pos:
			owner.move_to(target_pos)

	func update(delta: float):
		if owner.target_unit and is_instance_valid(owner.target_unit):
			var dist = owner.position.distance_to(owner.target_unit.position)
			if dist <= owner.attack_range:
				owner.fsm.change_state("Attack")
				return
		if owner.update_position(delta):
			if owner.target_unit and is_instance_valid(owner.target_unit):
				var dist = owner.position.distance_to(owner.target_unit.position)
				if dist <= owner.attack_range:
					owner.fsm.change_state("Attack")
				else:
					owner.fsm.set_parameter("target_pos", owner.target_unit.grid_pos)
					owner.move_to(owner.target_unit.grid_pos)
			else:
				owner.fsm.change_state("Idle")

class WarriorAttack extends FSMState:
	func update(delta: float):
		if not owner.target_unit or not is_instance_valid(owner.target_unit):
			owner.fsm.change_state("Idle")
			return
		var dist = owner.position.distance_to(owner.target_unit.position)
		if dist > owner.attack_range:
			owner.fsm.set_parameter("target_pos", owner.target_unit.grid_pos)
			owner.fsm.change_state("Move")
			return
		owner.attack_target()
