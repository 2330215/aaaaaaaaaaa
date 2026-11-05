extends Area2D
## Panes con aviso, polvo, rebote y retirada bajo el suelo.
@export var warning_time: float = 0.55
@export var active_time: float = 2.5
@export var bread_height: float = 140.0
@export var bread_spacing: float = 48.0

var _elapsed := 0.0
var _rise := 0.0
var _shapes: Array[CollisionShape2D] = []
var _bread_texture: Texture2D
var _texture_region := Rect2()
var _dust: Array[Dictionary] = []
var _last_rise: Array[float] = [0.0, 0.0, 0.0]


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("bread_barrier")
	_bread_texture = load("res://enemy/breadstick_pixel.png") as Texture2D
	if _bread_texture:
		# Usar solo el area pintada para que el margen transparente no reduzca el pan.
		_texture_region = Rect2(_bread_texture.get_image().get_used_rect())
	for index in 3:
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(24.0, 1.0)
		collider.shape = shape
		collider.disabled = true
		add_child(collider)
		_shapes.append(collider)
		for particle in 12:
			_dust.append({
				"index": index,
				"velocity": Vector2(randf_range(-90, 90), randf_range(-130, -35)),
				"size": randf_range(2, 5),
				"color": Color("d9b17d") if particle % 2 == 0 else Color("9b744b")
			})


func _bread_rise(index: int) -> float:
	var age := _elapsed - warning_time - absf(index - 1) * 0.055
	if age <= 0.0:
		return 0.0
	if age > active_time:
		# Enterrarse sin aplastar ni encoger la imagen.
		var progress := clampf((age - active_time) / 0.38, 0.0, 1.0)
		return 1.0 - progress * progress
	var t := clampf(age / 0.32, 0.0, 1.0)
	var s := t - 1.0
	return 1.0 + 2.1 * s * s * s + 1.1 * s * s


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_rise = _bread_rise(1)
	if _elapsed > warning_time + active_time + 0.55:
		queue_free()
		return
	for index in _shapes.size():
		var rise := _bread_rise(index)
		_last_rise[index] = rise
		var height := bread_height * (0.85 if index != 1 else 1.0)
		var visible_height := minf(height, height * rise)
		var collider := _shapes[index]
		collider.position = Vector2((index - 1) * bread_spacing, -visible_height * 0.5)
		(collider.shape as RectangleShape2D).size = Vector2(24.0, maxf(1.0, visible_height))
		collider.set_deferred("disabled", visible_height < 8.0)
	for body in get_overlapping_bodies():
		if body is Player:
			body.take_damage()
	queue_redraw()


func _draw() -> void:
	for index in 3:
		var x := (index - 1) * bread_spacing
		var age := _elapsed - warning_time - absf(index - 1) * 0.055
		var rise := _last_rise[index]
		var height := bread_height * (0.85 if index != 1 else 1.0)
		# Sombra de la abertura y grieta que avisa antes del ataque.
		var warning := clampf(_elapsed / maxf(warning_time, 0.01), 0.0, 1.0)
		draw_set_transform(Vector2(x, 0), 0, Vector2(1, 0.18))
		draw_circle(Vector2.ZERO, 20.0, Color(0.12, 0.07, 0.03, 0.65 * warning))
		if age < 0.0:
			draw_arc(Vector2.ZERO, 23.0, 0, TAU, 16, Color(1.0, 0.62, 0.15, 0.35 + sin(_elapsed * 24) * 0.15), 3.0)
		draw_set_transform(Vector2.ZERO)
		var crack := PackedVector2Array([Vector2(x-24, 0), Vector2(x-11, -3), Vector2(x-4, 1), Vector2(x+7, -2), Vector2(x+23, 1)])
		draw_polyline(crack, Color(0.24, 0.12, 0.04, warning), 2.0)
		if rise > 0.0 and _bread_texture:
			# Recortar la parte enterrada, manteniendo el tamano y los pixeles.
			var visible_fraction := minf(rise, 1.0)
			var source := _texture_region
			source.size.y *= visible_fraction
			var destination := Rect2(x - 17.0, -height * rise, 34.0, height * visible_fraction)
			draw_texture_rect_region(_bread_texture, destination, source)
		# Tierra delante de la base para integrar el pan con el piso.
		if age >= 0.0:
			draw_rect(Rect2(x-21, -2, 13, 4), Color("74502e"))
			draw_rect(Rect2(x+8, -1, 14, 3), Color("987042"))
	for particle in _dust:
		var age := _elapsed - warning_time - absf(int(particle.index) - 1) * 0.055
		if age < 0.0 or age > 0.6:
			continue
		var point := Vector2((int(particle.index)-1) * bread_spacing, -3.0)
		point += particle.velocity * age + Vector2(0, 220.0 * age * age)
		var tint: Color = particle.color
		tint.a = 1.0 - age / 0.6
		var size: float = particle.size
		draw_rect(Rect2(point, Vector2.ONE * size), tint)
