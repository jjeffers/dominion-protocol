extends SceneTree

const RESOLUTION = 128
const RADIUS = 1.0

func _init() -> void:
	print("Baking Test...")
	
	var img = Image.new()
	img.load("/home/jdjeffers/Documents/uv_test.png")
	var w = img.get_width()
	var h = img.get_height()
	
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	var verts = PackedVector3Array()
	var indices = PackedInt32Array()
	var colors = PackedColorArray()
	var vertex_offset = 0
	
	for face in range(6):
		for y in range(RESOLUTION):
			for x in range(RESOLUTION):
				var cx = (float(x + 0.5) / RESOLUTION) * 2.0 - 1.0
				var cy = (float(y + 0.5) / RESOLUTION) * 2.0 - 1.0
				
				var centroid = _get_sphere_point(face, cx, cy).normalized() * RADIUS
				var lat = asin(centroid.y) 
				var lon = atan2(centroid.z, centroid.x) 
				
				var u = (lon + PI) / (2.0 * PI)
				var v = (lat + (PI / 2.0)) / PI
				
				# DO NOT FLIP ANY AXIS HERE!
				
				var px = clamp(int(u * w), 0, w - 1)
				var py = clamp(int(v * h), 0, h - 1)
				var tile_color = img.get_pixel(px, py)
				
				# Build quad
				var p1 = _get_sphere_point(face, (float(x) / RESOLUTION) * 2.0 - 1.0, (float(y) / RESOLUTION) * 2.0 - 1.0).normalized() * RADIUS
				var p2 = _get_sphere_point(face, (float(x + 1) / RESOLUTION) * 2.0 - 1.0, (float(y) / RESOLUTION) * 2.0 - 1.0).normalized() * RADIUS
				var p3 = _get_sphere_point(face, (float(x) / RESOLUTION) * 2.0 - 1.0, (float(y + 1) / RESOLUTION) * 2.0 - 1.0).normalized() * RADIUS
				var p4 = _get_sphere_point(face, (float(x + 1) / RESOLUTION) * 2.0 - 1.0, (float(y + 1) / RESOLUTION) * 2.0 - 1.0).normalized() * RADIUS
				
				verts.append(p1); verts.append(p2); verts.append(p3); verts.append(p4)
				colors.append(tile_color); colors.append(tile_color); colors.append(tile_color); colors.append(tile_color)
				
				indices.append(vertex_offset + 0)
				indices.append(vertex_offset + 1)
				indices.append(vertex_offset + 2)
				indices.append(vertex_offset + 1)
				indices.append(vertex_offset + 3)
				indices.append(vertex_offset + 2)
				vertex_offset += 4

	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_COLOR] = colors
	surface_array[Mesh.ARRAY_INDEX] = indices
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	ResourceSaver.save(mesh, "/home/jdjeffers/.gemini/antigravity/playground/glowing-prominence/src/data/uv_test.res")
	print("Saved to src/data/uv_test.res")
	quit()

func _get_sphere_point(face: int, local_x: float, local_y: float) -> Vector3:
	match face:
		0: return Vector3(local_x, -local_y, 1.0)
		1: return Vector3(-local_x, -local_y, -1.0)
		2: return Vector3(-1.0, -local_y, local_x)
		3: return Vector3(1.0, -local_y, -local_x)
		4: return Vector3(local_x, 1.0, local_y)
		5: return Vector3(local_x, -1.0, -local_y)
		_: return Vector3.ZERO
