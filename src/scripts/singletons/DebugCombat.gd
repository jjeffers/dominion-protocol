extends Node

func _process(delta):
	if Engine.get_process_frames() % 60 == 0:
		var units = get_tree().get_nodes_in_group("units")
		for u in units:
			if u.is_engaged:
				print("Unit: ", u.name, " is_engaged=True, target=", u.combat_target.name if is_instance_valid(u.combat_target) else "null", ", dist=", u.current_position.distance_to(u.combat_target.current_position) if is_instance_valid(u.combat_target) else 0)
			if u.movement_target_unit != null:
				print("Unit: ", u.name, " movement_tgt=", u.movement_target_unit.name, " dist=", u.current_position.distance_to(u.movement_target_unit.current_position))
