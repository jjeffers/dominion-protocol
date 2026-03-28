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
	unit.target_position = Vector3(0, 1, 0)

const EXPECTED_TEC = {
	"Infantry": {
		"PLAINS": {"movement": 1.0, "defense": 1.0},
		"FOREST": {"movement": 0.5, "defense": 0.75},
		"JUNGLE": {"movement": 0.25, "defense": 0.5},
		"DESERT": {"movement": 0.5, "defense": 1.0},
		"MOUNTAINS": {"movement": 0.1, "defense": 0.5},
		"POLAR": {"movement": 0.25, "defense": 1.0},
		"CITY": {"movement": 1.0, "defense": 0.5},
		"OCEAN": {"movement": 3.0, "defense": 1.0},
		"LAKE": {"movement": 3.0, "defense": 1.0}
	},
	"Armor": {
		"PLAINS": {"movement": 3.75, "defense": 1.0},
		"FOREST": {"movement": 1.25, "defense": 0.75},
		"JUNGLE": {"movement": 0.625, "defense": 0.75},
		"DESERT": {"movement": 2.5, "defense": 1.0},
		"MOUNTAINS": {"movement": 0.25, "defense": 1.0},
		"POLAR": {"movement": 0.625, "defense": 1.0},
		"CITY": {"movement": 2.5, "defense": 0.75},
		"OCEAN": {"movement": 3.0, "defense": 1.0},
		"LAKE": {"movement": 3.0, "defense": 1.0}
	}
}

func test_all_infantry_movement():
	unit.unit_type = "Infantry"
	for terrain in EXPECTED_TEC["Infantry"].keys():
		mock_view.city_tile_cache.clear()
		if terrain == "CITY":
			mock_view.mock_terrain = "MOUNTAINS"
			mock_view.city_tile_cache[100] = "test_city"
		else:
			mock_view.mock_terrain = terrain
		
		unit._process(0.1)
		var expected = EXPECTED_TEC["Infantry"][terrain]["movement"]
		assert_eq(unit.current_terrain_modifier, expected, "Infantry movement on " + terrain)

func test_all_infantry_defense():
	unit.unit_type = "Infantry"
	for terrain in EXPECTED_TEC["Infantry"].keys():
		mock_view.city_tile_cache.clear()
		if terrain == "CITY":
			mock_view.mock_terrain = "MOUNTAINS"
			mock_view.city_tile_cache[100] = "test_city"
		else:
			mock_view.mock_terrain = terrain
		
		unit.health = 100.0
		unit.is_dead = false
		unit.take_damage(100.0)
		var expected_health = 100.0 - (100.0 * EXPECTED_TEC["Infantry"][terrain]["defense"])
		assert_eq(unit.health, expected_health, "Infantry defense on " + terrain)

func test_all_armor_movement():
	unit.unit_type = "Armor"
	for terrain in EXPECTED_TEC["Armor"].keys():
		mock_view.city_tile_cache.clear()
		if terrain == "CITY":
			mock_view.mock_terrain = "MOUNTAINS"
			mock_view.city_tile_cache[100] = "test_city"
		else:
			mock_view.mock_terrain = terrain
		
		unit._process(0.1)
		var expected = EXPECTED_TEC["Armor"][terrain]["movement"]
		assert_eq(unit.current_terrain_modifier, expected, "Armor movement on " + terrain)

func test_all_armor_defense():
	unit.unit_type = "Armor"
	for terrain in EXPECTED_TEC["Armor"].keys():
		mock_view.city_tile_cache.clear()
		if terrain == "CITY":
			mock_view.mock_terrain = "MOUNTAINS"
			mock_view.city_tile_cache[100] = "test_city"
		else:
			mock_view.mock_terrain = terrain
		
		unit.health = 100.0
		unit.is_dead = false
		unit.take_damage(100.0)
		var expected_health = 100.0 - (100.0 * EXPECTED_TEC["Armor"][terrain]["defense"])
		assert_eq(unit.health, expected_health, "Armor defense on " + terrain)

func test_sea_units_cannot_move_to_land():
	unit.unit_type = "Cruiser"
	
	# Test Ocean
	mock_view.city_tile_cache.clear()
	mock_view.mock_terrain = "OCEAN"
	unit._process(0.1)
	assert_eq(unit.current_terrain_modifier, 5.0, "Cruiser movement on OCEAN should be 5.0")
	
	# Test Land
	mock_view.mock_terrain = "PLAINS"
	unit._process(0.1)
	assert_eq(unit.current_terrain_modifier, 0.0, "Cruiser movement on PLAINS should be 0.0")



