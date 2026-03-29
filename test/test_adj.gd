extends SceneTree

func _init():
	var md = MapData.new()
	var o_reg = "Iranian Hub"
	var adjacent_regions = {}
	
	for t_id in md._region_map.keys():
		if md._region_map[t_id] == o_reg:
			for n in md.get_neighbors(t_id):
				if md._region_map.has(n):
					var r = md._region_map[n]
					if r != "" and r != o_reg and r != "WILDERNESS":
						adjacent_regions[r] = true
						
	print("Iranian Hub adjacent regions: ", adjacent_regions.keys())
	quit(0)
