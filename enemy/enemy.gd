class_name Enemy extends CharacterBody2D


enum State {
	PATROL,   ## Patrulla cíclica de un lado a otro
	CHASE,    ## Persigue activamente al jugador
	DEAD,
}

const WALK_SPEED    = 90.0
const CHASE_SPEED   = 140.0
const JUMP_VELOCITY = -420.0   ## Solo se usa para saltar obstáculos

## Distancia a la que el enemigo detecta al jugador y empieza a perseguirlo.
@export var agro_range: float = 320.0
## Distancia a la que pierde al jugador y vuelve a patrullar.
@export var deagro_range: float = 500.0

## Si es verdadero el enemigo no se mueve (blanco de práctica).
@export var stationary: bool = false

var _state := State.PATROL
var facing_direction: float = 1.0

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var platform_detector:     RayCast2D = get_node_or_null(^"PlatformDetector")
@onready var floor_detector_left:   RayCast2D = get_node_or_null(^"FloorDetectorLeft")
@onready var floor_detector_right:  RayCast2D = get_node_or_null(^"FloorDetectorRight")
@onready var sprite      := $Sprite2D as Sprite2D
@onready var animation_player := $AnimationPlayer as AnimationPlayer


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	# Aplicar gravedad siempre
	velocity.y += gravity * delta

	if stationary:
		velocity.x = 0.0
		move_and_slide()
		return

	if not is_on_floor():
		move_and_slide()
		_update_sprite_direction()
		_update_animation()
		return

	# ── En el suelo ──────────────────────────────────────────────────────────
	var player := _find_closest_player()
	var dist := INF if player == null else global_position.distance_to(player.global_position)

	# Transiciones de estado
	if _state == State.PATROL and dist <= agro_range:
		_state = State.CHASE
	elif _state == State.CHASE and dist > deagro_range:
		_state = State.PATROL

	match _state:
		State.PATROL:
			_do_patrol()
		State.CHASE:
			_do_chase(player)

	# Saltar paredes
	if is_on_wall():
		velocity.y = JUMP_VELOCITY

	move_and_slide()
	_update_sprite_direction()
	_update_animation()


## Patrulla: camina en la dirección actual; invierte al chocar con pared o borde.
func _do_patrol() -> void:
	# Detectar borde: rayo izquierdo o derecho según la dirección actual
	var on_edge := false
	if facing_direction > 0.0 and floor_detector_right and is_on_floor():
		on_edge = not floor_detector_right.is_colliding()
	elif facing_direction < 0.0 and floor_detector_left and is_on_floor():
		on_edge = not floor_detector_left.is_colliding()

	# Solo girar en borde si el detector opuesto sí tiene suelo (evita flips infinitos)
	if on_edge:
		var opposite_safe := true
		if facing_direction > 0.0 and floor_detector_left:
			opposite_safe = floor_detector_left.is_colliding()
		elif facing_direction < 0.0 and floor_detector_right:
			opposite_safe = floor_detector_right.is_colliding()
		if opposite_safe:
			facing_direction = -facing_direction

	velocity.x = WALK_SPEED * facing_direction


## Persecución: se mueve hacia el jugador respetando bordes si el detector opuesto tiene suelo.
func _do_chase(player: Node2D) -> void:
	if player == null:
		_state = State.PATROL
		return

	var dir_to_player := signf(player.global_position.x - global_position.x)
	facing_direction = dir_to_player
	velocity.x = CHASE_SPEED * facing_direction


func _find_closest_player() -> Node2D:
	var closest: Node2D = null
	var min_dist := INF
	for node in get_tree().get_nodes_in_group("player"):
		var d := global_position.distance_to(node.global_position)
		if d < min_dist:
			min_dist = d
			closest = node
	return closest


func _update_sprite_direction() -> void:
	if velocity.x > 0.0:
		sprite.scale.x = 0.8
	elif velocity.x < 0.0:
		sprite.scale.x = -0.8


func _update_animation() -> void:
	var anim := get_new_animation()
	if anim != animation_player.current_animation:
		animation_player.play(anim)


func destroy() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	GameState.record_enemy_defeated()
	velocity = Vector2.ZERO


func get_new_animation() -> StringName:
	if _state == State.DEAD:
		return &"destroy"
	if not is_on_floor():
		return &"jump" if animation_player.has_animation(&"jump") else &"idle"
	if absf(velocity.x) > 5.0:
		return &"walk" if animation_player.has_animation(&"walk") else &"idle"
	return &"idle"
