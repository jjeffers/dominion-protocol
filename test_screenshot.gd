extends SceneTree
func _init():
    var vp = SubViewport.new()
    vp.size = Vector2(800, 600)
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    vp.transparent_bg = false
    
    var root = Node3D.new()
    vp.add_child(root)
    get_root().add_child(vp)
    
    var cam = Camera3D.new()
    cam.position = Vector3(0, 0, 3)
    root.add_child(cam)
    
    var mesh_instance = MeshInstance3D.new()
    var mesh = load("res://src/data/globe_mesh.res")
    mesh_instance.mesh = mesh
    
    var img = Image.new()
    if img.load("res://src/assets/biome_map.png") == OK:
        var mat = StandardMaterial3D.new()
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.albedo_texture = ImageTexture.create_from_image(img)
        mesh_instance.material_override = mat
    root.add_child(mesh_instance)
    
    RenderingServer.frame_post_draw.connect(_on_rendered.bind(vp), CONNECT_ONE_SHOT)

func _on_rendered(vp):
    var out_img = vp.get_texture().get_image()
    if out_img == null:
        print("Failed to get image")
    else:
        var path = "res://debug_screenshot.png"
        out_img.save_png(path)
        print("Saved screenshot to ", path)
    quit()
