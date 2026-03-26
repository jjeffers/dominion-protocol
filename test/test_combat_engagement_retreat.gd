extends GutTest

var GlobeUnitPath = "res://src/scripts/map/GlobeUnit.gd"

var mock_view
var u1
var u2

func before_each():
	var gv_scene = load("res://src/scenes/map/GlobeView.tscn")
	mock_view = gv_scene.instantiate()
	add_child(mock_view)
	
	u1 = GlobeUnit.new()
	u1.name = "Unit1"
	u1.faction_name = "Blue"
	u1.current_position = Vector3(1, 0, 0)
	u1.target_position = Vector3(1, 0, 0)
	u1.health = 100.0
	u1.unit_type = "Infantry"
	add_child(u1)
	
	u2 = GlobeUnit.new()
	u2.name = "Unit2"
	u2.faction_name = "Red"
	u2.current_position = Vector3(0.992, 0, 0)
	u2.target_position = Vector3(0.992, 0, 0)
	u2.health = 100.0
	u2.unit_type = "Infantry"
	add_child(u2)
	
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	NetworkManager.is_host = true

func after_each():
	u1.queue_free()
	u2.queue_free()
	mock_view.queue_free()

func test_combat_damage_loop():
	u1.set_combat_target(u2)
	u2.set_combat_target(u1)
	
	# Simulate 10 seconds of combat
	for i in range(100):
		u1._process(0.1)
		u2._process(0.1)
		
	# Both should have taken damage
	print("TEST LOG: After 100 ticks. u1.health: ", u1.health, " u2.health: ", u2.health)
	assert_lt(u1.health, 100.0)
	assert_lt(u2.health, 100.0)
	
	# Emulate low health AI retreat
	u1.health = 29.0
	u1.target_position = Vector3(0, 1, 0) # Run away
	
	# Simulate another 10 seconds
	var old_health_u2 = u2.health
	for i in range(100):
		u1._process(0.1)
		u2._process(0.1)
		
	print("TEST LOG: After retreat 100 ticks. u1.health: ", u1.health, " u2.health: ", u2.health)
	assert_lt(u2.health, old_health_u2, "U1 should STILL be damaging U2 while retreating or stuck!")
