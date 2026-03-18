extends Node

signal fade_finished

var bgm_player: AudioStreamPlayer
var tween: Tween

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Music"
	add_child(bgm_player)

func play_music(stream_path: String, volume_db: float = 0.0, fade_in_duration: float = 0.0) -> void:
	var stream = load(stream_path)
	if not stream:
		push_error("MusicManager: Failed to load stream %s" % stream_path)
		return
		
	if bgm_player.stream == stream and bgm_player.playing:
		return
		
	bgm_player.stream = stream
	bgm_player.volume_db = volume_db
	bgm_player.play()
	
	if tween:
		tween.kill()
		
	if fade_in_duration > 0.0:
		bgm_player.volume_db = -80.0
		tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", volume_db, fade_in_duration)

func fade_out(duration: float = 2.0) -> void:
	if not bgm_player.playing:
		fade_finished.emit()
		return
		
	if tween:
		tween.kill()
		
	tween = create_tween()
	tween.tween_property(bgm_player, "volume_db", -80.0, duration)
	tween.tween_callback(self._on_fade_out_complete)

func _on_fade_out_complete() -> void:
	bgm_player.stop()
	fade_finished.emit()
