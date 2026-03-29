extends SceneTree

func _init() -> void:
	print("Starting Nuke Test")
	
	print("Instantiating Main")
	var main_scene = load("res://src/scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	
	# Wait for ready
	await create_timer(1.0).timeout
	
	var globe = main_scene.get_node("GlobeView")
	
	print("Loading default test scenario...")
	var scm = FileAccess.open("res://src/data/scenarios/initial_test.json", FileAccess.READ)
	var sc = JSON.new()
	sc.parse(scm.get_as_text())
	scm.close()
	globe._instantiate_scenario(sc.data)
	
	# Wait a bit
	await create_timer(1.0).timeout
	
	var pos = Vector3(-0.093744, 0.805753, -0.584785)
	print("Executing nuke impact at ", pos)
	
	# Mock NetworkManager
	var fake_multiplayer = MultiplayerAPI.create_default_interface()
	
	var t = Time.get_ticks_msec()
	globe._process_nuke_impact(pos)
	print("Finished in ", Time.get_ticks_msec() - t, " ms")
	
	print("Sleeping to detect post-execution hangs...")
	await create_timer(2.0).timeout
	print("Exiting cleanly")
	quit()
