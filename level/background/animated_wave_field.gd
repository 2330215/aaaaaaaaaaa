extends Node2D
## Crestas que nacen, avanzan, rompen y se sustituyen al desaparecer.

const TEXTURES: Array[Texture2D] = [
	preload("res://level/background/olas/ola_01.png"),
	preload("res://level/background/olas/ola_02.png"),
	preload("res://level/background/olas/ola_03.png"),
	preload("res://level/background/olas/ola_04.png"),
	preload("res://level/background/olas/ola_05.png"),
	preload("res://level/background/olas/ola_06.png"),
	preload("res://level/background/olas/ola_07.png"),
	preload("res://level/background/olas/ola_08.png"),
	preload("res://level/background/olas/ola_09.png"),
	preload("res://level/background/olas/ola_10.png"),
	preload("res://level/background/olas/ola_11.png"),
	preload("res://level/background/olas/ola_12.png"),
	preload("res://level/background/olas/ola_13.png"),
	preload("res://level/background/olas/ola_14.png"),
	preload("res://level/background/olas/ola_15.png"),
	preload("res://level/background/olas/ola_16.png"),
	preload("res://level/background/olas/ola_17.png"),
	preload("res://level/background/olas/ola_18.png"),
	preload("res://level/background/olas/ola_19.png"),
	preload("res://level/background/olas/ola_20.png"),
	preload("res://level/background/olas/ola_21.png"),
	preload("res://level/background/olas/ola_22.png"),
	preload("res://level/background/olas/ola_23.png"),
	preload("res://level/background/olas/ola_24.png")
]

var _waves: Array[Sprite2D] = []
var _area := Vector2.ZERO
var _factor: float = 1.0
var _speed: float = 1.0
var _rng := RandomNumberGenerator.new()


func configure(area: Vector2, factor: float, speed: float = 1.0) -> void:
	_area = area
	_factor = factor
	_speed = speed
	_rng.seed = 41927
	for wave in _waves:
		wave.queue_free()
	_waves.clear()
	var columns := maxi(1, ceili(area.x / (125.0 * factor)))
	for row in range(10):
		for column in range(columns):
			var wave := Sprite2D.new()
			wave.set_meta("depth", float(row) / 9.0)
			wave.set_meta("column", float(column) / columns)
			add_child(wave)
			_waves.append(wave)
			_restart(wave)
			wave.set_meta("age", _rng.randf() * float(wave.get_meta("life")))
	update_waves(0.0)


func _restart(wave: Sprite2D) -> void:
	var depth: float = wave.get_meta("depth")
	wave.texture = TEXTURES[_rng.randi_range(0, TEXTURES.size() - 1)]
	wave.flip_h = _rng.randf() > 0.5
	wave.set_meta("age", 0.0)
	wave.set_meta("life", _rng.randf_range(1.0, 2.2))
	wave.set_meta("origin", Vector2(
		fposmod(float(wave.get_meta("column")) * _area.x + _rng.randf_range(-70, 70) * _factor, _area.x),
		_area.y * (0.02 + depth * 0.90)))
	wave.set_meta("size", _factor * lerpf(0.55, 1.35, depth) * _rng.randf_range(0.85, 1.15))


func update_waves(delta: float) -> void:
	for wave in _waves:
		var age := float(wave.get_meta("age")) + delta
		var life: float = wave.get_meta("life")
		if age >= life:
			_restart(wave)
			age = 0.0
			life = wave.get_meta("life")
		wave.set_meta("age", age)
		var progress := age / life
		var depth: float = wave.get_meta("depth")
		var origin: Vector2 = wave.get_meta("origin")
		# Avanzar hacia la orilla y estirar la cresta al romper; nunca flotar.
		wave.position = origin + Vector2(-age * lerpf(30.0, 85.0, depth), age * lerpf(3.0, 18.0, depth)) * _factor * _speed
		wave.position.x = fposmod(wave.position.x, _area.x)
		var size: float = wave.get_meta("size")
		wave.scale = Vector2(size * lerpf(0.8, 1.25, progress), size * lerpf(0.50, 0.25, progress))
		wave.modulate.a = smoothstep(0.0, 0.18, progress) * (1.0 - smoothstep(0.48, 1.0, progress)) * lerpf(0.55, 0.85, depth)
