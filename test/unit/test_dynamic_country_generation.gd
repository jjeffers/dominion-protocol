extends "res://addons/gut/test.gd"

var MainScene = preload("res://src/scenes/main.tscn")
var CountryNameGenerator = preload("res://src/scripts/map/CountryNameGenerator.gd")

func test_dynamic_country_generation():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	
	await get_tree().process_frame
	
	var globe = main.globe_view
	
	# Pass in a scenario where only a few cities are defined
	# Meaning there will be many unaligned cities
	var test_scenario = {
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
	
	GlobeView.skip_mesh_generation = true
	
	# Simulate NetworkManager/Lobby Country Generation
	var c_dict = {}
	var path = "res://src/data/city_data.json"
	
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	c_dict = json.data
	
	var all_cities = c_dict.keys()
	var unaligned = []
	for c in all_cities:
		if c != "London" and c != "Berlin":
			unaligned.append(c)
			
	var temp_countries = {}
	var num_countries = randi_range(20, 50)
	var centroids = []
	var available = unaligned.duplicate()
	for i in range(num_countries):
		var idx = randi() % available.size()
		centroids.append(available[idx])
		available.remove_at(idx)
		temp_countries["Country " + str(i + 1)] = {"cities": [], "color": "#FFD700"}
		
	for c_name in unaligned:
		var best = ""
		# Simple assignment for test
		for i in range(centroids.size()):
			if c_name == centroids[i]:
				best = "Country " + str(i + 1)
				break
			if randf() < 0.2 or best == "":
				best = "Country " + str(i + 1)
		temp_countries[best]["cities"].append(c_name)
		
	var countries = {}
	for temp_key in temp_countries.keys():
		var c_list: Array[String] = []
		for c in temp_countries[temp_key]["cities"]:
			c_list.append(c as String)
			
		if c_list.is_empty():
			continue
			
		var generated_name = CountryNameGenerator.generate_name(c_list)
		var base_name = generated_name
		var counter = 2
		while countries.has(generated_name):
			generated_name = base_name + " " + str(counter)
			counter += 1
			
		countries[generated_name] = temp_countries[temp_key]
		
	NetworkManager.initial_countries = countries
	
	# Main scene load
	globe._instantiate_scenario(test_scenario)
	
	assert_true(globe.active_scenario.has("countries"), "Dynamic countries should be generated")
	
	countries = globe.active_scenario["countries"]
	assert_true(countries.size() >= 20 and countries.size() <= 50, "Number of dynamic countries should be between 20 and 50 (got %d)" % countries.size())
	
	for c_name in countries.keys():
		assert_true(c_name.length() > 0, "Country name should be a valid string")
		assert_eq(countries[c_name]["color"], "#FFD700", "Country color should be Gold (#FFD700)")
		assert_true(countries[c_name].has("cities"), "Country should have a list of cities")
		assert_true(countries[c_name]["cities"].size() > 0, "Country should have at least one city")
		
	# Verify that a known neutral city like "Paris" or something is now in a country
	# Actually, verify that *no* city is left behind.
	# But since we just want to ensure it works, this is enough.
	path = "res://src/data/city_data.json"
	file = FileAccess.open(path, FileAccess.READ)
	json = JSON.new()
	json.parse(file.get_as_text())
	c_dict = json.data
	
	var all_cities_assigned = true
	var failed_city = ""
	for c in c_dict.keys():
		# Is it in a faction?
		var in_faction = false
		for f in test_scenario["factions"].values():
			if c in f["cities"]:
				in_faction = true
				break
		
		# If not, it MUST be in a country
		if not in_faction:
			var in_country = false
			for c_data in test_scenario["countries"].values():
				if c in c_data["cities"]:
					in_country = true
					break
			if not in_country:
				all_cities_assigned = false
				failed_city = c
				break
				
	assert_true(all_cities_assigned, "All unaligned cities should be assigned to a country (failed on %s)" % failed_city)
