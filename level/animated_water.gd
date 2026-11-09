@tool
extends Node2D
## Franja de agua decorativa; las colisiones siguen a cargo del peligro de caída.

@export var sprite_sheet: Texture2D
@export var water_width: float = 3840.0
@export var water_depth: float = 640.0
@export var frames_per_second: float = 7.0

const FRAME_SIZE := Vector2(887, 221)
const DRAW_SIZE := Vector2(512, 128)

var _elapsed: float = 0.0
var _frame: int = 0


func _process(delta: float) -> void:
	_elapsed += delta
	var next_frame := int(_elapsed * frames_per_second) % 8
	if next_frame != _frame:
		_frame = next_frame
		queue_redraw()


func _draw() -> void:
	if sprite_sheet == null:
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
