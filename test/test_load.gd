extends GutTest

func test_texture_loading():
    var tex = load("res://src/assets/biome_map.png")
    assert_not_null(tex, "Should load biome_map.png as CompressedTexture2D")



