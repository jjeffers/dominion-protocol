extends Node3D

signal focus_changed(longitude: float, latitude: float)
signal bounds_changed(min_lon: float, max_lon: float, min_lat: float, max_lat: float)

var map_data: MapData

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var current_longitude: float = -1.3788
var current_latitude: float = 0.6196

var _is_dragging: bool = false
var _drag_start_pos: Vector2
var _drag_start_lon: float
var _drag_start_lat: float

func _ready() -> void:
	if not map_data:
		map_data = MapData.new()
		
	_generate_mesh()
	_update_camera()
	
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

func _generate_mesh() -> void:
	var mesh = ResourceLoader.load("res://src/data/quadsphere_globe.res")
	if not mesh:
		push_error("TacticalView: Failed to load Quad-Sphere Mesh!")
		return
		
	mesh_instance.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = mat

func _on_viewport_size_changed() -> void:
	call_deferred("_emit_bounds")

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
		var lon_delta = -delta.x * (camera.size * 0.005)
		var lat_delta = delta.y * (camera.size * 0.005)
		
		current_longitude = wrapf(_drag_start_lon + lon_delta, -PI, PI)
		current_latitude = clampf(_drag_start_lat + lat_delta, -PI/2.1, PI/2.1)
		
		_update_camera()
		focus_changed.emit(current_longitude, current_latitude)

func set_focus(longitude: float, latitude: float) -> void:
	current_longitude = longitude
	current_latitude = latitude
	_update_camera()

func _update_camera() -> void:
	var t = Transform3D.IDENTITY
	t = t.rotated(Vector3.UP, current_longitude)
	t = t.rotated(t.basis.x, -current_latitude)
	camera_pivot.transform = t
	_emit_bounds()

func _emit_bounds() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	if vp_size.x == 0 or vp_size.y == 0:
		return
		
	var h = camera.size
	var w = h * (vp_size.x / vp_size.y)
	
	var r = 1.0
	var half_lat_arc = (h / 2.0) / r
	var half_lon_arc = (w / 2.0) / r
	
	var min_lat = current_latitude - half_lat_arc
	var max_lat = current_latitude + half_lat_arc
	var min_lon = current_longitude - half_lon_arc
	var max_lon = current_longitude + half_lon_arc
	
	bounds_changed.emit(min_lon, max_lon, min_lat, max_lat)

