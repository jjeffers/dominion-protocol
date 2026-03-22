extends SceneTree

const CountryNameGenerator = preload("res://src/scripts/map/CountryNameGenerator.gd")

func _init() -> void:
	print("--- Generating Random Countries ---")
	
	CountryNameGenerator._init_data()
	var all_cities = CountryNameGenerator._city_data.keys()
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(20):
		# Pick 1 to 5 random cities to form a country
		var num_cities = (rng.randi() % 5) + 1
		var country_cities: Array[String] = []
		
		for j in range(num_cities):
			var iter_city = all_cities[rng.randi() % all_cities.size()]
			if not country_cities.has(iter_city):
				country_cities.append(iter_city)
				
		var name = CountryNameGenerator.generate_name(country_cities)
		var cities_str = ", ".join(country_cities)
		print("- Name: ", name)
		print("  Territory includes: ", cities_str)
		print("")

	quit(0)
