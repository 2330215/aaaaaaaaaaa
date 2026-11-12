extends AudioStreamPlayer
## Música persistente con fundidos independientes del volumen elegido en opciones.

const FADE_SECONDS: float = 1.0
const MENU_TRACK: AudioStream = preload("res://level/audio/menu.wav")
const LEVEL_TRACKS: Array[AudioStream] = [
	preload("res://level/audio/nivel1.wav"),
	preload("res://level/audio/nivel2.wav"),
	preload("res://level/audio/nivel3.wav"),
	preload("res://level/audio/nivel4.wav"),
	preload("res://level/audio/nivel5.wav")
]

var _fade: Tween
var _scene_id: int = 0
var _quitting: bool = false
var _ending: bool = false
var _switching: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	stop()
	stream = null
	volume_linear = 0.0
	finished.connect(_on_finished)


func _process(_delta: float) -> void:
	if _quitting:
		return
	var scene := get_tree().current_scene
	if scene != null and scene.get_instance_id() != _scene_id:
		_scene_id = scene.get_instance_id()
		var track: AudioStream = null
		if scene.scene_file_path == "res://gui/start_screen.tscn":
			track = MENU_TRACK
		elif scene is Game:
			var index: int = scene.level_number - 1
			if index >= 0 and index < LEVEL_TRACKS.size():
				track = LEVEL_TRACKS[index]
		_switch_track(track)
	# Suavizar también el final natural de cada canción antes de repetirla.
	if playing and not stream_paused and not _ending and stream != null:
		var remaining := stream.get_length() - get_playback_position()
		if remaining <= FADE_SECONDS and (_fade == null or not _fade.is_running()):
			_ending = true
			_fade_volume(0.0, maxf(remaining, 0.01))


func _fade_volume(target: float, duration: float = FADE_SECONDS) -> Tween:
	if _fade != null:
		_fade.kill()
	_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.tween_property(self, "volume_linear", target, duration)
	return _fade


func _switch_track(track: AudioStream) -> void:
	_switching = true
	stream_paused = false
	if playing and volume_linear > 0.0:
		var fade := _fade_volume(0.0)
		fade.tween_callback(_start_track.bind(track))
	else:
		if _fade != null:
			_fade.kill()
		_start_track(track)


func _start_track(track: AudioStream) -> void:
	_switching = false
	stop()
	stream = track
	_ending = false
	volume_linear = 0.0
	if stream != null:
		play()
		_fade_volume(1.0)


func _on_finished() -> void:
	if not _quitting and not _switching:
		_start_track(stream)


func set_music_paused(paused: bool) -> void:
	if paused:
		var fade := _fade_volume(0.0)
		fade.tween_callback(set.bind("stream_paused", true))
	else:
		stream_paused = false
		_fade_volume(1.0)


func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	AudioSettings.save_settings()
	stream_paused = false
	var fade := _fade_volume(0.0)
	fade.tween_callback(get_tree().quit)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
