extends GutTest
const CountryNameGenerator = preload("res://src/scripts/map/CountryNameGenerator.gd")

func test_empty_cities():
	var name = CountryNameGenerator.generate_name([])
	assert_eq(name, "Unknown Territory", "Should return Unknown Territory for empty cities array")

func test_single_city():
	var cities: Array[String] = ["London"]
	var name = CountryNameGenerator.generate_name(cities, 123)
	assert_true(name.length() > 0, "Name string should be generated")
	assert_true("London" in name or "Europa" in name, "Capital or region name should be included")

func test_multiple_cities():
	var cities: Array[String] = ["New York", "Chicago", "Boston"]
	for i in range(10):
		var name = CountryNameGenerator.generate_name(cities, i)
		assert_true(name.length() > 0, "Name string should be generated")
		# Mostly should contain base text, New York, etc.

func test_different_regions():
	var cities_america: Array[String] = ["New York", "Boston"]
	var cities_asia: Array[String] = ["Tokyo", "Seoul"]
	var cities_africa: Array[String] = ["Nairobi", "Cape Town"]
	
	var res_america = CountryNameGenerator.generate_name(cities_america, 42)
	var res_asia = CountryNameGenerator.generate_name(cities_asia, 43)
	var res_africa = CountryNameGenerator.generate_name(cities_africa, 45)

	# As tests just need to ensure no crashing and names generated
	assert_ne(res_america, res_asia, "Different random seeds and regions should produce different results")
	assert_ne(res_america, "", "Should return a non-empty name")
	assert_ne(res_asia, "", "Should return a non-empty name")
	
func test_same_seed_produces_same_output():
	var cities: Array[String] = ["Paris", "Berlin", "Munich"]
	var name1 = CountryNameGenerator.generate_name(cities, 999)
	var name2 = CountryNameGenerator.generate_name(cities, 999)
	assert_eq(name1, name2, "Same seed and same cities should produce the exact same text result")
