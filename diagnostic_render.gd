extends SceneTree

func _init():
    print("-- INIT DIAGNOSTIC RENDER --")
    var root = Node3D.new()
    
    var vp = SubViewport.new()
    vp.size = Vector2(800, 600)
    vp.transparent_bg = true
    vp.render_target_update_mode = SubViewport.UPDATE_ONCE
    vp.add_child(root)
    get_root().add_child(vp)
    
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
    mat.albedo_color = Color.WHITE
    
    var tex = load("res://src/assets/biome_map.png")
    if tex:
        print("Texture loaded correctly! Class: ", tex.get_class())
        mat.albedo_texture = tex
    else:
        print("TEXTURE FAILED TO LOAD!")
        
    mesh_instance.material_override = mat
    
    # We must use self.process_frame inside SceneTree
    print("Waiting for render...")
    await self.process_frame
    await self.process_frame
    
    var img = vp.get_texture().get_image()
    var c_pixel = img.get_pixel(400, 300)
    print("CENTER PIXEL COLOR: ", c_pixel)
    img.save_png("diagnostic_render.png")
    print("Diagnostic image saved.")
    quit()
