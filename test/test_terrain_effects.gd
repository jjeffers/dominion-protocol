extends GutTest

var GlobeUnit = preload("res://src/scripts/map/GlobeUnit.gd")

class MockGlobeView extends Node:
	var mock_terrain: String = "PLAINS"
	var city_tile_cache: Dictionary = {}
	
	# Mock map_data object (we just return self since the method is right here)
	var map_data = self
	
	func get_terrain(tile_id: String) -> String:
		return mock_terrain
		
	func _get_tile_from_vector3(pos: Vector3) -> String:
		return "mock_tile_id"

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
	unit.target_position = Vector3(0, 1, 0)

func test_terrain_plains_modifier():
	mock_view.mock_terrain = "PLAINS"
	unit._process(0.1)
	assert_eq(unit.current_terrain_modifier, 1.0, "Plains should have 1.0 modifier")

func test_terrain_forest_modifier():
	mock_view.mock_terrain = "FOREST"
	unit._process(0.1)
	assert_eq(unit.current_terrain_modifier, 0.5, "Forest should have 0.5 modifier")

func test_terrain_jungle_modifier():
	mock_view.mock_terrain = "JUNGLE"
	unit._process(0.1)
	assert_eq(unit.current_terrain_modifier, 0.25, "Jungle should have 0.25 modifier")
	
func test_terrain_polar_modifier():
	mock_view.mock_terrain = "POLAR"
	unit._process(0.1)
	assert_eq(unit.current_terrain_modifier, 0.25, "Polar should have 0.25 modifier")

func test_terrain_mountain_modifier():
	mock_view.mock_terrain = "MOUNTAIN"
	unit._process(0.1)
	assert_eq(unit.current_terrain_modifier, 0.1, "Mountain should have 0.1 modifier")
	
func test_terrain_city_modifier():
	mock_view.mock_terrain = "MOUNTAIN" # Terrain string won't matter if city cache hits
	mock_view.city_tile_cache["mock_tile_id"] = "test_city"
	unit._process(0.1)
	assert_eq(unit.current_terrain_modifier, 1.0, "City should override underlying terrain with 1.0 modifier")
