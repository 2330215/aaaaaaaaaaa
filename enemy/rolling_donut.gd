extends Area2D
## Dona baja que rueda por el piso y se esquiva saltando.
@export var speed: float = 260.0
@export var radius: float = 23.0
var direction: float = -1.0
var hazard_group := ""
var _angle := 0.0
var _age := 0.0
var _fall_speed: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	z_index = 5
	add_to_group("rolling_donut")
	if not hazard_group.is_empty():
		add_to_group(hazard_group)

func _physics_process(delta: float) -> void:
	_age += delta
	var travel := direction * speed * delta
	var space := get_world_2d().direct_space_state
	var wall_query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(travel + direction * radius, 0), 24)
	if not space.intersect_ray(wall_query).is_empty() or _age > 7.0:
		queue_free()
		return
	var next_position := global_position + Vector2(travel, 0)
	_fall_speed = minf(_fall_speed + 1600.0 * delta, 900.0)
	# Seguir pequeños desniveles sin atascarse en las uniones del atlas.
	var ground_query := PhysicsRayQueryParameters2D.create(
		next_position - Vector2(0, 8),
		next_position + Vector2(0, radius + maxf(8.0, _fall_speed * delta)), 24)
	var ground := space.intersect_ray(ground_query)
	if ground.is_empty():
		next_position.y += _fall_speed * delta
	else:
		next_position.y = ground.position.y - radius
		_fall_speed = 0.0
	global_position = next_position
	_angle += travel / radius
	for body in get_overlapping_bodies():
		if body is Player:
			body.take_damage()
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, _angle)
	draw_arc(Vector2.ZERO, radius * 0.63, 0, TAU, 40, Color("8e4828"), radius * 0.75, true)
	draw_arc(Vector2.ZERO, radius * 0.63, 0, TAU, 40, Color("e7a252"), radius * 0.62, true)
	draw_arc(Vector2(0, -1), radius * 0.63, 0, TAU, 40, Color("f36aa8"), radius * 0.48, true)
	var colors := [Color("ffe982"), Color("8bf4ed"), Color("fff2d7"), Color("c18cff")]
	for i in 12:
		var angle := i * TAU / 12.0
		var point := Vector2.from_angle(angle) * radius * 0.65
		draw_line(point - Vector2(2, 1), point + Vector2(2, 1), colors[i % 4], 2.0)
