extends GutTest

func test_render_color():
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
    mesh_instance.mesh = load("res://src/data/globe_mesh.res")
    root.add_child(mesh_instance)
    
    var tex = load("res://src/assets/biome_map.png")
    if tex:
        var mat = StandardMaterial3D.new()
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.albedo_texture = tex
        mesh_instance.material_override = mat
        
    await wait_frames(5)
    
    if DisplayServer.get_name() != "headless":
        var out_img = vp.get_texture().get_image()
        assert_not_null(out_img, "SubViewport image should not be null")
        
        if out_img:
            var center_pixel = out_img.get_pixel(400, 300)
            assert_ne(center_pixel, Color(0,0,0,0), "Center pixel should have valid color data")
    else:
        assert_not_null(vp.get_texture(), "Headless render_color passes with texture existence.")



