class_name MainScene
extends Control


@onready var globe_view = $GlobeContainer/SubViewport/GlobeView

@onready var terrain_panel: Panel = $TerrainSummaryPanel
@onready var terrain_color: ColorRect = $TerrainSummaryPanel/TerrainColor
@onready var terrain_name: Label = $TerrainSummaryPanel/TerrainNameLabel
@onready var city_name: Label = $TerrainSummaryPanel/CityNameLabel

@onready var economy_panel: Panel = $EconomyStatusPanel
@onready var credits_label: Label = $EconomyStatusPanel/CreditsLabel
@onready var cities_label: Label = $EconomyStatusPanel/CitiesLabel

var city_icon: TextureRect
var map_data: MapData

var economy_timer: float = 0.0
const ECONOMY_INTERVAL: float = 60.0

var capture_banner: Label
var banner_timer: float = 0.0
var victory_banner: Label

const TERRAIN_COLORS: Dictionary = {
	"OCEAN": Color("#1f679c"),
	"PLAINS": Color("#477a2d"),
	"FOREST": Color("#2d4c1e"),
	"DESERT": Color("#e6c27a"),
	"MOUNTAIN": Color("#8c8c8c"),
	"POLAR": Color("#ffffff")
}

func _ready() -> void:
	# 1. Initialize Canonical Data
	map_data = MapData.new()
	
	# Parse Scenario
	_load_scenario()
	
	# Update Economy UI
	_update_economy_ui()
	
	# 2. Inject Data into Views
	globe_view.map_data = map_data
	
	# 3. Connect focus synchronization signals
	globe_view.hovered_tile_changed.connect(_on_globe_hovered_tile_changed)
	globe_view.city_captured.connect(_on_city_captured)
	globe_view.victory_declared.connect(_on_victory_declared)
	
	# Trigger initial generation and sync
	globe_view._generate_mesh()
	globe_view._update_camera()
	
	# Ensure GlobeView explicitly relies on the scenario definitions to draw features
	globe_view._instantiate_scenario(scenario_data)
	
	# Initialize HUD State
	terrain_panel.hide()
	
	var city_texture = AtlasTexture.new()
	var img = load("res://src/assets/spritesheet.png")
	city_texture.atlas = img
	city_texture.region = Rect2(0, 480, 32, 32)
	
	city_icon = TextureRect.new()
	city_icon.texture = city_texture
	city_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	city_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	city_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	city_icon.hide()
	terrain_color.add_child(city_icon)
	
	# Setup Capture Banner
	capture_banner = Label.new()
	capture_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	capture_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capture_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	capture_banner.add_theme_font_size_override("font_size", 48)
	capture_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	capture_banner.add_theme_constant_override("outline_size", 8)
	capture_banner.position.y = 120
	capture_banner.hide()
	add_child(capture_banner)

	# Setup Victory Banner
	victory_banner = Label.new()
	victory_banner.set_anchors_preset(Control.PRESET_CENTER)
	victory_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory_banner.add_theme_font_size_override("font_size", 96)
	victory_banner.add_theme_color_override("font_color", Color.YELLOW)
	victory_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	victory_banner.add_theme_constant_override("outline_size", 12)
	victory_banner.hide()
	add_child(victory_banner)

func _on_globe_hovered_tile_changed(tile_id: String, terrain: String, c_name: String, region_name: String) -> void:
	if tile_id == "":
		terrain_panel.hide()
		return
		
	terrain_panel.show()
	
	if c_name != "":
		city_name.text = c_name
		city_name.show()
		
		# Show city icon and hide underlying terrain color
		terrain_name.text = "CITY"
		if region_name != "":
			terrain_name.text += " (" + region_name + ")"
		city_icon.show()
		terrain_color.self_modulate = Color(1, 1, 1, 0)
	else:
		city_name.hide()
		
		# Show underlying terrain
		var t_name = terrain
		if region_name != "":
			t_name += " (" + region_name + ")"
		terrain_name.text = t_name
		city_icon.hide()
		terrain_color.self_modulate = Color.WHITE
		
		if TERRAIN_COLORS.has(terrain):
			terrain_color.color = TERRAIN_COLORS[terrain]
		else:
			terrain_color.color = Color.BLACK

	pass

var scenario_data: Dictionary = {}
var active_cities: Array[String] = []
var active_regions: Array[String] = []

func _load_scenario() -> void:
	var path = "res://src/data/scenarios/initial_test.json"
	if not FileAccess.file_exists(path):
		push_error("MainScene: Could not find scenario file at ", path)
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		scenario_data = json.data
	else:
		push_error("MainScene: Failed to parse scenario JSON")
		return
		
	# Build active city list
	if scenario_data.has("factions"):
		for faction in scenario_data["factions"].values():
			if faction.has("cities"):
				for city in faction["cities"]:
					active_cities.append(city)
					
	if scenario_data.has("neutral_cities"):
		for city in scenario_data["neutral_cities"]:
			active_cities.append(city)
			
	# We rely on GlobeView or MapData to discover the active regions from these cities and cull the rest.
	# GlobeView handles projection, so we delay region culling until GlobeView processes it over in `_instantiate_scenario`.

func _on_city_captured(city_name: String, new_faction: String, old_faction: String) -> void:
	print(">>> CITY DOMAINS UPDATED: ", city_name, " is now under control of ", new_faction)
	capture_banner.text = "%s CAPTURES %s!" % [new_faction.to_upper(), city_name.replace("Unit_City_", "").to_upper()]
	capture_banner.modulate.a = 1.0
	capture_banner.show()
	banner_timer = 10.0
	_update_economy_ui()

func _on_victory_declared(winning_faction: String) -> void:
	print(">>> GAME OVER: ", winning_faction, " IS VICTORIOUS!")
	victory_banner.text = "%s WINS!" % winning_faction.to_upper()
	victory_banner.show()

func _process(delta: float) -> void:
	if banner_timer > 0.0:
		banner_timer -= delta
		if banner_timer <= 0.0:
			capture_banner.hide()
		elif banner_timer <= 2.0:
			capture_banner.modulate.a = banner_timer / 2.0

	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and multiplayer.is_server():
		economy_timer += delta
		if economy_timer >= ECONOMY_INTERVAL:
			economy_timer -= ECONOMY_INTERVAL
			_process_economy_tick()

func _process_economy_tick() -> void:
	if not scenario_data.has("factions"):
		return
		
	var updated = false
	for faction_name in scenario_data["factions"].keys():
		var fac_data = scenario_data["factions"][faction_name]
		if fac_data.has("cities"):
			var city_count = fac_data["cities"].size()
			var current_money = fac_data.get("money", 0.0)
			# 1 Credit per 1 minute per city
			fac_data["money"] = current_money + (city_count * 1.0)
			updated = true
			
	if updated:
		rpc("sync_economy", scenario_data)
		# Local update for host
		# sync_economy(scenario_data) - rpc with call_local already triggers it

@rpc("authority", "call_local", "reliable")
func sync_economy(new_scenario_data: Dictionary) -> void:
	scenario_data = new_scenario_data
	_update_economy_ui()

func _update_economy_ui() -> void:
	var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var local_faction = ""
	if NetworkManager.players.has(local_id):
		local_faction = NetworkManager.players[local_id].get("faction", "")
		
	var credits = 0.0
	var controlled_cities = 0
	var total_cities = active_cities.size()
	
	if local_faction != "" and scenario_data.has("factions") and scenario_data["factions"].has(local_faction):
		var fac_data = scenario_data["factions"][local_faction]
		credits = fac_data.get("money", 0.0)
		if fac_data.has("cities"):
			controlled_cities = fac_data["cities"].size()
			
	credits_label.text = "Credits: %.1f" % credits
	cities_label.text = "Cities: %d/%d" % [controlled_cities, total_cities]
