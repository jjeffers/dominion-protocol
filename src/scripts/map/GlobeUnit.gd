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
	# Faded translucent white/gray
	path_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	path_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.4)
	path_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	path_mat.use_point_size = true
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
	# Draw line strip connecting current to target
	path_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	# Calculate number of segments based on angular distance, min 4, max 32
	var segments = clampi(int(angle * 30.0), 4, 32)
	
	for i in range(segments + 1):
		var w = i / float(segments)
		var p = current_position.slerp(target_position, w).normalized() * radius
		
		# Elevate slightly to prevent z-fighting with the globe surface
		path_immediate_mesh.surface_add_vertex(p * 1.002)
		
	path_immediate_mesh.surface_end()
