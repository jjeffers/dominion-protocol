extends Control

@onready var player_list = $CenterContainer/VBoxContainer/PlayerList
@onready var blue_btn = $CenterContainer/VBoxContainer/HBoxContainer/BlueFactionBtn
@onready var red_btn = $CenterContainer/VBoxContainer/HBoxContainer/RedFactionBtn
@onready var start_btn = $CenterContainer/VBoxContainer/StartGameBtn
@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel
@onready var loading_bar = $CenterContainer/VBoxContainer/LoadingBar

var auto_start: bool = false
var is_loading_game: bool = false
var is_transitioning: bool = false
var is_host_generated_countries: bool = false
var load_start_time: int = 0
var main_scene_path: String = "res://src/scenes/main.tscn"

func _ready():
	_update_ui()
	
	blue_btn.pressed.connect(_on_join_blue)
	red_btn.pressed.connect(_on_join_red)
	start_btn.pressed.connect(_on_start_game)
	
	NetworkManager.players_updated.connect(_update_ui)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.initial_countries_received.connect(_on_initial_countries_received)

	var args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--faction="):
			var parts = arg.split("=")
			if parts.size() > 1:
				var fac = parts[1]
				if fac == "Blue":
					_on_join_blue()
				elif fac == "Red":
					_on_join_red()
		if arg == "--auto-start":
			auto_start = true

func _update_ui():
	# Only host can start game
	start_btn.visible = NetworkManager.is_host
	
	player_list.clear()
	var all_ready = true
	var blue_taken = false
	var red_taken = false
	
	# Populate list
	for id in NetworkManager.players.keys():
		var p_info = NetworkManager.players[id]
		var faction_str = p_info["faction"]
		if faction_str == "":
			faction_str = "Unassigned"
			all_ready = false
		elif faction_str == "Blue":
			blue_taken = true
		elif faction_str == "Red":
			red_taken = true
			
		var display_text = "%s - %s" % [p_info.get("name", "Player " + str(id)), faction_str]
		if id == multiplayer.get_unique_id():
			display_text += " (You)"
			
		player_list.add_item(display_text)
	
	# Update button states based on who has what faction
	blue_btn.disabled = blue_taken
	red_btn.disabled = red_taken
	
	# Host can start anytime, empty slots will be played by AI bots
	if NetworkManager.is_host:
		start_btn.disabled = false
		
		# If auto-starting is queued, wait until the client (at least 2 players total) connects and claims a faction
		if auto_start and all_ready and NetworkManager.players.size() >= 2:
			_on_start_game()


func _on_join_blue():
	NetworkManager.rpc_id(1, "claim_faction", "Blue")

func _on_join_red():
	NetworkManager.rpc_id(1, "claim_faction", "Red")

func _on_start_game():
	if NetworkManager.is_host:
		NetworkManager.rpc("start_game")

func _on_game_started():
	print("Lobby: Starting background load for main.tscn")
	
	# Disable interaction
	start_btn.disabled = true
	blue_btn.disabled = true
	red_btn.disabled = true
	
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
	# Allow a small frame delay to ensure 100% renders before freezing for scene transition
	get_tree().call_deferred("change_scene_to_packed", ResourceLoader.load_threaded_get(main_scene_path))

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
			
	var scenario_data = {}
	var spath = "res://src/data/scenarios/initial_test.json"
	if FileAccess.file_exists(spath):
		var s_json = JSON.new()
		if s_json.parse(FileAccess.open(spath, FileAccess.READ).get_as_text()) == OK:
			scenario_data = s_json.data
			
	var active_cities = []
	if scenario_data.has("factions"):
		for f in scenario_data["factions"].values():
			if f.has("cities"): active_cities.append_array(f["cities"])
	if scenario_data.has("neutral_cities"):
		active_cities.append_array(scenario_data["neutral_cities"])
		
	var all_cities = c_dict.keys()
	var unaligned = []
	for c in all_cities:
		if not active_cities.has(c):
			unaligned.append(c)
			
	var countries = {}
	if unaligned.size() > 0:
		var base_countries = int(round(randfn(19.0, 5.0)))
		var num_countries = clampi(base_countries, 8, min(30, unaligned.size()))
		
		var centroids = []
		var available = unaligned.duplicate()
		for i in range(num_countries):
			if available.size() == 0: break
			var idx = randi() % available.size()
			centroids.append(available[idx])
			available.remove_at(idx)
			countries["Country " + str(i + 1)] = {"cities": [], "color": "#708090"}
			
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
				countries[best]["cities"].append(c_name)
			
		print("Generated %d dynamic countries." % num_countries)
		
	NetworkManager.rpc("sync_initial_countries", countries)
	set_process(true)

