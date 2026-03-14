class_name MainScene
extends Control

@onready var tactical_view: TacticalView = $TacticalPanel/TacticalContainer/SubViewport/TacticalView
@onready var globe_view: GlobeView = $GlobeContainer/SubViewport/GlobeView

var map_data: MapData

func _ready() -> void:
	# 1. Initialize Canonical Data
	map_data = MapData.new(0, 0)
	var loaded = map_data.load_from_image("res://src/assets/map_half.png")
	if not loaded:
		print("Fallback to procedural continents")
		map_data = MapData.new(64, 32)
		map_data.generate_prototype_continents()
	
	# 2. Inject Data into Views
	tactical_view.map_data = map_data
	globe_view.map_data = map_data
	
	# 3. Connect focus synchronization signals
	tactical_view.focus_changed.connect(_on_tactical_focus_changed)
	globe_view.focus_changed.connect(_on_globe_focus_changed)
	tactical_view.bounds_changed.connect(globe_view.update_outline)
	
	# Trigger initial generation and sync
	tactical_view._on_viewport_size_changed()
	globe_view._generate_mesh()
	globe_view._update_camera()

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
