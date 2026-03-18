extends SceneTree
func _init():
    var atlas = load("res://src/assets/spritesheet.png") as Texture2D
    var img = atlas.get_image()
    var region = Rect2(0, 64, 32, 32)
    var cropped_img = img.get_region(region)
    var is_blank = true
    for y in range(32):
        for x in range(32):
            if cropped_img.get_pixel(x, y).a > 0.1:
                is_blank = false
                break
    if is_blank:
        print("TEXTURE WAS COMPLETELY TRANSPARENT/BLANK!")
    else:
        print("TEXTURE HAS VISIBLE PIXELS!")
    quit()
