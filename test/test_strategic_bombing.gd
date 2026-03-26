extends GutTest

var globe_view_scene = preload("res://src/scenes/map/GlobeView.tscn")
var globe_unit_script = preload("res://src/scripts/map/GlobeUnit.gd")
var GlobeView = preload("res://src/scripts/map/GlobeView.gd")



func test_strategic_bombing_success():
	var gv = globe_view_scene.instantiate()
	add_child_autofree(gv)
	
	# Mock active scenario
	gv.set("active_scenario", {
		"factions": {
			"Blue": {"cities": {"London": 1}, "money": 100.0},
			"Red": {"cities": {"Berlin": 1}, "money": 100.0}
		}
	})
	
	var attacker = globe_unit_script.new()
	gv.add_child(attacker)
	gv.units_list.append(attacker)
	
	attacker.unit_type = "Air"
	attacker.name = "Air1"
	attacker.set("faction_name", "Blue")
	attacker.set("is_air_ready", true)
	
	# Execute strategic bombing sync (successfully bypassed interception)
	gv._on_strategic_bombing_synced("Air1", "Berlin", "", "UNREADY", "", true)
	
	# Red should lose 10 credits
	var red_money = gv.get("active_scenario")["factions"]["Red"]["money"]
	assert_eq(red_money, 90.0, "Target faction should lose 10 credits after successful bombing")
	
	# Air unit should become UNREADY
	assert_false(attacker.get("is_air_ready"), "Attacking air unit should become UNREADY")
	
	# Berlin should gain 120s cooldown
	assert_true(gv.city_cooldowns.has("Berlin"), "Berlin should be put on cooldown")
	assert_eq(gv.city_cooldowns["Berlin"], 120.0, "City cooldown should be exactly 120 seconds")

func test_strategic_bombing_aborted():
	var gv = globe_view_scene.instantiate()
	add_child_autofree(gv)
	
	gv.set("active_scenario", {
		"factions": {
			"Blue": {"cities": {"London": 1}, "money": 100.0},
			"Red": {"cities": {"Berlin": 1}, "money": 100.0}
		}
	})
	
	var attacker = globe_unit_script.new()
	var interceptor = globe_unit_script.new()
	gv.add_child(attacker)
	gv.add_child(interceptor)
	gv.units_list.append(attacker)
	gv.units_list.append(interceptor)
	
	attacker.unit_type = "Air"
	attacker.name = "Air1"
	attacker.set("faction_name", "Blue")
	attacker.set("is_air_ready", true)
	
	interceptor.unit_type = "Air"
	interceptor.name = "Air2"
	interceptor.set("faction_name", "Red")
	interceptor.set("is_air_ready", true)
	
	# Aborted due to interception
	gv._on_strategic_bombing_synced("Air1", "Berlin", "Air2", "UNREADY", "UNREADY", false)
	
	var red_money = gv.get("active_scenario")["factions"]["Red"]["money"]
	assert_eq(red_money, 100.0, "Red should NOT lose credits when aborted")
	assert_false(attacker.get("is_air_ready"), "Attacking air unit should become UNREADY")
	assert_false(interceptor.get("is_air_ready"), "Intercepting air unit should become UNREADY")
	assert_false(gv.city_cooldowns.has("Berlin"), "City should NOT get cooldown on aborted run")

func test_strategic_bombing_destroyed():
	var gv = globe_view_scene.instantiate()
	add_child_autofree(gv)
	
	gv.set("active_scenario", {
		"factions": {
			"Blue": {"cities": {"London": 1}, "money": 100.0},
			"Red": {"cities": {"Berlin": 1}, "money": 100.0}
		}
	})
	
	var attacker = globe_unit_script.new()
	var interceptor = globe_unit_script.new()
	gv.add_child(attacker)
	gv.add_child(interceptor)
	gv.units_list.append(attacker)
	gv.units_list.append(interceptor)
	
	attacker.unit_type = "Air"
	attacker.name = "Air1"
	attacker.set("faction_name", "Blue")
	attacker.set("is_air_ready", true)
	attacker.health = 100.0
	
	interceptor.unit_type = "Air"
	interceptor.name = "Air2"
	interceptor.set("faction_name", "Red")
	interceptor.set("is_air_ready", true)
	
	gv._on_strategic_bombing_synced("Air1", "Berlin", "Air2", "DESTROYED", "UNREADY", false)
	
	var red_money = gv.get("active_scenario")["factions"]["Red"]["money"]
	assert_eq(red_money, 100.0, "Red should NOT lose credits when shot down")
	assert_true(attacker.is_dead or attacker.health <= 0.0, "Attacking air unit should be DESTROYED (health drops or dies)")
	assert_false(interceptor.get("is_air_ready"), "Intercepting air unit should become UNREADY")
