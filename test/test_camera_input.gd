extends GutTest

var globe_view_scene = preload("res://src/scenes/map/GlobeView.tscn")

func test_camera_movement():
	var globe_view = globe_view_scene.instantiate()
	add_child_autoqfree(globe_view)
	
	# Wait for ready and a few frames initializing 
	await wait_frames(5)
	
	var initial_lat = globe_view.current_latitude
	var initial_lon = globe_view.current_longitude
	
	Input.action_press("ui_up")
	await wait_frames(10)
	Input.action_release("ui_up")
	
	assert_gt(globe_view.current_latitude, initial_lat, "Up Action successfully increased camera latitude.")
		
	Input.action_press("ui_right")
	await wait_frames(10)
	Input.action_release("ui_right")
	
	assert_gt(globe_view.current_longitude, initial_lon, "Right Action successfully increased camera longitude.")

	var lat2 = globe_view.current_latitude
	Input.action_press("ui_down")
	await wait_frames(10)
	Input.action_release("ui_down")
	
	assert_lt(globe_view.current_latitude, lat2, "Down Arrow successfully decreased camera latitude.")
