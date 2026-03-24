extends Node3D

var start_pos: Vector3
var end_pos: Vector3
var is_strategic: bool
var target_hit: bool
var shot_down: bool
var radius: float = 1.0
var duration: float = 1.0

var t: float = 0.0
var speed: float = 1.0
var max_t: float = 1.0

var sprite_inst: Sprite3D

func init_animation(p_start: Vector3, p_end: Vector3, p_is_strategic: bool, p_target_hit: bool, p_shot_down: bool, p_color: Color, p_radius: float, p_duration_override: float = -1.0):
	start_pos = p_start
	end_pos = p_end
	is_strategic = p_is_strategic
	target_hit = p_target_hit
	shot_down = p_shot_down
	radius = p_radius
	
	duration = 1.5 if is_strategic else 1.0
	if p_duration_override > 0.0:
		duration = p_duration_override
	speed = 1.0 / duration
	max_t = 0.6 if shot_down else 1.0
	
	sprite_inst = Sprite3D.new()
	var exact_tile_width = (PI * radius) / 512.0
	sprite_inst.pixel_size = (exact_tile_width * 1.5) / 34.0
	sprite_inst.transparent = true
	sprite_inst.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite_inst.modulate = p_color
	
	var atlas = load("res://src/assets/spritesheet.png") as Texture2D
	if atlas:
		var img = atlas.get_image()
		if img:
			var region = Rect2(0, 64, 32, 32)
			var cropped_img = img.get_region(region)
			if cropped_img.get_format() != Image.FORMAT_RGBA8:
				cropped_img.convert(Image.FORMAT_RGBA8)
			var padded_img = Image.create(34, 34, false, Image.FORMAT_RGBA8)
			padded_img.fill(Color(0, 0, 0, 0))
			padded_img.blend_rect(cropped_img, Rect2(0, 0, 32, 32), Vector2(1, 1))
			sprite_inst.texture = ImageTexture.create_from_image(padded_img)

	add_child(sprite_inst)
	position = start_pos

func _process(delta: float) -> void:
	t += speed * delta
	if t >= max_t:
		_finish()
		return
		
	var _t = clampf(t, 0.0, 1.0)
	var pos = start_pos.slerp(end_pos, _t)
	position = pos.normalized() * (radius + 0.02)
	
	var look_t = clampf(_t + 0.05, 0.0, 1.0)
	var look_pos = start_pos.slerp(end_pos, look_t).normalized() * (radius + 0.02)
	
	if position.distance_to(look_pos) > 0.001:
		var forward = (look_pos - position).normalized()
		var normal = position.normalized()
		var right = forward.cross(normal).normalized()
		
		# Ensure orthogonality
		forward = normal.cross(right).normalized()
		
		# Set basis so the sprite lies flat on the globe surface
		# +Y (Top of sprite) = forward
		# +Z (Face of sprite) = normal (pointing out from globe)
		# +X = right
		var new_basis = Basis(right, forward, normal)
		sprite_inst.global_transform.basis = new_basis

func _finish():
	if target_hit:
		var flash = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.03
		sphere.height = 0.06
		flash.mesh = sphere
		var f_mat = StandardMaterial3D.new()
		f_mat.albedo_color = Color(1.0, 0.5, 0.0)
		f_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		f_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flash.material_override = f_mat
		get_parent().add_child(flash)
		flash.position = end_pos.normalized() * (radius + 0.01)
		var f_twn = get_tree().create_tween()
		f_twn.tween_property(f_mat, "albedo_color:a", 0.0, 0.5)
		f_twn.tween_callback(flash.queue_free)
	queue_free()
