extends SceneTree
func _init():
    var resolved = IP.resolve_hostname("google.com", IP.TYPE_IPV4)
    print("Resolved google.com: ", resolved)
    var peer = ENetMultiplayerPeer.new()
    var err = peer.create_client("google.com", 4444)
    print("create_client google.com error: ", err)
    var err2 = peer.create_client(resolved, 4444)
    print("create_client resolved error: ", err2)
    quit()
