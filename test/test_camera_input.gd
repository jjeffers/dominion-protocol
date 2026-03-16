extends SceneTree

var globe_view_scene = preload("res://src/scenes/map/GlobeView.tscn")
var globe_view: Node3D

func _init():
	print("--- Running Camera Input Test ---")
	globe_view = globe_view_scene.instantiate()
	root.add_child(globe_view)
	root.set_process(true)
	
	# Wait for ready and a few frames initializing 
	await process_frame
	await process_frame
	
	var initial_lat = globe_view.current_latitude
	var initial_lon = globe_view.current_longitude
	
	print("Initial lat/lon:", initial_lat, ", ", initial_lon)
	print("Testing W key (up)")
	var ev_w = InputEventKey.new()
	ev_w.physical_keycode = KEY_W
	ev_w.pressed = true
	Input.parse_input_event(ev_w)
	
	await process_frame
	await process_frame
	
	ev_w.pressed = false
	Input.parse_input_event(ev_w)
	
	if globe_view.current_latitude > initial_lat:
		print("PASS: W Key successfully increased camera latitude.")
	else:
		print("FAIL: W Key did not modify camera latitude! Old:", initial_lat, " New:", globe_view.current_latitude)
		quit(1)
		return
		
	print("Testing D key (right)")
	var ev_d = InputEventKey.new()
	ev_d.physical_keycode = KEY_D
	ev_d.pressed = true
	Input.parse_input_event(ev_d)
	
	await process_frame
	await process_frame
	
	ev_d.pressed = false
	Input.parse_input_event(ev_d)
	
	if globe_view.current_longitude > initial_lon:
		print("PASS: D Key successfully increased camera longitude.")
	else:
		print("FAIL: D Key did not modify camera longitude! Old:", initial_lon, " New:", globe_view.current_longitude)
		quit(1)
		return

	print("Testing arrow keys...")
	var lat2 = globe_view.current_latitude
	var ev_down = InputEventAction.new()
	ev_down.action = "ui_down"
	ev_down.pressed = true
	Input.parse_input_event(ev_down)
	
	await process_frame
	await process_frame
	
	ev_down.pressed = false
	Input.parse_input_event(ev_down)
	
	if globe_view.current_latitude < lat2:
		print("PASS: Down Arrow successfully decreased camera latitude.")
	else:
		print("FAIL: Down Arrow did not modify camera latitude! Old:", lat2, " New:", globe_view.current_latitude)
		quit(1)
		return

	print("All camera input tests passed.")
	quit(0)
