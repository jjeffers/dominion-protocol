class_name CountryNameGenerator
extends RefCounted

## Generates plausible-sounding Country names based on constituent cities and geography.

const CITIES_PATH = "res://src/data/city_data.json"
static var _city_data: Dictionary = {}
static var _initialized: bool = false

static var political_titles = [
	"Republic", "Federation", "Empire", "Union", "Coalition",
	"Directorate", "Syndicate", "Dominion", "Pact", "Alliance", "State",
	"Commonwealth"
]

static func _init_data() -> void:
	if _initialized:
		return
	if FileAccess.file_exists(CITIES_PATH):
		var f = FileAccess.open(CITIES_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(f.get_as_text()) == OK:
			_city_data = json.data
	else:
		push_error("CountryNameGenerator: Could not find city data at " + CITIES_PATH)
	_initialized = true

static func generate_name(cities: Array[String], seed_value: int = 0) -> String:
	_init_data()
	
	if cities.is_empty():
		return "Unknown Territory"
	
	var rng = RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	
	var total_lat = 0.0
	var total_lon = 0.0
	var valid_cities = 0
	
	var capital = cities[rng.randi() % cities.size()]
	
	for city in cities:
		if _city_data.has(city):
			total_lat += float(_city_data[city]["latitude"])
			total_lon += float(_city_data[city]["longitude"])
			valid_cities += 1
			
	var centroid_lat = 0.0
	var centroid_lon = 0.0
	
	if valid_cities > 0:
		centroid_lat = total_lat / valid_cities
		centroid_lon = total_lon / valid_cities
	else:
		if _city_data.has(capital):
			centroid_lat = float(_city_data[capital]["latitude"])
			centroid_lon = float(_city_data[capital]["longitude"])
			
	var prefix = ""
	var region_base = ""
			
	if centroid_lon < -30:
		if centroid_lat > 15:
			region_base = "Americana"
		else:
			region_base = "Latina"
	elif centroid_lon >= -30 and centroid_lon <= 50:
		if centroid_lat >= 35:
			region_base = "Europa"
		elif centroid_lat >= -35:
			region_base = "African"
		else:
			region_base = "Southern"
	else:
		if centroid_lat >= 10:
			region_base = "Pan-Asian"
		else:
			region_base = "Pacifica"
			
	if centroid_lat > 50:
		prefix = "Northern"
	elif centroid_lat < -45:
		prefix = "Southern"
	elif centroid_lat > -15 and centroid_lat < 15:
		prefix = "Equatorial"
	elif centroid_lon > 100 or (centroid_lon < -30 and centroid_lon > -90):
		prefix = "Eastern"
	elif centroid_lon < -90 or (centroid_lon > -30 and centroid_lon < 20):
		prefix = "Western"
		
	var title = political_titles[rng.randi() % political_titles.size()]
	
	# Fallbacks
	if region_base == "":
		region_base = "Global"
	
	var format_choice = rng.randi() % 5
	
	match format_choice:
		0:
			if prefix != "":
				return prefix + " " + region_base + " " + title
			else:
				return "The " + region_base + " " + title
		1:
			return title + " of " + capital
		2:
			return capital + " " + title
		3:
			return "United " + region_base + " " + title
		4:
			if cities.size() >= 2:
				var capital2 = cities[rng.randi() % cities.size()]
				while capital2 == capital:
					capital2 = cities[rng.randi() % cities.size()]
				return capital + "-" + capital2 + " " + title
			else:
				return "Greater " + capital + " " + title

	return "The " + capital + " " + title
