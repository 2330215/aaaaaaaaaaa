extends Node
## GameState: Singleton que persiste el estado del juego entre muertes y niveles.
## Almacena qué special coins ya fueron activadas y las estadísticas del nivel.

signal boss_defeated()
signal life_lost(lives_remaining: int)
signal life_gained(lives_remaining: int)
signal lives_changed(lives_remaining: int)
signal game_over()
signal progress_changed()

## Conjunto de nombres de special coins que ya han sido usadas.
var used_special_coins: Dictionary = {}

## Vidas del jugador.
## MAX_LIVES  → vidas con las que empieza cada nivel.
## MAX_STORED_LIVES → tope máximo acumulable (p. ej. recogiendo manzanas).
## Modifica estos valores para ajustar la dificultad.
const MAX_LIVES: int = 3
const MAX_STORED_LIVES: int = 9
var lives: int = MAX_LIVES

## Nivel actual, usado para las estadísticas y la pantalla de victoria.
var current_level: int = 1

const TITLE_SCENE := "res://gui/start_screen.tscn"
const PROGRESS_PATH := "user://progress.cfg"
const SINGLEPLAYER_LEVELS: Array[String] = [
	"res://game_singleplayer.tscn", "res://game_singleplayer_level2.tscn",
	"res://game_singleplayer_level3.tscn", "res://game_singleplayer_level4.tscn",
	"res://game_singleplayer_level5.tscn"
]
const SPLITSCREEN_LEVELS: Array[String] = [
	"res://game_splitscreen.tscn", "res://game_splitscreen_level2.tscn"
]

var save_path: String = PROGRESS_PATH
var highest_completed_level: int = 0
var last_save_error: Error = OK
var last_played_scene: String = ""
var _suspended_game: Node
var _changing_scene: bool = false

var _level_elapsed: float = 0.0
var _level_timer_running: bool = false

var _shots_fired: int = 0
var _enemies_defeated: int = 0
var _coins_collected: int = 0
var _special_coins_used: int = 0
var _deaths: int = 0
var _boss_defeated: bool = false


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	highest_completed_level = 0
	last_played_scene = ""
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	var path := str(config.get_value("progress", "last_scene", ""))
	# Las partidas anteriores solo guardaban el último nivel visitado.
	var legacy_completed := maxi(0, level_for_scene(path) - 1)
	highest_completed_level = clampi(int(config.get_value("progress", "highest_completed", legacy_completed)), 0, SINGLEPLAYER_LEVELS.size())
	if can_play_scene(path):
		last_played_scene = path


func level_for_scene(path: String) -> int:
	var index := SINGLEPLAYER_LEVELS.find(path)
	if index < 0:
		index = SPLITSCREEN_LEVELS.find(path)
	return index + 1


func is_level_unlocked(level_number: int) -> bool:
	return level_number >= 1 and level_number <= mini(SINGLEPLAYER_LEVELS.size(), highest_completed_level + 1)


func can_play_scene(path: String) -> bool:
	return is_level_unlocked(level_for_scene(path))


func save_progress() -> Error:
	var config := ConfigFile.new()
	config.set_value("progress", "version", 2)
	config.set_value("progress", "highest_completed", highest_completed_level)
	config.set_value("progress", "last_scene", last_played_scene)
	var temporary := save_path + ".tmp"
	last_save_error = config.save(temporary)
	if last_save_error == OK:
		last_save_error = DirAccess.rename_absolute(temporary, save_path)
	if last_save_error != OK:
		push_warning("No se pudo guardar la partida local: %s" % error_string(last_save_error))
	return last_save_error


func remember_level(path: String) -> void:
	if not can_play_scene(path):
		return
	last_played_scene = path
	save_progress()
	progress_changed.emit()


func _complete_current_level() -> void:
	if not is_level_unlocked(current_level):
		return
	highest_completed_level = maxi(highest_completed_level, current_level)
	# Guardar la próxima etapa incluso si se cierra el juego en la victoria.
	if current_level < SINGLEPLAYER_LEVELS.size():
		if last_played_scene in SPLITSCREEN_LEVELS and current_level < SPLITSCREEN_LEVELS.size():
			last_played_scene = SPLITSCREEN_LEVELS[current_level]
		else:
			last_played_scene = SINGLEPLAYER_LEVELS[current_level]
	save_progress()
	progress_changed.emit()


func has_continue() -> bool:
	return is_instance_valid(_suspended_game) or can_play_scene(last_played_scene)


func return_to_title(keep_game: bool = true) -> void:
	if _changing_scene:
		return
	_changing_scene = true
	call_deferred("_return_to_title", keep_game)


func _return_to_title(keep_game: bool) -> void:
	var tree := get_tree()
	_level_timer_running = false
	AudioSettings.save_settings()
	_release_gameplay_input()
	if not keep_game:
		_discard_suspended_game()
	if keep_game and tree.current_scene:
		_discard_suspended_game()
		_suspended_game = tree.current_scene
		var pause_menu := _suspended_game.get_node_or_null("InterfaceLayer/PauseMenu")
		if pause_menu:
			pause_menu.hide()
		if _suspended_game.has_method("prepare_for_title"):
			_suspended_game.prepare_for_title()
		tree.root.remove_child(_suspended_game)
		tree.current_scene = null
	tree.paused = false
	Music.stream_paused = false
	var error := tree.change_scene_to_file(TITLE_SCENE)
	if error != OK:
		push_error("No se pudo abrir la pantalla de inicio: %s" % error_string(error))
	_changing_scene = false


func continue_game() -> void:
	if _changing_scene or not has_continue():
		return
	if not is_instance_valid(_suspended_game):
		start_level(last_played_scene)
		return
	_changing_scene = true
	call_deferred("_restore_game")


func _restore_game() -> void:
	var tree := get_tree()
	var title := tree.current_scene
	tree.root.remove_child(title)
	title.queue_free()
	var game := _suspended_game
	_suspended_game = null
	tree.root.add_child(game)
	tree.current_scene = game
	if game.has_method("resume_from_title"):
		game.resume_from_title()
	tree.paused = false
	Music.stream_paused = false
	_level_timer_running = true
	_changing_scene = false


func start_level(path: String) -> bool:
	if _changing_scene or not can_play_scene(path):
		return false
	_changing_scene = true
	call_deferred("_start_level", path)
	return true


func _start_level(path: String) -> void:
	_discard_suspended_game()
	used_special_coins.clear()
	_release_gameplay_input()
	get_tree().paused = false
	Music.stream_paused = false
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("No se pudo abrir el nivel: %s" % error_string(error))
	_changing_scene = false


func _release_gameplay_input() -> void:
	for suffix: String in ["", "_p1", "_p2"]:
		for action: String in ["move_left", "move_right", "jump", "move_down", "shoot", "special_attack"]:
			if InputMap.has_action(action + suffix):
				Input.action_release(action + suffix)


func _discard_suspended_game() -> void:
	if is_instance_valid(_suspended_game):
		_suspended_game.free()
	_suspended_game = null


func _exit_tree() -> void:
	_discard_suspended_game()


func _process(delta: float) -> void:
	if _level_timer_running:
		_level_elapsed += delta


## Reinicia las estadísticas al empezar un nivel nuevo.
func begin_level(level_number: int) -> void:
	current_level = level_number
	_level_elapsed = 0.0
	_level_timer_running = true
	_shots_fired = 0
	_enemies_defeated = 0
	_coins_collected = 0
	_special_coins_used = 0
	_deaths = 0
	_boss_defeated = false
	lives = MAX_LIVES
	lives_changed.emit(lives)


func record_shot(count: int = 1) -> void:
	_shots_fired += count


func record_enemy_defeated() -> void:
	_enemies_defeated += 1


func record_coin() -> void:
	_coins_collected += 1


func record_special_coin() -> void:
	_special_coins_used += 1


func record_death() -> void:
	_deaths += 1


## Descuenta una vida. Retorna true si quedan vidas, false si es Game Over.
func lose_life() -> bool:
	record_death()
	lives = max(0, lives - 1)
	lives_changed.emit(lives)
	life_lost.emit(lives)
	if lives <= 0:
		game_over.emit()
		return false
	return true


## Añade una vida (hasta MAX_STORED_LIVES). Usada por las manzanas.
func gain_life() -> void:
	lives = min(MAX_STORED_LIVES, lives + 1)
	lives_changed.emit(lives)
	life_gained.emit(lives)


## El jefe avisa una sola vez y detiene el cronómetro del nivel.
func notify_boss_defeated() -> void:
	if _boss_defeated:
		return
	_boss_defeated = true
	_level_timer_running = false
	_complete_current_level()
	boss_defeated.emit()


## Devuelve una copia lista para mostrar en la pantalla de victoria.
func get_level_stats() -> Dictionary:
	return {
		"level_number": current_level,
		"time_seconds": _level_elapsed,
		"rows": [
			{"label": "Tiempo del nivel", "value": _format_time(_level_elapsed)},
			{"label": "Balas disparadas", "value": str(_shots_fired)},
			{"label": "Enemigos eliminados", "value": str(_enemies_defeated)},
			{"label": "Monedas recogidas", "value": str(_coins_collected)},
			{"label": "Monedas especiales", "value": str(_special_coins_used)},
			{"label": "Muertes", "value": str(_deaths)},
		],
	}


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	var minutes := floori(float(total) / 60.0)
	return "%02d:%02d" % [minutes, total % 60]


func mark_coin_used(coin_name: String) -> void:
	used_special_coins[coin_name] = true


func is_coin_used(coin_name: String) -> bool:
	return used_special_coins.has(coin_name)


func reset() -> void:
	## Llama esto si reinicias el juego desde el principio.
	used_special_coins.clear()
	begin_level(1)


## Solo se llama después de confirmar el borrado en ajustes.
func erase_local_progress() -> Error:
	if _changing_scene:
		return ERR_BUSY
	# Conservar copias en memoria para restaurar si falla alguno de los borrados.
	var backups: Dictionary = {}
	for path: String in [save_path, RecipeCollection.save_path, save_path + ".tmp", RecipeCollection.save_path + ".tmp"]:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return FileAccess.get_open_error()
		backups[path] = file.get_buffer(file.get_length())
		file.close()
	var removed: Array[String] = []
	for path: String in backups:
		var error := DirAccess.remove_absolute(path)
		if error != OK:
			for previous: String in removed:
				var file := FileAccess.open(previous, FileAccess.WRITE)
				if file:
					file.store_buffer(backups[previous])
					file.close()
			return error
		removed.append(path)
	_discard_suspended_game()
	_release_gameplay_input()
	used_special_coins.clear()
	begin_level(1)
	_level_timer_running = false
	highest_completed_level = 0
	last_played_scene = ""
	last_save_error = OK
	RecipeCollection.clear_runtime_progress()
	progress_changed.emit()
	return OK


func erase_save_and_restart() -> Error:
	var error := erase_local_progress()
	if error == OK:
		return_to_title(false)
	return error
