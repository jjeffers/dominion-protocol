extends GutTest

func test_mesh_type():
    var mesh = load("res://src/data/globe_mesh.res")
    assert_not_null(mesh, "Globe mesh resource should load.")



