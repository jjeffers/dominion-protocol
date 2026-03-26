extends GutTest

func test_uvs_exist():
    var mesh = load("res://src/data/globe_mesh.res")
    
    if mesh is ArrayMesh:
        var arrays = mesh.surface_get_arrays(0)
        var uvs = arrays[Mesh.ARRAY_TEX_UV]
        assert_not_null(uvs, "UV array should exist in the globe_mesh.res")
        assert_gt(uvs.size(), 0, "UV array should have more than 0 elements")
    elif mesh is SphereMesh:
        assert_true(true, "SphereMesh auto-generates UVs.")
    else:
        fail_test("Mesh is neither ArrayMesh nor SphereMesh")



