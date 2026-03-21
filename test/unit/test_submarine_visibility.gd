extends "res://addons/gut/test.gd"

var GlobeUnit = preload("res://src/scripts/map/GlobeUnit.gd")

func test_submarine_detected_by_stationary_cruiser():
	var sub = GlobeUnit.new()
	sub.name = "RedSub"
	sub.unit_type = "Submarine"
	sub.faction_name = "Red"
	add_child_autofree(sub)
	
	var cruiser = GlobeUnit.new()
	cruiser.name = "BlueCruiser"
	cruiser.unit_type = "Cruiser"
	cruiser.faction_name = "Blue"
	add_child_autofree(cruiser)
	
	# Spawn them close to each other (dist <= 0.024)
	sub.spawn(Vector3(0, 0, 1))
	# A slight offset to be adjacent but well within the 0.024 threshold
	var off_pos = Vector3(0, 0.015, 1).normalized()
	cruiser.spawn(off_pos)
	
	# Frame 1: Make cruiser perfectly stationary
	cruiser.set_target(cruiser.current_position)
	cruiser._process(1.0)
	assert_false(cruiser.get("is_moving"), "Cruiser must natively report as stationary when halted.")
	
	# Frame 2: Ensure submarine is moving, as subs only check detection flags while in motion
	sub.set_target(sub.current_position + Vector3(0.005, 0, 0))
	sub._process(1.0)
	
	# Assertion: Because the cruiser is stationary, the moving sub should be instantly pinged
	assert_true(sub.is_detected, "Moving Submarine MUST be detected by an adjacent stationary cruiser")

func test_submarine_hidden_from_moving_cruiser():
	var sub = GlobeUnit.new()
	sub.name = "RedSub2"
	sub.unit_type = "Submarine"
	sub.faction_name = "Red"
	add_child_autofree(sub)
	
	var cruiser = GlobeUnit.new()
	cruiser.name = "BlueCruiser2"
	cruiser.unit_type = "Cruiser"
	cruiser.faction_name = "Blue"
	add_child_autofree(cruiser)
	
	# Spawn close to each other
	sub.spawn(Vector3(0, 0, 1))
	cruiser.spawn(Vector3(0, 0.015, 1).normalized())
	
	# Frame 1: Make cruiser move, which provides camouflage to the sub
	cruiser.set_target(cruiser.current_position + Vector3(0.05, 0, 0))
	cruiser._process(1.0)
	assert_true(cruiser.get("is_moving"), "Cruiser must natively report as moving when travelling.")
	
	# Frame 2: Submarine moves through the water, but the cruiser is masked by its own noise
	sub.set_target(sub.current_position + Vector3(0.005, 0, 0))
	sub._process(1.0)
	
	# Assertion: Sub remains invisible if the only adjacent enemies are also in motion
	assert_false(sub.is_detected, "Moving Submarine MUST REMAIN HIDDEN if adjacent cruisers are also moving")
