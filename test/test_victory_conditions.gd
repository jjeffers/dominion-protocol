extends GutTest

var globe: GlobeView
var main: MainScene

func before_all():
	MapData.use_mock_data = true
	GlobeView.skip_mesh_generation = true

func after_all():
	MapData.use_mock_data = false
	GlobeView.skip_mesh_generation = false

func before_each() -> void:
	var main_scene = load("res://src/scenes/main.tscn")
	main = main_scene.instantiate()
	add_child_autofree(main)
	globe = main.globe_view
	
	# Create a dummy scenario
	var test_scenario = {
		"name": "Test Elimination",
		"factions": {
			"Blue": {
				"capitol": "Paris",
				"cities": ["London", "Paris", "Marseille"],
				"units": []
			},
			"Red": {
				"capitol": "Berlin",
				"cities": ["Berlin", "Munich"],
				"units": []
			}
		},
		"neutral_cities": []
	}
	
	globe.active_scenario = test_scenario
	
	# We mock the multiplayer peer by acting as authority locally
	var peer = OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = peer

func after_each() -> void:
	multiplayer.multiplayer_peer = null

func test_faction_elimination() -> void:
	# Add dummy units
	var blue_unit = Node3D.new()
	var script = GDScript.new()
	script.source_code = "extends Node3D\nvar faction_name: String"
	script.reload()
	blue_unit.set_script(script)
	blue_unit.set("faction_name", "Blue")
	
	var red_unit = Node3D.new()
	red_unit.set_script(script)
	red_unit.set("faction_name", "Red")

	globe.units_list.append(blue_unit)
	globe.units_list.append(red_unit)
	globe.add_child(blue_unit)
	globe.add_child(red_unit)
	
	# Simulate Blue losing a normal city (London)
	globe.sync_city_capture("London", "Red", "Blue")
	
	# Verify Blue is NOT eliminated
	assert_false(globe.active_scenario["factions"]["Blue"].has("eliminated") and globe.active_scenario["factions"]["Blue"]["eliminated"])
	assert_true(is_instance_valid(blue_unit))
	
	# Simulate Blue losing their capitol (Paris)
	globe.sync_city_capture("Paris", "Red", "Blue")
	
	# Verify Blue IS eliminated
	var blue_elim_status = globe.active_scenario["factions"]["Blue"].get("eliminated", false)
	assert_true(blue_elim_status, "Blue should be eliminated after losing Paris")
	
	# Verify remaining cities are neutral
	assert_true(globe.active_scenario["neutral_cities"].has("Marseille"), "Marseille should be neutral")
	assert_false(globe.active_scenario["factions"]["Blue"]["cities"].has("Marseille"), "Blue should no longer own Marseille")
	
	# Verify units are destroyed (queue_free called)
	# is_queued_for_deletion() immediately returns true after queue_free, 
	# removing the need to wait for engine garbage collection loops.
	assert_true(blue_unit.is_queued_for_deletion(), "Blue unit should be queued for deletion")
	assert_false(red_unit.is_queued_for_deletion(), "Red unit should survive")

func test_victory_condition() -> void:
	# Spy on the victory signal
	watch_signals(globe)
	
	# Eliminate Blue (leaving only Red)
	globe.sync_city_capture("Paris", "Red", "Blue")
	
	assert_signal_emitted(globe, "victory_declared")
	assert_signal_emitted_with_parameters(globe, "victory_declared", ["Red"])
