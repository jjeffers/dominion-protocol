extends SceneTree
func _init():
    print("Is IP? ", "127.0.0.1".is_valid_ip_address())
    print("Is IP? ", "udp.pinggy.io".is_valid_ip_address())
    print("Error code: ", ERR_CANT_RESOLVE)
    quit()
