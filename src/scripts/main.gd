class_name MainScene
extends Control


@onready var globe_view = $GlobeContainer/SubViewport/GlobeView

@onready var terrain_panel: Panel = $TerrainSummaryPanel
@onready var terrain_color: ColorRect = $TerrainSummaryPanel/TerrainColor
@onready var terrain_name: Label = $TerrainSummaryPanel/TerrainNameLabel
@onready var city_name: Label = $TerrainSummaryPanel/CityNameLabel

var city_icon: TextureRect
var map_data: MapData

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
	
	# 2. Inject Data into Views
	globe_view.map_data = map_data
	
	# 3. Connect focus synchronization signals
	globe_view.hovered_tile_changed.connect(_on_globe_hovered_tile_changed)
	
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
