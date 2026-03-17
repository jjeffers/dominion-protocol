class_name GlobeView
extends Node3D

signal focus_changed(longitude: float, latitude: float)
signal hovered_tile_changed(tile_id: String, terrain: String, city_name: String, region_name: String)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var map_data: MapData
var active_scenario: Dictionary = {}

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

var selected_unit: Node3D = null
var units_list: Array[Node3D] = []
var target_bracket: Sprite3D
# List of 3D positional nodes to trace against the camera horizon
var cullable_nodes: Array[Node3D] = []
var map_collider: StaticBody3D

var city_nodes: Array[Node3D] = []
var friendly_city_positions: Array[Vector3] = []

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
	outline_mat.render_priority = 2 # Draw over region borders
	outline_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	outline_mat.vertex_color_use_as_albedo = true
	outline_mesh_instance.material_override = outline_mat
	
	add_child(outline_mesh_instance)
	
	if NetworkManager:
		NetworkManager.unit_target_synced.connect(_on_unit_target_synced)
	
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
			border_mat.render_priority = 1 # Draw over globe, under faction borders
			border_node.material_override = border_mat
			add_child(border_node)
	
	# Instantiate targeting bracket
	target_bracket = Sprite3D.new()
	# Draw bracket using same spritesheet
	var t_tex = load("res://src/assets/extracted_sprite.png") as Texture2D
	if t_tex:
		target_bracket.texture = t_tex
	else:
		push_error("GlobeView: Failed to load extracted_sprite.png")
	
	var tb_mat = StandardMaterial3D.new()
	tb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tb_mat.albedo_color = Color(1, 1, 0, 0.8) # Yellow
	tb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tb_mat.no_depth_test = true # Ensure it draws over terrain
	tb_mat.render_priority = 20 # Below selected unit
	target_bracket.material_override = tb_mat
	
	target_bracket.visible = false
	add_child(target_bracket)

func _on_unit_target_synced(unit_name: String, target_pos: Vector3, enemy_target_name: String) -> void:
	print("GlobeView handling _on_unit_target_synced for ", unit_name, " enemy: ", enemy_target_name)
	var unit: Node3D = null
	for u in units_list:
		if not is_instance_valid(u):
			continue
		if u.name == unit_name:
			unit = u
			break
			
	if unit:
		if enemy_target_name != "":
			var enemy: Node3D = null
			for u in units_list:
				if not is_instance_valid(u):
					continue
				if u.name == enemy_target_name:
					enemy = u
					break
			if enemy:
				unit.clear_combat_target()
				unit.set_movement_target_unit(enemy)
		else:
			# Manual coordinate movement
			unit.clear_combat_target()
			unit.set_target(target_pos)

func _generate_mesh() -> void:
	var mesh = load("res://src/data/globe_mesh.res")
	if mesh:
		mesh_instance.mesh = mesh
		var tex = load("res://src/assets/biome_map.png") as Texture2D
		if tex:
			var mat = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
			mat.albedo_texture = tex
			mesh_instance.material_override = mat
		else:
			push_error("GlobeView: Failed to load biome_map.png image")
	else:
		push_error("GlobeView: Failed to load globe_mesh.res!")

func _process(delta: float) -> void:
	if not camera:
		return
		
	# Handle Zoom Interpolation
	if camera.transform.origin.z != target_zoom:
		var new_z = lerpf(camera.transform.origin.z, target_zoom, 10.0 * delta)
		if abs(new_z - target_zoom) < 0.01:
			new_z = target_zoom
		camera.transform.origin.z = new_z
		
	# Handle Node Visibility (Horizon Culling & Fog of War)
	# Because Sprites have no_depth_test to render clearly over terrain peaks, they punch through the globe.
	# We dynamically hide them if they rotate out of hemispheric front-view.
	var cam_pos = camera.global_position.normalized()
	
	# Compute friendly vision anchors for Fog of War
	var local_faction = _get_local_faction()
			
	var friendly_unit_positions: Array[Vector3] = []
	if local_faction != "":
		for u in units_list:
			if not is_instance_valid(u):
				continue
			if u.get("faction_name") == local_faction and u.get("is_dead") != true:
				friendly_unit_positions.append(u.global_position)
	
	# Populate friendly_city_positions for Fog of War
	friendly_city_positions.clear() # Clear previous frame's positions
	if local_faction != "" and active_scenario.has("factions") and active_scenario["factions"].has(local_faction):
		var faction_cities = active_scenario["factions"][local_faction].get("cities", [])
		for city_node in city_nodes: # Iterate through existing city nodes
			var city_name = city_node.name # Assuming city_node.name holds the city name
			if city_name in faction_cities:
				friendly_city_positions.append(city_node.global_position) # Use global_position of the city node
	
	var valid_nodes: Array[Node3D] = []
	for node in cullable_nodes:
		if not is_instance_valid(node):
			continue
			
		valid_nodes.append(node)
		
		# Base Horizon Culling
		var is_visible = false
		# Use 0.15 threshold to cull them slightly before they clip exactly sideways over the mathematical edge
		if node.position.normalized().dot(cam_pos) > 0.15:
			is_visible = true
			
		# Fog of War Distance Culling (only applies if we have a faction and node is an enemy unit)
		if is_visible and local_faction != "" and node.get("faction_name") != null and node.get("faction_name") != local_faction:
			is_visible = false
			# 6x unit widths = 0.036 distance
			var vision_range = 0.036
			for f_pos in friendly_unit_positions:
				if node.global_position.distance_to(f_pos) <= vision_range:
					is_visible = true
					break
			if not is_visible:
				for c_pos in friendly_city_positions:
					if node.global_position.distance_to(c_pos) <= vision_range:
						is_visible = true
						break
			
		if is_visible:
			if node.has_method("set_visibility"):
				node.set_visibility(true)
			else:
				node.show()
		else:
			if node.has_method("set_visibility"):
				node.set_visibility(false)
			else:
				node.hide()
			
	cullable_nodes = valid_nodes

	# Keyboard Zoom Input (+/- or PageUp/PageDown)
	if camera:
		if Input.is_physical_key_pressed(KEY_EQUAL) or Input.is_action_pressed("ui_page_up"):
			target_zoom = clampf(target_zoom - 2.0 * delta, min_zoom, max_zoom)
		if Input.is_physical_key_pressed(KEY_MINUS) or Input.is_action_pressed("ui_page_down"):
			target_zoom = clampf(target_zoom + 2.0 * delta, min_zoom, max_zoom)

	var lon_delta = 0.0
	var lat_delta = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A): lon_delta = -2.0 * delta
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D): lon_delta = 2.0 * delta
	if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W): lat_delta = 2.0 * delta
	if Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S): lat_delta = -2.0 * delta
	
	if lon_delta != 0.0 or lat_delta != 0.0:
		current_longitude = wrapf(current_longitude + lon_delta, -PI, PI)
		current_latitude = clampf(current_latitude + lat_delta, -PI/2.1, PI/2.1)
		
	# Handle City Captures
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and multiplayer.is_server():
		capture_timer += delta
		if capture_timer >= CAPTURE_INTERVAL:
			capture_timer -= CAPTURE_INTERVAL
			_process_city_captures()
		_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		print("RAW RIGHT CLICK EVENT RECEIVED IN GLOBEVIEW: ", event, " pressed: ", event.pressed)
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed):
		if selected_unit:
			selected_unit.set_selected(false)
			selected_unit = null
			target_bracket.visible = false
			
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
				if _is_dragging and _drag_start_pos.distance_to(event.position) < 15.0:
					# Valid Click (not a drag release)
					_handle_click(event.position, true)
				_is_dragging = false
				
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			print("Right click unhandled input block executes!")
			if selected_unit:
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
			# Sensitivity scaling directly tied to zoom depth
			var zoom_scalar = (target_zoom / max_zoom)
			var lon_delta = -delta.x * 0.01 * zoom_scalar
			var lat_delta = delta.y * 0.01 * zoom_scalar
			
			# Update coordinates
			current_longitude = wrapf(_drag_start_lon + lon_delta, -PI, PI)
			# Clamp latitude to avoid flipping over poles
			current_latitude = clampf(_drag_start_lat + lat_delta, -PI/2.1, PI/2.1)
			
			_update_camera()
		elif selected_unit:
			_handle_hover(event.position)
			
		# Always update terrain HUD regardless of unit selection
		_update_terrain_hover(event.position)

signal city_captured(city_name: String, new_faction: String, old_faction: String)
signal victory_declared(winning_faction: String)

var capture_timer: float = 0.0
const CAPTURE_INTERVAL: float = 1.0
			
func _process_city_captures() -> void:
	for city_node in city_nodes:
		var units_in_range: Array[Node3D] = []
		for u in units_list:
			if not is_instance_valid(u):
				continue
			if u.get("is_dead") != true:
				var dist = city_node.position.distance_to(u.position) / radius
				if dist <= 0.01:
					units_in_range.append(u)
					
		if units_in_range.size() > 0:
			var capturing_faction = units_in_range[0].get("faction_name")
			var contested = false
			
			for u in units_in_range:
				if u.get("faction_name") != capturing_faction:
					contested = true
					break
					
			if not contested and capturing_faction != "":
				# Find current owner
				var current_owner = ""
				if active_scenario.has("factions"):
					for f_name in active_scenario["factions"].keys():
						if active_scenario["factions"][f_name].has("cities") and city_node.name in active_scenario["factions"][f_name]["cities"]:
							current_owner = f_name
							break
				if current_owner == "":
					current_owner = "neutral"
					
				# If ownership changed
				if current_owner != capturing_faction:
					rpc("sync_city_capture", city_node.name, capturing_faction, current_owner)

@rpc("authority", "call_local", "reliable")
func sync_city_capture(city_name: String, new_faction: String, old_faction: String) -> void:
	print("City Capture: ", city_name, " captured by ", new_faction, " from ", old_faction)
	
	# Strip from old faction
	if old_faction == "neutral":
		if active_scenario.has("neutral_cities"):
			active_scenario["neutral_cities"].erase(city_name)
	else:
		if active_scenario.has("factions") and active_scenario["factions"].has(old_faction):
			if active_scenario["factions"][old_faction].has("cities"):
				active_scenario["factions"][old_faction]["cities"].erase(city_name)
				
	# Add to new faction
	if active_scenario.has("factions") and active_scenario["factions"].has(new_faction):
		if not active_scenario["factions"][new_faction].has("cities"):
			active_scenario["factions"][new_faction]["cities"] = []
		if not active_scenario["factions"][new_faction]["cities"].has(city_name):
			active_scenario["factions"][new_faction]["cities"].append(city_name)
			
	# Process Elimination
	var faction_eliminated = false
	if old_faction != "neutral" and active_scenario.has("factions") and active_scenario["factions"].has(old_faction):
		var old_fac_data = active_scenario["factions"][old_faction]
		if old_fac_data.has("capitol") and old_fac_data["capitol"] == city_name:
			print("FACTION ELIMINATED: ", old_faction, " lost their capitol (", city_name, ")!")
			faction_eliminated = true
			old_fac_data["eliminated"] = true
			
			# Transfer remaining cities to neutral
			if old_fac_data.has("cities"):
				if not active_scenario.has("neutral_cities"):
					active_scenario["neutral_cities"] = []
				for rem_city in old_fac_data["cities"]:
					active_scenario["neutral_cities"].append(rem_city)
				old_fac_data["cities"].clear()
				
			# Destroy all units belonging to the eliminated faction
			for u in units_list:
				if is_instance_valid(u) and u.get("faction_name") == old_faction:
					u.queue_free()

	# Redraw borders
	_generate_faction_borders()
	
	# Emit so HUD can update
	city_captured.emit(city_name, new_faction, old_faction)
	
	# Process Victory Condition
	if faction_eliminated and multiplayer.is_server():
		var remaining_factions = []
		for f_name in active_scenario["factions"].keys():
			if not active_scenario["factions"][f_name].get("eliminated", false):
				remaining_factions.append(f_name)
				
		if remaining_factions.size() == 1:
			var winner = remaining_factions[0]
			print("VICTORY CONDITION MET: ", winner, " is the last standing faction!")
			rpc("sync_victory", winner)

@rpc("authority", "call_local", "reliable")
func sync_victory(winning_faction: String) -> void:
	victory_declared.emit(winning_faction)

func _update_camera() -> void:
	var t = Transform3D.IDENTITY
	t = t.rotated(Vector3.UP, current_longitude + PI)
	t = t.rotated(t.basis.x, -current_latitude)
	camera_pivot.transform = t
	
	focus_changed.emit(current_longitude, current_latitude)

func _instantiate_scenario(scenario_data: Dictionary) -> void:
	if scenario_data.is_empty():
		return
	active_scenario = scenario_data
		
	var active_cities: Array[String] = []
	var active_oil: Array[String] = []
	
	if scenario_data.has("factions"):
		for faction in scenario_data["factions"].values():
			if faction.has("cities"):
				for c in faction["cities"]:
					active_cities.append(c)
			if faction.has("oil"):
				for o in faction["oil"]:
					active_oil.append(o)
					
	if scenario_data.has("neutral_cities"):
		for c in scenario_data["neutral_cities"]:
			active_cities.append(c)
	if scenario_data.has("neutral_oil"):
		for o in scenario_data["neutral_oil"]:
			active_oil.append(o)
			
	var active_regions: Array[String] = []
	var faction_regions: Dictionary = {}
	
	var path = "res://src/data/city_data.json"
	var c_dict = {}
	if FileAccess.file_exists(path):
		var c_json = JSON.new()
		if c_json.parse(FileAccess.open(path, FileAccess.READ).get_as_text()) == OK:
			c_dict = c_json.data
			
	if c_dict.is_empty() == false:
		if scenario_data.has("factions"):
			for f_name in scenario_data["factions"].keys():
				faction_regions[f_name] = []
				var faction = scenario_data["factions"][f_name]
				if faction.has("cities"):
					for c_name in faction["cities"]:
						active_regions.append(c_name)
						faction_regions[f_name].append(c_name)
						
		if scenario_data.has("neutral_cities"):
			for c_name in scenario_data["neutral_cities"]:
				active_regions.append(c_name)

	# Identitfy active regions from oil
	var opath = "res://src/data/oil_data.json"
	if FileAccess.file_exists(opath):
		var o_json = JSON.new()
		if o_json.parse(FileAccess.open(opath, FileAccess.READ).get_as_text()) == OK:
			var o_arr = o_json.data
			if scenario_data.has("factions"):
				for faction_name in scenario_data["factions"].keys():
					var faction = scenario_data["factions"][faction_name]
					if faction.has("oil"):
						for o_name in faction["oil"]:
							for marker in o_arr:
								if marker.get("tile") == o_name:
									var pos = marker.get("position")
									var tile = _get_tile_from_vector3(Vector3(pos.x, pos.y, pos.z).normalized() * radius)
									var reg = map_data.get_region(tile)
									if reg != "":
										if not active_regions.has(reg):
											active_regions.append(reg)
										if not faction_regions[faction_name].has(reg):
											faction_regions[faction_name].append(reg)
			# Neutral oil
			if scenario_data.has("neutral_oil"):
				for o_name in scenario_data["neutral_oil"]:
					for marker in o_arr:
						if marker.get("tile") == o_name:
							var pos = marker.get("position")
							var tile = _get_tile_from_vector3(Vector3(pos.x, pos.y, pos.z).normalized() * radius)
							var reg = map_data.get_region(tile)
							if reg != "" and not active_regions.has(reg):
								active_regions.append(reg)

	map_data.cull_regions(active_regions)
	
	_generate_faction_borders()
	
	_load_cities(active_cities)
	_load_oil(active_oil)
	
	# Spawn defined Units
	if c_dict.is_empty() == false:
		if scenario_data.has("factions"):
			for faction_name in scenario_data["factions"].keys():
				var faction = scenario_data["factions"][faction_name]
				if faction.has("units"):
					for unit_def in faction["units"]:
						_spawn_unit(unit_def, faction_name, c_dict, faction_regions)

func _load_cities(active_cities: Array[String]) -> void:
	var path = "res://src/data/city_data.json"
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
	var tex_map = load("res://src/assets/spritesheet.png") as Texture2D
	if not tex_map:
		push_error("GlobeView: Failed to load spritesheet.png")
		return
	var img = tex_map.get_image()
		
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
		
	# Capitol Land Surrounds (Row 14, Col 2-9)
	var tex_cap_land: Array[ImageTexture] = []
	for i in range(8):
		tex_cap_land.append(ImageTexture.create_from_image(img.get_region(Rect2i(32 + (i * 32), 416, 32, 32))))
		
	# Capitol Ocean Surrounds (Row 13, Col 2-9)
	var tex_cap_ocean: Array[ImageTexture] = []
	for i in range(8):
		tex_cap_ocean.append(ImageTexture.create_from_image(img.get_region(Rect2i(32 + (i * 32), 384, 32, 32))))
		
	print("Loaded city spritesheet slices successfully!")
	
	var capitols: Dictionary = {}
	if active_scenario.has("factions"):
		for faction in active_scenario["factions"].values():
			var cap = faction.get("capital", faction.get("capitol", ""))
			if cap != "":
				capitols[cap] = faction.get("color", "#FFFFFF")
		
	for city_name in cities_dict:
		if not active_cities.has(city_name):
			continue
			
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
			var tile_width = _get_tile_width(tile_id)
				
			var node_pixel_size = tile_width / 32.0
			
			var city_node = Node3D.new()
			city_node.name = city_name
			add_child(city_node)
			city_nodes.append(city_node)
			
			var is_capitol = capitols.has(city_name)
			
			var sprite_main = Sprite3D.new()
			sprite_main.texture = tex_center
			if is_capitol:
				sprite_main.modulate = Color(capitols[city_name])
			
			# Mathematically exactly size the 32x32 sprite to stretch perfectly across the true width of the underlying geometric tile!
			sprite_main.pixel_size = node_pixel_size
			# Turn off Billboard so the Sprite lays mathematically flat against the XYZ rotation of the `city_node` LookAt
			sprite_main.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			sprite_main.no_depth_test = true # Guarantee rendering over terrain
			sprite_main.render_priority = 5 # Renters UNDER units (priority 10)
			city_node.add_child(sprite_main)
			

			
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
				Vector3(-tile_width, -tile_width, 0), # 4: SW (Bottom-Left) - Fixed Swap
				Vector3(0, -tile_width, 0),           # 5: S  (Bottom)
				Vector3(tile_width, -tile_width, 0),  # 6: SE (Bottom-Right) - Fixed Swap
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
				if is_ocean:
					sub_sprite.texture = tex_cap_ocean[o_idx] if is_capitol else tex_ocean[o_idx]
				else:
					sub_sprite.texture = tex_cap_land[o_idx] if is_capitol else tex_land[o_idx]
				
				sub_sprite.pixel_size = node_pixel_size
				sub_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
				sub_sprite.no_depth_test = true
				sub_sprite.render_priority = 5
				sub_sprite.position = local_offset # We position it linearly off the center node
				
				city_node.add_child(sub_sprite)
				o_idx += 1
				
			cullable_nodes.append(city_node)

func _load_oil(active_oil: Array[String]) -> void:
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
	
	var tex_map = load("res://src/assets/spritesheet.png") as Texture2D
	if not tex_map:
		push_error("GlobeView: Failed to load oil spritesheet.png")
		return
	var img = tex_map.get_image()
		
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
		if not active_oil.has(marker.get("tile", "")):
			continue
			
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
	print("TESTING RIGHT CLICK Raycast hit target: ", result)
	
	if result:
		var collider = result.collider
		var is_unit = collider is Area3D and collider.get_parent().has_method("set_target")
		var hit_point = result.position
		
		# print("DEBUG CLICKED COLLIDER: ", collider.name if collider else "NULL", " of class ", collider.get_class() if collider else "None")
		
		if is_left_click:
			if is_unit:
				var unit = collider.get_parent()
				if selected_unit and selected_unit != unit:
					selected_unit.set_selected(false)
				selected_unit = unit
				selected_unit.set_selected(true)
				target_bracket.visible = true
				_handle_hover(screen_pos)
			elif collider == map_collider:
				if selected_unit:
					selected_unit.set_selected(false)
					selected_unit = null
					target_bracket.visible = false
		elif not is_left_click and selected_unit:
			# Right Click = Move unit to clicked position
			if is_unit or collider == map_collider:
				if NetworkManager and NetworkManager.players.has(multiplayer.get_unique_id()):
					# NetworkManager syncs targeted moves but not manual clear requests alone right now, so we clear it locally
					# The RPC calls later will override the target unit appropriately
					selected_unit.clear_combat_target()
				else:
					selected_unit.clear_combat_target()
				
				if is_unit and collider.get_parent() != selected_unit:
					var target_enemy = collider.get_parent()
					if NetworkManager and NetworkManager.players.has(multiplayer.get_unique_id()):
						NetworkManager.request_unit_move.rpc_id(1, selected_unit.name, Vector3.ZERO, target_enemy.name)
					else:
						selected_unit.set_movement_target_unit(target_enemy)
					print("Unit Ordered to Travel to Enemy Position")
				else:
					var tile_id = _get_tile_from_vector3(hit_point)
					var centroid = map_data.get_centroid(tile_id)
					
					if centroid != Vector3.ZERO:
						if NetworkManager and NetworkManager.players.has(multiplayer.get_unique_id()):
							NetworkManager.request_unit_move.rpc_id(1, selected_unit.name, centroid, "")
						else:
							selected_unit.set_target(centroid)
						print("Unit Ordered To Compute Travel to Centroid of Tile: ", tile_id)
				
				# Deselect unit instantly per user request
				selected_unit.set_selected(false)
				selected_unit = null
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
		var tile_id = _get_tile_from_vector3(result.position)
		var centroid = map_data.get_centroid(tile_id)
		
		# Track the mouse position exactly instead of snapping to the centroid.
		# Match the GlobeUnit's elevation precisely to prevent parallax offset.
		var raw_pos = result.position.normalized()
		var snap_pos = raw_pos * radius
		
		var tile_width = 0.006
		var nbrs = map_data.get_neighbors(tile_id)
		if nbrs.size() > 0:
			var c1 = centroid.normalized()
			var c2 = map_data.get_centroid(nbrs[0]).normalized()
			tile_width = c1.distance_to(c2) * (radius * 1.02)
			
		# Match GlobeUnit sizing exactly
		target_bracket.pixel_size = ((tile_width * 3.0) / 34.0) * (38.0 / 34.0)
		
		if snap_pos != Vector3.ZERO:
			target_bracket.position = snap_pos
			target_bracket.look_at(Vector3.ZERO, Vector3.UP)
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

func _get_tile_width(tile_id: String) -> float:
	var tile_width = 0.006
	var centroid = map_data.get_centroid(tile_id)
	var nbrs = map_data.get_neighbors(tile_id)
	if nbrs.size() > 0 and centroid != Vector3.ZERO:
		var c1 = centroid.normalized()
		var c2 = map_data.get_centroid(nbrs[0]).normalized()
		tile_width = c1.distance_to(c2) * radius
	return tile_width

func _generate_faction_borders() -> void:
	print("GlobeView: Generating Dynamic Faction Borders...")
	# Track edges we've already drawn so we don't draw overlapping lines
	var drawn_edges = {}
	var edges_by_faction = {}
	
	for tile_id in map_data._region_map.keys():
		var owner_city = map_data._region_map[tile_id]
		# Find which faction owns this city
		var owning_faction = ""
		var faction_color = Color(0.2, 0.2, 0.2, 1.0)
		
		# Reverse lookup faction from city name
		if active_scenario.has("factions"):
			for f_name in active_scenario["factions"]:
				var f_data = active_scenario["factions"][f_name]
				if f_data.has("cities") and owner_city in f_data["cities"]:
					owning_faction = f_name
					if f_data.has("color"):
						faction_color = Color(f_data["color"])
					break
					
		if owning_faction == "":
			continue # Neutral or un-configured cities don't get borders for now
			
		var neighbors = map_data.get_neighbors(tile_id)
		for n_id in neighbors:
			var n_owner = map_data.get_region(n_id)
			var n_faction = ""
			
			if n_owner != "":
				if active_scenario.has("factions"):
					for f_name in active_scenario["factions"]:
						if active_scenario["factions"][f_name].has("cities") and n_owner in active_scenario["factions"][f_name]["cities"]:
							n_faction = f_name
							break
							
			# We draw a line ONLY if the neighboring tile is owned by a different faction, 
			# or if it's unowned (wilderness), BUT NOT if it is water (ocean/lake).
			if n_faction != owning_faction:
				var n_terrain = map_data.get_terrain(n_id).to_lower()
				if n_terrain == "ocean" or n_terrain == "lake":
					continue
					
				var c1_list = _get_global_corners(tile_id)
				var c2_list = _get_global_corners(n_id)
				var shared_verts: Array[Vector3] = []
				
				for c1 in c1_list:
					for c2 in c2_list:
						if c1.distance_to(c2) < 0.001:
							shared_verts.append(c1)
							break
							
				if shared_verts.size() == 2:
					# Sort verts so A_B is same as B_A
					var v0 = shared_verts[0]
					var v1 = shared_verts[1]
					var key1 = "%.4f,%.4f,%.4f_%.4f,%.4f,%.4f" % [v0.x, v0.y, v0.z, v1.x, v1.y, v1.z]
					var key2 = "%.4f,%.4f,%.4f_%.4f,%.4f,%.4f" % [v1.x, v1.y, v1.z, v0.x, v0.y, v0.z]
					
					if not drawn_edges.has(key1) and not drawn_edges.has(key2):
						drawn_edges[key1] = true
						drawn_edges[key2] = true
						
						if not edges_by_faction.has(owning_faction):
							edges_by_faction[owning_faction] = []
						edges_by_faction[owning_faction].append([v0, v1])
						
	for faction_name in edges_by_faction.keys():
		var edge_list = edges_by_faction[faction_name]
		var col_str = ""
		if active_scenario.has("factions") and active_scenario["factions"].has(faction_name):
			col_str = active_scenario["factions"][faction_name].get("color", "#FFFFFF")
		var faction_color = Color(col_str)
		# Dim the color by 50%
		faction_color = faction_color * 0.5
		faction_color.a = 1.0 # Ensure fully opaque
		
		# Elevated slightly to prevent z-fighting with the globe surface
		outline_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for edge in edge_list:
			var p1 = edge[0] * 1.002
			var p2 = edge[1] * 1.002
			var center = (p1 + p2) * 0.5
			var up = center.normalized()
			var fwd = (p2 - p1).normalized()
			if fwd.length() > 0.0001:
				var right = fwd.cross(up).normalized()
				var hw = 0.0006 # Thinner lines. Tile width ~0.006.
				
				var v1 = p1 - right * hw
				var v2 = p1 + right * hw
				var v3 = p2 + right * hw
				var v4 = p2 - right * hw
				
				outline_immediate_mesh.surface_set_color(faction_color)
				outline_immediate_mesh.surface_add_vertex(v1)
				outline_immediate_mesh.surface_set_color(faction_color)
				outline_immediate_mesh.surface_add_vertex(v2)
				outline_immediate_mesh.surface_set_color(faction_color)
				outline_immediate_mesh.surface_add_vertex(v3)
				
				outline_immediate_mesh.surface_set_color(faction_color)
				outline_immediate_mesh.surface_add_vertex(v1)
				outline_immediate_mesh.surface_set_color(faction_color)
				outline_immediate_mesh.surface_add_vertex(v3)
				outline_immediate_mesh.surface_set_color(faction_color)
				outline_immediate_mesh.surface_add_vertex(v4)
		outline_immediate_mesh.surface_end()
						
	var total_factions = edges_by_faction.keys().size()
	print("GlobeView: Finished Faction Borders. Factions drawn: ", total_factions)
	for f in edges_by_faction.keys():
		print(" - Faction: ", f, " edges: ", edges_by_faction[f].size())

func _get_global_corners(tile_id: String) -> Array[Vector3]:
	var parts = tile_id.split("_")
	if parts.size() < 3: return []
	
	var face_str = parts[0]
	var x = parts[1].to_int()
	var y = parts[2].to_int()
	var face = -1
	
	var face_names = ["FRONT", "BACK", "LEFT", "RIGHT", "TOP", "BOTTOM"]
	face = face_names.find(face_str)
	if face == -1: return []
	
	var RESOLUTION = 361
	var cx1 = (float(x) / RESOLUTION) * 2.0 - 1.0
	var cx2 = (float(x + 1) / RESOLUTION) * 2.0 - 1.0
	var cy1 = (float(y) / RESOLUTION) * 2.0 - 1.0
	var cy2 = (float(y + 1) / RESOLUTION) * 2.0 - 1.0
	
	var corners2d = [
	   Vector2(cx1, cy1),
	   Vector2(cx2, cy1),
	   Vector2(cx2, cy2),
	   Vector2(cx1, cy2)
	]
	
	var corners3d: Array[Vector3] = []
	for c in corners2d:
		var p = _get_sphere_point(face, c.x, c.y).normalized() * radius
		corners3d.append(p)
		
	return corners3d

func _get_sphere_point(face: int, local_x: float, local_y: float) -> Vector3:
	match face:
		0: return Vector3(local_x, -local_y, 1.0)
		1: return Vector3(-local_x, -local_y, -1.0)
		2: return Vector3(-1.0, -local_y, local_x)
		3: return Vector3(1.0, -local_y, -local_x)
		4: return Vector3(local_x, 1.0, local_y)
		5: return Vector3(local_x, -1.0, -local_y)
		_: return Vector3.ZERO

## Public function to sync this view from external changes (e.g. 2D map panning)
func set_focus(longitude: float, latitude: float) -> void:
	current_longitude = longitude
	current_latitude = latitude
	_update_camera()

func _spawn_unit(unit_def: Dictionary, faction_name: String, c_dict: Dictionary, faction_regions: Dictionary) -> void:
	if unit_def.has("latitude") and unit_def.has("longitude"):
		var lat = unit_def["latitude"]
		var lon = unit_def["longitude"]
		var raw_pos = _lat_lon_to_vector3(deg_to_rad(lat), deg_to_rad(lon), radius)
		
		var tile_id = _get_tile_from_vector3(raw_pos)
		var tile_width = _get_tile_width(tile_id)
		
		var unit = GlobeUnitScript.new()
		# Snap exactly to globe bounds for zero-parallax since shader uses no_depth_test
		unit.radius = radius
		unit.name = "Unit_LatLon_" + str(int(lat * 10)) + "_" + str(int(lon * 10))
		add_child(unit)
		if faction_name != "":
			unit.faction_name = faction_name
			unit.is_friendly = (faction_name == _get_local_faction())
			var faction = _get_faction_data(faction_name)
			if faction.has("color"):
				unit.set_faction_color(faction["color"])
		
		if unit.has_method("set_sizing"):
			unit.set_sizing(tile_width)
			
		if unit_def.has("entrenched") and unit_def["entrenched"] == true:
			unit.entrenched = true
			unit.time_motionless = 30.0
			if unit.entrench_bar:
				unit.entrench_bar.visible = true
			
		unit.spawn(raw_pos)
		units_list.append(unit)
		cullable_nodes.append(unit)
		return

	if not unit_def.has("location"):
		return
		
	var loc = unit_def["location"]
	
	if loc == "border":
		var count = unit_def.get("count", 5)
		var keys = faction_regions.keys()
		# Find the faction dictionary from scenario_data
		var scenario_factions = map_data._region_map # Wait, we need the original scenario data. We don't have it passed here directly except faction_name.
		# For this prototype we can query the dictionary we passed in... wait, c_dict is just cities. 
		# We need to compute the color here.
		
		if keys.size() >= 2:
			# For this generic prototype, assume the border is between the first two loaded factions
			_spawn_border_units(count, keys[0], keys[1], faction_regions, faction_name)
		return
		
	if c_dict.has(loc):
		var lat = c_dict[loc].get("latitude")
		var lon = c_dict[loc].get("longitude")
		if lat != null and lon != null:
			var raw_pos = _lat_lon_to_vector3(deg_to_rad(lat), deg_to_rad(lon), radius)
			
			var tile_id = _get_tile_from_vector3(raw_pos)
			var tile_width = _get_tile_width(tile_id)
			
			var unit = GlobeUnitScript.new()
			unit.radius = radius
			unit.name = "Unit_City_" + loc
			add_child(unit)
			if faction_name != "":
				unit.faction_name = faction_name
				unit.is_friendly = (faction_name == _get_local_faction())
				var faction = _get_faction_data(faction_name)
				if faction.has("color"):
					unit.set_faction_color(faction["color"])
					
			if unit.has_method("set_sizing"):
				unit.set_sizing(tile_width)

			if unit_def.has("entrenched") and unit_def["entrenched"] == true:
				unit.entrenched = true
				unit.time_motionless = 30.0
				if unit.entrench_bar:
					unit.entrench_bar.visible = true
				
			unit.spawn(raw_pos)
			units_list.append(unit)
			cullable_nodes.append(unit) # GlobeUnit itself handles tracking/visibility or we use unit.sprite depending on logic
	elif map_data.get_centroid(loc) != Vector3.ZERO:
		var raw_pos = map_data.get_centroid(loc).normalized() * radius
		
		var tile_width = _get_tile_width(loc)
		
		var unit = GlobeUnitScript.new()
		unit.radius = radius
		unit.name = "Unit_Region_" + loc
		add_child(unit)
		if faction_name != "":
			unit.faction_name = faction_name
			unit.is_friendly = (faction_name == _get_local_faction())
			var faction = _get_faction_data(faction_name)
			if faction.has("color"):
				unit.set_faction_color(faction["color"])
				
		if unit.has_method("set_sizing"):
			unit.set_sizing(tile_width)
			
		if unit_def.has("entrenched") and unit_def["entrenched"] == true:
			unit.entrenched = true
			unit.time_motionless = 30.0
			if unit.entrench_bar:
				unit.entrench_bar.visible = true
			
		unit.spawn(raw_pos)
		units_list.append(unit)
		cullable_nodes.append(unit)

func _get_faction_data(faction_name: String) -> Dictionary:
	if active_scenario.has("factions"):
		if active_scenario["factions"].has(faction_name):
			return active_scenario["factions"][faction_name]
	return {}

func _get_local_faction() -> String:
	if NetworkManager and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var id = multiplayer.get_unique_id()
		if NetworkManager.players.has(id):
			return NetworkManager.players[id].get("faction", "")
	return ""

func _spawn_border_units(count: int, faction1: String, faction2: String, faction_regions: Dictionary, owning_faction: String) -> void:
	var f1_regs = faction_regions[faction1]
	var f2_regs = faction_regions[faction2]
	
	var border_tiles = []
	var keys = map_data._region_map.keys()
	
	# Sweep the culled active map to find tiles owned by f1 that touch tiles owned by f2
	for tile_id in keys:
		var r = map_data._region_map[tile_id]
		if f1_regs.has(r):
			var neighbors = map_data.get_neighbors(tile_id)
			for n in neighbors:
				var nr = map_data.get_region(n)
				if f2_regs.has(nr):
					border_tiles.append(tile_id)
					break
					
	if border_tiles.is_empty():
		print("GlobeView: No border found between ", faction1, " and ", faction2)
		return
		
	var faction_data = _get_faction_data(owning_faction)
		
	# Spread the specified unit count out evenly along the computed border arc
	var step = max(1, int(border_tiles.size() / count))
	for i in range(count):
		var idx = (i * step) % border_tiles.size()
		var tid = border_tiles[idx]
		
		var raw_pos = map_data.get_centroid(tid).normalized() * radius
		var tile_width = _get_tile_width(tid)
		var unit = GlobeUnitScript.new()
		unit.radius = radius
		unit.name = "Unit_Border_" + owning_faction + "_" + str(i)
		unit.faction_name = owning_faction
		unit.is_friendly = (owning_faction == _get_local_faction())
		add_child(unit)
		if faction_data.has("color"):
			unit.set_faction_color(faction_data["color"])
			
		if unit.has_method("set_sizing"):
			unit.set_sizing(tile_width)
			
		unit.spawn(raw_pos)
		units_list.append(unit)
		cullable_nodes.append(unit)
