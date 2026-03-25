class_name MapData
extends RefCounted

## Represents the Quad-Sphere Binary map data.

const DATA_PATH = "res://src/data/map_data.bin"
const REGIONS_PATH = "res://src/data/region_data.json"

const TILE_STRUCT_SIZE = 32
const RESOLUTION = 361

enum Terrain { OCEAN=0, PLAINS=1, DESERT=2, FOREST=3, MOUNTAINS=4, JUNGLE=5, WASTELAND=6, RUINS=7 }

var _quad_data: PackedByteArray
var _region_map: Dictionary = {}
var _terrain_overrides: Dictionary = {}

var land_astar: AStar3D
var naval_astar: AStar3D

static var use_mock_data: bool = false

func _init() -> void:
	_load_data()
	
func _load_data() -> void:
	if use_mock_data:
		return
		
	if not FileAccess.file_exists(DATA_PATH):
		push_error("MapData: Quad-Sphere binary map not found at ", DATA_PATH)
		return
		
	var file = FileAccess.open(DATA_PATH, FileAccess.READ)
	_quad_data = file.get_buffer(file.get_length())
	file.close()
	
	print("MapData: Successfully loaded ", _quad_data.size() / TILE_STRUCT_SIZE, " quad tiles from Binary buffer.")

	_build_pathfinding_graphs()

	# Load Regional Territory Ownership Metadata
	if FileAccess.file_exists(REGIONS_PATH):
		var rf = FileAccess.open(REGIONS_PATH, FileAccess.READ)
		var r_json = JSON.new()
		if r_json.parse(rf.get_as_text()) == OK:
			var string_regions = r_json.get_data()
			# Convert string numeric keys directly to integers
			for key in string_regions:
				if key.contains("_"):
					_region_map[get_uuid_from_string(key)] = string_regions[key]
				else:
					_region_map[key.to_int()] = string_regions[key]
			print("MapData: Successfully loaded ", _region_map.size(), " regional claims.")
		else:
			push_error("MapData: Failed to parse Regions JSON!")

## Purges all regions that are not present in the given active list
func cull_regions(active_regions: Array[String]) -> void:
	var keys = _region_map.keys()
	var culled = 0
	for tile_id in keys:
		if not active_regions.has(_region_map[tile_id]):
			_region_map.erase(tile_id)
			culled += 1
	print("MapData: Culled ", culled, " unused region tiles based on scenario configuration.")

## Helper to build an ID from face enum and grid x/y
func get_id_from_coords(face: String, x: int, y: int) -> int:
	var face_idx = 0
	match face:
		"FRONT": face_idx = 0
		"BACK": face_idx = 1
		"LEFT": face_idx = 2
		"RIGHT": face_idx = 3
		"TOP": face_idx = 4
		"BOTTOM": face_idx = 5
	return face_idx * (RESOLUTION * RESOLUTION) + y * RESOLUTION + x

## Returns a Dictionary with "face", "x", and "y" from a UUID
func get_coords_from_id(id: int) -> Dictionary:
	var remainder = id % (RESOLUTION * RESOLUTION)
	return {
		"face": id / (RESOLUTION * RESOLUTION),
		"y": remainder / RESOLUTION,
		"x": remainder % RESOLUTION
	}

func get_uuid_from_string(id_str: String) -> int:
	var parts = id_str.split("_")
	if parts.size() != 3: return 0
	return get_id_from_coords(parts[0], parts[1].to_int(), parts[2].to_int())

## Returns an array of neighboring tile UUIDs [N, E, S, W]
func get_neighbors(tile_id: int) -> Array[int]:
	if tile_id < 0 or tile_id * TILE_STRUCT_SIZE >= _quad_data.size():
		return []
		
	var offset = tile_id * TILE_STRUCT_SIZE
	var n0 = _quad_data.decode_u32(offset + 12)
	var n1 = _quad_data.decode_u32(offset + 16)
	var n2 = _quad_data.decode_u32(offset + 20)
	var n3 = _quad_data.decode_u32(offset + 24)
	return [n0, n1, n2, n3]

## Returns the 3D local centroid of the tile
func get_centroid(tile_id: int) -> Vector3:
	if tile_id < 0 or tile_id * TILE_STRUCT_SIZE >= _quad_data.size():
		return Vector3.ZERO
		
	var offset = tile_id * TILE_STRUCT_SIZE
	var x = _quad_data.decode_float(offset)
	var y = _quad_data.decode_float(offset + 4)
	var z = _quad_data.decode_float(offset + 8)
	return Vector3(x, y, z)

## Returns the terrain type as a string
func get_terrain(tile_id: int) -> String:
	if _terrain_overrides.has(tile_id):
		return _terrain_overrides[tile_id]
		
	if tile_id < 0 or tile_id * TILE_STRUCT_SIZE >= _quad_data.size():
		return "OCEAN"
		
	var offset = tile_id * TILE_STRUCT_SIZE
	var t_id = _quad_data.decode_u8(offset + 28)
	
	match t_id:
		Terrain.OCEAN: return "OCEAN"
		Terrain.PLAINS: return "PLAINS"
		Terrain.DESERT: return "DESERT"
		Terrain.FOREST: return "FOREST"
		Terrain.MOUNTAINS: return "MOUNTAINS"
		Terrain.JUNGLE: return "JUNGLE"
		Terrain.WASTELAND: return "WASTELAND"
		Terrain.RUINS: return "RUINS"
	return "OCEAN"

## Sets a runtime terrain override for a specific tile
func set_terrain(tile_id: int, new_terrain: String) -> void:
	_terrain_overrides[tile_id] = new_terrain

## Returns the sovereign Region string
func get_region(tile_id: int) -> String:
	if _region_map.has(tile_id):
		return _region_map[tile_id]
	return ""

## Check if this tile has a port
func has_port(tile_id: int) -> bool:
	# Flags will be implemented later, assuming false for now
	return false

func _build_pathfinding_graphs() -> void:
	land_astar = AStar3D.new()
	naval_astar = AStar3D.new()
	
	var total_tiles = _quad_data.size() / TILE_STRUCT_SIZE
	
	# Pass 1: Add Points
	for i in range(total_tiles):
		var pos = get_centroid(i)
		var terrain = get_terrain(i)
		
		# Naval AStar includes OCEAN
		if terrain == "OCEAN" or terrain == "LAKE":
			naval_astar.add_point(i, pos)
		else:
			land_astar.add_point(i, pos)
			var weight = 1.0
			match terrain:
				"FOREST", "JUNGLE": weight = 2.0
				"MOUNTAINS", "RUINS": weight = 3.0
				"WASTELAND": weight = 4.0
			land_astar.set_point_weight_scale(i, weight)

	# Pass 2: Connect Edges
	for i in range(total_tiles):
		var terrain = get_terrain(i)
		var is_ocean = (terrain == "OCEAN" or terrain == "LAKE")
		var neighbors = get_neighbors(i)
		
		for n in neighbors:
			if n <= i: continue # Avoid double connecting
			
			var n_terrain = get_terrain(n)
			var n_is_ocean = (n_terrain == "OCEAN" or n_terrain == "LAKE")
			
			if is_ocean and n_is_ocean:
				naval_astar.connect_points(i, n, true)
			elif not is_ocean and not n_is_ocean:
				land_astar.connect_points(i, n, true)
	
	print("MapData: Built AStar3D pathfinding graphs for ", total_tiles, " tiles.")

func find_path(start_pos: Vector3, end_pos: Vector3, unit_type: String) -> Array[Vector3]:
	var u_type = unit_type.capitalize()
	if u_type == "Air":
		return [] # Air uses direct pathing naturally handled by caller
		
	var astar: AStar3D
	if u_type in ["Cruiser", "Submarine"]:
		astar = naval_astar
	else:
		astar = land_astar
		
	var start_id = astar.get_closest_point(start_pos)
	var end_id = astar.get_closest_point(end_pos)
	
	if start_id == -1 or end_id == -1:
		return []
		
	var path_ids = astar.get_id_path(start_id, end_id)
	var path: Array[Vector3] = []
	for id in path_ids:
		path.append(astar.get_point_position(id))
		
	if path.size() > 1:
		path.pop_front()
		
	if path.size() > 0:
		path[path.size() - 1] = end_pos # Enforce literal final click position
	
	return path
