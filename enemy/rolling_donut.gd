extends CharacterBody2D
## Dona baja que rueda por el piso y se esquiva saltando.
@export var speed: float = 260.0
@export var radius: float = 23.0
var direction: float = -1.0
var hazard_group := ""
var _angle := 0.0
var _age := 0.0
var _sensor: Area2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 24
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	add_to_group("rolling_donut")
	if not hazard_group.is_empty():
		add_to_group(hazard_group)
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	collider.shape = circle
	add_child(collider)
	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	var hurt_shape := CollisionShape2D.new()
	hurt_shape.shape = circle
	_sensor.add_child(hurt_shape)
	add_child(_sensor)

func _physics_process(delta: float) -> void:
	_age += delta
	velocity.x = direction * speed
	velocity.y = minf(velocity.y + 1600.0 * delta, 900.0)
	move_and_slide()
	_angle += direction * speed / radius * delta
	for body in _sensor.get_overlapping_bodies():
		if body is Player:
			body.take_damage()
	if is_on_wall() or _age > 7.0:
		queue_free()
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
