extends Node
## Volumen global separado para la música y los efectos, guardado entre partidas.

const SETTINGS_PATH := "user://audio_settings.cfg"
const MUSIC_BUS := &"Music"
const EFFECTS_BUS := &"SFX"

var music_volume: float = 1.0
var effects_volume: float = 1.0

var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _save_timer == null:
		_save_timer = Timer.new()
		_save_timer.one_shot = true
		_save_timer.wait_time = 0.3
		_save_timer.timeout.connect(save_settings)
		add_child(_save_timer)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		music_volume = clampf(float(config.get_value("audio", "music", 1.0)), 0.0, 1.0)
		effects_volume = clampf(float(config.get_value("audio", "effects", 1.0)), 0.0, 1.0)
	_apply_volume(MUSIC_BUS, music_volume)
	_apply_volume(EFFECTS_BUS, effects_volume)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volume(MUSIC_BUS, music_volume)
	_save_timer.start()


func set_effects_volume(value: float) -> void:
	effects_volume = clampf(value, 0.0, 1.0)
	_apply_volume(EFFECTS_BUS, effects_volume)
	_save_timer.start()


func save_settings() -> void:
	_save_timer.stop()
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "effects", effects_volume)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("No se pudieron guardar los ajustes de audio: %s" % error_string(error))


func _apply_volume(bus_name: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_linear(index, value)
	AudioServer.set_bus_mute(index, is_zero_approx(value))
