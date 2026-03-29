extends SceneTree

func _init():
	print("--- Starting Oil Region Test ---")
	var map_data = MapData.new()
	var oil_path = "res://src/data/oil_data.json"
	var f = FileAccess.open(oil_path, FileAccess.READ)
	var arr = JSON.new().parse_string(f.get_as_text())
	f.close()
	
	for marker in arr:
		if marker.has("name") and marker["name"] == "Iranian Hub":
			var pos_data = marker["position"]
			var raw_pos = Vector3(pos_data.x, pos_data.y, pos_data.z)
			var tile_id = _get_tile_from_vector3(raw_pos, map_data)
			var reg = map_data.get_region(tile_id)
			print("Iranian Hub -> Tile ID: ", tile_id, " | Region: ", reg)
			
			for t_id in map_data._region_map.keys():
				if map_data._region_map[t_id] == "Iranian Hub":
					print("Iranian Hub region exists in MapData! Example Tile ID: ", t_id)
					break
			break
	quit(0)

func _get_tile_from_vector3(pos: Vector3, map_data: MapData) -> int:
	var n = pos.normalized()
	var ax = abs(n.x)
	var ay = abs(n.y)
	var az = abs(n.z)
	var face = -1
	var max_axis = max(ax, max(ay, az))
	
	if max_axis == ax:
		face = 3 if n.x > 0 else 2
	elif max_axis == ay:
		face = 4 if n.y > 0 else 5
	else:
		face = 0 if n.z > 0 else 1
		
	var local_x = 0.0
	var local_y = 0.0
	
	if face == 0:
		local_x = n.x / n.z
		local_y = -n.y / n.z
	elif face == 1:
		local_x = -n.x / -n.z
		local_y = -n.y / -n.z
	elif face == 2:
		local_x = n.z / -n.x
		local_y = -n.y / -n.x
	elif face == 3:
		local_x = -n.z / n.x
		local_y = -n.y / n.x
	elif face == 4:
		local_x = n.x / n.y
		local_y = n.z / n.y
	elif face == 5:
		local_x = n.x / -n.y
		local_y = -n.z / -n.y

	var M = 361
	var tx = clamp(int(((local_x + 1.0) / 2.0) * M), 0, M - 1)
	var ty = clamp(int(((local_y + 1.0) / 2.0) * M), 0, M - 1)
	
	var face_names = ["FRONT", "BACK", "LEFT", "RIGHT", "TOP", "BOTTOM"]
	return map_data.get_id_from_coords(face_names[face], tx, ty)
