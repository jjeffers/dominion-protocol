extends Node3D

var start_pos: Vector3
var end_pos: Vector3
var duration: float = 10.0
var radius: float = 1.0

var t: float = 0.0
var speed: float = 1.0

var mesh_inst: MeshInstance3D
var immediate_mesh: ImmediateMesh
var missile_head: MeshInstance3D

var trail_points: PackedVector3Array = []

func init_animation(p_start: Vector3, p_end: Vector3, p_radius: float, p_duration: float, p_color: Color):
	start_pos = p_start
	end_pos = p_end
	radius = p_radius
	duration = p_duration
	speed = 1.0 / duration
	
	immediate_mesh = ImmediateMesh.new()
	mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = immediate_mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = p_color
	mat.emission_enabled = true
	mat.emission = p_color
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	
	missile_head = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.0015 * p_radius
	sphere.height = 0.003 * p_radius
	missile_head.mesh = sphere
	
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color.WHITE
	head_mat.emission_enabled = true
	head_mat.emission = Color.WHITE
	head_mat.emission_energy_multiplier = 8.0
	head_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	missile_head.material_override = head_mat
	add_child(missile_head)
	
	position = Vector3.ZERO
	trail_points.append(start_pos)

func _process(delta: float) -> void:
	t += speed * delta
	if t >= 1.0:
		_finish()
		return
		
	var _t = clampf(t, 0.0, 1.0)
	
	# Base position on the surface of the sphere
	var surface_pos = start_pos.slerp(end_pos, _t)
	
	var dist_dot = start_pos.normalized().dot(end_pos.normalized())
	dist_dot = clampf(dist_dot, -1.0, 1.0)
	var angle = acos(dist_dot)
	
	# Max height is scaled up to 35% of the radius based on distance
	var max_height = radius * max(0.1, (angle / PI) * 0.35) 
	var current_height = sin(PI * _t) * max_height
	
	var current_pos = surface_pos.normalized() * (radius + current_height)
	missile_head.position = current_pos
	
	# Add point to trail periodically (prevent too many points but smooth enough)
	if trail_points.size() == 0 or trail_points[trail_points.size() - 1].distance_to(current_pos) > (0.005 * radius):
		trail_points.append(current_pos)
		
	_draw_trail()

func _draw_trail():
	immediate_mesh.clear_surfaces()
	
	var pts = trail_points.duplicate()
	pts.append(missile_head.position)
	
	if pts.size() < 2:
		return
		
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var trail_thickness = radius * 0.0008
	
	for i in range(pts.size() - 1):
		var p1 = pts[i]
		var p2 = pts[i+1]
		
		# Skip overlapping points to avoid bad cross products
		if p1.distance_to(p2) < 0.0001:
			continue
			
		var forward = (p2 - p1).normalized()
		var up = p1.normalized()
		var right = forward.cross(up).normalized()
		if right.length_squared() < 0.001:
			right = Vector3.UP.cross(up).normalized()
			
		var r_offset = right * trail_thickness
		
		var v11 = p1 - r_offset
		var v12 = p1 + r_offset
		var v21 = p2 - r_offset
		var v22 = p2 + r_offset
		
		immediate_mesh.surface_add_vertex(v11)
		immediate_mesh.surface_add_vertex(v21)
		immediate_mesh.surface_add_vertex(v22)
		
		immediate_mesh.surface_add_vertex(v11)
		immediate_mesh.surface_add_vertex(v22)
		immediate_mesh.surface_add_vertex(v12)
		
	immediate_mesh.surface_end()

func _finish():
	queue_free()
