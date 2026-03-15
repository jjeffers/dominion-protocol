class_name GlobeView
extends Node3D

signal focus_changed(longitude: float, latitude: float)
signal hovered_tile_changed(tile_id: String, terrain: String, city_name: String, region_name: String)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var map_data: MapData

var radius: float = 1.0
var city_tile_cache: Dictionary = {}
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
# List of 3D positional nodes to trace against the camera horizon
var cullable_nodes: Array[Node3D] = []
var map_collider: StaticBody3D

var city_nodes: Array[Node3D] = []

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
	var sphere = SphereShape3D.new()
	sphere.radius = radius 
	collision_shape.shape = sphere
	map_collider.add_child(collision_shape)
	
	# Keep on layer 1 by default, but let's make it explicitly interactive
	map_collider.collision_layer = 1
	add_child(map_collider)
	
	# Initialize Regional Borders
	if FileAccess.file_exists("res://src/data/region_borders.res"):
		var border_mesh = load("res://src/data/region_borders.res") as ArrayMesh
		if border_mesh:
			var border_node = MeshInstance3D.new()
			border_node.mesh = border_mesh
			var border_mat = StandardMaterial3D.new()
			border_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			border_mat.albedo_color = Color(0.2, 0.2, 0.2, 1.0) # Solid dark grey lines
			border_node.material_override = border_mat
			add_child(border_node)
	
	_load_cities()
	_load_oil()
	
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
	target_bracket.render_priority = 11
	target_bracket.visible = false
	add_child(target_bracket)

	# Removed hover highlight sprite

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
	var mesh = load("res://src/data/globe_mesh.res")
	if mesh:
		mesh_instance.mesh = mesh
		var img = Image.new()
		if img.load("res://src/assets/biome_map.png") == OK:
			var mat = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
			mat.albedo_texture = ImageTexture.create_from_image(img)
			mesh_instance.material_override = mat
		else:
			push_error("GlobeView: Failed to load biome_map.png image")
	else:
		push_error("GlobeView: Failed to load globe_mesh.res!")

func _process(delta: float) -> void:
	# Handle Zoom Interpolation
	if camera.transform.origin.z != target_zoom:
		var new_z = lerpf(camera.transform.origin.z, target_zoom, 10.0 * delta)
		if abs(new_z - target_zoom) < 0.01:
			new_z = target_zoom
		camera.transform.origin.z = new_z
		
	# Handle Node Visibility (Horizon Culling)
	# Because Sprites have no_depth_test to render clearly over terrain peaks, they punch through the globe.
	# We dynamically hide them if they rotate out of hemispheric front-view.
	var cam_pos = camera.global_position.normalized()
	for node in cullable_nodes:
		# Use 0.15 threshold to cull them slightly before they clip exactly sideways over the mathematical edge
		if node.position.normalized().dot(cam_pos) > 0.15:
			node.show()
		else:
			node.hide()

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
			if test_unit.is_selected:
				# Issue Move Command via Right Click
				_handle_click(event.position, false)
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
			
		# Always update terrain HUD regardless of unit selection
		_update_terrain_hover(event.position)

func _update_camera() -> void:
	var t = Transform3D.IDENTITY
	t = t.rotated(Vector3.UP, current_longitude + PI)
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
	
	# Pre-load the full city spritesheet into memory
	var img = Image.new()
	if img.load("res://src/assets/spritesheet.png") != OK:
		push_error("GlobeView: Failed to load spritesheet.png")
		return
		
	# Slice the 32x32 tiles
	# Center Marker (Row 16, Col 1) -> y=480, x=0
	var tex_center = ImageTexture.create_from_image(img.get_region(Rect2i(0, 480, 32, 32)))
	
	# Land Surrounds (Row 16, Col 2-9)
	var tex_land: Array[ImageTexture] = []
	for i in range(8):
		tex_land.append(ImageTexture.create_from_image(img.get_region(Rect2i(32 + (i * 32), 480, 32, 32))))
		
	# Ocean Surrounds (Row 15, Col 2-9)
	var tex_ocean: Array[ImageTexture] = []
	for i in range(8):
		tex_ocean.append(ImageTexture.create_from_image(img.get_region(Rect2i(32 + (i * 32), 448, 32, 32))))
		
	print("Loaded city spritesheet slices successfully!")
		
	for city_name in cities_dict:
		var data = cities_dict[city_name]
		var lat_deg = data.get("latitude")
		var lon_deg = data.get("longitude")
		
		if lat_deg != null and lon_deg != null:
			# Get generic continuous point to find what Godot discrete Face/X/Y coordinate it lands on
			var raw_pos = _lat_lon_to_vector3(deg_to_rad(lat_deg), deg_to_rad(lon_deg), radius)
			var tile_id = _get_tile_from_vector3(raw_pos)
			city_tile_cache[tile_id] = city_name
			
			print("Placing City: ", city_name, " at Tile: ", tile_id)
			
			var centroid = map_data.get_centroid(tile_id)
			var pos = raw_pos
			if centroid != Vector3.ZERO:
				# Snap it exactly to the geometric center of the true Godot tile so it frames perfectly with the hover outline!
				pos = centroid.normalized() * radius
			
			# Discover exact physical size of the terrain quad here to correct for spherified cube distortion
			var tile_width = 0.006
			var nbrs = map_data.get_neighbors(tile_id)
			if nbrs.size() > 0:
				var c1 = centroid.normalized()
				var c2 = map_data.get_centroid(nbrs[0]).normalized()
				tile_width = c1.distance_to(c2) * radius
				
			var node_pixel_size = tile_width / 32.0
			
			var city_node = Node3D.new()
			add_child(city_node)
			
			var sprite_main = Sprite3D.new()
			sprite_main.texture = tex_center
			
			# Mathematically exactly size the 32x32 sprite to stretch perfectly across the true width of the underlying geometric tile!
			sprite_main.pixel_size = node_pixel_size
			# Turn off Billboard so the Sprite lays mathematically flat against the XYZ rotation of the `city_node` LookAt
			sprite_main.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			sprite_main.no_depth_test = true # Guarantee rendering over terrain
			sprite_main.render_priority = 5 # Renters UNDER units (priority 10)
			city_node.add_child(sprite_main)
			
			var lbl = Label3D.new()
			lbl.text = city_name
			lbl.pixel_size = 0.0005
			lbl.font_size = 32
			# Keep Labels billboarded so the text is always readable to the player despite the rotation angle of the ground
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.no_depth_test = true
			lbl.offset = Vector2(0, -32)
			lbl.render_priority = 5
			city_node.add_child(lbl)
			
			# Orient the Node directly away from the core
			city_node.position = pos
			if pos.normalized().abs() != Vector3.UP:
				city_node.look_at(Vector3.ZERO, Vector3.UP)
				
			# Generate the 8 surrounding subtiles using the dynamically retrieved tile width
			# Order matches: NW, N, NE, E, SE, S, SW, W -> Index 0 to 7
			var grid_offsets = [
				Vector3(-tile_width, tile_width, 0),  # 0: NW (Top-Left)
				Vector3(0, tile_width, 0),            # 1: N  (Top)
				Vector3(tile_width, tile_width, 0),   # 2: NE (Top-Right)
				Vector3(tile_width, 0, 0),            # 3: E  (Right)
				Vector3(tile_width, -tile_width, 0),  # 4: SE (Bottom-Right)
				Vector3(0, -tile_width, 0),           # 5: S  (Bottom)
				Vector3(-tile_width, -tile_width, 0), # 6: SW (Bottom-Left)
				Vector3(-tile_width, 0, 0)            # 7: W  (Left)
			]
			
			var o_idx = 0
			for local_offset in grid_offsets:
				# Convert the local XY tangent offset to true Godot global 3D space relative to the angled CityNode
				var global_offset = city_node.to_global(local_offset)
				# Reverse-project the global 3D coordinate back into the specific XYZ Face coordinate string of the map
				var sub_tile_id = _get_tile_from_vector3(global_offset)
				# Cache adjacent tile so hover tooltip displays city name within 3x3 array
				city_tile_cache[sub_tile_id] = city_name
				# Query the memory dictionary to ascertain the biome
				var is_ocean = map_data.get_terrain(sub_tile_id) == "OCEAN"
				
				# Spawn the correct adjacent piece
				var sub_sprite = Sprite3D.new()
				sub_sprite.texture = tex_ocean[o_idx] if is_ocean else tex_land[o_idx]
				sub_sprite.pixel_size = node_pixel_size
				sub_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
				sub_sprite.no_depth_test = true
				sub_sprite.render_priority = 5
				sub_sprite.position = local_offset # We position it linearly off the center node
				
				city_node.add_child(sub_sprite)
				o_idx += 1
				
			cullable_nodes.append(city_node)

func _load_oil() -> void:
	var path = "res://src/data/oil_data.json"
	if not FileAccess.file_exists(path):
		push_error("GlobeView: Could not find oil_data.json")
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		push_error("GlobeView: Failed to parse oil_data.json error " + str(err))
		return
		
	var oil_dict = json.data
	
	var img = Image.new()
	if img.load("res://src/assets/spritesheet.png") != OK:
		push_error("GlobeView: Failed to load oil spritesheet.png")
		return
		
	# Slice Oil icon from Row 1 (index 0), Col 8 (index 7) => y=0, x=224
	var tex_oil = ImageTexture.create_from_image(img.get_region(Rect2i(224, 0, 32, 32)))
	
	var outline_mat = ShaderMaterial.new()
	var outline_shader = Shader.new()
	outline_shader.code = """
shader_type spatial;
render_mode unshaded, depth_test_disabled;
uniform sampler2D tex_albedo : source_color, filter_nearest;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
void fragment() {
	vec4 c = texture(tex_albedo, UV);
	vec2 size = vec2(32.0, 32.0);
	float o = 0.0;
	o = max(o, texture(tex_albedo, UV + vec2(-1.0, 0.0) / size).a);
	o = max(o, texture(tex_albedo, UV + vec2(0.0, 1.0) / size).a);
	o = max(o, texture(tex_albedo, UV + vec2(1.0, 0.0) / size).a);
	o = max(o, texture(tex_albedo, UV + vec2(0.0, -1.0) / size).a);
	o = max(o, texture(tex_albedo, UV + vec2(-1.0, -1.0) / size).a);
	o = max(o, texture(tex_albedo, UV + vec2(-1.0, 1.0) / size).a);
	o = max(o, texture(tex_albedo, UV + vec2(1.0, -1.0) / size).a);
	o = max(o, texture(tex_albedo, UV + vec2(1.0, 1.0) / size).a);
	if (c.a > 0.1) {
		ALBEDO = c.rgb;
		ALPHA = c.a;
	} else if (o > 0.1) {
		ALBEDO = outline_color.rgb;
		ALPHA = 1.0;
	} else {
		ALPHA = 0.0;
	}
}
"""
	outline_mat.shader = outline_shader
	outline_mat.set_shader_parameter("tex_albedo", tex_oil)
	outline_mat.render_priority = 5
	
	for marker in oil_dict:
		var pos_data = marker.get("position")
		if pos_data and pos_data.has("x"):
			var pos = Vector3(pos_data["x"], pos_data["y"], pos_data["z"])
			var final_pos = pos.normalized() * radius
			
			var oil_node = Node3D.new()
			add_child(oil_node)
			
			var sprite = Sprite3D.new()
			sprite.texture = tex_oil
			
			# Enlarged pixel size so the 32x32 sprite is slightly easier to spot than a city
			sprite.pixel_size = 0.00035
			sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			sprite.no_depth_test = true
			sprite.render_priority = 5
			sprite.material_override = outline_mat
			
			oil_node.add_child(sprite)
			
			# Target coordinates generated from map_data.get_centroid, which is explicitly mathematical radius. Push by 1.02 multiplier matching Cities
			oil_node.position = final_pos
			if final_pos.normalized().abs() != Vector3.UP:
				oil_node.look_at(Vector3.ZERO, Vector3.UP)
			
			cullable_nodes.append(oil_node)

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
			if is_left_click:
				# Left Click empty ground = Deselect
				if test_unit.is_selected:
					test_unit.is_selected = false
					target_bracket.visible = false
			elif not is_left_click and test_unit.is_selected:
				# Right Click = Move unit to exact tile centroid
				var hit_point = result.position
				var tile_id = _get_tile_from_vector3(hit_point)
				var centroid = map_data.get_centroid(tile_id)
				
				if centroid != Vector3.ZERO:
					test_unit.set_target(centroid)
					print("Unit Ordered To Compute Travel to Centroid of Tile: ", tile_id)
				
				# Deselect unit instantly per user request
				test_unit.is_selected = false
				target_bracket.visible = false

func _handle_hover(screen_pos: Vector2) -> void:
	var space_state = get_world_3d().direct_space_state
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_end = ray_origin + camera.project_ray_normal(screen_pos) * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == map_collider:
		# Snap bracket over the exact centroid of the hovered tile
		var tile_id = _get_tile_from_vector3(result.position)
		var centroid = map_data.get_centroid(tile_id)
		
		# Position slightly above the terrain surface
		var snap_pos = centroid.normalized() * (radius * 1.03) # slightly higher than city tiles (1.02)
		
		var tile_width = 0.006
		var nbrs = map_data.get_neighbors(tile_id)
		if nbrs.size() > 0:
			var c1 = centroid.normalized()
			var c2 = map_data.get_centroid(nbrs[0]).normalized()
			tile_width = c1.distance_to(c2) * (radius * 1.02)
			
		target_bracket.pixel_size = (tile_width / 32.0) * 1.1 # 10% larger than 1 tile
		
		if snap_pos != Vector3.ZERO:
			target_bracket.position = snap_pos
			target_bracket.look_at_from_position(snap_pos, Vector3.ZERO, Vector3.UP)
			target_bracket.visible = true
	else:
		target_bracket.visible = false

func _update_terrain_hover(screen_pos: Vector2) -> void:
	var space_state = get_world_3d().direct_space_state
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_end = ray_origin + camera.project_ray_normal(screen_pos) * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == map_collider:
		var tile_id = _get_tile_from_vector3(result.position)
		var terrain = map_data.get_terrain(tile_id)
		var c_name = ""
		if city_tile_cache.has(tile_id):
			c_name = city_tile_cache[tile_id]
			
		var centroid = map_data.get_centroid(tile_id)
		var snap_pos = centroid.normalized() * (radius * 1.03) # slightly atop city (1.02)
		
		var tile_width = 0.006
		var nbrs = map_data.get_neighbors(tile_id)
		if nbrs.size() > 0:
			var c1 = centroid.normalized()
			var c2 = map_data.get_centroid(nbrs[0]).normalized()
			tile_width = c1.distance_to(c2) * (radius * 1.02)
			
		var region_name = map_data.get_region(tile_id)
		hovered_tile_changed.emit(tile_id, terrain, c_name, region_name)
	else:
		# Cursor over deep space
		hovered_tile_changed.emit("", "", "", "")

func _get_tile_from_vector3(pos: Vector3) -> String:
	# Convert a 3D coordinate point on the sphere back into the exact Face and XY coordinate it corresponds to on the underlying 361x361 matrices.
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
	# RESOLUTION = 361
	var M = 361
	
	var x = clamp(int(((local_x + 1.0) / 2.0) * M), 0, M - 1)
	var y = clamp(int(((local_y + 1.0) / 2.0) * M), 0, M - 1)
	
	# Array of names must match Face enum from Baker: FRONT, BACK, LEFT, RIGHT, TOP, BOTTOM
	var face_names = ["FRONT", "BACK", "LEFT", "RIGHT", "TOP", "BOTTOM"]
	return "%s_%d_%d" % [face_names[face], x, y]
func _lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var cos_lat = cos(lat)
	var ny = sin(lat)
	var nx = cos_lat * -sin(lon)
	var nz = cos_lat * -cos(lon)
	return Vector3(nx, ny, nz) * r
## Public function to sync this view from external changes (e.g. 2D map panning)
func set_focus(longitude: float, latitude: float) -> void:
	current_longitude = longitude
	current_latitude = latitude
	_update_camera()

