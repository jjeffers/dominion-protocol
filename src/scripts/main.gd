class_name MainScene
extends Control


@onready var globe_view = $GlobeContainer/SubViewport/GlobeView

@onready var terrain_panel: Panel = $TerrainSummaryPanel
@onready var terrain_color: ColorRect = $TerrainSummaryPanel/TerrainColor
@onready var terrain_name: Label = $TerrainSummaryPanel/TerrainNameLabel
@onready var city_name: Label = $TerrainSummaryPanel/CityNameLabel

@onready var unit_panel: Panel = $UnitStatusPanel
@onready var unit_type_label: Label = $UnitStatusPanel/VBoxContainer/UnitTypeLabel
@onready var unit_terrain_label: Label = $UnitStatusPanel/VBoxContainer/UnitTerrainLabel
@onready var unit_state_label: Label = $UnitStatusPanel/VBoxContainer/UnitStateLabel
@onready var unit_icon: TextureRect = $UnitStatusPanel/VBoxContainer/IconMarginContainer/UnitIcon
@onready var health_bar_fg: ColorRect = $UnitStatusPanel/VBoxContainer/IconMarginContainer/UnitIcon/HealthBarBg/HealthBarFg
@onready var entrench_bar: ColorRect = $UnitStatusPanel/VBoxContainer/IconMarginContainer/UnitIcon/EntrenchBar
var last_hovered_tile_id: int = -1

@onready var economy_panel: Panel = $EconomyStatusPanel
@onready var credits_label: Label = $EconomyStatusPanel/CreditsLabel
@onready var cities_label: Label = $EconomyStatusPanel/CitiesLabel

@onready var purchase_menu: Panel = $PurchaseMenu
@onready var purchase_infantry_btn: Button = $PurchaseMenu/VBoxContainer/InfantryRow/PurchaseInfantryBtn
@onready var purchase_armor_btn: Button = $PurchaseMenu/VBoxContainer/ArmorRow/PurchaseArmorBtn
@onready var purchase_air_btn: Button = $PurchaseMenu/VBoxContainer/AirRow/PurchaseAirBtn
@onready var purchase_cruiser_btn: Button = $PurchaseMenu/VBoxContainer/CruiserRow/PurchaseCruiserBtn

var city_icon: TextureRect
var map_data: MapData

var economy_timer: float = 0.0
const ECONOMY_INTERVAL: float = 10.0

var capture_banner: Label
var match_timer_label: Label
var banner_timer: float = 0.0
var war_start_audio: AudioStreamPlayer
var victory_banner: Label
var air_ops_prompt: Label

const TERRAIN_COLORS: Dictionary = {
	"OCEAN": Color("#1f679c"),
	"PLAINS": Color("#477a2d"),
	"FOREST": Color("#2d4c1e"),
	"JUNGLE": Color("#163510"),
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
	
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_spawn_tactical_ais()
	
	purchase_infantry_btn.pressed.connect(_on_purchase_infantry)
	purchase_armor_btn.pressed.connect(_on_purchase_armor)
	purchase_air_btn.pressed.connect(_on_purchase_air)
	purchase_cruiser_btn.pressed.connect(_on_purchase_cruiser)
	
	# Initialize HUD State
	terrain_panel.hide()
	
	unit_icon.texture = load("res://src/assets/extracted_sprite.png")
	
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
	
	# Setup Air Ops Prompt
	air_ops_prompt = Label.new()
	air_ops_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	air_ops_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	air_ops_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	air_ops_prompt.position.y = -60
	air_ops_prompt.add_theme_font_size_override("font_size", 28)
	air_ops_prompt.add_theme_color_override("font_color", Color.WHITE)
	air_ops_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	air_ops_prompt.add_theme_constant_override("outline_size", 6)
	air_ops_prompt.text = "[T] - Air Strike | [R] - Redeploy | [ESC] - Cancel"
	air_ops_prompt.hide()
	add_child(air_ops_prompt)

	# Setup Match Timer Label
	match_timer_label = Label.new()
	match_timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	match_timer_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	match_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	match_timer_label.add_theme_font_size_override("font_size", 32)
	match_timer_label.add_theme_color_override("font_color", Color.WHITE)
	match_timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	match_timer_label.add_theme_constant_override("outline_size", 4)
	match_timer_label.offset_left = -300
	match_timer_label.offset_top = 20
	match_timer_label.offset_right = -20
	match_timer_label.offset_bottom = 60
	add_child(match_timer_label)
	
	war_start_audio = AudioStreamPlayer.new()
	war_start_audio.stream = load("res://src/assets/audio/war-start.ogg")
	add_child(war_start_audio)
	war_start_audio.play()
	
	var network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager and network_manager.is_host:
		ConsoleManager.log_message("\n==================================")
		ConsoleManager.log_message("    GLOBAL CONFLICT AUTHORIZED    ")
		ConsoleManager.log_message("==================================\n")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_P:
			if purchase_menu.visible:
				purchase_menu.hide()
			else:
				# Don't open if they're actively deploying something
				if globe_view.get("deploying_unit_type") == "":
					purchase_menu.show()
		elif event.physical_keycode == KEY_ESCAPE:
			if purchase_menu.visible:
				purchase_menu.hide()

func _on_purchase_infantry() -> void:
	purchase_menu.hide()
	globe_view.start_deployment("Infantry", 5.0)

func _on_purchase_armor() -> void:
	purchase_menu.hide()
	globe_view.start_deployment("Armor", 10.0)

func _on_purchase_air() -> void:
	purchase_menu.hide()
	globe_view.start_deployment("Air", 30.0)

func _on_purchase_cruiser() -> void:
	purchase_menu.hide()
	globe_view.start_deployment("Cruiser", 50.0)

func _on_globe_hovered_tile_changed(tile_id: int, terrain: String, c_name: String, region_name: String) -> void:
	last_hovered_tile_id = tile_id
	if tile_id < 0:
		terrain_panel.hide()
		return
		
	# Only show terrain panel if we aren't looking at a unit
	if globe_view == null or globe_view.selected_unit == null:
		terrain_panel.show()
	else:
		terrain_panel.hide()
	
	if c_name != "":
		city_name.text = c_name
		city_name.show()
		
		# Show city icon and hide underlying terrain color
		if terrain == "OCEAN" or terrain == "LAKE":
			terrain_name.text = "DOCKS"
		else:
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

func _spawn_tactical_ais() -> void:
	if not scenario_data.has("factions"): return
	
	var human_factions = []
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		for p in nm.players.values():
			if p.has("faction") and p["faction"] != "":
				if not p.get("name", "").begins_with("[BOT]"):
					human_factions.append(p["faction"])
				
	for fac in scenario_data["factions"].keys():
		if not (fac in human_factions):
			print("MainScene: Spawning TacticalAI for unassigned or bot-managed faction ", fac)
			var ai = load("res://src/scripts/ai/TacticalAI.gd").new()
			ai.name = "TacticalAI_" + fac
			add_child(ai)
			ai.set_faction(fac, 0.5, 2) # Aggression 0.5, Capability 2


func _on_city_captured(city_name: String, new_faction: String, old_faction: String) -> void:
	print(">>> CITY DOMAINS UPDATED: ", city_name, " is now under control of ", new_faction)
	capture_banner.text = "%s CAPTURES %s!" % [new_faction.to_upper(), city_name.replace("Unit_City_", "").to_upper()]
	capture_banner.modulate.a = 1.0
	capture_banner.show()
	banner_timer = 10.0
	_update_economy_ui()

func _on_victory_declared(winning_faction: String) -> void:
	print(">>> GAME OVER: ", winning_faction, " IS VICTORIOUS!")
	
	var role = "Host" if NetworkManager.is_host else "Client"
	var local_fac = "Unassigned"
	if NetworkManager.players.has(multiplayer.get_unique_id()):
		local_fac = NetworkManager.players[multiplayer.get_unique_id()].get("faction", "")
	print("[MATCH_RESULT] MATCH=%s ROLE=%s FACTION=%s WINNER=%s" % [NetworkManager.match_id, role, local_fac, winning_faction])
	
	victory_banner.text = "%s WINS!" % winning_faction.to_upper()
	victory_banner.show()

	if "[BOT]" in NetworkManager.local_player_name:
		await get_tree().create_timer(10.0).timeout
		get_tree().quit()

func post_news_event(msg: String, involved_factions: Array) -> void:
	print(">>> NEWS EVENT: ", msg)
	var local_fac = ""
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and multiplayer.has_multiplayer_peer():
		var local_id = multiplayer.get_unique_id()
		if nm.players.has(local_id):
			local_fac = nm.players[local_id].get("faction", "")
			
	if local_fac in involved_factions or local_fac == "":
		capture_banner.text = msg
		capture_banner.modulate.a = 1.0
		capture_banner.show()
		banner_timer = 10.0
		DisplayServer.tts_speak(msg)
		banner_timer = 10.0

func _process(delta: float) -> void:
	if is_instance_valid(match_timer_label):
		match_timer_label.text = ConsoleManager.get_elapsed_time_string()

	if banner_timer > 0.0:
		banner_timer -= delta
		if banner_timer <= 0.0:
			capture_banner.hide()
		elif banner_timer <= 2.0:
			capture_banner.modulate.a = banner_timer / 2.0

	# Unit Status UI Updates
	if globe_view and globe_view.selected_unit != null:
		terrain_panel.hide()
		unit_panel.show()
		
		var su = globe_view.selected_unit
		unit_type_label.text = su.unit_type
		unit_icon.texture = su.sprite.texture
		
		# Terrain Lookup
		var u_tile = globe_view._get_tile_from_vector3(su.current_position)
		var u_terrain = map_data.get_terrain(u_tile)
		if globe_view.city_tile_cache.has(u_tile):
			if u_terrain == "OCEAN" or u_terrain == "LAKE":
				unit_terrain_label.text = "Terrain: DOCKS"
			else:
				unit_terrain_label.text = "Terrain: CITY"
			unit_terrain_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		else:
			unit_terrain_label.text = "Terrain: " + u_terrain
			unit_terrain_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			
		# State Computation
		var states = ["Health: " + str(int(su.health)) + "%"]
		if su.get("unit_type") == "Air":
			if su.get("is_air_ready"):
				states.append("READY")
				if globe_view.current_air_operation_mode == "":
					air_ops_prompt.text = "[T] - Air Strike | [R] - Redeploy | [ESC] - Cancel"
				elif globe_view.current_air_operation_mode == "AIRSTRIKE":
					air_ops_prompt.text = "LEFT CLICK ENEMY UNIT = AIRSTRIKE | [ESC] - Cancel"
				elif globe_view.current_air_operation_mode == "REDEPLOY":
					air_ops_prompt.text = "LEFT CLICK GREEN CITY = REDEPLOY | [ESC] - Cancel"
				air_ops_prompt.show()
			else:
				states.append("UNREADY")
				air_ops_prompt.hide()
		else:
			air_ops_prompt.hide()
				
		if su.is_engaged:
			states.append("ENGAGED")
		elif su.current_position != null and su.target_position != null and su.current_position.distance_to(su.target_position) > 0.0001:
			var move_state = "MOVING"
			if su.get("is_seaborne") and su.get("unit_type") != "Cruiser":
				move_state = "SEA TRANSPORT"
				
			if su.current_terrain_modifier != 1.0:
				var diff_pct = int(abs(1.0 - su.current_terrain_modifier) * 100.0)
				if su.current_terrain_modifier < 1.0:
					move_state += " (-" + str(diff_pct) + "% Spd)"
				else:
					move_state += " (+" + str(diff_pct) + "% Spd)"
					
			states.append(move_state)
			
		if su.entrenched:
			states.append("ENTRENCHED")
			entrench_bar.show()
		else:
			entrench_bar.hide()
			
		if su.get("is_recovering"):
			states.append("RECOVERING")
			
		unit_state_label.text = " | ".join(states)
		
		# Update Health Bar
		var pct = clamp(su.health / 100.0, 0.0, 1.0)
		health_bar_fg.anchor_right = pct
		health_bar_fg.offset_right = 0
		if pct > 0.5:
			health_bar_fg.color = Color(0.0, 0.8, 0.2)
		elif pct > 0.25:
			health_bar_fg.color = Color(0.8, 0.8, 0.0)
		else:
			health_bar_fg.color = Color(0.9, 0.1, 0.1)
	else:
		unit_panel.hide()
		air_ops_prompt.hide()
		if last_hovered_tile_id >= 0:
			terrain_panel.show()

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
			# 1 Credit per 1 minute per city -> 0.0333 credit per 10 seconds
			fac_data["money"] = current_money + (city_count * (ECONOMY_INTERVAL / 300.0))
			updated = true
			
	if updated:
		rpc("sync_economy", scenario_data)
		# Local update for host
		# sync_economy(scenario_data) - rpc with call_local already triggers it

@rpc("authority", "call_local", "reliable")
func sync_economy(new_scenario_data: Dictionary) -> void:
	scenario_data = new_scenario_data
	if globe_view:
		globe_view.active_scenario = scenario_data
	_update_economy_ui()

func _update_economy_ui() -> void:
	var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var local_faction = ""
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.players.has(local_id):
		local_faction = nm.players[local_id].get("faction", "")
		
	var credits = 0.0
	var controlled_cities = 0
	var total_cities = active_cities.size()
	
	if local_faction != "" and scenario_data.has("factions") and scenario_data["factions"].has(local_faction):
		var fac_data = scenario_data["factions"][local_faction]
		credits = fac_data.get("money", 0.0)
		if fac_data.has("cities"):
			controlled_cities = fac_data["cities"].size()
			
	credits_label.text = "Credits: %.0f" % floor(credits)
	cities_label.text = "Cities: %d/%d" % [controlled_cities, total_cities]
	
	# Update Purchase Availability
	purchase_infantry_btn.disabled = credits < 5.0
	purchase_armor_btn.disabled = credits < 10.0
	purchase_air_btn.disabled = credits < 30.0
	purchase_cruiser_btn.disabled = credits < 50.0
