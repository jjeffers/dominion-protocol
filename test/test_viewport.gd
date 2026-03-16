extends GutTest

func test_viewport_load():
    var mesh_instance = MeshInstance3D.new()
    add_child_autoqfree(mesh_instance)
    
    var mesh = SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    mesh_instance.mesh = mesh
    
    var mat = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    
    var tex = load("res://src/assets/biome_map.png")
    assert_not_null(tex, "Should load biome_map.png without error")
    if tex:
        mat.albedo_texture = tex
        mesh.material = mat
        
    await wait_frames(1)
    assert_not_null(mesh.material, "Material must be assigned to mesh")
