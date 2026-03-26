extends GutTest

var TacticalAIPath = "res://src/scripts/ai/TacticalAI.gd"
var GlobeUnitPath = "res://src/scripts/map/GlobeUnit.gd"

var ai
var mock_main
var mock_globe
var mock_nm

func before_each():
	var peer = OfflineMultiplayerPeer.new()
	get_tree().get_multiplayer().multiplayer_peer = peer
	ai = preload("res://src/scripts/ai/TacticalAI.gd").new()
	
	mock_main = Node.new()
	var mock_main_script = GDScript.new()
	mock_main_script.source_code = "extends Node\nvar scenario_data = {}"
	mock_main_script.reload()
	mock_main.set_script(mock_main_script)
	mock_main.name = "Main"
	var scenario_data = {
		"factions": {
			"Red": {
				"money": 100.0,
				"cities": ["Unit_City_A", "Unit_City_B"]
			}
		}
	}
	mock_main.scenario_data = scenario_data
	get_tree().root.add_child(mock_main)
	
	var mock_globe_script = GDScript.new()
	mock_globe_script.source_code = "extends Node3D\nvar units_list = []\nvar city_cooldowns = {}\nvar city_nodes = []\nvar radius = 1.0\nvar active_scenario = {\"countries\":{}}\nfunc _get_city_faction(city_name: String) -> String:\n\tif city_name == 'Unit_City_A' or city_name == 'Unit_City_B': return 'Red'\n\tif city_name == 'Unit_City_Enemy': return 'Blue'\n\treturn 'neutral'\n@rpc('authority', 'call_local', 'reliable')\nfunc sync_unit_purchase(c,t,f,cost):\n\tpass\n"

	mock_globe_script.reload()
	mock_globe = Node3D.new()
	mock_globe.set_script(mock_globe_script)
	mock_globe.name = "GlobeView"
	
	var city_a = Node3D.new()
	city_a.name = "Unit_City_A"
	mock_globe.add_child(city_a)
	city_a.global_position = Vector3(1, 0, 0)
	
	var city_b = Node3D.new()
	city_b.name = "Unit_City_B"
	mock_globe.add_child(city_b)
	city_b.global_position = Vector3(0, 1, 0)
	
	var enemy_city = Node3D.new()
	enemy_city.name = "Unit_City_Enemy"
	mock_globe.add_child(enemy_city)
	enemy_city.global_position = Vector3(0, 0, 1)
	
	mock_globe.city_nodes = [city_a, city_b, enemy_city]
	mock_globe.radius = 1.0
	get_tree().root.add_child(mock_globe)
	
	var mock_nm_script = GDScript.new()
	mock_nm_script.source_code = """extends Node
var is_host = true
var last_strike_target = ''
var last_redeploy_target = ''
var last_bombing_target = ''
var players = {1: {"name": "TestPlayer", "faction": "Red"}}


@rpc('any_peer')
func sync_unit_target(a, b, c=''):
	pass

@rpc('any_peer', 'call_local')
func request_air_strike(unit, enemy):
	last_strike_target = enemy

@rpc('any_peer', 'call_local')
func request_strategic_bombing(unit, city):
	last_bombing_target = city

@rpc('any_peer', 'call_local')
func request_air_redeploy(unit, city):
	last_redeploy_target = city
"""
	var err = mock_nm_script.reload()
	if err != OK:
		push_error("MOCK NM SCRIPT FAILED TO COMPILE")
	mock_nm = Node.new()
	mock_nm.set_script(mock_nm_script)
	mock_nm.name = "NetworkManager"
	get_tree().root.add_child(mock_nm)
	
	add_child(ai)
	ai.set_faction("Red", 0.5, 1)
	ai.network_manager = mock_nm
	ai.globe_view = mock_globe

func after_each():
	ai.queue_free()
	mock_main.queue_free()
	mock_globe.queue_free()
	mock_nm.queue_free()

func test_initial_state_and_transition():
	assert_eq(ai.current_state, ai.AIState.PRODUCING, "AI should start in PRODUCING state")
	
func test_production_transitions_to_rallying():
	# Manually bypass the wait time
	ai.current_state = ai.AIState.PRODUCING
	ai._evaluate_state()
	# Without units, it stays in PRODUCING
	assert_eq(ai.current_state, ai.AIState.PRODUCING, "Should stay in PRODUCING if no units exist")
	
	# Add a unit to mock_globe
	var unit_scr = GDScript.new()
	unit_scr.source_code = "extends Node3D\nvar faction_name = 'Red'\nvar is_dead = false\nvar is_engaged = false\nvar sprite = {\"visible\": true}"
	unit_scr.reload()
	var u1 = Node3D.new()
	u1.set_script(unit_scr)
	mock_globe.add_child(u1)
	mock_globe.units_list.append(u1)
	
	ai._evaluate_state()
	# Now it should transition to RALLYING because owned_units.size() > 0
	assert_eq(ai.current_state, ai.AIState.RALLYING, "Should transition to RALLYING when a unit is produced")
	u1.free()

func test_rallying_transitions_to_attacking():
	ai.current_state = ai.AIState.RALLYING
	
	var unit_scr = GDScript.new()
	unit_scr.source_code = "extends Node3D\nvar faction_name = 'Red'\nvar is_dead = false\nvar is_engaged = false\nvar sprite = {\"visible\": true}"
	unit_scr.reload()
	
	var u1 = Node3D.new()
	u1.set_script(unit_scr)
	mock_globe.add_child(u1)
	u1.global_position = Vector3(1,0,0)
	
	var u2 = Node3D.new()
	u2.set_script(unit_scr)
	mock_globe.add_child(u2)
	u2.global_position = Vector3(1,0,0)
	
	var u3 = Node3D.new()
	u3.set_script(unit_scr)
	mock_globe.add_child(u3)
	u3.global_position = Vector3(1,0,0)
	
	mock_globe.units_list.append(u1)
	mock_globe.units_list.append(u2)
	mock_globe.units_list.append(u3)
	
	ai._evaluate_state()
	
	assert_eq(ai.current_state, ai.AIState.ATTACKING, "Should transition to ATTACKING with 3+ units")
	
	u1.free()
	u2.free()
	u3.free()

func test_air_operations():
	# Test Air Strike
	var air_scr = GDScript.new()
	air_scr.source_code = "extends Node3D\nvar faction_name = 'Red'\nvar is_dead = false\nvar unit_type = 'Air'\nvar is_air_ready = true\nvar sprite = {\"visible\": true}"
	air_scr.reload()
	
	var u1 = Node3D.new()
	u1.set_script(air_scr)
	u1.name = "Unit_Air_1"
	mock_globe.add_child(u1)
	u1.global_position = Vector3(1, 0, 0)
	
	var enemy_scr = GDScript.new()
	enemy_scr.source_code = "extends Node3D\nvar faction_name = 'Blue'\nvar is_dead = false\nvar sprite = {\"visible\": true}"
	enemy_scr.reload()
	
	var enemy = Node3D.new()
	enemy.set_script(enemy_scr)
	enemy.name = "Unit_Infantry_Enemy"
	mock_globe.add_child(enemy)
	# Place enemy within 0.165 distance
	enemy.global_position = Vector3(1, 0.1, 0) 
	
	mock_globe.units_list.append(u1)
	mock_globe.units_list.append(enemy)
	
	ai.current_state = ai.AIState.ATTACKING
	ai._evaluate_state()
	
	assert_eq(mock_nm.last_strike_target, "Unit_Infantry_Enemy", "AI should have requested an airstrike on the enemy")
	
	# Test Redeploy
	mock_nm.last_strike_target = "" # reset
	u1.global_position = Vector3(0, 1, 0) # Move air unit far away (near Unit_City_B)
	# Target city is enemy_city at (0, 0, 1)
	# City A is at (1, 0, 0). Move it closer to front lines.
	mock_globe.city_nodes[0].global_position = Vector3(0, 0.2, 0.8) 
	
	enemy.global_position = Vector3(0, 0, 1) # Move enemy out of strike range of (0,1,0)
	
	ai._evaluate_state()
	
	assert_eq(mock_nm.last_redeploy_target, "Unit_City_A", "AI should have redeployed closer to the front lines")
	
	u1.free()
	enemy.free()

func test_ai_logs_production_to_console():
	var cm = get_node_or_null("/root/ConsoleManager")
	if cm and cm.output_log:
		cm.output_log.clear()
		
	ai.current_state = ai.AIState.PRODUCING
	ai.target_purchase = ""
	mock_main.scenario_data["factions"]["Red"]["money"] = 0.0 # Force no purchase, just log evaluation
	ai._handle_production() # Call production manually
	
	assert_true("AI Command: Authorizing funds for" in cm.output_log.get_parsed_text() if cm else "", "Logged message should reflect target purchase decision.")

func test_ai_cannot_target_invisible_infantry():
	# Red is the AI faction, Blue is the enemy
	var unit_scr = GDScript.new()
	unit_scr.source_code = "extends Node3D\nvar faction_name = 'Red'\nvar unit_type = 'Infantry'\nvar is_dead = false\nvar is_engaged = false"
	unit_scr.reload()
	
	var red_inf = Node3D.new()
	red_inf.set_script(unit_scr)
	red_inf.name = "RedInf"
	mock_globe.add_child(red_inf)
	mock_globe.units_list.append(red_inf)
	
	var enemy_scr = GDScript.new()
	enemy_scr.source_code = "extends Node3D\nvar faction_name = 'Blue'\nvar unit_type = 'Infantry'\nvar is_dead = false\nvar is_engaged = false"
	enemy_scr.reload()
	
	var blue_inf = Node3D.new()
	blue_inf.set_script(enemy_scr)
	blue_inf.name = "BlueInf"
	mock_globe.add_child(blue_inf)
	mock_globe.units_list.append(blue_inf)
	
	# Place Red infantry and Red cities far away from Blue infantry
	red_inf.global_position = Vector3(0, 1, 0) # Near City B (0, 1, 0)
	blue_inf.global_position = Vector3(0, -1, 0) # Bottom of globe
	
	# Also ensure all Red cities are far away (City A is at 1,0,0, City B is at 0,1,0)
	ai._refresh_owned_units()
	
	var target = ai._get_closest_enemy(red_inf)
	assert_null(target, "AI MUST NOT target an enemy Infantry if it is outside vision range.")
	
	# Move Blue infantry within vision range (0.036) of Red infantry
	blue_inf.global_position = Vector3(0, 0.98, 0)
	
	ai._refresh_owned_units()
	
	target = ai._get_closest_enemy(red_inf)
	assert_true(target != null, "AI MUST target the enemy Infantry when it moves inside vision range.")
	if target:
		assert_eq(target.name, "BlueInf", "Target should be the Blue Infantry.")
		
	red_inf.free()
	blue_inf.free()

func test_airstrike_ignores_air_targets():
	# Ensure Air Strike specifically avoids Air targets
	var air_scr = GDScript.new()
	air_scr.source_code = "extends Node3D\nvar faction_name = 'Red'\nvar is_dead = false\nvar unit_type = 'Air'\nvar is_air_ready = true\nvar sprite = {\"visible\": true}"
	air_scr.reload()
	
	var u1 = Node3D.new()
	u1.set_script(air_scr)
	u1.name = "Unit_Air_1"
	mock_globe.add_child(u1)
	u1.global_position = Vector3(1, 0, 0)
	
	var enemy_scr = GDScript.new()
	enemy_scr.source_code = "extends Node3D\nvar faction_name = 'Blue'\nvar is_dead = false\nvar unit_type = 'Air'\nvar sprite = {\"visible\": true}"
	enemy_scr.reload()
	
	var enemy = Node3D.new()
	enemy.set_script(enemy_scr)
	enemy.name = "Unit_Air_Enemy"
	mock_globe.add_child(enemy)
	
	# Place enemy extremely close (within strike radius)
	enemy.global_position = Vector3(1, 0.1, 0) 
	
	mock_globe.units_list.append(u1)
	mock_globe.units_list.append(enemy)
	
	mock_nm.last_strike_target = "" # Clear previous artifacts if any
	
	ai.current_state = ai.AIState.ATTACKING
	ai._evaluate_state()
	
	assert_eq(mock_nm.last_strike_target, "", "AI must NOT request an airstrike against an enemy Air unit.")
	
	u1.free()
	enemy.free()

func test_strategic_bombing_targets_enemy_cities():
	var air_scr = GDScript.new()
	air_scr.source_code = "extends Node3D\nvar faction_name = 'Red'\nvar is_dead = false\nvar unit_type = 'Air'\nvar is_air_ready = true\nvar sprite = {\"visible\": true}"
	air_scr.reload()
	
	var u1 = Node3D.new()
	u1.set_script(air_scr)
	u1.name = "Unit_Air_1"
	mock_globe.add_child(u1)
	u1.global_position = Vector3(1, 0, 0)
	
	# Make sure `Unit_City_Enemy` is within strike_radius (0.165) of Unit_Air_1
	var original_city_pos = mock_globe.city_nodes[2].global_position
	mock_globe.city_nodes[2].global_position = Vector3(1, 0.1, 0) # City is 'Blue'
	
	mock_globe.units_list.append(u1)
	
	mock_nm.last_bombing_target = ""
	
	ai.current_state = ai.AIState.ATTACKING
	ai._evaluate_state()
	
	assert_eq(mock_nm.last_bombing_target, "Unit_City_Enemy", "AI must request a strategic bombing against an enemy city within radius when no units are present.")
	
	# Reset state
	mock_globe.city_nodes[2].global_position = original_city_pos
	u1.free()



