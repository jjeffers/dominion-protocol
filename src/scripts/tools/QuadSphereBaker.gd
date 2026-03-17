extends SceneTree

const RESOLUTION = 361
const RADIUS = 1.0

const TOPOGRAPHY_IMAGE_PATH = "res://src/assets/Topography.jpg"
const LANDMASK_IMAGE_PATH = "res://src/assets/etopo-landmask.png"
const NDVI_IMAGE_PATH = "res://src/assets/NDVI_84.bw.png"
const OUT_MESH_PATH = "res://src/data/quadsphere_globe.res"
const OUT_BIN_PATH = "res://src/data/map_data.bin"

enum Face { FRONT, BACK, LEFT, RIGHT, TOP, BOTTOM }
enum Terrain { OCEAN=0, PLAINS=1, DESERT=2, FOREST=3, MOUNTAINS=4 }

func _get_uuid(face: int, x: int, y: int) -> int:
	return face * (RESOLUTION * RESOLUTION) + y * RESOLUTION + x

func _get_terrain_id(terrain_str: String) -> int:
	match terrain_str:
		"OCEAN": return Terrain.OCEAN
		"PLAINS": return Terrain.PLAINS
		"DESERT": return Terrain.DESERT
		"FOREST": return Terrain.FOREST
		"MOUNTAINS": return Terrain.MOUNTAINS
	return Terrain.OCEAN

func _init() -> void:
	print("Starting Quad-Sphere Baker (R=", RESOLUTION, ")...")
	_bake()
	print("Baking Complete!")
	quit()

func _bake() -> void:
	var img = Image.new()
	var err = img.load(TOPOGRAPHY_IMAGE_PATH)
	if err != OK:
		print("ERROR: Failed to load topography image at: ", TOPOGRAPHY_IMAGE_PATH)
		return
	print("Loaded Topography Image: ", img.get_size())
	
	var mask_img = Image.new()
	var mask_err = mask_img.load(LANDMASK_IMAGE_PATH)
	if mask_err != OK:
		print("ERROR: Failed to load landmask image at: ", LANDMASK_IMAGE_PATH)
		return
	print("Loaded Landmask Image: ", mask_img.get_size())
	
	var ndvi_img = Image.new()
	var ndvi_err = ndvi_img.load(NDVI_IMAGE_PATH)
	if ndvi_err != OK:
		print("ERROR: Failed to load NDVI image at: ", NDVI_IMAGE_PATH)
		return
	print("Loaded NDVI Image: ", ndvi_img.get_size())
	
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = 42
	noise.frequency = 2.0
	
	# Open binary file for writing
	var bin_file = FileAccess.open(OUT_BIN_PATH, FileAccess.WRITE)
	
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	var verts = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()
	var uvs = PackedVector2Array()
	
	var img_w = img.get_width()
	var img_h = img.get_height()
	var vertex_offset = 0
	
	for face in Face.values():
		var face_name = Face.keys()[face]
		print("Baking Face: ", face_name)
		
		for y in range(RESOLUTION):
			for x in range(RESOLUTION):
				# Local Coordinates [-1.0, 1.0] for the CENTER of the tile
				var cx = (float(x + 0.5) / RESOLUTION) * 2.0 - 1.0
				var cy = (float(y + 0.5) / RESOLUTION) * 2.0 - 1.0
				
				# Generate 3D Vector and Spherify
				var centroid = _get_sphere_point(face, cx, cy).normalized() * RADIUS
				
				# Sample Terrain
				var terrain_data = _sample_terrain(centroid, img, img_w, img_h, mask_img, mask_img.get_width(), mask_img.get_height(), ndvi_img, ndvi_img.get_width(), ndvi_img.get_height(), noise)
				var terrain = terrain_data[0]
				var veg = terrain_data[1]
				var tile_color = _get_terrain_debug_color(terrain, veg)
				
				# Build Tile Struct Data
				var t_id = _get_terrain_id(terrain)
				var neighbors = _get_neighbors(face, x, y)
				
				# Write 32-byte struct tightly packed
				bin_file.store_float(centroid.x) # Bytes 0-3
				bin_file.store_float(centroid.y) # Bytes 4-7
				bin_file.store_float(centroid.z) # Bytes 8-11
				bin_file.store_32(neighbors[0])  # Bytes 12-15 (N)
				bin_file.store_32(neighbors[1])  # Bytes 16-19 (E)
				bin_file.store_32(neighbors[2])  # Bytes 20-23 (S)
				bin_file.store_32(neighbors[3])  # Bytes 24-27 (W)
				bin_file.store_8(t_id)           # Byte 28
				bin_file.store_8(0)              # Byte 29 (padding/flags)
				bin_file.store_8(0)              # Byte 30 (padding/flags)
				bin_file.store_8(0)              # Byte 31 (padding/flags)
				
				# Build Mesh Geometry for this tile (A quad = 2 triangles = 4 verts)
				var v00 = _get_sphere_point(face, (float(x) / RESOLUTION) * 2.0 - 1.0, (float(y) / RESOLUTION) * 2.0 - 1.0).normalized() * RADIUS
				var v10 = _get_sphere_point(face, (float(x + 1) / RESOLUTION) * 2.0 - 1.0, (float(y) / RESOLUTION) * 2.0 - 1.0).normalized() * RADIUS
				var v01 = _get_sphere_point(face, (float(x) / RESOLUTION) * 2.0 - 1.0, (float(y + 1) / RESOLUTION) * 2.0 - 1.0).normalized() * RADIUS
				var v11 = _get_sphere_point(face, (float(x + 1) / RESOLUTION) * 2.0 - 1.0, (float(y + 1) / RESOLUTION) * 2.0 - 1.0).normalized() * RADIUS
				
				verts.append(v00)
				verts.append(v10)
				verts.append(v01)
				verts.append(v11)
				
				var n = centroid.normalized()
				normals.append(n); normals.append(n); normals.append(n); normals.append(n)
				colors.append(tile_color); colors.append(tile_color); colors.append(tile_color); colors.append(tile_color)
				
				# Generate UVs and handle anti-meridian seam
				var uv00 = _get_uv(v00)
				var uv10 = _get_uv(v10)
				var uv01 = _get_uv(v01)
				var uv11 = _get_uv(v11)
				var tile_uvs = [uv00, uv10, uv01, uv11]
				
				var min_u = uv00.x
				var max_u = uv00.x
				for t_uv in tile_uvs:
					if t_uv.x < min_u: min_u = t_uv.x
					if t_uv.x > max_u: max_u = t_uv.x
					
				if (max_u - min_u) > 0.5:
					if uv00.x < 0.5: uv00.x += 1.0
					if uv10.x < 0.5: uv10.x += 1.0
					if uv01.x < 0.5: uv01.x += 1.0
					if uv11.x < 0.5: uv11.x += 1.0
					
				uvs.append(uv00)
				uvs.append(uv10)
				uvs.append(uv01)
				uvs.append(uv11)
				
				# Triangle 1: v00 (0), v10 (1), v01 (2) -> 0, 1, 2
				indices.append(vertex_offset + 0)
				indices.append(vertex_offset + 1)
				indices.append(vertex_offset + 2)
				
				# Triangle 2: v10 (1), v11 (3), v01 (2) -> 1, 3, 2
				indices.append(vertex_offset + 1)
				indices.append(vertex_offset + 3)
				indices.append(vertex_offset + 2)
				
				vertex_offset += 4
				
	# Save Mesh
	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_COLOR] = colors
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_INDEX] = indices
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	ResourceSaver.save(mesh, OUT_MESH_PATH)
	print("Saved Quad-Sphere Mesh to: ", OUT_MESH_PATH)
	
	# Close Binary File
	bin_file.close()
	print("Saved Quad Binary Map to: ", OUT_BIN_PATH)

func _get_uv(v: Vector3) -> Vector2:
	var n = v.normalized()
	var lat = asin(n.y)
	var lon = atan2(-n.x, -n.z)
	var u_base = (lon + PI) / (2.0 * PI)
	var v_base = (lat + (PI / 2.0)) / PI
	var v_north = 1.0 - v_base
	return Vector2(u_base, v_north)

func _get_sphere_point(face: int, local_x: float, local_y: float) -> Vector3:
	# Convert 2D face coordinates to 3D cube coordinates
	# We assume Godot's Forward is -Z, Right is +X, Up is +Y
	
	# To make UV sampling intuitive:
	# local_x goes left to right
	# local_y goes top to bottom (so -local_y maps to +Y geometry up)
	
	match face:
		Face.FRONT:  return Vector3(local_x, -local_y, 1.0)
		Face.BACK:   return Vector3(-local_x, -local_y, -1.0)
		Face.LEFT:   return Vector3(-1.0, -local_y, local_x)
		Face.RIGHT:  return Vector3(1.0, -local_y, -local_x)
		Face.TOP:    return Vector3(local_x, 1.0, local_y)
		Face.BOTTOM: return Vector3(local_x, -1.0, -local_y)
		_: return Vector3.ZERO


func _get_neighbors(face: int, x: int, y: int) -> Array[int]:
	# Array matches [N, E, S, W] order
	var neighbors: Array[int] = [0, 0, 0, 0]
	
	# NORTH
	if y > 0: neighbors[0] = _get_uuid(face, x, y - 1)
	else: neighbors[0] = _get_edge_neighbor(face, x, y, "N")
		
	# EAST
	if x < RESOLUTION - 1: neighbors[1] = _get_uuid(face, x + 1, y)
	else: neighbors[1] = _get_edge_neighbor(face, x, y, "E")
	
	# SOUTH
	if y < RESOLUTION - 1: neighbors[2] = _get_uuid(face, x, y + 1)
	else: neighbors[2] = _get_edge_neighbor(face, x, y, "S")
		
	# WEST
	if x > 0: neighbors[3] = _get_uuid(face, x - 1, y)
	else: neighbors[3] = _get_edge_neighbor(face, x, y, "W")

	return neighbors


func _get_edge_neighbor(face: int, x: int, y: int, dir: String) -> int:
	# This handles the complex topology mapping where cube faces meet.
	# It translates coordinates from the current face edge to the adjoining face edge.
	var M = RESOLUTION - 1
	var f_name: int = Face.FRONT
	var nx = 0
	var ny = 0
	
	match face:
		Face.FRONT:
			if dir == "N": f_name = Face.TOP; nx = x; ny = M
			elif dir == "S": f_name = Face.BOTTOM; nx = x; ny = 0
			elif dir == "E": f_name = Face.RIGHT; nx = 0; ny = y
			elif dir == "W": f_name = Face.LEFT; nx = M; ny = y
		Face.BACK:
			if dir == "N": f_name = Face.TOP; nx = M - x; ny = 0
			elif dir == "S": f_name = Face.BOTTOM; nx = M - x; ny = M
			elif dir == "E": f_name = Face.LEFT; nx = 0; ny = y
			elif dir == "W": f_name = Face.RIGHT; nx = M; ny = y
		Face.LEFT:
			if dir == "N": f_name = Face.TOP; nx = 0; ny = x
			elif dir == "S": f_name = Face.BOTTOM; nx = 0; ny = M - x
			elif dir == "E": f_name = Face.FRONT; nx = 0; ny = y
			elif dir == "W": f_name = Face.BACK; nx = M; ny = y
		Face.RIGHT:
			if dir == "N": f_name = Face.TOP; nx = M; ny = M - x
			elif dir == "S": f_name = Face.BOTTOM; nx = M; ny = x
			elif dir == "E": f_name = Face.BACK; nx = 0; ny = y
			elif dir == "W": f_name = Face.FRONT; nx = M; ny = y
		Face.TOP:
			if dir == "N": f_name = Face.BACK; nx = M - x; ny = 0
			elif dir == "S": f_name = Face.FRONT; nx = x; ny = 0
			elif dir == "E": f_name = Face.RIGHT; nx = M - y; ny = 0
			elif dir == "W": f_name = Face.LEFT; nx = y; ny = 0
		Face.BOTTOM:
			if dir == "N": f_name = Face.FRONT; nx = x; ny = M
			elif dir == "S": f_name = Face.BACK; nx = M - x; ny = M
			elif dir == "E": f_name = Face.RIGHT; nx = y; ny = M
			elif dir == "W": f_name = Face.LEFT; nx = M - y; ny = M
			
	return _get_uuid(f_name, nx, ny)


func _sample_terrain(centroid: Vector3, img: Image, img_w: int, img_h: int, mask: Image, mask_w: int, mask_h: int, ndvi: Image, ndvi_w: int, ndvi_h: int, noise: FastNoiseLite) -> Array:
	# Compute Lon/Lat mapping on Sphere
	var lat = asin(centroid.y) 
	var lon = atan2(-centroid.x, -centroid.z) 
	
	# Godot 3D orientation needs a U-flip for standard projection images
	var u_base = (lon + PI) / (2.0 * PI)
	var v_base = (lat + (PI / 2.0)) / PI
	
	# All maps are North-Up
	var v_north = 1.0 - v_base
	
	# Sample Landmask First
	var mask_px = clamp(int(u_base * mask_w), 0, mask_w - 1)
	var mask_py = clamp(int(v_north * mask_h), 0, mask_h - 1)
	var is_land = mask.get_pixel(mask_px, mask_py).v > 0.5
	
	if not is_land:
		return ["OCEAN", 0.0]
	
	# Sample Topography if Land
	var px = clamp(int(u_base * img_w), 0, img_w - 1)
	var py = clamp(int(v_north * img_h), 0, img_h - 1)
	var topo_color = img.get_pixel(px, py)
	var elevation = topo_color.v
	
	if elevation >= 0.75: 
		return ["MOUNTAINS", 0.0]
		
	# Sample Vegetation
	# The NDVI image matches the Topography mapping now.
	var ndvi_px = clamp(int(u_base * ndvi_w), 0, ndvi_w - 1)
	var ndvi_py = clamp(int(v_north * ndvi_h), 0, ndvi_h - 1)
	var veg = ndvi.get_pixel(ndvi_px, ndvi_py).v
	
	if veg < 0.35: 
		if abs(lat) > 1.0: return ["POLAR", veg]
		return ["DESERT", veg]
	if veg < 0.8: return ["PLAINS", veg]
	
	var fuzzy_lat = abs(lat) + noise.get_noise_3dv(centroid) * 0.15
	if fuzzy_lat < 0.4: return ["JUNGLE", veg]
	return ["FOREST", veg]

func _get_terrain_debug_color(terrain: String, veg: float) -> Color:
	match terrain:
		"OCEAN": return Color("1e90ff") # Dodger Blue
		"POLAR": return Color("f0f8ff") # Alice Blue
		"DESERT": return Color(0.902, 0.8, 0.0, 0.5) # Yellow + Alpha 0.5 Shader Tag for black noise
		"PLAINS": 
			var t = clamp((veg - 0.35) / 0.45, 0.0, 1.0)
			return Color("90ee90").lerp(Color("32cd32"), t) # Light green to Lime green gradient
		"FOREST": return Color("228b22") # Forest Green
		"JUNGLE": return Color("006400") # Dark Green
		"MOUNTAINS": return Color("808080") # Gray
		_: return Color.MAGENTA
