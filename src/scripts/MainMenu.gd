extends Control

@onready var player_name_input = $CenterContainer/VBoxContainer/PlayerSettings/HBoxContainer/PlayerNameInput

@onready var host_ip_input = $CenterContainer/VBoxContainer/HostSection/HBoxContainer2/HostIPInput
@onready var host_port_input = $CenterContainer/VBoxContainer/HostSection/HBoxContainer/HostPortInput
@onready var host_btn = $CenterContainer/VBoxContainer/HostSection/HostButton
@onready var load_btn = $CenterContainer/VBoxContainer/HostSection/LoadGameButton
@onready var load_dialog = $LoadGameDialog

@onready var join_ip_input = $CenterContainer/VBoxContainer/JoinSection/HBoxContainer2/JoinIPInput
@onready var join_port_input = $CenterContainer/VBoxContainer/JoinSection/HBoxContainer/JoinPortInput
@onready var join_btn = $CenterContainer/VBoxContainer/JoinSection/JoinButton

@onready var settings_btn = $CenterContainer/VBoxContainer/SettingsButton
@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel

const CONFIG_PATH = "user://network_settings.cfg"
var config = ConfigFile.new()

func _ready():
	_load_config()
	MusicManager.play_music("res://src/assets/audio/Last Orders in the War Room.mp3")
	
	host_btn.pressed.connect(_on_host_pressed)
	if load_btn:
		load_btn.pressed.connect(_on_load_pressed)
	if load_dialog:
		load_dialog.file_selected.connect(_on_load_file_selected)
		
	join_btn.pressed.connect(_on_join_pressed)
	
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	
	NetworkManager.connection_succeeded.connect(_on_connection_success)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	
	if NetworkManager.last_disconnect_reason != "":
		status_label.text = NetworkManager.last_disconnect_reason
		NetworkManager.last_disconnect_reason = ""
	
	var args = OS.get_cmdline_args()
	print("MainMenu Args: ", args)
	
	for arg in args:
		if arg.begins_with("--bot"):
			player_name_input.text = "[BOT] TacticalAI"
		elif arg.begins_with("--port="):
			var p = arg.split("=")[1]
			host_port_input.text = p
			join_port_input.text = p
		elif arg.begins_with("--host-ip="):
			host_ip_input.text = arg.split("=")[1]
		elif arg.begins_with("--host-port="):
			host_port_input.text = arg.split("=")[1]
		elif arg.begins_with("--match-id="):
			NetworkManager.match_id = arg.split("=")[1]
			
	for arg in args:
		if arg == "--host":
			_on_host_pressed()
		elif arg == "--client":
			_on_join_pressed()


func _load_config():
	if config.load(CONFIG_PATH) == OK:
		var last_ip = config.get_value("Network", "last_ip", "127.0.0.1")
		var last_port = config.get_value("Network", "last_port", "7001")
		var last_host_ip = config.get_value("Network", "last_host_ip", "*")
		var last_host_port = config.get_value("Network", "last_host_port", "7001")
		var last_name = config.get_value("Network", "player_name", "Commander")
		
		var is_bot = false
		for arg in OS.get_cmdline_args():
			if arg.begins_with("--bot"):
				is_bot = true
				break
				
		if not is_bot and last_name.begins_with("[BOT]"):
			last_name = "Commander"
			
		join_ip_input.text = last_ip
		host_ip_input.text = last_host_ip
		host_port_input.text = str(last_host_port)
		join_port_input.text = str(last_port)
		player_name_input.text = last_name
		NetworkManager.local_player_name = last_name


func _save_config():
	config.set_value("Network", "last_ip", join_ip_input.text)
	config.set_value("Network", "last_port", join_port_input.text)
	config.set_value("Network", "last_host_ip", host_ip_input.text)
	config.set_value("Network", "last_host_port", host_port_input.text)
	config.set_value("Network", "player_name", player_name_input.text)
	config.save(CONFIG_PATH)
	NetworkManager.local_player_name = player_name_input.text


func _on_host_pressed():
	status_label.text = "Starting Host..."
	var ip = host_ip_input.text
	var port = host_port_input.text.to_int()
	if port <= 0:
		status_label.text = "Invalid Host Port"
		return
		
	_save_config()
	
	# Ensure loaded state is clear on a fresh host
	if GameStateManager != null:
		GameStateManager.current_loaded_state = {}
	
	var err = NetworkManager.host_game(port, ip)
	if err != OK:
		status_label.text = "Failed to host on port " + str(port)

func _on_load_pressed():
	if load_dialog:
		if OS.has_feature("windows") or OS.has_feature("macos") or OS.has_feature("linux"):
			load_dialog.use_native_dialog = true
		load_dialog.popup_centered()

func _on_load_file_selected(path: String):
	if GameStateManager == null:
		return
		
	var success = GameStateManager.load_game(path)
	if not success:
		status_label.text = "Failed to parse save file."
		return
		
	status_label.text = "Save loaded. Starting Host..."
	var ip = host_ip_input.text
	var port = host_port_input.text.to_int()
	if port <= 0:
		port = 7001
		
	_save_config()
	
	var err = NetworkManager.host_game(port, ip)
	if err != OK:
		status_label.text = "Failed to host on port " + str(port)

func _on_join_pressed():
	var ip = join_ip_input.text
	var port = join_port_input.text.to_int()
	
	if ip == "" or port <= 0:
		status_label.text = "Invalid IP or Port"
		return
		
	status_label.text = "Connecting to " + ip + ":" + str(port) + "..."
	_save_config()
	
	var err = NetworkManager.join_game(ip, port)
	if err != OK:
		status_label.text = "Failed to initiate connection: " + error_string(err)


func _on_connection_success():
	status_label.text = "Connected! Loading Game..."
	print("MainMenu: Connection established, swapping scene...")
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/Lobby.tscn")


func _on_connection_failed(reason: String = ""):
	if reason == "":
		status_label.text = "Connection Failed."
	else:
		status_label.text = reason

func _on_settings_pressed():
	if not has_node("SettingsMenu"):
		var menu_scn = load("res://src/scenes/SettingsMenu.tscn").instantiate()
		menu_scn.name = "SettingsMenu"
		if menu_scn.has_method("setup_for_main_menu"):
			menu_scn.setup_for_main_menu()
		add_child(menu_scn)

