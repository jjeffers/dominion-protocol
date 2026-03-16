extends SceneTree

var globe_unit_scene = load("res://src/scripts/map/GlobeUnit.gd")

func _init():
    var unit_a = globe_unit_scene.new()
    unit_a.name = "UnitA"
    unit_a.faction_name = "Blue"
    unit_a.radius = 1.02
    root.add_child(unit_a)
    unit_a._init()
    
    # Check sprite dimensions
    var tex = unit_a.sprite.texture
    if tex:
        print("Texture size: ", tex.get_size())
        print("Pixel size (m): ", unit_a.sprite.pixel_size)
        print("Unit A scale: ", unit_a.sprite.scale)
        var physical_width = tex.get_width() * unit_a.sprite.pixel_size * unit_a.sprite.scale.x
        print("Visible 3D width: ", physical_width)
        print("Visual overlap radius: ", physical_width * 0.5)
        
    quit(0)
