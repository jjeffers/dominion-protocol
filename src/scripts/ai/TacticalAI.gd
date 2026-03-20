class_name TacticalAI
extends Node

enum AIState { IDLE, PRODUCING, RALLYING, ATTACKING }

var faction_name: String = ""
var aggression_factor: float = 0.5
var capability_level: int = 1
var current_state: AIState = AIState.IDLE

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

func _process(delta: float) -> void:
	if not globe_view or faction_name == "":
		return
		
	# Only the host runs AI logic to ensure multiplayer sync
	if network_manager and not network_manager.is_host:
		return
		
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
			if owned_units.size() >= 3 or (aggression_factor > 0.8 and owned_units.size() > 0):
				current_state = AIState.ATTACKING
				
		AIState.ATTACKING:
			_handle_attacking()
			_handle_production()
			_handle_air_ops()
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
		
	# Find an available city (no cooldown)
	var best_city = ""
	for c in own_cities:
		if not globe_view.city_cooldowns.has(c):
			best_city = c
			break
			
	if best_city == "":
		return
		
	# Unit costs from MainScene
	# Infantry: 5.0, Armor: 10.0, Air: 30.0, Cruiser: 50.0
	
	var buy_type = ""
	var cost = 0.0
	
	if capability_level > 1:
		# Intelligent composition: Look at enemy units
		var enemy_has_air = false
		var enemy_has_cruiser = false
		for u in globe_view.units_list:
			if is_instance_valid(u) and u.get("faction_name") != faction_name and not u.get("is_dead"):
				if u.get("unit_type") == "Air": enemy_has_air = true
				if u.get("unit_type") == "Cruiser": enemy_has_cruiser = true
				
		if enemy_has_air and money >= 30.0:
			buy_type = "Air"
			cost = 30.0
		elif money >= 20.0:
			buy_type = "Armor"
			cost = 20.0
		elif money >= 10.0:
			buy_type = "Infantry"
			cost = 5.0
	else:
		# Dumb composition: Buy most expensive
		if money >= 50.0:
			buy_type = "Cruiser"
			cost = 50.0
		elif money >= 30.0:
			buy_type = "Air"
			cost = 30.0
		elif money >= 20.0:
			buy_type = "Armor"
			cost = 20.0
		elif money >= 10.0:
			buy_type = "Infantry"
			cost = 5.0
			
	if buy_type != "":
		var c_name = best_city if typeof(best_city) == TYPE_STRING else best_city.name
		# Spawn using Host RPC directly, with offline fallback for unit tests
		if network_manager and network_manager.multiplayer.has_multiplayer_peer() and network_manager.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			globe_view.rpc("sync_unit_purchase", c_name, buy_type, faction_name, cost)
		else:
			globe_view.sync_unit_purchase(c_name, buy_type, faction_name, cost)

func _find_high_value_target() -> Node3D:
	var main_scene = get_node_or_null("/root/Main")
	var own_cities = []
	if main_scene and main_scene.scenario_data.has("factions") and main_scene.scenario_data["factions"].has(faction_name):
		own_cities = main_scene.scenario_data["factions"][faction_name].get("cities", [])
		
	var targets = []
	for cn in globe_view.city_nodes:
		if is_instance_valid(cn) and not (cn.name in own_cities):
			targets.append(cn)
			
	if targets.size() == 0:
		return null
		
	# Pick closest
	var best_target = null
	var best_dist = 99999.0
	
	for t in targets:
		var dist = t.global_position.distance_to(rally_point)
		if dist < best_dist:
			best_dist = dist
			best_target = t
			
	return best_target

func _handle_rallying() -> void:
	for u in owned_units:
		if is_instance_valid(u) and u.get("unit_type") != "Air" and not u.get("is_engaged"):
			if _process_unit_repair(u):
				continue
			var dist = u.global_position.distance_to(rally_point)
			if dist > 0.05:
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
								
							if current_target_tile != my_assignment or not u.get("in_motion"):
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
								
								if globe_view.city_tile_cache.has(n):
									is_valid = true
								elif u_type == "Infantry" or u_type == "Armor":
									if n_terrain != "OCEAN" and n_terrain != "DEEP_OCEAN" and n_terrain != "LAKE":
										is_valid = true
								elif u_type == "Cruiser":
									if n_terrain == "OCEAN" or n_terrain == "DEEP_OCEAN" or n_terrain == "LAKE" or n_terrain == "COAST":
										is_valid = true
										
								if is_valid:
									var n_pos = globe_view.map_data.get_centroid(n).normalized() * globe_view.radius
									var dist = u.global_position.distance_to(n_pos)
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
			if u.get("unit_type") == "Cruiser":
				continue # Cruisers shouldn't march blindly across landmasses
			var dist = u.global_position.distance_to(target_city.global_position)
			if dist > 0.05:
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
				var dist = unit_pos.distance_to(enemy.global_position)
				if dist <= strike_radius and dist < min_dist:
					min_dist = dist
					best_target = enemy
					
		if best_target:
			if network_manager and network_manager.is_host:
				network_manager.rpc_id(1, "request_air_strike", u.name, best_target.name)
			continue
			
		# 2. Look for redeployment opportunities if far from front lines
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
	var is_cruiser = unit.get("unit_type") == "Cruiser"
	for other in globe_view.units_list:
		if is_instance_valid(other) and other != unit and not other.get("is_dead") and other.get("faction_name") != faction_name:
			var d = unit.global_position.distance_to(other.global_position)
			
			if is_cruiser:
				var e_tile = globe_view._get_tile_from_vector3(other.global_position)
				var e_terrain = globe_view.map_data.get_terrain(e_tile)
				if globe_view.city_tile_cache.has(e_tile):
					if e_terrain == "OCEAN" or e_terrain == "LAKE":
						e_terrain = "DOCKS"
					else:
						e_terrain = "CITY"
						
				if e_terrain != "OCEAN" and e_terrain != "LAKE" and e_terrain != "COAST" and e_terrain != "DEEP_OCEAN" and e_terrain != "DOCKS":
					# Target is firmly on land! We can only engage if they are ALREADY within firing range!
					var enemy_range = 0.0165 if other.get("unit_type") == "Cruiser" else 0.012
					var threshold = (0.0165 + enemy_range) / 2.0
					if d >= (threshold - 0.001):
						continue # We would have to move inland to reach them, impossible!
						
			if d < best_dist:
				best_dist = d
				best = other
	return best

func _issue_move_order(unit: Node3D, target_pos: Vector3, enemy_target_name: String = "") -> void:
	# Use network manager to sync movement, ensuring parity with players
	if network_manager and network_manager.is_host:
		network_manager.rpc("sync_unit_target", unit.name, target_pos, enemy_target_name)
		# call local update
		network_manager.sync_unit_target(unit.name, target_pos, enemy_target_name)

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
			var dist = u.global_position.distance_to(nearest_city.global_position)
			if dist > 0.05:
				_issue_move_order(u, nearest_city.global_position)
			else:
				# We are in the city, stop and heal!
				_issue_move_order(u, u.global_position)
		return true
	return false

func _get_closest_friendly_city(unit: Node3D) -> Node3D:
	var main_scene = get_node_or_null("/root/Main")
	if not main_scene or not main_scene.scenario_data.has("factions"):
		return null
		
	var fac_data = main_scene.scenario_data["factions"].get(faction_name, {})
	var own_cities = fac_data.get("cities", [])
	
	var best_city = null
	var best_dist = INF
	
	for cn in globe_view.city_nodes:
		if is_instance_valid(cn) and cn.name in own_cities:
			var dist = unit.global_position.distance_to(cn.global_position)
			if dist < best_dist:
				best_dist = dist
				best_city = cn
				
	return best_city
