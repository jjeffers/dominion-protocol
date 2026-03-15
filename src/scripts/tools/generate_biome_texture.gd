extends SceneTree

const OUT_PATH = "res://src/assets/biome_map.png"
const WIDTH = 4096
const HEIGHT = 2048

func _init():
	print("--- Generating Biome Map Texture ---")
	
	var topo_img = Image.new()
	topo_img.load("res://src/assets/Topography.jpg")
	var topo_w = topo_img.get_width()
	var topo_h = topo_img.get_height()
	
	var mask_img = Image.new()
	mask_img.load("res://src/assets/etopo-landmask.png")
	var mask_w = mask_img.get_width()
	var mask_h = mask_img.get_height()
	
	var ndvi_img = Image.new()
	ndvi_img.load("res://src/assets/NDVI_84.bw.png")
	var ndvi_w = ndvi_img.get_width()
	var ndvi_h = ndvi_img.get_height()
	
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = 12345
	noise.frequency = 2.0
	
	var out_img = Image.create_empty(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	
	print("Processing ", WIDTH, "x", HEIGHT, " pixels...")
	var start_time = Time.get_ticks_msec()
	
	for y in range(HEIGHT):
		var v_north = float(y) / float(HEIGHT)
		var lat = ((1.0 - v_north) * PI) - (PI / 2.0)
		
		for x in range(WIDTH):
			var u_base = float(x) / float(WIDTH)
			var lon = (1.0 - u_base) * 2.0 * PI - PI
			var centroid = Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			
			var terrain_data = _sample_terrain_2d(u_base, v_north, lat, centroid, topo_img, topo_w, topo_h, mask_img, mask_w, mask_h, ndvi_img, ndvi_w, ndvi_h, noise)
			var color = _get_terrain_debug_color(terrain_data[0], terrain_data[1])
			
			# Strip alpha channel for the flat map, we don't want transparency in the albedo
			color.a = 1.0
			out_img.set_pixel(x, y, color)
			
		if y > 0 and y % 500 == 0:
			print("Row ", y, " / ", HEIGHT, "...")
			
	out_img.save_png(OUT_PATH)
	
	var end_time = Time.get_ticks_msec()
	print("Saved Biome Map to: ", OUT_PATH, " in ", (end_time - start_time) / 1000.0, " seconds.")
	quit(0)

func _sample_terrain_2d(u_base: float, v_north: float, lat: float, centroid: Vector3, img: Image, img_w: int, img_h: int, mask: Image, mask_w: int, mask_h: int, ndvi: Image, ndvi_w: int, ndvi_h: int, noise: FastNoiseLite) -> Array:
	var mask_px = clamp(int(u_base * mask_w), 0, mask_w - 1)
	var mask_py = clamp(int(v_north * mask_h), 0, mask_h - 1)
	var is_land = mask.get_pixel(mask_px, mask_py).v > 0.5
	
	if not is_land:
		return ["OCEAN", 0.0]
	
	var px = clamp(int(u_base * img_w), 0, img_w - 1)
	var py = clamp(int(v_north * img_h), 0, img_h - 1)
	var topo_color = img.get_pixel(px, py)
	var elevation = topo_color.v
	
	if elevation >= 0.75: 
		return ["MOUNTAINS", 0.0]
		
	var ndvi_px = clamp(int(u_base * ndvi_w), 0, ndvi_w - 1)
	var ndvi_py = clamp(int(v_north * ndvi_h), 0, ndvi_h - 1)
	var veg = ndvi.get_pixel(ndvi_px, ndvi_py).v
	
	if veg < 0.35: 
		if abs(lat) > 1.0: return ["POLAR", veg]
		return ["DESERT", veg]
	if veg < 0.8: return ["PLAINS", veg]
	
	var fuzzy_lat = abs(lat) + noise.get_noise_3dv(centroid) * 0.15
	if fuzzy_lat < 0.4: return ["JUNGLE", veg]
	return ["FOREST", veg]

func _get_terrain_debug_color(terrain: String, veg: float) -> Color:
	match terrain:
		"OCEAN": return Color("1e90ff") # Dodger Blue
		"POLAR": return Color("f0f8ff") # Alice Blue
		"DESERT": return Color(0.902, 0.8, 0.0, 1.0)
		"PLAINS": 
			var t = clamp((veg - 0.35) / 0.45, 0.0, 1.0)
			return Color("90ee90").lerp(Color("32cd32"), t) # Light green to Lime green gradient
		"FOREST": return Color("228b22") # Forest Green
		"JUNGLE": return Color("006400") # Dark Green
		"MOUNTAINS": return Color("808080") # Gray
		_: return Color.MAGENTA
