extends GutTest

func test_biome_colors():
    assert_ne(Color("d2b48c"), Color(), "DESERT color parses correctly")
    assert_ne(Color("8b9c44"), Color(), "PLAINS color parses correctly")
    assert_ne(Color("3e6b2e"), Color(), "FOREST color parses correctly")
    assert_ne(Color("1a4a19"), Color(), "JUNGLE color parses correctly")
