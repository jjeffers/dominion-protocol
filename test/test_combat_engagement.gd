extends GutTest

var GameManagerPath = "res://src/scripts/GameManager.gd"
var GlobeViewPath = "res://src/scripts/map/GlobeView.gd"
var GlobeUnitPath = "res://src/scripts/map/GlobeUnit.gd"

var mock_view
var u1
var u2

var city_tile_cache: Dictionary = {}

var map_data = self

func _get_tile_from_vector3(pos: Vector3) -> int:
	return 12345

func get_terrain(tile_id: int) -> String:
	return "PLAINS"

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
	
	u1 = GlobeUnit.new()
	u1.faction_name = "Blue"
	u1.current_position = Vector3(1, 0, 0)
	u1.target_position = Vector3(1, 0, 0)
	add_child(u1)
	
	u2 = GlobeUnit.new()
	u2.faction_name = "Red"
	u2.current_position = Vector3(0.999, 0, 0)
	u2.target_position = Vector3(0.999, 0, 0)
	add_child(u2)

func after_each():
	u1.queue_free()
	u2.queue_free()
	mock_view.queue_free()

func test_combat_engagement_locks_target():
	# Act: Set target to enemy unit
	var starting_pos = u1.current_position
	u1.set_movement_target_unit(u2)
	
	# Simulate physics process
	for i in range(100):
		u1._process(0.1)
		
	# Assert: It stopped moving entirely to fight
	assert_true(u1.is_engaged)
	assert_eq(u1.combat_target, u2)

func test_combat_damage_armor():
	u1.unit_type = "Armor"
	u1.set_combat_target(u2)
	u2.health = 100.0
	u1.combat_timer = 5.0 # force attack next frame
	u1._process(0.1)
	assert_eq(u2.health, 75.0, "Armor should deal 25 damage")

func test_armor_attacks_entrenched_infantry_in_city():
	u1.unit_type = "Armor"
	u2.unit_type = "Infantry"
	u2.entrenched = true
	city_tile_cache[12345] = "test_city"
	u1.set_combat_target(u2)
	u2.health = 100.0
	u1.combat_timer = 5.0 # force attack next frame
	u1._process(0.1)
	
	# Base Armor damage = 25. Infantry City Defense = 0.5, Entrenched = 0.5. Total damage = 25 * 0.5 * 0.5 = 6.25
	assert_eq(u2.health, 93.75, "Entrenched Infantry in City should take 6.25 damage from Armor")

func test_right_click_bypasses_unit_area():
	# Let physics space sync so Map collider is ready
	await wait_physics_frames(2)
	
	# Setup mock network manager to safely evaluate local faction without RPC exceptions in test
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var local_id = multiplayer.get_unique_id()
	NetworkManager.players[local_id] = {"faction": "Blue"}
	
	mock_view.selected_unit = u1
	mock_view.target_bracket = Sprite3D.new()
	mock_view.add_child(mock_view.target_bracket)
	mock_view.target_bracket.visible = true
	
	# Camera is at (0, 0, 3) looking down Z axis at origin.
	# Center of screen raycast hits exact globe geometric map surface at (0, 0, 1.0)
	# Position enemy u2 slightly off-center (x=0.008), 
	# which is close enough that its Area3D (radius 0.0092) physically intersects the exact center screen raycast.
	u2.global_position = Vector3(0.008, 0, 1.0)
	u2.current_position = Vector3(0.008, 0, 1.0)
	
	# Issue right click (false = right) exactly in the center of the screen
	var center = mock_view.camera.get_viewport().size / 2.0
	mock_view._handle_click(center, false)
	
	# Assert: Because the raycast bypassed Area3Ds, it hit the raw map coordinate (0, 0, 1.0).
	# Because u2 is located at (0.008...) which is a different map tile, it should NOT snap to target u2.
	assert_null(u1.movement_target_unit, "Unit should not be targeting enemy.")
	assert_not_null(u1.target_position, "Unit should have geometric movement target.")
	assert_gt(u1.target_position.distance_to(u2.current_position), 0.001, "Unit geometric target should not strictly match enemy position.")
	
	# Teardown local network mock
	multiplayer.multiplayer_peer = null
	if NetworkManager.players.has(local_id):
		NetworkManager.players.erase(local_id)
