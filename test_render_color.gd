extends SceneTree
func _init():
    print("Testing Texture rendering...")
    var root = Node3D.new()
    
    var vp = SubViewport.new()
    vp.size = Vector2(800, 600)
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    vp.add_child(root)
    get_root().add_child(vp)
    
    var cam = Camera3D.new()
    cam.position = Vector3(0, 0, 3)
    root.add_child(cam)
    
    var mesh_instance = MeshInstance3D.new()
    mesh_instance.mesh = load("res://src/data/globe_mesh.res")
    root.add_child(mesh_instance)
    
    var img = Image.new()
    var err = img.load("res://src/assets/biome_map.png")
    if err == OK:
        var mat = StandardMaterial3D.new()
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.albedo_texture = ImageTexture.create_from_image(img)
        mesh_instance.material_override = mat
        print("Material overridden")
    else:
        print("Failed to load map")
        
    RenderingServer.frame_post_draw.connect(_on_rendered.bind(vp), CONNECT_ONE_SHOT)

func _on_rendered(vp):
    var out_img = vp.get_texture().get_image()
    if out_img == null:
        print("Failed to get image from viewport")
        quit()
        return
        
    var center_pixel = out_img.get_pixel(400, 300)
    var other_pixel = out_img.get_pixel(400, 100)
    print("Center Pixel (400, 300): ", center_pixel)
    print("Other Pixel (400, 100): ", other_pixel)
    quit()
