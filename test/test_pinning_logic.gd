extends GutTest

var unit_script := preload("res://src/scripts/map/GlobeUnit.gd")
var globe_view_script := preload("res://src/scripts/map/GlobeView.gd")
var globe_view: Node3D

func before_each():
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	if NetworkManager != null and NetworkManager.multiplayer.has_multiplayer_peer():
		NetworkManager.multiplayer.multiplayer_peer = null

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
	mock_globe.add_child(mock_map)
	mock_globe.set("city_tile_cache", {})
	add_child_autofree(mock_globe)
	globe_view = mock_globe

func test_infantry_stops_when_engaged_and_armor_does_not():
	# Setup Infantry
	var inf = unit_script.new()
	inf.unit_type = "Infantry"
	inf.faction_name = "Blue"
	globe_view.add_child(inf)
	inf.spawn(Vector3(-0.005, 0, 1.0))
	
	# Setup Armor
	var arm = unit_script.new()
	arm.unit_type = "Armor"
	arm.faction_name = "Red"
	globe_view.add_child(arm)
	arm.spawn(Vector3(0.005, 0, 1.0))
	
	inf.target_position = Vector3(-2.0, 0, 1.0)
	arm.target_position = Vector3(2.0, 0, 1.0)
	
	var inf_path: Array[Vector3] = []
	inf_path.append(inf.target_position)
	inf.current_path = inf_path
	
	var arm_path: Array[Vector3] = []
	arm_path.append(arm.target_position)
	arm.current_path = arm_path
	
	
	# Force combat
	inf.set_combat_target(arm)
	arm.set_combat_target(inf)
	
	assert_true(inf.is_engaged, "Infantry should be engaged")
	assert_true(arm.is_engaged, "Armor should be engaged")
	
	# Infantry should have its path cleared and target reset
	assert_eq(inf.current_path.size(), 0, "Infantry should clear its path upon engagement")
	assert_eq(inf.target_position, inf.current_position, "Infantry target position should reset to current")
	
	# Armor should NOT have its path cleared nor target reset
	assert_eq(arm.current_path.size(), 1, "Armor should NOT clear its path upon engagement")
	assert_ne(arm.target_position, arm.current_position, "Armor target position should NOT reset to current")
	
	# Now test runtime process loop behavior
	inf._process(0.1)
	arm._process(0.1)
	
	assert_false(inf.is_moving, "Infantry should hard stop (is_moving = false) when engaged and within threshold")
	assert_true(arm.is_moving, "Armor should never hard stop (is_moving remains true) even when engaged and within threshold")
