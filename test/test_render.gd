extends GutTest

func test_basic_render():
    var vp = SubViewport.new()
    vp.size = Vector2(800, 600)
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child_autoqfree(vp)
    
    var root = Node3D.new()
    vp.add_child(root)
    
    var cam = Camera3D.new()
    cam.position = Vector3(0, 0, 3)
    root.add_child(cam)
    
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

    await wait_frames(5)
    
    if DisplayServer.get_name() != "headless":
        var img = vp.get_texture().get_image()
        assert_not_null(img, "Should extract an image from the viewport.")
    else:
        assert_not_null(vp.get_texture(), "Headless viewport texture extraction.")
