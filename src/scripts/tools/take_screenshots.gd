extends SceneTree

func _init() -> void:
    var root = Node3D.new()
    var mesh_instance = MeshInstance3D.new()
    mesh_instance.mesh = load("res://src/data/globe_mesh.res")
    
    var mat = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(1,1,1)
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    # mesh_instance.material_override = mat # Do not override the globe's native material
    root.add_child(mesh_instance)
    
    var camera = Camera3D.new()
    root.add_child(camera)
    camera.transform = Transform3D(Basis(), Vector3(0, 0, 3.0))
    
    var sub_window = SubViewport.new()
    sub_window.size = Vector2i(1024, 1024)
    sub_window.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    sub_window.add_child(root)
    self.root.add_child(sub_window)
    
    await self.process_frame
    await self.process_frame
    
    var img = sub_window.get_texture().get_image()
    img.save_png("res://render_front.png")
    
    # Render back face
    camera.transform = camera.transform.rotated(Vector3.UP, PI)
    await self.process_frame
    await self.process_frame
    img = sub_window.get_texture().get_image()
    img.save_png("res://render_back.png")
    
    # Render +Y top face
    camera.transform = Transform3D(Basis(), Vector3(0, 3.0, 0))
    camera.transform = camera.transform.looking_at(Vector3.ZERO, Vector3.FORWARD)
    await self.process_frame
    await self.process_frame
    img = sub_window.get_texture().get_image()
    img.save_png("res://render_top.png")

    print("Rendered test images")
    quit()
