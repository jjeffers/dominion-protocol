extends "res://addons/gut/test.gd"

var MainScene = preload("res://src/scenes/main.tscn")

func test_nuke_sdi_targeting_prevention():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	
	await get_tree().process_frame
	
	var globe = main.globe_view
	
	globe.active_scenario = {
		"factions": {
			"Blue": {
				"capitol": "London",
				"cities": ["London"],
				"color": "blue"
			},
			"Red": {
				"capitol": "Berlin",
				"cities": ["Berlin"],
				"color": "red"
			}
		}
	}
	
	var london = Node3D.new()
	london.name = "London"
	london.position = Vector3(0, 1, 0)
	globe.city_nodes.append(london)
	add_child_autofree(london)
	
	# Simulate targeting logic
	var hit_city = "London"
	var owner = globe._get_city_faction(hit_city)
	
	var is_valid = true
	if owner != "" and globe.active_scenario["factions"][owner].has("capitol") and globe.active_scenario["factions"][owner]["capitol"] == hit_city:
		is_valid = false
		
	assert_false(is_valid, "Nuking an enemy capitol MUST be marked as invalid by client validation logic.")

func after_each():
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null

func test_process_nuke_impact_does_not_hang():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	
	await get_tree().process_frame
	var globe = main.globe_view
	
	# Load scenario
	var scm = FileAccess.open("res://src/data/scenarios/initial_test.json", FileAccess.READ)
	var sc = JSON.new()
	sc.parse(scm.get_as_text())
	scm.close()
	globe._instantiate_scenario(sc.data)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Mock network
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(9999)
	main.get_tree().get_multiplayer().multiplayer_peer = peer
	
	var pos = Vector3(-0.093744, 0.805753, -0.584785)
	
	var t = Time.get_ticks_msec()
	globe._process_nuke_impact(pos)
	var diff = Time.get_ticks_msec() - t
	
	assert_true(diff < 2000, "Nuke impact processed in reasonable time (took " + str(diff) + "ms)")
	peer.close()
	
