extends Enemy
## Patrulla un rectangulo en el aire y persigue al jugador cercano en ambos ejes.

@export var flight_patrol_size := Vector2(360.0, 160.0)

var _flight_origin := Vector2.ZERO
var _waypoint_index: int = 0
var _patrol_points: Array[Vector2] = []


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_flight_origin = global_position
	var half_size := flight_patrol_size.abs() * 0.5
	_patrol_points = [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	]


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		velocity = Vector2.ZERO
		return

	velocity = Vector2.ZERO
	if not stationary:
		var target := _find_nearby_player()
		if target:
			var offset := target.global_position - global_position
			# Limitar el avance para no sobrepasar al jugador ni vibrar cerca de el.
			var travel := maxf(0.0, offset.length() - chase_stop_distance)
			velocity = offset.normalized() * minf(chase_speed, travel / maxf(delta, 0.001))
		else:
			var destination := _flight_origin + _patrol_points[_waypoint_index]
			if global_position.distance_to(destination) <= 8.0:
				_waypoint_index = (_waypoint_index + 1) % _patrol_points.size()
				destination = _flight_origin + _patrol_points[_waypoint_index]
			var offset := destination - global_position
			velocity = offset.normalized() * minf(patrol_speed, offset.length() / maxf(delta, 0.001))

	move_and_slide()
	# Cambiar de punto si una pared interrumpe la patrulla.
	if get_slide_collision_count() > 0 and not stationary:
		_waypoint_index = (_waypoint_index + 1) % _patrol_points.size()
	if not is_zero_approx(velocity.x):
		facing_direction = signf(velocity.x)
		sprite.scale.x = absf(sprite.scale.x) * facing_direction
	var animation: StringName = &"walk" if not stationary else &"idle"
	if animation_player.current_animation != animation:
		animation_player.play(animation)


func _find_nearby_player() -> Player:
	var nearest: Player = null
	var nearest_distance := detection_radius
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player:
			var distance := global_position.distance_to(node.global_position)
			if distance <= nearest_distance:
				nearest = node
				nearest_distance = distance
	return nearest


func destroy() -> void:
	if _state == State.DEAD:
		return
	super.destroy()
	animation_player.play(&"destroy")
