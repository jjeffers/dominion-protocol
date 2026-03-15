extends SceneTree
func _init():
    var mesh = load("res://src/data/globe_mesh.res")
    if mesh is ArrayMesh:
        var arrays = mesh.surface_get_arrays(0)
        var uvs = arrays[Mesh.ARRAY_TEX_UV]
        if uvs != null and uvs.size() > 0:
            print("UVs exist! First 5: ", uvs.slice(0, 5))
        else:
            print("NO UVS FOUND IN globe_mesh.res!")
    elif mesh is SphereMesh:
        print("It's a SphereMesh, Godot auto-generates UVs.")
    quit()
