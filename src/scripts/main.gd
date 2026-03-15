class_name MainScene
extends Control

@onready var tactical_view = $TacticalPanel/TacticalContainer/SubViewport/TacticalView
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
	
	# 2. Inject Data into Views
	tactical_view.map_data = map_data
	globe_view.map_data = map_data
	
	# 3. Connect focus synchronization signals
	tactical_view.focus_changed.connect(_on_tactical_focus_changed)
	globe_view.focus_changed.connect(_on_globe_focus_changed)
	tactical_view.bounds_changed.connect(globe_view.update_outline)
	globe_view.hovered_tile_changed.connect(_on_globe_hovered_tile_changed)
	
	# Trigger initial generation and sync
	tactical_view._on_viewport_size_changed()
	globe_view._generate_mesh()
	globe_view._update_camera()
	
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

func _on_tactical_focus_changed(longitude: float, latitude: float) -> void:
	# Stop echoing
	if globe_view._is_dragging:
		return
	globe_view.set_focus(longitude, latitude)

func _on_globe_focus_changed(longitude: float, latitude: float) -> void:
	# Stop echoing
	if tactical_view._is_dragging:
		return
	tactical_view.set_focus(longitude, latitude)
