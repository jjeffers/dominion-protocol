extends GutTest

func test_initialization():
    var unit_a = GlobeUnit.new()
    unit_a.name = "UnitA"
    unit_a.faction_name = "Blue"
    unit_a.radius = 1.02
    add_child_autoqfree(unit_a)
    unit_a._init()
    
    var tex = unit_a.sprite.texture
    assert_not_null(tex, "Sprite texture should be assigned.")
    
    var physical_width = tex.get_width() * unit_a.sprite.pixel_size * unit_a.sprite.scale.x
    assert_gt(physical_width, 0.0, "Visible 3D width should be calculated.")



