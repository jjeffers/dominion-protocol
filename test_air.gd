extends SceneTree
func _init():
    var glob = load("res://src/scripts/map/GlobeUnit.gd").new()
    glob.unit_type = "Air"
    if glob.sprite.texture == null:
        print("ERROR: texture is null!")
    else:
        print("Texture loaded successfully!")
    quit()
