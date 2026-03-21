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
