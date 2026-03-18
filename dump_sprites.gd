extends SceneTree
func _init():
    var atlas = load("res://src/assets/spritesheet.png") as Texture2D
    var img = atlas.get_image()
    var r2 = img.get_region(Rect2(0, 32, 32, 32))
    r2.save_png("row2.png")
    var r4 = img.get_region(Rect2(0, 96, 32, 32))
    r4.save_png("row4.png")
    quit()
