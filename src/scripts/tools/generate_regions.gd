extends SceneTree

class PQItem:
	var cost: float
	var id: int
	var origin: String
	func _init(c: float, i: int, o: String):
		cost = c
		id = i
		origin = o

class MinHeap:
	var _data: Array = []
	
	func push(item: PQItem):
		_data.append(item)
		_sift_up(_data.size() - 1)
		
	func pop() -> PQItem:
		if _data.is_empty(): return null
		var result = _data[0]
		var last = _data.pop_back()
		if not _data.is_empty():
			_data[0] = last
			_sift_down(0)
		return result
		
	func is_empty() -> bool:
		return _data.is_empty()
		
	func _sift_up(idx: int):
		while idx > 0:
			var parent = (idx - 1) / 2
			if _data[idx].cost >= _data[parent].cost:
				break
			var temp = _data[idx]
			_data[idx] = _data[parent]
			_data[parent] = temp
			idx = parent
			
	func _sift_down(idx: int):
		var size = _data.size()
		while true:
			var left = 2 * idx + 1
			var right = 2 * idx + 2
			var smallest = idx
			
			if left < size and _data[left].cost < _data[smallest].cost:
				smallest = left
			if right < size and _data[right].cost < _data[smallest].cost:
				smallest = right
				
			if smallest == idx:
				break
				
			var temp = _data[idx]
			_data[idx] = _data[smallest]
			_data[smallest] = temp
			idx = smallest

enum Face { FRONT, BACK, LEFT, RIGHT, TOP, BOTTOM }

const RESOLUTION = 361
const RADIUS = 1.002

var map_data: MapData

func _init() -> void:
	print("--- Starting Regional Partition Generation ---")
	map_data = MapData.new()
	if map_data._quad_data.is_empty():
		push_error("MapData failed to load quad tiles!")
		quit(1)
		return
		
	var cities_path = "res://src/data/city_data.json"
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
	print("Loaded ", cities.size(), " cities as region seeds.")
	
	var cost_map = {}
	var region_map = {}
	var pq = MinHeap.new()
	
	# Seed Priority Queue
	for city_name in cities:
		var lat = cities[city_name]["latitude"]
		var lon = cities[city_name]["longitude"]
		var raw_pos = _lat_lon_to_vector3(deg_to_rad(lat), deg_to_rad(lon), 1.02)
		var tile_id = _get_tile_from_vector3(raw_pos)
		
		cost_map[tile_id] = 0.0
		region_map[tile_id] = city_name
		pq.push(PQItem.new(0.0, tile_id, city_name))
		
	print("Starting Dijkstra Flood-Fill...")
	
	var processed_count = 0
	while not pq.is_empty():
		var current = pq.pop()
		
		# Skip if we already found a better path
		if current.cost > cost_map[current.id]:
			continue
			
		processed_count += 1
		var neighbors = map_data.get_neighbors(current.id)
		
		for n_id in neighbors:
			var terrain = map_data.get_terrain(n_id)
			if terrain == "OCEAN":
				continue
				
			var res = 1.0
			if terrain == "WOODS": res = 2.5
			elif terrain == "DESERT": res = 10.0
			elif terrain == "MOUNTAIN": res = 15.0
			
			var new_cost = current.cost + res
			
			if not cost_map.has(n_id) or new_cost < cost_map[n_id]:
				cost_map[n_id] = new_cost
				region_map[n_id] = current.origin
				pq.push(PQItem.new(new_cost, n_id, current.origin))
				
	print("Flood-Fill Complete! Assigned ", region_map.size(), " land tiles to regions.")
	
	# Export Regions Data
	var out_path = "res://src/data/region_data.json"
	var out_f = FileAccess.open(out_path, FileAccess.WRITE)
	out_f.store_string(JSON.stringify(region_map, "\t"))
	out_f.close()
	print("Saved Region Mapping to: ", out_path)
	
	print("Generating 3D Border Boundary Lines...")
	var verts = PackedVector3Array()
	var drawn_edges = {}
	
	var processed_edges = 0
	for tile_id in region_map:
		var origin_region = region_map[tile_id]
		var neighbors = map_data.get_neighbors(tile_id)
		
		# Find boundaries
		for n_id in neighbors:
			if not region_map.has(n_id) or region_map[n_id] != origin_region:
				# It is a border (either meets ocean or meets another region)
				# But let's only draw borders between differing LAND regions, or maybe land-ocean too?
				# The plan states: "If their region_owner differs, that edge represents an international boundary."
				# Usually we only want lines between regions, not coastlines. Coastlines are implied.
				if region_map.has(n_id) and region_map[n_id] != origin_region:
					var c1_list = _get_global_corners(tile_id)
					var c2_list = _get_global_corners(n_id)
					var shared_verts: Array[Vector3] = []
					
					for c1 in c1_list:
						for c2 in c2_list:
							if c1.distance_to(c2) < 0.001:
								shared_verts.append(c1)
								break
								
					if shared_verts.size() == 2:
						var key1 = "%.4f,%.4f,%.4f_%.4f,%.4f,%.4f" % [shared_verts[0].x, shared_verts[0].y, shared_verts[0].z, shared_verts[1].x, shared_verts[1].y, shared_verts[1].z]
						var key2 = "%.4f,%.4f,%.4f_%.4f,%.4f,%.4f" % [shared_verts[1].x, shared_verts[1].y, shared_verts[1].z, shared_verts[0].x, shared_verts[0].y, shared_verts[0].z]
						if not drawn_edges.has(key1) and not drawn_edges.has(key2):
							drawn_edges[key1] = true
							verts.append(shared_verts[0])
							verts.append(shared_verts[1])
							processed_edges += 1
							
	print("Found ", processed_edges, " boundary line segments. Generating Mesh...")
	
	if verts.size() > 0:
		var surface_array = []
		surface_array.resize(Mesh.ARRAY_MAX)
		surface_array[Mesh.ARRAY_VERTEX] = verts
		
		var mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, surface_array)
		
		var mesh_path = "res://src/data/region_borders.res"
		ResourceSaver.save(mesh, mesh_path)
		print("Saved Border Line Mesh to: ", mesh_path)
	else:
		print("WARNING: No boundaries found! Is the map populated?")
		
	print("Generation Complete.")
	quit(0)

# --- MAP MATH FOR REVERSE PROJECTION & CORNER CALCULATION ---

func _lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var cos_lat = cos(lat)
	var ny = sin(lat)
	var nx = cos_lat * -sin(lon)
	var nz = cos_lat * -cos(lon)
	return Vector3(nx, ny, nz) * r

func _get_tile_from_vector3(pos: Vector3) -> int:
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

	var M = RESOLUTION
	var tx = clamp(int(((local_x + 1.0) / 2.0) * M), 0, M - 1)
	var ty = clamp(int(((local_y + 1.0) / 2.0) * M), 0, M - 1)
	
	var face_names = ["FRONT", "BACK", "LEFT", "RIGHT", "TOP", "BOTTOM"]
	return map_data.get_id_from_coords(face_names[face], tx, ty)

func _get_global_corners(tile_id: int) -> Array[Vector3]:
	var coords = map_data.get_coords_from_id(tile_id)
	var face = coords["face"]
	var x = coords["x"]
	var y = coords["y"]
	
	var cx1 = (float(x) / RESOLUTION) * 2.0 - 1.0
	var cx2 = (float(x + 1) / RESOLUTION) * 2.0 - 1.0
	var cy1 = (float(y) / RESOLUTION) * 2.0 - 1.0
	var cy2 = (float(y + 1) / RESOLUTION) * 2.0 - 1.0
	
	var corners2d = [
	   Vector2(cx1, cy1),
	   Vector2(cx2, cy1),
	   Vector2(cx2, cy2),
	   Vector2(cx1, cy2)
	]
	
	var corners3d: Array[Vector3] = []
	for c in corners2d:
		var p = _get_sphere_point(face, c.x, c.y).normalized() * RADIUS
		corners3d.append(p)
		
	return corners3d

func _get_sphere_point(face: int, local_x: float, local_y: float) -> Vector3:
	match face:
		Face.FRONT:  return Vector3(local_x, -local_y, 1.0)
		Face.BACK:   return Vector3(-local_x, -local_y, -1.0)
		Face.LEFT:   return Vector3(-1.0, -local_y, local_x)
		Face.RIGHT:  return Vector3(1.0, -local_y, -local_x)
		Face.TOP:    return Vector3(local_x, 1.0, local_y)
		Face.BOTTOM: return Vector3(local_x, -1.0, -local_y)
		_: return Vector3.ZERO
