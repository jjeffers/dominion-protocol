class_name GlobeView
extends Node3D

signal focus_changed(longitude: float, latitude: float)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var camera_pivot: Node3D = $CameraPivot

var map_data: MapData

var radius: float = 1.0
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
		map_data = MapData.new()
		
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
	var mesh = ResourceLoader.load("res://src/data/quadsphere_globe.res")
	if not mesh:
		push_error("GlobeView: Failed to load Quad-Sphere Mesh!")
		return
		
	mesh_instance.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED # Render both sides to avoid backface hollow bowl illusion
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
	var t = Transform3D.IDENTITY
	t = t.rotated(Vector3.UP, current_longitude)
	t = t.rotated(t.basis.x, -current_latitude)
	camera_pivot.transform = t
	
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

