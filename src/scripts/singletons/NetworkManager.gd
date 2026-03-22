extends Node

const GAME_VERSION: String = "v0.5.1"

var peer = ENetMultiplayerPeer.new()
var is_host = false
var local_player_name: String = ""
var last_disconnect_reason: String = ""
var match_id: String = "0"

signal connection_succeeded
signal connection_failed(reason: String)
signal server_disconnected

# Lobby Signals
signal players_updated
signal game_started
signal unit_target_synced(unit_name: String, target_pos: Vector3, enemy_target_name: String)
signal air_strike_requested(sender_id: int, unit_name: String, target_unit_name: String)
signal air_strike_synced(unit_name: String, target_unit_name: String, counter_unit_name: String, attacker_status: String, defender_status: String, target_hit: bool)
signal strategic_bombing_requested(sender_id: int, unit_name: String, target_city: String)
signal strategic_bombing_synced(unit_name: String, target_city: String, counter_unit_name: String, attacker_status: String, defender_status: String, success: bool)
signal air_redeploy_synced(unit_name: String, target_city: String)
signal unit_damage_synced(target_unit_name: String, amount: float, attacker_name: String)
signal unit_health_synced(target_unit_name: String, amount: float)

# Dictionary of players: { id: { "name": String, "faction": String } }
var players: Dictionary = {}

var _sync_timer: float = 0.0

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
		players[1] = { "name": local_player_name, "faction": "" }
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

func _process(delta: float) -> void:
	if is_host and multiplayer.has_multiplayer_peer():
		_sync_timer += delta
		if _sync_timer >= 0.25: # Every 0.25 seconds (4Hz)
			_sync_timer -= 0.25
			_broadcast_positions()

func _broadcast_positions() -> void:
	var pos_dict = {}
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if unit.get("current_position") != null:
			var tp = unit.get("target_position")
			pos_dict[unit.name] = {
				"pos": unit.current_position,
				"targ": tp if tp != null else unit.current_position
			}
	
	if pos_dict.size() > 0:
		rpc("sync_unit_positions", pos_dict)

@rpc("authority", "unreliable")
func sync_unit_positions(pos_dict: Dictionary) -> void:
	# Ignore on host since they authoritative anyway
	if is_host:
		return
		
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if pos_dict.has(unit.name):
			var data = pos_dict[unit.name]
			if typeof(data) == TYPE_DICTIONARY and data.has("pos") and data.has("targ"):
				var host_pos = data["pos"]
				var host_targ = data["targ"]
				
				# Update intended destination to ensure client stops simulating if host deadlocked/reached target
				unit.target_position = host_targ
				
				# Seamlessly lerp minor deviations, hard snap major divergences or new spawns
				var dev = unit.current_position.distance_to(host_pos)
				if dev > 0.05:
					unit.current_position = host_pos
				elif dev > 0.0001:
					unit.current_position = unit.current_position.lerp(host_pos, 0.5)

func _on_connected_ok():
	print("Connected to server successfully! Self ID: ", multiplayer.get_unique_id())
	rpc_id(1, "register_name", local_player_name, GAME_VERSION)
	connection_succeeded.emit()

func _on_connected_fail():
	print("Failed to connect to server.")
	connection_failed.emit("Failed to connect to server.")

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
		var p_name = players[id].get("player_name", "")
		if p_name == "":
			p_name = players[id].get("name", "")
			
		if "[BOT]" in p_name:
			if get_tree().root.has_node("ConsoleManager"):
				get_tree().root.get_node("ConsoleManager").log_message("%s has disconnected." % p_name, Color.GRAY)
				
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
		DisplayServer.window_set_title("Dominion Protocol " + GAME_VERSION)
		return
		
	var id = multiplayer.get_unique_id()
	if players.has(id):
		var fac = players[id]["faction"]
		var disp_name = players[id]["name"]
		if fac == "":
			fac = "Unassigned"
		DisplayServer.window_set_title("Dominion Protocol " + GAME_VERSION + " - %s [%s]" % [disp_name, fac])
	else:
		DisplayServer.window_set_title("Dominion Protocol " + GAME_VERSION + " - Player %d" % id)

@rpc("any_peer", "call_local", "reliable")
func register_name(player_name: String, client_version: String = ""):
	if not is_host:
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	if client_version != GAME_VERSION:
		# Use deferred call to prevent immediately killing the connection before RPCs send
		call_deferred("_kick_mismatched_client", sender_id, client_version)
		return
		
	if players.has(sender_id):
		# Prevent incredibly long names or exploits
		players[sender_id]["name"] = player_name.substr(0, 20)
		_sync_players_to_all()

func _kick_mismatched_client(client_id: int, client_version: String):
	var reason = "Version Mismatch. Host: " + GAME_VERSION + " | You: " + (client_version if client_version != "" else "Unknown")
	rpc_id(client_id, "reject_connection", reason)
	await get_tree().create_timer(0.5).timeout
	if multiplayer.has_multiplayer_peer() and players.has(client_id):
		peer.disconnect_peer(client_id)

@rpc("authority", "call_local", "reliable")
func reject_connection(reason: String):
	print("Connection rejected: ", reason)
	last_disconnect_reason = reason
	disconnect_peer()
	get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn")

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

@rpc("any_peer", "call_local", "reliable")
func request_air_strike(unit_name: String, target_unit_name: String):
	if not is_host:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if players.has(sender_id):
		air_strike_requested.emit(sender_id, unit_name, target_unit_name)

func execute_air_strike(unit_name: String, target_unit_name: String, counter_unit_name: String, attacker_status: String, defender_status: String, target_hit: bool):
	if is_host:
		rpc("sync_air_strike", unit_name, target_unit_name, counter_unit_name, attacker_status, defender_status, target_hit)

@rpc("authority", "call_local", "reliable")
func sync_air_strike(unit_name: String, target_unit_name: String, counter_unit_name: String, attacker_status: String, defender_status: String, target_hit: bool):
	air_strike_synced.emit(unit_name, target_unit_name, counter_unit_name, attacker_status, defender_status, target_hit)

@rpc("any_peer", "call_local")
func request_strategic_bombing(unit_name: String, target_city: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if is_host:
		strategic_bombing_requested.emit(sender_id, unit_name, target_city)

func execute_strategic_bombing(unit_name: String, target_city: String, counter_unit_name: String, attacker_status: String, defender_status: String, success: bool):
	if is_host:
		rpc("sync_strategic_bombing", unit_name, target_city, counter_unit_name, attacker_status, defender_status, success)

@rpc("call_local", "authority")
func sync_strategic_bombing(unit_name: String, target_city: String, counter_unit_name: String, attacker_status: String, defender_status: String, success: bool):
	strategic_bombing_synced.emit(unit_name, target_city, counter_unit_name, attacker_status, defender_status, success)

@rpc("any_peer", "call_local", "reliable")
func request_air_redeploy(unit_name: String, target_city: String):
	if not is_host:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if players.has(sender_id):
		rpc("sync_air_redeploy", unit_name, target_city)

@rpc("authority", "call_local", "reliable")
func sync_air_redeploy(unit_name: String, target_city: String):
	air_redeploy_synced.emit(unit_name, target_city)

@rpc("authority", "call_local", "reliable")
func sync_unit_damage(target_unit_name: String, amount: float, attacker_name: String):
	unit_damage_synced.emit(target_unit_name, amount, attacker_name)

@rpc("authority", "call_local", "reliable")
func sync_unit_health(target_unit_name: String, amount: float):
	unit_health_synced.emit(target_unit_name, amount)
