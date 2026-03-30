extends SceneTree

func _init():
	print("Checking GlobeView.gd...")
	var script = load("res://src/scripts/map/GlobeView.gd")
	if script == null:
		push_error("Failed to compile GlobeView.gd")
	else:
		print("Successfully compiled!")
	quit()
