extends SceneTree
func _init():
    var gdscript = GDScript.new()
    var file = FileAccess.open("res://src/scripts/ai/TacticalAI.gd", FileAccess.READ)
    gdscript.source_code = file.get_as_text()
    file.close()
    var err = gdscript.reload()
    if err != OK:
        print("PARSE ERROR: ", err)
    else:
        print("ALL GOOD!")
    quit()
