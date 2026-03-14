class_name GlobeView
extends Node3D

signal focus_changed(longitude: float, latitude: float)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var camera_pivot: Node3D = $CameraPivot

var map_data: MapData

var radius: float = 1.5
var current_longitude: float = 0.0
var current_latitude: float = 0.0

var _is_dragging: bool = false
var _drag_start_pos: Vector2
var _drag_start_lon: float
var _drag_start_lat: float

var outline_mesh_instance: MeshInstance3D
var outline_immediate_mesh: ImmediateMesh

func _ready() -> void:
	if not map_data:
		# Create a dummy map for testing if none provided
		map_data = MapData.new(64, 32)
		map_data.generate_prototype_continents()
		
	_generate_mesh()
	_update_camera()
	
	outline_immediate_mesh = ImmediateMesh.new()
	outline_mesh_instance = MeshInstance3D.new()
	outline_mesh_instance.mesh = outline_immediate_mesh
	
	var outline_mat = StandardMaterial3D.new()
	outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_mat.albedo_color = Color.RED
	outline_mat.no_depth_test = true
	outline_mesh_instance.material_override = outline_mat
	
	add_child(outline_mesh_instance)
	


func _generate_mesh() -> void:
	var segments_w = 120
	var segments_h = 60
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	
	var verts = PackedVector3Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Generate vertices
	for y in range(segments_h + 1):
		# Cylindrical Equal Area: Map rows to sine ranges [-1.0, 1.0]
		var l_sin = clamp(1.0 - 2.0 * (y / float(segments_h)), -1.0, 1.0)
		var lat = asin(l_sin)
		var cos_lat = cos(lat)
		var sin_lat = sin(lat)
		
		for x in range(segments_w + 1):
			var lon = -PI + (2.0 * PI * x / float(segments_w))
			
			var nx = cos_lat * sin(lon)
			var ny = sin_lat
			var nz = cos_lat * cos(lon)
			
			verts.append(Vector3(nx, ny, nz) * radius)
			normals.append(Vector3(nx, ny, nz))
			uvs.append(Vector2(x / float(segments_w), y / float(segments_h)))

	# Generate indices (Quads -> Triangles)
	for y in range(segments_h):
		for x in range(segments_w):
			var i = y * (segments_w + 1) + x
			
			# Triangle 1
			indices.append(i)
			indices.append(i + 1)
			indices.append(i + segments_w + 1)
			
			# Triangle 2
			indices.append(i + 1)
			indices.append(i + segments_w + 2)
			indices.append(i + segments_w + 1)

	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_INDEX] = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	
	mesh_instance.mesh = mesh
	
	# Create material that uses the high resolution map texture
	var mat = StandardMaterial3D.new()
	var img = Image.new()
	img.load("res://src/assets/map_half.png")
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = mat

func _process(delta: float) -> void:
	var lon_delta = 0.0
	var lat_delta = 0.0
	if Input.is_action_pressed("ui_left"): lon_delta = -2.0 * delta
	if Input.is_action_pressed("ui_right"): lon_delta = 2.0 * delta
	if Input.is_action_pressed("ui_up"): lat_delta = 2.0 * delta
	if Input.is_action_pressed("ui_down"): lat_delta = -2.0 * delta
	
	if lon_delta != 0.0 or lat_delta != 0.0:
		current_longitude = wrapf(current_longitude + lon_delta, -PI, PI)
		current_latitude = clampf(current_latitude + lat_delta, -PI/2.1, PI/2.1)
		_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = true
				_drag_start_pos = event.position
				_drag_start_lon = current_longitude
				_drag_start_lat = current_latitude
			else:
				_is_dragging = false
	
	elif event is InputEventMouseMotion and _is_dragging:
		var delta = event.position - _drag_start_pos
		# Sensitivity scaling
		var lon_delta = -delta.x * 0.01
		var lat_delta = delta.y * 0.01
		
		# Update coordinates
		current_longitude = wrapf(_drag_start_lon + lon_delta, -PI, PI)
		# Clamp latitude to avoid flipping over poles
		current_latitude = clampf(_drag_start_lat + lat_delta, -PI/2.1, PI/2.1)
		
		_update_camera()

func _update_camera() -> void:
	# Rotate the pivot to match the current lat/lon focus
	# Use -current_latitude so positive latitude aims Camera at Northern Hemisphere
	camera_pivot.rotation = Vector3(-current_latitude, current_longitude, 0)
	
	focus_changed.emit(current_longitude, current_latitude)

func update_outline(min_lon: float, max_lon: float, min_lat: float, max_lat: float) -> void:
	outline_immediate_mesh.clear_surfaces()
	outline_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	var steps = 16
	var r = radius * 1.01
	
	# Top edge (max_lat), going min_lon to max_lon
	for i in range(steps + 1):
		var lon = lerp(min_lon, max_lon, i / float(steps))
		outline_immediate_mesh.surface_add_vertex(_lat_lon_to_vector3(max_lat, lon, r))
		
	# Right edge (max_lon), going max_lat to min_lat
	for i in range(steps + 1):
		var lat = lerp(max_lat, min_lat, i / float(steps))
		outline_immediate_mesh.surface_add_vertex(_lat_lon_to_vector3(lat, max_lon, r))
		
	# Bottom edge (min_lat), going max_lon to min_lon
	for i in range(steps + 1):
		var lon = lerp(max_lon, min_lon, i / float(steps))
		outline_immediate_mesh.surface_add_vertex(_lat_lon_to_vector3(min_lat, lon, r))
		
	# Left edge (min_lon), going min_lat to max_lat
	for i in range(steps + 1):
		var lat = lerp(min_lat, max_lat, i / float(steps))
		outline_immediate_mesh.surface_add_vertex(_lat_lon_to_vector3(lat, min_lon, r))
		
	outline_immediate_mesh.surface_end()

func _lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var cos_lat = cos(lat)
	var nx = cos_lat * sin(lon)
	var ny = sin(lat)
	var nz = cos_lat * cos(lon)
	return Vector3(nx, ny, nz) * r
## Public function to sync this view from external changes (e.g. 2D map panning)
func set_focus(longitude: float, latitude: float) -> void:
	current_longitude = longitude
	current_latitude = latitude
	_update_camera()

