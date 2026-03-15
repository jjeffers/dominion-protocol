extends SceneTree

func _init() -> void:
    var mesh = SphereMesh.new()
    
    var mat = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.vertex_color_use_as_albedo = false
    
    var img = Image.new()
    var err = img.load("res://src/assets/biome_map.png")
    if err == OK:
        var tex = ImageTexture.create_from_image(img)
        mat.albedo_texture = tex
        mesh.material = mat
        print("GLOBE: Assigned dynamic texture to SphereMesh.material directly")
    else:
        print("GlobeView: Failed to load biome_map.png dynamically!")
    quit()
