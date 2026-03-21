extends "res://addons/gut/test.gd"

var MainScene = preload("res://src/scripts/main.gd")

func test_nuke_input():
	var main = MainScene.new()
	add_child_autofree(main)
	main._ready()
	
	# Simulate NetworkManager having current player ID
	var nm = Node.new()
	nm.name = "NetworkManager"
	nm.set_script(preload("res://src/scripts/network/Lobby.gd"))
	get_tree().root.add_child(nm)
	
	# Wait for a frame to let things settle
	await get_tree().process_frame
	
	var event = InputEventKey.new()
	event.physical_keycode = KEY_N
	event.pressed = true
	
	print("--- TRIGGERING N KEY ---")
	main._unhandled_input(event)
	print("--- FINISHED N KEY ---")
	
	nm.queue_free()
