class_name Enemy extends CharacterBody2D


enum State {
	WALKING,
	DEAD,
}

## Los enemigos del tutorial pueden seguir quietos.
@export var stationary: bool = false
@export var hit_points: int = 1
@export var patrol_speed: float = 100.0
@export var chase_speed: float = 160.0
## Distancia que recorre a cada lado de su posicion inicial.
@export var patrol_distance: float = 150.0
@export var detection_radius: float = 350.0
## Evita perseguir jugadores que estan en otro piso.
@export var detection_height: float = 100.0
@export var chase_stop_distance: float = 30.0
@export var can_jump: bool = false
@export var jump_velocity: float = -780.0
@export var jump_horizontal_speed: float = 360.0
var _jump_velocity_x: float = 0.0

var _state := State.WALKING
var facing_direction: float = -1.0
var _patrol_origin_x: float
var _damage_tween: Tween
var _damage_rest_position: Vector2
var _damage_rest_color: Color

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var platform_detector: RayCast2D = get_node_or_null(^"PlatformDetector")
@onready var floor_detector_left: RayCast2D = get_node_or_null(^"FloorDetectorLeft")
@onready var floor_detector_right: RayCast2D = get_node_or_null(^"FloorDetectorRight")
@onready var sprite := $Sprite2D as Sprite2D
@onready var animation_player := $AnimationPlayer as AnimationPlayer


func _ready() -> void:
	_patrol_origin_x = global_position.x
	_damage_rest_position = sprite.position
	_damage_rest_color = sprite.self_modulate
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
	if is_on_floor() and velocity.y >= 0.0:
		_jump_velocity_x = 0.0
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
			var higher_target := target != null and target.global_position.y < global_position.y - 40.0
			var jumped := can_jump and (at_edge or against_wall or higher_target) and _try_jump(target)
			if jumped:
				velocity.y = jump_velocity
			elif at_edge or against_wall:
				should_move = false
				if not target:
					facing_direction = -facing_direction

		if should_move:
			velocity.x = speed * facing_direction

	if _state == State.WALKING and not is_zero_approx(_jump_velocity_x):
		velocity.x = _jump_velocity_x
	move_and_slide()

	if not is_zero_approx(velocity.x):
		sprite.scale.x = absf(sprite.scale.x) * facing_direction

	var animation := get_new_animation()
	if animation != animation_player.current_animation:
		animation_player.play(animation)


## Busca suelo al otro lado y comprueba que el arco no atraviese paredes o techos.
func _try_jump(target: Player) -> bool:
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider == null or collider.shape == null:
		return false
	var bounds: Rect2 = collider.global_transform * collider.shape.get_rect()
	var feet := Vector2(global_position.x, bounds.end.y)
	var height := jump_velocity * jump_velocity / (2.0 * gravity)
	var max_reach := jump_horizontal_speed * 2.0 * absf(jump_velocity) / gravity
	var first_distance := bounds.size.x * 0.5 + 24.0
	for distance in range(int(first_distance), int(max_reach), 16):
		if target != null and distance > absf(target.global_position.x - global_position.x) + bounds.size.x:
			break
		var x := feet.x + facing_direction * distance
		var ray := PhysicsRayQueryParameters2D.create(Vector2(x, feet.y - height + 12.0), Vector2(x, feet.y + 64.0), collision_mask, [get_rid()])
		var hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			continue
		var landing: Vector2 = hit.position
		if hit.normal.y > -0.7:
			continue
		var supported := true
		for side: float in [-1.0, 1.0]:
			var foot := landing + Vector2(side * bounds.size.x * 0.35, 0.0)
			var support := PhysicsRayQueryParameters2D.create(foot - Vector2(0, 12), foot + Vector2(0, 24), collision_mask, [get_rid()])
			if get_world_2d().direct_space_state.intersect_ray(support).is_empty():
				supported = false
		if not supported:
			continue
		var rise := feet.y - landing.y
		if target != null and rise < 24.0 and absf(target.global_position.y - global_position.y) > 40.0 and not is_on_wall():
			continue
		var discriminant := jump_velocity * jump_velocity - 2.0 * gravity * rise
		if discriminant <= 0.0:
			continue
		var duration := (-jump_velocity + sqrt(discriminant)) / gravity
		var horizontal := facing_direction * distance / duration
		if absf(horizontal) > jump_horizontal_speed:
			continue
		var previous := Vector2.ZERO
		var clear := true
		for step in range(1, 12):
			var time := duration * float(step) / 12.0
			var offset := Vector2(horizontal * time, jump_velocity * time + 0.5 * gravity * time * time)
			if test_move(global_transform.translated(previous), offset - previous):
				clear = false
				break
			previous = offset
		if clear:
			_jump_velocity_x = horizontal
			return true
	return false


func _find_nearby_player() -> Player:
	var nearest: Player = null
	var nearest_distance := detection_radius
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player:
			if absf(node.global_position.y - global_position.y) > maxf(detection_height, 220.0 if can_jump else detection_height):
				continue
			var distance := global_position.distance_to(node.global_position)
			if distance <= nearest_distance:
				nearest = node
				nearest_distance = distance
	return nearest


func destroy() -> void:
	if _state == State.DEAD:
		return
	hit_points -= 1
	if hit_points > 0:
		_play_damage_feedback()
		return
	_reset_damage_feedback()
	_state = State.DEAD
	GameState.record_enemy_defeated()
	velocity = Vector2.ZERO


func _reset_damage_feedback() -> void:
	if _damage_tween:
		_damage_tween.kill()
		sprite.position = _damage_rest_position
		sprite.self_modulate = _damage_rest_color


func _play_damage_feedback() -> void:
	_reset_damage_feedback()
	var hit_sound := get_node_or_null(^"Hit") as AudioStreamPlayer2D
	if hit_sound:
		hit_sound.play()
	sprite.self_modulate = Color(1.0, 0.25, 0.25, _damage_rest_color.a)
	sprite.position = _damage_rest_position + Vector2(5.0, 0.0)
	_damage_tween = create_tween().set_parallel(true)
	_damage_tween.tween_property(sprite, "self_modulate", _damage_rest_color, 0.25)
	_damage_tween.tween_property(sprite, "position", _damage_rest_position - Vector2(4.0, 0.0), 0.05)
	_damage_tween.chain().tween_property(sprite, "position", _damage_rest_position + Vector2(2.0, 0.0), 0.05)
	_damage_tween.chain().tween_property(sprite, "position", _damage_rest_position, 0.05)


func get_new_animation() -> StringName:
	if _state == State.DEAD:
		return &"destroy"
	if not is_on_floor() and animation_player.has_animation(&"jump"):
		return &"jump"
	if not is_zero_approx(velocity.x) and animation_player.has_animation(&"walk"):
		return &"walk"
	return &"idle"
