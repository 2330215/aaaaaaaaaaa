@tool
extends Node2D
## Escalera exterior o pasarela con barandales; colisión continua bajo los peldaños.

@export var points := PackedVector2Array():
	set(value):
		points = value
		queue_redraw()
		if is_inside_tree():
			_update_collisions()
@export var support_ground_y: float = 448.0
@export var draw_supports: bool = true
@export var steel_color := Color(0.26, 0.32, 0.39)
@export var rail_color := Color(0.76, 0.68, 0.48)


func _ready() -> void:
	_update_collisions()


func _update_collisions() -> void:
	var body := get_node_or_null("Walkway") as StaticBody2D
	if body == null:
		body = StaticBody2D.new()
		body.name = "Walkway"
		body.collision_layer = 16
		body.collision_mask = 0
		add_child(body)
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	for index in range(points.size()-1):
		var a := points[index]
		var b := points[index+1]
		if a.x > b.x:
			var swap := a
			a = b
			b = swap
		if is_equal_approx(a.x, b.x):
			continue
		var shape := RectangleShape2D.new()
		shape.size = Vector2(a.distance_to(b), 10)
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.rotation = (b-a).angle()
		collider.position = (a+b)*0.5 + Vector2(-sin(collider.rotation), cos(collider.rotation))*5.0
		collider.one_way_collision = true
		# Orientar la cara atravesable con la pendiente permite subir caminando.
		collider.one_way_collision_margin = 24.0 if not is_equal_approx(a.y,b.y) else 8.0
		body.add_child(collider)


func _draw() -> void:
	if points.size() < 2:
		return
	if draw_supports:
		var supports: Dictionary = {}
		for index in range(points.size()):
			var point := points[index]
			if not supports.has(point.x) or point.y < float(supports[point.x]):
				supports[point.x] = point.y
		for x: float in supports:
			var top := float(supports[x])
			draw_line(Vector2(x, top), Vector2(x, support_ground_y), steel_color.darkened(0.28), 8)
			draw_line(Vector2(x-1, top), Vector2(x-1, support_ground_y), steel_color.lightened(0.15), 2)
			draw_rect(Rect2(x-12, support_ground_y-8, 24, 8), steel_color)
	for index in range(points.size()-1):
		var a := points[index]
		var b := points[index+1]
		draw_line(a+Vector2(0, 6), b+Vector2(0, 6), Color(0.11, 0.15, 0.20), 14)
		draw_line(a+Vector2(0, 3), b+Vector2(0, 3), steel_color, 8)
		draw_line(a, b, steel_color.lightened(0.50), 2)
		var posts := maxi(1, ceili(a.distance_to(b)/48.0))
		for post in range(posts+1):
			var point := a.lerp(b, float(post)/posts)
			draw_line(point, point+Vector2(0, -30), steel_color, 3)
		draw_line(a+Vector2(0, -30), b+Vector2(0, -30), rail_color, 3)
		# Los peldaños siguen la rampa física y quedan unidos a la estructura.
		if not is_equal_approx(a.y, b.y):
			var steps := maxi(1, ceili(absf(b.x-a.x)/16.0))
			for step in range(steps):
				var point := a.lerp(b, (float(step)+0.5)/steps)
				draw_line(point+Vector2(-7, -1), point+Vector2(7, -1), rail_color, 2)
