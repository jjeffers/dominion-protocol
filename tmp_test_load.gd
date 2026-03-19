extends SceneTree
func _init():
    var script = load("res://src/scripts/ai/TacticalAI.gd")
    if not script:
        print("Failed to load script")
    else:
        var instance = script.new()
        print("Instance: ", instance)
    quit()
