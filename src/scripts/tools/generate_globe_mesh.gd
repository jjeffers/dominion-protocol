extends SceneTree

func _init():
    print("Baking SphereMesh and Material cache...")
    var sphere = SphereMesh.new()
    sphere.radius = 1.0
    sphere.height = 2.0
    sphere.radial_segments = 128
    sphere.rings = 64
    
    var mat = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    
    var img = Image.new()
    var err_img = img.load("res://src/assets/biome_map.png")
    if err_img == OK:
        var tex = ImageTexture.create_from_image(img)
        mat.albedo_texture = tex
        print("Texture linked successfully.")
    else:
        print("Error: Could not load texture!")
        
    sphere.material = mat
    
    var err = ResourceSaver.save(sphere, "res://src/data/globe_mesh.res")
    if err == OK:
        print("Successfully saved res://src/data/globe_mesh.res")
    else:
        print("Failed to save resource!")
        
    quit()
