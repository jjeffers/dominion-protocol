extends SceneTree

func _init():
    var config_path = "user://test_network_settings.cfg"
    var config = ConfigFile.new()
    config.set_value("Network", "last_ip", "10.0.0.1")
    config.set_value("Network", "last_port", "12345")
    var err = config.save(config_path)
    if err != OK:
        print("FAIL: Should save test config file")
        quit(1)
        return

    var load_config = ConfigFile.new()
    var err2 = load_config.load(config_path)
    if err2 != OK:
        print("FAIL: Should load test config file")
        quit(1)
        return

    var ip = load_config.get_value("Network", "last_ip")
    var port = load_config.get_value("Network", "last_port")

    if ip != "10.0.0.1":
        print("FAIL: Expected IP 10.0.0.1, got ", ip)
        quit(1)
        return

    if port != "12345":
        print("FAIL: Expected Port 12345, got ", port)
        quit(1)
        return

    DirAccess.remove_absolute(config_path)
    print("PASS: Config file saved and loaded correctly.")
    quit(0)
