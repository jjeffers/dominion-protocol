extends Node

var peer = ENetMultiplayerPeer.new()
var is_host = false

signal connection_succeeded
signal connection_failed
signal server_disconnected

# Lobby Signals
signal players_updated
signal game_started
signal unit_target_synced(unit_name: String, target_pos: Vector3, enemy_target_name: String)

# Dictionary of players: { id: { "name": String, "faction": String } }
var players: Dictionary = {}

func _ready():
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func host_game(port: int) -> Error:
	var error = peer.create_server(port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		is_host = true
		print("Hosting on port %d" % port)
		
		# Register Host
		players[1] = { "name": "Host", "faction": "" }
		connection_succeeded.emit()
	else:
		print("Error hosting on port %d: %d" % [port, error])
	return error

func join_game(ip: String, port: int) -> Error:
	var error = peer.create_client(ip, port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		is_host = false
		print("Joining %s:%d" % [ip, port])
	else:
		print("Error joining %s:%d: %d" % [ip, port, error])
	return error

# --- Multiplayer Peer Signals ---

func _on_connected_ok():
	print("Connected to server successfully! Self ID: ", multiplayer.get_unique_id())
	connection_succeeded.emit()

func _on_connected_fail():
	print("Failed to connect to server.")
	connection_failed.emit()

func _on_server_disconnected():
	print("Server disconnected.")
	players.clear()
	server_disconnected.emit()

func _on_peer_connected(id: int):
	print("Peer connected: ", id)
	if is_host:
		players[id] = { "name": "Player " + str(id), "faction": "" }
		_sync_players_to_all()

func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)
	if players.has(id):
		players.erase(id)
	if is_host:
		_sync_players_to_all()

func disconnect_peer():
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	players.clear()


# --- RPCs & State Sync ---

func _sync_players_to_all():
	rpc("update_players", players)

@rpc("authority", "call_local", "reliable")
func update_players(new_players: Dictionary):
	players = new_players
	_update_window_title()
	players_updated.emit()

func _update_window_title():
	if not multiplayer.has_multiplayer_peer() or multiplayer.get_unique_id() == 0:
		DisplayServer.window_set_title("Dominion Protocol")
		return
		
	var id = multiplayer.get_unique_id()
	if players.has(id):
		var fac = players[id]["faction"]
		if fac == "":
			fac = "Unassigned"
		DisplayServer.window_set_title("Dominion Protocol - Player %d [%s]" % [id, fac])
	else:
		DisplayServer.window_set_title("Dominion Protocol - Player %d" % id)

@rpc("any_peer", "call_local", "reliable")
func claim_faction(faction_name: String):
	# Only host validates and processes claims to prevent race conditions
	if not is_host:
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Verify faction isn't already taken
	var is_taken = false
	for p in players.values():
		if p["faction"] == faction_name:
			is_taken = true
			break
			
	if not is_taken and players.has(sender_id):
		# Clear their old faction if they had one
		players[sender_id]["faction"] = faction_name
		_sync_players_to_all()

@rpc("authority", "call_local", "reliable")
func start_game():
	print("Server ordered game start!")
	game_started.emit()

@rpc("any_peer", "call_local", "reliable")
func request_unit_move(unit_name: String, target_pos: Vector3, enemy_target_name: String):
	if not is_host:
		print("Client attempted to run request_unit_move, but must be host!")
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	print("Host received request_unit_move from ", sender_id, " for unit: ", unit_name, " enemy: ", enemy_target_name)
	
	# Future enhancement: The host should lookup the unit by `unit_name` and 
	# verify that `unit.faction_name` actually matches `players[sender_id]["faction"]`.
	# For now, we trust the client's `_handle_click` block and just broadcast.
	if players.has(sender_id):
		rpc("sync_unit_target", unit_name, target_pos, enemy_target_name)

@rpc("authority", "call_local", "reliable")
func sync_unit_target(unit_name: String, target_pos: Vector3, enemy_target_name: String):
	print("Peer ", multiplayer.get_unique_id(), " received sync_unit_target for ", unit_name, " enemy: ", enemy_target_name)
	unit_target_synced.emit(unit_name, target_pos, enemy_target_name)

