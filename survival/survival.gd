extends Node2D
## Arena independiente: conserva el estado de la campaña al salir.
const TOTAL_WAVES := 10
const REWARD := "hotcakes_supervivencia"
const ENEMY_SCENE := preload("res://enemy/enemy.tscn")
const SESSION_FIELDS := ["lives", "current_level", "_level_elapsed", "_level_timer_running", "_shots_fired", "_enemies_defeated", "_coins_collected", "_special_coins_used", "_deaths", "_boss_defeated"]
var level_number := 0
var wave := 0
var pending := 0
var enemies: Array[Enemy] = []
var countdown := 4.0
var spawn_clock := 0.0
var finished := false
var intermission := true
var player: Player
var hud: Label
var banner: Label
var overlay: Control
var actions: VBoxContainer
var controls: CanvasLayer
var saved_session: Dictionary = {}
## Ajusta los límites visibles desde el Inspector al ampliar el mapa.
@export var camera_bounds := Rect2(0, -80, 1600, 860)
@export var fall_limit_y: float = 820.0
var _respawn_position := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key: String in SESSION_FIELDS:
		saved_session[key] = GameState.get(key)
	GameState.begin_level(0)
	get_tree().paused = false
	Music.stream_paused = false
	_setup_arena()
	_build_ui()
	GameState.game_over.connect(_lose)

func _exit_tree() -> void:
	for key: String in saved_session:
		GameState.set(key, saved_session[key])

func _setup_arena() -> void:
	# El escenario vive en survival.tscn; aquí solo se conectan sus nodos.
	player = $Level/Player as Player
	_respawn_position = player.global_position
	player.camera.limit_left = int(camera_bounds.position.x)
	player.camera.limit_right = int(camera_bounds.end.x)
	player.camera.limit_top = int(camera_bounds.position.y)
	player.camera.limit_bottom = int(camera_bounds.end.y)
	player.camera.position_smoothing_enabled = true
	controls = $Level/TouchControls as CanvasLayer
	controls.get_node("TrucosButton").hide()
	var stage_button: Button = controls.get("_stage_btn")
	stage_button.disabled = true
	stage_button.text = "Arena de supervivencia"

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = preload("res://gui/theme.tres").duplicate()
	root.theme.default_font = preload("res://gui/fonts/DejaVuSans.ttf")
	root.theme.set_font("font", "Button", root.theme.default_font)
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud = Label.new()
	hud.position = Vector2(18, 12)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_constant_override("outline_size", 6)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	banner = Label.new()
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_constant_override("outline_size", 6)
	banner.add_theme_font_size_override("font_size", 18)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 65
	overlay = CenterContainer.new()
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.09, 0.98)
	style.set_content_margin_all(20)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	panel.add_child(actions)
	overlay.hide()

func _process(delta: float) -> void:
	if finished or get_tree().paused:
		return
	for i in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[i]):
			enemies.remove_at(i)
	var alive := 0
	for enemy in enemies:
		if enemy._state != Enemy.State.DEAD:
			alive += 1
	hud.text = "SUPERVIVENCIA   •   Horda %d / 10   •   Vidas: %d\nEnemigos restantes: %d" % [wave, GameState.lives, pending + alive]
	if player.global_position.y > fall_limit_y:
		player.die_from_pit(_respawn_position)
	if intermission:
		countdown -= delta
		banner.text = "¡Muévete, salta y dispara!\nHorda %d en %d…" % [wave + 1, maxi(1, ceili(countdown))]
		if countdown <= 0:
			wave += 1
			pending = 3 + wave * 2
			spawn_clock = 0
			intermission = false
	else:
		banner.text = "Elimina a todos para avanzar"
		spawn_clock -= delta
		if pending > 0 and alive < mini(4 + wave, 10) and spawn_clock <= 0:
			if _spawn_enemy():
				pending -= 1
			spawn_clock = maxf(0.5, 1.9 - wave * 0.13)
		if pending == 0 and alive == 0 and not player._is_dead:
			if wave == TOTAL_WAVES:
				_win()
			else:
				intermission = true
				countdown = 4.0

func _spawn_enemy() -> bool:
	# Los Marker2D se pueden mover o duplicar desde el editor.
	var spots: Array[Vector2] = []
	for point in $Level.find_children("Spawn*", "Marker2D", true, false):
		spots.append(point.global_position)
	if spots.is_empty():
		push_warning("Supervivencia necesita al menos un Marker2D llamado Spawn...")
		return false
	var safe: Array[Vector2] = []
	var farthest: Vector2 = spots[0]
	for spot in spots:
		if spot.distance_to(player.global_position) > farthest.distance_to(player.global_position):
			farthest = spot
		if spot.distance_to(player.global_position) > 350:
			safe.append(spot)
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = $Level.to_local(safe.pick_random() if not safe.is_empty() else farthest)
	# Conservar los parámetros, animaciones, ataques y efectos de la escena original.
	$Level.add_child(enemy)
	enemies.append(enemy)
	return true

func _win() -> void:
	if finished:
		return
	finished = true
	RecipeCollection.unlock_recipe(REWARD)
	_show_panel("¡Completaste las 10 hordas!\nReceta: hot cakes de avena, plátano y huevo", true)

func _lose() -> void:
	if finished:
		return
	finished = true
	_show_panel("Fin de la partida\nLlegaste a la horda %d de 10" % wave, false)

func _show_panel(message: String, reward: bool) -> void:
	get_tree().paused = true
	controls.hide()
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	actions.add_child(label)
	if reward:
		_add_button("Ver receta", func(): RecipeCollection.open_notebook(self, REWARD))
		if RecipeCollection.last_save_error != OK:
			label.text += "\nNo se pudo guardar la receta en este dispositivo."
	if not finished:
		_add_button("Continuar", toggle_pause)
	_add_button("Reintentar desde la horda 1", _retry)
	_add_button("Volver al menú", _leave)
	overlay.show()

func _add_button(title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	actions.add_child(button)

func toggle_pause() -> void:
	if finished:
		return
	if get_tree().paused:
		get_tree().paused = false
		overlay.hide()
		controls.show()
	else:
		_show_panel("Supervivencia en pausa", false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func _retry() -> void:
	GameState._release_gameplay_input()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _leave() -> void:
	GameState._release_gameplay_input()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://gui/start_screen.tscn")

