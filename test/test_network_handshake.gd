extends GutTest

var network_manager = null

func before_each():
	network_manager = get_node("/root/NetworkManager")
	assert_not_null(network_manager, "NetworkManager Singleton should exist")

func test_reject_connection_sets_reason():
	network_manager.last_disconnect_reason = ""
	var mock_reason = "Version Mismatch. Host: v9.9.9 | You: v0.0.1"
	
	# Simulate the RPC arriving at the client
	network_manager.reject_connection(mock_reason)
	
	assert_eq(network_manager.last_disconnect_reason, mock_reason, "The client should store the host's rejection reason in memory to display on the MainMenu")

func test_game_version_is_valid():
	var ver = network_manager.GAME_VERSION
	assert_true(ver.length() > 0, "GAME_VERSION must not be empty")
	assert_true(ver.begins_with("v"), "GAME_VERSION should follow the v* format")



