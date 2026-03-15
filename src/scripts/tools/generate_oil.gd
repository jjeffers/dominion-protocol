extends SceneTree

var map_data: MapData

func _init() -> void:
	print("--- Starting Oil Resource Generation ---")
	map_data = MapData.new()
	if map_data._quad_faces.is_empty():
		push_error("MapData failed to load quad tiles!")
		quit(1)
		return
		
	var cities_path = "res://docs/city_data.json"
	if not FileAccess.file_exists(cities_path):
		push_error("Could not find city_data.json!")
		quit(1)
		return
		
	var f = FileAccess.open(cities_path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_error("Failed to parse city_data.json")
		quit(1)
		return
	f.close()
	
	var cities = json.data
	print("Loaded ", cities.size(), " cities.")
	
	var quota = int(cities.size() / 8.0)
	print("Calculated target Oil Quota: ", quota, " (based on 8:1 limit).")
	
	# Phase A: Distance Calculation & Filtering
	var city_tiles = _get_city_tiles(cities)
	print("Reverse-projected ", city_tiles.size(), " unique city tiles.")
	
	var tile_distances = _calculate_distances_from_cities(city_tiles)
	
	var high_priority_pool: Array[String] = []
	var low_priority_pool: Array[String] = []
	
	for tile_id in tile_distances:
		var dist = tile_distances[tile_id]
		if dist >= 12:
			high_priority_pool.append(tile_id)
		else:
			low_priority_pool.append(tile_id)
			
	print("Filtered High Priority Tiles (>11): ", high_priority_pool.size())
	print("Filtered Low Priority Tiles (<12): ", low_priority_pool.size())
	
	if high_priority_pool.is_empty():
		push_error("No high priority tiles available! Distances may be too constrained.")
		quit(1)
		return
		
	# Add Desert Bias by front-loading DESERT terrain over everything else
	var desert_pool: Array[String] = []
	var other_pool: Array[String] = []
	for tile_id in high_priority_pool:
		if map_data.get_terrain(tile_id) == "DESERT":
			desert_pool.append(tile_id)
		else:
			other_pool.append(tile_id)
			
	desert_pool.shuffle()
	other_pool.shuffle()
	high_priority_pool = desert_pool + other_pool
	
	print("Found ", desert_pool.size(), " high priority DESERT tiles to bias.")
		
	var final_oil_tiles: Array[String] = []
	
	# Phase B: Cluster Generation
	# We build 2 clusters of 3 (6 resources).
	
	for cluster_id in range(2):
		if high_priority_pool.is_empty(): break
		
		# 1. Seed Selection
		var lead_tile = high_priority_pool[0]
		final_oil_tiles.append(lead_tile)
		
		# 2. Member Placement
		var cluster_members = _find_cluster_members(lead_tile, 2)
		for member in cluster_members:
			final_oil_tiles.append(member)
			
		# Remove clustered tiles and immediate neighbors from High Priority Pool
		var exclusions = [lead_tile] + cluster_members
		for ex in exclusions:
			high_priority_pool.erase(ex)
			var neighbors = map_data.get_neighbors(ex)
			for n in neighbors:
				high_priority_pool.erase(n)
				
		print("Generated Cluster ", cluster_id + 1, " with ", 1 + cluster_members.size(), " nodes.")
				
	# Phase C: Lone Scattering
	# Scattering remaining quota targets
	var scattered = 0
	
	for tile_id in high_priority_pool:
		if final_oil_tiles.size() >= quota:
			break
			
		# Ensure minimum 15 spacing from any existing oil to prevent bloat
		if _is_safe_distance(tile_id, final_oil_tiles, 15):
			final_oil_tiles.append(tile_id)
			scattered += 1
			
	print("Scattered ", scattered, " lone resources.")
	
	# Fallback if map is too tight (unlikely with 196k tiles, but mathematically possible)
	while final_oil_tiles.size() < quota and not low_priority_pool.is_empty():
		low_priority_pool.shuffle()
		var candidate = low_priority_pool.pop_back()
		if not final_oil_tiles.has(candidate):
			final_oil_tiles.append(candidate)
			print("Fallback: Added Low Priority Tile to meet quota.")
			
	# JSON Export
	var output_arr = []
	for tile_id in final_oil_tiles:
		var centroid = map_data.get_centroid(tile_id)
		output_arr.append({
			"tile": tile_id,
			"position": {
				"x": centroid.x,
				"y": centroid.y,
				"z": centroid.z
			}
		})
		
	var out_file = FileAccess.open("res://src/data/oil_data.json", FileAccess.WRITE)
	out_file.store_string(JSON.stringify(output_arr, "\t"))
	out_file.close()
	
	print("--- Successfully Exported ", final_oil_tiles.size(), " Oil Resources to src/data/oil_data.json ---")
	quit(0)


func _get_city_tiles(cities: Dictionary) -> Array[String]:
	var tiles: Array[String] = []
	var r = 1.0 # Base radius for Quad matching
	for city in cities.values():
		var lat_deg = city.get("latitude")
		var lon_deg = city.get("longitude")
		if lat_deg != null and lon_deg != null:
			var lat = deg_to_rad(lat_deg)
			var lon = deg_to_rad(lon_deg)
			
			# GlobeView/QuadBaker projection math
			var u_base = (lon + PI) / (2.0 * PI)
			var lon_baker = ((1.0 - u_base) * 2.0 * PI) - PI
			var cos_lat = cos(lat)
			var y = sin(lat)
			var x = cos_lat * cos(lon_baker)
			var z = cos_lat * sin(lon_baker)
			
			var v = Vector3(x, y, z)
			var t_id = _get_tile_from_vector3(v)
			if not tiles.has(t_id):
				tiles.append(t_id)
	return tiles

func _calculate_distances_from_cities(city_tiles: Array[String]) -> Dictionary:
	var distances = {}
	var queue = []
	
	for t in city_tiles:
		queue.append({"id": t, "dist": 0})
		distances[t] = 0
		
	var q_idx = 0
	while q_idx < queue.size():
		var current = queue[q_idx]
		q_idx += 1
		
		var t_id = current["id"]
		var d = current["dist"]
		
		# Stop tracking if we hit maximum logical influence width to save computational time over 196k nodes
		if d > 20: 
			continue
			
		var neighbors = map_data.get_neighbors(t_id)
		for n in neighbors:
			if map_data.get_terrain(n) == "OCEAN":
				continue
				
			var nd = d + 1
			if not distances.has(n) or nd < distances[n]:
				distances[n] = nd
				queue.append({"id": n, "dist": nd})
				
	# If a land tile was never reached (dist > 20), we explicitly manually inject it so it isn't skipped during filtering
	for face_id in map_data._quad_faces.keys():
		if map_data.get_terrain(face_id) != "OCEAN" and not distances.has(face_id):
			distances[face_id] = 21 # Safely "> 11" High Priority
			
	return distances

func _find_cluster_members(lead: String, count: int) -> Array[String]:
	var members: Array[String] = []
	var visited = {lead: 0}
	var queue = [{"id": lead, "dist": 0}]
	var candidates = []
	
	var q_idx = 0
	while q_idx < queue.size():
		var current = queue[q_idx]
		q_idx += 1
		
		var t_id = current["id"]
		var d = current["dist"]
		
		if d >= 3 and d <= 5:
			candidates.append(t_id)
			
		if d > 5:
			continue
			
		var neighbors = map_data.get_neighbors(t_id)
		for n in neighbors:
			if map_data.get_terrain(n) != "OCEAN" and not visited.has(n):
				visited[n] = d + 1
				queue.append({"id": n, "dist": d + 1})
				
	candidates.shuffle()
	
	var member_queue = []
	for c in candidates:
		if members.size() >= count:
			break
			
		# Ensure > 1 distance from OTHER members
		var ok = true
		for existing in members:
			var n_list = map_data.get_neighbors(existing)
			if c == existing or n_list.has(c):
				ok = false
				break
				
		if ok:
			members.append(c)
			
	return members

func _is_safe_distance(candidate: String, existing_pool: Array[String], min_dist: int) -> bool:
	var visited = {candidate: 0}
	var queue = [{"id": candidate, "dist": 0}]
	
	var q_idx = 0
	while q_idx < queue.size():
		var current = queue[q_idx]
		q_idx += 1
		
		var t_id = current["id"]
		var d = current["dist"]
		
		if existing_pool.has(t_id):
			return false
			
		if d >= min_dist:
			continue
			
		var neighbors = map_data.get_neighbors(t_id)
		for n in neighbors:
			if not visited.has(n):
				visited[n] = d + 1
				queue.append({"id": n, "dist": d + 1})
				
	return true

func _get_tile_from_vector3(pos: Vector3) -> String:
	# Duplicate of GlobeView math
	var n = pos.normalized()
	var ax = abs(n.x)
	var ay = abs(n.y)
	var az = abs(n.z)
	var face = -1
	var max_axis = max(ax, max(ay, az))
	if max_axis == ax: face = 3 if n.x > 0 else 2
	elif max_axis == ay: face = 4 if n.y > 0 else 5
	else: face = 0 if n.z > 0 else 1
		
	var local_x = 0.0
	var local_y = 0.0
	if face == 0: local_x = n.x / n.z; local_y = -n.y / n.z
	elif face == 1: local_x = -n.x / -n.z; local_y = -n.y / -n.z
	elif face == 2: local_x = n.z / -n.x; local_y = -n.y / -n.x
	elif face == 3: local_x = -n.z / n.x; local_y = -n.y / n.x
	elif face == 4: local_x = n.x / n.y; local_y = n.z / n.y
	elif face == 5: local_x = n.x / -n.y; local_y = -n.z / -n.y

	var M = 181
	var rx = clamp(int(((local_x + 1.0) / 2.0) * M), 0, M - 1)
	var ry = clamp(int(((local_y + 1.0) / 2.0) * M), 0, M - 1)
	var face_names = ["FRONT", "BACK", "LEFT", "RIGHT", "TOP", "BOTTOM"]
	return "%s_%d_%d" % [face_names[face], rx, ry]
