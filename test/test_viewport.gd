extends Node3D

func _ready():
    var mesh_instance = MeshInstance3D.new()
    add_child(mesh_instance)
    
    var mesh = SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    mesh_instance.mesh = mesh
    
    var mat = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    
    var img = Image.new()
    var err = img.load("res://src/assets/biome_map.png")
    if err == OK:
        var tex = ImageTexture.create_from_image(img)
        mat.albedo_texture = tex
        mesh.material = mat
        print("Test OK - assigned material directly to mesh")
    else:
        print("Test FAILED to load image")
        
    get_tree().quit()
