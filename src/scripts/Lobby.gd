extends Control

@onready var player_list = $CenterContainer/VBoxContainer/PlayerList
@onready var blue_btn = $CenterContainer/VBoxContainer/HBoxContainer/BlueFactionBtn
@onready var red_btn = $CenterContainer/VBoxContainer/HBoxContainer/RedFactionBtn
@onready var start_btn = $CenterContainer/VBoxContainer/StartGameBtn
@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel

var auto_start: bool = false

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
	print("Lobby: Transitioning to main.tscn")
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/main.tscn")
