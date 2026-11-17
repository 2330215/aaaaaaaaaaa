extends Node

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	# No usar la partida real durante las pruebas.
	GameState.save_path = "res://../tmp/player_menu_progress.cfg"
	RecipeCollection.save_path = "res://../tmp/player_menu_recipes.cfg"
	GameState._level_timer_running = false
	var pause_menu := preload("res://gui/pause_menu_singleplayer.tscn").instantiate()
	add_child(pause_menu)
	get_tree().paused = true
	pause_menu.open()
	pause_menu.main_options.get_node("CollectiblesButton").pressed.emit()
	check(not pause_menu.visible, "El menu debe cerrarse al abrir Coleccionables")
	check(is_instance_valid(RecipeCollection._notebook), "Debe abrirse la libreta")
	check(RecipeCollection._notebook.get_parent() == self, "La libreta debe vivir fuera del menu oculto")
	check(get_tree().paused, "La libreta debe mantener la partida pausada")
	RecipeCollection._notebook.free()
	check(not get_tree().paused, "Al cerrar la libreta debe reanudarse la partida")
	pause_menu.open()
	check(pause_menu.visible, "El menu debe poder volver a abrirse")
	pause_menu.free()

	GameState.begin_level(1)
	var player := preload("res://player/player.tscn").instantiate() as Player
	player.position = Vector2(400, 300)
	player.gravity = 0
	add_child(player)
	player._invincible = true
	var enemy := preload("res://enemy/enemy_redbull.tscn").instantiate() as Enemy
	enemy.position = Vector2(400, 400)
	add_child(enemy)
	enemy.set_physics_process(false)
	for skin in [Player.CharacterSkin.ROBOT, Player.CharacterSkin.GLOBO]:
		player.set_skin(skin)
		player.position = Vector2(400, 300)
		player.velocity = Vector2.ZERO
		for direction in [-1.0, 1.0]:
			enemy.position = Vector2(400, 300 - direction * 100)
			for step in range(45):
				enemy.velocity = Vector2(0, direction * 600)
				enemy.move_and_slide()
				await get_tree().physics_frame
			check(absf(player.position.y - 300) < 0.1, "Un enemigo no debe empujar verticalmente al jugador, skin=%d" % skin)
			check(not player.is_on_floor(), "El enemigo no debe ser una plataforma")

	# El contacto continua causando dano, incluso si ya estaban superpuestos.
	player.set_skin(Player.CharacterSkin.ROBOT)
	enemy.position = player.position
	player._invincible = false
	for frame in range(5):
		await get_tree().physics_frame
	check(player._is_dead, "El contacto debe iniciar la muerte")
	await get_tree().create_timer(1.0).timeout
	check(GameState.lives == 2 and not player._is_dead, "La muerte debe descontar una vida y reaparecer")
	check(player._invincible, "Debe conservarse la invencibilidad tras reaparecer")

	# El suelo real debe seguir sosteniendo al jugador.
	enemy.position = Vector2(1000, 1000)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 16
	floor_body.position = Vector2(400, 400)
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(600, 20)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	player.gravity = 2100
	for frame in range(90):
		await get_tree().physics_frame
	check(player.is_on_floor(), "El suelo real debe seguir funcionando")
	print("PLAYER_MENU_REGRESSION failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
