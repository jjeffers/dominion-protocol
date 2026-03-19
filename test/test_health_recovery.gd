extends GutTest

var GlobeViewPath = "res://src/scripts/map/GlobeView.gd"
var GlobeUnitPath = "res://src/scripts/map/GlobeUnit.gd"

var mock_view
var u1

func before_all():
	MapData.use_mock_data = true
	GlobeView.skip_mesh_generation = true

func after_all():
	MapData.use_mock_data = false
	GlobeView.skip_mesh_generation = false

func before_each():
	var gv_scene = load("res://src/scenes/map/GlobeView.tscn")
	mock_view = gv_scene.instantiate()
	add_child(mock_view)
	
	u1 = load(GlobeUnitPath).new()
	u1.faction_name = "Blue"
	u1.current_position = Vector3(1, 0, 0)
	u1.target_position = Vector3(1, 0, 0)
	mock_view.add_child(u1)

func after_each():
	if u1 and is_instance_valid(u1):
		u1.queue_free()
	if mock_view and is_instance_valid(mock_view):
		mock_view.queue_free()

func test_health_recovery():
	await wait_physics_frames(2)
	
	u1.health = 50.0
	
	mock_view.active_scenario = {
		"factions": {
			"Blue": {
				"cities": ["BlueCity"]
			}
		}
	}
	
	# Determine what tile ID the mock view thinks is at u1.current_position
	var tile_id = mock_view._get_tile_from_vector3(u1.current_position)
	
	# Register this tile as "BlueCity"
	mock_view.city_tile_cache[tile_id] = "BlueCity"
	
	# Simulate physics process for 29 seconds (should not heal yet)
	for i in range(290):
		u1._process(0.1)
		
	assert_almost_eq(u1.health, 50.0, 0.001, "Health should not recover before 30 seconds.")
	
	# Simulate 1.1 more seconds to cross the 30-second threshold
	for i in range(11):
		u1._process(0.1)
		
	assert_almost_eq(u1.health, 60.0, 0.001, "Health should recover by 10 points after 30 seconds.")
	
	# Simulate another 30 seconds
	for i in range(300):
		u1._process(0.1)
		
	assert_almost_eq(u1.health, 70.0, 0.001, "Health should recover another 10 points.")
	
func test_no_recovery_if_not_in_friendly_city():
	await wait_physics_frames(2)
	
	u1.health = 50.0
	
	mock_view.active_scenario = {
		"factions": {
			"Red": {
				"cities": ["RedCity"]
			},
			"Blue": {
				"cities": []
			}
		}
	}
	
	var tile_id = mock_view._get_tile_from_vector3(u1.current_position)
	mock_view.city_tile_cache[tile_id] = "RedCity"
	
	# Simulate 35 seconds
	for i in range(350):
		u1._process(0.1)
		
	assert_almost_eq(u1.health, 50.0, 0.001, "Health should not recover in enemy or neutral city.")

func test_no_recovery_if_engaged():
	await wait_physics_frames(2)
	
	u1.health = 50.0
	
	var u2 = load(GlobeUnitPath).new()
	mock_view.add_child(u2)
	u2.faction_name = "Red"
	u2.current_position = Vector3(1, 0, 0)
	
	u1.set_combat_target(u2)
	u1.is_engaged = true
	
	mock_view.active_scenario = {
		"factions": {
			"Blue": {
				"cities": ["BlueCity"]
			}
		}
	}
	
	var tile_id = mock_view._get_tile_from_vector3(u1.current_position)
	mock_view.city_tile_cache[tile_id] = "BlueCity"
	
	# Simulate 35 seconds
	for i in range(350):
		u1._process(0.1)
		
	assert_almost_eq(u1.health, 50.0, 0.001, "Health should not recover when unit is engaged in combat.")

func test_sea_unit_recovery_in_docks():
	await wait_physics_frames(2)
	
	var u2 = load(GlobeUnitPath).new()
	mock_view.add_child(u2)
	u2.faction_name = "Blue"
	u2.unit_type = "cruiser"
	u2.current_position = Vector3(1, 0, 0)
	u2.target_position = Vector3(1, 0, 0)
	u2.health = 50.0
	
	mock_view.active_scenario = {
		"factions": {
			"Blue": {
				"cities": ["BlueCity"]
			}
		}
	}
	
	var tile_id = mock_view._get_tile_from_vector3(u2.current_position)
	mock_view.city_tile_cache[tile_id] = "BlueCity"
	
	# Simulate physics process for 29 seconds (should not heal yet)
	for i in range(290):
		u2._process(0.1)
		
	assert_almost_eq(u2.health, 50.0, 0.001, "Sea unit health should not recover before 30 seconds.")
	
	# Simulate 1.1 more seconds to cross the 30-second threshold
	for i in range(11):
		u2._process(0.1)
		
	assert_almost_eq(u2.health, 60.0, 0.001, "Sea unit health should recover by 10 points after 30 seconds in a dock (friendly city tile).")
	
	# Simulate another 30 seconds
	for i in range(300):
		u2._process(0.1)
		
	assert_almost_eq(u2.health, 70.0, 0.001, "Sea unit health should recover another 10 points.")
	
	u2.queue_free()
