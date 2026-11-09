extends Node2D
## Defensa de los barcos: treinta segundos de oleadas y limpieza de supervivientes.

@export var duration: float = 30.0
@export var spawn_interval: float = 2.0
@export var max_enemies: int = 10
@export var spawn_points: Array[Vector2] = [Vector2(1160, 2330), Vector2(2060, 2320), Vector2(2940, 2330)]

const ENEMIES: Array[PackedScene] = [
	preload("res://enemy/enemy.tscn"),
	preload("res://enemy/enemy_coca.tscn"),
	preload("res://enemy/enemy_redbull.tscn")
]

var _time_left: float
var _spawn_timer: float = 0.75
var _enemies: Array[Enemy] = []
var _finished: bool = false
var _spawn_index: int = 0
var _status: Label
@onready var _gateway: StageGateway = get_parent().get_node("StageGateway2")


func _ready() -> void:
	_time_left = duration
	_gateway.set_enabled(false)
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	_status = Label.new()
	_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_status.offset_left = -260
	_status.offset_right = 260
	_status.offset_top = 52
	_status.offset_bottom = 116
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 5)
	hud.add_child(_status)
	_status.hide()


func _process(delta: float) -> void:
	var active := false
	var level := get_parent() as Node2D
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and node.get_world_2d() == get_world_2d():
			var height := level.to_local(node.global_position).y
			active = active or (height >= 1792.0 and height < 3584.0)
	_status.visible = active
	if not active or _finished or get_parent().get_node("StageGateway1")._triggered:
		return
	_update_battle(delta)


func _update_battle(delta: float) -> void:
	_time_left = maxf(0.0, _time_left - delta)
	_spawn_timer -= delta
	_enemies = _enemies.filter(func(enemy) -> bool: return is_instance_valid(enemy))
	for enemy in _enemies:
		# Un enemigo que cae al mar deja de contar para la defensa.
		if enemy.position.y > 2720.0:
			enemy.queue_free()
	var living := _living_count()
	if _time_left > 0.0 and _spawn_timer <= 0.0 and living < max_enemies:
		_spawn_enemy()
		_spawn_timer = spawn_interval
		living += 1
	var seconds := ceili(_time_left)
	_status.text = "BATALLA NAVAL  %d:%02d\nEnemigos: %d" % [seconds / 60, seconds % 60, living]
	if _time_left <= 0.0:
		_status.text = "Elimina a los enemigos restantes: %d" % living
		if living == 0:
			_finished = true
			_status.text = "¡Mar despejado!  A la isla →"
			_gateway.set_enabled(true)


func _living_count() -> int:
	var count := 0
	for enemy in _enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy._state != Enemy.State.DEAD:
			count += 1
	return count


func _spawn_enemy() -> void:
	var point := spawn_points[_spawn_index % spawn_points.size()]
	var kind := _spawn_index % ENEMIES.size()
	_spawn_index += 1
	var enemy := ENEMIES[kind].instantiate() as Enemy
	enemy.name = "NavalEnemy%d" % _spawn_index
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var screen_top := (get_parent() as Node2D).to_local(inverse * get_viewport_rect().position).y
	enemy.position = Vector2(point.x, minf(point.y - 100.0, screen_top - 96.0))
	enemy.detection_radius = 4000.0
	enemy.detection_height = 1000.0
	if "detection_range" in enemy:
		enemy.set("detection_range", 4000.0)
	get_parent().add_child(enemy)
	_enemies.append(enemy)
