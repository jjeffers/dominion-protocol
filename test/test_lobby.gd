extends SceneTree

func _init():
	var lobby = preload("res://src/scripts/Lobby.gd").new()
	lobby.auto_start = true
	lobby._ready()
	lobby._host_generate_scenario()
	await get_tree().process_frame # Wait for async
	
	var nm = NetworkManager
	var c_name = ""
	for c in nm.initial_countries.keys():
		if "Tehran" in nm.initial_countries[c]["cities"]:
			c_name = c
			break
			
	print("Tehran is in country: ", c_name)
	print("Country data: ", nm.initial_countries.get(c_name, "NULL"))
	quit(0)
