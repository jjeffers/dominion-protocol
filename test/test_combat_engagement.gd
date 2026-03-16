extends GutTest

var GameManagerPath = "res://src/scripts/GameManager.gd"
var GlobeViewPath = "res://src/scripts/map/GlobeView.gd"
var GlobeUnitPath = "res://src/scripts/map/GlobeUnit.gd"

var mock_view
var u1
var u2

func before_each():
	mock_view = GlobeView.new()
	add_child(mock_view)
	
	u1 = GlobeUnit.new()
	u1.faction_name = "Blue"
	u1.current_position = Vector3(1, 0, 0)
	u1.target_position = Vector3(1, 0, 0)
	add_child(u1)
	
	u2 = GlobeUnit.new()
	u2.faction_name = "Red"
	u2.current_position = Vector3(0.999, 0, 0)
	u2.target_position = Vector3(0.999, 0, 0)
	add_child(u2)

func after_each():
	u1.queue_free()
	u2.queue_free()
	mock_view.queue_free()

func test_combat_engagement_locks_target():
	# Act: Set target to enemy unit
	var starting_pos = u1.current_position
	u1.set_movement_target_unit(u2)
	
	# Simulate physics process
	for i in range(100):
		u1._process(0.1)
		
	# Assert: It stopped moving entirely to fight
	assert_true(u1.is_engaged)
	assert_eq(u1.combat_target, u2)
