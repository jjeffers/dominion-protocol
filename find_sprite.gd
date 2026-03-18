extends SceneTree
func _init():
    var atlas = load("res://src/assets/spritesheet.png") as Texture2D
    var img = atlas.get_image()
    for row in range(16):
        var is_blank = true
        var cropped = img.get_region(Rect2(0, row*32, 32, 32))
        for y in range(32):
            for x in range(32):
                if cropped.get_pixel(x, y).a > 0.1:
                    is_blank = false
                    break
        if not is_blank:
            print("FOUND IMAGES IN ROW ", row + 1)
    quit()
