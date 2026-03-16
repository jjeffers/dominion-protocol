extends GutTest

func test_config_save_load():
var config_path = "user://test_network_settings.cfg"
var config = ConfigFile.new()

config.set_value("Network", "last_ip", "10.0.0.1")
config.set_value("Network", "last_port", "12345")
var err = config.save(config_path)
assert_eq(err, OK, "Should save test config file")

var load_config = ConfigFile.new()
var err2 = load_config.load(config_path)
assert_eq(err2, OK, "Should load test config file")

var ip = load_config.get_value("Network", "last_ip")
var port = load_config.get_value("Network", "last_port")

assert_eq(ip, "10.0.0.1", "Should load correct IP")
assert_eq(port, "12345", "Should load correct Port")

DirAccess.remove_absolute(config_path)
