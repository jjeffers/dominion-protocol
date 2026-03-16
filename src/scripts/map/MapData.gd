class_name MapData
extends RefCounted

## Represents the Quad-Sphere Dictionary data.

const DATA_PATH = "res://src/data/quad_data.json"
const REGIONS_PATH = "res://src/data/region_data.json"

var _quad_faces: Dictionary = {}
var _region_map: Dictionary = {}

func _init() -> void:
	_load_data()
	
func _load_data() -> void:
	# Load Quadrilateral Grid Metadata
	if not FileAccess.file_exists(DATA_PATH):
		push_error("MapData: Quad-Sphere dictionary not found at ", DATA_PATH)
		return
		
	var file = FileAccess.open(DATA_PATH, FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.new()
	var err = json.parse(content)
	
	if err != OK:
		push_error("MapData: Failed to parse Quad-Sphere JSON!")
		return
		
	_quad_faces = json.get_data()
	print("MapData: Successfully loaded ", _quad_faces.size(), " quad tiles from Dictionary.")

	# Load Regional Territory Ownership Metadata
	if FileAccess.file_exists(REGIONS_PATH):
		var rf = FileAccess.open(REGIONS_PATH, FileAccess.READ)
		var r_json = JSON.new()
		if r_json.parse(rf.get_as_text()) == OK:
			_region_map = r_json.get_data()
			print("MapData: Successfully loaded ", _region_map.size(), " regional claims from Dictionary.")
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

## Returns the dictionary entry for a specific tile ID (e.g. 'FRONT_10_10')
func get_tile(tile_id: String) -> Dictionary:
	if _quad_faces.has(tile_id):
		return _quad_faces[tile_id]
	return {}

## Returns an array of neighboring tile IDs (up to 4)
func get_neighbors(tile_id: String) -> Array[String]:
	var tile = get_tile(tile_id)
	if tile.is_empty():
		return []
	
	var neighbors: Array[String] = []
	var n_dict = tile.get("neighbors", {})
	for dir in n_dict.values():
		neighbors.append(dir)
	return neighbors

## Returns the 3D local centroid of the tile
func get_centroid(tile_id: String) -> Vector3:
	var tile = get_tile(tile_id)
	if tile.is_empty():
		return Vector3.ZERO
	return Vector3(tile.get("world_x", 0), tile.get("world_y", 0), tile.get("world_z", 0))

## Returns the terrain type as a string
func get_terrain(tile_id: String) -> String:
	var tile = get_tile(tile_id)
	if tile.is_empty():
		return "OCEAN"
	return tile.get("terrain", "OCEAN")

## Returns the sovereign Region string
func get_region(tile_id: String) -> String:
	if _region_map.has(tile_id):
		return _region_map[tile_id]
	return ""

## Check if this tile has a port
func has_port(tile_id: String) -> bool:
	var tile = get_tile(tile_id)
	if tile.is_empty():
		return false
	return tile.get("is_port", false)

## Helper to build an ID from face enum and grid x/y
func get_id_from_coords(face: String, x: int, y: int) -> String:
	return "%s_%d_%d" % [face, x, y]
