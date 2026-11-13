@tool
extends Node2D
## Franja de agua decorativa; las colisiones siguen a cargo del peligro de caída.

@export var sprite_sheet: Texture2D
@export var water_width: float = 3840.0
@export var water_depth: float = 640.0
@export var breaking_waves: bool = false
@export var surface_color := Color(0.015, 0.62, 0.72)
@export var deep_color := Color(0.015, 0.36, 0.51)
@export var crest_color := Color.WHITE

@export var frames_per_second: float = 7.0

const FRAME_SIZE := Vector2(887, 221)
const DRAW_SIZE := Vector2(512, 128)

const WaveField = preload("res://level/background/animated_wave_field.gd")

var _wave_field: WaveField

var _elapsed: float = 0.0
var _frame: int = 0


func _ready() -> void:
	if breaking_waves:
		_wave_field = WaveField.new()
		_wave_field.position.y = -8.0
		_wave_field.modulate = crest_color
		add_child(_wave_field)
		_wave_field.configure(Vector2(water_width, minf(water_depth, 320.0)), 1.4, 1.5)


func _process(delta: float) -> void:
	if breaking_waves:
		if _wave_field:
			_wave_field.update_waves(delta)
		return
	_elapsed += delta
	var next_frame := int(_elapsed * frames_per_second) % 8
	if next_frame != _frame:
		_frame = next_frame
		queue_redraw()


func _draw() -> void:
	if sprite_sheet == null:
		return
	if breaking_waves:
		_draw_sea_body()
		return
	# Las filas del atlas tienen 221/222 píxeles: redondear evita tomar la fila vecina.
	var source := Rect2(Vector2((_frame % 2) * 887, roundi((_frame / 2) * 887.0 / 4.0)), FRAME_SIZE)
	var x := 0.0
	while x < water_width:
		var width := minf(DRAW_SIZE.x, water_width - x)
		var clipped_source := source
		clipped_source.size.x *= width / DRAW_SIZE.x
		# Repetir solo el interior opaco: las crestas quedan en la superficie.
		var body_source := Rect2(source.position + Vector2(8, 112), Vector2(871, 72))
		body_source.size.x *= width / DRAW_SIZE.x
		var y := 96.0
		var band := 0
		while y < water_depth:
			var height := minf(48.0, water_depth - y)
			var band_source := body_source
			band_source.size.y *= height / 48.0
			# Reflejar filas alternas une los mismos bordes sin cortes horizontales.
			if band % 2 == 1:
				band_source.position.y += body_source.size.y - band_source.size.y
				draw_set_transform(Vector2(x, y + height), 0.0, Vector2(1, -1))
			else:
				draw_set_transform(Vector2(x, y))
			draw_texture_rect_region(sprite_sheet, Rect2(0, 0, width, height), band_source)
			y += height
			band += 1
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect_region(sprite_sheet,
			Rect2(Vector2(x, 0), Vector2(width, DRAW_SIZE.y)), clipped_source)
		x += DRAW_SIZE.x


func _draw_sea_body() -> void:
	# Agua continua bajo las crestas: el borde transparente moja el casco
	# sin tapar de golpe la proa ni las plataformas del barco.
	var y := 0.0
	while y < water_depth:
		var height := minf(4.0, water_depth - y)
		var depth := y / maxf(water_depth, 1.0)
		var color := surface_color.lerp(deep_color, depth)
		color.a = smoothstep(0.0, 72.0, y)
		draw_rect(Rect2(0, y, water_width, height), color)
		y += height
