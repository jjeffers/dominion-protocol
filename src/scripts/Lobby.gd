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
var load_start_time: int = 0
var main_scene_path: String = "res://src/scenes/main.tscn"

func _ready():
	_update_ui()
	
	blue_btn.pressed.connect(_on_join_blue)
	red_btn.pressed.connect(_on_join_red)
	start_btn.pressed.connect(_on_start_game)
	
	NetworkManager.players_updated.connect(_update_ui)
	NetworkManager.game_started.connect(_on_game_started)

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
			
		var display_text = "Player %d - %s" % [id, faction_str]
		if id == multiplayer.get_unique_id():
			display_text += " (You)"
			
		player_list.add_item(display_text)
	
	# Update button states based on who has what faction
	blue_btn.disabled = blue_taken
	red_btn.disabled = red_taken
	
	# Host can only start if all players exist and have factions assigned
	# And both Blue/Red are filled
	if NetworkManager.is_host:
		start_btn.disabled = not (blue_taken and red_taken and all_ready)
		
		if auto_start and not start_btn.disabled:
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
