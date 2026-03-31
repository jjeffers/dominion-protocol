extends Control

@onready var player_list = $CenterContainer/VBoxContainer/PlayerList
@onready var faction_button_container = $CenterContainer/VBoxContainer/HBoxContainer
@onready var start_btn = $CenterContainer/VBoxContainer/StartGameBtn
@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel
@onready var loading_bar = $CenterContainer/VBoxContainer/LoadingBar

var auto_start: bool = false
var is_loading_game: bool = false
var is_transitioning: bool = false
var is_host_generated_countries: bool = false
var load_start_time: int = 0
var main_scene_path: String = "res://src/scenes/main.tscn"

var scenario_data: Dictionary = {}
var faction_buttons: Dictionary = {}
var money_spinboxes: Dictionary = {}
var available_scenarios: Array[String] = []
var scenario_dropdown: OptionButton
var scenario_label: Label
var available_colors: Array[Color] = [
	Color.RED, Color.BLUE, Color.GOLD, Color.GREEN, Color.BLACK, 
	Color.PURPLE, Color.ORANGE, Color.YELLOW, Color.CYAN, Color.MAGENTA, 
	Color.WHITE, Color.GRAY
]

func _get_faction_display_name(fac_key: String) -> String:
	if not scenario_data.has("factions") or not scenario_data["factions"].has(fac_key):
		return fac_key
		
	var fac = scenario_data["factions"][fac_key]
	var d_name = fac.get("display_name", "")
	
	if d_name != "" and d_name != fac_key and not "(to be renamed" in d_name:
		return d_name
		
	var c_hex = fac.get("color", "ffffff")
	if typeof(c_hex) == TYPE_STRING:
		c_hex = c_hex.to_lower()
		var color_map = {
			Color.RED.to_html(false).to_lower(): "Red",
			Color.BLUE.to_html(false).to_lower(): "Blue",
			Color.GOLD.to_html(false).to_lower(): "Gold",
			Color.GREEN.to_html(false).to_lower(): "Green",
			Color.BLACK.to_html(false).to_lower(): "Black",
			Color.PURPLE.to_html(false).to_lower(): "Purple",
			Color.ORANGE.to_html(false).to_lower(): "Orange",
			Color.YELLOW.to_html(false).to_lower(): "Yellow",
			Color.CYAN.to_html(false).to_lower(): "Cyan",
			Color.MAGENTA.to_html(false).to_lower(): "Magenta",
			Color.WHITE.to_html(false).to_lower(): "White",
			Color.GRAY.to_html(false).to_lower(): "Gray",
			"#ff0000": "Red",
			"#0000ff": "Blue",
			"#00ff00": "Green"
		}
		if color_map.has(c_hex):
			return color_map[c_hex] + " Faction"
			
	return fac_key

var test_compile_flag = false

func _ready():
	# Build the Scenario Header UI
	var vbox = $CenterContainer/VBoxContainer
	
	var scenario_hbox = HBoxContainer.new()
	scenario_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	scenario_hbox.add_theme_constant_override("separation", 20)
	
	var slabel = Label.new()
	slabel.text = "Scenario:"
	slabel.add_theme_font_size_override("font_size", 48)
	scenario_hbox.add_child(slabel)
	
	scenario_label = Label.new()
	scenario_label.add_theme_font_size_override("font_size", 48)
	scenario_label.self_modulate = Color(0.7, 0.7, 1.0)
	scenario_hbox.add_child(scenario_label)
	
	scenario_dropdown = OptionButton.new()
	scenario_dropdown.add_theme_font_size_override("font_size", 42)
	scenario_dropdown.get_popup().add_theme_font_size_override("font_size", 42)
	scenario_dropdown.item_selected.connect(_on_scenario_selected)
	scenario_hbox.add_child(scenario_dropdown)
	
	vbox.add_child(scenario_hbox)
	vbox.move_child(scenario_hbox, 3) # Insert right above faction lists
	
	_load_available_scenarios()
	
	if GameStateManager != null and not GameStateManager.current_loaded_state.is_empty():
		scenario_data = GameStateManager.current_loaded_state.duplicate(true)
		_build_faction_ui()
	else:
		if NetworkManager.is_host:
			_load_scenario_index(0)
		else:
			rpc_id(1, "request_scenario_sync")
	
	start_btn.pressed.connect(_on_start_game)
	
	NetworkManager.players_updated.connect(_update_ui)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.initial_countries_received.connect(_on_initial_countries_received)

	var args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--faction="):
			var parts = arg.split("=")
			if parts.size() > 1:
				var fac = parts[1].replace("\"", "").replace("'", "").strip_edges()
				if NetworkManager.is_host or multiplayer.has_multiplayer_peer() and multiplayer.get_unique_id() != 0:
					_on_join_faction(fac)
				else:
					NetworkManager.connection_succeeded.connect(func(): _on_join_faction(fac))
		if arg.begins_with("--scenario="):
			var parts = arg.split("=")
			if parts.size() > 1 and NetworkManager.is_host:
				var target_s = parts[1].replace("\"", "").replace("'", "").strip_edges()
				for i in range(available_scenarios.size()):
					if target_s.to_lower() in available_scenarios[i].get_file().to_lower():
						scenario_dropdown.select(i)
						_load_scenario_index(i)
						break
		if arg == "--auto-start":
			auto_start = true

func _load_available_scenarios():
	available_scenarios.clear()
	scenario_dropdown.clear()
	
	var dir = DirAccess.open("res://src/data/scenarios/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				available_scenarios.append("res://src/data/scenarios/" + file_name)
			file_name = dir.get_next()
			
	available_scenarios.sort()
	
	for path in available_scenarios:
		var disp_name = path.get_file()
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data.has("name"):
			disp_name = json.data["name"]
		scenario_dropdown.add_item(disp_name)
			
func _on_scenario_selected(idx: int) -> void:
	if NetworkManager.is_host:
		_load_scenario_index(idx)

func _load_scenario_index(idx: int) -> void:
	if idx < 0 or idx >= available_scenarios.size():
		return
		
	var path = available_scenarios[idx]
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			scenario_data = json.data.duplicate(true)
			_process_scenario_defaults()
			_build_faction_ui()
			rpc("sync_scenario", scenario_data)

func _process_scenario_defaults() -> void:
	if not scenario_data.has("factions"):
		return
		
	var used_colors = []
	for f in scenario_data["factions"].values():
		if f.has("color") and f["color"] != "":
			used_colors.append(Color(f["color"]))
			
	for fac_key in scenario_data["factions"].keys():
		var fac = scenario_data["factions"][fac_key]
		var d_name = fac.get("display_name", "")
			
		if not fac.has("color") or fac["color"] == "":
			var picked = Color.WHITE
			for c in available_colors:
				if not c in used_colors:
					picked = c
					break
			used_colors.append(picked)
			fac["color"] = "#" + picked.to_html(false)
			
		if not fac.has("money"):
			fac["money"] = 100.0

@rpc("any_peer", "call_local", "reliable")
func request_scenario_sync() -> void:
	if NetworkManager.is_host:
		var sender_id = multiplayer.get_remote_sender_id()
		rpc_id(sender_id, "sync_scenario", scenario_data)

@rpc("authority", "call_local", "reliable")
func sync_scenario(s_data: Dictionary) -> void:
	scenario_data = s_data
	_build_faction_ui()

func _build_faction_ui():
	for child in faction_button_container.get_children():
		child.queue_free()
		
	faction_buttons.clear()
	money_spinboxes.clear()
	
	var s_name = scenario_data.get("name", "Unknown Scenario")
	scenario_dropdown.visible = NetworkManager.is_host
	scenario_label.visible = not NetworkManager.is_host
	scenario_label.text = s_name
	
	if NetworkManager.is_host:
		for i in range(scenario_dropdown.item_count):
			if scenario_dropdown.get_item_text(i) == s_name:
				scenario_dropdown.select(i)
				break
				
	if scenario_data.has("factions"):
		for fac_key in scenario_data["factions"].keys():
			var fac = scenario_data["factions"][fac_key]
			var vbox = VBoxContainer.new()
			vbox.add_theme_constant_override("separation", 10)
			
			var btn = Button.new()
			var d_name = _get_faction_display_name(fac_key)
			var oil_reserves = fac.get("oil_stored", 0)
			if fac.has("oil"):
				oil_reserves += fac["oil"].size() * 500
				
			var oil_text = ""
			if oil_reserves > 0:
				oil_text = " [Oil: " + str(oil_reserves) + "]"
				
			btn.text = "Join " + d_name + " (" + fac_key + ")" + oil_text
			btn.add_theme_font_size_override("font_size", 54)
			btn.custom_minimum_size = Vector2(300, 80)
			
			var c_val = fac.get("color", "#FFFFFF")
			if typeof(c_val) == TYPE_STRING:
				btn.modulate = Color(c_val)
			elif typeof(c_val) == TYPE_ARRAY and c_val.size() >= 3:
				btn.modulate = Color(c_val[0], c_val[1], c_val[2])
				
			btn.pressed.connect(func(): _on_join_faction(fac_key))
			faction_buttons[fac_key] = btn
			vbox.add_child(btn)
			
			var money_hbox = HBoxContainer.new()
			money_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
			var money_label = Label.new()
			money_label.text = "Starting Money:"
			money_label.add_theme_font_size_override("font_size", 48)
			money_hbox.add_child(money_label)
			
			var money_spin = SpinBox.new()
			money_spin.min_value = 0
			money_spin.max_value = 99999
			money_spin.step = 10
			money_spin.value = fac.get("money", 100.0)
			money_spin.add_theme_font_size_override("font_size", 48)
			money_spin.get_line_edit().add_theme_font_size_override("font_size", 48)
			money_spin.value_changed.connect(func(val): _on_money_changed(fac_key, val))
			money_spinboxes[fac_key] = money_spin
			money_hbox.add_child(money_spin)
			vbox.add_child(money_hbox)
			
			faction_button_container.add_child(vbox)
			
	_update_ui()

func _update_ui():
	# Only host can start game
	start_btn.visible = NetworkManager.is_host
	
	player_list.clear()
	var all_ready = true
	var taken_factions = {}
	
	# Populate list
	for id in NetworkManager.players.keys():
		var p_info = NetworkManager.players[id]
		var faction_str = p_info["faction"]
		if faction_str == "":
			faction_str = "Unassigned"
			all_ready = false
		else:
			taken_factions[faction_str] = true
			
		var fac_display = faction_str
		if scenario_data.has("factions") and scenario_data["factions"].has(faction_str):
			fac_display = _get_faction_display_name(faction_str)
			
		var display_text = "%s - %s" % [p_info.get("name", "Player " + str(id)), fac_display]
		if id == multiplayer.get_unique_id():
			display_text += " (You)"
			
		player_list.add_item(display_text)
	
	# Update button states based on who has what faction
	for fac_key in faction_buttons.keys():
		faction_buttons[fac_key].disabled = taken_factions.has(fac_key)
		
	for fac_key in money_spinboxes.keys():
		money_spinboxes[fac_key].editable = NetworkManager.is_host
	
	# Host can start anytime, empty slots will be played by AI bots
	if NetworkManager.is_host:
		start_btn.disabled = false
		
		# If auto-starting is queued, wait until the client (at least 2 players total) connects and claims a faction
		if auto_start and all_ready and NetworkManager.players.size() >= 2:
			_on_start_game()

func _on_join_faction(fac: String):
	NetworkManager.rpc_id(1, "claim_faction", fac)

func _on_money_changed(fac_key: String, val: float) -> void:
	if NetworkManager.is_host:
		scenario_data["factions"][fac_key]["money"] = val
		rpc("sync_faction_money", fac_key, val)

@rpc("authority", "call_local", "reliable")
func sync_faction_money(fac_key: String, money: float) -> void:
	if scenario_data.has("factions") and scenario_data["factions"].has(fac_key):
		scenario_data["factions"][fac_key]["money"] = money
		if money_spinboxes.has(fac_key):
			money_spinboxes[fac_key].set_value_no_signal(money)

var _game_started_rpc_sent = false

func _on_start_game():
	if NetworkManager.is_host and not _game_started_rpc_sent:
		_game_started_rpc_sent = true
		if scenario_data.has("factions"):
			for fac_key in scenario_data["factions"].keys():
				var fac = scenario_data["factions"][fac_key]
				var check_name = fac.get("display_name", "")
				if check_name == "" or "(to be renamed" in check_name or check_name == fac_key:
					var generated_name = FactionNameGenerator.generate_faction_name()
					fac["display_name"] = generated_name
					fac["abbreviation"] = FactionNameGenerator.generate_faction_acronym(generated_name)
		
		rpc("sync_scenario", scenario_data)
		NetworkManager.rpc("start_game")

func _on_game_started():
	print("Lobby: Starting background load for main.tscn")
	
	# Disable interaction
	start_btn.disabled = true
	for btn in faction_buttons.values():
		btn.disabled = true
	
	# Show loading bar
	loading_bar.show()
	loading_bar.value = 0.0
	status_label.text = "Loading Resources..."
	
	is_loading_game = true
	load_start_time = Time.get_ticks_msec()
	
	var err = ResourceLoader.load_threaded_request(main_scene_path)
	if err != OK:
		push_error("Failed to start loading main scene!")

func _process(_delta: float) -> void:
	if not is_loading_game:
		return
		
	var progress = []
	var status = ResourceLoader.load_threaded_get_status(main_scene_path, progress)
	
	if progress.size() > 0:
		loading_bar.value = progress[0] * 100.0
		
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		if not is_host_generated_countries:
			if NetworkManager.is_host:
				loading_bar.value = 95.0
				status_label.text = "Generating dynamic countries..."
				
				is_host_generated_countries = true # Next frame it will pass, but we handle it async
				set_process(false)
				call_deferred("_host_generate_scenario")
			else:
				loading_bar.value = 90.0
				status_label.text = "Waiting for Host..."
				if not NetworkManager.initial_countries.is_empty():
					is_host_generated_countries = true
		else:
			loading_bar.value = 100.0
			if not is_transitioning:
				is_transitioning = true
				var elapsed = Time.get_ticks_msec() - load_start_time
				var client_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
				print("[Client %d] Resource loading completed in %d ms" % [client_id, elapsed])
				
				if MusicManager.bgm_player.playing:
					MusicManager.fade_finished.connect(self._on_fade_finished, CONNECT_ONE_SHOT)
					MusicManager.fade_out(2.0)
				else:
					_on_fade_finished()
				
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		is_loading_game = false
		push_error("Failed to load main scene during threaded load!")
		status_label.text = "Failed to load game!"

func _on_fade_finished() -> void:
	is_loading_game = false
	status_label.text = "Initializing Framework..."
	loading_bar.value = 0.0
	
	var main_scene = ResourceLoader.load_threaded_get(main_scene_path)
	var main_instance = main_scene.instantiate()
	main_instance.visible = false
	main_instance.set("is_async_setup", true)
	main_instance.set("scenario_data", scenario_data.duplicate(true))
	
	get_tree().root.add_child(main_instance)
	
	if main_instance.has_method("execute_async_setup"):
		main_instance.execute_async_setup(self)
	else:
		get_tree().current_scene = main_instance
		main_instance.visible = true
		queue_free()
		
	if GameStateManager != null:
		GameStateManager.current_loaded_state.clear()

func update_progress(pct: float, text: String) -> void:
	loading_bar.value = pct
	status_label.text = text

func _on_initial_countries_received() -> void:
	if not NetworkManager.is_host:
		is_host_generated_countries = true

func _host_generate_scenario() -> void:
	var c_dict = {}
	var path = "res://src/data/city_data.json"
	if FileAccess.file_exists(path):
		var c_json = JSON.new()
		if c_json.parse(FileAccess.open(path, FileAccess.READ).get_as_text()) == OK:
			c_dict = c_json.data
			
	var spath = "res://src/data/scenarios/initial_test.json"
	if scenario_data.is_empty() and FileAccess.file_exists(spath):
		var s_json = JSON.new()
		if s_json.parse(FileAccess.open(spath, FileAccess.READ).get_as_text()) == OK:
			scenario_data = s_json.data
			
	# Dynamically allocate cities to factions that don't have them
	if scenario_data.has("factions") and not c_dict.is_empty():
		var all_cities_arr = c_dict.keys()
		var reserved = []
		if scenario_data.has("neutral_cities"):
			reserved.append_array(scenario_data["neutral_cities"])
		for f in scenario_data["factions"].values():
			if f.has("cities") and f["cities"].size() > 0:
				reserved.append_array(f["cities"])
				
		for f_id in scenario_data["factions"].keys():
			var f = scenario_data["factions"][f_id]
			if not f.has("cities") or f["cities"].size() == 0:
				f["cities"] = []
				var available = []
				for c in all_cities_arr:
					if not c in reserved:
						available.append(c as String)
				
				if available.size() > 0:
					var chosen_center = available[randi() % available.size()]
					f["cities"].append(chosen_center)
					reserved.append(chosen_center)
					
					# Attempt to find 1 to 2 nearby cities to attach to this faction
					var c_lat = deg_to_rad(c_dict[chosen_center].get("latitude", 0.0))
					var c_lon = deg_to_rad(c_dict[chosen_center].get("longitude", 0.0))
					var c_pos = Vector3(cos(c_lat)*cos(c_lon), sin(c_lat), cos(c_lat)*sin(c_lon))
					
					var neighbors = []
					for other in available:
						if other == chosen_center: continue
						var o_lat = deg_to_rad(c_dict[other].get("latitude", 0.0))
						var o_lon = deg_to_rad(c_dict[other].get("longitude", 0.0))
						var o_pos = Vector3(cos(o_lat)*cos(o_lon), sin(o_lat), cos(o_lat)*sin(o_lon))
						# Check direct chord distance
						if c_pos.distance_to(o_pos) < 0.2: 
							neighbors.append(other)
							
					neighbors.shuffle()
					var count = min(randi() % 2 + 1, neighbors.size())
					for i in range(count):
						f["cities"].append(neighbors[i])
						reserved.append(neighbors[i])
						
			# Enforce Capitol Assignment
			if f.has("cities") and f["cities"].size() > 0:
				if not f.has("capitol") or f["capitol"] == "":
					f["capitol"] = f["cities"][0]
	
	# Finally push the fully hydrated faction payload down to all connected clients
	rpc("sync_scenario", scenario_data)
			
	var active_cities = []
	if scenario_data.has("factions"):
		for f in scenario_data["factions"].values():
			if f.has("cities"): active_cities.append_array(f["cities"])
			
	# We intentionally bypass appending neutral_cities to active_cities here
	# so that they are dumped into the unaligned array and grouped into
	# actual, formal dynamic countries which will render political borders natively.
	# if scenario_data.has("neutral_cities"):
	# 	active_cities.append_array(scenario_data["neutral_cities"])
		
	var all_cities = c_dict.keys()
	var unaligned = []
	for c in all_cities:
		if not active_cities.has(c):
			unaligned.append(c)
			
	if scenario_data.has("countries"):
		var countries = scenario_data["countries"]
		NetworkManager.rpc("sync_initial_countries", countries)
		set_process(true)
		return
			
	var countries = {}
	if unaligned.size() > 0:
		var base_countries = int(round(randfn(35.0, 8.0)))
		var num_countries = clampi(base_countries, 20, min(50, unaligned.size()))
		
		var centroids = []
		var available = unaligned.duplicate()
		var temp_countries = {}
		for i in range(num_countries):
			if available.size() == 0: break
			var idx = randi() % available.size()
			centroids.append(available[idx])
			available.remove_at(idx)
			temp_countries["Country " + str(i + 1)] = {"cities": [], "color": "#FFD700"} # High-contrast Gold
			
		for c_name in unaligned:
			var c_lat = deg_to_rad(c_dict[c_name].get("latitude", 0.0))
			var c_lon = deg_to_rad(c_dict[c_name].get("longitude", 0.0))
			var c_pos = Vector3(cos(c_lat)*cos(c_lon), sin(c_lat), cos(c_lat)*sin(c_lon))
			
			var best = ""
			var best_score = INF
			for i in range(centroids.size()):
				var cent_name = centroids[i]
				var cent_lat = deg_to_rad(c_dict[cent_name].get("latitude", 0.0))
				var cent_lon = deg_to_rad(c_dict[cent_name].get("longitude", 0.0))
				var cent_pos = Vector3(cos(cent_lat)*cos(cent_lon), sin(cent_lat), cos(cent_lat)*sin(cent_lon))
				
				var dist = c_pos.distance_to(cent_pos)
				var score = dist * randf_range(0.8, 1.2)
				if score < best_score:
					best_score = score
					best = "Country " + str(i + 1)
					
			if best != "":
				temp_countries[best]["cities"].append(c_name)
				
		# Load land neighbors for connectivity checks
		var city_neighbors = {}
		if FileAccess.file_exists("res://src/data/city_land_neighbors.json"):
			var n_file = FileAccess.open("res://src/data/city_land_neighbors.json", FileAccess.READ)
			var n_json = JSON.new()
			if n_json.parse(n_file.get_as_text()) == OK:
				city_neighbors = n_json.data

		var final_countries_count = 0
		for temp_key in temp_countries.keys():
			var raw_c_list: Array[String] = []
			for c in temp_countries[temp_key]["cities"]:
				raw_c_list.append(c as String)
				
			if raw_c_list.is_empty():
				continue
				
			# Partition raw_c_list into connected landmass components via BFS
			var unvisited = raw_c_list.duplicate()
			var components = []
			
			while unvisited.size() > 0:
				var start_node = unvisited[0]
				unvisited.remove_at(0)
				
				var current_component: Array[String] = [start_node]
				var queue = [start_node]
				
				while queue.size() > 0:
					var curr = queue[0]
					queue.remove_at(0)
					
					if city_neighbors.has(curr):
						for n in city_neighbors[curr]:
							var n_str = n as String
							if n_str in unvisited:
								unvisited.erase(n_str)
								current_component.append(n_str)
								queue.append(n_str)
								
				components.append(current_component)
				
			for comp in components:
				var generated_name = CountryNameGenerator.generate_name(comp)
				var base_name = generated_name
				var counter = 2
				while countries.has(generated_name):
					generated_name = base_name + " " + str(counter)
					counter += 1
					
				countries[generated_name] = {
					"cities": comp, 
					"color": temp_countries[temp_key]["color"]
				}
				final_countries_count += 1
			
		print("Generated %d contiguous dynamic countries from %d regional clusters." % [final_countries_count, num_countries])
		
	NetworkManager.rpc("sync_initial_countries", countries)
	set_process(true)

