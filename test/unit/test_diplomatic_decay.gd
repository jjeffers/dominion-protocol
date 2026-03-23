extends GutTest

var GlobeViewPath = "res://src/scripts/map/GlobeView.gd"

var mock_globe
var mock_main

func before_each():
	var peer = OfflineMultiplayerPeer.new()
	get_tree().get_multiplayer().multiplayer_peer = peer

	var mock_main_script = GDScript.new()
	mock_main_script.source_code = "extends Node\nvar scenario_data = {}\nfunc _update_diplomacy_ui(): pass"
	mock_main_script.reload()
	mock_main = Node.new()
	mock_main.set_script(mock_main_script)
	mock_main.name = "Main"
	get_tree().root.add_child(mock_main)

	mock_globe = preload("res://src/scripts/map/GlobeView.gd").new()
	mock_globe.name = "GlobeView"
	get_tree().root.add_child(mock_globe)

func after_each():
	if is_instance_valid(mock_main):
		mock_main.queue_free()
	if is_instance_valid(mock_globe):
		mock_globe.queue_free()

func test_invasion_decay_applied_to_neutral_country():
	var scenario = {
		"countries": {
			"Switzerland": {
				"cities": ["Geneva"],
				"opinions": {"Red": 0.0, "Blue": 0.0}
			}
		},
		"neutral_cities": ["Geneva"],
		"factions": {
			"Red": {},
			"Blue": {}
		}
	}
	mock_globe.active_scenario = scenario
	
	# Mock MapData
	var mock_map = preload("res://src/scripts/map/MapData.gd").new()
	var mock_map_script = GDScript.new()
	mock_map_script.source_code = "extends 'res://src/scripts/map/MapData.gd'\nfunc get_region(tile_id): return 'Switzerland'"
	mock_map_script.reload()
	mock_map.set_script(mock_map_script)
	mock_globe.map_data = mock_map
	mock_globe.units_list.clear()
	
	# Create an infantry unit for Red faction
	var mock_unit = Node3D.new()
	var mock_unit_script = GDScript.new()
	mock_unit_script.source_code = "extends Node3D\nvar unit_type = 'Infantry'\nvar is_dead = false\nvar target_position = Vector3(1,0,0)\nvar current_position = Vector3(1,0,0)\nvar faction_name = 'Red'"
	mock_unit_script.reload()
	mock_unit.set_script(mock_unit_script)
	mock_globe.add_child(mock_unit)
	mock_globe.units_list.append(mock_unit)
	
	# Initial opinion should be 0.0
	assert_eq(mock_globe.active_scenario["countries"]["Switzerland"]["opinions"]["Red"], 0.0)
	
	# Trigger the diplomacy tick process
	mock_globe._process_diplomacy()
	
	# Verify opinion decayed by 1.0 points for the Red faction after 1 tick
	assert_eq(mock_globe.active_scenario["countries"]["Switzerland"]["opinions"]["Red"], -1.0)
	
	# Verify Blue faction opinion remains unaffected
	assert_eq(mock_globe.active_scenario["countries"]["Switzerland"]["opinions"]["Blue"], 0.0)
