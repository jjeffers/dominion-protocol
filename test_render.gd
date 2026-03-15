extends SceneTree

func _init():
    var root = Node3D.new()
    var vp = SubViewport.new()
    vp.size = Vector2(800, 600)
    vp.render_target_update_mode = SubViewport.UPDATE_ONCE
    vp.add_child(root)
    # The SceneTree needs to incorporate the viewport to process it
    root.set_process(true)
    
    var cam = Camera3D.new()
    cam.position = Vector3(0, 0, 3)
    root.add_child(cam)
    
    var light = DirectionalLight3D.new()
    light.rotation.x = -PI / 4.0
    root.add_child(light)

    var mesh_instance = MeshInstance3D.new()
    root.add_child(mesh_instance)
    
    var mesh = SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    mesh_instance.mesh = mesh
    
    var mat = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_texture = load("res://src/assets/biome_map.png")
    mesh_instance.material_override = mat

    # Add viewport to current scene tree
    get_root().add_child(vp)
    
    print("Waiting 2 frames for render...")
    await get_tree().process_frame
    await get_tree().process_frame
    
    var img = vp.get_texture().get_image()
    img.save_png("test_output.png")
    print("Saved test_output.png")
    quit()
