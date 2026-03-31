extends GutTest

var GlobeView = load("res://src/scripts/map/GlobeView.gd")
var globe_view = null

func before_each():
	globe_view = GlobeView.new()
	globe_view.active_scenario = {
		"neutral_cities": ["NeutralCity1"],
		"neutral_oil": ["NeutralOil1", "NeutralOil2"],
		"countries": {
			"TestLand": {
				"cities": ["NeutralCity1"],
				"oil": ["NeutralOil1", "NeutralOil2"],
				"opinions": {}
			}
		},
		"factions": {
			"Red": {
				"cities": ["RedCity"],
				"oil": []
			},
			"Blue": {
				"cities": ["BlueCity"],
				"oil": []
			}
		}
	}
	# Add map data mock so _get_city_faction works properly if it ever accesses it
	add_child_autofree(globe_view)
	
	# Add map data mock so _get_city_faction works properly if it ever accesses it
	add_child_autofree(globe_view)
	
	# Override the Autoload singleton to enable host-only evaluation blocks
	if get_node_or_null("/root/NetworkManager"):
		NetworkManager.is_host = true
	
	# Create multiplayer peer to trigger local RPCs
	var peer = OfflineMultiplayerPeer.new()
	get_tree().get_multiplayer().multiplayer_peer = peer

func after_each():
	if get_node_or_null("/root/NetworkManager"):
		NetworkManager.is_host = false
	get_tree().get_multiplayer().multiplayer_peer = null

func test_already_captured_oil_is_not_flipped():
	# Red captures NeutralOil1 militarily
	globe_view.sync_oil_capture("NeutralOil1", "Red", "neutral")
	
	assert_eq(globe_view._get_city_faction("NeutralOil1"), "Red", "Red should own the oil after military capture")
	
	# Simulate TestLand being invaded by Red, causing drastic opinion drop and leading to an alliance with Blue
	globe_view.sync_diplomatic_penalty("TestLand", "Red", 100.0, "Invasion", true)
	
	# After _evaluate_country_alignment triggers:
	# 1. NeutralOil2 (still neutral) should flip to Blue
	# 2. NeutralOil1 (captured by Red) should REMAIN Red
	assert_eq(globe_view._get_city_faction("NeutralOil2"), "Blue", "Uncaptured oil should flip to the new alliance")
	assert_eq(globe_view._get_city_faction("NeutralOil1"), "Red", "Captured oil MUST NOT flip to the new alliance")
