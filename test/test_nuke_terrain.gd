extends "res://addons/gut/test.gd"

var MainScene = preload("res://src/scenes/main.tscn")

func test_nuke_water_terrain_not_wasteland():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	
	# Wait enough frames to let MapData load properly
	for i in range(10):
		await get_tree().process_frame
	
	var globe = main.globe_view
	var map = globe.map_data
	
	# We want to pick a tile, set it to OCEAN, drop a nuke, and see if it turns to WASTELAND.
	# We can just use tile 0 and its neighbors.
	var hit_tile = 0
	
	# Set hit_tile and its neighbors to OCEAN
	map.set_terrain(hit_tile, "OCEAN")
	for n in map.get_neighbors(hit_tile):
		map.set_terrain(n, "OCEAN")
		
	# Target position for the nuke is the centroid of the hit_tile
	var target_pos = map.get_centroid(hit_tile).normalized() * globe.radius
	
	# Execute nuke impact directly
	globe._process_nuke_impact(target_pos)
	
	# Wait for tweens or any delayed things (though nuke terrain changes happen immediately)
	await get_tree().process_frame
	
	# Assert that hit_tile and neighbors are STILL OCEAN and NOT WASTELAND
	assert_eq(map.get_terrain(hit_tile), "OCEAN", "Hit tile should remain OCEAN after nuke on water")
	
	for n in map.get_neighbors(hit_tile):
		assert_ne(map.get_terrain(n), "WASTELAND", "Neighbor should not turn into WASTELAND")
		assert_eq(map.get_terrain(n), "OCEAN", "Neighbor should remain OCEAN")



