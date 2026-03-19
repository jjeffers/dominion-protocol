extends Control

@onready var player_name_input = $CenterContainer/VBoxContainer/PlayerSettings/HBoxContainer/PlayerNameInput

@onready var host_port_input = $CenterContainer/VBoxContainer/HostSection/HBoxContainer/HostPortInput
@onready var host_btn = $CenterContainer/VBoxContainer/HostSection/HostButton

@onready var join_ip_input = $CenterContainer/VBoxContainer/JoinSection/HBoxContainer2/JoinIPInput
@onready var join_port_input = $CenterContainer/VBoxContainer/JoinSection/HBoxContainer/JoinPortInput
@onready var join_btn = $CenterContainer/VBoxContainer/JoinSection/JoinButton

@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel

const CONFIG_PATH = "user://network_settings.cfg"
var config = ConfigFile.new()

func _ready():
	_load_config()
	MusicManager.play_music("res://src/assets/audio/Last Orders in the War Room.mp3")
	
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	
	NetworkManager.connection_succeeded.connect(_on_connection_success)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	
	if NetworkManager.last_disconnect_reason != "":
		status_label.text = NetworkManager.last_disconnect_reason
		NetworkManager.last_disconnect_reason = ""
	
	var args = OS.get_cmdline_args()
	print("MainMenu Args: ", args)
	for arg in args:
		if arg == "--host":
			_on_host_pressed()
		elif arg == "--client":
			_on_join_pressed()


func _load_config():
	if config.load(CONFIG_PATH) == OK:
		var last_ip = config.get_value("Network", "last_ip", "127.0.0.1")
		var last_port = config.get_value("Network", "last_port", "7001")
		var last_name = config.get_value("Network", "player_name", "Commander")
		
		join_ip_input.text = last_ip
		host_port_input.text = str(last_port)
		join_port_input.text = str(last_port)
		player_name_input.text = last_name


func _save_config(ip: String, port: String):
	config.set_value("Network", "last_ip", ip)
	config.set_value("Network", "last_port", port)
	config.set_value("Network", "player_name", player_name_input.text)
	config.save(CONFIG_PATH)
	NetworkManager.local_player_name = player_name_input.text


func _on_host_pressed():
	status_label.text = "Starting Host..."
	var port = host_port_input.text.to_int()
	if port <= 0:
		status_label.text = "Invalid Host Port"
		return
		
	_save_config(join_ip_input.text, str(port))
	
	var err = NetworkManager.host_game(port)
	if err != OK:
		status_label.text = "Failed to host on port " + str(port)


func _on_join_pressed():
	var ip = join_ip_input.text
	var port = join_port_input.text.to_int()
	
	if ip == "" or port <= 0:
		status_label.text = "Invalid IP or Port"
		return
		
	status_label.text = "Connecting to " + ip + ":" + str(port) + "..."
	_save_config(ip, str(port))
	
	var err = NetworkManager.join_game(ip, port)
	if err != OK:
		status_label.text = "Failed to initiate connection."


func _on_connection_success():
	status_label.text = "Connected! Loading Game..."
	print("MainMenu: Connection established, swapping scene...")
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/Lobby.tscn")


func _on_connection_failed(reason: String = ""):
	if reason == "":
		status_label.text = "Connection Failed."
	else:
		status_label.text = reason
