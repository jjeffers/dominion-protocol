class_name MapData
extends RefCounted

## Represents the Quad-Sphere Dictionary data.

const DATA_PATH = "res://src/data/quad_data.json"

var _quad_faces: Dictionary = {}

func _init() -> void:
	_load_data()

func _load_data() -> void:
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

## Check if this tile has a port
func has_port(tile_id: String) -> bool:
	var tile = get_tile(tile_id)
	if tile.is_empty():
		return false
	return tile.get("is_port", false)

## Helper to build an ID from face enum and grid x/y
func get_id_from_coords(face: String, x: int, y: int) -> String:
	return "%s_%d_%d" % [face, x, y]
