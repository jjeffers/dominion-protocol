class_name GlobeUnit
extends Node3D

var sprite: Sprite3D
var click_area: Area3D
var collision_shape: CollisionShape3D

var is_selected: bool = false
var current_tile_id: String = ""

var radius: float = 1.02
var current_position: Vector3
var target_position: Vector3

# Given ~6.28 circumference mapped across 1024 tiles
# 1 tile roughly equals 0.006 units
var speed_units_per_sec: float = 0.006

var path_mesh_instance: MeshInstance3D
var path_immediate_mesh: ImmediateMesh

func _init() -> void:
	# Setup Sprite
	sprite = Sprite3D.new()
	var img = Image.new()
	if img.load("res://src/assets/extracted_sprite.png") == OK:
		sprite.texture = ImageTexture.create_from_image(img)
	else:
		push_error("GlobeUnit: Failed to load extracted_sprite.png")
	
	# 34x34 sprite. 3 tiles = 0.0184 units across. 0.0184 / 34 = 0.00054 pixel_size
	sprite.pixel_size = 0.00054
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(sprite)
	
	# Setup Clickable Area
	click_area = Area3D.new()
	collision_shape = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	# Size is roughly half the width of the sprite
	shape.radius = 0.0092 
	collision_shape.shape = shape
	click_area.add_child(collision_shape)
	add_child(click_area)

	# Setup Path Drawing
	path_mesh_instance = MeshInstance3D.new()
	path_immediate_mesh = ImmediateMesh.new()
	path_mesh_instance.mesh = path_immediate_mesh
	
	var path_mat = StandardMaterial3D.new()
	# Glowing Yellow/White
	path_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	path_mat.albedo_color = Color(1.0, 1.0, 0.5, 0.8)
	path_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	path_mat.use_point_size = false
	
	# To make the line visible at varying distances, we use a thicker tube-like approach if standard line width isn't supported, but since ImmediateMesh line_strip thickness is fixed at 1px on most platforms, we just ensure it exists robustly.
	path_mesh_instance.material_override = path_mat
	
	# Add the path mesh as a sibling to the unit so it doesn't rotate relative to the unit's local transform
	# But wait, GlobeUnit IS a Node3D. If we add it as a child, its global position tracks the unit.
	# We want the path to be drawn in global space so it stays fixed relative to the globe.
	# The easiest way is to add it as a top-level child so it ignores the parent's transform:
	path_mesh_instance.top_level = true
	add_child(path_mesh_instance)

func spawn(pos: Vector3) -> void:
	current_position = pos.normalized() * radius
	target_position = current_position
	global_position = current_position
	
	# Point -Z axis straight into the core, meaning the +Z face (sprite) aims perfectly upwards from the surface
	look_at(Vector3.ZERO, Vector3.UP)

func set_target(pos: Vector3) -> void:
	target_position = pos.normalized() * radius

func _process(delta: float) -> void:
	if current_position.distance_to(target_position) > 0.0001:
		# Calculate angle between current and target
		var angle = current_position.angle_to(target_position)
		var distance = current_position.distance_to(target_position)
		
		# Move at constant speed along the arc
		var step = (speed_units_per_sec * delta) / radius
		var weight = min(step / angle, 1.0)
		
		current_position = current_position.slerp(target_position, weight).normalized() * radius
		global_position = current_position
		
		look_at(Vector3.ZERO, Vector3.UP)
		
		_draw_path(angle)
	else:
		# Arrived or stationary: clear path
		path_immediate_mesh.clear_surfaces()

func _draw_path(angle: float) -> void:
	path_immediate_mesh.clear_surfaces()
	path_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Calculate number of segments based on angular distance, min 4, max 32
	var segments = clampi(int(angle * 30.0), 4, 32)
	
	# ~1 tile width = 0.006 world units
	var path_width = 0.006
	var path_elevation = 1.03 # Float above the terrain peaks
	
	# Calculate arrowhead proportion (fixed world unit length, converted to percentage of path)
	var arrow_length_units = 0.02
	var total_distance = current_position.distance_to(target_position)
	var arrow_fraction = min(arrow_length_units / total_distance, 0.5) if total_distance > 0 else 0.5
	
	var arrow_start_segment = int(segments * (1.0 - arrow_fraction))
	
	# Store the vertices so we can stitch them into triangles
	var left_verts = []
	var right_verts = []
	
	# Draw the main line body
	for i in range(arrow_start_segment + 1):
		var w = i / float(segments)
		var p = current_position.slerp(target_position, w).normalized()
		
		# Figure out the forward direction at this exact point on the curve
		var forward = Vector3.ZERO
		if i < arrow_start_segment:
			var w_next = (i + 1) / float(segments)
			forward = (current_position.slerp(target_position, w_next).normalized() - p).normalized()
		else:
			# Last segment of line body, use previous as reference
			var w_prev = (i - 1) / float(segments)
			forward = (p - current_position.slerp(target_position, w_prev).normalized()).normalized()
			
		# The UP vector is just the normal extending from the core
		var up = p
		
		# The RIGHT vector is perpendicular to Forward and Up
		var right = forward.cross(up).normalized()
		
		var left_point = (p * radius * path_elevation) - (right * path_width * 0.5)
		var right_point = (p * radius * path_elevation) + (right * path_width * 0.5)
		
		left_verts.append(left_point)
		right_verts.append(right_point)
		
	# Build Triangles for the main line body
	for i in range(left_verts.size() - 1):
		var tl = left_verts[i]
		var tr = right_verts[i]
		var bl = left_verts[i+1]
		var br = right_verts[i+1]
		
		# Triangle 1: TopLeft, BottomLeft, TopRight
		path_immediate_mesh.surface_add_vertex(tl)
		path_immediate_mesh.surface_add_vertex(bl)
		path_immediate_mesh.surface_add_vertex(tr)
		
		# Triangle 2: TopRight, BottomLeft, BottomRight
		path_immediate_mesh.surface_add_vertex(tr)
		path_immediate_mesh.surface_add_vertex(bl)
		path_immediate_mesh.surface_add_vertex(br)

	# Draw the Arrowhead (spanning from arrow_start_segment to the target_position)
	# The base of the arrow should be twice as wide as the path
	var arrow_width = path_width * 3.0
	
	var arrow_base_w = arrow_start_segment / float(segments)
	var arrow_base_p = current_position.slerp(target_position, arrow_base_w).normalized()
	
	var arrow_tip_p = target_position.normalized()
	var arrow_forward = (arrow_tip_p - arrow_base_p).normalized()
	var arrow_up = arrow_base_p
	var arrow_right = arrow_forward.cross(arrow_up).normalized()
	
	var arrow_base_left = (arrow_base_p * radius * path_elevation) - (arrow_right * arrow_width * 0.5)
	var arrow_base_right = (arrow_base_p * radius * path_elevation) + (arrow_right * arrow_width * 0.5)
	var arrow_tip = arrow_tip_p * radius * path_elevation
	
	# Arrow Triangle: BaseLeft, Tip, BaseRight
	path_immediate_mesh.surface_add_vertex(arrow_base_left)
	path_immediate_mesh.surface_add_vertex(arrow_tip)
	path_immediate_mesh.surface_add_vertex(arrow_base_right)
	
	path_immediate_mesh.surface_end()
