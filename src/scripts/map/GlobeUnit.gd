class_name GlobeUnit
extends Node3D

var sprite: Sprite3D
var click_area: Area3D
var collision_shape: CollisionShape3D

var is_selected: bool = false
var base_render_priority: int = 10
var current_tile_id: int = -1

var health: float = 100.0
var unit_type: String = "Infantry" :
	set(value):
		unit_type = value.capitalize()
		_update_texture()

func _update_texture() -> void:
	if not sprite: return
	
	var tex: Texture2D
	if unit_type == "Air" or unit_type == "Cruiser" or unit_type == "Submarine" or unit_type == "Armor":
		var atlas = load("res://src/assets/spritesheet.png") as Texture2D
		if atlas:
			var img = atlas.get_image()
			if img:
				var region = Rect2(0, 64, 32, 32) # Default Air
				if unit_type == "Cruiser":
					region = Rect2(32, 192, 32, 32)
				elif unit_type == "Submarine":
					region = Rect2(0, 32, 32, 32)
				elif unit_type == "Armor":
					region = Rect2(0, 192, 32, 32)
				var cropped_img = img.get_region(region)
				
				if cropped_img.get_format() != Image.FORMAT_RGBA8:
					cropped_img.convert(Image.FORMAT_RGBA8)
					
				var padded_img = Image.create(34, 34, false, Image.FORMAT_RGBA8)
				if unit_type == "Air":
					padded_img.fill(Color(0, 0, 0, 0))
				else:
					padded_img.fill(Color.WHITE)
					
				padded_img.blend_rect(cropped_img, Rect2(0, 0, 32, 32), Vector2(1, 1))
				
				tex = ImageTexture.create_from_image(padded_img)
	else:
		var tex_path = "res://src/assets/extracted_sprite.png"
		tex = load(tex_path) as Texture2D

	if tex:
		sprite.texture = tex
		_apply_shared_material(tex)

var combat_target: GlobeUnit = null
var movement_target_unit: GlobeUnit = null
var is_engaged: bool = false
var is_dead: bool = false

func _ready() -> void:
	if NetworkManager != null:
		NetworkManager.unit_damage_synced.connect(_on_unit_damage_synced)
		NetworkManager.unit_health_synced.connect(_on_unit_health_synced)

func _on_unit_damage_synced(target_unit_name: String, amount: float, attacker_name: String) -> void:
	if target_unit_name == name:
		take_damage(amount, attacker_name, true)

func _on_unit_health_synced(target_unit_name: String, amount: float) -> void:
	if target_unit_name == name:
		health = amount
		_update_health_bar()

var radius: float = 1.0
var current_position: Vector3
var target_position: Vector3

var current_path: Array[Vector3] = []
var _last_path_update_pos: Vector3 = Vector3.ZERO
var _last_target_update_pos: Vector3 = Vector3.ZERO

static var _shared_materials: Dictionary = {}

func clear_path() -> void:
	current_path.clear()
	path_update_timer = 0.0
	if path_immediate_mesh:
		path_immediate_mesh.clear_surfaces()
	if destination_bracket:
		destination_bracket.visible = false

var path_update_timer: float = 0.0

# 1 tile roughly equals 0.006 units. Move 1 width per 10 seconds.
var speed_units_per_sec: float = 0.0006
var current_terrain_modifier: float = 1.0
var is_seaborne: bool = false

# Air Unit State
var is_air_ready: bool = true
var _last_air_ready: bool = true
var air_cooldown_timer: float = 0.0
var base_faction_color: Color = Color.BLACK

var path_mesh_instance: MeshInstance3D
var path_immediate_mesh: ImmediateMesh
var destination_bracket: Sprite3D



var engagement_line: MeshInstance3D
var engagement_mesh: ImmediateMesh


var hit_audio: AudioStreamPlayer
var flash_timer: float = 0.0
var combat_timer: float = 0.0

var faction_name: String = ""
var is_friendly: bool = false
var last_damage_time: float = 0.0

var entrenched: bool = false
var is_recovering: bool = false
var time_motionless: float = 0.0
var time_in_city: float = 0.0
var recovery_timer: float = 0.0
var is_detected: bool = false
var is_moving: bool = false

const TEC_MODIFIERS: Dictionary = {
	"Infantry": {
		"PLAINS": {"movement": 1.0, "defense": 1.0},
		"FOREST": {"movement": 0.5, "defense": 0.75},
		"JUNGLE": {"movement": 0.25, "defense": 0.5},
		"DESERT": {"movement": 0.5, "defense": 1.0},
		"MOUNTAINS": {"movement": 0.1, "defense": 0.5},
		"POLAR": {"movement": 0.25, "defense": 1.0},
		"CITY": {"movement": 1.0, "defense": 0.5},
		"DOCKS": {"movement": 1.0, "defense": 0.5},
		"OCEAN": {"movement": 3.0, "defense": 1.0},
		"DEEP_OCEAN": {"movement": 3.0, "defense": 1.0},
		"COAST": {"movement": 3.0, "defense": 1.0},
		"LAKE": {"movement": 3.0, "defense": 1.0},
		"WASTELAND": {"movement": 1.0, "defense": 1.0},
		"RUINS": {"movement": 1.0, "defense": 1.0}
	},
	"Armor": {
		"PLAINS": {"movement": 3.75, "defense": 1.0},
		"FOREST": {"movement": 1.25, "defense": 0.75},
		"JUNGLE": {"movement": 0.625, "defense": 0.75},
		"DESERT": {"movement": 2.5, "defense": 1.0},
		"MOUNTAINS": {"movement": 0.25, "defense": 1.0},
		"POLAR": {"movement": 0.625, "defense": 1.0},
		"CITY": {"movement": 2.5, "defense": 0.75},
		"DOCKS": {"movement": 2.5, "defense": 0.75},
		"OCEAN": {"movement": 3.0, "defense": 1.0},
		"DEEP_OCEAN": {"movement": 3.0, "defense": 1.0},
		"COAST": {"movement": 3.0, "defense": 1.0},
		"LAKE": {"movement": 3.0, "defense": 1.0},
		"WASTELAND": {"movement": 2.5, "defense": 1.0},
		"RUINS": {"movement": 2.5, "defense": 1.0}
	},
	"Cruiser": {
		"PLAINS": {"movement": 0.0, "defense": 1.0},
		"FOREST": {"movement": 0.0, "defense": 1.0},
		"JUNGLE": {"movement": 0.0, "defense": 1.0},
		"DESERT": {"movement": 0.0, "defense": 1.0},
		"MOUNTAINS": {"movement": 0.0, "defense": 1.0},
		"POLAR": {"movement": 0.0, "defense": 1.0},
		"CITY": {"movement": 0.0, "defense": 0.75},
		"DOCKS": {"movement": 5.0, "defense": 0.75},
		"OCEAN": {"movement": 5.0, "defense": 1.0},
		"DEEP_OCEAN": {"movement": 5.0, "defense": 1.0},
		"COAST": {"movement": 5.0, "defense": 1.0},
		"LAKE": {"movement": 5.0, "defense": 1.0},
		"WASTELAND": {"movement": 0.0, "defense": 1.0},
		"RUINS": {"movement": 5.0, "defense": 1.0}
	},
	"Submarine": {
		"PLAINS": {"movement": 0.0, "defense": 1.0},
		"FOREST": {"movement": 0.0, "defense": 1.0},
		"JUNGLE": {"movement": 0.0, "defense": 1.0},
		"DESERT": {"movement": 0.0, "defense": 1.0},
		"MOUNTAINS": {"movement": 0.0, "defense": 1.0},
		"POLAR": {"movement": 0.0, "defense": 1.0},
		"CITY": {"movement": 0.0, "defense": 0.75},
		"DOCKS": {"movement": 4.0, "defense": 0.75},
		"OCEAN": {"movement": 4.0, "defense": 1.0},
		"DEEP_OCEAN": {"movement": 4.0, "defense": 1.0},
		"COAST": {"movement": 4.0, "defense": 1.0},
		"LAKE": {"movement": 4.0, "defense": 1.0},
		"WASTELAND": {"movement": 0.0, "defense": 1.0},
		"RUINS": {"movement": 4.0, "defense": 1.0}
	}
}

func _init() -> void:
	add_to_group("units")
	# Keep base references intact before materials
	# Wait for children to instantiate before running update_render_priorities
	# Setup Sprite
	sprite = Sprite3D.new()
	var tex = load("res://src/assets/extracted_sprite.png") as Texture2D
	if tex:
		sprite.texture = tex
	else:
		push_error("GlobeUnit: Failed to load extracted_sprite.png")
	
	# Initialize with a default, but GlobeView will override this with exact local map geometry
	set_sizing(0.006)
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# Ensure the unit consistently renders above the path arrow and cities
	sprite.render_priority = 10
	add_child(sprite)
	
	_update_texture()
	
	# Setup Clickable Area
	click_area = Area3D.new()
	click_area.input_ray_pickable = false
	collision_shape = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	# Size is roughly half the width of the sprite
	shape.radius = 0.0092 
	collision_shape.shape = shape
	click_area.add_child(collision_shape)
	add_child(click_area)



	# Setup Path Drawing
	path_mesh_instance = MeshInstance3D.new()
	path_immediate_mesh = ImmediateMesh.new()
	path_mesh_instance.mesh = path_immediate_mesh
	
	if not _shared_materials.has("path_mat"):
		var path_mat = StandardMaterial3D.new()
		# Glowing Yellow/White
		path_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		path_mat.vertex_color_use_as_albedo = true
		path_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		path_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		path_mat.use_point_size = false
		path_mat.no_depth_test = true
		path_mat.render_priority = 6
		_shared_materials["path_mat"] = path_mat
	
	path_mesh_instance.material_override = _shared_materials["path_mat"]
	path_mesh_instance.top_level = true
	add_child(path_mesh_instance)
	
	# Setup Destination Bracket
	destination_bracket = Sprite3D.new()
	var bracket_tex = load("res://src/assets/target_bracket.png") as Texture2D
	if bracket_tex:
		destination_bracket.texture = bracket_tex
		if not _shared_materials.has("tb_mat"):
			var tb_mat = StandardMaterial3D.new()
			tb_mat.albedo_texture = bracket_tex
			tb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			tb_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
			tb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tb_mat.no_depth_test = true
			tb_mat.render_priority = 20
			_shared_materials["tb_mat"] = tb_mat
		destination_bracket.material_override = _shared_materials["tb_mat"]
		# Initial sizing will be overridden by set_sizing() later based on map data
		destination_bracket.pixel_size = (0.006 * 3.0) / 128.0
	
	destination_bracket.visible = false
	destination_bracket.top_level = true
	add_child(destination_bracket)
	
	# Setup Engagement Line Drawing
	engagement_line = MeshInstance3D.new()
	engagement_mesh = ImmediateMesh.new()
	engagement_line.mesh = engagement_mesh
	
	if not _shared_materials.has("eng_mat"):
		var eng_mat = StandardMaterial3D.new()
		eng_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		eng_mat.albedo_color = Color(1.0, 0.2, 0.2, 0.8) # Red laser line
		eng_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		eng_mat.no_depth_test = true
		eng_mat.render_priority = 6
		_shared_materials["eng_mat"] = eng_mat
		
	engagement_line.material_override = _shared_materials["eng_mat"]
	engagement_line.top_level = true
	add_child(engagement_line)
	


	# Setup Hit Audio
	hit_audio = AudioStreamPlayer.new()
	var sfx = load("res://src/assets/audio/land-combat.mp3") as AudioStream
	if sfx:
		hit_audio.stream = sfx
	add_child(hit_audio)

func _update_health_bar() -> void:
	if sprite and sprite.material_override is ShaderMaterial:
		var pct = clamp(health / 100.0, 0.0, 1.0)
		sprite.set_instance_shader_parameter("health_pct", pct)

func set_sizing(tile_width: float) -> void:
	# Match the physical dimensions of the 3x3 City tiles exactly.
	# The base texture is 34x34 pixels, creating a base denominator of 34.
	# However, our Shader actively shrinks the visual texture down to create a 4px buffer (38/34 scale factor)
	# so we must multiply the pixel size by the reverse of that factor to make the VISUAL content perfectly align
	sprite.pixel_size = ((tile_width * 3.0) / 34.0) * (38.0 / 34.0)
	if destination_bracket:
		destination_bracket.pixel_size = (tile_width * 3.0) / 128.0
	
func _apply_shared_material(tex: Texture2D) -> void:
	if not tex: return
	var tex_id = tex.get_rid().get_id()
	var mat_key = "outline_mat_" + str(tex_id)
	
	if not _shared_materials.has("base_outline_shader"):
		var outline_shader = Shader.new()
		outline_shader.code = """
shader_type spatial;
render_mode unshaded, depth_test_disabled;
uniform sampler2D tex_albedo : source_color, filter_nearest;
instance uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform float outline_width = 2.0;

instance uniform bool use_bg_color = false;
instance uniform vec4 bg_color_override : source_color = vec4(0.0);

instance uniform float health_pct = 1.0;
instance uniform bool is_entrenched = false;
instance uniform bool is_engaged = false;
instance uniform float engagement_angle = 0.0;
instance uniform bool is_air_unit = false;
instance uniform bool is_air_ready = true;

void fragment() {
	// Scale UV to create padding inside the 38x38 quad for the 34x34 sprite
	float scale = 38.0 / 34.0;
	vec2 uv = (UV - 0.5) * scale + 0.5;
	
	// Default base color
	vec4 c = vec4(0.0);
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		c = texture(tex_albedo, uv);
		
		// Sea Transport: Replace white background with ocean color
		if (use_bg_color && c.r > 0.9 && c.g > 0.9 && c.b > 0.9 && c.a > 0.9) {
			c = bg_color_override;
		}
	}
	
	if (is_air_unit && !is_air_ready && c.a > 0.1) {
		float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		c.rgb = vec3(lum);
		c.a *= 0.5;
	}
	
	vec2 size = vec2(34.0, 34.0);
	float o = 0.0;
	
	for (float x = -outline_width; x <= outline_width; x += 1.0) {
		for (float y = -outline_width; y <= outline_width; y += 1.0) {
			vec2 offset = vec2(x, y);
			if (length(offset) > 0.0 && length(offset) <= outline_width + 0.5) {
				vec2 sample_uv = uv + offset / size;
				if (sample_uv.x >= 0.0 && sample_uv.x <= 1.0 && sample_uv.y >= 0.0 && sample_uv.y <= 1.0) {
					o = max(o, texture(tex_albedo, sample_uv).a);
				}
			}
		}
	}
	
	// Evaluate custom UI extensions
	// True bounds of the visual 34x34 icon map to uv (0.0 to 1.0)
	bool hit_ui = false;
	
	if (!is_air_unit) {
		// Health bar background: Top 4 pixels of the 34x34 area (UV.y = 0.0 is TOP). Flush against the absolute top edge.
		if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 0.12) {
			hit_ui = true;
			// Foreground bar logic
			if (uv.x <= health_pct) {
				if (health_pct > 0.5) {
					ALBEDO = vec3(0.0, 0.8, 0.2); // Green
				} else if (health_pct > 0.25) {
					ALBEDO = vec3(0.8, 0.8, 0.0); // Yellow
				} else {
					ALBEDO = vec3(0.9, 0.1, 0.1); // Red
				}
			} else {
				ALBEDO = vec3(0.2, 0.0, 0.0); // Background Red
			}
			ALPHA = 1.0;
		}
		
		// Entrenchment bar: Bottom 4 pixels (UV.y = 1.0 is BOTTOM). Flush against the absolute bottom edge.
		if (is_entrenched && !hit_ui && uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.88 && uv.y <= 1.0) {
			hit_ui = true;
			ALBEDO = vec3(0.0, 0.4, 0.0); // Dark green
			ALPHA = 1.0;
		}
		
		// Engagement arrow (Points towards target)
		if (is_engaged && !hit_ui) {
			vec2 center = vec2(0.2, 0.5); // Center on the left side
			vec2 p = uv - center;
			p.y = -p.y; // Standard Y-up orientation for math

			float ca = cos(engagement_angle);
			float sa = sin(engagement_angle);
			// Rotate local UV offset to match engagement_angle
			vec2 rp = vec2(ca * p.x + sa * p.y, -sa * p.x + ca * p.y);
			
			// Draw right-pointing generic arrow logic
			if (rp.x > -0.1 && rp.x < 0.1) {
				float y_lim = (0.1 - rp.x) * 0.6; // Scale down height
				if (abs(rp.y) <= y_lim) {
					hit_ui = true;
					ALBEDO = vec3(0.0, 0.0, 0.0); // Black arrow
					ALPHA = 1.0;
				}
			}
		}
	}
	
	if (!hit_ui) {
		if (c.a > 0.1) {
			ALBEDO = c.rgb;
			ALPHA = c.a;
		} else if (o > 0.1) {
			ALBEDO = outline_color.rgb;
			float out_alpha = 1.0;
			if (is_air_unit && is_air_ready) {
				out_alpha = (sin(TIME * 6.0) * 0.5) + 0.5;
			}
			ALPHA = out_alpha;
		} else {
			ALPHA = 0.0;
		}
	}
}
"""
		_shared_materials["base_outline_shader"] = outline_shader

	if not _shared_materials.has(mat_key):
		var outline_mat = ShaderMaterial.new()
		outline_mat.shader = _shared_materials["base_outline_shader"]
		outline_mat.resource_local_to_scene = false
		outline_mat.set_shader_parameter("tex_albedo", tex)
		_shared_materials[mat_key] = outline_mat
		
	sprite.material_override = _shared_materials[mat_key]
	
	# Initial instance uniforms setup
	sprite.set_instance_shader_parameter("health_pct", clamp(health/100.0, 0, 1))
	sprite.set_instance_shader_parameter("is_entrenched", entrenched)
	sprite.set_instance_shader_parameter("is_engaged", is_engaged)
	sprite.set_instance_shader_parameter("is_air_unit", unit_type == "Air")
	sprite.set_instance_shader_parameter("is_air_ready", is_air_ready)
	sprite.set_instance_shader_parameter("engagement_angle", 0.0)
	sprite.set_instance_shader_parameter("outline_color", base_faction_color)
	sprite.set_instance_shader_parameter("use_bg_color", is_seaborne)
	if is_seaborne:
		sprite.set_instance_shader_parameter("bg_color_override", Color("#1f679c"))

## Sets the outline color of the unit indicating faction alignment. Hex string e.g. "#FF0000"
func set_faction_color(hex_color: String) -> void:
	var c = Color(hex_color)
	base_faction_color = c
	if sprite and sprite.material_override is ShaderMaterial:
		sprite.set_instance_shader_parameter("outline_color", c)
	update_render_priorities()
	_update_air_readiness_visuals()

func _update_air_readiness_visuals() -> void:
	if unit_type != "Air":
		return
	if sprite and sprite.material_override is ShaderMaterial:
		sprite.set_instance_shader_parameter("is_air_ready", is_air_ready)
		if is_air_ready:
			sprite.set_instance_shader_parameter("outline_color", base_faction_color)
		else:
			var dull = base_faction_color.lerp(Color.BLACK, 0.5)
			sprite.set_instance_shader_parameter("outline_color", dull)

func set_selected(selected: bool) -> void:
	is_selected = selected
	_recalc_base_priority()
	update_render_priorities()

func _recalc_base_priority() -> void:
	if is_selected:
		base_render_priority = 50
	elif is_friendly:
		if (Time.get_ticks_msec() / 1000.0) - last_damage_time < 3.0:
			base_render_priority = 30
		else:
			base_render_priority = 20
	else:
		base_render_priority = 10

func set_visibility(is_vis: bool) -> void:
	var final_vis = is_vis
	if unit_type.capitalize() == "Submarine" and not is_detected:
		final_vis = false
		
	var is_local_owned = is_vis
	if multiplayer.has_multiplayer_peer():
		var id = multiplayer.get_unique_id()
		if NetworkManager.players.has(id) and NetworkManager.players[id].has("faction"):
			var is_mine = (faction_name == NetworkManager.players[id]["faction"])
			is_local_owned = is_vis and is_mine
			if is_mine:
				final_vis = true
				
	sprite.visible = final_vis
	if path_mesh_instance:
		path_mesh_instance.visible = is_local_owned
	if destination_bracket:
		destination_bracket.visible = is_local_owned and target_position != null and current_position != null and current_position.distance_to(target_position) > 0.0001

func update_render_priorities() -> void:
	if sprite:
		sprite.render_priority = base_render_priority
		if sprite.material_override:
			sprite.material_override.render_priority = base_render_priority
	
	if path_mesh_instance and path_mesh_instance.material_override:
		path_mesh_instance.material_override.render_priority = base_render_priority - 1
		
	if engagement_line and engagement_line.material_override:
		engagement_line.material_override.render_priority = base_render_priority - 1

func spawn(pos: Vector3) -> void:
	if pos.is_zero_approx():
		push_error("GlobeUnit: Attempted to spawn unit at Vector3.ZERO")
		return
		
	current_position = pos.normalized() * radius
	target_position = current_position
	global_position = current_position
	
	# Point -Z axis straight into the core, meaning the +Z face (sprite) aims perfectly upwards from the surface
	look_at(Vector3.ZERO, Vector3.UP)
	
	_recalc_base_priority()
	update_render_priorities()

func set_target(pos: Vector3) -> void:
	movement_target_unit = null
	var p = get_parent()
	if unit_type.capitalize() != "Air" and p and p.get("map_data") != null and p.map_data.has_method("find_path"):
		current_path = p.map_data.find_path(current_position, pos, unit_type)
		print("DEBUG: Unit ", name, " computed find_path to ", pos, " and got path size: ", current_path.size())
		if current_path.size() > 0:
			target_position = current_path.pop_front()
		else:
			target_position = pos.normalized() * radius
	else:
		target_position = pos.normalized() * radius
		current_path.clear()
		print("DEBUG: Unit ", name, " skipping find_path because Air or missing map_data.")

func set_movement_target_unit(target: GlobeUnit) -> void:
	movement_target_unit = target
	path_update_timer = 2.0 # Force an immediate path update on next frame

func set_combat_target(target: GlobeUnit) -> void:
	if unit_type.capitalize() == "Air" or target.unit_type.capitalize() == "Air":
		return
		
	if unit_type.capitalize() == "Submarine" and target.unit_type.capitalize() not in ["Cruiser", "Submarine"] and not target.get("is_seaborne"):
		return
		
	# Block explicit retargeting lock-ons while we are already engaged!
	# The player or AI must have this unit break engagement (by running away) 
	# to organically re-acquire a new closest target, preventing combat flapping.
	if is_engaged and is_instance_valid(combat_target) and not combat_target.is_dead:
		return
		
	combat_target = target
	is_engaged = true
	if sprite and sprite.material_override is ShaderMaterial:
		sprite.set_instance_shader_parameter("is_engaged", true)
	# Reset timer so attacker has to wait 5 seconds for their first swing
	combat_timer = 0.0

func clear_combat_target() -> void:
	combat_target = null
	is_engaged = false
	if sprite and sprite.material_override is ShaderMaterial:
		sprite.set_instance_shader_parameter("is_engaged", false)
	combat_timer = 0.0
	if engagement_mesh:
		engagement_mesh.clear_surfaces()

func get_defense_modifier() -> float:
	var current_terrain = "PLAINS"
	var p = get_parent()
	if p and p.has_method("_get_tile_from_vector3"):
		var tile_id = p._get_tile_from_vector3(current_position)
		if p.get("city_tile_cache") != null and p.city_tile_cache.has(tile_id):
			var raw_terrain = "PLAINS"
			if p.get("map_data") != null:
				raw_terrain = p.map_data.get_terrain(tile_id)
			if raw_terrain == "OCEAN" or raw_terrain == "LAKE":
				current_terrain = "DOCKS"
			else:
				current_terrain = "CITY"
		elif p.get("map_data") != null:
			current_terrain = p.map_data.get_terrain(tile_id)
			
	var u_type = unit_type.capitalize()
	if not TEC_MODIFIERS.has(u_type):
		u_type = "Infantry"
		
	var defense_modifier = 1.0
	if TEC_MODIFIERS[u_type].has(current_terrain):
		defense_modifier = TEC_MODIFIERS[u_type][current_terrain]["defense"]
	
	if entrenched:
		defense_modifier *= 0.5
	
	# Ensure damage never goes negative
	return max(0.0, defense_modifier)

func take_damage(amount: float, attacker_name: String = "Unknown", is_raw: bool = false) -> void:
	if is_dead:
		return
		
	if not is_raw:
		amount *= get_defense_modifier()
	
	health -= amount
	_update_health_bar()
	
	if is_friendly:
		last_damage_time = Time.get_ticks_msec() / 1000.0
		_recalc_base_priority()
		update_render_priorities()
	
	# Flash orange
	sprite.modulate = Color(1.0, 0.5, 0.0)
	flash_timer = 0.1
	
	if hit_audio and not hit_audio.playing:
		hit_audio.play()
		
	if health <= 0.0:
		is_dead = true
		clear_combat_target()
		
		if ConsoleManager != null and (NetworkManager == null or NetworkManager.is_host):
			var col = "#" + base_faction_color.to_html(false)
			var fac = "[outline_size=2][outline_color=#dddddd][color=" + col + "]" + faction_name + "[/color][/outline_color][/outline_size]"
			ConsoleManager.log_message(fac + " " + unit_type + " destroyed")
		
		if path_immediate_mesh:
			path_immediate_mesh.clear_surfaces()
		if engagement_mesh:
			engagement_mesh.clear_surfaces()
			
		var parent = get_parent()
		if parent:
			var death_node = Node3D.new()
			parent.add_child(death_node)
			death_node.global_position = global_position
			death_node.global_transform.basis = global_transform.basis
			
			var death_sprite = Sprite3D.new()
			var death_tex = load("res://src/assets/death.jpeg") as Texture2D
			if death_tex:
				death_sprite.texture = death_tex
				if not _shared_materials.has("d_mat"):
					var d_mat = StandardMaterial3D.new()
					d_mat.albedo_texture = death_tex
					d_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					d_mat.render_priority = 10
					d_mat.no_depth_test = true
					_shared_materials["d_mat"] = d_mat
				death_sprite.material_override = _shared_materials["d_mat"].duplicate()
				
				var expected_width = 34.0 * sprite.pixel_size
				death_sprite.pixel_size = expected_width / float(death_tex.get_width())
			
			death_node.add_child(death_sprite)
			
			var death_audio = AudioStreamPlayer.new()
			var death_sfx = load("res://src/assets/audio/death.mp3") as AudioStream
			if death_sfx:
				death_audio.stream = death_sfx
			death_audio.volume_db = 0.0
			death_audio.autoplay = true
			death_node.add_child(death_audio)
			
			# Register for horizon culling in GlobeView
			if parent.get("cullable_nodes") != null:
				parent.cullable_nodes.append(death_node)
			
			# 5s hold, then 1s fade out
			var tween = parent.get_tree().create_tween()
			tween.bind_node(death_node)
			tween.tween_interval(5.0)
			if death_sprite.material_override:
				var target_color = Color(1, 1, 1, 0)
				tween.tween_property(death_sprite.material_override, "albedo_color", target_color, 1.0)
			tween.tween_callback(death_node.queue_free)
			
		queue_free()

func _process(delta: float) -> void:
	var starting_position = current_position
	
	if is_friendly and base_render_priority == 30:
		if (Time.get_ticks_msec() / 1000.0) - last_damage_time >= 3.0:
			_recalc_base_priority()
			update_render_priorities()

	# Handle Damage Flash
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			sprite.modulate = Color(1.0, 1.0, 1.0)
			
	# Handle Air Unit Cooldown
	var old_ready = is_air_ready
	if unit_type == "Air" and not is_air_ready:
		var drop = delta
		var p = get_parent()
		if p and p.get("active_scenario") and p.active_scenario.has("factions"):
			var f_data = p.active_scenario["factions"].get(faction_name)
			if f_data and f_data.get("oil_shortage", false):
				drop = delta * 0.333333 # Increased cooldown by 200%
				
		air_cooldown_timer -= drop
		if air_cooldown_timer <= 0.0:
			is_air_ready = true
			air_cooldown_timer = 0.0
			
	if unit_type == "Air" and old_ready != is_air_ready:
		_update_air_readiness_visuals()
			
	if movement_target_unit != null:
		if is_instance_valid(movement_target_unit) and not movement_target_unit.is_dead:
			if movement_target_unit.current_position != null:
				path_update_timer += delta
				if path_update_timer >= 2.0:
					path_update_timer = 0.0
					var p = get_parent()
					if unit_type.capitalize() != "Air" and p and p.get("map_data") != null and p.map_data.has_method("find_path"):
						current_path = p.map_data.find_path(current_position, movement_target_unit.current_position.normalized() * radius, unit_type)
						if current_path.size() > 0:
							target_position = current_path.pop_front()
					else:
						target_position = movement_target_unit.current_position.normalized() * radius
		else:
			movement_target_unit = null
			if current_position != null:
				target_position = current_position
			current_path.clear()
			
	var in_motion = false
	if current_position != null and target_position != null and current_position.distance_to(target_position) > 0.0001:
		in_motion = true
		
		var is_local_owned = true
		if multiplayer.has_multiplayer_peer():
			var id = multiplayer.get_unique_id()
			if NetworkManager.players.has(id) and NetworkManager.players[id].has("faction"):
				is_local_owned = faction_name == NetworkManager.players[id]["faction"]
			
		if destination_bracket and is_local_owned and sprite.visible:
			var final_target = target_position
			if current_path.size() > 0:
				final_target = current_path.back()
			destination_bracket.position = final_target
			var up_vec = Vector3.UP
			var norm_target = final_target.normalized()
			if abs(norm_target.y) > 0.99:
				up_vec = Vector3.FORWARD
			destination_bracket.look_at(Vector3.ZERO, up_vec)
			destination_bracket.visible = true
	else:
		if destination_bracket:
			destination_bracket.visible = false
			
	var current_terrain = "PLAINS"
	var parent_map = get_parent()
	if parent_map and parent_map.has_method("_get_tile_from_vector3") and current_position != null:
		var tile_id = parent_map._get_tile_from_vector3(current_position)
		if parent_map.get("city_tile_cache") != null and parent_map.city_tile_cache.has(tile_id):
			var raw_terrain = "PLAINS"
			if parent_map.get("map_data") != null:
				raw_terrain = parent_map.map_data.get_terrain(tile_id)
			if raw_terrain == "OCEAN" or raw_terrain == "LAKE":
				current_terrain = "DOCKS"
			elif raw_terrain == "RUINS":
				current_terrain = "RUINS"
			else:
				current_terrain = "CITY"
		elif parent_map.get("map_data") != null:
			current_terrain = parent_map.map_data.get_terrain(tile_id)

	if current_terrain == "WASTELAND":
		health -= 5.0 * (delta / 30.0)
		if health <= 0.0:
			take_damage(9999.0) # reuse death flow
		is_recovering = false
		
	# Determine dynamic engagement radius based on unit size
	var my_range = 0.0165 if unit_type.capitalize() == "Cruiser" else 0.012
		
	# 1. Evaluate Current Combat Lock 
	if is_engaged:
		if is_instance_valid(combat_target) and not combat_target.is_dead:
			if current_position != null and combat_target.current_position != null:
				var target_range = 0.0165 if combat_target.unit_type.capitalize() == "Cruiser" else 0.012
				# Average the two engagement ranges to find exactly where they visually touch
				var engagement_threshold = (my_range + target_range) / 2.0
				
				var dist = current_position.distance_to(combat_target.current_position)
				if dist < engagement_threshold:
					# We have a valid overlap. Process combat.
					
					# Hard stop if we hit max overlap (center tile collision)
					if dist < (engagement_threshold * 0.9):
						var is_retreating = false
						if target_position != null and in_motion:
							var dist_target = target_position.distance_to(combat_target.current_position)
							if dist_target > dist:
								is_retreating = true
								
						if not is_retreating:
							in_motion = false
					
					# Calculate direction to target in local space
					var to_target = (combat_target.current_position - current_position).normalized()
					var local_x = global_transform.basis.x.dot(to_target)
					var local_y = global_transform.basis.y.dot(to_target)
					var angle_to_target = atan2(local_y, local_x)
					
					if sprite and sprite.material_override is ShaderMaterial:
						sprite.set_instance_shader_parameter("engagement_angle", angle_to_target)
					
					_draw_engagement_line()
					
					combat_timer += delta
					print("Combat Timer: ", combat_timer, " for ", self.name)
					if combat_timer >= 5.0:
						combat_timer -= 5.0
						
						var is_offline = (NetworkManager == null or not NetworkManager.multiplayer.has_multiplayer_peer())
						if is_offline or NetworkManager.is_host:
							var dmg = 15.0
							if unit_type.capitalize() == "Armor":
								dmg = 25.0
							elif unit_type.capitalize() in ["Cruiser", "Submarine"]:
								dmg = 30.0
								
							# Amphibious assault penalty for land units in sea transport
							if is_seaborne and unit_type.capitalize() not in ["Cruiser", "Submarine"]:
								if combat_target.unit_type.capitalize() in ["Cruiser", "Submarine"]:
									dmg = 10.0
								else:
									dmg *= 0.50
									
							# Suffer 2x damage from sea units if self is a sea unit attacking a land unit in sea transport
							if unit_type.capitalize() in ["Cruiser", "Submarine"] and combat_target.get("is_seaborne") and combat_target.unit_type.capitalize() not in ["Cruiser", "Submarine"]:
								dmg *= 2.0
								
							var final_dmg = dmg * combat_target.get_defense_modifier()
							if not is_offline:
								NetworkManager.rpc("sync_unit_damage", combat_target.name, final_dmg, self.name)
							else:
								combat_target.take_damage(final_dmg, self.name, true)
						
					# Defender advantage
					if not combat_target.is_engaged and not combat_target.is_dead:
						var tar_in_motion = combat_target.current_position.distance_to(combat_target.target_position) > 0.0001
						var target_fleeing = false
						if tar_in_motion:
							var my_dist = current_position.distance_to(combat_target.current_position)
							var target_dest_dist = current_position.distance_to(combat_target.target_position)
							if target_dest_dist > my_dist:
								target_fleeing = true
								
						if not target_fleeing:
							combat_target.set_combat_target(self)
							combat_target.combat_timer = 5.0
				else:
					# Target walked out of range. Drop the lock instantly.
					clear_combat_target()
		else:
			# Target was deleted/died. Drop the lock instantly.
			clear_combat_target()

	is_moving = in_motion

	# Evaluate Submarine Detection
	var previously_detected = is_detected
	if unit_type.capitalize() == "Submarine":
		if is_engaged:
			is_detected = true
		else:
			var newly_detected = is_detected
			if not has_meta("sub_timer"): set_meta("sub_timer", 0.0)
			var st = get_meta("sub_timer") + delta
			if st > 0.15:
				st = 0.0
				newly_detected = false
				var p = get_parent()
				var units_to_check = p.units_list if p and p.get("units_list") != null else get_tree().get_nodes_in_group("units")
				for other in units_to_check:
						if other != self and is_instance_valid(other) and other.get("is_dead") != true:
							var f_name = other.get("faction_name")
							if f_name != null and self.faction_name != "" and f_name != self.faction_name:
								var u_type = other.get("unit_type")
								if u_type != null and u_type.capitalize() in ["Cruiser", "Submarine"]:
									var c_pos = other.get("current_position")
									if c_pos != null and current_position.distance_to(c_pos) <= 0.024:
										if is_moving and not other.get("is_moving"):
											newly_detected = true
											break
			set_meta("sub_timer", st)
			is_detected = newly_detected

		if is_detected != previously_detected:
			set_visibility(true) # Force native cascade update when detection state toggles

	# 2. Passive Scan (if not engaged after Step 1 evaluation)
	if not is_engaged and not is_dead:
		var all_units = get_tree().get_nodes_in_group("units")
		for other in all_units:
			if other != self and is_instance_valid(other) and not other.is_dead:
				if other.faction_name != "" and self.faction_name != "" and other.faction_name != self.faction_name:
					if other.unit_type.capitalize() == "Air" or self.unit_type.capitalize() == "Air":
						continue
						
					if unit_type.capitalize() == "Submarine" and other.unit_type.capitalize() not in ["Cruiser", "Submarine"] and not other.get("is_seaborne"):
						continue
						
					var target_range = 0.0165 if other.unit_type.capitalize() == "Cruiser" else 0.012
					var engagement_threshold = (my_range + target_range) / 2.0
					
					if current_position.distance_to(other.current_position) < engagement_threshold:
						if in_motion:
							# Only engage if we are actively moving towards them, not running away
							var dist_now = current_position.distance_to(other.current_position)
							var dist_target = target_position.distance_to(other.current_position)
							if dist_target > dist_now:
								continue # Moving away from this specific enemy, don't re-engage
								
						set_combat_target(other)
						break
						
	var p = get_parent()
	var effective_terrain = "PLAINS"
	var u_type = unit_type.capitalize()
	if not TEC_MODIFIERS.has(u_type):
		u_type = "Infantry"
		
	if p and p.has_method("_get_tile_from_vector3"):
		var tile_id = p._get_tile_from_vector3(current_position)
		var terrain = p.map_data.get_terrain(tile_id)
		effective_terrain = terrain
		
		if p.get("city_tile_cache") != null and p.city_tile_cache.has(tile_id):
			if terrain == "OCEAN" or terrain == "LAKE":
				effective_terrain = "DOCKS"
			else:
				effective_terrain = "CITY"
		
		if effective_terrain in ["OCEAN", "LAKE", "DOCKS"]:
			_set_seaborne(true)
		else:
			_set_seaborne(false)

	# 3. Process Movement (if still slated to move after combat overrides)
	if in_motion:
		var angle = current_position.angle_to(target_position)
		var distance = current_position.distance_to(target_position)
		
		# Move at constant speed along the arc
		var step = (speed_units_per_sec * delta) / radius
		
		current_terrain_modifier = 1.0
		if TEC_MODIFIERS[u_type].has(effective_terrain):
			current_terrain_modifier = TEC_MODIFIERS[u_type][effective_terrain]["movement"]
			
		if p and p.get("active_scenario") and p.active_scenario.has("factions"):
			var f_data = p.active_scenario["factions"].get(faction_name)
			if f_data and f_data.get("oil_shortage", false):
				if u_type == "Infantry":
					current_terrain_modifier *= 0.5
				elif u_type == "Armor":
					current_terrain_modifier *= 0.333333
					
		step *= current_terrain_modifier
		
		if is_engaged:
			step *= 0.25 # Move at 25% speed while engaged
			
		var weight = min(step / angle, 1.0) if angle > 0 else 1.0
		
		# Look-ahead terrain check to prevent getting stuck inside impassable tiles
		var next_pos = current_position.slerp(target_position, weight).normalized() * radius
		var lookahead_terrain_modifier = 1.0
		
		if p and p.has_method("_get_tile_from_vector3"):
			var next_tile = p._get_tile_from_vector3(next_pos)
			var terrain = p.map_data.get_terrain(next_tile)
			var next_effective_terrain = terrain
			
			if p.get("city_tile_cache") != null and p.city_tile_cache.has(next_tile):
				if terrain == "OCEAN" or terrain == "LAKE":
					next_effective_terrain = "DOCKS"
				else:
					next_effective_terrain = "CITY"
					
			if TEC_MODIFIERS[u_type].has(next_effective_terrain):
				var mod = TEC_MODIFIERS[u_type][next_effective_terrain]["movement"]
				if mod <= 0.0:
					# Verify if the actual destination tile is valid to prevent corner-clipping false positives
					var target_tile = p._get_tile_from_vector3(target_position)
					var target_terr = p.map_data.get_terrain(target_tile)
					if p.get("city_tile_cache") != null and p.city_tile_cache.has(target_tile):
						target_terr = "DOCKS" if (target_terr == "OCEAN" or target_terr == "LAKE") else "CITY"
					if TEC_MODIFIERS[u_type].has(target_terr) and TEC_MODIFIERS[u_type][target_terr]["movement"] > 0.0:
						lookahead_terrain_modifier = 1.0 # Trust the valid destination map data over microscopic slerp collisions
					else:
						lookahead_terrain_modifier = mod
				else:
					lookahead_terrain_modifier = mod
					
		var terrain_blocked = (lookahead_terrain_modifier <= 0.0)
		var unit_blocked = false
		var blocking_unit_pos = Vector3.ZERO
		
		if not terrain_blocked:
			var all_units = get_tree().get_nodes_in_group("units")
			for other in all_units:
				if other != self and is_instance_valid(other) and not other.get("is_dead"):
					var target_type = other.get("unit_type")
					if target_type == null or target_type.capitalize() == "Air" or self.unit_type.capitalize() == "Air":
						continue
					
					var target_range = 0.0165 if target_type.capitalize() == "Cruiser" else 0.012
					var collision_threshold = (my_range + target_range) / 3.0
					
					if other.get("current_position") != null:
						var dist_next = next_pos.distance_to(other.get("current_position"))
						if dist_next < collision_threshold:
							var dist_now = current_position.distance_to(other.get("current_position"))
							# Only block if we are pushing CLOSER into their space
							if dist_next < dist_now:
								lookahead_terrain_modifier = 0.0
								unit_blocked = true
								blocking_unit_pos = other.get("current_position")
								break
					
		if lookahead_terrain_modifier <= 0.0:
			# Path is physically blocked by another unit or terrain. 
			# Implement lateral Obstruction Avoidance to slide left or right around the barrier natively.
			var slide_success = false
			var to_target = (target_position - current_position).normalized()
			var surface_normal = current_position.normalized()
			var right_vec = to_target.cross(surface_normal).normalized()
			
			for slide_dir in [1.0, -1.0]: # Try Right, then Left
				var slide_mag = step * 1.5 * slide_dir
				var try_pos = (current_position + (to_target * step * 0.5) + (right_vec * slide_mag)).normalized() * radius
				
				var s_mod = 1.0
				var t_id = p._get_tile_from_vector3(try_pos) if (p and p.has_method("_get_tile_from_vector3")) else -1
				if t_id != -1:
					var s_terr = p.map_data.get_terrain(t_id)
					var s_eff_terr = s_terr
					if p.get("city_tile_cache") != null and p.city_tile_cache.has(t_id):
						s_eff_terr = "DOCKS" if (s_terr == "OCEAN" or s_terr == "LAKE") else "CITY"
					if TEC_MODIFIERS[u_type].has(s_eff_terr):
						s_mod = TEC_MODIFIERS[u_type][s_eff_terr]["movement"]
				
				if s_mod > 0.0:
					var s_blocked = false
					var all_units = get_tree().get_nodes_in_group("units")
					for other in all_units:
						if other != self and is_instance_valid(other) and not other.get("is_dead"):
							var t_type = other.get("unit_type")
							if not t_type or t_type.capitalize() == "Air" or self.unit_type.capitalize() == "Air": continue
							var tr = 0.0165 if t_type.capitalize() == "Cruiser" else 0.012
							var c_thresh = (my_range + tr) / 3.0
							if other.get("current_position") != null:
								var d_next = try_pos.distance_to(other.get("current_position"))
								if d_next < c_thresh:
									var d_now = current_position.distance_to(other.get("current_position"))
									if d_next < d_now:
										s_blocked = true
										break
					if not s_blocked:
						current_position = try_pos
						slide_success = true
						break
			
			if not slide_success:
				in_motion = false # Halt here
				if terrain_blocked:
					# Fully blocked by impassable physical terrain (not just traffic), wipe orders completely
					target_position = current_position 
					current_path.clear()
				elif unit_blocked and p and p.get("map_data") != null and p.map_data.has_method("find_path"):
					# Traffic jam! Replan alternative route around the blockage.
					var final_dest = target_position
					if current_path.size() > 0:
						final_dest = current_path.back()
						
					var block_tile = p._get_tile_from_vector3(blocking_unit_pos) if p.has_method("_get_tile_from_vector3") else -1
					if block_tile != -1:
						var astar = p.map_data.naval_astar if u_type in ["Cruiser", "Submarine"] else p.map_data.land_astar
						if astar.has_point(block_tile) and not astar.is_point_disabled(block_tile):
							astar.set_point_disabled(block_tile, true)
							
							var new_path = p.map_data.find_path(current_position, final_dest, unit_type)
							if new_path.size() > 0:
								current_path = new_path
								target_position = current_path.pop_front()
								
							astar.set_point_disabled(block_tile, false)
		else:
			current_position = next_pos
			if current_path.size() > 0 and current_position.distance_to(target_position) <= 0.005:
				target_position = current_path.pop_front()
		
		if current_position.distance_to(_last_path_update_pos) > 0.002 or target_position != _last_target_update_pos:
			_draw_path(angle)
			_last_path_update_pos = current_position
			_last_target_update_pos = target_position
	else:
		current_terrain_modifier = 1.0
		# Evaluate terrain at organic rest to ensure graphics adhere.
		var u_type_low = unit_type.to_lower()
		var can_capture = (u_type_low == "infantry" or u_type_low == "armor")
		
		is_recovering = false
		# Evaluate city presence for Capture and Health Recovery
		if time_motionless > 0.0 and p and p.has_method("_get_tile_from_vector3"):
			var inside_city = false
			var current_tile = p._get_tile_from_vector3(current_position)
			
			if p.get("city_tile_cache") != null and p.city_tile_cache.has(current_tile):
				inside_city = true
				var c_name = p.city_tile_cache[current_tile]
				var c_faction = ""
				
				# Identify the current controlling faction of this city from the scenario dictionary
				if p.get("active_scenario") and p.active_scenario.has("factions"):
					for f_name in p.active_scenario["factions"].keys():
						if p.active_scenario["factions"][f_name].has("cities") and c_name in p.active_scenario["factions"][f_name]["cities"]:
							c_faction = f_name
							break
							
				time_in_city += delta
				if c_faction == self.faction_name:
					# Friendly City: Health Recovery Protocol
					if not is_dead and health < 100.0 and not is_engaged:
						if time_in_city >= 30.0:
							is_recovering = true
							recovery_timer += delta
							if recovery_timer >= 30.0:
								recovery_timer -= 30.0
								var is_offline = (NetworkManager == null or not NetworkManager.multiplayer.has_multiplayer_peer())
								if is_offline or NetworkManager.is_host:
									var hp_gain = min(10.0, 100.0 - health)
									if hp_gain > 0:
										if not is_offline:
											NetworkManager.rpc("sync_unit_health", name, health + hp_gain)
										else:
											health = health + hp_gain
											_update_health_bar()
						else:
							is_recovering = false
							recovery_timer = 0.0
					else:
						is_recovering = false
						recovery_timer = 0.0
				else:
					# Hostile City: Capture Protocol
					if can_capture:
						if time_in_city >= 5.0:
							time_in_city = 0.0
							var is_offline = (NetworkManager == null or not NetworkManager.multiplayer.has_multiplayer_peer())
							if is_offline or NetworkManager.is_host:
								if not is_offline:
									NetworkManager.rpc("capture_city", c_name, self.faction_name)
								else:
									if NetworkManager and NetworkManager.has_method("capture_city"):
										NetworkManager.capture_city(c_name, self.faction_name)
					else:
						time_in_city = 0.0 # Non-capturing units strictly reset clock upon evaluation
						
			if not inside_city:
				time_in_city = 0.0 # Reset if motionless inherently outside defined nodes
		else:
			time_in_city = 0.0 # Reset completely if actively in motion or evaluating blanks
		
		if current_position != null:
			p = get_parent()
			if p and p.has_method("_get_tile_from_vector3"):
				var tile_id = p._get_tile_from_vector3(current_position)
				var terrain = p.map_data.get_terrain(tile_id)
				effective_terrain = terrain
				
				if p.get("city_tile_cache") != null and p.city_tile_cache.has(tile_id):
					if terrain == "OCEAN" or terrain == "LAKE":
						effective_terrain = "DOCKS"
					else:
						effective_terrain = "CITY"
				
				if effective_terrain in ["OCEAN", "LAKE", "DOCKS"]:
					_set_seaborne(true)
				else:
					_set_seaborne(false)
						
		if path_immediate_mesh != null:
			path_immediate_mesh.clear_surfaces()
			
		# Explicitly snap to target position if we arrived organically without combat overrides
		if not is_engaged and current_position != null and target_position != null and current_position.distance_to(target_position) <= 0.0001:
			if current_path.size() > 0:
				target_position = current_path.pop_front()
			else:
				target_position = current_position
			
	# 4. Final Transform Output (Always attach visuals to math coordinates unconditionally)
	if current_position != null:
		global_position = current_position
		if current_position.length_squared() > 0.0001:
			look_at(Vector3.ZERO, Vector3.UP)

	var actively_trying_to_move = (current_position != null and target_position != null and current_position.distance_to(target_position) > 0.0001)

	var actually_moved = false
	if starting_position != null and current_position != null and starting_position != current_position:
		actually_moved = true
		
	if not actually_moved and not actively_trying_to_move:
		time_motionless += delta
		if time_motionless >= 30.0:
			if unit_type == "Infantry":
				entrenched = true
				if sprite and sprite.material_override is ShaderMaterial:
					sprite.set_instance_shader_parameter("is_entrenched", true)
	else:
		if actually_moved or actively_trying_to_move:
			time_motionless = 0.0
		if actually_moved:
			time_in_city = 0.0
		recovery_timer = 0.0
		is_recovering = false
		if entrenched:
			entrenched = false
			if sprite and sprite.material_override is ShaderMaterial:
				sprite.set_instance_shader_parameter("is_entrenched", false)

						
func _draw_engagement_line() -> void:
	if not engagement_mesh or not is_instance_valid(combat_target): return
	if current_position == null or combat_target.current_position == null: return
	
	engagement_mesh.clear_surfaces()
	engagement_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	# Draw line natively flush with surface
	var p1 = current_position.normalized() * radius
	var p2 = combat_target.current_position.normalized() * radius
	
	engagement_mesh.surface_add_vertex(p1)
	engagement_mesh.surface_add_vertex(p2)
	engagement_mesh.surface_end()

func _draw_path(angle: float) -> void:
	if current_position == null or target_position == null or path_immediate_mesh == null: return
	path_immediate_mesh.clear_surfaces()
	
	var path_nodes: Array[Vector3] = [current_position]
	if current_position.distance_to(target_position) > 0.0001:
		path_nodes.append(target_position)
	if current_path.size() > 0:
		path_nodes.append_array(current_path)
		
	if path_nodes.size() < 2: return
	
	path_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var path_width = 0.002
	var path_elevation = 1.0
	
	var left_verts = []
	var right_verts = []
	
	for i in range(path_nodes.size()):
		var p = path_nodes[i].normalized()
		var forward = Vector3.ZERO
		
		if i < path_nodes.size() - 1:
			var p_next = path_nodes[i+1].normalized()
			forward = (p_next - p).normalized()
		else:
			var p_prev = path_nodes[i-1].normalized()
			forward = (p - p_prev).normalized()
			
		var up = p
		var right = forward.cross(up).normalized()
		
		var left_point = (p * radius * path_elevation) - (right * path_width * 0.5)
		var right_point = (p * radius * path_elevation) + (right * path_width * 0.5)
		
		left_verts.append(left_point)
		right_verts.append(right_point)
		
	# Build Triangles for the main line body
	var total_segments = max(1, left_verts.size() - 1)
	for i in range(left_verts.size() - 1):
		var tl = left_verts[i]
		var tr = right_verts[i]
		var bl = left_verts[i+1]
		var br = right_verts[i+1]
		
		# Fade from 0.1 to 0.6 opacity based on segment index
		var color_start = base_faction_color
		color_start.a = lerp(0.1, 0.6, float(i) / float(total_segments))
		var color_end = base_faction_color
		color_end.a = lerp(0.1, 0.6, float(i+1) / float(total_segments))
		
		path_immediate_mesh.surface_set_color(color_start)
		path_immediate_mesh.surface_add_vertex(tl)
		path_immediate_mesh.surface_set_color(color_end)
		path_immediate_mesh.surface_add_vertex(bl)
		path_immediate_mesh.surface_set_color(color_start)
		path_immediate_mesh.surface_add_vertex(tr)
		
		path_immediate_mesh.surface_set_color(color_start)
		path_immediate_mesh.surface_add_vertex(tr)
		path_immediate_mesh.surface_set_color(color_end)
		path_immediate_mesh.surface_add_vertex(bl)
		path_immediate_mesh.surface_set_color(color_end)
		path_immediate_mesh.surface_add_vertex(br)

	# Draw arrowhead at the VERY END
	var arrow_width = 0.005 # Narrower wings
	var tip_p = path_nodes.back().normalized()
	var base_p = path_nodes[path_nodes.size() - 2].normalized()
	
	# Pull base_p slightly back from tip_p for visual scale
	var arrow_length = 0.012 # Fixed absolute length based on sphere radians
	var dist = tip_p.distance_to(base_p)
	var t = clamp(1.0 - (arrow_length / max(dist, 0.0001)), 0.1, 0.9)
	base_p = base_p.slerp(tip_p, t).normalized()
	
	var arrow_forward = (tip_p - base_p).normalized()
	var arrow_up = base_p
	var arrow_right = arrow_forward.cross(arrow_up).normalized()
	
	var arrow_base_left = (base_p * radius * path_elevation) - (arrow_right * arrow_width * 0.5)
	var arrow_base_right = (base_p * radius * path_elevation) + (arrow_right * arrow_width * 0.5)
	var arrow_tip = tip_p * radius * path_elevation
	
	var color_arrow = base_faction_color
	color_arrow.a = 0.8
	path_immediate_mesh.surface_set_color(color_arrow)
	path_immediate_mesh.surface_add_vertex(arrow_base_left)
	path_immediate_mesh.surface_set_color(color_arrow)
	path_immediate_mesh.surface_add_vertex(arrow_tip)
	path_immediate_mesh.surface_set_color(color_arrow)
	path_immediate_mesh.surface_add_vertex(arrow_base_right)
	
	path_immediate_mesh.surface_end()

func _set_seaborne(status: bool) -> void:
	if is_seaborne == status:
		return
	is_seaborne = status
	if sprite and sprite.material_override is ShaderMaterial:
		sprite.set_instance_shader_parameter("use_bg_color", is_seaborne)
		sprite.set_instance_shader_parameter("bg_color_override", Color("#1f679c"))

func set_air_unready(override_time: float = -1.0, add_time: float = 0.0) -> void:
	if unit_type != "Air":
		return
	is_air_ready = false
	if override_time > 0.0:
		air_cooldown_timer = override_time
	if add_time > 0.0:
		air_cooldown_timer += add_time
	_update_air_readiness_visuals()

