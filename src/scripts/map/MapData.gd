class_name MapData
extends RefCounted

## Represents the Quad-Sphere Binary map data.

const DATA_PATH = "res://src/data/map_data.bin"
const REGIONS_PATH = "res://src/data/region_data.json"

const TILE_STRUCT_SIZE = 32
const RESOLUTION = 361

enum Terrain { OCEAN=0, PLAINS=1, DESERT=2, FOREST=3, MOUNTAINS=4 }

var _quad_data: PackedByteArray
var _region_map: Dictionary = {}

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

	# Load Regional Territory Ownership Metadata
	if FileAccess.file_exists(REGIONS_PATH):
		var rf = FileAccess.open(REGIONS_PATH, FileAccess.READ)
		var r_json = JSON.new()
		if r_json.parse(rf.get_as_text()) == OK:
			var string_regions = r_json.get_data()
			# Convert string keys like "FRONT_0_0" to UUID integers for faster lookups later
			for key in string_regions:
				_region_map[get_uuid_from_string(key)] = string_regions[key]
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
	return "OCEAN"

## Returns the sovereign Region string
func get_region(tile_id: int) -> String:
	if _region_map.has(tile_id):
		return _region_map[tile_id]
	return ""

## Check if this tile has a port
func has_port(tile_id: int) -> bool:
	# Flags will be implemented later, assuming false for now
	return false
