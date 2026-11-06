class_name Game extends Node

## Nivel que representa esta escena y escena que se carga al pulsar AVANZAR.
## Los niveles finales dejan next_level_scene vacío.
@export var level_number: int = 1
@export_file("*.tscn") var next_level_scene: String = ""

const VICTORY_SCREEN_SCENE := preload("res://gui/victory_screen.tscn")
const GAME_OVER_SCREEN_SCENE := preload("res://gui/game_over_screen.tscn")

@onready var _pause_menu := $InterfaceLayer/PauseMenu as PauseMenu

var _victory_screen: VictoryScreen
var _game_over_screen: GameOverScreen
var _victory_active := false
var _game_over_active := false
var _music: AudioStreamPlayer


func _ready() -> void:
	GameState.begin_level(level_number)
	_apply_level_skin()

	_music = get_node_or_null("/root/Music") as AudioStreamPlayer

	_victory_screen = VICTORY_SCREEN_SCENE.instantiate() as VictoryScreen
	add_child(_victory_screen)
	_victory_screen.exit_requested.connect(_on_victory_exit_requested)
	_victory_screen.advance_requested.connect(_on_victory_advance_requested)
	GameState.boss_defeated.connect(_on_boss_defeated)
	GameState.game_over.connect(_on_game_over)

	_game_over_screen = GAME_OVER_SCREEN_SCENE.instantiate() as GameOverScreen
	add_child(_game_over_screen)

	_play_fade_in()


func _apply_level_skin() -> void:
	# Se aplica en cada entrada al nivel, tambien desde menus y al avanzar.
	var starting_skin: Player.CharacterSkin
	match level_number:
		1:
			starting_skin = Player.CharacterSkin.ROBOT # Frijol: nombre interno heredado.
		2:
			starting_skin = Player.CharacterSkin.AGUACATE
		3:
			starting_skin = Player.CharacterSkin.LIMONES
		_:
			return
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and is_ancestor_of(node):
			(node as Player).set_skin(starting_skin)


func apply_stage_skin() -> void:
	if level_number != 3:
		return
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and is_ancestor_of(node):
			var player := node as Player
			var level := get_node("Level") as Node2D
			var skin := Player.CharacterSkin.GLOBO if level.to_local(player.global_position).y >= 3584.0 else Player.CharacterSkin.LIMONES
			player.set_skin(skin)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or \
				mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_tree().root.set_input_as_handled()

	elif event.is_action_pressed(&"toggle_pause"):
		# No permitir reanudar el juego por detrás de la pantalla de victoria o de game over.
		if _victory_active or _game_over_active:
			return
		var tree := get_tree()
		tree.paused = not tree.paused
		if tree.paused:
			_pause_menu.open()
		else:
			_pause_menu.close()
		get_tree().root.set_input_as_handled()


func _on_boss_defeated() -> void:
	if _victory_active:
		return
	_victory_active = true

	# Congelamos las estadísticas en el instante en que cae el jefe.
	var stats := GameState.get_level_stats()

	# Dejar que termine la explosión/muerte del jefe antes de mostrar el resumen.
	await get_tree().create_timer(1.55).timeout
	if not is_inside_tree():
		return

	get_tree().paused = true
	_set_music_paused(true)
	_victory_screen.show_victory(stats, not next_level_scene.is_empty())


func _on_victory_exit_requested() -> void:
	# Todavía no existe un menú principal: salir cierra el juego.
	get_tree().quit()


func _on_victory_advance_requested() -> void:
	if next_level_scene.is_empty():
		return

	get_tree().paused = false
	_set_music_paused(false)
	_victory_active = false

	var error := get_tree().change_scene_to_file(next_level_scene)
	if error != OK:
		push_error("No se pudo cargar el siguiente nivel: %s" % next_level_scene)


func _on_game_over() -> void:
	if _game_over_active:
		return
	_game_over_active = true
	_set_music_paused(true)
	_game_over_screen.show_game_over()


func _set_music_paused(paused: bool) -> void:
	if _music:
		_music.stream_paused = paused


## Fundido desde negro al entrar al nivel (también sirve tras AVANZAR).
func _play_fade_in() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 300
	# Pausable: si el menú se abre durante el fade, este se detiene
	# y no se superpone sobre la UI del menú de pausa.
	fade_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fade_layer)

	var fade_rect := ColorRect.new()
	fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	await get_tree().process_frame

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_property(fade_rect, "color:a", 0.0, 0.8)
	await tween.finished
	fade_layer.queue_free()
