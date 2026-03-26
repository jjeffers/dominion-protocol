class_name GlobeView
extends Node3D

signal focus_changed(longitude: float, latitude: float)
signal hovered_tile_changed(tile_id: int, terrain: String, city_name: String, region_name: String)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var map_data: MapData
var active_scenario: Dictionary = {}

var radius: float = 1.0
var city_tile_cache: Dictionary = {}
var current_longitude: float = 0.192
var current_latitude: float = 0.6196

var target_zoom: float = 3.0
var min_zoom: float = 1.5
var max_zoom: float = 4.5

var _is_dragging: bool = false
var _drag_start_pos: Vector2
var _drag_start_lon: float
var _drag_start_lat: float
const GlobeUnitScript = preload("res://src/scripts/map/GlobeUnit.gd")

var outline_mesh_instance: MeshInstance3D
var outline_immediate_mesh: ImmediateMesh

var air_ops_mesh_instance: MeshInstance3D
var air_ops_immediate_mesh: ImmediateMesh

var nuke_ash_mesh: ImmediateMesh
var nuke_ash_mesh_instance: MeshInstance3D

var current_air_operation_mode: String = ""

var selected_unit: Node3D = null
var units_list: Array[Node3D] = []
var selected_unit_mesh: MeshInstance3D
var target_bracket: Sprite3D
var air_strike_bracket: Sprite3D
var air_redeploy_bracket: Sprite3D
var foreign_aid_bracket: Sprite3D
var is_deploying_foreign_aid: bool = false

# List of 3D positional nodes to trace against the camera horizon
var cullable_nodes: Array[Node3D] = []
var map_collider: StaticBody3D
var air_strike_sfx: AudioStreamPlayer
var air_redeploy_sfx: AudioStreamPlayer
var air_battle_sfx: AudioStreamPlayer
var city_loss_sfx: AudioStreamPlayer
var nuke_alert_sfx: AudioStreamPlayer
var nuke_impact_sfx: AudioStreamPlayer
var capitols: Dictionary = {}

var city_nodes: Array[Node3D] = []
var friendly_city_positions: Array[Vector3] = []
var friendly_unit_positions: Array[Vector3] = []
var friendly_air_bubbles: Array[Dictionary] = []

# Deployment State
var deploying_unit_type: String = ""
var deploying_unit_cost: float = 0.0
var city_cooldowns: Dictionary = {}
var cached_city_data: Dictionary = {}
var recent_threats: Dictionary = {}
var deployment_ghost: Sprite3D

var unit_name_counters: Dictionary = {}

func _get_fac_color_hex(fac_key: String) -> String:
	if active_scenario and active_scenario.has("factions") and active_scenario["factions"].has(fac_key):
		return active_scenario["factions"][fac_key].get("color", "#CCCCCC")
	return "#CCCCCC"

func _get_standard_unit_name(faction: String, type: String) -> String:
	var f = faction.capitalize()
	if f == "":
		f = "Neutral"
	var t = type.capitalize()
	if t == "Air":
		t = "AIR"
		
	if not unit_name_counters.has(f):
		unit_name_counters[f] = {}
	if not unit_name_counters[f].has(t):
		unit_name_counters[f][t] = 1
		
	var n = f + "_" + t + "_" + str(unit_name_counters[f][t])
	unit_name_counters[f][t] += 1
	return n

func _ready() -> void:
	if not map_data:
		# Create a dummy map for testing if none provided
		map_data = MapData.new()
		
	if has_node("MeshInstance3D"):
		_generate_mesh()
	if has_node("CameraPivot/Camera3D"):
		_update_camera()
	
	outline_immediate_mesh = ImmediateMesh.new()
	outline_mesh_instance = MeshInstance3D.new()
	outline_mesh_instance.mesh = outline_immediate_mesh
	
	var outline_mat = StandardMaterial3D.new()
	outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_mat.render_priority = 2 # Draw over region borders
	outline_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	outline_mat.vertex_color_use_as_albedo = true
	outline_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outline_mesh_instance.material_override = outline_mat
	
	add_child(outline_mesh_instance)
	
	air_ops_immediate_mesh = ImmediateMesh.new()
	air_ops_mesh_instance = MeshInstance3D.new()
	air_ops_mesh_instance.mesh = air_ops_immediate_mesh
	
	var air_ops_mat = StandardMaterial3D.new()
	air_ops_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	air_ops_mat.albedo_color = Color(1.0, 0.0, 0.0, 0.8) # Red circle
	air_ops_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	air_ops_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	air_ops_mat.render_priority = 3 # Draw over globe and borders
	air_ops_mat.no_depth_test = true
	air_ops_mesh_instance.material_override = air_ops_mat
	add_child(air_ops_mesh_instance)
	
	air_strike_sfx = AudioStreamPlayer.new()
	var strike_stream = load("res://src/assets/audio/release-of-a-combat-missile.mp3") as AudioStream
	if strike_stream:
		air_strike_sfx.stream = strike_stream
	add_child(air_strike_sfx)
	
	air_redeploy_sfx = AudioStreamPlayer.new()
	var redeploy_stream = load("res://src/assets/audio/air-unit-redeploy.mp3") as AudioStream
	if redeploy_stream:
		air_redeploy_sfx.stream = redeploy_stream
	add_child(air_redeploy_sfx)
	
	air_battle_sfx = AudioStreamPlayer.new()
	var battle_stream = load("res://src/assets/audio/air-battle.mp3") as AudioStream
	if battle_stream:
		air_battle_sfx.stream = battle_stream
	add_child(air_battle_sfx)
	
	city_loss_sfx = AudioStreamPlayer.new()
	var loss_stream = load("res://src/assets/audio/city-loss.wav") as AudioStream
	if loss_stream:
		city_loss_sfx.stream = loss_stream
	add_child(city_loss_sfx)

	nuke_alert_sfx = AudioStreamPlayer.new()
	var n_sfx_stream = load("res://src/assets/audio/nuke-alert.mp3") as AudioStream
	if n_sfx_stream:
		nuke_alert_sfx.stream = n_sfx_stream
	add_child(nuke_alert_sfx)
	
	nuke_impact_sfx = AudioStreamPlayer.new()
	var n_imp_stream = load("res://src/assets/audio/combat-explosion.mp3") as AudioStream
	if n_imp_stream:
		nuke_impact_sfx.stream = n_imp_stream
	add_child(nuke_impact_sfx)


	
	if NetworkManager:
		NetworkManager.unit_target_synced.connect(_on_unit_target_synced)
		NetworkManager.air_strike_synced.connect(_on_air_strike_synced)
		NetworkManager.strategic_bombing_synced.connect(_on_strategic_bombing_synced)
		NetworkManager.air_redeploy_synced.connect(_on_air_redeploy_synced)
		if NetworkManager.is_host:
			NetworkManager.air_strike_requested.connect(_on_air_strike_requested)
			NetworkManager.strategic_bombing_requested.connect(_on_strategic_bombing_requested)
	
	# Add physics collider matching the exact globe surface
	map_collider = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radius 
	collision_shape.shape = sphere
	map_collider.add_child(collision_shape)
	
	# Keep on layer 1 by default, but let's make it explicitly interactive
	map_collider.collision_layer = 1
	add_child(map_collider)
	
	# Initialize Regional Borders
	if FileAccess.file_exists("res://src/data/region_borders.res"):
		var border_mesh = load("res://src/data/region_borders.res") as ArrayMesh
		if border_mesh:
			var border_node = MeshInstance3D.new()
			border_node.mesh = border_mesh
			var border_mat = StandardMaterial3D.new()
			border_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			border_mat.albedo_color = Color(0.2, 0.2, 0.2, 1.0) # Solid dark grey lines
			border_mat.render_priority = 1 # Draw over globe, under faction borders
			border_node.material_override = border_mat
			add_child(border_node)
	
	# Instantiate targeting bracket
	target_bracket = Sprite3D.new()
	# Draw bracket using same spritesheet
	var t_tex = load("res://src/assets/extracted_sprite.png") as Texture2D
	
	var bracket_tex = load("res://src/assets/target_bracket.png") as Texture2D
	if bracket_tex:
		target_bracket.texture = bracket_tex
	else:
		push_error("GlobeView: Failed to load target_bracket.png")
	
	var tb_mat = StandardMaterial3D.new()
	if bracket_tex:
		tb_mat.albedo_texture = bracket_tex
	tb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tb_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0) # White, opaque lines
	tb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tb_mat.no_depth_test = true # Ensure it draws over terrain
	tb_mat.render_priority = 20 # Below selected unit
	target_bracket.material_override = tb_mat
	
	target_bracket.visible = false
	add_child(target_bracket)
	
	air_strike_bracket = Sprite3D.new()
	var strike_tex = load("res://src/assets/air_strike_bracket.png") as Texture2D
	if strike_tex:
		air_strike_bracket.texture = strike_tex
	else:
		push_error("GlobeView: Failed to load air_strike_bracket.png")
		
	var stb_mat = StandardMaterial3D.new()
	if strike_tex:
		stb_mat.albedo_texture = strike_tex
	stb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stb_mat.albedo_color = Color(1.0, 0.0, 0.0, 1.0) # Red reticle
	stb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stb_mat.no_depth_test = true
	stb_mat.render_priority = 21 # Above regular bracket
	air_strike_bracket.material_override = stb_mat
	air_strike_bracket.visible = false
	add_child(air_strike_bracket)
	
	air_redeploy_bracket = Sprite3D.new()
	var redeploy_tex = load("res://src/assets/air_redeploy_bracket.png") as Texture2D
	if redeploy_tex:
		air_redeploy_bracket.texture = redeploy_tex
	else:
		push_error("GlobeView: Failed to load air_redeploy_bracket.png")
		
	var rtb_mat = StandardMaterial3D.new()
	if redeploy_tex:
		rtb_mat.albedo_texture = redeploy_tex
	rtb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rtb_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0) # White reticle for redeploy
	rtb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rtb_mat.no_depth_test = true
	rtb_mat.render_priority = 21
	air_redeploy_bracket.material_override = rtb_mat
	air_redeploy_bracket.visible = false
	add_child(air_redeploy_bracket)
	
	foreign_aid_bracket = Sprite3D.new()
	var fab_tex = load("res://src/assets/target_bracket.png") as Texture2D
	if fab_tex:
		foreign_aid_bracket.texture = fab_tex
		var fab_mat = StandardMaterial3D.new()
		fab_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fab_mat.albedo_texture = fab_tex
		fab_mat.albedo_color = Color(1.0, 1.0, 1.0) # White
		fab_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fab_mat.no_depth_test = true
		fab_mat.render_priority = 22
		foreign_aid_bracket.material_override = fab_mat
	foreign_aid_bracket.visible = false
	add_child(foreign_aid_bracket)
	
	# Instantiate deployment ghost
	deployment_ghost = Sprite3D.new()
	if t_tex:
		deployment_ghost.texture = t_tex
	deployment_ghost.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	
	var dep_mat = StandardMaterial3D.new()
	dep_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dep_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.5) # Semi-transparent white
	dep_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dep_mat.no_depth_test = true
	dep_mat.render_priority = 30
	deployment_ghost.material_override = dep_mat
	deployment_ghost.visible = false
	add_child(deployment_ghost)

func start_foreign_aid_purchase() -> void:
	is_deploying_foreign_aid = true
	# Deselect any active units
	if selected_unit:
		selected_unit.set_selected(false)
		selected_unit = null
		if target_bracket: target_bracket.visible = false
	_update_city_highlights(true, false, false, true)

func start_deployment(unit_type: String, cost: float) -> void:
	deploying_unit_type = unit_type
	deploying_unit_cost = cost
	
	# Deselect any active units
	if selected_unit:
		selected_unit.set_selected(false)
		selected_unit = null
		target_bracket.visible = false
		
	deployment_ghost.visible = true
	_update_city_highlights(true)

func _on_unit_target_synced(unit_name: String, target_pos: Vector3, enemy_target_name: String) -> void:
	print("GlobeView handling _on_unit_target_synced for ", unit_name, " enemy: ", enemy_target_name)
	var unit: Node3D = null
	for u in units_list:
		if not is_instance_valid(u):
			continue
		if u.name == unit_name:
			unit = u
			break
			
	if unit:
		if enemy_target_name != "":
			var enemy: Node3D = null
			for u in units_list:
				if not is_instance_valid(u):
					continue
				if u.name == enemy_target_name:
					enemy = u
					break
			if enemy:
				if unit.get("combat_target") == enemy and unit.get("is_engaged"):
					unit.set("movement_target_unit", enemy)
				else:
					unit.clear_combat_target()
					unit.set_movement_target_unit(enemy)
		else:
			# Manual coordinate movement
			# We DO NOT clear the target here. If they are engaged, they should keep shooting the enemy while retreating!
			unit.set_target(target_pos)
			
		var u_type = unit.get("unit_type")
		if (u_type == "Infantry" or u_type == "Armor") and target_pos != null:
			var t_tile = _get_tile_from_vector3(target_pos)
			if city_tile_cache.has(t_tile):
				var c_name = city_tile_cache[t_tile]
				var c_faction = ""
				if active_scenario and active_scenario.has("factions"):
					for f_name in active_scenario["factions"].keys():
						if active_scenario["factions"][f_name].has("cities") and c_name in active_scenario["factions"][f_name]["cities"]:
							c_faction = f_name
							break
				if c_faction != "" and c_faction != unit.get("faction_name"):
					var current_time = Time.get_ticks_msec() / 1000.0
					var threat_key = c_name + "_" + c_faction + "_" + unit.get("faction_name")
					if not recent_threats.has(threat_key) or (current_time - recent_threats[threat_key] > 20.0):
						recent_threats[threat_key] = current_time
						var main_node = get_node_or_null("/root/Main")
						if main_node and main_node.has_method("post_news_event"):
							var msg = "%s FORCE THREATENS %s" % [unit.get("faction_name").to_upper(), c_name.to_upper()]
							main_node.post_news_event(msg, [c_faction])

func _on_air_strike_requested(sender_id: int, unit_name: String, target_unit_name: String) -> void:
	if not NetworkManager.is_host: return
	
	var attacker: Node3D = null
	var target: Node3D = null
	
	for u in units_list:
		if is_instance_valid(u):
			if u.name == unit_name: attacker = u
			elif u.name == target_unit_name: target = u
			
	if not attacker or not target: return
	
	var attacker_faction = ""
	if "faction_name" in attacker:
		attacker_faction = attacker.get("faction_name")
		
	var attacker_player_name = "Unknown"
	if NetworkManager.players.has(sender_id):
		attacker_player_name = NetworkManager.players[sender_id].get("name", "Unknown")
		
	ConsoleManager.log_message("\n[outline_size=2][outline_color=#dddddd][color=cyan]AIR STRIKE REQUESTED:[/color][/outline_color][/outline_size] [color=yellow]" + attacker_player_name + " (" + attacker_faction + ")[/color] targeting [outline_size=2][outline_color=#dddddd][color=red]" + target_unit_name + "[/color][/outline_color][/outline_size]")
		
	var valid_counters = []
	var total_interception_chance = 0.0
	
	for u in units_list:
		if is_instance_valid(u) and u != attacker and u != target and u.get("unit_type") == "Air":
			if u.get("faction_name") != attacker_faction:
				var ops_radius = 30.0 * _get_tile_width(_get_tile_from_vector3(u.current_position))
				var dist = u.current_position.distance_to(target.current_position)
				if dist <= ops_radius:
					valid_counters.append(u)
					var chance = 1.0 - (dist / ops_radius)
					if u.get("is_air_ready") == false:
						chance *= 0.1
					total_interception_chance += chance
					
	total_interception_chance = clampf(total_interception_chance, 0.0, 1.0)
	
	ConsoleManager.log_message("[color=gray]Interception Phase[/color]")
	var int_roll = randf()
	ConsoleManager.log_message(str("  -> Interceptors Available: ", valid_counters.size(), " | Target Chance: <= ", snappedf(total_interception_chance, 0.01), " | Rolled: ", snappedf(int_roll, 0.01)))
	
	var intercepted = false
	var counter_name = ""
	var attacker_status = ""
	var defender_status = ""
	var target_hit = false
	
	if int_roll <= total_interception_chance and valid_counters.size() > 0:
		intercepted = true
		
		# Pick best counter (READY first, then closest)
		var best_counter = null
		var best_score = -9999.0
		for u in valid_counters:
			var is_ready = u.get("is_air_ready")
			var dist = u.current_position.distance_to(target.current_position)
			var score = (1000.0 if is_ready else 0.0) - dist
			if score > best_score:
				best_score = score
				best_counter = u
				
		counter_name = best_counter.name
		var c_ready = best_counter.get("is_air_ready")
		
		var counter_faction = best_counter.get("faction_name")
		var counter_player = "Unknown"
		for pid in NetworkManager.players:
			if NetworkManager.players[pid].get("faction", "") == counter_faction:
				counter_player = NetworkManager.players[pid].get("name", "Unknown")
				break
		ConsoleManager.log_message(str("  -> Intercepted by ", counter_name, " ([color=yellow]", counter_player, " - ", counter_faction, "[/color]). Ready: ", c_ready))
		
		# Roll interception outcome
		var roll = randf()
		var success = false
		var abort = false
		var shot_down = false
		
		if c_ready:
			if roll <= 0.25: success = true
			elif roll <= 0.75: abort = true
			else: shot_down = true
			ConsoleManager.log_message("  -> Dogfight Odds: 25% Success | 50% Abort | 25% Shot Down")
		else:
			if roll <= 0.90: success = true
			else: abort = true
			ConsoleManager.log_message("  -> Dogfight Odds: 90% Success | 10% Abort | 0% Shot Down")
			
		ConsoleManager.log_message(str("  -> Dogfight Rolled: ", snappedf(roll, 0.01), " | Outcome: ", "SUCCESS" if success else ("ABORT" if abort else "SHOT DOWN")))
			
		if success:
			# Attacker succeeds, defender destroyed
			defender_status = "DESTROYED"
			intercepted = false # Proceed to target roll
		elif abort:
			attacker_status = "UNREADY"
			defender_status = "ADD_COOLDOWN" if not c_ready else "UNREADY"
			target_hit = false
		elif shot_down:
			attacker_status = "DESTROYED"
			defender_status = "ADD_COOLDOWN" if not c_ready else "UNREADY"
			target_hit = false
			
	if not intercepted:
		# Target Roll
		ConsoleManager.log_message("[color=gray]Target Strike Phase[/color]")
		var is_sea = false
		if target.get("unit_type") == "Sea":
			is_sea = true
		elif target.get("unit_type") != "Air":
			var t_tile = _get_tile_from_vector3(target.current_position)
			var t_terrain = map_data.get_terrain(t_tile)
			if t_terrain == "OCEAN" or t_terrain == "COAST" or t_terrain == "DEEP_OCEAN" or t_terrain == "LAKE":
				is_sea = true
				
		var roll = randf()
		var is_sea_str = "SEA" if is_sea else "LAND"
		
		if is_sea:
			ConsoleManager.log_message("  -> Target Odds: 65% Hit | 25% Miss | 10% Miss & Shot Down")
			if roll <= 0.65:
				target_hit = true
				attacker_status = "UNREADY"
			elif roll <= 0.90:
				target_hit = false
				attacker_status = "UNREADY"
			else:
				target_hit = false
				attacker_status = "DESTROYED"
		else:
			ConsoleManager.log_message("  -> Target Odds: 90% Hit | 9% Miss | 1% Miss & Shot Down")
			if roll <= 0.90:
				target_hit = true
				attacker_status = "UNREADY"
			elif roll <= 0.99:
				target_hit = false
				attacker_status = "UNREADY"
			else:
				target_hit = false
				attacker_status = "DESTROYED"
				
		var outcome_str = "HIT" if target_hit else ("MISS & SHOT DOWN" if attacker_status == "DESTROYED" else "MISS")
		ConsoleManager.log_message(str("  -> Target type: ", is_sea_str, " | Rolled: ", snappedf(roll, 0.01), " | Target Hit: ", outcome_str))

	NetworkManager.execute_air_strike(unit_name, target_unit_name, counter_name, attacker_status, defender_status, target_hit)

func _on_strategic_bombing_requested(sender_id: int, unit_name: String, target_city: String) -> void:
	if not NetworkManager.is_host: return
	
	var attacker: Node3D = null
	for u in units_list:
		if is_instance_valid(u) and u.name == unit_name:
			attacker = u
			break
			
	if not attacker: return
	
	var attacker_faction = attacker.get("faction_name")
	var attacker_player_name = "Unknown"
	if NetworkManager.players.has(sender_id):
		attacker_player_name = NetworkManager.players[sender_id].get("name", "Unknown")
		
	var target_tile = -1
	for t_id in city_tile_cache:
		if city_tile_cache[t_id] == target_city:
			target_tile = t_id
			break
			
	if target_tile == -1: return
	var target_pos = map_data.get_centroid(target_tile).normalized() * radius
		
	ConsoleManager.log_message("\n[outline_size=2][outline_color=#dddddd][color=cyan]STRATEGIC BOMBING REQUESTED:[/color][/outline_color][/outline_size] [color=yellow]" + attacker_player_name + " (" + attacker_faction + ")[/color] targeting [outline_size=2][outline_color=#dddddd][color=red]" + target_city + "[/color][/outline_color][/outline_size]")
		
	var valid_counters = []
	var total_interception_chance = 0.0
	
	for u in units_list:
		if is_instance_valid(u) and u != attacker and u.get("unit_type") == "Air" and u.get("faction_name") != attacker_faction:
			var ops_radius = 30.0 * _get_tile_width(_get_tile_from_vector3(u.current_position))
			var dist = u.current_position.distance_to(target_pos)
			if dist <= ops_radius:
				valid_counters.append(u)
				var chance = 1.0 - (dist / ops_radius)
				if u.get("is_air_ready") == false: chance *= 0.1
				total_interception_chance += chance
					
	total_interception_chance = clampf(total_interception_chance, 0.0, 1.0)
	ConsoleManager.log_message("[color=gray]Interception Phase[/color]")
	var int_roll = randf()
	ConsoleManager.log_message(str("  -> Interceptors Available: ", valid_counters.size(), " | Target Chance: <= ", snappedf(total_interception_chance, 0.01), " | Rolled: ", snappedf(int_roll, 0.01)))
	
	var intercepted = false
	var counter_name = ""
	var attacker_status = ""
	var defender_status = ""
	var success = false
	
	if int_roll <= total_interception_chance and valid_counters.size() > 0:
		intercepted = true
		
		var best_counter = null
		var best_score = -9999.0
		for u in valid_counters:
			var is_ready = u.get("is_air_ready")
			var dist = u.current_position.distance_to(target_pos)
			var score = (1000.0 if is_ready else 0.0) - dist
			if score > best_score:
				best_score = score
				best_counter = u
				
		counter_name = best_counter.name
		var c_ready = best_counter.get("is_air_ready")
		
		var roll = randf()
		var dogfight_success = false
		var abort = false
		var shot_down = false
		
		if c_ready:
			if roll <= 0.25: dogfight_success = true
			elif roll <= 0.75: abort = true
			else: shot_down = true
		else:
			if roll <= 0.90: dogfight_success = true
			else: abort = true
			
		if dogfight_success:
			defender_status = "DESTROYED"
			intercepted = false
		elif abort:
			attacker_status = "UNREADY"
			defender_status = "ADD_COOLDOWN" if not c_ready else "UNREADY"
			success = false
		elif shot_down:
			attacker_status = "DESTROYED"
			defender_status = "ADD_COOLDOWN" if not c_ready else "UNREADY"
			success = false
			
	if not intercepted:
		success = true
		attacker_status = "UNREADY"
		
	NetworkManager.execute_strategic_bombing(unit_name, target_city, counter_name, attacker_status, defender_status, success)

func _on_strategic_bombing_synced(unit_name: String, target_city: String, counter_unit_name: String, attacker_status: String, defender_status: String, success: bool) -> void:
	var attacker: Node3D = null
	var counter: Node3D = null
	
	var target_pos = Vector3.ZERO
	for u in units_list:
		if not is_instance_valid(u): continue
		if u.name == unit_name: attacker = u
		if counter_unit_name != "" and u.name == counter_unit_name: counter = u
		
	if cached_city_data.has(target_city):
		var city_data = cached_city_data[target_city]
		var lat = city_data.get("latitude")
		var lon = city_data.get("longitude")
		if lat != null and lon != null:
			target_pos = _lat_lon_to_vector3(deg_to_rad(lat), deg_to_rad(lon), radius)
			
	if attacker and target_pos != Vector3.ZERO:
		var attacker_fac = attacker.get("faction_name")
		var fac_color = Color.WHITE
		if attacker_fac != "" and active_scenario.has("factions") and active_scenario["factions"].has(attacker_fac):
			var c_val = active_scenario["factions"][attacker_fac].get("color", "#ffffffff")
			if typeof(c_val) == TYPE_STRING:
				fac_color = Color(c_val)
			elif typeof(c_val) == TYPE_ARRAY and c_val.size() >= 3:
				fac_color = Color(c_val[0], c_val[1], c_val[2])
		_play_air_mission_animation(attacker.current_position, target_pos, true, success, attacker_status == "DESTROYED", fac_color)

	if air_strike_sfx and attacker:
		air_strike_sfx.play()

	if counter and defender_status != "":
		var defender_fac = counter.get("faction_name")
		var def_color = Color.WHITE
		if defender_fac != "" and active_scenario.has("factions") and active_scenario["factions"].has(defender_fac):
			var c_val = active_scenario["factions"][defender_fac].get("color", "#ffffffff")
			if typeof(c_val) == TYPE_STRING:
				def_color = Color(c_val)
			elif typeof(c_val) == TYPE_ARRAY and c_val.size() >= 3:
				def_color = Color(c_val[0], c_val[1], c_val[2])
		var intercept_point = attacker.current_position.slerp(target_pos, 0.6)
		# Converging flight path for the interceptor
		_play_air_mission_animation(counter.current_position, intercept_point, false, true, false, def_color, 0.6 * 1.5)

		if defender_status == "DESTROYED":
			if "health" in counter:
				counter.take_damage(9999.0)
		elif defender_status == "ADD_COOLDOWN":
			if counter.has_method("add_unready_cooldown"):
				counter.add_unready_cooldown(240.0)
		elif defender_status == "UNREADY":
			if counter.has_method("set_air_unready"):
				counter.set_air_unready(120.0, 0.0)
				
	var attacker_fac = ""
	if attacker and is_instance_valid(attacker):
		attacker_fac = attacker.get("faction_name")
		if attacker_status == "DESTROYED":
			if "health" in attacker:
				attacker.take_damage(9999.0)
		elif attacker_status == "UNREADY":
			if attacker.has_method("set_air_unready"):
				attacker.set_air_unready(120.0, 0.0)
				
	var target_fac = ""
	if active_scenario.has("factions"):
		for fac in active_scenario["factions"].keys():
			if active_scenario["factions"][fac].has("cities") and active_scenario["factions"][fac]["cities"].has(target_city):
				target_fac = fac
				break
				
	var main_node = get_node_or_null("/root/Main")

	if success:
		if target_fac != "":
			active_scenario["factions"][target_fac]["money"] -= 10.0
			var msg = "%s AIR FORCES SUCCESSFULLY STRATEGICALLY BOMBED %s!" % [attacker_fac.to_upper(), target_city.to_upper()]
			ConsoleManager.log_message("[outline_size=2][outline_color=#dddddd][color=green]" + msg + "[/color][/outline_color][/outline_size]")
			if main_node and main_node.has_method("post_news_event"):
				main_node.post_news_event(msg, [attacker_fac, target_fac])
			
			city_cooldowns[target_city] = city_cooldowns.get(target_city, 0.0) + 120.0
	else:
		if attacker_status == "DESTROYED":
			var msg = "%s STRATEGIC BOMBER OVER %s SHOT DOWN BY %s COUNTERMEASURES!" % [attacker_fac.to_upper(), target_city.to_upper(), target_fac.to_upper()]
			ConsoleManager.log_message("[outline_size=2][outline_color=#dddddd][color=red]" + msg + "[/color][/outline_color][/outline_size]")
			if main_node and main_node.has_method("post_news_event"):
				main_node.post_news_event(msg, [attacker_fac, target_fac])
		elif attacker_status == "UNREADY":
			var msg = "%s STRATEGIC BOMBING MISSION IN %s ABORTED DUE TO %s INTERCEPTORS!" % [attacker_fac.to_upper(), target_city.to_upper(), target_fac.to_upper()]
			ConsoleManager.log_message("[color=yellow]" + msg + "[/color]")
			if main_node and main_node.has_method("post_news_event"):
				main_node.post_news_event(msg, [attacker_fac, target_fac])

func _on_air_strike_synced(unit_name: String, target_unit_name: String, counter_unit_name: String, attacker_status: String, defender_status: String, target_hit: bool) -> void:
	print("GlobeView handling _on_air_strike_synced for ", unit_name, " targeting ", target_unit_name)
	var attacker: Node3D = null
	var target: Node3D = null
	var counter: Node3D = null
	
	for u in units_list:
		if not is_instance_valid(u): continue
		if u.name == unit_name: attacker = u
		if u.name == target_unit_name: target = u
		if counter_unit_name != "" and u.name == counter_unit_name: counter = u
		
	if attacker and target:
		var attacker_fac = attacker.get("faction_name")
		var fac_color = Color.WHITE
		if attacker_fac != "" and active_scenario.has("factions") and active_scenario["factions"].has(attacker_fac):
			var c_val = active_scenario["factions"][attacker_fac].get("color", "#ffffff")
			if typeof(c_val) == TYPE_STRING:
				fac_color = Color(c_val)
			elif typeof(c_val) == TYPE_ARRAY and c_val.size() >= 3:
				fac_color = Color(c_val[0], c_val[1], c_val[2])
		_play_air_mission_animation(attacker.current_position, target.current_position, false, target_hit, attacker_status == "DESTROYED", fac_color)

	if air_strike_sfx and attacker and target:
		air_strike_sfx.play()

	if counter and defender_status != "":
		var defender_fac = counter.get("faction_name")
		var def_color = Color.WHITE
		if defender_fac != "" and active_scenario.has("factions") and active_scenario["factions"].has(defender_fac):
			var c_val = active_scenario["factions"][defender_fac].get("color", "#ffffff")
			if typeof(c_val) == TYPE_STRING:
				def_color = Color(c_val)
			elif typeof(c_val) == TYPE_ARRAY and c_val.size() >= 3:
				def_color = Color(c_val[0], c_val[1], c_val[2])
		var intercept_point = attacker.current_position.slerp(target.current_position, 0.6)
		_play_air_mission_animation(counter.current_position, intercept_point, false, true, false, def_color, 0.6 * 1.0)
		
		# Play interception dogfight sound
		if air_battle_sfx:
			air_battle_sfx.play()
			
		if defender_status == "DESTROYED":
			counter.take_damage(9999.0)
		elif defender_status == "UNREADY":
			if counter.has_method("set_air_unready"):
				counter.set_air_unready(120.0, 0.0)
		elif defender_status == "ADD_COOLDOWN":
			if counter.has_method("set_air_unready"):
				counter.set_air_unready(-1.0, 120.0)
			
		if not target_hit and attacker_status != "":
			var attacker_fac = attacker.get("faction_name") if attacker else "UNKNOWN"
			defender_fac = counter.get("faction_name")
			var target_tile = _get_tile_from_vector3(target.current_position) if target else 0
			var region = map_data.get_region(target_tile) if target else ""
			if region == "": region = "WILDERNESS"
			
			var msg = "%s AIRSTRIKE IN %s COUNTERED BY %s AIR DEFENSES" % [attacker_fac.to_upper(), region.to_upper(), defender_fac.to_upper()]
			var colors = [attacker_fac, defender_fac]
			
			if attacker_status == "DESTROYED":
				msg = "%s AIRSTRIKE OVER %s SHOT DOWN BY %s COUNTERMEASURES!" % [attacker_fac.to_upper(), region.to_upper(), defender_fac.to_upper()]
			elif defender_status == "DESTROYED":
				msg = "%s AIRSTRIKE OVER %s CRUSHED ALL %s INTERCEPTORS!" % [attacker_fac.to_upper(), region.to_upper(), defender_fac.to_upper()]

			var main_node = get_node_or_null("/root/Main")
			if main_node and main_node.has_method("post_news_event"):
				main_node.post_news_event(msg, colors)
				
	elif attacker and attacker_status == "DESTROYED" and counter == null: # Target phase shot down
		var attacker_fac = attacker.get("faction_name") if attacker else "UNKNOWN"
		var target_fac = target.get("faction_name") if target else "UNKNOWN"
		var target_tile = _get_tile_from_vector3(target.current_position) if target else 0
		var region = map_data.get_region(target_tile) if target else ""
		if region == "": region = "WILDERNESS"
		
		var msg = "%s AIRSTRIKE OVER %s DESTROYED BY %s ANTI-AIR!" % [attacker_fac.to_upper(), region.to_upper(), target_fac.to_upper()]
		var main_node = get_node_or_null("/root/Main")
		if main_node and main_node.has_method("post_news_event"):
			main_node.post_news_event(msg, [attacker_fac, target_fac])

	if attacker and attacker_status != "":
		if attacker_status == "DESTROYED":
			attacker.take_damage(9999.0)
		elif attacker_status == "UNREADY":
			if attacker.has_method("set_air_unready"):
				attacker.set_air_unready(120.0, 0.0)
			
	if target and target_hit:
		var is_sea_transport = false
		if target.get("unit_type") != "Sea" and target.get("unit_type") != "Air":
			var t_tile = _get_tile_from_vector3(target.current_position)
			var t_terrain = map_data.get_terrain(t_tile)
			if t_terrain == "OCEAN" or t_terrain == "COAST" or t_terrain == "DEEP_OCEAN" or t_terrain == "LAKE":
				is_sea_transport = true

		var val = 35.0 # Standard Sea damage mapped to 35
		if target.get("unit_type") != "Sea" and not is_sea_transport:
			var target_health = target.get("health")
			if target_health != null:
				val = target_health * 0.50
		target.take_damage(val)
		
		var log_attacker = attacker.get("faction_name") if attacker else "UNKNOWN"
		var log_target = target.get("faction_name") if target else "UNKNOWN"
		ConsoleManager.local_log_message("SYSTEM: " + log_attacker + " Air Strike hit " + log_target + " for " + str(int(val)) + " damage.")
		
		if not counter:
			var attacker_fac = attacker.get("faction_name") if attacker else "UNKNOWN"
			var target_fac = target.get("faction_name") if target else "UNKNOWN"
			var target_tile = _get_tile_from_vector3(target.current_position) if target else 0
			var region = map_data.get_region(target_tile) if target else ""
			if region == "": region = "WILDERNESS"
			
			var msg = "%s AIRSTRIKE DEALT %d DAMAGE TO %s IN %s!" % [attacker_fac.to_upper(), int(val), target_fac.to_upper(), region.to_upper()]
			var main_node = get_node_or_null("/root/Main")
			if main_node and main_node.has_method("post_news_event"):
				main_node.post_news_event(msg, [attacker_fac, target_fac])
				
	elif target and not target_hit and attacker_status == "UNREADY":
		if not counter:
			var attacker_fac = attacker.get("faction_name") if attacker else "UNKNOWN"
			var target_fac = target.get("faction_name") if target else "UNKNOWN"
			var target_tile = _get_tile_from_vector3(target.current_position) if target else 0
			var region = map_data.get_region(target_tile) if target else ""
			if region == "": region = "WILDERNESS"
			
			var msg = "%s AIRSTRIKE FAILED TO HIT %s TARGETS IN %s!" % [attacker_fac.to_upper(), target_fac.to_upper(), region.to_upper()]
			var main_node = get_node_or_null("/root/Main")
			if main_node and main_node.has_method("post_news_event"):
				main_node.post_news_event(msg, [attacker_fac, target_fac])

func _on_air_redeploy_synced(unit_name: String, target_city: String) -> void:
	print("GlobeView handling _on_air_redeploy_synced for ", unit_name, " to ", target_city)
	var unit: Node3D = null
	for u in units_list:
		if is_instance_valid(u) and u.name == unit_name:
			unit = u
			break
			
	if unit:
		if unit.has_method("set_air_unready"):
			unit.set_air_unready(120.0, 0.0)
		
		if cached_city_data.has(target_city):
			var city_data = cached_city_data[target_city]
			var lat = city_data.get("latitude")
			var lon = city_data.get("longitude")
			if lat != null and lon != null:
				var new_pos = _lat_lon_to_vector3(deg_to_rad(lat), deg_to_rad(lon), radius)
				unit.spawn(new_pos)
				
				if air_redeploy_sfx:
					air_redeploy_sfx.play()

static var skip_mesh_generation: bool = false

func _generate_mesh() -> void:
	if skip_mesh_generation: return
	
	var mesh = load("res://src/data/globe_mesh.res")
	if mesh:
		mesh_instance.mesh = mesh
		var tex = load("res://src/assets/biome_map.png") as Texture2D
		if tex:
			var mat = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
			mat.albedo_texture = tex
			mesh_instance.material_override = mat
		else:
			push_error("GlobeView: Failed to load biome_map.png image")
	else:
		push_error("GlobeView: Failed to load globe_mesh.res!")
var _violation_log_cooldowns: Dictionary = {}
var active_captures: Dictionary = {} # Tracks 10-second city capture holds { "CityName": { "faction": string, "time": float } }

func _process(delta: float) -> void:
	if not camera:
		return
		
	var cooldowns_to_erase = []
	for key in _violation_log_cooldowns.keys():
		if _violation_log_cooldowns[key] > 0:
			_violation_log_cooldowns[key] -= delta
		if _violation_log_cooldowns[key] <= 0:
			cooldowns_to_erase.append(key)
	for key in cooldowns_to_erase:
		_violation_log_cooldowns.erase(key)
		
	# Handle Zoom Interpolation
	if camera.transform.origin.z != target_zoom:
		var new_z = lerpf(camera.transform.origin.z, target_zoom, 10.0 * delta)
		if abs(new_z - target_zoom) < 0.01:
			new_z = target_zoom
		camera.transform.origin.z = new_z
		
	# Handle Node Visibility (Horizon Culling & Fog of War)
	# Because Sprites have no_depth_test to render clearly over terrain peaks, they punch through the globe.
	# We dynamically hide them if they rotate out of hemispheric front-view.
	var cam_pos = camera.global_position.normalized()
	
	# Compute friendly vision anchors for Fog of War
	var local_faction = _get_local_faction()
			
	friendly_unit_positions.clear()
	friendly_air_bubbles.clear()
		
	if local_faction != "":
		for u in units_list:
			if not is_instance_valid(u):
				continue
			if u.get("faction_name") == local_faction and u.get("is_dead") != true:
				friendly_unit_positions.append(u.global_position)
				if u.get("unit_type") == "Air" and u.get("is_air_ready") == true:
					var tile_id = _get_tile_from_vector3(u.global_position)
					var air_range = 30.0 * _get_tile_width(tile_id)
					friendly_air_bubbles.append({
						"pos": u.global_position,
						"range": air_range
					})
	
	# Populate friendly_city_positions for Fog of War
	friendly_city_positions.clear() # Clear previous frame's positions
	if local_faction != "" and active_scenario.has("factions") and active_scenario["factions"].has(local_faction):
		var faction_cities = active_scenario["factions"][local_faction].get("cities", [])
		for city_node in city_nodes: # Iterate through existing city nodes
			var city_name = city_node.name # Assuming city_node.name holds the city name
			if city_name in faction_cities:
				friendly_city_positions.append(city_node.global_position) # Use global_position of the city node
	
	var valid_nodes: Array[Node3D] = []
	for node in cullable_nodes:
		if not is_instance_valid(node):
			continue
			
		valid_nodes.append(node)
		
		# Base Horizon Culling
		var is_visible = false
		# Use 0.15 threshold to cull them slightly before they clip exactly sideways over the mathematical edge
		if node.position.normalized().dot(cam_pos) > 0.15:
			is_visible = true
			
		# Fog of War Distance Culling (only applies if we have a faction and node is an enemy unit)
		if is_visible and local_faction != "" and node.get("faction_name") != null and node.get("faction_name") != local_faction:
			is_visible = false
			# 6x unit widths = 0.036 distance
			var vision_range = 0.036
			for f_pos in friendly_unit_positions:
				if node.global_position.distance_to(f_pos) <= vision_range:
					is_visible = true
					break
			if not is_visible:
				for c_pos in friendly_city_positions:
					if node.global_position.distance_to(c_pos) <= vision_range:
						is_visible = true
						break
			if not is_visible:
				for bubble in friendly_air_bubbles:
					if node.global_position.distance_to(bubble.pos) <= bubble.range:
						is_visible = true
						break
			
		if is_visible and (current_air_operation_mode == "REDEPLOY" or current_air_operation_mode == "STRATEGIC_BOMBING" or deploying_unit_type != ""):
			if node in units_list and node != selected_unit:
				is_visible = false
			
		if is_visible:
			if node.has_method("set_visibility"):
				node.set_visibility(true)
			else:
				node.show()
		else:
			if node.has_method("set_visibility"):
				node.set_visibility(false)
			else:
				node.hide()
			
	cullable_nodes = valid_nodes

	# Keyboard Zoom Input (+/- or PageUp/PageDown)
	if camera:
		if Input.is_physical_key_pressed(KEY_EQUAL) or Input.is_action_pressed("ui_page_up"):
			target_zoom = clampf(target_zoom - 2.0 * delta, min_zoom, max_zoom)
		if Input.is_physical_key_pressed(KEY_MINUS) or Input.is_action_pressed("ui_page_down"):
			target_zoom = clampf(target_zoom + 2.0 * delta, min_zoom, max_zoom)

	var lon_delta = 0.0
	var lat_delta = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A): lon_delta = -2.0 * delta
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D): lon_delta = 2.0 * delta
	if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W): lat_delta = 2.0 * delta
	if Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S): lat_delta = -2.0 * delta
	
	if lon_delta != 0.0 or lat_delta != 0.0:
		current_longitude = wrapf(current_longitude + lon_delta, -PI, PI)
		current_latitude = clampf(current_latitude + lat_delta, -PI/2.1, PI/2.1)
		
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and multiplayer.is_server():
		capture_timer += delta
		if capture_timer >= CAPTURE_INTERVAL:
			capture_timer -= CAPTURE_INTERVAL
			_process_city_captures()
			
		diplomacy_timer += delta
		if diplomacy_timer >= DIPLOMACY_INTERVAL:
			diplomacy_timer -= DIPLOMACY_INTERVAL
			_process_diplomacy()
		_update_camera()

	# Process deployment cooldowns
	var to_erase = []
	for city in city_cooldowns.keys():
		city_cooldowns[city] -= delta
		if city_cooldowns[city] <= 0:
			to_erase.append(city)
	for city in to_erase:
		city_cooldowns.erase(city)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if selected_unit and selected_unit.get("unit_type") == "Air" and selected_unit.get("is_air_ready") and selected_unit.get("faction_name") == _get_local_faction():
			if event.physical_keycode == KEY_T or event.physical_keycode == KEY_A:
				current_air_operation_mode = "AIRSTRIKE"
				_draw_air_ops_radius(selected_unit, false)
				_update_city_highlights(false)
				return
			elif event.physical_keycode == KEY_B:
				current_air_operation_mode = "STRATEGIC_BOMBING"
				_draw_air_ops_radius(selected_unit, false)
				_update_city_highlights(true, false, true)
				return
			elif event.physical_keycode == KEY_R:
				current_air_operation_mode = "REDEPLOY"
				_draw_air_ops_radius(selected_unit, true)
				_update_city_highlights(true, true)
				return
				
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed):
		if current_air_operation_mode != "":
			if current_air_operation_mode == "NUKE":
				if air_strike_bracket: air_strike_bracket.visible = false
			if target_bracket: target_bracket.visible = false
			current_air_operation_mode = ""
			_update_city_highlights(false)
			if selected_unit and selected_unit.get("unit_type") == "Air":
				_draw_air_ops_radius(selected_unit, false)
			return
			
		var canceled_something = false
		if selected_unit:
			selected_unit.set_selected(false)
			selected_unit = null
			target_bracket.visible = false
			air_ops_immediate_mesh.clear_surfaces()
			canceled_something = true
		if deploying_unit_type != "":
			deploying_unit_type = ""
			deployment_ghost.visible = false
			_update_city_highlights(false)
			canceled_something = true
		if is_deploying_foreign_aid:
			is_deploying_foreign_aid = false
			if foreign_aid_bracket: foreign_aid_bracket.visible = false
			_update_city_highlights(false)
			canceled_something = true
			
		if canceled_something:
			return
			
		if not has_node("SettingsMenu"):
			var menu_scn = load("res://src/scenes/SettingsMenu.tscn").instantiate()
			menu_scn.name = "SettingsMenu"
			add_child(menu_scn)
			get_viewport().set_input_as_handled()
			return
			
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if deploying_unit_type != "":
			deploying_unit_type = ""
			deployment_ghost.visible = false
			_update_city_highlights(false)
		if is_deploying_foreign_aid:
			is_deploying_foreign_aid = false
			if foreign_aid_bracket: foreign_aid_bracket.visible = false
			_update_city_highlights(false)
			
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Standard Drag Init
				_is_dragging = true
				_drag_start_pos = event.position
				_drag_start_lon = current_longitude
				_drag_start_lat = current_latitude
			else:
				# Drag release or Click
				if _is_dragging and _drag_start_pos.distance_to(event.position) < 15.0:
					# Valid Click (not a drag release)
					_handle_click(event.position, true)
				_is_dragging = false
				
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			print("Right click unhandled input block executes!")
			if selected_unit:
				# Issue Move Command via Right Click
				_handle_click(event.position, false)
			else:
				# Cancel any potential drag early
				_is_dragging = false
				
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_zoom = clampf(target_zoom - 0.25, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_zoom = clampf(target_zoom + 0.25, min_zoom, max_zoom)
	
	elif event is InputEventMouseMotion:
		if _is_dragging:
			var delta = event.position - _drag_start_pos
			# Sensitivity scaling directly tied to zoom depth
			var zoom_scalar = (target_zoom / max_zoom)
			var lon_delta = -delta.x * 0.01 * zoom_scalar
			var lat_delta = delta.y * 0.01 * zoom_scalar
			
			# Update coordinates
			current_longitude = wrapf(_drag_start_lon + lon_delta, -PI, PI)
			# Clamp latitude to avoid flipping over poles
			current_latitude = clampf(_drag_start_lat + lat_delta, -PI/2.1, PI/2.1)
			
			_update_camera()
		elif selected_unit or current_air_operation_mode != "":
			_handle_hover(event.position)
			
		# Always update terrain HUD regardless of unit selection
		_update_terrain_hover(event.position)

signal city_captured(city_name: String, new_faction: String, old_faction: String)
signal victory_declared(winning_faction: String)

var capture_timer: float = 0.0
const CAPTURE_INTERVAL: float = 1.0

var diplomacy_timer: float = 0.0
const DIPLOMACY_INTERVAL: float = 1.0

func _process_diplomacy() -> void:
	if not active_scenario.has("countries"):
		return
		
	var faction_infringements = {}
	
	for u in units_list:
		if is_instance_valid(u) and not u.get("is_dead") and u.get("unit_type") in ["Infantry", "Armor"]:
			var pos = u.get("current_position")
			if pos == null:
				pos = u.get("target_position")
				if pos == null:
					pos = u.global_position
					
			var tile_id = _get_tile_from_vector3(pos)
			var region_city_name = map_data.get_region(tile_id)
			var c_name = ""
			
			if region_city_name != "" and active_scenario.has("countries"):
				for country in active_scenario["countries"].keys():
					var c_data = active_scenario["countries"][country]
					if c_data.has("cities") and c_data["cities"].has(region_city_name):
						c_name = country
						break
							
			if c_name != "":
				var is_neutral = false
				var c_data = active_scenario["countries"][c_name]
				if c_data.has("cities"):
					for city in c_data["cities"]:
						if active_scenario.has("neutral_cities") and active_scenario["neutral_cities"].has(city):
							is_neutral = true
							break
							
				if is_neutral:
					var fac = u.get("faction_name")
					if fac != "":
						if not faction_infringements.has(c_name):
							faction_infringements[c_name] = []
						if not faction_infringements[c_name].has(fac):
							faction_infringements[c_name].append(fac)
							
	for c_name in faction_infringements.keys():
		for fac in faction_infringements[c_name]:
			# Issue 1 point decay because they are standing in neutral territory (ticks every 1s)
			rpc("sync_diplomatic_penalty", c_name, fac, 1.0, "Invasion")
			print("DIPLOMATIC INCIDENT: ", fac, " invaded neutral ", c_name)
			
func _evaluate_country_alignment(country_name: String, triggering_faction: String = "") -> void:
	if not active_scenario.has("countries") or not active_scenario["countries"].has(country_name):
		return
		
	var c_data = active_scenario["countries"][country_name]
	if not c_data.has("opinions") or not c_data.has("cities"):
		return
		
	# Find current owner faction of the country (assuming all cities are owned by same faction for simplicity)
	var current_faction = ""
	var is_neutral = false
	if active_scenario.has("neutral_cities") and c_data["cities"].size() > 0 and active_scenario["neutral_cities"].has(c_data["cities"][0]):
		is_neutral = true
	else:
		if active_scenario.has("factions"):
			for f_name in active_scenario["factions"].keys():
				if active_scenario["factions"][f_name].has("cities") and c_data["cities"].size() > 0 and active_scenario["factions"][f_name]["cities"].has(c_data["cities"][0]):
					current_faction = f_name
					break
					
	if current_faction != "":
		# If allied, check if it wants to leave
		var op = c_data["opinions"].get(current_faction, 0.0)
		if op < 50.0:
			# Leave faction, become neutral
			print("DIPLOMACY: ", country_name, " has left the ", current_faction, " faction and is now neutral!")
			if ConsoleManager and ConsoleManager.has_method("local_log_message"):
				var fac_name = active_scenario["factions"][current_faction].get("display_name", current_faction) if (active_scenario.has("factions") and active_scenario["factions"].has(current_faction)) else current_faction
				ConsoleManager.local_log_message("SYSTEM: " + country_name + " has declared neutrality and formally withdrawn from the " + fac_name + " alliance.")
			if get_node_or_null("/root/NetworkManager") and NetworkManager.is_host:
				for city in c_data["cities"]:
					rpc("sync_city_capture", city, "neutral", current_faction)
			is_neutral = true
			current_faction = ""
			
	if is_neutral:
		# Check if it likes someone enough to join their faction directly
		var loves_faction = ""
		for f_name in c_data["opinions"].keys():
			if c_data["opinions"][f_name] >= 50.0 and f_name == triggering_faction:
				loves_faction = f_name
				break
				
		if loves_faction == "":
			for f_name in c_data["opinions"].keys():
				if c_data["opinions"][f_name] >= 50.0:
					loves_faction = f_name
					break
					
		if loves_faction != "":
			if active_scenario.has("factions") and active_scenario["factions"].has(loves_faction) and not active_scenario["factions"][loves_faction].get("eliminated", false):
				print("DIPLOMACY: ", country_name, " has joined the ", loves_faction, " faction due to high opinion!")
				if ConsoleManager and ConsoleManager.has_method("local_log_message"):
					var col = _get_fac_color_hex(loves_faction)
					var fac_name = active_scenario["factions"][loves_faction].get("display_name", loves_faction) if (active_scenario.has("factions") and active_scenario["factions"].has(loves_faction)) else loves_faction
					var f_str = "[color=" + col + "]" + fac_name + "[/color]"
					ConsoleManager.local_log_message("SYSTEM: " + country_name + " has joined the " + f_str + " alliance!")
				if get_node_or_null("/root/NetworkManager") and NetworkManager.is_host:
					for city in c_data["cities"]:
						rpc("sync_city_capture", city, loves_faction, "neutral")
				return
				
		# Check if it hates someone enough to join their enemy
		var hates_faction = ""
		for f_name in c_data["opinions"].keys():
			if c_data["opinions"][f_name] < -50.0 and f_name == triggering_faction:
				hates_faction = f_name
				break
				
		if hates_faction == "" :
			for f_name in c_data["opinions"].keys():
				if c_data["opinions"][f_name] < -50.0:
					hates_faction = f_name
					break
					
		if hates_faction != "":
			# Pick highest opinion faction that is not the hated faction
			var best_fac = ""
			var best_op = -INF
			if active_scenario.has("factions"):
				for f_name in active_scenario["factions"].keys():
					if f_name != hates_faction and not active_scenario["factions"][f_name].get("eliminated", false):
						var op = c_data["opinions"].get(f_name, 0.0)
						if op > best_op:
							best_op = op
							best_fac = f_name
					
			if best_fac != "" and active_scenario.has("factions") and active_scenario["factions"].has(best_fac):
				print("DIPLOMACY: ", country_name, " has joined the ", best_fac, " faction in response to aggression!")
				if ConsoleManager and ConsoleManager.has_method("local_log_message"):
					var col = _get_fac_color_hex(best_fac)
					var fac_name = active_scenario["factions"][best_fac].get("display_name", best_fac) if (active_scenario.has("factions") and active_scenario["factions"].has(best_fac)) else best_fac
					var f_str = "[color=" + col + "]" + fac_name + "[/color]"
					ConsoleManager.local_log_message("SYSTEM: " + country_name + " has joined the " + f_str + " alliance!")
				if get_node_or_null("/root/NetworkManager") and NetworkManager.is_host:
					if best_op < 50.0:
						# User requested: when country joins due to invasion, its opinion of the joining faction should be at least +50
						# We suppress alignment evaluation explicitly to avoid infinite recursion over the new 50.0 triggering a second event wave natively.
						rpc("sync_diplomatic_penalty", country_name, best_fac, best_op - 50.0, "", false)
					for city in c_data["cities"]:
						rpc("sync_city_capture", city, best_fac, "neutral")

@rpc("authority", "call_local", "reliable")
func sync_diplomatic_penalty(country_name: String, faction: String, penalty: float, log_reason: String = "", evaluate_alignment: bool = true) -> void:
	if not active_scenario.has("countries") or not active_scenario["countries"].has(country_name):
		return
		
	var c_data = active_scenario["countries"][country_name]
	if not c_data.has("opinions"):
		c_data["opinions"] = {}
		
	var current_opinion = c_data["opinions"].get(faction, 0.0)
	c_data["opinions"][faction] = current_opinion - penalty
	
	if ConsoleManager and log_reason == "Invasion":
		var col = _get_fac_color_hex(faction)
		var f_str = "[outline_size=2][outline_color=#dddddd][color=" + col + "]" + faction + "[/color][/outline_color][/outline_size]"
		var should_log = (current_opinion == 0.0) or (current_opinion > -99.0 and int(abs(current_opinion)) % 10 == 0)
		
		var cooldown_key = faction + "_" + country_name
		if should_log and not _violation_log_cooldowns.has(cooldown_key):
			ConsoleManager.log_message("SYSTEM: " + f_str + " forces violated the neutrality of " + country_name + "!")
			_violation_log_cooldowns[cooldown_key] = 300.0
			
			var main_node = get_node_or_null("/root/Main")
			if main_node and main_node.has_method("post_news_event"):
				main_node.post_news_event(faction + " violated the neutrality of " + country_name + "!", [faction])
			
	# Suppressed localized console messages about basic alignment deteriorations per user request.
	# Major defection announcements remain managed inside `_evaluate_country_alignment()`.
	var main_node = get_node_or_null("/root/Main")
	if main_node and main_node.has_method("_update_diplomacy_ui"):
		main_node._update_diplomacy_ui()
	
	if evaluate_alignment and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_evaluate_country_alignment(country_name, faction)

@rpc("authority", "call_local", "reliable")
func sync_global_diplomatic_penalty(faction: String, penalties: Dictionary, log_reason: String = "", evaluate_alignment: bool = true) -> void:
	if not active_scenario.has("countries"):
		return
		
	for country_name in penalties:
		var penalty = penalties[country_name]
		if not active_scenario["countries"].has(country_name):
			continue
			
		var c_data = active_scenario["countries"][country_name]
		if not c_data.has("opinions"):
			c_data["opinions"] = {}
			
		var current_opinion = c_data["opinions"].get(faction, 0.0)
		c_data["opinions"][faction] = current_opinion - penalty
		
	if log_reason != "":
		print("Global Diplomatic Penalty applied to ", faction, " across ", penalties.size(), " countries for: ", log_reason)
		
	var main_node = get_node_or_null("/root/Main")
	if main_node and main_node.has_method("_update_diplomacy_ui"):
		main_node._update_diplomacy_ui()

	if evaluate_alignment and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		for country_name in penalties:
			_evaluate_country_alignment(country_name, faction)
			
func _process_city_captures() -> void:
	for city_node in city_nodes:
		var land_factions = []
		var sea_factions = []
		
		# First find the 'current_owner'
		var current_owner = ""
		if active_scenario.has("factions"):
			for f_name in active_scenario["factions"].keys():
				if active_scenario["factions"][f_name].has("cities") and city_node.name in active_scenario["factions"][f_name]["cities"]:
					current_owner = f_name
					break
		if current_owner == "":
			current_owner = "neutral"
			
		for u in units_list:
			if not is_instance_valid(u):
				continue
			if u.get("is_dead") != true:
				var dist = city_node.position.distance_to(u.position) / radius
				if dist <= 0.01:
					var fac = u.get("faction_name")
					if u.get("unit_type") in ["Infantry", "Armor"]:
						if not land_factions.has(fac): land_factions.append(fac)
					elif u.get("unit_type") in ["Cruiser", "Submarine", "Transport"]:
						if not sea_factions.has(fac): sea_factions.append(fac)
						
		# A city can only be physically captured by a single faction's Land units
		if land_factions.size() == 1:
			var capturing_faction = land_factions[0]
			var is_contested = false
			
			# Contested if any other faction has sea units actively present in the perimeter
			for fac in sea_factions:
				if fac != capturing_faction:
					is_contested = true
					break
					
			if not is_contested and capturing_faction != "" and capturing_faction != current_owner:
				# Increment timer 
				if not active_captures.has(city_node.name) or active_captures[city_node.name]["faction"] != capturing_faction:
					active_captures[city_node.name] = { "faction": capturing_faction, "time": 1.0 }
				else:
					active_captures[city_node.name]["time"] += 1.0
					
				# Capture execution condition
				if active_captures[city_node.name]["time"] >= 10.0:
					active_captures.erase(city_node.name)
					
					if current_owner == "neutral" and active_scenario.has("countries"):
						for c_name in active_scenario["countries"].keys():
							if active_scenario["countries"][c_name].has("cities") and city_node.name in active_scenario["countries"][c_name]["cities"]:
								var op = active_scenario["countries"][c_name].get("opinions", {}).get(capturing_faction, 0.0)
								if op < 50.0:
									rpc("sync_diplomatic_penalty", c_name, capturing_faction, 100.0, "Captured Neutral City")
								break
					rpc("sync_city_capture", city_node.name, capturing_faction, current_owner)
			else:
				# Reset progress if contested or already owned
				active_captures.erase(city_node.name)
		else:
			# Reset progress if 0 or >1 land factions are inside
			active_captures.erase(city_node.name)

@rpc("authority", "call_local", "reliable")
func sync_city_capture(city_name: String, new_faction: String, old_faction: String) -> void:
	print("City Capture: ", city_name, " captured by ", new_faction, " from ", old_faction)
	var network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager and network_manager.is_host:
		var old_str = old_faction if old_faction != "neutral" else "neutral forces"
		var alert_str = city_name + " was captured by " + new_faction + " from " + old_str + "."
		ConsoleManager.log_message(alert_str)
		
	if network_manager and multiplayer.has_multiplayer_peer():
		var local_id = multiplayer.get_unique_id()
		if network_manager.players.has(local_id) and old_faction == network_manager.players[local_id].get("faction", ""):
			if city_loss_sfx:
				city_loss_sfx.play()
	
	# Destroy Air Units in Captured Cities
	var c_tiles = []
	var c_data = {}
	if active_scenario.has("cities") and active_scenario["cities"].has(city_name):
		c_data = active_scenario["cities"][city_name]
	elif cached_city_data.has(city_name):
		c_data = cached_city_data[city_name]
		
	if c_data.has("latitude") and c_data.has("longitude"):
		var base_raw_pos = _lat_lon_to_vector3(deg_to_rad(c_data["latitude"]), deg_to_rad(c_data["longitude"]), radius)
		var base_tile = _get_tile_from_vector3(base_raw_pos)
		c_tiles.append(base_tile)
		c_tiles.append_array(map_data.get_neighbors(base_tile))
			
	for u in units_list:
		if is_instance_valid(u) and not u.get("is_dead") and u.get("unit_type") == "Air":
			var u_tile = _get_tile_from_vector3(u.global_position)
			if u_tile in c_tiles:
				u.take_damage(9999.0) # Destroy it
	
	# Strip from old faction
	if old_faction == "neutral":
		if active_scenario.has("neutral_cities"):
			active_scenario["neutral_cities"].erase(city_name)
	else:
		if active_scenario.has("factions") and active_scenario["factions"].has(old_faction):
			if active_scenario["factions"][old_faction].has("cities"):
				active_scenario["factions"][old_faction]["cities"].erase(city_name)
				
	# Add to new faction
	if new_faction == "neutral":
		if not active_scenario.has("neutral_cities"):
			active_scenario["neutral_cities"] = []
		if not active_scenario["neutral_cities"].has(city_name):
			active_scenario["neutral_cities"].append(city_name)
	elif active_scenario.has("factions") and active_scenario["factions"].has(new_faction):
		if not active_scenario["factions"][new_faction].has("cities"):
			active_scenario["factions"][new_faction]["cities"] = []
		if not active_scenario["factions"][new_faction]["cities"].has(city_name):
			active_scenario["factions"][new_faction]["cities"].append(city_name)
			
	# Process Elimination
	var faction_eliminated = false
	if old_faction != "neutral" and active_scenario.has("factions") and active_scenario["factions"].has(old_faction):
		var old_fac_data = active_scenario["factions"][old_faction]
		if old_fac_data.has("capitol") and old_fac_data["capitol"] == city_name:
			print("FACTION ELIMINATED: ", old_faction, " lost their capitol (", city_name, ")!")
			faction_eliminated = true
			old_fac_data["eliminated"] = true
			
			# Transfer remaining cities to neutral
			if old_fac_data.has("cities"):
				if not active_scenario.has("neutral_cities"):
					active_scenario["neutral_cities"] = []
				for rem_city in old_fac_data["cities"]:
					active_scenario["neutral_cities"].append(rem_city)
				old_fac_data["cities"].clear()
				
			# Destroy all units belonging to the eliminated faction
			for u in units_list:
				if is_instance_valid(u) and u.get("faction_name") == old_faction:
					u.queue_free()

	# Redraw borders
	_generate_faction_borders()
	
	# Emit so HUD can update
	city_captured.emit(city_name, new_faction, old_faction)
	
	# Process Victory Condition
	if faction_eliminated and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var remaining_factions = []
		for f_name in active_scenario["factions"].keys():
			if not active_scenario["factions"][f_name].get("eliminated", false):
				remaining_factions.append(f_name)
				
		if remaining_factions.size() == 1:
			var winner = remaining_factions[0]
			print("VICTORY CONDITION MET: ", winner, " is the last standing faction!")
			rpc("sync_victory", winner)

@rpc("authority", "call_local", "reliable")
func sync_victory(winning_faction: String) -> void:
	victory_declared.emit(winning_faction)

func _update_camera() -> void:
	var t = Transform3D.IDENTITY
	t = t.rotated(Vector3.UP, current_longitude + PI)
	t = t.rotated(t.basis.x, -current_latitude)
	camera_pivot.transform = t
	
	focus_changed.emit(current_longitude, current_latitude)

@rpc("any_peer", "call_local", "reliable")
func sync_nuke_purchase(faction: String, cost: float) -> void:
	if active_scenario.has("factions") and active_scenario["factions"].has(faction):
		var fac_data = active_scenario["factions"][faction]
		var money = fac_data.get("money", 0.0)
		fac_data["money"] = money - cost
		fac_data["nukes"] = fac_data.get("nukes", 0) + 1
		if ConsoleManager:
			var col = _get_fac_color_hex(faction)
			var fac = "[outline_size=2][outline_color=#dddddd][color=" + col + "]" + faction + "[/color][/outline_color][/outline_size]"
			# Print to all consoles universally since everyone dreads a nuke
			ConsoleManager.log_message("SYSTEM: " + fac + " has acquired a Nuclear Weapon.")
		# Ping local economy UI to refresh
		var main_node = get_node_or_null("/root/Main")
		if main_node and main_node.has_method("_update_economy_ui"):
			main_node._update_economy_ui()

@rpc("any_peer", "call_local", "reliable")
func request_foreign_aid(country_name: String, faction: String) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		if not active_scenario.has("countries") or not active_scenario.has("factions"): return
		var c_data = active_scenario["countries"].get(country_name)
		var fac_data = active_scenario["factions"].get(faction)
		if not c_data or not fac_data: return
		
		var num_cities = c_data.get("cities", []).size()
		if num_cities <= 0: return
		
		if fac_data.get("money", 0.0) >= 10.0:
			fac_data["money"] -= 10.0
			if multiplayer.has_multiplayer_peer():
				rpc("sync_foreign_aid", country_name, faction)
			else:
				sync_foreign_aid(country_name, faction)

@rpc("authority", "call_local", "reliable")
func sync_foreign_aid(country_name: String, faction: String) -> void:
	if not active_scenario.has("countries"): return
	var c_data = active_scenario["countries"].get(country_name)
	if not c_data: return
	
	var num_cities = c_data.get("cities", []).size()
	if num_cities <= 0: return
	
	var shift = 100.0 / float(num_cities)
	
	if not c_data.has("opinions"):
		c_data["opinions"] = {}
		
	# Determine current alignment
	var current_faction = ""
	var is_neutral = false
	if active_scenario.has("neutral_cities") and c_data.get("cities", []).size() > 0 and active_scenario["neutral_cities"].has(c_data["cities"][0]):
		is_neutral = true
	else:
		if active_scenario.has("factions"):
			for f_name in active_scenario["factions"].keys():
				if active_scenario["factions"][f_name].has("cities") and c_data.get("cities", []).size() > 0 and active_scenario["factions"][f_name]["cities"].has(c_data["cities"][0]):
					current_faction = f_name
					break
					
	if current_faction != "" and current_faction != faction:
		# Enemy allied country -> shift diplomatic opinion of the current aligned faction DOWN 
		var current_op = c_data["opinions"].get(current_faction, 0.0)
		var new_op = max(0.0, current_op - shift)
		c_data["opinions"][current_faction] = new_op
	elif is_neutral:
		# Neutral country -> shift diplomatic opinion of the faction sending foreign aid UP 
		var current_op = c_data["opinions"].get(faction, 0.0)
		var new_op = min(100.0, current_op + shift)
		c_data["opinions"][faction] = new_op
	elif current_faction == faction:
		# Friendly allied country -> shift diplomatic opinion of the current aligned faction UP
		var current_op = c_data["opinions"].get(faction, 0.0)
		var new_op = min(100.0, current_op + shift)
		c_data["opinions"][faction] = new_op
	
	var col = _get_fac_color_hex(faction)
	var fac_str = "[outline_size=2][outline_color=#dddddd][color=" + col + "]" + faction + "[/color][/outline_color][/outline_size]"
	if ConsoleManager and ConsoleManager.has_method("local_log_message"):
		ConsoleManager.local_log_message("SYSTEM: " + fac_str + " provided Foreign Aid to " + country_name + ".")
	
	var main_node = get_node_or_null("/root/Main")
	if main_node and main_node.has_method("post_news_event"):
		main_node.post_news_event(faction + " provided Foreign Aid to " + country_name, [faction])
	
	_evaluate_country_alignment(country_name, faction)
	if main_node and main_node.has_method("_update_economy_ui"):
		main_node._update_economy_ui()

@rpc("any_peer", "call_local", "reliable")
func sync_unit_purchase(city_name: String, unit_type: String, faction: String, cost: float) -> void:
	print("Unit Purchase: ", faction, " bought ", unit_type, " at ", city_name, " for ", cost)
	
	if ConsoleManager:
		var col = _get_fac_color_hex(faction)
		var fac = "[color=" + col + "]" + faction + "[/color]"

		var local_fac = _get_local_faction()
		var should_log = true

		if local_fac != "" and faction != local_fac:
			should_log = false
			# Find city tile to evaluate local horizon
			for cn in city_nodes:
				if cn.name == "Unit_City_" + city_name:
					var c_pos = cn.global_position
					var vision_range = 0.036
					for f_pos in friendly_unit_positions:
						if c_pos.distance_to(f_pos) <= vision_range:
							should_log = true
							break
					if not should_log:
						for f_c_pos in friendly_city_positions:
							if c_pos.distance_to(f_c_pos) <= vision_range:
								should_log = true
								break
					if not should_log:
						for bubble in friendly_air_bubbles:
							if c_pos.distance_to(bubble.pos) <= bubble.range:
								should_log = true
								break
					break

		if should_log:
			ConsoleManager.local_log_message(fac + " deployed " + unit_type + " in " + city_name)
	
	# Universally enforce native deploy locks across host and all clients internally
	city_cooldowns[city_name] = 300.0
	
	if active_scenario.has("factions") and active_scenario["factions"].has(faction):
		var money = active_scenario["factions"][faction].get("money", 0.0)
		active_scenario["factions"][faction]["money"] = money - cost
		
	# Ensure the unit definition is formally recorded in the active scenario data so it syncs and saves properly
	if not active_scenario["factions"][faction].has("units"):
		active_scenario["factions"][faction]["units"] = []
	
	var unit_def = {
		"type": unit_type,
		"location": city_name,
		"status": "active"
	}
	
	active_scenario["factions"][faction]["units"].append(unit_def)
	
	# If we are the host, immediately broadcast the updated economy down to the clients so their UI updates
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and has_node("/root/Main"):
		var main_node = get_node("/root/Main")
		if main_node.has_method("sync_economy"):
			main_node.rpc("sync_economy", active_scenario)
			main_node.sync_economy(active_scenario)
			
	# Add 5 minute (300 second) cooldown to the city
	city_cooldowns[city_name] = 300.0
	
	# Spawning logic handles attaching it to the scene locally
	var path = "res://src/data/city_data.json"
	var c_dict = {}
	if FileAccess.file_exists(path):
		var c_json = JSON.new()
		if c_json.parse(FileAccess.open(path, FileAccess.READ).get_as_text()) == OK:
			c_dict = c_json.data
	
	# Force it as friendly if the buyer is the local player
	var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var local_faction = ""
	if NetworkManager and NetworkManager.players.has(local_id):
		local_faction = NetworkManager.players[local_id].get("faction", "")
	
	_spawn_unit(unit_def, faction, c_dict, {})

func _instantiate_scenario(scenario_data: Dictionary, progress_callback: Callable = Callable()) -> void:
	if scenario_data.is_empty():
		return
	active_scenario = scenario_data
		
	var active_cities: Array[String] = []
	var active_oil: Array[String] = []
	
	if scenario_data.has("factions"):
		for faction in scenario_data["factions"].values():
			if faction.has("cities"):
				for c in faction["cities"]:
					active_cities.append(c)
			if faction.has("oil"):
				for o in faction["oil"]:
					active_oil.append(o)
					
	if scenario_data.has("neutral_cities"):
		for c in scenario_data["neutral_cities"]:
			active_cities.append(c)
	if scenario_data.has("neutral_oil"):
		for o in scenario_data["neutral_oil"]:
			active_oil.append(o)
			
	var active_regions: Array[String] = []
	var faction_regions: Dictionary = {}
	
	var path = "res://src/data/city_data.json"
	var c_dict = {}
	if FileAccess.file_exists(path):
		var c_json = JSON.new()
		if c_json.parse(FileAccess.open(path, FileAccess.READ).get_as_text()) == OK:
			c_dict = c_json.data
			
	if c_dict.is_empty() == false:
		if scenario_data.has("factions"):
			for f_name in scenario_data["factions"].keys():
				faction_regions[f_name] = []
				var faction = scenario_data["factions"][f_name]
				if faction.has("cities"):
					for c_name in faction["cities"]:
						active_regions.append(c_name)
						faction_regions[f_name].append(c_name)
						
		if scenario_data.has("neutral_cities"):
			for c_name in scenario_data["neutral_cities"]:
				active_regions.append(c_name)

	if c_dict.is_empty() == false:
		# --- Inject Pre-Generated Dynamic Countries ---
		if not NetworkManager.initial_countries.is_empty():
			if not scenario_data.has("countries"):
				scenario_data["countries"] = {}
				
			for c_name in NetworkManager.initial_countries.keys():
				scenario_data["countries"][c_name] = NetworkManager.initial_countries[c_name].duplicate(true)
				
				if scenario_data["countries"][c_name].has("cities"):
					for city in scenario_data["countries"][c_name]["cities"]:
						if not active_cities.has(city):
							active_cities.append(city)
						if not active_regions.has(city):
							active_regions.append(city)
						if not scenario_data.has("neutral_cities"):
							scenario_data["neutral_cities"] = []
						if not scenario_data["neutral_cities"].has(city):
							scenario_data["neutral_cities"].append(city)
		# ----------------------------------

	if scenario_data.has("countries"):
		for c_name in scenario_data["countries"].keys():
			if not scenario_data["countries"][c_name].has("opinions"):
				var ops = {}
				if scenario_data.has("factions"):
					for f_name in scenario_data["factions"].keys():
						ops[f_name] = 0.0
				scenario_data["countries"][c_name]["opinions"] = ops

	# Identitfy active regions from oil
	var opath = "res://src/data/oil_data.json"
	if FileAccess.file_exists(opath):
		var o_json = JSON.new()
		if o_json.parse(FileAccess.open(opath, FileAccess.READ).get_as_text()) == OK:
			var o_arr = o_json.data
			if scenario_data.has("factions"):
				for faction_name in scenario_data["factions"].keys():
					var faction = scenario_data["factions"][faction_name]
					if faction.has("oil"):
						for o_name in faction["oil"]:
							for marker in o_arr:
								if marker.get("tile") == o_name:
									var pos = marker.get("position")
									var tile = _get_tile_from_vector3(Vector3(pos.x, pos.y, pos.z).normalized() * radius)
									var reg = map_data.get_region(tile)
									if reg != "":
										if not active_regions.has(reg):
											active_regions.append(reg)
										if not faction_regions[faction_name].has(reg):
											faction_regions[faction_name].append(reg)
			# Neutral oil
			if scenario_data.has("neutral_oil"):
				for o_name in scenario_data["neutral_oil"]:
					for marker in o_arr:
						if marker.get("tile") == o_name:
							var pos = marker.get("position")
							var tile = _get_tile_from_vector3(Vector3(pos.x, pos.y, pos.z).normalized() * radius)
							var reg = map_data.get_region(tile)
							if reg != "" and not active_regions.has(reg):
								active_regions.append(reg)

	if progress_callback.is_valid():
		progress_callback.call(0.2, "Baking Regions...")
		await get_tree().process_frame
	map_data.cull_regions(active_regions)
	
	if progress_callback.is_valid():
		progress_callback.call(0.4, "Loading Cities...")
		await get_tree().process_frame
	_load_cities(active_cities)
	
	if progress_callback.is_valid():
		progress_callback.call(0.6, "Loading Resource Nodes...")
		await get_tree().process_frame
	_load_oil(active_oil)
	
	# Spawn defined Units
	if progress_callback.is_valid():
		progress_callback.call(0.8, "Deploying Entities...")
		await get_tree().process_frame
	if c_dict.is_empty() == false:
		if scenario_data.has("factions"):
			for faction_name in scenario_data["factions"].keys():
				var faction = scenario_data["factions"][faction_name]
				if faction.has("units"):
					for unit_def in faction["units"]:
						_spawn_unit(unit_def, faction_name, c_dict, faction_regions)
						
	if progress_callback.is_valid():
		progress_callback.call(0.9, "Generating Country Labels...")
		await get_tree().process_frame
	_generate_country_labels(c_dict)
	
	if progress_callback.is_valid():
		progress_callback.call(0.95, "Generating Faction Labels...")
		await get_tree().process_frame
	_generate_faction_labels(c_dict)
	
	_generate_faction_borders()

func _generate_country_labels(city_dict: Dictionary) -> void:
	if not active_scenario.has("countries"):
		return
		
	var country_labels_parent = Node3D.new()
	country_labels_parent.name = "CountryLabels"
	add_child(country_labels_parent)
	
	for country_name in active_scenario["countries"]:
		var data = active_scenario["countries"][country_name]
		var cities = data.get("cities", [])
		if cities.size() == 0:
			continue
			
		var centroid = Vector3.ZERO
		var valid_cities = 0
		for city_name in cities:
			if city_dict.has(city_name):
				var c_lat = deg_to_rad(city_dict[city_name].get("latitude", 0.0))
				var c_lon = deg_to_rad(city_dict[city_name].get("longitude", 0.0))
				var pos = _lat_lon_to_vector3(c_lat, c_lon, radius)
				centroid += pos.normalized()
				valid_cities += 1
		
		if valid_cities > 0:
			centroid = centroid / float(valid_cities)
			centroid = centroid.normalized() * (radius * 1.003) # Project slightly above surface to prevent clipping
			
			var label = Label3D.new()
			label.text = country_name
			label.modulate = Color.BLACK
			label.outline_render_priority = 0
			label.outline_modulate = Color.WHITE
			label.outline_size = 2
			label.font_size = 18 + (cities.size() * 1.5) 
			label.pixel_size = 0.00025
			label.autowrap_mode = TextServer.AUTOWRAP_WORD
			label.width = 350.0
			label.position = centroid
			country_labels_parent.add_child(label)
			
			var up_vec = Vector3.UP
			if abs(centroid.normalized().y) > 0.99:
				up_vec = Vector3.RIGHT
			label.look_at(Vector3.ZERO, up_vec)
			print("Added 3D Label for ", country_name, " at ", centroid, " scale: ", label.font_size)

func _generate_faction_labels(city_dict: Dictionary) -> void:
	if not active_scenario.has("factions"):
		return
		
	var faction_labels_parent = Node3D.new()
	faction_labels_parent.name = "FactionLabels"
	add_child(faction_labels_parent)
	
	for faction_name in active_scenario["factions"]:
		var data = active_scenario["factions"][faction_name]
		var cap = data.get("capital", data.get("capitol", ""))
		if cap == "" or not city_dict.has(cap):
			continue
			
		var c_lat = deg_to_rad(city_dict[cap].get("latitude", 0.0))
		var c_lon = deg_to_rad(city_dict[cap].get("longitude", 0.0))
		var centroid = _lat_lon_to_vector3(c_lat, c_lon, radius)
		
		# Offset slightly higher than country labels to ensure visibility and prevent clipping
		centroid = centroid.normalized() * (radius * 1.004)
		
		var d_name = data.get("display_name", faction_name)
		var label = Label3D.new()
		label.text = d_name.to_upper()
		
		# Determine faction color
		var fac_color = Color.WHITE
		var c_val = data.get("color", "#ffffff")
		if typeof(c_val) == TYPE_STRING:
			fac_color = Color(c_val)
		elif typeof(c_val) == TYPE_ARRAY and c_val.size() >= 3:
			fac_color = Color(c_val[0], c_val[1], c_val[2])
			
		label.modulate = fac_color
		label.outline_render_priority = 0
		label.outline_modulate = Color.BLACK
		label.outline_size = 3
		# Adjust offset to push the text "near" the city but not covering the exact center
		label.offset = Vector2(0, 45)
		label.font_size = 32
		label.pixel_size = 0.00025
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.width = 500.0
		label.position = centroid
		faction_labels_parent.add_child(label)
		
		var up_vec = Vector3.UP
		if abs(centroid.normalized().y) > 0.99:
			up_vec = Vector3.RIGHT
		label.look_at(Vector3.ZERO, up_vec)
		print("Added 3D Faction Label for ", faction_name, " near ", cap)

func _load_cities(active_cities: Array[String]) -> void:
	var path = "res://src/data/city_data.json"
	if not FileAccess.file_exists(path):
		push_error("GlobeView: Could not find city_data.json")
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		push_error("GlobeView: Failed to parse city_data.json error " + str(err))
		return
		
	var cities_dict = json.data
	cached_city_data = cities_dict
	
	# Pre-load the full city spritesheet into memory
	var tex_map = load("res://src/assets/spritesheet.png") as Texture2D
	if not tex_map:
		push_error("GlobeView: Failed to load spritesheet.png")
		return
	var img = tex_map.get_image()
		
	# Slice the 32x32 tiles
	# Center Marker (Row 16, Col 1) -> y=480, x=0
	var tex_center = ImageTexture.create_from_image(img.get_region(Rect2i(0, 480, 32, 32)))
	
	# Land Surrounds (Row 16, Col 2-9)
	var tex_land: Array[ImageTexture] = []
	for i in range(8):
		tex_land.append(ImageTexture.create_from_image(img.get_region(Rect2i(32 + (i * 32), 480, 32, 32))))
		
	# Ocean Surrounds (Row 15, Col 2-9)
	var tex_ocean: Array[ImageTexture] = []
	for i in range(8):
		tex_ocean.append(ImageTexture.create_from_image(img.get_region(Rect2i(32 + (i * 32), 448, 32, 32))))
		
	# Capitol Land Surrounds (Row 14, Col 2-9)
	var tex_cap_land: Array[ImageTexture] = []
	for i in range(8):
		tex_cap_land.append(ImageTexture.create_from_image(img.get_region(Rect2i(32 + (i * 32), 416, 32, 32))))
		
	# Capitol Ocean Surrounds (Row 13, Col 2-9)
	var tex_cap_ocean: Array[ImageTexture] = []
	for i in range(8):
		tex_cap_ocean.append(ImageTexture.create_from_image(img.get_region(Rect2i(32 + (i * 32), 384, 32, 32))))
		
	print("Loaded city spritesheet slices successfully!")
	
	capitols.clear()
	if active_scenario.has("factions"):
		for faction in active_scenario["factions"].values():
			var cap = faction.get("capital", faction.get("capitol", ""))
			if cap != "":
				capitols[cap] = faction.get("color", "#FFFFFF")
		
	for city_name in cities_dict:
		if not active_cities.has(city_name):
			continue
			
		var data = cities_dict[city_name]
		var lat_deg = data.get("latitude")
		var lon_deg = data.get("longitude")
		
		if lat_deg != null and lon_deg != null:
			# Get generic continuous point to find what Godot discrete Face/X/Y coordinate it lands on
			var raw_pos = _lat_lon_to_vector3(deg_to_rad(lat_deg), deg_to_rad(lon_deg), radius)
			var tile_id = _get_tile_from_vector3(raw_pos)
			city_tile_cache[tile_id] = city_name
			
			print("Placing City: ", city_name, " at Tile: ", tile_id)
			
			var centroid = map_data.get_centroid(tile_id)
			var pos = raw_pos
			if centroid != Vector3.ZERO:
				# Snap it exactly to the geometric center of the true Godot tile so it frames perfectly with the hover outline!
				pos = centroid.normalized() * radius
			
			# Discover exact physical size of the terrain quad here to correct for spherified cube distortion
			var tile_width = _get_tile_width(tile_id)
				
			var node_pixel_size = tile_width / 32.0
			
			var city_node = Node3D.new()
			city_node.name = city_name
			add_child(city_node)
			city_nodes.append(city_node)
			
			var is_capitol = capitols.has(city_name)
			
			var sprite_main = Sprite3D.new()
			sprite_main.texture = tex_center
			if is_capitol:
				sprite_main.modulate = Color(capitols[city_name])
			
			# Mathematically exactly size the 32x32 sprite to stretch perfectly across the true width of the underlying geometric tile!
			sprite_main.pixel_size = node_pixel_size
			# Turn off Billboard so the Sprite lays mathematically flat against the XYZ rotation of the `city_node` LookAt
			sprite_main.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			sprite_main.no_depth_test = true # Guarantee rendering over terrain
			sprite_main.render_priority = 7 # Renters UNDER units (priority 10)
			city_node.add_child(sprite_main)
			
			var border_sprite = Sprite3D.new()
			border_sprite.texture = load("res://src/assets/target_bracket.png")
			border_sprite.pixel_size = node_pixel_size * 1.05
			border_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			border_sprite.no_depth_test = true
			border_sprite.render_priority = 8
			border_sprite.name = "CityBorder"
			border_sprite.visible = false
			city_node.add_child(border_sprite)
			

			
			# Orient the Node directly away from the core
			city_node.position = pos
			if pos.normalized().abs() != Vector3.UP:
				city_node.look_at(Vector3.ZERO, Vector3.UP)
				
			# Generate the 8 surrounding subtiles using the dynamically retrieved tile width
			# Order matches: NW, N, NE, E, SE, S, SW, W -> Index 0 to 7
			var grid_offsets = [
				Vector3(-tile_width, tile_width, 0),  # 0: NW (Top-Left)
				Vector3(0, tile_width, 0),            # 1: N  (Top)
				Vector3(tile_width, tile_width, 0),   # 2: NE (Top-Right)
				Vector3(tile_width, 0, 0),            # 3: E  (Right)
				Vector3(-tile_width, -tile_width, 0), # 4: SW (Bottom-Left) - Fixed Swap
				Vector3(0, -tile_width, 0),           # 5: S  (Bottom)
				Vector3(tile_width, -tile_width, 0),  # 6: SE (Bottom-Right) - Fixed Swap
				Vector3(-tile_width, 0, 0)            # 7: W  (Left)
			]
			
			var o_idx = 0
			for local_offset in grid_offsets:
				# Convert the local XY tangent offset to true Godot global 3D space relative to the angled CityNode
				var global_offset = city_node.to_global(local_offset)
				# Reverse-project the global 3D coordinate back into the specific XYZ Face coordinate string of the map
				var sub_tile_id = _get_tile_from_vector3(global_offset)
				# Cache adjacent tile so hover tooltip displays city name within 3x3 array
				city_tile_cache[sub_tile_id] = city_name
				# Query the memory dictionary to ascertain the biome
				var is_ocean = map_data.get_terrain(sub_tile_id) == "OCEAN"
				
				# Spawn the correct adjacent piece
				var sub_sprite = Sprite3D.new()
				if is_ocean:
					sub_sprite.texture = tex_cap_ocean[o_idx] if is_capitol else tex_ocean[o_idx]
				else:
					sub_sprite.texture = tex_cap_land[o_idx] if is_capitol else tex_land[o_idx]
				
				sub_sprite.pixel_size = node_pixel_size
				sub_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
				sub_sprite.no_depth_test = true
				sub_sprite.render_priority = 5
				sub_sprite.position = local_offset # We position it linearly off the center node
				
				city_node.add_child(sub_sprite)
				o_idx += 1
				
			var hl_tex = load("res://src/assets/target_bracket.png") as Texture2D
			if hl_tex:
				var highlight_sprite = Sprite3D.new()
				highlight_sprite.texture = hl_tex
				highlight_sprite.pixel_size = node_pixel_size * 1.2
				var hl_mat = StandardMaterial3D.new()
				hl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				hl_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.4)
				hl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				hl_mat.no_depth_test = true
				hl_mat.render_priority = 25
				highlight_sprite.material_override = hl_mat
				highlight_sprite.visible = false
				highlight_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
				highlight_sprite.name = "HighlightRing"
				
				# Place it exactly at the center of the city node to prevent any parallax shifting 
				# (Render priority 25 ensures it still draws on top)
				highlight_sprite.position = Vector3.ZERO
				city_node.add_child(highlight_sprite)

			cullable_nodes.append(city_node)

func _is_city_coastal(raw_city_name: String) -> bool:
	for t_id in city_tile_cache:
		if city_tile_cache[t_id] == raw_city_name:
			var t = map_data.get_terrain(t_id)
			if t in ["OCEAN", "DEEP_OCEAN", "LAKE", "COAST"]:
				return true
			# Check immediate neighbors of this exact tile
			var neighbors = map_data.get_neighbors(t_id)
			for n in neighbors:
				var nt = map_data.get_terrain(n)
				if nt in ["OCEAN", "DEEP_OCEAN", "LAKE", "COAST"]:
					return true
	return false

func _update_city_highlights(active: bool, is_redeploy: bool = false, is_strategic_bombing: bool = false, is_foreign_aid: bool = false) -> void:
	var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var local_faction = ""
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.players.has(local_id):
		local_faction = nm.players[local_id].get("faction", "")
		
	for city_node in city_nodes:
		var hr = city_node.get_node_or_null("HighlightRing")
		if hr:
			if not active:
				hr.visible = false
				continue
				
			var c_name = city_node.name
			var is_valid = false
			if c_name != "" and local_faction != "":
				if active_scenario.has("factions") and active_scenario["factions"].has(local_faction):
					var fac_data = active_scenario["factions"][local_faction]
					var has_city = fac_data.has("cities") and fac_data["cities"].has(c_name)
					var has_money = true if is_redeploy else fac_data.get("money", 0.0) >= deploying_unit_cost
					var on_cooldown = false if is_redeploy else city_cooldowns.has(c_name)
					var is_full = _is_city_full(c_name)
					
					
					if is_strategic_bombing and selected_unit:
						if not has_city:
							var is_enemy = false
							for e_fac in active_scenario["factions"].keys():
								if e_fac != local_faction and active_scenario["factions"][e_fac].has("cities") and active_scenario["factions"][e_fac]["cities"].has(c_name):
									is_enemy = true
									break
							if is_enemy:
								var attacker_pos = selected_unit.current_position
								var target_tile = -1
								for t_id in city_tile_cache:
									if city_tile_cache[t_id] == c_name:
										target_tile = t_id
										break
								if target_tile != -1:
									var target_pos = map_data.get_centroid(target_tile).normalized() * radius
									var distance = attacker_pos.distance_to(target_pos)
									var ops_radius = 30.0 * _get_tile_width(_get_tile_from_vector3(attacker_pos))
									if distance <= ops_radius:
										is_valid = true
					else:
						if is_redeploy and selected_unit:
							var origin_tile = _get_tile_from_vector3(selected_unit.current_position)
							var origin_city = city_tile_cache.get(origin_tile, "")
							if c_name == origin_city:
								has_city = false
								
						if is_foreign_aid:
							if not has_city and fac_data.get("money", 0.0) >= 10.0:
								is_valid = true
						elif has_city and has_money and not on_cooldown and not is_full:
							if deploying_unit_type in ["Cruiser", "Submarine"]:
								if _is_city_coastal(c_name.replace("Unit_City_", "")):
									is_valid = true
							else:
								is_valid = true
						
			if is_valid:
				hr.visible = true
			else:
				hr.visible = false
				
	for u in units_list:
		if is_instance_valid(u):
			if active:
				if u != selected_unit:
					u.visible = false
			else:
				u.visible = true

func _load_oil(active_oil: Array[String]) -> void:
	var path = "res://src/data/oil_data.json"
	if not FileAccess.file_exists(path):
		push_error("GlobeView: Could not find oil_data.json")
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		push_error("GlobeView: Failed to parse oil_data.json error " + str(err))
		return
		
	var oil_dict = json.data
	
	var tex_map = load("res://src/assets/spritesheet.png") as Texture2D
	if not tex_map:
		push_error("GlobeView: Failed to load oil spritesheet.png")
		return
	var img = tex_map.get_image()
		
	# Slice Oil icon from Row 1 (index 0), Col 8 (index 7) => y=0, x=224
	var tex_oil = ImageTexture.create_from_image(img.get_region(Rect2i(224, 0, 32, 32)))
	
	var outline_mat = ShaderMaterial.new()
	var outline_shader = Shader.new()
	outline_shader.code = """
shader_type spatial;
render_mode unshaded, depth_test_disabled;
uniform sampler2D tex_albedo : source_color, filter_nearest;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
void fragment() {
	vec4 c = texture(tex_albedo, UV);
	vec2 size = vec2(32.0, 32.0);
	float o = 0.0;
	o = max(o, texture(tex_albedo, UV + vec2(-1.0, 0.0) / size).a);
	o = max(o, texture(tex_albedo, UV + vec2(0.0, 1.0) / size).a);
	o = max(o, texture(tex_albedo, UV + vec2(1.0, 0.0) / size).a);
	o = max(o, texture(tex_albedo, UV + vec2(0.0, -1.0) / size).a);
	o = max(o, texture(tex_albedo, UV + vec2(-1.0, -1.0) / size).a);
	o = max(o, texture(tex_albedo, UV + vec2(-1.0, 1.0) / size).a);
	o = max(o, texture(tex_albedo, UV + vec2(1.0, -1.0) / size).a);
	o = max(o, texture(tex_albedo, UV + vec2(1.0, 1.0) / size).a);
	if (c.a > 0.1) {
		ALBEDO = c.rgb;
		ALPHA = c.a;
	} else if (o > 0.1) {
		ALBEDO = outline_color.rgb;
		ALPHA = 1.0;
	} else {
		ALPHA = 0.0;
	}
}
"""
	outline_mat.shader = outline_shader
	outline_mat.set_shader_parameter("tex_albedo", tex_oil)
	outline_mat.render_priority = 5
	
	for marker in oil_dict:
		if not active_oil.has(marker.get("tile", "")):
			continue
			
		var pos_data = marker.get("position")
		if pos_data and pos_data.has("x"):
			var pos = Vector3(pos_data["x"], pos_data["y"], pos_data["z"])
			var final_pos = pos.normalized() * radius
			
			var oil_node = Node3D.new()
			add_child(oil_node)
			
			var sprite = Sprite3D.new()
			sprite.texture = tex_oil
			
			# Enlarged pixel size so the 32x32 sprite is slightly easier to spot than a city
			sprite.pixel_size = 0.00035
			sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			sprite.no_depth_test = true
			sprite.render_priority = 5
			sprite.material_override = outline_mat
			
			oil_node.add_child(sprite)
			
			# Target coordinates generated from map_data.get_centroid, which is explicitly mathematical radius. Push by 1.02 multiplier matching Cities
			oil_node.position = final_pos
			if final_pos.normalized().abs() != Vector3.UP:
				oil_node.look_at(Vector3.ZERO, Vector3.UP)
			
			cullable_nodes.append(oil_node)

func update_outline(min_lon: float, max_lon: float, min_lat: float, max_lat: float) -> void:
	outline_immediate_mesh.clear_surfaces()
	outline_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	var steps = 16
	var r = radius * 1.01
	
	# Top edge (max_lat), going min_lon to max_lon
	for i in range(steps + 1):
		var lon = lerp(min_lon, max_lon, i / float(steps))
		outline_immediate_mesh.surface_add_vertex(_lat_lon_to_vector3(max_lat, lon, r))
		
	# Right edge (max_lon), going max_lat to min_lat
	for i in range(steps + 1):
		var lat = lerp(max_lat, min_lat, i / float(steps))
		outline_immediate_mesh.surface_add_vertex(_lat_lon_to_vector3(lat, max_lon, r))
		
	# Bottom edge (min_lat), going max_lon to min_lon
	for i in range(steps + 1):
		var lon = lerp(max_lon, min_lon, i / float(steps))
		outline_immediate_mesh.surface_add_vertex(_lat_lon_to_vector3(min_lat, lon, r))
		
	# Left edge (min_lon), going min_lat to max_lat
	for i in range(steps + 1):
		var lat = lerp(min_lat, max_lat, i / float(steps))
		outline_immediate_mesh.surface_add_vertex(_lat_lon_to_vector3(lat, min_lon, r))
		
	outline_immediate_mesh.surface_end()
func _handle_click(screen_pos: Vector2, is_left_click: bool) -> void:
	if not is_left_click and selected_unit:
		# Verify ownership before issuing orders
		var local_fac = _get_local_faction()
		if local_fac != "" and selected_unit.get("faction_name") != local_fac:
			selected_unit.set_selected(false)
			selected_unit = null
			if target_bracket:
				target_bracket.visible = false
			if air_strike_bracket:
				air_strike_bracket.visible = false
			if air_redeploy_bracket:
				air_redeploy_bracket.visible = false
			return
			
	var space_state = get_world_3d().direct_space_state
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_end = ray_origin + camera.project_ray_normal(screen_pos) * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	# We want to collide with areas (units) and bodies (the globe)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	print("TESTING RIGHT CLICK Raycast hit target: ", result)
	
	if result:
		var collider = result.collider
		var is_unit = collider is Area3D and collider.get_parent().has_method("set_target")
		var hit_point = result.position
		
		# print("DEBUG CLICKED COLLIDER: ", collider.name if collider else "NULL", " of class ", collider.get_class() if collider else "None")
		
		if is_left_click:
			if is_deploying_foreign_aid:
				var tile_id = _get_tile_from_vector3(hit_point)
				var c_name = city_tile_cache.get(tile_id, "")
				var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
				var local_faction = ""
				if NetworkManager.players.has(local_id):
					local_faction = NetworkManager.players[local_id].get("faction", "")
					
				var is_valid = false
				if c_name != "" and local_faction != "":
					if active_scenario.has("factions") and active_scenario["factions"].has(local_faction):
						var fac_data = active_scenario["factions"][local_faction]
						var has_city = fac_data.has("cities") and fac_data["cities"].has(c_name)
						if not has_city and fac_data.get("money", 0.0) >= 10.0:
							is_valid = true
							
				if is_valid:
					is_deploying_foreign_aid = false
					if foreign_aid_bracket: foreign_aid_bracket.visible = false
					_update_city_highlights(false)
					
					var country_name = ""
					if active_scenario.has("countries"):
						for c_key in active_scenario["countries"].keys():
							if active_scenario["countries"][c_key].has("cities") and active_scenario["countries"][c_key]["cities"].has(c_name):
								country_name = c_key
								break
					if country_name != "":
						if NetworkManager and multiplayer.has_multiplayer_peer():
							rpc("request_foreign_aid", country_name, local_faction)
						else:
							request_foreign_aid(country_name, local_faction)
				return
				
			if deploying_unit_type != "":
				var tile_id = _get_tile_from_vector3(hit_point)
				var c_name = city_tile_cache.get(tile_id, "")
				
				var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
				var local_faction = ""
				if NetworkManager.players.has(local_id):
					local_faction = NetworkManager.players[local_id].get("faction", "")
					
				var is_valid = false
				if c_name != "" and local_faction != "":
					if active_scenario.has("factions") and active_scenario["factions"].has(local_faction):
						var fac_data = active_scenario["factions"][local_faction]
						var has_city = fac_data.has("cities") and fac_data["cities"].has(c_name)
						var has_money = fac_data.get("money", 0.0) >= deploying_unit_cost
						var on_cooldown = city_cooldowns.has(c_name)
						var is_full = _is_city_full(c_name)
						
						var valid_terrain = true
						if deploying_unit_type in ["Cruiser", "Submarine"]:
							valid_terrain = _city_has_water(c_name)
							
						if has_city and has_money and not on_cooldown and not is_full and valid_terrain:
							is_valid = true
							
				if is_valid:
					var cost = deploying_unit_cost
					var u_type = deploying_unit_type
					
					# Immediately apply local cooldown to stop UI double-clicks
					city_cooldowns[c_name] = 300.0
					
					deploying_unit_type = ""
					deployment_ghost.visible = false
					_update_city_highlights(false)
					
					if NetworkManager and multiplayer.has_multiplayer_peer():
						rpc("sync_unit_purchase", c_name, u_type, local_faction, cost)
					else:
						sync_unit_purchase(c_name, u_type, local_faction, cost)
				return
				
			if current_air_operation_mode == "NUKE":
				var hit_tile = _get_tile_from_vector3(hit_point)
				var is_valid_target = true
				var tile_width = 0.006 
				var nbrs = map_data.get_neighbors(hit_tile)
				if nbrs.size() > 0:
					var c1 = map_data.get_centroid(hit_tile).normalized()
					var c2 = map_data.get_centroid(nbrs[0]).normalized()
					tile_width = c1.distance_to(c2) * (radius * 1.02)
					
				var local_fac = _get_local_faction()
				if local_fac == "" and get_node_or_null("/root/NetworkManager") and multiplayer.has_multiplayer_peer() and NetworkManager.players.has(multiplayer.get_unique_id()):
					local_fac = NetworkManager.players[multiplayer.get_unique_id()].get("faction", "")
					
				for fac_name in active_scenario.get("factions", {}).keys():
					if fac_name == local_fac: continue
					var cap_name = active_scenario["factions"][fac_name].get("capitol", "")
					if cap_name != "" and active_scenario.has("cities") and active_scenario["cities"].has(cap_name):
						var c_data = active_scenario["cities"][cap_name]
						var cap_pos = _lat_lon_to_vector3(deg_to_rad(c_data["latitude"]), deg_to_rad(c_data["longitude"]), radius)
						var dist = cap_pos.distance_to(hit_point)
						if dist <= (tile_width * 1.5):
							is_valid_target = false
							break
							
				if is_valid_target:
					var max_others = 0
					for fac in active_scenario["factions"].keys():
						if fac != local_fac:
							max_others = max(max_others, active_scenario["factions"][fac].get("nukes_launched", 0))
					var my_launched = active_scenario["factions"].get(local_fac, {}).get("nukes_launched", 0)
					
					if my_launched < max_others + 4: # Can launch up to 3 MORE than the max others
						# Snap the hit point to the exact centroid of the tile to guarantee perfect collision centering
						var snapped_target = map_data.get_centroid(hit_tile).normalized() * radius
						if get_node_or_null("/root/NetworkManager") and multiplayer.has_multiplayer_peer():
							rpc_id(1, "request_nuke_launch", snapped_target, local_fac)
						else:
							request_nuke_launch(snapped_target, local_fac)
					else:
						ConsoleManager.log_message("Command refused: Maximum unilateral launch threshold exceeded.")
						
					current_air_operation_mode = ""
					if air_strike_bracket: air_strike_bracket.visible = false
				return
				
			if current_air_operation_mode != "" and selected_unit and selected_unit.get("unit_type") == "Air":
				var tile_id = _get_tile_from_vector3(hit_point)
				var local_fac = _get_local_faction()
				if local_fac == "" and multiplayer.has_multiplayer_peer() and NetworkManager.players.has(multiplayer.get_unique_id()):
					local_fac = NetworkManager.players[multiplayer.get_unique_id()].get("faction", "")
					
				var is_ready = selected_unit.get("is_air_ready")
				if is_ready != null and not is_ready:
					current_air_operation_mode = ""
					air_ops_immediate_mesh.clear_surfaces()
					return
					
				var dist = selected_unit.current_position.distance_to(hit_point.normalized() * radius)
				var ops_radius = 30.0 * _get_tile_width(_get_tile_from_vector3(selected_unit.current_position))
				
				if current_air_operation_mode == "AIRSTRIKE":
					if dist <= ops_radius:
						var intended_enemy = null
						if is_unit and collider.get_parent().get("faction_name") != local_fac:
							intended_enemy = collider.get_parent()
						else:
							var all_units = get_tree().get_nodes_in_group("units")
							for u in all_units:
								if u != selected_unit and is_instance_valid(u) and not u.is_dead and u.visible:
									if u.get("faction_name") != local_fac:
										if _get_tile_from_vector3(u.current_position) == tile_id:
											intended_enemy = u
											break
						if intended_enemy:
							if NetworkManager and multiplayer.has_multiplayer_peer() and NetworkManager.players.has(multiplayer.get_unique_id()):
								NetworkManager.request_air_strike.rpc_id(1, selected_unit.name, intended_enemy.name)
							
							current_air_operation_mode = ""
							_update_city_highlights(false)
							selected_unit.set_selected(false)
							selected_unit = null
							if target_bracket: target_bracket.visible = false
							if air_strike_bracket: air_strike_bracket.visible = false
							if air_redeploy_bracket: air_redeploy_bracket.visible = false
							air_ops_immediate_mesh.clear_surfaces()
					return
					
				elif current_air_operation_mode == "STRATEGIC_BOMBING":
					if dist <= ops_radius:
						var c_name = city_tile_cache.get(tile_id, "")
						if c_name != "":
							var city_owner = ""
							if active_scenario.has("factions"):
								for fac in active_scenario["factions"].keys():
									if active_scenario["factions"][fac].has("cities") and active_scenario["factions"][fac]["cities"].has(c_name):
										city_owner = fac
										break
							if city_owner != "" and city_owner != local_fac:
								if NetworkManager and multiplayer.has_multiplayer_peer() and NetworkManager.players.has(multiplayer.get_unique_id()):
									NetworkManager.request_strategic_bombing.rpc_id(1, selected_unit.name, c_name)
								
								current_air_operation_mode = ""
								_update_city_highlights(false)
								selected_unit.set_selected(false)
								selected_unit = null
								if target_bracket: target_bracket.visible = false
								if air_strike_bracket: air_strike_bracket.visible = false
								if air_redeploy_bracket: air_redeploy_bracket.visible = false
								air_ops_immediate_mesh.clear_surfaces()
					return
					
				elif current_air_operation_mode == "REDEPLOY":
					if dist <= ops_radius * 10.0:
						var c_name = city_tile_cache.get(tile_id, "")
						if c_name != "" and active_scenario.has("factions") and active_scenario["factions"].has(local_fac):
							if active_scenario["factions"][local_fac].has("cities") and active_scenario["factions"][local_fac]["cities"].has(c_name):
								if NetworkManager and multiplayer.has_multiplayer_peer() and NetworkManager.players.has(multiplayer.get_unique_id()):
									NetworkManager.request_air_redeploy.rpc_id(1, selected_unit.name, c_name)
								
								current_air_operation_mode = ""
								_update_city_highlights(false)
								selected_unit.set_selected(false)
								selected_unit = null
								if target_bracket: target_bracket.visible = false
								if air_strike_bracket: air_strike_bracket.visible = false
								if air_redeploy_bracket: air_redeploy_bracket.visible = false
								air_ops_immediate_mesh.clear_surfaces()
					return
				
			if is_unit:
				var unit = collider.get_parent()
				if selected_unit and selected_unit != unit:
					selected_unit.set_selected(false)
				selected_unit = unit
				selected_unit.set_selected(true)
				target_bracket.visible = true
				if selected_unit.get("unit_type") == "Air":
					_draw_air_ops_radius(selected_unit)
				else:
					air_ops_immediate_mesh.clear_surfaces()
				_handle_hover(screen_pos)
			elif collider == map_collider:
				if selected_unit:
					selected_unit.set_selected(false)
					selected_unit = null
					if target_bracket: target_bracket.visible = false
					if air_strike_bracket: air_strike_bracket.visible = false
					if air_redeploy_bracket: air_redeploy_bracket.visible = false
					air_ops_immediate_mesh.clear_surfaces()
				return
		elif not is_left_click and selected_unit:
			# If right click when mode is active, cancel mode!
			if current_air_operation_mode != "":
				if current_air_operation_mode == "NUKE":
					if air_strike_bracket: air_strike_bracket.visible = false
				current_air_operation_mode = ""
				_update_city_highlights(false)
				if selected_unit.get("unit_type") == "Air":
					_draw_air_ops_radius(selected_unit, false)
				return
				
			if selected_unit.get("unit_type") == "Air":
				return # Air units DO NOT move via right click anymore
				
			# Right Click = Move land/sea unit to clicked position
			# Perform a strict Raycast to the MAP to find the exact tile clicked, ignoring massive Area3D spheres
			var map_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
			map_query.collide_with_areas = false
			map_query.collide_with_bodies = true
			var map_result = space_state.intersect_ray(map_query)
			
			var map_hit_point = Vector3.ZERO
			if map_result and map_result.collider == map_collider:
				map_hit_point = map_result.position
			elif result:
				# Fallback: if the strict raycast misses the shrunken globe collider,
				# use the original raycast hit point (which might have hit an Area3D near the visual horizon).
				map_hit_point = result.position
				
			if map_hit_point != Vector3.ZERO:
				var tile_id = _get_tile_from_vector3(map_hit_point)
				var exact_target_pos = map_hit_point.normalized() * radius
				
				# Determine if they clicked on a tile exactly containing an enemy
				var intended_enemy = null
				var all_units = get_tree().get_nodes_in_group("units")
				var local_fac = _get_local_faction()
				if local_fac == "" and multiplayer.has_multiplayer_peer() and NetworkManager.players.has(multiplayer.get_unique_id()):
					local_fac = NetworkManager.players[multiplayer.get_unique_id()].get("faction", "")

				for u in all_units:
					if u != selected_unit and is_instance_valid(u) and not u.is_dead:
						if u.get("faction_name") != local_fac: # Enemy
							var u_tile = _get_tile_from_vector3(u.current_position)
							if u_tile == tile_id:
								intended_enemy = u
								break
				
				# We deliberately bypass clear_combat_target() here so that units explicitly retreating on click orders do not lose their engagement bounds prematurely and can continue defending themselves.
					
				if intended_enemy:
					# Real intercept command against the exact enemy
					if NetworkManager and multiplayer.has_multiplayer_peer() and NetworkManager.players.has(multiplayer.get_unique_id()):
						NetworkManager.request_unit_move.rpc_id(1, selected_unit.name, Vector3.ZERO, intended_enemy.name)
					else:
						selected_unit.set_movement_target_unit(intended_enemy)
					print("Unit Ordered to Travel to Enemy Position")
				else:
					# Explicit geometric walk sequence, no snapping to centroids or overlapping areas
					if NetworkManager and multiplayer.has_multiplayer_peer() and NetworkManager.players.has(multiplayer.get_unique_id()):
						NetworkManager.request_unit_move.rpc_id(1, selected_unit.name, exact_target_pos, "")
					else:
						selected_unit.set_target(exact_target_pos)
					print("Unit Ordered To Compute Travel to Exact Coordinate")
				
				# Deselect unit instantly per user request
				selected_unit.set_selected(false)
				selected_unit = null
				if target_bracket:
					target_bracket.visible = false
			else:
				print("FAILED RIGHT CLICK! map_result: ", map_result, " map_collider: ", map_collider)

func _handle_hover(screen_pos: Vector2) -> void:
	var space_state = get_world_3d().direct_space_state
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_end = ray_origin + camera.project_ray_normal(screen_pos) * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == map_collider:
		var tile_id = _get_tile_from_vector3(result.position)
		var centroid = map_data.get_centroid(tile_id)
		
		# Track the mouse position exactly instead of snapping to the centroid.
		# Match the GlobeUnit's elevation precisely to prevent parallax offset.
		var raw_pos = result.position.normalized()
		var snap_pos = raw_pos * radius
		
		var tile_width = 0.006
		var nbrs = map_data.get_neighbors(tile_id)
		if nbrs.size() > 0:
			var c1 = centroid.normalized()
			var c2 = map_data.get_centroid(nbrs[0]).normalized()
			tile_width = c1.distance_to(c2) * (radius * 1.02)
			
		# Scale unit-relative pixel size for 128x128 graphic. Visual matching of tile_width * 3.0
		var tex_width = 128.0
		if target_bracket and target_bracket.texture:
			tex_width = float(target_bracket.texture.get_width())
			
		if current_air_operation_mode == "NUKE":
			var is_valid_target = true
			var local_fac = _get_local_faction()
			if local_fac == "" and get_node_or_null("/root/NetworkManager") and multiplayer.has_multiplayer_peer() and NetworkManager.players.has(multiplayer.get_unique_id()):
				local_fac = NetworkManager.players[multiplayer.get_unique_id()].get("faction", "")
				
			for fac_name in active_scenario.get("factions", {}).keys():
				if fac_name == local_fac: continue
				var cap_name = active_scenario["factions"][fac_name].get("capitol", "")
				if cap_name != "" and active_scenario.has("cities") and active_scenario["cities"].has(cap_name):
					var c_data = active_scenario["cities"][cap_name]
					var cap_pos = _lat_lon_to_vector3(deg_to_rad(c_data["latitude"]), deg_to_rad(c_data["longitude"]), radius)
					var dist = cap_pos.distance_to(result.position)
					if dist <= (tile_width * 1.5):
						is_valid_target = false
						break
						
			if is_valid_target:
				var max_others = 0
				for fac in active_scenario["factions"].keys():
					if fac != local_fac:
						max_others = max(max_others, active_scenario["factions"][fac].get("nukes_launched", 0))
				var my_launched = active_scenario["factions"].get(local_fac, {}).get("nukes_launched", 0)
				if my_launched < max_others + 4:
					if air_strike_bracket.material_override:
						air_strike_bracket.material_override.albedo_color = Color(1.0, 0.0, 0.0) # Red
				else:
					if air_strike_bracket.material_override:
						air_strike_bracket.material_override.albedo_color = Color(0.5, 0.5, 0.5) # Gray (Threshold Blocked)
			else:
				if air_strike_bracket.material_override:
					air_strike_bracket.material_override.albedo_color = Color(0.5, 0.5, 0.5) # Gray
			
			target_bracket.visible = false
			air_redeploy_bracket.visible = false
			air_strike_bracket.position = snap_pos
			air_strike_bracket.look_at(Vector3.ZERO, Vector3.UP)
			air_strike_bracket.pixel_size = (tile_width * 3.0) / 128.0
			air_strike_bracket.visible = true
			return
			
		var show_air_strike = false
		var show_air_redeploy = false
		var valid_target_found = false
		
		if selected_unit and is_instance_valid(selected_unit) and selected_unit.get("unit_type") == "Air" and selected_unit.get("is_air_ready"):
			var ops_radius = 30.0 * tile_width
			
			if current_air_operation_mode == "AIRSTRIKE":
				show_air_strike = true
				var hovered_enemy = null
				for u in units_list:
					if is_instance_valid(u) and u.get("faction_name") != selected_unit.get("faction_name") and u.visible:
						var dist_to_cursor = u.current_position.distance_to(result.position)
						if dist_to_cursor < (tile_width * 5.0): # Made slightly more forgiving
							hovered_enemy = u
							break
				if hovered_enemy:
					if selected_unit.current_position.distance_to(hovered_enemy.current_position) <= ops_radius:
						valid_target_found = true
			elif current_air_operation_mode == "STRATEGIC_BOMBING":
				show_air_strike = true
				var c_name = city_tile_cache.get(tile_id, "")
				if c_name != "":
					var city_owner = ""
					if active_scenario.has("factions"):
						for fac in active_scenario["factions"].keys():
							if active_scenario["factions"][fac].has("cities") and active_scenario["factions"][fac]["cities"].has(c_name):
								city_owner = fac
								break
					if city_owner != "" and city_owner != selected_unit.get("faction_name"):
						if selected_unit.current_position.distance_to(result.position) <= ops_radius:
							valid_target_found = true
			
			elif current_air_operation_mode == "REDEPLOY":
				show_air_redeploy = true
				var c_name = city_tile_cache.get(tile_id, "")
				if c_name != "":
					var city_owner = ""
					for f_name in active_scenario.get("factions", {}).keys():
						if active_scenario["factions"][f_name].has("cities") and active_scenario["factions"][f_name]["cities"].has(c_name):
							city_owner = f_name
							break
					if city_owner == selected_unit.get("faction_name"):
						var origin_tile = _get_tile_from_vector3(selected_unit.current_position)
						var origin_city = city_tile_cache.get(origin_tile, "")
						if c_name != origin_city:
							if selected_unit.current_position.distance_to(result.position) <= ops_radius * 10.0:
								valid_target_found = true
		
		# Set pixel scale so texture fits directly over 3x3 tile block 
		target_bracket.pixel_size = (tile_width * 3.0) / tex_width
		
		if show_air_strike:
			if air_strike_bracket.material_override:
				if valid_target_found:
					air_strike_bracket.material_override.albedo_color = Color(1.0, 0.0, 0.0) # Red
				else:
					air_strike_bracket.material_override.albedo_color = Color(0.5, 0.5, 0.5) # Gray
		elif show_air_redeploy:
			if air_redeploy_bracket.material_override:
				if valid_target_found:
					air_redeploy_bracket.material_override.albedo_color = Color(0.0, 1.0, 0.0) # Green
				else:
					air_redeploy_bracket.material_override.albedo_color = Color(0.5, 0.5, 0.5) # Gray
					
		air_strike_bracket.pixel_size = (tile_width * 3.0) / 128.0
		air_redeploy_bracket.pixel_size = (tile_width * 3.0) / 128.0
		
		if snap_pos != Vector3.ZERO:
			target_bracket.visible = false
			air_strike_bracket.visible = false
			air_redeploy_bracket.visible = false
			
			if show_air_strike:
				air_strike_bracket.position = snap_pos
				air_strike_bracket.look_at(Vector3.ZERO, Vector3.UP)
				air_strike_bracket.visible = true
			elif show_air_redeploy:
				air_redeploy_bracket.position = snap_pos
				air_redeploy_bracket.look_at(Vector3.ZERO, Vector3.UP)
				air_redeploy_bracket.visible = true
			else:
				target_bracket.position = snap_pos
				target_bracket.look_at(Vector3.ZERO, Vector3.UP)
				target_bracket.visible = true
	else:
		target_bracket.visible = false
		air_strike_bracket.visible = false
		air_redeploy_bracket.visible = false


	if is_deploying_foreign_aid:
		if result and result.collider == map_collider:
			var tile_id = _get_tile_from_vector3(result.position)
			var centroid = map_data.get_centroid(tile_id)
			var snap_pos = centroid.normalized() * (radius * 1.05)
			var c_name = city_tile_cache.get(tile_id, "")
			
			if snap_pos != Vector3.ZERO:
				var tile_width = 0.006
				var nbrs = map_data.get_neighbors(tile_id)
				if nbrs.size() > 0:
					var c1 = centroid.normalized()
					var c2 = map_data.get_centroid(nbrs[0]).normalized()
					tile_width = c1.distance_to(c2) * (radius * 1.02)
				
				if foreign_aid_bracket and foreign_aid_bracket.texture:
					var tex_width = float(foreign_aid_bracket.texture.get_width())
					foreign_aid_bracket.pixel_size = (tile_width * 3.0) / tex_width
					foreign_aid_bracket.position = snap_pos
					foreign_aid_bracket.look_at(Vector3.ZERO, Vector3.UP)
					
					var is_valid = false
					var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
					var local_faction = ""
					if NetworkManager.players.has(local_id):
						local_faction = NetworkManager.players[local_id].get("faction", "")
					if c_name != "" and local_faction != "":
						if active_scenario.has("factions") and active_scenario["factions"].has(local_faction):
							if not active_scenario["factions"][local_faction].get("cities", []).has(c_name) and active_scenario["factions"][local_faction].get("money", 0.0) >= 10.0:
								is_valid = true
					
					if is_valid:
						foreign_aid_bracket.material_override.albedo_color = Color(1.0, 1.0, 1.0)
					else:
						foreign_aid_bracket.material_override.albedo_color = Color(1.0, 0.0, 0.0)
					foreign_aid_bracket.visible = true
		elif foreign_aid_bracket:
			foreign_aid_bracket.visible = false

	if deploying_unit_type != "":
		# Handle the ghost positioning similarly but checking for valid city deployment
		if result and result.collider == map_collider:
			var tile_id = _get_tile_from_vector3(result.position)
			var centroid = map_data.get_centroid(tile_id)
			var snap_pos = centroid.normalized() * (radius * 1.05)
			var c_name = city_tile_cache.get(tile_id, "")
			
			if snap_pos != Vector3.ZERO:
				var tile_width = 0.006
				var nbrs = map_data.get_neighbors(tile_id)
				if nbrs.size() > 0:
					var c1 = centroid.normalized()
					var c2 = map_data.get_centroid(nbrs[0]).normalized()
					tile_width = c1.distance_to(c2) * (radius * 1.02)
				
				deployment_ghost.pixel_size = (tile_width * 3.0) / 34.0
				deployment_ghost.position = snap_pos
				deployment_ghost.look_at(Vector3.ZERO, Vector3.UP)
				
				# Determine validity for coloring
				var is_valid = false
				var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
				var local_faction = ""
				if NetworkManager.players.has(local_id):
					local_faction = NetworkManager.players[local_id].get("faction", "")
					
				if c_name != "" and local_faction != "":
					if active_scenario.has("factions") and active_scenario["factions"].has(local_faction):
						var fac_data = active_scenario["factions"][local_faction]
						var has_city = fac_data.has("cities") and fac_data["cities"].has(c_name)
						var has_money = fac_data.get("money", 0.0) >= deploying_unit_cost
						var on_cooldown = city_cooldowns.has(c_name)
						var is_full = _is_city_full(c_name)
						if has_city and has_money and not on_cooldown and not is_full:
							is_valid = true
							
				if is_valid:
					deployment_ghost.material_override.albedo_color = Color(1.0, 1.0, 1.0, 0.7) # White valid
				else:
					deployment_ghost.material_override.albedo_color = Color(1.0, 0.0, 0.0, 0.7) # Red invalid
					
		else:
			deployment_ghost.position = Vector3(0, 0, 0) # hide somewhat safely

func _update_terrain_hover(screen_pos: Vector2) -> void:
	var space_state = get_world_3d().direct_space_state
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_end = ray_origin + camera.project_ray_normal(screen_pos) * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == map_collider:
		var tile_id = _get_tile_from_vector3(result.position)
		var terrain = map_data.get_terrain(tile_id)
		var c_name = ""
		if city_tile_cache.has(tile_id):
			c_name = city_tile_cache[tile_id]
			
		var centroid = map_data.get_centroid(tile_id)
		var snap_pos = centroid.normalized() * (radius * 1.03) # slightly atop city (1.02)
		
		var tile_width = 0.006
		var nbrs = map_data.get_neighbors(tile_id)
		if nbrs.size() > 0:
			var c1 = centroid.normalized()
			var c2 = map_data.get_centroid(nbrs[0]).normalized()
			tile_width = c1.distance_to(c2) * (radius * 1.02)
			
		var region_name = map_data.get_region(tile_id)
		hovered_tile_changed.emit(tile_id, terrain, c_name, region_name)
	else:
		# Cursor over deep space
		hovered_tile_changed.emit(-1, "", "", "")

func _get_tile_from_vector3(pos: Vector3) -> int:
	# Convert a 3D coordinate point on the sphere back into the exact Face and XY coordinate it corresponds to on the underlying 361x361 matrices.
	var n = pos.normalized()
	
	# Determine principle axis (which face of the cube)
	var ax = abs(n.x)
	var ay = abs(n.y)
	var az = abs(n.z)
	
	var face = -1
	var max_axis = max(ax, max(ay, az))
	
	if max_axis == ax:
		face = 3 if n.x > 0 else 2 # RIGHT or LEFT
	elif max_axis == ay:
		face = 4 if n.y > 0 else 5 # TOP or BOTTOM
	else:
		face = 0 if n.z > 0 else 1 # FRONT or BACK
		
	# Un-project from sphere onto the cube plane
	var local_x = 0.0
	var local_y = 0.0
	
	# Reverse mapping from QuadSphereBaker's _get_sphere_point
	if face == 0: # FRONT: local_x, -local_y, 1.0
		local_x = n.x / n.z
		local_y = -n.y / n.z
	elif face == 1: # BACK: -local_x, -local_y, -1.0
		local_x = -n.x / -n.z
		local_y = -n.y / -n.z
	elif face == 2: # LEFT: -1.0, -local_y, local_x
		local_x = n.z / -n.x
		local_y = -n.y / -n.x
	elif face == 3: # RIGHT: 1.0, -local_y, -local_x
		local_x = -n.z / n.x
		local_y = -n.y / n.x
	elif face == 4: # TOP: local_x, 1.0, local_y
		local_x = n.x / n.y
		local_y = n.z / n.y
	elif face == 5: # BOTTOM: local_x, -1.0, -local_y
		local_x = n.x / -n.y
		local_y = -n.z / -n.y

	# Map cube coordinates [-1, 1] to discrete matrix indices [0, RESOLUTION-1]
	# RESOLUTION = 361
	var M = 361
	
	var x = clamp(int(((local_x + 1.0) / 2.0) * M), 0, M - 1)
	var y = clamp(int(((local_y + 1.0) / 2.0) * M), 0, M - 1)
	var face_names = ["FRONT", "BACK", "LEFT", "RIGHT", "TOP", "BOTTOM"]
	return map_data.get_id_from_coords(face_names[face], x, y)
	
func _lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var cos_lat = cos(lat)
	var ny = sin(lat)
	var nx = cos_lat * -sin(lon)
	var nz = cos_lat * -cos(lon)
	return Vector3(nx, ny, nz) * r

func _get_tile_width(tile_id: int) -> float:
	var tile_width = 0.006
	var centroid = map_data.get_centroid(tile_id)
	var nbrs = map_data.get_neighbors(tile_id)
	if nbrs.size() > 0 and centroid != Vector3.ZERO:
		var c1 = centroid.normalized()
		var c2 = map_data.get_centroid(nbrs[0]).normalized()
		tile_width = c1.distance_to(c2) * radius
	return tile_width

func _update_city_borders() -> void:
	if not active_scenario.has("factions"): return
	
	for city_node in city_nodes:
		var border = city_node.get_node_or_null("CityBorder")
		if border:
			var c_name = city_node.name
			var owner_fac = ""
			for fac_name in active_scenario["factions"].keys():
				if active_scenario["factions"][fac_name].get("cities", []).has(c_name):
					owner_fac = fac_name
					break
			
			if owner_fac != "":
				var fac_color = active_scenario["factions"][owner_fac].get("color", "#333333")
				border.modulate = Color(fac_color)
				border.visible = true
			else:
				border.visible = false

var _faction_borders_dirty: bool = false
func _generate_faction_borders() -> void:
	_update_city_borders()
	if not _faction_borders_dirty:
		_faction_borders_dirty = true
		call_deferred("_do_generate_faction_borders")

func _do_generate_faction_borders() -> void:
	_faction_borders_dirty = false
	print("GlobeView: Generating Dynamic Faction Borders...")
	outline_immediate_mesh.clear_surfaces()
	
	# Pre-cache city ownership to bypass O(N^2) 40k loop latency locks
	var city_to_owner = {}
	if active_scenario.has("factions"):
		for f_name in active_scenario["factions"]:
			var f_cities = active_scenario["factions"][f_name].get("cities", [])
			var c = Color(active_scenario["factions"][f_name].get("color", "#333333"))
			for city in f_cities:
				city_to_owner[city] = {"owner": f_name, "color": c}
				
	if active_scenario.has("countries"):
		for c_name in active_scenario["countries"]:
			var c_cities = active_scenario["countries"][c_name].get("cities", [])
			var c = Color(active_scenario["countries"][c_name].get("color", "#333333"))
			for city in c_cities:
				if not city_to_owner.has(city):
					city_to_owner[city] = {"owner": c_name, "color": c}
	
	# Track edges we've already drawn so we don't draw overlapping lines
	var drawn_edges = {}
	var edges_by_faction = {}
	var shading_edges_by_faction = {}

	
	for tile_id in map_data._region_map.keys():
		var owner_city = map_data._region_map[tile_id]
		var owning_faction = ""
		var faction_color = Color(0.2, 0.2, 0.2, 1.0)
		
		var cached = city_to_owner.get(owner_city, null)
		if cached:
			owning_faction = cached.owner
			faction_color = cached.color
					
		if owning_faction == "":
			continue # Neutral or un-configured cities don't get borders for now
			
		var neighbors = map_data.get_neighbors(tile_id)
		for n_id in neighbors:
			var n_owner = map_data.get_region(n_id)
			var n_faction = ""
			
			if n_owner != "":
				var n_cached = city_to_owner.get(n_owner, null)
				if n_cached:
					n_faction = n_cached.owner
							
			# We draw a line ONLY if the neighboring tile is owned by a different faction, 
			# or if it's unowned (wilderness), BUT NOT if it is water (ocean/lake).
			if n_faction != owning_faction:
				var n_terrain = map_data.get_terrain(n_id).to_lower()
				if n_terrain == "ocean" or n_terrain == "lake":
					continue
					
				var c1_list = _get_global_corners(tile_id)
				var c2_list = _get_global_corners(n_id)
				var shared_verts: Array[Vector3] = []
				
				for c1 in c1_list:
					for c2 in c2_list:
						if c1.distance_to(c2) < 0.001:
							shared_verts.append(c1)
							break
							
				if shared_verts.size() == 2:
					# Sort verts so A_B is same as B_A
					var v0 = shared_verts[0]
					var v1 = shared_verts[1]
					var key1 = "%.4f,%.4f,%.4f_%.4f,%.4f,%.4f" % [v0.x, v0.y, v0.z, v1.x, v1.y, v1.z]
					var key2 = "%.4f,%.4f,%.4f_%.4f,%.4f,%.4f" % [v1.x, v1.y, v1.z, v0.x, v0.y, v0.z]
					
					if not drawn_edges.has(key1) and not drawn_edges.has(key2):
						drawn_edges[key1] = true
						drawn_edges[key2] = true
						
						if not edges_by_faction.has(owning_faction):
							edges_by_faction[owning_faction] = []
						edges_by_faction[owning_faction].append([v0, v1])
						
					if not shading_edges_by_faction.has(owning_faction):
						shading_edges_by_faction[owning_faction] = []
					var tile_center = map_data.get_centroid(tile_id)
					shading_edges_by_faction[owning_faction].append([v0, v1, tile_center, tile_id])
						
	for faction_name in edges_by_faction.keys():
		var edge_list = edges_by_faction[faction_name]
		var col_str = ""
		if active_scenario.has("factions") and active_scenario["factions"].has(faction_name):
			col_str = active_scenario["factions"][faction_name].get("color", "#FFFFFF")
		elif active_scenario.has("countries") and active_scenario["countries"].has(faction_name):
			col_str = active_scenario["countries"][faction_name].get("color", "#708090")
		var faction_color = Color(col_str)
		# Dim the color by 50%
		faction_color = faction_color * 0.5
		faction_color.a = 1.0 # Ensure fully opaque
		
		# Elevated slightly to prevent z-fighting with the globe surface
		outline_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for edge in edge_list:
			var p1 = edge[0] * 1.002
			var p2 = edge[1] * 1.002
			var center = (p1 + p2) * 0.5
			var up = center.normalized()
			var fwd = (p2 - p1).normalized()
			if fwd.length() > 0.0001:
				var right = fwd.cross(up).normalized()
				var hw = 0.0006 # Thinner lines. Tile width ~0.006.
				
				var v1 = p1 - right * hw
				var v2 = p1 + right * hw
				var v3 = p2 + right * hw
				var v4 = p2 - right * hw
				
				outline_immediate_mesh.surface_set_color(faction_color)
				outline_immediate_mesh.surface_add_vertex(v1)
				outline_immediate_mesh.surface_set_color(faction_color)
				outline_immediate_mesh.surface_add_vertex(v2)
				outline_immediate_mesh.surface_set_color(faction_color)
				outline_immediate_mesh.surface_add_vertex(v3)
				
				outline_immediate_mesh.surface_set_color(faction_color)
				outline_immediate_mesh.surface_add_vertex(v1)
				outline_immediate_mesh.surface_set_color(faction_color)
				outline_immediate_mesh.surface_add_vertex(v3)
				outline_immediate_mesh.surface_set_color(faction_color)
				outline_immediate_mesh.surface_add_vertex(v4)
		outline_immediate_mesh.surface_end()
						
	for faction_name in shading_edges_by_faction.keys():
		var edge_list = shading_edges_by_faction[faction_name]
		var col_str = ""
		if active_scenario.has("factions") and active_scenario["factions"].has(faction_name):
			col_str = active_scenario["factions"][faction_name].get("color", "#FFFFFF")
		elif active_scenario.has("countries") and active_scenario["countries"].has(faction_name):
			col_str = active_scenario["countries"][faction_name].get("color", "#708090")
		var faction_color = Color(col_str)
		
		var outer_color = faction_color
		outer_color.a = 0.6
		var inner_color = faction_color
		inner_color.a = 0.0
		
		outline_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for edge in edge_list:
			var p1 = edge[0] * 1.002
			var p2 = edge[1] * 1.002
			var tile_center = edge[2] * 1.002
			var t_id = edge[3]
			
			var center = (p1 + p2) * 0.5
			var up = center.normalized()
			var fwd = (p2 - p1).normalized()
			if fwd.length() > 0.0001:
				var inward = (tile_center - center)
				var right = fwd.cross(up).normalized()
				if inward.dot(right) < 0:
					right = -right
					
				var tile_width = _get_tile_width(t_id)
				var unit_width = tile_width * 3.35
				var shade_width = unit_width * 0.5
				
				var v_inner1 = p1 + right * shade_width
				var v_inner2 = p2 + right * shade_width
				
				# First Triangle
				outline_immediate_mesh.surface_set_color(outer_color)
				outline_immediate_mesh.surface_add_vertex(p1)
				outline_immediate_mesh.surface_set_color(outer_color)
				outline_immediate_mesh.surface_add_vertex(p2)
				outline_immediate_mesh.surface_set_color(inner_color)
				outline_immediate_mesh.surface_add_vertex(v_inner2)
				
				# Second Triangle
				outline_immediate_mesh.surface_set_color(outer_color)
				outline_immediate_mesh.surface_add_vertex(p1)
				outline_immediate_mesh.surface_set_color(inner_color)
				outline_immediate_mesh.surface_add_vertex(v_inner2)
				outline_immediate_mesh.surface_set_color(inner_color)
				outline_immediate_mesh.surface_add_vertex(v_inner1)
				
		outline_immediate_mesh.surface_end()
						
	var total_factions = edges_by_faction.keys().size()
	print("GlobeView: Finished Faction Borders. Factions drawn: ", total_factions)
	for f in edges_by_faction.keys():
		print(" - Faction: ", f, " edges: ", edges_by_faction[f].size())

func _get_global_corners(tile_id: int) -> Array[Vector3]:
	var coords = map_data.get_coords_from_id(tile_id)
	var face = coords["face"]
	var x = coords["x"]
	var y = coords["y"]
	
	var RESOLUTION = 361
	var cx1 = (float(x) / RESOLUTION) * 2.0 - 1.0
	var cx2 = (float(x + 1) / RESOLUTION) * 2.0 - 1.0
	var cy1 = (float(y) / RESOLUTION) * 2.0 - 1.0
	var cy2 = (float(y + 1) / RESOLUTION) * 2.0 - 1.0
	
	var corners2d = [
	   Vector2(cx1, cy1),
	   Vector2(cx2, cy1),
	   Vector2(cx2, cy2),
	   Vector2(cx1, cy2)
	]
	
	var corners3d: Array[Vector3] = []
	for c in corners2d:
		var p = _get_sphere_point(face, c.x, c.y).normalized() * radius
		corners3d.append(p)
		
	return corners3d

func _get_sphere_point(face: int, local_x: float, local_y: float) -> Vector3:
	match face:
		0: return Vector3(local_x, -local_y, 1.0)
		1: return Vector3(-local_x, -local_y, -1.0)
		2: return Vector3(-1.0, -local_y, local_x)
		3: return Vector3(1.0, -local_y, -local_x)
		4: return Vector3(local_x, 1.0, local_y)
		5: return Vector3(local_x, -1.0, -local_y)
		_: return Vector3.ZERO

## Public function to sync this view from external changes (e.g. 2D map panning)
func set_focus(longitude: float, latitude: float) -> void:
	current_longitude = longitude
	current_latitude = latitude
	_update_camera()

func focus_on_city(city_name: String) -> void:
	if cached_city_data.has(city_name):
		var c_data = cached_city_data[city_name]
		if c_data.has("latitude") and c_data.has("longitude"):
			set_focus(deg_to_rad(c_data["longitude"]), deg_to_rad(c_data["latitude"]))

func _spawn_unit(unit_def: Dictionary, faction_name: String, c_dict: Dictionary, faction_regions: Dictionary) -> void:
	if unit_def.has("latitude") and unit_def.has("longitude"):
		var lat = unit_def["latitude"]
		var lon = unit_def["longitude"]
		var raw_pos = _lat_lon_to_vector3(deg_to_rad(lat), deg_to_rad(lon), radius)
		
		var tile_id = _get_tile_from_vector3(raw_pos)
		var tile_width = _get_tile_width(tile_id)
		
		var unit = GlobeUnitScript.new()
		if unit_def.has("type"):
			unit.unit_type = str(unit_def["type"]).capitalize()
			
		# Snap exactly to globe bounds for zero-parallax since shader uses no_depth_test
		unit.radius = radius
		add_child(unit)
		if faction_name != "":
			unit.faction_name = faction_name
			unit.is_friendly = (faction_name == _get_local_faction())
			var faction = _get_faction_data(faction_name)
			if faction.has("color"):
				unit.set_faction_color(faction["color"])
		unit.name = _get_standard_unit_name(unit.faction_name, unit.unit_type)
		
		if unit.has_method("set_sizing"):
			unit.set_sizing(tile_width)
			
		if unit_def.has("entrenched") and unit_def["entrenched"] == true:
			unit.entrenched = true
			unit.time_motionless = 30.0
			if unit.sprite and unit.sprite.material_override is ShaderMaterial:
				unit.sprite.material_override.set_shader_parameter("is_entrenched", true)
			
		unit.spawn(raw_pos)
		units_list.append(unit)
		cullable_nodes.append(unit)
		return

	if not unit_def.has("location"):
		return
		
	var loc = unit_def["location"]
	
	if loc == "border":
		var count = unit_def.get("count", 5)
		var keys = faction_regions.keys()
		# Find the faction dictionary from scenario_data
		var scenario_factions = map_data._region_map # Wait, we need the original scenario data. We don't have it passed here directly except faction_name.
		# For this prototype we can query the dictionary we passed in... wait, c_dict is just cities. 
		# We need to compute the color here.
		
		if keys.size() >= 2:
			# For this generic prototype, assume the border is between the first two loaded factions
			_spawn_border_units(count, keys[0], keys[1], faction_regions, faction_name)
		return
		
	if c_dict.has(loc):
		var lat = c_dict[loc].get("latitude")
		var lon = c_dict[loc].get("longitude")
		if lat != null and lon != null:
			var base_raw_pos = _lat_lon_to_vector3(deg_to_rad(lat), deg_to_rad(lon), radius)
			
			var tile_id = _get_tile_from_vector3(base_raw_pos)
			var tile_width = _get_tile_width(tile_id)
			
			var candidates = [tile_id]
			candidates.append_array(map_data.get_neighbors(tile_id))
			
			var final_raw_pos = base_raw_pos
			
			var unit_type_str = "Infantry"
			if unit_def.has("type"):
				unit_type_str = str(unit_def["type"]).capitalize()
				
			var is_sea_unit = (unit_type_str in ["Cruiser", "Submarine"])
			var is_land_unit = (unit_type_str == "Armor" or unit_type_str == "Infantry")

			var fallback_pos = base_raw_pos
			for candidate_id in candidates:
				var terrain = map_data.get_terrain(candidate_id)
				var is_water = (terrain == "OCEAN" or terrain == "LAKE")
				
				if is_sea_unit and not is_water:
					continue
				if is_land_unit and is_water:
					continue
					
				var centroid = map_data.get_centroid(candidate_id)
				if centroid.is_zero_approx():
					continue
				var candidate_pos = centroid.normalized() * radius
				
				# Ensure that if we are forced to stack, we at least stack on the correct terrain type
				if fallback_pos == base_raw_pos:
					fallback_pos = candidate_pos
					
				var is_occupied = false
				
				for existing_unit in units_list:
					if is_instance_valid(existing_unit) and existing_unit.position.distance_to(candidate_pos) < (tile_width * 0.5):
						is_occupied = true
						break
				
				if not is_occupied:
					final_raw_pos = candidate_pos
					break
					
			if final_raw_pos == base_raw_pos and fallback_pos != base_raw_pos:
				final_raw_pos = fallback_pos
			
			var unit = GlobeUnitScript.new()
			if unit_def.has("type"):
				unit.unit_type = str(unit_def["type"]).capitalize()
				
			unit.radius = radius
			add_child(unit)
			if faction_name != "":
				unit.faction_name = faction_name
				unit.is_friendly = (faction_name == _get_local_faction())
				var faction = _get_faction_data(faction_name)
				if faction.has("color"):
					unit.set_faction_color(faction["color"])
			unit.name = _get_standard_unit_name(unit.faction_name, unit.unit_type)
					
			if unit.has_method("set_sizing"):
				unit.set_sizing(tile_width)

			if unit_def.has("entrenched") and unit_def["entrenched"] == true:
				unit.entrenched = true
				unit.time_motionless = 30.0
				if unit.sprite and unit.sprite.material_override is ShaderMaterial:
					unit.sprite.material_override.set_shader_parameter("is_entrenched", true)
				
			unit.spawn(final_raw_pos)
			units_list.append(unit)
			cullable_nodes.append(unit) # GlobeUnit itself handles tracking/visibility or we use unit.sprite depending on logic
	elif map_data.get_centroid(loc) != Vector3.ZERO:
		var raw_pos = map_data.get_centroid(loc).normalized() * radius
		
		var tile_width = _get_tile_width(loc)
		
		var unit = GlobeUnitScript.new()
		if unit_def.has("type"):
			unit.unit_type = str(unit_def["type"]).capitalize()
			
		unit.radius = radius
		add_child(unit)
		if faction_name != "":
			unit.faction_name = faction_name
			unit.is_friendly = (faction_name == _get_local_faction())
			var faction = _get_faction_data(faction_name)
			if faction.has("color"):
				unit.set_faction_color(faction["color"])
		unit.name = _get_standard_unit_name(unit.faction_name, unit.unit_type)
				
		if unit.has_method("set_sizing"):
			unit.set_sizing(tile_width)
			
		if unit_def.has("entrenched") and unit_def["entrenched"] == true:
			unit.entrenched = true
			unit.time_motionless = 30.0
			if unit.sprite and unit.sprite.material_override is ShaderMaterial:
				unit.sprite.material_override.set_shader_parameter("is_entrenched", true)
			
		unit.spawn(raw_pos)
		units_list.append(unit)
		cullable_nodes.append(unit)

func _get_faction_data(faction_name: String) -> Dictionary:
	if active_scenario.has("factions"):
		if active_scenario["factions"].has(faction_name):
			return active_scenario["factions"][faction_name]
	return {}

func _get_local_faction() -> String:
	if NetworkManager and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var id = multiplayer.get_unique_id()
		if NetworkManager.players.has(id):
			return NetworkManager.players[id].get("faction", "")
	return ""

func start_nuke_targeting() -> void:
	if selected_unit:
		selected_unit.set_selected(false)
		selected_unit = null
	current_air_operation_mode = "NUKE"
	if has_method("_update_city_highlights"):
		call("_update_city_highlights", false)
	if target_bracket: target_bracket.visible = false
	if air_strike_bracket: air_strike_bracket.visible = true
	if air_redeploy_bracket: air_redeploy_bracket.visible = false
	if air_ops_immediate_mesh: air_ops_immediate_mesh.clear_surfaces()
	deploying_unit_type = ""
	if deployment_ghost: deployment_ghost.visible = false
	
	ConsoleManager.log_message("Nuclear Targeting Protocol Enabled. Select Target.")

func _spawn_border_units(count: int, faction1: String, faction2: String, faction_regions: Dictionary, owning_faction: String) -> void:
	var f1_regs = faction_regions[faction1]
	var f2_regs = faction_regions[faction2]
	
	var border_tiles = []
	var keys = map_data._region_map.keys()
	
	# Sweep the culled active map to find tiles owned by f1 that touch tiles owned by f2
	for tile_id in keys:
		var r = map_data._region_map[tile_id]
		if f1_regs.has(r):
			var neighbors = map_data.get_neighbors(tile_id)
			for n in neighbors:
				var nr = map_data.get_region(n)
				if f2_regs.has(nr):
					border_tiles.append(tile_id)
					break
					
	if border_tiles.is_empty():
		print("GlobeView: No border found between ", faction1, " and ", faction2)
		return
		
	var faction_data = _get_faction_data(owning_faction)
		
	# Spread the specified unit count out evenly along the computed border arc
	var step = max(1, int(border_tiles.size() / count))
	for i in range(count):
		var idx = (i * step) % border_tiles.size()
		var tid = border_tiles[idx]
		
		var raw_pos = map_data.get_centroid(tid).normalized() * radius
		var tile_width = _get_tile_width(tid)
		var unit = GlobeUnitScript.new()
		unit.radius = radius
		unit.faction_name = owning_faction
		unit.is_friendly = (owning_faction == _get_local_faction())
		unit.name = _get_standard_unit_name(unit.faction_name, unit.unit_type)
		add_child(unit)
		if faction_data.has("color"):
			unit.set_faction_color(faction_data["color"])
			
		if unit.has_method("set_sizing"):
			unit.set_sizing(tile_width)
			
		unit.spawn(raw_pos)
		units_list.append(unit)
		cullable_nodes.append(unit)

func _city_has_water(c_name: String) -> bool:
	if not cached_city_data.has(c_name):
		return false
		
	var city_data = cached_city_data[c_name]
	var lat = city_data.get("latitude")
	var lon = city_data.get("longitude")
	if lat == null or lon == null:
		return false
		
	var base_raw_pos = _lat_lon_to_vector3(deg_to_rad(lat), deg_to_rad(lon), radius)
	var tile_id = _get_tile_from_vector3(base_raw_pos)
	
	var candidates = [tile_id]
	candidates.append_array(map_data.get_neighbors(tile_id))
	
	for candidate_id in candidates:
		var terrain = map_data.get_terrain(candidate_id)
		if terrain == "OCEAN" or terrain == "LAKE":
			return true
			
	return false

func _is_city_full(c_name: String) -> bool:
	if not cached_city_data.has(c_name):
		return false
		
	var city_data = cached_city_data[c_name]
	var lat = city_data.get("latitude")
	var lon = city_data.get("longitude")
	if lat == null or lon == null:
		return false
		
	var base_raw_pos = _lat_lon_to_vector3(deg_to_rad(lat), deg_to_rad(lon), radius)
	var tile_id = _get_tile_from_vector3(base_raw_pos)
	var tile_width = _get_tile_width(tile_id)
	
	var candidates = [tile_id]
	candidates.append_array(map_data.get_neighbors(tile_id))
	
	var occupied_count = 0
	
	for candidate_id in candidates:
		var candidate_pos = map_data.get_centroid(candidate_id).normalized() * radius
		
		for existing_unit in units_list:
			if is_instance_valid(existing_unit) and existing_unit.position.distance_to(candidate_pos) < (tile_width * 0.5):
				occupied_count += 1
				break
				
	return occupied_count >= candidates.size()

func _draw_air_ops_radius(unit: Node3D, is_redeploy: bool = false) -> void:
	air_ops_immediate_mesh.clear_surfaces()
	var tile_id = _get_tile_from_vector3(unit.current_position)
	var tile_width = _get_tile_width(tile_id)
	
	# Icon width is tile_width * 3.0. Ops radius = 10 * icon width = 30.0 * tile_width
	var radius_dist = 30.0 * tile_width
	if is_redeploy:
		radius_dist *= 10.0
		
	var mat = air_ops_mesh_instance.material_override as StandardMaterial3D
	if mat:
		if is_redeploy:
			mat.albedo_color = Color(0.0, 1.0, 0.0, 0.5)
		else:
			mat.albedo_color = Color(1.0, 0.0, 0.0, 0.5)
			
	var unit_pos = unit.current_position.normalized() * (radius * 1.002)
	
	var up = unit_pos.normalized()
	var right = Vector3.UP.cross(up).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.FORWARD.cross(up).normalized()
	var forward = up.cross(right).normalized()
	
	var segments = 64
	var thickness = 0.003
	if is_redeploy:
		thickness = 0.006
		
	air_ops_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var pts_inner = []
	var pts_outer = []
	for i in range(segments + 1):
		var angle = (float(i) / segments) * TAU
		var offset_dir = (right * cos(angle) + forward * sin(angle))
		
		var in_offset = offset_dir * (radius_dist - thickness)
		var out_offset = offset_dir * (radius_dist + thickness)
		
		pts_inner.append((unit_pos + in_offset).normalized() * (radius * 1.002))
		pts_outer.append((unit_pos + out_offset).normalized() * (radius * 1.002))
		
	for i in range(segments):
		var i0 = i
		var i1 = i + 1
		
		air_ops_immediate_mesh.surface_add_vertex(pts_inner[i0])
		air_ops_immediate_mesh.surface_add_vertex(pts_outer[i0])
		air_ops_immediate_mesh.surface_add_vertex(pts_inner[i1])
		
		air_ops_immediate_mesh.surface_add_vertex(pts_inner[i1])
		air_ops_immediate_mesh.surface_add_vertex(pts_outer[i0])
		air_ops_immediate_mesh.surface_add_vertex(pts_outer[i1])
		
	air_ops_immediate_mesh.surface_end()

@rpc("any_peer", "call_local", "reliable")
func request_nuke_launch(target_pos: Vector3, launching_faction: String) -> void:
	var is_server = multiplayer.has_multiplayer_peer() and multiplayer.get_unique_id() == 1
	print("DEBUG [Server? ", is_server, "]: request_nuke_launch received for ", launching_faction)
	if not multiplayer.has_multiplayer_peer() or multiplayer.get_unique_id() == 1:
		var fac_data = active_scenario["factions"].get(launching_faction, {})
		print("DEBUG Server: Faction nukes inventory = ", fac_data.get("nukes", 0))
		if fac_data.get("nukes", 0) > 0:
			fac_data["nukes"] -= 1
			fac_data["nukes_launched"] = fac_data.get("nukes_launched", 0) + 1
			print("DEBUG Server: Inventory decremented. Broadcasting sync_nuke_launch to all peers.")
			rpc("sync_nuke_launch", target_pos, launching_faction)
			var main_node = get_node_or_null("/root/Main")
			if main_node and main_node.has_method("rpc"):
				main_node.rpc("sync_economy", active_scenario)
				
			# Apply global diplomatic penalty for nuke launch 
			# Varies randomly per country between 20 and 60
			if active_scenario.has("countries"):
				var penalties = {}
				for c_name in active_scenario["countries"].keys():
					penalties[c_name] = randf_range(20.0, 60.0)
				rpc("sync_global_diplomatic_penalty", launching_faction, penalties, "Nuke Detonation")
		else:
			print("DEBUG Server: NAUGHTY CLIENT! Nuke launch rejected. Inventory is 0.")

@rpc("authority", "call_local", "reliable")
func sync_nuke_launch(target_pos: Vector3, launching_faction: String) -> void:
	var peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	print("DEBUG [Peer ", peer_id, "]: sync_nuke_launch received.")
	
	var hint = _get_location_hint_string(target_pos)
	var alert_msg = "NUCLEAR LAUNCH DETECTED" + hint.to_upper()
	ConsoleManager.local_log_message("[outline_size=2][outline_color=#dddddd][color=red]" + alert_msg + "[/color][/outline_color][/outline_size]")
	
	var main_node = get_node_or_null("/root/Main")
	if main_node and main_node.has_method("post_news_event"):
		main_node.post_news_event(alert_msg, [])
	
	if nuke_alert_sfx and nuke_alert_sfx.stream:
		nuke_alert_sfx.play()
	
	# Wait for visual impact roughly 5 seconds (not exact visually, but mechanically delays destruction)
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(func(): _process_nuke_impact(target_pos))

func _process_nuke_impact(target_pos: Vector3) -> void:
	var hint = _get_location_hint_string(target_pos)
	var alert_msg = "NUCLEAR IMPACT CATASTROPHE" + hint.to_upper()
	ConsoleManager.local_log_message("[outline_size=2][outline_color=#dddddd][color=red]" + alert_msg + "[/color][/outline_color][/outline_size]")
	
	if nuke_impact_sfx and nuke_impact_sfx.stream:
		nuke_impact_sfx.play()
	
	var main_node = get_node_or_null("/root/Main")
	if main_node and main_node.has_method("post_news_event"):
		main_node.post_news_event(alert_msg, [])
	
	var hit_tile = _get_tile_from_vector3(target_pos)
	var nbrs = map_data.get_neighbors(hit_tile)
	var tile_width = 0.006 
	if nbrs.size() > 0:
		var c1 = map_data.get_centroid(hit_tile).normalized()
		var c2 = map_data.get_centroid(nbrs[0]).normalized()
		tile_width = c1.distance_to(c2) * (radius * 1.02)
		
	var unit_width = tile_width * 3.35 # Approximate relative sprite scale
	var inner_radius = unit_width * 1.35
	var outer_radius = unit_width * 2.25
	var surface_target = target_pos.normalized() * radius
	print("DEBUG: Blast center: ", surface_target, ", inner_radius: ", inner_radius, " outer: ", outer_radius)
	
	# Instantiate visual 3D fireball
	var sphere = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	sphere.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.0, 0.8) # Blinding Orange blast
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.0)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material_override = mat
	sphere.position = surface_target
	add_child(sphere)
	
	sphere.scale = Vector3.ZERO
	var twn = create_tween()
	# Expand drastically to inner radius
	twn.tween_property(sphere, "scale", Vector3(inner_radius, inner_radius, inner_radius), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Turn to ash cloud
	twn.tween_property(mat, "albedo_color", Color(0.2, 0.2, 0.2, 0.6), 1.0)
	twn.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, 1.0)
	# Slow dissipate and expand to outer damage radius over 8.5 seconds (10s total)
	twn.tween_property(sphere, "scale", Vector3(outer_radius, outer_radius, outer_radius), 8.5)
	twn.parallel().tween_property(mat, "albedo_color:a", 0.0, 8.5)
	twn.tween_callback(sphere.queue_free)
	
	if not multiplayer.has_multiplayer_peer() or NetworkManager.is_host:
		for u in units_list:
			if is_instance_valid(u) and not u.get("is_dead"):
				var dist = u.current_position.distance_to(surface_target)
				var dmg = 0.0
				if dist <= inner_radius:
					dmg = 9999.0
				elif dist <= outer_radius:
					if u.get("unit_type") != "Air":
						var fraction = (dist - inner_radius) / (outer_radius - inner_radius)
						dmg = lerp(90.0, 10.0, fraction)
				
				if dmg > 0.0:
					if multiplayer.has_multiplayer_peer():
						NetworkManager.rpc("sync_unit_damage", u.name, dmg, "Nuke Strike")
					else:
						u.take_damage(dmg, "Nuke Strike", true)
				
	# Terrain conversion
	var affected_tiles = [hit_tile]
	var q = [hit_tile]
	var visited = {hit_tile: true}
	
	for _i in range(15):
		var next_q = []
		for t in q:
			for n in map_data.get_neighbors(t):
				if not visited.has(n):
					visited[n] = true
					var t_pos = map_data.get_centroid(n).normalized() * radius
					if t_pos.distance_to(surface_target) <= inner_radius:
						affected_tiles.append(n)
						next_q.append(n)
		q = next_q
		
	var hit_city_factions = {}
	var penalized_cities = {}
	for t_id in affected_tiles:
		if city_tile_cache.has(t_id):
			var c_name = city_tile_cache[t_id]
			map_data.set_terrain(t_id, "RUINS")
			
			if not penalized_cities.has(c_name):
				penalized_cities[c_name] = true
				city_cooldowns[c_name] = city_cooldowns.get(c_name, 0.0) + 600.0
				var owner = _get_city_faction(c_name)
				if owner != "":
					hit_city_factions[owner] = hit_city_factions.get(owner, 0) + 1
		else:
			var current_terrain = map_data.get_terrain(t_id)
			if current_terrain != "OCEAN" and current_terrain != "LAKE":
				map_data.set_terrain(t_id, "WASTELAND")

	if not multiplayer.has_multiplayer_peer() or multiplayer.get_unique_id() == 1:
		var economy_changed = false
		for owner in hit_city_factions.keys():
			var penalty = hit_city_factions[owner] * 10.0
			active_scenario["factions"][owner]["money"] = max(0, active_scenario["factions"][owner].get("money", 0.0) - penalty)
			economy_changed = true
			
		if economy_changed:
			if main_node and main_node.has_method("rpc"):
				main_node.rpc("sync_economy", active_scenario)
			
	_rebuild_nuke_ash_layer()
	
func _rebuild_nuke_ash_layer() -> void:
	if not nuke_ash_mesh_instance:
		nuke_ash_mesh = ImmediateMesh.new()
		nuke_ash_mesh_instance = MeshInstance3D.new()
		nuke_ash_mesh_instance.mesh = nuke_ash_mesh
		var ash_mat = StandardMaterial3D.new()
		ash_mat.vertex_color_use_as_albedo = true
		ash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ash_mat.no_depth_test = true
		ash_mat.render_priority = 5 # Draw flat over terrain
		nuke_ash_mesh_instance.material_override = ash_mat
		add_child(nuke_ash_mesh_instance)

	nuke_ash_mesh.clear_surfaces()
	
	var has_ruins = false
	for t_id in map_data._terrain_overrides.keys():
		var ter = map_data._terrain_overrides[t_id]
		if (ter == "WASTELAND" or ter == "RUINS") and map_data.get_neighbors(t_id).size() == 4:
			has_ruins = true
			break
			
	if not has_ruins:
		return
		
	nuke_ash_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for t_id in map_data._terrain_overrides.keys():
		var ter = map_data._terrain_overrides[t_id]
		if ter == "WASTELAND" or ter == "RUINS":
			var nbrs = map_data.get_neighbors(t_id)
			if nbrs.size() != 4: continue
			
			var center = map_data.get_centroid(t_id).normalized() * (radius * 1.002)
			var n_pos = []
			var n_ruined = []
			for n in nbrs:
				n_pos.append(map_data.get_centroid(n).normalized() * (radius * 1.002))
				var n_ter = map_data.get_terrain(n)
				n_ruined.append(n_ter == "WASTELAND" or n_ter == "RUINS")
				
			var c_pos = []
			var c_alpha = []
			for i in range(4):
				var next_i = (i+1)%4
				c_pos.append((center + n_pos[i] + n_pos[next_i]).normalized() * (radius * 1.002))
				if n_ruined[i] and n_ruined[next_i]:
					c_alpha.append(0.95)
				else:
					c_alpha.append(0.0)
					
			var center_alpha = 0.95
			for i in range(4):
				var next_i = (i+1)%4
				
				nuke_ash_mesh.surface_set_color(Color(0.05, 0.05, 0.05, center_alpha))
				nuke_ash_mesh.surface_add_vertex(center)
				
				nuke_ash_mesh.surface_set_color(Color(0.05, 0.05, 0.05, c_alpha[i]))
				nuke_ash_mesh.surface_add_vertex(c_pos[i])
				
				nuke_ash_mesh.surface_set_color(Color(0.05, 0.05, 0.05, c_alpha[next_i]))
				nuke_ash_mesh.surface_add_vertex(c_pos[next_i])

	nuke_ash_mesh.surface_end()

func _get_location_hint_string(target_pos: Vector3) -> String:
	var hit_tile = _get_tile_from_vector3(target_pos)
	if city_tile_cache.has(hit_tile):
		return " over " + city_tile_cache[hit_tile]
	var region = map_data.get_region(hit_tile)
	if region != "":
		return " in " + region
	return ""

func _get_city_faction(city_name: String) -> String:
	if active_scenario.has("factions"):
		for f_name in active_scenario["factions"].keys():
			if active_scenario["factions"][f_name].has("cities") and city_name in active_scenario["factions"][f_name]["cities"]:
				return f_name
	return ""

func _play_air_mission_animation(start_pos: Vector3, end_pos: Vector3, is_strategic: bool, target_hit: bool, shot_down: bool, faction_color: Color = Color.WHITE, duration_override: float = -1.0) -> void:
	var anim_script = load("res://src/scripts/map/AirMissionAnimation.gd")
	if anim_script:
		var anim_node = anim_script.new()
		add_child(anim_node)
		var r = 1.0
		if "radius" in self: r = self.get("radius")
		anim_node.init_animation(start_pos, end_pos, is_strategic, target_hit, shot_down, faction_color, r, duration_override)
