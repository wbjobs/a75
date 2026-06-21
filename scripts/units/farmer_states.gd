extends FSMState

class FarmerIdle extends FSMState:
	func enter():
		owner.fsm.set_parameter("target_resource", null)
		owner.fsm.set_parameter("returning", false)

	func update(delta: float):
		var ai = owner.fsm.get_parameter("ai_controller", null)
		if ai and ai.auto_harvest:
			var grid = owner.grid_map
			if grid:
				var nearest = grid.find_nearest_resource(owner.grid_pos)
				if nearest.x >= 0:
					owner.fsm.set_parameter("target_resource", nearest)
					owner.fsm.change_state("Move")

class FarmerMove extends FSMState:
	func enter():
		var target = owner.fsm.get_parameter("target_resource", null)
		if target:
			owner.move_to(target)

	func update(delta: float):
		if owner.update_position(delta):
			var target = owner.fsm.get_parameter("target_resource", null)
			var returning = owner.fsm.get_parameter("returning", false)
			if returning:
				owner.fsm.change_state("Deposit")
			elif target and owner.grid_pos == target:
				owner.fsm.change_state("Harvest")
			else:
				owner.fsm.change_state("Idle")

class FarmerHarvest extends FSMState:
	var _harvest_timer: float = 0.0
	var harvest_interval: float = 0.5
	var harvest_amount: int = 5

	func enter():
		_harvest_timer = 0.0

	func update(delta: float):
		_harvest_timer += delta
		if _harvest_timer >= harvest_interval:
			_harvest_timer = 0.0
			var target = owner.fsm.get_parameter("target_resource", null)
			if target and owner.grid_map:
				var harvested = owner.grid_map.harvest_resource(target, harvest_amount)
				owner.carry_resource += harvested
				if owner.carry_resource >= owner.max_carry or harvested == 0:
					owner.fsm.set_parameter("returning", true)
					var base_pos = owner.fsm.get_parameter("base_position", owner.grid_pos)
					owner.fsm.set_parameter("target_resource", base_pos)
					owner.fsm.change_state("Move")

class FarmerDeposit extends FSMState:
	var _deposit_timer: float = 0.0
	var deposit_time: float = 0.5

	func enter():
		_deposit_timer = 0.0

	func update(delta: float):
		_deposit_timer += delta
		if _deposit_timer >= deposit_time:
			var ai = owner.fsm.get_parameter("ai_controller", null)
			if ai:
				ai.resources += owner.carry_resource
			owner.carry_resource = 0
			owner.fsm.set_parameter("returning", false)
			owner.fsm.change_state("Idle")
