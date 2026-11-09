extends CharacterBody2D
## Chispa que avisa su trayectoria y luego cae desde arriba.
var fall_speed: float = 330.0
var warning_time: float = 0.4
var hazard_group := ""
var tint := Color("ff71b3")
var _age := 0.0
var _despawn_y: float
var _sensor: Area2D

func _ready() -> void:
	# Limpiar por recorrido, nunca por tiempo: las chispas lentas también terminan de caer.
	var viewport := get_viewport()
	var screen_bottom := viewport.get_visible_rect().end
	_despawn_y = maxf(global_position.y,
		(viewport.get_canvas_transform().affine_inverse() * screen_bottom).y) + 64.0
	collision_layer = 0
	collision_mask = 24
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("donut_sprinkle")
	if not hazard_group.is_empty():
		add_to_group(hazard_group)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(7, 17)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	var sensor_shape := CollisionShape2D.new()
	sensor_shape.shape = shape
	_sensor.add_child(sensor_shape)
	add_child(_sensor)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age < warning_time:
		queue_redraw()
		return
	velocity = Vector2(0, fall_speed)
	move_and_slide()
	for body in _sensor.get_overlapping_bodies():
		if body is Player:
			body.take_damage()
			queue_free()
			return
	if get_slide_collision_count() > 0 or global_position.y > _despawn_y:
		queue_free()
	queue_redraw()

func _draw() -> void:
	if _age < warning_time:
		draw_line(Vector2(0, 14), Vector2(0, 100), Color(tint, 0.3), 2.0)
		draw_circle(Vector2(0, 30), 5.0, Color(tint, 0.8))
	else:
		draw_line(Vector2(0, -6), Vector2(0, 6), Color("61334a"), 9.0, true)
		draw_line(Vector2(0, -5), Vector2(0, 5), tint, 6.0, true)
		draw_line(Vector2(-1, -5), Vector2(-1, 2), tint.lightened(0.5), 2.0)
