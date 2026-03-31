class_name TacticalAI
extends Node

enum AIState { IDLE, PRODUCING, RALLYING, ATTACKING }

var faction_name: String = ""
var aggression_factor: float = 0.5
var capability_level: int = 1
var current_state: AIState = AIState.IDLE

var target_purchase: String = ""
var target_purchase_cost: float = 0.0

var high_value_targets: Array[Node3D] = []
var owned_units: Array[Node3D] = []
var rally_point: Vector3 = Vector3.ZERO
var target_city: Node3D = null

var process_timer: float = -10.0
const PROCESS_INTERVAL: float = 2.0 # Evaluate AI logic every 2 seconds

var globe_view: Node3D = null
var network_manager = null

func _ready() -> void:
	network_manager = get_node_or_null("/root/NetworkManager")

func set_faction(fac: String, aggro: float = 0.5, cap: int = 1) -> void:
	faction_name = fac
	aggression_factor = aggro
	capability_level = cap
	current_state = AIState.PRODUCING
	
	globe_view = get_node_or_null("/root/Main/GlobeContainer/SubViewport/GlobeView")
	if not globe_view:
		# Fallback just in case tree is structured differently
		var main_scene = get_tree().root.get_node_or_null("Main")
		if main_scene and main_scene.get("globe_view"):
			globe_view = main_scene.globe_view

var time_since_last_priority_log: float = 0.0

func _process(delta: float) -> void:
	if not globe_view or faction_name == "":
		return
		
	# Only the host runs AI logic to ensure multiplayer sync
	if network_manager and not network_manager.is_host:
		return
		
	time_since_last_priority_log += delta
	if time_since_last_priority_log >= 150.0:
		time_since_last_priority_log = 0.0
		if target_purchase != "":
			_log_target_purchase()
			
	process_timer += delta
	if process_timer >= PROCESS_INTERVAL:
		process_timer -= PROCESS_INTERVAL
		_evaluate_state()

func _evaluate_state() -> void:
	_refresh_owned_units()
	
	match current_state:
		AIState.IDLE:
			current_state = AIState.PRODUCING
			
		AIState.PRODUCING:
			_handle_production()
			if owned_units.size() > 0:
				current_state = AIState.RALLYING
				
		AIState.RALLYING:
			_handle_rallying()
			_handle_production()
			_handle_air_ops()
			_handle_nuke_ops()
			if owned_units.size() >= 3 or (aggression_factor > 0.8 and owned_units.size() > 0):
				current_state = AIState.ATTACKING
				
		AIState.ATTACKING:
			_handle_attacking()
			_handle_production()
			_handle_air_ops()
			_handle_nuke_ops()
			if owned_units.size() == 0:
				current_state = AIState.PRODUCING
				
func _refresh_owned_units() -> void:
	var current_units: Array[Node3D] = []
	for u in globe_view.units_list:
		if is_instance_valid(u) and not u.get("is_dead") and u.get("faction_name") == faction_name:
			current_units.append(u)
			
	owned_units = current_units
	
	# Determine friendly cities map
	var main_scene = get_node_or_null("/root/Main")
	var own_cities = []
	if main_scene and main_scene.scenario_data.has("factions") and main_scene.scenario_data["factions"].has(faction_name):
		own_cities = main_scene.scenario_data["factions"][faction_name].get("cities", [])
		
	if is_instance_valid(target_city) and target_city.name in own_cities:
		target_city = null
		
	# Automatically calculate rally point near our average city position or unit position
	if rally_point == Vector3.ZERO:
		var sum_pos = Vector3.ZERO
		var count = 0
		for cn in globe_view.city_nodes:
			if is_instance_valid(cn) and cn.name in own_cities:
				sum_pos += cn.global_position
				count += 1
		if count > 0:
			rally_point = (sum_pos / float(count)).normalized() * globe_view.radius

func _handle_production() -> void:
	var main_scene = get_node_or_null("/root/Main")
	if not main_scene or not main_scene.scenario_data.has("factions"):
		return
		
	var fac_data = main_scene.scenario_data["factions"].get(faction_name, {})
	var money = fac_data.get("money", 0.0)
	var own_cities = fac_data.get("cities", [])
	
	if own_cities.size() == 0:
		return
		
	# Unit costs from MainScene
	# Infantry: 5.0, Armor: 10.0, Air: 30.0, Cruiser: 50.0
	
	var fac_nukes = fac_data.get("nukes", 0)
	
	if target_purchase == "":
		var wants_nuke = false
		if capability_level > 1 and fac_nukes < 3:
			if randf() < 0.1:
				target_purchase = "Nuke"
				target_purchase_cost = 20.0
				
		if target_purchase == "":
			if capability_level >= 1 and main_scene.scenario_data.has("countries"):
				var best_fa_country = ""
				var best_fa_score = 0.0
				
				for c_name in main_scene.scenario_data["countries"].keys():
					var c_data = main_scene.scenario_data["countries"][c_name]
					var num_cities = c_data.get("cities", []).size()
					if num_cities == 0: continue
					
					var current_op = c_data.get("opinions", {}).get(faction_name, 0.0)
					if current_op >= 50.0: continue # already allied
					
					var shift = 100.0 / float(num_cities)
					var new_op = current_op + shift
					
					var score = shift
					
					if current_op < 50.0 and new_op >= 50.0:
						score += 150.0 
					elif current_op < 0.0 and new_op >= 0.0:
						score += 100.0 
						
					# Penalize if heavily garrisoned by enemies
					var enemy_garrison = 0
					var friend_garrison = 0
					
					for c_city in c_data.get("cities", []):
						var c_pos = Vector3.ZERO
						for cn in globe_view.city_nodes:
							if cn.name == "Unit_City_" + c_city:
								c_pos = cn.global_position
								break
						if c_pos != Vector3.ZERO:
							for u in globe_view.units_list:
								if is_instance_valid(u) and not u.get("is_dead"):
									if u.current_position.distance_to(c_pos) < 0.05:
										if u.get("faction_name") == faction_name:
											friend_garrison += 1
										elif u.get("faction_name") != faction_name: # any enemy
											enemy_garrison += 1
					
					if enemy_garrison > friend_garrison:
						score -= (enemy_garrison - friend_garrison) * 20.0
						
					if score > best_fa_score:
						best_fa_score = score
						best_fa_country = c_name
						
				if best_fa_country != "" and best_fa_score > 30.0: 
					if randf() < 0.6: 
						target_purchase = "Foreign Aid:" + best_fa_country
						target_purchase_cost = 10.0

		if target_purchase == "":
			if capability_level > 1:
				# Intelligent composition: Look at enemy units
				var enemy_has_air = false
				var enemy_has_sea = false
				for u in globe_view.units_list:
					if is_instance_valid(u) and u.get("faction_name") != faction_name and not u.get("is_dead"):
						if u.get("unit_type") == "Air": enemy_has_air = true
						if u.get("unit_type") in ["Cruiser", "Submarine"]: enemy_has_sea = true
						
				if enemy_has_air and randf() < 0.6:
					target_purchase = "Air"
					target_purchase_cost = 30.0
				elif enemy_has_sea and randf() < 0.6:
					target_purchase = "Submarine"
					target_purchase_cost = 35.0
				elif randf() < 0.4:
					target_purchase = "Armor"
					target_purchase_cost = 20.0
				else:
					target_purchase = "Infantry"
					target_purchase_cost = 5.0
			else:
				# Dumb composition: Pick mostly random
				var roll = randf()
				if roll < 0.1:
					target_purchase = "Cruiser"
					target_purchase_cost = 50.0
				elif roll < 0.3:
					target_purchase = "Submarine"
					target_purchase_cost = 35.0
				elif roll < 0.5:
					target_purchase = "Air"
					target_purchase_cost = 30.0
				elif roll < 0.7:
					target_purchase = "Armor"
					target_purchase_cost = 20.0
				else:
					target_purchase = "Infantry"
					target_purchase_cost = 5.0
					
			if target_purchase != "":
				_log_target_purchase()
				time_since_last_priority_log = 0.0
					
	if target_purchase != "" and money >= target_purchase_cost:
		if target_purchase == "Nuke":
			if network_manager and network_manager.multiplayer.has_multiplayer_peer() and network_manager.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				globe_view.rpc("sync_nuke_purchase", faction_name, 20.0)
			else:
				globe_view.sync_nuke_purchase(faction_name, 20.0)
		elif target_purchase.begins_with("Foreign Aid:"):
			var target_country = target_purchase.split(":")[1]
			if network_manager and network_manager.multiplayer.has_multiplayer_peer() and network_manager.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				globe_view.rpc("request_foreign_aid", target_country, faction_name)
			else:
				globe_view.request_foreign_aid(target_country, faction_name)
		else:
			# Find an available city (no cooldown)
			var best_city = ""
			var is_sea_unit = (target_purchase in ["Cruiser", "Submarine"])
			
			for c in own_cities:
				if not globe_view.city_cooldowns.has(c):
					if is_sea_unit and globe_view.has_method("_is_city_coastal"):
						if not globe_view._is_city_coastal(c):
							continue
					best_city = c
					break
					
			if best_city == "":
				if is_sea_unit:
					# We want a sea unit, but have no available coastal cities. Clear the queue so we don't softlock!
					target_purchase = ""
					target_purchase_cost = 0.0
				return # Wait for next loop if all cities are on cooldown
				
			var c_name = best_city if typeof(best_city) == TYPE_STRING else best_city.name
			# Spawn using Host RPC directly, with offline fallback for unit tests
			if network_manager and network_manager.multiplayer.has_multiplayer_peer() and network_manager.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				globe_view.rpc("sync_unit_purchase", c_name, target_purchase, faction_name, target_purchase_cost)
			else:
				globe_view.sync_unit_purchase(c_name, target_purchase, faction_name, target_purchase_cost)
				
		# Reset our savings goal so we can pick a new target next time
		target_purchase = ""
		target_purchase_cost = 0.0

func _log_target_purchase() -> void:
	if target_purchase == "":
		return
		
	var target_peer_id = -1
	if network_manager and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if network_manager.get("players") != null:
			for p_id in network_manager.players.keys():
				if network_manager.players[p_id].has("faction") and network_manager.players[p_id]["faction"] == faction_name:
					target_peer_id = p_id
					break
			
	var cm = get_node_or_null("/root/ConsoleManager")
	if cm:
		var col = "#cccccc"
		var main_scene = get_node_or_null("/root/Main")
		if main_scene and main_scene.scenario_data.has("factions") and main_scene.scenario_data["factions"].has(faction_name):
			col = main_scene.scenario_data["factions"][faction_name].get("color", "#cccccc")

		var fac = faction_name
		if globe_view and globe_view.has_method("_get_fac_color_rich"):
			fac = globe_view._get_fac_color_rich(faction_name)
		else:
			fac = "[outline_size=2][outline_color=#dddddd][color=" + col + "]" + faction_name + "[/color][/outline_color][/outline_size]"

		var msg = fac + " AI Command: Authorizing funds for " + target_purchase + " production."
		
		if target_peer_id != -1:
			if multiplayer.has_multiplayer_peer() and target_peer_id == multiplayer.get_unique_id():
				if cm.has_method("local_log_message"):
					cm.local_log_message(msg)
			elif multiplayer.has_multiplayer_peer():
				cm.rpc_id(target_peer_id, "sync_log_message", msg)
		else:
			# If no player owns the faction, fall back to testing if the local API is disconnected
			if not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
				if cm.has_method("local_log_message"):
					cm.local_log_message(msg)

func _find_high_value_target() -> Node3D:
	var main_scene = get_node_or_null("/root/Main")
	var own_cities = []
	var own_oil = []
	var has_shortage = false
	
	if main_scene and main_scene.scenario_data.has("factions") and main_scene.scenario_data["factions"].has(faction_name):
		own_cities = main_scene.scenario_data["factions"][faction_name].get("cities", [])
		own_oil = main_scene.scenario_data["factions"][faction_name].get("oil", [])
		has_shortage = main_scene.scenario_data["factions"][faction_name].get("oil_shortage", false)
		
	var targets = []
	for cn in globe_view.city_nodes:
		if is_instance_valid(cn) and not (cn.name in own_cities):
			targets.append(cn)
			
	if globe_view.get("oil_nodes") != null:
		for on in globe_view.oil_nodes:
			if is_instance_valid(on) and not (on.name in own_oil):
				targets.append(on)
			
	if targets.size() == 0:
		return null
		
	# Pick closest, heavily prioritizing Capitols and injecting noise
	var best_target = null
	var best_dist = 99999.0
	
	var enemy_capitols = []
	if main_scene and main_scene.scenario_data.has("factions"):
		for f in main_scene.scenario_data["factions"]:
			if f != faction_name and main_scene.scenario_data["factions"][f].has("capitol"):
				enemy_capitols.append(main_scene.scenario_data["factions"][f]["capitol"])
	
	var start_id = -1
	if globe_view.get("map_data") != null and globe_view.map_data.get("land_astar") != null:
		start_id = globe_view.map_data.land_astar.get_closest_point(rally_point)
		
	for t in targets:
		if start_id != -1:
			var end_id = globe_view.map_data.land_astar.get_closest_point(t.global_position)
			if end_id != -1:
				var path = globe_view.map_data.land_astar.get_id_path(start_id, end_id)
				if path.size() == 0 and start_id != end_id:
					continue # No connecting landmass exists!
					
		var dist = t.global_position.distance_to(rally_point)
		
		# Heavily weight capitols by mathematically shrinking their perceived distance natively
		if t.name in enemy_capitols:
			dist *= 0.1 
			
		var is_oil = false
		if globe_view.get("oil_nodes") != null and globe_view.oil_nodes.has(t):
			is_oil = true
			
		if is_oil:
			if has_shortage:
				dist *= 0.1
			else:
				dist *= 0.5
			
		var t_faction = globe_view._get_city_faction(t.name)
		if t_faction == "neutral":
			# Huge penalty for targeting neutral neutral cities to avoid the -100 opinion penalty
			dist *= 10.0
			
		# Structural noise generation (10% variance) breaks deterministic array cycling permanently
		dist *= randf_range(0.9, 1.1)
		
		if dist < best_dist:
			best_dist = dist
			best_target = t
			
	return best_target

func _handle_rallying() -> void:
	for u in owned_units:
		if is_instance_valid(u) and u.get("unit_type") != "Air" and not u.get("is_engaged"):
			if _process_unit_repair(u):
				continue
				
			if u.get("unit_type") in ["Cruiser", "Submarine"]:
				continue # Prevent sea units from arbitrarily marching inland to the global rally point
				
			var dist = u.global_position.distance_to(rally_point)
			if dist > 0.01:
				_issue_move_order(u, rally_point)

func _handle_attacking() -> void:
	if not is_instance_valid(target_city):
		target_city = _find_high_value_target()
		
	if not is_instance_valid(target_city):
		# No targets left
		return
		
	# Move rally point progressively towards target city
	if is_instance_valid(target_city):
		rally_point = rally_point.slerp(target_city.global_position, 0.1).normalized() * globe_view.radius
	
	var target_assignments = {}
	var occupied_tiles = []
	
	# Pre-cache all occupied tiles and persistent attack arrays to prevent iteration toggling natively
	for ou in globe_view.units_list:
		if is_instance_valid(ou) and not ou.get("is_dead"):
			var ou_pos = ou.get("target_position")
			if ou_pos == null:
				ou_pos = ou.get("current_position")
			if ou_pos != null:
				var t_id = globe_view._get_tile_from_vector3(ou_pos)
				if not occupied_tiles.has(t_id):
					occupied_tiles.append(t_id)
			
			if ou.get("faction_name") == faction_name and ou.has_meta("attack_target_name"):
				var t_name = ou.get_meta("attack_target_name")
				if not target_assignments.has(t_name):
					target_assignments[t_name] = []
				
				var t_hex = -2
				if ou.has_meta("attack_target_hex"):
					t_hex = ou.get_meta("attack_target_hex")
				
				if t_hex != -2:
					target_assignments[t_name].append(t_hex)
					
	for u in owned_units:
		if not is_instance_valid(u) or u.get("unit_type") == "Air":
			continue
			
		if _process_unit_repair(u):
			continue
			
		# Tactical Engagement override
		var closest_enemy = _get_closest_enemy(u)
		if closest_enemy != null:
			var dist_to_enemy = u.global_position.distance_to(closest_enemy.global_position)
			if dist_to_enemy < 0.1: # Within tactical range
				var u_health = u.get("health")
				if u_health != null and u_health < 30.0:
					var run_vec = (u.global_position - closest_enemy.global_position).normalized()
					var kite_pos = (u.global_position + run_vec * 0.1).normalized() * globe_view.radius
					_issue_move_order(u, kite_pos)
					continue
				else:
					# Attack! We allow the AI to push targets UNLESS the unit is already fiercely brawling
					if u.get("is_engaged"):
						continue
						
					var t_name = closest_enemy.name
					if not target_assignments.has(t_name):
						target_assignments[t_name] = []
						
					var enemy_tile = globe_view._get_tile_from_vector3(closest_enemy.global_position)
					
					# Discard old metadata if target shifted hexes or swapped targets
					var tracked_enemy = u.get_meta("attack_target_name") if u.has_meta("attack_target_name") else ""
					var tracked_home_tile = u.get_meta("attack_enemy_tile") if u.has_meta("attack_enemy_tile") else -1
					var my_assignment = u.get_meta("attack_target_hex") if u.has_meta("attack_target_hex") else -2
					
					if tracked_enemy != t_name or tracked_home_tile != enemy_tile:
						my_assignment = -2 # Invalidated
					
					if my_assignment != -2:
						# Persist existing un-toggled assignment
						if my_assignment == -1:
							_issue_move_order(u, closest_enemy.global_position, t_name)
						else:
							var n_pos = globe_view.map_data.get_centroid(my_assignment).normalized() * globe_view.radius
							
							var current_target_pos = u.get("target_position")
							var current_target_tile = -1
							if current_target_pos != null:
								current_target_tile = globe_view._get_tile_from_vector3(current_target_pos)
								
							if current_target_tile != my_assignment or not u.get("is_moving"):
								_issue_move_order(u, n_pos, "") # Strip name to snap to tile center
					else:
						var count = target_assignments[t_name].size()
						
						if count == 0:
							target_assignments[t_name].append(-1) # Lead attacker takes exact center
							u.set_meta("attack_target_name", t_name)
							u.set_meta("attack_enemy_tile", enemy_tile)
							u.set_meta("attack_target_hex", -1)
							_issue_move_order(u, closest_enemy.global_position, t_name)
						else:
							var neighbors = globe_view.map_data.get_neighbors(enemy_tile)
							var best_neighbor = -1
							var min_dist = INF
							var u_type = u.get("unit_type")
							
							# Scramble neighbor array to prevent directional biases natively
							var shuffled_neighbors = neighbors.duplicate()
							shuffled_neighbors.shuffle()
							
							for n in shuffled_neighbors:
								if occupied_tiles.has(n) or target_assignments[t_name].has(n):
									continue # Hex physically occupied or already assigned to a friendly
									
								var n_terrain = globe_view.map_data.get_terrain(n)
								var is_valid = false
								
								if u_type == "Infantry" or u_type == "Armor":
									if globe_view.city_tile_cache.has(n):
										is_valid = true
									elif n_terrain != "OCEAN" and n_terrain != "DEEP_OCEAN" and n_terrain != "LAKE":
										is_valid = true
								elif u_type in ["Cruiser", "Submarine"]:
									if n_terrain == "OCEAN" or n_terrain == "DEEP_OCEAN" or n_terrain == "LAKE" or n_terrain == "COAST":
										is_valid = true
								if is_valid:
									var n_pos = globe_view.map_data.get_centroid(n).normalized() * globe_view.radius
									if u_type != "Air":
										var test_path = globe_view.map_data.find_path(u.global_position, n_pos, u_type)
										if test_path.size() == 0 and u.global_position.distance_to(n_pos) >= 0.005:
											is_valid = false
											
								if is_valid:
									var n_pos = globe_view.map_data.get_centroid(n).normalized() * globe_view.radius
									var dist = u.global_position.distance_to(n_pos)
									
									if u_type in ["Infantry", "Armor"]:
										var c_name = globe_view.map_data.get_region(n)
										if c_name != "" and globe_view.active_scenario.has("countries") and globe_view.active_scenario["countries"].has(c_name):
											var is_neutral = false
											var c_data = globe_view.active_scenario["countries"][c_name]
											if c_data.has("cities"):
												for city in c_data["cities"]:
													if globe_view.active_scenario.has("neutral_cities") and globe_view.active_scenario["neutral_cities"].has(city):
														is_neutral = true
														break
											if is_neutral:
												dist *= 15.0 # High penalty for pathing into neutral borders to flank!
									
									if dist < min_dist:
										min_dist = dist
										best_neighbor = n
										
							if best_neighbor != -1:
								target_assignments[t_name].append(best_neighbor)
								occupied_tiles.append(best_neighbor)
								u.set_meta("attack_target_name", t_name)
								u.set_meta("attack_enemy_tile", enemy_tile)
								u.set_meta("attack_target_hex", best_neighbor)
								
								var n_pos = globe_view.map_data.get_centroid(best_neighbor).normalized() * globe_view.radius
								
								var current_target_pos = u.get("target_position")
								var current_target_tile = -1
								if current_target_pos != null:
									current_target_tile = globe_view._get_tile_from_vector3(current_target_pos)
									
								if current_target_tile != best_neighbor or not u.get("in_motion"):
									_issue_move_order(u, n_pos, "") # Flank units strip t_name to override Engine snapping
							else:
								# All neighbor hexes invalid or full, force march directly behind to queue naturally
								u.set_meta("attack_target_name", t_name)
								u.set_meta("attack_enemy_tile", enemy_tile)
								u.set_meta("attack_target_hex", -1)
								_issue_move_order(u, closest_enemy.global_position, t_name)
								
					continue
		
		# Clear target metadata if no close enemy applies
		if u.has_meta("attack_target_name"):
			u.remove_meta("attack_target_name")
		
		# Otherwise march to target
		if not u.get("is_engaged"):
			if u.get("unit_type") in ["Cruiser", "Submarine"]:
				continue # Sea units shouldn't march blindly across landmasses
			var dist = u.global_position.distance_to(target_city.global_position)
			if dist > 0.002:
				_issue_move_order(u, target_city.global_position)

func _handle_air_ops() -> void:
	if not is_instance_valid(target_city):
		target_city = _find_high_value_target()
		
	for u in owned_units:
		if not is_instance_valid(u) or u.get("unit_type") != "Air" or not u.get("is_air_ready"):
			continue
			
		var unit_pos = u.global_position
		
		# 1. Look for strike opportunities
		var best_target = null
		var min_dist = INF
		# Air strike radius is roughly 0.165 world units
		var strike_radius = 0.165
		
		for enemy in globe_view.units_list:
			if is_instance_valid(enemy) and not enemy.get("is_dead") and enemy.get("faction_name") != faction_name:
				if enemy.get("unit_type") == "Air": continue
				if not _is_enemy_visible_to_faction(enemy): continue
				var dist = unit_pos.distance_to(enemy.global_position)
				if dist <= strike_radius and dist < min_dist:
					min_dist = dist
					best_target = enemy
					
		if best_target:
			if network_manager and network_manager.is_host:
				network_manager.rpc_id(1, "request_air_strike", u.name, best_target.name)
			continue
			
		# 2. Look for strategic bombing opportunities
		var best_bomb_target = null
		min_dist = INF
		
		for cn in globe_view.city_nodes:
			if is_instance_valid(cn):
				var c_faction = globe_view._get_city_faction(cn.name)
				if c_faction != faction_name and c_faction != "neutral":
					# Only bomb ENEMY cities (avoiding neutrality penalties)
					var dist = unit_pos.distance_to(cn.global_position)
					if dist <= strike_radius and dist < min_dist:
						min_dist = dist
						best_bomb_target = cn
						
		if best_bomb_target:
			if network_manager and network_manager.is_host:
				network_manager.rpc_id(1, "request_strategic_bombing", u.name, best_bomb_target.name)
			continue
			
		# 3. Look for redeployment opportunities if far from front lines
		if is_instance_valid(target_city):
			var dist_to_front = unit_pos.distance_to(target_city.global_position)
			if dist_to_front > 0.15: # Far from front line target
				var best_redeploy_city = null
				var max_improvement = 0.0
				var redeploy_radius = 1.65
				
				var main_scene = get_node_or_null("/root/Main")
				if main_scene and main_scene.scenario_data.has("factions") and main_scene.scenario_data["factions"].has(faction_name):
					var own_cities = main_scene.scenario_data["factions"][faction_name].get("cities", [])
					for city_name in own_cities:
						var c_node = null
						for cn in globe_view.city_nodes:
							if cn.name == city_name:
								c_node = cn
								break
						if c_node:
							var city_dist_to_front = c_node.global_position.distance_to(target_city.global_position)
							if city_dist_to_front < dist_to_front:
								var improvement = dist_to_front - city_dist_to_front
								if improvement > max_improvement and unit_pos.distance_to(c_node.global_position) <= redeploy_radius:
									max_improvement = improvement
									best_redeploy_city = c_node
									
				if best_redeploy_city:
					if network_manager and network_manager.is_host:
						network_manager.rpc_id(1, "request_air_redeploy", u.name, best_redeploy_city.name)

func _get_closest_enemy(unit: Node3D) -> Node3D:
	var best = null
	var best_dist = 99999.0
	var is_sea_unit = unit.get("unit_type") in ["Cruiser", "Submarine"]
	for other in globe_view.units_list:
		if is_instance_valid(other) and other != unit and not other.get("is_dead") and other.get("faction_name") != faction_name:
			if not _is_enemy_visible_to_faction(other): continue
			if other.get("unit_type") == "Submarine" and not other.get("is_detected"):
				continue # AI cannot target hidden submarines out of fairness
				
			var d = unit.global_position.distance_to(other.global_position)
			
			if is_sea_unit:
				var e_tile = globe_view._get_tile_from_vector3(other.global_position)
				var e_terrain = globe_view.map_data.get_terrain(e_tile)
				if globe_view.city_tile_cache.has(e_tile):
					if e_terrain == "OCEAN" or e_terrain == "LAKE":
						e_terrain = "DOCKS"
					else:
						e_terrain = "CITY"
						
				if e_terrain != "OCEAN" and e_terrain != "LAKE" and e_terrain != "COAST" and e_terrain != "DEEP_OCEAN" and e_terrain != "DOCKS":
					# Target is firmly on land! We can only engage if they are ALREADY within firing range!
					var enemy_range = 0.0165 if other.get("unit_type") in ["Cruiser", "Submarine"] else 0.012
					var threshold = (0.0165 + enemy_range) / 2.0
					if d >= (threshold - 0.001):
						continue # We would have to move inland to reach them, impossible!
						
			if not is_sea_unit and unit.get("unit_type") != "Air":
				if other.get("unit_type") in ["Cruiser", "Submarine"]:
					# Land units aggressively deprioritize engaging Naval assets avoiding inherent Sea Transport vulnerabilities
					d *= 3.0
					
			# Add 5% structural tactical noise to prevent uniform parallel targeting jams natively
			d *= randf_range(0.95, 1.05)
			
			if d < best_dist:
				best_dist = d
				best = other
	return best

func _issue_move_order(unit: Node3D, target_pos: Vector3, enemy_target_name: String = "") -> void:
	# Debounce identical move orders to fundamentally prevent RPC spam and infinite looping lockups
	var last_pos = unit.get_meta("last_ordered_target_pos", Vector3.INF)
	var last_enemy = unit.get_meta("last_ordered_enemy", "NONE")
	var last_time = unit.get_meta("last_ordered_time", 0)
	
	if last_pos.distance_to(target_pos) < 0.005 and last_enemy == enemy_target_name and (Time.get_ticks_msec() - last_time) < 3000:
		return # Suppression: We already gave this exact instruction recently!
	
	unit.set_meta("last_ordered_target_pos", target_pos)
	unit.set_meta("last_ordered_enemy", enemy_target_name)
	unit.set_meta("last_ordered_time", Time.get_ticks_msec())

	# Use network manager to sync movement, ensuring parity with players
	if network_manager and network_manager.is_host:
		network_manager.unit_move_requested.emit(unit.name, target_pos, enemy_target_name)

func _is_enemy_visible_to_faction(enemy: Node3D) -> bool:
	var vision_range = 0.036
	var e_pos = enemy.global_position
	
	# Check friendly units
	for u in owned_units:
		if is_instance_valid(u) and not u.get("is_dead"):
			var u_type = u.get("unit_type")
			if u_type == "Air" and u.get("is_air_ready"):
				if u.global_position.distance_to(e_pos) <= 0.165:
					return true
			else:
				if u.global_position.distance_to(e_pos) <= vision_range:
					return true
				
	# Check friendly cities
	var main_scene = get_node_or_null("/root/Main")
	if main_scene and main_scene.scenario_data.has("factions") and main_scene.scenario_data["factions"].has(faction_name):
		var own_cities = main_scene.scenario_data["factions"][faction_name].get("cities", [])
		for city_name in own_cities:
			var c_node = null
			for cn in globe_view.city_nodes:
				if cn.name == city_name:
					c_node = cn
					break
			if c_node and c_node.global_position.distance_to(e_pos) <= vision_range:
				return true

	return false

func _process_unit_repair(u: Node3D) -> bool:
	var u_health = u.get("health")
	if u_health != null:
		if u_health < 40.0:
			u.set_meta("needs_repair", true)
		elif u_health >= 90.0:
			u.set_meta("needs_repair", false)
			
	if u.has_meta("needs_repair") and u.get_meta("needs_repair"):
		var nearest_city = _get_closest_friendly_city(u)
		if nearest_city:
			var target_pos = nearest_city.global_position
			
			if globe_view.get("city_tile_cache") != null and globe_view.get("map_data") != null:
				var available_tiles = []
				for t_id in globe_view.city_tile_cache:
					if globe_view.city_tile_cache[t_id] == nearest_city.name:
						available_tiles.append(t_id)
						
				if available_tiles.is_empty():
					var city_tile = globe_view._get_tile_from_vector3(nearest_city.global_position)
					available_tiles.append(city_tile)
					
				var u_type = u.get("unit_type")
				var is_sea_unit = u_type in ["Cruiser", "Submarine"]
				
				var valid_tiles = []
				for t in available_tiles:
					var t_terrain = globe_view.map_data.get_terrain(t)
					if is_sea_unit and t_terrain != "OCEAN" and t_terrain != "LAKE":
						continue
						
					var is_occupied = false
					var c_pos = globe_view.map_data.get_centroid(t).normalized() * globe_view.radius
					
					for other in globe_view.units_list:
						if is_instance_valid(other) and other != u and not other.get("is_dead"):
							var o_pos = other.get("target_position")
							if o_pos == null:
								o_pos = other.get("current_position")
							if o_pos != null and o_pos.distance_to(c_pos) < 0.005:
								is_occupied = true
								break
								
					if not is_occupied:
						valid_tiles.append(t)
						
				if valid_tiles.size() > 0:
					var best_t = valid_tiles[0]
					var best_d = INF
					for t in valid_tiles:
						var pt = globe_view.map_data.get_centroid(t).normalized() * globe_view.radius
						var d = u.global_position.distance_to(pt)
						if d < best_d:
							best_d = d
							best_t = t
					target_pos = globe_view.map_data.get_centroid(best_t).normalized() * globe_view.radius
				else:
					# All proper tiles are occupied. Find the closest one just to maneuver towards it.
					var fallback_tiles = []
					for t in available_tiles:
						var t_terrain = globe_view.map_data.get_terrain(t)
						if is_sea_unit and t_terrain != "OCEAN" and t_terrain != "LAKE":
							continue
						fallback_tiles.append(t)
						
					if fallback_tiles.size() > 0:
						var best_t = fallback_tiles[0]
						var best_d = INF
						for t in fallback_tiles:
							var pt = globe_view.map_data.get_centroid(t).normalized() * globe_view.radius
							var d = u.global_position.distance_to(pt)
							if d < best_d:
								best_d = d
								best_t = t
						target_pos = globe_view.map_data.get_centroid(best_t).normalized() * globe_view.radius
						
					if u.global_position.distance_to(target_pos) < 0.02:
						# We have arrived near the full port. Halt and wait our turn.
						_issue_move_order(u, u.global_position)
						return true

			var dist = u.global_position.distance_to(target_pos)
			if dist > 0.005:
				_issue_move_order(u, target_pos)
			else:
				# We are in the city, stop and heal!
				_issue_move_order(u, u.global_position)
			return true
		else:
			# If no friendly cities exist, we cannot repair! Fight to the death.
			u.set_meta("needs_repair", false)
			return false
	return false

func _get_closest_friendly_city(unit: Node3D) -> Node3D:
	var main_scene = get_node_or_null("/root/Main")
	if not main_scene or not main_scene.scenario_data.has("factions"):
		return null
		
	var fac_data = main_scene.scenario_data["factions"].get(faction_name, {})
	var own_cities = fac_data.get("cities", [])
	
	var best_city = null
	var best_dist = INF
	
	var is_sea_unit = unit.get("unit_type") in ["Cruiser", "Submarine"]
	
	var start_id = -1
	if globe_view.get("map_data") != null:
		var astar = globe_view.map_data.naval_astar if is_sea_unit else globe_view.map_data.land_astar
		start_id = astar.get_closest_point(unit.global_position)
	
	for cn in globe_view.city_nodes:
		if is_instance_valid(cn) and cn.name in own_cities:
			if globe_view.get("map_data") != null:
				var is_reachable = false
				
				var has_valid_docks = false
				if is_sea_unit:
					if globe_view.get("city_tile_cache") != null:
						for c_tid in globe_view.city_tile_cache:
							if globe_view.city_tile_cache[c_tid] == cn.name:
								var c_terrain = globe_view.map_data.get_terrain(c_tid)
								if c_terrain == "OCEAN" or c_terrain == "LAKE":
									has_valid_docks = true
									var end_id = globe_view.map_data.naval_astar.get_closest_point(globe_view.map_data.get_centroid(c_tid))
									if start_id != -1 and end_id != -1:
										var path = globe_view.map_data.naval_astar.get_id_path(start_id, end_id)
										if path.size() > 0 or start_id == end_id:
											is_reachable = true
											break
					if not has_valid_docks or not is_reachable:
						continue
				else:
					var end_id = globe_view.map_data.land_astar.get_closest_point(cn.global_position)
					if start_id != -1 and end_id != -1:
						var path = globe_view.map_data.land_astar.get_id_path(start_id, end_id)
						if path.size() > 0 or start_id == end_id:
							is_reachable = true
							
					if not is_reachable:
						continue
				
			var dist = unit.global_position.distance_to(cn.global_position)
			if dist < best_dist:
				best_dist = dist
				best_city = cn
				
	return best_city

func _handle_nuke_ops() -> void:
	var main_scene = get_node_or_null("/root/Main")
	if not main_scene or not main_scene.scenario_data.has("factions"): return
	var fac_data = main_scene.scenario_data["factions"].get(faction_name, {})
	var nukes = fac_data.get("nukes", 0)
	if nukes <= 0: return
	
	# Verify +3 launch threshold
	var my_launched = fac_data.get("nukes_launched", 0)
	var max_others = 0
	for f in main_scene.scenario_data["factions"].keys():
		if f != faction_name:
			max_others = max(max_others, main_scene.scenario_data["factions"][f].get("nukes_launched", 0))
	if my_launched >= max_others + 3:
		return
		
	# Gather all enemy capitols for SDI check (1.5 radius)
	var enemy_capitols_pos = []
	for f in main_scene.scenario_data["factions"].keys():
		if f != faction_name:
			var cap = main_scene.scenario_data["factions"][f].get("capitol", "")
			if cap != "":
				for cn in globe_view.city_nodes:
					if is_instance_valid(cn) and cn.name == cap:
						enemy_capitols_pos.append(cn.global_position)
						break
	
	var best_score = -INF
	var best_target_pos = Vector3.ZERO
	
	var potential_targets = []
	for cn in globe_view.city_nodes:
		if is_instance_valid(cn):
			potential_targets.append(cn.global_position)
	for u in globe_view.units_list:
		if is_instance_valid(u) and not u.get("is_dead") and u.get("faction_name") != faction_name:
			if not _is_enemy_visible_to_faction(u): continue
			potential_targets.append(u.global_position)
			
	var inner_rad = 1.35 * 0.006
	var outer_rad = 2.25 * 0.006
	var sdi_rad = 1.5 * 0.006
	
	for t_pos in potential_targets:
		var blocked_by_sdi = false
		for cap_pos in enemy_capitols_pos:
			if t_pos.distance_to(cap_pos) <= sdi_rad:
				blocked_by_sdi = true
				break
		if blocked_by_sdi:
			continue
			
		var score = 0.0
		# Evaluate Units
		for u in globe_view.units_list:
			if is_instance_valid(u) and not u.get("is_dead"):
				var d = t_pos.distance_to(u.global_position)
				if d <= inner_rad:
					if u.get("faction_name") == faction_name:
						score -= 50.0 # Don't nuke yourself
					else:
						var enemy_t_id = globe_view._get_tile_from_vector3(u.global_position)
						var enemy_country = globe_view.map_data.get_region(enemy_t_id)
						var is_in_own_borders = false
						if enemy_country != "" and globe_view.active_scenario.has("countries") and globe_view.active_scenario["countries"].has(enemy_country):
							var c_cities = globe_view.active_scenario["countries"][enemy_country].get("cities", [])
							if c_cities.size() > 0:
								if globe_view._get_city_faction(c_cities[0]) == faction_name:
									is_in_own_borders = true
						
						if is_in_own_borders:
							score += 10.0 # Good, clearing own borders
						else:
							score += 5.0 # Less ideal, just hitting enemies broadly
				elif d <= outer_rad:
					if u.get("faction_name") == faction_name:
						score -= 20.0
					else:
						score += 4.0
						
		# Evaluate Cities
		for cn in globe_view.city_nodes:
			if is_instance_valid(cn):
				var d = t_pos.distance_to(cn.global_position)
				if d <= inner_rad:
					var city_fac = globe_view._get_city_faction(cn.name)
					if city_fac == faction_name:
						score -= 100.0 # Never nuke own cities
					elif city_fac == "neutral":
						score -= 200.0 # Extreme diplomatic penalty for nuking neutrals
					else:
						# If allied:
						var my_fac = globe_view.active_scenario["factions"][faction_name]
						if my_fac.has("allies") and my_fac["allies"].has(city_fac):
							score -= 100.0
						else:
							score += 15.0 # Enemy city
						
		# Final Evaluation Variance
		# Inject a +/- 40% noise into the score so it won't always perfectly target the absolute geometric epicenter
		if score > 0:
			score *= randf_range(0.6, 1.4)
			
		if score > best_score:
			best_score = score
			best_target_pos = t_pos
			
	# Due to the severe diplomatic penalties for launching nukes at all, the AI requires a much higher threshold to justify the launch.
	# Threshold: 25 means at least 1 city (+15) and 1 enemy in borders (+10), or 5 enemies outside borders (+25).
	# Randomize the threshold (25 to 35) so it occasionally "holds fire" waiting for a juicier target
	var dynamic_threshold = randf_range(25.0, 35.0)
	if best_score >= dynamic_threshold:
		if network_manager and network_manager.is_host:
			globe_view.request_nuke_launch(best_target_pos, faction_name)

