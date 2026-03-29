extends GutTest

var mock_main
var mock_globe

func before_each():
	var peer = OfflineMultiplayerPeer.new()
	get_tree().get_multiplayer().multiplayer_peer = peer
	
	mock_main = load("res://src/scenes/main.tscn").instantiate()
	mock_main.name = "Main"
	get_tree().root.add_child(mock_main)
	
	mock_globe = mock_main.get_node_or_null("GlobeView")
	if not mock_globe:
		mock_globe = load("res://src/scripts/map/GlobeView.gd").new()
		mock_globe.name = "GlobeView"
		mock_main.add_child(mock_globe)
		
	mock_globe.active_scenario = {
		"factions": {
			"Red": {
				"money": 100.0,
				"cities": ["City_A"],
				"oil": []
			},
			"Blue": {
				"money": 100.0,
				"cities": ["City_B"],
				"oil": ["TOP_0_0"]
			}
		},
		"neutral_cities": ["City_C"],
		"neutral_oil": ["TOP_1_1"],
		"countries": {
			"TargetCountry": {
				"cities": ["City_C"],
				"oil": ["TOP_1_1"],
				"opinions": {"Red": 0.0, "Blue": 0.0}
			}
		}
	}
	mock_main.scenario_data = mock_globe.active_scenario
	mock_main.set_process(false)

func after_each():
	get_tree().get_multiplayer().multiplayer_peer = null
	if is_instance_valid(mock_main):
		mock_main.queue_free()

func test_sync_oil_capture_transfers_ownership():
	mock_main._process_economy_tick()
	var red_initial_prod = mock_globe.active_scenario["factions"]["Red"].get("oil_production", 0)
	var blue_initial_prod = mock_globe.active_scenario["factions"]["Blue"].get("oil_production", 0)
	
	assert_eq(red_initial_prod, 0, "Red starts with 0 oil hubs")
	assert_eq(blue_initial_prod, 25, "Blue starts with 1 oil hub")

	# Red captures Blue's oil
	mock_globe.sync_oil_capture("TOP_0_0", "Red", "Blue")
	
	# Recalculcate
	mock_main._process_economy_tick()
	
	var red_final_prod = mock_globe.active_scenario["factions"]["Red"].get("oil_production", 0)
	var blue_final_prod = mock_globe.active_scenario["factions"]["Blue"].get("oil_production", 0)
	
	assert_eq(red_final_prod, 25, "Red's production should increase by 25")
	assert_eq(blue_final_prod, 0, "Blue's production should drop to 0")

func test_sync_oil_capture_from_neutral():
	# Red captures Neutral oil
	mock_globe.sync_oil_capture("TOP_1_1", "Red", "neutral")
	
	var red_oil = mock_globe.active_scenario["factions"]["Red"].get("oil", [])
	var neutral_oil = mock_globe.active_scenario.get("neutral_oil", [])
	
	assert_true(red_oil.has("TOP_1_1"), "Red should now own the previously neutral oil hub")
	assert_false(neutral_oil.has("TOP_1_1"), "Oil hub should be removed from neutral_oil array")
	
	mock_main._process_economy_tick()
	var red_final_prod = mock_globe.active_scenario["factions"]["Red"].get("oil_production", 0)
	assert_eq(red_final_prod, 25, "Capturing neutral oil successfully increases production by 25")

func test_armor_movement_shortage_penalty():
	var unit = load("res://src/scripts/map/GlobeUnit.gd").new()
	unit.name = "TestArmor"
	unit.faction_name = "Red"
	unit.unit_type = "Armor"
	
	# Manually setup motion state
	unit.current_position = Vector3(0, 1, 0)
	unit.target_position = Vector3(1, 0, 0)
	# Ensure mock map data bypasses terrain lookups cleanly by letting effective_terrain default to "WILDERNESS"
	
	if not mock_globe.get("map_data"):
		mock_globe.map_data = load("res://src/scripts/MapData.gd").new()
		
	mock_globe.add_child(unit)
	
	# Evaluate Normal Speed
	mock_globe.active_scenario["factions"]["Red"]["oil_shortage"] = false
	unit._process(1.0)
	var distance_normal = unit.current_position.distance_to(Vector3(0, 1, 0))
	
	unit.current_position = Vector3(0, 1, 0) # Reset position
	
	# Evaluate Shortage Speed
	mock_globe.active_scenario["factions"]["Red"]["oil_shortage"] = true
	unit._process(1.0)
	var distance_shortage = unit.current_position.distance_to(Vector3(0, 1, 0))
	
	unit.queue_free()
	
	# "slowed by 200%" means it takes 300% of the normal time to travel (1/3rd the typical speed)
	var expected_shortage_dist = distance_normal * 0.333333
	var margin_of_error = 0.001
	
	assert_true(abs(distance_shortage - expected_shortage_dist) <= margin_of_error, 
		"Armor movement distance should be reduced by roughly 66% (1/3rd speed) during an oil shortage.")
