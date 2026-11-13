extends Node2D
## Frente de tormenta con bancos de nubes, lluvia y descargas de fondo.

const WaveField = preload("res://level/background/animated_wave_field.gd")
const CLOUDS: Array[Texture2D] = [
	preload("res://level/background/assets_tormenta/nube_oscura.png"),
	preload("res://level/background/assets_tormenta/nube_alargada.png"),
	preload("res://level/background/assets_tormenta/nube_delgada.png"),
	preload("res://level/background/assets_tormenta/nube_densa.png")
]
const LIGHTNING: Array[Texture2D] = [
	preload("res://level/background/assets_tormenta/rayo_fondo_01.png"),
	preload("res://level/background/assets_tormenta/rayo_fondo_02.png"),
	preload("res://level/background/assets_tormenta/rayo_jugador.png")
]

var _area := Vector2.ZERO
var _clouds: Array[Sprite2D] = []
var _bolts: Array[Sprite2D] = []
var _rain: Array[Vector2] = []
var _waves: WaveField
var _rng := RandomNumberGenerator.new()
var _elapsed: float = 0.0
var _strike_wait: float = 0.8
var _strike_age: float = 1.0
var _flash: float = 0.0


func configure(repeat_width: float, image_height: float) -> void:
	var area := Vector2(repeat_width, image_height)
	if _area.is_equal_approx(area) or repeat_width <= 0.0 or image_height <= 0.0:
		return
	_area = area
	_rng.seed = 48213
	for sprite in _clouds + _bolts:
		sprite.queue_free()
	_clouds.clear()
	_bolts.clear()
	_rain.clear()
	var columns := maxi(4, ceili(repeat_width / image_height * 3.0))
	for row in range(3):
		for column in range(columns):
			var cloud := Sprite2D.new()
			cloud.texture = CLOUDS[(column + row) % CLOUDS.size()]
			var size := image_height * (0.28 + row * 0.035) / cloud.texture.get_height()
			cloud.scale = Vector2(size * 1.25, size)
			cloud.position = Vector2(repeat_width * (column + row * 0.33) / columns,
				image_height * (0.10 + row * 0.145))
			cloud.set_meta("origin_y", cloud.position.y)
			cloud.set_meta("speed", image_height / 724.0 * (20.0 + row * 18.0 + column % 3 * 4.0) * 0.35)
			cloud.set_meta("phase", _rng.randf() * TAU)
			cloud.modulate = Color(0.68 + row * 0.08, 0.72 + row * 0.07, 0.84 + row * 0.04, 0.92)
			cloud.z_index = 2
			add_child(cloud)
			_clouds.append(cloud)
			for side in [-1.0, 1.0]:
				var copy := Sprite2D.new()
				copy.texture = cloud.texture
				copy.position.x = side * repeat_width / size / 1.25
				cloud.add_child(copy)
	# Una descarga por tramo visible evita que todos los rayos caigan fuera de cámara.
	var bolt_count := maxi(2, ceili(repeat_width / image_height))
	for index in range(bolt_count):
		var bolt := Sprite2D.new()
		bolt.z_index = 1
		bolt.modulate.a = 0.0
		add_child(bolt)
		_bolts.append(bolt)
	for index in range(ceili(repeat_width / image_height * 100.0)):
		_rain.append(Vector2(_rng.randf() * repeat_width, _rng.randf_range(0.14, 0.64) * image_height))
	if _waves == null:
		_waves = WaveField.new()
		add_child(_waves)
	_waves.position.y = image_height * 0.655
	_waves.modulate = Color(0.72, 0.84, 0.98, 0.95)
	_waves.configure(Vector2(repeat_width, image_height * 0.33), image_height / 724.0, 1.8)
	animate(0.0)


func animate(delta: float) -> void:
	if not visible or _area == Vector2.ZERO:
		return
	_elapsed += delta
	for cloud in _clouds:
		var phase := float(cloud.get_meta("phase"))
		cloud.position.x = fposmod(cloud.position.x - float(cloud.get_meta("speed")) * delta, _area.x)
		cloud.position.y = float(cloud.get_meta("origin_y")) + sin(_elapsed * 0.55 + phase) * _area.y * 0.012
		# Deformación lenta del banco sin vaciar el cielo al renovar las nubes.
		cloud.skew = sin(_elapsed * 0.35 + phase) * 0.035
	_waves.update_waves(delta)
	for index in range(_rain.size()):
		_rain[index].x = fposmod(_rain[index].x - delta * _area.y * 0.20, _area.x)
		_rain[index].y = _area.y * 0.14 + fposmod(_rain[index].y - _area.y * 0.14 + delta * _area.y * 0.65, _area.y * 0.50)
	_strike_wait -= delta
	_strike_age += delta
	if _strike_wait <= 0.0:
		_strike_wait = _rng.randf_range(2.0, 4.2)
		_strike_age = 0.0
		for index in range(_bolts.size()):
			var bolt := _bolts[index]
			bolt.texture = LIGHTNING[_rng.randi_range(0, LIGHTNING.size() - 1)]
			bolt.scale = Vector2.ONE * _area.y * _rng.randf_range(0.40, 0.50) / bolt.texture.get_height()
			bolt.flip_h = _rng.randf() > 0.5
			bolt.position = Vector2(_area.x * (index + _rng.randf_range(0.25, 0.75)) / _bolts.size(), _area.y * 0.38)
	# Dos pulsos rápidos y una cola corta dan forma de descarga al destello.
	var pulse := 0.0
	if _strike_age < 0.10:
		pulse = 1.0
	elif _strike_age >= 0.17:
		pulse = (1.0 - smoothstep(0.23, 0.52, _strike_age)) * 0.85
	for bolt in _bolts:
		bolt.modulate.a = pulse
	_flash = pulse * 0.13
	queue_redraw()


func _draw() -> void:
	if _area == Vector2.ZERO:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(_area.x, _area.y * 0.65)), Color(0.035, 0.05, 0.12, 0.22))
	for drop in _rain:
		draw_line(drop, drop + Vector2(-0.008, 0.025) * _area.y, Color(0.62, 0.73, 0.90, 0.18), maxf(0.7, _area.y / 900.0))
	draw_rect(Rect2(Vector2.ZERO, Vector2(_area.x, _area.y * 0.65)), Color(0.65, 0.77, 1.0, _flash))
