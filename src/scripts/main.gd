class_name MainScene
extends Control


@onready var globe_view = $GlobeContainer/SubViewport/GlobeView

@onready var terrain_panel: Panel = $TerrainSummaryPanel
@onready var terrain_color: ColorRect = $TerrainSummaryPanel/TerrainColor
@onready var terrain_name: Label = $TerrainSummaryPanel/TerrainNameLabel
@onready var city_name: Label = $TerrainSummaryPanel/CityNameLabel
@onready var faction_owner_label: Label = $TerrainSummaryPanel/FactionOwnerLabel

@onready var unit_panel: Panel = $UnitStatusPanel
@onready var unit_type_label: Label = $UnitStatusPanel/VBoxContainer/UnitTypeLabel
@onready var unit_terrain_label: Label = $UnitStatusPanel/VBoxContainer/UnitTerrainLabel
@onready var unit_state_label: Label = $UnitStatusPanel/VBoxContainer/UnitStateLabel
@onready var unit_icon: TextureRect = $UnitStatusPanel/VBoxContainer/IconMarginContainer/UnitIcon
@onready var health_bar_fg: ColorRect = $UnitStatusPanel/VBoxContainer/IconMarginContainer/UnitIcon/HealthBarBg/HealthBarFg
@onready var entrench_bar: ColorRect = $UnitStatusPanel/VBoxContainer/IconMarginContainer/UnitIcon/EntrenchBar
var last_hovered_tile_id: int = -1
var hovered_c_name: String = ""

@onready var economy_panel: Panel = $EconomyStatusPanel
@onready var credits_label: Label = $EconomyStatusPanel/CreditsLabel
@onready var cities_label = $EconomyStatusPanel/CitiesLabel
@onready var nukes_label: Label = $EconomyStatusPanel/NukesLabel

@onready var diplomacy_panel: Panel = $DiplomaticStatusPanel
@onready var diplomacy_vbox: VBoxContainer = $DiplomaticStatusPanel/ScrollContainer/VBoxContainer

@onready var purchase_menu: Panel = $PurchaseMenu
@onready var purchase_infantry_btn: Button = $PurchaseMenu/VBoxContainer/InfantryRow/PurchaseInfantryBtn
@onready var purchase_armor_btn: Button = $PurchaseMenu/VBoxContainer/ArmorRow/PurchaseArmorBtn
@onready var purchase_air_btn: Button = $PurchaseMenu/VBoxContainer/AirRow/PurchaseAirBtn
@onready var purchase_cruiser_btn: Button = $PurchaseMenu/VBoxContainer/CruiserRow/PurchaseCruiserBtn
@onready var purchase_submarine_btn: Button = $PurchaseMenu/VBoxContainer/SubmarineRow/PurchaseSubmarineBtn
@onready var purchase_nuke_btn: Button = $PurchaseMenu/VBoxContainer/NukeRow/PurchaseNukeBtn
@onready var purchase_foreign_aid_btn: Button = $PurchaseMenu/VBoxContainer/ForeignAidRow/PurchaseForeignAidBtn

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
var nuke_hint_prompt: Label

const TERRAIN_COLORS: Dictionary = {
	"OCEAN": Color("#1f679c"),
	"PLAINS": Color("#477a2d"),
	"FOREST": Color("#2d4c1e"),
	"JUNGLE": Color("#163510"),
	"DESERT": Color("#e6c27a"),
	"MOUNTAIN": Color("#8c8c8c"),
	"POLAR": Color("#ffffff"),
	"WASTELAND": Color("#2b2b2b"),
	"RUINS": Color("#1a1a1a")
}

var is_async_setup: bool = false

func _ready() -> void:
	# 0. Upgrade CitiesLabel to natively support BBCode HTML fraction strings
	var old_cities = cities_label
	cities_label = RichTextLabel.new()
	cities_label.name = "CitiesLabelRT"
	cities_label.layout_mode = 1
	cities_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cities_label.offset_top = -90.0
	cities_label.offset_bottom = -50.0
	cities_label.bbcode_enabled = true
	cities_label.scroll_active = false
	cities_label.add_theme_font_size_override("normal_font_size", 36)
	old_cities.get_parent().add_child(cities_label)
	old_cities.queue_free()

	# 1. Initialize Canonical Data
	map_data = globe_view.map_data
	if not map_data:
		map_data = MapData.new()
		globe_view.map_data = map_data
	
	# Parse Scenario
	_load_scenario()
	
	# Update Economy UI
	_update_economy_ui()
	
	# 3. Connect focus synchronization signals
	globe_view.hovered_tile_changed.connect(_on_globe_hovered_tile_changed)
	globe_view.city_captured.connect(_on_city_captured)
	globe_view.victory_declared.connect(_on_victory_declared)
	
	# Trigger initial generation and sync
	if not is_async_setup:
		globe_view._generate_mesh()
		globe_view._update_camera()
		
		# Ensure GlobeView explicitly relies on the scenario definitions to draw features
		globe_view._instantiate_scenario(scenario_data)
		
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			_spawn_tactical_ais()

	
	purchase_infantry_btn.pressed.connect(_on_purchase_infantry)
	purchase_armor_btn.pressed.connect(_on_purchase_armor)
	purchase_air_btn.pressed.connect(_on_purchase_air)
	purchase_cruiser_btn.pressed.connect(_on_purchase_cruiser)
	purchase_submarine_btn.pressed.connect(_on_purchase_submarine)
	purchase_nuke_btn.pressed.connect(_on_purchase_nuke)
	purchase_foreign_aid_btn.pressed.connect(_on_purchase_foreign_aid)
	
	# Initialize HUD State
	terrain_panel.hide()
	
	# Increase font size (default is 16, doubling to 32) and add white outline
	faction_owner_label.add_theme_font_size_override("font_size", 32)
	faction_owner_label.add_theme_color_override("font_outline_color", Color.WHITE)
	faction_owner_label.add_theme_constant_override("outline_size", 4)
	
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
	air_ops_prompt.text = "[T] - Air Strike | [B] - Bombing | [R] - Redeploy | [ESC] - Cancel"
	air_ops_prompt.hide()
	add_child(air_ops_prompt)

	# Setup Nuke Hint Prompt
	nuke_hint_prompt = Label.new()
	nuke_hint_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nuke_hint_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nuke_hint_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nuke_hint_prompt.position.y = -100
	nuke_hint_prompt.add_theme_font_size_override("font_size", 28)
	nuke_hint_prompt.add_theme_color_override("font_color", Color.YELLOW)
	nuke_hint_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	nuke_hint_prompt.add_theme_constant_override("outline_size", 6)
	nuke_hint_prompt.text = "[N] - Launch Nuclear Weapon"
	nuke_hint_prompt.hide()
	add_child(nuke_hint_prompt)

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
	
	if not is_async_setup:
		war_start_audio.play()
		
		# Open the console automatically when the match starts
		ConsoleManager.is_visible = true
		ConsoleManager.panel.show()
		
		var network_manager = get_node_or_null("/root/NetworkManager")
		if network_manager and network_manager.is_host:
			ConsoleManager.log_message("==================================")
			ConsoleManager.log_message("    GLOBAL CONFLICT AUTHORIZED    ")
			ConsoleManager.log_message("==================================\n")
			post_news_event("GLOBAL CONFLICT AUTHORIZED", [])

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
		elif event.physical_keycode == KEY_N:
			if purchase_menu.visible:
				purchase_menu.hide()
			ConsoleManager.log_message("SYSTEM: N key registered.")
			var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
			var local_faction = ""
			var nm = get_node_or_null("/root/NetworkManager")
			if nm and nm.players.has(local_id):
				local_faction = nm.players[local_id].get("faction", "")
			
			if local_faction == "":
				ConsoleManager.log_message("SYSTEM: local_faction missing")
			else:
				var active_s = globe_view.get("active_scenario")
				if typeof(active_s) == TYPE_DICTIONARY and active_s.has("factions") and active_s["factions"].has(local_faction):
					var available_nukes = active_s["factions"][local_faction].get("nukes", 0)
					if available_nukes > 0:
						if globe_view.has_method("start_nuke_targeting"):
							globe_view.start_nuke_targeting()
					else:
						ConsoleManager.log_message("SYSTEM: No nukes available (" + str(available_nukes) + ")")
				else:
					ConsoleManager.log_message("SYSTEM: Scenario parsing failed")

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

func _on_purchase_submarine() -> void:
	purchase_menu.hide()
	globe_view.start_deployment("Submarine", 35.0)

func _on_purchase_foreign_aid() -> void:
	purchase_menu.hide()
	globe_view.start_foreign_aid_purchase()

func _on_purchase_nuke() -> void:
	purchase_menu.hide()
	var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var local_faction = ""
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.players.has(local_id):
		local_faction = nm.players[local_id].get("faction", "")
		
	if local_faction != "" and scenario_data.has("factions") and scenario_data["factions"].has(local_faction):
		var fac_data = scenario_data["factions"][local_faction]
		var costs = 20.0
		if fac_data.get("money", 0.0) >= costs:
			print("DEBUG: Attempting to purchase Nuke. Calling sync_nuke_purchase RPC...")
			if get_node_or_null("/root/NetworkManager") and multiplayer.has_multiplayer_peer():
				globe_view.rpc("sync_nuke_purchase", local_faction, costs)
			else:
				globe_view.sync_nuke_purchase(local_faction, costs)

func _on_globe_hovered_tile_changed(tile_id: int, terrain: String, c_name: String, region_name: String) -> void:
	last_hovered_tile_id = tile_id
	hovered_c_name = c_name
	if tile_id < 0:
		terrain_panel.hide()
		hovered_c_name = ""
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
		if terrain == "RUINS":
			terrain_name.text = "RUINS"
		elif terrain == "OCEAN" or terrain == "LAKE":
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

	var faction_owner = ""
	var faction_color = Color.WHITE
	if region_name != "":
		if scenario_data.has("factions"):
			for f_name in scenario_data["factions"]:
				var f_data = scenario_data["factions"][f_name]
				if f_data.has("cities") and region_name in f_data["cities"]:
					faction_owner = f_name
					if f_data.has("color"):
						faction_color = Color(f_data["color"])
					break
		
		if faction_owner == "" and scenario_data.has("countries"):
			for country_name in scenario_data["countries"]:
				var c_data = scenario_data["countries"][country_name]
				if c_data.has("cities") and region_name in c_data["cities"]:
					faction_owner = country_name
					if c_data.has("color"):
						faction_color = Color(c_data["color"])
					break
				
	if faction_owner != "":
		faction_owner_label.text = get_faction_name(faction_owner)
		if faction_color.to_html(false) == "ffd700":
			faction_owner_label.remove_theme_color_override("font_color")
			faction_owner_label.remove_theme_color_override("font_outline_color")
			faction_owner_label.remove_theme_constant_override("outline_size")
		else:
			faction_owner_label.add_theme_color_override("font_color", faction_color)
			faction_owner_label.add_theme_color_override("font_outline_color", Color.WHITE)
			faction_owner_label.add_theme_constant_override("outline_size", 4)
		faction_owner_label.show()
	else:
		faction_owner_label.hide()

var scenario_data: Dictionary = {}

func get_faction_name(f_id: String) -> String:
	if scenario_data and scenario_data.has("factions") and scenario_data["factions"].has(f_id):
		return scenario_data["factions"][f_id].get("display_name", f_id)
	return f_id
	
var active_cities: Array[String] = []
var active_regions: Array[String] = []

func _load_scenario() -> void:
	if scenario_data.is_empty():
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
	capture_banner.text = "%s CAPTURES %s!" % [get_faction_name(new_faction).to_upper(), city_name.replace("Unit_City_", "").to_upper()]
	capture_banner.modulate.a = 1.0
	capture_banner.show()
	banner_timer = 10.0
	_update_economy_ui()

func _on_victory_declared(winning_faction: String) -> void:
	print(">>> GAME OVER: ", winning_faction, " IS VICTORIOUS!")
	
	var role = "Host" if NetworkManager.is_host else "Client"
	var local_fac = "Unassigned"
	if multiplayer.has_multiplayer_peer() and NetworkManager.players.has(multiplayer.get_unique_id()):
		local_fac = NetworkManager.players[multiplayer.get_unique_id()].get("faction", "")
	print("[MATCH_RESULT] MATCH=%s ROLE=%s FACTION=%s WINNER=%s" % [NetworkManager.match_id, role, local_fac, winning_faction])
	
	victory_banner.text = "%s WINS!" % get_faction_name(winning_faction).to_upper()
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
			
	if involved_factions.is_empty() or local_fac in involved_factions or local_fac == "":
		capture_banner.text = msg
		capture_banner.modulate.a = 1.0
		capture_banner.show()
		banner_timer = 10.0

func _process(delta: float) -> void:
	if is_instance_valid(match_timer_label):
		match_timer_label.text = ConsoleManager.get_elapsed_time_string()

	# Dynamic Cooldown text check
	if hovered_c_name != "" and globe_view and globe_view.city_cooldowns.has(hovered_c_name):
		var cd = int(globe_view.city_cooldowns[hovered_c_name])
		if cd > 0:
			var mins = cd / 60
			var secs = cd % 60
			city_name.text = hovered_c_name + " [CD: %02d:%02d]" % [mins, secs]
			city_name.add_theme_color_override("font_color", Color.RED)
		else:
			city_name.text = hovered_c_name
			city_name.remove_theme_color_override("font_color")
	elif hovered_c_name != "":
		city_name.text = hovered_c_name
		city_name.remove_theme_color_override("font_color")

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
		var states = []
		if su.get("unit_type") != "Air":
			states.append("Health: " + str(int(su.health)) + "%")
			
		if su.get("unit_type") == "Air":
			if su.get("is_air_ready"):
				states.append("READY")
				if globe_view.current_air_operation_mode == "":
					air_ops_prompt.text = "[T] - Air Strike | [B] - Bombing | [R] - Redeploy | [ESC] - Cancel"
				elif globe_view.current_air_operation_mode == "AIRSTRIKE":
					air_ops_prompt.text = "LEFT CLICK ENEMY UNIT = AIRSTRIKE | [ESC] - Cancel"
				elif globe_view.current_air_operation_mode == "STRATEGIC_BOMBING":
					air_ops_prompt.text = "LEFT CLICK ENEMY CITY = BOMBING | [ESC] - Cancel"
				elif globe_view.current_air_operation_mode == "REDEPLOY":
					air_ops_prompt.text = "LEFT CLICK GREEN CITY = REDEPLOY | [ESC] - Cancel"
				air_ops_prompt.show()
			else:
				var cd_val = su.get("air_cooldown_timer")
				var seconds_left = int(ceil(cd_val if cd_val != null else 0.0))
				states.append("UNREADY (" + str(seconds_left) + "s)")
				air_ops_prompt.hide()
		else:
			air_ops_prompt.hide()
				
		if su.is_engaged:
			states.append("ENGAGED")
		elif su.current_position != null and su.target_position != null and su.current_position.distance_to(su.target_position) > 0.0001:
			var move_state = "MOVING"
			if su.get("is_seaborne") and su.get("unit_type") not in ["Cruiser", "Submarine"]:
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
		
		# Update Health/Readiness Bar
		if su.get("unit_type") == "Air":
			var cd_val = su.get("air_cooldown_timer")
			cd_val = cd_val if cd_val != null else 0.0
			var pct = clamp(1.0 - (cd_val / 120.0), 0.0, 1.0)
			health_bar_fg.anchor_right = pct
			health_bar_fg.offset_right = 0
			if pct >= 1.0:
				health_bar_fg.color = Color(0.0, 0.8, 0.8) # Cyan ready
			else:
				health_bar_fg.color = Color(0.8, 0.8, 0.0) # Yellow charging
		else:
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
		var city_count = 0
		if fac_data.has("cities"):
			city_count = fac_data["cities"].size()
			
		var oil_count = 0
		if fac_data.has("oil"):
			oil_count = fac_data["oil"].size()
			
		if city_count > 0 or oil_count > 0:
			var current_money = fac_data.get("money", 0.0)
			# City: 1 Credit/1 min -> 5 per 300s | Oil: 10 per 300s
			fac_data["money"] = current_money + (city_count * (ECONOMY_INTERVAL / 300.0)) + (oil_count * 10.0 * (ECONOMY_INTERVAL / 300.0))
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
	var my_cities = 0
	var my_color = "#FFFFFF"
	var enemy_cities = 0
	var enemy_color = "#FFFFFF"
	var total_cities = active_cities.size()
	if globe_view and globe_view.get("city_nodes"):
		total_cities = globe_view.city_nodes.size()
	var nukes = 0
	
	if local_faction != "" and scenario_data.has("factions"):
		if scenario_data["factions"].has(local_faction):
			var fac_data = scenario_data["factions"][local_faction]
			credits = fac_data.get("money", 0.0)
			nukes = fac_data.get("nukes", 0)
			
		for fac in scenario_data["factions"].keys():
			var f_data = scenario_data["factions"][fac]
			var count = 0
			if f_data.has("cities"): count = f_data["cities"].size()
			if fac == local_faction:
				my_cities = count
				my_color = f_data.get("color", "#FFFFFF")
			elif not f_data.get("eliminated", false):
				enemy_cities += count
				enemy_color = f_data.get("color", "#FFFFFF")
				
	var neutral_cities_count = total_cities - (my_cities + enemy_cities)
	if neutral_cities_count < 0: neutral_cities_count = 0
			
	credits_label.text = "Credits: %.0f (P - Buy)" % floor(credits)
	cities_label.text = "[center]Cities: [outline_size=2][outline_color=#dddddd][color=%s]%d[/color][/outline_color][/outline_size] / [outline_size=2][outline_color=#dddddd][color=%s]%d[/color][/outline_color][/outline_size] / [color=#AAAAAA]%d[/color][/center]" % [my_color, my_cities, enemy_color, enemy_cities, neutral_cities_count]
	if nukes > 0:
		nukes_label.text = "Nukes: %d (N - Nuke)" % nukes
	else:
		nukes_label.text = "Nukes: 0"
	
	if nuke_hint_prompt:
		if nukes > 0:
			nuke_hint_prompt.show()
		else:
			nuke_hint_prompt.hide()
	
	# Update Purchase Availability
	purchase_infantry_btn.disabled = credits < 5.0
	purchase_armor_btn.disabled = credits < 10.0
	purchase_air_btn.disabled = credits < 30.0
	purchase_cruiser_btn.disabled = credits < 50.0
	purchase_submarine_btn.disabled = credits < 35.0
	purchase_nuke_btn.disabled = credits < 20.0
	purchase_foreign_aid_btn.disabled = credits < 10.0
	
	_update_diplomacy_ui()

var _diplomacy_dirty: bool = false
func _update_diplomacy_ui() -> void:
	if not _diplomacy_dirty:
		_diplomacy_dirty = true
		call_deferred("_do_update_diplomacy_ui")

func _do_update_diplomacy_ui() -> void:
	_diplomacy_dirty = false
	if not scenario_data.has("countries"):
		return
		
	var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var local_faction = ""
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.players.has(local_id):
		local_faction = nm.players[local_id].get("faction", "")
		
	if local_faction == "":
		diplomacy_panel.hide()
		return
	else:
		diplomacy_panel.show()
		
	var countries_list = []
	for c_name in scenario_data["countries"].keys():
		var c_data = scenario_data["countries"][c_name]
		if c_data.has("cities") and c_data["cities"].size() > 0:
			var op = c_data.get("opinions", {}).get(local_faction, 0.0)
			var num_cities = 0
			var num_oil = 0
			for region in c_data["cities"]:
				if region.begins_with("TOP_") or region.begins_with("BOTTOM_") or region.begins_with("LEFT_") or region.begins_with("RIGHT_") or region.begins_with("FRONT_") or region.begins_with("BACK_"):
					num_oil += 1
				else:
					num_cities += 1
					
			countries_list.append({"name": c_name, "opinion": op, "cities": num_cities, "oil": num_oil})
		
	countries_list.sort_custom(func(a, b):
		var op_a = a["opinion"]
		var op_b = b["opinion"]
		if op_a > 0 and op_b <= 0: return true
		if op_b > 0 and op_a <= 0: return false
		if op_a < 0 and op_b == 0: return true
		if op_b < 0 and op_a == 0: return false
		if op_a > 0 and op_b > 0: return op_a > op_b
		if op_a < 0 and op_b < 0: return op_a < op_b
		return a["name"] < b["name"]
	)
	
	for child in diplomacy_vbox.get_children():
		diplomacy_vbox.remove_child(child)
		child.queue_free()
		
	for c_item in countries_list:
		var hb = HBoxContainer.new()
		
		var name_btn = Button.new()
		name_btn.text = c_item["name"] + " (" + str(c_item["cities"]) + "/" + str(c_item["oil"]) + ")"
		name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_btn.add_theme_font_size_override("font_size", 24)
		name_btn.flat = true
		name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_btn.clip_text = true
		
		var op_val = int(clamp(round(c_item["opinion"]), -100, 100))
		var op_lbl = Label.new()
		if op_val > 0:
			op_lbl.text = "+" + str(op_val)
		else:
			op_lbl.text = str(op_val)
		op_lbl.add_theme_font_size_override("font_size", 24)
			
		if op_val >= 50:
			name_btn.add_theme_color_override("font_color", Color.GREEN)
			op_lbl.add_theme_color_override("font_color", Color.GREEN)
		elif op_val < 0:
			name_btn.add_theme_color_override("font_color", Color.RED)
			op_lbl.add_theme_color_override("font_color", Color.RED)
		else:
			name_btn.add_theme_color_override("font_color", Color.YELLOW)
			op_lbl.add_theme_color_override("font_color", Color.YELLOW)
			
		name_btn.pressed.connect(_on_diplomacy_country_clicked.bind(c_item["name"]))
		
		hb.add_child(name_btn)
		hb.add_child(op_lbl)
		diplomacy_vbox.add_child(hb)

func _on_diplomacy_country_clicked(country_name: String) -> void:
	if globe_view == null: return
	if not scenario_data.has("countries"): return
	var c_data = scenario_data["countries"].get(country_name, {})
	if c_data.has("cities") and c_data["cities"].size() > 0:
		var target_city = c_data["cities"][0]
		if globe_view.has_method("focus_on_city"):
			globe_view.focus_on_city(target_city)

func execute_async_setup(lobby_node: Node) -> void:
	lobby_node.update_progress(10.0, "Generating Globe Mesh...")
	await get_tree().process_frame
	globe_view._generate_mesh()
	globe_view._update_camera()
	
	lobby_node.update_progress(30.0, "Instantiating Scenario Entities...")
	await get_tree().process_frame
	
	var update_cb = func(pct: float, text: String):
		lobby_node.update_progress(30.0 + (pct * 60.0), text)
	
	await globe_view._instantiate_scenario(scenario_data, update_cb)
	
	lobby_node.update_progress(95.0, "Spawning AI Commanders...")
	await get_tree().process_frame
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_spawn_tactical_ais()
		
	lobby_node.update_progress(100.0, "Transitioning to Game...")
	await get_tree().process_frame
	
	get_tree().current_scene = self
	self.visible = true
	lobby_node.queue_free()
	
	war_start_audio.play()
	ConsoleManager.is_visible = true
	ConsoleManager.panel.show()
	
	var network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager and network_manager.is_host:
		ConsoleManager.log_message("==================================")
		ConsoleManager.log_message("    GLOBAL CONFLICT AUTHORIZED    ")
		ConsoleManager.log_message("==================================\n")
		post_news_event("GLOBAL CONFLICT AUTHORIZED", [])
