extends SceneTree

func _init():
	var map_unit = load("res://src/scripts/map/GlobeUnit.gd")
	var u1 = map_unit.new()
	var u2 = map_unit.new()
	u1.name = "Attacker"
	u2.name = "Defender"
	u1.faction_name = "Blue"
	u2.faction_name = "Red"
	
	var root = Node3D.new()
	root.add_child(u1)
	root.add_child(u2)
	
	u1.spawn(Vector3(1.0, 0.0, 0.0))
	var a = deg_to_rad(0.85)
	u2.spawn(Vector3(cos(a), sin(a), 0.0))
	
	print("Radii properties:")
	print("u1 radius: ", u1.radius)
	print("u2 radius: ", u2.radius)
	print("Path execution speed: ", u1.speed_units_per_sec)
	
	u1.set_movement_target_unit(u2)
	u1.set_target(u2.current_position)
	
	# Execute a single frame manually to see what breaks
	var delta = 0.1
	var angle = u1.current_position.angle_to(u1.target_position)
	var step = (u1.speed_units_per_sec * delta) / u1.radius
	var weight = min(step / angle, 1.0) if angle > 0 else 1.0
	var next_pos = u1.current_position.slerp(u1.target_position, weight).normalized() * u1.radius
	
	print("Angle: ", angle)
	print("Step: ", step)
	print("Weight: ", weight)
	print("Next distance: ", next_pos.distance_to(u2.current_position))
	
	quit()
