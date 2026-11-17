extends Node2D
## Reflejos y cascada en las coordenadas del paisaje, incluidas sus copias reflejadas.

const REFLECTIONS: Array[Texture2D] = [
	preload("res://level/background/reflejos1.png"),
	preload("res://level/background/reflejos2.png")
]
const WATERFALL = preload("res://level/background/cascada.png")
const WaveField = preload("res://level/background/animated_wave_field.gd")
const REFLECTION_REGIONS: Array[Rect2] = [Rect2(90, 216, 1969, 383), Rect2(52, 259, 2069, 280)]
const FALL_REGION := Rect2(73, 239, 2027, 260)

var _stage: int = -1
var _width: float = 0.0
var _height: float = 0.0
var _elapsed: float = 0.0
var _waves: Array[Node2D] = []


func configure(stage: int, width: float, height: float) -> void:
	if stage == _stage and is_equal_approx(width, _width) and is_equal_approx(height, _height):
		return
	_stage = stage
	_width = width
	_height = height
	for wave in _waves:
		remove_child(wave)
		wave.queue_free()
	_waves.clear()
	var waterline := 0.81 if stage == 0 else 0.735
	for tile in range(2):
		var holder := Node2D.new()
		holder.position = Vector2(0.0 if tile == 0 else width * 2.0, height * waterline)
		holder.scale.x = 1.0 if tile == 0 else -1.0
		add_child(holder)
		_waves.append(holder)
		var field := WaveField.new()
		holder.add_child(field)
		field.modulate = Color(0.65, 0.95, 1.0, 0.28)
		field.configure(Vector2(width, height * (1.0 - waterline) * 0.85), height / 1100.0, 0.35)
	queue_redraw()


func animate(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	for holder in _waves:
		(holder.get_child(0) as WaveField).update_waves(delta)
	queue_redraw()


func _draw() -> void:
	if _stage < 0 or _stage > 1:
		return
	for tile in range(2):
		draw_set_transform(Vector2.ZERO if tile == 0 else Vector2(_width * 2.0, 0), 0.0,
			Vector2.ONE if tile == 0 else Vector2(-1, 1))
		var waterline := 0.81 if _stage == 0 else 0.735
		var lake := Rect2(_width * 0.02, _height * (waterline + 0.025), _width * 0.96, _height * (0.96 - waterline))
		_draw_flow(REFLECTIONS[_stage], REFLECTION_REGIONS[_stage], lake, false)
		if _stage == 1:
			# El labio y la espuma coinciden con el escalon de roca de nivel5_2.
			_draw_flow(WATERFALL, FALL_REGION,
				Rect2(_width * 0.267, _height * 0.612, _width * 0.535, _height * 0.124), true)
	draw_set_transform(Vector2.ZERO)


func _draw_flow(texture: Texture2D, region: Rect2, destination: Rect2, falling: bool) -> void:
	const STRIPS := 48
	for row in range(STRIPS):
		var depth := float(row) / STRIPS
		var source_y := region.position.y + region.size.y * depth
		var phase := depth * 22.0 - _elapsed * (9.0 if falling else 2.5)
		var shift := sin(phase) * _height * (0.0015 if falling else 0.004)
		var brightness := 0.88 + 0.12 * sin(phase)
		var alpha := brightness if falling else (0.30 + 0.15 * sin(_elapsed * 1.7 + depth * 12.0))
		var target := Rect2(destination.position + Vector2(shift, destination.size.y * depth),
			Vector2(destination.size.x, destination.size.y / STRIPS + 0.5))
		var source := Rect2(region.position.x, source_y, region.size.x, region.size.y / STRIPS)
		draw_texture_rect_region(texture, target, source, Color(brightness, brightness, 1.0, alpha))
