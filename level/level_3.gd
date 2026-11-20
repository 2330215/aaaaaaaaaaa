extends "res://level/level.gd"
## Arenas de defensa y combate aereo exclusivas del nivel 3.

@export var horde_duration: float = 30.0
@export var reinforcement_interval: float = 1.75
@export var intro_duration: float = 1.5
@export var horde_spawn_interval_min: float = 2.6
@export var horde_spawn_interval_max: float = 3.3
@export var max_horde_enemies: int = 10

const ARENA_WIDTH: float = 2048.0
const CAMERA_OFFSET := Vector2(0, -10)
const DEFENSE_FLOOR_Y: float = 449.0
const DEFENSE_BOUNDS := Rect2(0, -192, ARENA_WIDTH, 1088)
const SECOND_STAGE_WIDTH: float = 4480.0
const SECOND_STAGE_BOUNDS := Rect2(0, 1792, SECOND_STAGE_WIDTH, 1088)
const AIR_BOUNDS := Rect2(0, 3584, 1280, 704)
const AIR_SPAWN_MARGIN := 120.0
const PICKUP_RESPAWN_DELAY := 5.0
const APPLE_RESPAWN_DELAY := 10.0
const HAMBURGER_SCENE := preload("res://enemy/enemy.tscn")
const HORDE_SCENES: Array[PackedScene] = [
	preload("res://enemy/enemy_redbull.tscn"),
	HAMBURGER_SCENE,
	preload("res://enemy/enemy_papa.tscn"),
	preload("res://enemy/enemy_coca.tscn")
]
const COTTON_SCENE := preload("res://enemy/enemy_jefe_level3.tscn")
const INTRO_SCENE := preload("res://level/dialogue_box.tscn")

var _player_stages: Dictionary = {}

var _time_left: float
var _spawn_timer: float = 0.5
var _horde_enemies: Array[Enemy] = []
var _enemy_bag: Array[int] = []
var _horde_complete: bool = false
var _air_started: bool = false
var _cotton: Enemy
var _reinforcement_timer: float
var _reinforcement_side: int = 0
var _reinforcements: Array[Enemy] = []
var _status: Label
var _intro: DialogueBox


func _ready() -> void:
	_time_left = horde_duration
	_set_defense_npc_active(false)
	_reinforcement_timer = reinforcement_interval
	_build_defense_boundaries()
	$StageGateway1.set_enabled(false)
	$StageGateway3.set_enabled(false)
	$StageGateway3.hide()
	_build_status()
	for node in find_children("*", "Area2D"):
		var pickup := node as Area2D
		if not DEFENSE_BOUNDS.has_point(to_local(pickup.global_position)):
			continue
		if pickup is Coin or pickup is ShieldPickup or pickup is Apple:
			_watch_pickup(pickup)
	super._ready()


func _watch_pickup(pickup: Area2D) -> void:
	var animation := pickup.get_node("AnimationPlayer") as AnimationPlayer
	var delay := APPLE_RESPAWN_DELAY if pickup is Apple else PICKUP_RESPAWN_DELAY
	animation.animation_started.connect(_on_pickup_animation.bind(
		load(pickup.scene_file_path) as PackedScene, pickup.get_parent(), pickup.transform, delay))


func _defense_pickups_active() -> bool:
	if _time_left <= 0.0 or _horde_complete:
		return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player != null and to_local(player.global_position).y < SECOND_STAGE_BOUNDS.position.y


func get_stage_destinations() -> Array:
	return [
		{"pos": to_global(Vector2(128, 448)), "stage_index": 0, "cave": false, "sky": true, "label": "Defensa"},
		{"pos": $StageGateway1.target_position, "stage_index": 1, "cave": false, "sky": true, "label": "Bosque"},
		{"pos": $StageGateway2.target_position, "stage_index": 2, "cave": true, "sky": true, "label": "Jefe"}
	]


func _on_pickup_animation(animation: StringName, scene: PackedScene, parent: Node, placement: Transform2D, delay: float) -> void:
	if animation != &"picked" or not _defense_pickups_active():
		return
	await get_tree().create_timer(delay, false).timeout
	if not is_inside_tree() or not _defense_pickups_active():
		return
	if not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion():
		return
	var pickup := scene.instantiate() as Area2D
	pickup.transform = placement
	parent.add_child(pickup)
	_watch_pickup(pickup)


func _set_defense_npc_active(active: bool) -> void:
	var npc := $Trolelo as DialogueEnemy
	npc.visible = active
	npc.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	npc.input_pickable = active
	# También impedir diálogos automáticos y clics mientras sigue la defensa.
	var interaction := npc.get_node("InteractionArea") as Area2D
	interaction.set_deferred("monitoring", active)
	var click_area := npc.get_node_or_null("ClickArea") as Area2D
	if click_area:
		click_area.input_pickable = active


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
			_spawn_reinforcement()
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
		bounds.position.y += 8.0
		bounds.size.y -= 16.0
		# Aplicar el nuevo encuadre sin arrastrar la camara entre escenarios.
		player.camera.position_smoothing_enabled = false
		player.camera.limit_smoothed = false
		player.camera.offset = CAMERA_OFFSET
		_apply_camera_bounds(player.camera, bounds)
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
	if _time_left > 0.0 and _spawn_timer <= 0.0 and _living_count(_horde_enemies) < max_horde_enemies:
		if _enemy_bag.is_empty():
			_enemy_bag.assign([0, 1, 2, 3])
			_enemy_bag.shuffle()
		var kind: int = _enemy_bag.pop_back()
		var point := _horde_spawn_position()
		_horde_enemies.append(_spawn_enemy(HORDE_SCENES[kind], point))
		_spawn_timer = randf_range(horde_spawn_interval_min, horde_spawn_interval_max)
	var remaining := _living_count(_horde_enemies)
	var seconds := ceili(_time_left)
	_status.text = "DEFENSA  %d:%02d\nEnemigos: %d" % [seconds / 60, seconds % 60, remaining]
	if _time_left <= 0.0:
		_status.text = "Elimina a los enemigos restantes: %d" % remaining
		if remaining == 0:
			_horde_complete = true
			_set_defense_npc_active(true)
			_status.text = "¡Defensa completada!  Puerta abierta →"
			$StageGateway1.set_enabled(true)


func _horde_spawn_position() -> Vector2:
	var left := 120.0
	var right := ARENA_WIDTH - 120.0
	var top := -90.0
	if get_viewport().get_camera_2d():
		var inverse := get_viewport().get_canvas_transform().affine_inverse()
		var screen := get_viewport_rect()
		var top_left := to_local(inverse * screen.position)
		var bottom_right := to_local(inverse * screen.end)
		left = maxf(left, top_left.x + 80.0)
		right = maxf(left, minf(right, bottom_right.x - 80.0))
		top = minf(top, top_left.y - 96.0)
	return Vector2(randf_range(left, right), top)


func _spawn_enemy(scene: PackedScene, point: Vector2) -> Enemy:
	var enemy := scene.instantiate() as Enemy
	enemy.position = point
	enemy.detection_radius = 2000.0
	enemy.detection_height = 1000.0
	enemy.can_jump_down = scene == HAMBURGER_SCENE
	if "detection_range" in enemy:
		enemy.set("detection_range", 2000.0)
	add_child(enemy)
	return enemy


func _start_air_intro() -> void:
	if not await SceneFlow.wait_for_dialogue(self):
		return
	# Preparar el cielo antes de pausar, incluso al entrar por teletransporte.
	$ParallaxBackground.set_stage(2)
	$ParallaxBackground._process(0.0)
	_intro = INTRO_SCENE.instantiate() as DialogueBox
	add_child(_intro)
	get_tree().paused = true
	_intro.dialogue_finished.connect(_finish_air_intro, CONNECT_ONE_SHOT)
	_intro.start_dialogue("Algodón de azúcar", preload("res://enemy/portraits/enemy_jefe_level3.png"), preload("res://story/story_dialogues.gd").lines("algodon"))


func _finish_air_intro() -> void:
	if is_instance_valid(_cotton):
		return
	if is_instance_valid(_intro):
		_intro.queue_free()
		_intro = null
	get_tree().paused = false
	SceneFlow.release_dialogue(self)
	_cotton = COTTON_SCENE.instantiate() as Enemy
	_cotton.name = "CottonBoss"
	_cotton.position = Vector2(980, 3880)
	add_child(_cotton)
	_reinforcement_timer = reinforcement_interval


func _spawn_reinforcement() -> void:
	_reinforcements = _reinforcements.filter(func(enemy) -> bool: return is_instance_valid(enemy))
	var visible_area := AIR_BOUNDS
	if get_viewport().get_camera_2d():
		var screen_to_level := global_transform.affine_inverse() * get_viewport().get_canvas_transform().affine_inverse()
		visible_area = screen_to_level * get_viewport_rect()
	var along_edge := randf_range(0.18, 0.82)
	var point: Vector2
	match _reinforcement_side:
		0:
			point = Vector2(visible_area.end.x + AIR_SPAWN_MARGIN,
				visible_area.position.y + visible_area.size.y * along_edge)
		1:
			point = Vector2(visible_area.position.x + visible_area.size.x * along_edge,
				visible_area.position.y - AIR_SPAWN_MARGIN)
		_:
			point = Vector2(visible_area.position.x + visible_area.size.x * along_edge,
				visible_area.end.y + AIR_SPAWN_MARGIN)
	_reinforcement_side = (_reinforcement_side + 1) % 3
	_reinforcements.append(_spawn_enemy(HORDE_SCENES[0], point))


func _clear_reinforcements() -> void:
	for enemy in _reinforcements:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_reinforcements.clear()
