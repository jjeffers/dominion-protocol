extends SceneTree

var map_data: MapData

func _init() -> void:
	print("--- Injecting Historical Oil Resources ---")
	map_data = MapData.new()
	if map_data._quad_data.is_empty():
		push_error("MapData failed to load quad tiles!")
		quit(1)
		return

	var oil_hubs = [
		{"name": "North Slope", "lat": 70.3, "lon": -150.0},
		{"name": "Siberia", "lat": 65.0, "lon": 70.0},
		{"name": "Volga-Urals 1", "lat": 55.0, "lon": 52.0},
		{"name": "Volga-Urals 2", "lat": 54.0, "lon": 53.0},
		{"name": "Texas / Mid-Con", "lat": 31.8, "lon": -102.3},
		{"name": "Baku / Caucasus", "lat": 40.4, "lon": 50.0},
		{"name": "Gulf of Mexico 1", "lat": 27.0, "lon": -91.0},
		{"name": "Gulf of Mexico 2", "lat": 26.0, "lon": -93.0},
		{"name": "Kuwait Hub", "lat": 29.3, "lon": 47.9},
		{"name": "Iranian Hub", "lat": 31.0, "lon": 50.0},
		{"name": "Saudi Hub", "lat": 25.0, "lon": 49.0},
		{"name": "Libyan Hub", "lat": 29.0, "lon": 19.0},
		{"name": "Oman / UAE", "lat": 23.0, "lon": 56.0},
		{"name": "Indonesia", "lat": -2.0, "lon": 110.0},
		{"name": "Iraq / Basra", "lat": 30.5, "lon": 47.8},
		{"name": "Central Asia", "lat": 46.5, "lon": 52.0},
		{"name": "Venezuela", "lat": 8.5, "lon": -63.0},
		{"name": "Brazil / Pre-Salt", "lat": -24.0, "lon": -43.0},
		{"name": "West Africa", "lat": 5.0, "lon": 6.0}
	]

	var output_arr = []
	var M = 361
	
	for hub in oil_hubs:
		var lat = deg_to_rad(hub["lat"])
		var lon = deg_to_rad(hub["lon"])
		
		var cos_lat = cos(lat)
		var ny = sin(lat)
		var nx = cos_lat * -sin(lon)
		var nz = cos_lat * -cos(lon)
		var pos = Vector3(nx, ny, nz)
		
		var tile_id = _get_tile_from_vector3(pos)
		
		# Snapping to land or shallow water if needed
		# But we assume the coordinates are already roughly correct!
		
		var centroid = map_data.get_centroid(tile_id)
		
		output_arr.append({
			"name": hub["name"],
			"tile": map_data.get_id_from_coords(_get_coords_as_string(tile_id)[0], _get_coords_as_string(tile_id)[1], _get_coords_as_string(tile_id)[2]),
			"tile_uuid": tile_id,
			"position": {
				"x": centroid.x,
				"y": centroid.y,
				"z": centroid.z
			}
		})
		
		print("Generated: ", hub["name"], " at tile: ", _get_coords_as_string(tile_id)[0] + "_" + str(_get_coords_as_string(tile_id)[1]) + "_" + str(_get_coords_as_string(tile_id)[2]))
		
	# Clean up to match original oil_data.json structure
	var clean_output = []
	for data in output_arr:
		var face_str = _get_coords_as_string(data["tile_uuid"])
		var tile_str = face_str[0] + "_" + str(face_str[1]) + "_" + str(face_str[2])
		clean_output.append({
			"tile": tile_str,
			"position": data["position"]
		})

	var out_file = FileAccess.open("res://src/data/oil_data.json", FileAccess.WRITE)
	out_file.store_string(JSON.stringify(clean_output, "\t"))
	out_file.close()

	print("Saved 19 specific oil hubs to src/data/oil_data.json")
	quit(0)

func _get_coords_as_string(tile_id: int) -> Array:
	var coords = map_data.get_coords_from_id(tile_id)
	var face_names = ["FRONT", "BACK", "LEFT", "RIGHT", "TOP", "BOTTOM"]
	return [face_names[coords["face"]], coords["x"], coords["y"]]

func _get_tile_from_vector3(pos: Vector3) -> int:
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

	var M = 361
	var rx = clamp(int(((local_x + 1.0) / 2.0) * M), 0, M - 1)
	var ry = clamp(int(((local_y + 1.0) / 2.0) * M), 0, M - 1)
	var face_names = ["FRONT", "BACK", "LEFT", "RIGHT", "TOP", "BOTTOM"]
	return map_data.get_id_from_coords(face_names[face], rx, ry)
