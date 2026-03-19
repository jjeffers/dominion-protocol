extends GutTest

var globe_view_scene = preload("res://src/scenes/map/GlobeView.tscn")
var globe_unit_script = preload("res://src/scripts/map/GlobeUnit.gd")

func before_all():
	MapData.use_mock_data = true
	GlobeView.skip_mesh_generation = true

func after_all():
	MapData.use_mock_data = false
	GlobeView.skip_mesh_generation = false

class MockPlainsMapData extends MapData:
	func get_terrain(tile: int) -> String:
		return "PLAINS"
	func get_region(tile: int) -> String:
		return "WILDERNESS"

func test_air_strike_damage():
	var gv = globe_view_scene.instantiate()
	add_child_autofree(gv)
	gv.map_data = MockPlainsMapData.new()
	
	var attacker = globe_unit_script.new()
	var target = globe_unit_script.new()
	gv.add_child(attacker)
	gv.add_child(target)
	gv.units_list.append(attacker)
	gv.units_list.append(target)
	
	attacker.unit_type = "Air"
	target.unit_type = "Infantry"
	target.health = 100.0
	attacker.name = "Air1"
	target.name = "Inf1"
	
	attacker.set("is_air_ready", true)
	
	gv._on_air_strike_synced("Air1", "Inf1", "", "UNREADY", "", true)
	
	# Plains terrain gives Infantry a 1.0x damage penalty. 50 * 1.0 = 50 damage.
	assert_eq(target.health, 50.0, "Air strike should do 50% of target health (100 -> 50 with 1.0x modifier)")
	assert_false(attacker.get("is_air_ready"), "Attacker should become UNREADY")
	
func test_air_strike_sea_damage():
	var gv = globe_view_scene.instantiate()
	add_child_autofree(gv)
	
	var attacker = globe_unit_script.new()
	var target = globe_unit_script.new()
	gv.add_child(attacker)
	gv.add_child(target)
	gv.units_list.append(attacker)
	gv.units_list.append(target)
	
	attacker.unit_type = "Air"
	target.unit_type = "Sea"
	target.health = 80.0
	attacker.name = "Air1"
	target.name = "Sea1"
	
	attacker.set("is_air_ready", true)
	
	gv._on_air_strike_synced("Air1", "Sea1", "", "UNREADY", "", true)
	
	# Ocean terrain gives Infantry(Sea fallback) a 1.5x damage penalty. 35 * 1.5 = 52.5 damage.
	assert_eq(target.health, 27.5, "Air strike on Sea should do exactly 35 flat damage (80 -> 27.5 with 1.5x modifier)")

func test_air_redeploy():
	var gv = globe_view_scene.instantiate()
	add_child_autofree(gv)
	
	var attacker = globe_unit_script.new()
	gv.add_child(attacker)
	gv.units_list.append(attacker)
	
	attacker.unit_type = "Air"
	attacker.name = "Air1"
	attacker.set("is_air_ready", true)
	
	var start_pos = attacker.current_position
	
	gv.cached_city_data = {
		"London": {"latitude": 51.5, "longitude": -0.1}
	}
	
	gv._on_air_redeploy_synced("Air1", "London")
	
	assert_ne(attacker.current_position, start_pos, "Air unit should have moved to London")
	assert_false(attacker.get("is_air_ready"), "Redeployed air unit should be UNREADY")
	
func test_air_strike_countered():
	var gv = globe_view_scene.instantiate()
	add_child_autofree(gv)
	
	var attacker = globe_unit_script.new()
	var target = globe_unit_script.new()
	var counter = globe_unit_script.new()
	gv.add_child(attacker)
	gv.add_child(target)
	gv.add_child(counter)
	gv.units_list.append(attacker)
	gv.units_list.append(target)
	gv.units_list.append(counter)
	
	attacker.unit_type = "Air"
	target.unit_type = "Infantry"
	counter.unit_type = "Air"
	
	attacker.name = "AirAttacker"
	target.name = "Target"
	counter.name = "AirCounter"
	
	target.health = 100.0
	
	attacker.set("is_air_ready", true)
	counter.set("is_air_ready", true)
	
	gv._on_air_strike_synced("AirAttacker", "Target", "AirCounter", "UNREADY", "UNREADY", false)
	
	assert_eq(target.health, 100.0, "Target health should be untouched if countered")
	assert_false(attacker.get("is_air_ready"), "Attacker should be UNREADY")
	assert_false(counter.get("is_air_ready"), "Countering unit should be UNREADY")

class MockOceanMapData extends MapData:
	func get_terrain(tile: int) -> String:
		return "OCEAN"
	func get_region(tile: int) -> String:
		return "WILDERNESS"

func test_air_strike_sea_transport_damage():
	var gv = globe_view_scene.instantiate()
	add_child_autofree(gv)
	
	# Override map_data to force OCEAN evaluation
	gv.map_data = MockOceanMapData.new()
	
	var attacker = globe_unit_script.new()
	var target = globe_unit_script.new()
	gv.add_child(attacker)
	gv.add_child(target)
	gv.units_list.append(attacker)
	gv.units_list.append(target)
	
	attacker.unit_type = "Air"
	target.unit_type = "Armor"
	target.health = 100.0
	attacker.name = "Air1"
	target.name = "Trans1"
	
	# Move target somewhere
	target.current_position = Vector3(1, 0, 0)
	
	attacker.set("is_air_ready", true)
	
	gv._on_air_strike_synced("Air1", "Trans1", "", "UNREADY", "", true)
	
	# Armor takes 0.5 damage from Air normally.
	# The test expects 35 flat damage base.
	# GlobeUnit `take_damage(amount)` does: health -= amount * terrain_modifier.
	# Armor takes 1.5x damage in Ocean.
	# So 35 * 1.5 = 52.5. 100 - 52.5 = 47.5.
	assert_eq(target.health, 47.5, "Air strike on Sea Transport land unit should do exactly 35 flat base damage, yielding 52.5 total damage")
