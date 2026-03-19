extends CanvasLayer

var panel: PanelContainer
var output_log: RichTextLabel
var is_visible: bool = false
var max_lines: int = 200

func _ready() -> void:
	layer = 100 # High z-index to overlay on top of everything
	
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -1240
	panel.offset_top = -540
	panel.offset_right = -40
	panel.offset_bottom = -40
	
	# Add some semi-transparent background styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	panel.add_theme_stylebox_override("panel", style)
	
	output_log = RichTextLabel.new()
	output_log.bbcode_enabled = true
	output_log.scroll_following = true
	output_log.selection_enabled = true
	output_log.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Add padding
	output_log.offset_left = 10
	output_log.offset_top = 10
	output_log.offset_right = -10
	output_log.offset_bottom = -10
	
	output_log.add_theme_font_size_override("normal_font_size", 24)
	output_log.add_theme_font_size_override("bold_font_size", 24)
	output_log.add_theme_font_size_override("italics_font_size", 24)
	output_log.add_theme_font_size_override("bold_italics_font_size", 24)
	
	panel.add_child(output_log)
	add_child(panel)
	
	is_visible = true
	panel.show()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.physical_keycode == KEY_QUOTELEFT or event.physical_keycode == KEY_ASCIITILDE:
			toggle_console()
			get_viewport().set_input_as_handled()

func toggle_console() -> void:
	is_visible = !is_visible
	panel.visible = is_visible

func log_message(msg: String) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		rpc("sync_log_message", msg)
	else:
		sync_log_message(msg)

var match_time: float = 0.0

func _process(delta: float) -> void:
	match_time += delta
	
func get_elapsed_time_string() -> String:
	var hours = int(match_time) / 3600
	var minutes = (int(match_time) % 3600) / 60
	var seconds = int(match_time) % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

@rpc("any_peer", "call_local", "reliable")
func sync_log_message(msg: String) -> void:
	var time_str = get_elapsed_time_string()
	var formatted_msg = "[color=gray][" + time_str + "][/color] " + msg
	
	output_log.append_text(formatted_msg + "\n")
	print(formatted_msg.strip_edges()) # Also send to stdout for terminal
	
	if output_log.get_line_count() > max_lines:
		pass

	if panel.visible:
		output_log.scroll_to_line(output_log.get_line_count() - 1)
