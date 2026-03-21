extends SceneTree

func _init():
var file = FileAccess.open("res://src/data/scenarios/initial_test.json", FileAccess.READ)
var text = file.get_as_text()
var json = JSON.parse_string(text)
print("Nukes for Blue: ", json["factions"]["Blue"].get("nukes", 0))
quit()
