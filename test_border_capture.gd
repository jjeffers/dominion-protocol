extends SceneTree

func _init():
	var map_data = MapData.new()
	print("MapData loaded. Total tiles: ", map_data._region_map.size())
	
	var active_scenario = {}
	var path = "res://src/data/scenarios/initial_test.json"
	var rf = FileAccess.open(path, FileAccess.READ)
	if rf:
		var jp = JSON.new()
		jp.parse(rf.get_as_text())
		active_scenario = jp.data
	else:
		print("Failed to load scenario")
		quit()
		
	var active_regions: Array[String] = []
	for faction in active_scenario["factions"].values():
		if faction.has("cities"):
			for c in faction["cities"]:
				active_regions.append(c)
	map_data.cull_regions(active_regions)
	
	var edge_counts = _test_get_edges(map_data, active_scenario)
	print("Initial edges: ", edge_counts)
	
	# Capture Amsterdam to Red
	active_scenario["factions"]["Blue"]["cities"].erase("Amsterdam")
	active_scenario["factions"]["Red"]["cities"].append("Amsterdam")
	print("Blue cities after erase: ", active_scenario["factions"]["Blue"]["cities"])
	print("Red cities after append: ", active_scenario["factions"]["Red"]["cities"])
	
	var edge_counts2 = _test_get_edges(map_data, active_scenario)
	print("Edges after capture: ", edge_counts2)
	quit()

func _test_get_edges(map_data, active_scenario) -> Dictionary:
	var drawn_edges = {}
	var edges_by_faction = {}
	
	for tile_id in map_data._region_map.keys():
		var owner_city = map_data._region_map[tile_id]
		var owning_faction = ""
		for f_name in active_scenario["factions"]:
			var f_data = active_scenario["factions"][f_name]
			if f_data.has("cities") and owner_city in f_data["cities"]:
				owning_faction = f_name
				break
				
		if owning_faction == "":
			continue
			
		var neighbors = map_data.get_neighbors(tile_id)
		for n_id in neighbors:
			var n_owner = map_data.get_region(n_id)
			var n_faction = ""
			if n_owner != "":
				for f_name in active_scenario["factions"]:
					if active_scenario["factions"][f_name].has("cities") and n_owner in active_scenario["factions"][f_name]["cities"]:
						n_faction = f_name
						break
						
			if n_faction != owning_faction:
				var n_terrain = map_data.get_terrain(n_id).to_lower()
				if n_terrain == "ocean" or n_terrain == "lake":
					continue
					
				var key1 = "%d_%d" % [tile_id, n_id]
				var key2 = "%d_%d" % [n_id, tile_id]
				
				if not drawn_edges.has(key1) and not drawn_edges.has(key2):
					drawn_edges[key1] = true
					drawn_edges[key2] = true
					
					if not edges_by_faction.has(owning_faction):
						edges_by_faction[owning_faction] = 0
					edges_by_faction[owning_faction] += 1
					
	return edges_by_faction
