class_name GlobeView
extends Node3D

signal focus_changed(longitude: float, latitude: float)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var map_data: MapData

var radius: float = 1.0
var current_longitude: float = 0.192
var current_latitude: float = 0.6196

var target_zoom: float = 3.0
var min_zoom: float = 1.5
var max_zoom: float = 4.5

var _is_dragging: bool = false
var _drag_start_pos: Vector2
var _drag_start_lon: float
var _drag_start_lat: float
const GlobeUnitScript = preload("res://src/scripts/map/GlobeUnit.gd")

var outline_mesh_instance: MeshInstance3D
var outline_immediate_mesh: ImmediateMesh

var test_unit: Node3D
var target_bracket: Sprite3D
var map_collider: StaticBody3D

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
	
	# Add physics collider matching the exact globe surface
	map_collider = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = radius 
	collision_shape.shape = sphere_shape
	map_collider.add_child(collision_shape)
	add_child(map_collider)
	
	_load_cities()
	
	# Instantiate targeting bracket
	target_bracket = Sprite3D.new()
	# Draw bracket using same spritesheet
	var timg = Image.new()
	if timg.load("res://src/assets/extracted_sprite.png") == OK:
		# Temporarily use the same sprite, tinted via modulate, scaled up by 1.2x to fit outside the unit
		target_bracket.texture = ImageTexture.create_from_image(timg)
		target_bracket.modulate = Color(1.0, 1.0, 0.0, 0.5) # Translucent yellow
	target_bracket.pixel_size = 0.00065
	target_bracket.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	target_bracket.render_priority = 1
	target_bracket.visible = false
	add_child(target_bracket)

	# Add custom unit for North Carolina
	test_unit = GlobeUnitScript.new()
	test_unit.radius = radius * 1.01
	
	# Lat/Lon for North Carolina is ~35.5 N, -79.0 W
	var nc_lat = deg_to_rad(35.5)
	var nc_lon = deg_to_rad(-79.0)
	var spawn_pos = _lat_lon_to_vector3(nc_lat, nc_lon, radius * 1.01)
	
	add_child(test_unit)
	test_unit.spawn(spawn_pos)


func _generate_mesh() -> void:
	var mesh = ResourceLoader.load("res://src/data/quadsphere_globe.res")
	if not mesh:
		push_error("GlobeView: Failed to load Quad-Sphere Mesh!")
		return
		
	mesh_instance.mesh = mesh
	
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = VERTEX;
}

// 3D hash for noise
float hash(vec3 p) {
	p = fract(p * 0.3183099 + .1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void fragment() {
	vec3 col = COLOR.rgb;
	
	// Desert is tagged with Alpha < 0.9 (we use 0.5 in Baker)
	if (COLOR.a < 0.9) {
		float n = hash(floor(v_world_pos * 500.0));
		if (n > 0.95) {
			col = vec3(0.3, 0.3, 0.3); // Dark Gray speck
		}
	}
	
	ALBEDO = col;
	ALPHA = 1.0;
}
"""
	mat.shader = shader
	mesh_instance.material_override = mat

func _process(delta: float) -> void:
	# Handle Zoom Interpolation
	if camera.transform.origin.z != target_zoom:
		var new_z = lerpf(camera.transform.origin.z, target_zoom, 10.0 * delta)
		if abs(new_z - target_zoom) < 0.01:
			new_z = target_zoom
		camera.transform.origin.z = new_z

	# Keyboard Zoom Input (+/- or PageUp/PageDown)
	if Input.is_physical_key_pressed(KEY_EQUAL) or Input.is_action_pressed("ui_page_up"):
		target_zoom = clampf(target_zoom - 2.0 * delta, min_zoom, max_zoom)
	if Input.is_physical_key_pressed(KEY_MINUS) or Input.is_action_pressed("ui_page_down"):
		target_zoom = clampf(target_zoom + 2.0 * delta, min_zoom, max_zoom)

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
				# Standard Drag Init
				_is_dragging = true
				_drag_start_pos = event.position
				_drag_start_lon = current_longitude
				_drag_start_lat = current_latitude
			else:
				# Drag release or Click
				if _is_dragging and _drag_start_pos.distance_to(event.position) < 4.0:
					# Valid Click (not a drag release)
					_handle_click(event.position, true)
				_is_dragging = false
				
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Deselect / Cancel
			if test_unit.is_selected:
				test_unit.is_selected = false
				target_bracket.visible = false
			else:
				# Cancel any potential drag early
				_is_dragging = false
				
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_zoom = clampf(target_zoom - 0.25, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_zoom = clampf(target_zoom + 0.25, min_zoom, max_zoom)
	
	elif event is InputEventMouseMotion:
		if _is_dragging:
			var delta = event.position - _drag_start_pos
			# Sensitivity scaling
			var lon_delta = -delta.x * 0.01
			var lat_delta = delta.y * 0.01
			
			# Update coordinates
			current_longitude = wrapf(_drag_start_lon + lon_delta, -PI, PI)
			# Clamp latitude to avoid flipping over poles
			current_latitude = clampf(_drag_start_lat + lat_delta, -PI/2.1, PI/2.1)
			
			_update_camera()
		elif test_unit.is_selected:
			_handle_hover(event.position)

func _update_camera() -> void:
	var t = Transform3D.IDENTITY
	t = t.rotated(Vector3.UP, current_longitude)
	t = t.rotated(t.basis.x, -current_latitude)
	camera_pivot.transform = t
	
	focus_changed.emit(current_longitude, current_latitude)

func _load_cities() -> void:
	var path = "res://docs/city_data.json"
	if not FileAccess.file_exists(path):
		push_error("GlobeView: Could not find city_data.json")
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		push_error("GlobeView: Failed to parse city_data.json error " + str(err))
		return
		
	var cities_dict = json.data
	
	# Pre-load the spritesheet texture directly
	var img = Image.new()
	if img.load("res://src/assets/spritesheet.png") != OK:
		push_error("GlobeView: Failed to load spritesheet.png")
		return
	var tex = ImageTexture.create_from_image(img)
		
	for city_name in cities_dict:
		var data = cities_dict[city_name]
		var lat_deg = data.get("latitude")
		var lon_deg = data.get("longitude")
		
		if lat_deg != null and lon_deg != null:
			# Radius 1.02 perfectly aligns the sprite on the unit layer hovering over the peaks
			var pos = _lat_lon_to_vector3(deg_to_rad(lat_deg), deg_to_rad(lon_deg), radius * 1.02)
			
			var city_node = Node3D.new()
			add_child(city_node)
			
			var sprite = Sprite3D.new()
			sprite.texture = tex
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 240, 16, 16)
			# 0.006 is 1 tile width. 16px * 0.000375 = 0.006 world units
			sprite.pixel_size = 0.000375
			sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			# Keep city marker flat against the terrain but render over it
			sprite.render_priority = 1
			city_node.add_child(sprite)
			
			var lbl = Label3D.new()
			lbl.text = city_name
			lbl.pixel_size = 0.0005
			lbl.font_size = 32
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			# Float the label slightly above and screen-facing so it's readable
			lbl.offset = Vector2(0, -24)
			# Ensure text sorts predictably
			lbl.render_priority = 1
			city_node.add_child(lbl)
			
			# Orient the Node directly away from the core
			city_node.global_position = pos
			city_node.look_at(Vector3.ZERO, Vector3.UP)

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
func _handle_click(screen_pos: Vector2, is_left_click: bool) -> void:
	var space_state = get_world_3d().direct_space_state
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_end = ray_origin + camera.project_ray_normal(screen_pos) * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	# We want to collide with areas (units) and bodies (the globe)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		if collider is Area3D and collider.get_parent().has_method("set_target"):
			# Clicked a Unit!
			var unit = collider.get_parent()
			
			if is_left_click:
				test_unit.is_selected = true
				target_bracket.visible = true
				_handle_hover(screen_pos)
				
		elif collider == map_collider:
			# Clicked the globe surface!
			if is_left_click and test_unit.is_selected:
				# Move unit
				var hit_point = result.position
				test_unit.set_target(hit_point)
				
				# Deselect unit instantly per user request
				test_unit.is_selected = false
				target_bracket.visible = false
				
				# Debug Log Tile Hit
				var tile_id = _get_tile_from_vector3(hit_point)
				print("Unit Ordered To Compute Travel to Tile: ", tile_id)

func _handle_hover(screen_pos: Vector2) -> void:
	var space_state = get_world_3d().direct_space_state
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_end = ray_origin + camera.project_ray_normal(screen_pos) * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == map_collider:
		# Place bracket over the globe surface where hovered
		target_bracket.position = result.position
		target_bracket.look_at_from_position(result.position, Vector3.ZERO, Vector3.UP)
		target_bracket.visible = true
	else:
		target_bracket.visible = false

func _get_tile_from_vector3(pos: Vector3) -> String:
	# Convert a 3D coordinate point on the sphere back into the exact Face and XY coordinate it corresponds to on the underlying 181x181 matrices.
	var n = pos.normalized()
	
	# Determine principle axis (which face of the cube)
	var ax = abs(n.x)
	var ay = abs(n.y)
	var az = abs(n.z)
	
	var face = -1
	var max_axis = max(ax, max(ay, az))
	
	if max_axis == ax:
		face = 3 if n.x > 0 else 2 # RIGHT or LEFT
	elif max_axis == ay:
		face = 4 if n.y > 0 else 5 # TOP or BOTTOM
	else:
		face = 0 if n.z > 0 else 1 # FRONT or BACK
		
	# Un-project from sphere onto the cube plane
	var local_x = 0.0
	var local_y = 0.0
	
	# Reverse mapping from QuadSphereBaker's _get_sphere_point
	if face == 0: # FRONT: local_x, -local_y, 1.0
		local_x = n.x / n.z
		local_y = -n.y / n.z
	elif face == 1: # BACK: -local_x, -local_y, -1.0
		local_x = -n.x / -n.z
		local_y = -n.y / -n.z
	elif face == 2: # LEFT: -1.0, -local_y, local_x
		local_x = n.z / -n.x
		local_y = -n.y / -n.x
	elif face == 3: # RIGHT: 1.0, -local_y, -local_x
		local_x = -n.z / n.x
		local_y = -n.y / n.x
	elif face == 4: # TOP: local_x, 1.0, local_y
		local_x = n.x / n.y
		local_y = n.z / n.y
	elif face == 5: # BOTTOM: local_x, -1.0, -local_y
		local_x = n.x / -n.y
		local_y = -n.z / -n.y

	# Map cube coordinates [-1, 1] to discrete matrix indices [0, RESOLUTION-1]
	# RESOLUTION = 181
	var M = 181
	
	var x = clamp(int(((local_x + 1.0) / 2.0) * M), 0, M - 1)
	var y = clamp(int(((local_y + 1.0) / 2.0) * M), 0, M - 1)
	
	# Array of names must match Face enum from Baker: FRONT, BACK, LEFT, RIGHT, TOP, BOTTOM
	var face_names = ["FRONT", "BACK", "LEFT", "RIGHT", "TOP", "BOTTOM"]
	return "%s_%d_%d" % [face_names[face], x, y]
func _lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	# Calculate standard 2D map projection U-coordinate
	var u_base = (lon + PI) / (2.0 * PI)
	# Map back to the 3D space baked by QuadSphereBaker (which applied 1.0 - u_base)
	var lon_baker = ((1.0 - u_base) * 2.0 * PI) - PI
	
	var cos_lat = cos(lat)
	var ny = sin(lat)
	var nx = cos_lat * cos(lon_baker)
	var nz = cos_lat * sin(lon_baker)
	return Vector3(nx, ny, nz) * r
## Public function to sync this view from external changes (e.g. 2D map panning)
func set_focus(longitude: float, latitude: float) -> void:
	current_longitude = longitude
	current_latitude = latitude
	_update_camera()

