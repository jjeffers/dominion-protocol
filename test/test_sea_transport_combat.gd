extends GutTest

var unit_script := preload("res://src/scripts/map/GlobeUnit.gd")
var globe_view_script := preload("res://src/scripts/map/GlobeView.gd")
var globe_view: Node3D

func before_each():
	globe_view = Node3D.new()
	globe_view.set_script(globe_view_script)
	add_child_autofree(globe_view)
	# Mock city_tile_cache and map_data layout
	globe_view.set("city_tile_cache", {})
	
	var mock_map = Node.new()
	var mock_map_script = GDScript.new()
	mock_map_script.source_code = """
extends Node
func get_terrain(tile_id: int) -> String:
	if tile_id == 0:
		return "OCEAN"
	else:
		return "PLAINS"
	"""
	mock_map_script.reload()
	mock_map.set_script(mock_map_script)
	globe_view.set("map_data", mock_map)
	globe_view.add_child(mock_map)
	
	var mock_get_tile_script = GDScript.new()
	mock_get_tile_script.source_code = """
extends Node3D
var map_data
var city_tile_cache = {}
# Extend the globe_view script essentially to provide _get_tile_from_vector3
func _get_tile_from_vector3(pos: Vector3) -> int:
	if pos.x < 0.0:
		return 0 # OCEAN
	return 1 # PLAINS
	"""
	mock_get_tile_script.reload()
	
	# Instead of extending the globe view directly, we'll just mock the function
	var mock_globe = Node3D.new()
	mock_globe.set_script(mock_get_tile_script)
	mock_globe.set("map_data", mock_map)
	mock_globe.set("city_tile_cache", {})
	add_child_autofree(mock_globe)
	globe_view = mock_globe

func test_amphibious_vs_coastal_armor():
	# Setup Infantry in Ocean
	var inf = unit_script.new()
	inf.unit_type = "Infantry"
	inf.faction_name = "Blue"
	globe_view.add_child(inf)
	inf.spawn(Vector3(-1.0, 0, 0)) # Spawns in OCEAN
	
	# Setup Armor on Plains
	var arm = unit_script.new()
	arm.unit_type = "Armor"
	arm.faction_name = "Red"
	globe_view.add_child(arm)
	arm.spawn(Vector3(1.0, 0, 0)) # Spawns in PLAINS
	
	# Move them right into engagement range manually
	inf.current_position = Vector3(-0.005, 0, 1.0) # Within 0.01 threshold
	arm.current_position = Vector3(0.005, 0, 1.0)
	inf.target_position = inf.current_position
	arm.target_position = arm.current_position
	
	# Force combat lock
	inf.set_combat_target(arm)
	arm.set_combat_target(inf)
	
	assert_true(inf.is_engaged, "Infantry should be engaged")
	assert_true(arm.is_engaged, "Armor should be engaged")
	
	# Evaluate terrain resolution logic before combat ticks
	inf._process(0.1)
	arm._process(0.1)
	
	assert_true(inf.get("is_seaborne"), "Infantry on ocean tile should be flagged as seaborne")
	assert_false(arm.get("is_seaborne"), "Armor on plains tile should not be flagged as seaborne")
	
	var start_hp_arm = arm.health
	var start_hp_inf = inf.health
	
	# Tick exactly 5 seconds so they both fire once
	inf._process(4.9)
	arm._process(4.9)
	
	var end_hp_arm = arm.health
	var end_hp_inf = inf.health
	
	assert_true(end_hp_arm < start_hp_arm, "Armor should take damage from Infantry. Expected < 100, got: " + str(end_hp_arm))
	assert_true(end_hp_inf < start_hp_inf, "Infantry should take damage from Armor. Expected < 100, got: " + str(end_hp_inf))



