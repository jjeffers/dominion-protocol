extends GutTest

var GlobeView = load("res://src/scripts/map/GlobeView.gd")
var globe_view = null
var mock_unit = null

func before_each():
	globe_view = GlobeView.new()
	globe_view.active_scenario = {
		"neutral_oil": ["NeutralOil1"],
		"countries": {
			"OilState": {
				"oil": ["NeutralOil1"],
				"opinions": {"Invader": 0.0}
			}
		},
		"factions": {
			"Invader": {
				"cities": ["InvaderCity"],
				"oil": []
			}
		}
	}
	
	add_child_autofree(globe_view)
	
	# Override NetworkManager to allow host-only penalty execution
	if get_node_or_null("/root/NetworkManager"):
		NetworkManager.is_host = true
	var peer = OfflineMultiplayerPeer.new()
	get_tree().get_multiplayer().multiplayer_peer = peer

	# Explicitly assign the exact tile ID for spatial boundary detection
	globe_view.map_data.use_mock_data = true
	globe_view.map_data._build_mock_minimal_data()
	
	var predicted_tile_id = globe_view._get_tile_from_vector3(Vector3(1.0, 0.0, 0.0))
	globe_view.map_data._region_map[predicted_tile_id] = "NeutralOil1"
	# Mock a genuine GlobeUnit for the trespassing loop
	var GlobeUnit = load("res://src/scripts/map/GlobeUnit.gd")
	mock_unit = GlobeUnit.new()
	mock_unit.name = "InvaderTank"
	mock_unit.faction_name = "Invader"
	mock_unit.unit_type = "Armor"
	mock_unit.is_dead = false
	# Position coordinates matching mock tile 0: rx=1.0, ry=0.0, rz=0.0
	mock_unit.position = Vector3(1.0, 0.0, 0.0)
	mock_unit.current_position = Vector3(1.0, 0.0, 0.0)
	
	# _process_diplomacy looks for current_position first
	mock_unit.set_meta("current_position", Vector3(1.0, 0.0, 0.0))
	add_child_autofree(mock_unit)
	
	# Insert into GlobeView's internal tracker
	globe_view.units_list.append(mock_unit)

func after_each():
	if get_node_or_null("/root/NetworkManager"):
		NetworkManager.is_host = false
	get_tree().get_multiplayer().multiplayer_peer = null

func test_process_diplomacy_penalizes_neutral_oil_trespassing():
	# Retrieve initial opinion
	var initial_opinion = globe_view.active_scenario["countries"]["OilState"]["opinions"]["Invader"]
	assert_eq(initial_opinion, 0.0, "Initial diplomatic opinion should be 0.0")
	
	# Manually force the tick that scans unit locations over map topology
	globe_view._process_diplomacy()
	
	# The Invader unit is positioned exactly over 'NeutralOil1'.
	# Evaluating the loop must result in a -1.0 penalty.
	var new_opinion = globe_view.active_scenario["countries"]["OilState"]["opinions"]["Invader"]
	assert_eq(new_opinion, -1.0, "Trespassing over a neutral oil hub must trigger the -1.0 diplomatic decay")
