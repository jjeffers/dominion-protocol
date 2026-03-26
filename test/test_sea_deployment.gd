extends GutTest

var globe_view_scene = preload("res://src/scenes/map/GlobeView.tscn")
var globe_view: GlobeView
var local_id = 1

class MockMapData extends MapData:
	var _terrain_map = {}
	func _load_data():
		pass
	func get_terrain(tile_id: int) -> String:
		if _terrain_map.has(tile_id):
			return _terrain_map[tile_id]
		return "PLAINS"

	
	# Mock network
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(7008)
	multiplayer.multiplayer_peer = peer
	
	NetworkManager.players = {
		local_id: {"name": "TestHost", "faction": "Blue"}
	}
	NetworkManager.is_host = true

	
	multiplayer.multiplayer_peer = null
	if NetworkManager.players.has(local_id):
		NetworkManager.players.erase(local_id)

func before_each():
	globe_view = globe_view_scene.instantiate() as GlobeView
	globe_view.map_data = MockMapData.new()
	add_child_autofree(globe_view)
	
	# Inject Mock Faction and Money
	globe_view.active_scenario = {
		"factions": {
			"Blue": {
				"cities": ["CoastalCity", "LandlockedCity"],
				"money": 100.0
			}
		}
	}
	
	globe_view._update_camera()
	globe_view.camera.global_position = Vector3(globe_view.radius + 2.0, 0, 0)
	globe_view.camera.look_at(Vector3.ZERO)

func test_sea_unit_coastal_deployment():
	var coastal_lat = 10.0
	var coastal_lon = 10.0
	var land_lat = -10.0
	var land_lon = -10.0
	
	globe_view.cached_city_data = {
		"CoastalCity": {
			"latitude": coastal_lat,
			"longitude": coastal_lon
		},
		"LandlockedCity": {
			"latitude": land_lat,
			"longitude": land_lon
		}
	}
	
	var coastal_pos = globe_view._lat_lon_to_vector3(deg_to_rad(coastal_lat), deg_to_rad(coastal_lon), globe_view.radius)
	var coastal_tile = globe_view._get_tile_from_vector3(coastal_pos)
	
	var land_pos = globe_view._lat_lon_to_vector3(deg_to_rad(land_lat), deg_to_rad(land_lon), globe_view.radius)
	var land_tile = globe_view._get_tile_from_vector3(land_pos)
	
	globe_view.map_data._terrain_map[coastal_tile] = "OCEAN"
	globe_view.map_data._terrain_map[land_tile] = "PLAINS"
	
	assert_true(globe_view._city_has_water("CoastalCity"), "CoastalCity should return true for _city_has_water when its base tile is OCEAN")
	assert_false(globe_view._city_has_water("LandlockedCity"), "LandlockedCity should return false for _city_has_water when its base tile is PLAINS")
	
	for sea_unit_type in ["Cruiser", "Submarine"]:
		globe_view.deploying_unit_type = sea_unit_type
		globe_view.deploying_unit_cost = 50.0 if sea_unit_type == "Cruiser" else 35.0
		
		# Coastal City
		var c_name = "CoastalCity"
		var fac_data = globe_view.active_scenario["factions"]["Blue"]
		var has_city = fac_data.has("cities") and fac_data["cities"].has(c_name)
		var has_money = fac_data.get("money", 0.0) >= globe_view.deploying_unit_cost
		var on_cooldown = globe_view.city_cooldowns.has(c_name)
		var is_full = globe_view._is_city_full(c_name)
		var valid_terrain = true
		if globe_view.deploying_unit_type in ["Cruiser", "Submarine"]:
			valid_terrain = globe_view._city_has_water(c_name)
		
		var is_valid_coastal = (has_city and has_money and not on_cooldown and not is_full and valid_terrain)
		assert_true(is_valid_coastal, "CoastalCity must satisfy all terrain and resource requirements for " + sea_unit_type + " deployment")
		
		# Landlocked City
		c_name = "LandlockedCity"
		has_city = fac_data.has("cities") and fac_data["cities"].has(c_name)
		is_full = globe_view._is_city_full(c_name)
		valid_terrain = true
		if globe_view.deploying_unit_type in ["Cruiser", "Submarine"]:
			valid_terrain = globe_view._city_has_water(c_name)
			
		var is_valid_landlocked = (has_city and has_money and not on_cooldown and not is_full and valid_terrain)
		assert_false(is_valid_landlocked, "LandlockedCity must be rejected for " + sea_unit_type + " deployment because valid_terrain resolves to false")

