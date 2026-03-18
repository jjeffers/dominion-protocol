extends GutTest

var globe_view_scene = preload("res://src/scenes/map/GlobeView.tscn")
var globe_view: GlobeView
var u1: GlobeUnit # Friendly Air Unit
var u2: GlobeUnit # Enemy Armor
var local_id = 1

func before_all():
	MapData.use_mock_data = true
	GlobeView.skip_mesh_generation = true
	
	# Mock network
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(7005)
	multiplayer.multiplayer_peer = peer
	
	NetworkManager.players = {
		local_id: {"name": "TestHost", "faction": "Blue"}
	}
	NetworkManager.is_host = true
	
	globe_view_scene = load("res://src/scenes/map/GlobeView.tscn")

func after_all():
	MapData.use_mock_data = false
	GlobeView.skip_mesh_generation = false
	
	multiplayer.multiplayer_peer = null
	if NetworkManager.players.has(local_id):
		NetworkManager.players.erase(local_id)

func before_each():
	globe_view = globe_view_scene.instantiate() as GlobeView
	
	# Skip generating geometry
	globe_view.map_data = MapData.new()
	add_child_autofree(globe_view)
	
	# Empty map state
	globe_view.active_scenario = {
		"factions": {
			"Blue": {"cities": ["TestCity"]},
			"Red": {"cities": []}
		}
	}
	
	var city_node = Node3D.new()
	city_node.name = "Unit_City_TestCity"
	
	# A point exactly on the equator (longitude/latitude 0/0 -> Vector3(0,0,1))
	var map_radius = globe_view.radius
	city_node.position = Vector3(0, 0, map_radius) 
	globe_view.add_child(city_node)
	globe_view.city_nodes.append(city_node)
	
	u1 = GlobeUnit.new()
	u1.name = "Unit1"
	globe_view.add_child(u1)
	globe_view.units_list.append(u1)
	globe_view.cullable_nodes.append(u1)
	
	u2 = GlobeUnit.new()
	u2.name = "Unit2"
	globe_view.add_child(u2)
	globe_view.units_list.append(u2)
	globe_view.cullable_nodes.append(u2)

func after_each():
	pass

func test_air_visibility_bubble():
	var map_radius = globe_view.radius
	
	u1.faction_name = "Blue"
	u1.unit_type = "Air"
	u1.is_air_ready = true
	# Placed at city center
	u1.global_position = Vector3(map_radius, 0, 0)
	
	u2.faction_name = "Red"
	u2.unit_type = "Armor"
	
	# Calculate exactly how massive the bubble should be at the equator
	var tile_id = globe_view._get_tile_from_vector3(u1.global_position)
	var tile_width = globe_view._get_tile_width(tile_id)
	var strike_radius = 30.0 * tile_width
	
	# Place the enemy Armor unit just barely inside the 30x radius limit
	var test_dir = Vector3(0, strike_radius - 0.005, 0)
	u2.global_position = (u1.global_position + test_dir).normalized() * map_radius
	
	# Force explicit positions for culling script
	u2.position = u2.global_position
	u1.position = u1.global_position
	
	globe_view.current_longitude = 0
	globe_view.current_latitude = 0
	globe_view._update_camera()
	globe_view.camera.global_position = Vector3(map_radius + 2.0, 0, 0)
	globe_view.camera.look_at(Vector3.ZERO)
	
	# Step process
	globe_view._process(0.1)
	
	# Visibly verified! Red armor inside the bubble can be seen
	assert_true(u2.sprite.visible, "Red Armor must be visible while inside the READY Air strike radius")
	
	# Air unit attacks, disabling readiness
	u1.is_air_ready = false
	globe_view._process(0.1)
	
	# Visibly purged! FOW should occlude it since 30x radius is dropped to standard 0.036
	assert_false(u2.sprite.visible, "Red Armor must vanish into FOW after Air unit goes UNREADY")
