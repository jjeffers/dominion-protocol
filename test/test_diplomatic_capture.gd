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
		
	# Initialize the mock scenario
	mock_globe.active_scenario = {
		"factions": {
			"Red": {
				"money": 100.0,
				"cities": ["City_X"],
				"oil": []
			},
			"Blue": {
				"money": 100.0,
				"cities": ["City_Y"],
				"oil": []
			}
		},
		"neutral_cities": ["City_A", "City_B"],
		"neutral_oil": [],
		"countries": {
			"TargetCountry": {
				"cities": ["City_A", "City_B"],
				"oil": [],
				"opinions": {"Red": 0.0, "Blue": -40.0}
			}
		}
	}
	mock_main.scenario_data = mock_globe.active_scenario
	mock_main.set_process(false)
	
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.is_host = true

func after_each():
	get_tree().get_multiplayer().multiplayer_peer = null
	if is_instance_valid(mock_main):
		mock_main.queue_free()
		
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.is_host = false

func test_city_capture_state_corruption():
	var city_node = Node3D.new()
	city_node.name = "City_A"
	mock_globe.add_child(city_node)
	city_node.position = Vector3(1, 0, 0)
	mock_globe.city_nodes.append(city_node)
	
	var land_unit = load("res://src/scripts/map/GlobeUnit.gd").new()
	land_unit.name = "TestInfantry"
	land_unit.faction_name = "Blue"
	land_unit.unit_type = "Infantry"
	mock_globe.add_child(land_unit)
	land_unit.current_position = Vector3(1, 0, 0)
	land_unit.global_position = Vector3(1, 0, 0)
	mock_globe.units_list.append(land_unit)
	
	# Assert initial condition
	assert_false(mock_globe.active_scenario["factions"]["Blue"]["cities"].has("City_A"), "Blue should not own City_A at start")
	assert_false(mock_globe.active_scenario["factions"]["Red"]["cities"].has("City_A"), "Red should not own City_A at start")
	
	# Tick captures. 12 ticks to safely clear the 10.0 time requirement
	for i in range(12):
		mock_globe._process_city_captures()

	# Assert outcomes
	
	var blue_has_a = mock_globe.active_scenario["factions"]["Blue"]["cities"].has("City_A")
	var red_has_a = mock_globe.active_scenario["factions"]["Red"]["cities"].has("City_A")
	var red_has_b = mock_globe.active_scenario["factions"]["Red"]["cities"].has("City_B")
	
	assert_true(blue_has_a, "Blue successfully captures City_A and parses it into JSON")
	assert_false(red_has_a, "Red MUST NOT retain City_A simultaneously. The JSON state must be completely decoupled.")
	assert_true(red_has_b, "Red successfully receives City_B (the remaining country city) via the diplomatic alignment cascade")
	
	land_unit.queue_free()
	city_node.queue_free()
