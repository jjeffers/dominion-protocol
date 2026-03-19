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

var process_timer: float = 0.0
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
		elif money >= 10.0:
			buy_type = "Armor"
			cost = 10.0
		elif money >= 5.0:
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
		elif money >= 10.0:
			buy_type = "Armor"
			cost = 10.0
		elif money >= 5.0:
			buy_type = "Infantry"
			cost = 5.0
			
	if buy_type != "":
		# Spawn using Host RPC directly
		globe_view.sync_unit_purchase(best_city, buy_type, faction_name, cost)

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
	rally_point = rally_point.slerp(target_city.global_position, 0.1).normalized() * globe_view.radius
	
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
					# Attack!
					_issue_move_order(u, closest_enemy.global_position, closest_enemy.name)
					continue
		
		# Otherwise march to target
		if not u.get("is_engaged"):
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
	for other in globe_view.units_list:
		if is_instance_valid(other) and other != unit and not other.get("is_dead") and other.get("faction_name") != faction_name:
			var d = unit.global_position.distance_to(other.global_position)
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
