extends GutTest

var GlobeUnit = preload("res://src/scripts/map/GlobeUnit.gd")

class MockGlobeView extends Node:
	var mock_terrain: String = "PLAINS"
	var city_tile_cache: Dictionary = {}
	var map_data = self
	
	func get_terrain(tile_id: int) -> String:
		return mock_terrain
		
	func _get_tile_from_vector3(pos: Vector3) -> int:
		return 100

var mock_view: MockGlobeView
var unit

func before_each():
	mock_view = MockGlobeView.new()
	add_child_autoqfree(mock_view)
	
	unit = GlobeUnit.new()
	unit.faction_name = "Blue"
	mock_view.add_child(unit)
	unit._init()
	unit.current_position = Vector3(1, 0, 0)
	unit.target_position = Vector3(1, 0, 0)

func test_infantry_entrenchment_after_30_seconds():
	unit.unit_type = "Infantry"
	unit.time_motionless = 0.0
	unit.entrenched = false
	
	# Simulate 29 seconds of waiting
	unit._process(29.0)
	assert_false(unit.entrenched, "Infantry should NOT be entrenched before 30 seconds pass.")
	
	# Simulate 1 more second to cross the 30s threshold
	unit._process(1.5)
	assert_true(unit.entrenched, "Infantry MUST be entrenched after being motionless for 30 seconds.")
	
func test_armor_never_entrenches():
	unit.unit_type = "Armor"
	unit.time_motionless = 0.0
	unit.entrenched = false
	
	# Simulate 35 seconds of waiting
	unit._process(35.0)
	assert_false(unit.entrenched, "Armor must never entrench regardless of motionless time.")



