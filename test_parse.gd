extends SceneTree

func _init():
	var u = load("res://src/scripts/map/GlobeUnit.gd")
	if u:
		print("GlobeUnit Loaded OK")
	else:
		print("GlobeUnit Failed to load")
	quit()
