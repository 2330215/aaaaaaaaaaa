class_name Enemy extends CharacterBody2D


enum State {
	WALKING,
	DEAD,
}

## Los enemigos del tutorial pueden seguir quietos.
@export var stationary: bool = false
@export var patrol_speed: float = 100.0
@export var chase_speed: float = 160.0
## Distancia que recorre a cada lado de su posicion inicial.
@export var patrol_distance: float = 150.0
@export var detection_radius: float = 350.0
## Evita perseguir jugadores que estan en otro piso.
@export var detection_height: float = 100.0
@export var chase_stop_distance: float = 30.0

var _state := State.WALKING
var facing_direction: float = -1.0
var _patrol_origin_x: float

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var platform_detector: RayCast2D = get_node_or_null(^"PlatformDetector")
@onready var floor_detector_left: RayCast2D = get_node_or_null(^"FloorDetectorLeft")
@onready var floor_detector_right: RayCast2D = get_node_or_null(^"FloorDetectorRight")
@onready var sprite := $Sprite2D as Sprite2D
@onready var animation_player := $AnimationPlayer as AnimationPlayer


func _ready() -> void:
	_patrol_origin_x = global_position.x
	# Colocar los detectores fuera del cuerpo, incluso si se escala la colision.
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider and collider.shape:
		var bounds: Rect2 = collider.transform * collider.shape.get_rect()
		if floor_detector_left:
			floor_detector_left.position = Vector2(bounds.position.x - 8.0, bounds.get_center().y)
			floor_detector_left.target_position = Vector2(0.0, bounds.size.y * 0.5 + 24.0)
		if floor_detector_right:
			floor_detector_right.position = Vector2(bounds.end.x + 8.0, bounds.get_center().y)
			floor_detector_right.target_position = Vector2(0.0, bounds.size.y * 0.5 + 24.0)


func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta
	velocity.x = 0.0

	if _state == State.WALKING and not stationary:
		var target := _find_nearby_player()
		var speed := patrol_speed
		var should_move := true
		if target:
			var distance_x := target.global_position.x - global_position.x
			speed = chase_speed
			should_move = absf(distance_x) > chase_stop_distance
			if should_move:
				facing_direction = signf(distance_x)
		else:
			if global_position.x <= _patrol_origin_x - patrol_distance:
				facing_direction = 1.0
			elif global_position.x >= _patrol_origin_x + patrol_distance:
				facing_direction = -1.0

		if should_move and is_on_floor():
			var detector := floor_detector_right if facing_direction > 0.0 else floor_detector_left
			if detector:
				detector.force_raycast_update()
			var at_edge := detector != null and not detector.is_colliding()
			var against_wall := is_on_wall() and get_wall_normal().x * facing_direction < 0.0
			if at_edge or against_wall:
				should_move = false
				if not target:
					facing_direction = -facing_direction

		if should_move:
			velocity.x = speed * facing_direction

	move_and_slide()

	if not is_zero_approx(velocity.x):
		sprite.scale.x = absf(sprite.scale.x) * facing_direction

	var animation := get_new_animation()
	if animation != animation_player.current_animation:
		animation_player.play(animation)


func _find_nearby_player() -> Player:
	var nearest: Player = null
	var nearest_distance := detection_radius
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player:
			if absf(node.global_position.y - global_position.y) > detection_height:
				continue
			var distance := global_position.distance_to(node.global_position)
			if distance <= nearest_distance:
				nearest = node
				nearest_distance = distance
	return nearest


func destroy() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	GameState.record_enemy_defeated()
	velocity = Vector2.ZERO


func get_new_animation() -> StringName:
	if _state == State.DEAD:
		return &"destroy"
	if not is_on_floor() and animation_player.has_animation(&"jump"):
		return &"jump"
	if not is_zero_approx(velocity.x) and animation_player.has_animation(&"walk"):
		return &"walk"
	return &"idle"
