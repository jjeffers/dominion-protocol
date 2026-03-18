extends GutTest

var GlobeViewScene = preload("res://src/scenes/map/GlobeView.tscn")
var GlobeUnitPath = "res://src/scripts/map/GlobeUnit.gd"

var mock_view
var u1

func before_all():
	MapData.use_mock_data = true
	GlobeView.skip_mesh_generation = true

func after_all():
	MapData.use_mock_data = false
	GlobeView.skip_mesh_generation = false

func before_each():
	mock_view = GlobeViewScene.instantiate()
	
	u1 = load(GlobeUnitPath).new()
	u1.current_position = Vector3(1, 0, 0)
	
	add_child_autofree(mock_view)
	mock_view.add_child(u1)
	
	# Mock the multiplayer network manager to allow _get_local_faction() functionality
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var local_id = multiplayer.get_unique_id()
	NetworkManager.players[local_id] = {"faction": "Blue"}

func after_each():
	var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if local_id != 0 and NetworkManager.players.has(local_id):
		NetworkManager.players.erase(local_id)
	multiplayer.multiplayer_peer = null

func test_enemy_unit_order_rejected():
	u1.faction_name = "Red"
	
	# Act: Select Red unit, as Blue player
	mock_view.selected_unit = u1
	mock_view.target_bracket = Sprite3D.new()
	mock_view.add_child(mock_view.target_bracket)
	mock_view.target_bracket.visible = true
	
	# Issue right click (false = right click)
	mock_view._handle_click(Vector2.ZERO, false)
		
	# Assert: It rejected the order and deselected the unit early
	assert_null(mock_view.selected_unit, "Enemy unit should be deselected automatically")
	assert_false(mock_view.target_bracket.visible, "Target bracket should be hidden")

func test_friendly_unit_order_allowed():
	# Change unit to Blue
	u1.faction_name = "Blue"
	
	mock_view.selected_unit = u1
	mock_view.target_bracket = Sprite3D.new()
	mock_view.add_child(mock_view.target_bracket)
	mock_view.target_bracket.visible = true
	
	# Issue right click (false = right click)
	mock_view._handle_click(Vector2.ZERO, false)
	
	# Assert: It did not reject the order and left the unit selected
	assert_not_null(mock_view.selected_unit, "Friendly unit should remain selected to process the order")
