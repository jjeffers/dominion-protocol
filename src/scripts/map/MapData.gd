class_name MapData
extends RefCounted

## Represents the canonical DGGS 2D Uniform Grid data.
## The map wraps horizontally (longitude) but is bounded vertically (latitude).

enum TerrainType {
	PLAINS,
	WOODS,
	MOUNTAINS,
	OCEAN,
	LAKES
}

var grid_width: int
var grid_height: int

## 1D array representing the 2D grid.
## Indexed by (y * grid_width + x)
var _grid: Array[TerrainType]

func _init(width: int, height: int) -> void:
	grid_width = width
	grid_height = height
	_grid.resize(grid_width * grid_height)
	_grid.fill(TerrainType.OCEAN)

## Gets the appropriate wrapped X coordinate
func wrap_x(x: int) -> int:
	@warning_ignore("integer_division")
	return posmod(x, grid_width)

## Validates if the Y coordinate is within bounds (poles)
func is_valid_y(y: int) -> bool:
	return y >= 0 and y < grid_height

## Converts 2D (x, y) coordinates to 1D array index
func _get_index(x: int, y: int) -> int:
	return y * grid_width + wrap_x(x)

## Gets the terrain at the given grid coordinates
func get_terrain(x: int, y: int) -> TerrainType:
	if not is_valid_y(y):
		push_warning("Attempted to get terrain out of Y bounds: ", y)
		return TerrainType.OCEAN
	
	return _grid[_get_index(x, y)]

## Sets the terrain at the given grid coordinates
func set_terrain(x: int, y: int, terrain: TerrainType) -> void:
	if not is_valid_y(y):
		push_warning("Attempted to set terrain out of Y bounds: ", y)
		return
	
	_grid[_get_index(x, y)] = terrain

## Fills the entire grid with a specific terrain
func fill(terrain: TerrainType) -> void:
	_grid.fill(terrain)

## Loads the map grid from a grayscale heightmap image
func load_from_image(image_path: String) -> bool:
	var image = Image.new()
	var err = image.load(image_path)
	if err != OK:
		push_error("Failed to load map image: ", image_path)
		return false
		
	grid_width = image.get_width()
	grid_height = image.get_height()
	_grid.resize(grid_width * grid_height)
	
	for y in range(grid_height):
		for x in range(grid_width):
			var color = image.get_pixel(x, y)
			var brightness = color.v # Value in HSV, represents lightness since it's grayscale
			
			var terrain: TerrainType = TerrainType.OCEAN
			
			if brightness < 0.35:
				# Dark grey is ocean
				terrain = TerrainType.OCEAN
			elif brightness < 0.45:
				# Slightly higher might be coastal plains or lowlands
				terrain = TerrainType.PLAINS
			elif brightness < 0.65:
				# Mid greys - woods
				terrain = TerrainType.WOODS
			else:
				# Light greys to white - mountains
				terrain = TerrainType.MOUNTAINS
				
			set_terrain(x, y, terrain)
			
	return true

## Generates a temporary blob-like terrain layout for testing
func generate_prototype_continents() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	
	fill(TerrainType.OCEAN)
	
	# Drop some continent seeds
	var num_continents = 5
	for _c in range(num_continents):
		var cx = rng.randi_range(0, grid_width - 1)
		# Keep away from absolute poles
		var cy = rng.randi_range(int(grid_height * 0.2), int(grid_height * 0.8))
		var radius = rng.randi_range(5, 12)
		
		_draw_blob(cx, cy, radius, TerrainType.PLAINS, rng)
		
		# Add some mountains in the middle
		_draw_blob(cx, cy, radius / 2, TerrainType.MOUNTAINS, rng)
		
		# And some woods offset
		var wx = cx + rng.randi_range(-3, 3)
		var wy = cy + rng.randi_range(-3, 3)
		_draw_blob(wrap_x(wx), wy, radius / 3, TerrainType.WOODS, rng)


func _draw_blob(cx: int, cy: int, radius: int, terrain: TerrainType, rng: RandomNumberGenerator) -> void:
	for y in range(cy - radius, cy + radius + 1):
		if not is_valid_y(y):
			continue
			
		for x in range(cx - radius, cx + radius + 1):
			var wrapped_x = wrap_x(x)
			
			# Rough circular distance check with some noise
			var dist_sq = (x - cx) * (x - cx) + (y - cy) * (y - cy)
			var max_dist_sq = radius * radius
			
			if dist_sq <= max_dist_sq:
				# Add noise to edges
				if dist_sq > max_dist_sq * 0.6 and rng.randf() > 0.5:
					continue
				set_terrain(wrapped_x, y, terrain)
