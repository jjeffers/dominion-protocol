extends GutTest

var GlobeViewPath = "res://src/scripts/map/GlobeView.gd"
var mock_globe

func before_each():
	var peer = OfflineMultiplayerPeer.new()
	get_tree().get_multiplayer().multiplayer_peer = peer
	
	var mock_globe_script = load(GlobeViewPath)
	mock_globe = mock_globe_script.new()
	mock_globe.name = "GlobeView"
	
	mock_globe.active_scenario = {
		"factions": {
			"Red": {
				"money": 100.0,
				"cities": ["City_A", "City_F"]
			},
			"Blue": {
				"money": 100.0,
				"cities": ["City_E"]
			}
		},
		"neutral_cities": ["City_B", "City_C", "City_D"],
		"countries": {
			"TargetCountry1": {
				"cities": ["City_B", "City_C"],
				"opinions": {"Red": 0.0}
			},
			"TargetCountry2": {
				"cities": ["City_D"],
				"opinions": {"Red": 0.0}
			},
			"EnemyAlliedCountry": {
				"cities": ["City_E"],
				"opinions": {"Blue": 80.0}
			},
			"FriendlyAlliedCountry": {
				"cities": ["City_F"],
				"opinions": {"Red": 80.0}
			}
		}
	}
	get_tree().root.add_child(mock_globe)

func after_each():
	get_tree().get_multiplayer().multiplayer_peer = null
	if is_instance_valid(mock_globe):
		mock_globe.queue_free()

func test_request_foreign_aid_charges_cost():
	var initial_money = mock_globe.active_scenario["factions"]["Red"]["money"]
	mock_globe.request_foreign_aid("TargetCountry1", "Red")
	
	var final_money = mock_globe.active_scenario["factions"]["Red"]["money"]
	assert_eq(final_money, initial_money - 10.0, "Requesting Foreign Aid should charge 10 credits")

func test_sync_foreign_aid_neutral_two_cities():
	mock_globe.sync_foreign_aid("TargetCountry1", "Red")
	var new_op = mock_globe.active_scenario["countries"]["TargetCountry1"]["opinions"]["Red"]
	assert_eq(new_op, 50.0, "A neutral country with 2 cities should grant +50 opinion to purchasing faction")

func test_sync_foreign_aid_neutral_one_city():
	mock_globe.sync_foreign_aid("TargetCountry2", "Red")
	var new_op = mock_globe.active_scenario["countries"]["TargetCountry2"]["opinions"]["Red"]
	assert_eq(new_op, 100.0, "A neutral country with 1 city should grant +100 opinion to purchasing faction")

func test_sync_foreign_aid_enemy_allied_country():
	var initial_blue = mock_globe.active_scenario["countries"]["EnemyAlliedCountry"]["opinions"]["Blue"]
	mock_globe.sync_foreign_aid("EnemyAlliedCountry", "Red")
	
	var final_blue = mock_globe.active_scenario["countries"]["EnemyAlliedCountry"]["opinions"]["Blue"]
	assert_eq(final_blue, max(0.0, initial_blue - 100.0), "Purchasing aid for a Blue country as Red should reduce Blue's opinion")
	# Assert Red didn't magically get opinion
	var final_red = mock_globe.active_scenario["countries"]["EnemyAlliedCountry"]["opinions"].get("Red", 0.0)
	assert_eq(final_red, 0.0, "Red's opinion should stay 0 while Blue's drops")

func test_sync_foreign_aid_friendly_allied_country():
	var initial_red = mock_globe.active_scenario["countries"]["FriendlyAlliedCountry"]["opinions"]["Red"]
	mock_globe.sync_foreign_aid("FriendlyAlliedCountry", "Red")
	
	var final_red = mock_globe.active_scenario["countries"]["FriendlyAlliedCountry"]["opinions"]["Red"]
	assert_eq(final_red, min(100.0, initial_red + 100.0), "Purchasing aid for a Red country as Red should increase Red's opinion")

func test_request_foreign_aid_fails_no_funds():
	mock_globe.active_scenario["factions"]["Red"]["money"] = 5.0
	mock_globe.request_foreign_aid("TargetCountry1", "Red")
	
	var final_money = mock_globe.active_scenario["factions"]["Red"]["money"]
	assert_eq(final_money, 5.0, "Should not charge money if funds are insufficient")
	# Opinion should remain unchanged since sync never fired
	var op = mock_globe.active_scenario["countries"]["TargetCountry1"]["opinions"]["Red"]
	assert_eq(op, 0.0, "Opinion should not change if purchase failed due to lack of funds")



