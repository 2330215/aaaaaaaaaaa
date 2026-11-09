extends "res://level/level.gd"
## Arenas de defensa y combate aereo exclusivas del nivel 3.

@export var horde_duration: float = 30.0
@export var reinforcement_interval: float = 30.0
@export var intro_duration: float = 1.5

const ARENA_WIDTH: float = 1664.0
const DEFENSE_FLOOR_Y: float = 449.0
const DEFENSE_BOUNDS := Rect2(0, -192, 1664, 1088)
const SECOND_STAGE_BOUNDS := Rect2(0, 1792, 3840, 1088)
const AIR_BOUNDS := Rect2(0, 3584, 1280, 704)
const HORDE_SCENES: Array[PackedScene] = [
	preload("res://enemy/enemy_redbull.tscn"),
	preload("res://enemy/enemy.tscn"),
	preload("res://enemy/enemy_papa.tscn"),
	preload("res://enemy/enemy_coca.tscn")
]
const COTTON_SCENE := preload("res://enemy/enemy_jefe_level3.tscn")
const INTRO_SCENE := preload("res://level/dialogue_box.tscn")

var _player_stages: Dictionary = {}

var _time_left: float
var _spawn_timer: float = 1.0
var _horde_enemies: Array[Enemy] = []
var _enemy_bag: Array[int] = []
var _horde_complete: bool = false
var _air_started: bool = false
var _cotton: Enemy
var _reinforcement_timer: float
var _reinforcements: Array[Enemy] = []
var _status: Label
var _intro: DialogueBox


func _ready() -> void:
	_time_left = horde_duration
	_reinforcement_timer = reinforcement_interval
	_build_defense_boundaries()
	$StageGateway1.set_enabled(false)
	$StageGateway3.set_enabled(false)
	$StageGateway3.hide()
	_build_status()
	super._ready()


func _build_defense_boundaries() -> void:
	# Suelo continuo y paredes fisicas para que las hordas no empujen al
	# jugador fuera de la arena ni queden enemigos atrapados fuera de ella.
	var body := StaticBody2D.new()
	body.name = "DefenseBounds"
	body.collision_layer = 16
	body.collision_mask = 0
	for bounds in [Rect2(-64, -400, 64, 1400), Rect2(ARENA_WIDTH, -400, 64, 1400), Rect2(0, DEFENSE_FLOOR_Y, ARENA_WIDTH, 64)]:
		var collider := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = bounds.size
		collider.shape = rectangle
		collider.position = bounds.get_center()
		body.add_child(collider)
	add_child(body)


func _build_status() -> void:
	var hud := CanvasLayer.new()
	hud.name = "ArenaHUD"
	hud.layer = 10
	add_child(hud)
	_status = Label.new()
	_status.name = "HordeCounter"
	hud.add_child(_status)
	_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_status.offset_left = -220
	_status.offset_right = 220
	_status.offset_top = 52
	_status.offset_bottom = 116
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 5)


func _process(delta: float) -> void:
	super._process(delta)
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var height := to_local((players[0] as Node2D).global_position).y
	_status.visible = height < 1792.0
	if height < 1792.0 and not _horde_complete:
		_update_horde(delta)
	if height >= AIR_BOUNDS.position.y and not _air_started and not $StageGateway2._triggered:
		_air_started = true
		_start_air_intro()
	if is_instance_valid(_cotton) and _cotton._state != Enemy.State.DEAD and height >= AIR_BOUNDS.position.y:
		_reinforcement_timer -= delta
		if _reinforcement_timer <= 0.0:
			_spawn_reinforcements()
			_reinforcement_timer = reinforcement_interval
	elif is_instance_valid(_cotton) and _cotton._state == Enemy.State.DEAD:
		_clear_reinforcements()


func _physics_process(_delta: float) -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or player._is_dead:
			continue
		var point := to_local(player.global_position)
		if point.y < 1792.0:
			point.x = clampf(point.x, 48.0, ARENA_WIDTH - 48.0)
			var feet: Rect2 = player.collision_shape.global_transform * player.collision_shape.shape.get_rect()
			var floor_height := DEFENSE_FLOOR_Y - (feet.end.y - player.global_position.y)
			if point.y > floor_height:
				point.y = floor_height
				player.velocity.y = minf(0.0, player.velocity.y)
			player.global_position = to_global(point)
		elif point.y >= AIR_BOUNDS.position.y:
			point = point.clamp(AIR_BOUNDS.position + Vector2(60, 60), AIR_BOUNDS.end - Vector2(60, 60))
			player.global_position = to_global(point)
	for enemy in _horde_enemies:
		if not is_instance_valid(enemy) or enemy._state == Enemy.State.DEAD:
			continue
		var collider := enemy.get_node("CollisionShape2D") as CollisionShape2D
		var bounds: Rect2 = collider.global_transform * collider.shape.get_rect()
		var left_margin := enemy.global_position.x - bounds.position.x + 2.0
		var right_margin := bounds.end.x - enemy.global_position.x + 2.0
		enemy.position.x = clampf(enemy.position.x, left_margin, ARENA_WIDTH - right_margin)
		if enemy.scene_file_path != HORDE_SCENES[0].resource_path:
			var floor_height := DEFENSE_FLOOR_Y - (bounds.end.y - enemy.global_position.y)
			if enemy.position.y > floor_height:
				enemy.position.y = floor_height
				enemy.velocity.y = minf(0.0, enemy.velocity.y)


func _setup_camera() -> void:
	super._setup_camera()
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or player.get_world_2d() != get_world_2d():
			continue
		var height := to_local(player.global_position).y
		var stage := 2 if height >= AIR_BOUNDS.position.y else (1 if height >= 1792.0 else 0)
		var changed_stage: bool = _player_stages.get(player, stage) != stage
		_player_stages[player] = stage
		var bounds := DEFENSE_BOUNDS
		if height >= AIR_BOUNDS.position.y:
			bounds = AIR_BOUNDS
		elif height >= 1792.0:
			bounds = SECOND_STAGE_BOUNDS
		# Ocultar las uniones exteriores de los tiles incluso con redondeo de pixeles.
		bounds = bounds.grow(-8.0)
		var viewport_size := player.get_viewport_rect().size
		var zoom := maxf(0.7, maxf(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y))
		player.camera.zoom = Vector2.ONE * zoom
		# Aplicar el nuevo encuadre sin arrastrar la camara entre escenarios.
		player.camera.position_smoothing_enabled = false
		player.camera.limit_smoothed = false
		player.camera.limit_left = roundi(to_global(bounds.position).x - player.camera.offset.x)
		player.camera.limit_top = roundi(to_global(bounds.position).y - player.camera.offset.y)
		player.camera.limit_right = roundi(to_global(bounds.end).x - player.camera.offset.x)
		player.camera.limit_bottom = roundi(to_global(bounds.end).y - player.camera.offset.y)
		if changed_stage:
			player.velocity = Vector2.ZERO
			player.camera.reset_smoothing()
			player.camera.force_update_scroll()
			$ParallaxBackground.set_stage(stage)



func _living_count(enemies: Array[Enemy]) -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy._state != Enemy.State.DEAD:
			count += 1
	return count


func _update_horde(delta: float) -> void:
	_time_left = maxf(0.0, _time_left - delta)
	_spawn_timer -= delta
	_horde_enemies = _horde_enemies.filter(func(enemy) -> bool: return is_instance_valid(enemy))
	if _time_left > 0.0 and _spawn_timer <= 0.0 and _living_count(_horde_enemies) < 10:
		if _enemy_bag.is_empty():
			_enemy_bag.assign([0, 1, 2, 3])
			_enemy_bag.shuffle()
		var kind: int = _enemy_bag.pop_back()
		var point := _horde_spawn_position()
		_horde_enemies.append(_spawn_enemy(HORDE_SCENES[kind], point))
		_spawn_timer = randf_range(2.5, 4.0)
	var remaining := _living_count(_horde_enemies)
	var seconds := ceili(_time_left)
	_status.text = "DEFENSA  %d:%02d\nEnemigos: %d" % [seconds / 30, seconds % 30, remaining]
	if _time_left <= 0.0:
		_status.text = "Elimina a los enemigos restantes: %d" % remaining
		if remaining == 0:
			_horde_complete = true
			_status.text = "¡Defensa completada!  Puerta abierta →"
			$StageGateway1.set_enabled(true)


func _horde_spawn_position() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera:
		var half_width := get_viewport_rect().size.x / camera.zoom.x * 0.5
		var center := to_local(camera.get_screen_center_position())
		var sides: Array[float] = []
		if center.x - half_width > 160.0:
			sides.append(center.x - half_width - 80.0)
		if center.x + half_width < ARENA_WIDTH - 160.0:
			sides.append(center.x + half_width + 80.0)
		if not sides.is_empty():
			return Vector2(sides.pick_random(), 280)
	# Si toda la arena es visible, entran desde el cielo dentro de las paredes.
	return Vector2(randf_range(120, ARENA_WIDTH - 120), -90)


func _spawn_enemy(scene: PackedScene, point: Vector2) -> Enemy:
	var enemy := scene.instantiate() as Enemy
	enemy.position = point
	enemy.detection_radius = 2000.0
	enemy.detection_height = 1000.0
	if "detection_range" in enemy:
		enemy.set("detection_range", 2000.0)
	add_child(enemy)
	return enemy


func _start_air_intro() -> void:
	# Preparar el cielo antes de pausar, incluso al entrar por teletransporte.
	$ParallaxBackground.set_stage(2)
	$ParallaxBackground._process(0.0)
	_intro = INTRO_SCENE.instantiate() as DialogueBox
	add_child(_intro)
	get_tree().paused = true
	_intro.dialogue_finished.connect(_finish_air_intro, CONNECT_ONE_SHOT)
	_intro.start_dialogue("ALGODÓN DE AZÚCAR", null, [""])
	await get_tree().create_timer(intro_duration, true).timeout
	if is_instance_valid(_intro):
		_finish_air_intro()


func _finish_air_intro() -> void:
	if is_instance_valid(_cotton):
		return
	if is_instance_valid(_intro):
		_intro.queue_free()
		_intro = null
	get_tree().paused = false
	_cotton = COTTON_SCENE.instantiate() as Enemy
	_cotton.name = "CottonBoss"
	_cotton.position = Vector2(980, 3880)
	add_child(_cotton)
	_reinforcement_timer = reinforcement_interval


func _spawn_reinforcements() -> void:
	if not is_instance_valid(_cotton) or _cotton._state == Enemy.State.DEAD:
		return
	for index in range(3):
		var angle := randf_range(0.0, TAU)
		var point := _cotton.position + Vector2.from_angle(angle) * randf_range(140, 220)
		point = point.clamp(AIR_BOUNDS.position + Vector2(100, 100), AIR_BOUNDS.end - Vector2(100, 100))
		_reinforcements.append(_spawn_enemy(HORDE_SCENES[0], point))


func _clear_reinforcements() -> void:
	for enemy in _reinforcements:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_reinforcements.clear()
