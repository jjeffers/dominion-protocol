extends SceneTree

func _init():
	var oil_path = "res://src/data/oil_data.json"
	var f = FileAccess.open(oil_path, FileAccess.READ)
	var arr = JSON.new().parse_string(f.get_as_text())
	f.close()
	
	var tile_to_name = {}
	for marker in arr:
		tile_to_name[marker.get("tile", "")] = marker.get("name", "")
		
	var scenarios = [
		"res://src/data/scenarios/initial_test.json",
		"res://src/data/second_sathar_war.json"  # Might be in scenarios/ depending on the repo format
	]
	
	for sp in scenarios:
		if FileAccess.file_exists(sp):
			var s_f = FileAccess.open(sp, FileAccess.READ)
			var s_data = JSON.new().parse_string(s_f.get_as_text())
			s_f.close()
			
			var changed = false
			if s_data.has("neutral_oil"):
				var new_neutrals = []
				for o_name in s_data["neutral_oil"]:
					if tile_to_name.has(o_name) and tile_to_name[o_name] != "":
						new_neutrals.append(tile_to_name[o_name])
						changed = true
					else:
						new_neutrals.append(o_name)
				s_data["neutral_oil"] = new_neutrals
				
			if s_data.has("factions"):
				for fac in s_data["factions"].values():
					if fac.has("oil"):
						var new_fac_oil = []
						for o_name in fac["oil"]:
							if tile_to_name.has(o_name) and tile_to_name[o_name] != "":
								new_fac_oil.append(tile_to_name[o_name])
								changed = true
							else:
								new_fac_oil.append(o_name)
						fac["oil"] = new_fac_oil
						
			if changed:
				var out_f = FileAccess.open(sp, FileAccess.WRITE)
				out_f.store_string(JSON.stringify(s_data, "\t"))
				out_f.close()
				print("Updated scenario: ", sp)
				
	quit(0)
