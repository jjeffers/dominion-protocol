class_name MainScene
extends Control

@onready var tactical_view: TacticalView = $TacticalPanel/TacticalContainer/SubViewport/TacticalView
@onready var globe_view: GlobeView = $GlobeContainer/SubViewport/GlobeView

@onready var terrain_panel: Panel = $TerrainSummaryPanel
@onready var terrain_color: ColorRect = $TerrainSummaryPanel/TerrainColor
@onready var terrain_name: Label = $TerrainSummaryPanel/TerrainNameLabel
@onready var city_name: Label = $TerrainSummaryPanel/CityNameLabel

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

func _on_globe_hovered_tile_changed(tile_id: String, terrain: String, c_name: String) -> void:
	if tile_id == "":
		terrain_panel.hide()
		return
		
	terrain_panel.show()
	terrain_name.text = terrain
	
	if TERRAIN_COLORS.has(terrain):
		terrain_color.color = TERRAIN_COLORS[terrain]
	else:
		terrain_color.color = Color.BLACK
		
	if c_name != "":
		city_name.text = c_name
		city_name.show()
	else:
		city_name.hide()

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
