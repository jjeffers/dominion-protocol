class_name TacticalView
extends Node2D

signal focus_changed(longitude: float, latitude: float)
signal bounds_changed(min_lon: float, max_lon: float, min_lat: float, max_lat: float)

var map_data: MapData

@onready var map_layer: Node2D = $MapLayer
@onready var camera: Camera2D = $Camera2D

var tile_size: int = 64
var current_longitude: float = 0.0
var current_latitude: float = 0.0

var _is_dragging: bool = false
var _drag_start_pos: Vector2
var _drag_start_cam_pos: Vector2

var _visible_rect_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	if not map_data:
		map_data = MapData.new(64, 32)
		map_data.generate_prototype_continents()
		
	camera.zoom = Vector2(0.3, 0.3)
	
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	queue_redraw()

func _on_viewport_size_changed() -> void:
	var vp_size = get_viewport_rect().size
	_visible_rect_size = vp_size
	_emit_bounds()

func _get_terrain_color(terrain: MapData.TerrainType) -> Color:
	match terrain:
		MapData.TerrainType.OCEAN: return Color("1f669c")
		MapData.TerrainType.LAKES: return Color("3a86c4")
		MapData.TerrainType.PLAINS: return Color("8b9c44")
		MapData.TerrainType.WOODS: return Color("3e6b2e")
		MapData.TerrainType.MOUNTAINS: return Color("736b60")
		_: return Color.MAGENTA

func _draw() -> void:
	if not map_data:
		return
		
	# Draw the whole map for now.
	# In a real scenario, we'd only draw the visible tiles based on camera position.
	# To handle wrapping, we draw 3 copies (left, center, right)
	
	var map_width_px = map_data.grid_width * tile_size
	
	var view_width = _visible_rect_size.x / camera.zoom.x
	var view_height = _visible_rect_size.y / camera.zoom.y
	
	var view_left = camera.position.x - view_width / 2.0
	var view_right = camera.position.x + view_width / 2.0
	var view_top = camera.position.y - view_height / 2.0
	var view_bottom = camera.position.y + view_height / 2.0
	
	for offset_mod in range(-1, 2):
		var offset_x = offset_mod * map_width_px
		
		var chunk_left = offset_x
		var chunk_right = offset_x + map_width_px
		
		# Skip chunk if not in view
		if view_right < chunk_left or view_left > chunk_right:
			continue
			
		var start_x = clampi(int((view_left - offset_x) / tile_size), 0, map_data.grid_width - 1)
		var end_x = clampi(int((view_right - offset_x) / tile_size), 0, map_data.grid_width - 1)
		
		var start_y = clampi(int(view_top / tile_size), 0, map_data.grid_height - 1)
		var end_y = clampi(int(view_bottom / tile_size), 0, map_data.grid_height - 1)
			
		for y in range(start_y, end_y + 1):
			for x in range(start_x, end_x + 1):
				var rect = Rect2(
					offset_x + x * tile_size, 
					y * tile_size, 
					tile_size, 
					tile_size
				)
				var terrain = map_data.get_terrain(x, y)
				var color = _get_terrain_color(terrain)
				
				# Filled rect
				draw_rect(rect, color)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = true
				_drag_start_pos = event.position
				_drag_start_cam_pos = camera.position
			else:
				_is_dragging = false
	
	elif event is InputEventMouseMotion and _is_dragging:
		var delta = event.position - _drag_start_pos
		var new_cam_pos = _drag_start_cam_pos - (delta / camera.zoom)
		
		# Clamp Y (latitude)
		var map_height_px = map_data.grid_height * tile_size
		var view_height = _visible_rect_size.y / camera.zoom.y
		var min_y = view_height / 2.0
		var max_y = map_height_px - view_height / 2.0
		
		# Allow panning if map is bigger than screen, otherwise center it
		if map_height_px > view_height:
			new_cam_pos.y = clamp(new_cam_pos.y, min_y, max_y)
		else:
			new_cam_pos.y = map_height_px / 2.0
		
		# Wrap X (longitude)
		var map_width_px = map_data.grid_width * tile_size
		new_cam_pos.x = wrapf(new_cam_pos.x, 0, map_width_px)
		
		camera.position = new_cam_pos
		queue_redraw() # Re-evaluate which chunks to draw
		
		# Calculate lat/lon and emit
		
		var lon_pct = new_cam_pos.x / map_width_px
		var lat_pct = new_cam_pos.y / map_height_px
		
		# Linear longitude
		current_longitude = lerp(-PI, PI, lon_pct)
		# CEA Latitude (Y maps linearly to sine of latitude)
		var l_sin = lerp(1.0, -1.0, lat_pct)
		current_latitude = asin(clamp(l_sin, -1.0, 1.0))
		
		focus_changed.emit(current_longitude, current_latitude)
		_emit_bounds()

func set_focus(longitude: float, latitude: float) -> void:
	current_longitude = longitude
	current_latitude = latitude
	
	if not map_data:
		return
		
	var map_width_px = map_data.grid_width * tile_size
	var map_height_px = map_data.grid_height * tile_size
	
	var lon_pct = inverse_lerp(-PI, PI, longitude)
	var target_x = lon_pct * map_width_px
	
	# Inverse CEA Latitude (pixel Y is linear to sine of latitude)
	var lat_pct = inverse_lerp(1.0, -1.0, sin(latitude))
	var target_y = lat_pct * map_height_px
	
	var view_height = _visible_rect_size.y / camera.zoom.y
	# Still clamp Y just in case
	var min_y = view_height / 2.0
	var max_y = map_height_px - view_height / 2.0
	if map_height_px > view_height:
		target_y = clamp(target_y, min_y, max_y)
	
	camera.position = Vector2(target_x, target_y)
	queue_redraw()
	_emit_bounds()

func _emit_bounds() -> void:
	if not map_data or _visible_rect_size.x == 0:
		return
		
	var map_width_px = map_data.grid_width * tile_size
	var map_height_px = map_data.grid_height * tile_size
	
	var view_width = _visible_rect_size.x / camera.zoom.x
	var view_height = _visible_rect_size.y / camera.zoom.y
	
	var half_w = view_width / 2.0
	var half_h = view_height / 2.0
	
	var min_x = camera.position.x - half_w
	var max_x = camera.position.x + half_w
	var min_y = camera.position.y - half_h
	var max_y = camera.position.y + half_h
	
	var min_lon = lerp(-PI, PI, min_x / float(map_width_px))
	var max_lon = lerp(-PI, PI, max_x / float(map_width_px))
	
	var max_lat_sin = lerp(1.0, -1.0, min_y / float(map_height_px))
	var min_lat_sin = lerp(1.0, -1.0, max_y / float(map_height_px))
	
	var max_lat = asin(clamp(max_lat_sin, -1.0, 1.0))
	var min_lat = asin(clamp(min_lat_sin, -1.0, 1.0))
	
	bounds_changed.emit(min_lon, max_lon, min_lat, max_lat)
