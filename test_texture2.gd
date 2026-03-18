extends SceneTree
func _init():
    var atlas = load("res://src/assets/spritesheet.png") as Texture2D
    var img = atlas.get_image()
    var cropped_img = img.get_region(Rect2(0, 64, 32, 32))
    cropped_img.save_png("test_air_save.png")
    
    var c4 = img.get_region(Rect2(0, 96, 32, 32))
    c4.save_png("test_air_row4.png")
    quit()
