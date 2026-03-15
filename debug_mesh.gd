extends SceneTree

func _init():
    var mesh = ResourceLoader.load("res://src/data/quadsphere_globe.res")
    var aabb = mesh.get_aabb()
    print("Mesh AABB size: ", aabb.size)
    print("Mesh bounds: ", aabb.position, " to ", aabb.position + aabb.size)
    var arr = mesh.surface_get_arrays(0)
    var verts = arr[Mesh.ARRAY_VERTEX]
    print("Total verts: ", verts.size())
    print("Sample verts:")
    for i in range(5):
        print("  ", verts[i])
    quit()
