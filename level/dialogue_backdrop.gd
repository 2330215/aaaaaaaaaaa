extends ColorRect
## Detalles del entorno dibujados a escala del cuadro, dentro de su máscara de barrido.

var environment_level: int = 1
var _palette: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func apply_environment(level: int, palette: Dictionary) -> void:
	environment_level = clampi(level, 1, 5)
	_palette = palette
	color = palette["background"]
	queue_redraw()


func _draw() -> void:
	if _palette.is_empty():
		return
	var accent: Color = _palette["accent"]
	var detail: Color = _palette["detail"]
	var faint := Color(detail, 0.13)
	var width: float = size.x
	var height: float = size.y
	# Ribete superior y franja que sostiene visualmente el retrato.
	draw_rect(Rect2(0, 0, width, 3), accent)
	draw_rect(Rect2(10, 10, 118, height - 20), Color(detail, 0.09))
	draw_line(Vector2(136, 15), Vector2(136, height - 15), Color(accent, 0.32), 1.0)
	match environment_level:
		1:
			# Papel arenoso: manchas pequeñas, grietas y muescas en los bordes.
			for i in range(100):
				var point := Vector2(fmod(i * 73.0 + 19.0, width), fmod(i * 37.0 + 11.0, height))
				draw_rect(Rect2(point, Vector2(2 + i % 3, 1)), faint)
			for i in range(12):
				var x: float = width * float(i) / 11.0
				draw_polyline(PackedVector2Array([Vector2(x, height), Vector2(x + 6, height - 5), Vector2(x + 18, height - 3)]), Color(detail, 0.4), 2.0)
			draw_polyline(PackedVector2Array([Vector2(width - 130, height - 8), Vector2(width - 94, height - 19), Vector2(width - 56, height - 8), Vector2(width, height - 15)]), Color(detail, 0.3), 2.0)
		2:
			# Juntas de metal, remaches y una banda de señalización urbana.
			for x in range(0, int(width), 48):
				draw_line(Vector2(x, 4), Vector2(x, height), Color(detail, 0.06), 1.0)
			for x: float in [8.0, width - 9.0]:
				for y: float in [9.0, height - 9.0]:
					draw_circle(Vector2(x, y), 2.0, detail)
			for i in range(12):
				var x: float = width - 110 + i * 10
				draw_line(Vector2(x, height - 5), Vector2(x + 5, height - 11), Color("e7ba62"), 3.0)
		3, 5:
			# Tablones con vetas, clavos y pequeñas marcas de uso.
			for y in range(32, int(height), 30):
				draw_line(Vector2(0, y), Vector2(width, y), Color(_palette["border"], 0.45), 2.0)
			for i in range(22):
				var x: float = fmod(i * 97.0, width)
				var y: float = fmod(i * 23.0 + 15.0, height)
				draw_line(Vector2(x, y), Vector2(minf(x + 24 + i % 16, width), y + 1), faint, 1.0)
			for x: float in [7.0, width - 8.0]:
				for y: float in [10.0, height - 10.0]:
					draw_circle(Vector2(x, y), 2.0, Color(accent, 0.6))
			if environment_level == 3:
				_draw_mountains(width, height, detail)
			else:
				_draw_leaves(width, height, detail)
		4:
			# Cuerda en el ribete y espuma del mar en el borde inferior.
			draw_line(Vector2(0, 7), Vector2(width, 7), Color("cfba83"), 2.0)
			for x in range(0, int(width), 12):
				draw_line(Vector2(x, 5), Vector2(x + 4, 9), Color("8d7852"), 1.0)
			for row in range(2):
				var wave := PackedVector2Array()
				for x in range(0, int(width) + 5, 4):
					wave.append(Vector2(x, height - 5 - row * 7 + sin(x * 0.035 + row) * 3))
				draw_polyline(wave, Color(detail, 0.3 - row * 0.08), 2.0)


func _draw_mountains(width: float, height: float, detail: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(width - 170, height), Vector2(width - 126, height - 29),
		Vector2(width - 96, height - 13), Vector2(width - 62, height - 40),
		Vector2(width, height - 5), Vector2(width, height),
	]), Color(detail, 0.13))


func _draw_leaves(width: float, height: float, detail: Color) -> void:
	for side in range(2):
		var origin := Vector2(0 if side == 0 else width, height)
		var direction: float = 1.0 if side == 0 else -1.0
		for i in range(4):
			var tip := origin + Vector2(direction * (18 + i * 17), -18 - (3 - i) * 12)
			var middle := origin.lerp(tip, 0.55)
			draw_colored_polygon(PackedVector2Array([origin, middle + Vector2(-7, -5), tip, middle + Vector2(7, 5)]), Color(detail, 0.25))
